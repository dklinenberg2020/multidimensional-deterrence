# 01_ingest_viina.R -- download VIINA event_info + event_labels (all years),
# stack, join, clean. Output: data/interim/viina_events.parquet
source(here::here("R", "00_setup.R"))

dir.create(raw_dir("viina"), recursive = TRUE, showWarnings = FALSE)
base <- sprintf("https://media.githubusercontent.com/media/zhukovyuri/VIINA/%s", VIINA_COMMIT)
files <- c(sprintf("Data/event_info_latest_%d.zip", VIINA_YEARS),
           sprintf("Data/event_labels_latest_%d.zip", VIINA_YEARS),
           "README.md")
for (f in files) {
  dest <- file.path(raw_dir("viina"), basename(f))
  if (!file.exists(dest)) {
    url <- if (grepl("\\.md$", f)) sprintf("https://raw.githubusercontent.com/zhukovyuri/VIINA/%s/%s", VIINA_COMMIT, f) else file.path(base, f)
    message("downloading ", url)
    download.file(url, dest, mode = "wb", quiet = TRUE)
  }
}

read_zip <- function(z) {
  inner <- unzip(z, list = TRUE)$Name[1]
  data.table::fread(cmd = sprintf("unzip -p '%s' '%s'", z, inner),
                    encoding = "UTF-8", colClasses = list(character = c("event_id")))
}
info   <- map_dfr(sprintf("%s/event_info_latest_%d.zip",   raw_dir("viina"), VIINA_YEARS), read_zip) |> as_tibble()
labels <- map_dfr(sprintf("%s/event_labels_latest_%d.zip", raw_dir("viina"), VIINA_YEARS), read_zip) |> as_tibble()
message("info rows: ", nrow(info), "; label rows: ", nrow(labels))

# Variables with BERT out-of-sample AUC < 0.80 are dropped (VIINA's own rule).
# NB: Diagnostics/classification_report_bert.csv in the repo is an HTML page,
# not a CSV (see NOTES.md). We parse the detailed accuracy table in README.md.
rd  <- readLines(file.path(raw_dir("viina"), "README.md"), encoding = "UTF-8")
h   <- grep("^\\|variable +\\| +f1-score", rd)[1]
tb  <- rd[(h + 2):length(rd)]; tb <- tb[seq_len(which(!grepl("^\\|", tb))[1] - 1)]
auc <- read.table(text = gsub("^\\||\\|$", "", tb), sep = "|", strip.white = TRUE,
                  col.names = c("variable", "f1", "support", "accuracy", "roc_auc", "threshold")) |> as_tibble()
low_auc <- auc |> filter(roc_auc < 0.80) |> pull(variable)
readr::write_csv(auc, out("viina_auc.csv"))
message("dropping low-AUC vars: ", paste(low_auc, collapse = ", "))

drop_cols <- names(labels)[sub("_b$", "", names(labels)) %in% low_auc]
labels <- labels |> select(-any_of(drop_cols))
dup_cols <- setdiff(intersect(names(info), names(labels)), "event_id")
ev <- info |> distinct(event_id, .keep_all = TRUE) |>
  left_join(labels |> distinct(event_id, .keep_all = TRUE) |> select(-any_of(dup_cols)), by = "event_id")

# Clean: parse date/time (VIINA date = YYYYMMDD, time = HH:MM, publication time, Kyiv).
ev <- ev |>
  mutate(date  = ymd(as.character(date)),
         lat   = suppressWarnings(as.numeric(latitude)),
         lon   = suppressWarnings(as.numeric(longitude)),
         month = floor_date(date, "month")) |>
  filter(!is.na(date), date >= ymd("2022-02-24"))

n_nogeo <- sum(is.na(ev$lat) | is.na(ev$lon))
log_gap("01_ingest_viina", "events without coordinates", n_nogeo, "kept; lat/lon NA")
dir.create(interim(), showWarnings = FALSE, recursive = TRUE)
arrow::write_parquet(ev, interim("viina_events.parquet"))
message("wrote ", nrow(ev), " events; ", n_nogeo, " lack coordinates")
