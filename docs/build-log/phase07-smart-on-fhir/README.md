# Phase 07 - SMART on FHIR Authentication

## Goal
Implement the SMART App Launch authorization flow against Azure Health Data Services using Entra ID and validate scope enforcement behavior.

## Key Azure Resources
- Entra ID app: `fhir-client-joel`
- SMART scopes: `patient/*.read`, `launch/patient`
- Postman environment: `fhir-env`

## Key Architecture Finding
AHDS does not enforce SMART scopes at the FHIR resource level. Entra ID enforces scope at token issuance only. The FHIR server accepts any valid Bearer token from the configured tenant. Scope enforcement must be designed at the Entra ID application permission and token issuance policy level.

## Outcome
SMART token flow working end-to-end between Postman and AHDS. jwt.ms confirmed correct scope claims in token. Architecture boundary documented accurately — Postman simulates EHR launch token flow but does not validate against a real EHR initiating the flow.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
