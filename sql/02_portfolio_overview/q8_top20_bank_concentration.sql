-- Q8 | What % of total exposure do the top 20 banks represent? (concentration risk)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: Top 20 banks' Original Exposure as a % of total portfolio. Built using CTEs: bank-level
-- totals, top-20 sum, grand total, then divided.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).

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
