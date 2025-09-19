# Latent Profile Analysis (LPA) Pipeline

A reproducible R pipeline for Latent Profile Analysis (LPA) using `tidyLPA`.  
It sweeps model parameterizations (1–6) × profile counts (1..K), selects the best by **BIC** (tie → higher **Entropy**), and saves:
class assignments, class-wise means, and plots.  
Optional region-aware runs are supported; if `--region` is provided but the column is missing, the option is ignored (single global run).

---

## Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Data Schema](#data-schema)
- [How to Run](#how-to-run)
- [Outputs](#outputs)
- [Analysis Flow](#analysis-flow)
- [Interpretation Guide](#interpretation-guide)
- [CLI Options](#cli-options)
- [Troubleshooting](#troubleshooting)
- [Reproducibility](#reproducibility)
- [License](#license)

---

## Prerequisites

- R ≥ 4.1
- Packages:

```r
install.packages(c(
  "optparse","dplyr","tidyr","ggplot2",
  "tidyLPA","readr","glue","purrr","stringr"
))
```

## Quick Start

Assuming the repository layout:

```bash
R/lpa_pipeline.R
data/toy_stores_clustered.csv
results/              # generated
```

Run with auto-detected variables:

```bash
Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv \
  --id NAME --kmax 6 --scale TRUE --outdir results
```

## Data Schema

The example dataset is clustered for clear profiles. Replace with your own if needed.

```sql
Required:
- ID column: NAME (use --id to match your file)

Indicators (either auto-detected or passed via --vars):
- ENGAGEMENT_EMPLOYEE   (≈ 1.5–4.9, one decimal)
- ENGAGEMENT_MANAGER    (≈ 1.5–4.9, one decimal)
- ATTRITION_EMPLOYEE    (≈ 0.02–0.45, two decimals)
- ATTRITION_MANAGER     (≈ 0.02–0.45, two decimals)

Optional:
- Region column (e.g., Region) for per-region runs
```

**Auto-detection rules** (when `--vars` is omitted):

Columns containing prefixes `ENGAGEMENT_` / `ATTRITION_`, or Korean keywords `참여` / `이탈`.

## How to Run

### 1) Auto-detect variables (recommended)

```bash
Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv \
  --id NAME --kmax 6 --scale TRUE --outdir results
```

### 2) Manually specify variables

```bash
Rscript R/lpa_pipeline.R data/toy_stores_clustered.csv --id NAME \
  --vars ENGAGEMENT_EMPLOYEE,ENGAGEMENT_MANAGER,ATTRITION_EMPLOYEE,ATTRITION_MANAGER \
  --kmax 6 --scale TRUE --outdir results
```

### 3) Optional region split

If your data includes a region column (e.g., `Region`), run per region.  
If the column is missing, the script silently falls back to a single global run.

```bash
Rscript R/lpa_pipeline.R data/your.csv \
  --id NAME --region Region --kmax 6 --scale TRUE --outdir results
```

Output organization when region is found:

```bash
results/
  Region=<value>/
    fit_indices.csv
    profiles.csv
    profile_means.csv
    elbow_bic.png
    profile_means.png
    session_info.txt
regions_summary.csv   # present only if region runs were executed
```

## Outputs

```bash
results/
  fit_indices.csv     # all tried solutions: model, n_profiles, BIC, Entropy, ...
  profiles.csv        # ID + assigned Class
  profile_means.csv   # class-wise means (indicators)
  elbow_bic.png       # BIC vs. number of profiles (lines by model)
  profile_means.png   # class-wise mean line plot
  session_info.txt    # R session info for reproducibility
```

## Analysis Flow

(what the script does)

1. Load CSV and validate `--id`.
2. Select indicators: `--vars` if provided, otherwise auto-detect via name patterns.
3. Handle missing values by median imputation (simple default).
4. Scale indicators when `--scale TRUE` (recommended if ranges differ).
5. Fit LPA across models 1–6 and profiles 1..kmax.
6. Choose solution by min BIC; tie-break by max Entropy.
7. Export class assignments, class-wise means, and plots.
8. If `--region` exists in the data, repeat steps 1–7 per region and write an index.

## Interpretation Guide

(brief)

- **Profiles** summarize typical patterns (e.g., high engagement / low attrition vs. the opposite).
- **K selection**: small K can merge distinct groups (under-extraction); large K can over-fragment. Use BIC + Entropy + domain sense.
- **Class sizes**: very small classes (< 5%) need caution in decision-making.
- **Posterior clarity**: many low max posteriors = fuzzy boundaries → try fewer K or revise indicators.
- **Actionable labels**: rename classes to narrative labels (e.g., `HighEng_LowAttr`, `LowEng_HighAttr`) and tie to interventions.

## CLI Options

(summary)

```
--id <CHAR>                 # required; ID column name (e.g., NAME)
--vars <CSV>                # optional; comma-separated indicators. If omitted, auto-detect
--kmax <INT>                # default: 6; maximum number of profiles to try
--scale <TRUE|FALSE>        # default: TRUE; standardize indicators
--outdir <PATH>             # default: results; output directory
--region <CHAR>             # optional; region column. If missing in data, ignored
```

**Examples:**

```bash
# Korean-named columns example
Rscript R/lpa_pipeline.R data/your.csv --id 매장명 \
  --vars 직원참여도,관리자참여도,직원이탈률,관리자이탈률 \
  --kmax 5 --scale TRUE --outdir results_kr
```

## Troubleshooting

- **Auto-detect failed**  
  → Ensure indicator names contain `ENGAGEMENT_` / `ATTRITION_` (or `참여` / `이탈`), or pass `--vars`.

- **ID column not found**  
  → `--id` must match a column name exactly (case-sensitive).

- **Packages missing**  
  → Re-run the install block or install individually.

- **Flat/odd plots**  
  → Use `--scale TRUE`, check constant indicators or extreme outliers, try a different kmax.

## Reproducibility

- Random seed fixed: `set.seed(123)`.
- `session_info.txt` records package versions.
- File-based pipeline; no hidden state.

## License

MIT (optional). Add a LICENSE file if you plan to share.
