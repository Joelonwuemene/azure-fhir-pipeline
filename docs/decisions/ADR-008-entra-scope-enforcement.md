# ADR-008: Entra ID as SMART Scope Enforcement Boundary

**Status:** Accepted  
**Date:** 2026-01  
**Component:** SMART on FHIR / access control

## Context

SMART on FHIR defines a scope model (`patient/*.read`, `user/*.*`, `system/*.*`) for controlling access to FHIR resources. The question is where in the stack these scopes are enforced: at the FHIR service layer (per-request resource-level enforcement) or at the identity layer (token issuance).

## Decision

SMART scope enforcement is implemented at Entra ID token issuance, not at the FHIR service resource layer.

## Rationale

Azure Health Data Services does not enforce SMART scopes at the resource level. The FHIR service validates that the request bearer token is a valid Entra ID token with the correct audience claim. It does not inspect the scope claims within the token to restrict which resource types or operations are permitted.

Scope enforcement happens at token issuance: Entra ID will not issue a token containing scope grants beyond what was explicitly authorised for the application registration. If a client requests `patient/*.write` but the app registration only permits `patient/*.read`, the issued token will not carry the write scope. The FHIR service accepts the token, but the client cannot request a token with elevated permissions it was not granted.

The practical consequence is that access control in this architecture is managed via Entra ID app registration scope configuration and RBAC role assignments on the FHIR service, not via FHIR-layer resource-level policy.

## Consequences

- FHIR RBAC roles (`FHIR Data Reader`, `FHIR Data Writer`, `FHIR Data Contributor`) are the primary access control mechanism at the service level. These must be assigned to the correct Managed Identity or service principal.
- Scope claims in access tokens are informational about what the client was authorised to request. They do not substitute for RBAC.
- Claims about SMART scope enforcement in documentation or client-facing materials must be accurate: "the access token will not carry scope grants beyond what was explicitly authorized" is correct. "The FHIR service enforces SMART scopes at the resource level" is not correct for AHDS and must not be stated.
- Postman-based SMART flow testing simulates the token acquisition and scope request process. It does not validate against a real EHR launch context. This distinction must be maintained in any demo or portfolio claim.
