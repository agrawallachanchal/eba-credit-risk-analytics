-- Q14 | Which NACE sectors have the highest average exposure size?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Average exposure size per sector closely tracks Q13's total-exposure ranking — Real Estate
-- leads both, followed by Manufacturing and Wholesale/Retail Trade. No sector shows an unusually high
-- average relative to its total rank, meaning exposure size scales fairly evenly with the number of
-- reporting banks — no sign of a small group of banks making unusually large, concentrated bets in any
-- one sector.
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
select bysector.item, bysector.nace_codes, bysector.label, bysector.total,
       bysector.total / count(distinct bybankbysector.lei_code) as avgbysector
from bysector
inner join bybankbysector
    on bybankbysector.item = bysector.item and bybankbysector.nace_codes = bysector.nace_codes
group by bysector.item, bysector.nace_codes, bysector.label, bysector.total
order by item, avgbysector desc;
