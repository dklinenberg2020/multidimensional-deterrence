# Subdaily SITREP transcription

The benchmark is Berman et al.'s UN security report for November 20, 2010. It reports incidents from both sides with observation dates, clock times, governorates, action or munition type, and reported human and physical outcomes. Some rows explicitly report no harm. The June 2026 draft describes occurrence timing of up to five-minute precision and distinguishes the recorded incident from the action and response opportunity created in analysis. Matching that standard requires consecutive source coverage and useful event detail. A complete transcription of a one-sided journal or a public summary remains limited by what its source recorded. [Example SITREP, Figure 5 in the December 2024 draft](https://openscholar.huji.ac.il/sites/default/files/estebanklor/files/drc_08dec2024_full_draft.pdf#page=17) · [June 2026 paper, Sections 3–5](https://eklor.huji.ac.il/sites/default/files/estebanklor/files/drc-july26.pdf)

| Conflict | Reviewed extraction | Coverage limit |
| --- | --- | --- |
| Vietnam | All 37 numbered entries and two summaries from the January 1, 1968 battalion journal, including all four form pages and the source's daily casualty zeros. | The combat episode gives a 01:03 receipt clock, an approximate munition count and a duration range. The requested response is recorded, but the journal gives no independent first-shot time or confirmation that the requested outgoing fire occurred. The journal observes one reporting chain. |
| Colombia | 15 newly transcribed observations from the CNMH Bojayá narrative, 11 with a clock or a time bound. Four rows link back to the earlier narrative pilot as corroborating observations. | The CNMH narrative has approximate and reported clocks for selected events and no continuous observation schedule. It supplies the previously missing second projectile that fell without exploding. The May 2 10:30 and 11:00 anchors are approximate in CNMH. |
| Cyprus | Indexed S/11353 and all 33 public addenda. Curated 40 observations across seven reports, including 18 with a reported occurrence clock or boundary. Reviewed all five paragraphs of Add.20 and recorded its observation window. | Public summaries have varying windows and levels of detail. Add.4 says 29 incidents were recorded in five hours but its published text does not enumerate them. The unreviewed clock queue also contains report times, meetings and other non-incident milestones. |

## Data files

- [Vietnam complete source day](vietnam-1968-01-01.csv) and [journal coverage register](vietnam-coverage.csv). `clock_in` and `clock_out` preserve the form's columns. A numbered item repeated as a continuation across pages is a single item. The casualty summary is scoped to the reporting unit and day. A reported tactical request is distinct from its execution.
- [Colombia CNMH observations](colombia-bojaya-cnmh.csv). `clock_end` on a `reported_latest_time` row is an upper bound. `prior_pilot_id` points to an observation in the [first pilot](../pilots/colombia-subdaily.csv). Treat those pairs as separate evidence about the same event when estimating totals. [CNMH book, printed pages 53–66](https://centrodememoriahistorica.gov.co/wp-content/uploads/2020/01/Bojay%C3%A1-La-guera-sin-l%C3%ADmites.pdf)
- [Cyprus curated observations](cyprus-observations.csv), [coverage intervals](cyprus-coverage.csv), and [all public report headings](cyprus-report-register.csv). Issue dates are distinct from the date an incident occurred or was reported. Same-minute records remain unordered unless the source supplies an order. [Security Council compilation, PDF pages 48–66](https://digitallibrary.un.org/record/605114/files/S_SUPP_1974_3--%5EOR_SC_1974_III%5E-EN.pdf) · [Add.20](https://digitallibrary.un.org/record/484623/files/S_11353_Add.20-EN.pdf)
- [Structured measurements](measurements.csv) joins to the country observation ID. Counts retain their scope and qualifiers. An empty measurement is unknown. Recorded zero fatalities in an incident has a different scope from zero fatalities in a daily unit summary.

## Acquisitions needed for continuous coverage

**Cyprus** requires the original UNFICYP situation reports, particularly item `S-0903-0003-03-00001` (July 15–August 17, 1974) and `S-0903-0003-02-00001` (August 19, 1974–April 22, 1975). The public compilation was retrieved. The original logs remain outstanding. **Colombia** requires a recurring original field series beyond retrospectively documented episodes, such as local and regional tripartite monitoring records or contemporaneous dispatch logs. The CINEP issue No. 24 endpoint returned an HTML verification page. **Vietnam** requires the original INCDA occurrence fields and damage assessments for 1973–75, and a second reporting source to test omissions by each side. The earlier direct NARA AAD table requests were denied. These source gaps prevent a Gaza-equivalent result from the files acquired to date. No absence of reporting is coded as absence of an event.

## Reproduce the source index

Preserve the official UN compilation and battalion PDF under the paths below. The script requires PyMuPDF and verifies the compilation hash because the manually keyed heading boundaries depend on the pinned source's text layout.

```text
deterrence-subdaily-sources/cyprus/un-security-council-1974-q3.pdf
deterrence-subdaily-sources/vietnam/35th-1968-01-01-15.pdf
```

```sh
python scripts/index_subdaily_sources.py ../deterrence-subdaily-sources ../deterrence-subdaily-sources/expanded
```

The output indexes all 100 Vietnam PDF pages and 202 Cyprus clock-like lines. The queues contain unreviewed OCR and stay in the workspace. The [source index audit](../audits/subdaily-source-index-audit.json) and [reviewed data audit](../audits/subdaily-reviewed-audit.json) are committed. [Vietnam journal scan](https://cacti35th.com/daily_journals/2-35-1968/68-01-01-15.pdf)
