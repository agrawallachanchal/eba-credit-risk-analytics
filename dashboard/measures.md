# DAX measures

Create these in a measures table (Home → Enter data → name it `_Measures`, then delete the dummy column). Formats are given after each measure. Table and column names match the CSV files in [`data/processed/`](../data/processed/).

## Page 1: Where the exposure is

```dax
Original Exposure =
SUM ( bank_exposure[original_exposure] )
-- Format: #,0 ; display units: billions (EUR bn)
```

```dax
Original Exposure EUR tn =
DIVIDE ( [Original Exposure], 1000000 )
-- Format: 0.0 (card shows EUR trillions)
```

```dax
Country Share of Exposure =
DIVIDE (
    [Original Exposure],
    CALCULATE ( [Original Exposure], REMOVEFILTERS ( countries ) )
)
-- Format: percentage, 1 decimal
```

```dax
Sector Gross Carrying Amount =
SUM ( sector[gross_carrying_amount] )
-- Format: #,0 ; display units: billions
```

```dax
Sector Share of Exposure =
DIVIDE (
    [Sector Gross Carrying Amount],
    CALCULATE ( [Sector Gross Carrying Amount], REMOVEFILTERS ( sector ) )
)
-- Format: percentage, 1 decimal
```

```dax
Top 20 Bank Share =
-- Named banks only: excludes the EBA "All other banks" aggregate
VAR Total = CALCULATE ( [Original Exposure], bank_exposure[is_named_bank] = TRUE () )
VAR Top20 =
    TOPN (
        20,
        CALCULATETABLE ( VALUES ( bank_exposure[lei_code] ), bank_exposure[is_named_bank] = TRUE () ),
        CALCULATE ( [Original Exposure] )
    )
RETURN
    DIVIDE ( SUMX ( Top20, CALCULATE ( [Original Exposure] ) ), Total )
-- Format: percentage, 1 decimal
```

```dax
Banks Holding Half of Exposure =
-- Named banks only: excludes the EBA "All other banks" aggregate
VAR Total = CALCULATE ( [Original Exposure], bank_exposure[is_named_bank] = TRUE () )
VAR ByBank =
    ADDCOLUMNS (
        CALCULATETABLE ( VALUES ( bank_exposure[lei_code] ), bank_exposure[is_named_bank] = TRUE () ),
        "@exp", CALCULATE ( [Original Exposure] )
    )
VAR WithRunningTotal =
    ADDCOLUMNS (
        ByBank,
        "@before",
            VAR ThisBank = [@exp]
            RETURN SUMX ( FILTER ( ByBank, [@exp] > ThisBank ), [@exp] )
    )
RETURN
    COUNTROWS ( FILTER ( WithRunningTotal, [@before] < Total / 2 ) )
-- Counts the banks, largest first, needed to reach half of total exposure. Format: whole number
```

```dax
HHI by Bank =
-- Named banks only: excludes the EBA "All other banks" aggregate
VAR Total =
    CALCULATE ( [Original Exposure], REMOVEFILTERS ( bank_exposure ), bank_exposure[is_named_bank] = TRUE () )
RETURN
    SUMX (
        CALCULATETABLE ( VALUES ( bank_exposure[lei_code] ), bank_exposure[is_named_bank] = TRUE () ),
        POWER ( DIVIDE ( CALCULATE ( [Original Exposure] ), Total ) * 100, 2 )
    )
-- Format: #,0
```

```dax
HHI by Country =
VAR Total = CALCULATE ( [Original Exposure], REMOVEFILTERS ( bank_exposure ) )
RETURN
    SUMX (
        VALUES ( bank_exposure[country_code] ),
        POWER ( DIVIDE ( CALCULATE ( [Original Exposure] ), Total ) * 100, 2 )
    )
-- Format: #,0
```

```dax
HHI by Sector =
VAR Total = CALCULATE ( [Sector Gross Carrying Amount], REMOVEFILTERS ( sector ) )
RETURN
    SUMX (
        VALUES ( sector[nace_code] ),
        POWER ( DIVIDE ( CALCULATE ( [Sector Gross Carrying Amount] ), Total ) * 100, 2 )
    )
-- Format: #,0
```

## Page 2: Where the risk is

```dax
Sector NPE Rate =
DIVIDE ( SUM ( sector[non_performing] ), SUM ( sector[gross_carrying_amount] ) )
-- Format: percentage, 1 decimal
```

```dax
Sector Impairment Ratio =
DIVIDE ( SUM ( sector[accumulated_impairment] ), SUM ( sector[gross_carrying_amount] ) )
-- Format: percentage, 1 decimal
```

```dax
Country NPE Ratio =
DIVIDE (
    SUM ( country_asset_quality[non_performing] ),
    SUM ( country_asset_quality[performing] ) + SUM ( country_asset_quality[non_performing] )
)
-- Format: percentage, 2 decimals
```

```dax
NPE Coverage =
DIVIDE ( SUM ( country_asset_quality[npe_provisions] ), SUM ( country_asset_quality[non_performing] ) )
-- Format: percentage, 1 decimal
```

```dax
NPE Ratio Trend =
DIVIDE (
    SUM ( npe_trend[non_performing] ),
    SUM ( npe_trend[performing] ) + SUM ( npe_trend[non_performing] )
)
-- Format: percentage, 2 decimals
```

## Page 3: Can capital absorb the shock?

These measures assume one scenario and one view are selected in slicers (single select).

```dax
Headroom After Shock =
SUM ( stress_results[headroom] )
-- Format: percentage, 2 decimals (read as pp of RWA)
```

```dax
Headroom Today =
MAX ( stress_results[headroom_today] )
-- Format: percentage, 2 decimals
```

```dax
Stressed CET1 Ratio =
SUM ( stress_results[stressed_cet1_ratio] )
-- Format: percentage, 2 decimals
```

```dax
Core Banks Below Requirement =
CALCULATE (
    DISTINCTCOUNT ( stress_results[lei_code] ),
    stress_results[role] = "Core",
    stress_results[below_requirement] = "Yes"
) + 0
-- Format: whole number
```

```dax
Median Headroom Core =
CALCULATE (
    MEDIAN ( stress_results[headroom] ),
    stress_results[role] = "Core"
)
-- Format: percentage, 2 decimals
```

```dax
Median Headroom Today Core =
CALCULATE (
    MEDIAN ( stress_results[headroom_today] ),
    stress_results[role] = "Core",
    stress_results[view] = "Instant loss"
)
-- Format: percentage, 2 decimals
```

```dax
Headroom Colour =
IF ( [Headroom After Shock] < 0, "#B42318", IF ( [Headroom After Shock] < 0.01, "#D97706", "#1F3A4D" ) )
-- Used for conditional formatting of bar colour (Format → Bars → fx → Field value)
```
