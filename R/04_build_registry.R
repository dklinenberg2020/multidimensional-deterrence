# 04_build_registry.R -- seed registry/facilities.csv
#  * Russian refineries: capacity from the IntelliNews Missile War Monitor sheet
#    (mn t/yr -> t/yr), coordinates + RU/UA/EN names from ru.wikipedia (via the
#    crosswalk registry/ru_refinery_crosswalk.csv, hand-made).
#  * Ukrainian thermal + hydro plants: Wikidata (P625 coordinates, P2109 nominal
#    power in MW), plus ru/uk.wikipedia coordinates where Wikidata lacks them.
# Every value carries a source_url; anything not in a source stays NA.
source(here::here("R", "00_setup.R"))
pacman::p_load(httr2, jsonlite)
UA <- "deter-two-dim-research/0.1 (academic dataset; R httr2)"
INTELLINEWS_URL <- "https://docs.google.com/spreadsheets/d/1AHjZvX9Hf-6jdKxcTE8Dw7f6O2_svY0kX54sqKPyU_s"

fetch <- function(url, dest, ...) {
  if (!file.exists(dest)) {
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    request(url) |> req_user_agent(UA) |> req_url_query(...) |> req_retry(max_tries = 4) |>
      req_timeout(180) |> req_perform(path = dest)
  }
  dest
}

# ---- 1. IntelliNews sheet (raw) --------------------------------------------
in_csv <- fetch(paste0(INTELLINEWS_URL, "/export"), file.path(raw_dir("intellinews"), "refineries.csv"), format = "csv")
inn <- readr::read_csv(in_csv, skip = 4, show_col_types = FALSE, col_types = cols(.default = "c")) |>
  filter(!is.na(Refinery), !is.na(Strikes))
names(inn) <- make.names(names(inn))

# ---- 2. ru.wikipedia coordinates + language links ---------------------------
wiki_coords <- function(lang, titles, tag) {
  dest <- file.path(raw_dir("wikipedia"), sprintf("%s_%s.json", lang, tag))
  fetch(sprintf("https://%s.wikipedia.org/w/api.php", lang), dest,
        action = "query", format = "json", titles = paste(titles, collapse = "|"),
        prop = "coordinates|langlinks|info", inprop = "url", lllimit = "max", colimit = "max", redirects = 1)
  j <- jsonlite::fromJSON(dest, simplifyVector = FALSE)
  pairs <- function(l) bind_rows(tibble(from = character(), to = character()),
                                  map_dfr(l %||% list(), ~ tibble(from = .x$from, to = .x$to)))
  redir <- pairs(j$query$redirects); norm <- pairs(j$query$normalized)
  pages <- map_dfr(j$query$pages, function(p) {
    ll <- p$langlinks %||% list()
    get_ll <- function(l) { x <- keep(ll, ~ .x$lang == l); if (length(x)) x[[1]][["*"]] else NA_character_ }
    tibble(title = p$title, url = p$fullurl %||% NA_character_,
           lat = p$coordinates[[1]]$lat %||% NA_real_, lon = p$coordinates[[1]]$lon %||% NA_real_,
           ll_en = get_ll("en"), ll_uk = get_ll("uk"), ll_ru = get_ll("ru"))
  })
  # map requested title -> page
  tibble(req = titles) |>
    mutate(t1 = coalesce(norm$to[match(req, norm$from)], req),
           t2 = coalesce(redir$to[match(t1, redir$from)], t1)) |>
    left_join(pages, by = c("t2" = "title")) |> select(-t1)
}

cw <- readr::read_csv(here("registry", "ru_refinery_crosswalk.csv"), show_col_types = FALSE)
rw <- wiki_coords("ru", na.omit(cw$ruwiki_title), "ru_refineries")

ru <- cw |>
  left_join(rw, by = c("ruwiki_title" = "req")) |>
  left_join(inn |> select(Refinery, Capacity..mn.t.yr.), by = c("intellinews_name" = "Refinery")) |>
  mutate(cap_mn = suppressWarnings(as.numeric(str_extract(Capacity..mn.t.yr., "^[0-9.]+"))),
         cap_mn = if_else(str_detect(coalesce(plant_share_note, ""), "per-plant capacity is NA"), NA_real_, cap_mn),
         capacity = cap_mn * 1e6,
         capacity_unit = if_else(is.na(capacity), NA_character_, "t/yr"),
         source_url = pmap_chr(list(url, !is.na(capacity)), function(u, has_cap)
           paste(na.omit(c(u, if (has_cap) INTELLINEWS_URL)), collapse = "; ")),
         source_url = na_if(source_url, ""),
         country = "RU",
         name_ru = coalesce(t2, NA_character_), name_ua = ll_uk) |>
  transmute(facility_id, name_en, name_ua, name_ru, country, class, lat, lon, capacity, capacity_unit, source_url,
            capacity_note = Capacity..mn.t.yr., note = plant_share_note)

# ---- 3. Ukrainian thermal + hydro plants (Wikidata) -------------------------
sparql <- 'SELECT ?p ?cls ?en ?uk ?ru ?coord ?mw WHERE {
  VALUES ?cls {wd:Q200297 wd:Q6558431 wd:Q15911738 wd:Q1060744 wd:Q159719}
  ?p wdt:P31 ?cls; wdt:P17 wd:Q212.
  OPTIONAL{?p wdt:P625 ?coord} OPTIONAL{?p wdt:P2109 ?mw}
  OPTIONAL{?p rdfs:label ?en FILTER(lang(?en)="en")} OPTIONAL{?p rdfs:label ?uk FILTER(lang(?uk)="uk")}
  OPTIONAL{?p rdfs:label ?ru FILTER(lang(?ru)="ru")} }'
wd_csv <- file.path(raw_dir("wikidata"), "ua_power_plants.csv")
if (!file.exists(wd_csv)) {
  dir.create(dirname(wd_csv), recursive = TRUE, showWarnings = FALSE)
  request("https://query.wikidata.org/sparql") |> req_user_agent(UA) |>
    req_headers(Accept = "text/csv") |> req_url_query(query = sparql) |>
    req_retry(max_tries = 4) |> req_timeout(180) |> req_perform(path = wd_csv)
}
wd <- readr::read_csv(wd_csv, show_col_types = FALSE) |>
  mutate(qid = basename(p),
         lon = as.numeric(str_match(coord, "Point\\(([-0-9.]+) ")[, 2]),
         lat = as.numeric(str_match(coord, " ([-0-9.]+)\\)")[, 2])) |>
  group_by(qid) |> summarise(across(c(en, uk, ru, lat, lon), ~ .x[!is.na(.x)][1]),
                             mw = if (all(is.na(mw))) NA_real_ else max(mw, na.rm = TRUE),
                             n_mw_values = n_distinct(na.omit(mw)), .groups = "drop") |>
  filter(str_detect(coalesce(uk, ru, en, ""), "ТЕС|ТЕЦ|ДРЕС|ГЕС|ГАЕС|теплоелектроцентрал|ТЭС|ТЭЦ|ГРЭС|ГЭС"))

# Exclusions (logged): Crimean plants built under Russian control after 2014 are not
# part of the pre-war Ukrainian grid; implausible Wikidata MW values are flagged, not used.
crimea <- c("Q21644346", "Q48922473", "Q48922533")       # Balaklava, Tavricheskaya, Saky
implausible_mw <- c("Q56356704")                          # Shchedrivska HES: P2109 = 640 MW for a micro-hydro
wd <- wd |> filter(!qid %in% crimea) |>
  mutate(mw = if_else(qid %in% implausible_mw, NA_real_, mw))
log_gap("04_build_registry", "Wikidata MW set NA as implausible", length(implausible_mw), paste(implausible_mw, collapse = ";"))
log_gap("04_build_registry", "Wikidata UA plants with multiple MW values (max kept)", sum(wd$n_mw_values > 1), "")

# Keep major plants: >= 50 MW, or named in the supplementary list below.
# Supplementary list of major plants (hand-picked: the large TPP/CHP/HPP/PSP named in
# Ukrenergo/Ministry of Energy strike reports) whose coordinates come from uk.wikipedia.
extra_uk <- readr::read_csv(here("registry", "ua_plants_supplement.csv"), show_col_types = FALSE)$ukwiki_title
uw <- wiki_coords("uk", extra_uk, "ua_plants")
wd_keep <- wd |> filter(coalesce(mw, 0) >= 50 | uk %in% uw$t2)

# Plants in the supplementary list that Wikidata did not return at all.
missing_extra <- uw |> filter(!(t2 %in% wd$uk))
ua <- bind_rows(
  wd_keep |> left_join(uw |> select(t2, url, wlat = lat, wlon = lon), by = c("uk" = "t2")) |>
    mutate(coord_from_wiki = is.na(lat) & !is.na(wlat),
           lat = coalesce(lat, wlat), lon = coalesce(lon, wlon),
           source_url = paste0("https://www.wikidata.org/wiki/", qid),
           source_url = if_else(coord_from_wiki, paste(source_url, url, sep = "; "), source_url)) |>
    transmute(name_en = en, name_ua = uk, name_ru = ru, lat, lon, capacity = mw, source_url),
  missing_extra |> transmute(name_en = ll_en, name_ua = t2, name_ru = ll_ru, lat, lon, capacity = NA_real_,
                             source_url = url)
) |>
  mutate(country = "UA", class = "gen",
         capacity_unit = if_else(is.na(capacity), NA_character_, "MW"),
         type = case_when(str_detect(name_ua, "ГАЕС") ~ "PSP", str_detect(name_ua, "ГЕС") ~ "HPP",
                          str_detect(name_ua, "ТЕЦ|теплоелектроцентрал") ~ "CHP", TRUE ~ "TPP"),
         facility_id = paste0("UA_", type, "_", toupper(stri_trans_general(
           str_remove(name_ua, "\\s*(ТЕС|ТЕЦ|ГЕС|ГАЕС|ДРЕС|теплоелектроцентраль)\\b.*$|\\s*(ТЕС|ТЕЦ|ГЕС|ГАЕС|ДРЕС)(-?\\d+)?$"),
           "Ukrainian-Latin/BGN; Latin-ASCII")) |> str_remove_all("['ʹ]") |> str_replace_all("[^A-Z0-9]+", "_") |> str_remove("_$"),
           str_match(name_ua, "(?:ТЕЦ|ТЕС|ГЕС|№)\\s*-?\\s*(\\d+)")[, 2] |> (\(n) if_else(is.na(n), "", paste0("_", n)))()),
         capacity_note = if_else(is.na(capacity), "nameplate MW not in Wikidata", "Wikidata P2109 nominal power (MW); taken as pre-war nameplate"),
         note = NA_character_) |>
  # Same plant reached twice (Wikidata label vs uk.wikipedia title, e.g. "теплоелектроцентраль № 5"
  # vs "ТЕЦ-5"): merge, taking each field from the first non-missing row and keeping both sources.
  arrange(is.na(capacity), is.na(lat)) |>
  group_by(facility_id) |>
  summarise(across(c(name_en, name_ua, name_ru, lat, lon, capacity, country, class, capacity_unit, capacity_note, note),
                   ~ .x[!is.na(.x)][1]),
            source_url = paste(unique(na.omit(unlist(str_split(source_url, "; ")))), collapse = "; "),
            .groups = "drop")

fac <- bind_rows(ru, ua) |>
  select(facility_id, name_en, name_ua, name_ru, country, class, lat, lon, capacity, capacity_unit, source_url, capacity_note, note) |>
  arrange(country, facility_id)
dups <- fac$facility_id[duplicated(fac$facility_id)]; if (length(dups)) print(fac |> filter(facility_id %in% dups) |> select(facility_id, name_en, name_ua, capacity, source_url))
stopifnot(!anyDuplicated(fac$facility_id), all(!is.na(fac$source_url) | (is.na(fac$lat) & is.na(fac$capacity))))
fac <- fac |> mutate(source_url = coalesce(source_url, if_else(country == "RU", INTELLINEWS_URL, NA_character_)))
readr::write_csv(fac, here("registry", "facilities.csv"), na = "NA")
log_gap("04_build_registry", "facilities without coordinates", sum(is.na(fac$lat)), paste(fac$facility_id[is.na(fac$lat)], collapse = ";"))
log_gap("04_build_registry", "facilities without capacity", sum(is.na(fac$capacity)), "")
message(nrow(fac), " facilities: ", sum(fac$country == "RU"), " RU, ", sum(fac$country == "UA"), " UA; ",
        sum(is.na(fac$lat)), " lack coords, ", sum(is.na(fac$capacity)), " lack capacity")
