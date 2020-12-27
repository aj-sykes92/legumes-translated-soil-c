
library(raster)
library(rgdal)
library(tidyverse)

# read in cru climate data
mm_temp <- read_rds("raw-data/climate-rasters/cru-4-03-temp-20y-mm-1999-2018.rds")
mm_precip <- read_rds("raw-data/climate-rasters/cru-4-03-precip-20y-mm-1999-2018.rds")
mm_pet <- read_rds("raw-data/climate-rasters/cru-4-03-pet-20y-mm-1999-2018.rds")

# read in sand data
sand <- read_rds("raw-data/sand-fraction/soilgrids-sandfrac-resampled-30-arc-sec.rds")

# read in nuts data
nuts <- read_rds("raw-data/nuts-shapefiles/nuts-lvl2-wgs84.rds")

# read in study nuts regions
study_nuts <- read_csv("raw-data/study-nuts-codes-raw.csv")

# summary functions
get_mean <- function(shp, brick) {
  brick %>%
    crop(shp) %>%
    mask(shp) %>%
    cellStats(stat = "mean", na.rm = TRUE)
}

summarise_climdata <- function(nuts_code, shp = nuts, data = list(temp = mm_temp, precip = mm_precip, pet = mm_pet)) {
  
  if (is.na(nuts_code)) return(NULL)
  
  # get shapefile
  shp <- shp %>% raster::subset(NUTS_ID == nuts_code)
  
  # get means
  means <- map_dfc(data, ~get_mean(shp, .x))
  
  return(means)
}

summarise_sand <- function(nuts_code, shp = nuts, data = sand) {
  
  if (is.na(nuts_code)) return(NA)
  
  # get shapefile
  shp <- shp %>% raster::subset(NUTS_ID == nuts_code)
  
  # get means
  means <- get_mean(shp, data)
  
  return(means)
}

# run functions
climdata <- map(study_nuts$nuts2, summarise_climdata)
sanddata <- map_dbl(study_nuts$nuts2, summarise_sand)

# take care of our odd one out (Ukraine)
ukraine <- read_rds("raw-data/nuts-shapefiles/ukraine-country-wgs84.rds")
climdata[[7]] <- map_dfc(list(temp = mm_temp, precip = mm_precip, pet = mm_pet), ~get_mean(ukraine, .x))
sanddata[7] <- get_mean(ukraine, sand)

# convert pet to monthly, not daily
climdata <- map(climdata, ~.x %>% mutate(pet = pet * 365/12))

# write out
study_nuts$nuts2[7] <- "NA_UKRAINE"
names(climdata) <- paste0(study_nuts$study_ref, "_", study_nuts$nuts2)
names(sanddata) <- paste0(study_nuts$study_ref, "_", study_nuts$nuts2)

write_rds(climdata, "spatial-data/study-climdata.rds")
write_rds(sanddata, "spatial-data/study-sanddata.rds")
