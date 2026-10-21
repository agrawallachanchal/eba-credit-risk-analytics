# Details for analysts

Everything needed to inspect or rebuild the analysis. The plain-English summary is in the [main README](../README.md).

| File | Content |
|---|---|
| [`METHODOLOGY.md`](METHODOLOGY.md) | Design decisions, method, assumptions register, limitations, validation log, data dictionary, model guide, references |
| [`eba_analysis.sql`](eba_analysis.sql) | All the SQL in one file. Part 1 builds the PostgreSQL database; Part 2 holds the 40 analytical queries, each with its question, notes and result; Part 3 writes the compact tables in `data/` used by the web page |
| [`build_web_data.py`](build_web_data.py) | Rebuilds the web page's data from the raw EBA files |
| [`data/`](data/) | Compact tables, CET1 requirements, EBA lookup files and the web page's database |

The stress-test workbook is [`../EBA_stress_test_model.xlsx`](../EBA_stress_test_model.xlsx).

## Reproduce

Run all commands from this `details/` folder.

1. **Download** `tr_cre.csv` (~123 MB) and `tr_oth.csv` (~15 MB) from the EBA [transparency exercise page](https://www.eba.europa.eu/risk-and-data-analysis/risk-analysis/eu-wide-transparency-exercise), under *Database > Full database*, and place them in `data/`. They are git-ignored. The EBA indicates this exercise is being succeeded by its Pillar 3 Data Hub, so check the page for current availability.
2. **Build the database** (PostgreSQL 14 or later). This runs all three parts of `eba_analysis.sql`: it builds the tables, runs the 40 queries and refreshes the exported tables.
   ```bash
   createdb eba
   psql -d eba -f eba_analysis.sql
   ```
   Expected row counts after Part 1: `credit` 648,951 · `oth` 91,277 · `bank_metadata` 120 · `nace_metadata` 20 · `prefstatus_metadata` 12.
3. **Work with a single query** by copying it from Part 2 of `eba_analysis.sql`. Query Q33 produces the model's `Bank Inputs` sheet.
4. **Rebuild the web page's data** with `pip install "duckdb>=1.4,<2"` and `python build_web_data.py`. To view the site locally, run `python -m http.server 8000` from the repository root (one level up) and open http://localhost:8000.
