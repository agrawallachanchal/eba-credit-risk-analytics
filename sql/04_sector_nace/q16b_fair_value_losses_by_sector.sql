-- Q16b | Which sectors hold the largest share of accumulated fair-value losses on non-performing exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521303
-- Added to make the Real Estate finding in Q16 reproducible (item 2521303 is reported by sector only, no status split).

with bysector as (
    select item, credit.nace_codes, nace_metadata.label, sum(amount) as sectortotal
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521303' and credit.nace_codes != 0
    group by item, credit.nace_codes, nace_metadata.label
)
select item, nace_codes, label, sectortotal,
       sectortotal / sum(sectortotal) over () * 100 as sector_share_pct
from bysector
order by sector_share_pct desc;
