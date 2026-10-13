-- Known source-data issue (found with sql/01_data_quality/q2_unmatched_lei_codes.sql):
-- the bank metadata file carries one LEI code that was converted to scientific notation (9.598E+19)
-- when the file was opened in Excel. The correct value was confirmed against the credit table
-- (same bank, same country: Banco de Credito Social Cooperativo, ES).
-- If you download a fresh copy of the metadata from the EBA, this fix is not needed.

UPDATE bank_metadata
SET    lei_code = '95980020140005881190'
WHERE  lei_code = '9.598E+19';
