-- Q31 | Are concentration and the NPE ratio rising or falling across the four reporting periods?
-- Periods: 202409, 202412, 202503, 202506 | Units: EUR mn | Item(s): 2520502, 2520603
-- The number of banks reporting differs by period (116, 120, 111, 120), so period-to-period changes mix real movement with sample changes.
-- A like-for-like comparison would restrict to banks reporting in all four periods.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).

with exposure as (
    select period, lei_code, sum(amount) as amt
    from credit where item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX' group by period, lei_code
),
ranked as (
    select period, lei_code, amt, row_number() over (partition by period order by amt desc) as rn
    from exposure
),
concentration as (
    select period, count(*) as banks_reporting, sum(amt) as total_exposure,
           sum(case when rn <= 20 then amt end) / sum(amt) * 100 as top20_share_pct
    from ranked group by period
),
npe as (
    select period,
           sum(case when pref_status = 2 then amount end) / sum(amount) * 100 as npe_ratio_pct
    from credit
    where item = '2520603' and pref_status in (1, 2)
    group by period
)
select concentration.period, banks_reporting, total_exposure, top20_share_pct, npe.npe_ratio_pct
from concentration
inner join npe on npe.period = concentration.period
order by concentration.period;
