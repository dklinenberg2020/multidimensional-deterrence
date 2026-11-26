# Vietnam incident timing and damage review

VietnamWarData v1.0.0 has **555,653 within-day clock values** on 638,760 combined rows. This supports a historical chronology audit. The files combine different record types and selected reporting streams. No part of this review identifies a retaliatory response or an interval with verified nonresponse. [Release documentation](https://gl-smith.github.io/VietnamWarData/reference/get_comb_inc_dta.html) · [Construction paper and NARA source manifest](sources.csv)

## What the clocks measure

The authors call the master field `initiation_time`. It is stored as seconds since midnight. **Every usable value falls on an exact minute.** The fine resolution implied by storage is therefore misleading, and the observed distribution shows further clustering. **301,219** clocks (54.2%) fall on an exact hour or half-hour. In SITRA alone 37,574 rows show 23:00, including 35,739 large-unit operation rows. VNDBA has 3,509 rows at 16:01. These concentrations do not establish why any individual value was assigned. The audit excludes zero and 24:00 as ambiguous boundaries, preserves missing values and invalid raw codes, and applies no time-zone conversion.

| Source of surviving master rows | Rows | Usable clocks | Timed starts by source-coded side |
| --- | ---: | ---: | --- |
| SITRA | 334,184 | 274,063 | 141,100 Friendly, 132,152 Enemy, 811 unspecified |
| VNDBA | 99,974 | 93,396 | 47,499 Friendly, 45,897 Enemy |
| VCIIA | 154,253 | 142,948 | 142,948 Enemy |
| TIRSA | 50,349 | 45,246 | 45,246 Enemy |

- **VNDBA** documents a separate incident start and completion date and clock. I joined the release component to **96,110** master rows on a unique source serial and start date. All **89,638** matches with usable clocks on both sides of the join agree exactly. This checks preservation of the clock through the merge. It does not independently confirm when the historical events occurred. 10,062 component records carry a same-day action counter greater than one, so the source row can cover multiple actions. [VNDBA technical guide, start and completion fields](https://gl-smith.github.io/VietnamWarData/guides/vndba-guide.pdf)
- **SITRA** includes enemy incident records, friendly small-unit records and large-unit operations. Its manual describes the large-scale operation initiation and termination clocks and uses Hotel time for that field. The released tables also populate clocks for other record types. Those clocks and their provenance need record-type-specific verification before comparison. An operation start can precede individual contacts within the operation. [SITRA technical guide, HOURI and ITIME](https://gl-smith.github.io/VietnamWarData/guides/sitra-guide.pdf)
- **VCIIA and TIRSA** contribute enemy-initiated rows only. VCIIA records an incident clock and a separate situation-report serial. TIRSA separates the reporting date in its control record from the occurrence date and time in its fixed record. Neither series independently supplies both directions. [VCIIA guide](https://gl-smith.github.io/VietnamWarData/guides/vciia-guide.pdf) · [TIRSA guide](https://gl-smith.github.io/VietnamWarData/guides/tirsa-guide.pdf)

The construction paper describes deduplication across overlapping files using source fields including side, action and operation information, military unit, start date and time, and coordinates. It also uses the VNDBA event identifier. The master ID is unique, while some originating serials repeat. A remaining time tie may reflect simultaneous events, coarse recording, multiple rows associated with an operation, or duplication. In the previous battalion-journal spot check, six combat messages had receipt or transmission clocks and none had an independent narrative occurrence clock. There was no verified event match to the master. [Journal pilot](pilots/README.md#vietnam)

## How much ordering survives

I grouped usable clocks by **source, province and calendar date**. I ordered distinct clock buckets and used only neighboring buckets containing exactly one row each, with opposite source-coded initiating sides. I did not skip tied buckets or unknown-side rows to find an opposite-side match. Untimed rows and unobserved actions can still intervene. For the distance checks I used the master latitudes and longitudes and excluded positions the release flags as outside South Vietnam or offshore. This is one conservative screening rule. It excludes cross-source and cross-province candidates. The resulting counts describe record proximity under this rule.

| Screening rule | Opposite-side pairs |
| --- | ---: |
| Adjacent singleton clocks in the same source, province and date | 30,996 |
| Also within 30 minutes | 6,931 |
| Within 30 minutes and 10 km | 1,792 |
| Within 30 minutes and 5 km | **1,001** |
| Within 5 minutes and 5 km | **222** |
| Within 120 minutes and 5 km | 1,861 |

Of the 1,001 pairs within 30 minutes and 5 km, **895** are SITRA and **106** are VNDBA. Friendly is first in 528 and Enemy is first in 473. Eleven include a large-unit operation. Only six have both clocks off the five-minute grid. Across all 535,053 timed rows with a province, **161,953** share their exact source, province, date and clock with another row. **4,925** tied buckets contain both initiating sides; their recorded clocks cannot establish an order.

For example, the SITRA extract has an Allied small-unit operation at **17:00** followed by an enemy-initiated incident at **17:30** in the same recorded province on February 6, 1968. The source coordinates are about 1.2 km apart. This is an example of what the screen can surface. The records do not say whether the incidents were connected. The candidate CSV in the cloud workspace retains master IDs, unconverted clock offsets, reported side and calculated distance.

## Damage and response measures

**Human damage.** VCIIA and VNDBA carry the bulk of rows with all four friendly and enemy killed/wounded fields. **106 of the 1,001** close pairs have all four fields populated on both records, all in VNDBA. **93** close pairs have specific target fields on both records, all in SITRA. SITRA carries some casualty fields, and no SITRA pair meets the both-sides complete casualty standard in the combined extract. Treat source-coded zeros and missing values separately. Coverage of civilian harm and consistently measured munition types and quantities is insufficient to construct the Gaza expected-damage measure directly.

**Physical and material damage.** The individual VNDBA release has structure, vehicle, food, fuel and weapons loss counts that the master omits. Of the roughly 96,000 uniquely linked master records, 2,041 have positive friendly structure losses and 717 have positive enemy structure losses. Vehicle loss fields are positive on 592 and 436 linked records respectively. Nearly all linked entries are numerical. The source zeros need validation against how each loss was collected and coded. All 106 close VNDBA pairs link at both ends to the component. Only four record positive structure, vehicle, food or fuel losses on either end. These counts provide a possible physical-damage dimension for the broader VNDBA file, with sparse positive observations among the local pairs. They do not measure monetary loss or restrictions on civilian movement. [VNDBA guide](https://gl-smith.github.io/VietnamWarData/guides/vndba-guide.pdf) · [Field-level coverage](audits/vietnam-ordering-audit.json)

**Support-request and receipt fields.** The VNDBA manual defines both clocks as six-digit day-of-month, hour and minute. The component has 3,648 populated request fields and 1,090 populated receipt fields, with both present on 1,085 rows. **Zero values in either field match a valid six-digit clock.** Common strings include `100USA` and `4BUSMC` in the request field and `F` and `MSN` in the receipt field. These values indicate a documentation or parsing mismatch. The component supplies no usable support latency from those fields. Identifying the source of the mismatch would require tracing the original records and layout. [VNDBA technical guide, RQDAY and RCDAY](https://gl-smith.github.io/VietnamWarData/guides/vndba-guide.pdf)

**Post-ceasefire coverage.** There are 1,281 rows from January 27, 1973 onward, 1,241 with usable clocks. Only six rows fall after the documented SITRA end on March 12, 1973. These six have already been flagged for source verification. No post-ceasefire pair meets the 30-minute and 5-km screen. The combined file cannot establish continuous coverage through 1975. NARA's separate INCDA files and codebook, and the ICCS field records, remain outstanding. [Post-ceasefire source search](subdaily-source-search.md#vietnam)

## Reproduction

Run against the two pinned RDS files listed in the source inventory, with the project requirements installed. The JSON audit is committed. The row-level candidate CSV remains in the cloud workspace with the other Vietnam-derived tables.

```sh
python scripts/audit_vietnam_ordering.py ../deterrence-source-files/vietnam \
  --candidate-csv ../deterrence-subdaily-sources/vietnam/clock-review/ordering-candidates.csv
```
