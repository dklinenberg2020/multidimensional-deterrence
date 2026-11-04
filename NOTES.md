# NOTES: running log

Project: an action-level dataset of strikes in the Russia–Ukraine war, with a kinetic and an economic damage per action. Full plan: https://claude.ai/artifact/LckpVR3Y9VquLcvtfECyhW

Newest entries go at the top of each section. Phase 1 started on 2026-11-03.

---

## How to run

```sh
Rscript -e 'renv::restore()'   # once, on a fresh clone (R 4.3.3; lockfile = renv.lock)
Rscript R/run_all.R            # runs 01..07 from the repo root
```

- System libraries that `sf`/`s2`/`arrow` need on Ubuntu 24.04: `libgdal-dev libgeos-dev libproj-dev libudunits2-dev libcurl4-openssl-dev libssl-dev libxml2-dev`. For building from source, `renv::restore()` also asks for `gdal-bin libabsl-dev libfribidi-dev libharfbuzz-dev libuv1-dev`. Binaries from the Posit package manager worked without them.
- `.Renviron` forces a UTF-8 locale. Without it, Rscript in a C locale corrupts Cyrillic string literals; this bit `04_build_registry.R` once.
- Large raw pulls (`data/raw/viina/`) and everything in `data/interim/` are git-ignored. They are re-created by the scripts: VIINA is pinned to a commit in `R/00_setup.R`. Small raw pulls are committed, because the live sources change daily (IntelliNews, Wikipedia, Wikidata).
- `RAW_DATE` (environment variable, default `2026-11-03`) selects the `data/raw/<source>/<date>/` folder. To re-pull, set a new date.
- `output/gap_log.csv` records every deliberate NA, with counts. Each script overwrites its own rows on each run.

## Pipeline map

| Script | Does | Main output |
|---|---|---|
| `01_ingest_viina.R` | Downloads `event_info` + `event_labels` 2022–2026 at the pinned commit, joins them, drops the low-AUC variable | `data/interim/viina_events.parquet` (591,923 events) |
| `02_size_job.R` | Monthly counts: all events, `t_property`, each actor flag | `output/monthly_counts.{csv,png}` |
| `03_dict_hits.R` | Applies `dict/econ_targets.csv` to the headlines | `output/dict_hits_by_*.csv` |
| `04_build_registry.R` | Seeds the facility registry | `registry/facilities.csv` |
| `05_russia_coverage.R` | Russia geocoding share; IntelliNews refinery-date coverage | `output/russia_share_by_year.csv`, `output/refinery_strike_coverage*.csv` |
| `06_pilot_classify_match.R` | March 2024: classify, attribute attacker, match facilities, de-duplicate | `data/interim/pilot_2024_03_{reports,strikes}.parquet`, `output/pilot_precision_sample.csv` |
| `07_pilot_score.R` | Recall against the reference list; precision from the hand labels | `output/pilot_scores.csv`, `output/pilot_recall_*.csv` |

---

## Decisions taken (Phase 1)

0. **Language** (PI, 2026-11-03). Any language is fine; use whatever is best for the task. The existing pipeline stays in R. Python is preferred for headline number extraction (casualties) and any classifier.

Each decision is provisional unless it is marked as fixed by the brief.

1. **VIINA version.** VIINA is pinned to commit `a1ad3633…` (main, 2026-10-27). I use the raw `event_info` + `event_labels` files, not the `event_1pd` one-per-day files: our own de-duplication rule has to run on raw reports.
2. **AUC filter.** VIINA's `Diagnostics/classification_report_bert.csv` is not a CSV: it is a saved GitHub HTML page (see Source quirks). The AUCs are therefore parsed from the detailed BERT table in VIINA's README at the pinned commit (`output/viina_auc.csv`). Only `t_cyber` (AUC 0.754) falls below 0.80, and it is dropped. `t_airalert` passes in that table, though it scored 0.808 in the older table.
3. **Actor flags with missing values.** A month in which more than 50% of an actor flag is NA is reported as NA, not 0 (see the quirk below).
4. **Recognised borders.** Natural Earth 1:10m admin-0 polygons are used. NE draws Crimea inside the RUS polygon, so an event counts as "in Russia" only if it is inside RUS **and not** inside UKR. Occupied territory counts as Ukraine.
5. **Dictionary format.** Each row holds two ICU regexes (`term_ua`, `term_ru`), matched against the lower-cased headline. `term_ua` is applied to `lang == "ua"` headlines and `term_ru` to `lang == "ru"`. I added a 4th column, `specific`: FALSE marks generic or ambiguous terms (e.g. "термінал", "завод", "енергосистема", "знеструмлення"), so counts can be reported with and without them. The generic "energy infrastructure/object" phrase is assigned to `gen` and outage words to `transmission`. These two assignments are judgement calls.
6. **Registry sources.**
   - Russian refineries: nameplate capacity from the IntelliNews sheet (mn t/yr × 1e6 → t/yr). Where the sheet lists conflicting values, the first, headline value is taken; the full text is kept in `capacity_note`. Coordinates come from ru.wikipedia, via the hand-made crosswalk `registry/ru_refinery_crosswalk.csv`. The Ufa group's capacity (23.4) is NA per plant, because IntelliNews does not attribute the 9.5 / 7.3 / 6.6 split to individual plants.
   - Ukrainian plants: Wikidata (P625 coordinates, P2109 nominal MW, taken as the pre-war nameplate), plus uk.wikipedia coordinates for the hand-picked list in `registry/ua_plants_supplement.csv`.
   - Exclusions: Crimean plants built after 2014 are left out (not part of the pre-war Ukrainian grid). Shchedrivska HES has P2109 = 640 MW, which is implausible for a micro-hydro, so its capacity is set to NA.
   - Two extra columns, `capacity_note` and `note`, are kept beyond the brief's schema.
7. **Pilot classification** (in `06`): a report counts as an economic strike if it has (a) a dictionary hit, AND (b) a strike cue (удар/атак/ракет/дрон/шахед/пошкод/уламк/знеструм…) OR `t_property_b == 1`, AND NOT (c) a restoration/legal/price headline without a strike cue. The target class is the most specific class hit, in the order refining > storage_export > gen > transmission > industrial.
8. **Pilot attacker.** VIINA's initiator flags are empty in 2024, so the attacker comes from a heuristic. It is UA if the headline names Russian territory, the "DNR/LNR" authorities, a Russian refinery or oil depot, or "ВСУ обстрел…"; otherwise it is RU. **This needs your review** (see Open questions).
9. **Pilot facility match.**
   - First by name: an alias regex is built from the registry stem plus a type word (ТЕС/ТЕЦ/ГЕС/НПЗ…), plus three hand aliases (ДніпроГЕС, Трипільська, Зміївська). The aliases are in `output/pilot_facility_aliases.csv`.
   - Otherwise spatially: a facility within 10 km, in the same Natural Earth admin-1 unit (Kyiv City merged into Kyiv oblast), and of the same class. The spatial match is used only for STREET/ADM3-precision geocodes.
10. **Pilot de-duplication** (fixed by the brief: same target and attacker within 24 h).
    - Target = `facility_id` if matched, else class × oblast × VIINA populated place (`geonameid`).
    - Windows are anchored at the first report of each strike, so follow-up reports cannot chain a strike past 24 h.
    - The timestamp is VIINA `date` + `time`, read as Kyiv time.
11. **Recall reference.** The energy-map.info file needs an account (see Blocked sources). In its place I compiled a provisional reference list of March 2024 attacks on energy by hand, with a source URL on every row (`data/raw/manual_reference/2026-11-03/`). It draws on Ukrenergo, DTEK and Ukrhydroenergo Telegram posts, Ministry of Energy bulletins and DiXi weekly reviews #40–44. `massive_flag = yes` marks only the attacks Ukrenergo or the Ministry called "massive": 22 and 29 March. Plants that were named as targets but whose damage was not confirmed (Kaniv, Dniester HPPs) are marked `uncertain`. Recall against energy-map itself is still to do.
    - Recall results (March 2024):
      - attack level: 2/2;
      - named registry plants: 4/7, or 2/5 counting confirmed damage only;
      - attack-date × oblast: 6/11.
    - Misses come from three sources:
      - "критична інфраструктура" (critical infrastructure) headlines are not in the dictionary;
      - plants named only days later: Zmiiv on 30 Mar, Burshtyn in a repair report on 27 Mar;
      - Ladyzhyn TPP has no coordinates.
    - **Next fix:** add the critical-infrastructure term and widen the recall window to day 0–3 for named plants. I have held this back so that the labelled precision sample stays valid.
12. **Precision labels.** I (Claude) labelled the 50-strike sample from the headline text only. These labels are not human-verified, and the file says so (`data/raw/manual_labels/2026-11-03/pilot_precision_labels.csv`).

---

## Source quirks

- **VIINA initiator flags missing in 2022–2024.** `a_rus_init`/`a_ukr_init` (and their `_b` versions) are NA for 99.4% of 2022 events and 100% of 2023–2024 events. They are populated from 2025 on. The 2022–2024 files were all coded by one model release (`bert_20250404…`), and 2025 and 2026 by later releases (`bert_20260320…`, `bert_20261027…`). Use `a_rus_b`/`a_ukr_b` ("involves") for the early period, or our own attribution.
- **VIINA source and volume break at 2025.** RIA stops in 2025 and NV restarts in 2026. Liveuamap falls from 62k reports (2023) to 3.7k (2026). Total reports fall from 260k (2022) to 42k (2026), while the `t_property` share rises from 6% to 31%. Monthly counts are **not comparable across the 2024/25 break**: the plot marks it.
- **VIINA geocodes almost nothing in Russia.** Of the 26,063 events whose coordinates fall in Russia, 23,490 (90%) have a geocoder address string that begins "Украина/Україна". These are mis-geocodes: e.g. "Украина, Киев" placed at the Moscow centroid (55.7N, 37.6E), or at 28.6N, 77.2E (Delhi). Strikes on Russian refineries are geocoded to Ukrainian namesakes, e.g. "Ильский НПЗ" placed at Kropyvnytskyi.
- **`classification_report_bert.csv`** in VIINA's repo is HTML, not CSV.
- **VIINA `time`** looks like Kyiv local publication time (DniproHES reports on 22 Mar 2024 start at 08:20). The README does not say. An earlier bug converted Kyiv timestamps to UTC dates; it is fixed in `06`.
- **Wikidata** has P2109 for most large TPPs and HPPs but not for Burshtyn, Trypillia, Prydniprovska or the pumped-storage plants (PSPs). Those capacities are NA in the registry.
- **Wikipedia API**: `prop=coordinates` returns at most 10 pages unless `colimit=max` is set. Fixed.
- **IntelliNews sheet** is updated daily. The snapshot used is the 2 Nov 2026 version, saved in `data/raw/intellinews/2026-11-03/`. The sheet notes that its strike counts are floors and that some 2026 dates "may be the same night counted twice" (Yaroslavl).

## Blocked or restricted sources (not worked around)

| Source | Status | Needed action |
|---|---|---|
| energy-map.info / map.ua-energy.org "massive strikes" (DiXi Group) | Downloading needs a registered account (Terms 5.1.1). The free page shows a "download limit" wall. The listed English file is `2024_08_26`, last updated 2024-10-01, 81 rows. | **Manual download requested.** Put the CSV/XLSX in `data/raw/energymap/<date>/`. `07` will then need a parser. |
| Kaggle "massive-missile-attacks-on-ukraine" (piterfm) | The API redirects to login; no Kaggle credentials in this environment. Third-party GitHub copies exist; not used. | **Manual download requested**, into `data/raw/kaggle_mmau/<date>/`. |
| Baker Institute dataset (Collins, refinery and energy strikes Apr 2022–Feb 2026) | bakerinstitute.org returns 403 to scripts. Reporting describes the dataset as "available upon request". | **Ask before requesting access** (brief rule). Coverage in Phase 1 uses IntelliNews only. |
| ACLED (Ukraine + Russia, and the infrastructure-tag file) | Needs an account; the infrastructure file is restricted. | Not requested: **ask first.** |
| Deep Strike (deepstrike.live) | Reachable (308 redirect) but not yet explored. | Phase 2. |
| OpenStreetMap Overpass API | The connection is reset by the egress proxy (both mirrors). | I used Wikipedia/Wikidata instead. Overpass would give better facility polygons, if network policy allows it. |

---

## Economic damage: PI decision (2026-11-03), implemented for the pilot in `R/08_pilot_econ_damage.R`

- **Named facility with capacity:** `dmg_econ = capacity / national capacity × severity weight`.
  - National denominators are in `registry/national_capacity.csv`:
    - UA: 56.1 GW installed at end-2021 (BDO 2023 report, checked in the PDF);
    - RU: 327 mn t/yr refining (IntelliNews).
  - Severity is coded from the strike's headlines on IntelliNews's 0–4 scale, taking the maximum over the strike's reports. Weights: 0 / 0.1 / 0.3 / 0.6 / 1.
  - Severity 0 means attacked but no damage reported, so `dmg_econ` = 0 (a real zero, not NA).
- **Grid strikes:** `cust_out` = the maximum number of customers or people left without power in the strike's headlines. A headline counts only if it also names an attack and does not describe restoration.
  - Kept as a separate column, because it is not in the same units as `dmg_econ`.
- **Everything else:** `dmg_econ` stays NA, and `econ_flag` gives the reason.
- **No oblast-level proxy.** The PI rejected it.
- **March 2024 pilot result (142 strikes):**
  - 13 have `dmg_econ`;
  - 6 have `cust_out` (Kharkiv 600k on 22 Mar is the largest);
  - **123 have neither.**
- **Main coverage fix:** Ukrenergo and Ministry of Energy daily bulletins report customers cut off almost every day; e.g. Odesa 195k on 25 Mar and 170k on 31 Mar, both absent from VIINA headlines. Next step: ingest those bulletins.
- **Known errors in the pilot values:**
  - Kakhovka HPP is matched from commentary, giving `dmg_econ` 0.
  - Zmiiv TPP is dated 30 Mar (the day it was reported).
  - The Donetsk 41k outage is attributed to RU, but it was a UA strike on occupied Donetsk.

## Ships: PI decision (2026-11-03), implemented whole-period in `R/09_ships.R`

PI decisions:
- Option (b): merchant-ship damage = deadweight tonnage (DWT) × severity.
- Location matters little for ships, so a ship gets a sea-area label (Black Sea, Sea of Azov, Baltic Sea, Danube, Mediterranean, Caspian) instead of an oblast.
- Warships: kinetic only (recommended, and not objected to).

Method:
- **Dictionaries.** `dict/vessel_terms.csv` sorts vessel words into classes: tanker / cargo / generic merchant / warship. `dict/econ_targets.csv` gains a `shipping` class. The pilot (06) ignores `shipping`, so the March 2024 pilot and its labelled sample are unchanged.
- **What counts as a ship strike:** a vessel word and a strike word **within 6 words** of each other. Excluded: fleet HQ and buildings, naval drones as targets, retrospectives, warnings, ship-repair yards, and courts ("суд"). Red Sea and Houthi stories are out of scope; they are dropped and logged.
- **Vessel names:** taken only when the name directly follows a vessel noun ("суховантаж MARIAM M", "пором «Славянін»"), with a stoplist for weapons and outlets.
- **De-duplication:** same vessel + attacker within 72 h for named vessels; sea area × vessel class × attacker within 24 h for unnamed ones.
- **Vessel registry:** `registry/vessels.csv` holds IMO, type, flag, DWT and a `military` flag, with a source URL per row. DWT comes mostly from public VesselFinder pages, cross-checked with news; Equasis was not used. The registry overrides the headline wording: naval auxiliaries (the Project 15310 cable ships Volga and Vyatka) count as warships, and merchant ships such as Helt count as merchant.
- **`dmg_econ_ship`** = DWT × severity weight, using the same 0–4 headline coder as plants. Ship words have been added to it ("затонуло" → 4; "влучив/попал/уразили" → 2).

Result:
- 571 ship strikes in 2022–Oct 2026: 333 warship and 238 merchant.
- Locations: Black Sea 522, Sea of Azov 29, Danube 14, Baltic 2, Mediterranean 2, Caspian 1.
- Only 15 merchant strikes name a vessel, and 14 of those have DWT.

**Precision** (`data/raw/manual_labels/2026-11-03/ship_precision_labels.csv`). I labelled 40 sampled strikes myself (an LLM reading the headline only); they are not human-verified, and were labelled before the final attacker/term fixes:
- Warships: 70% strict / 80% lenient.
- Merchant ships: 65% / 80%.
- Attacker errors among true strikes: warships 5/14 wrong (Russian strikes on Ukrainian boats; a rule was added afterwards). Merchant ships: 1/13 wrong, 5/13 missing.

Known problems:
- **VIINA dates are sometimes wrong for ships.** MJ Pinar (struck 11 Mar 2025) is dated 2022-03-12. Millennial Spirit (struck 25 Feb 2022) shows up in July 2022 retrospectives. Golden Leo carries its sinking date (26 Jul 2026), not the strike date (19 Jul). The registry `note` column records the true dates.
- **Severity is often 0 when casualties are reported** ("ударила … чотири загинули"). A casualty-based floor is needed once `dmg_kin` is built.
- **Fleet-share denominator (open).** `dmg_econ_ship` is in DWT-weighted tonnes. The proposal was "a share of the relevant fleet", and that fleet still needs choosing: e.g. Black Sea grain-corridor traffic for RU→UA, Russia's tanker/ferry fleet for UA→RU.
- **Coverage.** Most merchant strikes are unnamed ("пошкоджено цивільне судно під прапором Ліберії"). Flag + date + port could be matched to AMPU (Ukrainian Sea Ports Authority) reports to recover names.
- **Possible double counting.** A port strike that also damages a ship can appear both in the energy/economic layer (storage_export) and in the ship layer. To be resolved when the layers merge.

## Ship name recovery: PI-approved (2026-11-03)

- **AMPU (Ukrainian Sea Ports Authority) could not be used.** Its website (WordPress API; 1,473 posts) carries no per-attack vessel reports, and its per-attack posts are on Facebook, which needs a login, so it was not scraped. It does provide an aggregate benchmark: **172 civilian vessels damaged or partially destroyed, Feb 2022–Apr 2026** (USPA head, 24 Apr 2026, on uspa.gov.ua).
- **Replacement method.** I researched 83 unnamed merchant strikes that have a flag or port clue against the maritime trade press and Ukrainian news (gCaptain, Maritime Executive, Marine Insight, Maritime Optima, Baird, BlackSeaNews, Kyiv Independent, Ukrinform, Militarnyi, Interfax-Ukraine, kmu.gov.ua). Particulars come from public VesselFinder pages. A name is kept only where an opened source ties the vessel to the event.
  - Raw research: `data/raw/ship_identification/2026-11-03/batch{1,2}.csv`.
  - `py/build_ship_ids.py` turns it into `registry/ship_strike_ids.csv` and adds the new vessels to `registry/vessels.csv`. It runs after `09_ships.R` and its outputs are then read by `09`; this is a curation step, not part of `run_all`.
- **Result.** 48 of the 83 rows were identified, with 32 new vessels. Researcher-stated and same-vessel-within-3-days duplicates (30 rows) are excluded. 8 rows were not ship strikes, e.g. the Orlivka checkpoint and storm-sunk Volgoneft tankers; 5 are unclear.
  - Merchant strikes with `dmg_econ_ship`: **14 → 35**.
  - 23 researched strikes are real but unnamed in every source; 140 unnamed strikes remain unresearched (no flag or port in the headline).
- **VIINA date errors found:** five "2022" stories actually happened in 2023–2025. Also Millennial Spirit (Feb 2022), shown in July 2022, and Golden Leo, shown on its sinking date. All are corrected via `actual_strike_date`.
- **Attacker corrections:** 9, e.g. Golden Leo and Emil (RU, not UA), and the Kerch terminal strike (UA). The NS Pride attacker is unknown (an unidentified explosive device).
- **Open:**
  - Helt: the cause is disputed (mine vs missile), and the headline-based attacker is UA, which is likely wrong.
  - Several DWTs rest on a database name match rather than an IMO given in the news (noted per vessel).
  - Tedy's IMO is unconfirmed.

## Ship layer: full review + fleet-share denominator (PI-approved 2026-11-04)

**Full review.** The remaining 140 unnamed merchant strikes were checked against web sources in four batches (`data/raw/ship_identification/2026-11-03/review1-4.csv`), applying the same rules as the identification batches. `py/build_ship_ids.py` merges all six research files.
- Duplicates across files are resolved explicitly, e.g. the 25–26 Dec 2025 Odesa/Mykolaiv attack appeared in all four review files.
- Rows marked military move to the warship layer (`id_status = warship`).

**Result: every merchant strike is now reviewed.**
- 103 unique confirmed merchant-ship strike events, out of 235 machine-extracted. The rest are 67 duplicates, 53 not ship strikes and 12 unclear.
- 54 of the 103 name a vessel; 45 have `dmg_econ_ship`.
- By year (RU / UA): 2022 5/1, 2023 4/1, 2024 8/3, 2025 8/2 (+1 unknown attacker), 2026 40/30.
- About **55% of the raw machine-extracted merchant "strikes" were noise.** The raw ship layer must not be used unreviewed.

**Recall check.** USPA counts 172 civilian vessels damaged, Feb 2022–Apr 2026. We have about 65 RU strike events on merchant ships in the same span; some events hit several ships, and USPA also counts barges and pontoons.
- VIINA headlines therefore capture well under half of the damaged civilian vessels.
- A dedicated maritime source is needed for completeness, e.g. BlackSeaNews monitoring or the Odesa "Institute" yearly tallies (39 ships damaged in 2025).

**Fleet-share denominator.** `dmg_econ_ship_share = DWT × severity ÷ (annual seaborne cargo of the target side ÷ 12)`. The target side's ports are Ukrainian seaports for RU strikes, and all Russian seaports for UA strikes, since shadow-fleet tankers are hit outside the Black Sea too.
- Sources and derivations: `registry/port_throughput.csv`.
- 2026 carries the 2025 figure forward, flagged.

**Warships were not reviewed.** 332 warship strikes are still raw machine extraction, with earlier sampled precision of about 70%. They are kinetic only, so they matter once `dmg_kin` is built.

## Proposal sent to the PI (2026-11-03): action mapping and kinetic damage. Not implemented; economic part decided above.

- **Hierarchy:** report → strike (built: same target and attacker within 24 h) → action → episode (lull of 48 h or more).
- **Action:** a run of strikes by one side. It ends when the other side strikes, or after a gap of **g = 12 h** by the same side. The 12 h covers news-publication lag on overnight waves. Overlapping RU/UA actions are allowed and ordered by start time; `gap_prev` may then be negative. Alternative: group strikes by RU "attack night", using the Ukrainian Air Force daily tallies as the backbone.
- **`dmg_kin`:** death counts extracted from headlines, taking the maximum across a strike's reports. Where no count is reported, a modelled expected value is filled in (weapon × target × location) and flagged as modelled. The action value is the sum over its strikes. Cross-checks: OHCHR monthly totals, and ACLED if access is approved.
- **`dmg_econ`:** capacity as a share of national capacity × a severity weight. IntelliNews's 0–4 damage scale maps to 0 / 0.1 / 0.3 / 0.6 / 1; RU→UA severity would be coded from the reports. Robustness check: capacity × days offline. Unnamed grid strikes stay NA, or are measured by customers cut off, or by an oblast proxy (PI to decide).

## Open questions / decisions for the PI

0. **Ships:** (a) denominator for "share of the relevant fleet"; (b) recover names for unnamed merchant ships from AMPU reports?

1. ~~Economic damage measure~~: decided 2026-11-03 (see above). Remaining question: ingest Ukrenergo/Ministry bulletins for customers cut off? The leading candidate is capacity offline × severity. The Phase 1 registry supports capacity for RU refineries (t/yr) and UA plants (MW). Severity has no source yet for RU→UA; IntelliNews has a 0–4 damage scale for UA→RU.
2. **Action-merging rule** (stop-and-ask). Not implemented. The pilot stops at strike level.
3. **UA→RU needs a separate source.** VIINA puts 1.5% of IntelliNews refinery strike-dates within 25 km of the refinery (±1 day). A text search finds 23% (3.7% in 2024, 31% in 2026). Proposal: build UA→RU strikes from IntelliNews (+ Baker, if you approve the request, + Deep Strike) and use VIINA only for RU→UA. Approve?
4. **Attacker attribution for 2022–2024.** VIINA's initiator flags are empty, so attacker must come from our own rule or classifier. The keyword heuristic is wrong on 2 of 38 true strikes in the precision sample; both are strikes in occupied Horlivka attributed to RU. Options: (a) refine the keywords; (b) use a control map (VIINA `control` files) plus target location; (c) train a classifier on the 2025+ labelled VIINA data. I recommend (b)+(c).
5. **Occupied-territory strikes** (UA strikes on Donetsk, Horlivka, Crimea). Attacker = UA, but are these "UA→RU" actions or a separate category?
6. **Generic energy headlines** ("пошкоджено об'єкт енергетичної інфраструктури") carry no facility. Should they become strikes with `facility_id` NA and an oblast-level capacity proxy, or be held back until a named report matches them?
7. **ZNPP news.** АЕС/АЭС is the second-largest dictionary term (4,187 hits), mostly about the occupied ZNPP. Should ZNPP be excluded outright, or require a strike cue plus ZNPP-specific terms?
8. **VIINA timestamp timezone.** It looks like Kyiv local time. Confirm with the VIINA authors?
9. **Recall reference.** Can you download energy-map.info (and Kaggle) manually? The provisional list is built from news and official statements.
10. **Human check of precision labels.** The 50 labels are mine; a human pass is needed before the precision figure is quoted.
