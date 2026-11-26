# Yemen and Colombia comparison with the Gaza SITREP

## Yemen

The Hudaydah series is a continuous sequence of **2,746 numbered coalition claims** in submissions to the UN Security Council. The annex in S/2019/51 printed rows 1–494. S/2019/99 republishes that sequence and continues to 943. S/2019/206 continues from 944 to 1,754. S/2019/299 continues from 1,755 to 2,746. The table publishes the reporting coalition's claims. UN circulation does not establish independent verification or coverage of the other side's actions. [S/2019/51](https://digitallibrary.un.org/record/1663250) · [S/2019/99](https://digitallibrary.un.org/record/1664462) · [S/2019/206](https://digitallibrary.un.org/record/3798182) · [S/2019/299](https://digitallibrary.un.org/record/3802379)

- The [structured claim table](hudaydah-coalition-claims.csv) includes source row, page, reported date and clock, time in UTC and Yemen local time, reported location, category and attribution. It uses the later filing for the 494 repeated claim numbers and audits field differences. Claims sharing a time and place remain separate when the source numbers them separately.
- **2,744** claims have a usable reported minute. One clock is blank and one is invalid as printed (`1685`). **363** entries change dates under the source's UTC+3 conversion. Local timestamps span December 18, 2018 to March 31, 2019, with claims on all 104 calendar days. This establishes a continuous series of dated reports by one party. It supplies no observation of a quiet interval or of an opponent declining to respond.
- Source narratives preserved in the local extraction include civilian harm and damage in some entries. Absence of a casualty mention is missing data. The [audit](../../audits/hudaydah-claims-audit.json) records row counts, missing values and source checksums.
- In the same 104-date window, the Yemen Data Project has **10 reported coalition air raids in Hudaydah governorate**, with **eight usable hour codes**. Its geographic unit is the wider governorate, and the air-raids table covers a different weapon class from much of the coalition claim series. The two tables therefore leave a major coverage imbalance. [Yemen Data Project](https://www.yemendataproject.org/data/)
- Mwatana's independent ground-attack report documents attacks involving multiple sides and provides some occurrence times and casualty counts. The three [reviewed examples](yemen-independent-examples.csv) are outside the Hudaydah window. One has an internally inconsistent weekday/date. The public case narratives cannot fill the opponent series for the whole window. Arabic press results also often carry an article timestamp and a day-level incident description. [Mwatana ground-attack cases](https://old.mwatana.org/en/withering-life/part-two/section2/) · [Example Arabic Saba report](https://saba.ye/ar/news3082174.htm?cid=59)

The outstanding source is the original UNMHA monitoring or liaison incident series for both parties, or a comparable series of coalition ground actions in the same locations and dates. UNMHA confirms the role of the joint mechanism. Its public summaries do not expose the complete underlying log. [UNMHA on the joint committee](https://unmha.unmissions.org/en/redeployment-coordination-committee-rcc)

## Colombia

Retrieved the twelve monthly case sections of CINEP and Justicia y Paz's *Noche y Niebla*, issues 23–26, for **January–December 2002**. The index covers **506 PDF pages**, detects **4,045 dated case headings**, and flags **753 case fragments** with at least one clock-like expression. These counts are OCR/text-layout diagnostics. Headings are source entries and may overlap. Clock expressions can refer to occurrence, a deadline, a report, or a related event on a later date. The index scans the source page and column, so it can miss continuation text on later pages. [Publisher archive index](https://www.nocheyniebla.org/revistas/revista-noche-y-niebla/) · [June 2002 source PDF](https://www.nocheyniebla.org/wp-content/uploads/u1/24/pdf/noche0602.pdf) · [Index audit](../../audits/cinep-2002-index-audit.json)

Reviewed and transcribed eight occurrence clocks or bounds into a [source-cited table](colombia-reviewed.csv). A single Florida case filed under June 1 documents multiple actions on June 1 and June 2 and shows why the case heading cannot simply supply one date and clock to every event. The archive offers material on conflict activity, harm, mobility and property, with case selection based on the publisher's documentation remit. It cannot by itself identify the periods during which an opponent's actions would reliably have been observed.

Separately checked CERAC's monthly index and its report links. Direct article endpoints returned a maintenance page. The publicly accessible index summarizes dated cases and includes publication cutoffs. The original Government–FARC–UN verification annex covering **64 violations** still has not been recovered. [CERAC monthly archive](https://cerac.org.co/es/l%C3%ADneas-de-investigaci%C3%B3n/analisis-conflicto/monitor-de-desescalamiento-en-el-marco-del-conficto/reportes-mensuales.html) · [Monitoring mechanism closing report, section 6](https://colombiapeace.org/files/170925_un_cierre.pdf)

## Reproduce the extractions

The Yemen extractor uses Poppler's `pdftotext`. The Colombia indexer uses the PyMuPDF version in the project requirements.

```sh
python scripts/extract_hudaydah_claims.py ../deterrence-subdaily-sources/yemen ../deterrence-subdaily-sources/yemen/claims-extract
python scripts/index_cinep_cases.py ../deterrence-subdaily-sources/colombia ../deterrence-subdaily-sources/colombia/cinep-extract
```

The Yemen source files are named `S-2019-{51,99,206,299}-en.pdf`. The CINEP files follow `cinep-<issue>-<MM>02.pdf` and the June snapshot is named `cinep-24-media.pdf`. Find the CINEP months at `https://www.nocheyniebla.org/wp-content/uploads/u1/<issue>/pdf/noche<MM>02.pdf`. The downloaded PDFs, Yemen narrative extract and Colombia review queue are retained in the cloud workspace. The reviewed extracts and audit counts are committed.

The [archive acquisition log](archive-acquisition.md) records the follow-up search, downloaded documentary evidence and draft access requests.
