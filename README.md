# Predicting Marijuana Seizure Volumes in Mexico

This project applies a supervised machine learning workflow in R to model
municipality–year variation in marijuana seizure volumes, using a negative
binomial regression as the core predictive model. The outcome data (marijuana
seizures by state, year, and municipality) come from a newly compiled dataset
obtained from the government of Mexico. The goal is to understand how cartel
presence (using data from Esberg 2025) relates to the quantity of drugs seized, 
controlling for population size.

The project is designed as a reproducible, end-to-end analysis suitable for
policy research, applied data science, and academic settings.


## Project Motivation

The project adopts a machine learning perspective, treating the negative
binomial model as a predictive learner trained on a subset of the data and
evaluated on held-out observations. The emphasis is on implementing a complete
modeling pipeline on a real-world dataset, including preprocessing, reproducible
train/test splits, model evaluation on held-out data, and clear interpretation
of results.

The focus is on workflow design and transparency rather than algorithmic
complexity.

---

## Data

The analysis combines three sources:
- **Cartel presence data**: number of distinct cartel groups operating in each 
municipality–year (Esberg 2025)
- **Population data**: municipality–year population totals
- **Seizure data**: kilograms of marijuana seized by authorities

Seizure quantities are recorded in kilograms and rounded to the nearest kilogram
prior to modeling. This reflects the discrete, count-like nature of the outcome
and avoids spurious precision from decimal reporting.

> **Note**: Raw data files may not be included in this repository. Scripts assume
that data are placed in a `data/` directory at the project root.

---

## Methods

- Outcome: kilograms of marijuana seized (rounded to the nearest kilogram)
- Model: negative binomial regression (to account for overdispersion)
- Predictors:
  - Number of cartel groups operating in a municipality–year (Esberg 2025)
  - Log population
- Fixed effects: year fixed effects to account for national shocks and time trends
- Inference: cluster-robust standard errors at the municipality level
- Train/test split stratified on outcome quantiles
- Evaluation metrics: MAE and RMSE on held-out test data

All preprocessing and model fitting are implemented using the `tidymodels`
ecosystem, with model estimation via `MASS::glm.nb()`.

---

## Key Result


Holding population constant and controlling for year fixed effects, each
additional cartel group operating in a municipality is associated with an
approximately **70–75% increase in expected marijuana seizure volume**
(\(e^{0.56} \approx 1.75\)).

Seizure volumes also exhibit strong time variation, with substantially lower
expected seizure levels in later years relative to the baseline year, consistent
with national-level shifts.

---

## Predicted Effects

The figure below shows model-based predictions from the negative binomial model
with year fixed effects. Expected seizure volume increases sharply with the
number of cartel groups (unsurprisingly), holding population at its median value.

![Predicted seizure volume by cartel presence](figures/marginal_effects.png)

## Repository Structure

## Reference

Esberg, Jane. 2025. “Criminal Fragmentation in Mexico.” 
*Political Science Research and Methods*. 
https://doi.org/10.1017/psrm.2025.4
