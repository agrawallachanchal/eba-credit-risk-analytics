-- Q13b | Within each NACE sector, what % of total exposure does each bank represent?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).

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
order by item, nace_codes;
