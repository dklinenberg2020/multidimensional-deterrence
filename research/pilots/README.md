# Colombia and Vietnam subdaily pilots

These are traceable source transcriptions for checking time granularity and linkage. They represent selected documents and pages. Empty fields retain missing information. Observations such as movement, an administrative message and a combat report are distinct record types. Ordering a receipt or a report does not establish the order of the underlying actions.

## Colombia

[colombia-subdaily.csv](colombia-subdaily.csv) contains 15 observations, 10 with a clock value or interval. The Bojayá sequence shows that the May 2 combat opening and the two projectiles can be ordered within the day. The Mitú entries record the dates and qualifiers of the published testimony, including the distinction between an overflight on November 1 and the start of ground fighting on November 2. The clocks are preserved as published and have no timezone conversion.

- `victims-unit` identifies the Unidad para las Víctimas Bojayá chronology. [Source](https://www.unidadvictimas.gov.co/especiales/Bojaya/index.html)
- `defensoria12` identifies Defensoría del Pueblo humanitarian resolution No. 12. The approximate April 21 time was read from the public indexed document. The direct file request returned HTTP 500. [Source](https://www.defensoria.gov.co/documents/20123/1311006/humanitaria12.pdf/76b75942-f491-a828-6df4-406a9e15ed00?download=true&t=1648527337291)
- `cev-mitu` identifies the Truth Commission’s Mitú case study. The printed page numbers apply to the PDF's document pagination. [Source](https://www.comisiondelaverdad.co/sites/default/files/2022-08/Caso%20Toma%20de%20Mitu%CC%81.pdf)

The audit selected six CNMH case candidates for Bojayá/Vigía del Fuerte and four for Mitú by locality and date window. CNMH shares a related-case identifier across combat and property records for May 2 in Bojayá, and across the community attack, kidnapping and one property record for Mitú on November 1. A shared case group can describe several actions or consequences. The pilot assigns no hand-transcribed clock to a CNMH case. The generated candidate table is available in the workspace.

## Vietnam

[vietnam-journal.csv](vietnam-journal.csv) contains every visible numbered entry on PDF pages 8, 47 and 70 of the 2nd Battalion, 35th Infantry S2/S3 journal. The selected pages are a spot check on January 2, 6 and 9, 1968. The record descriptions are paraphrases. The journal's `Time In` and `Time Out` appear separately. `occurrence_start` and `occurrence_end` are populated only when the narrative independently gives a clock. The raw `24:00` convention is retained for an outgoing situation report. Page 70 item 64 carries an explicit late-entry note. Its 18:45 clock follows the 19:00 entry on the page. [Journal PDF](https://cacti35th.com/daily_journals/2-35-1968/68-01-01-15.pdf)

Six rows report combat. None gives an independent occurrence clock in the narrative. Two movement narratives do give explicit clock intervals. Two combat messages share a receipt minute with seven release incidents nationwide, including two candidates in Quang Ngai. The release does not supply a corroborating battalion identifier for the three sampled dates and none of the same-minute candidates was verified as the same event. Routine outgoing updates are recorded as status messages and provide no direct measure of inaction by an opposing party.

The official NARA Access to Archival Databases inventory gives three publicly identified INCDA tables and historic row counts:

| Table | Description | Listed records |
| --- | --- | ---: |
| 2232 | Incident information | 21,489 |
| 2233 | Damage assessments | 24,395 |
| 2234 | Friendly force identification and quantity of ammunition received | 12,001 |

These counts come from the NARA inventory. The table links returned HTTP 403 in this environment. The records and codebook remain outstanding. The three table row counts are at different reporting levels and should not be summed as incidents. [NARA AAD inventory, pp. 6–7](https://www.archives.gov/files/calendar/genealogy-fair/2014/handouts/session-5-handout-4of4-list-of-series-legloahec.pdf) · [NARA series 601815](https://catalog.archives.gov/id/601815)

## Reproduce the checks

Run from the checkout with the tidy data built using the instructions in the main README.

```sh
python scripts/audit_subdaily_pilots.py ../deterrence-tidy ../deterrence-subdaily-sources/results
```

The script validates clock encodings and writes the candidate tables and [aggregate audit](../audits/subdaily-pilot-audit.json). Neither candidate join inserts an event-level association.
