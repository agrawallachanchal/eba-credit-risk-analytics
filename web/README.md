# Web page

A static page with three sections, published with GitHub Pages: https://agrawallachanchal.github.io/eba-credit-risk-analytics/

| Section | What it shows | Source |
|---|---|---|
| Overview | Exposure by country and sector, NPE ratio trend, stress-test headline | `data/processed/` (same files as the Power BI report) |
| Ask the data | The 40 queries from `sql/`, with their notes, run live in the browser; the SQL can be edited | DuckDB-WASM on `data/eba.duckdb` |
| Stress test | The stress model with adjustable shock, coverage and earnings horizon | `data/stress_inputs.json`, `js/stress-model.js` |

There is no server and no build step for the page itself: HTML, CSS and JavaScript modules only. The single third-party script, DuckDB-WASM 1.32.0, is loaded from jsDelivr when *Ask the data* is opened.

## Data files

`web/data/` is produced by one script from the raw EBA files:

```bash
pip install "duckdb>=1.4,<2"
python web/build_web_data.py
```

| File | Content |
|---|---|
| `eba.duckdb` | Tables `credit`, `oth`, `bank_metadata` (also `metadata`), `nace_metadata`, `prefstatus_metadata`: the rows for the 17 items the queries use, all four periods (about 5 MB) |
| `queries.json` | Question, notes and SQL of every file in `sql/01_*` to `sql/08_*`, taken from the files unchanged |
| `stress_inputs.json` | Q33 run on the extract, joined to `model/inputs/cet1_requirements.csv` |
| `overview.json` | Figures for the overview, from `data/processed/` |

## Checks

- Every query returns the same result as on the full PostgreSQL database, except Q3, which lists only the items in the extract (validation log, Q-5).
- At each scenario's default settings, the stress test equals `data/processed/stress_results.csv` (exported from the Excel model) for all 88 bank, scenario and view combinations (validation log, O-6).

## Run locally

The page reads its data with `fetch`, so it needs a local web server rather than opening the file directly:

```bash
cd web
python -m http.server 8000
```

Then open http://localhost:8000.
