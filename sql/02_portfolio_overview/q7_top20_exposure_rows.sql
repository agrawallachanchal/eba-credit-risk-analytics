-- Q7 | What are the top 20 largest single exposure rows (bank + country + sector combination)?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: These rows are dominated by single large, concentrated exposures (one bank's exposure to one
-- country/sector) — not by overall bank size. A bank with a large but well-spread book across many
-- rows won't appear here even if its total exposure is far bigger, because no single row captures its
-- full size. Useful for spotting concentrated single bets, not for ranking the biggest banks overall
-- (that's Q8).
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.

select metadata.name, credit.lei_code, credit.item, credit.exposure, credit.amount
from credit
inner join metadata on metadata.lei_code = credit.lei_code
where period = '202506' and item = '2520502' and credit.country = 0
order by amount desc
limit 20;
