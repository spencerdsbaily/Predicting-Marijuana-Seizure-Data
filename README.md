# Predicting Marijuana Seizure Volumes in Mexico

This project analyzes municipality–year variation in marijuana seizure volumes
using a negative binomial regression model. The outcome data (marijuana seizures by state, 
year, and municipality) is a brand new dataset obtained from the government
of Mexico. The goal is to understand how cartel presence relates to the 
quantity of drugs seized, controlling for population size.

The project is designed as a reproducible, end-to-end analysis suitable for
policy research, applied data science, and academia.


## Project Motivation

This project was created to build practical experience with the `tidymodels`
machine learning framework in R. I focused on implementing a complete modeling
pipeline on a real-world dataset, emphasizing clean preprocessing, reproducible
splits, model evaluation on held-out data, and clear interpretation of results.

The emphasis is on workflow design and transparency rather than algorithmic
complexity.

---

## Data

The analysis combines three sources:
- **Cartel presence data**: number of distinct cartel groups operating in each municipality–year
- **Population data**: municipality–year population totals
- **Seizure data**: kilograms of marijuana seized by authorities

Seizure quantities are recorded in kilograms and rounded to the nearest kilogram
prior to modeling. This reflects the discrete, count-like nature of the outcome
and avoids spurious precision from decimal reporting.

> **Note**: Raw data files may not be included in this repository. Scripts assume
that data are placed in a `data/` directory at the project root.

---

## Methods

- Outcome: kilograms seized (rounded to nearest integer)
- Model: negative binomial regression (to account for overdispersion)
- Predictors:
  - Number of cartel groups
  - Log population
- Train/test split stratified on outcome quantiles
- Evaluation metrics: MAE and RMSE on held-out test data

All preprocessing and modeling steps are implemented using the `tidymodels`
ecosystem, with model estimation performed via `MASS::glm.nb()`.

---

## Key Result

Holding population constant, each additional cartel group operating in a
municipality is associated with an approximately **25–30% increase in expected
seizure volume**.

---

## Predicted Effects

![Predicted seizure volume by cartel presence](figures/marginal_effects.png)


## Repository Structure

