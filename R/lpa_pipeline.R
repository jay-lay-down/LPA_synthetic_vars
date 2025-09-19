# lpa_pipeline.R --------------------------------------------------------------
# Usage (vars 자동탐지):
#   Rscript lpa_pipeline.R toy_stores_engagement_attrition.csv --id NAME --kmax 6 --scale TRUE --outdir results
#
# Usage (명시 지정):
#   Rscript lpa_pipeline.R input.csv --id NAME \
#     --vars ENGAGEMENT_EMPLOYEE,ENGAGEMENT_MANAGER,ATTRITION_EMPLOYEE,ATTRITION_MANAGER \
#     --kmax 6 --scale TRUE --outdir results

suppressPackageStartupMessages({
  library(optparse); library(dplyr); library(tidyr); library(ggplot2)
  library(tidyLPA); library(readr); library(glue); library(purrr); library(stringr)
})

opt <- OptionParser() |>
  add_option("--id", type="character", help="ID column name (e.g., NAME)", metavar="CHAR") |>
  add_option("--vars", type="character", help="Comma-separated indicator columns (auto-detect if omitted)") |>
  add_option("--kmax", type="integer", default=6) |>
  add_option("--scale", type="character", default="TRUE") |>
  add_option("--outdir", type="character", default="results") |>
  parse_args(args = commandArgs(trailingOnly = TRUE), positional_arguments = 1)

infile <- opt$args[1]
stopifnot(file.exists(infile))
id_col <- opt$options$id
stopifnot(!is.null(id_col) && nchar(id_col) > 0)

# parse vars (may be NULL -> auto-detect)
vars_arg <- opt$options$vars
kmax   <- opt$options$kmax
do_scale <- tolower(opt$options$scale) %in% c("true","t","1","yes","y")
outdir <- opt$options$outdir
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
set.seed(123)

# ---- Load & prepare ---------------------------------------------------------
df <- readr::read_csv(infile, show_col_types = FALSE)
stopifnot(id_col %in% names(df))

# Auto-detect indicator columns if --vars omitted:
if (is.null(vars_arg) || !nzchar(vars_arg)) {
  # 패턴: 영문(ENGAGEMENT_/ATTRITION_) + 한국어(참여/이탈) 키워드
  pat <- paste0(
    "^ENGAGEMENT_", "|^ATTRITION_",
    "|참여",        "|이탈"
  )
  cand <- setdiff(names(df), id_col)
  vars <- cand[ str_detect(cand, pat) ]
  if (length(vars) < 2L) {
    stop("Auto-detect failed: '--vars'를 명시하거나, 컬럼명을 ENGAGEMENT_/ATTRITION_ 또는 '참여/이탈' 키워드로 맞춰주세요.")
  }
  message(glue("Auto-detected vars: {paste(vars, collapse=', ')}"))
} else {
  vars <- strsplit(vars_arg, ",")[[1]] |> trimws()
  stopifnot(all(vars %in% names(df)))
}

dat <- df |> dplyr::select(dplyr::all_of(c(id_col, vars)))

# 간단 결측 처리(중앙값 대치; 필요 시 변경)
dat <- dat |> dplyr::mutate(across(all_of(vars), ~ ifelse(is.na(.x), stats::median(.x, na.rm=TRUE), .x)))

# 스케일링(권장)
if (do_scale) {
  dat <- dat |> dplyr::mutate(across(all_of(vars), ~ as.numeric(scale(.x))))
}

X <- dat |> dplyr::select(dplyr::all_of(vars))

# ---- Fit many models (n=1..kmax, model=1..6) -------------------------------
# tidyLPA model parameterizations:
# 1: equal variances, zero covariances
# 2: varying variances, zero covariances
# 3: equal variances, equal covariances
# 4: varying variances, equal covariances
# 5: equal variances, varying covariances
# 6: varying variances, varying covariances
models_to_try <- 1:6

fits <- purrr::map(models_to_try, function(m) {
  estimate_profiles(X, n_profiles = 1:kmax, model = m)
})

# ---- Collect fit indices ----------------------------------------------------
fit_tbl <- purrr::map2_dfr(fits, models_to_try, ~{
  fi <- get_fit(.x)
  fi$model <- .y
  fi
}) |> dplyr::relocate(model)

readr::write_csv(fit_tbl, file.path(outdir, "fit_indices.csv"))

# ---- Choose best solution: min BIC, tie-break by max Entropy ----------------
best_row <- fit_tbl |>
  dplyr::arrange(BIC, dplyr::desc(Entropy)) |>
  dplyr::slice(1)

best_model      <- best_row$model
best_n_profiles <- best_row$n_profiles[1]

message(glue(">> Selected model={best_model}, n_profiles={best_n_profiles} (by BIC, tie:Entropy)"))

# ---- Extract assignments/data for chosen solution ---------------------------
chosen_fit <- fits[[best_model]]
lpa_data   <- get_data(chosen_fit, n_profiles = best_n_profiles)

profiles <- dat |> dplyr::select(dplyr::all_of(id_col)) |>
  dplyr::bind_cols(lpa_data) |>
  dplyr::rename(Class = Class)

readr::write_csv(profiles |> dplyr::arrange(Class, .data[[id_col]]),
                 file.path(outdir, "profiles.csv"))

# ---- Profile means table ----------------------------------------------------
prof_summary <- profiles |>
  dplyr::group_by(Class) |>
  dplyr::summarise(across(all_of(vars), mean), .groups="drop") |>
  dplyr::arrange(Class)
readr::write_csv(prof_summary, file.path(outdir, "profile_means.csv"))

# ---- Plots ------------------------------------------------------------------
# 1) Fit indices elbow
p_elbow <- ggplot2::ggplot(fit_tbl, aes(x = n_profiles, y = BIC, group = factor(model))) +
  ggplot2::geom_line() + ggplot2::geom_point() +
  ggplot2::labs(title = "BIC across models", x = "Number of profiles", y = "BIC") +
  ggplot2::theme_minimal()
ggplot2::ggsave(file.path(outdir, "elbow_bic.png"), p_elbow, width = 6, height = 4, dpi = 150)

# 2) Profile mean lines
prof_long <- prof_summary |>
  tidyr::pivot_longer(-Class, names_to = "Variable", values_to = "Mean")

p_prof <- ggplot2::ggplot(prof_long, aes(Variable, Mean, group = Class, color = factor(Class))) +
  ggplot2::geom_line(linewidth = 1.1) + ggplot2::geom_point(size = 2.8) +
  ggplot2::labs(title = glue("LPA: model {best_model}, {best_n_profiles} profiles"),
       color = "Class") +
  ggplot2::theme_minimal() +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
ggplot2::ggsave(file.path(outdir, "profile_means.png"), p_prof, width = 7, height = 4.5, dpi = 150)

# ---- Session info -----------------------------------------------------------
sink(file.path(outdir, "session_info.txt"))
print(sessionInfo())
sink()

message(glue("Done. Outputs saved under: {normalizePath(outdir)}"))
