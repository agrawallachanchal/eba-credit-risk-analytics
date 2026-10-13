-- Q1 | List all distinct banks (LEI_Code, Name, Country) from the metadata table.
-- Period: 202506 (Jun 2025) | Units: EUR mn
-- Note: Confirms the bank universe (name, country) the rest of the project is built on.

select distinct metadata.lei_code, metadata.name, metadata.country,
       metadata.desc_country, credit.nsa
from metadata
inner join credit on metadata.lei_code = credit.lei_code;
