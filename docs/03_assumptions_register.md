# Assumptions register

This mirrors the `Assumptions` sheet of [`model/EBA_stress_test_model.xlsx`](../model/EBA_stress_test_model.xlsx). The workbook is the controlling version; if the two ever differ, the workbook governs.

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
| A15 | CET1 requirement | Bank's published requirement | SREP announcements or Pillar 3 EU KM1; CEC Bank fallback ([cet1_requirements.csv](../model/inputs/cet1_requirements.csv)). |
| A16 | Kommuninvest | Excluded from stress run | Public-sector lender with no NPE. ECB report (text under Chart 3.8): exposures to central banks, governments and financial institutions are 32% of exposures but about 6% of impairments, being "low default". |
| A17 | Revolut | Reference case | Fintech business model; shown separately and excluded from medians. |
| A18 | Horizon | Single-period end state | Provisions are assumed spread evenly over the horizon, so annual and cumulative results have the same sign. |
| A19 | Headline view | Instant loss absorption | Shock provisions charged against June 2025 CET1 without an earnings offset; the earnings view (A9–A14) is a second layer. See [methodology §4.5](02_methodology.md). |

## Sources

- ECB (2025), *2025 stress test of euro area banks – Final results*. <https://www.bankingsupervision.europa.eu/ecb/pub/pdf/ssm.Report_2025_Stress_Test_202508.en.pdf>
- EBA (2024), *2025 EU-wide stress test – Methodological note*. <https://www.eba.europa.eu/sites/default/files/2024-11/ee01efca-947b-43ae-b17d-20f9d4314e8e/2025%20EU-wide%20stress%20test%20-%20Methodological%20Note.pdf>
- Regulation (EU) No 575/2013 (CRR), Article 36(1)(c).
