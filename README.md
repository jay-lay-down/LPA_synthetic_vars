# Latent Profile Analysis (LPA) Pipeline

A reproducible R pipeline for Latent Profile Analysis (LPA) using `tidyLPA`.  
It sweeps model parameterizations (1–6) and profile counts (1..K), selects the best by **BIC** (ties → higher **Entropy**), and saves class assignments, class-wise means, and plots.  
**Region column is optional**: if you pass `--region` but the column is absent, the script proceeds with a single global run (no failure).

---

## Repository Structure
- `R/lpa_pipeline.R` — the analysis pipeline (drop-in; no edits required)
- `data/toy_stores_clustered.csv` — example dataset (clustered for clear profiles)
- `results/` — output folder (created automatically)

---

## Example Data (`data/toy_stores_clustered.csv`)

Columns:
- `NAME` — store ID  
- `ENGAGEMENT_EMPLOYEE`, `ENGAGEMENT_MANAGER` — engagement (≈ 1.5–4.9, one decimal)  
- `ATTRITION_EMPLOYEE`, `ATTRITION_MANAGER` — attrition rate (≈ 0.02–0.45, two decimals)

Notes:
- The dataset is **clustered** so that LPA can recover 3–4 distinct profiles easily.  
- You can replace this file with your own; keep the same schema or specify `--vars`.

---

## Installation (once)

```r
install.packages(c(
  "optparse","dplyr","tidyr","ggplot2",
  "tidyLPA","readr","glue","purrr","stringr"
))


# How to Run
## 1) Auto-detect variables (recommended)
- ** Columns containing prefixes ENGAGEMENT_ / ATTRITION_ (or Korean keywords 참여 / 이탈) are detected automatically.

Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv \
  --id NAME --kmax 6 --scale TRUE --outdir results

## 2) Manually specify variables
Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv --id NAME \
  --vars ENGAGEMENT_EMPLOYEE,ENGAGEMENT_MANAGER,ATTRITION_EMPLOYEE,ATTRITION_MANAGER \
  --kmax 6 --scale TRUE --outdir results

## 3) Optional region split
If your data includes a region column (e.g., Region), you may ask for per-region runs.
If the column is missing, the script silently ignores the option and runs once globally.
Rscript R/lpa_pipeline.R data/your.csv --id NAME --region Region --kmax 6 --scale TRUE --outdir results

Outputs will be organized as:
results/
  Region=<value>/
    fit_indices.csv
    profiles.csv
    profile_means.csv
    elbow_bic.png
    profile_means.png
    session_info.txt
regions_summary.csv        # (only when --region is used and found)


Outputs (in results/)

fit_indices.csv — all tried solutions (model, n_profiles, BIC, Entropy, …)

profiles.csv — NAME + assigned Class

profile_means.csv — per-class means for all indicators

elbow_bic.png — BIC vs. number of profiles (lines by model)

profile_means.png — class-wise mean line plot

session_info.txt — R session info for reproducibility

Analysis Flow (what the script does)

Load & validate: read CSV; ensure --id exists.

Variable selection: use --vars if given; otherwise auto-detect by name patterns (ENGAGEMENT_, ATTRITION_, or 참여, 이탈).

Missing values: median imputation (simple, editable in the script).

Scaling: standardize indicators when --scale TRUE (recommended if ranges differ).

Grid search: fit LPA for models 1–6 and profiles 1..kmax.

Model selection: choose min BIC; break ties by higher Entropy.

Class assignment: export IDs with Class and class-wise means; save plots.

(Optional) Region: if --region exists in the data, repeat steps 1–7 per region.

Interpretation Guide (brief)

Profiles summarize typical patterns across continuous indicators (e.g., high engagement / low attrition vs. the opposite).

K selection: too small (under-extracted); too large (over-fragmented). Use BIC + Entropy and check substantive sense.

Class sizes: extremely small classes (< 5%) require caution.

Posterior probabilities: if many cases have low max posterior, boundaries are fuzzy → consider fewer K or different indicators.

Actionable labels: rename classes to narrative labels (e.g., HighEng_LowAttr, LowEng_HighAttr) and tie to interventions.

Troubleshooting

“Auto-detect failed”
→ Rename columns to include ENGAGEMENT_ / ATTRITION_ (or 참여 / 이탈), or pass --vars explicitly.

“ID column not found”
→ Ensure --id exactly matches a column name (case-sensitive).

Package not found
→ Re-run the install block above, or install missing packages individually.

Weird plots / flat profiles
→ Confirm scaling (--scale TRUE), check for constant/near-constant indicators, remove extreme outliers, or try different kmax.

Reproducibility

Random seed is fixed (set.seed(123)).

session_info.txt is written to capture package versions.

The script is file-based; no hidden state.

License

MIT (optional). Add a LICENSE file if you plan to share.
