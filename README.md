# LPA_synthetic_vars
# Latent Profile Analysis (LPA) Pipeline

A small, reproducible R pipeline for **Latent Profile Analysis (LPA)** with [`tidyLPA`](https://cran.r-project.org/package=tidyLPA).

## Repo Structure
R/lpa_pipeline.R
data/toy_stores_engagement_attrition.csv
results/  (generated)

## Example Data
- `NAME` – store ID
- `ENGAGEMENT_EMPLOYEE`, `ENGAGEMENT_MANAGER` – engagement (1–5)
- `ATTRITION_EMPLOYEE`, `ATTRITION_MANAGER` – attrition (0–1)

## Install (once)
```r
install.packages(c("optparse","dplyr","tidyr","ggplot2",
                   "tidyLPA","readr","glue","purrr","stringr"))
## run
Rscript R/lpa_pipeline.R data/toy_stores_engagement_attrition.csv \
  --id NAME --kmax 6 --scale TRUE --outdir results
