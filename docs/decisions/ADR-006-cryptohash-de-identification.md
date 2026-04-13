# ADR-006: CRYPTOHASH De-identification for FHIR Bulk Export

**Status:** Accepted  
**Date:** 2026-01  
**Component:** De-identification pipeline

## Context

The pipeline exports FHIR resources to ADLS Gen2 via the AHDS `$export` operation for downstream analytics in Synapse. Exported data contains PHI. HIPAA Safe Harbor de-identification requires removal or transformation of 18 identifier categories before data can be used for analytics without individual authorisation.

Two AHDS anonymization methods were evaluated: `redact` (removes the field entirely) and `cryptoHash` (replaces the value with a deterministic HMAC-SHA256 hash).

## Decision

Use `cryptoHash` for patient and subject identifiers. Use `redact` for direct identifiers (names, addresses, contact information) where the value has no analytical utility.

## Rationale

**Referential integrity.** Analytics queries across exported FHIR resources require the ability to join Observation and DiagnosticReport resources to their Patient subject. If Patient IDs are redacted, cross-resource joins are impossible. CRYPTOHASH preserves the join key — the hash of a given ID is consistent across all resources in the export — while making the original identifier unrecoverable without the key.

**Key management.** The CRYPTOHASH key is stored in Azure Key Vault and referenced in `anonymizationConfig.json` via the Key Vault reference syntax, not as a hardcoded value. This ensures the de-identification key is managed under the same access control and audit trail as other PHI-adjacent secrets.

**Reversibility boundary.** CRYPTOHASH is not reversible without the key. The key is access-controlled. This satisfies the HIPAA requirement that re-identification requires access controls equivalent to those protecting the original PHI.

## Consequences

- `anonymizationConfig.json` must reference the Key Vault secret using the Azure Key Vault reference syntax. A literal placeholder string in this field will cause the export operation to either error or produce incorrect hashes. This is a deployment-time configuration step, not a code change.
- The CRYPTOHASH key must be rotated on a defined schedule. Rotation produces different hashes for the same input, breaking historical joins. Rotation policy must account for this.
- Synapse OPENROWSET queries on exported NDJSON must use exact file paths. Wildcard paths (`/*.ndjson`) may return no results depending on the export job structure. Use the export manifest to construct exact paths.
