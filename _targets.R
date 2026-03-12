# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(crew)
library(crew.cluster)

## Running on HPC with Slurm:
project_dir <- "/vsc-hard-mounts/leuven-data/348/vsc34871/MakeTiles_CutFutBinaryStacks"

dir.create(file.path(project_dir, "crew_scripts"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(project_dir, "logs"), recursive = TRUE, showWarnings = FALSE)

tar_option_set(
  packages = c("terra", "sf"),
  memory = "transient",
  garbage_collection = 1,
  controller = crew_controller_slurm(
    name = "MakeTiles",
    workers = 1,
    seconds_idle = 60,
    seconds_wall = 10 * 3600,
    options_cluster = crew_options_slurm(
      script_directory = file.path(project_dir, "crew_scripts"),
      cpus_per_task = 72,
      n_tasks = 1,
      memory_gigabytes_per_cpu = 3,
      time_minutes = 5 * 60,
      partition = "batch",
      log_output = file.path(project_dir, "logs", "crew_%A.out"),
      log_error  = file.path(project_dir, "logs", "crew_%A.err"),
      script_lines = c(
        "#SBATCH -A lp_climateplants",
        "#SBATCH -M wice",
        "source $VSC_HOME/.bashrc",
        "source activate VoCC_R_new",
        "cd $VSC_DATA/MakeTiles_CutFutBinaryStacks",
        "export OMP_NUM_THREADS=1",
        "export GDAL_NUM_THREADS=1"
      )
    )
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
