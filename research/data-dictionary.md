# Historical incident data dictionary

Each row is an incident record in its source's reporting unit. The pair `source` and `source_row` identifies a record within a pinned file. Rows are retained even when a publisher identifier repeats. Colombia victim rows remain in separate publisher files. Full native field names, missing counts and selected label distributions appear in the per-file audit JSON.

| Field | Definition |
| --- | --- |
| `source` | Publisher filename listed in the source inventory. |
| `source_row` | One-based record ordinal within a CSV or RDS, or one-based worksheet row for Excel including the header row. |
| `source_id` | Publisher identifier scoped to a source file. It can be missing or repeat. |
| `date` | Valid ISO occurrence date. An empty date means a valid day could not be assigned. |
| `time_reported` | Source time representation without a timezone conversion. Iraq uses a clock string, Yemen uses the source hour or source missing code, and Vietnam uses the R release's seconds since midnight. |
| `precision` | `clock_reported` means a usable clock value was present. `hour_reported` is a populated integer hour from 1 to 23. `day` means a date was usable but the clock was unavailable or ambiguous. `unknown` means a valid day was unavailable. Clock accuracy and time zone are unverified. |
| `event_type` | Source event classification. Labels retain source wording. |
| `actor_reported` | Source-reported initiator or suspected responsible actor. Yemen uses the coalition stated in the publisher's series definition. |
| `recipient_reported` | Reported target or target category. A target label can refer to a place, structure or population rather than a strategic actor. |
| `actor_context` | Source context such as force type, initiative grouping or aggressor subgroup. Interpret it using the source-specific notes. |
| `place` | A source locality label. Administrative level varies by source. |
| `fatalities_civilian`, `injured_civilian` | Reported civilian fatalities and injured counts when available. |
| `fatalities_friendly`, `injured_friendly`, `fatalities_enemy`, `injured_enemy` | Vietnam reported casualties by original reporting-side categories. |
| `victims_reported` | Source total victims when available. It is a source-defined measure. |
| `physical_damage_reported` | Reported property damage description where mapped. Property indicators and other details remain in the Colombia source workbook. |
| `mobility_restriction_reported`, `economic_coercion_reported` | Colombia source fields for confinement or mobility restriction and extortion. Values retain source coding. |
| `related_case_id` | Colombia `ID Caso Relacionado` value. Its use as a cross-category linkage field needs validation. |
| `archive_series` | Vietnam combined-release source series. |

Empty cells represent missing or unmapped information. Explicit publisher zeros are retained. Neither an empty field nor an absent date in a source establishes zero harm or zero events. The extracts retain source-row order and carry no inferred retaliation links.

## Source mappings

- **Vietnam:** `master_event_id`, `initiation_date`, `initiation_time`, `aggressor_side`, `aggressor_sub_group`, `general_action_category`, `prov_name`, `data_file_origin` and the four `n_*_kia` / `n_*_wia` fields.
- **Iraq:** `serial`, `date_time_occ` with date fallback from `doi`, `category` with `type` fallback, `attack_on`, `force_type`, and `ADM3NAME`. The CSV ordinal is excluded from the duplicate payload audit.
- **Colombia:** `ID Caso`, `Año`, `Mes`, `Día`, `Modalidad`, `Descripción Presunto Responsable` with `Presunto Responsable` fallback, `Iniciativa`, `Municipio`, `Lesionados Civiles`, `Total de Víctimas del Caso`, `Descripción Tipo de Bien`, `Confinamiento o Restricción a la Movilidad`, `Extorsión`, and `ID Caso Relacionado`. `Grupo Armado` fields are contextual participants and remain in the raw workbooks. Cases in the attacks-on-communities file are identified by that file's category.
- **Yemen:** `Incident ID`, `Date`, ` Confirmed Time`, `Sub-category` with `Main category` fallback, `Target`, `Governorate`, `Fatalities `, and `Injured `. A reported value of 24 remains in `time_reported` with day precision because its midnight convention is unresolved.
