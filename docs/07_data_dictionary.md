# Data dictionary

## Tables

| Table | Source file | Rows | Grain |
|---|---|---|---|
| `credit` | `tr_cre.csv` | 648,951 | One value per bank × period × item × breakdown combination |
| `oth` | `tr_oth.csv` | 91,277 | One value per bank × period × item (capital, P&L, balance sheet) |
| `bank_metadata` | `TR_Metadata_Bankdetail.csv` | 120 | One row per bank (LEI) |
| `nace_metadata` | `TR_Metadata_nace.csv` | 20 | NACE sector codes 0–19 |
| `prefstatus_metadata` | `TR_Metadata_perfstatus.csv` | 12 | Performing-status codes |

View `metadata` is an alias of `bank_metadata`.

## Key columns

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

## Performing status (`pref_status`)

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

## NACE sectors (`nace_codes`)

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

## Items used

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
