# Limitations and model risk

## Limitations

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

## Model risk assessment

| Risk | Description | Control |
|---|---|---|
| Data | Wrong item, wrong breakdown or double counting | Item codes checked against labels and templates; duplicate-total rules documented; CET1 ratio recomputed from CET1 ÷ RWA for every bank; four banks' ratios matched to Pillar 3. |
| Specification | The model answers a narrower question than a supervisory stress test | Question stated as "can today's capital absorb the shock"; limitations listed with direction of bias. |
| Parameter | Shocks, coverage and payout are uncertain | Every parameter sourced in the assumptions register; sensitivity on the three that matter. |
| Implementation | Spreadsheet formula errors | Live formulas only, no pasted results; independent recalculation outside Excel matched to within 1e-15; in-workbook check cells. |
| Use | Results read as a forecast or as investment advice | Scope note on the cover sheet and in every summary document. |
