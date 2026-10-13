-- Q22a | Which NACE sectors carry the largest non-performing exposure amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301

select item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label,
       sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
where period = '202506' and item = '2521301' and credit.pref_status = 2 and credit.nace_codes != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label
order by highest_exposure desc;
