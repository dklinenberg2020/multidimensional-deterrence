"""Validate pilot transcriptions and identify date/place or date/clock candidates."""
import argparse
import json
from pathlib import Path

import pandas as pd


def read(path):
    return pd.read_csv(path, dtype="string", keep_default_na=False)


def check_clocks(frame, columns, end_of_day=None):
    for column in columns:
        clock = frame[column]
        valid = clock.eq("") | clock.str.fullmatch(r"(?:[01][0-9]|2[0-3]):[0-5][0-9]")
        if column == end_of_day:
            valid |= clock.eq("24:00")
        if not valid.all():
            raise ValueError(f"Invalid clock in {column}")
    pd.to_datetime(frame["date"], format="%Y-%m-%d", errors="raise")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tidy_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    pilots = Path(__file__).resolve().parents[1] / "research" / "pilots"

    co = read(pilots / "colombia-subdaily.csv")
    check_clocks(co, ["clock_start", "clock_end"])
    if not co["observation_id"].is_unique:
        raise ValueError("Repeated Colombia observation ID")
    if (co["clock_end"].ne("") & co["clock_end"].lt(co["clock_start"])).any():
        raise ValueError("Reversed Colombia time range")
    cases = read(args.tidy_directory / "colombia-tidy-incidents.csv.gz")
    windows = {
        "Bojaya": ("2002-04-21", "2002-05-07", ["BOJAYA", "VIGIA DEL FUERTE"]),
        "Mitu": ("1998-11-01", "1998-11-04", ["MITU"]),
    }
    candidate_tables = []
    for episode, (start, end, places) in windows.items():
        row_filter = cases["date"].between(start, end) & cases["place"].isin(places)
        candidates = cases.loc[row_filter, [
            "incident_id", "date", "place", "source", "event_type", "actor_reported", "related_case_id",
        ]].copy()
        candidates.insert(0, "episode", episode)
        candidates.insert(1, "link_status", "episode_candidate_only")
        candidate_tables.append(candidates)
    co_candidates = pd.concat(candidate_tables, ignore_index=True)
    co_candidates.to_csv(args.output_directory / "colombia-cnmh-episode-candidates.csv", index=False)

    vn = read(pilots / "vietnam-journal.csv")
    check_clocks(vn, ["time_in", "time_out", "occurrence_start", "occurrence_end"], end_of_day="time_out")
    if vn.duplicated(["date", "journal_item"]).any():
        raise ValueError("Repeated Vietnam journal item")
    if (vn["occurrence_end"].ne("") & vn["occurrence_end"].lt(vn["occurrence_start"])).any():
        raise ValueError("Reversed Vietnam occurrence interval")
    events = read(args.tidy_directory / "vietnam-tidy-incidents.csv.gz")
    events["event_minute"] = events["event_time"].str[:5]
    matches = (
        vn.loc[vn["record_type"].eq("combat_report"), ["date", "journal_item", "time_in"]]
        .merge(
            events.loc[events["event_time"].ne(""), [
                "incident_id", "date", "event_time", "event_minute", "archive_series", "event_type", "place",
            ]],
            left_on=["date", "time_in"], right_on=["date", "event_minute"], how="inner",
        )
    )
    matches.insert(0, "link_status", "receipt_clock_collision_only")
    matches.to_csv(args.output_directory / "vietnam-clock-candidates.csv", index=False)
    collisions = matches.loc[matches["incident_id"].notna()]
    audit = {
        "colombia_observations": len(co),
        "colombia_with_subdaily_clock": int(co["clock_start"].ne("").sum()),
        "colombia_cnmh_episode_candidates": co_candidates["episode"].value_counts().to_dict(),
        "vietnam_journal_entries": len(vn),
        "vietnam_combat_reports": int(vn["record_type"].eq("combat_report").sum()),
        "vietnam_explicit_occurrence_times": int(vn["occurrence_start"].ne("").sum()),
        "vietnam_combat_reports_with_explicit_occurrence_times": int(
            (vn["record_type"].eq("combat_report") & vn["occurrence_start"].ne("")).sum()
        ),
        "vietnam_combat_reports_with_same_minute_release_clock": int(
            collisions[["date", "journal_item"]].drop_duplicates().shape[0]
        ),
        "vietnam_same_minute_candidate_incidents": len(collisions),
        "verified_event_level_links": 0,
    }
    (args.output_directory / "subdaily-pilot-audit.json").write_text(
        json.dumps(audit, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(audit, indent=2))


if __name__ == "__main__":
    main()
