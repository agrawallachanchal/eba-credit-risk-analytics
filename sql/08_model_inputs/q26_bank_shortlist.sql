-- Q26 | Combine total assets, NPE ratio and CET1 ratio into one reference table (shortlist for the stress test)
-- Period: 202506 (Jun 2025) | Item(s): 2521010 (total assets), 2520603 (loans), 2520140 (CET1 ratio)

with t as (
    select distinct oth.item, oth.label, oth.lei_code, bank_metadata.name
    from oth
    inner join bank_metadata on bank_metadata.lei_code = oth.lei_code
    where period = '202506' and item in ('2521010')
),
exposure as (
    select item, lei_code, sum(amount) as exp_total
    from oth
    where period = '202506' and item = '2521010'
    group by item, lei_code
),
prefstatus as (
    select lei_code, sum(amount) as exp_prefstatus
    from credit
    where period = '202506' and item = '2520603' and pref_status in ('1', '2')
    group by lei_code
),
npe as (
    select lei_code, sum(amount) as npe
    from credit
    where period = '202506' and item = '2520603' and pref_status = 2
    group by lei_code
),
nperatio as (
    select npe.lei_code, ((npe / exp_prefstatus) * 100) as nperatio
    from npe
    inner join prefstatus on prefstatus.lei_code = npe.lei_code
),
cet1 as (
    select lei_code, amount as cet1ratio
    from oth
    where period = '202506' and item = '2520140'
)
select t.item, label, t.lei_code, name, exp_total, nperatio, cet1ratio
from t
inner join exposure on exposure.item = t.item and exposure.lei_code = t.lei_code
inner join nperatio on nperatio.lei_code = t.lei_code
inner join cet1 on cet1.lei_code = t.lei_code
order by item, name;
