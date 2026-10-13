# Validation log

Checks performed on the data, the queries and the stress model. Each entry records what was checked, how, and the result.

## Data

| # | Check | Method | Result |
|---|---|---|---|
| D1 | Row counts after load | `count(*)` per table | credit 648,951; oth 91,277; bank_metadata 120; nace_metadata 20; prefstatus_metadata 12 |
| D2 | Units are EUR millions | Total assets (item 2521010) compared with published balance sheets of Santander and BBVA | Consistent |
| D3 | Bank codes match | Q2: LEI codes in `credit` with no match in `bank_metadata` | One corrupted code (`9.598E+19`, scientific-notation conversion); fixed in `sql/00_setup/03_fix_known_issues.sql` |
| D4 | NACE code 0 | Q13a: compare code 0 with the sum of codes 1–19 | Code 0 is a duplicate total, not unclassified exposure; excluded from sector queries |
| D5 | Perf_Status duplicates in item 2521301 | Count rows per bank-sector pair by Perf_Status | Each pair appears under 0, 2, 4 and 5; sector queries filter `pref_status = 0` |
| D6 | Exposure value against bank disclosures | Crédit Agricole summed to EUR 3.80tn (item 2520522, all rows) against about EUR 2.17–2.19tn leverage exposure | Gap traced to a double count: the item holds a country-total row and a counterparty-country breakdown of the same exposure. With `country = 0` only it is EUR 1.98tn, consistent with the bank's figure. Fifteen queries corrected (see D8) |
| D7 | NPE ratio against bank NPL ratios | Santander 3.35% against 2.92% reported; BNP Paribas 2.79% against 1.6% | Definitional: EBA NPE includes "unlikely to pay" |
| D8 | Country breakdown in exposure items | Rows by `country` for items 2520502/522/532 | `country = 0` is the total; codes 1+ break it down by top counterparty countries (full-template banks only). Total original exposure is EUR 31.3tn, not the EUR 58tn an all-row sum gives. Shares by country and bank change little because the duplication is broadly proportional |
| D9 | Entities that are not banks | Unmatched codes in Q2; names in `bank_metadata` | `XXXXXXXXXXXXXXXXXXXX` is the EBA "All other banks" aggregate (EUR 527bn, 17th largest if ranked as a bank). Excluded from bank-level counts and rankings; kept in system and country totals |

## Queries

| # | Check | Result |
|---|---|---|
| Q-1 | All 40 analytical queries and the setup scripts run end to end on PostgreSQL 16 loaded from the EBA files | Pass |
| Q-2 | Sector results recomputed after the Perf_Status correction | Real Estate 25.5% of classified exposure; Construction NPE rate 6.4% |
| Q-3 | Concentration found two independent ways | Top-20 share (Q8, 66.4%) and running total (Q18, 11–13 banks for half of exposure) agree |
| Q-4 | Trend query checked for composition effects | Banks reporting vary by period (115, 119, 110, 119); the top-20 share is not read as a trend |

## Stress model inputs

| # | Check | Result |
|---|---|---|
| M-1 | Q33 output equals the `Bank Inputs` sheet | Equal for all 12 banks |
| M-2 | CET1 capital ÷ RWA equals the reported CET1 ratio (item 2520140) | Equal for all 12 banks (check column R) |
| M-3 | Reported CET1 ratio equals the bank's Pillar 3 KM1 at 30 June 2025 | Deutsche Bank 14.24%, Morgan Stanley Europe 18.00%, Revolut 31.32%, HSBC Continental Europe 15.5%: all match, confirming the same consolidation scope |
| M-4 | Each CET1 requirement equals the sum of its published components | Matches within rounding (0.01–0.1 pp); source, date and components recorded in `cet1_requirements.csv` |
| M-5 | Chart 3.7 readings | Reading of the adverse line at end-2027 (5.74%) against the published 5.8% gives a calibration error of about 0.06 pp |

## Stress model outputs

| # | Check | Result |
|---|---|---|
| O-1 | Workbook recalculated in LibreOffice | 1,390 formulas, 0 errors |
| O-2 | Every headroom figure (11 banks × 4 scenarios × 2 views) recomputed in Python from the raw inputs | Maximum absolute difference 5 × 10⁻¹⁶ |
| O-3 | Sensitivity base cases equal the Summary results | In-workbook check cells return 0 |
| O-4 | Order of magnitude against the ECB | 3-year adverse credit loss 1.5–4.2 pp of RWA at the core banks, against 5.0 pp loan-loss contribution in the ECB aggregate; lower, as expected given L9 (current coverage on new defaults) and the ECB's wider loss perimeter, which also covers impairments on performing exposures |
| O-5 | Direction of results | The three banks that breach (BNP Paribas, BAWAG, ING) are the three with the lowest starting headroom (2.2–2.4 pp) |
