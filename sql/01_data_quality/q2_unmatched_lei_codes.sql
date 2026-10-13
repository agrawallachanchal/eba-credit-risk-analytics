-- Q2 | Find LEI_Codes in credit that have no match in the metadata table (data quality check).
-- Period: 202506 (Jun 2025) | Units: EUR mn
-- Note: Found two unmatched LEI_Codes. One was a genuine placeholder row (not a real bank). The other
-- belonged to a real bank (Banco de Crédito Social Cooperativo, ES) whose LEI_Code had been corrupted
-- in the metadata file — Excel had auto-converted the 20-digit code into scientific notation
-- (9.598E+19). Verified the true value against the credit table and the bank's country/name, then
-- corrected it with an UPDATE. Re-running the check afterward left only the genuine placeholder row.

select distinct c.lei_code
from credit as c
left join metadata as m on c.lei_code = m.lei_code
where m.lei_code is null;
