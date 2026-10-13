-- Q22b | Which NACE sectors have the highest non-performing exposure rate (non-performing ÷ sector total), rather than the highest raw amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Ranking sectors by non-performing rate tells a different story than Q22a: Construction has the
-- highest NPE rate (6.4%), more than double Real Estate's (2.8%), despite Real Estate having a far
-- larger absolute non-performing amount. Construction loans are proportionally riskier — a smaller
-- sector, but a higher share of its lending has gone bad. Real Estate's top ranking in Q22a mainly
-- reflects its overall size, not elevated risk per loan.
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).

with sector_total as (
    select credit.nace_codes, nace_metadata.label, sum(amount) as total_pref_status
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0'
      and credit.pref_status = 0
    group by credit.nace_codes, nace_metadata.label
),
sector_npe as (
    select nace_codes, sum(amount) as total_pref_status2
    from credit
    where period = '202506' and item = '2521301' and nace_codes != '0' and pref_status = '2'
    group by nace_codes
)
select sector_total.nace_codes, sector_total.label, sector_total.total_pref_status, sector_npe.total_pref_status2,
       sector_npe.total_pref_status2 / sector_total.total_pref_status * 100 as npe_rate_pct
from sector_total
inner join sector_npe on sector_npe.nace_codes = sector_total.nace_codes
order by npe_rate_pct desc;
