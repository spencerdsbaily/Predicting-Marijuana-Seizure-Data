library(tidymodels)
library(readxl)
library(skimr)
library(dplyr)
library(tidyverse)
library(here)


####### FILES NEEDED ########
#############################


esberg <- readr::read_csv(here("data", "esberg_groups.csv"))

pop <- readr::read_csv(here("data", "pobproy_quinq1.csv"))

mary <- readxl::read_excel(here("data", "mary_with_codes.xlsx"))
########## ESBERG ###########
#############################

esberg <- esberg %>%
  select(group, year, CVE_ENT, CVE_MUN) %>% 
  rename(state = CVE_ENT) %>% 
  rename(mun = CVE_MUN) %>% 
  group_by(state, mun, year) %>% 
  summarise(n_groups = n_distinct(group), .groups = "drop")

############ POP ############
#############################

pop <- pop %>% 
  select(CLAVE, CLAVE_ENT, SEXO, POB_TOTAL, ANO) %>% 
  rename(state = CLAVE_ENT) %>%
  rename(year = ANO) %>% 
  mutate(mun = CLAVE %% 1000) %>% 
  group_by(state, mun, year) %>% 
  summarise(pop_total = sum(POB_TOTAL))

############ MARY ##############
###############################
mary <- mary %>% 
  rename(state = state...6)


############# JOIN #############
################################

parent <- mary %>% 
  left_join(pop, by = c('mun', 'state', 'year')) %>% 
  left_join(esberg, by = c('mun', 'state', 'year'))


parent$n_groups[is.na(parent$n_groups)] <- 0
parent <- parent %>%
  mutate(log_pop = log(pop_total))


parent <- parent %>%
  mutate(kilos_int = round(kilos))

############## RECIPE AND WORKFLOW ############
###############################################
parent <- parent %>%
  mutate(kilos_bin = ntile(kilos_int, 5))   

split <- initial_split(parent, strata = kilos_bin)

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

# -----------------------------
# Prep & bake
# -----------------------------
rec_p <- prep(rec_nb, training = train_data, retain = TRUE)
train_baked <- bake(rec_p, new_data = train_data)
test_baked  <- bake(rec_p, new_data = test_data)


# -----------------------------
# Fit Negative Binomial
# -----------------------------
parent <- parent %>%
  mutate(kilos_int = round(kilos))
predictors <- setdiff(names(train_baked), "kilos")
fmla <- as.formula(paste("kilos ~", paste(predictors, collapse = " + ")))

nb_fit <- glm.nb(fmla, data = train_baked)
summary(nb_fit)

# -----------------------------
# Predict & evaluate
# -----------------------------
pred_nb <- predict(nb_fit, newdata = test_baked, type = "response")

eval_df <- test_baked %>% mutate(pred = pred_nb)

mae_val  <- mae_vec(eval_df$kilos, eval_df$pred)
rmse_val <- rmse_vec(eval_df$kilos, eval_df$pred)

cat("Negative binomial performance:\n")
cat("MAE :", round(mae_val, 3), "\n")
cat("RMSE:", round(rmse_val, 3), "\n")