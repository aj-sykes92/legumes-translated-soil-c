library(tidyverse)
library(soilc.ipcc)

# read in collated raw data
rawdata <- read_rds("model-data/model-input-data-raw.rds")

# extend crop data to 100 years
repno <- ceiling(100 / min(map_int(rawdata$cropdata, nrow)))
rawdata <- rawdata %>%
  mutate(
    cropdata = map(cropdata,
                    ~.x %>%
                      slice(rep(1:nrow(.x), times = repno)) %>%
                      slice(1:100)
                   )
  )

# crop entry translation
crop_trans <- rawdata %>%
  mutate(temp = map(cropdata, ~select(.x, crop_type))) %>%
  pull(temp) %>%
  bind_rows() %>%
  distinct() %>%
  arrange(crop_type)

crop_trans = crop_trans %>%
  mutate(trans = c("alfalfa", "beans_and_pulses", "beans_and_pulses", "n_fixing_forage", "n_fixing_forage",
                   "grass_clover_mix", "grass", "n_fixing_forage", "maize", "n_fixing_forage",
                   "n_fixing_forage", "maize", "soybean", "barley", "barley",
                   "barley", "oats", "tubers", "non_n_fixing_forage", "rye",
                   "barley", "barley", "oats", "oats", "non_n_fixing_forage",
                   "non_n_fixing_forage", "rye", "winter_wheat"))

# manure entry translation
man_trans <- rawdata %>%
  drop_na(man_fname) %>%
  mutate(temp = map(mandata, ~select(.x, man_type))) %>%
  pull(temp) %>%
  bind_rows() %>%
  distinct() %>%
  arrange(man_type)

man_trans = man_trans %>%
  mutate(trans = c("dairy_cattle", "dairy_cattle", "swine"))

# add translations
rawdata <- rawdata %>%
  mutate(
    cropdata = map(cropdata, ~left_join(.x, crop_trans, by = "crop_type")),
    mandata = map_if(mandata, ~!is_null(.x), ~left_join(.x, man_trans, by = "man_type"))
    )

# create model organic matter inputs
crop_input <- map(
  rawdata$cropdata,
  ~add_crop(crop = .x$trans,
            yield_tha = .x$yield_tha,
            frac_remove = 0.6,
            frac_renew = 1)
)

man_input <- map(
  rawdata$mandata,
  ~add_manure(livestock_type = .x$trans,
              n_rate = .x$man_nrate)
)

# build model data
# warnings are where manure data is null
modeldata <- rawdata %>%
  select(ref_no, is_control, sand_frac) %>%
  mutate(modeldata = map2(crop_input, man_input, build_soil_input),
         modeldata = map2(modeldata, sand_frac, ~.x %>% mutate(sand_frac = .y))) %>%
  select(-sand_frac)

# add climate data
# uncomment and incorporate if/when climdata processing is removed from run_model function
#map_dbl(rawdata$climdata, ~tfac(.x$temp))
#map_dbl(rawdata$climdata, ~wfac(.x$precip, .x$pet))

modeldata <- modeldata %>%
  mutate(modeldata = map2(
    modeldata,
    rawdata$climdata,
    function(x, y) {
      x %>%
        mutate(climdata = map(1:nrow(x), ~y))
    })
    )

# add year and tillage type
modeldata <- modeldata %>%
  mutate(modeldata = map2(modeldata, rawdata$cropdata,
                          ~mutate(.x,
                                  year = 1:nrow(.x),
                                  till_type = .y$till_type,
                                  .before = om_input))
         )

# run model
modeldata <- modeldata %>%
  mutate(modeloutput = map(modeldata, run_model))
