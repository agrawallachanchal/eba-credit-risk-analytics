-- Q6 | What is the average exposure per bank, for each anchor item?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: The question is ambiguous as worded — it could mean the average size of a single reported row,
-- or the average size of a bank's whole book. Went with the second, more meaningful interpretation:
-- total exposure divided by the number of distinct banks.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).

select item, label, sum(amount)/count(distinct lei_code) as avg_exposure_per_bank
from credit
where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX'
group by item, label;
