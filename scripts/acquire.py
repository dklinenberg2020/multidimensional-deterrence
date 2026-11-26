"""Retrieve and verify the exact source files listed in the research manifest."""
import argparse
import csv
import hashlib
from pathlib import Path
import subprocess
from tempfile import NamedTemporaryFile


def sha256(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--country", action="append")
    args = parser.parse_args()
    manifest = Path(__file__).resolve().parents[1] / "research" / "sources.csv"
    with manifest.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            if args.country and row["country"] not in args.country:
                continue
            path = args.source_directory / row["country"] / row["filename"]
            if path.is_file() and sha256(path) == row["sha256"]:
                print(f"Verified {path}")
                continue
            if args.verify_only:
                raise ValueError(f"Missing or mismatched snapshot {path}")
            path.parent.mkdir(parents=True, exist_ok=True)
            with NamedTemporaryFile(dir=path.parent, delete=False) as handle:
                temporary_path = Path(handle.name)
            try:
                subprocess.run(
                    ["curl", "--fail", "--location", "--silent", "--show-error",
                     "--retry", "2", "--max-time", "300", "--output",
                     str(temporary_path), row["source_url"]],
                    check=True,
                )
                if sha256(temporary_path) != row["sha256"]:
                    raise ValueError(f"Publisher snapshot changed for {path}")
                temporary_path.replace(path)
                print(f"Downloaded and verified {path}")
            finally:
                temporary_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
