-- ============================================================
-- Azure FHIR Pipeline - Week 9: Bulk Export Analytics
-- File:    openrowset-query.sql
-- Author:  Joel Onwuemene
-- Purpose: Query FHIR R4 NDJSON bulk export files in ADLS Gen2
--          using Synapse Analytics serverless SQL pool (OPENROWSET)
-- Source:  $export output from fhirhipaajoell (Azure Health Data Services)
-- Region:  West US 2 (Synapse workspace, W9 lab - since deleted)
-- ============================================================

-- ------------------------------------------------------------
-- SECTION 1: Patient Resources
-- Reads Patient NDJSON exported from FHIR $export operation
-- Confirmed output: 3 Patient records
-- ------------------------------------------------------------

SELECT
    JSON_VALUE(doc, '$.id')            AS patient_id,
    JSON_VALUE(doc, '$.resourceType')  AS resource_type,
    JSON_VALUE(doc, '$.name[0].family') AS family_name,
    JSON_VALUE(doc, '$.name[0].given[0]') AS given_name,
    JSON_VALUE(doc, '$.birthDate')     AS birth_date,
    JSON_VALUE(doc, '$.gender')        AS gender
FROM OPENROWSET(
    BULK 'https://<stadlshipaajoell>.dfs.core.windows.net/<fhir-export>/Patient/*.ndjson',
    FORMAT = 'CSV',
    FIELDQUOTE = '0x0b',
    FIELDTERMINATOR = '0x0b',
    ROWTERMINATOR = '0x0a'
) WITH (doc NVARCHAR(MAX)) AS rows;

-- ------------------------------------------------------------
-- SECTION 2: Observation Resources
-- Reads Observation NDJSON exported from FHIR $export operation
-- Confirmed output: 2 Observation records (lab results, LOINC-coded)
-- ------------------------------------------------------------

SELECT
    JSON_VALUE(doc, '$.id')                            AS observation_id,
    JSON_VALUE(doc, '$.resourceType')                  AS resource_type,
    JSON_VALUE(doc, '$.status')                        AS status,
    JSON_VALUE(doc, '$.subject.reference')             AS patient_reference,
    JSON_VALUE(doc, '$.code.coding[0].system')         AS coding_system,
    JSON_VALUE(doc, '$.code.coding[0].code')           AS loinc_code,
    JSON_VALUE(doc, '$.code.coding[0].display')        AS test_name,
    JSON_VALUE(doc, '$.valueQuantity.value')           AS result_value,
    JSON_VALUE(doc, '$.valueQuantity.unit')            AS result_unit,
    JSON_VALUE(doc, '$.effectiveDateTime')             AS effective_date
FROM OPENROWSET(
    BULK 'https://<stadlshipaajoell>.dfs.core.windows.net/<fhir-export>/Observation/*.ndjson',
    FORMAT = 'CSV',
    FIELDQUOTE = '0x0b',
    FIELDTERMINATOR = '0x0b',
    ROWTERMINATOR = '0x0a'
) WITH (doc NVARCHAR(MAX)) AS rows;

-- ------------------------------------------------------------
-- SECTION 3: De-identified Patient Export (W9 Anonymization)
-- Queries the output of the de-identified $export run
-- Confirmed: name and birthDate fields are redacted
-- CRYPTOHASH tags applied per anonymizationConfig.json
-- ------------------------------------------------------------

SELECT
    JSON_VALUE(doc, '$.id')                    AS patient_id,
    JSON_VALUE(doc, '$.resourceType')          AS resource_type,
    JSON_VALUE(doc, '$.name[0].family')        AS family_name_redacted,   -- Expected: NULL or redacted
    JSON_VALUE(doc, '$.birthDate')             AS birth_date_redacted,     -- Expected: NULL or redacted
    JSON_VALUE(doc, '$.gender')                AS gender,
    JSON_VALUE(doc, '$.meta.tag[0].code')      AS anonymization_tag        -- Expected: CRYPTOHASH
FROM OPENROWSET(
    BULK 'https://<stadlshipaajoell>.dfs.core.windows.net/<fhir-export>/Patient/*.ndjson',
    FORMAT = 'CSV',
    FIELDQUOTE = '0x0b',
    FIELDTERMINATOR = '0x0b',
    ROWTERMINATOR = '0x0a'
) WITH (doc NVARCHAR(MAX)) AS rows;

-- ------------------------------------------------------------
-- NOTES
-- 1. Replace <your-adls-account> and <container> with your
--    actual ADLS Gen2 storage account name and container path.
-- 2. The Synapse workspace used in W9 (West US 2, serverless)
--    has been deleted to control lab costs.
-- 3. ADLS Gen2 hierarchical namespace is required for W9 bulk
--    export. Upgrade from flat namespace is a pre-requisite.
-- 4. Synapse serverless SQL requires the Storage Blob Data
--    Reader role on the ADLS Gen2 account (Managed Identity).
-- 5. OPENROWSET NDJSON pattern: FIELDQUOTE=0x0b,
--    FIELDTERMINATOR=0x0b, ROWTERMINATOR=0x0a is the standard
--    approach for reading newline-delimited JSON in Synapse.
-- ------------------------------------------------------------
