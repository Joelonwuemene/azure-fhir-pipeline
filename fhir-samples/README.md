# FHIR Samples

This folder contains reference examples showing both sides of the HL7 v2.x to FHIR R4 transformation pipeline.

## Files

| File | Description |
|---|---|
| `sample-oru-r01.hl7` | Synthetic HL7 v2.5 ORU^R01 lab result message (Comprehensive Metabolic Panel) |
| `patient.json` | FHIR R4 Patient resource — transformation output |
| `observation.json` | FHIR R4 Observation resource (LOINC-coded lab result) |
| `diagnosticreport.json` | FHIR R4 DiagnosticReport resource referencing Patient and Observation |

## What These Demonstrate

The `sample-oru-r01.hl7` file is a representative inbound message processed by the pipeline. The FHIR JSON files are the corresponding output resources persisted in Azure Health Data Services (`<your-fhir-service>`) after passing through the validation quality gate.

LOINC codes used in these samples are validated against the FHIR R4 specification and loinc.org.

> All patient data in these files is fully synthetic. No real patient identifiers are present.
