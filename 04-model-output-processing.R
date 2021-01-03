library(tidyverse)

# read in model outputs
modeldata <- read_rds("model-data/model-output-data.rds")

# pad out ref_no strings and arrange
modeldata <- modeldata %>%
  mutate(control_name = str_pad(control_name, 7, "left", "0"),
         treatment_name = str_pad(treatment_name, 7, "left", "0")) %>%
  arrange(control_name, treatment_name)

# df with model output summary statistics
modelsummary <- modeldata %>%
  mutate(eq_c_stock_control_tha = map_dbl(controldata, ~mean(.x$total_y[450:500])),
         eq_c_stock_treatment_tha = map_dbl(treatmentdata, ~mean(.x$total_y[450:500])),
         annual_stock_change_20y_tha = map_dbl(combdata, ~mean(.x$c_stock_change[51:70])),
         annual_stock_change_50y_tha = map_dbl(combdata, ~mean(.x$c_stock_change[51:100])),
         co2_seq_20y_tha = annual_stock_change_20y_tha * 44/12,
         co2_seq_50y_tha = annual_stock_change_50y_tha * 44/12
  ) %>%
  select(-controldata, -treatmentdata, -combdata)

write_csv(modelsummary, "model-output-summaries/model-summary-stats.csv")

# trajectories plot
modeldata %>%
  select(-controldata, -treatmentdata) %>%
  unnest(combdata) %>%
  filter(year <= 200) %>%
  ggplot(aes(x = year, y = total_y)) +
  geom_line(colour = "darkred", alpha = 0.3) +
  geom_smooth(size = 1, colour = "black") +
  geom_vline(xintercept = 50, colour = "darkgrey", alpha = 0.5) +
  facet_wrap(~ control_name + treatment_name, nrow = 5, scales = "free") +
  labs(x = "Year",
       y = expression("Soil C stocks (tonnes C ha"^{-1}*")")) +
  theme_classic()

ggsave("model-output-summaries/faceted-trajectories-plot.png", height = 6, width = 8)


