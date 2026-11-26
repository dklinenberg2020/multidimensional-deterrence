"""Audit clock resolution and recorded chronology in VietnamWarData v1.0.0."""

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadr


SIDES = {"Friendly", "Enemy"}
CASUALTY_FIELDS = ["n_friendly_kia", "n_friendly_wia", "n_enemy_kia", "n_enemy_wia"]
LOSS_FIELDS = [
    "n_friendly_structures_lost", "n_enemy_structures_lost", "n_food_lost",
    "n_enemy_food_lost", "n_friendly_fuel_lost", "n_enemy_fuel_gallons_lost",
    "n_vehicles_lost_by_enemy", "n_enemy_vehicles_lost",
    "n_friendly_weapons_lost", "n_enemy_weapons_lost",
]


def counts(series):
    return {str(key): int(value) for key, value in series.value_counts().items()}


def numeric_coverage(frame, fields):
    coverage = {}
    for name in fields:
        value = pd.to_numeric(frame[name], errors="coerce")
        coverage[name] = {
            "populated": int(frame[name].notna().sum()),
            "numeric": int(value.notna().sum()),
            "source_zero": int(value.eq(0).sum()),
            "positive": int(value.gt(0).sum()),
        }
    return coverage


def source_summary(frame):
    timed = frame.loc[frame["valid_clock"]]
    # The convenient machine-readable CSV stores seconds since midnight.
    clock = timed["initiation_time"].astype(int)
    return {
        "rows": len(frame),
        "first_date": frame["date"].min().strftime("%Y-%m-%d"),
        "last_date": frame["date"].max().strftime("%Y-%m-%d"),
        "valid_clocks": len(timed),
        "rows_by_initiator": counts(frame["aggressor_side"].fillna("unspecified")),
        "timed_by_initiator": counts(timed["aggressor_side"].fillna("unspecified")),
        "exact_hour": int(clock.mod(3600).eq(0).sum()),
        "exact_half_hour_excluding_hour": int(clock.mod(3600).eq(1800).sum()),
        "off_five_minute_grid": int(clock.mod(300).ne(0).sum()),
        "nonzero_seconds_past_minute": int(clock.mod(60).ne(0).sum()),
        "most_frequent_clock": f"{int(clock.mode().iloc[0]) // 3600:02d}:{int(clock.mode().iloc[0]) % 3600 // 60:02d}",
        "most_frequent_clock_rows": int(clock.value_counts().iloc[0]),
        "clock_1601_rows": int(clock.eq(16 * 3600 + 60).sum()),
        "boundary_clock": int(frame["initiation_time"].isin([0, 86400]).sum()),
        "both_sides_four_casualty_fields": int(frame[CASUALTY_FIELDS].notna().all(axis=1).sum()),
        "target_specific_populated": int(frame["target_specific"].notna().sum()),
        "data_type_counts": counts(frame["data_type"].fillna("unspecified")),
    }


def distance_km(pairs):
    lat1, lat2 = np.radians(pairs["lat"]), np.radians(pairs["next_lat"])
    dlat = lat2 - lat1
    dlon = np.radians(pairs["next_lng"] - pairs["lng"])
    a = np.sin(dlat / 2) ** 2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon / 2) ** 2
    return 6371.0088 * 2 * np.arcsin(np.sqrt(a.clip(0, 1)))


def adjacent_clock_pairs(frame):
    """Use adjacent distinct timestamp buckets within each source, province and date."""
    partition = ["data_file_origin", "prov_name", "date"]
    clock_key = partition + ["initiation_time"]
    timed = frame.loc[frame["valid_clock"] & frame["prov_name"].notna()].copy()
    timed = timed.sort_values(clock_key, kind="stable")
    bucket_size = timed.groupby(clock_key, sort=False)["master_event_id"].transform("size")
    timed["bucket_size"] = bucket_size
    buckets = timed.drop_duplicates(clock_key).copy()
    side_counts = timed.loc[timed["aggressor_side"].isin(SIDES)].groupby(clock_key, sort=False)["aggressor_side"].nunique()
    shifts = [
        "master_event_id", "initiation_time", "aggressor_side", "bucket_size", "record_id",
        "lat", "lng", "valid_location", "four_casualty_fields", "target_specific", "data_type",
    ]
    following = buckets.groupby(partition, sort=False)[shifts].shift(-1).add_prefix("next_")
    buckets = buckets.join(following)
    pairs = buckets.loc[
        buckets["bucket_size"].eq(1) & buckets["next_bucket_size"].eq(1)
        & buckets["aggressor_side"].isin(SIDES) & buckets["next_aggressor_side"].isin(SIDES)
        & buckets["aggressor_side"].ne(buckets["next_aggressor_side"])
    ].copy()
    pairs["gap_minutes"] = (pairs["next_initiation_time"] - pairs["initiation_time"]) / 60
    pairs["distance_km"] = distance_km(pairs).where(
        pairs["valid_location"] & pairs["next_valid_location"].eq(True)
    )
    return pairs, {
        "timed_rows_with_province": len(timed),
        "rows_in_same_source_province_date_clock_ties": int(bucket_size.gt(1).sum()),
        "clock_buckets_with_both_initiator_labels": int(side_counts.eq(2).sum()),
    }


def pair_summary(pairs):
    near = pairs["distance_km"].le(5)
    short = pairs["gap_minutes"].between(1, 30)
    strict = pairs.loc[near & short]
    return {
        "adjacent_distinct_singleton_clock_pairs_opposite_side": len(pairs),
        "with_valid_coordinates_both_rows": int(pairs["distance_km"].notna().sum()),
        "within_30_minutes": int(short.sum()),
        "within_30_minutes_and_5_km": len(strict),
        "within_5_minutes_and_5_km": int((near & pairs["gap_minutes"].le(5)).sum()),
        "within_120_minutes_and_5_km": int((near & pairs["gap_minutes"].le(120)).sum()),
        "within_30_minutes_and_10_km": int((short & pairs["distance_km"].le(10)).sum()),
        "within_30_minutes_and_5_km_same_record_id": int(strict["record_id"].eq(strict["next_record_id"]).sum()),
        "within_30_minutes_and_5_km_both_rows_four_casualty_fields": int(
            (strict["four_casualty_fields"] & strict["next_four_casualty_fields"].eq(True)).sum()
        ),
        "within_30_minutes_and_5_km_both_rows_target_specific": int(
            (strict["target_specific"].notna() & strict["next_target_specific"].notna()).sum()
        ),
        "within_30_minutes_and_5_km_by_first_initiating_side": counts(strict["aggressor_side"]),
        "within_30_minutes_and_5_km_by_year": counts(strict["date"].dt.year),
        "within_30_minutes_and_5_km_touching_large_unit_operation": int(
            (strict["data_type"].eq("large_unit_operation")
             | strict["next_data_type"].eq("large_unit_operation")).sum()
        ),
        "within_30_minutes_and_5_km_neither_clock_on_five_minute_grid": int(
            (strict["initiation_time"].mod(300).ne(0)
             & strict["next_initiation_time"].mod(300).ne(0)).sum()
        ),
    }


def vndba_audit(path, combined, close_pairs):
    raw = pyreadr.read_r(str(path))[None]
    master = combined.loc[combined["data_file_origin"].eq("VNDBA")].copy()
    # Exact source serial and date are used only for an unambiguous one-to-one join.
    left = master.assign(serial=master["record_id"])
    right = raw.assign(serial=raw["sitrep_number"], date=pd.to_datetime(raw["start_date"]))
    keys = ["serial", "date"]
    right = right.loc[right["serial"].notna() & right["date"].notna()]
    left_unique = left.drop_duplicates(keys, keep=False)
    right_unique = right.drop_duplicates(keys, keep=False)
    matched = left_unique.merge(right_unique[keys + LOSS_FIELDS + ["start_time"]], on=keys, validate="one_to_one")
    compare = matched.loc[matched["valid_clock"] & matched["start_time"].notna()]
    # The component release uses HH:MM strings, including a 24:00 boundary.
    clock = compare["start_time"].str.extract(r"^(\d{2}):([0-5]\d)$").astype(float)
    source_clock = clock[0] * 3600 + clock[1] * 60
    pair_ends = set(close_pairs["master_event_id"]) | set(close_pairs["next_master_event_id"])
    linked_close = matched.loc[matched["master_event_id"].isin(pair_ends)].set_index("master_event_id")
    linked_ids = linked_close.index
    both_linked = close_pairs["master_event_id"].isin(linked_ids) & close_pairs["next_master_event_id"].isin(linked_ids)
    loss_columns = [field for field in LOSS_FIELDS if "weapons" not in field]
    positive_loss = linked_close[loss_columns].apply(pd.to_numeric, errors="coerce").gt(0).any(axis=1)
    positive_ids = positive_loss[positive_loss].index
    either_end_positive = (
        close_pairs["master_event_id"].isin(positive_ids)
        | close_pairs["next_master_event_id"].isin(positive_ids)
    )
    support_fields = ["support_request_time", "support_received_time"]
    valid_support = raw[support_fields].apply(
        lambda field: field.str.fullmatch(r"(?:0[1-9]|[12][0-9]|3[01])(?:[01][0-9]|2[0-3])[0-5][0-9]", na=False)
    )
    return {
        "component_rows": len(raw),
        "unique_serial_date_components_matching_master": len(matched),
        "matched_both_clock_fields_valid": int(source_clock.between(1, 86399).sum()),
        "matched_valid_clock_agreement": int(
            (source_clock.between(1, 86399) & source_clock.eq(compare["initiation_time"])).sum()
        ),
        "component_loss_fields": numeric_coverage(raw, LOSS_FIELDS),
        "matched_loss_fields": numeric_coverage(matched, LOSS_FIELDS),
        "close_pairs_both_endpoints_linked_to_component": int(both_linked.sum()),
        "close_pairs_both_endpoints_linked_with_any_positive_nonweapons_loss": int(
            (both_linked & either_end_positive).sum()
        ),
        "component_both_support_fields_populated": int(raw[support_fields].notna().all(axis=1).sum()),
        "component_valid_ddhhmm_support_request": int(valid_support["support_request_time"].sum()),
        "component_valid_ddhhmm_support_receipt": int(valid_support["support_received_time"].sum()),
        "component_valid_ddhhmm_support_both": int(valid_support.all(axis=1).sum()),
        "component_support_request_field_populated": int(raw["support_request_time"].notna().sum()),
        "component_support_received_field_populated": int(raw["support_received_time"].notna().sum()),
        "component_same_day_action_counter_gt_one": int(pd.to_numeric(raw["n_actions_initiated_same_day"], errors="coerce").gt(1).sum()),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("--candidate-csv", type=Path)
    args = parser.parse_args()
    frame = pyreadr.read_r(str(args.source_directory / "vietwar_ground_combat.rds"))[None]
    frame["date"] = pd.to_datetime(frame["initiation_date"], errors="raise")
    frame["valid_clock"] = frame["initiation_time"].between(1, 86399)
    frame["valid_location"] = (
        frame["outside_south_vietnam"].eq(0) & frame["coord_over_ocean"].eq(0)
        & frame["lat"].between(-90, 90) & frame["lng"].between(-180, 180)
    )
    frame["four_casualty_fields"] = frame[CASUALTY_FIELDS].notna().all(axis=1)
    if not frame["master_event_id"].is_unique or frame["date"].isna().any():
        raise ValueError("Invalid master IDs or dates")
    pairs, collisions = adjacent_clock_pairs(frame)
    if not pairs["gap_minutes"].gt(0).all():
        raise ValueError("Adjacent clock pairs must have a positive time gap")
    by_source = {name: source_summary(group) for name, group in frame.groupby("data_file_origin")}
    close_pairs = pairs.loc[pairs["gap_minutes"].le(30) & pairs["distance_km"].le(5)]
    post_ceasefire = frame["date"].ge("1973-01-27")
    summary = {
        "release_rows": len(frame),
        "post_ceasefire_rows": int(post_ceasefire.sum()),
        "post_ceasefire_valid_clocks": int((post_ceasefire & frame["valid_clock"]).sum()),
        "after_documented_sitra_end_rows": int(frame["date"].gt("1973-03-12").sum()),
        "post_ceasefire_close_pairs": int(close_pairs["date"].ge("1973-01-27").sum()),
        "valid_clocks": int(frame["valid_clock"].sum()),
        "source_breakdown": by_source,
        "clock_bucket_counts": collisions,
        "pairs_all": pair_summary(pairs),
        "pairs_by_source": {
            name: pair_summary(pairs.loc[pairs["data_file_origin"].eq(name)])
            for name in sorted(by_source)
        },
        "vndba_source_check": vndba_audit(
            args.source_directory / "vietwar_vndba.rds",
            frame,
            close_pairs.loc[close_pairs["data_file_origin"].eq("VNDBA")],
        ),
    }
    if args.candidate_csv:
        columns = [
            "data_file_origin", "prov_name", "date", "master_event_id", "next_master_event_id",
            "aggressor_side", "next_aggressor_side", "initiation_time", "next_initiation_time",
            "gap_minutes", "distance_km", "general_action_category", "data_type", "next_data_type",
        ]
        close_pairs[columns].to_csv(args.candidate_csv, index=False, float_format="%.6f")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
