"""Index the dated entries and candidate clock expressions in CINEP 2002 issues 23–26."""
import argparse
import csv
from datetime import date
import hashlib
import json
from pathlib import Path
import re
import unicodedata

import fitz


MONTHS = {
    name.casefold(): index for index, name in enumerate(
        ("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"), 1
    )
}
FILES = {
    f"{month:02}": f"cinep-{23 + (month - 1) // 3}-{month:02}02.pdf" for month in range(1, 13)
}
FILES["06"] = "cinep-24-media.pdf"
HEADING = re.compile(r"(" + "|".join(MONTHS) + r")\s+(\d{1,2})\s*/\s*2002", re.I)
CLOCK = re.compile(
    r"\b(?:[01]?\d|2[0-4])[:.]\d{2}\b"
    r"|\b(?:a|hacia|sobre)\s+las\s+(?:una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce)"
    r"(?:\s+y\s+media)?\b",
    re.I,
)


def page_lines(page):
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            text = "".join(span["text"] for span in line["spans"]).strip()
            if text:
                yield line["bbox"], text


def index_pdf(path, month):
    with fitz.open(path) as pdf:
        rows = []
        for page_number, page in enumerate(pdf, 1):
            lines = list(page_lines(page))
            starts = [(box, m) for box, text in lines if (m := HEADING.fullmatch(text)) and MONTHS[m[1].casefold()] == int(month)]
            for box, heading in sorted(starts, key=lambda entry: (round(entry[0][1], 1), entry[0][0])):
                right, top = box[2], box[1]
                headers = sorted(
                    ((b[1], text) for b, text in lines
                     if top < b[1] < top + 64 and abs(b[2] - right) < 5
                     and text.startswith(("DEPARTAMENTO:", "MUNICIPIO:"))),
                )
                labels = dict(text.split(":", 1) for _, text in headers)
                if "MUNICIPIO" not in labels or "DEPARTAMENTO" not in labels:
                    continue
                next_heading = min(
                    (b[1] for b, _ in starts if abs(b[2] - right) < 5 and b[1] > top + 10),
                    default=page.rect.height - 34,
                )
                region = fitz.Rect(max(right - 171, 0), top, min(right + 2, page.rect.width), next_heading)
                text = unicodedata.normalize("NFC", page.get_text(clip=region, sort=True))
                expressions = [item.group(0) for item in CLOCK.finditer(text)]
                rows.append({
                    "source_month": month,
                    "pdf_page": page_number,
                    "heading_date": date(2002, int(month), int(heading[2])).isoformat(),
                    "department": labels["DEPARTAMENTO"].strip(),
                    "municipality": labels["MUNICIPIO"].strip(),
                    "clock_like_expressions": len(expressions),
                    "expressions_for_review": " | ".join(expressions),
                    "status": "candidate_only",
                })
        with path.open("rb") as handle:
            digest = hashlib.file_digest(handle, "sha256").hexdigest()
        audit = {
            "pdf_pages": len(pdf), "sha256": digest, "detected_dated_case_headings": len(rows),
            "case_fragments_with_clock_like_text": sum(r["clock_like_expressions"] > 0 for r in rows),
            "clock_like_expressions": sum(r["clock_like_expressions"] for r in rows),
        }
    return rows, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    combined, audit = [], {}
    for month, filename in FILES.items():
        rows, audit[month] = index_pdf(args.source_directory / filename, month)
        combined.extend(rows)
    with (args.output_directory / "cinep-2002-clock-review-queue.csv").open(
        "w", newline="", encoding="utf-8",
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=list(combined[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(combined)
    (args.output_directory / "cinep-2002-index-audit.json").write_text(
        json.dumps(audit, indent=2) + "\n", encoding="utf-8",
    )
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
