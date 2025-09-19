# lpa_pipeline.R --------------------------------------------------------------
# Usage (auto-detect vars):
#   Rscript lpa_pipeline.R data/toy_stores_clustered.csv --id NAME --kmax 6 --scale TRUE --outdir results
# Usage (explicit vars):
#   Rscript lpa_pipeline.R input.csv --id NAME \
#     --vars ENGAGEMENT_EMPLOYEE,ENGAGEMENT_MANAGER,ATTRITION_EMPLOYEE,ATTRITION_MANAGER \
#     --kmax 6 --scale TRUE --outdir results
# Usage (optional region split; silently ignored if column absent):
#   Rscript lpa_pipeline.R input.csv --id NAME --region REGION

suppressPackageStartupMessages({
  library(optparse); library(dplyr); library(tidyr); library(ggplot2)
  library(tidyLPA); library(readr); library(glue); library(purrr); library(stringr)
})

# ----------------------------- CLI -------------------------------------------
opt <- OptionParser() |>
  add_option("--id", type="character", help="ID column name (e.g., NAME)") |>
  add_option("--vars", type="character", help="Comma-separated indicator columns (auto-detect if omitted)") |>
  add_option("--kmax", type="integer",  default=6) |>
  add_option("--scale", type="character", default="TRUE") |>
  add_option("--outdir", type="character", default="results") |>
  add_option("--region", type="character", default=NULL,
             help="Region column (optional). If missing in data, it will be ignored.") |>
  parse_args(args = commandArgs(trailingOnly = TRUE), positional_arguments = 1)

infile     <- opt$args[1];  stopifnot(file.exists(infile))
id_col     <- opt$options$id;  stopifnot(!is.null(id_col) && nchar(id_col) > 0)
vars_arg   <- opt$options$vars
kmax       <- opt$options$kmax
do_scale   <- tolower(opt$options$scale) %in% c("true","t","1","yes","y")
outdirroot <- opt$options$outdir
region_col <- opt$options$region
dir.create(outdirroot, showWarnings = FALSE, recursive = TRUE)
set.seed(123)

# ----------------------------- Data ------------------------------------------
df <- readr::read_csv(infile, show_col_types = FALSE)
stopifnot(id_col %in% names(df))

# Auto-detect indicator columns if --vars omitted
detect_vars <- function(nms) {
  pat <- paste0("^ENGAGEMENT_","|^ATTRITION_","|참여","|이탈")
  cand <- setdiff(nms, id_col)
  out <- cand[str_detect(cand, pat)]
  if (length(out) < 2L) stop("Auto-detect failed. Use --vars or rename columns to ENGAGEMENT_/ATTRITION_ or include '참여'/'이탈'.")
  message(glue("Auto-detected vars: {paste(out, collapse=', ')}"))
  out
}
vars <- if (is.null(vars_arg) || !nzchar(vars_arg)) detect_vars(names(df)) else {
  v <- strsplit(vars_arg, ",")[[1]] |> trimws()
  stopifnot(all(v %in% names(df))); v
}

# ----------------------------- Core runner -----------------------------------
run_lpa_once <- function(dat, outdir) {
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

  dat <- dat |> select(all_of(c(id_col, vars)))
  # simple impute
  dat <- dat |> mutate(across(all_of(vars), ~ ifelse(is.na(.x), stats::median(.x, na.rm=TRUE), .x)))
  if (do_scale) dat <- dat |> mutate(across(all_of(vars), ~ as.numeric(scale(.x))))
  X <- dat |> select(all_of(vars))

  models_to_try <- 1:6
  fits <- map(models_to_try, ~ estimate_profiles(X, n_profiles = 1:kmax, model = .x))

  fit_tbl <- map2_dfr(fits, models_to_try, ~{ fi <- get_fit(.x); fi$model <- .y; fi }) |> relocate(model)
  readr::write_csv(fit_tbl, file.path(outdir, "fit_indices.csv"))

  best_row <- fit_tbl |> arrange(BIC, desc(Entropy)) |> slice(1)
  best_model <- best_row$model[1]; best_n <- best_row$n_profiles[1]
  message(glue(">> Selected model={best_model}, n_profiles={best_n}"))

  chosen_fit <- fits[[best_model]]
  lpa_data   <- get_data(chosen_fit, n_profiles = best_n)

  profiles <- dat |> select(all_of(id_col)) |> bind_cols(lpa_data) |> rename(Class = Class)
  readr::write_csv(profiles |> arrange(Class, .data[[id_col]]), file.path(outdir, "profiles.csv"))

  prof_summary <- profiles |> group_by(Class) |> summarise(across(all_of(vars), mean), .groups="drop") |> arrange(Class)
  readr::write_csv(prof_summary, file.path(outdir, "profile_means.csv"))

  p_elbow <- ggplot(fit_tbl, aes(x = n_profiles, y = BIC, group = factor(model))) +
    geom_line() + geom_point() + labs(title="BIC across models", x="Number of profiles", y="BIC") + theme_minimal()
  ggsave(file.path(outdir, "elbow_bic.png"), p_elbow, width=6, height=4, dpi=150)

  prof_long <- prof_summary |> pivot_longer(-Class, names_to="Variable", values_to="Mean")
  p_prof <- ggplot(prof_long, aes(Variable, Mean, group=Class, color=factor(Class))) +
    geom_line(linewidth=1.1) + geom_point(size=2.8) +
    labs(title=glue("LPA: model {best_model}, {best_n} profiles"), color="Class") +
    theme_minimal() + theme(axis.text.x = element_text(angle=45, hjust=1))
  ggsave(file.path(outdir, "profile_means.png"), p_prof, width=7, height=4.5, dpi=150)

  sink(file.path(outdir, "session_info.txt")); print(sessionInfo()); sink()
}

# ----------------------------- Region-aware flow -----------------------------
if (!is.null(region_col) && region_col %in% names(df)) {
  # Region이 있으면 지역별로 나눠서 각각 저장
  regs <- sort(unique(df[[region_col]]))
  message(glue("Region column '{region_col}' detected. Running per region: {paste(regs, collapse=', ')}"))
  index <- tibble(Region = character(), Outdir = character(), N = integer())
  for (rg in regs) {
    dat_rg <- df %>% filter(.data[[region_col]] == rg)
    outdir <- file.path(outdirroot, glue("Region={rg}"))
    run_lpa_once(dat_rg, outdir)
    index <- bind_rows(index, tibble(Region = as.character(rg), Outdir = normalizePath(outdir), N = nrow(dat_rg)))
  }
  readr::write_csv(index, file.path(outdirroot, "regions_summary.csv"))
} else {
  if (!is.null(region_col) && !(region_col %in% names(df))) {
    message(glue("Warning: region column '{region_col}' not found. Proceeding with single global run."))
  }
  run_lpa_once(df, outdirroot)
}

message(glue("Done. Outputs under: {normalizePath(outdirroot)}"))
