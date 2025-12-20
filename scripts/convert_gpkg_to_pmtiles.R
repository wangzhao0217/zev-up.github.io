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

get_layer_name <- function(gpkg_path) {
  layers <- st_layers(gpkg_path)$name
  if (length(layers) == 0) stop("No layers found in GPKG file")
  return(layers[1])
}

convert_polygon_layer <- function(gpkg_path, output_name, stage) {
  message(sprintf("Converting polygon: %s", basename(gpkg_path)))

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

  if (is.na(st_crs(sf_data))) {
    message("  Warning: No CRS defined, assuming EPSG:27700")
    st_crs(sf_data) <- 27700
  }
  sf_data <- st_transform(sf_data, 4326)

  # Fix invalid geometries
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  sf_data <- st_simplify(sf_data, dTolerance = 0.001, preserveTopology = TRUE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  message(sprintf("  Features: %d, Columns: %d", nrow(sf_data), ncol(sf_data)))

  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  cmd <- sprintf(
    'tippecanoe -o "%s" -Z6 -z14 --drop-densest-as-needed %s -l "%s" --force "%s"',
    output_path,
    "--extend-zooms-if-still-dropping",
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

  # Sample large files
  sample_rate <- 1.0
  if (file_size_gb > 5) {
    sample_rate <- 0.1
  } else if (file_size_gb > 1) {
    sample_rate <- 0.3
  } else if (file_size_gb > 0.5) {
    sample_rate <- 0.5
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

  sf_data <- st_simplify(sf_data, dTolerance = 0.0005, preserveTopology = FALSE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  message(sprintf("  Features: %d, Columns: %d", nrow(sf_data), ncol(sf_data)))

  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  cmd <- sprintf(
    'tippecanoe -o "%s" -Z8 -z14 --drop-densest-as-needed %s -l "%s" --force "%s"',
    output_path,
    "--extend-zooms-if-still-dropping",
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

if (!interactive()) {
  convert_all()
}