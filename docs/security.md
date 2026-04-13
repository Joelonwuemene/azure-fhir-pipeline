# Security Architecture

This document describes the security posture of the Azure HIPAA FHIR Pipeline. It covers identity and access control, encryption, audit trail design, and secret management.

## Threat Model Boundary

The pipeline processes HL7 v2.x messages that may contain PHI. PHI enters at the Service Bus queue and must not leave the pipeline boundary unencrypted or un-de-identified. The FHIR store is the authoritative PHI boundary. Any data exported beyond the FHIR service (to ADLS Gen2 or Synapse) must be de-identified before export.

## Identity and Access Control

### Managed Identity

All Azure services in the pipeline authenticate to each other using System-Assigned Managed Identity. No application passwords or client secrets are used for service-to-service communication.

| Service | Identity Type | Role Assignment |
|---|---|---|
| Logic App | System-Assigned MI | Service Bus Data Receiver on `hl7-inbound` queue |
| Logic App | System-Assigned MI | FHIR Data Writer on FHIR service |
| Azure Function | System-Assigned MI | FHIR Data Reader on FHIR service |
| AHDS $export | System-Assigned MI | Storage Blob Data Contributor on ADLS Gen2 |

### FHIR Service RBAC

The FHIR service uses Azure RBAC. Local FHIR RBAC is disabled. All access is controlled via Entra ID role assignments.

| Role | Principal | Purpose |
|---|---|---|
| FHIR Data Writer | Logic App MI | Write transformed FHIR resources |
| FHIR Data Reader | Azure Function MI | $validate operation |
| FHIR Data Exporter | AHDS Export MI | $export bulk operation |

### SMART on FHIR

SMART scope enforcement occurs at Entra ID token issuance. The FHIR service validates bearer token authenticity and audience. Scope-based access restriction is managed via Entra ID app registration configuration. See [ADR-008](decisions/ADR-008-entra-scope-enforcement.md) for the full rationale.

## Encryption

### In Transit

All communication between pipeline components uses TLS 1.2 minimum. Azure-managed endpoints enforce this by default. No plaintext HTTP endpoints are exposed.

### At Rest

| Component | Encryption |
|---|---|
| Service Bus messages | Azure-managed encryption at rest |
| FHIR store (AHDS) | Azure-managed encryption at rest |
| ADLS Gen2 | Azure-managed encryption at rest |
| Key Vault secrets | Azure-managed HSM-backed encryption |

Customer-managed keys (CMK) are not implemented in this reference architecture. For production HIPAA deployments, CMK should be evaluated against key management operational overhead.

## Secret Management

All secrets are stored in Azure Key Vault (`kv-hipaa-phi-*`). No secrets are hardcoded in application code, IaC templates, or configuration files.

| Secret | Key Vault Reference | Consumer |
|---|---|---|
| FHIR service URL | `fhir-url` | Azure Function app setting |
| CRYPTOHASH de-identification key | `anonymization-crypto-key` | anonymizationConfig.json reference |
| Service Bus connection | Managed Identity (no secret) | Logic App connector |

Key Vault access policies grant get and list permissions to consuming service identities only. No broad subscription-level access.

## Audit Trail

All FHIR read and write operations are logged to Log Analytics (`law-hipaa-*`). The following KQL query surfaces all FHIR write operations with their source identity:

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.HEALTHCAREAPIS"
| where OperationName contains "Write" or OperationName contains "Create"
| project TimeGenerated, OperationName, CallerIpAddress, identity_claim_appid_s
| order by TimeGenerated desc
```

Log retention is set to 90 days minimum. Azure Monitor alerts fire within 5 minutes on Logic App failed runs, providing near-real-time visibility into pipeline failures.

## Azure Policy

Azure Policy assignments enforce the following deny-effect controls on the resource group:

- Deny creation of resources without required HIPAA tags (`DataClassification`, `ComplianceFramework`, `Environment`, `Owner`)
- Deny creation of storage accounts without HTTPS-only enforcement
- Deny creation of Key Vaults with public network access enabled

Policy assignment is documented in `iac/policy/hipaa-policy-assignment.json` with all environment-specific identifiers replaced by placeholders.

## Known Limitations

- Customer-managed keys are not implemented.
- Network isolation (Private Endpoints, VNet integration) is not implemented in this reference architecture. In a production deployment, FHIR service and Key Vault should be private endpoint-only.
- The Logic App workflow definition cannot be fully managed as code (see [ADR-002](decisions/ADR-002-logic-app-consumption-designer-save.md)). Manual Designer configuration steps are required.
