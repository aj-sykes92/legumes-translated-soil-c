
library(raster)
library(tidyverse)

# read in sand raster from external repo
sand <- raster(find_onedrive("GIS data repository/SoilGrids 5km/Sand content", "SNDPPT_M_sl4_5km_ll.tif"))
sand <- readAll(sand)

# resample to climdata resolution
template <- read_rds("raw-data/climate-rasters/cru-4-03-temp-20y-mm-1999-2018.rds")[[1]]
sand <- resample(sand, template)

# write out
write_rds(sand, "raw-data/sand-fraction/soilgrids-sandfrac-resampled-30-arc-sec.rds")
