# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes) # Load other packages as needed.
library(clustermq)

## Running on HPC with Slurm:
# Settings for clustermq
options(
  clustermq.scheduler = "slurm",
  clustermq.template = "./cmq.tmpl" # if using your own template
)

# # Running locally on Windows
# options(clustermq.scheduler = "multiprocess")

tar_option_set(
  resources = tar_resources(
    clustermq = tar_resources_clustermq(template = list(
      job_name = "MakeTiles_CutFutBinaryStacks",
      per_cpu_mem = "3000mb", #"3470mb"(wice thin node), #"21000mb" (genius bigmem， hugemem)"5100mb"
      n_tasks = 1,
      per_task_cpus = 72,
      walltime = "10:00:00"
    ))
  )
)

# Run the R scripts in the R/ folder with your custom functions:
tar_source()
# tar_source("other_functions.R") # Source other scripts as needed.

# Replace the target list below with your own:
list(
  tar_target(
    cur_files,
    list.files(
      "/lustre1/scratch/348/vsc34871/Binary_curActual/",
      pattern = "\\.tif$",
      full.names = TRUE
    )
  ),
  tar_target(
    fut_files,
    list.files(
      "/lustre1/scratch/348/vsc34871/Binary_futActual/",
      pattern = "\\.tif$",
      full.names = TRUE
    )
  ),
  tar_target(
    matched_files,
    match_cur_fut_files(cur_files, fut_files)
  ),
  tar_target(
    eu_shape,
    {
      x <- sf::read_sf("/lustre1/scratch/348/vsc34871/EUshap/Europe.shp")
      sf::st_buffer(x, 1)
    }
  ),
  tar_target(
    grid_sf,
    make_tile_grid(
      eu_shape = eu_shape,
      cellsize = 6e5
    )
  ),
  tar_target(
    tile_index,
    seq_len(nrow(grid_sf))
  ),
  tar_target(
    tile_pair_files,
    process_one_tile(
      i = tile_index,
      grid_sf = grid_sf,
      cur_files = matched_files$cur,
      fut_files = matched_files$fut,
      out_dir_cur = "/lustre1/scratch/348/vsc34871/output/Binary_CurrentActual_tiles/",
      out_dir_fut = "/lustre1/scratch/348/vsc34871/output/Binary_FutureReachable_tiles/"
    ),
    pattern = map(tile_index),
    format = "file"
  )
)
