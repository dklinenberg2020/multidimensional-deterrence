# 09_ships.R -- ship-strike layer, whole period (24 Feb 2022 onward). PI-approved 2026-11-03:
#  * vessels get a sea-area location (Black Sea, Sea of Azov, Baltic Sea, Danube, ...), not an oblast
#  * warships: kinetic only (dmg_econ NA, flagged)
#  * merchant ships: dmg_econ_ship = deadweight tonnage (DWT, from registry/vessels.csv) x severity weight
# Outputs: data/interim/ship_reports.parquet, data/interim/ship_strikes.parquet,
#          output/ship_strikes.csv, output/ship_vessel_names.csv, output/ship_summary_by_year.csv
source(here::here("R", "00_setup.R"))
ev <- arrow::read_parquet(interim("viina_events.parquet"),
                          col_select = c(event_id, date, time, source, url, text, lang))
vt <- readr::read_csv(here("dict", "vessel_terms.csv"), show_col_types = FALSE)
ev <- ev |> mutate(tl = stri_trans_tolower(text))

det <- function(cls) {
  r <- vt |> filter(vessel_class == cls)
  rx <- paste(c(r$term_ua, r$term_ru), collapse = "|")
  stri_detect_regex(ev$tl, rx)
}
for (k in unique(vt$vessel_class)) ev[[paste0("v_", k)]] <- det(k)

strike_cue <- "атак|удар|уражен|поражен|влуч|поціл|прил[іе]т|пошкод|поврежд|дрон|ракет|вибух|взрыв|знищ|уничтож|затону|потоп|пожеж|пожар|загор"
noise_cue  <- "судноремонт|судоремонт|суднобуд|судострои|судостро|\\bсуд\\b|суду\\b|судд|судебн|судов\\w* (рішен|решени|засідан|заседан|процес)|корабельн\\w* (сторон|район)"
# fuel-truck sense of "танкер" in convoy reports is not a ship
ev <- ev |> mutate(v_merchant_tanker = v_merchant_tanker & !str_detect(tl, "колон\\w*.{0,60}танкер|танкер\\w*.{0,60}колон"))
# Proximity rule: a strike word must sit within 6 words of a vessel word (either order).
vessel_any_rx <- paste0("(?:", paste(c(vt$term_ua, vt$term_ru), collapse = "|"), ")")
hit_rx <- "(?:уразил\\w*|вразил\\w*|вразив|атак\\w*|постражд\\w*|пострада\\w*|уражен\\w*|уражено|поражен\\w*|влуч\\w*|поціл\\w*|попал\\w*|прил[іе]т\\w*|атакува\\w*|атакова\\w*|атак[аиуі] на|удар\\w* по|вдари\\w*|ударил\\w*|пошкодж\\w*|поврежд\\w*|знищ\\w*|уничтож\\w*|затону\\w*|потоп\\w*|загор\\w*|горить|горит|пожеж\\w*|пожар\\w*|підбит\\w*|подбит\\w*)"
near_rx <- paste0(vessel_any_rx, "\\w*(?:\\W+\\w+){0,6}?\\W+", hit_rx, "|", hit_rx, "(?:\\W+\\w+){0,6}?\\W+", vessel_any_rx)
# not ship strikes: buildings/HQ of the fleet, naval drones (weapons), retrospectives, warnings
noise2 <- "штаб\\w* (чорноморськ|черноморск|чф)|будівл\\w* (чорноморськ|чф)|здани\\w* (черноморск|чф)|безекіпажн|безэкипажн|морськ\\w* дрон\\w* (знищ|уничтож)|виставк|выставк|фільм|фильм|річниц|годовщин|попереджа|предупрежда"
ev <- ev |> mutate(named_gc = stri_detect_regex(text, "(?i:зерновоз\\w*)\\s+[A-Z][A-Za-z]"),
                   v_merchant_cargo = v_merchant_cargo | named_gc)
ev <- ev |> mutate(any_vessel = v_merchant_tanker | v_merchant_cargo | v_merchant_generic | v_warship,
                   ship = any_vessel & (stri_detect_regex(tl, near_rx) | (named_gc & str_detect(tl, strike_cue))) & !str_detect(tl, noise_cue) & !str_detect(tl, noise2))
r <- ev |> filter(ship)

# ---- vessel class: warship terms win; else tanker > cargo > generic merchant
r <- r |> mutate(vessel_class = case_when(v_warship & !(v_merchant_tanker | v_merchant_cargo) ~ "warship",
                                          v_merchant_tanker ~ "merchant_tanker",
                                          v_merchant_cargo ~ "merchant_cargo",
                                          TRUE ~ "merchant_generic"),
                 shadow_fleet = str_detect(tl, "тіньов\\w* флот|тенево\\w* флот|shadow fleet"))

# ---- location: sea area (PI: location matters little for ships; one label per sea)
r <- r |> mutate(sea_area = case_when(
  str_detect(tl, "азовськ\\w* мор|азовск\\w* мор|бердянськ|бердянск|маріупол|мариупол|ейськ|ейск|таганрог") ~ "Sea of Azov",
  str_detect(tl, "балтійськ|балтийск|балтик|усть-луг|приморськ|приморск|фінськ\\w* затоц|финск\\w* залив") ~ "Baltic Sea",
  str_detect(tl, "дуна|ізмаїл|измаил|\\bрені\\b|\\bрени\\b|кілі|килия") ~ "Danube",
  str_detect(tl, "середземн|средиземн") ~ "Mediterranean",
  str_detect(tl, "каспі|каспи") ~ "Caspian Sea",
  str_detect(tl, "червон\\w* мор|красн\\w* мор|хусит|хуси|аденськ|аденск") ~ "Red Sea",
  TRUE ~ "Black Sea"))

# ---- attacker: warships -> UA unless the ship is Ukrainian; merchant -> RU unless UA cues
# Attacker rules (heuristic; see NOTES.md):
#  * a Ukrainian boat/ship as the object, or Russian weapons (Ланцет) -> RU
#  * warships otherwise -> UA (Black Sea Fleet targets)
#  * merchant: Ukrainian-forces wording or Crimea/Kerch/Russian ports -> UA; Russian-forces wording -> RU
ua_vessel_obj <- "українськ\\w* (катер|корабл|човн|судн)|украинск\\w* (катер|корабл|лодк|судн|десантн)|(катер|корабл|лодк|човн)\\w* (всу|зсу|вмс україни|вмс украины)|вмс україни|вмс украины|ланцет"
ua_cue <- "\\bсбу\\b|\\bгур\\b|\\bсбс\\b|морськ\\w* дрон|морск\\w* дрон|sea baby|магура|\\bзсу\\b|\\bвсу (уничтож|атаков|удар)|сили оборони|українськ\\w* військов|уразил|тіньов|тенев|крим|крым|керч|феодос|севастопол|новоросійськ|новороссийск|усть-луг|приморськ|приморск|тамань|туапс|таганро|бердянськ|бердянск|российск\\w* (судн|танкер)|російськ\\w* (судн|танкер)"
ru_cue <- "\\bрф\\b|росія|россия|росіян|россиян|окупант|ворог|ворож|одес|ізмаїл|измаил|\\bрені\\b|чорноморськ|південн\\w* (порт|одещ)|дунай|дунаї"
r <- r |> mutate(attacker = case_when(
  str_detect(tl, ua_vessel_obj) ~ "RU",
  vessel_class == "warship" ~ "UA",
  str_detect(tl, ua_cue) & !str_detect(tl, "рф (знову )?атак|росія (знову )?атак|ворог|окупант\\w* (атак|удар)") ~ "UA",
  str_detect(tl, ru_cue) ~ "RU",
  TRUE ~ NA_character_))
log_gap("09_ships", "ship reports with attacker undetermined", sum(is.na(r$attacker)), "kept; attacker NA")

# dmg_econ_ship is in DWT-weighted tonnes (DWT x severity weight). Turning it into a share of
# "the relevant fleet" needs a denominator: open question for the PI (NOTES.md).

# ---- vessel names: quoted spans or Latin capitals; drop weapons and common words
stop_names <- c("ланцет","шахед","шахеди","калібр","калибр","нептун","магура","магура v5","sea baby","си бейби","приліт","прилет",
  "бавовна","кинджал","кинжал","циркон","онікс","оникс","герань","іскандер","искандер","storm shadow","atacms","flamingo","фламінго",
  "живучість кораблів","бджола","птахи мадяра","isw","sbu","nato","bbc","cnn","usa","osint","hur","uav","ukrinform","reuters",
  "unian","ap","bloomberg","rbc","dw","tass","ria","mil","ok","sea","ship","видео","відео","фото","video",
  "bayraktar","байрактар","орлівка","орловка","тори","тор","кавказ","astra","ковель","панцирь","панцир","південний","южный","транснефть-порт приморск","азову","флеш")
# A name counts only when it directly follows a vessel noun (0-3 words between), e.g.
# "суховантаж MARIAM M", "корабель «Сергей Котов»", "танкер Millennial Spirit", "IMO 9216729 SHUI SPIRIT".
noun_rx <- "(?i:корабл\\w*|судн\\w*|суден|судов|танкер\\w*|сухогруз\\w*|суховантаж\\w*|зерновоз\\w*|балкер\\w*|контейнеровоз\\w*|пором\\w*|паром\\w*|фрегат\\w*|крейсер\\w*|корвет\\w*|катер\\w*|буксир\\w*|тральщик\\w*|ракетонос\\w*|\\bimo\\s*\\d{7})"
name_rx <- paste0(noun_rx, "\\s+(?:[^\\s\"«]+\\s+){0,3}?",
                  "(?:\"+\\s*([^\"]{2,40}?)\\s*\"+|«\\s*([^»]{2,40}?)\\s*»|([A-Z][A-Za-z0-9\\-]{1,}(?:\\s+[A-Z0-9][A-Za-z0-9\\-]*){0,3}))")
extract_names <- function(t) {
  m <- stri_match_all_regex(t, name_rx)[[1]]
  n <- c(m[, 2], m[, 3], m[, 4]); n <- str_squish(n[!is.na(n)])
  n <- str_squish(str_remove(n, "^(?i:imo)\\s*\\d{7}\\s*"))   # "IMO 9216729 SHUI SPIRIT" -> "SHUI SPIRIT"
  n <- n[!stri_trans_tolower(n) %in% stop_names & str_detect(n, "^[A-ZА-ЯІЇЄҐ0-9]") & str_count(n, "\\S+") <= 4]
  n <- unique(n)
  if (length(n)) paste(n, collapse = ";") else NA_character_
}
r <- r |> mutate(vessel_names = map_chr(text, extract_names))
# Red Sea / Houthi incidents are outside the Russia-Ukraine war: logged and dropped
log_gap("09_ships", "ship reports dropped as out of scope (Red Sea / Houthi)", sum(r$sea_area == "Red Sea"), "")
r <- r |> filter(sea_area != "Red Sea")
arrow::write_parquet(r |> select(-tl), interim("ship_reports.parquet"))

# ---- strikes: same vessel (name) + attacker within 24 h; unnamed -> sea area x vessel class x attacker
r <- r |> mutate(ts = ymd_hm(paste(date, coalesce(time, "00:00")), tz = "Europe/Kyiv", quiet = TRUE),
                 sev = map_int(tl, sev_of)) |>
  separate_rows(vessel_names, sep = ";") |>
  mutate(vessel_key = if_else(is.na(vessel_names), NA_character_, stri_trans_toupper(stri_trans_general(vessel_names, "Any-Latin; Latin-ASCII"))),
         target_key = coalesce(paste0("vessel|", vessel_key), paste("unnamed", sea_area, vessel_class, sep = "|")) ,
         target_key = if_else(is.na(vessel_key), paste("unnamed", sea_area, vessel_class, sep = "|"), target_key)) |>
  arrange(attacker, target_key, ts) |>
  group_by(attacker, target_key) |>
  group_modify(function(d, k) {
    sid <- integer(nrow(d)); cur <- 0L; t0 <- as.POSIXct(NA)
    for (i in seq_len(nrow(d))) {
      # named vessels: 72 h window (follow-up reports on the same ship run over several days);
      # unnamed: 24 h (brief's rule)
      win <- if (startsWith(k$target_key, "vessel|")) 72 else 24
      if (is.na(t0) || as.numeric(difftime(d$ts[i], t0, units = "hours")) > win) { cur <- cur + 1L; t0 <- d$ts[i] }
      sid[i] <- cur }
    d$k <- sid; d }) |> ungroup() |>
  group_by(attacker, target_key, k) |>
  # id uses the strike's FIRST report date, so reports that cross midnight stay one strike
  mutate(strike_id = sprintf("SHIP_%s_%s_%s_%02d", coalesce(attacker, "NA"),
                             format(as.Date(min(ts), tz = "Europe/Kyiv"), "%Y%m%d"),
                             str_replace_all(target_key, "[^A-Za-z0-9]+", "_"), k)) |>
  ungroup()

vessels <- readr::read_csv(here("registry", "vessels.csv"), show_col_types = FALSE,
                           col_types = cols(.default = "c", dwt = "d"))
alias <- vessels |> select(vessel_id, name_variants) |> separate_rows(name_variants, sep = ";") |>
  mutate(vessel_key = stri_trans_toupper(stri_trans_general(str_squish(name_variants), "Any-Latin; Latin-ASCII"))) |>
  distinct(vessel_key, .keep_all = TRUE) |> select(vessel_key, vessel_id)

ids <- readr::read_csv(here("registry", "ship_strike_ids.csv"), show_col_types = FALSE,
                       col_types = cols(.default = "c"))
# a strike with several identified vessels keeps the first here; extra vessels become extra rows below
ids_one <- ids |> group_by(strike_id) |> slice(1) |> ungroup() |>
  transmute(strike_id, id_vessel_id = na_if(vessel_id, ""), id_vessel_name = na_if(vessel_name, ""),
            id_actual_date = as.Date(na_if(actual_strike_date, "")), id_attacker = na_if(attacker, ""),
            id_status = status, id_duplicate_of = na_if(duplicate_of, ""), id_source_url = source_url)
strikes <- r |> group_by(strike_id, attacker, target_key) |>
  summarise(date = as.Date(min(ts), tz = "Europe/Kyiv"), time = format(min(ts), "%H:%M", tz = "Europe/Kyiv"),
            vessel_class = names(sort(table(vessel_class), decreasing = TRUE))[1],
            shadow_fleet = any(shadow_fleet), sea_area = names(sort(table(sea_area), decreasing = TRUE))[1],
            vessel_name = first(vessel_names), vessel_key = first(vessel_key),
            severity = if (all(is.na(sev))) NA_integer_ else max(sev, na.rm = TRUE),
            n_reports = n(), n_sources = n_distinct(source), headline = first(text), url = first(url),
            event_ids = paste(unique(event_id), collapse = ";"), .groups = "drop") |>
  left_join(alias, by = "vessel_key") |>
  # ---- hand-curated identifications (registry/ship_strike_ids.csv): researched from maritime press,
  # one source URL per row. Can (i) attach a vessel to an unnamed strike, (ii) correct date/attacker,
  # (iii) mark a strike as not a ship strike, (iv) mark it a duplicate of another strike.
  left_join(ids_one, by = "strike_id") |>
  mutate(vessel_id = coalesce(id_vessel_id, vessel_id),
         vessel_name = coalesce(id_vessel_name, vessel_name),
         date_reported = date,
         date = coalesce(id_actual_date, date),
         attacker = coalesce(id_attacker, attacker),
         id_source_url = id_source_url) |>
  left_join(vessels |> select(vessel_id, imo, vessel_type, flag, dwt, military, dwt_source_url = source_url), by = "vessel_id") |>
  # registry overrides headline wording: naval auxiliaries (e.g. Navy cable ships) count as warships
  mutate(vessel_class = case_when(coalesce(military, "") == "TRUE" ~ "warship",
                                  coalesce(military, "") == "FALSE" & vessel_class == "warship" ~ "merchant_generic",
                                  TRUE ~ vessel_class),
         target_class = if_else(vessel_class == "warship", "warship", "shipping"),
         location = sea_area,
         sev_weight = unname(sev_w[as.character(severity)]),
         dmg_econ_ship = if_else(target_class == "shipping", dwt * sev_weight, NA_real_),
         econ_flag = case_when(
           target_class == "warship" ~ "warship: kinetic only (PI decision)",
           !is.na(dmg_econ_ship) ~ NA_character_,
           is.na(vessel_name) ~ "merchant vessel not named in headlines",
           is.na(vessel_id) ~ "named vessel not yet in registry/vessels.csv",
           is.na(dwt) ~ "DWT missing in registry",
           is.na(severity) ~ "severity not codable",
           TRUE ~ "other"),
         dmg_kin = NA_real_)   # kinetic damage not yet implemented (decision pending)
# extra vessels identified in the same strike -> one row each (suffix _v2, _v3, ...)
extra <- ids |> group_by(strike_id) |> mutate(j = row_number()) |> ungroup() |> filter(j > 1, status == "ship_strike")
if (nrow(extra)) {
  add <- strikes |> inner_join(extra |> select(strike_id, j, x_vid = vessel_id, x_vname = vessel_name, x_src = source_url), by = "strike_id") |>
    mutate(strike_id = paste0(strike_id, "_v", j), vessel_id = x_vid, vessel_name = x_vname, id_source_url = x_src) |>
    select(-j, -x_vid, -x_vname, -x_src)
  strikes <- bind_rows(strikes, add)
}
# re-attach registry particulars for vessels attached by the ids file, then recompute damage
strikes <- strikes |> select(-any_of(c("imo", "vessel_type", "flag", "dwt", "military", "dwt_source_url"))) |>
  left_join(vessels |> select(vessel_id, imo, vessel_type, flag, dwt, military, dwt_source_url = source_url), by = "vessel_id") |>
  mutate(vessel_class = case_when(coalesce(military, "") == "TRUE" ~ "warship",
                                  coalesce(military, "") == "FALSE" & vessel_class == "warship" ~ "merchant_generic",
                                  TRUE ~ vessel_class),
         target_class = if_else(vessel_class == "warship", "warship", "shipping"),
         id_status = coalesce(id_status, "unreviewed"),
         dmg_econ_ship = if_else(target_class == "shipping" & id_status %in% c("ship_strike", "unreviewed"), dwt * sev_weight, NA_real_),
         econ_flag = case_when(
           id_status == "not_ship_strike" ~ "reviewed: not a ship strike (excluded)",
           id_status == "duplicate" ~ paste("reviewed: duplicate of", id_duplicate_of),
           target_class == "warship" ~ "warship: kinetic only (PI decision)",
           !is.na(dmg_econ_ship) ~ NA_character_,
           id_status == "ship_strike" & is.na(vessel_id) ~ "reviewed: vessel not identified in sources",
           is.na(vessel_name) ~ "merchant vessel not named in headlines",
           is.na(vessel_id) ~ "named vessel not yet in registry/vessels.csv",
           is.na(dwt) ~ "DWT missing in registry",
           is.na(severity) ~ "severity not codable",
           TRUE ~ "other"))
arrow::write_parquet(strikes, interim("ship_strikes.parquet"))
readr::write_csv(strikes |> select(strike_id, date, date_reported, time, attacker, target_class, vessel_class, shadow_fleet, location,
                                   vessel_name, vessel_id, imo, dwt, severity, sev_weight, dmg_econ_ship, econ_flag, id_status,
                                   n_reports, n_sources, headline, url, id_source_url),
                 out("ship_strikes.csv"))

# Named merchant vessels to look up (feeds registry/vessels.csv)
names_tbl <- strikes |> filter(target_class == "shipping", !is.na(vessel_name)) |>
  group_by(vessel_key) |> summarise(vessel_name = first(vessel_name), first_date = min(date), n_strikes = n(),
                                    attacker = paste(unique(na.omit(attacker)), collapse = ";"),
                                    in_registry = any(!is.na(vessel_id)), example = first(headline), .groups = "drop") |>
  arrange(first_date)
readr::write_csv(names_tbl, out("ship_vessel_names.csv"))

summ <- strikes |> filter(!id_status %in% c("not_ship_strike", "duplicate")) |> mutate(year = year(date)) |>
  group_by(year, attacker, target_class) |>
  summarise(n_strikes = n(), n_named = sum(!is.na(vessel_name)), n_dwt = sum(!is.na(dwt)),
            sum_dmg_econ_ship = sum(dmg_econ_ship, na.rm = TRUE), .groups = "drop")
readr::write_csv(summ, out("ship_summary_by_year.csv"))
log_gap("09_ships", "merchant ship strikes without dmg_econ_ship", sum(strikes$target_class == "shipping" & is.na(strikes$dmg_econ_ship)), "see econ_flag")
message(sprintf("%d ship reports -> %d ship strikes (%d warship, %d merchant); %d merchant strikes name a vessel; %d distinct merchant names",
                nrow(r |> distinct(event_id)), nrow(strikes), sum(strikes$target_class == "warship"),
                sum(strikes$target_class == "shipping"), sum(strikes$target_class == "shipping" & !is.na(strikes$vessel_name)), nrow(names_tbl)))
print(as.data.frame(summ))
