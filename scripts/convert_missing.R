#!/usr/bin/env Rscript
# Convert only missing PMTiles files

library(sf)

BASE_DIR <- "/workspaces/EV_modelling"
OUTPUT_DIR <- file.path(BASE_DIR, "output")
PMTILES_DIR <- file.path(BASE_DIR, "web", "pmtiles")

COLUMN_RANGES <- list(
  adoption_propensity = c(418, 438),
  charging_network = c(418, 434),
  conversion_potential = c(418, 439),
  ev_assignment_replaceable_only = c(418, 451),
  integrated_conversion_with_ev_types = c(418, 444),
  trip_purpose = c(15, 25),
  range_feasibility = c(3, 10)
)

convert_polygon <- function(gpkg_path, output_name, stage) {
  message(sprintf("Converting: %s", output_name))

  layer_name <- st_layers(gpkg_path)$name[1]
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  col_range <- COLUMN_RANGES[[stage]]
  if (!is.null(col_range)) {
    n_cols <- ncol(sf_data)
    start_col <- min(col_range[1], n_cols)
    end_col <- min(col_range[2], n_cols)
    sf_data <- sf_data[, start_col:end_col]
  }

  if (is.na(st_crs(sf_data))) {
    st_crs(sf_data) <- 27700
  }
  sf_data <- st_transform(sf_data, 4326)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]
  sf_data <- st_simplify(sf_data, dTolerance = 0.0005, preserveTopology = TRUE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  message(sprintf("  Features: %d", nrow(sf_data)))

  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  cmd <- sprintf(
    'tippecanoe -o "%s" -Z5 -z12 --coalesce-densest-as-needed --drop-densest-as-needed --extend-zooms-if-still-dropping --simplification=10 -l "%s" --force "%s"',
    output_path, output_name, temp_geojson
  )

  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
  }
}

convert_line <- function(gpkg_path, output_name, stage, sample_rate = 0.15) {
  message(sprintf("Converting: %s", output_name))

  file_size_gb <- file.info(gpkg_path)$size / (1024^3)
  message(sprintf("  File size: %.2f GB", file_size_gb))

  layer_name <- st_layers(gpkg_path)$name[1]
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  col_range <- COLUMN_RANGES[[stage]]
  if (!is.null(col_range)) {
    n_cols <- ncol(sf_data)
    start_col <- min(col_range[1], n_cols)
    end_col <- min(col_range[2], n_cols)
    sf_data <- sf_data[, start_col:end_col]
  }

  n_original <- nrow(sf_data)
  n_sample <- ceiling(n_original * sample_rate)
  set.seed(42)
  sf_data <- sf_data[sample(n_original, n_sample), ]
  message(sprintf("  Sampled: %d -> %d (%.0f%%)", n_original, n_sample, sample_rate * 100))

  if (is.na(st_crs(sf_data))) {
    st_crs(sf_data) <- 27700
  }
  current_crs <- st_crs(sf_data)
  if (!is.null(current_crs$epsg) && current_crs$epsg != 4326) {
    sf_data <- st_transform(sf_data, 4326)
  }

  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]
  sf_data <- st_simplify(sf_data, dTolerance = 0.0005, preserveTopology = FALSE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  message(sprintf("  Features: %d", nrow(sf_data)))

  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  cmd <- sprintf(
    'tippecanoe -o "%s" -Z8 -z14 --drop-densest-as-needed --extend-zooms-if-still-dropping -l "%s" --force "%s"',
    output_path, output_name, temp_geojson
  )

  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
  }
}

# Missing files to create
missing <- list(
  # SPT polygon layers
  list(region = "SPT", stage = "adoption_propensity", type = "polygon"),
  list(region = "SPT", stage = "charging_network", type = "polygon"),
  list(region = "SPT", stage = "conversion_potential", type = "polygon"),
  list(region = "SPT", stage = "ev_assignment_replaceable_only", type = "polygon"),
  list(region = "SPT", stage = "integrated_conversion_with_ev_types", type = "polygon"),

  # SWESTRANS all layers
  list(region = "SWESTRANS", stage = "adoption_propensity", type = "polygon"),
  list(region = "SWESTRANS", stage = "charging_network", type = "polygon"),
  list(region = "SWESTRANS", stage = "conversion_potential", type = "polygon"),
  list(region = "SWESTRANS", stage = "ev_assignment_replaceable_only", type = "polygon"),
  list(region = "SWESTRANS", stage = "integrated_conversion_with_ev_types", type = "polygon"),
  list(region = "SWESTRANS", stage = "trip_purpose", type = "line", sample = 0.15),
  list(region = "SWESTRANS", stage = "range_feasibility", type = "line", sample = 0.05),

  # Tactran polygon layers
  list(region = "Tactran", stage = "adoption_propensity", type = "polygon"),
  list(region = "Tactran", stage = "charging_network", type = "polygon"),
  list(region = "Tactran", stage = "conversion_potential", type = "polygon"),
  list(region = "Tactran", stage = "ev_assignment_replaceable_only", type = "polygon"),
  list(region = "Tactran", stage = "integrated_conversion_with_ev_types", type = "polygon")
)

message("========================================")
message("Converting Missing PMTiles")
message("========================================\n")

for (item in missing) {
  gpkg_path <- file.path(OUTPUT_DIR, item$region, paste0(item$stage, ".gpkg"))
  output_name <- paste0(tolower(item$region), "_", item$stage)

  if (!file.exists(gpkg_path)) {
    message(sprintf("Skipping %s: file not found", output_name))
    next
  }

  tryCatch({
    if (item$type == "polygon") {
      convert_polygon(gpkg_path, output_name, item$stage)
    } else {
      sample_rate <- if (!is.null(item$sample)) item$sample else 0.15
      convert_line(gpkg_path, output_name, item$stage, sample_rate)
    }
  }, error = function(e) {
    message(sprintf("  ERROR: %s", e$message))
  })
}

message("\n========================================")
message("Summary")
message("========================================")

pmtiles_files <- list.files(PMTILES_DIR, pattern = "\\.pmtiles$", full.names = TRUE)
total_size_mb <- sum(file.info(pmtiles_files)$size) / (1024^2)
message(sprintf("Total: %d files, %.1f MB", length(pmtiles_files), total_size_mb))
