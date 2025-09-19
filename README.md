Plaintext

# Latent Profile Analysis (LPA) Pipeline

A small, reproducible R pipeline for Latent Profile Analysis (LPA).
It sweeps multiple model parameterizations (1–6) and profile counts (1..K), selects the best by BIC (tie → higher Entropy), and exports assignments, profile means, and plots.

---

## Repository Structure

```yaml
.
├── R/
│   └── lpa_pipeline.R
├── data/
│   └── toy_stores_clustered.csv
└── results/          # (Generated outputs)
Example Data (data/toy_stores_clustered.csv)
Columns:

NAME — store ID

ENGAGEMENT_EMPLOYEE, ENGAGEMENT_MANAGER — engagement (≈ 1.5–4.9, one decimal)

ATTRITION_EMPLOYEE, ATTRITION_MANAGER — attrition rate (≈ 0.02–0.45, two decimals)

The toy dataset is clustered so profiles are easy to separate:

HighEng_LowAttr: high engagement, low attrition

MidEng_MidAttr: mid engagement, mid attrition

LowEng_HighAttr: low engagement, high attrition

MgrHigh_PeopleMid: manager engagement high, employee mid; lower attrition

You can replace this file with your own; keep the same schema or specify --vars.

Installation (once)
R

install.packages(c(
  "optparse","dplyr","tidyr","ggplot2",
  "tidyLPA","readr","glue","purrr","stringr"
))
Run
1) Auto-detect variables
Columns containing the prefixes ENGAGEMENT_ / ATTRITION_ (또는 한국어 키워드 참여 / 이탈)를 자동 인식합니다.

Bash

Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv \
  --id NAME --kmax 6 --scale TRUE --outdir results
2) Manually specify variables
Bash

Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv --id NAME \
  --vars ENGAGEMENT_EMPLOYEE,ENGAGEMENT_MANAGER,ATTRITION_EMPLOYEE,ATTRITION_MANAGER \
  --kmax 6 --scale TRUE --outdir results
Outputs (in results/)
fit_indices.csv — all tried solutions (model, n_profiles, BIC, Entropy, …)

profiles.csv — NAME + assigned Class

profile_means.csv — per-class means for all indicators

elbow_bic.png — BIC vs. number of profiles (lines by model)

profile_means.png — class-wise mean line plot

session_info.txt — R session info for reproducibility

Notes
--scale TRUE is recommended when indicators have different ranges.

Missing values are median-imputed by default (change in the script if needed).

Interpret classes with domain context; LPA can be sensitive to distributional assumptions and starting values.

License
MIT
