-- Q5 | How many distinct banks reported each anchor item in the latest period?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).

select count(distinct lei_code)
from credit
where period = '202506'
and item = '2520502' and lei_code <> 'XXXXXXXXXXXXXXXXXXXX';
