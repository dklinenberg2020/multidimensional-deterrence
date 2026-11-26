# Multilingual archival follow-up

The [observation table](multilingual-observations.csv) contains 12 source claims from Spanish, Vietnamese, Turkish and Greek materials. Five are marked for comparison with an existing observation. A comparison ID marks a source pairing for review. It does not resolve timing disagreements, establish source independence, or imply retaliation. Polish catalogues were searched for additional Vietnam ceasefire records.

## Colombia

The Spanish OHCHR mission report dated May 20, 2002 places the first projectile impact at approximately **10:30** and the church explosion at approximately **10:45**. The later CNMH reconstruction likewise gives approximately 10:30 for the first projectile and approximately **11:00** for the church explosion. The official Unidad para las Víctimas chronology also gives 11:00. The sources agree on the sequence and disagree on the clock for the church explosion. Record both approximate times. Treat the 15-minute difference as source disagreement and leave the exact time unresolved. The initial OHCHR casualty estimate was also preliminary. The direct PDF requests failed, but the Spanish text was readable in the indexed copy used for the extraction. [OHCHR mission report](https://www.hchr.org.co/wp/wp-content/uploads/2002/05/bojaya.pdf) · [CNMH, printed pp. 58–59](https://centrodememoriahistorica.gov.co/wp-content/uploads/2020/01/Bojay%C3%A1-La-guera-sin-l%C3%ADmites.pdf) · [Victims Unit chronology](https://www.unidadvictimas.gov.co/especiales/Bojaya/index.html)

The tripartite monitoring mechanism's 2017 closing report identifies **the verification team's annex**, which describes 54 minor and 10 serious violations. Its summary gives 473 completed verifications across several categories, including 331 checks that did not establish an incident and 78 relevant incidents that did not establish a violation. It reports another 18 pending. These are verification categories, so 473 is not a count of combat incidents. The report says its annexes were declassified at publication. I located the report but did not locate the case annex or establish that it records occurrence clocks. The retrieved second monthly report covers December 7, 2016 through January 7, 2017. It lists 73 requests and aggregate dispositions, with selected day-dated cases. This public report does not supply subdaily records for the 73 requests. [Closing report, §6](https://colombiapeace.org/files/170925_un_cierre.pdf) · [Second monthly report](https://www.humanas.org.co/wp-content/uploads/2023/07/38.-Mision-monitoreo-ONU.pdf)

## Vietnam

I retrieved two Vietnamese accounts of **Cửa Việt in January 1973**. Vũ Ngự Chiêu places an early phase of the Republic of Vietnam attack at 04:00 on January 28 and capture shortly before the ceasefire. Vietnam National Archives Center I publishes a participant account that places the end of local firing in the early morning of January 31. The first source is a later historical account. The second is a veteran's retrospective narrative published by an archival institution. Neither provides the full dispatch record. The archives article's printed GMT date conversion is internally inconsistent. The extraction does not use that conversion or assign a common time zone. [Vũ Ngự Chiêu, PDF p. 34](https://www.viet-studies.com/kinhte/TanCongTriThien_VuNguChieu_HopLuu.pdf) · [Vietnam National Archives Center I](https://www.archives.org.vn/gioi-thieu-tai-lieu-nghiep-vu/tran-cua-viet-truoc-va-sau-ngay-ky-hiep-dinh-paris-27-1-1973.htm)

The Polish state catalogue identifies file `2/1354/0/2.8.1/LXXVI-104` for party meetings and administration at the Polish delegation to the Vietnam and Laos monitoring commissions. This establishes an archival lead for the delegation. The description does not identify field incident reports, and no usable scans were recovered. The Polish search did not yield the missing INCDA records. [Polish state archival catalogue](https://www.szukajwarchiwach.gov.pl/seria?_Seria_delta=200&_Seria_id_serii=653156&_Seria_nameofjsp=jednostki&_Seria_resetCur=false&p_p_id=Seria&p_p_lifecycle=0&p_p_mode=view&p_p_state=normal)

## Cyprus

I retrieved a **681-page Turkish Red Crescent archival compilation** and indexed **33 dated headings from July 17 to August 30, 1974** in PDF pages 347–366. These headings organize a section of the compilation and do not establish continuous observation on the island. One message summarized under July 25 reports a projectile hitting the storage area of Red Crescent medical premises at **11:00 on July 24**. A field team's report gives **06:00 on August 1** for its arrival at Kyrenia. A quoted ICRC account gives a clock for entry into a Turkish Cypriot area and describes later firing without a separate firing time. Preserve the distinction between event, message and compilation date. The humanitarian material adds leads on relief activity and medical infrastructure beyond what the public UN military summaries provide. [Turkish Red Crescent compilation](https://www.kizilay.org.tr/upload/Dokuman/Dosya/00191283_kizilay-belgeleri-isiginda-kibris-baris-harekati-1974-profdr.pdf) · [Date index](cyprus-kizilay-date-index.csv)

I retrieved the **632-page Greek-language parliamentary inquiry findings**, Volume I of *Φάκελος Κύπρου*. PDF p. 142 gives **16:00 on July 22** for the ceasefire, consistent with UNFICYP, and discusses reported activity afterward. The inquiry is a retrospective source. Its agreement on the ceasefire clock does not demonstrate independent corroboration. The original UNFICYP observer logs are still outstanding. [Volume I](https://www.parliament.cy/images/media/redirectfile/fakelos_kyprou_tomos1.pdf) · [UNFICYP public report](https://digitallibrary.un.org/record/484451/files/S_11353_Add.4-EN.pdf)

## Source file register

The following artifacts were retrieved and opened. Paths are relative to the Codex Cloud directory `/workspace/deterrence-subdaily-sources`.

| Source key | Workspace file | SHA-256 |
| --- | --- | --- |
| `cy-kizilay` | `cyprus/turkish-red-crescent-1974.pdf` | `d7978b76e6b7ad0fb7b5804f85c6a051ad596a1c80f4683031d496628ec61a19` |
| `cy-fakelos1` | `cyprus/fakelos-kyprou-vol1.pdf` | `b2c32369515bd424b6ce6b4c14c2a33b33c60fb4f0ad4e4f5f595d2ba0673171` |
| `vn-archives1` | `vietnam/cua-viet-vietnam-archives.html` | `c21a86baf6e12d729e5d1b4da25d3619025ca4e7298e5d3cadb0ed9988aac7f6` |
| `vn-vnc` | `vietnam/cua-viet-vu-ngu-chieu.pdf` | `527954a502b048aeecd479b620dfcad7d4fa69f1ac6a38533e5bec903ba9cfac` |
| `co-mmv2` | `colombia/mmv-second-humanas.pdf` | `97b35834bae66a2d1c7bf6e924f0405518e9ff46c5490e398db1923573fb66be` |

The `co-ohchr` claims were read from the searchable copy linked under Colombia. I did not obtain a local PDF or checksum for that report.
