# Week 06 - FHIR Search and DiagnosticReport

## Goal
Implement LOINC-coded FHIR R4 resources and validate FHIR search queries including _include, chained parameters, and search modifiers.

## Key Azure Resources
- FHIR service: `fhirhipaajoell`
- Resources created: Patient, Observation (LOINC-coded), DiagnosticReport

## Key Constraints Documented
- All LOINC codes validated against loinc.org before commit — lesson learned from cholesterol/CMP panel mismatch caught during LinkedIn post review
- AHDS does not support conditional references — direct server IDs required

## Outcome
FHIR search queries returning correct resource sets. _include, _revinclude, and chained parameter queries validated in Postman. LOINC codes confirmed against FHIR R4 spec.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
