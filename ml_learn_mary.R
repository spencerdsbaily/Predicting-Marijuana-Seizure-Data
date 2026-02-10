library(tidymodels)
library(readxl)
library(skimr)
library(dplyr)
library(tidyverse)
library(here)

# read data (relative paths)
esberg <- readr::read_csv(here("data", "esberg_groups.csv"))
pop    <- readr::read_csv(here("data", "pobproy_quinq1.csv"))
mary   <- readxl::read_excel(here("data", "mary_with_codes.xlsx"))

# prepare esberg
esberg <- esberg %>%
  select(group, year, CVE_ENT, CVE_MUN) %>%
  rename(state = CVE_ENT, mun = CVE_MUN) %>%
  group_by(state, mun, year) %>%
  summarise(n_groups = n_distinct(group), .groups = "drop")

# prepare pop
pop <- pop %>%
  select(CLAVE, CLAVE_ENT, SEXO, POB_TOTAL, ANO) %>%
  rename(state = CLAVE_ENT, year = ANO) %>%
  mutate(mun = CLAVE %% 1000) %>%
  group_by(state, mun, year) %>%
  summarise(pop_total = sum(POB_TOTAL), .groups = "drop")

# mary: keep state column as before
mary <- mary %>% rename(state = state...6)

# join everything
parent <- mary %>%
  left_join(pop, by = c("mun", "state", "year")) %>%
  left_join(esberg, by = c("mun", "state", "year"))

# replace NA groups with 0 and make log_pop
parent$n_groups[is.na(parent$n_groups)] <- 0
parent <- parent %>% mutate(log_pop = log(pop_total))

# create integer outcome
parent <- parent %>% mutate(kilos_int = round(kilos))

# create bins for stratified split
parent <- parent %>% mutate(kilos_bin = ntile(kilos_int, 5))

set.seed(123)
split <- initial_split(parent, strata = "kilos_bin")
train_data <- training(split) %>% select(-kilos_bin)
test_data  <- testing(split)  %>% select(-kilos_bin)

# -----------------------------
# Recipe (predictors only)
# -----------------------------
rec_nb <- recipe(kilos_int ~ n_groups + log_pop, data = train_data) %>%
  step_mutate(
    n_groups = as.numeric(n_groups),
    log_pop  = as.numeric(log_pop)
  ) %>%
  step_impute_median(all_numeric_predictors()) %>%
  step_impute_mode(all_nominal_predictors()) %>%
  step_log(n_groups, offset = 1) %>%        # log(n_groups + 1)
  step_dummy(all_nominal_predictors()) %>%
  step_zv(all_predictors())

na_table <- train_baked %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(cols = everything(), names_to = "variable", values_to = "n_missing") %>%
  arrange(desc(n_missing))

print(na_table)   # inspect this; you'll see where NAs are

# now drop rows that have NA in key modeling variables (safe and explicit)
train_baked_clean <- train_baked %>%
  drop_na(kilos_int, n_groups, log_pop, year, mun)

test_baked_clean <- test_baked %>%
  drop_na(kilos_int, n_groups, log_pop, year, mun)

# quick before/after counts
cat("Rows: train original =", nrow(train_baked), 
    " | train clean =", nrow(train_baked_clean), "\n")
cat("Rows: test original  =", nrow(test_baked), 
    " | test clean  =", nrow(test_baked_clean), "\n")

# -----------------------------
# Fit Negative Binomial with year fixed effects (on cleaned data)
# -----------------------------
# Build formula: all baked predictors except kilos_int, mun, year
predictors <- setdiff(names(train_baked_clean), c("kilos_int", "mun", "year"))
fmla <- as.formula(paste("kilos_int ~", paste(predictors, collapse = " + "), "+ factor(year)"))

# fit via MASS::glm.nb (no library(MASS) required)
nb_fit <- MASS::glm.nb(fmla, data = train_baked_clean)
print(summary(nb_fit))

# -----------------------------
# Clustered standard errors (cluster by municipality 'mun') on cleaned data
# -----------------------------
library(sandwich)
library(lmtest)

# ensure cluster vector has no NAs
stopifnot(!any(is.na(train_baked_clean$mun)))

vcov_clust <- vcovCL(nb_fit, cluster = train_baked_clean$mun)
coeftest(nb_fit, vcov = vcov_clust) -> clustered_coef_table

# optional: tidy for programmatic use (requires broom)
if (requireNamespace("broom", quietly = TRUE)) {
  robust_coef_table <- broom::tidy(clustered_coef_table)
} else {
  robust_coef_table <- as.data.frame(clustered_coef_table)
}

print(robust_coef_table)

# -----------------------------
# Predict & evaluate on cleaned test set
# -----------------------------
pred_nb <- predict(nb_fit, newdata = test_baked_clean, type = "response")
eval_df <- test_baked_clean %>% mutate(pred = pred_nb)

mae_val  <- mae_vec(eval_df$kilos_int, eval_df$pred)
rmse_val <- rmse_vec(eval_df$kilos_int, eval_df$pred)

cat("Negative binomial performance (cleaned data):\n")
cat("MAE :", round(mae_val, 3), "\n")
cat("RMSE:", round(rmse_val, 3), "\n")

# -----------------------------
# Marginal effects plot (predicted counts by n_groups)
# uses the cleaned model and uses median year from the cleaned train data
# -----------------------------
median_year <- as.numeric(stats::median(train_baked_clean$year, na.rm = TRUE))

newdata <- tibble(
  n_groups = 0:10,
  log_pop  = median(train_baked_clean$log_pop, na.rm = TRUE),
  year     = median_year
)

pred_link <- predict(nb_fit, newdata = newdata, type = "link", se.fit = TRUE)

newdata <- newdata %>%
  mutate(
    fit = exp(pred_link$fit),
    lo  = exp(pred_link$fit - 1.96 * pred_link$se.fit),
    hi  = exp(pred_link$fit + 1.96 * pred_link$se.fit)
  )

# Plot (polished)
library(ggplot2)
ggplot(newdata, aes(x = n_groups, y = fit)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#1f78b4", alpha = 0.18) +
  geom_line(colour = "#1f78b4", linewidth = 1.3, lineend = "round") +
  scale_y_log10() +
  scale_x_continuous(breaks = 0:10) +
  labs(
    x = "Number of cartel groups",
    y = "Expected kilograms seized (log scale)",
    title = "Predicted drug seizure volume by cartel presence",
    subtitle = "Negative binomial model; population held at median; year fixed effects"
  ) +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())