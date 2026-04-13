# Phase 05 - End-to-End Pipeline

## Goal
Wire the full message flow from Service Bus trigger through HL7 transformation to FHIR resource persistence in Azure Health Data Services.

## Key Azure Resources
- Logic App: `la-hipaa-hl7-processor` (Consumption tier, East US)
- Service Bus: `sb-hipaa-hl7-joel` queue `hl7-inbound`
- FHIR service: `fhirhipaajoell`

## Key Constraints Documented
- Logic App Designer is the only reliable save method for Consumption tier definition changes
- `ContentData` from Service Bus uses `triggerBody()?['ContentData']` without array index notation
- Content-Type headers require body serialized via `string()` in a Compose action

## Outcome
End-to-end message flow confirmed: Service Bus trigger to FHIR resource persisted in `fhirhipaajoell`. Patient, Observation, and DiagnosticReport resources queryable via FHIR search after pipeline run.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
