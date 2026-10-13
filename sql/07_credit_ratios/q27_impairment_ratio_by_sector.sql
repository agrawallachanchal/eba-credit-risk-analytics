-- Q27 | How much accumulated impairment does each sector carry relative to its gross carrying amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301 (gross carrying amount), 2521302 (accumulated impairment)
-- Impairment ratio = accumulated impairment / gross carrying amount (all loans in the sector).
-- The NACE template does not split impairment by performing status, so a sector-level NPE coverage ratio cannot be built from it.

with gross as (
    select nace_codes, sum(amount) as gross_amt
    from credit
    where period = '202506' and item = '2521301' and pref_status = 0 and nace_codes != 0
    group by nace_codes
),
imp as (
    select nace_codes, sum(amount) as impairment
    from credit
    where period = '202506' and item = '2521302' and nace_codes != 0
    group by nace_codes
)
select gross.nace_codes, nace_metadata.label, gross.gross_amt, imp.impairment,
       imp.impairment / nullif(gross.gross_amt, 0) * 100 as impairment_ratio_pct
from gross
inner join imp on imp.nace_codes = gross.nace_codes
inner join nace_metadata on nace_metadata.nace_codes = gross.nace_codes
order by impairment_ratio_pct desc;
