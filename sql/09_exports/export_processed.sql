-- Exports the compact tables in data/processed/ used by the Power BI dashboard and the web page.
-- Run from the repository root:  psql -d eba -f sql/09_exports/export_processed.sql
-- Each table applies the same filters as the queries cited in its comment, so dashboard figures equal the SQL log.

-- banks.csv | one row per bank (dimension)
\copy (select lei_code, name, country as country_code, desc_country as country from bank_metadata order by name) to 'data/processed/banks.csv' with (format csv, header, encoding 'UTF8')

-- countries.csv | one row per bank home country (dimension)
\copy (select distinct country as country_code, desc_country as country from bank_metadata order by country) to 'data/processed/countries.csv' with (format csv, header, encoding 'UTF8')

-- bank_exposure.csv | Q4–Q12, Q17–Q19, Q29, Q30 | period 202506, country-total rows (country = 0) of the three anchor items per bank.
-- is_named_bank = false marks the EBA "All other banks" aggregate, which bank-level measures exclude.
\copy (select c.lei_code, c.nsa as country_code, case when c.lei_code <> 'XXXXXXXXXXXXXXXXXXXX' then 'TRUE' else 'FALSE' end as is_named_bank, round(sum(case when item = 2520502 then amount else 0 end)::numeric, 2) as original_exposure, round(sum(case when item = 2520522 then amount else 0 end)::numeric, 2) as exposure_value, round(sum(case when item = 2520532 then amount else 0 end)::numeric, 2) as risk_exposure_amount from credit c where period = 202506 and item in (2520502, 2520522, 2520532) and c.country = 0 group by c.lei_code, c.nsa order by original_exposure desc) to 'data/processed/bank_exposure.csv' with (format csv, header)

-- sector.csv | Q16, Q22b, Q27 | item 2521301 Perf_Status 0 (total) and 2 (non-performing), 2521302 impairment; NACE 1–19 only
\copy (select n.nace_codes as nace_code, n.label as sector, round(sum(case when c.item = 2521301 and c.pref_status = 0 then amount else 0 end)::numeric, 2) as gross_carrying_amount, round(sum(case when c.item = 2521301 and c.pref_status = 2 then amount else 0 end)::numeric, 2) as non_performing, round(sum(case when c.item = 2521302 then amount else 0 end)::numeric, 2) as accumulated_impairment from credit c join nace_metadata n on n.nace_codes = c.nace_codes where c.period = 202506 and c.item in (2521301, 2521302) and c.nace_codes <> 0 group by n.nace_codes, n.label order by n.nace_codes) to 'data/processed/sector.csv' with (format csv, header, encoding 'UTF8')

-- country_asset_quality.csv | Q20b, Q23, Q28 | item 2520603 Perf_Status 1 and 2, item 2520613 Perf_Status 2, by bank home country
\copy (select nsa as country_code, round(sum(case when item = 2520603 and pref_status = 1 then amount else 0 end)::numeric, 2) as performing, round(sum(case when item = 2520603 and pref_status = 2 then amount else 0 end)::numeric, 2) as non_performing, round(sum(case when item = 2520613 and pref_status = 2 then amount else 0 end)::numeric, 2) as npe_provisions from credit where period = 202506 and item in (2520603, 2520613) and pref_status in (1, 2) group by nsa order by nsa) to 'data/processed/country_asset_quality.csv' with (format csv, header)

-- npe_trend.csv | Q31 | all four periods
\copy (select period, count(distinct lei_code) as banks_reporting, round(sum(case when pref_status = 1 then amount else 0 end)::numeric, 2) as performing, round(sum(case when pref_status = 2 then amount else 0 end)::numeric, 2) as non_performing from credit where item = 2520603 and pref_status in (1, 2) group by period order by period) to 'data/processed/npe_trend.csv' with (format csv, header)

-- stress_results.csv is exported from model/EBA_stress_test_model.xlsx (sheet Stress), not from SQL; see dashboard/README.md.
