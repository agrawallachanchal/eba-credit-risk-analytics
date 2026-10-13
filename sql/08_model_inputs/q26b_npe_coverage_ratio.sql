-- Q26b | Provision coverage of performing and non-performing loans, per bank
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603 (gross carrying amount), 2520613 (impairment and provisions)

with c as (
    select item, pref_status, lei_code, amount
    from credit
    where period = '202506' and item in ('2520603', '2520613') and pref_status in ('1', '2')
),
t as (
    select lei_code,
           sum(case when item = '2520603' and pref_status = 1 then amount else 0 end) as gross_p,
           sum(case when item = '2520613' and pref_status = 1 then amount else 0 end) as provision_p,
           sum(case when item = '2520603' and pref_status = 2 then amount else 0 end) as gross_np,
           sum(case when item = '2520613' and pref_status = 2 then amount else 0 end) as provision_np
    from c
    group by lei_code
)
select t.lei_code, gross_p, provision_p, round((provision_p / nullif(gross_p, 0)) * 100, 3) as coverage_p,
       gross_np, provision_np, round((provision_np / nullif(gross_np, 0)) * 100, 3) as coverage_np
from t;
