# 08_pilot_econ_damage.R -- economic damage for the March 2024 pilot strikes (PI-approved 2026-11-03)
#  (1) Named facility with capacity:  dmg_econ = capacity / national capacity x severity weight
#  (2) Grid strikes:                  cust_out = max customers reported without power (headline numbers)
#  (3) Everything else:               dmg_econ NA, flagged (kept as an economic strike)
# Outputs: data/interim/pilot_2024_03_strikes_econ.parquet, output/pilot_econ_damage.csv,
#          output/pilot_econ_summary.csv
source(here::here("R", "00_setup.R"))
strikes <- arrow::read_parquet(interim("pilot_2024_03_strikes.parquet"))
reports <- arrow::read_parquet(interim("pilot_2024_03_reports.parquet"), col_select = c(event_id, text))
natcap  <- readr::read_csv(here("registry", "national_capacity.csv"), show_col_types = FALSE)
fac     <- readr::read_csv(here("registry", "facilities.csv"), show_col_types = FALSE) |> select(facility_id, country)

# all report texts of each strike
st_txt <- strikes |> select(strike_id, event_ids) |> separate_rows(event_ids, sep = ";") |>
  mutate(event_id = event_ids) |>
  left_join(reports |> distinct(event_id, .keep_all = TRUE), by = "event_id") |>
  mutate(tl = stri_trans_tolower(text))

# ---- severity: sev_of() / sev_w are defined in 00_setup.R (shared with 09_ships.R)

# ---- customers without power: "<n> [тис.] <customer noun>" in a headline with an outage word
outage_rx <- "без світла|без света|знеструм|обесточ|відключен|отключен|без електро|без электро|без енергопостач"
attack_rx <- "атак|удар|обстр|ракет|дрон|безп[іи]лот|беспилот|шахед|уламк|обломк|прил[іе]т|вибух|взрыв"
restore_rx <- "вже зі світлом|вже із світлом|уже со светом|повернули світло|вернули свет|відновили|восстановили|заживили|живлення відновлено"
cust_rx   <- paste0("(\\d{1,3}(?:[ \\u00a0]\\d{3})+|\\d+(?:[.,]\\d+)?)\\s*",
                    "(тис\\.?|тисяч\\w*|тыс\\.?|тысяч\\w*|млн|мільйон\\w*|миллион\\w*)?\\s*",
                    "(?:\\w+\\s+){0,2}?",
                    "(абонент\\w*|споживач\\w*|потребител\\w*|домогосподарств\\w*|осел\\w*|сімей|семей|людей|человек|жител\\w*|мешканц\\w*)")
cust_of <- function(t) {
  # need an outage word AND an attack word, and no restoration wording
  if (is.na(t) || !stri_detect_regex(t, outage_rx) || !stri_detect_regex(t, attack_rx) ||
      stri_detect_regex(t, restore_rx)) return(NA_real_)
  m <- stri_match_all_regex(t, cust_rx)[[1]]
  if (all(is.na(m[, 1]))) return(NA_real_)
  n <- as.numeric(str_replace(str_remove_all(m[, 2], "[ \\u00a0]"), ",", "."))
  mult <- case_when(str_detect(coalesce(m[, 3], ""), "^(тис|тыс)") ~ 1e3,
                    str_detect(coalesce(m[, 3], ""), "^(млн|мільйон|миллион)") ~ 1e6, TRUE ~ 1)
  max(n * mult, na.rm = TRUE)
}

st_txt <- st_txt |> mutate(sev = map_int(tl, sev_of), cust = map_dbl(tl, cust_of))
per <- st_txt |> group_by(strike_id) |>
  summarise(severity = if (all(is.na(sev))) NA_integer_ else max(sev, na.rm = TRUE),
            cust_out = if (all(is.na(cust))) NA_real_ else max(cust, na.rm = TRUE),
            cust_headline = text[which.max(coalesce(cust, -1))][1], .groups = "drop") |>
  mutate(cust_headline = if_else(is.na(cust_out), NA_character_, cust_headline))

out_tbl <- strikes |> select(-severity, -dmg_econ) |>
  left_join(per, by = "strike_id") |>
  left_join(fac, by = "facility_id") |>
  left_join(natcap |> select(country, nat_cap = capacity, nat_unit = capacity_unit), by = "country") |>
  mutate(single_fac = !is.na(facility_id) & !str_detect(facility_id, ";"),
         cap_share  = if_else(single_fac & capacity_unit == nat_unit, capacity / nat_cap, NA_real_),
         sev_weight = unname(sev_w[as.character(severity)]),
         dmg_econ   = cap_share * sev_weight,
         econ_basis = case_when(!is.na(dmg_econ) & !is.na(cust_out) ~ "capacity+customers",
                                !is.na(dmg_econ) ~ "capacity", !is.na(cust_out) ~ "customers", TRUE ~ "none"),
         econ_flag  = case_when(
           !is.na(dmg_econ) ~ NA_character_,
           !is.na(facility_id) & str_detect(facility_id, ";") ~ "facility ambiguous (several plants within 10 km)",
           single_fac & is.na(capacity) ~ "facility capacity missing in registry",
           single_fac & is.na(severity) ~ "severity not codable from headlines",
           !is.na(cust_out) ~ "no named facility; customers-out only",
           target_class == "transmission" ~ "grid strike; no customer count in headlines",
           TRUE ~ "no named facility"))

arrow::write_parquet(out_tbl, interim("pilot_2024_03_strikes_econ.parquet"))
readr::write_csv(out_tbl |> select(strike_id, date, attacker, target_class, facility_id, capacity, capacity_unit,
                                   cap_share, severity, sev_weight, dmg_econ, cust_out, econ_basis, econ_flag,
                                   n_reports, headline, cust_headline),
                 out("pilot_econ_damage.csv"))
log_gap("08_pilot_econ", "pilot strikes with dmg_econ NA", sum(is.na(out_tbl$dmg_econ)), "see econ_flag")
log_gap("08_pilot_econ", "pilot strikes with neither dmg_econ nor cust_out", sum(out_tbl$econ_basis == "none"), "")

summ <- out_tbl |> group_by(attacker, target_class) |>
  summarise(n_strikes = n(), n_dmg_econ = sum(!is.na(dmg_econ)), sum_dmg_econ = sum(dmg_econ, na.rm = TRUE),
            n_cust = sum(!is.na(cust_out)), sum_cust_out = sum(cust_out, na.rm = TRUE), .groups = "drop")
readr::write_csv(summ, out("pilot_econ_summary.csv"))
print(summ)
print(count(out_tbl, econ_basis)); print(count(out_tbl, econ_flag))
print(out_tbl |> filter(!is.na(dmg_econ)) |> arrange(desc(dmg_econ)) |>
        transmute(date, facility_id, cap_share = round(cap_share, 4), severity, dmg_econ = round(dmg_econ, 4)), n = 30)
print(out_tbl |> filter(!is.na(cust_out)) |> arrange(desc(cust_out)) |> transmute(date, oblast, cust_out, h = str_sub(cust_headline, 1, 90)), n = 30)
