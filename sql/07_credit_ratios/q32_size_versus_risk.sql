-- Q32 | Are the banks that drive exposure concentration also the ones with higher NPE ratios?
-- Period: 202506 (Jun 2025) | Item(s): 2520502 (exposure), 2520603 (loans, performing status 1 and 2)
-- Splits banks into the 11 largest (about half of all exposure, see Q18) and the rest, and compares
-- the pooled NPE ratio of each group. Also reports the correlation between log exposure size and bank NPE ratio.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).

with exposure as (
    select lei_code, sum(amount) as exposure
    from credit where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX' group by lei_code
),
loans as (
    select lei_code,
           sum(amount) as loans_gross,
           sum(case when pref_status = 2 then amount end) as npe
    from credit
    where period = '202506' and item = '2520603' and pref_status in (1, 2)
    group by lei_code
),
joined as (
    select exposure.lei_code, exposure.exposure, loans.loans_gross, loans.npe,
           row_number() over (order by exposure.exposure desc) as size_rank
    from exposure
    inner join loans on loans.lei_code = exposure.lei_code
    where loans.loans_gross > 0
)
select case when size_rank <= 11 then 'largest 11 banks' else 'other banks' end as bank_group,
       count(*) as banks,
       sum(npe) / sum(loans_gross) * 100 as pooled_npe_ratio_pct,
       avg(npe / loans_gross * 100) as simple_average_npe_ratio_pct
from joined
group by 1
union all
select 'correlation: ln(exposure) vs bank NPE ratio', count(*),
       corr(ln(exposure), npe / loans_gross), null
from joined;
