-- Q26c | CET1 capital and total risk exposure amount (RWA), per bank
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520102 (CET1 capital), 2520138 (total RWA)

select item, label, lei_code, amount
from oth
where period = '202506' and item in ('2520102', '2520138')
order by item;
