-- Q11 | Which countries account for more than 5% of total exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.

with exp_by_nsa as (
    select nsa, sum(amount) as total_exposure
    from credit
    where period = '202506' and item = '2520502' and country = 0
    group by nsa
)
select exp_by_nsa.nsa, exp_by_nsa.total_exposure
from exp_by_nsa
where exp_by_nsa.total_exposure > (
    select 0.05 * sum(total_exposure)
    from exp_by_nsa
);
