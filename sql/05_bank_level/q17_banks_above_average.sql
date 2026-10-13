-- Q17 | Which banks have exposure above the overall average?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502, 2520522, 2520532
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
    select item, sum(total) as total, sum(total) / count(distinct lei_code) as avg
    from bybank
    group by item
)
select bybank.item, lei_code, name, byitem.avg, bybank.total
from bybank
inner join byitem on byitem.item = bybank.item
where bybank.total >= byitem.avg
order by bybank.item, byitem.avg desc;
