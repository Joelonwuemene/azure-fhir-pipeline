# Project Scope and Limitations

## What This Project Is

This is a 10-week self-directed portfolio build demonstrating end-to-end architecture decision-making across Azure healthcare integration. The goal was breadth and depth of architectural reasoning across a realistic domain: HIPAA-compliant HL7 v2.x to FHIR R4 transformation on Azure Health Data Services.

It is not a production system. It was never designed to be. Evaluating it against production readiness criteria produces accurate findings that are largely beside the point.

The relevant evaluation question is: does the person who built this understand what production would require, and can they explain why each gap exists and how they would close it?

The answer to both is yes. This document addresses each limitation directly.

---

## Scope Decisions

### Testing

There are no automated tests in this repository. This was a deliberate scope decision, not an oversight.

Integration tests for this pipeline require live Azure infrastructure: a running FHIR service, a provisioned Service Bus queue, a deployed Function App, and valid OAuth2 tokens. Running that infrastructure continuously in CI costs money and was outside the budget constraints of a lab project ($5-10/month total target).

Unit tests for the validation Function were deprioritised in favour of pipeline breadth across 10 architectural domains. The tradeoff was explicit: demonstrate end-to-end architecture decisions across FHIR transformation, HIPAA compliance, SMART on FHIR, bulk export, IaC, and CI/CD rather than deep testing of a single component.

In a production context, the testing strategy would be:

- **Unit tests**: pytest with mocked FHIR responses for the validation Function. Input: raw HL7 message. Assertions: correct OperationOutcome severity, correct FHIR resource structure, correct dead-letter routing on validation failure.
- **Integration tests**: Postman collection with Newman runner, triggered post-deploy, pushing a known HL7 message through the Service Bus queue and asserting the resulting FHIR resource exists in the store with correct LOINC codes and patient reference.
- **Smoke test**: replace the current `/metadata` health check with an end-to-end queue injection test, asserting a Patient and Observation resource are created within a defined SLA window.

The existing Postman collection in `tests/postman/` contains the OAuth2 token flow and FHIR endpoint assertions used during manual validation. The gap is automation, not knowledge of what to test.

---

### Azure Health Data Services Not in Bicep CI/CD

`infrastructure/bicep/ahds.bicep` contains a reference template but was not deployed via CI/CD. The AHDS workspace was provisioned manually during initial lab setup.

Two reasons:

1. **RBAC propagation timing.** `$convert-data` requires the FHIR Data Converter role in addition to FHIR Data Contributor. In the lab environment, RBAC propagation took up to 5 minutes after Bicep deployment, causing the CI/CD pipeline to fail the smoke test consistently. Sequencing infrastructure deployment with dependent role assignments in a single pipeline requires either a sleep step (fragile) or a two-stage pipeline with a manual gate (out of scope for this build).

2. **AHDS workspace naming constraint.** Workspace names must be lowercase alphanumeric with no hyphens, which is not enforced at authoring time and caused initial deployment failures. The reference template in `ahds.bicep` is correct and deployable. It was not wired into the pipeline because the RBAC timing issue was not resolved within the lab window.

In a production context, the correct pattern is a two-stage pipeline: infrastructure deployment in Stage 1, role assignment propagation confirmed via `az role assignment list` polling in Stage 2, application deployment and smoke test in Stage 3.

---

### Function App Not Deployed via CI/CD

The GitHub Actions pipeline in `.github/workflows/` deploys infrastructure via Bicep. Function App code changes require a manual `func azure functionapp publish` step.

This was an explicit scope boundary for Week 10. The IaC and CI/CD work focused on infrastructure deployment, policy gates, and FHIR CapabilityStatement validation. Application code deployment was documented as the natural next step but not implemented.

In a production context, the pipeline would add a `deploy-functions` job after the infrastructure job, using `Azure/functions-action@v1` with the Function App name and publish profile stored in GitHub Secrets or retrieved via OIDC.

---

### No Retry Logic in the Validation Function

The validation Function sends messages to the dead-letter queue on any non-2xx response from the FHIR service, including transient 503s. There is no exponential backoff.

This was an acceptable simplification for a lab environment with no SLA. The architectural decision to dead-letter on validation failure rather than retry was intentional: a FHIR write that fails validation should not be retried automatically, because the failure is typically a data quality issue, not a transient infrastructure issue. The distinction matters clinically.

Transient infrastructure failures (503, 429) should use retry with backoff before dead-lettering. The correct pattern is: catch HTTP status, if 429 or 503 apply exponential backoff up to 3 attempts, if validation error (400, 422) dead-letter immediately. This distinction was documented but not implemented.

---

### Observability

Log Analytics and KQL audit queries are configured and documented in `docs/architecture/`. Application Insights is not wired into the Function App or Logic App.

Without Application Insights, there are no correlation IDs linking a Service Bus message to its FHIR write outcome across the Logic App, Function, and AHDS. Debugging a silent failure requires manually correlating timestamps across three separate log streams.

In a production context, Application Insights would be provisioned in Bicep, the Function App would be configured with `APPINSIGHTS_INSTRUMENTATIONKEY`, and the Logic App would use the built-in Application Insights connector. Structured logging with a correlation ID generated at Service Bus ingest and passed through each pipeline stage is the correct pattern for a HIPAA audit trail.

---

## Known Infrastructure Gaps

### Network Isolation

All resources in this project have public endpoints. Private endpoints, VNet integration, and NSG rules are not configured.

This is a cost and complexity decision appropriate for a lab environment. A Consumption-tier Logic App cannot be VNet-integrated without upgrading to Standard tier, which is approximately $150/month. Private endpoints for AHDS and Key Vault add cost and require DNS configuration that is disproportionate to a lab build.

The architecture documentation in `docs/architecture/architecture-overview.md` notes the private endpoint pattern as the production extension. The HIPAA compliance posture of this project rests on Managed Identity, RBAC least-privilege, Key Vault secret management, and audit logging, which are implemented. Network isolation is the documented next layer.

---

### De-identification Key Placeholder

`anonymizationConfig.json` contains `"cryptoHashKey": "REPLACE-WITH-KEYVAULT-REFERENCE"`. The de-identification export pipeline is functional; the cryptographic key is not live-wired to Key Vault.

The correct production pattern is a Key Vault reference in the AHDS de-identification configuration, accessed via the AHDS managed identity. The RBAC chain is documented. The wiring was not completed because the Synapse analytics workspace was deprovisioned before the de-identification pipeline was tested end-to-end.

---

### Synapse Analytics Workspace Deprovisioned

The Synapse workspace used in Week 9 for FHIR bulk export analytics was deleted after that week's lab work to avoid ongoing cost. The OPENROWSET queries in `docs/architecture/openrowset-query.sql` are reference artifacts demonstrating the query pattern against NDJSON exports in ADLS Gen2. They cannot be run against a live endpoint without reprovisioning the workspace.

The ADLS Gen2 storage account (`stadlshipaajoell`) remains active with the `fhir-export` and `anonymization` containers. A new Synapse workspace connected to the existing storage can reproduce the analytics layer in approximately 30 minutes.

---

## What This Project Demonstrates

The gaps above are implementation details that any senior engineer on a real project team would close during a production hardening sprint. None of them represent architectural misunderstanding.

What this project does demonstrate:

- End-to-end architecture decision-making across 10 integrated domains over 10 weeks
- Honest documentation of tradeoffs, constraints, and failure modes alongside successes
- Correct application of HIPAA Security Rule controls at the infrastructure level: Managed Identity, RBAC least-privilege, Key Vault secret management, audit logging, and pipeline validation gates
- Production-accurate FHIR R4 resource modeling: correct LOINC codes, valid resource references, AHDS-specific constraints understood and documented
- IaC and CI/CD patterns: Bicep modules, GitHub Actions with OIDC, Azure Policy deny gates, CapabilityStatement validation
- Incident documentation: runaway message loop root cause analysis, Logic App header stripping, RBAC propagation timing, ADLS Gen2 HNS constraint. These are real failure modes, not synthetic exercises.

The architecture decisions record (ADRs in `docs/architecture/`) documents context, tradeoffs, and consequences for each major decision. That is the correct artifact for evaluating whether someone can make and defend architecture decisions under constraint.

---

*This document was written in response to a structured external portfolio review conducted April 2026. The reviewer's findings were accurate. The explanations above are the ones that belong in the repo.*
