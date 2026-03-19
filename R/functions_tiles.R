match_cur_fut_files <- function(cur_files, fut_files) {
  to_species_key <- function(x) {
    x <- basename(x)
    x <- sub("\\.tif$", "", x, ignore.case = TRUE)
    x <- sub("^binary[_ ]+", "", x, ignore.case = TRUE)
    x <- sub("(_CurrentActual|_CurrentAtual|_Current)$", "", x, ignore.case = TRUE)
    x <- sub("(_FuturePotentialReachable|_FuturePotential|_FutureReachable|_Future)$", "", x, ignore.case = TRUE)
    x <- gsub("[[:space:]]+", "_", x)
    x <- gsub("_+", "_", x)
    x <- gsub("^_|_$", "", x)
    x
  }
  
  cur_key <- to_species_key(cur_files)
  fut_key <- to_species_key(fut_files)
  
  if (!setequal(cur_key, fut_key)) {
    stop(
      "Species sets differ.\n",
      "Missing in future: ", paste(setdiff(cur_key, fut_key), collapse = ", "), "\n",
      "Missing in current: ", paste(setdiff(fut_key, cur_key), collapse = ", ")
    )
  }
  
  list(
    cur = cur_files,
    fut = fut_files[match(cur_key, fut_key)]
  )
}

make_tile_grid <- function(eu_shape, cellsize) {
  grid <- sf::st_make_grid(
    eu_shape, 
    cellsize = c(cellsize, cellsize)
    ) |>
    sf::st_as_sf()
}

is_jointly_empty <- function(r1, r2) {
  n1 <- terra::global(!is.na(r1), "sum", na.rm = TRUE)[1, 1]
  n2 <- terra::global(!is.na(r2), "sum", na.rm = TRUE)[1, 1]
  
  empty1 <- is.na(n1) || n1 == 0
  empty2 <- is.na(n2) || n2 == 0
  
  empty1 && empty2
}

process_one_tile <- function(i, grid_sf, cur_files, fut_files, out_dir_cur, out_dir_fut) {
  
  message("------ Tile ", i, " ------")
  
  dir.create(out_dir_cur, recursive = TRUE, showWarnings = FALSE)
  dir.create(out_dir_fut, recursive = TRUE, showWarnings = FALSE)

  # If the output files already exist, skip processing.
  fcur <- file.path(out_dir_cur, sprintf("tile_current_%03d.tif", i))
  ffut <- file.path(out_dir_fut, sprintf("tile_future_%03d.tif", i))
  fempty <- file.path(out_dir_cur, sprintf("tile_pair_%03d.empty", i))

  if (file.exists(fcur) && file.exists(ffut)) {
    message("Tile ", i, " already exists, skipping.")
    return(c(fcur, ffut))
  }

  if (file.exists(fempty)) {
    message("Tile ", i, " already known to be jointly empty, skipping.")
    return(fempty)
  }

  cur_stack <- terra::rast(cur_files)
  fut_stack <- terra::rast(fut_files)
  
  tile_vect <- terra::vect(grid_sf[i, ])
  e <- terra::ext(tile_vect)
  
  message("Cropping tile ", i)
  cur_tile <- terra::crop(cur_stack, e, snap = "out")
  fut_tile <- terra::crop(fut_stack, e, snap = "out")
  
   if (is_jointly_empty(cur_tile, fut_tile)) {
    rm(cur_tile, fut_tile, cur_stack, fut_stack)
    gc()

    file.create(fempty)
    message("Tile ", i, " skipped (jointly empty)")
    return(fempty)
  }
  
  wopt <- list(
    datatype = "INT1U",
    gdal = c("COMPRESS=LZW", "TILED=YES", "BIGTIFF=YES")
  )
  
  terra::writeRaster(cur_tile, fcur, overwrite = TRUE, wopt = wopt)
  terra::writeRaster(fut_tile, ffut, overwrite = TRUE, wopt = wopt)
  
  rm(cur_tile, fut_tile, cur_stack, fut_stack)
  gc()
  message("Finished tile ", i)
  
  c(fcur, ffut)
}