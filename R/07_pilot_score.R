# 07_pilot_score.R -- score the March 2024 pilot.
#  Recall: against a reference list of massive Russian attacks on energy. The intended
#  reference is the energy-map.info (DiXi Group) "massive strikes" file, which needs an
#  account to download; until it is supplied (data/raw/energymap/<date>/), we score against
#  a provisional hand-compiled list with a source URL per row
#  (data/raw/manual_reference/<date>/march2024_energy_attacks.csv).
#  Precision: hand-check labels for the 50-strike sample
#  (data/raw/manual_labels/<date>/pilot_precision_labels.csv).
# Outputs: output/pilot_recall_attack.csv, output/pilot_recall_facility.csv,
#          output/pilot_scores.csv
source(here::here("R", "00_setup.R"))
strikes <- arrow::read_parquet(interim("pilot_2024_03_strikes.parquet"))
fac     <- readr::read_csv(here("registry", "facilities.csv"), show_col_types = FALSE)

em_dir  <- raw_dir("energymap")
ref_src <- if (dir.exists(em_dir) && length(list.files(em_dir, "\\.(csv|xlsx)$"))) "energymap" else "manual_reference"
if (ref_src == "energymap") stop("energy-map file present: add its parser here (column names unknown until downloaded)")
ref <- readr::read_csv(file.path(raw_dir("manual_reference"), "march2024_energy_attacks.csv"), show_col_types = FALSE) |>
  mutate(date = ymd(date))

ru <- strikes |> filter(attacker == "RU")
gen_like <- c("gen", "transmission", "storage_export")

# ---- attack-level recall: >= 1 RU energy strike on the attack date or the day after
att <- ref |> filter(massive_flag %in% c("yes", "TRUE", TRUE)) |> distinct(date) |>
  mutate(n_ru_energy_strikes_d0_d1 = map_int(date, ~ sum(ru$target_class %in% gen_like & ru$date >= .x & ru$date <= .x + 1)),
         recalled = n_ru_energy_strikes_d0_d1 > 0)
readr::write_csv(att, out("pilot_recall_attack.csv"))

# ---- facility-level recall: named facility hit -> a strike matched to that registry
# facility (or, when the facility is not in the registry, an energy strike in the same
# oblast) within [date, date+1]
reg_lookup <- ref |> filter(!is.na(facility_id) & facility_id != "")
facrec <- ref |> filter(!is.na(facility_en) & facility_en != "") |>
  mutate(in_registry = !is.na(facility_id) & facility_id != "",
         hit_facility = pmap_lgl(list(date, facility_id, in_registry), function(d, f, inr) {
           if (!inr) return(NA)
           any(str_detect(coalesce(ru$facility_id, ""), fixed(f)) & ru$date >= d & ru$date <= d + 1) }),
         hit_oblast = pmap_lgl(list(date, oblast_ne), function(d, o) {
           any(ru$target_class %in% gen_like & coalesce(ru$oblast, "") == o & ru$date >= d & ru$date <= d + 1) }))
readr::write_csv(facrec, out("pilot_recall_facility.csv"))

# ---- precision
lab <- readr::read_csv(file.path(raw_dir("manual_labels"), "pilot_precision_labels.csv"), show_col_types = FALSE)
stopifnot(all(lab$strike_id %in% strikes$strike_id))   # labels must match the current sample
prec_strict  <- mean(lab$is_econ_strike == "TRUE")
prec_lenient <- mean(lab$is_econ_strike %in% c("TRUE", "AMBIG"))
att_ok <- with(lab |> filter(is_econ_strike == "TRUE"), mean(attacker_check == "ok"))
fm <- lab |> filter(!is.na(facility_match_check), !str_detect(facility_match_check, "^n/a"))

scores <- tribble(~metric, ~value, ~n, ~note,
  "recall_attack_level", mean(att$recalled), nrow(att), paste("reference:", ref_src),
  "recall_facility_exact", mean(facrec$hit_facility, na.rm = TRUE), sum(!is.na(facrec$hit_facility)), "named facility in registry, matched facility_id, d..d+1",
  "recall_facility_oblast", mean(facrec$hit_oblast), nrow(facrec), "any RU energy strike in facility's oblast, d..d+1",
  "precision_strict", prec_strict, nrow(lab), "AMBIG counted as false; labels by LLM, not human-verified",
  "precision_lenient", prec_lenient, nrow(lab), "AMBIG counted as true",
  "attacker_accuracy_among_true", att_ok, sum(lab$is_econ_strike == "TRUE"), "",
  "facility_match_correct", mean(str_detect(fm$facility_match_check, "^(right|partly)")), nrow(fm), "share of sampled facility matches judged right/partly right")
readr::write_csv(scores, out("pilot_scores.csv"))
print(scores); print(att); print(facrec |> select(date, facility_en, facility_id, oblast_ne, hit_facility, hit_oblast), n = 60)
