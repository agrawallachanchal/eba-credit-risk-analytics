-- Q33 | One row per stress-model bank with every input the model uses (feeds model/EBA_stress_test_model.xlsx, sheet Bank Inputs)
-- Period: 202506 (Jun 2025) | Units: EUR mn; CET1 ratio is a decimal (0.13 = 13%)
-- Items: 2521010 total assets, 2520138 RWA, 2520102 CET1 capital, 2520140 CET1 ratio,
--        2520332 profit before tax, 2520333 profit after tax (oth; half-year cumulative, n_quarters = 2);
--        2520603 gross loans by Perf_Status 1 and 2, 2520613 provisions on non-performing loans (credit, NPE sheet)
-- Kommuninvest is extracted for reference; the model excludes it from the stress run (assumption A16).

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
