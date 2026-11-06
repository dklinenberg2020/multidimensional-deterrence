# 11_pilot_actions.R -- March 2024 pilot: strikes -> actions -> episodes (PI decisions 2026-11-06).
#  Scope (PI): long-range strikes only (missile / drone / air strike wording; artillery excluded),
#    plus every economic-target strike (06/08) and every reviewed ship strike (09), whatever the weapon.
#  Attacker: territorial-control + text rule (10_attacker.R).
#  dmg_kin: deaths_reported (max over a strike's headlines); if none, dmg_kin_model (see below), flagged.
#  Actions: per attacker, a new action starts after a gap >= 12 h, or when the other side struck in
#    between -- unless the gap is < WAVE_H (an opponent strike inside an ongoing wave does not split it).
#  Episodes: a new episode after a lull >= 48 h with no action by either side.
# Outputs: data/final/pilot_2024_03_strikes.csv, data/final/pilot_2024_03_actions.csv, output/pilot_actions_summary.csv
source(here::here("R", "00_setup.R"))
PS <- ymd("2024-03-01"); PE <- ymd("2024-03-31")
GAP_H <- 12; WAVE_H <- 3; LULL_H <- 48     # WAVE_H is an implementation detail -- flagged in NOTES

ev <- arrow::read_parquet(interim("viina_events.parquet")) |> filter(date >= PS, date <= PE)
at <- arrow::read_parquet(interim("viina_attacker.parquet"))
# Sources that publish dates only stamp every report 00:00 (liveuamap, pravdaua, liga, meduza in 2024):
# their reports get ts = NA (day precision) and never set an action's clock time.
all_ev <- arrow::read_parquet(interim("viina_events.parquet"), col_select = c(source, time))
date_only_sources <- all_ev |> group_by(source) |> summarise(z = mean(time == "00:00", na.rm = TRUE)) |>
  filter(z > 0.95) |> pull(source)
rm(all_ev)
ev <- ev |> left_join(at, by = "event_id") |>
  mutate(tl = stri_trans_tolower(text),
         timed = !(source %in% date_only_sources) & !is.na(time) & time != "",
         ts = if_else(timed, ymd_hm(paste(date, time), tz = "Europe/Kyiv", quiet = TRUE), as.POSIXct(NA, tz = "Europe/Kyiv")))

# ---- deaths from headlines ------------------------------------------------------
words <- c("один"=1,"одна"=1,"двоє"=2,"двое"=2,"два"=2,"дві"=2,"две"=2,"троє"=3,"трое"=3,"три"=3,"четверо"=4,"чотири"=4,"четыре"=4,
           "п.ятеро"=5,"пятеро"=5,"шестеро"=6,"семеро"=7,"восьмеро"=8,"дев.ятеро"=9,"девятеро"=9,"десятеро"=10)
death_w <- "загин\\w*|загибл\\w*|погиб\\w*|вбит\\w*|убит\\w*|жертв\\w*|смерт\\w*"
num_rx <- paste0("(\\d+|", paste(names(words), collapse = "|"), ")")
deaths_of <- function(t) {
  if (is.na(t)) return(NA_real_)
  if (stri_detect_regex(t, "без жертв|обійшлося без|обошлось без|никто не (погиб|пострадал)|ніхто не (загинув|постраждав)|не постраждав|не пострадал")) return(0)
  if (!stri_detect_regex(t, death_w)) return(NA_real_)
  # "<n> ... загинули" or "загинули <n>" within 4 words
  t <- stri_replace_all_regex(t, "\\d+-?(річн|летн|рок|год|лет)\\w*", " ")          # ages / durations
  t <- stri_replace_all_regex(t, "\\d+\\s+(\\w+\\s+){0,1}(поранен|ранен|постражд|пострада|травм)\\w*", " ")  # injuries
  m1 <- stri_match_all_regex(t, paste0(num_rx, "\\s+(?:\\w+\\s+){0,3}?(?:", death_w, ")"))[[1]][, 2]
  m2 <- stri_match_all_regex(t, paste0("(?:", death_w, ")\\s+(?:до\\s+)?", num_rx, "\\b"))[[1]][, 2]
  m <- c(m1, m2); m <- m[!is.na(m)]
  if (!length(m)) return(if (stri_detect_regex(t, "загинув|загинула|погиб |погибла|вбит[аоий]? |убит[аоый]? ")) 1 else NA_real_)
  v <- suppressWarnings(as.numeric(m)); w <- words[stri_replace_all_regex(m[is.na(v)], "[ʼ'’]", ".")]
  v[is.na(v)] <- w
  v <- v[!is.na(v) & v < 1000]     # guard against years / casualty totals for the whole war
  if (length(v)) max(v) else NA_real_
}
ev <- ev |> mutate(deaths = map_dbl(tl, deaths_of))

# ---- 1. kinetic long-range strike reports ---------------------------------------------
# Long-range strike report: a weapon/attack phrase, not a front-line digest, not commentary.
lr_rx <- paste0("ракетн\\w* (удар|атак|обстріл|обстрел)|ракет\\w* (влучил|попал|вдарил|ударил)|балісти\\w*|баллисти\\w*|",
                "шахед|shahed|герань|кинджал|кинжал|іскандер|искандер|х-101|х-22|х-59|калібр|калибр|циркон|с-300|",
                "атак\\w* (дрон|безпілот|беспилот|бпла|ударн)|(дрон|безпілот|беспилот|бпла)\\w* (атакува|атакова|вдари|удари|влучи|попал|уразил|поразил)|",
                "авіаудар|авиаудар|авіабомб|авиабомб|\\bкаб\\b|кабами|\\bфаб-|storm shadow|atacms|нептун|flamingo|фламінго|",
                "масован\\w* (атак|удар|обстріл)|комбінован\\w* (атак|удар)")
front_rx <- "сіверщин|слобожанщин|за добу|обстрілю\\w*|напрямку|направлении|fpv|фпв|скид|передов|позиці|позици|штурм|окоп|бліндаж|блиндаж|ппо збил|ппо знищ|збито|сбито|сбили|знищено \\d+|уничтожен\\w* \\d+"
noise_rx <- "тривог|тревог|прощаються|похорон|затрима\\w*|задержа\\w*|уламки однієї|історія|история|виставк|пообіця|пообеща|розповів|рассказал|експерт|эксперт|аналітик|аналитик|можуть|может|план|навчанн|учени|суд\\b|санкц|виявили (тіла|останки)|обнаружили (тела|останки)"
ev <- ev |> mutate(lr = stri_detect_regex(tl, lr_rx), front = stri_detect_regex(tl, front_rx), noise = stri_detect_regex(tl, noise_rx))
kin <- ev |> filter(strike_like, lr, !front, !noise, !is.na(attacker_rule),
                    # long-range UA strikes are into Russia / Crimea / occupied rear: require the text cue for UA
                    attacker_rule == "RU" | attacker_basis == "text") |>
  mutate(attacker = attacker_rule)

# ---- 2. economic strikes (06/08) and ship strikes (09) ---------------------------------
econ <- arrow::read_parquet(interim("pilot_2024_03_strikes_econ.parquet"))
econ_ev <- econ |> select(strike_id, event_ids) |> separate_rows(event_ids, sep = ";") |> rename(event_id = event_ids)
# attacker for economic strikes now also from the rule (majority of its reports; old keyword attacker as fallback)
econ_att <- econ_ev |> left_join(at |> select(event_id, attacker_rule), by = "event_id") |>
  group_by(strike_id) |> summarise(att_rule = { tb <- table(attacker_rule); if (length(tb)) names(sort(tb, decreasing = TRUE))[1] else NA_character_ }, .groups = "drop")
econ_deaths <- econ_ev |> left_join(ev |> select(event_id, deaths), by = "event_id") |>
  group_by(strike_id) |> summarise(deaths_reported = if (all(is.na(deaths))) NA_real_ else max(deaths, na.rm = TRUE), .groups = "drop")
econ_time <- econ_ev |> left_join(ev |> select(event_id, ts, date), by = "event_id") |>
  group_by(strike_id) |> summarise(start = if (all(is.na(ts))) as.POSIXct(NA, tz = "Europe/Kyiv") else min(ts, na.rm = TRUE),
                                   day = min(date), .groups = "drop")
econ_s <- econ |> select(-date) |> left_join(econ_att, by = "strike_id") |> left_join(econ_deaths, by = "strike_id") |>
  left_join(econ_time, by = "strike_id") |>
  mutate(attacker = coalesce(att_rule, attacker), source_layer = "economic") |>
  transmute(strike_id, start, day, attacker, target_class, facility_id, location = oblast, n_reports, n_sources,
            deaths_reported, dmg_econ, cust_out, dmg_econ_ship_share = NA_real_, match_conf, source_layer, headline)

ships <- readr::read_csv(out("ship_strikes.csv"), show_col_types = FALSE) |>
  filter(date >= PS, date <= PE, !id_status %in% c("duplicate", "not_ship_strike", "unclear")) |>
  mutate(hm = substr(as.character(time), 1, 5),
         start = if_else(hm == "00:00" | is.na(hm), as.POSIXct(NA, tz = "Europe/Kyiv"), ymd_hm(paste(date, hm), tz = "Europe/Kyiv", quiet = TRUE)),
         day = as.Date(date), source_layer = "ship") |>
  transmute(strike_id, start, day, attacker, target_class, facility_id = vessel_id, location, n_reports, n_sources,
            deaths_reported = NA_real_, dmg_econ = NA_real_, cust_out = NA_real_, dmg_econ_ship_share,
            match_conf = NA_character_, source_layer, headline)
ship_ev <- arrow::read_parquet(interim("ship_reports.parquet"), col_select = "event_id")$event_id

# kinetic strikes exclude reports already used by economic or ship strikes (no double counting)
kin <- kin |> filter(!event_id %in% c(econ_ev$event_id, ship_ev)) |>
  mutate(target_key = paste(attacker, coalesce(as.character(geonameid), "NA"), sep = "|")) |>
  mutate(tclust = coalesce(ts, as.POSIXct(paste(date, "12:00"), tz = "Europe/Kyiv"))) |>   # day-only reports clustered at midday
  arrange(target_key, tclust) |>
  group_by(target_key) |>
  group_modify(function(d, k) { sid <- integer(nrow(d)); cur <- 0L; t0 <- as.POSIXct(NA)
    for (i in seq_len(nrow(d))) { if (is.na(t0) || as.numeric(difftime(d$tclust[i], t0, units = "hours")) > 24) { cur <- cur + 1L; t0 <- d$tclust[i] }; sid[i] <- cur }
    d$k <- sid; d }) |> ungroup()
kin_s <- kin |> group_by(target_key, k) |>
  summarise(strike_id = sprintf("K2403_%s_%02d", str_replace_all(first(target_key), "[^A-Za-z0-9]+", "_"), first(k)),
            start = if (all(is.na(ts))) as.POSIXct(NA, tz = "Europe/Kyiv") else min(ts, na.rm = TRUE),
            day = min(date), attacker = first(attacker), location = first(ADM1_NAME), facility_id = NA_character_,
            n_reports = n(), n_sources = n_distinct(source),
            deaths_reported = if (all(is.na(deaths))) NA_real_ else max(deaths, na.rm = TRUE),
            casualty_flag = any(t_civcas_b == 1 | t_milcas_b == 1), headline = first(text), .groups = "drop") |>
  mutate(target_class = "kinetic", dmg_econ = NA_real_, cust_out = NA_real_, dmg_econ_ship_share = NA_real_,
         match_conf = NA_character_, source_layer = "kinetic") |>
  select(-target_key, -k)

strikes <- bind_rows(econ_s, ships, kin_s) |> filter(!is.na(attacker), !is.na(day)) |>
  mutate(time_precision = if_else(is.na(start), "day", "minute")) |>
  mutate(casualty_flag = coalesce(casualty_flag, !is.na(deaths_reported) & deaths_reported > 0))

# ---- dmg_kin: reported, else modelled (two-part, provisional) --------------------------------
# Strikes whose headlines report casualties but no number -> mean reported deaths of strikes with a
# number (same attacker); strikes with no casualty mention -> 0. Both flagged in dmg_kin_basis.
m_att <- strikes |> filter(!is.na(deaths_reported), deaths_reported > 0) |> group_by(attacker) |>
  summarise(mean_deaths_if_any = mean(deaths_reported), n_basis = n(), .groups = "drop")
pooled <- strikes |> filter(!is.na(deaths_reported), deaths_reported > 0) |> summarise(m = mean(deaths_reported)) |> pull(m)
# fewer than 10 strikes with a reported count for a side -> use the pooled mean (flagged in NOTES)
m_att <- tibble(attacker = unique(strikes$attacker)) |> left_join(m_att, by = "attacker") |>
  mutate(mean_deaths_if_any = if_else(coalesce(n_basis, 0L) < 10L, pooled, mean_deaths_if_any))
strikes <- strikes |> left_join(m_att, by = "attacker") |>
  mutate(dmg_kin_model = case_when(!is.na(deaths_reported) ~ NA_real_,
                                   casualty_flag ~ mean_deaths_if_any, TRUE ~ 0),
         dmg_kin = coalesce(deaths_reported, dmg_kin_model),
         dmg_kin_basis = case_when(!is.na(deaths_reported) ~ "reported",
                                   casualty_flag ~ "modelled: casualties mentioned, no count",
                                   TRUE ~ "modelled: no casualties mentioned (0)")) |>
  select(-mean_deaths_if_any, -n_basis)

# ---- actions ---------------------------------------------------------------------------
# Stage 1: minute-precision strikes define actions (12 h gap / opponent-in-between rule).
# Stage 2: a day-precision strike joins the same-attacker action that spans or touches its Kyiv date
#          (nearest by start if several); otherwise it forms its own day-precision action.
tm <- strikes |> filter(time_precision == "minute") |> arrange(start, strike_id)
opp_between <- function(att, t_prev, t_now) any(tm$attacker != att & tm$start > t_prev & tm$start < t_now)
tm$action_k <- NA_integer_
for (a in unique(tm$attacker)) {
  idx <- which(tm$attacker == a); cur <- 0L; tprev <- as.POSIXct(NA)
  for (i in idx) {
    g <- if (is.na(tprev)) Inf else as.numeric(difftime(tm$start[i], tprev, units = "hours"))
    if (g >= GAP_H || (g >= WAVE_H && opp_between(a, tprev, tm$start[i]))) cur <- cur + 1L
    tm$action_k[i] <- cur; tprev <- tm$start[i]
  }
}
tm <- tm |> mutate(action_id = sprintf("A2403_%s_%03d", attacker, action_k))
spans <- tm |> group_by(action_id, attacker) |>
  summarise(d0 = as.Date(min(start), tz = "Europe/Kyiv"), d1 = as.Date(max(start), tz = "Europe/Kyiv"), t0 = min(start), .groups = "drop")
dy <- strikes |> filter(time_precision == "day")
dy$action_id <- map2_chr(dy$attacker, dy$day, function(a, d) {
  c <- spans |> filter(attacker == a, d0 <= d, d1 >= d)
  if (!nrow(c)) c <- spans |> filter(attacker == a, abs(as.numeric(d0 - d)) <= 0 | abs(as.numeric(d1 - d)) <= 0)
  if (nrow(c)) c$action_id[which.min(abs(as.numeric(difftime(c$t0, as.POSIXct(paste(d, "12:00"), tz = "Europe/Kyiv")))))] else NA_character_
})
nd <- dy |> filter(is.na(action_id)) |> distinct(attacker, day) |> arrange(day) |>
  group_by(attacker) |> mutate(action_id = sprintf("A2403_%s_D%02d", attacker, row_number())) |> ungroup()
dy <- dy |> left_join(nd |> rename(aid2 = action_id), by = c("attacker", "day")) |> mutate(action_id = coalesce(action_id, aid2)) |> select(-aid2)
strikes <- bind_rows(tm |> select(-action_k), dy) |>
  mutate(start_sort = coalesce(start, as.POSIXct(paste(day, "12:00"), tz = "Europe/Kyiv")))
actions <- strikes |> group_by(action_id, attacker) |>
  summarise(start_precision = if (all(is.na(start))) "day" else "minute",
            end = if (all(is.na(start))) max(start_sort) else max(start, na.rm = TRUE),
            start = if (all(is.na(start))) min(start_sort) else min(start, na.rm = TRUE),
            n_strikes = n(), n_day_precision = sum(time_precision == "day"),
            has_econ = any(source_layer %in% c("economic", "ship") & target_class != "warship"),
            has_kin = any(source_layer == "kinetic" | target_class == "warship" | dmg_kin > 0),
            dmg_kin = sum(dmg_kin), dmg_kin_reported = sum(deaths_reported, na.rm = TRUE),
            dmg_econ = sum(dmg_econ, na.rm = TRUE), n_econ_capacity = sum(!is.na(dmg_econ)),
            dmg_econ_ship_share = sum(dmg_econ_ship_share, na.rm = TRUE), cust_out = sum(cust_out, na.rm = TRUE),
            .groups = "drop") |>
  mutate(action_type = case_when(has_econ & has_kin ~ "both", has_econ ~ "economic", TRUE ~ "kinetic")) |>
  arrange(start) |>
  mutate(action_seq = row_number(),
         prev_end = lag(cummax(as.numeric(end))),
         gap_prev = round((as.numeric(start) - prev_end) / 3600, 1),
         episode_id = cumsum(is.na(gap_prev) | gap_prev >= LULL_H)) |>
  select(action_seq, action_id, attacker, start, end, start_precision, n_strikes, n_day_precision, action_type, dmg_kin, dmg_kin_reported,
         dmg_econ, n_econ_capacity, dmg_econ_ship_share, cust_out, episode_id, gap_prev)

dir.create(here("data", "final"), showWarnings = FALSE)
readr::write_csv(strikes |> select(strike_id, action_id, day, start, time_precision, attacker, source_layer, target_class, facility_id, location,
                                   n_reports, n_sources, deaths_reported, dmg_kin_model, dmg_kin, dmg_kin_basis,
                                   dmg_econ, cust_out, dmg_econ_ship_share, match_conf, headline),
                 here("data", "final", "pilot_2024_03_strikes.csv"))
readr::write_csv(actions |> mutate(across(c(start, end), ~ format(.x, "%Y-%m-%d %H:%M", tz = "Europe/Kyiv"))),
                 here("data", "final", "pilot_2024_03_actions.csv"))
summ <- actions |> group_by(attacker, action_type) |>
  summarise(n_actions = n(), n_strikes = sum(n_strikes), dmg_kin = sum(dmg_kin), dmg_kin_reported = sum(dmg_kin_reported),
            dmg_econ = sum(dmg_econ), cust_out = sum(cust_out), .groups = "drop")
readr::write_csv(summ, out("pilot_actions_summary.csv"))
log_gap("11_pilot_actions", "pilot strikes with modelled dmg_kin", sum(strikes$dmg_kin_basis != "reported"), "see dmg_kin_basis")
message(sprintf("%d strikes (%s) -> %d actions (%d RU, %d UA), %d episodes", nrow(strikes),
                paste(names(table(strikes$source_layer)), table(strikes$source_layer), collapse = ", "),
                nrow(actions), sum(actions$attacker == "RU"), sum(actions$attacker == "UA"), max(actions$episode_id)))
print(summ); print(table(strikes$dmg_kin_basis)); print(m_att)
