-- Q18 | Which banks cumulatively account for 50% of total exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502, 2520522, 2520532
-- Note: Roughly 10-12 banks (out of ~120) account for half of total reported exposure, across all
-- three anchor items — confirming the concentration pattern already seen in Q8, now found
-- independently using a running total instead of a fixed top-20 cutoff.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.

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
