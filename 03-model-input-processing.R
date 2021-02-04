library(tidyverse)
#devtools::install_github("oj-sykes92/soilc.ipcc")
library(soilc.ipcc)

# read in collated raw data
rawdata <- read_rds("model-data/model-input-data-raw.rds")

# extend crop and manure data to n_years
n_years = 500
repno <- ceiling(n_years / min(map_int(rawdata$cropdata, nrow)))
rawdata <- rawdata %>%
  mutate(
    mandata = map2(mandata, cropdata,
                   ~if(!is_null(.x)) {
                     .x %>%
                     slice(rep(1:nrow(.y), times = repno)) %>%
                     slice(1:n_years)
                   }
                   ),
    cropdata = map(cropdata,
                    ~.x %>%
                      slice(rep(1:nrow(.x), times = repno)) %>%
                      slice(1:n_years)
                   )
  )

# crop entry translation
crop_trans <- rawdata %>%
  mutate(temp = map(cropdata, ~select(.x, crop_type))) %>%
  pull(temp) %>%
  bind_rows() %>%
  distinct() %>%
  arrange(crop_type)

crop_trans <- crop_trans %>%
  mutate(trans = c("alfalfa", "beans_and_pulses", "beans_and_pulses", "beans_and_pulses", "beans_and_pulses",
                   "grass_clover_mix", "grass", "n_fixing_forage", "maize", "n_fixing_forage",
                   "n_fixing_forage", "maize", "soybean", "barley", "barley",
                   "barley", "oats", "tubers", "generic_crops_nos", "grains_nos",
                   "barley", "barley", "oats", "oats", "grains_nos",
                   "grains_nos", "grains_nos", "winter_wheat"))

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

# add in residue removal estimates based on information from project
# utilises some functionality from the soilc.ipcc package
get_res_remove <- function(df, straw_yield) {
  df %>%
    mutate(slope = map_dbl(trans, ~soilc.ipcc::crop_agrc[[.x]]$slope),
           intercept = map_dbl(trans, ~soilc.ipcc::crop_agrc[[.x]]$intercept),
           dry = map_dbl(trans, ~soilc.ipcc::crop_bgrc[[.x]]$dry),
           agr = yield_tha * slope + intercept / dry, # calculation in fresh weight
           tha_remove = rep(straw_yield, length.out = 500),
           frac_remove = tha_remove / yield_tha,
           frac_remove = ifelse(frac_remove > 1, 1, frac_remove),
           frac_remove = ifelse(frac_remove < 0, 0, frac_remove)
    ) %>%
    select(-(slope:tha_remove))
}

# take care of individual cases with residue removal
rawdata$cropdata[[21]] <- get_res_remove(rawdata$cropdata[[21]], c(0, 4.7, 2.9, 4.1)) # scotland, no legumes
rawdata$cropdata[[22]] <- get_res_remove(rawdata$cropdata[[22]], c(0, 4.1, 4.7, 0, 4.35)) # scotland, legumes 1
rawdata$cropdata[[23]] <- get_res_remove(rawdata$cropdata[[23]], c(0, 4.1, 4.7, 0, 3.1)) # scotland, legumes 2
rawdata$cropdata[[31]] <- get_res_remove(rawdata$cropdata[[31]], c(3.3, 3.2, 3.5, 3.2, 0, 4.1)) # ireland a, no legumes
rawdata$cropdata[[32]] <- get_res_remove(rawdata$cropdata[[32]], c(3.3, 3.2, 3.5, 0, 3.5)) # ireland a, legumes
rawdata$cropdata[[33]] <- get_res_remove(rawdata$cropdata[[33]], c(3.3, 3.2, 3.3, 3.3, 3.3)) # ireland b, no legumes
rawdata$cropdata[[34]] <- get_res_remove(rawdata$cropdata[[34]], c(3.3, 0, 3.2, 3.3, 3.3)) # ireland b, legumes

# no residue removal for anybody else
rawdata <- rawdata %>%
  mutate(cropdata = map(cropdata, ~mutate(.x, frac_remove = ifelse(is.na(frac_remove), 0, frac_remove))))

# create model organic matter inputs
crop_input <- map(
  rawdata$cropdata,
  ~add_crop(crop = .x$trans,
            yield_tha = .x$yield_tha,
            frac_remove = .x$frac_remove,
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
  select(crop_fname, ref_no, is_control, sand_frac) %>%
  mutate(crop_fname = crop_fname %>% str_replace("\\.xlsx", ""),
         modeldata = map2(crop_input, man_input, build_soil_input),
         modeldata = map2(modeldata, sand_frac, ~.x %>% mutate(sand_frac = .y * 10^-2))) %>%
  select(-sand_frac)

# add climate factors
modeldata <- modeldata %>%
  mutate(
    modeldata = map2(
      modeldata,
      rawdata$climdata,
      ~mutate(.x,
              tfac = tfac(.y$temp),
              wfac = wfac(.y$precip, .y$pet)
              )
      )
    )

# add year and tillage type
modeldata <- modeldata %>%
  mutate(
    modeldata = map2(
      modeldata,
      rawdata$cropdata,
      ~mutate(.x,
              year = 1:nrow(.x),
              till_type = .y$till_type,
              .before = om_input)
      )
    )

# separate and combine control and treatment data
controldata <- modeldata %>%
  filter(is_control) %>%
  rename(control_name = crop_fname, controldata = modeldata) %>%
  select(-is_control)

treatmentdata = modeldata %>%
  filter(!is_control) %>%
  rename(treatment_name = crop_fname, treatmentdata = modeldata) %>%
  select(-is_control)

modeldata <- full_join(controldata, treatmentdata, by = "ref_no") %>%
  select(ref_no, control_name, treatment_name, controldata, treatmentdata)

# create combined model dataset
start_year <- 51
modeldata <- modeldata %>%
  mutate(combdata = map2(controldata, treatmentdata, function(c, t) {
    c <- c %>%
      slice(1:(start_year - 1)) %>%
      mutate(origin = "control", .before = year)
    t <- t %>%
      slice(start_year:nrow(t)) %>%
      mutate(origin = "treatment", .before = year)
    m = bind_rows(c, t)
    return(m)
  }))

# run model
modeldata <- modeldata %>%
  mutate(
    
    controldata =
      map(
        controldata,
        ~run_model(
          .x,
          runin_dur = 50,
          drop_prelim = FALSE,
          drop_runin = TRUE,
          calculate_climfacs = FALSE
        )
      ),
    
    treatmentdata =
      map(
        treatmentdata,
        ~run_model(
          .x,
          runin_dur = 50,
          drop_prelim = FALSE,
          drop_runin = TRUE,
          calculate_climfacs = FALSE
        )
      ),
    
    combdata =
      map(
        combdata,
        ~run_model(
          .x,
          runin_dur = 50,
          drop_prelim = FALSE,
          drop_runin = TRUE,
          calculate_climfacs = FALSE
        )
      )
  )

# pad out name strings and arrange (necessary for plotting in order)
# also modify ref_no so it's unique to control-treatment pair
modeldata <- modeldata %>%
  mutate(control_name = ifelse(str_detect(control_name, "^[:digit:]{1}_"),
                               paste0(0, control_name),
                               control_name),
         treatment_name = ifelse(str_detect(treatment_name, "^[:digit:]{1}_"),
                                 paste0(0, treatment_name),
                                 treatment_name)) %>%
  arrange(control_name, treatment_name) %>%
  group_by(control_name) %>%
  mutate(treatment = 1:n()) %>%
  ungroup() %>%
  mutate(ref_no = paste0(ref_no, "_t", treatment)) %>%
  select(-treatment)

# write out results
write_rds(modeldata, "model-data/model-output-data.rds")
