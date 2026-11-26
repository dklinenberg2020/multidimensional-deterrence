"""Build source-faithful incident extracts and coverage audits."""
import argparse
import json
from pathlib import Path
import warnings

import pandas as pd

COLUMNS = [
    "source", "source_row", "source_id", "date", "time_reported", "precision",
    "event_type", "actor_reported", "recipient_reported", "actor_context",
    "place", "fatalities_civilian", "injured_civilian",
    "fatalities_friendly", "injured_friendly", "fatalities_enemy", "injured_enemy",
    "victims_reported", "physical_damage_reported", "mobility_restriction_reported",
    "economic_coercion_reported", "related_case_id",
]


def values(series):
    return series.astype("string").str.strip().replace("", pd.NA)


def parse_date(series, format):
    return pd.to_datetime(series, format=format, errors="coerce").dt.strftime("%Y-%m-%d").astype("string")


def base(data, filename, offset=1):
    result = pd.DataFrame(index=data.index, columns=COLUMNS)
    result["source"] = filename
    result["source_row"] = range(offset, offset + len(data))
    return result


def summarize(data, columns):
    return {
        "rows": len(data),
        "columns": list(data.columns),
        "exact_duplicate_rows_after_first": int(data.duplicated().sum()),
        "missing_by_field": {str(key): int(count) for key, count in data.isna().sum().items()},
        "label_counts": {
            n: {str(k): int(v) for k, v in values(data[n]).value_counts().head(20).items()}
            for n in columns if n in data
        },
    }


def iraq(path):
    raw = pd.read_csv(path, dtype="string", keep_default_na=False).replace(["", "NULL"], pd.NA)
    audit = summarize(raw, ["type", "category", "force_type", "attack_on"])
    audit["duplicate_payload_rows_after_first"] = int(raw.drop(columns=["Unnamed: 0"]).duplicated().sum())
    out = base(raw, path.name)
    stamp = values(raw["date_time_occ"]).str.replace(r"\s+", " ", regex=True)
    date = parse_date(stamp.str[:10], "%Y-%m-%d")
    date_alternative = parse_date(raw["doi"], "%d-%b-%y")
    out["date"] = date.fillna(date_alternative)
    clock = stamp.str.extract(r" (\d\d:\d\d:\d\d)$", expand=False)
    valid_clock = clock.str.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d", na=False)
    out["time_reported"] = clock.where(date.notna() & valid_clock)
    out["precision"] = out["date"].notna().map({True: "day", False: "unknown"})
    out.loc[out["time_reported"].notna(), "precision"] = "clock_reported"
    out["source_id"] = values(raw["serial"])
    out["event_type"] = values(raw["category"]).fillna(values(raw["type"]))
    out["actor_context"] = values(raw["force_type"]).replace("None Selected", pd.NA)
    out["recipient_reported"] = values(raw["attack_on"]).replace("None Selected", pd.NA)
    out["place"] = values(raw["ADM3NAME"])
    audit["occurrence_date_disagreements"] = int((date.notna() & date_alternative.notna() & date.ne(date_alternative)).sum())
    audit["midnight_clock_rows"] = int(out["time_reported"].eq("00:00:00").sum())
    return out, {path.name: audit}


def yemen(path):
    raw = pd.read_csv(path, encoding="cp1252", dtype="string", keep_default_na=False).replace("", pd.NA)
    audit = summarize(raw, [" Confirmed Time", "Time of Day", "Main category"])
    out = base(raw, path.name)
    out["date"] = parse_date(raw["Date"], "%d/%m/%Y")
    hour = pd.to_numeric(raw[" Confirmed Time"], errors="coerce")
    out["time_reported"] = values(raw[" Confirmed Time"])
    out["precision"] = "day"
    out.loc[hour.between(1, 23).fillna(False), "precision"] = "hour_reported"
    out["source_id"] = values(raw["Incident ID"])
    out["event_type"] = values(raw["Sub-category"]).fillna(values(raw["Main category"]))
    out["actor_reported"] = "Saudi/UAE-led coalition"
    out["recipient_reported"] = values(raw["Target"]).replace("Unknown", pd.NA)
    out["place"] = values(raw["Governorate"])
    out["fatalities_civilian"] = pd.to_numeric(raw["Fatalities "], errors="coerce")
    out["injured_civilian"] = pd.to_numeric(raw["Injured "], errors="coerce")
    in_period = out["date"].between("2015-01-01", "2022-12-31").fillna(False)
    audit["rows_excluded_from_historical_extract"] = int((~in_period).sum())
    audit["hour_24_or_outside_valid_range"] = int((hour.notna() & ~hour.between(1, 23)).sum())
    return out.loc[in_period], {path.name: audit}


def colombia(directory):
    output, audits, case_ids = [], {}, {}
    for path in sorted(directory.glob("*.xlsx")):
        with warnings.catch_warnings():
            warnings.filterwarnings("ignore", message="Workbook contains no default style")
            data = pd.read_excel(path, dtype="string", keep_default_na=False).replace("", pd.NA)
        ids = values(data["ID Caso"])
        category = path.stem.split("-", 1)[1]
        count = summarize(data, ["Iniciativa", "Presunto Responsable", "Modalidad"])
        count["distinct_case_ids"] = int(ids.nunique())
        count["rows_without_case_id"] = int(ids.isna().sum())
        count["rows_with_case_id_repeated_after_first"] = int(ids.dropna().duplicated().sum())
        audits[path.name] = count
        if path.stem.startswith("victimas-"):
            if category in case_ids:
                count["victim_rows_with_unmatched_case_id"] = int((ids.notna() & ~ids.isin(case_ids[category])).sum())
            continue
        case_ids[category] = set(ids.dropna())
        out = base(data, path.name, offset=2)
        out["source_id"] = ids
        out["date"] = parse_date(values(data["Año"]) + "-" + values(data["Mes"]) + "-" + values(data["Día"]), "%Y-%m-%d")
        out["precision"] = out["date"].notna().map({True: "day", False: "unknown"})
        out["event_type"] = data["Modalidad"] if "Modalidad" in data else "ATAQUE A POBLACIÓN"
        if "Descripción Presunto Responsable" in data:
            out["actor_reported"] = values(data["Descripción Presunto Responsable"]).replace(
                ["NO APLICA", "SIN INFORMACIÓN", "DESCONOCIDO"], pd.NA
            ).fillna(values(data["Presunto Responsable"]).replace(["DESCONOCIDO", "SIN INFORMACIÓN"], pd.NA))
        if "Iniciativa" in data:
            out["actor_context"] = values(data["Iniciativa"]).replace("SIN INFORMACIÓN", pd.NA)
        out["place"] = data["Municipio"]
        for field, source in {
            "related_case_id": "ID Caso Relacionado",
            "injured_civilian": "Lesionados Civiles",
            "victims_reported": "Total de Víctimas del Caso",
            "mobility_restriction_reported": "Confinamiento o Restricción a la Movilidad",
            "economic_coercion_reported": "Extorsión",
            "physical_damage_reported": "Descripción Tipo de Bien",
        }.items():
            if source in data:
                out[field] = data[source]
        output.append(out.loc[ids.notna()].astype("string"))
    audits["distinct_ids_in_multiple_case_workbooks"] = sum(
        sum(event_id in ids for ids in case_ids.values()) > 1
        for event_id in set().union(*case_ids.values())
    )
    return pd.concat(output, ignore_index=True), audits


def vietnam(directory):
    import pyreadr

    audits = {}
    out = None
    for path in sorted(directory.glob("vietwar_*.rds")):
        data = pyreadr.read_r(str(path))[None]
        audits[path.name] = summarize(data, ["aggressor_side", "initiating_side"])
        if path.name != "vietwar_ground_combat.rds":
            continue
        out = base(data, path.name)
        out["source_id"] = values(data["master_event_id"])
        out["date"] = parse_date(values(data["initiation_date"]).str[:10], "%Y-%m-%d")
        out["time_reported"] = values(data["initiation_time"])
        out["precision"] = out["date"].notna().map({True: "day", False: "unknown"})
        seconds = pd.to_numeric(out["time_reported"], errors="coerce")
        within_day = seconds.gt(0) & seconds.lt(86400)
        out.loc[out["date"].notna() & within_day.fillna(False), "precision"] = "clock_reported"
        combined_audit = audits[path.name]
        combined_audit["time_zero_rows"] = int(seconds.eq(0).sum())
        combined_audit["time_86400_rows"] = int(seconds.eq(86400).sum())
        combined_audit["other_nonblank_time_outside_day_rows"] = int(
            (out["time_reported"].notna() & ~within_day.fillna(False) & ~seconds.isin([0, 86400])).sum()
        )
        combined_audit["dated_after_documented_sitra_end"] = int(out["date"].gt("1973-03-12").sum())
        out["actor_reported"] = values(data["aggressor_side"])
        out["actor_context"] = values(data["aggressor_sub_group"])
        out["event_type"] = values(data["general_action_category"])
        out["place"] = values(data["prov_name"])
        out["archive_series"] = values(data["data_file_origin"])
        for field, source in {
            "fatalities_friendly": "n_friendly_kia", "injured_friendly": "n_friendly_wia",
            "fatalities_enemy": "n_enemy_kia", "injured_enemy": "n_enemy_wia",
        }.items():
            out[field] = data[source]
    if out is None:
        raise ValueError("The combined Vietnam release is required")
    return out, audits


def main():
    builds = {
        "iraq": lambda directory: iraq(directory / "IQ_SIGACTs.csv"),
        "yemen": lambda directory: yemen(directory / "air-raids-2015-2026.csv"),
        "colombia": colombia,
        "vietnam": vietnam,
    }
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_directory", type=Path)
    parser.add_argument("output_directory", type=Path)
    parser.add_argument("--country", choices=builds, action="append")
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    for country in args.country or builds:
        out, audit = builds[country](args.source_directory / country)
        dates = out["date"].dropna()
        keys = out.loc[out["source_id"].notna(), ["source", "source_id"]]
        report = {
            "incident_rows": len(out),
            "first_date": dates.min() if len(dates) else None,
            "last_date": dates.max() if len(dates) else None,
            "precision": out["precision"].value_counts().to_dict(),
            "missing_by_field": {key: int(value) for key, value in out.isna().sum().items()},
            "duplicate_source_keys_after_first": int(keys.duplicated().sum()),
            "sources": audit,
        }
        output_path = args.output_directory / f"{country}-incidents.csv.gz"
        out.to_csv(output_path, index=False, compression={"method": "gzip", "mtime": 0})
        (args.output_directory / f"{country}-audit.json").write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"{country}: {len(out):,} rows ({report['first_date']} to {report['last_date']})", flush=True)


if __name__ == "__main__":
    main()
