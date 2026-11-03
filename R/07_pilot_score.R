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

# ---- facility-level recall: a named registry facility hit in a massive attack ->
# a RU strike matched to that facility_id within [date, date+1].
mas <- ref |> filter(massive_flag == "yes")
facrec <- mas |> filter(!is.na(facility_id)) |>
  mutate(hit_facility = map2_lgl(date, facility_id, function(d, f)
           any(str_detect(coalesce(ru$facility_id, ""), fixed(f)) & ru$date >= d & ru$date <= d + 1)))
readr::write_csv(facrec, out("pilot_recall_facility.csv"))
# ---- oblast-level recall: each (attack date, oblast) with confirmed energy damage ->
# any RU energy strike (gen / transmission / storage_export) in that oblast within [date, date+1].
oblrec <- mas |> filter(!is.na(oblast_ne), certainty == "confirmed") |> distinct(date, oblast_ne) |>
  mutate(hit_oblast = map2_lgl(date, oblast_ne, function(d, o)
           any(ru$target_class %in% gen_like & coalesce(ru$oblast, "") == o & ru$date >= d & ru$date <= d + 1)))
readr::write_csv(oblrec, out("pilot_recall_oblast.csv"))

# ---- precision
lab <- readr::read_csv(file.path(raw_dir("manual_labels"), "pilot_precision_labels.csv"), show_col_types = FALSE)
stopifnot(all(lab$strike_id %in% strikes$strike_id))   # labels must match the current sample
prec_strict  <- mean(lab$is_econ_strike == "TRUE")
prec_lenient <- mean(lab$is_econ_strike %in% c("TRUE", "AMBIG"))
att_ok <- with(lab |> filter(is_econ_strike == "TRUE"), mean(attacker_check == "ok"))
fm <- lab |> filter(!is.na(facility_match_check), !str_detect(facility_match_check, "^n/a"))

scores <- tribble(~metric, ~value, ~n, ~note,
  "recall_attack_level", mean(att$recalled), nrow(att), paste("reference:", ref_src),
  "recall_facility_all", mean(facrec$hit_facility), nrow(facrec), "named registry facilities in massive attacks, d..d+1",
  "recall_facility_confirmed", mean(facrec$hit_facility[facrec$certainty == "confirmed"]), sum(facrec$certainty == "confirmed"), "excluding facilities only named as targets",
  "recall_oblast", mean(oblrec$hit_oblast), nrow(oblrec), "attack-date x oblast with confirmed damage, d..d+1",
  "precision_strict", prec_strict, nrow(lab), "AMBIG counted as false; labels by LLM, not human-verified",
  "precision_lenient", prec_lenient, nrow(lab), "AMBIG counted as true",
  "attacker_accuracy_among_true", att_ok, sum(lab$is_econ_strike == "TRUE"), "",
  "facility_match_correct", mean(str_detect(fm$facility_match_check, "^(right|partly)")), nrow(fm), "share of sampled facility matches judged right/partly right")
readr::write_csv(scores, out("pilot_scores.csv"))
print(scores, width = 200); print(att); print(facrec |> select(date, facility_en, facility_id, certainty, hit_facility)); print(oblrec)
