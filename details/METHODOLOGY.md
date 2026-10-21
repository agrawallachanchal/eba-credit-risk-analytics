# Methodology

How the analysis was built, why each choice was made, and how it was checked. The summary is in the [main README](../README.md) and the [method note](https://agrawallachanchal.github.io/eba-credit-risk-analytics/blog/how-this-analysis-works.html); the queries and their results are in [eba_analysis.sql](eba_analysis.sql).

## Contents

1. [Design decisions](#1-design-decisions)
2. [Method](#2-method)
3. [Assumptions register](#3-assumptions-register)
4. [Limitations and model risk](#4-limitations-and-model-risk)
5. [Validation log](#5-validation-log)
6. [Data dictionary](#6-data-dictionary)
7. [Stress model workbook](#7-stress-model-workbook)
8. [References](#8-references)

## 1. Design decisions

### Why this question

Rising non-performing exposures are the main channel through which a downturn reaches bank capital. In the ECB 2025 adverse scenario, loan losses removed 5.0 pp of CET1, the largest single driver. When CET1 falls below a bank's requirement, the bank is restricted from paying dividends, coupons and bonuses (CRD Article 141). The distance to that trigger is therefore the measure that matters to shareholders, bondholders and supervisors alike. That distance, not the CET1 ratio itself, is the model's output.
### Why this data

| Choice | Reason | Alternative rejected |
|---|---|---|
| EBA Transparency Exercise | Bank-level, item-level, consistent definitions across 119 banks and four quarters; free and reproducible | Bank annual reports: inconsistent definitions, manual extraction |
| June 2025 reference date | Latest available quarter; matches the ECB stress test starting point closely | Year-end 2024: older, and P&L would be full-year rather than half-year |
| EBA NPE definition | Same supervisory definition the ECB uses for its NPE path, so the shock and the base are like for like | Banks' own NPL ratios: narrower and not comparable across banks |
### Choices

#### Portfolio analysis

- **Three exposure measures, never summed.** Original exposure, exposure value and risk exposure amount measure different things (before mitigation, after mitigation, after risk weighting). Each is analysed on its own.
- **Rates, not only amounts.** Real estate carries the largest non-performing amount by sector, but construction has the highest NPE rate (6.4% against 2.8%). Ranking by amount alone would point to the wrong sector.
- **Concentration measured two ways.** A top-20 share and a running-total count both show 11–13 banks holding half of exposure. The HHI adds that, because those banks are of similar size, the system is not concentrated in the antitrust sense (HHI 302 by bank).
- **Duplicate totals removed.** Three structural traps in the data would have inflated results: NACE code 0 and Perf_Status code 0 holding sector totals, and exposure items carrying a counterparty-country breakdown alongside the country total. A fourth issue, an "All other banks" aggregate stored as if it were a bank, would have distorted bank rankings. Each was identified, documented and corrected in every affected query.

#### Stress model

| Decision | Rationale | Alternative rejected and why |
|---|---|---|
| Shock = ECB 2025 system NPE path | An authoritative, published scenario; the adverse end point (+4.1 pp to 5.8%) is stated in the ECB text | An invented shock: not defensible |
| Baseline and 1-year shocks read from ECB Chart 3.7 | The only ECB source for these values; reading calibrated to the two published values | Fractions of the 3-year shock: no source |
| Shock applied to gross loans, provisioned at the bank's own coverage | Uses bank-specific data where it exists; banks with weaker coverage lose more | A single system coverage ratio: discards bank information |
| RWA constant | Isolates the credit-loss channel. In the ECB result RWA growth was a smaller driver (1.1 pp) than loan losses (5.0 pp) | Modelling RWA migration: needs rating-migration data not in the dataset |
| Headline = instant loss absorption | The model does not stress revenues. Crediting run-rate profits would show capital rising under stress, contradicting the ECB's 4.0 pp fall | Earnings as the headline: produces a result no supervisor would accept |
| Earnings shown as a second layer under EBA rules (30% tax, 30% payout, no payout in loss years) | Shows how much depends on continued profitability, using the exercise's own rules | Ignoring earnings entirely: hides an important part of the answer |
| Each bank's own published CET1 requirement | The trigger differs by bank (from 9.6% to 11.2% among the published figures); a uniform threshold would misstate headroom | One threshold for all: simpler but wrong for every bank |
| Kommuninvest excluded from the stress run | It lends only to the public sector and has no NPE; the ECB treats such exposure as "low default". A commercial-loan shock would produce a meaningless 80% capital loss | Applying the shock anyway: an artefact, not a finding |
| Morgan Stanley Europe kept despite a 0.02% NPE ratio | A low NPE ratio is a starting point, not an exemption; it has a EUR 38bn credit book | Excluding healthy banks: selection bias towards weaker banks |
| Revolut kept but reported separately | A fintech with a loan book can be stressed; separating it keeps the comparison with traditional banks without distorting medians | Mixing it into medians: its 31% CET1 ratio would distort them |
### Anticipated questions

**Why not use the supervisors' own bank-level results?** The EBA publishes bank-level projections for the banks in its sample. Re-presenting them would show supervisory output, not analysis. The project instead builds a transparent model from first principles, in which every step can be inspected and changed, and uses the published results as a benchmark. A bank-by-bank comparison with the EBA projections is a natural extension.

**Your model shows smaller losses than the ECB (1.5–4.2 pp against 5.0 pp). Is it wrong?** It is narrower by design. New NPE are provisioned at today's coverage, while in a downturn coverage on new defaults is typically higher and the ECB also captures impairments on performing loans. The coverage sensitivity shows the effect: at +10 pp coverage, breaches rise from three to six. The direction of each bias is stated in the limitations.

**Why is the NPE ratio higher than banks report?** The EBA definition includes exposures "unlikely to pay" regardless of days past due. Santander shows 3.35% here against 2.92% in its own reporting. The ECB uses the same supervisory definition, so the shock and the base are consistent.

**Why hold RWA constant?** It isolates the credit-loss channel and follows the static-balance-sheet convention of the exercise. It understates depletion, and the limitations say so.

**Why 30% tax and 30% payout?** These are the EBA 2025 methodology's own rules (common 30% tax rate; payout floor of 30%, zero in loss years). The bank-specific payout history the rule prefers is not in the dataset, so the floor is used and its effect is shown in the sensitivity analysis.

**Why exclude Kommuninvest but not Morgan Stanley Europe?** The exclusion rests on what the bank is, not on its current numbers. Kommuninvest lends only to public-sector borrowers, whose exposures the ECB treats as low default. Morgan Stanley Europe lends to corporates and financial institutions, which can default. Excluding a bank because its loan book is healthy today would bias the sample.

**How do you know the numbers are right?** All queries run end to end on a fresh database. Model inputs reconcile to the source (CET1 ÷ RWA reproduces the reported ratio for every bank) and to the banks' own Pillar 3 disclosures. Every model output was recomputed outside Excel and matches to within 10⁻¹⁵. See the [validation log](#5-validation-log).

**What would you do with more time or data?** Bank-specific shocks by portfolio (mortgages, corporate, consumer); coverage that rises with severity; a revenue stress calibrated to the ECB's NII and fee effects; RWA migration; a year-by-year path rather than an end state; and a bank-by-bank comparison with the EBA's published projections.
### What the project does not claim

- It is not a forecast and not a replication of the supervisory stress test.
- It does not cover market, operational or funding risk.
- It is not investment advice.

## 2. Method

### Pipeline

```
EBA Transparency Exercise 2025 (CSV files in data/)
        │  eba_analysis.sql, Part 1: schema, load, fix of one corrupted LEI
        ▼
PostgreSQL 16 ──► eba_analysis.sql, Part 2: 40 analytical queries, each with its result
        │
        ├──► query Q33 ──► ../EBA_stress_test_model.xlsx ◄── data/cet1_requirements.csv
        │                        │
        └──► eba_analysis.sql, Part 3 ──► data/*.csv
                                 │
        build_web_data.py ──► data/eba.duckdb, data/web_data.json ──► ../index.html
```

Every number in the documentation traces to a query in eba_analysis.sql or to a cell on the model's sheets.

### Data

| Item | Detail |
|---|---|
| Source | European Banking Authority, EU-wide Transparency Exercise 2025 |
| Coverage | 119 banks from 25 home countries, plus an EBA "All other banks" aggregate (code OT); reference dates Sep 2024, Dec 2024, Mar 2025, Jun 2025 |
| Reference period for the analysis | 202506 (30 June 2025) |
| Units | EUR millions; ratio items (for example CET1 ratio, item 2520140) are decimals |
| Tables | `credit` (tr_cre.csv, 648,951 rows), `oth` (tr_oth.csv, 91,277 rows), `bank_metadata`, `nace_metadata`, `prefstatus_metadata` |

Three structural rules govern every query. The data dictionary has the detail ([section 6](#6-data-dictionary)).

1. **Templates and dimensions.** The credit table stacks several report templates (the `sheet` column). Each item reports only some breakdowns, and a breakdown is coded 0 where it does not apply.
2. **Duplicate totals.** Where an item reports a breakdown, code 0 can hold the total of the other codes. Item 2521301 repeats every bank-sector pair under Perf_Status 0, 2, 4 and 5, so sector queries filter `pref_status = 0`. NACE code 0 is likewise a total, not "unclassified" exposure (Q13a). The exposure items 2520502, 2520522 and 2520532 hold a country-total row (`country = 0`) and a breakdown of the same exposure by top counterparty countries, so exposure queries filter `country = 0`.
3. **Aggregate entity.** LEI `XXXXXXXXXXXXXXXXXXXX` is the EBA's "All other banks" aggregate. It is kept in system totals and country totals (as "Other") and excluded from bank-level counts, rankings and concentration.

### Portfolio analysis

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

### Stress model

#### Question

If the NPE ratio rises by the amount in the ECB 2025 stress test, does each bank's CET1 ratio stay above its CET1 requirement (the trigger for restrictions on distributions, or "MDA trigger")?

#### Bank sample

The input sheet lists 12 banks. They span size (EUR 19bn to EUR 2.6tn total assets), NPE ratio (0% to 6.9%) and CET1 ratio (12.5% to 31%, with Kommuninvest an outlier at 353%), and include two deliberate contrast cases:

- **Kommuninvest**, a lender to Swedish municipalities and regions. It has no non-performing exposure and its lending is to the public sector. An NPE shock derived from commercial loan defaults does not apply to it, so it is kept for reference and excluded from the stress run (assumption A16).
- **Revolut Holdings Europe**, a fintech. It is stressed but reported on its own line as a reference case and excluded from medians (A17).

The other ten banks are the core sample.

#### Scenarios

| Scenario | NPE shock | Horizon | Source |
|---|---|---|---|
| S1 1-year baseline | +0.8 pp | 1 year | ECB report, Chart 3.7 (read from chart) |
| S2 1-year adverse | +1.2 pp | 1 year | ECB report, Chart 3.7 (read from chart) |
| S3 3-year baseline | +2.4 pp | 3 years | ECB report, Chart 3.7 (read from chart) |
| S4 3-year adverse | +4.1 pp | 3 years | ECB report, p. 26: NPE ratio from 1.7% to 5.8% by end-2027 |

The ECB states the adverse end point in its text. The baseline path and the intermediate years appear only in Chart 3.7 (page 27). They were read by measuring the plotted lines against the chart's axis, calibrated to the two published values (1.7% at end-2024 and 5.8% at end-2027). The readings are accurate to about ±0.1 pp, and the sensitivity analysis tests ±0.3 pp.

#### Calculation

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

#### Why the headline is instant loss absorption

The model stresses credit losses only. It does not stress revenues, market risk or operational risk. Crediting three years of profit at the June 2025 run rate adds 4 to 14 pp of CET1 per bank, more than the 1.5 to 4.2 pp the adverse shock removes. That would show capital rising under stress, against the ECB's finding of a 4.0 pp fall. The headline therefore answers a narrower and more robust question: can today's capital absorb the shock? The earnings layer is reported beside it and labelled optimistic.

#### CET1 requirement

Each bank's own published CET1 requirement, excluding Pillar 2 Guidance, is used. It is taken from the bank's SREP announcement or its Pillar 3 EU KM1 template. It equals 4.5% Pillar 1, plus the CET1 part of the Pillar 2 requirement, plus the combined buffer requirement. CEC Bank publishes none, so it uses a labelled fallback built from the same components ([cet1_requirements.csv](data/cet1_requirements.csv)).

#### Sensitivity

The 3-year adverse headroom is recomputed with the shock ±0.3 pp, coverage ±10 pp, and (earnings layer) payout at 0% and 50%.

## 3. Assumptions register

This mirrors the `Assumptions` sheet of [`EBA_stress_test_model.xlsx`](../EBA_stress_test_model.xlsx). The workbook is the controlling version; if the two ever differ, the workbook governs.

| ID | Assumption | Value | Source / rationale |
|---|---|---|---|
| A1 | NPE shock, 1-year baseline | +0.8 pp | ECB 2025 stress test report, Chart 3.7 (p. 27), read from chart: baseline path about 2.5% at end-2025 against 1.7% at the start. |
| A2 | NPE shock, 1-year adverse | +1.2 pp | Same chart: adverse path about 2.9% at end-2025. |
| A3 | NPE shock, 3-year baseline | +2.4 pp | Same chart: baseline path about 4.1% at end-2027. |
| A4 | NPE shock, 3-year adverse | +4.1 pp | ECB report, p. 26: "banks project a steady increase in the NPE ratio to 5.8% at the end of 2027", from 1.7%. |
| A5 | Shock base | Gross loans, performing + non-performing | Item 2520603, Perf_Status 1 and 2. The shock moves the NPE ratio, so it applies to the whole gross book. |
| A6 | Provisioning of new NPE | Bank's current NPE coverage | Item 2520613 ÷ item 2520603 (Perf_Status 2). |
| A7 | RWA | Held constant | Isolates the credit-loss channel. In the ECB 2025 adverse result (net CET1 depletion 4.0 pp), loan losses took 5.0 pp and risk exposure amount growth 1.1 pp. Holding RWA constant understates depletion. |
| A8 | Balance sheet | Static | Mirrors the EBA/ECB methodology. |
| A9 | Annualisation factor | 2 | Profit items at 202506 are half-year cumulative (n_quarters = 2). |
| A10 | Earnings capacity per year | Annualised profit before tax | Item 2520332 × 2. Profit before tax already includes the ongoing impairment charge, so only the shock provisions are added. |
| A11 | Tax rate on positive results | 30% | EBA 2025 stress test methodological note, para. 32: "common simplified tax rate of 30%". |
| A12 | Tax on losses | No tax credit | Deferred tax assets from tax losses depend on future profitability and are deducted from CET1 (CRR Art. 36(1)(c)). |
| A13 | Payout ratio, profit years | 30% | EBA methodological note, Table 1: declared policy, else max(30%, median 2020–24 payout); same in adverse. The 2020–24 payouts are not in the data, so the 30% floor is applied to all banks. |
| A14 | Payout ratio, loss years | 0% | EBA methodological note, Table 1. |
| A15 | CET1 requirement | Bank's published requirement | SREP announcements or Pillar 3 EU KM1; CEC Bank fallback ([cet1_requirements.csv](data/cet1_requirements.csv)). |
| A16 | Kommuninvest | Excluded from stress run | Public-sector lender with no NPE. ECB report (text under Chart 3.8): exposures to central banks, governments and financial institutions are 32% of exposures but about 6% of impairments, being "low default". |
| A17 | Revolut | Reference case | Fintech business model; shown separately and excluded from medians. |
| A18 | Horizon | Single-period end state | Provisions are assumed spread evenly over the horizon, so annual and cumulative results have the same sign. |
| A19 | Headline view | Instant loss absorption | Shock provisions charged against June 2025 CET1 without an earnings offset; the earnings view (A9–A14) is a second layer. See [Why the headline is instant loss absorption](#why-the-headline-is-instant-loss-absorption). |

### Sources

- ECB (2025), *2025 stress test of euro area banks – Final results*. <https://www.bankingsupervision.europa.eu/ecb/pub/pdf/ssm.Report_2025_Stress_Test_202508.en.pdf>
- EBA (2024), *2025 EU-wide stress test – Methodological note*. <https://www.eba.europa.eu/sites/default/files/2024-11/ee01efca-947b-43ae-b17d-20f9d4314e8e/2025%20EU-wide%20stress%20test%20-%20Methodological%20Note.pdf>
- Regulation (EU) No 575/2013 (CRR), Article 36(1)(c).

## 4. Limitations and model risk

### Limitations

| ID | Limitation | Direction of bias | Mitigation |
|---|---|---|---|
| L1 | Credit losses only. Market, operational and funding risk are not modelled; in the ECB 2025 adverse scenario market risk took 1.3 pp and operational risk about 0.6–0.7 pp of CET1. | Understates depletion | Results are compared to the ECB only as a partial channel; the headline avoids crediting earnings. |
| L2 | No revenue stress. Earnings in the second layer are held at the H1 2025 run rate; the ECB adverse scenario cuts net interest income capacity by 2.6 pp and fee and dividend income by 1.0 pp against baseline. Constant RWA (A7) adds to this. | Overstates headroom in the earnings layer | Earnings layer labelled optimistic; headline uses instant loss absorption (A19). |
| L3 | One system-wide shock for every bank. Bank-specific ECB projections differ by portfolio mix and are not published in a usable form. | Either way: understates for riskier books, overstates for safer ones | Sensitivity of ±0.3 pp; banks' own NPE ratio and coverage still drive the size of the loss. |
| L4 | Baseline and 1-year shocks are read from ECB Chart 3.7, not stated in its text. | ±0.1 pp reading precision | Calibrated to the two published values; sensitivity ±0.3 pp leaves the breach count unchanged. |
| L5 | Payout: the EBA rule uses declared dividend policies or the 2020–24 median payout, neither of which is in the dataset; the 30% floor is applied to all banks. | Overstates retained earnings for high-payout banks | Payout 0% and 50% shown in the sensitivity sheet. |
| L6 | CET1 requirements: five are as at 1 January 2025, five as at 30 June 2025 (differences mainly in the countercyclical buffer, up to about 0.1 pp). Commerzbank's figure is its published MDA threshold, which includes a 0.04 pp AT1 shortfall. CEC Bank uses a fallback including a 2% systemic risk buffer last confirmed for 2022; without it the requirement is 10.2%. | Small, either way | Source and date recorded per bank; CEC's result is far from the threshold under either value. |
| L7 | Morgan Stanley Europe's coverage rests on EUR 7 mn of NPE and Revolut's on EUR 57 mn, so their provisioning on a large shock is uncertain. Both carry risks (market and counterparty; payments and funding) that a loan-loss shock does not capture. | Uncertain | Coverage sensitivity ±10 pp; Revolut reported separately. |
| L8 | Single period: no year-by-year path, management actions or changes in balance sheet size and mix. | Either way | Consistent with the static balance sheet used by the EBA/ECB. |
| L9 | New NPE are provisioned at the bank's current coverage. In a downturn, collateral values fall and coverage on new defaults can be higher. | Understates losses | Coverage +10 pp case: six of ten core banks below requirement instead of three. |
| L10 | EBA NPE is broader than banks' own NPL measures (it includes "unlikely to pay"). Applying a pp shock to a broader base gives a larger loss than the same shock on an NPL base. | Overstates losses slightly | Consistent with the ECB, whose NPE ratio uses the same supervisory definition. |

### Model risk assessment

| Risk | Description | Control |
|---|---|---|
| Data | Wrong item, wrong breakdown or double counting | Item codes checked against labels and templates; duplicate-total rules documented; CET1 ratio recomputed from CET1 ÷ RWA for every bank; four banks' ratios matched to Pillar 3. |
| Specification | The model answers a narrower question than a supervisory stress test | Question stated as "can today's capital absorb the shock"; limitations listed with direction of bias. |
| Parameter | Shocks, coverage and payout are uncertain | Every parameter sourced in the assumptions register; sensitivity on the three that matter. |
| Implementation | Spreadsheet formula errors | Live formulas only, no pasted results; independent recalculation outside Excel matched to within 1e-15; in-workbook check cells. |
| Use | Results read as a forecast or as investment advice | Scope note on the cover sheet and in every summary document. |

## 5. Validation log

Checks performed on the data, the queries and the stress model. Each entry records what was checked, how, and the result.

### Data

| # | Check | Method | Result |
|---|---|---|---|
| D1 | Row counts after load | `count(*)` per table | credit 648,951; oth 91,277; bank_metadata 120; nace_metadata 20; prefstatus_metadata 12 |
| D2 | Units are EUR millions | Total assets (item 2521010) compared with published balance sheets of Santander and BBVA | Consistent |
| D3 | Bank codes match | Q2: LEI codes in `credit` with no match in `bank_metadata` | One corrupted code (`9.598E+19`, scientific-notation conversion); fixed in `eba_analysis.sql` (Part 1) |
| D4 | NACE code 0 | Q13a: compare code 0 with the sum of codes 1–19 | Code 0 is a duplicate total, not unclassified exposure; excluded from sector queries |
| D5 | Perf_Status duplicates in item 2521301 | Count rows per bank-sector pair by Perf_Status | Each pair appears under 0, 2, 4 and 5; sector queries filter `pref_status = 0` |
| D6 | Exposure value against bank disclosures | Crédit Agricole summed to EUR 3.80tn (item 2520522, all rows) against about EUR 2.17–2.19tn leverage exposure | Gap traced to a double count: the item holds a country-total row and a counterparty-country breakdown of the same exposure. With `country = 0` only it is EUR 1.98tn, consistent with the bank's figure. Fifteen queries corrected (see D8) |
| D7 | NPE ratio against bank NPL ratios | Santander 3.35% against 2.92% reported; BNP Paribas 2.79% against 1.6% | Definitional: EBA NPE includes "unlikely to pay" |
| D8 | Country breakdown in exposure items | Rows by `country` for items 2520502/522/532 | `country = 0` is the total; codes 1+ break it down by top counterparty countries (full-template banks only). Total original exposure is EUR 31.3tn, not the EUR 58tn an all-row sum gives. Shares by country and bank change little because the duplication is broadly proportional |
| D9 | Entities that are not banks | Unmatched codes in Q2; names in `bank_metadata` | `XXXXXXXXXXXXXXXXXXXX` is the EBA "All other banks" aggregate (EUR 527bn, 17th largest if ranked as a bank). Excluded from bank-level counts and rankings; kept in system and country totals |

### Queries

| # | Check | Result |
|---|---|---|
| Q-1 | All 40 analytical queries and the setup scripts run end to end on PostgreSQL 16 loaded from the EBA files | Pass |
| Q-2 | Sector results recomputed after the Perf_Status correction | Real Estate 25.5% of classified exposure; Construction NPE rate 6.4% |
| Q-3 | Concentration found two independent ways | Top-20 share (Q8, 66.4%) and running total (Q18, 11–13 banks for half of exposure) agree |
| Q-4 | Trend query checked for composition effects | Banks reporting vary by period (115, 119, 110, 119); the top-20 share is not read as a trend |
| Q-5 | All 40 queries run unchanged on DuckDB-WASM 1.32.0 (the web page) against the extract built by `build_web_data.py` | 39 of 40 results identical to PostgreSQL; Q3 lists only the items in the extract. Five queries (Q13a, Q13b, Q14, Q17, Q26) had an unqualified column in `ORDER BY` that PostgreSQL resolves to the output column and DuckDB 1.4 rejects as ambiguous; the table alias was added, results unchanged |

### Stress model inputs

| # | Check | Result |
|---|---|---|
| M-1 | Q33 output equals the `Bank Inputs` sheet | Equal for all 12 banks |
| M-2 | CET1 capital ÷ RWA equals the reported CET1 ratio (item 2520140) | Equal for all 12 banks (check column R) |
| M-3 | Reported CET1 ratio equals the bank's Pillar 3 KM1 at 30 June 2025 | Deutsche Bank 14.24%, Morgan Stanley Europe 18.00%, Revolut 31.32%, HSBC Continental Europe 15.5%: all match, confirming the same consolidation scope |
| M-4 | Each CET1 requirement equals the sum of its published components | Matches within rounding (0.01–0.1 pp); source, date and components recorded in `cet1_requirements.csv` |
| M-5 | Chart 3.7 readings | Reading of the adverse line at end-2027 (5.74%) against the published 5.8% gives a calibration error of about 0.06 pp |

### Stress model outputs

| # | Check | Result |
|---|---|---|
| O-1 | Workbook recalculated in LibreOffice | 1,390 formulas, 0 errors |
| O-2 | Every headroom figure (11 banks × 4 scenarios × 2 views) recomputed in Python from the raw inputs | Maximum absolute difference 5 × 10⁻¹⁶ |
| O-6 | Web page stress test (`index.html`) against `data/stress_results.csv`, all 88 rows, in a headless browser | Every headroom equal to 2 decimals as displayed; maximum absolute difference 5 × 10⁻⁷ (the CSV is rounded to 6 decimals) |
| O-3 | Sensitivity base cases equal the Summary results | In-workbook check cells return 0 |
| O-4 | Order of magnitude against the ECB | 3-year adverse credit loss 1.5–4.2 pp of RWA at the core banks, against 5.0 pp loan-loss contribution in the ECB aggregate; lower, as expected given L9 (current coverage on new defaults) and the ECB's wider loss perimeter, which also covers impairments on performing exposures |
| O-5 | Direction of results | The three banks that breach (BNP Paribas, BAWAG, ING) are the three with the lowest starting headroom (2.2–2.4 pp) |

## 6. Data dictionary

### Tables

| Table | Source file | Rows | Grain |
|---|---|---|---|
| `credit` | `tr_cre.csv` | 648,951 | One value per bank × period × item × breakdown combination |
| `oth` | `tr_oth.csv` | 91,277 | One value per bank × period × item (capital, P&L, balance sheet) |
| `bank_metadata` | `TR_Metadata_Bankdetail.csv` | 120 | One row per bank (LEI) |
| `nace_metadata` | `TR_Metadata_nace.csv` | 20 | NACE sector codes 0–19 |
| `prefstatus_metadata` | `TR_Metadata_perfstatus.csv` | 12 | Performing-status codes |

View `metadata` is an alias of `bank_metadata`.

### Key columns

| Column | Table | Meaning |
|---|---|---|
| `lei_code` | all | Legal Entity Identifier of the reporting bank (join key) |
| `nsa` | credit, oth | Home country of the bank (national supervisory authority) |
| `period` | credit, oth | Reference date, YYYYMM (202409, 202412, 202503, 202506) |
| `item` | credit, oth | EBA item code; defines what the amount measures |
| `label` | credit, oth | Description of the item |
| `sheet` | credit, oth | Report template the item belongs to (for example NPE, NACE, Credit Risk_STA_a) |
| `portfolio` | credit | 1 = Standardised Approach, 2 = IRB, 0 = no breakdown |
| `country` | credit | Counterparty country code (0 = total) |
| `exposure` | credit, oth | Exposure class code (0 = total) |
| `pref_status` | credit | EBA `Perf_Status` (performing status), renamed in the schema |
| `nace_codes` | credit | NACE sector code (0 = total) |
| `amount` | credit, oth | Value: EUR millions, or a decimal for ratio items |
| `n_quarters` | oth | Quarters accumulated in P&L items (2 at 202506 = half-year) |

### Performing status (`pref_status`)

| Code | Meaning |
|---|---|
| 0 | No breakdown (can hold the total of other codes) |
| 1 | Performing |
| 11 | Performing, of which forborne |
| 12 | Performing, of which Stage 2 |
| 2 | Non-performing |
| 21 | Non-performing, of which forborne |
| 22 | Non-performing, of which unlikely to pay, not past due or ≤ 90 days past due |
| 222 | Non-performing, of which Stage 2 |
| 23 | Non-performing, of which Stage 3 |
| 3 | Performing but past due > 30 and ≤ 90 days |
| 4 | Non-performing and defaulted |
| 5 | Loans and advances subject to impairment |

Codes 11, 12, 21–23 and 222 are "of which" subsets and must not be added to their parent code.

### NACE sectors (`nace_codes`)

| Code | Sector | Code | Sector |
|---|---|---|---|
| 0 | No breakdown (total) | 10 | J Information and communication |
| 1 | A Agriculture, forestry and fishing | 11 | K Financial and insurance |
| 2 | B Mining and quarrying | 12 | L Real estate |
| 3 | C Manufacturing | 13 | M Professional, scientific and technical |
| 4 | D Electricity, gas, steam | 14 | N Administrative and support services |
| 5 | E Water supply | 15 | O Public administration and defence |
| 6 | F Construction | 16 | P Education |
| 7 | G Wholesale and retail trade | 17 | Q Human health and social work |
| 8 | H Transport and storage | 18 | R Arts, entertainment and recreation |
| 9 | I Accommodation and food service | 19 | S Other services |

### Items used

| Item | Table | Template | Label | Referenced in |
|---|---|---|---|---|
| 2520502 | credit | Credit Risk STA/IRB | Original exposure by exposure class | Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q10, Q11, Q12, Q17, Q18, Q19, Q30, Q31, Q32 (anchor) |
| 2520522 | credit | Credit Risk STA/IRB | Exposure value by exposure class | Q3, Q4, Q5, Q6, Q7, Q8, Q17, Q18, Q19, Q29 |
| 2520532 | credit | Credit Risk STA/IRB | Risk exposure amount by exposure class | Q3, Q4, Q5, Q6, Q7, Q8, Q17, Q18, Q19, Q29 |
| 2521301 | credit | NACE | Gross carrying amount | Q13, Q13a, Q13b, Q14, Q16, Q20, Q22, Q22a, Q22b, Q27, Q30 |
| 2521302 | credit | NACE | Accumulated impairment | Q27 |
| 2521303 | credit | NACE | Accumulated negative changes in fair value due to credit risk on non-performing exposures | Q16, Q16b |
| 2520603 | credit | NPE | Gross carrying amount on loans and advances | Q20, Q20b, Q21, Q23, Q24, Q26, Q26b, Q28, Q31, Q32, Q33 |
| 2520613 | credit | NPE | Accumulated impairment, fair-value changes due to credit risk and provisions on loans and advances | Q26b, Q28, Q33 |
| 2521010 | oth | Assets | Total assets | Q26, Q33 |
| 2520102 | oth | Capital | CET1 capital (net of deductions, transitional) | Q25, Q26c, Q33 |
| 2520138 | oth | Capital | Total risk exposure amount (RWA) | Q25, Q26c, Q33 |
| 2520140 | oth | Capital | CET1 ratio (transitional), decimal | Q25, Q26, Q33 |
| 2520332 | oth | P&L | Profit or loss before tax, continuing operations (half-year at 202506) | Q33 |
| 2520333 | oth | P&L | Profit or loss after tax, continuing operations (half-year at 202506) | Q33 |

For items 2520502, 2520522 and 2520532, `country` = 0 is the total for each bank and exposure class; other country codes repeat part of the same exposure by counterparty country, so totals use `country = 0` only. LEI `XXXXXXXXXXXXXXXXXXXX` (stored in lower case in `bank_metadata`) is the EBA "All other banks" aggregate, not a bank.

Items with similar labels can cover different scopes. For example, three different items are labelled "gross carrying amount on loans and advances". Use the item code, not the label.

## 7. Stress model workbook

`EBA_stress_test_model.xlsx` measures each bank's CET1 headroom to its own CET1 requirement after an NPE shock taken from the ECB 2025 stress test. The method is in [section 2](#2-method) and the assumptions in [section 3](#3-assumptions-register).

### Sheets

| Sheet | Content |
|---|---|
| Cover | Purpose, data, units, colour code, scope |
| Assumptions | A1–A19 with values and sources; scenario table S1–S4 |
| Requirements | CET1 requirement per bank, with components, date and source URL |
| Bank Inputs | Output of query Q33 in `eba_analysis.sql`, plus derived ratios and today's headroom |
| Stress | Four scenario blocks. Columns F–K are the headline (instant loss absorption); columns L–S are the earnings layer |
| Summary | Headroom by bank and scenario for both views; medians, minimums and breach counts for the core banks |
| Sensitivity | 3-year adverse headroom with the shock ±0.3 pp, coverage ±10 pp and payout 0% / 50% |
| Notes | Method and limitations L1–L10 |

### Colour code

Blue text = input or source data · black = formula · green = link to another sheet · yellow fill = key lever.

### Updating the model

1. To change a scenario or rule, edit the yellow cells on `Assumptions` (or the steps on `Sensitivity`).
2. To refresh the data, run query Q33 for the new period and paste the values into `Bank Inputs` columns A–K, N and O, keeping the row order.
3. To update a requirement, edit `Requirements` column C and its source, and the same row in `data/cet1_requirements.csv`.

The workbook has no macros and no external links; all results recalculate from the inputs.

### Headline results (30 June 2025 data)

| Core banks | Today | S1 | S2 | S3 | S4 |
|---|---|---|---|---|---|
| Median headroom, instant loss (pp) | 3.78 | 3.15 | 2.83 | 1.89 | 0.54 |
| Below requirement | 0 | 0 | 0 | 0 | 3 |
| Median headroom, with earnings (pp) | 3.78 | 4.70 | 4.55 | 7.15 | 6.72 |

## 8. References

### Data

- European Banking Authority (2025). *EU-wide Transparency Exercise 2025*, full database. <https://www.eba.europa.eu/risk-and-data-analysis/risk-analysis/eu-wide-transparency-exercise>
- European Banking Authority. *Legal notice* (reproduction authorised provided the source is acknowledged). <https://eba.europa.eu/legal-notice>

### Stress-test methodology and results

- European Central Bank (2025). *2025 stress test of euro area banks – Final results*. Chart 3.7 (p. 27), NPE path text (p. 26), MDA breaches and dividend restrictions (pp. 6, 20), revenue effects (pp. 18–19). <https://www.bankingsupervision.europa.eu/ecb/pub/pdf/ssm.Report_2025_Stress_Test_202508.en.pdf>
- European Central Bank (2025). Press release on the 2025 stress test results, 1 August 2025. <https://www.bankingsupervision.europa.eu/press/pr/date/2025/html/ssm.pr250801~24ec6ae308.en.html>
- European Banking Authority (2024). *2025 EU-wide stress test – Methodological note*. Para. 32 (tax), Table 1 (dividends). <https://www.eba.europa.eu/sites/default/files/2024-11/ee01efca-947b-43ae-b17d-20f9d4314e8e/2025%20EU-wide%20stress%20test%20-%20Methodological%20Note.pdf>
- European Banking Authority (2025). *2025 EU-wide stress test – Results*. <https://www.eba.europa.eu/sites/default/files/2025-08/0178b9c5-2f0d-42ee-8226-6fa0a87c0d6c/2025%20EU-wide%20stress%20test%20-%20Results.pdf>

### Capital requirements

- European Central Bank. *Pillar 2 requirements* (bank-specific P2R). <https://www.bankingsupervision.europa.eu/activities/srep/pillar-2-requirement/html/index.en.html>
- European Central Bank (2024). *ECB keeps capital requirements broadly steady for 2025*, press release, 17 December 2024. <https://www.bankingsupervision.europa.eu/press/pr/date/2024/html/ssm.pr241217~8ca7d1d44e.en.html>
- Bank disclosures used for each CET1 requirement are listed with URLs in [`data/cet1_requirements.csv`](data/cet1_requirements.csv).
- Romanian National Committee for Macroprudential Oversight: O-SII buffers from 1 April 2025; Recommendation R/1/2025 (countercyclical buffer). <https://www.cnsmro.ro/en/>
- European Systemic Risk Board (2022). Notification of the Romanian systemic risk buffer. <https://www.esrb.europa.eu/pub/pdf/other/Esrb.notification220629_SyRB_RO~d452cebd9d.en.pdf>

### Regulation

- Regulation (EU) No 575/2013 (Capital Requirements Regulation), Articles 36 and 92. <https://eur-lex.europa.eu/eli/reg/2013/575/oj>
- Directive 2013/36/EU (Capital Requirements Directive), Article 141 (restrictions on distributions). <https://eur-lex.europa.eu/eli/dir/2013/36/oj>
