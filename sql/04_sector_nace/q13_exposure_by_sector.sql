-- Q13 | What is total exposure by NACE sector code?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Initial finding claimed nace_codes = 0 ('No breakdown') meant ~50% of exposure was
-- unclassified. This was later found to be wrong — see the correction below.
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).

select item, credit.label, credit.nace_codes, nace_metadata.label, sum(amount) as total_exposure
from credit
inner join nace_metadata on credit.nace_codes = nace_metadata.nace_codes
where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
group by item, credit.label, credit.nace_codes, nace_metadata.label
order by item;
