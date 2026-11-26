"""Build tidy Vietnam and Colombia tables from the standardized extracts and source workbooks."""
import argparse
import json
from pathlib import Path
import warnings

import pandas as pd

from standardize import parse_date, values


def read_csv(path):
    return pd.read_csv(path, dtype="string", keep_default_na=False).replace("", pd.NA)


def read_workbook(path, **kwargs):
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message="Workbook contains no default style")
        return pd.read_excel(path, dtype="string", keep_default_na=False, **kwargs).replace("", pd.NA)


def integers(series, field, allowed=None):
    numbers = pd.to_numeric(series, errors="coerce")
    invalid = numbers.isna() | numbers.lt(0) | numbers.mod(1).ne(0)
    if allowed is not None:
        invalid |= ~numbers.isin(allowed)
    if (series.notna() & invalid).any():
        raise ValueError(f"Invalid {field} values: {series[series.notna() & invalid].head().tolist()}")
    return numbers.astype("Int64")


def incident_table(extract_directory, country, fields):
    source = read_csv(extract_directory / f"{country}-incidents.csv.gz")
    out = source[["source", "source_row", "source_id", "date", *fields]].copy()
    dataset = out["source"].str.replace(r"\.[^.]+$", "", regex=True)
    out.insert(0, "incident_id", country + ":" + dataset + ":" + out["source_id"])
    if out["incident_id"].isna().any() or not out["incident_id"].is_unique:
        raise ValueError(f"Missing or duplicate {country} incident identifiers")
    out["source_row"] = integers(out["source_row"], "source_row")
    return source, out


def vietnam(extract_directory):
    measures = ["fatalities_friendly", "injured_friendly", "fatalities_enemy", "injured_enemy"]
    source, out = incident_table(
        extract_directory, "vietnam",
        ["archive_series", "event_type", "actor_reported", "actor_context", "place", *measures],
    )
    for field in measures:
        out[field] = integers(out[field], field)
    raw = pd.to_numeric(source["time_reported"], errors="raise").astype("Int64")
    usable = raw.between(1, 86399).fillna(False)
    seconds = raw.where(usable)
    out["event_time"] = (
        (seconds // 3600).astype("string").str.zfill(2) + ":"
        + (seconds % 3600 // 60).astype("string").str.zfill(2) + ":"
        + (seconds % 60).astype("string").str.zfill(2)
    )
    out["time_seconds_reported"] = raw
    out["time_status"] = "out_of_range"
    out.loc[raw.isna(), "time_status"] = "missing"
    out.loc[raw.isin([0, 86400]), "time_status"] = "ambiguous_boundary"
    out.loc[usable, "time_status"] = "reported_clock"
    out["outside_documented_sitra_period"] = (
        out["archive_series"].eq("SITRA") & out["date"].gt("1973-03-12")
    )
    return out


def colombia(source_directory, extract_directory):
    counts = ["injured_civilian", "victims_reported"]
    indicators = ["mobility_restriction_reported", "economic_coercion_reported"]
    _, out = incident_table(
        extract_directory, "colombia",
        ["event_type", "actor_reported", "actor_context", "place", "physical_damage_reported",
         "related_case_id", *counts, *indicators],
    )
    for field in counts:
        out[field] = integers(out[field], field)
    for field in indicators:
        out[field] = integers(out[field], field, {0, 1}).astype("boolean")
    enrichment, victim_tables = [], []
    case_keys = ["source", "source_id"]
    date_parts = {"Año": "event_year", "Mes": "event_month", "Día": "event_day"}
    native_to_tidy = {"ID Caso": "source_id", **date_parts, "Departamento": "department",
                      "Código DANE de Municipio": "municipality_dane"}
    for name in sorted(out["source"].unique()):
        path = source_directory / "colombia" / name
        cases = read_workbook(path, usecols=list(native_to_tidy)).rename(columns=native_to_tidy)
        cases["source"] = name
        cases["source_id"] = values(cases["source_id"])
        enrichment.append(cases.loc[cases["source_id"].notna()])
        victims_path = path.with_name(path.name.replace("casos-", "victimas-", 1))
        victims = read_workbook(victims_path)
        cases_for_join = out.loc[out["source"].eq(name), ["source_id", "incident_id"]]
        victims.insert(0, "source_row", range(2, len(victims) + 2))
        victims.insert(0, "source", victims_path.name)
        victims = victims.merge(cases_for_join, left_on="ID Caso", right_on="source_id",
                                how="left", validate="many_to_one").drop(columns="source_id")
        if victims["incident_id"].isna().any():
            raise ValueError(f"Unmatched Colombia victim records in {victims_path.name}")
        victim_tables.append(victims.set_index(["incident_id", "source", "source_row"]))
    out = out.merge(pd.concat(enrichment, ignore_index=True), on=case_keys,
                    how="left", validate="one_to_one", indicator=True)
    if not out.pop("_merge").eq("both").all():
        raise ValueError("Some Colombia incidents could not be linked to their source workbook")
    year = values(out["event_year"])
    month = pd.to_numeric(out["event_month"], errors="coerce")
    day = pd.to_numeric(out["event_day"], errors="coerce")
    valid_year = year.str.fullmatch(r"[1-9]\d{3}", na=False)
    valid_month = valid_year & month.between(1, 12).fillna(False)
    parsed = parse_date(year + "-" + values(out["event_month"]) + "-" + values(out["event_day"]), "%Y-%m-%d")
    if not parsed.fillna("").eq(out["date"].fillna("")).all():
        raise ValueError("Colombia dates disagree with the standardized extract")
    out["event_year"] = pd.to_numeric(year.where(valid_year)).astype("Int64")
    out["event_month"] = month.where(valid_month).astype("Int64")
    out["event_day"] = day.where(parsed.notna()).astype("Int64")
    out["municipality_dane"] = values(out["municipality_dane"])
    out["date_precision"] = "unknown"
    out.loc[valid_year, "date_precision"] = "year"
    out.loc[valid_month, "date_precision"] = "month"
    out.loc[parsed.notna(), "date_precision"] = "day"
    victims = pd.concat(victim_tables).reset_index()
    return out, victims


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("extract_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    vn = vietnam(args.extract_directory)
    co, victims = colombia(args.source_directory, args.extract_directory)
    tables = {
        "vietnam-tidy-incidents": vn,
        "colombia-tidy-incidents": co,
        "colombia-tidy-victims": victims,
    }
    for name, table in tables.items():
        table.to_csv(args.output_directory / f"{name}.csv.gz", index=False,
                     compression={"method": "gzip", "mtime": 0})
    report = {
        "vietnam_incidents": len(vn),
        "vietnam_time_status": vn["time_status"].value_counts().to_dict(),
        "vietnam_late_sitra_rows": int(vn["outside_documented_sitra_period"].sum()),
        "colombia_incidents": len(co),
        "colombia_date_precision": co["date_precision"].value_counts().to_dict(),
        "colombia_victim_rows": len(victims),
        "colombia_incidents_with_victim_rows": int(victims["incident_id"].nunique()),
        "colombia_victim_rows_without_incident": int(victims["incident_id"].isna().sum()),
    }
    (args.output_directory / "tidy-audit.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
