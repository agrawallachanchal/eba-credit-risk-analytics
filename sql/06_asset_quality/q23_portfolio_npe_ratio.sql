-- Q23 | What % of total portfolio exposure is non-performing vs performing? (board-level KPI)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
-- Note: Non-performing ratio = 2.14% of total exposure (Performing + Non Performing, codes 1+2 only).
-- This is consistent with typical EU bank NPL ratios (roughly 1-3%), confirming the calculation is
-- realistic.

with by_prefstatus as (
    select item, credit.pref_status, prefstatus_metadata.label, sum(amount) as total
    from credit
    inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
    where period = '202506' and item = '2520603' and credit.pref_status in ('1', '2')
    group by item, credit.pref_status, prefstatus_metadata.label
),
total as (
    select item, sum(total) as total_exposure
    from by_prefstatus
    group by item
)
select by_prefstatus.item, pref_status, label, total, total_exposure,
       total / total_exposure * 100 as exp_pct
from by_prefstatus
inner join total on total.item = by_prefstatus.item;
