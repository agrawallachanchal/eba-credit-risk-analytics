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
