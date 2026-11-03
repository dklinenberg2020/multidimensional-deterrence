# 00_setup.R -- shared setup sourced by every numbered script.
# Run all scripts from the repo root: Rscript R/01_ingest_viina.R
if (!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(here, tidyverse, arrow, data.table, stringi, lubridate, sf)

# Pin the VIINA snapshot so the pipeline is reproducible.
VIINA_COMMIT   <- "a1ad3633e9239e9fef98c08009436ff99fb51bbe"  # main @ 2026-10-27
VIINA_YEARS    <- 2022:2026
RAW_DATE       <- Sys.getenv("RAW_DATE", "2026-11-03")       # pull date folder
raw_dir  <- function(src) here("data", "raw", src, RAW_DATE)
interim  <- function(...) here("data", "interim", ...)
out      <- function(...) here("output", ...)

# Gap log: every NA we create on purpose gets a row here. On its first call in a
# session a script drops its own rows from earlier runs, so the log reflects the latest run.
.gap_cleared <- new.env()
log_gap <- function(script, what, n, note = "") {
  f <- here("output", "gap_log.csv")
  old <- if (file.exists(f)) readr::read_csv(f, show_col_types = FALSE, col_types = "cccdc") else NULL
  if (!is.null(old) && is.null(.gap_cleared[[script]])) old <- old |> filter(.data$script != !!script)
  .gap_cleared[[script]] <- TRUE
  row <- tibble(ts = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), script, what, n = as.numeric(n), note)
  readr::write_csv(bind_rows(old, row), f, na = "")
}
