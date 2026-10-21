-- eba_analysis.sql | The whole SQL side of the project in one file (PostgreSQL 14+; the queries also run unchanged on DuckDB).
--
-- Part 1  Build the database: tables, load of the EBA files, fix of one corrupted bank code.
-- Part 2  The 40 analytical queries, each with its question, notes and result.
-- Part 3  Export of the compact tables in docs/data/ used by the web page.
--
-- Run from the repository root (client-side \copy, so no server file permissions are needed):
--   createdb eba
--   psql -d eba -f eba_analysis.sql        -- runs all three parts, printing every query result
-- To work with a single query instead, run Part 1, then copy the query you want from Part 2.
-- The raw EBA files tr_cre.csv and tr_oth.csv must be in raw/ first (download steps are in build_web_data.py).

-- ====================================================================================================
-- PART 1 | Build the database
-- Tables, load of the EBA files, fix of one corrupted bank code.
-- ====================================================================================================



-- ====================================================================================================
-- 1. Tables
-- ====================================================================================================

-- Schema for the EBA Transparency Exercise 2025 project (PostgreSQL 14+)
-- Column names are the lower-cased CSV headers, except Perf_Status, which is stored as pref_status
-- (the name used throughout the queries). "row" and "column" are reserved words, so they are quoted.

DROP TABLE IF EXISTS credit, oth, bank_metadata, nace_metadata, prefstatus_metadata CASCADE;

CREATE TABLE credit (                       -- tr_cre.csv
    lei_code      varchar(20),
    nsa           varchar(5),
    period        integer,
    item          bigint,
    label         text,
    portfolio     integer,
    country       integer,
    country_rank  integer,
    exposure      integer,
    status        integer,
    pref_status   integer,
    nace_codes    integer,
    amount        numeric,
    "row"         integer,
    "column"      integer,
    sheet         text
);

CREATE TABLE oth (                          -- tr_oth.csv (capital, P&L, balance sheet)
    lei_code              varchar(20),
    nsa                   varchar(5),
    period                integer,
    item                  bigint,
    label                 text,
    assets_fv             integer,
    assets_stages         integer,
    exposure              integer,
    financial_instruments integer,
    amount                numeric,
    fin_end_year          integer,
    n_quarters            integer,
    "row"                 integer,
    "column"              integer,
    sheet                 text
);

CREATE TABLE bank_metadata (                -- TR_Metadata_Bankdetail.csv (all text; only the first four columns are used)
    country text, desc_country text, lei_code text, name text, finrep text, fin_year_end text, footnotes text,
    te_24 text, lei_code_te24 text, te_23 text, lei_code_te23 text, te_22 text, lei_code_te22 text,
    te_21 text, lei_code_te21 text, te_20a text, lei_code_te20a text, te_20s text, lei_code_te20s text,
    te_19 text, lei_code_te19 text, te_18 text, lei_code_te18 text, tr_17 text, lei_code_17 text,
    tr_16 text, lei_code_tr16 text, tr_15 text, lei_code_tr15 text
);

CREATE TABLE nace_metadata (                -- TR_Metadata_nace.csv
    nace_codes integer,
    label      text
);

CREATE TABLE prefstatus_metadata (          -- TR_Metadata_perfstatus.csv
    pref_status integer,
    label       text
);

-- Q1, Q2 and Q7 refer to the bank table as "metadata"; keep that name working.
CREATE VIEW metadata AS SELECT * FROM bank_metadata;

-- ====================================================================================================
-- 2. Load the EBA files
-- ====================================================================================================

-- The raw EBA files tr_cre.csv and tr_oth.csv go in raw/ (see build_web_data.py); the lookup files are already in docs/data/.

-- The EBA files quote every field, so an empty value arrives as "" and must be forced to NULL for numeric columns.
\copy credit FROM 'raw/tr_cre.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', FORCE_NULL (period, item, portfolio, country, country_rank, exposure, status, pref_status, nace_codes, amount, "row", "column"))
\copy oth FROM 'raw/tr_oth.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', FORCE_NULL (period, item, assets_fv, assets_stages, exposure, financial_instruments, amount, fin_end_year, n_quarters, "row", "column"))
\copy bank_metadata FROM 'docs/data/TR_Metadata_Bankdetail.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy nace_metadata FROM 'docs/data/TR_Metadata_nace.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')
\copy prefstatus_metadata FROM 'docs/data/TR_Metadata_perfstatus.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')

-- The lookup CSVs end with a blank "," line: remove the resulting empty rows.
DELETE FROM nace_metadata WHERE nace_codes IS NULL;
DELETE FROM prefstatus_metadata WHERE pref_status IS NULL;

CREATE INDEX ON credit (period, item);
CREATE INDEX ON credit (lei_code);
CREATE INDEX ON oth (period, item);

-- ====================================================================================================
-- 3. Fix known source-data issues
-- ====================================================================================================

-- Known source-data issue (found with query Q2 in Part 2):
-- the bank metadata file carries one LEI code that was converted to scientific notation (9.598E+19)
-- when the file was opened in Excel. The correct value was confirmed against the credit table
-- (same bank, same country: Banco de Credito Social Cooperativo, ES).
-- If you download a fresh copy of the metadata from the EBA, this fix is not needed.

UPDATE bank_metadata
SET    lei_code = '95980020140005881190'
WHERE  lei_code = '9.598E+19';


-- ====================================================================================================
-- PART 2 | The 40 analytical queries
-- Question, notes and result for each query. build_web_data.py reads this part for the web page.
-- ====================================================================================================

-- Each query starts with a header line "-- Q<n> | <question>", then period, units and items, then notes and,
-- where the run produced a finding, "Result" lines with the figures. Part 1 must have been run first.
--
-- Conventions
-- - Reference period 202506 (June 2025); amounts in EUR millions.
-- - credit.pref_status is the EBA Perf_Status column. Q1, Q2 and Q7 read the bank table through the view metadata.
-- - Item 2521301 repeats each bank-sector pair under Perf_Status 0, 2, 4 and 5: sector queries filter pref_status = 0.
-- - Items 2520502, 2520522 and 2520532 hold a country-total row (country = 0) and a breakdown of the same exposure by
--   top counterparty countries: exposure queries filter country = 0.
-- - LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA "All other banks" aggregate; bank-level counts and rankings exclude it.
-- - Q4 to Q8 show the anchor item 2520502; repeat with 2520522 and 2520532. The three measures are not additive.
-- - Numbering follows the original working log; there is no Q15 (a retired draft).


-- ====================================================================================================
-- Data quality
-- ====================================================================================================

-- Q1 | List all distinct banks (LEI_Code, Name, Country) from the metadata table.
-- Period: 202506 (Jun 2025) | Units: EUR mn
-- Note: Confirms the bank universe (name, country) the rest of the project is built on.
select distinct metadata.lei_code, metadata.name, metadata.country,
       metadata.desc_country, credit.nsa
from metadata
inner join credit on metadata.lei_code = credit.lei_code;

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


-- ====================================================================================================
-- Portfolio overview
-- ====================================================================================================

-- Q4 | For the latest period, what is the total credit exposure across all banks, for each anchor item?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Run once per anchor item: replace 2520502 with 2520522 and 2520532 (the three measures are not additive).
-- Note: Run once per item (2520502, 2520522, 2520532). The three totals are not directly comparable —
-- Original Exposure (gross) is larger than Exposure value (post credit-risk mitigation), which is
-- larger again than Risk exposure amount (post risk-weighting). Each should be read on its own, not
-- summed together.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- Totals at June 2025: original exposure EUR 31.3tn, exposure value EUR 26.3tn, risk exposure amount EUR
-- 7.9tn.
select item, label, sum(amount) as total_credit_exposure
from credit
where period = '202506'
and item = '2520502' and country = 0
group by item, label;

-- Q5 | How many distinct banks reported each anchor item in the latest period?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).
-- Result:
-- The "All other banks" aggregate (LEI XXXXXXXXXXXXXXXXXXXX) is excluded from bank-level counts and rankings;
-- it is not a single bank. 119 banks reported original exposure at June 2025.
select count(distinct lei_code)
from credit
where period = '202506'
and item = '2520502' and lei_code <> 'XXXXXXXXXXXXXXXXXXXX';

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
-- Result:
-- Average per bank: original exposure EUR 259bn, exposure value EUR 217bn, risk exposure amount EUR 65bn.
select item, label, sum(amount)/count(distinct lei_code) as avg_exposure_per_bank
from credit
where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX'
group by item, label;

-- Q7 | What are the top 20 largest single exposure rows (bank + country + sector combination)?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: These rows are dominated by single large, concentrated exposures (one bank's exposure to one
-- country/sector) — not by overall bank size. A bank with a large but well-spread book across many
-- rows won't appear here even if its total exposure is far bigger, because no single row captures its
-- full size. Useful for spotting concentrated single bets, not for ranking the biggest banks overall
-- (that's Q8).
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- The largest rows are BNP Paribas (EUR 865bn), Crédit Agricole (EUR 740bn) and ING (EUR 669bn); the top 20
-- rows belong to ten of the largest banking groups. A bank with a large book spread across many classes can be
-- absent here, so this ranks concentrated positions, not bank size (Q8, Q18).
select metadata.name, credit.lei_code, credit.item, credit.exposure, credit.amount
from credit
inner join metadata on metadata.lei_code = credit.lei_code
where period = '202506' and item = '2520502' and credit.country = 0
order by amount desc
limit 20;

-- Q8 | What % of total exposure do the top 20 banks represent? (concentration risk)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Anchor item shown is 2520502; repeat with 2520522 and 2520532 for the other two measures.
-- Note: Top 20 banks' Original Exposure as a % of total portfolio. Built using CTEs: bank-level
-- totals, top-20 sum, grand total, then divided.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).
-- Result:
-- The top 20 banks hold 66.4% of original exposure held by named banks.
with exp_by_bank as (
    select lei_code, sum(amount) as total
    from credit
    where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX'
    group by lei_code
),
top20 as (
    select sum(total) as top20total
    from (
        select lei_code, total
        from exp_by_bank
        order by total desc
        limit 20
    ) as t
),
all_total as (
    select sum(total) as alltotal
    from exp_by_bank
)
select top20.top20total, all_total.alltotal,
       top20.top20total / all_total.alltotal * 100 as pertop20
from top20, all_total;


-- ====================================================================================================
-- Geography
-- ====================================================================================================

-- Q9 | What is total exposure by NSA (bank home country)?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
select nsa, sum(amount) as total_exposure
from credit
where period = '202506' and item = '2520502' and country = 0
group by nsa;

-- Q10 | Which 10 countries have the largest exposures?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
select nsa, sum(amount) as total_exposure
from credit
where period = '202506' and item = '2520502' and country = 0
group by nsa
order by total_exposure desc
limit 10;

-- Q11 | Which countries account for more than 5% of total exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
with exp_by_nsa as (
    select nsa, sum(amount) as total_exposure
    from credit
    where period = '202506' and item = '2520502' and country = 0
    group by nsa
)
select exp_by_nsa.nsa, exp_by_nsa.total_exposure
from exp_by_nsa
where exp_by_nsa.total_exposure > (
    select 0.05 * sum(total_exposure)
    from exp_by_nsa
);

-- Q12 | What % of total exposure does each country represent?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- Shares by bank home country: France 28.9%, Germany 15.4%, Spain 13.7%, Italy 10.5%, Netherlands 9.2%. Five
-- countries are above 5% (Q11) and together hold 77.7%.
with exp_by_nsa as (
    select nsa, sum(amount) as total_exposure
    from credit
    where period = '202506' and item = '2520502' and country = 0
    group by nsa
),
alltotal as (
    select sum(total_exposure) as alltotal
    from exp_by_nsa
)
select exp_by_nsa.nsa, exp_by_nsa.total_exposure,
       exp_by_nsa.total_exposure / alltotal.alltotal * 100 as per_exp
from exp_by_nsa, alltotal;


-- ====================================================================================================
-- Sector (NACE)
-- ====================================================================================================

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

-- Q13a | Correction: is nace_codes = 0 really unclassified exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Checked each bank's nace_codes = 0 total against the sum of its 19 real sector rows — they
-- matched almost exactly. This means nace_codes = 0 is a duplicate total, not unclassified exposure.
-- Sector analysis should exclude nace_codes = 0. The original Q13 totals (using only the 19 real
-- sectors) were correct all along.
with bybank as (
    select item, nace_codes, lei_code, sum(amount) as totalnace0
    from credit
    where period = '202506' and item = '2521301' and nace_codes = '0'
    group by item, nace_codes, lei_code
),
bybanknace as (
    select item, lei_code, sum(amount) as totalallnace
    from credit
    where period = '202506' and item = '2521301' and nace_codes != '0'
    group by item, lei_code
)
select bybank.item, bybank.lei_code, totalnace0, totalallnace
from bybank
inner join bybanknace on bybank.item = bybanknace.item and bybank.lei_code = bybanknace.lei_code
order by bybank.item;

-- Q13b | Within each NACE sector, what % of total exposure does each bank represent?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).
with bybankbysector as (
    select item, lei_code, credit.nace_codes, nace_metadata.label, sum(amount) as total
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, lei_code, credit.nace_codes, nace_metadata.label
),
bysector as (
    select item, nace_codes, label, sum(total) as total
    from bybankbysector
    group by item, nace_codes, label
)
select bybankbysector.item, bybankbysector.lei_code, bybankbysector.nace_codes, bybankbysector.label,
       bybankbysector.total, bysector.total,
       bybankbysector.total / nullif(bysector.total, 0) * 100 as bybankbysectorconc
from bybankbysector
inner join bysector
    on bysector.item = bybankbysector.item and bysector.nace_codes = bybankbysector.nace_codes
order by bybankbysector.item, bybankbysector.nace_codes;

-- Q14 | Which NACE sectors have the highest average exposure size?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Average exposure size per sector closely tracks Q13's total-exposure ranking — Real Estate
-- leads both, followed by Manufacturing and Wholesale/Retail Trade. No sector shows an unusually high
-- average relative to its total rank, meaning exposure size scales fairly evenly with the number of
-- reporting banks — no sign of a small group of banks making unusually large, concentrated bets in any
-- one sector.
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).
with bybankbysector as (
    select item, lei_code, credit.nace_codes, nace_metadata.label, sum(amount) as total
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, lei_code, credit.nace_codes, nace_metadata.label
),
bysector as (
    select item, nace_codes, label, sum(total) as total
    from bybankbysector
    group by item, nace_codes, label
)
select bysector.item, bysector.nace_codes, bysector.label, bysector.total,
       bysector.total / count(distinct bybankbysector.lei_code) as avgbysector
from bysector
inner join bybankbysector
    on bybankbysector.item = bysector.item and bybankbysector.nace_codes = bysector.nace_codes
group by bysector.item, bysector.nace_codes, bysector.label, bysector.total
order by bysector.item, avgbysector desc;

-- Q16 | Which sectors represent more than 10% of portfolio exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Real Estate, Manufacturing, and Wholesale/Retail Trade are consistently the three sectors
-- exceeding 10% of exposure, together representing roughly half the classified portfolio — a genuine
-- sector concentration. Separately, under item 2521303 (fair-value losses on non-performing exposure),
-- Real Estate alone accounts for ~47% — nearly double its ~25% share of gross exposure — suggesting
-- Real Estate exposures are disproportionately represented among distressed exposure relative to their
-- overall size.
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).
-- Result:
-- Real Estate (25.5%), Manufacturing (15.1%) and Wholesale and retail trade (12.9%) each exceed 10% of gross
-- carrying amount and together make up about 53% of the classified portfolio.
with bysector as (
    select item, credit.nace_codes, nace_metadata.label, sum(amount) as sectortotal
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0' and credit.pref_status = 0
    group by item, credit.nace_codes, nace_metadata.label
),
itemtotal as (
    select item, sum(sectortotal) as itemtotal
    from bysector
    group by item
)
select item, nace_codes, label, sectorconc
from (
    select bysector.item, nace_codes, label, sectortotal, itemtotal,
           sectortotal / itemtotal * 100 as sectorconc
    from bysector
    inner join itemtotal on itemtotal.item = bysector.item
) as t
where sectorconc >= 10;

-- Q16b | Which sectors hold the largest share of accumulated fair-value losses on non-performing exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521303
-- Added to make the Real Estate finding in Q16 reproducible (item 2521303 is reported by sector only, no status split).
-- Result:
-- Real Estate: 47.1% of the total.
with bysector as (
    select item, credit.nace_codes, nace_metadata.label, sum(amount) as sectortotal
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521303' and credit.nace_codes != 0
    group by item, credit.nace_codes, nace_metadata.label
)
select item, nace_codes, label, sectortotal,
       sectortotal / sum(sectortotal) over () * 100 as sector_share_pct
from bysector
order by sector_share_pct desc;


-- ====================================================================================================
-- Bank level
-- ====================================================================================================

-- Q17 | Which banks have exposure above the overall average?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502, 2520522, 2520532
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- Banks above the average: 27 for original exposure, 28 for exposure value and 28 for risk exposure amount,
-- out of 119.
with bybank as (
    select item, credit.lei_code, name, sum(amount) as total
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    where period = '202506' and item in ('2520502', '2520522', '2520532') and credit.country = 0
    group by item, credit.lei_code, name
),
byitem as (
    select item, sum(total) as total, sum(total) / count(distinct lei_code) as avg
    from bybank
    group by item
)
select bybank.item, lei_code, name, byitem.avg, bybank.total
from bybank
inner join byitem on byitem.item = bybank.item
where bybank.total >= byitem.avg
order by bybank.item, byitem.avg desc;

-- Q18 | Which banks cumulatively account for 50% of total exposure?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502, 2520522, 2520532
-- Note: Roughly 10-12 banks (out of ~120) account for half of total reported exposure, across all
-- three anchor items — confirming the concentration pattern already seen in Q8, now found
-- independently using a running total instead of a fixed top-20 cutoff.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- Half of total exposure is held by 11 banks on original exposure, 13 on exposure value and 11 on risk
-- exposure amount, out of 119.
with bybank as (
    select item, credit.lei_code, name, sum(amount) as total
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    where period = '202506' and item in ('2520502', '2520522', '2520532') and credit.country = 0
    group by item, credit.lei_code, name
),
byitem as (
    select item, sum(total) as total, sum(total) / 2 as half
    from bybank
    group by item
),
byrunningsum as (
    select bybank.item, lei_code, name, bybank.total, half,
           sum(bybank.total) over (partition by bybank.item order by bybank.total desc) as running_sum
    from bybank
    inner join byitem on byitem.item = bybank.item
    group by bybank.item, lei_code, name, bybank.total, half
),
byrn as (
    select *, row_number() over (partition by item order by running_sum) as rn
    from byrunningsum
    where running_sum >= half
),
byrn1 as (
    select item, running_sum
    from byrn
    where rn = 1
)
select byrunningsum.item, lei_code, name, total, half, byrunningsum.running_sum
from byrunningsum
join byrn1 on byrn1.item = byrunningsum.item
where byrunningsum.running_sum <= byrn1.running_sum;

-- Q19 | Distribution of banks by exposure-size bucket (<€1bn, €1–10bn, €10–100bn, €100bn–1tri, >1tri).
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502, 2520522, 2520532
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- Original exposure: 3 banks below EUR 10bn, 62 between EUR 10bn and 100bn, 45 between EUR 100bn and 1tn, and
-- 9 above EUR 1tn.
with bybank as (
    select item, credit.lei_code, name, sum(amount) as total
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    where period = '202506' and item in ('2520502', '2520522', '2520532') and credit.country = 0
    group by item, credit.lei_code, name
),
bybucket as (
    select item, lei_code, name, total,
        case
            when total < 1000 then '< 1bn'
            when total < 10000 then '1bn to <10 bn'
            when total < 100000 then '10 bn to <100 bn'
            when total < 1000000 then '100 bn to <1 tri'
            else '>= 1 tri'
        end as exposure_bucket
    from bybank
)
select item, exposure_bucket, count(lei_code) as count
from bybucket
group by item, exposure_bucket
order by item,
    case exposure_bucket
        when '< 1bn' then 1
        when '1bn to <10 bn' then 2
        when '10 bn to <100 bn' then 3
        when '100 bn to <1 tri' then 4
        when '>= 1 tri' then 5
    end;


-- ====================================================================================================
-- Asset quality
-- ====================================================================================================

-- Q20 | What is total exposure split by Perf_Status (performing vs non-performing), including the full sub-category breakdown?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
-- Note: Of the 7 non-zero codes returned, only 1 (Performing) and 2 (Non Performing) are the true top-
-- level, non-overlapping split. Codes 3, 4, 12, 23, and 222 are sub-categories nested inside 1 or 2 —
-- summing all 7 together would double-count. Full breakdown shown for detail; the clean total is 1 + 2
-- only. Two related items (2520605, by exposure class; 2521301, the NACE item) were checked and found
-- to be different, non-substitutable scopes — 2521301 turned out to be the better anchor for the
-- sector-level breakdown in Q22.
select item, credit.label, credit.pref_status, prefstatus_metadata.label, sum(amount) as total_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label;

-- Q20b | Same breakdown, by country.
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
select item, credit.label, credit.pref_status, prefstatus_metadata.label, nsa, sum(amount) as total_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status != 0
group by item, credit.label, nsa, credit.pref_status, prefstatus_metadata.label
order by credit.pref_status asc, total_exposure desc;

-- Q21 | Which NSA country has the highest non-performing exposure amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
select item, credit.label, credit.pref_status, prefstatus_metadata.label, nsa, sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
where period = '202506' and item = '2520603' and credit.pref_status = 2
group by item, credit.label, nsa, credit.pref_status, prefstatus_metadata.label
order by highest_exposure desc
limit 1;

-- Q22 | What is non-performing exposure by sector, including all Perf_Status sub-categories?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
select item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label,
       sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
where period = '202506' and item = '2521301' and credit.pref_status != 0 and credit.nace_codes != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label
order by credit.pref_status asc, credit.nace_codes asc, highest_exposure desc;

-- Q22a | Which NACE sectors carry the largest non-performing exposure amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
select item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label,
       sum(amount) as highest_exposure
from credit
inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
where period = '202506' and item = '2521301' and credit.pref_status = 2 and credit.nace_codes != 0
group by item, credit.label, credit.pref_status, prefstatus_metadata.label, credit.nace_codes, nace_metadata.label
order by highest_exposure desc;

-- Q22b | Which NACE sectors have the highest non-performing exposure rate (non-performing ÷ sector total), rather than the highest raw amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301
-- Note: Ranking sectors by non-performing rate tells a different story than Q22a: Construction has the
-- highest NPE rate (6.4%), more than double Real Estate's (2.8%), despite Real Estate having a far
-- larger absolute non-performing amount. Construction loans are proportionally riskier — a smaller
-- sector, but a higher share of its lending has gone bad. Real Estate's top ranking in Q22a mainly
-- reflects its overall size, not elevated risk per loan.
-- Correction: item 2521301 repeats every bank-sector pair under Perf_Status 0 (total), 2, 4 and 5.
-- Filtering on pref_status = 0 avoids counting the same exposure more than once (the first draft omitted it).
-- Result:
-- Construction has the highest NPE rate (6.4%), followed by Accommodation and food service (5.6%) and
-- Wholesale and retail trade (4.2%).
with sector_total as (
    select credit.nace_codes, nace_metadata.label, sum(amount) as total_pref_status
    from credit
    inner join nace_metadata on nace_metadata.nace_codes = credit.nace_codes
    where period = '202506' and item = '2521301' and credit.nace_codes != '0'
      and credit.pref_status = 0
    group by credit.nace_codes, nace_metadata.label
),
sector_npe as (
    select nace_codes, sum(amount) as total_pref_status2
    from credit
    where period = '202506' and item = '2521301' and nace_codes != '0' and pref_status = '2'
    group by nace_codes
)
select sector_total.nace_codes, sector_total.label, sector_total.total_pref_status, sector_npe.total_pref_status2,
       sector_npe.total_pref_status2 / sector_total.total_pref_status * 100 as npe_rate_pct
from sector_total
inner join sector_npe on sector_npe.nace_codes = sector_total.nace_codes
order by npe_rate_pct desc;

-- Q23 | What % of total portfolio exposure is non-performing vs performing? (board-level KPI)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
-- Note: Non-performing ratio = 2.14% of total exposure (Performing + Non Performing, codes 1+2 only).
-- This is consistent with typical EU bank NPL ratios (roughly 1-3%), confirming the calculation is
-- realistic.
with by_prefstatus as (
    select item, credit.pref_status, prefstatus_metadata.label, sum(amount) as total
    from credit
    inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
    where period = '202506' and item = '2520603' and credit.pref_status in ('1', '2')
    group by item, credit.pref_status, prefstatus_metadata.label
),
total as (
    select item, sum(total) as total_exposure
    from by_prefstatus
    group by item
)
select by_prefstatus.item, pref_status, label, total, total_exposure,
       total / total_exposure * 100 as exp_pct
from by_prefstatus
inner join total on total.item = by_prefstatus.item;


-- ====================================================================================================
-- Credit ratios, concentration and trend
-- ====================================================================================================

-- Q27 | How much accumulated impairment does each sector carry relative to its gross carrying amount?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2521301 (gross carrying amount), 2521302 (accumulated impairment)
-- Impairment ratio = accumulated impairment / gross carrying amount (all loans in the sector).
-- The NACE template does not split impairment by performing status, so a sector-level NPE coverage ratio cannot be built from it.
-- Result:
-- Construction has the highest ratio (4.1%), followed by Accommodation and food service (3.5%) and Wholesale
-- and retail trade (2.8%). Real Estate is 1.4%. Construction is highest on both the NPE rate (Q22b) and the
-- impairment ratio.
with gross as (
    select nace_codes, sum(amount) as gross_amt
    from credit
    where period = '202506' and item = '2521301' and pref_status = 0 and nace_codes != 0
    group by nace_codes
),
imp as (
    select nace_codes, sum(amount) as impairment
    from credit
    where period = '202506' and item = '2521302' and nace_codes != 0
    group by nace_codes
)
select gross.nace_codes, nace_metadata.label, gross.gross_amt, imp.impairment,
       imp.impairment / nullif(gross.gross_amt, 0) * 100 as impairment_ratio_pct
from gross
inner join imp on imp.nace_codes = gross.nace_codes
inner join nace_metadata on nace_metadata.nace_codes = gross.nace_codes
order by impairment_ratio_pct desc;

-- Q28 | How well are non-performing loans covered by provisions, by bank home country?
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603 (gross carrying amount), 2520613 (impairment and provisions)
-- NPE coverage = provisions on non-performing loans / gross non-performing loans (Perf_Status 2).
-- Computed from summed amounts, so larger banks weigh more (a ratio of sums, not an average of bank ratios).
-- Result:
-- Among the large markets: Italy 52.1%, Spain 45.5%, France 44.4%, Germany 35.0%, Netherlands 24.2%. Across
-- all 26 countries the range runs from 19.6% (Estonia) to 61.3% (Hungary). Low coverage combined with a large
-- NPE stock means more capital impact when NPEs rise, which is the mechanism the stress-test model captures.
with npe as (
    select nsa,
           sum(case when item = '2520603' then amount end) as gross_npe,
           sum(case when item = '2520613' then amount end) as provision_npe
    from credit
    where period = '202506' and item in ('2520603', '2520613') and pref_status = 2
    group by nsa
)
select nsa, gross_npe, provision_npe,
       provision_npe / nullif(gross_npe, 0) * 100 as npe_coverage_pct
from npe
order by gross_npe desc;

-- Q29 | Which banks report the most risk-weighted books relative to their size? (RWA density)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520532 (risk exposure amount), 2520522 (exposure value)
-- RWA density = credit-risk risk exposure amount / exposure value, both "by exposure class (SA and IRB)".
-- Public-sector funding agencies show near-zero density (Kommuninvest 0.03%, SFIL 3.6%, Nederlandse Waterschapsbank 4.2%, Kuntarahoitus 1.5%) because their lending is government-backed.
-- Exposure value is gross of provisions for IRB, so density is comparable across banks but not to leverage-ratio exposure.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Result:
-- Median 31.2% across 119 banks. Highest: Bpifrance 76.3% and Volkswagen Financial Services 74.5%. Examples
-- among the stress-model banks: Santander 33.9%, BNP Paribas 35.4%, BAWAG 28.8%, CEC Bank 23.5%.
with bybank as (
    select lei_code,
           sum(case when item = '2520532' then amount end) as rea,
           sum(case when item = '2520522' then amount end) as exposure_value
    from credit
    where period = '202506' and item in ('2520532', '2520522') and country = 0
    group by lei_code
)
select bank_metadata.name, bank_metadata.country, bybank.exposure_value, bybank.rea,
       bybank.rea / nullif(bybank.exposure_value, 0) * 100 as rwa_density_pct
from bybank
inner join bank_metadata on bank_metadata.lei_code = bybank.lei_code
where bybank.exposure_value > 0
order by rwa_density_pct desc;

-- Q30 | How concentrated is exposure by bank, by country and by sector? (Herfindahl-Hirschman index)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520502 (banks, countries), 2521301 (sectors)
-- HHI = sum of squared percentage shares, 0 to 10,000. Common reading: under 1,500 unconcentrated, above 2,500 highly concentrated.
-- Also reports the effective number of equal-sized units (10,000 / HHI).
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).
-- Result:
--    Dimension  Units  HHI    Effective number of equal-sized units
--    ---------  -----  -----  -------------------------------------
--    Bank       119    302    33.1
--    Country    26     1,501  6.7
--    Sector     19     1,234  8.1
--
-- By bank (excluding the "All other banks" aggregate), exposure is not concentrated in the HHI sense, even
-- though 11 banks hold half of it (Q18), because the large banks are similar in size. By country it sits at
-- the edge of the "unconcentrated" band (HHI 1,500), with an effective 6.7 countries behind 26.
with bank as (
    select 'bank' as dimension, lei_code as unit, sum(amount) as amt
    from credit where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX' group by lei_code
),
country as (
    select 'country', nsa, sum(amount)
    from credit where period = '202506' and item = '2520502' and country = 0 group by nsa
),
sector as (
    select 'sector', nace_codes::text, sum(amount)
    from credit where period = '202506' and item = '2521301' and pref_status = 0 and nace_codes != 0 group by nace_codes
),
unioned as (
    select * from bank union all select * from country union all select * from sector
),
shares as (
    select dimension, unit, amt, amt / sum(amt) over (partition by dimension) * 100 as share_pct
    from unioned
)
select dimension, count(*) as units,
       round(sum(share_pct * share_pct)::numeric, 0) as hhi,
       round((10000 / sum(share_pct * share_pct))::numeric, 1) as effective_units
from shares
group by dimension
order by dimension;

-- Q31 | Are concentration and the NPE ratio rising or falling across the four reporting periods?
-- Periods: 202409, 202412, 202503, 202506 | Units: EUR mn | Item(s): 2520502, 2520603
-- The number of banks reporting differs by period (115, 119, 110, 119, excluding the "All other banks" aggregate), so period-to-period changes mix real movement with sample changes.
-- A like-for-like comparison would restrict to banks reporting in all four periods.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).
-- Result:
--    Period   Banks reporting  Top-20 share  NPE ratio
--    -------  ---------------  ------------  ---------
--    2024-09  115              67.9%         2.24%
--    2024-12  119              67.2%         2.21%
--    2025-03  110              69.0%         2.17%
--    2025-06  119              66.4%         2.14%
--
-- The top-20 share moves with the number of banks reporting (it is highest in the period with the fewest
-- banks), so it is not read as a trend.
with exposure as (
    select period, lei_code, sum(amount) as amt
    from credit where item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX' group by period, lei_code
),
ranked as (
    select period, lei_code, amt, row_number() over (partition by period order by amt desc) as rn
    from exposure
),
concentration as (
    select period, count(*) as banks_reporting, sum(amt) as total_exposure,
           sum(case when rn <= 20 then amt end) / sum(amt) * 100 as top20_share_pct
    from ranked group by period
),
npe as (
    select period,
           sum(case when pref_status = 2 then amount end) / sum(amount) * 100 as npe_ratio_pct
    from credit
    where item = '2520603' and pref_status in (1, 2)
    group by period
)
select concentration.period, banks_reporting, total_exposure, top20_share_pct, npe.npe_ratio_pct
from concentration
inner join npe on npe.period = concentration.period
order by concentration.period;

-- Q32 | Are the banks that drive exposure concentration also the ones with higher NPE ratios?
-- Period: 202506 (Jun 2025) | Item(s): 2520502 (exposure), 2520603 (loans, performing status 1 and 2)
-- Splits banks into the 11 largest (about half of all exposure, see Q18) and the rest, and compares
-- the pooled NPE ratio of each group. Also reports the correlation between log exposure size and bank NPE ratio.
-- Correction: items 2520502, 2520522 and 2520532 hold a total row per bank and exposure class (counterparty country = 0)
-- plus a breakdown of the same exposure by the bank's top counterparty countries (country <> 0). Summing all rows
-- counts that exposure about twice, so this query keeps country = 0 only.
-- Note: LEI 'XXXXXXXXXXXXXXXXXXXX' is the EBA's "All other banks" aggregate, not a bank. Bank-level measures exclude it
-- (queries that join bank_metadata drop it automatically, because the metadata file stores the code in lower case).
-- Result:
-- The 11 largest banks have a pooled NPE ratio of 2.47%, against 1.81% for the other 96 banks. Across
-- individual banks, the correlation between log exposure size and NPE ratio is close to zero (−0.03). The
-- higher pooled figure for the largest banks comes from a few large banks with high NPE ratios, not from a
-- general link between size and risk.
with exposure as (
    select lei_code, sum(amount) as exposure
    from credit where period = '202506' and item = '2520502' and country = 0 and lei_code <> 'XXXXXXXXXXXXXXXXXXXX' group by lei_code
),
loans as (
    select lei_code,
           sum(amount) as loans_gross,
           sum(case when pref_status = 2 then amount end) as npe
    from credit
    where period = '202506' and item = '2520603' and pref_status in (1, 2)
    group by lei_code
),
joined as (
    select exposure.lei_code, exposure.exposure, loans.loans_gross, loans.npe,
           row_number() over (order by exposure.exposure desc) as size_rank
    from exposure
    inner join loans on loans.lei_code = exposure.lei_code
    where loans.loans_gross > 0
)
select case when size_rank <= 11 then 'largest 11 banks' else 'other banks' end as bank_group,
       count(*) as banks,
       sum(npe) / sum(loans_gross) * 100 as pooled_npe_ratio_pct,
       avg(npe / loans_gross * 100) as simple_average_npe_ratio_pct
from joined
group by 1
union all
select 'correlation: ln(exposure) vs bank NPE ratio', count(*),
       corr(ln(exposure), npe / loans_gross), null
from joined;


-- ====================================================================================================
-- Stress model inputs
-- ====================================================================================================

-- Q24 | What is each bank's non-performing exposure ratio? (bank-level version of Q23)
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603
with bybank as (
    select item, credit.pref_status, prefstatus_metadata.label, credit.lei_code, bank_metadata.name, sum(amount) as bankwise
    from credit
    inner join bank_metadata on bank_metadata.lei_code = credit.lei_code
    inner join prefstatus_metadata on prefstatus_metadata.pref_status = credit.pref_status
    where period = '202506' and item = '2520603' and credit.pref_status in ('1', '2')
    group by item, credit.pref_status, prefstatus_metadata.label, credit.lei_code, bank_metadata.name
),
total as (
    select item, lei_code, sum(bankwise) as total
    from bybank
    group by item, lei_code
)
select bybank.item, pref_status, label, bybank.lei_code, name, bankwise, total, ((bankwise / total) * 100) as bank_np_pct
from bybank
inner join total on total.item = bybank.item and total.lei_code = bybank.lei_code
where pref_status = 2
order by bank_np_pct desc;

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

-- Q26 | Combine total assets, NPE ratio and CET1 ratio into one reference table (shortlist for the stress test)
-- Period: 202506 (Jun 2025) | Item(s): 2521010 (total assets), 2520603 (loans), 2520140 (CET1 ratio)
-- Result:
-- Combines Q24, Q25 and total assets (item 2521010). Used to shortlist banks for the stress test.
with t as (
    select distinct oth.item, oth.label, oth.lei_code, bank_metadata.name
    from oth
    inner join bank_metadata on bank_metadata.lei_code = oth.lei_code
    where period = '202506' and item in ('2521010')
),
exposure as (
    select item, lei_code, sum(amount) as exp_total
    from oth
    where period = '202506' and item = '2521010'
    group by item, lei_code
),
prefstatus as (
    select lei_code, sum(amount) as exp_prefstatus
    from credit
    where period = '202506' and item = '2520603' and pref_status in ('1', '2')
    group by lei_code
),
npe as (
    select lei_code, sum(amount) as npe
    from credit
    where period = '202506' and item = '2520603' and pref_status = 2
    group by lei_code
),
nperatio as (
    select npe.lei_code, ((npe / exp_prefstatus) * 100) as nperatio
    from npe
    inner join prefstatus on prefstatus.lei_code = npe.lei_code
),
cet1 as (
    select lei_code, amount as cet1ratio
    from oth
    where period = '202506' and item = '2520140'
)
select t.item, label, t.lei_code, name, exp_total, nperatio, cet1ratio
from t
inner join exposure on exposure.item = t.item and exposure.lei_code = t.lei_code
inner join nperatio on nperatio.lei_code = t.lei_code
inner join cet1 on cet1.lei_code = t.lei_code
order by t.item, name;

-- Q26b | Provision coverage of performing and non-performing loans, per bank
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520603 (gross carrying amount), 2520613 (impairment and provisions)
with c as (
    select item, pref_status, lei_code, amount
    from credit
    where period = '202506' and item in ('2520603', '2520613') and pref_status in ('1', '2')
),
t as (
    select lei_code,
           sum(case when item = '2520603' and pref_status = 1 then amount else 0 end) as gross_p,
           sum(case when item = '2520613' and pref_status = 1 then amount else 0 end) as provision_p,
           sum(case when item = '2520603' and pref_status = 2 then amount else 0 end) as gross_np,
           sum(case when item = '2520613' and pref_status = 2 then amount else 0 end) as provision_np
    from c
    group by lei_code
)
select t.lei_code, gross_p, provision_p, round((provision_p / nullif(gross_p, 0)) * 100, 3) as coverage_p,
       gross_np, provision_np, round((provision_np / nullif(gross_np, 0)) * 100, 3) as coverage_np
from t;

-- Q26c | CET1 capital and total risk exposure amount (RWA), per bank
-- Period: 202506 (Jun 2025) | Units: EUR mn | Item(s): 2520102 (CET1 capital), 2520138 (total RWA)
-- Result:
-- Items 2520102 and 2520138, the capital inputs of the stress-test model.
select item, label, lei_code, amount
from oth
where period = '202506' and item in ('2520102', '2520138')
order by item;

-- Q33 | One row per stress-model bank with every input the model uses (feeds EBA_stress_test_model.xlsx, sheet Bank Inputs)
-- Period: 202506 (Jun 2025) | Units: EUR mn; CET1 ratio is a decimal (0.13 = 13%)
-- Items: 2521010 total assets, 2520138 RWA, 2520102 CET1 capital, 2520140 CET1 ratio,
--        2520332 profit before tax, 2520333 profit after tax (oth; half-year cumulative, n_quarters = 2);
--        2520603 gross loans by Perf_Status 1 and 2, 2520613 provisions on non-performing loans (credit, NPE sheet)
-- Kommuninvest is extracted for reference; the model excludes it from the stress run (assumption A16).
-- Result:
-- The output is pasted as values into the Bank Inputs sheet of EBA_stress_test_model.xlsx; the sheet's
-- CET1 ratio check column (CET1 capital ÷ RWA) reproduces the reported ratio for every bank.
with banks as (
    select lei_code, name
    from bank_metadata
    where lei_code in (
        '5493006QMFDDMYWIAM13', -- Banco Santander
        '529900S9YO2JHTIIDG38', -- BAWAG Group
        'R0MUWSFPU8MPRO8K5P83', -- BNP Paribas
        '2138008AVF4W7FMW8W87', -- CEC Bank
        '851WYGNLUQLFZBSYGB56', -- Commerzbank
        '7LTWFZYICNSX8D621K86', -- Deutsche Bank
        'FR969500TJ5KRTCJQWXH', -- Groupe Credit Agricole
        'F0HUI1NY1AZMJMD8LP67', -- HSBC Continental Europe
        '549300NYKK9MWM7GGW15', -- ING Groep
        'EV2XZWMLLXF2QRX0CD47', -- Kommuninvest (reference only)
        '549300C9KPZR0VZ16R05', -- Morgan Stanley Europe Holding SE
        '485100FX5Y9YLAQLNP12'  -- Revolut Holdings Europe
    )
),
o as (
    select lei_code,
           sum(case when item = 2521010 then amount end) as total_assets,
           sum(case when item = 2520138 then amount end) as rwa,
           sum(case when item = 2520102 then amount end) as cet1_capital,
           sum(case when item = 2520140 then amount end) as cet1_ratio,
           sum(case when item = 2520332 then amount end) as pbt_h1,
           sum(case when item = 2520333 then amount end) as pat_h1
    from oth
    where period = 202506 and item in (2521010, 2520138, 2520102, 2520140, 2520332, 2520333)
    group by lei_code
),
c as (
    select lei_code,
           sum(case when item = 2520603 and pref_status = '1' then amount else 0 end) as performing,
           sum(case when item = 2520603 and pref_status = '2' then amount else 0 end) as non_performing,
           sum(case when item = 2520613 and pref_status = '2' then amount else 0 end) as npe_provisions
    from credit
    where period = 202506 and item in (2520603, 2520613) and pref_status in ('1', '2')
    group by lei_code
)
select banks.lei_code, banks.name,
       o.total_assets, o.rwa, o.cet1_capital, o.cet1_ratio,
       c.performing, c.non_performing, c.npe_provisions,
       o.pbt_h1, o.pat_h1,
       round(c.non_performing / nullif(c.performing + c.non_performing, 0), 6) as npe_ratio,
       round(c.npe_provisions / nullif(c.non_performing, 0), 6) as npe_coverage
from banks
left join o on o.lei_code = banks.lei_code
left join c on c.lei_code = banks.lei_code
order by banks.name;


-- ====================================================================================================
-- PART 3 | Export for the web page
-- Writes the compact tables in docs/data/. Each applies the same filters as the queries cited in its comment.
-- ====================================================================================================

-- banks.csv | one row per bank (dimension)
\copy (select lei_code, name, country as country_code, desc_country as country from bank_metadata order by name) to 'docs/data/banks.csv' with (format csv, header, encoding 'UTF8')

-- countries.csv | one row per bank home country (dimension)
\copy (select distinct country as country_code, desc_country as country from bank_metadata order by country) to 'docs/data/countries.csv' with (format csv, header, encoding 'UTF8')

-- bank_exposure.csv | Q4–Q12, Q17–Q19, Q29, Q30 | period 202506, country-total rows (country = 0) of the three anchor items per bank.
-- is_named_bank = false marks the EBA "All other banks" aggregate, which bank-level measures exclude.
\copy (select c.lei_code, c.nsa as country_code, case when c.lei_code <> 'XXXXXXXXXXXXXXXXXXXX' then 'TRUE' else 'FALSE' end as is_named_bank, round(sum(case when item = 2520502 then amount else 0 end)::numeric, 2) as original_exposure, round(sum(case when item = 2520522 then amount else 0 end)::numeric, 2) as exposure_value, round(sum(case when item = 2520532 then amount else 0 end)::numeric, 2) as risk_exposure_amount from credit c where period = 202506 and item in (2520502, 2520522, 2520532) and c.country = 0 group by c.lei_code, c.nsa order by original_exposure desc) to 'docs/data/bank_exposure.csv' with (format csv, header)

-- sector.csv | Q16, Q22b, Q27 | item 2521301 Perf_Status 0 (total) and 2 (non-performing), 2521302 impairment; NACE 1–19 only
\copy (select n.nace_codes as nace_code, n.label as sector, round(sum(case when c.item = 2521301 and c.pref_status = 0 then amount else 0 end)::numeric, 2) as gross_carrying_amount, round(sum(case when c.item = 2521301 and c.pref_status = 2 then amount else 0 end)::numeric, 2) as non_performing, round(sum(case when c.item = 2521302 then amount else 0 end)::numeric, 2) as accumulated_impairment from credit c join nace_metadata n on n.nace_codes = c.nace_codes where c.period = 202506 and c.item in (2521301, 2521302) and c.nace_codes <> 0 group by n.nace_codes, n.label order by n.nace_codes) to 'docs/data/sector.csv' with (format csv, header, encoding 'UTF8')

-- country_asset_quality.csv | Q20b, Q23, Q28 | item 2520603 Perf_Status 1 and 2, item 2520613 Perf_Status 2, by bank home country
\copy (select nsa as country_code, round(sum(case when item = 2520603 and pref_status = 1 then amount else 0 end)::numeric, 2) as performing, round(sum(case when item = 2520603 and pref_status = 2 then amount else 0 end)::numeric, 2) as non_performing, round(sum(case when item = 2520613 and pref_status = 2 then amount else 0 end)::numeric, 2) as npe_provisions from credit where period = 202506 and item in (2520603, 2520613) and pref_status in (1, 2) group by nsa order by nsa) to 'docs/data/country_asset_quality.csv' with (format csv, header)

-- npe_trend.csv | Q31 | all four periods
\copy (select period, count(distinct lei_code) as banks_reporting, round(sum(case when pref_status = 1 then amount else 0 end)::numeric, 2) as performing, round(sum(case when pref_status = 2 then amount else 0 end)::numeric, 2) as non_performing from credit where item = 2520603 and pref_status in (1, 2) group by period order by period) to 'docs/data/npe_trend.csv' with (format csv, header)

-- stress_results.csv is exported from EBA_stress_test_model.xlsx (sheet Stress), not from SQL.
