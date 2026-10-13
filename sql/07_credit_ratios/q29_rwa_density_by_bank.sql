-- Q29 | Which banks report the most risk-weighted books relative to their size? (RWA density)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520532 (risk exposure amount), 2520522 (exposure value)
-- RWA density = credit-risk risk exposure amount / exposure value, both "by exposure class (SA and IRB)".
-- Public-sector funding agencies show near-zero density (Kommuninvest 0.03%, SFIL 3.4%, Nederlandse Waterschapsbank 4.1%, Kuntarahoitus 1.5%) because their lending is government-backed.
-- Exposure value is gross of provisions for IRB, so density is comparable across banks but not to leverage-ratio exposure.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.

with bybank as (
    select lei_code,
           sum(case when item = '2520532' then amount end) as rea,
           sum(case when item = '2520522' then amount end) as exposure_value
    from credit
    where period = '202506' and item in ('2520532', '2520522') and country = 0
    group by lei_code
)
select bank_metadata.name, bank_metadata.country, bybank.exposure_value, bybank.rea,
       bybank.rea / nullif(bybank.exposure_value, 0) * 100 as rwa_density_pct
from bybank
inner join bank_metadata on bank_metadata.lei_code = bybank.lei_code
where bybank.exposure_value > 0
order by rwa_density_pct desc;
