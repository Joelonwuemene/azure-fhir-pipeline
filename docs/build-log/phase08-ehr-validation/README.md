# Week 08 - EHR Integration and Data Quality

## Goal
Implement a FHIR validation quality gate as an Azure Function and wire it into the Logic App pipeline so invalid resources are intercepted before reaching the FHIR server.

## Key Azure Resources
- Azure Function: `func-hipaa-validate-joel` (Python 3.11, Consumption plan, Linux)
- Storage: `stfunchipaajoell`
- Logic App: `la-hipaa-hl7-processor` (updated via Designer only)

## Pipeline Flow
1. Logic App calls validation Function via HTTP POST
2. Function returns FHIR OperationOutcome JSON
3. Condition checks `length(body('Parse_OperationOutcome')?['issue'])` equals zero
4. True branch: FHIR POST to AHDS + complete Service Bus message
5. False branch: dead-letter + Terminate

## Outcome
Validation gate intercepting malformed FHIR resources in testing. Dead-letter queue receiving failed messages without affecting main queue flow. OperationOutcome responses structured per FHIR R4 spec.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
