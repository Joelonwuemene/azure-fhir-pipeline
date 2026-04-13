# Phase 04 - FHIR Transformation via AHDS

## Goal
Transform HL7 v2.x ORU_R01 messages to FHIR R4 resources using the Azure Health Data Services $convert-data API and the default HL7v2 Liquid template.

## Key Azure Resources
- AHDS workspace: `ahdshipaajoell` (lowercase alphanumeric, no hyphens — enforced constraint)
- FHIR service: `fhirhipaajoell`
- Template: `microsofthealth/hl7v2templates:default`, rootTemplate: `ORU_R01`

## Key Constraints Documented
- AHDS workspace name must be lowercase alphanumeric with no hyphens
- RBAC role `FHIR Data Converter` required — propagation takes up to 5 minutes
- `templateCollectionReference` is required, not optional
- Conditional references not supported in AHDS resource fields — use direct server IDs

## Outcome
ORU_R01 to FHIR R4 bundle transformation confirmed. Output bundle contains Patient, Observation, and DiagnosticReport resources.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
