# Phase 09 - Bulk Export and Analytics

## Goal
Implement FHIR bulk export ($export) to Azure Data Lake, de-identify the output, and query it via Synapse Serverless — validating the full analytics pipeline from FHIR server to SQL query.

## Key Azure Resources
- FHIR service: `fhirhipaajoell` ($export source)
- ADLS Gen2: `stadlshipaajoell` (hierarchical namespace enabled)
- De-identification config: `anonymizationConfig.json` (CRYPTOHASH + redact rules)
- Synapse Serverless: West US 2 (deleted post-validation to control cost)

## Outcome
- $export: 202 Accepted + 200 OK confirmed. 3 Patient + 2 Observation NDJSON records validated
- De-identification: `name` and `birthDate` redacted with CRYPTOHASH across all 3 Patient records
- Synapse OPENROWSET: 3 rows returned, zero PHI fields in output
- Cost impact: under $0.10. Synapse workspace deleted post-validation

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
