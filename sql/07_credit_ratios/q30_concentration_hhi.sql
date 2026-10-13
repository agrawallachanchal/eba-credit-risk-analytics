-- Q30 | How concentrated is exposure by bank, by country and by sector? (Herfindahl-Hirschman index)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502 (banks, countries), 2521301 (sectors)
-- HHI = sum of squared percentage shares, 0 to 10,000. Common reading: under 1,500 unconcentrated, above 2,500 highly concentrated.
-- Also reports the effective number of equal-sized units (10,000 / HHI).
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).

with bank as (
    select 'bank' as dimension, lei_code as unit, sum(amount) as amt
    from credit where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX' group by lei_code
),
country as (
    select 'country', nsa, sum(amount)
    from credit where period = '202506' and item = '2520502' and country = 0 group by nsa
),
sector as (
    select 'sector', nace_codes::text, sum(amount)
    from credit where period = '202506' and item = '2521301' and pref_status = 0 and nace_codes != 0 group by nace_codes
),
unioned as (
    select * from bank union all select * from country union all select * from sector
),
shares as (
    select dimension, unit, amt, amt / sum(amt) over (partition by dimension) * 100 as share_pct
    from unioned
)
select dimension, count(*) as units,
       round(sum(share_pct * share_pct)::numeric, 0) as hhi,
       round((10000 / sum(share_pct * share_pct))::numeric, 1) as effective_units
from shares
group by dimension
order by dimension;
