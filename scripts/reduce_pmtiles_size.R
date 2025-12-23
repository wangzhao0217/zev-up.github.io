#!/usr/bin/env Rscript
# Script to reduce PMTiles file sizes for large line layers
# Uses 15% sampling and optimized tippecanoe settings

library(sf)

BASE_DIR <- "/workspaces/EV_modelling"
PMTILES_DIR <- file.path(BASE_DIR, "web", "pmtiles")

# Configuration for large files that need size reduction
LARGE_FILES <- list(
  list(
    gpkg_path = file.path(BASE_DIR, "output/SESTRAN/trip_purpose.gpkg"),
    output_name = "sestran_trip_purpose",
    col_range = c(15, 25),
    sample_rate = 0.15
  ),
  list(
    gpkg_path = file.path(BASE_DIR, "output/SESTRAN/range_feasibility.gpkg"),
    output_name = "sestran_range_feasibility",
    col_range = c(3, 10),
    sample_rate = 0.05  # Even smaller for the huge file
  ),
  list(
    gpkg_path = file.path(BASE_DIR, "output/SPT/trip_purpose.gpkg"),
    output_name = "spt_trip_purpose",
    col_range = c(15, 25),
    sample_rate = 0.10
  ),
  list(
    gpkg_path = file.path(BASE_DIR, "output/SPT/range_feasibility.gpkg"),
    output_name = "spt_range_feasibility",
    col_range = c(3, 10),
    sample_rate = 0.05
  ),
  list(
    gpkg_path = file.path(BASE_DIR, "output/Tactran/trip_purpose.gpkg"),
    output_name = "tactran_trip_purpose",
    col_range = c(15, 25),
    sample_rate = 0.15
  ),
  list(
    gpkg_path = file.path(BASE_DIR, "output/Tactran/range_feasibility.gpkg"),
    output_name = "tactran_range_feasibility",
    col_range = c(3, 10),
    sample_rate = 0.10
  )
)

convert_large_line_layer <- function(gpkg_path, output_name, col_range, sample_rate) {
  if (!file.exists(gpkg_path)) {
    message(sprintf("  Skipping %s: file not found", output_name))
    return(NULL)
  }

  file_size_gb <- file.info(gpkg_path)$size / (1024^3)
  message(sprintf("\nConverting %s (%.2f GB) with %.0f%% sampling...",
                  output_name, file_size_gb, sample_rate * 100))

  layer_name <- st_layers(gpkg_path)$name[1]
  sf_data <- st_read(gpkg_path, layer = layer_name, quiet = TRUE)

  message(sprintf("  Original CRS: %s", st_crs(sf_data)$input))

  # Keep specified columns
  n_cols <- ncol(sf_data)
  start_col <- min(col_range[1], n_cols)
  end_col <- min(col_range[2], n_cols)
  sf_data <- sf_data[, start_col:end_col]
  message(sprintf("  Kept columns %d-%d", start_col, end_col))

  # Sample data
  n_original <- nrow(sf_data)
  n_sample <- ceiling(n_original * sample_rate)
  set.seed(42)
  sf_data <- sf_data[sample(n_original, n_sample), ]
  message(sprintf("  Sampled: %d -> %d (%.0f%%)", n_original, n_sample, sample_rate * 100))

  # Only transform if not already WGS84
  current_crs <- st_crs(sf_data)
  if (!is.na(current_crs) && !is.null(current_crs$epsg) && current_crs$epsg != 4326) {
    message(sprintf("  Transforming from EPSG:%s to EPSG:4326", current_crs$epsg))
    sf_data <- st_transform(sf_data, 4326)
  } else if (is.na(current_crs)) {
    message("  Warning: No CRS defined, assuming EPSG:27700")
    st_crs(sf_data) <- 27700
    sf_data <- st_transform(sf_data, 4326)
  } else {
    message("  Already in WGS84, no transformation needed")
  }

  # Fix and simplify geometries
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  sf_data <- st_simplify(sf_data, dTolerance = 0.0005, preserveTopology = FALSE)
  sf_data <- st_make_valid(sf_data)
  sf_data <- sf_data[!st_is_empty(sf_data), ]

  # Check bounds
  bbox <- st_bbox(sf_data)
  message(sprintf("  Bounds: %.2f,%.2f to %.2f,%.2f",
                  bbox["xmin"], bbox["ymin"], bbox["xmax"], bbox["ymax"]))

  message(sprintf("  Features: %d", nrow(sf_data)))

  # Write to GeoJSON
  temp_geojson <- tempfile(fileext = ".geojson")
  st_write(sf_data, temp_geojson, delete_dsn = TRUE, quiet = TRUE)

  output_path <- file.path(PMTILES_DIR, paste0(output_name, ".pmtiles"))

  # Run tippecanoe
  cmd <- sprintf(
    'tippecanoe -o "%s" -Z8 -z14 --drop-densest-as-needed --extend-zooms-if-still-dropping -l "%s" --force "%s"',
    output_path, output_name, temp_geojson
  )

  system(cmd)
  unlink(temp_geojson)

  if (file.exists(output_path)) {
    size_mb <- file.info(output_path)$size / (1024^2)
    message(sprintf("  -> Created: %s (%.1f MB)", basename(output_path), size_mb))
    return(size_mb)
  } else {
    message(sprintf("  -> ERROR: Failed to create %s", output_path))
    return(NULL)
  }
}

# Main execution
message("========================================")
message("Reducing PMTiles File Sizes")
message("========================================")

results <- list()
for (config in LARGE_FILES) {
  tryCatch({
    size <- convert_large_line_layer(
      config$gpkg_path,
      config$output_name,
      config$col_range,
      config$sample_rate
    )
    if (!is.null(size)) {
      results[[config$output_name]] <- size
    }
  }, error = function(e) {
    message(sprintf("  ERROR processing %s: %s", config$output_name, e$message))
  })
}

# Print summary
message("\n========================================")
message("Summary")
message("========================================")

pmtiles_files <- list.files(PMTILES_DIR, pattern = "\\.pmtiles$", full.names = TRUE)
total_size_mb <- sum(file.info(pmtiles_files)$size) / (1024^2)

message(sprintf("Total PMTiles: %d files", length(pmtiles_files)))
message(sprintf("Total size: %.1f MB (%.2f GB)", total_size_mb, total_size_mb / 1024))

message("\nAll files:")
for (f in sort(pmtiles_files)) {
  size_mb <- file.info(f)$size / (1024^2)
  message(sprintf("  %s (%.1f MB)", basename(f), size_mb))
}
