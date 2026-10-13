"""Builds the data files behind the project web page (web/data/).

Run from the repository root after placing the raw EBA files in data/raw/ (see data/README.md):

    pip install "duckdb>=1.4,<2"
    python web/build_web_data.py

Outputs (all in web/data/):
    eba.duckdb                         DuckDB database with the tables credit and oth (the rows of tr_cre.csv and
                                       tr_oth.csv for the items the 40 queries use), bank_metadata, nace_metadata
                                       and prefstatus_metadata
    queries.json                       question, notes and SQL of every query file in sql/01..08
    stress_inputs.json                 inputs of the stress model (Q33 run on the extract + model/inputs/cet1_requirements.csv)
    overview.json                      figures for the overview page, read from data/processed/

The SQL files are not changed for the web page: the browser runs them as written, on DuckDB-WASM,
against the extract below, with the same table names as the PostgreSQL database. The database is written
in DuckDB storage format v1.4.0, which DuckDB-WASM 1.32.0 (DuckDB 1.4.3) opens without loading extensions.
"""

import csv
import json
import re
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
META = ROOT / "data" / "metadata"
PROCESSED = ROOT / "data" / "processed"
OUT = ROOT / "web" / "data"
OUT.mkdir(parents=True, exist_ok=True)

# Items used by the 40 queries (credit = tr_cre.csv, oth = tr_oth.csv)
CREDIT_ITEMS = [2520502, 2520522, 2520532, 2521301, 2521302, 2521303, 2520603, 2520613]
OTH_ITEMS = [2521010, 2520138, 2520102, 2520140, 2520316, 2520317, 2520318, 2520332, 2520333]

# Stress model assumptions (model/EBA_stress_test_model.xlsx, sheet Assumptions)
SCENARIOS = [
    {"code": "S1", "name": "1-year baseline", "shock": 0.008, "horizon": 1},
    {"code": "S2", "name": "1-year adverse", "shock": 0.012, "horizon": 1},
    {"code": "S3", "name": "3-year baseline", "shock": 0.024, "horizon": 3},
    {"code": "S4", "name": "3-year adverse", "shock": 0.041, "horizon": 3},
]
ASSUMPTIONS = {"annualisation": 2, "tax_rate": 0.30, "payout_profit": 0.30, "payout_loss": 0.0}
ROLES = {"485100FX5Y9YLAQLNP12": "Reference case", "EV2XZWMLLXF2QRX0CD47": "Excluded"}
AGGREGATE_LEI = "XXXXXXXXXXXXXXXXXXXX"


DB_FILE = OUT / "eba.duckdb"


def build_database(con):
    for f in ["tr_cre.csv", "tr_oth.csv"]:
        if not (RAW / f).exists():
            raise SystemExit(f"Missing {RAW / f}. Download it as described in data/README.md.")
    if DB_FILE.exists():
        DB_FILE.unlink()
    con.execute(f"ATTACH '{DB_FILE.as_posix()}' AS eba (STORAGE_VERSION 'v1.4.0')")
    con.execute("USE eba")

    def num(col, typ="BIGINT"):
        return f"CAST(NULLIF(\"{col}\", '') AS {typ})"

    con.execute(f"""
        CREATE TABLE credit AS
        SELECT "LEI_Code" AS lei_code, "NSA" AS nsa, {num('Period')} AS period, {num('Item')} AS item,
               "Label" AS label, {num('Portfolio')} AS portfolio, {num('Country')} AS country,
               {num('Country_rank')} AS country_rank, {num('Exposure')} AS exposure, {num('Status')} AS status,
               {num('Perf_Status')} AS pref_status, {num('NACE_codes')} AS nace_codes,
               {num('Amount', 'DOUBLE')} AS amount, "Sheet" AS sheet
        FROM read_csv('{(RAW / 'tr_cre.csv').as_posix()}', all_varchar = true, header = true)
        WHERE CAST(NULLIF("Item", '') AS BIGINT) IN ({', '.join(map(str, CREDIT_ITEMS))})
        ORDER BY lei_code, period, item
    """)
    con.execute(f"""
        CREATE TABLE oth AS
        SELECT "LEI_Code" AS lei_code, "NSA" AS nsa, {num('Period')} AS period, {num('Item')} AS item,
               "Label" AS label, {num('Exposure')} AS exposure, {num('Amount', 'DOUBLE')} AS amount,
               {num('n_quarters')} AS n_quarters, "Sheet" AS sheet
        FROM read_csv('{(RAW / 'tr_oth.csv').as_posix()}', all_varchar = true, header = true)
        WHERE CAST(NULLIF("Item", '') AS BIGINT) IN ({', '.join(map(str, OTH_ITEMS))})
        ORDER BY lei_code, period, item
    """)

    # Bank metadata: all text, lower-case column names as in sql/00_setup/01_create_tables.sql,
    # with the known LEI fix from sql/00_setup/03_fix_known_issues.sql
    cols = ["country", "desc_country", "lei_code", "name", "finrep", "fin_year_end", "footnotes",
            "te_24", "lei_code_te24", "te_23", "lei_code_te23", "te_22", "lei_code_te22",
            "te_21", "lei_code_te21", "te_20a", "lei_code_te20a", "te_20s", "lei_code_te20s",
            "te_19", "lei_code_te19", "te_18", "lei_code_te18", "tr_17", "lei_code_17",
            "tr_16", "lei_code_tr16", "tr_15", "lei_code_tr15"]
    con.execute(f"""
        CREATE TABLE bank_metadata AS
        SELECT * FROM read_csv('{(META / 'TR_Metadata_Bankdetail.csv').as_posix()}',
                               all_varchar = true, header = true, names = {cols})
    """)
    con.execute("UPDATE bank_metadata SET lei_code = '95980020140005881190' WHERE lei_code = '9.598E+19'")

    for src, name, key in [("TR_Metadata_nace.csv", "nace_metadata", "nace_codes"),
                           ("TR_Metadata_perfstatus.csv", "prefstatus_metadata", "pref_status")]:
        con.execute(f"""
            CREATE TABLE {name} AS
            SELECT CAST(c0 AS INTEGER) AS {key}, c1 AS label
            FROM read_csv('{(META / src).as_posix()}', all_varchar = true, header = true, names = ['c0', 'c1'])
            WHERE NULLIF(c0, '') IS NOT NULL
        """)
    # Q1, Q2 and Q7 refer to the bank table as "metadata"
    con.execute("CREATE VIEW metadata AS SELECT * FROM bank_metadata")
    con.execute("CHECKPOINT")


def parse_query(path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    m = re.match(r"--\s*(Q\d+[a-z]?)\s*\|\s*(.*)", lines[0])
    qid, question = m.group(1), m.group(2).strip()
    header, i = [], 1
    while i < len(lines) and lines[i].startswith("--"):
        header.append(lines[i][2:].strip())
        i += 1
    meta = header[0] if header and header[0].startswith("Period") else ""
    notes = []  # one paragraph per "Note:", "Correction:" ... line, continuation lines appended
    for h in header:
        if not h or h == meta:
            continue
        if not notes or re.match(r"^[A-Z][A-Za-z0-9 ()/-]{0,40}:", h):
            notes.append(h)
        else:
            notes[-1] += " " + h
    sql = "\n".join(lines[i:]).strip()
    return {"id": qid, "question": question, "meta": meta, "notes": notes, "sql": sql,
            "file": path.relative_to(ROOT).as_posix()}


def build_queries():
    sections = {
        "01_data_quality": "Data quality", "02_portfolio_overview": "Portfolio overview",
        "03_geography": "Geography", "04_sector_nace": "Sector (NACE)", "05_bank_level": "Bank level",
        "06_asset_quality": "Asset quality", "07_credit_ratios": "Credit ratios", "08_model_inputs": "Model inputs",
    }
    out = []
    for folder, title in sections.items():
        files = sorted((ROOT / "sql" / folder).glob("q*.sql"),
                       key=lambda p: (int(re.match(r"q(\d+)", p.name).group(1)), p.name))
        out.append({"section": title, "queries": [parse_query(p) for p in files]})
    (OUT / "queries.json").write_text(json.dumps(out, indent=1, ensure_ascii=False), encoding="utf-8")
    return out


def build_stress_inputs(con, queries):
    q33 = next(q for s in queries for q in s["queries"] if q["id"] == "Q33")
    rows = con.execute(q33["sql"].rstrip(";")).fetchall()
    cols = [d[0] for d in con.description]
    with open(ROOT / "model" / "inputs" / "cet1_requirements.csv", encoding="utf-8") as f:
        req = {r["lei_code"]: r for r in csv.DictReader(f)}
    banks = []
    for r in rows:
        d = dict(zip(cols, r))
        lei = d["lei_code"]
        role = ROLES.get(lei, "Core")
        if role == "Excluded":
            continue
        rq = req[lei]
        banks.append({
            "lei_code": lei, "bank": rq["bank"].replace("Credit Agricole", "Crédit Agricole"), "role": role,
            "rwa": d["rwa"], "cet1_capital": d["cet1_capital"],
            "gross_loans": d["performing"] + d["non_performing"],
            "npe_ratio": d["non_performing"] / (d["performing"] + d["non_performing"]),
            "npe_coverage": d["npe_provisions"] / d["non_performing"],
            "pbt_h1": d["pbt_h1"],
            "cet1_requirement": round(float(rq["cet1_requirement_pct"]) / 100, 6),
            "requirement_basis": rq["basis"], "requirement_source": rq["source_url"],
        })
    banks.sort(key=lambda b: b["bank"])
    data = {"period": "June 2025", "units": "EUR mn", "scenarios": SCENARIOS, "assumptions": ASSUMPTIONS,
            "banks": banks}
    (OUT / "stress_inputs.json").write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")


def read_csv_rows(name):
    with open(PROCESSED / name, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def build_overview():
    countries = {r["country_code"]: r["country"] for r in read_csv_rows("countries.csv")}
    exp = [r for r in read_csv_rows("bank_exposure.csv")]
    total = sum(float(r["original_exposure"]) for r in exp)
    by_country = {}
    for r in exp:
        by_country[r["country_code"]] = by_country.get(r["country_code"], 0) + float(r["original_exposure"])
    country_share = sorted(({"name": countries.get(k, k), "value": v / total} for k, v in by_country.items()),
                           key=lambda x: -x["value"])
    sector = read_csv_rows("sector.csv")
    s_total = sum(float(r["gross_carrying_amount"]) for r in sector)
    sectors = sorted(({"name": r["sector"],
                       "share": float(r["gross_carrying_amount"]) / s_total,
                       "npe_rate": float(r["non_performing"]) / float(r["gross_carrying_amount"]),
                       "gross_carrying_amount": float(r["gross_carrying_amount"])} for r in sector),
                     key=lambda x: -x["share"])
    trend = [{"period": r["period"],
              "npe_ratio": float(r["non_performing"]) / (float(r["performing"]) + float(r["non_performing"]))}
             for r in sorted(read_csv_rows("npe_trend.csv"), key=lambda r: r["period"])]
    named = sorted((float(r["original_exposure"]) for r in exp if r["is_named_bank"] == "TRUE"), reverse=True)
    named_total = sum(named)
    running, half = 0, 0
    for v in named:
        if running < named_total / 2:
            half += 1
        running += v
    data = {
        "total_exposure_eur_tn": total / 1e6,
        "banks": len(named),
        "top20_share": sum(named[:20]) / named_total,
        "banks_for_half": half,
        "npe_ratio_latest": trend[-1]["npe_ratio"],
        "country_share": country_share,
        "sectors": sectors,
        "npe_trend": trend,
    }
    (OUT / "overview.json").write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")


def main():
    con = duckdb.connect()
    build_database(con)
    queries = build_queries()
    build_stress_inputs(con, queries)
    build_overview()
    con.execute("USE memory")
    con.execute("DETACH eba")
    for p in sorted(OUT.iterdir()):
        print(f"{p.name:28} {p.stat().st_size:>10,} bytes")


if __name__ == "__main__":
    main()
