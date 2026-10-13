-- Run from the repository root with psql (client-side \copy, so no server file permissions are needed):
--   psql -d eba -f sql/00_setup/02_load_data.sql
-- Raw EBA files go in data/raw/ (see data/README.md); the small lookup files are already in data/metadata/.

-- The EBA files quote every field, so an empty value arrives as "" and must be forced to NULL for numeric columns.
\copy credit FROM 'data/raw/tr_cre.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', FORCE_NULL (period, item, portfolio, country, country_rank, exposure, status, pref_status, nace_codes, amount, "row", "column"))
\copy oth FROM 'data/raw/tr_oth.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', FORCE_NULL (period, item, assets_fv, assets_stages, exposure, financial_instruments, amount, fin_end_year, n_quarters, "row", "column"))
\copy bank_metadata FROM 'data/metadata/TR_Metadata_Bankdetail.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy nace_metadata FROM 'data/metadata/TR_Metadata_nace.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy prefstatus_metadata FROM 'data/metadata/TR_Metadata_perfstatus.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- The lookup CSVs end with a blank "," line: remove the resulting empty rows.
DELETE FROM nace_metadata WHERE nace_codes IS NULL;
DELETE FROM prefstatus_metadata WHERE pref_status IS NULL;

CREATE INDEX ON credit (period, item);
CREATE INDEX ON credit (lei_code);
CREATE INDEX ON oth (period, item);
