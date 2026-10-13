-- Q13a | Correction: is nace_codes = 0 really unclassified exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Checked each bank's nace_codes = 0 total against the sum of its 19 real sector rows — they
-- matched almost exactly. This means nace_codes = 0 is a duplicate total, not unclassified exposure.
-- Sector analysis should exclude nace_codes = 0. The original Q13 totals (using only the 19 real
-- sectors) were correct all along.

with bybank as (
    select item, nace_codes, lei_code, sum(amount) as totalnace0
    from credit
    where period = '202506' and item = '2521301' and nace_codes = '0'
    group by item, nace_codes, lei_code
),
bybanknace as (
    select item, lei_code, sum(amount) as totalallnace
    from credit
    where period = '202506' and item = '2521301' and nace_codes != '0'
    group by item, lei_code
)
select bybank.item, bybank.lei_code, totalnace0, totalallnace
from bybank
inner join bybanknace on bybank.item = bybanknace.item and bybank.lei_code = bybanknace.lei_code
order by bybank.item;
