-- Q28 | How well are non-performing loans covered by provisions, by bank home country?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603 (gross carrying amount), 2520613 (impairment and provisions)
-- NPE coverage = provisions on non-performing loans / gross non-performing loans (Perf_Status 2).
-- Computed from summed amounts, so larger banks weigh more (a ratio of sums, not an average of bank ratios).

with npe as (
    select nsa,
           sum(case when item = '2520603' then amount end) as gross_npe,
           sum(case when item = '2520613' then amount end) as provision_npe
    from credit
    where period = '202506' and item in ('2520603', '2520613') and pref_status = 2
    group by nsa
)
select nsa, gross_npe, provision_npe,
       provision_npe / nullif(gross_npe, 0) * 100 as npe_coverage_pct
from npe
order by gross_npe desc;
