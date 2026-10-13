# Data

The analysis uses the **EBA EU-wide Transparency Exercise 2025** (reference dates Sep 2024 to Jun 2025). The raw files are large, so they are not stored in this repository.

## Download

All files are published by the European Banking Authority on the transparency exercise page:
<https://www.eba.europa.eu/risk-and-data-analysis/risk-analysis/eu-wide-transparency-exercise>

Under **Database > Full database** (base path `https://www.eba.europa.eu/assets/TE2025/Full_database/883401/`):

| File | Content | Used for | Size |
|---|---|---|---|
| `tr_cre.csv` | Credit risk (STA, IRB, NPE, NACE, forborne, collateral) | Main analysis (table `credit`) | ~123 MB |
| `tr_oth.csv` | Capital, P&L, balance sheet | Stress-test inputs (table `oth`) | ~15 MB |
| `TR_Metadata.xlsx` | Code lists | Source of the three lookup files below | ~3 MB |
| `SDD.xlsx` | Data dictionary | Reference | |
| `tr_sov.csv`, `tr_mrk.csv` | Sovereign and market risk | Not used | |

Place `tr_cre.csv` and `tr_oth.csv` in `data/raw/` (git-ignored).

The EBA site indicates this exercise is being succeeded by the EBA Pillar 3 Data Hub; check the page above for current availability.

## Included in this repository

| Path | Content |
|---|---|
| `data/metadata/TR_Metadata_Bankdetail.csv` | Bank names, countries and LEI codes (120 banks) |
| `data/metadata/TR_Metadata_nace.csv` | NACE sector codes 0 to 19 |
| `data/metadata/TR_Metadata_perfstatus.csv` | Performing / non-performing status codes |
| `data/processed/` | Compact derived files used by the model and the web page |

Known issue in the bank file: one LEI code (Banco de Crédito Social Cooperativo) is stored as `9.598E+19` after a spreadsheet conversion. `sql/00_setup/03_fix_known_issues.sql` restores the correct value.

## Load into PostgreSQL

From the repository root:

```bash
createdb eba
psql -d eba -f sql/00_setup/01_create_tables.sql
psql -d eba -f sql/00_setup/02_load_data.sql
psql -d eba -f sql/00_setup/03_fix_known_issues.sql
```

Expected row counts: `credit` 648,951 · `oth` 91,277 · `bank_metadata` 120 · `nace_metadata` 20 · `prefstatus_metadata` 12.

## Source and terms

Data: European Banking Authority, EU-wide Transparency Exercise 2025. The EBA's [legal notice](https://eba.europa.eu/legal-notice) authorises reproduction of EBA material provided the source is acknowledged. All figures are in EUR millions unless stated.
