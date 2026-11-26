"""Extract the numbered incident claims in the 2019 Hudaydah UN submissions."""
import argparse
import csv
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess


COLUMNS = ("Date", "Time", "Location", "Violation type", "Description")
HEADER = re.compile(r"^\s*(?:No\.|Number)\s+Date\s+Time.*Location\s+Violation type\s+Description")
ROW = re.compile(
    r"^\s*(\d+)\s+(\d{1,2} (?:December|January|February|March) 20\d{2})"
    r"\s+(?:(\d{3,4})\s*(?:hours|Z)|hours)\b"
)
LOCAL = timezone(timedelta(hours=3))
REPORTS = {51: (1, 494), 99: (1, 943), 206: (944, 1754), 299: (1755, 2746)}


def extract(pdf, symbol):
    layout = subprocess.check_output(["pdftotext", "-layout", str(pdf), "-"], text=True)
    rows = []
    date, location, kind, notes = COLUMNS[0], COLUMNS[2], COLUMNS[3], COLUMNS[4]
    for page, content in enumerate(layout.split("\f"), 1):
        positions = None
        for line in content.splitlines():
            if HEADER.match(line):
                positions = {name: line.index(name) for name in (date, location, kind, notes)}
                continue
            if positions is None or not line.strip():
                continue
            match = ROW.match(line)
            if match:
                number, date_text, raw_clock = match.groups()
                shown_date = datetime.strptime(date_text, "%d %B %Y").date()
                zulu = None
                clock_status = "missing"
                if raw_clock:
                    try:
                        zulu = datetime.strptime(raw_clock.zfill(4), "%H%M").replace(
                            year=shown_date.year, month=shown_date.month, day=shown_date.day,
                            tzinfo=timezone.utc,
                        )
                        clock_status = "reported_minute"
                    except ValueError:
                        clock_status = "invalid_source_value"
                rows.append({
                    "claim_id": int(number), "document": f"S/2019/{symbol}", "pdf_page": page,
                    "reported_date_utc": shown_date.isoformat(),
                    "reported_clock_utc_raw": raw_clock or "",
                    "clock_status": clock_status,
                    "timestamp_utc": zulu.isoformat(timespec="minutes") if zulu else "",
                    "timestamp_yemen_local": zulu.astimezone(LOCAL).isoformat(timespec="minutes") if zulu else "",
                    "reported_location": line[match.end():positions[kind]].strip(),
                    "reported_category": line[positions[kind]:positions[notes]].strip(),
                    "source_attribution": "Coalition submission alleges Houthi responsibility",
                    "source_narrative": line[positions[notes]:].strip(),
                })
            elif rows and not line[:positions[location]].strip():
                # Wrapped cells may continue at the top of the next page below its header.
                for key, start, end in (
                    ("reported_location", positions[location], positions[kind]),
                    ("reported_category", positions[kind], positions[notes]),
                    ("source_narrative", positions[notes], None),
                ):
                    text = line[start:end].strip()
                    if text:
                        rows[-1][key] = (rows[-1][key] + " " + text).strip()
    first, last = REPORTS[symbol]
    if [row["claim_id"] for row in rows] != list(range(first, last + 1)):
        raise ValueError(f"Numbered claims do not match the printed sequence in S/2019/{symbol}")
    return rows


def write_csv(path, rows, fields):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    sources, source_audit = {}, {}
    for symbol in REPORTS:
        path = args.source_directory / f"S-2019-{symbol}-en.pdf"
        sources[symbol] = extract(path, symbol)
        with path.open("rb") as handle:
            digest = hashlib.file_digest(handle, "sha256").hexdigest()
        source_audit[f"S/2019/{symbol}"] = {"sha256": digest, "numbered_rows": len(sources[symbol])}
    overlap_fields = ("reported_date_utc", "reported_clock_utc_raw", "reported_location", "reported_category")
    disagreements = {field: sum(a[field] != b[field] for a, b in zip(sources[51], sources[99]))
                     for field in overlap_fields}
    rows = sources[99] + sources[206] + sources[299]
    if any(not row["reported_category"] or not row["source_narrative"] for row in rows):
        raise ValueError("A required source category or narrative is blank")
    fields = list(rows[0])
    write_csv(args.output_directory / "hudaydah-coalition-claims.csv", rows, fields[:-1])
    write_csv(args.output_directory / "hudaydah-claims-source-notes.csv", rows, fields)
    observed = [row["timestamp_yemen_local"] for row in rows if row["timestamp_yemen_local"]]
    audit = {
        "sources": source_audit,
        "repeated_claim_numbers_across_51_and_99": len(sources[51]),
        "repeated_claim_field_disagreements": disagreements,
        "distinct_numbered_claims": len(rows),
        "claims_with_clock": len(observed),
        "claims_missing_clock": sum(row["clock_status"] == "missing" for row in rows),
        "claims_invalid_clock": sum(row["clock_status"] == "invalid_source_value" for row in rows),
        "claims_missing_location": sum(not row["reported_location"] for row in rows),
        "claims_changing_date_in_local_time": sum(
            row["reported_date_utc"] != row["timestamp_yemen_local"][:10]
            for row in rows if row["timestamp_yemen_local"]
        ),
        "first_yemen_local_clock": min(observed),
        "last_yemen_local_clock": max(observed),
        "calendar_days_with_timed_claims": len({item[:10] for item in observed}),
    }
    (args.output_directory / "hudaydah-claims-audit.json").write_text(
        json.dumps(audit, indent=2) + "\n", encoding="utf-8",
    )
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
