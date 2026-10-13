-- Q20 | What is total exposure split by Perf_Status (performing vs non-performing), including the full sub-category breakdown?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
-- Note: Of the 7 non-zero codes returned, only 1 (Performing) and 2 (Non Performing) are the true top-
-- level, non-overlapping split. Codes 3, 4, 12, 23, and 222 are sub-categories nested inside 1 or 2 —
-- summing all 7 together would double-count. Full breakdown shown for detail; the clean total is 1 + 2
-- only. Two related items (2520605, by exposure class; 2521301, the NACE item) were checked and found
-- to be different, non-substitutable scopes — 2521301 turned out to be the better anchor for the
-- sector-level breakdown in Q22.

select item, credit.label, credit.pref_status, prefstatus_metadata.label, sum(amount) as total_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label;
