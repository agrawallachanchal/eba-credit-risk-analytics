-- Q3 | List the distinct Item/Label combinations available, and pick one to anchor the analysis on.
-- Period: 202506 (Jun 2025) | Units: EUR mn
-- Note: Found 89 distinct Item/Label combinations spanning several EBA templates. Chose three related
-- items as the main anchors: 2520502 (Original Exposure), 2520522 (Exposure value), 2520532 (Risk
-- exposure amount) — all 'by exposure class' versions. These were chosen because they exist in both
-- the STA and IRB report types; the plain, non-broken-down totals only exist under STA and would
-- silently exclude every IRB bank.

select distinct item, label
from credit
order by item asc;
