# Research log

## Yemen and Colombia source expansion

Extracted 2,746 ordered coalition claims from UN-circulated Yemen filings, with 2,744 usable minute clocks. Retrieved and indexed 506 pages of CINEP's Colombian case sections for 2002. The [coverage comparison](subdaily/yemen-colombia/README.md) records the remaining differences from the Gaza SITREP and links to the data and source audits.

## Multilingual archival follow-up

Reviewed Spanish, Vietnamese, Turkish, Greek and Polish sources. Added 12 source observations and a 33-date index to the Turkish Red Crescent compilation. The archive review identifies a 15-minute discrepancy in Bojayá and the Colombia monitoring mechanism verification annex as an acquisition target. See [source locations and checksums](subdaily/multilingual-sources.md).

## SITREP transcription expansion

Reviewed the published Gaza specimen and expanded the [subdaily tables](subdaily/README.md) for Colombia, Vietnam and Cyprus. Completed a full Vietnam source day, transcribed a second Colombia chronology, and indexed the entire public Cyprus report series with curated observations and coverage intervals. The underlying field reports remain necessary for comparable continuous coverage.

## Pilot transcriptions and additional archive checks

Completed two [subdaily transcription pilots](pilots/README.md). The Colombia pilot retained 10 clock-bearing observations and identified 10 potential CNMH episode records. The Vietnam pilot separated combat reports' receipt clocks from independently stated occurrence times. No event-level link was verified. The [archive follow-up](subdaily-source-search.md#follow-up-on-the-other-conflicts) identifies exact UNFICYP and UNPROFOR file references.

## Subdaily archival search

Verified clock-bearing sources for Bojayá and Mitú, Vietnam duty logs, and UN observer reports from Cyprus. Located the relevant INCDA and ICCS archival series and identified Bosnia and Falklands records for further checks. The [source assessment](subdaily-source-search.md) records sample evidence, archive references, and acquisition status.

## Tidy Vietnam and Colombia tables

Built one clean incident table per country and a separate Colombia victim table. Verified 638,760 unique Vietnam incidents and 94,450 unique Colombia incidents. All 95,791 Colombia victim rows link to a case. Colombia date precision includes 90,647 day, 998 month, 865 year and 1,940 unknown records. Vietnam preserves original clock codes and flags the six rows after the documented SITRA series end. See the [tidy table dictionary](tidy-data.md) and [build audit](audits/tidy-audit.json).

## GitHub access restored

The GitHub connection now includes `dklinenberg2020`. Verified write access by publishing manuscript commit `23a3019` and acquisition commit `094cb55` to the project's `main` branch. The initial access failure is recorded below.

## Initial acquisition and audit

Verified the GitHub project `dklinenberg2020/multidimensional-deterrence` is readable. The connector's repository metadata reported read and push permissions, but the cloud Git credential and the connector's mutation endpoints returned HTTP 403. Repository listing through the connected installation returned `Nathan-Roll1/Extremism` and did not include the project. No writes were attempted against other repositories.

The [source inventory](sources.csv) lists 27 downloaded artifacts with SHA-256 checksums. Original publisher bytes are preserved outside the checkout. The [audit outputs](audits/) document the fields observed, missingness, exact duplicates, selected labels and date precision. One incident file per country was generated, without inferring responses or merging incidents on time proximity.

| Conflict | Records in incident extract | Temporal precision | Measurement and chronology |
| --- | ---: | --- | --- |
| Vietnam | 638,760 | 555,653 clock values within the day, 83,107 day-only | Both source-coded sides initiate events. Human harm counts are available for some events. Shared reporting periods and missing clocks require validation before sequence analysis. |
| Iraq | 251,845 | Timestamp strings for all rows, including 509 midnight records | Insurgent activity and explosive hazards dominate. Force fields do not reliably identify initiators, and the release has no casualty totals. Separate coverage of coalition operations is needed. |
| Colombia | 94,450 | 90,647 exact calendar dates, 3,803 without a valid day | Day-level, multisided data with case-level victim counts, property descriptions, mobility restrictions and extortion. Within-day ordering is unresolved. |
| Yemen | 25,054 | 14,753 usable reported hours, 10,301 day-only | Coalition air raids, civilian casualties and target types. A second source is needed for actions by opposing actors. |

### Vietnam

Downloaded the combined VietnamWarData v1.0.0 release and all four constituent derivatives. Parsed SITRA (739,022 rows), VNDBA (365,015), TIRSA (62,273) and VCIIA (175,475). The combined release contains 638,760 rows and 43 fields. It contains 388,240 Enemy and 249,703 Friendly initiators, plus 817 missing labels. Its master identifier is unique. The constituent derivatives overlap and have different reporting units and coverage, so adding their row counts would overstate incident coverage.

The combined time field includes 15,097 zero-second values, 62,862 values at exactly 86,400 seconds and 252 other populated values outside the accepted day range. These remain in the source time field with day precision. Six SITRA rows fall after the archive's stated March 12, 1973 series end and extend the parsed range through September 1975. Check those dates against the source before using them. The combined release is constructed from VNDBA, SITRA, TIRSA and VCIIA. Its late rows do not constitute coverage of INCDA.

Downloaded four technical guides, the NARA OPSANAL manual, the release construction paper and the NARA finding aid. NARA separately describes four INCDA files and 56 pages of technical documentation. The catalog links returned a JavaScript shell and the source machine-readable INCDA files and technical guide remain outstanding. The retrieved RDS files are cleaned releases, and their underlying NARA machine-readable originals have not been verified. [VietnamWarData](https://gl-smith.github.io/VietnamWarData/index.html) · [NARA finding aid](https://www.archives.gov/research/military/vietnam-war/electronic-data-files)

### Iraq

Downloaded the Harvard Dataverse replication CSV and verified the publisher's MD5. The cleaned release has 251,845 rows and 20 fields. The accompanying research paper describes a separate, earlier DoD release of 253,286 observations. That underlying file and a standalone codebook were not present in the supplied replication release. The paper documents the semantics of the released SIGACTs and is preserved with the downloaded metadata.

The parsed dates run from November 1, 2003 to December 31, 2011, with 13 rows from 2003. The two source date fields agree on the day. The audit found three duplicate payloads after removing the export ordinal. It retained all rows for traceability. Placeholders in the serial and actor context fields are excluded from usable identifiers and attribution. General labels such as Friendly Fire document incident categories and cannot establish a systematic series of friendly-initiated moves. [Harvard Dataverse](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/JRYGFP) · [Political Violence Lab](https://www.politicalviolencelab.com/sigacts-iraq)

### Colombia

Downloaded four case workbooks and four corresponding victim workbooks from the CNMH portal, plus the publisher methodology. The raw workbooks retain Spanish headings and native codes. The case extract has 39,507 military actions, 22,472 civilian property damage cases, 31,971 kidnapping cases and 500 attacks on communities. Across the four victim files, all 95,791 rows matched an `ID Caso` within the corresponding case workbook. The mapping is one-to-many. The incident extract leaves the victim files separate. The case files contain no repeated `ID Caso` values across categories. `ID Caso Relacionado` is populated for 13,633 cases and needs validation before it can support any cross-category linkage.

Across the files with relevant fields, 662 cases have a positive confinement or movement restriction indicator and 764 have a positive extortion indicator. The military action file lacks both of these fields. The initiative classification records broad categories and should be distinguished from named armed participants. Several victim records can refer to the same incident and an individual can appear in more than one case. [CNMH data portal](https://micrositios.centrodememoriahistorica.gov.co/observatorio/portal-de-datos/base-de-datos/) · [CNMH methodology](https://micrositios.centrodememoriahistorica.gov.co/observatorio/sievcac/metodologia/)

### Yemen

Downloaded the publisher CSV and methodology. The filename spans March 2015 to January 2026, but the 25,054 dated rows in this snapshot run from March 26, 2015 to March 31, 2022. One undated row was excluded from the historical extract. Four incident identifiers repeat and are retained. The source's hour value of 24 remains ambiguous and is treated as day precision.

The unit is a recorded raid, which can comprise multiple individual airstrikes. Target labels are not measurements of physical or economic loss. UCDP's Georeferenced Event Dataset can help check coverage of reported fatal events by both sides, but this supplement has not been acquired and would still leave nonfatal actions underrepresented. [Yemen Data Project](https://www.yemendataproject.org/data/) · [UCDP download center](https://ucdp.uu.se/downloads/)

### Redistribution

The repository includes the standardized Iraq and Yemen extracts, with license and attribution notes. Vietnam and Colombia source snapshots and standardized extracts are retained in the cloud workspace while redistribution terms are checked. The other conflicts and the prior conversation's preliminary datasets remain outside this initial acquisition pass.
