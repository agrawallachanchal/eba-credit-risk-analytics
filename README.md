# EU Bank Credit Risk: Could Banks Absorb the ECB's 2025 Stress?

**If a wave of bad loans like the ECB's 2025 stress test hit Europe, would the big banks still have enough capital?**

For most of them, yes. Ten large banks start with a cushion of about 3.8 percentage points above the minimum capital they must hold. The ECB's three-year adverse scenario would shrink that cushion to about 0.5 points, and three banks (BAWAG, ING and BNP Paribas) would drop below their minimum. If the banks keep earning profits, none would.

**[Open the website](https://agrawallachanchal.github.io/eba-credit-risk-analytics/)**: charts, the 40 questions asked of the data (run live in your browser), and a stress test you can adjust.

**[Read how the analysis works](https://agrawallachanchal.github.io/eba-credit-risk-analytics/blog/how-this-analysis-works.html)**: a method note covering the data, the model, the results and the limits.

![Stress test: how much capital cushion each bank keeps](screenshots/03_stress.png)

## What is in this repository

| Item | What it is |
|---|---|
| [`index.html`](index.html) | The website |
| [`blog/`](blog/) | The method note |
| [`EBA_stress_test_model.xlsx`](EBA_stress_test_model.xlsx) | The stress-test model in Excel. Change the yellow cells on the `Assumptions` sheet to try other scenarios. |
| [`details/`](details/) | For analysts: the SQL, the full methodology, and the data |

## A few terms

- **Non-performing exposure (NPE):** a loan the borrower is unlikely to repay in full.
- **CET1:** a bank's highest-quality capital, the first buffer against losses.
- **Headroom:** how far a bank's CET1 is above the minimum its supervisor requires. Below the minimum, a bank is restricted from paying dividends and bonuses.
- **Percentage point (pp):** a difference between two percentages. Going from 3.8% to 0.5% is a fall of 3.3 pp.

## Source and limits

Data: European Banking Authority, EU-wide Transparency Exercise 2025 (30 June 2025), reproduced with acknowledgement under the EBA [legal notice](https://eba.europa.eu/legal-notice). Scenario: ECB, *2025 stress test of euro area banks: final results*.

The model covers credit losses only and uses one shock for all banks, so it is a partial view, not a forecast. Educational analysis of public data. Not investment advice.

Chanchal Agrawalla · [GitHub](https://github.com/agrawallachanchal) · [MIT licence](LICENSE) for code and documentation. EBA data remain subject to the EBA's terms.
