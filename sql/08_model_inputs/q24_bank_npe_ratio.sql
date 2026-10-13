-- Q24 | What is each bank's non-performing exposure ratio? (bank-level version of Q23)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603

with bybank as (
    select item, credit.pref_status, prefstatus_metadata.label, credit.lei_code, bank_metadata.name, sum(amount) as bankwise
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
    where period = '202506' and item = '2520603' and credit.pref_status in ('1', '2')
    group by item, credit.pref_status, prefstatus_metadata.label, credit.lei_code, bank_metadata.name
),
total as (
    select item, lei_code, sum(bankwise) as total
    from bybank
    group by item, lei_code
)
select bybank.item, pref_status, label, bybank.lei_code, name, bankwise, total, ((bankwise / total) * 100) as bank_np_pct
from bybank
inner join total on total.item = bybank.item and total.lei_code = bybank.lei_code
where pref_status = 2
order by bank_np_pct desc;
