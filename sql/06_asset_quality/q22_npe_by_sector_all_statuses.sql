-- Q22 | What is non-performing exposure by sector, including all Perf_Status sub-categories?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301

select item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label,
       sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
where period = '202506' and item = '2521301' and credit.pref_status != 0 and credit.nace_codes != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label
order by credit.pref_status asc, credit.nace_codes asc, highest_exposure desc;
