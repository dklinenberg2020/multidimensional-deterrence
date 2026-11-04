"""Build registry/ship_strike_ids.csv and extend registry/vessels.csv from the sourced
ship-identification research files (data/raw/ship_identification/<date>/batch*.csv).

Run from repo root:  python3 py/build_ship_ids.py
Inputs : data/raw/ship_identification/2026-11-03/batch1.csv, batch2.csv  (one source URL per row)
         output/ship_strikes.csv (current ship strikes; used for strikes already named in headlines)
         registry/vessels.csv
Outputs: registry/ship_strike_ids.csv (overwritten), registry/vessels.csv (new vessels appended)
Rules  : * same vessel struck within 3 days = one event; the earliest-reported strike is primary,
           the rest are status=duplicate (duplicate_of = primary strike_id)
         * unnamed duplicates come only from the researchers' explicit notes (UNNAMED_DUPS)
         * is_ship_strike: yes -> ship_strike, no -> not_ship_strike, unclear -> unclear
"""
import csv, re, datetime as dt
from pathlib import Path

RAW = Path("data/raw/ship_identification/2026-11-03")
MILITARY = re.compile(r"navy|naval|landing ship|submarine|cable ship", re.I)
# researcher-stated duplicates among UNNAMED rows: row -> primary row (batch files)
UNNAMED_DUPS = {18: 7, 19: 7, 38: 37, 41: 40, 53: 51, 76: 75}
# duplicates ACROSS review files (each review file only saw its own rows):
#  26 Dec 2025 Odesa/Mykolaiv drone attack (Slovak/Palau/Liberian ships) -> primary row 172
#  Valery Gorchakov, Rostov-on-Don 18 Dec 2025 -> primary row 183
CROSS_DUPS = {173: 172, 179: 172, 184: 183}
# sea-area corrections stated by researchers
LOCATION = {57: "Black Sea", 72: "Sea of Azov", 80: "Sea of Azov"}
# headline-named strikes (already in output/ship_strike.csv) whose VIINA date is wrong:
# vessel_id -> (actual date, source)
NAMED_FIX = {
    "V_NAMURA_QUEEN": ("2022-02-25", "https://www.navalnews.com/?p=30848"),
    "V_MILLENNIAL_SPIRIT": ("2022-02-25", "https://www.navalnews.com/?p=30848"),
    "V_MJ_PINAR": ("2025-03-11", "https://gcaptain.com/four-killed-in-russian-strike-on-grain-ship-in-odesa-port/"),
    "V_GOLDEN_LEO": ("2026-07-19", "https://maritime-executive.com/article/multiple-crewmembers-killed-in-russian-strike-on-turkish-bulker"),
}

def norm(s):
    s = re.sub(r"\(.*?\)", "", s or "").strip().upper()
    return re.sub(r"\s+", " ", s)

def vid(name):
    return "V_" + re.sub(r"[^A-Z0-9]+", "_", norm(name)).strip("_")

vessels = list(csv.DictReader(open("registry/vessels.csv", encoding="utf-8")))
alias = {}
for v in vessels:
    for n in [v["name_en"]] + v["name_variants"].split(";"):
        alias[norm(n)] = v["vessel_id"]

rows = []
for f in sorted(RAW.glob("batch*.csv")):
    rows += list(csv.DictReader(open(f, encoding="utf-8")))
# review files (rows 101+): duplicate_of_row / known_vessel columns; a cell may name several ships
for f in sorted(RAW.glob("review*.csv")):
    for r in csv.DictReader(open(f, encoding="utf-8")):
        names = r.get("known_vessel") or r.get("vessel_name") or ""
        parts = [p.strip() for p in re.split(r"\s*(?:,|;|\band\b|\bта\b)\s*", names) if p.strip()] or [""]
        dup = (r.get("duplicate_of_row") or "").strip()
        for k, nm in enumerate(parts):
            rr = dict(r)
            rr["vessel_name"] = nm
            if k > 0 or r.get("known_vessel"):     # particulars belong to the single new vessel only
                rr["imo"] = rr["dwt"] = "" if (k > 0 or r.get("known_vessel")) else rr["imo"]
            rr["dup_row"] = int(float(dup)) if dup else None
            rr["port_or_area"] = ""
            rows.append(rr)

new_vessels = {}
for r in rows:
    r["row"] = int(r["row"])
    name = norm(r["vessel_name"])
    if not name or "/" in name:            # blank, or several sunk tankers in one cell (not a strike)
        r["vessel_id"] = ""
        continue
    v = alias.get(name)
    if not v:
        v = vid(name)
        alias[name] = v
        if v not in new_vessels:
            new_vessels[v] = {
                "vessel_id": v, "name_en": r["vessel_name"].strip(), "name_variants": r["vessel_name"].strip(),
                "imo": r["imo"], "vessel_type": r["vessel_type"], "flag": r["flag"], "dwt": r["dwt"],
                "military": "TRUE" if MILITARY.search(r["vessel_type"]) else "FALSE",
                "source_url": r["source_url"],
                "note": "from ship-identification research 2026-11-03 (row %d): %s" % (r["row"], r["notes"])}
    r["vessel_id"] = v

status_map = {"yes": "ship_strike", "no": "not_ship_strike", "unclear": "unclear"}
out = []
for r in rows:
    st = status_map.get(r["is_ship_strike"], "unclear")
    if st == "not_ship_strike" and re.search(r"\bmilitary\b", r.get("notes", ""), re.I):
        st = "warship"          # a real strike, but on a military vessel -> moves to the warship (kinetic) layer
    out.append(dict(strike_id=r["strike_id"], row=r["row"], status=st,
                    vessel_id=r["vessel_id"], vessel_name=r["vessel_name"].strip(),
                    actual_strike_date=r["actual_strike_date"][:10] if re.match(r"\d{4}-\d{2}-\d{2}", r["actual_strike_date"]) else "",
                    attacker=r["attacker"] if r["attacker"] in ("RU", "UA") else ("unknown" if r["is_ship_strike"] != "no" else ""),
                    location=LOCATION.get(r["row"], ""), duplicate_of="", source_url=r["source_url"],
                    note=r["notes"], reported=r["strike_id"].split("_")[2]))

# strikes already named in headlines (no research row) -> add with date fixes so they join the dedup
strikes = list(csv.DictReader(open("output/ship_strikes.csv", encoding="utf-8")))
have = {o["strike_id"] for o in out}
for s in strikes:
    if s["vessel_id"] in ("", "NA") or s["strike_id"] in have or s["id_status"] not in ("unreviewed", "NA", ""):
        continue
    d, src = NAMED_FIX.get(s["vessel_id"], (s["date_reported"] if s.get("date_reported") not in (None, "", "NA") else s["date"], ""))
    out.append(dict(strike_id=s["strike_id"], row=0, status="ship_strike", vessel_id=s["vessel_id"],
                    vessel_name=s["vessel_name"], actual_strike_date=d, attacker="", location="", duplicate_of="",
                    source_url=src, note="named in headline; date checked against vessel registry" if src else "named in headline",
                    reported=s["strike_id"].split("_")[2]))

# ---- duplicates: same vessel within 3 days = one event (primary = earliest reported, then strike_id)
def D(x): return dt.date.fromisoformat(x) if x else None
named = sorted([o for o in out if o["vessel_id"] and o["status"] != "not_ship_strike" and o["actual_strike_date"]],
               key=lambda o: (o["vessel_id"], o["actual_strike_date"], o["reported"], o["strike_id"]))
prim = {}
for o in named:
    key = o["vessel_id"]
    p = prim.get(key)
    if p and (D(o["actual_strike_date"]) - D(p["actual_strike_date"])).days <= 3:
        if o["strike_id"] != p["strike_id"]:
            o["status"], o["duplicate_of"] = "duplicate", p["strike_id"]
    else:
        prim[key] = o
by_row = {}
for o in out:
    by_row.setdefault(o["row"], o)
dup_rows = dict(UNNAMED_DUPS); dup_rows.update(CROSS_DUPS)
for r in rows:
    if r.get("dup_row"):
        dup_rows.setdefault(int(r["row"]), r["dup_row"])
def root(rw):
    seen = set()
    while rw in dup_rows and rw not in seen:
        seen.add(rw); rw = dup_rows[rw]
    return rw
for o in out:
    if o["row"] in dup_rows:
        p = root(o["row"])
        if p in by_row and by_row[p]["strike_id"] != o["strike_id"]:
            o["status"], o["duplicate_of"] = "duplicate", by_row[p]["strike_id"]

# a strike_id carrying several vessels: if its FIRST vessel is a duplicate, the whole strike is
first = {}
for o in out:
    first.setdefault(o["strike_id"], o)
for o in out:
    f = first[o["strike_id"]]
    if f["status"] == "duplicate" and o is not f:
        o["status"], o["duplicate_of"] = "duplicate", f["duplicate_of"]

cols = ["strike_id", "status", "vessel_id", "vessel_name", "actual_strike_date", "attacker", "location",
        "duplicate_of", "source_url", "note"]
with open("registry/ship_strike_ids.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore"); w.writeheader()
    w.writerows(sorted(out, key=lambda o: (o["row"] == 0, o["row"], o["strike_id"])))

if new_vessels:
    with open("registry/vessels.csv", "a", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(vessels[0].keys())); w.writerows(new_vessels.values())

from collections import Counter
print("id rows:", len(out), Counter(o["status"] for o in out))
print("new vessels:", len(new_vessels), "military:", sum(v["military"] == "TRUE" for v in new_vessels.values()))
