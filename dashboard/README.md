# Power BI dashboard

A three-page report that tells the project's story visually: where the exposure is, where the risk is, and whether capital can absorb the ECB adverse NPE shock. Every visual names the query or model sheet behind it, and the expected values below let anyone confirm the dashboard matches the SQL log and the stress model.

File: `EBA_credit_risk_dashboard.pbix` · Screenshots: [`screenshots/`](screenshots/)

## Quick build (Windows)

The report is stored as a Power BI Project in [`powerbi_project/`](powerbi_project/): the data model (TMDL) and the three pages (PBIR) as text files. One script points it at `data/processed/` and opens it in Power BI Desktop:

```powershell
powershell -ExecutionPolicy Bypass -File ".\dashboard\build_dashboard.ps1"
```

For the published `.pbix`, build in GitHub mode once the repository is public, so the file reads its data from the repository instead of a local folder and holds no local path or user name:

```powershell
powershell -ExecutionPolicy Bypass -File ".\dashboard\build_dashboard.ps1" -Source GitHub
```

If Power BI asks how to connect to `raw.githubusercontent.com`, choose **Anonymous**.

Run it from the repository root. When Power BI Desktop has loaded the data, check the visuals against the expected values below, then use File → Save as → Power BI file (.pbix) and save as `dashboard\EBA_credit_risk_dashboard.pbix`. Bar colours on page 3 (red below requirement) are set by hand: Format → Bars → Colors → fx → Field value → `Headroom Colour`.

The build guide below describes the same report step by step, for building it by hand or checking the generated one.

## Data

The report loads the compact CSV files in [`data/processed/`](../data/processed/), not the raw 123 MB extract. They are produced by [`sql/09_exports/export_processed.sql`](../sql/09_exports/export_processed.sql), which applies the same filters as the SQL queries (June 2025; Perf_Status 0 for sector totals; NACE codes 1–19). The dashboard therefore cannot drift from the SQL results.

| Table | Rows | Content | Matches |
|---|---|---|---|
| `banks` | 120 | LEI, name, country (includes the "All other banks" aggregate, code in lower case) | Q1 |
| `countries` | 26 | Country code and name | |
| `bank_exposure` | 120 | Original exposure, exposure value, risk exposure amount per bank (country-total rows); `is_named_bank` = FALSE marks the EBA "All other banks" aggregate | Q4–Q12, Q17–Q19, Q29, Q30 |
| `sector` | 19 | Gross carrying amount, non-performing, accumulated impairment per NACE sector | Q16, Q22b, Q27 |
| `country_asset_quality` | 26 | Performing, non-performing loans and NPE provisions by bank home country | Q20b, Q23, Q28 |
| `npe_trend` | 4 | Performing and non-performing loans by period | Q31 |
| `stress_results` | 88 | 11 banks × 4 scenarios × 2 views, exported from the stress model | Model, Summary sheet |

`banks_reporting` in `npe_trend` counts entities reporting item 2520603 (105–108, including the "All other banks" aggregate). Fewer banks report this NPE template than the exposure items (110–119 named banks in Q31).

### Load and relate

1. Get data → Text/CSV → load each file above. Check that amounts load as Decimal number and `period` and `nace_code` as Whole number.
2. Model view, relationships (single direction, many-to-one):
   - `bank_exposure[lei_code]` → `banks[lei_code]`
   - `bank_exposure[country_code]` → `countries[country_code]`
   - `country_asset_quality[country_code]` → `countries[country_code]`
   - `sector`, `npe_trend` and `stress_results` stand alone.
3. Create the measures in [`measures.md`](measures.md).

## Page 1: Where the exposure is

| Visual | Fields | Expected values |
|---|---|---|
| Clustered bar: exposure by country | Axis `countries[country]`; value `[Country Share of Exposure]`; sort descending | France 28.9%, Germany 15.4%, Spain 13.7%, Italy 10.5%, Netherlands 9.2% |
| Clustered bar: exposure by sector | Axis `sector[sector]`; value `[Sector Share of Exposure]`; sort descending | Real estate 25.5%, Manufacturing 15.1%, Wholesale and retail 12.9% |
| Card | `[Original Exposure EUR tn]` | 31.3 (EUR tn, all reporting entities) |
| Card | `[Banks Holding Half of Exposure]` | 11 |
| Card | `[Top 20 Bank Share]` | 66.4% |
| Multi-row card | `[HHI by Bank]`, `[HHI by Country]`, `[HHI by Sector]` | 302 · 1,501 · 1,234 |

Subtitle for the page: *Original exposure (item 2520502, country-total rows) by bank home country; gross carrying amount (item 2521301, Perf_Status 0) by NACE sector. June 2025, EUR. Sources: Q8, Q12, Q16, Q18, Q30.*

## Page 2: Where the risk is

| Visual | Fields | Expected values |
|---|---|---|
| Clustered bar: NPE rate by sector | Axis `sector[sector]`; value `[Sector NPE Rate]`; sort descending | Construction 6.4%, Accommodation and food 5.6%, Wholesale and retail 4.2%, Agriculture 4.1% |
| Scatter: size against risk by sector | X `[Sector Share of Exposure]`; Y `[Sector NPE Rate]`; values `sector[sector]` | Real estate far right and low (25.5%, 2.8%); construction high and small (6.4%) |
| Clustered bar: NPE coverage by country | Axis `countries[country]`; value `[NPE Coverage]`; filter to countries with a large NPE stock or sort by it | Italy 52.1%, Spain 45.5%, France 44.4%, Germany 35.0%, Netherlands 24.2% |
| Line: NPE ratio trend | Axis `npe_trend[period]` (as text); value `[NPE Ratio Trend]` | 2.24% → 2.21% → 2.17% → 2.14% |
| Card | `[Country NPE Ratio]` with no filter | 2.14% |

Subtitle: *Non-performing exposure per EBA definition (includes unlikely to pay). Sources: Q22b, Q27, Q28, Q31.*

## Page 3: Can capital absorb the shock?

| Visual | Fields | Expected values (S4 3-year adverse, Instant loss) |
|---|---|---|
| Slicer (single select, buttons) | `stress_results[scenario]` | Default: 3-year adverse |
| Slicer (single select, buttons) | `stress_results[view]` | Default: Instant loss |
| Clustered bar: headroom by bank | Axis `stress_results[bank]`; values `[Headroom Today]` and `[Headroom After Shock]`; filter `role` = Core; sort by `[Headroom After Shock]` ascending; bar colour for `[Headroom After Shock]` by `[Headroom Colour]` | BAWAG −1.42%, ING −1.04%, BNP Paribas −0.26%, Deutsche Bank 0.25%, Santander 0.53%, Commerzbank 0.56% |
| Card | `[Core Banks Below Requirement]` | 3 |
| Card | `[Median Headroom Core]` | 0.54% |
| Card | `[Median Headroom Today Core]` | 3.78% |
| Table: reference case | `stress_results[bank]`, `[Headroom Today]`, `[Headroom After Shock]`, filter `role` = Reference case | Revolut 21.35% → 15.68% |
| Text box | Method note | "Headroom = stressed CET1 ratio − bank's own CET1 requirement, pp of RWA. Instant loss: shock provisions charged against June 2025 CET1. With earnings: run-rate profit after 30% tax and 30% payout, revenues not stressed (optimistic). Source: model/EBA_stress_test_model.xlsx." |

Checks with the other selections: with *With earnings* and 3-year adverse, Core Banks Below Requirement = 0 and median headroom = 6.72%. With *Instant loss* and 3-year baseline, Core Banks Below Requirement = 0 and median headroom = 1.89%.

## Refreshing

1. Re-run `sql/09_exports/export_processed.sql`.
2. After changing the model, recalculate it in Excel and re-export `stress_results.csv` (sheet Stress, one row per bank, scenario and view).
3. In Power BI, Home → Refresh, then confirm the expected values above.

## Screenshots to add

`screenshots/01_exposure.png`, `screenshots/02_risk.png`, `screenshots/03_stress.png`, at 1920 × 1080, with the default slicer selections.
