library(tidyverse)

# study reference extraction regex
ref_rgx <- "^[:alnum:]+(?=_)"

# read pre-processed climate data and enframe
climdata <- read_rds("spatial-data/study-climdata.rds") %>%
  enframe(name = "clim_fname",
          value = "climdata") %>%
  mutate(ref_no = str_extract(clim_fname, ref_rgx), .before = "climdata")

# read pre-processed sand fraction data and join to climate data
sanddata <- read_rds("spatial-data/study-sanddata.rds") %>%
  enframe(name = "clim_fname",
          value = "sand_frac")

climdata <- left_join(climdata, sanddata, by = "clim_fname")

# read in crop data
fnames <- dir("raw-data/crop")
col_types <- c("text", "numeric", "text", "numeric", "numeric", "numeric", "text")
cropdata <- map(paste0("raw-data/crop/", fnames), ~readxl::read_xlsx(.x, col_types = col_types)) %>%
  set_names(fnames)

walk(cropdata, glimpse)
map_int(cropdata, nrow)

# main simulation dataset
cropdata <- enframe(cropdata, name = "crop_fname", value = "cropdata") %>%
  mutate(ref_no = str_extract(crop_fname, "^[:alnum:]+(?=_)"),
         is_control = ifelse(str_detect(crop_fname, "\\+"), FALSE, TRUE),
         .before = "cropdata")


# read in manure data
fnames <- dir("raw-data/manure")
col_types <- c("numeric", "text", "numeric")
mandata <- map(paste0("raw-data/manure/", fnames), ~readxl::read_xlsx(.x, col_types = col_types)) %>%
  set_names(fnames)

walk(mandata, glimpse)
map_int(mandata, nrow)

# manure dataset
mandata <- enframe(mandata, name = "man_fname", value = "mandata") %>%
  mutate(crop_fname = str_replace(man_fname, "_m", ""))

# full study dataset
studydata <- full_join(cropdata, mandata, by = "crop_fname")
sum(studydata$cropdata %>% map_lgl(is_null)) # no missing rows in cropdata
studydata <- left_join(studydata, climdata, by = "ref_no") %>%
  select(crop_fname, man_fname, clim_fname, ref_no, is_control, cropdata, mandata, climdata, sand_frac)

# write out
write_rds(studydata, "model-data/model-input-data-raw.rds")
