# Executive summary

## Question

How resilient is the capital of large EU banks to a rise in non-performing exposures (NPE) of the size the ECB used in its 2025 stress test, and where in the EU credit portfolio does that risk sit?

## View

At June 2025 the ten core banks modelled can absorb a one-year adverse NPE shock from existing capital alone. A three-year adverse shock absorbed by existing capital alone would push three of them below their CET1 requirement: BAWAG (−1.4 pp), ING (−1.0 pp) and BNP Paribas (−0.3 pp). Median headroom would fall from 3.8 pp to 0.5 pp of risk-weighted assets. With earnings at the June 2025 run rate, all ten stay above their requirement, so resilience depends on banks continuing to earn through the downturn, which is the channel the ECB adverse scenario itself weakens.

**Confidence: medium.** The credit-loss mechanics and the inputs are reconciled to source data and to the banks' own disclosures. The result covers credit losses only, uses one system-wide shock for all banks, and holds revenues and risk-weighted assets constant ([limitations](04_limitations_model_risk.md)).

**What would change the view:** NPE coverage on new defaults about 10 pp higher than banks' current coverage would raise the number of breaches from three to six. A bank-specific shock larger than the system average for the higher-NPE banks would also raise it. A shock 0.3 pp smaller or larger leaves the same three banks below.

## Evidence

| Finding | Figure | Source |
|---|---|---|
| Exposure is concentrated in a few banks | 11–13 of 119 banks hold half of reported credit exposure, depending on the measure; the top 20 hold 66.4% | [Q8, Q18](06_sql_question_log.md) |
| Concentration is moderate by country and low by bank | HHI 1,501 (country), 302 (bank) | Q30 |
| Real estate is the largest sector exposure | 25.5% of classified gross carrying amount | Q16 |
| Construction is the weakest sector | NPE rate 6.4%; impairment ratio 4.1% | Q22b, Q27 |
| Asset quality improved through the year | Portfolio NPE ratio 2.24% → 2.14% (Sep 2024 → Jun 2025) | Q23, Q31 |
| NPE coverage varies widely by country | Germany 35.0%, France 44.4%, Spain 45.5%, Italy 52.1% | Q28 |
| Banks start the stress close to their requirement | Median headroom 3.8 pp; lowest 2.2 pp (BNP Paribas, BAWAG) | Stress model |
| A 3-year adverse shock costs 1.5–4.2 pp of CET1 at the core banks | Shock provisions ÷ RWA, by bank | Stress model |

## Approach

1. **Data.** EBA 2025 EU-wide Transparency Exercise (119 banks, June 2025), loaded into PostgreSQL.
2. **Portfolio analysis.** 40 SQL queries cover concentration, geography, sector, asset quality, credit ratios and trend.
3. **Stress model.** For 11 banks (10 core banks plus Revolut as a fintech reference case), the model takes the ECB 2025 system NPE path as a shock, converts new NPE into provisions at each bank's own coverage, and measures CET1 headroom against each bank's published CET1 requirement. There are four scenarios: 1-year and 3-year, baseline and adverse.
4. **Validation.** Every query was run end to end, inputs were reconciled to bank Pillar 3 disclosures, and model outputs were recomputed independently ([validation log](05_validation_log.md)).

## Scope note

This is an educational analysis of public data. It is not investment advice and does not reproduce or replace supervisory stress-test results.
