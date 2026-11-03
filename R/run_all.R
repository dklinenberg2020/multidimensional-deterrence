# run_all.R -- run the Phase 1 pipeline end to end from the repo root:
#   Rscript R/run_all.R
# Fresh clone: run renv::restore() first.
scripts <- c("01_ingest_viina.R", "02_size_job.R", "03_dict_hits.R", "04_build_registry.R",
             "05_russia_coverage.R", "06_pilot_classify_match.R", "07_pilot_score.R", "08_pilot_econ_damage.R")
for (s in scripts) {
  message("\n==== ", s, " ====")
  st <- system2(file.path(R.home("bin"), "Rscript"), here::here("R", s))
  if (st != 0) stop(s, " failed with status ", st)
}
