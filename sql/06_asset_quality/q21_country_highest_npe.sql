-- Q21 | Which NSA country has the highest non-performing exposure amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603

select item, credit.label, credit.pref_status, prefstatus_metadata.label, nsa, sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status = 2
group by item, credit.label, nsa, credit.pref_status, prefstatus_metadata.label
order by highest_exposure desc
limit 1;
