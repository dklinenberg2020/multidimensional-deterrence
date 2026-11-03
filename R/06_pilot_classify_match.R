# 06_pilot_classify_match.R -- pilot month (March 2024): classify economic strike
# reports, match to registry facilities, de-duplicate into strikes.
# Outputs: data/interim/pilot_2024_03_reports.parquet (report level)
#          data/interim/pilot_2024_03_strikes.parquet (strike level, target schema subset)
#          output/pilot_precision_sample.csv (50 strikes for hand-checking)
source(here::here("R", "00_setup.R"))
pacman::p_load(rnaturalearth)
PILOT_START <- ymd("2024-03-01"); PILOT_END <- ymd("2024-03-31")

ev <- arrow::read_parquet(interim("viina_events.parquet")) |>
  filter(date >= PILOT_START, date <= PILOT_END)
hits <- arrow::read_parquet(interim("viina_dict_hits.parquet")) |> select(event_id, starts_with("hit"), terms_hit)
dict <- readr::read_csv(here("dict", "econ_targets.csv"), show_col_types = FALSE)
fac  <- readr::read_csv(here("registry", "facilities.csv"), show_col_types = FALSE)

r <- ev |> inner_join(hits, by = "event_id") |> mutate(tl = stri_trans_tolower(text))

# ---- 1. classify -------------------------------------------------------------
# Economic strike report = (a) a dictionary hit AND (b) a strike cue in the headline
# or VIINA t_property_b == 1, AND NOT (c) a restoration-only / non-strike headline.
strike_cue  <- "удар|атак|обстр[іе]л|ракет|дрон|безп[іи]лотн|беспилотн|шахед|shahed|влуч|прил[іе]т|пошкод|поврежд|зруйн|разруш|уражен|поражен|пожеж|пожар|вибух|взрыв|уламк|обломк|знеструм|обесточ"
noise_cue   <- "ремонт|відновил|восстановил|відновлен|восстановлен|підключено до мережі|катівн|\\bиск|суд\\b|санкц|тариф|ціни|цены"
r <- r |>
  mutate(cue_strike = str_detect(tl, strike_cue),
         cue_noise  = str_detect(tl, noise_cue) & !str_detect(tl, "удар|атак|обстр|ракет|дрон|шахед"),
         # ship strikes are handled whole-period by 09_ships.R, so the shipping class is not used here
         econ = (hit_refining | hit_storage_export | hit_gen | hit_transmission | hit_industrial) &
                (cue_strike | t_property_b == 1) & !cue_noise)

# Target class: most specific class hit, priority refining > storage_export > gen > transmission > industrial.
cls_order <- c("refining", "storage_export", "gen", "transmission", "industrial")
r$target_class <- apply(as.matrix(r[paste0("hit_", cls_order)]), 1, function(x) cls_order[which(x)[1]])

# ---- 2. attacker -------------------------------------------------------------
# VIINA a_rus_init / a_ukr_init are unpopulated in 2024 (NOTES.md), so attacker is a
# documented heuristic: UA if the headline names Russian territory, occupied-territory
# authorities, or a Russian refinery/oil depot; RU otherwise.
ua_cue <- paste0("белгород|бєлгород|курск|брянск|рязан|кубан|краснодар|ростов|воронеж|ленинград|ленінград|",
                 "москв|самар|сызран|сизран|новокуйб|кириш|туапс|татарстан|башкир|\\bднр\\b|\\bлнр\\b|",
                 "на территории россии|на території росії|в россии|в росії|российск\\w* нпз|російськ\\w* нпз|",
                 "всу (обстрел|атак|удар)|зсу (уразил|атакувал)|\\bнпз\\b|нефтебаз|нафтобаз")
r <- r |> mutate(attacker = if_else(str_detect(tl, ua_cue), "UA", "RU"))

# ---- 3. facility match: name first, else <= 10 km and same oblast ----------------
# Type words come from each plant's own name, so "Дністровська ГЕС" (HPP) and
# "Дністровська ГАЕС" (pumped storage) do not match each other.
type_of <- function(name_ua, cls) case_when(
  cls == "refining"                ~ "нпз|нефтеперераб|нафтоперероб|нефтехим|нафтохім",
  str_detect(name_ua, "ГАЕС")      ~ "гаес|гаэс",
  str_detect(name_ua, "ГЕС")       ~ "гес|гэс|гідроелектростанц|гидроэлектростанц",
  str_detect(name_ua, "ТЕЦ|теплоелектроцентрал") ~ "тец|тэц|теплоелектроцентрал|теплоэлектроцентрал",
  TRUE                             ~ "тес|тэс|дрес|грэс|теплоелектростанц|теплоэлектростанц|електростанц|электростанц")
stem <- function(x) {
  w <- str_split_fixed(stri_trans_tolower(coalesce(x, "")), "[ \\-]", 2)[, 1]
  w <- str_remove(w, "(ська|ский|ская|ське|ськ|ск)$")
  if_else(nchar(w) >= 4, str_sub(w, 1, max(4, nchar(w) - 1)), NA_character_)
}
num <- function(x) str_match(coalesce(x, ""), "(?:ТЕЦ|ТЭЦ|ТЕС|ГЕС|№)\\s*-?\\s*(\\d+)")[, 2]
alias <- fac |>
  mutate(s_ua = stem(name_ua), s_ru = stem(name_ru), n = coalesce(num(name_ua), num(name_ru)),
         trx = type_of(coalesce(name_ua, ""), class),
         rx = pmap_chr(list(s_ua, s_ru, n, trx), function(a, b, n, t) {
           s <- paste(na.omit(unique(c(a, b))), collapse = "|")
           if (s == "") return(NA_character_)
           nn <- if (is.na(n)) "" else paste0("[ -]?№?\\s?", n, "\\b")
           # "<stem>… ТЕС", "<stem>… та <other>… ГЕС" (coordinated list), or "ТЕС <stem>…"
           sprintf("(%s)\\w*(\\s+(та|і|й|и|and)\\s+\\w+)?\\s+(%s)%s|(%s)%s\\s+\\w*\\s*(%s)", s, t, nn, t, nn, s)
         }))
# hand-added aliases for compound names the stem rule cannot generate
manual <- tribble(~facility_id, ~rx,
  "UA_HPP_DNIPROVSKA", "дніпрогес|днепрогэс",
  "UA_TPP_TRYPILSKA",  "трипільськ|трипольск",
  "UA_TPP_ZMIYIVSKA",  "зміївськ|змиевск")
alias <- bind_rows(alias |> select(facility_id, rx), manual) |> filter(!is.na(rx))
readr::write_csv(alias, out("pilot_facility_aliases.csv"))

name_match <- map_chr(r$tl, function(t) {
  m <- alias$facility_id[vapply(alias$rx, function(x) stri_detect_regex(t, x), logical(1))]
  if (length(m)) paste(unique(m), collapse = ";") else NA_character_
})

adm <- rnaturalearth::ne_states(country = c("Ukraine", "Russia"), returnclass = "sf") |>
  mutate(oblast = if_else(name == "Kiev City", "Kiev", name)) |> select(oblast) |> st_make_valid()
sf_use_s2(TRUE)
to_obl <- function(df) {
  p <- st_as_sf(df, coords = c("lon", "lat"), crs = 4326)
  st_join(p, adm, join = st_within) |> st_drop_geometry() |> pull(oblast)
}
fac_geo <- fac |> filter(!is.na(lat)) |> mutate(oblast = to_obl(pick(lon, lat)))
r$oblast <- to_obl(r |> select(lon, lat))

fsf <- st_as_sf(fac_geo, coords = c("lon", "lat"), crs = 4326)
rsf <- st_as_sf(r, coords = c("lon", "lat"), crs = 4326)
nn  <- st_is_within_distance(rsf, fsf, dist = 10000)
spatial_match <- map_chr(seq_len(nrow(r)), function(i) {
  j <- nn[[i]]
  j <- j[fac_geo$oblast[j] %in% r$oblast[i] & fac_geo$class[j] == coalesce(r$target_class[i], "")]
  if (length(j) == 1) fac_geo$facility_id[j] else if (length(j) > 1) paste(fac_geo$facility_id[j], collapse = ";") else NA_character_
})
r <- r |> mutate(name_match = name_match, spatial_match = spatial_match,
                 facility_id = coalesce(name_match, if_else(GEO_PRECISION %in% c("STREET", "ADM3"), spatial_match, NA_character_)),
                 match_conf = case_when(!is.na(name_match) & !str_detect(name_match, ";") ~ "name",
                                        !is.na(name_match) ~ "name_multi",
                                        !is.na(facility_id) & !str_detect(facility_id, ";") ~ "spatial_10km_same_oblast",
                                        !is.na(facility_id) ~ "spatial_ambiguous",
                                        TRUE ~ NA_character_))
# A matched facility fixes the target class (e.g. "ДнепроГЭС … Укрэнерго" is gen, not transmission).
fac_cls <- setNames(fac$class, fac$facility_id)
r <- r |> mutate(target_class = if_else(!is.na(facility_id) & !str_detect(facility_id, ";"),
                                        unname(fac_cls[facility_id]), target_class))

# ---- 4. de-duplicate: same target and attacker within 24 h ----------------------
# Target key = facility_id if matched, else class x oblast x populated place.
# Timestamp = VIINA publication date + time, assumed Kyiv time (open question).
# A headline naming several registry plants ("Канівська та Дністровська ГЕС") yields one
# row per plant, i.e. separate targets.
econ <- r |> filter(econ) |>
  # (spatially ambiguous matches are NOT split: they stay one target listing both plants)
  mutate(facility_id = if_else(match_conf %in% "name_multi", facility_id, str_replace_all(facility_id, ";", "|"))) |>
  separate_rows(facility_id, sep = ";") |>
  mutate(facility_id = str_replace_all(facility_id, "\\|", ";")) |>
  mutate(ts = ymd_hm(paste(date, coalesce(time, "00:00")), tz = "Europe/Kyiv", quiet = TRUE),
         target_key = coalesce(facility_id, paste(target_class, coalesce(oblast, "NA"), coalesce(as.character(geonameid), "NA"), sep = "|"))) |>
  arrange(attacker, target_key, ts)
# A new strike starts when a report is > 24 h after the FIRST report of the current
# strike (anchored windows, so long runs of follow-up reports cannot chain).
econ <- econ |> group_by(attacker, target_key) |>
  group_modify(function(d, k) {
    sid <- integer(nrow(d)); cur <- 0L; t0 <- as.POSIXct(NA)
    for (i in seq_len(nrow(d))) {
      if (is.na(t0) || as.numeric(difftime(d$ts[i], t0, units = "hours")) > 24) { cur <- cur + 1L; t0 <- d$ts[i] }
      sid[i] <- cur
    }
    d$k <- sid; d }) |> ungroup() |>
  mutate(strike_id = sprintf("P2403_%s_%s_%02d", attacker, str_replace_all(target_key, "[^A-Za-z0-9]+", "_"), k))

arrow::write_parquet(r |> select(-tl), interim("pilot_2024_03_reports.parquet"))

fac_cap <- fac |> select(facility_id, capacity, capacity_unit)
strikes <- econ |>
  group_by(strike_id, attacker, target_key) |>
  summarise(date = as.Date(min(ts), tz = "Europe/Kyiv"), time = format(min(ts), "%H:%M", tz = "Europe/Kyiv"),
            target_class = first(target_class), facility_id = first(facility_id),
            match_conf = first(match_conf), oblast = first(oblast),
            n_reports = n(), n_sources = n_distinct(source),
            headline = first(text), url = first(url), event_ids = paste(event_id, collapse = ";"),
            .groups = "drop") |>
  left_join(fac_cap, by = "facility_id") |>
  mutate(action_id = NA_character_, severity = NA_real_, dmg_kin = NA_real_, dmg_econ = NA_real_,
         restored_date = as.Date(NA))
arrow::write_parquet(strikes, interim("pilot_2024_03_strikes.parquet"))
log_gap("06_pilot", "pilot strikes with severity/dmg/action_id NA (not yet defined)", nrow(strikes), "by design in Phase 1")

set.seed(20240322)
samp <- strikes |> slice_sample(n = min(50, nrow(strikes))) |>
  select(strike_id, date, time, attacker, target_class, facility_id, match_conf, oblast, n_reports, headline, url)
readr::write_csv(samp, out("pilot_precision_sample.csv"))

message(sprintf("March 2024: %d reports with dict hit; %d classified economic; %d strikes after dedup (%d RU, %d UA); %d matched to a facility",
                sum(r$hit_any), sum(r$econ), nrow(strikes), sum(strikes$attacker == "RU"), sum(strikes$attacker == "UA"),
                sum(!is.na(strikes$facility_id))))
print(strikes |> count(target_class, attacker))
print(strikes |> filter(!is.na(facility_id)) |> select(date, attacker, facility_id, match_conf, n_reports))
