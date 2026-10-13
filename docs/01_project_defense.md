# Project defense

This document sets out what the project does, why each design choice was made, which alternatives were rejected, and how it answers the challenges a reviewer is likely to raise.

## 1. The project in one paragraph

The project uses the EBA's 2025 Transparency Exercise, the most granular public dataset on EU bank balance sheets, to answer two linked questions. First, where does credit risk sit in the EU banking system: by bank, country and sector? Second, could a set of large and contrasting banks absorb, from today's capital, the rise in non-performing exposures that the ECB used in its 2025 stress test? The portfolio analysis is in SQL (40 queries, PostgreSQL). The stress test is an Excel model with live formulas. Every input and assumption is traced to a source, and every result is checked independently.

## 2. Why this question

Rising non-performing exposures are the main channel through which a downturn reaches bank capital. In the ECB 2025 adverse scenario, loan losses removed 5.0 pp of CET1, the largest single driver. When CET1 falls below a bank's requirement, the bank is restricted from paying dividends, coupons and bonuses (CRD Article 141). The distance to that trigger is therefore the measure that matters to shareholders, bondholders and supervisors alike. That distance, not the CET1 ratio itself, is the model's output.

## 3. Why this data

| Choice | Reason | Alternative rejected |
|---|---|---|
| EBA Transparency Exercise | Bank-level, item-level, consistent definitions across 119 banks and four quarters; free and reproducible | Bank annual reports: inconsistent definitions, manual extraction |
| June 2025 reference date | Latest available quarter; matches the ECB stress test starting point closely | Year-end 2024: older, and P&L would be full-year rather than half-year |
| EBA NPE definition | Same supervisory definition the ECB uses for its NPE path, so the shock and the base are like for like | Banks' own NPL ratios: narrower and not comparable across banks |

## 4. Design decisions

### 4.1 Portfolio analysis

- **Three exposure measures, never summed.** Original exposure, exposure value and risk exposure amount measure different things (before mitigation, after mitigation, after risk weighting). Each is analysed on its own.
- **Rates, not only amounts.** Real estate carries the largest non-performing amount by sector, but construction has the highest NPE rate (6.4% against 2.8%). Ranking by amount alone would point to the wrong sector.
- **Concentration measured two ways.** A top-20 share and a running-total count both show 11–13 banks holding half of exposure. The HHI adds that, because those banks are of similar size, the system is not concentrated in the antitrust sense (HHI 302 by bank).
- **Duplicate totals removed.** Three structural traps in the data would have inflated results: NACE code 0 and Perf_Status code 0 holding sector totals, and exposure items carrying a counterparty-country breakdown alongside the country total. A fourth issue, an "All other banks" aggregate stored as if it were a bank, would have distorted bank rankings. Each was identified, documented and corrected in every affected query.

### 4.2 Stress model

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

## 5. Results

| | Today | 3-year adverse, instant loss |
|---|---|---|
| Median headroom, core banks | 3.8 pp | 0.5 pp |
| Core banks below requirement | 0 | 3 (BAWAG, ING, BNP Paribas) |
| Core banks within 1 pp | 0 | 6 |

The one-year scenarios and the three-year baseline produce no breaches. With earnings credited, no bank breaches in any scenario. The view that follows is that the sample is resilient to a short or moderate shock, and that resilience to a severe, prolonged one depends on continued profitability.

## 6. Anticipated questions

**Why not use the supervisors' own bank-level results?** The EBA publishes bank-level projections for the banks in its sample. Re-presenting them would show supervisory output, not analysis. The project instead builds a transparent model from first principles, in which every step can be inspected and changed, and uses the published results as a benchmark. A bank-by-bank comparison with the EBA projections is a natural extension.

**Your model shows smaller losses than the ECB (1.5–4.2 pp against 5.0 pp). Is it wrong?** It is narrower by design. New NPE are provisioned at today's coverage, while in a downturn coverage on new defaults is typically higher and the ECB also captures impairments on performing loans. The coverage sensitivity shows the effect: at +10 pp coverage, breaches rise from three to six. The direction of each bias is stated in the limitations.

**Why is the NPE ratio higher than banks report?** The EBA definition includes exposures "unlikely to pay" regardless of days past due. Santander shows 3.35% here against 2.92% in its own reporting. The ECB uses the same supervisory definition, so the shock and the base are consistent.

**Why hold RWA constant?** It isolates the credit-loss channel and follows the static-balance-sheet convention of the exercise. It understates depletion, and the limitations say so.

**Why 30% tax and 30% payout?** These are the EBA 2025 methodology's own rules (common 30% tax rate; payout floor of 30%, zero in loss years). The bank-specific payout history the rule prefers is not in the dataset, so the floor is used and its effect is shown in the sensitivity analysis.

**Why exclude Kommuninvest but not Morgan Stanley Europe?** The exclusion rests on what the bank is, not on its current numbers. Kommuninvest lends only to public-sector borrowers, whose exposures the ECB treats as low default. Morgan Stanley Europe lends to corporates and financial institutions, which can default. Excluding a bank because its loan book is healthy today would bias the sample.

**How do you know the numbers are right?** All queries run end to end on a fresh database. Model inputs reconcile to the source (CET1 ÷ RWA reproduces the reported ratio for every bank) and to the banks' own Pillar 3 disclosures. Every model output was recomputed outside Excel and matches to within 10⁻¹⁵. See the [validation log](05_validation_log.md).

**What would you do with more time or data?** Bank-specific shocks by portfolio (mortgages, corporate, consumer); coverage that rises with severity; a revenue stress calibrated to the ECB's NII and fee effects; RWA migration; a year-by-year path rather than an end state; and a bank-by-bank comparison with the EBA's published projections.

## 7. What the project does not claim

- It is not a forecast and not a replication of the supervisory stress test.
- It does not cover market, operational or funding risk.
- It is not investment advice.
