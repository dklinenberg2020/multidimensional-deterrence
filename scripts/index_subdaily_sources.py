"""Index acquired archival scans and build a page-level transcription queue."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re

import fitz


# PDF page, original column (1=left), OCR line offset in the pinned scan.
# Boundaries were checked against the printed addendum sequence.
CYPRUS_HEADINGS = [
    (48, 1, 1), (49, 1, 30), (49, 2, 2), (50, 1, 38), (50, 2, 17),
    (51, 2, 2), (52, 1, 26), (52, 2, 20), (53, 2, 27), (54, 1, 18),
    (54, 1, 35), (54, 2, 23), (55, 1, 35), (55, 2, 33), (56, 1, 27),
    (56, 2, 4), (57, 2, 47), (59, 1, 17), (59, 2, 8), (60, 1, 5),
    (60, 1, 23), (60, 2, 14), (60, 2, 29), (60, 2, 43), (61, 1, 16),
    (61, 2, 40), (63, 1, 38), (64, 1, 15), (64, 2, 18), (65, 2, 26),
    (65, 2, 45), (66, 1, 20), (66, 1, 40), (66, 2, 38),
]
# Stop at the next Security Council document heading.
CYPRUS_END = (66, 2, 55)
CYPRUS_SHA256 = "f4af8c43d1ca9c4fec0798b38e6098f8a51fa50233d45814cf3a2ac06113b89c"


def sha256(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def scan_cyprus(source, output):
    digest = sha256(source)
    if digest != CYPRUS_SHA256:
        raise ValueError("Cyprus report boundaries require the pinned PDF")
    lines = []
    with fitz.open(source) as document:
        for page_number in range(48, CYPRUS_END[0] + 1):
            page = document[page_number - 1]
            middle = page.rect.width / 2
            for column, (left, right) in enumerate(((0, middle), (middle, page.rect.width)), 1):
                region = fitz.Rect(left, 29, right, page.rect.height - 33)
                for offset, line in enumerate(page.get_text(clip=region, sort=True).splitlines()):
                    lines.append(((page_number, column, offset), line.strip()))
    lookup = {position: index for index, (position, _) in enumerate(lines)}
    starts = [lookup[heading] for heading in CYPRUS_HEADINGS]
    if starts != sorted(set(starts)):
        raise ValueError("Cyprus report boundaries are out of order")
    rows, candidates = [], []
    clock_syntax = re.compile(r"\b(?:[01]\d|2[0-3])[0-5]\d\s*(?:hours?|hrs?\b)|"
                              r"\b(?:at|until|between|from|and)\s+(?:[01]\d|2[0-3])[0-5]\d\b", re.I)
    for number, (left, right) in enumerate(zip(starts, starts[1:] + [lookup[CYPRUS_END]])):
        segment = lines[left:right]
        code = "S/11353" + (f"/Add.{number}" if number else "")
        rows.append({
            "document": code, "pdf_page_first": segment[0][0][0],
            "pdf_column_first": segment[0][0][1], "pdf_page_last": segment[-1][0][0],
            "heading_ocr": " ".join(text for _, text in segment[:3]),
            "clock_candidates": sum(bool(clock_syntax.search(text)) for _, text in segment),
        })
        for index, (position, line) in enumerate(segment):
            if clock_syntax.search(line):
                candidates.append({
                    "document": code, "pdf_page": position[0], "column": position[1],
                    "column_line": position[2], "status": "unreviewed_ocr",
                    "context_ocr": " ".join(text for _, text in segment[max(index - 1, 0):index + 2]),
                })
    write_csv(output / "cyprus-report-register.csv", rows)
    write_csv(output / "cyprus-clock-review-queue.csv", candidates)
    return {"reports_indexed": len(rows), "candidate_lines": len(candidates), "source_sha256": digest}


def scan_vietnam(source, output):
    rows = []
    with fitz.open(source) as document:
        for index, page in enumerate(document, 1):
            text = page.get_text(sort=True)
            rows.append({"pdf_page": index, "status": "unreviewed_source_ocr", "page_ocr": text})
    write_csv(output / "vietnam-journal-page-review-queue.csv", rows)
    return {"pages_indexed": len(rows), "source_sha256": sha256(source)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    audit = {
        "cyprus": scan_cyprus(args.source_directory / "cyprus/un-security-council-1974-q3.pdf", args.output_directory),
        "vietnam": scan_vietnam(args.source_directory / "vietnam/35th-1968-01-01-15.pdf", args.output_directory),
    }
    (args.output_directory / "source-index-audit.json").write_text(json.dumps(audit, indent=2) + "\n")
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
