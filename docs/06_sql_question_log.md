# SQL question log

Queries, results and findings for the EBA Credit Risk Analytics project (PostgreSQL). Every query is also stored as a file in [`sql/`](../sql/).

| | |
|---|---|
| **Data** | EBA Transparency Exercise 2025: credit risk (`tr_cre.csv` → table `credit`), other items (`tr_oth.csv` → `oth`) and bank metadata (`bank_metadata`), plus lookup tables `nace_metadata` and `prefstatus_metadata` |
| **Reference period** | 202506 (June 2025, latest available quarter) |
| **Units** | EUR millions, per EBA reporting convention. Checked against the published total assets of two banks (Santander, BBVA) |

**Structural rule.** The credit table combines several EBA report templates, identified by the `Sheet` column (STA, IRB, NPE, NACE, Forborne, Collateral). Each item code belongs to one template, and each template only reports certain breakdown dimensions (exposure class, NACE sector, performing status). A dimension is coded 0 outside the items built to report it, so check which items populate a dimension before grouping by it.

**Duplicate-total rule.** Where an item reports a breakdown, code 0 ("no breakdown") can hold the total of the other codes. For item 2521301 every bank-sector pair appears under Perf_Status 0 (total), 2, 4 and 5, so sector queries filter on `pref_status = 0`. For the exposure items 2520502, 2520522 and 2520532, `country` = 0 is the total and other country codes break the same exposure down by counterparty country, so exposure queries filter on `country = 0`.

_Question numbering follows the original working log; there is no Q15 (a retired draft)._

## Foundations

### Q1. List all distinct banks (LEI_Code, Name, Country) from the metadata table.

File: [`sql/01_data_quality/q1_list_banks.sql`](../sql/01_data_quality/q1_list_banks.sql)

```sql
select distinct metadata.lei_code, metadata.name, metadata.country,
       metadata.desc_country, credit.nsa
from metadata
inner join credit on metadata.lei_code = credit.lei_code;
```

Confirms the bank universe (name, country) the rest of the project is built on.

### Q2. Find LEI_Codes in credit that have no match in the metadata table (data quality check).

File: [`sql/01_data_quality/q2_unmatched_lei_codes.sql`](../sql/01_data_quality/q2_unmatched_lei_codes.sql)

```sql
select distinct c.lei_code
from credit as c
left join metadata as m on c.lei_code = m.lei_code
where m.lei_code is null;
```

Found two unmatched LEI_Codes. One was a genuine placeholder row (not a real bank). The other belonged to a real bank (Banco de Crédito Social Cooperativo, ES) whose LEI_Code had been corrupted in the metadata file — Excel had auto-converted the 20-digit code into scientific notation (9.598E+19). Verified the true value against the credit table and the bank's country/name, then corrected it with an UPDATE. Re-running the check afterward left only the genuine placeholder row.

### Q3. List the distinct Item/Label combinations available, and pick one to anchor the analysis on.

File: [`sql/01_data_quality/q3_item_label_catalogue.sql`](../sql/01_data_quality/q3_item_label_catalogue.sql)

```sql
select distinct item, label
from credit
order by item asc;
```

Found 89 distinct Item/Label combinations spanning several EBA templates. Chose three related items as the main anchors: 2520502 (Original Exposure), 2520522 (Exposure value), 2520532 (Risk exposure amount) — all 'by exposure class' versions. These were chosen because they exist in both the STA and IRB report types; the plain, non-broken-down totals only exist under STA and would silently exclude every IRB bank.

## Portfolio overview

### Q4. For the latest period, what is the total credit exposure across all banks, for each anchor item?

File: [`sql/02_portfolio_overview/q4_total_exposure_by_item.sql`](../sql/02_portfolio_overview/q4_total_exposure_by_item.sql)

```sql
select item, label, sum(amount) as total_credit_exposure
from credit
where period = '202506'
and item = '2520502' and country = 0
group by item, label;
```

Run once per item. The three measures are not additive: original exposure (before credit-risk mitigation and conversion factors) is larger than exposure value (after them), which is larger than the risk exposure amount (after risk weighting).

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. Totals at June 2025: original exposure EUR 31.3tn, exposure value EUR 26.3tn, risk exposure amount EUR 7.9tn.

### Q5. How many distinct banks reported each anchor item in the latest period?

File: [`sql/02_portfolio_overview/q5_reporting_banks_by_item.sql`](../sql/02_portfolio_overview/q5_reporting_banks_by_item.sql)

```sql
select count(distinct lei_code)
from credit
where period = '202506'
and item = '2520502' and lei_code <> 'XXXXXXXXXXXXXXXXXXXX';
```

The "All other banks" aggregate (LEI `XXXXXXXXXXXXXXXXXXXX`) is excluded from bank-level counts and rankings; it is not a single bank. 119 banks reported original exposure at June 2025.

### Q6. What is the average exposure per bank, for each anchor item?

File: [`sql/02_portfolio_overview/q6_average_exposure_per_bank.sql`](../sql/02_portfolio_overview/q6_average_exposure_per_bank.sql)

```sql
select item, label, sum(amount)/count(distinct lei_code) as avg_exposure_per_bank
from credit
where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX'
group by item, label;
```

The question can mean the average reported row or the average bank book; the second is used (total ÷ number of distinct banks). **Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. The "All other banks" aggregate (LEI `XXXXXXXXXXXXXXXXXXXX`) is excluded from bank-level counts and rankings; it is not a single bank. Average per bank: original exposure EUR 259bn, exposure value EUR 217bn, risk exposure amount EUR 65bn.

### Q7. What are the top 20 largest single exposure rows (bank + country + sector combination)?

File: [`sql/02_portfolio_overview/q7_top20_exposure_rows.sql`](../sql/02_portfolio_overview/q7_top20_exposure_rows.sql)

```sql
select metadata.name, credit.lei_code, credit.item, credit.exposure, credit.amount
from credit
inner join metadata on metadata.lei_code = credit.lei_code
where period = '202506' and item = '2520502' and credit.country = 0
order by amount desc
limit 20;
```

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. Each row is now one bank's exposure to one exposure class. The largest rows are BNP Paribas (EUR 865bn), Crédit Agricole (EUR 740bn) and ING (EUR 669bn); the top 20 rows belong to ten of the largest banking groups. A bank with a large book spread across many classes can be absent here, so this ranks concentrated positions, not bank size (Q8, Q18).

### Q8. What % of total exposure do the top 20 banks represent? (concentration risk)

File: [`sql/02_portfolio_overview/q8_top20_bank_concentration.sql`](../sql/02_portfolio_overview/q8_top20_bank_concentration.sql)

```sql
with exp_by_bank as (
    select lei_code, sum(amount) as total
    from credit
    where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX'
    group by lei_code
),
top20 as (
    select sum(total) as top20total
    from (
        select lei_code, total
        from exp_by_bank
        order by total desc
        limit 20
    ) as t
),
all_total as (
    select sum(total) as alltotal
    from exp_by_bank
)
select top20.top20total, all_total.alltotal,
       top20.top20total / all_total.alltotal * 100 as pertop20
from top20, all_total;
```

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. The "All other banks" aggregate (LEI `XXXXXXXXXXXXXXXXXXXX`) is excluded from bank-level counts and rankings; it is not a single bank. The top 20 banks hold 66.4% of original exposure held by named banks.

## Geographic analysis

### Q9. What is total exposure by NSA (bank home country)?

File: [`sql/03_geography/q9_exposure_by_country.sql`](../sql/03_geography/q9_exposure_by_country.sql)

```sql
select nsa, sum(amount) as total_exposure
from credit
where period = '202506' and item = '2520502' and country = 0
group by nsa;
```

### Q10. Which 10 countries have the largest exposures?

File: [`sql/03_geography/q10_top10_countries.sql`](../sql/03_geography/q10_top10_countries.sql)

```sql
select nsa, sum(amount) as total_exposure
from credit
where period = '202506' and item = '2520502' and country = 0
group by nsa
order by total_exposure desc
limit 10;
```

### Q11. Which countries account for more than 5% of total exposure?

File: [`sql/03_geography/q11_countries_over_5pct.sql`](../sql/03_geography/q11_countries_over_5pct.sql)

```sql
with exp_by_nsa as (
    select nsa, sum(amount) as total_exposure
    from credit
    where period = '202506' and item = '2520502' and country = 0
    group by nsa
)
select exp_by_nsa.nsa, exp_by_nsa.total_exposure
from exp_by_nsa
where exp_by_nsa.total_exposure > (
    select 0.05 * sum(total_exposure)
    from exp_by_nsa
);
```

### Q12. What % of total exposure does each country represent?

File: [`sql/03_geography/q12_country_share.sql`](../sql/03_geography/q12_country_share.sql)

```sql
with exp_by_nsa as (
    select nsa, sum(amount) as total_exposure
    from credit
    where period = '202506' and item = '2520502' and country = 0
    group by nsa
),
alltotal as (
    select sum(total_exposure) as alltotal
    from exp_by_nsa
)
select exp_by_nsa.nsa, exp_by_nsa.total_exposure,
       exp_by_nsa.total_exposure / alltotal.alltotal * 100 as per_exp
from exp_by_nsa, alltotal;
```

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. Shares by bank home country: France 28.9%, Germany 15.4%, Spain 13.7%, Italy 10.5%, Netherlands 9.2%. Five countries are above 5% (Q11) and together hold 77.7%.

## Sector analysis (NACE)

### Q13. What is total exposure by NACE sector code?

File: [`sql/04_sector_nace/q13_exposure_by_sector.sql`](../sql/04_sector_nace/q13_exposure_by_sector.sql)

```sql
select item, credit.label, credit.nace_codes, nace_metadata.label, sum(amount) as total_exposure
from credit
inner join nace_metadata on credit.nace_codes = nace_metadata.nace_codes
where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
group by item, credit.label, credit.nace_codes, nace_metadata.label
order by item;
```

Initial finding claimed nace_codes = 0 ('No breakdown') meant ~50% of exposure was unclassified. This was later found to be wrong — see the correction below.

### Q13a. Correction: is nace_codes = 0 really unclassified exposure?

File: [`sql/04_sector_nace/q13a_nace0_duplicate_total_check.sql`](../sql/04_sector_nace/q13a_nace0_duplicate_total_check.sql)

```sql
with bybank as (
    select item, nace_codes, lei_code, sum(amount) as totalnace0
    from credit
    where period = '202506' and item = '2521301' and nace_codes = '0'
    group by item, nace_codes, lei_code
),
bybanknace as (
    select item, lei_code, sum(amount) as totalallnace
    from credit
    where period = '202506' and item = '2521301' and nace_codes != '0'
    group by item, lei_code
)
select bybank.item, bybank.lei_code, totalnace0, totalallnace
from bybank
inner join bybanknace on bybank.item = bybanknace.item and bybank.lei_code = bybanknace.lei_code
order by bybank.item;
```

Checked each bank's nace_codes = 0 total against the sum of its 19 real sector rows — they matched almost exactly. This means nace_codes = 0 is a duplicate total, not unclassified exposure. Sector analysis should exclude nace_codes = 0. The original Q13 totals (using only the 19 real sectors) were correct all along.

### Q14. Which NACE sectors have the highest average exposure size?

File: [`sql/04_sector_nace/q14_average_exposure_by_sector.sql`](../sql/04_sector_nace/q14_average_exposure_by_sector.sql)

```sql
with bybankbysector as (
    select item, lei_code, credit.nace_codes, nace_metadata.label, sum(amount) as total
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, lei_code, credit.nace_codes, nace_metadata.label
),
bysector as (
    select item, nace_codes, label, sum(total) as total
    from bybankbysector
    group by item, nace_codes, label
)
select bysector.item, bysector.nace_codes, bysector.label, bysector.total,
       bysector.total / count(distinct bybankbysector.lei_code) as avgbysector
from bysector
inner join bybankbysector
    on bybankbysector.item = bysector.item and bybankbysector.nace_codes = bysector.nace_codes
group by bysector.item, bysector.nace_codes, bysector.label, bysector.total
order by bysector.item, avgbysector desc;
```

Average exposure size per sector closely tracks Q13's total-exposure ranking — Real Estate leads both, followed by Manufacturing and Wholesale/Retail Trade. No sector shows an unusually high average relative to its total rank, meaning exposure size scales fairly evenly with the number of reporting banks — no sign of a small group of banks making unusually large, concentrated bets in any one sector.

### Q13b. Within each NACE sector, what % of total exposure does each bank represent?

File: [`sql/04_sector_nace/q13b_bank_share_within_sector.sql`](../sql/04_sector_nace/q13b_bank_share_within_sector.sql)

```sql
with bybankbysector as (
    select item, lei_code, credit.nace_codes, nace_metadata.label, sum(amount) as total
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, lei_code, credit.nace_codes, nace_metadata.label
),
bysector as (
    select item, nace_codes, label, sum(total) as total
    from bybankbysector
    group by item, nace_codes, label
)
select bybankbysector.item, bybankbysector.lei_code, bybankbysector.nace_codes, bybankbysector.label,
       bybankbysector.total, bysector.total,
       bybankbysector.total / nullif(bysector.total, 0) * 100 as bybankbysectorconc
from bybankbysector
inner join bysector
    on bysector.item = bybankbysector.item and bysector.nace_codes = bybankbysector.nace_codes
order by bybankbysector.item, bybankbysector.nace_codes;
```

### Q16. Which sectors represent more than 10% of portfolio exposure?

File: [`sql/04_sector_nace/q16_sectors_over_10pct.sql`](../sql/04_sector_nace/q16_sectors_over_10pct.sql)

```sql
with bysector as (
    select item, credit.nace_codes, nace_metadata.label, sum(amount) as sectortotal
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, credit.nace_codes, nace_metadata.label
),
itemtotal as (
    select item, sum(sectortotal) as itemtotal
    from bysector
    group by item
)
select item, nace_codes, label, sectorconc
from (
    select bysector.item, nace_codes, label, sectortotal, itemtotal,
           sectortotal / itemtotal * 100 as sectorconc
    from bysector
    inner join itemtotal on itemtotal.item = bysector.item
) as t
where sectorconc >= 10;
```

Real Estate (25.5%), Manufacturing (15.1%) and Wholesale and retail trade (12.9%) each exceed 10% of gross carrying amount and together make up about 53% of the classified portfolio. Separately, Q16b shows Real Estate holds 47.1% of accumulated fair-value losses on non-performing exposure (item 2521303), against 25.5% of gross exposure.

### Q16b. Which sectors hold the largest share of fair-value losses on non-performing exposure?

File: [`sql/04_sector_nace/q16b_fair_value_losses_by_sector.sql`](../sql/04_sector_nace/q16b_fair_value_losses_by_sector.sql)

Added so the Real Estate finding above can be reproduced: item 2521303 is reported by sector only, with no status split. Real Estate: 47.1% of the total.

## Bank-level analysis

### Q17. Which banks have exposure above the overall average?

File: [`sql/05_bank_level/q17_banks_above_average.sql`](../sql/05_bank_level/q17_banks_above_average.sql)

```sql
with bybank as (
    select item, credit.lei_code, name, sum(amount) as total
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    where period = '202506' and item in ('2520502', '2520522', '2520532') and credit.country = 0
    group by item, credit.lei_code, name
),
byitem as (
    select item, sum(total) as total, sum(total) / count(distinct lei_code) as avg
    from bybank
    group by item
)
select bybank.item, lei_code, name, byitem.avg, bybank.total
from bybank
inner join byitem on byitem.item = bybank.item
where bybank.total >= byitem.avg
order by bybank.item, byitem.avg desc;
```

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. Banks above the average: 27 for original exposure, 28 for exposure value and 28 for risk exposure amount, out of 119.

### Q18. Which banks cumulatively account for 50% of total exposure?

File: [`sql/05_bank_level/q18_banks_for_50pct_of_exposure.sql`](../sql/05_bank_level/q18_banks_for_50pct_of_exposure.sql)

```sql
with bybank as (
    select item, credit.lei_code, name, sum(amount) as total
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    where period = '202506' and item in ('2520502', '2520522', '2520532') and credit.country = 0
    group by item, credit.lei_code, name
),
byitem as (
    select item, sum(total) as total, sum(total) / 2 as half
    from bybank
    group by item
),
byrunningsum as (
    select bybank.item, lei_code, name, bybank.total, half,
           sum(bybank.total) over (partition by bybank.item order by bybank.total desc) as running_sum
    from bybank
    inner join byitem on byitem.item = bybank.item
    group by bybank.item, lei_code, name, bybank.total, half
),
byrn as (
    select *, row_number() over (partition by item order by running_sum) as rn
    from byrunningsum
    where running_sum >= half
),
byrn1 as (
    select item, running_sum
    from byrn
    where rn = 1
)
select byrunningsum.item, lei_code, name, total, half, byrunningsum.running_sum
from byrunningsum
join byrn1 on byrn1.item = byrunningsum.item
where byrunningsum.running_sum <= byrn1.running_sum;
```

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. Half of total exposure is held by 11 banks on original exposure, 13 on exposure value and 11 on risk exposure amount, out of 119. This confirms the concentration in Q8 by a different method (running total instead of a fixed top 20).

### Q19. Distribution of banks by exposure-size bucket (<€1bn, €1–10bn, €10–100bn, €100bn–1tri, >1tri).

File: [`sql/05_bank_level/q19_exposure_size_buckets.sql`](../sql/05_bank_level/q19_exposure_size_buckets.sql)

```sql
with bybank as (
    select item, credit.lei_code, name, sum(amount) as total
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    where period = '202506' and item in ('2520502', '2520522', '2520532') and credit.country = 0
    group by item, credit.lei_code, name
),
bybucket as (
    select item, lei_code, name, total,
        case
            when total < 1000 then '< 1bn'
            when total < 10000 then '1bn to <10 bn'
            when total < 100000 then '10 bn to <100 bn'
            when total < 1000000 then '100 bn to <1 tri'
            else '>= 1 tri'
        end as exposure_bucket
    from bybank
)
select item, exposure_bucket, count(lei_code) as count
from bybucket
group by item, exposure_bucket
order by item,
    case exposure_bucket
        when '< 1bn' then 1
        when '1bn to <10 bn' then 2
        when '10 bn to <100 bn' then 3
        when '100 bn to <1 tri' then 4
        when '>= 1 tri' then 5
    end;
```

**Correction (country totals).** Items 2520502, 2520522 and 2520532 report a total row per bank and exposure class (counterparty `country` = 0) and, for banks on the full template, a second breakdown of the same exposure by their top counterparty countries. Summing every row counted that exposure about twice. The query now keeps `country = 0`. Original exposure: 3 banks below EUR 10bn, 62 between EUR 10bn and 100bn, 45 between EUR 100bn and 1tn, and 9 above EUR 1tn.

## Performing and non-performing (asset quality)

### Q20. What is total exposure split by Perf_Status (performing vs non-performing), including the full sub-category breakdown?

File: [`sql/06_asset_quality/q20_perf_status_split.sql`](../sql/06_asset_quality/q20_perf_status_split.sql)

```sql
select item, credit.label, credit.pref_status, prefstatus_metadata.label, sum(amount) as total_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label;
```

Of the 7 non-zero codes returned, only 1 (Performing) and 2 (Non Performing) are the true top-level, non-overlapping split. Codes 3, 4, 12, 23, and 222 are sub-categories nested inside 1 or 2 — summing all 7 together would double-count. Full breakdown shown for detail; the clean total is 1 + 2 only. Two related items (2520605, by exposure class; 2521301, the NACE item) were checked and found to be different, non-substitutable scopes — 2521301 turned out to be the better anchor for the sector-level breakdown in Q22.

### Q20b. Same breakdown, by country.

File: [`sql/06_asset_quality/q20b_perf_status_by_country.sql`](../sql/06_asset_quality/q20b_perf_status_by_country.sql)

```sql
select item, credit.label, credit.pref_status, prefstatus_metadata.label, nsa, sum(amount) as total_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status != 0
group by item, credit.label, nsa, credit.pref_status, prefstatus_metadata.label
order by credit.pref_status asc, total_exposure desc;
```

### Q21. Which NSA country has the highest non-performing exposure amount?

File: [`sql/06_asset_quality/q21_country_highest_npe.sql`](../sql/06_asset_quality/q21_country_highest_npe.sql)

```sql
select item, credit.label, credit.pref_status, prefstatus_metadata.label, nsa, sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status = 2
group by item, credit.label, nsa, credit.pref_status, prefstatus_metadata.label
order by highest_exposure desc
limit 1;
```

### Q22. What is non-performing exposure by sector, including all Perf_Status sub-categories?

File: [`sql/06_asset_quality/q22_npe_by_sector_all_statuses.sql`](../sql/06_asset_quality/q22_npe_by_sector_all_statuses.sql)

```sql
select item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label,
       sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
where period = '202506' and item = '2521301' and credit.pref_status != 0 and credit.nace_codes != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label
order by credit.pref_status asc, credit.nace_codes asc, highest_exposure desc;
```

### Q22a. Which NACE sectors carry the largest non-performing exposure amount?

File: [`sql/06_asset_quality/q22a_npe_amount_by_sector.sql`](../sql/06_asset_quality/q22a_npe_amount_by_sector.sql)

```sql
select item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label,
       sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
where period = '202506' and item = '2521301' and credit.pref_status = 2 and credit.nace_codes != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label
order by highest_exposure desc;
```

### Q22b. Which NACE sectors have the highest non-performing exposure rate (non-performing ÷ sector total), rather than the highest raw amount?

File: [`sql/06_asset_quality/q22b_npe_rate_by_sector.sql`](../sql/06_asset_quality/q22b_npe_rate_by_sector.sql)

```sql
with sector_total as (
    select credit.nace_codes, nace_metadata.label, sum(amount) as total_pref_status
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0'
      and credit.pref_status = 0
    group by credit.nace_codes, nace_metadata.label
),
sector_npe as (
    select nace_codes, sum(amount) as total_pref_status2
    from credit
    where period = '202506' and item = '2521301' and nace_codes != '0' and pref_status = '2'
    group by nace_codes
)
select sector_total.nace_codes, sector_total.label, sector_total.total_pref_status, sector_npe.total_pref_status2,
       sector_npe.total_pref_status2 / sector_total.total_pref_status * 100 as npe_rate_pct
from sector_total
inner join sector_npe on sector_npe.nace_codes = sector_total.nace_codes
order by npe_rate_pct desc;
```

Ranking sectors by non-performing rate gives a different picture from Q22a. Construction has the highest NPE rate (6.4%), followed by Accommodation and food service (5.6%) and Wholesale and retail trade (4.2%). Real Estate is 2.8%, despite having the largest absolute non-performing amount (EUR 46.0bn). Real Estate's top position in Q22a mainly reflects its size, not a higher risk per loan.

### Q23. What % of total portfolio exposure is non-performing vs performing? (board-level KPI)

File: [`sql/06_asset_quality/q23_portfolio_npe_ratio.sql`](../sql/06_asset_quality/q23_portfolio_npe_ratio.sql)

```sql
with by_prefstatus as (
    select item, credit.pref_status, prefstatus_metadata.label, sum(amount) as total
    from credit
    inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
    where period = '202506' and item = '2520603' and credit.pref_status in ('1', '2')
    group by item, credit.pref_status, prefstatus_metadata.label
),
total as (
    select item, sum(total) as total_exposure
    from by_prefstatus
    group by item
)
select by_prefstatus.item, pref_status, label, total, total_exposure,
       total / total_exposure * 100 as exp_pct
from by_prefstatus
inner join total on total.item = by_prefstatus.item;
```

Non-performing ratio = 2.14% of total exposure (Performing + Non Performing, codes 1+2 only). This is consistent with typical EU bank NPL ratios (roughly 1-3%), confirming the calculation is realistic.

## Model inputs (Layer 3: capital and scenario preparation)

### Q24. What is each bank's non-performing exposure ratio?

File: [`sql/08_model_inputs/q24_bank_npe_ratio.sql`](../sql/08_model_inputs/q24_bank_npe_ratio.sql)

```sql
with bybank as (
    select item, credit.pref_status, prefstatus_metadata.label, credit.lei_code, bank_metadata.name, sum(amount) as bankwise
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
    where period = '202506' and item = '2520603' and credit.pref_status in ('1', '2')
    group by item, credit.pref_status, prefstatus_metadata.label, credit.lei_code, bank_metadata.name
),
total as (
    select item, lei_code, sum(bankwise) as total
    from bybank
    group by item, lei_code
)
select bybank.item, pref_status, label, bybank.lei_code, name, bankwise, total, ((bankwise / total) * 100) as bank_np_pct
from bybank
inner join total on total.item = bybank.item and total.lei_code = bybank.lei_code
where pref_status = 2
order by bank_np_pct desc;
```

Bank-level version of Q23 (item 2520603: non-performing ÷ performing + non-performing).

### Q25. What is each bank's current CET1 capital ratio?

File: [`sql/08_model_inputs/q25_bank_cet1_ratio.sql`](../sql/08_model_inputs/q25_bank_cet1_ratio.sql)

```sql
select item, label, oth.lei_code, bank_metadata.name, amount
from oth
inner join bank_metadata on bank_metadata.lei_code = oth.lei_code
where period = '202506' and item = '2520140'
order by amount;
```

Item 2520140. Amount is not in one unit across the `oth` table: capital and P&L items are EUR millions, ratio items are decimals (0.13 = 13%). Very high values (Kommuninvest ~352%, Kuntarahoitus ~89%) belong to municipal funding agencies with near-zero risk-weighted assets and are genuine.

### Q26. Reference table: total assets, NPE ratio and CET1 ratio per bank

File: [`sql/08_model_inputs/q26_bank_shortlist.sql`](../sql/08_model_inputs/q26_bank_shortlist.sql)

```sql
with t as (
    select distinct oth.item, oth.label, oth.lei_code, bank_metadata.name
    from oth
    inner join bank_metadata on bank_metadata.lei_code = oth.lei_code
    where period = '202506' and item in ('2521010')
),
exposure as (
    select item, lei_code, sum(amount) as exp_total
    from oth
    where period = '202506' and item = '2521010'
    group by item, lei_code
),
prefstatus as (
    select lei_code, sum(amount) as exp_prefstatus
    from credit
    where period = '202506' and item = '2520603' and pref_status in ('1', '2')
    group by lei_code
),
npe as (
    select lei_code, sum(amount) as npe
    from credit
    where period = '202506' and item = '2520603' and pref_status = 2
    group by lei_code
),
nperatio as (
    select npe.lei_code, ((npe / exp_prefstatus) * 100) as nperatio
    from npe
    inner join prefstatus on prefstatus.lei_code = npe.lei_code
),
cet1 as (
    select lei_code, amount as cet1ratio
    from oth
    where period = '202506' and item = '2520140'
)
select t.item, label, t.lei_code, name, exp_total, nperatio, cet1ratio
from t
inner join exposure on exposure.item = t.item and exposure.lei_code = t.lei_code
inner join nperatio on nperatio.lei_code = t.lei_code
inner join cet1 on cet1.lei_code = t.lei_code
order by t.item, name;
```

Combines Q24, Q25 and total assets (item 2521010). Used to shortlist banks for the stress test.

### Q26B. Provision coverage of performing and non-performing loans

File: [`sql/08_model_inputs/q26b_npe_coverage_ratio.sql`](../sql/08_model_inputs/q26b_npe_coverage_ratio.sql)

```sql
with c as (
    select item, pref_status, lei_code, amount
    from credit
    where period = '202506' and item in ('2520603', '2520613') and pref_status in ('1', '2')
),
t as (
    select lei_code,
           sum(case when item = '2520603' and pref_status = 1 then amount else 0 end) as gross_p,
           sum(case when item = '2520613' and pref_status = 1 then amount else 0 end) as provision_p,
           sum(case when item = '2520603' and pref_status = 2 then amount else 0 end) as gross_np,
           sum(case when item = '2520613' and pref_status = 2 then amount else 0 end) as provision_np
    from c
    group by lei_code
)
select t.lei_code, gross_p, provision_p, round((provision_p / nullif(gross_p, 0)) * 100, 3) as coverage_p,
       gross_np, provision_np, round((provision_np / nullif(gross_np, 0)) * 100, 3) as coverage_np
from t;
```

Items 2520603 (gross carrying amount) and 2520613 (impairment and provisions). Coverage = provisions ÷ gross.

### Q26C. CET1 capital and total risk exposure amount

File: [`sql/08_model_inputs/q26c_cet1_capital_and_rwa.sql`](../sql/08_model_inputs/q26c_cet1_capital_and_rwa.sql)

```sql
select item, label, lei_code, amount
from oth
where period = '202506' and item in ('2520102', '2520138')
order by item;
```

Items 2520102 and 2520138, the capital inputs of the stress-test model.

### Q33. One row per stress-model bank with every model input

File: [`sql/08_model_inputs/q33_stress_model_inputs.sql`](../sql/08_model_inputs/q33_stress_model_inputs.sql)

Pulls, for the 12 banks on the model's input sheet, total assets, RWA, CET1 capital and ratio, gross performing and non-performing loans, provisions on non-performing loans, and half-year profit before and after tax. The output is pasted as values into the `Bank Inputs` sheet of `model/EBA_stress_test_model.xlsx`; the sheet's CET1 ratio check column (CET1 capital ÷ RWA) reproduces the reported ratio for every bank.

## Credit ratios, concentration and trend

These queries use the same period (202506) and conventions as above. Files are in [`sql/07_credit_ratios/`](../sql/07_credit_ratios/).

### Q27. Impairment ratio by sector

File: [`sql/07_credit_ratios/q27_impairment_ratio_by_sector.sql`](../sql/07_credit_ratios/q27_impairment_ratio_by_sector.sql)

Accumulated impairment (2521302) divided by gross carrying amount (2521301, Perf_Status 0). Construction has the highest ratio (4.1%), followed by Accommodation and food service (3.5%) and Wholesale and retail trade (2.8%). Real Estate is 1.4%. The NACE template does not split impairment by performing status, so a sector NPE coverage ratio cannot be built from it. Construction is highest on both the NPE rate (Q22b) and the impairment ratio.

### Q28. NPE coverage by bank home country

File: [`sql/07_credit_ratios/q28_npe_coverage_by_country.sql`](../sql/07_credit_ratios/q28_npe_coverage_by_country.sql)

Provisions on non-performing loans (2520613) divided by gross non-performing loans (2520603), Perf_Status 2, as a ratio of sums. Among the large markets: Italy 52.1%, Spain 45.5%, France 44.4%, Germany 35.0%, Netherlands 24.2%. Across all 26 countries the range runs from 19.6% (Estonia) to 61.3% (Hungary). Low coverage combined with a large NPE stock means more capital impact when NPEs rise, which is the mechanism the stress-test model captures.

### Q29. RWA density by bank

File: [`sql/07_credit_ratios/q29_rwa_density_by_bank.sql`](../sql/07_credit_ratios/q29_rwa_density_by_bank.sql)

Credit-risk risk exposure amount (2520532) divided by exposure value (2520522), country-total rows only (see the correction in Q4). Median 31.2% across 119 banks. Highest: Bpifrance 76.3% and Volkswagen Financial Services 74.5%. Public-sector funding agencies are near zero (Kommuninvest 0.04%), because their lending is government-backed. Examples among the stress-model banks: Santander 33.9%, BNP Paribas 35.4%, BAWAG 28.8%, CEC Bank 23.5%.

### Q30. Concentration (Herfindahl-Hirschman index)

File: [`sql/07_credit_ratios/q30_concentration_hhi.sql`](../sql/07_credit_ratios/q30_concentration_hhi.sql)

| Dimension | Units | HHI | Effective number of equal-sized units |
|---|---|---|---|
| Bank | 119 | 302 | 33.1 |
| Country | 26 | 1,501 | 6.7 |
| Sector | 19 | 1,234 | 8.1 |

By bank (excluding the "All other banks" aggregate), exposure is not concentrated in the HHI sense, even though 11 banks hold half of it (Q18), because the large banks are similar in size. Exposure uses country-total rows only (correction in Q4). By country it sits at the edge of the "unconcentrated" band (HHI 1,500), with an effective 6.7 countries behind 26.

### Q31. Trend across the four periods

File: [`sql/07_credit_ratios/q31_trend_across_periods.sql`](../sql/07_credit_ratios/q31_trend_across_periods.sql)

| Period | Banks reporting | Top-20 share | NPE ratio |
|---|---|---|---|
| 2024-09 | 115 | 67.9% | 2.24% |
| 2024-12 | 119 | 67.2% | 2.21% |
| 2025-03 | 110 | 69.0% | 2.17% |
| 2025-06 | 119 | 66.4% | 2.14% |

The NPE ratio falls in every period. The top-20 share moves with the number of banks reporting (it is highest in the period with the fewest banks), so it is not read as a trend.

### Q32. Size versus risk

File: [`sql/07_credit_ratios/q32_size_versus_risk.sql`](../sql/07_credit_ratios/q32_size_versus_risk.sql)

The 11 largest banks have a pooled NPE ratio of 2.47%, against 1.81% for the other 96 banks. Across individual banks, the correlation between log exposure size and NPE ratio is close to zero (−0.03). The higher pooled figure for the largest banks comes from a few large banks with high NPE ratios, not from a general link between size and risk.

## Validation notes

**Exposure versus bank disclosures.** Before the country-total correction (Q4), Crédit Agricole's exposure value summed to EUR 3.80tn against about EUR 2.17–2.19tn in the bank's own leverage exposure measure. With country-total rows only it is EUR 1.98tn, in line with the bank's figure once off-balance-sheet conversion and items outside credit risk are allowed for. The gap was the double count, which this check exposed.

**NPE ratio versus bank-reported NPL ratios.** Santander 3.35% (EBA data) against 2.92% (reported); BNP Paribas 2.79% against 1.6%. The EBA definition of non-performing exposure is deliberately broader than NPL: it includes "unlikely to pay" exposures regardless of days past due, not only loans more than 90 days past due. This is a definitional difference, not a data or query error.

**Kommuninvest.** It reports zero non-performing exposure at June 2025, so its coverage ratio is undefined (0 ÷ 0). It lends only to Swedish municipalities and regions, so a commercial-loan NPE shock does not apply to it; the stress model keeps it as a reference row and excludes it from the stress run (assumption A16).

## Overall findings

- Exposure is concentrated: 11–13 of 119 banks hold half of all reported credit exposure, depending on the measure, and the top 20 hold 66.4% (Q8, Q18).
- Real Estate, Manufacturing and Wholesale and retail trade are the three largest sectors by gross carrying amount, about 53% of the classified portfolio together (Q13, Q16).
- Real Estate holds 47.1% of fair-value losses on non-performing exposure against 25.5% of gross exposure (Q16b).
- Construction has the highest sector NPE rate (6.4%), more than twice Real Estate's (2.8%), although Real Estate has the larger absolute amount (Q22a against Q22b).
- The portfolio NPE ratio is 2.14% (non-performing ÷ performing + non-performing, loans and advances; Q23).
- Three source-data issues were found and resolved: a bank LEI code corrupted by scientific-notation formatting (Q2); code-0 duplicate totals in the NACE and Perf_Status breakdowns (Q13a, Q13, Q16, Q22b); and a counterparty-country breakdown stored alongside country totals in the exposure items (Q4 and the queries that use them).
- Construction is the weakest sector on both measures: highest NPE rate (6.4%, Q22b) and highest impairment ratio (4.1%, Q27).
- The NPE ratio falls in each of the four periods, from 2.24% to 2.14% (Q31). Country concentration is moderate (HHI 1,501) and bank concentration low (HHI 302) (Q30).
- Items with similar labels (for example three different "Gross carrying amount on loans and advances" items) cover different scopes and must not be substituted for one another.
