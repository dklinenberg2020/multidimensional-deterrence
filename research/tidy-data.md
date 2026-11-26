# Vietnam and Colombia tidy tables

Each incident table has one row per released incident or case. The stable `incident_id` combines country, source dataset and native identifier. `source`, `source_row` and `source_id` trace the observation to the source. Measure columns contain integers or Boolean values where available. Blank CSV cells represent missing information. Reported zeros and false values are retained. The output CSV files can be read directly from gzip with pandas or R.

| File | Unit of observation | Cleaning |
| --- | --- | --- |
| `vietnam-tidy-incidents.csv.gz` | Combined-release incident | Published times within the day are converted to `HH:MM:SS`. `time_status` flags missing, out-of-range and ambiguous boundary values. The reported seconds are retained. Four casualty counts preserve the original friendly and enemy categories. `outside_documented_sitra_period` flags the six late SITRA dates. |
| `colombia-tidy-incidents.csv.gz` | CNMH case | `date_precision` records day, month, year or unknown. `event_year`, `event_month` and `event_day` retain the supported parts. `date` is present only for a valid full date. The municipality DANE code stays an identifier. Victim and injury totals are nullable integers. Movement restrictions and extortion are nullable Booleans. |
| `colombia-tidy-victims.csv.gz` | CNMH victim workbook row | The original Spanish columns are retained. Join to the incident table on `incident_id` with a one-to-many relationship. The pair `source` and `source_row` uniquely identifies each victim row. A person may appear in multiple cases. |
| `tidy-audit.json` | Build summary | Row totals, temporal precision counts and victim linkage checks. |

The Vietnam clock keeps the source's reported time without timezone conversion. Values of zero or 86,400 seconds are treated as ambiguous and have an empty `event_time`. The Colombia case table carries suspected responsible party or initiative context where provided. Categories with the same related-case identifier may overlap. These tables preserve source evidence without imputing dates, relabeling participants as initiators, or assigning move–countermove links.

The generated tables are retained in the Codex Cloud workspace while redistribution terms are verified. The [source inventory](sources.csv) and [incident dictionary](data-dictionary.md) document the underlying snapshots and source mappings.
