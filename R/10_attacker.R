# 10_attacker.R -- attacker attribution for strike reports (PI decision 2026-11-06, item 3).
# Rule: (a) headline names Russian territory / Russian refinery / UA-forces wording -> UA;
#       (b) else territorial control of the reported populated place on the report date
#           (VIINA control files, majority-vote `status`): UA-held -> attacker RU,
#           RU-held -> attacker UA, CONTESTED / unknown -> NA.
# Validated against VIINA's own initiator labels (a_rus_init_b / a_ukr_init_b, populated 2025+).
# Outputs: data/interim/viina_attacker.parquet, output/attacker_validation.csv
source(here::here("R", "00_setup.R"))
dir.create(raw_dir("viina"), recursive = TRUE, showWarnings = FALSE)
for (y in VIINA_YEARS) {
  dest <- file.path(raw_dir("viina"), sprintf("control_latest_%d.zip", y))
  if (!file.exists(dest)) download.file(sprintf("https://media.githubusercontent.com/media/zhukovyuri/VIINA/%s/Data/control_latest_%d.zip", VIINA_COMMIT, y),
                                        dest, mode = "wb", quiet = TRUE)
}
ev <- arrow::read_parquet(interim("viina_events.parquet"),
                          col_select = c(event_id, date, geonameid, text, a_rus_init_b, a_ukr_init_b,
                                         t_artillery_b, t_airstrike_b, t_uav_b, t_property_b, t_civcas_b, t_milcas_b))
ev <- ev |> mutate(geonameid = as.integer(geonameid), d = as.integer(format(date, "%Y%m%d")))
keys <- data.table::as.data.table(ev |> distinct(geonameid, d))
ctrl <- data.table::rbindlist(lapply(VIINA_YEARS, function(y) {
  z <- file.path(raw_dir("viina"), sprintf("control_latest_%d.zip", y))
  x <- data.table::fread(cmd = sprintf("unzip -p '%s'", z), select = c("geonameid", "date", "status"))
  x[keys, on = c(geonameid = "geonameid", date = "d"), nomatch = 0]
}))
ev <- ev |> left_join(as_tibble(ctrl) |> rename(d = date, ctrl_status = status), by = c("geonameid", "d"))

ua_text <- paste0("белгород|бєлгород|курск|брянск|рязан|кубан|краснодар|ростов|воронеж|ленинград|ленінград|",
                  "москв|самар|сызран|сизран|кириш|туапс|татарстан|башкир|новоросс|новоросій|таганро|",
                  "на территории россии|на території росії|в россии|в росії|российск\\w* нпз|російськ\\w* нпз|",
                  "\\bнпз\\b|нефтебаз|нафтобаз|всу (обстрел|атак|удар)|зсу (уразил|атакувал)|сили оборони уразил|",
                  "\\bсбу\\b (уразил|атакувал)|\\bгур\\b (уразил|атакувал)|\\bсбс\\b")
ev <- ev |> mutate(tl = stri_trans_tolower(text),
                   text_ua = stri_detect_regex(tl, ua_text),
                   attacker_rule = case_when(text_ua ~ "UA",
                                             ctrl_status == "UA" ~ "RU",
                                             ctrl_status == "RU" ~ "UA",
                                             TRUE ~ NA_character_),
                   attacker_basis = case_when(text_ua ~ "text", !is.na(attacker_rule) ~ "control",
                                              ctrl_status == "CONTESTED" ~ "contested", TRUE ~ "no_control_data"),
                   attacker_viina = case_when(a_rus_init_b == 1 & coalesce(a_ukr_init_b, 0) == 0 ~ "RU",
                                              a_ukr_init_b == 1 & coalesce(a_rus_init_b, 0) == 0 ~ "UA"),
                   strike_like = t_artillery_b == 1 | t_airstrike_b == 1 | t_uav_b == 1 | t_property_b == 1 | t_civcas_b == 1 | t_milcas_b == 1)
arrow::write_parquet(ev |> select(event_id, ctrl_status, attacker_rule, attacker_basis, attacker_viina, strike_like),
                     interim("viina_attacker.parquet"))

# validation: strike-like reports with an unambiguous VIINA initiator label
v <- ev |> filter(strike_like, !is.na(attacker_viina))
val <- bind_rows(
  v |> summarise(subset = "all labelled strike-like", n = n(), coverage = mean(!is.na(attacker_rule)),
                 accuracy = mean(attacker_rule == attacker_viina, na.rm = TRUE)),
  v |> group_by(subset = paste("basis =", attacker_basis)) |>
    summarise(n = n(), coverage = mean(!is.na(attacker_rule)), accuracy = mean(attacker_rule == attacker_viina, na.rm = TRUE), .groups = "drop"),
  v |> group_by(subset = paste("VIINA label =", attacker_viina)) |>
    summarise(n = n(), coverage = mean(!is.na(attacker_rule)), accuracy = mean(attacker_rule == attacker_viina, na.rm = TRUE), .groups = "drop"))
readr::write_csv(val, out("attacker_validation.csv"))
print(val)
print(ev |> filter(strike_like) |> mutate(y = year(date)) |> count(y, attacker_basis) |> tidyr::pivot_wider(names_from = attacker_basis, values_from = n))
