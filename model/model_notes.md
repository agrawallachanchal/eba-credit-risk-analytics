# Stress model: notes

`EBA_stress_test_model.xlsx` measures each bank's CET1 headroom to its own CET1 requirement after an NPE shock taken from the ECB 2025 stress test. The method is in [docs/02_methodology.md](../docs/02_methodology.md) and the assumptions in [docs/03_assumptions_register.md](../docs/03_assumptions_register.md).

## Sheets

| Sheet | Content |
|---|---|
| Cover | Purpose, data, units, colour code, scope |
| Assumptions | A1–A19 with values and sources; scenario table S1–S4 |
| Requirements | CET1 requirement per bank, with components, date and source URL |
| Bank Inputs | Output of `sql/08_model_inputs/q33_stress_model_inputs.sql`, plus derived ratios and today's headroom |
| Stress | Four scenario blocks. Columns F–K are the headline (instant loss absorption); columns L–S are the earnings layer |
| Summary | Headroom by bank and scenario for both views; medians, minimums and breach counts for the core banks |
| Sensitivity | 3-year adverse headroom with the shock ±0.3 pp, coverage ±10 pp and payout 0% / 50% |
| Notes | Method and limitations L1–L10 |

## Colour code

Blue text = input or source data · black = formula · green = link to another sheet · yellow fill = key lever.

## Updating the model

1. To change a scenario or rule, edit the yellow cells on `Assumptions` (or the steps on `Sensitivity`).
2. To refresh the data, run `q33_stress_model_inputs.sql` for the new period and paste the values into `Bank Inputs` columns A–K, N and O, keeping the row order.
3. To update a requirement, edit `Requirements` column C and its source, and the same row in `inputs/cet1_requirements.csv`.

The workbook has no macros and no external links; all results recalculate from the inputs.

## Headline results (30 June 2025 data)

| Core banks | Today | S1 | S2 | S3 | S4 |
|---|---|---|---|---|---|
| Median headroom, instant loss (pp) | 3.78 | 3.15 | 2.83 | 1.89 | 0.54 |
| Below requirement | 0 | 0 | 0 | 0 | 3 |
| Median headroom, with earnings (pp) | 3.78 | 4.70 | 4.55 | 7.15 | 6.72 |
