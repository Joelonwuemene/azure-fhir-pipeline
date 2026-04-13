# ADR-004: FHIR Validation Gate Before Store Write

**Status:** Accepted  
**Date:** 2026-01  
**Component:** Data quality and pipeline integrity

## Context

The pipeline transforms HL7 v2.x messages into FHIR R4 resources via the AHDS `$convert-data` operation. The conversion operation can succeed — returning a syntactically valid HTTP 200 response — while producing a FHIR resource that violates R4 profile constraints, contains incorrect LOINC codes, or references non-existent subjects.

The question is where to enforce quality: before the FHIR write, or after via downstream validation and remediation.

## Decision

Enforce FHIR resource validation before every store write. An Azure Function invokes the AHDS `$validate` operation on the converted resource. Any resource that returns a non-informational OperationOutcome is rejected and dead-lettered. It does not reach the FHIR store.

## Rationale

A resource that converts successfully and writes malformed data to a FHIR store creates two distinct problems that post-write remediation cannot easily solve.

**Clinical integrity.** A FHIR store is a source of truth for clinical data. A malformed Observation or DiagnosticReport that persists in the store may be queried, displayed, or acted on before it is identified as invalid. In a clinical environment, acting on a wrong lab value is a patient safety issue, not a data quality issue.

**HIPAA audit exposure.** Under HIPAA, a documented failure to enforce data integrity controls at the point of ingestion is a finding. Post-write remediation implies the pipeline knew validation was possible and deferred it. Pre-write validation closes that gap before it becomes a regulatory exposure.

**Remediation cost.** Correcting a resource after it has been written to a FHIR store requires a versioned update, an audit log entry for the correction, and potentially notification to downstream consumers. Rejecting it before write costs a dead-letter queue entry and a log record.

## Consequences

- The validation gate adds a network round-trip to the pipeline execution path. Observed latency impact is 2-4 seconds per message. Acceptable for a lab result pipeline where throughput is measured in messages per minute, not per second.
- The Azure Function requires Managed Identity with FHIR Data Reader role on the FHIR service. Writer role is not required for the validation function alone.
- OperationOutcome responses from $validate must be parsed to distinguish informational issues (severity: information) from actual failures (severity: error or fatal). Informational outcomes should not block the write.
- Dead-lettered messages must include the OperationOutcome payload as a message property to enable investigation without requiring a separate FHIR query.
