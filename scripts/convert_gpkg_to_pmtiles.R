#!/usr/bin/env Rscript
# PMTiles Conversion Script for EV Modelling Outputs
# Converts GPKG files to PMTiles for web visualization
#
# Usage: Rscript convert_gpkg_to_pmtiles.R
#
# Prerequisites:
#   devtools::install_github("nptscot/pmtiles")

library(sf)
library(dplyr)

BASE_DIR <- "/workspaces/EV_modelling"
OUTPUT_DIR <- file.path(BASE_DIR, "output")
PMTILES_DIR <- file.path(BASE_DIR, "web", "pmtiles")
DATA_DIR <- file.path(BASE_DIR, "data")

dir.create(PMTILES_DIR, recursive = TRUE, showWarnings = FALSE)

REGIONS <- c(
  "HITRANS", "Nestrans", "SESTRAN", "SPT", "SWESTRANS", "Tactran", "ZetTrans"
)

# Column ranges for each stage (based on ZetTrans analysis)
# Format: list(start_col, end_col) - end_col includes geometry
COLUMN_RANGES <- list(
  adoption_propensity = c(418, 438),
  charging_network = c(418, 434),
  trip_purpose = c(15, 25),
  range_feasibility = c(3, 10),
  conversion_potential = c(418, 439),
  integrated_conversion_with_ev_types = c(418, 444),
  ev_assignment_replaceable_only = c(418, 451)
)

POLYGON_STAGES <- c(
  "adoption_propensity",
  "charging_network",
  "conversion_potential",
  "ev_assignment_replaceable_only",
  "integrated_conversion_with_ev_types"
)

LINE_STAGES <- c(
  "trip_purpose",
  "range_feasibility"
)

# Tippecanoe optimization settings for smaller file sizes
TIPPECANOE_OPTS <- list(
  # Polygon layers: aggressive simplification at low zoom, preserve detail at high zoom
  polygon = paste(
    "-Z5 -z12",                              # Reduced max zoom from 14 to 12
    "--coalesce-densest-as-needed",          # Merge dense features
    "--drop-densest-as-needed",              # Drop features in dense areas
    "--extend-zooms-if-still-dropping",      # Extend if needed
    "--simplification=10",                   # Aggressive simplification
    "--detect-shared-borders",               # Better polygon simplification
    "--no-tile-size-limit",                  # Allow larger tiles for better compression
    "--no-feature-limit"                     # No feature limit per tile
  ),
  # Line layers: more aggressive optimization
  line = paste(
    "-Z6 -z12",                              # Reduced zoom range
    "--coalesce-densest-as-needed",
    "--drop-densest-as-needed",
    "--extend-zooms-if-still-dropping",
    "--simplification=10",
    "--no-tile-size-limit",
    "--no-feature-limit"
  ),
  # Point layers: minimal optimization
  point = paste(
    "-Z4 -z14",
    "--drop-densest-as-needed",
    "--extend-zooms-if-still-dropping",
    "-r1"                                    # No feature dropping at base zoom
  )
)

get_layer_name <- function(gpkg_path) {
  layers <- st_layers(gpkg_path)$name
  if (length(layers) == 0) stop("No layers found in GPKG file")
  return(layers[1])
}

convert_polygon_layer <- function(gpkg_path, output_name, stage, columns = NULL) {
  message(sprintf("Converting polygon: %s", basename(gpkg_path)))

  layer_name <- get_layer_name(gpkg_path)
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  # Get column range for this stage (if not explicitly provided)
  if (!is.null(columns)) {
    # Use explicit column names
    geom_col <- attr(sf_data, "sf_column")
    cols_to_keep <- intersect(columns, names(sf_data))
    sf_data <- sf_data[, c(cols_to_keep, geom_col)]
    message(sprintf("  Kept %d columns: %s", length(cols_to_keep), paste(cols_to_keep, collapse = ", ")))
  } else {
    col_range <- COLUMN_RANGES[[stage]]
    if (!is.null(col_range)) {
      n_cols <- ncol(sf_data)
      start_col <- min(col_range[1], n_cols)
      end_col <- min(col_range[2], n_cols)
      sf_data <- sf_data[, start_col:end_col]
      message(sprintf("  Kept columns %d-%d", start_col, end_col))
    }
  }

  if (is.na(st_crs(sf_data))) {
    message("  Warning: No CRS defined, assuming EPSG:27700")
    st_crs(sf_data) <- 27700
  }
  sf_data <- st_transform(sf_data, 4326)

  # Fix invalid geometries
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  # More aggressive simplification for smaller files
  sf_data <- st_simplify(sf_data, dTolerance = 0.0005, preserveTopology = TRUE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  message(sprintf("  Features: %d, Columns: %d", nrow(sf_data), ncol(sf_data)))

  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  # Use optimized tippecanoe settings
  cmd <- sprintf(
    'tippecanoe -o "%s" %s -l "%s" --force "%s"',
    output_path,
    TIPPECANOE_OPTS$polygon,
    output_name,
    temp_geojson
  )

  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
  } else {
    message(sprintf("  -> ERROR: Failed to create %s", output_path))
  }
}

convert_line_layer <- function(gpkg_path, output_name, stage) {
  message(sprintf("Converting lines: %s", basename(gpkg_path)))

  file_size_gb <- file.info(gpkg_path)$size / (1024^3)
  message(sprintf("  File size: %.2f GB", file_size_gb))

  layer_name <- get_layer_name(gpkg_path)
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  # Get column range for this stage
 col_range <- COLUMN_RANGES[[stage]]
  if (!is.null(col_range)) {
    n_cols <- ncol(sf_data)
    start_col <- min(col_range[1], n_cols)
    end_col <- min(col_range[2], n_cols)
    sf_data <- sf_data[, start_col:end_col]
    message(sprintf("  Kept columns %d-%d", start_col, end_col))
  }

  # More aggressive sampling for smaller files
  sample_rate <- 1.0
  if (file_size_gb > 10) {
    sample_rate <- 0.01  # 1% for huge files (>10GB)
  } else if (file_size_gb > 3) {
    sample_rate <- 0.03  # 3% for very large files
  } else if (file_size_gb > 1) {
    sample_rate <- 0.05  # 5% for large files
  } else if (file_size_gb > 0.5) {
    sample_rate <- 0.10  # 10% for medium files
  } else if (file_size_gb > 0.1) {
    sample_rate <- 0.15  # 15% for smaller files
  }

  if (sample_rate < 1.0) {
    n_original <- nrow(sf_data)
    n_sample <- ceiling(n_original * sample_rate)
    set.seed(42)
    sf_data <- sf_data[sample(n_original, n_sample), ]
    message(sprintf("  Sampled: %d -> %d (%.0f%%)", n_original, n_sample, sample_rate * 100))
  }

  if (is.na(st_crs(sf_data))) {
    message("  Warning: No CRS defined, assuming EPSG:27700")
    st_crs(sf_data) <- 27700
  }
  sf_data <- st_transform(sf_data, 4326)

  # Fix invalid geometries
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  # More aggressive simplification
  sf_data <- st_simplify(sf_data, dTolerance = 0.001, preserveTopology = FALSE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  message(sprintf("  Features: %d, Columns: %d", nrow(sf_data), ncol(sf_data)))

  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  # Use optimized tippecanoe settings
  cmd <- sprintf(
    'tippecanoe -o "%s" %s -l "%s" --force "%s"',
    output_path,
    TIPPECANOE_OPTS$line,
    output_name,
    temp_geojson
  )

  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
  } else {
    message(sprintf("  -> ERROR: Failed to create %s", output_path))
  }
}

convert_all <- function() {
  message("========================================")
  message("PMTiles Conversion for EV Modelling")
  message("========================================")
  message(sprintf("Output directory: %s", PMTILES_DIR))
  message("")

  for (region in REGIONS) {
    message(sprintf("\n=== Processing %s ===", region))
    region_dir <- file.path(OUTPUT_DIR, region)

    if (!dir.exists(region_dir)) {
      message("  Skipping: directory not found")
      next
    }

    for (stage in POLYGON_STAGES) {
      gpkg_path <- file.path(region_dir, paste0(stage, ".gpkg"))
      if (file.exists(gpkg_path)) {
        output_name <- sprintf("%s_%s", tolower(region), stage)
        tryCatch(
          convert_polygon_layer(gpkg_path, output_name, stage),
          error = function(e) message(sprintf("  ERROR: %s", e$message))
        )
      } else {
        message(sprintf("  Skipping %s: file not found", stage))
      }
    }

    for (stage in LINE_STAGES) {
      gpkg_path <- file.path(region_dir, paste0(stage, ".gpkg"))
      if (file.exists(gpkg_path)) {
        output_name <- sprintf("%s_%s", tolower(region), stage)
        tryCatch(
          convert_line_layer(gpkg_path, output_name, stage),
          error = function(e) message(sprintf("  ERROR: %s", e$message))
        )
      } else {
        message(sprintf("  Skipping %s: file not found", stage))
      }
    }
  }

  print_summary()
}

#' Convert car/van availability demographic data to PMTiles
convert_car_availability <- function() {
  message("\n=== Converting Car/Van Availability Data ===")

  gpkg_path <- file.path(
    DATA_DIR,
    "demographic_data",
    "scotland_oa_2011_census_Accommodation_type_by_car_or_van_availability_by_number_of_people_aged_17_or_over_in_household_scotland.gpkg"
  )

  if (!file.exists(gpkg_path)) {
    message("  ERROR: File not found")
    return()
  }

  message(sprintf("  Reading: %s", basename(gpkg_path)))
  layer_name <- get_layer_name(gpkg_path)
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  # Select key columns for visualization
  # Calculate summary metrics from the raw data
  cols <- names(sf_data)
  geom_col <- attr(sf_data, "sf_column")

  # Keep geo_code and calculate summary statistics
  sf_data$geo_code <- sf_data$geo_code

  # Parse numeric columns (they're stored as strings)
  # Total households
  total_col <- grep("All\\.households\\._Total_All\\.households", cols, value = TRUE)
  if (length(total_col) > 0) {
    sf_data$total_households <- as.numeric(sf_data[[total_col[1]]])
  }

  # No cars/vans
  no_car_col <- grep("All\\.households\\._Number\\.of\\.cars\\.or\\.vans\\.in\\.household\\.\\.No\\.cars\\.or\\.vans_All\\.households", cols, value = TRUE)
  if (length(no_car_col) > 0) {
    sf_data$no_car_households <- as.numeric(sf_data[[no_car_col[1]]])
  }

  # One car/van
  one_car_col <- grep("All\\.households\\._Number\\.of\\.cars\\.or\\.vans\\.in\\.household\\.\\.One\\.car\\.or\\.van_All\\.households", cols, value = TRUE)
  if (length(one_car_col) > 0) {
    sf_data$one_car_households <- as.numeric(sf_data[[one_car_col[1]]])
  }

  # Two or more cars/vans
  multi_car_col <- grep("All\\.households\\._Number\\.of\\.cars\\.or\\.vans\\.in\\.household\\.\\.Two\\.or\\.more\\.cars\\.or\\.vans_All\\.households", cols, value = TRUE)
  if (length(multi_car_col) > 0) {
    sf_data$multi_car_households <- as.numeric(sf_data[[multi_car_col[1]]])
  }

  # Calculate percentages
  sf_data$no_car_pct <- ifelse(sf_data$total_households > 0,
                                sf_data$no_car_households / sf_data$total_households, 0)
  sf_data$one_car_pct <- ifelse(sf_data$total_households > 0,
                                 sf_data$one_car_households / sf_data$total_households, 0)
  sf_data$multi_car_pct <- ifelse(sf_data$total_households > 0,
                                   sf_data$multi_car_households / sf_data$total_households, 0)
  sf_data$car_ownership_rate <- 1 - sf_data$no_car_pct

  # Keep only summary columns
  keep_cols <- c("geo_code", "total_households", "no_car_households", "one_car_households",
                 "multi_car_households", "no_car_pct", "one_car_pct", "multi_car_pct",
                 "car_ownership_rate", geom_col)
  sf_data <- sf_data[, intersect(keep_cols, names(sf_data))]

  message(sprintf("  Features: %d, Columns: %d", nrow(sf_data), ncol(sf_data)))

  # Transform CRS
  if (is.na(st_crs(sf_data))) {
    st_crs(sf_data) <- 4326
  } else if (st_crs(sf_data)$epsg != 4326) {
    sf_data <- st_transform(sf_data, 4326)
  }

  # Fix and simplify geometries
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]
  sf_data <- st_simplify(sf_data, dTolerance = 0.0005, preserveTopology = TRUE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  # Write to GeoJSON
  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, "car_availability.pmtiles")

  cmd <- sprintf(
    'tippecanoe -o "%s" %s -l "car_availability" --force "%s"',
    output_path,
    TIPPECANOE_OPTS$polygon,
    temp_geojson
  )

  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
  } else {
    message(sprintf("  -> ERROR: Failed to create %s", output_path))
  }
}

#' Convert EV distribution MOT data to PMTiles
convert_ev_distribution <- function() {
  message("\n=== Converting EV Distribution Data ===")

  gpkg_path <- file.path(DATA_DIR, "mot", "ev_distribution.gpkg")

  if (!file.exists(gpkg_path)) {
    message("  ERROR: File not found")
    return()
  }

  message(sprintf("  Reading: %s", basename(gpkg_path)))
  layer_name <- get_layer_name(gpkg_path)
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  message(sprintf("  Features: %d, Columns: %d", nrow(sf_data), ncol(sf_data)))

  # Transform CRS (data is in EPSG:27700)
  if (is.na(st_crs(sf_data))) {
    st_crs(sf_data) <- 27700
  }
  sf_data <- st_transform(sf_data, 4326)

  # Fix and simplify geometries
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]
  sf_data <- st_simplify(sf_data, dTolerance = 0.001, preserveTopology = TRUE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  # Write to GeoJSON
  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, "ev_distribution.pmtiles")

  cmd <- sprintf(
    'tippecanoe -o "%s" %s -l "ev_distribution" --force "%s"',
    output_path,
    TIPPECANOE_OPTS$polygon,
    temp_geojson
  )

  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
  } else {
    message(sprintf("  -> ERROR: Failed to create %s", output_path))
  }
}

#' Print summary of all PMTiles files
print_summary <- function() {
  message("\n========================================")
  message("Conversion Summary")
  message("========================================")

  pmtiles_files <- list.files(PMTILES_DIR, pattern = "\\.pmtiles$", full.names = TRUE)
  total_size_mb <- sum(file.info(pmtiles_files)$size) / (1024^2)

  message(sprintf("Created %d PMTiles files", length(pmtiles_files)))
  message(sprintf("Total size: %.1f MB", total_size_mb))

  for (f in sort(pmtiles_files)) {
    size_mb <- file.info(f)$size / (1024^2)
    message(sprintf("  %s (%.1f MB)", basename(f), size_mb))
  }

  message("\nNext Steps:")
  message("1. Upload PMTiles to GitHub Releases")
  message("2. Update CONFIG.pmtilesBaseUrl in web/js/config.js")
  message("3. Deploy web/ folder to GitHub Pages")
}

#' Convert only the new overlay layers (car availability and EV distribution)
convert_overlays <- function() {
  message("========================================")
  message("Converting Overlay Layers")
  message("========================================")

  convert_car_availability()
  convert_ev_distribution()

  print_summary()
}

# To run from command line:
# Rscript -e "source('web/scripts/convert_gpkg_to_pmtiles.R'); convert_all()"
# Rscript -e "source('web/scripts/convert_gpkg_to_pmtiles.R'); convert_overlays()"