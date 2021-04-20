# purpose of script is to output intermediate-stage data for human readability/guiding analysis
# do not run independently --- sourced within 03-model-input-processing.R

# prepare human readable model inputs (not used in model)
crop_model_input <- map(crop_input, build_soil_input)
man_model_input <- map(man_input, build_soil_input)

crop_model_input <- map(crop_model_input, function(x) {
  colnames(x) <- paste0("crop_", colnames(x))
  return(x)
})

man_model_input <- map(man_model_input, function(x) {
  colnames(x) <- paste0("man_", colnames(x))
  return(x)
})

man_model_input <- map(man_model_input, function(x) {
  if(nrow(x) == 0) {
    x <- add_row(x,
                 man_om_input = rep(0, 500),
                 man_c_input = rep(0, 500),
                 man_n_input = rep(0, 500),
                 man_lignin_input = rep(0, 500),
                 man_n_frac = rep(0, 500),
                 man_lignin_frac = rep(0, 500))
  }
  return(x)
})

# assemble list of flat file model inputs + raw input data
intermediate_output <- pmap(
  list(
    rawdata$cropdata,
    crop_model_input,
    man_model_input
  ),
  function(a, b, c) {
    bind_cols(
      select(a, crop_type, yield_tha, till_type, ipcc_translation_crop = trans),
      b,
      c
    ) %>%
      slice(1:50)
  }
) %>%
  map2(rawdata$mandata, function(x, y) {
    if(!is_null(y)) {
      x <- x %>%
        mutate(man_type = y$man_type[1:50],
               man_nrate = y$man_nrate[1:50],
               ipcc_translation_manure = y$trans[1:50],
               .before = crop_om_input)
    } else {
      x <- x %>%
        mutate(man_type = rep("None", 50),
               man_nrate = rep(0, 50),
               ipcc_translation_manure = rep("none", 50),
               .before = crop_om_input)
    }
    return(x)
  })

# write out
fnames <- paste0("intermediate-data/", rawdata$crop_fname %>% str_replace_all(".xlsx", ".csv"))
walk2(intermediate_output, fnames, ~write_csv(.x, .y))

# clean up
rm(fnames, intermediate_output, crop_model_input, man_model_input)
      