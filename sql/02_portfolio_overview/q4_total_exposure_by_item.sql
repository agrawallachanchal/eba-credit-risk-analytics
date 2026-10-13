-- Q4 | For the latest period, what is the total credit exposure across all banks, for each anchor item?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Run once per anchor item: replace 2520502 with 2520522 and 2520532 (the three measures are not additive).
-- Note: Run once per item (2520502, 2520522, 2520532). The three totals are not directly comparable —
-- Original Exposure (gross) is larger than Exposure value (post credit-risk mitigation), which is
-- larger again than Risk exposure amount (post risk-weighting). Each should be read on its own, not
-- summed together.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.

select item, label, sum(amount) as total_credit_exposure
from credit
where period = '202506'
and item = '2520502' and country = 0
group by item, label;
