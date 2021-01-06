library(tidyverse)

# read in full model data
modeldata <- read_rds("model-data/model-output-data.rds")

# read in summary data
summarydata <- read_csv("model-output-summaries/model-summary-stats.csv")

# fractional difference between model input variables
modeldata <- modeldata %>%
  mutate(var_diff = map2(controldata, treatmentdata,
         function(c, t) {
           c <- c %>% select_if(is.numeric)
           t <- t %>% select_if(is.numeric)
           c <- c %>% summarise_all(mean)
           t <- t %>% summarise_all(mean)
           var_diff <- (t - c)
           return(as_tibble(var_diff))
         }),
         var_diff_frac = map2(controldata, treatmentdata,
                        function(c, t) {
                          c <- c %>% select_if(is.numeric)
                          t <- t %>% select_if(is.numeric)
                          c <- c %>% summarise_all(mean)
                          t <- t %>% summarise_all(mean)
                          var_diff_frac <- (t - c) / c
                          return(as_tibble(var_diff_frac))
                        })
         )

var_diff <- left_join(
  summarydata %>%
    mutate(is_negative = annual_stock_change_50y_tha < 0) %>%
    select(ref_no, is_negative, stock_change = annual_stock_change_50y_tha),
  modeldata %>%
    select(ref_no, var_diff) %>%
    unnest(var_diff),
  by = "ref_no"
  )

var_diff_frac <- left_join(
  summarydata %>%
    mutate(is_negative = annual_stock_change_50y_tha < 0) %>%
    select(ref_no, is_negative, stock_change = annual_stock_change_50y_tha),
  modeldata %>%
    select(ref_no, var_diff_frac) %>%
    unnest(var_diff_frac),
  by = "ref_no"
)

# correlation plot of differences
var_diff %>%
  select(c_input, n_frac, lignin_frac, tillfac:k_s, total_y) %>%
  cor(method = "spearman") %>%
  ggcorrplot::ggcorrplot(method = "circle") +
  scale_fill_viridis_c() +
  labs(title = "Spearman's correlation plot for model variables",
       subtitle = "Correlation statistic based on (treatment - control)")

# boxplot
var_diff_frac %>%
  mutate(response = ifelse(is_negative, "Loss of soil C", "Gain of soil C")) %>%
  select(ref_no, response, c_input, n_frac, lignin_frac, tillfac:k_s) %>%
  gather(-ref_no, -response, key = "var", value = "frac_diff") %>%
  filter(frac_diff <= quantile(frac_diff, 0.95),
         frac_diff >= quantile(frac_diff, 0.05)) %>%
  ggplot(aes(x = var, y = frac_diff)) +
  geom_boxplot(outlier.shape = NA) +
  geom_hline(yintercept = 0) +
  facet_wrap(~response) +
  labs(title = "") +
  coord_flip() +
  theme_classic()

# correlation plot for control rotations
cor_control <- modeldata %>%
  select(ref_no, controldata) %>%
  unnest(controldata) %>%
  select(c_input, n_frac:k_p, total_y) %>%
  cor(method = "spearman")

cor_control %>%
  ggcorrplot::ggcorrplot(method = "circle") +
  scale_fill_viridis_c()

# correlation plot for treatment rotations
cor_treatment <- modeldata %>%
  select(ref_no, treatmentdata) %>%
  unnest(treatmentdata) %>%
  select(c_input, n_frac:k_p, total_y) %>%
  cor(method = "spearman")

cor_treatment %>%
  ggcorrplot::ggcorrplot(method = "circle") +
  scale_fill_viridis_c()

# plot of correlative differences
cor_diff <- cor_treatment - cor_control

cor_diff %>%
  ggcorrplot::ggcorrplot(method = "circle") +
  scale_fill_viridis_c()
