# 05_russia_coverage.R -- (a) share of VIINA events geocoded inside Russia's
# internationally recognised borders; (b) share of IntelliNews dated refinery strikes
# with any VIINA event within 25 km on the strike date (and +/- 1 day).
# Outputs: output/russia_share_by_year.csv, output/refinery_strike_coverage.csv,
#          output/refinery_strike_coverage_summary.csv
source(here::here("R", "00_setup.R"))
pacman::p_load(rnaturalearth)
sf_use_s2(TRUE)

ev <- arrow::read_parquet(interim("viina_events.parquet"),
                          col_select = c(event_id, date, lat, lon, address, ADM1_NAME, GEO_PRECISION, text, t_property_b))

# Internationally recognised borders: Natural Earth 1:10m admin-0 countries.
# Natural Earth's default (de facto) layer may draw Crimea inside Russia, so an event
# counts as "Russia" only if it is inside RUS AND not inside UKR; we also report
# occupied Crimea separately by checking against UKR alone.
w   <- rnaturalearth::ne_countries(scale = 10, returnclass = "sf")
rus <- w |> filter(adm0_a3 == "RUS") |> st_geometry() |> st_union()
ukr <- w |> filter(adm0_a3 == "UKR") |> st_geometry() |> st_union()
crimea_in_ne_rus <- lengths(st_intersects(st_sfc(st_point(c(34.1, 44.95)), crs = 4326), rus)) > 0
message("Natural Earth draws Simferopol inside RUS polygon: ", crimea_in_ne_rus)

pts <- st_as_sf(ev |> filter(!is.na(lat)), coords = c("lon", "lat"), crs = 4326, remove = FALSE)
in_rus <- lengths(st_intersects(pts, rus)) > 0
in_ukr <- lengths(st_intersects(pts, ukr)) > 0
ev_geo <- pts |> st_drop_geometry() |>
  mutate(in_russia_intl = in_rus & !in_ukr, in_ukraine_intl = in_ukr,
         addr_ukraine = str_detect(address, "^(Украина|Україна)"),  # VIINA address string
         year = year(date))

# Events whose coordinates fall in Russia but whose geocoder address string begins
# "Украина/Україна" are likely mis-geocodes (e.g. "Украина, Киев" placed at 55.4N 42.3E);
# reported separately and excluded from the "clean" Russia share.
share <- ev_geo |>
  group_by(year) |>
  summarise(n = n(), n_russia = sum(in_russia_intl), share_russia = mean(in_russia_intl),
            n_ukraine = sum(in_ukraine_intl), n_other = sum(!in_russia_intl & !in_ukraine_intl),
            n_russia_ukr_address = sum(in_russia_intl & addr_ukraine, na.rm = TRUE),
            n_russia_property = sum(in_russia_intl & t_property_b == 1), .groups = "drop") |>
  mutate(share_russia_clean = (n_russia - n_russia_ukr_address) / n) |>
  bind_rows(ev_geo |> summarise(year = NA_integer_, n = n(), n_russia = sum(in_russia_intl),
                                share_russia = mean(in_russia_intl), n_ukraine = sum(in_ukraine_intl),
                                n_other = sum(!in_russia_intl & !in_ukraine_intl),
                                n_russia_ukr_address = sum(in_russia_intl & addr_ukraine, na.rm = TRUE),
                                n_russia_property = sum(in_russia_intl & t_property_b == 1)) |>
              mutate(share_russia_clean = (n_russia - n_russia_ukr_address) / n))
readr::write_csv(share, out("russia_share_by_year.csv"))
print(share)

# Precision of geocodes inside Russia
print(ev_geo |> filter(in_russia_intl) |> count(GEO_PRECISION) |> mutate(p = n / sum(n)))

# ---- (b) refinery strike-date coverage --------------------------------------
fac <- readr::read_csv(here("registry", "facilities.csv"), show_col_types = FALSE)
cw  <- readr::read_csv(here("registry", "ru_refinery_crosswalk.csv"), show_col_types = FALSE)
inn <- readr::read_csv(file.path(raw_dir("intellinews"), "refineries.csv"), skip = 4,
                       show_col_types = FALSE, col_types = cols(.default = "c")) |>
  filter(!is.na(Refinery), !is.na(Strikes))

strikes <- inn |>
  transmute(Refinery, d = str_split(`Strike dates`, ";\\s*")) |> unnest(d) |>
  mutate(strike_date = dmy(str_trim(d), quiet = TRUE)) |>
  filter(!is.na(strike_date)) |> select(-d) |>
  # Ufa group = three plants: use all three coordinates (an event near any counts)
  inner_join(cw |> select(facility_id, intellinews_name), by = c("Refinery" = "intellinews_name"), relationship = "many-to-many") |>
  left_join(fac |> select(facility_id, lat, lon), by = "facility_id")
log_gap("05_russia_coverage", "IntelliNews strike-dates at facilities with no coordinates (dropped)",
        n_distinct(strikes |> filter(is.na(lat)) |> transmute(paste(Refinery, strike_date))),
        paste(unique(strikes$Refinery[is.na(strikes$lat)]), collapse = ";"))
strikes <- strikes |> filter(!is.na(lat))

ev_ru <- ev_geo |> filter(in_russia_intl) |> select(event_id, date, lat, lon, text, t_property_b)
ev_ru_sf <- st_as_sf(ev_ru, coords = c("lon", "lat"), crs = 4326)
st_sf  <- st_as_sf(strikes |> distinct(facility_id, lat, lon), coords = c("lon", "lat"), crs = 4326)
near <- st_is_within_distance(st_sf, ev_ru_sf, dist = 25000)
near_tbl <- tibble(facility_id = st_sf$facility_id, idx = near) |> unnest(idx) |>
  mutate(event_id = ev_ru$event_id[idx], ev_date = ev_ru$date[idx],
         ev_text = ev_ru$text[idx], ev_property = ev_ru$t_property_b[idx]) |> select(-idx)

cov <- strikes |>
  left_join(near_tbl, by = "facility_id", relationship = "many-to-many") |>
  mutate(lag = as.integer(ev_date - strike_date)) |>
  group_by(Refinery, strike_date) |>
  summarise(any_same_day = any(lag == 0, na.rm = TRUE),
            any_pm1      = any(abs(lag) <= 1, na.rm = TRUE),
            n_events_pm1 = sum(abs(lag) <= 1, na.rm = TRUE),
            any_refinery_word_pm1 = any(abs(lag) <= 1 & str_detect(stri_trans_tolower(coalesce(ev_text, "")), "нпз|нефтеперераб|нафтоперероб"), na.rm = TRUE),
            example = ev_text[abs(lag) <= 1 & !is.na(lag)][1],
            .groups = "drop") |>
  mutate(year = year(strike_date))
# Text-based coverage (location-free): any VIINA headline within +/-1 day that names
# a refinery/oil facility AND the plant's place (place_regex in the crosswalk).
oilw <- "нпз|нефтеперераб|нафтоперероб|нефтебаз|нафтобаз|\\bнефт|\\bнафт"
ev_oil <- ev |> mutate(tl = stri_trans_tolower(text)) |> filter(str_detect(tl, oilw)) |> select(date, tl)
place <- cw |> filter(!is.na(intellinews_name)) |> group_by(intellinews_name) |> summarise(rx = first(place_regex))
cov <- cov |> left_join(place, by = c("Refinery" = "intellinews_name")) |>
  mutate(text_hit_pm1 = map2_lgl(strike_date, rx, function(d, r) {
           x <- ev_oil$tl[abs(as.integer(ev_oil$date - d)) <= 1]
           length(x) > 0 && !is.na(r) && any(stri_detect_regex(x, r)) }),
         any_oil_headline_pm1 = map_lgl(strike_date, ~ any(abs(as.integer(ev_oil$date - .x)) <= 1))) |>
  select(-rx)
readr::write_csv(cov, out("refinery_strike_coverage.csv"))

summ <- bind_rows(cov |> group_by(year) |> summarise(n_strike_dates = n(),
                    share_same_day = mean(any_same_day), share_pm1 = mean(any_pm1),
                    share_pm1_refinery_word = mean(any_refinery_word_pm1),
                    share_text_pm1 = mean(text_hit_pm1), share_any_oil_headline_pm1 = mean(any_oil_headline_pm1), .groups = "drop"),
                  cov |> summarise(year = NA_integer_, n_strike_dates = n(),
                    share_same_day = mean(any_same_day), share_pm1 = mean(any_pm1),
                    share_pm1_refinery_word = mean(any_refinery_word_pm1),
                    share_text_pm1 = mean(text_hit_pm1), share_any_oil_headline_pm1 = mean(any_oil_headline_pm1)))
readr::write_csv(summ, out("refinery_strike_coverage_summary.csv"))
print(summ)
