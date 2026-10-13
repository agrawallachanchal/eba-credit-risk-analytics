-- Q25 | What is each bank's current CET1 capital ratio?
-- Period: 202506 (Jun 2025) | Item(s): 2520140
-- Note: Amount is not in one unit across the oth table. Capital and P&L items (e.g. 2520102, 2520138, 2520335)
-- are in EUR mn; ratio items (2520140, 2520905) are plain decimals (0.13 = 13%).
-- Very high values (Kommuninvest ~352%, Kuntarahoitus ~89%) belong to municipal funding agencies with near-zero
-- risk-weighted assets and are genuine, not data errors.

select item, label, oth.lei_code, bank_metadata.name, amount
from oth
inner join bank_metadata on bank_metadata.lei_code = oth.lei_code
where period = '202506' and item = '2520140'
order by amount;
