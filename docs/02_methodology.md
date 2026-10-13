# Methodology

## 1. Pipeline

```
EBA Transparency Exercise 2025 (CSV)
        │  sql/00_setup: schema, load, fix of one corrupted LEI
        ▼
PostgreSQL 16 ──► sql/01–08: 40 analytical queries ──► docs/06_sql_question_log.md
        │
        └──► sql/08_model_inputs/q33 ──► model/EBA_stress_test_model.xlsx
                                              ▲
             model/inputs/cet1_requirements.csv (published CET1 requirements)
```

Every number in the documentation traces to a query file or to a cell on the model's sheets.

## 2. Data

| Item | Detail |
|---|---|
| Source | European Banking Authority, EU-wide Transparency Exercise 2025 |
| Coverage | 119 banks from 25 home countries, plus an EBA "All other banks" aggregate (code OT); reference dates Sep 2024, Dec 2024, Mar 2025, Jun 2025 |
| Reference period for the analysis | 202506 (30 June 2025) |
| Units | EUR millions; ratio items (for example CET1 ratio, item 2520140) are decimals |
| Tables | `credit` (tr_cre.csv, 648,951 rows), `oth` (tr_oth.csv, 91,277 rows), `bank_metadata`, `nace_metadata`, `prefstatus_metadata` |

Three structural rules govern every query. The data dictionary has the detail ([07_data_dictionary.md](07_data_dictionary.md)).

1. **Templates and dimensions.** The credit table stacks several report templates (the `sheet` column). Each item reports only some breakdowns, and a breakdown is coded 0 where it does not apply.
2. **Duplicate totals.** Where an item reports a breakdown, code 0 can hold the total of the other codes. Item 2521301 repeats every bank-sector pair under Perf_Status 0, 2, 4 and 5, so sector queries filter `pref_status = 0`. NACE code 0 is likewise a total, not "unclassified" exposure (Q13a). The exposure items 2520502, 2520522 and 2520532 hold a country-total row (`country = 0`) and a breakdown of the same exposure by top counterparty countries, so exposure queries filter `country = 0`.
3. **Aggregate entity.** LEI `XXXXXXXXXXXXXXXXXXXX` is the EBA's "All other banks" aggregate. It is kept in system totals and country totals (as "Other") and excluded from bank-level counts, rankings and concentration.

## 3. Portfolio analysis

The queries move from data quality, to portfolio size and concentration, to geography, sector, bank level, asset quality, and finally credit ratios and trend. Key definitions:

| Measure | Definition | Items |
|---|---|---|
| Exposure (anchor) | Original exposure by exposure class, country-total rows; exposure value and risk exposure amount read separately, never summed | 2520502, 2520522, 2520532 |
| NPE ratio | Non-performing ÷ (performing + non-performing) gross carrying amount of loans and advances | 2520603, Perf_Status 1 and 2 |
| NPE coverage | Provisions on non-performing loans ÷ gross non-performing loans | 2520613 ÷ 2520603, Perf_Status 2 |
| Sector NPE rate | Non-performing ÷ total gross carrying amount by NACE sector | 2521301 |
| Impairment ratio | Accumulated impairment ÷ gross carrying amount by sector | 2521302 ÷ 2521301 |
| RWA density | Credit risk exposure amount ÷ exposure value | 2520532 ÷ 2520522 |
| Concentration | Herfindahl-Hirschman index (sum of squared percentage shares) and effective number of units (10,000 ÷ HHI) | 2520502 (country = 0) |

The NPE ratio uses the EBA definition of non-performing exposure, which includes "unlikely to pay" exposures regardless of days past due. It is therefore higher than banks' own NPL ratios (Santander 3.35% here against 2.92% reported).

## 4. Stress model

### 4.1 Question

If the NPE ratio rises by the amount in the ECB 2025 stress test, does each bank's CET1 ratio stay above its CET1 requirement (the trigger for restrictions on distributions, or "MDA trigger")?

### 4.2 Bank sample

The input sheet lists 12 banks. They span size (EUR 19bn to EUR 2.6tn total assets), NPE ratio (0% to 6.9%) and CET1 ratio (12.5% to 31%, with Kommuninvest an outlier at 353%), and include two deliberate contrast cases:

- **Kommuninvest**, a lender to Swedish municipalities and regions. It has no non-performing exposure and its lending is to the public sector. An NPE shock derived from commercial loan defaults does not apply to it, so it is kept for reference and excluded from the stress run (assumption A16).
- **Revolut Holdings Europe**, a fintech. It is stressed but reported on its own line as a reference case and excluded from medians (A17).

The other ten banks are the core sample.

### 4.3 Scenarios

| Scenario | NPE shock | Horizon | Source |
|---|---|---|---|
| S1 1-year baseline | +0.8 pp | 1 year | ECB report, Chart 3.7 (read from chart) |
| S2 1-year adverse | +1.2 pp | 1 year | ECB report, Chart 3.7 (read from chart) |
| S3 3-year baseline | +2.4 pp | 3 years | ECB report, Chart 3.7 (read from chart) |
| S4 3-year adverse | +4.1 pp | 3 years | ECB report, p. 26: NPE ratio from 1.7% to 5.8% by end-2027 |

The ECB states the adverse end point in its text. The baseline path and the intermediate years appear only in Chart 3.7 (page 27). They were read by measuring the plotted lines against the chart's axis, calibrated to the two published values (1.7% at end-2024 and 5.8% at end-2027). The readings are accurate to about ±0.1 pp, and the sensitivity analysis tests ±0.3 pp.

### 4.4 Calculation

For bank *i*, shock *s* and horizon *T* years:

| Step | Formula |
|---|---|
| Incremental NPE | ΔNPE = s × gross loans (performing + non-performing) |
| Incremental provisions | P = ΔNPE × current NPE coverage |
| **Headline: stressed CET1** | CET1′ = CET1 − P |
| **Headline: headroom** | CET1′ ÷ RWA − CET1 requirement |
| Second layer: pre-tax result | E = annual profit before tax × T − P |
| Tax | 30% × max(E, 0); no tax credit on losses |
| Distributions | 30% × net result if positive, otherwise 0 |
| Second layer: stressed CET1 | CET1 + net result − distributions |

RWA is held constant and the balance sheet is static.

### 4.5 Why the headline is instant loss absorption

The model stresses credit losses only. It does not stress revenues, market risk or operational risk. Crediting three years of profit at the June 2025 run rate adds 4 to 14 pp of CET1 per bank, more than the 1.5 to 4.2 pp the adverse shock removes. That would show capital rising under stress, against the ECB's finding of a 4.0 pp fall. The headline therefore answers a narrower and more robust question: can today's capital absorb the shock? The earnings layer is reported beside it and labelled optimistic.

### 4.6 CET1 requirement

Each bank's own published CET1 requirement, excluding Pillar 2 Guidance, is used. It is taken from the bank's SREP announcement or its Pillar 3 EU KM1 template. It equals 4.5% Pillar 1, plus the CET1 part of the Pillar 2 requirement, plus the combined buffer requirement. CEC Bank publishes none, so it uses a labelled fallback built from the same components ([cet1_requirements.csv](../model/inputs/cet1_requirements.csv)).

### 4.7 Sensitivity

The 3-year adverse headroom is recomputed with the shock ±0.3 pp, coverage ±10 pp, and (earnings layer) payout at 0% and 50%.

## 5. Validation

See [05_validation_log.md](05_validation_log.md).
