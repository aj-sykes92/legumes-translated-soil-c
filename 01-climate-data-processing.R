
library(raster)
library(rgdal)
library(tidyverse)

# read in cru climate data
mm_temp <- read_rds("raw-data/climate-rasters/cru-4-03-temp-20y-mm-1999-2018.rds")
mm_precip <- read_rds("raw-data/climate-rasters/cru-4-03-precip-20y-mm-1999-2018.rds")
mm_pet <- read_rds("raw-data/climate-rasters/cru-4-03-pet-20y-mm-1999-2018.rds")

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

summarise_nuts <- function(nuts_code, shp = nuts, data = list(temp = mm_temp, precip = mm_precip, pet = mm_pet)) {
  
  if (is.na(nuts_code)) return(NULL)
  
  # get shapefile
  shp <- shp %>% subset(NUTS_ID == nuts_code)
  
  # get means
  means <- map_dfc(data, ~get_mean(shp, .x))
  
  return(means)
}

# run function
climdata <- map(study_nuts$nuts2, summarise_nuts)

# take care of our odd one out (Ukraine)
ukraine <- read_rds("raw-data/nuts-shapefiles/ukraine-country-wgs84.rds")
climdata[[7]] <- map_dfc(list(temp = mm_temp, precip = mm_precip, pet = mm_pet), ~get_mean(ukraine, .x))

# write out
study_nuts$nuts2[7] <- "NA_UKRAINE"
names(climdata) <- paste0(study_nuts$study_ref, "_", study_nuts$nuts2)
write_rds(climdata, "climate-data/study-climdata.rds")
