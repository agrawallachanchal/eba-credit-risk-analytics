-- Q19 | Distribution of banks by exposure-size bucket (<€1bn, €1–10bn, €10–100bn, €100bn–1tri, >1tri).
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
