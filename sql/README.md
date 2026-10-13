# SQL

PostgreSQL queries for the analysis, one file per question, grouped by theme. The full write-up with results and findings is in [`docs/06_sql_question_log.md`](../docs/06_sql_question_log.md).

| Folder | Questions | Theme |
|---|---|---|
| `00_setup/` | | Tables, data load, known-issue fix |
| `01_data_quality/` | Q1–Q3 | Bank universe, unmatched LEI codes, item catalogue |
| `02_portfolio_overview/` | Q4–Q8 | Totals, averages, top-20 concentration |
| `03_geography/` | Q9–Q12 | Exposure by home country |
| `04_sector_nace/` | Q13–Q16b | Exposure by NACE sector |
| `05_bank_level/` | Q17–Q19 | Bank size, 50% concentration, size buckets |
| `06_asset_quality/` | Q20–Q23 | Performing / non-performing split, NPE rates |
| `07_credit_ratios/` | Q27–Q32 | Impairment and NPE coverage, RWA density, HHI, trend, size versus risk |
| `08_model_inputs/` | Q24–Q26c, Q33 | Inputs for the stress-test model (Q33 feeds the workbook directly) |
| `09_exports/` | | Writes the compact tables in `data/processed/` used by the dashboard and web page |

## Conventions

- Reference period `202506`; amounts in EUR millions.
- `credit.pref_status` is the EBA `Perf_Status` column; queries use the lower-case names created by `00_setup/01_create_tables.sql`.
- Q1, Q2 and Q7 read the bank table through the view `metadata` (an alias of `bank_metadata`).
- Item 2521301 repeats each bank-sector pair under `Perf_Status` 0, 2, 4 and 5. Sector queries filter on `pref_status = 0`; see the correction notes in Q13, Q13b, Q14, Q16 and Q22b.
- Items 2520502, 2520522 and 2520532 hold a country-total row (`country = 0`) and a breakdown of the same exposure by top counterparty countries. Exposure queries filter `country = 0`.
- LEI `XXXXXXXXXXXXXXXXXXXX` is the EBA "All other banks" aggregate. Bank-level counts and rankings exclude it.
- There is no Q15 (a retired draft).
- Q4 to Q8 show the anchor item 2520502; repeat with 2520522 and 2520532 for the other two measures. The three measures are not additive.

All queries were run end to end against PostgreSQL 16 loaded from the EBA files.
