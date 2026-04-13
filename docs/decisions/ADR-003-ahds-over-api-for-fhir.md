# ADR-003: Azure Health Data Services over Azure API for FHIR

**Status:** Accepted  
**Date:** 2026-01  
**Component:** FHIR store

## Context

Two Azure services expose a managed FHIR R4 API: Azure API for FHIR (the original service) and Azure Health Data Services (AHDS), which supersedes it. New deployments must choose between them.

## Decision

Use Azure Health Data Services (AHDS) FHIR service (`Microsoft.HealthcareApis/workspaces/fhirservices`).

## Rationale

Azure API for FHIR (`Microsoft.HealthcareApis/services`) is retired and blocked for new deployments. Any attempt to provision it via Bicep or CLI fails with a resource type unavailability error. AHDS is the current Microsoft-supported path and the only viable option for new implementations.

Beyond the retirement constraint, AHDS provides additional capabilities relevant to this pipeline: native integration with AHDS $export for bulk FHIR data extraction, de-identification pipeline support via `anonymizationConfig.json`, and DICOM service co-location within the same workspace if imaging integration is required in future.

## Consequences

- AHDS workspace names must be lowercase alphanumeric with no hyphens. This is a validation constraint enforced at deployment time and differs from the naming conventions permitted for most other Azure resources.
- The AHDS workspace and FHIR service are two distinct resources. Both must be provisioned. The FHIR service endpoint includes both names: `https://<workspace>-<fhirservice>.fhir.azurehealthcareapis.com`.
- Managed Identity role assignments target the FHIR service resource, not the workspace.
- Any documentation or tooling referencing `Microsoft.HealthcareApis/services` is describing the retired service and should not be followed for new deployments.
