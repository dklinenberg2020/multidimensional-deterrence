"""Extract incident metadata from saved Mwatana listing and detail pages."""

import argparse
from collections import Counter
import csv
import json
from pathlib import Path
import re

from lxml import html


START = "2018-12-18"
END = "2019-03-31"
BASE = "https://maps.mwatana.org"


def read_page(path):
    return html.fromstring(path.read_bytes())


def listing_rows(directory):
    candidates = []
    for page_number in range(18, 24):
        page = read_page(directory / f"mwatana-page-{page_number}.html")
        links = page.xpath('//a[starts-with(@href, "/en/incident/")]')
        if not links:
            raise ValueError(f"No incident links on listing page {page_number}")
        for link in links:
            case_id = link.get("href").rsplit("/", 1)[-1]
            card = link.getparent().getparent().text_content()
            date = re.search(r"\b\d{4}-\d{2}-\d{2}\b", card).group()
            candidates.append((date, case_id))
    dates = [date for date, _ in candidates]
    if dates != sorted(dates) or not dates[0] < START <= END < dates[-1]:
        raise ValueError("Listing pages do not bracket the date window in ascending order")
    selected = [(date, case_id) for date, case_id in candidates if START <= date <= END]
    if len({case_id for _, case_id in selected}) != len(selected):
        raise ValueError("Duplicate incident identifier in listing window")
    return selected


def text_content(node):
    return " ".join(node.text_content().split())


def incident(directory, listed_date, case_id):
    document = read_page(directory / f"mwatana-incident-{case_id}.html")
    fields = {
        text_content(row[0]): row[1]
        for row in document.xpath('//table/tbody/tr[th and td]')
    }
    date_field = fields["Incident Date"]
    date = (date_field.text or "").strip()
    if date != listed_date:
        raise ValueError(f"Listing and detail dates disagree for {case_id}")
    period = " ".join(date_field.xpath("./small/text()")).strip()
    if period not in {"", "AM", "PM"}:
        raise ValueError(f"Unrecognized time label {period!r} for {case_id}")
    victim_table = document.xpath('//table[thead/tr/th[normalize-space(.)="Victim type"]]')
    if len(victim_table) > 1:
        raise ValueError(f"Multiple victim tables for {case_id}")
    victim_types = Counter()
    if victim_table:
        table = victim_table[0]
        labels = [text_content(th) for th in table.xpath("./thead/tr/th")]
        column = labels.index("Victim type")
        victim_types.update(text_content(row[column]) for row in table.xpath("./tbody/tr"))
    return {
        "source_id": case_id,
        "event_date": date,
        "event_daypart": period,
        "temporal_precision": "half_day" if period else "day",
        "governorate": text_content(fields["Governorate"]),
        "district": text_content(fields["Directorate"]),
        "actor_attributed": text_content(fields["Perpetrator"]),
        "incident_types": " | ".join(text_content(link) for link in fields["Incident types"].xpath("./a")),
        "victim_rows": sum(victim_types.values()) if victim_table else "",
        "injured_victim_rows": victim_types.get("Injured", 0) if victim_table else "",
        "killed_victim_rows": victim_types.get("Killed", 0) if victim_table else "",
        "source_url": f"{BASE}/en/incident/{case_id}",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("csv_output", type=Path)
    args = parser.parse_args()
    rows = [
        incident(args.source_directory, date, case_id)
        for date, case_id in listing_rows(args.source_directory)
    ]
    with args.csv_output.open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    district_dates = {}
    for row in rows:
        if row["district"] and row["event_daypart"]:
            key = (row["district"], row["event_date"])
            district_dates.setdefault(key, {}).setdefault(row["event_daypart"], set()).add(row["actor_attributed"])
    opposite_period_dates = sum(
        any(am != pm for am in groups.get("AM", ()) for pm in groups.get("PM", ()))
        for groups in district_dates.values()
    )
    audit = {
        "source_rows": len(rows),
        "covered_dates": len({row["event_date"] for row in rows}),
        "daypart_counts": Counter(row["event_daypart"] or "unspecified" for row in rows),
        "actor_counts": Counter(row["actor_attributed"] or "unspecified" for row in rows),
        "incident_type_counts": Counter(row["incident_types"] for row in rows),
        "missing_district": sum(not row["district"] for row in rows),
        "source_rows_with_victim_table": sum(row["victim_rows"] != "" for row in rows),
        "district_dates_with_different_attributed_actors_in_am_and_pm": opposite_period_dates,
    }
    print(json.dumps(audit, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
