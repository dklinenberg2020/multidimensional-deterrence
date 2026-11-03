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

# ---- Severity coder, shared by 08 and 09: 0-4 scale (IntelliNews definitions), coded from a
# lower-cased headline; callers take the max over a strike's reports.
# 4 halted/destroyed · 3 major damage · 2 damaged/hit · 1 fire or minor · 0 attacked/claimed only
sev_rx <- list(
  `4` = "зруйнован|знищен|разрушен|уничтожен|повністю зупин|полностью останов|зупинила роботу|остановила работу|вивели з ладу|выведен\\w* из строя|затону|затонул|потоплен|потопил|потопи",
  `3` = "серйозн\\w* пошкодж|значн\\w* пошкодж|серьезн\\w* поврежд|значительн\\w* поврежд|критичн\\w* пошкодж|втрат\\w* \\d+% генерац",
  `2` = "пошкодж|поврежд|влучан|влучил|влучи|попал|уразил|уражено|підбит|подбит|попадан|прил[іе]т|уражен|поражен|вибуховою хвилею",
  `1` = "пожеж|пожар|загоран|загорі|загорел|уламк|обломк",
  `0` = "атак|обстр|удар")
sev_of <- function(t) {
  for (k in names(sev_rx)) if (!is.na(t) && stri_detect_regex(t, sev_rx[[k]])) return(as.integer(k))
  NA_integer_
}
sev_w <- c(`0` = 0, `1` = 0.1, `2` = 0.3, `3` = 0.6, `4` = 1)   # PI-approved weights

