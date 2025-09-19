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

