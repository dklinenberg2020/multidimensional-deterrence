# Phase 1 report: Russia–Ukraine action-level damage dataset

2026-11-03 · VIINA commit `a1ad363` (27 Oct 2026) · Details, decisions and source quirks are in `NOTES.md`.

## 1. Event counts (VIINA, 24 Feb 2022 – 31 Oct 2026)

- **Total:** 591,923 raw event reports. Of these, 52,174 have `t_property` = 1.
- **By year:** 2022: 259,851 · 2023: 141,593 · 2024: 97,885 · 2025: 50,490 · 2026: 42,104.
- **March 2024 (pilot month):** 10,148 reports, 991 with `t_property` = 1.
- **Initiator flags (`a_rus_init`, `a_ukr_init`) are unpopulated from May 2022 to Dec 2024.** In 2025–26 they run at about 1,000–2,000 RU-initiated and 200–480 UA-initiated reports a month. Attacker attribution for 2022–24 has to come from our own rule.
- **Structural break at 2025** (sources and classifier version change). Volume falls about 5×, while the `t_property` share rises from 6% to 31%. Counts are not comparable across the break.
- Files: `output/monthly_counts.csv` and `output/monthly_counts.png`.

## 2. Coverage of Russian territory

- **Geocodes inside Russia.** 4.4% of events have coordinates inside Russia's internationally recognised borders (26,063 events). But 90% of these are mis-geocodes: their address string reads "Ukraine, …", typically placed at the Moscow centroid. The clean share is **0.43%**, ranging from 0.2% in 2022 to 1.0% in 2026.
- **IntelliNews refinery strikes.** Test set: the 198 dated strikes at plants with known coordinates.
  - **1.5%** of them have any VIINA event within 25 km on the day ±1. All three of those are 2026 Samara strikes.
  - **23%** have a VIINA headline naming oil infrastructure and the plant's town within ±1 day: 4% in 2024, 21% in 2025, 31% in 2026. VIINA carries some of the news but geocodes it to Ukrainian namesakes.
- **Conclusion: UA→RU needs a separate source.** IntelliNews is the base; Baker (if you approve requesting access) and Deep Strike come next. VIINA is usable only as a weak text supplement.
- Files: `output/russia_share_by_year.csv` and `output/refinery_strike_coverage*.csv`.

## 3. Keyword dictionary (`dict/econ_targets.csv`, 38 terms)

Headline hits, 2022 to Oct 2026. The specific-terms-only count is in brackets.

| Class | Hits |
|---|---|
| gen | 8,280 |
| transmission | 6,490 |
| refining | 504 |
| storage_export | 4,527 |
| industrial | 6,586 |
| **Any class** | **24,992 (12,055)** |

Monthly figures by class are in `output/dict_hits_by_class_month.csv`, and term-level counts in `output/dict_hits_by_term.csv`.

Problems with the terms:
- **АЕС/АЭС** (4,187 hits) is dominated by news about the occupied Zaporizhzhia nuclear plant.
- **Outage words** ("без світла", "знеструмлення") account for 4,163 hits. They are a useful grid signal but are not strikes in themselves.
- **"шахт" (mine)** was tightened from 4,751 hits to 365, because it was matching the place names Shakhtarsk and Shakhtarske.
- **"critical infrastructure" is missing.** Officials use the phrase as a euphemism for energy hits. Adding it is the main fix for recall (§5).

## 4. Facility registry seed (`registry/facilities.csv`)

- **72 facilities: 36 RU and 36 UA.**
  - RU: refineries plus 3 condensate and gas plants. Capacity is in t/yr, from IntelliNews.
  - UA: thermal, CHP, hydro and pumped-storage plants. Capacity is in MW, from Wikidata.
- **Sources:** every row has a source URL. Coordinates come from Wikipedia or Wikidata.
- **Gaps:** 15 rows have no coordinates and 16 have no capacity. These are left NA and logged in `output/gap_log.csv`.

## 5. Pilot: March 2024

**Pipeline counts:** 362 dictionary-hit reports → 251 classified economic → **142 strikes** after de-duplication (same target and attacker within 24 h). Of these, 134 are RU and 8 are UA, and 23 are matched to a registry facility.

**Recall reference.** This is a provisional reference I compiled by hand, with a source URL on every row (`data/raw/manual_reference/`): Ukrenergo/Ministry posts plus DiXi weekly reviews. It stands in for energy-map.info, which needs an account. Ukrenergo explicitly called two attacks "massive": 22 and 29 March.

| Metric | Value | n |
|---|---|---|
| Recall: massive attacks with at least one RU energy strike on day 0–1 | **100%** | 2 |
| Recall: named registry plant matched on day 0–1, all | 57% | 7 |
| Recall: named registry plant matched, confirmed damage only | 40% | 5 |
| Recall: attack-date × oblast with confirmed damage | 55% | 11 |
| Precision, strict (ambiguous = no) | **82%** | 50 |
| Precision, lenient | 88% | 50 |
| Attacker correct, among true strikes | 90% | 41 |
| Facility match correct, among sampled matches | 22% | 9 |

**Why recall misses:**
1. **"Critical infrastructure" headlines are not in the dictionary.** Examples: "в Івано-Франківській області пошкоджено об'єкт критичної інфраструктури", and "критичну інфраструктуру на Вінниччині і Львівщині". This accounts for most of the oblast misses.
2. **Late naming.** Zmiiv TPP is only named on 30 Mar, and Burshtyn only in a 27 Mar repair report. A day 0–1 window misses both.
3. **Ladyzhyn TPP has no coordinates** in the registry seed.

**Precision errors:**
- ZNPP or diplomatic news, arrests and policy items (6 false).
- Daily-digest and follow-up reports.
- 4 of 50 sampled strikes are duplicates that the de-duplication missed, because the same headline was geocoded to a different oblast.

**Attacker errors:** all 4 are Ukrainian strikes on occupied territory (Horlivka, Crimea, occupied Zaporizhzhia) that the rule assigned to RU.

**Facility matching is weak.** Spatial matches attach ZNPP and substation news to DniproHES or Prydniprovska TPP.

**Caveat:** the precision labels are mine (an LLM reading headlines only). They need a human check before the precision figure is quoted.

## 6. Open decisions

1. **Action-merging rule.** Proposed: an action ends at an attacker switch or after a gap of g = 12 h by the same side.
2. **Economic damage measure.** Proposed: share of national capacity × severity, with capacity × days offline as a robustness check.
3. **Kinetic damage.** Reported deaths only, or reported plus modelled expected deaths?
4. **UA→RU source strategy.** May I request the Baker dataset? ACLED needs the same decision.
5. **Attacker rule for 2022–24.** Options: a control map plus target location, and/or a classifier trained on VIINA's 2025+ labels.
6. **Occupied-territory strikes:** a category of their own?
7. **Generic "energy object" strikes with no named facility:** keep them with an oblast-level proxy, or hold them back?
8. **ZNPP handling.**
9. **Manual downloads of energy-map.info and Kaggle** for the real recall test.
10. **A human pass on the precision labels.**
