-- Q16 | Which sectors represent more than 10% of portfolio exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Real Estate, Manufacturing, and Wholesale/Retail Trade are consistently the three sectors
-- exceeding 10% of exposure, together representing roughly half the classified portfolio — a genuine
-- sector concentration. Separately, under item 2521303 (fair-value losses on non-performing exposure),
-- Real Estate alone accounts for ~47% — nearly double its ~25% share of gross exposure — suggesting
-- Real Estate exposures are disproportionately represented among distressed exposure relative to their
-- overall size.
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).

with bysector as (
    select item, credit.nace_codes, nace_metadata.label, sum(amount) as sectortotal
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, credit.nace_codes, nace_metadata.label
),
itemtotal as (
    select item, sum(sectortotal) as itemtotal
    from bysector
    group by item
)
select item, nace_codes, label, sectorconc
from (
    select bysector.item, nace_codes, label, sectortotal, itemtotal,
           sectortotal / itemtotal * 100 as sectorconc
    from bysector
    inner join itemtotal on itemtotal.item = bysector.item
) as t
where sectorconc >= 10;
