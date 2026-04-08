# Azure FHIR Pipeline

**HL7 v2 to FHIR R4 Integration Pipeline on Azure**

A HIPAA-aligned, cloud-native integration pipeline built as a 12-week self-directed portfolio project demonstrating end-to-end healthcare interoperability on Microsoft Azure. The pipeline ingests HL7 v2.x ORU^R01 lab messages, transforms them to FHIR R4 resources, and delivers validated, queryable clinical data through Azure Health Data Services.

---

## Architecture Overview

```
HL7 v2 Source
     |
     v
[Service Bus Queue: hl7-inbound]
     |
     v
[Logic App: la-hipaa-hl7-processor]  (Consumption tier, East US)
     |
     |-- HTTP POST --> [Azure Function: func-hipaa-validate-joel]
     |                   (Python 3.11, FHIR R4 validation)
     |                        |
     |              Pass --> FHIR POST --> [Azure Health Data Services]
     |              Fail --> Dead-letter queue + Terminate
     |
     v
[FHIR Service: fhirhipaajoell]
     |
     |-- FHIR Search (Patient, Observation, DiagnosticReport)
     |-- Bulk $export --> ADLS Gen2 --> NDJSON
     |-- De-identification export (CRYPTOHASH)
     v
[Log Analytics: law-hipaa-joel]  (audit trail, KQL queries)
```

**SMART on FHIR** token flow implemented via Entra ID app registration (`fhir-client-joel`). Note: Azure Health Data Services does not enforce SMART scopes at the resource level. Scope enforcement occurs at token issuance in Entra ID only.

---

## Azure Resource Inventory

| Resource | Name | Type | Region |
|---|---|---|---|
| Resource Group | `rg-hipaa-apps` | Resource Group | East US |
| AHDS Workspace | `ahdshipaajoell` | Health Data Services | East US |
| FHIR Service | `fhirhipaajoell` | FHIR R4 | East US |
| Logic App | `la-hipaa-hl7-processor` | Consumption | East US |
| Azure Function | `func-hipaa-validate-joel` | Python 3.11, Linux | East US |
| Function Storage | `stfunchipaajoell` | Storage Account | East US |
| Service Bus | `sb-hipaa-hl7-joel` | Standard tier | East US |
| Queue | `hl7-inbound` | Service Bus Queue | East US |
| Key Vault | `kv-hipaa-phi-joel` | Key Vault | East US |
| Log Analytics | `law-hipaa-joel` | Log Analytics Workspace | East US |
| Entra ID App | `fhir-client-joel` | App Registration | Global |
| Action Group | `ag-hipaa-pipeline-failures` | Monitor Action Group | Global |
| Monitor Alert | `alert-la-hipaa-failed-runs-v2` | Metric Alert, Sev 2 | East US |

**HIPAA Tags applied to all resources:**

| Tag | Value |
|---|---|
| DataClassification | PHI |
| ComplianceFramework | HIPAA |
| Environment | Lab |
| Owner | Joel |

---

## Tech Stack

- **Cloud:** Microsoft Azure (East US)
- **Integration:** Azure Logic Apps (Consumption), Azure Service Bus
- **Compute:** Azure Functions (Python 3.11, Linux, Consumption plan)
- **Clinical Data:** Azure Health Data Services, FHIR R4
- **Standards:** HL7 v2.x (ORU^R01), FHIR R4, SMART on FHIR, LOINC
- **Auth:** Microsoft Entra ID (OIDC, OAuth 2.0)
- **Observability:** Azure Monitor, Log Analytics, KQL
- **Security:** Azure Key Vault, RBAC, Azure Policy
- **Testing:** Postman, jwt.ms
- **IaC:** Bicep (Week 10, in progress)
- **CI/CD:** GitHub Actions (Week 10, in progress)

---

## Weekly Progress

### Week 1: Azure Core Architecture

Provisioned all foundational resources in `rg-hipaa-apps` (East US): AHDS workspace and FHIR R4 service, Key Vault, Log Analytics workspace, Service Bus namespace and `hl7-inbound` queue. Applied HIPAA compliance tags across all resources using a consistent tagging schema.

**Key decision:** Chose Azure Health Data Services (managed FHIR) over self-hosted HAPI FHIR to eliminate server management overhead. AHDS workspace names must be lowercase alphanumeric with no hyphens.

---

### Week 2: HIPAA Compliance Controls

Implemented layered alerting and cost governance. Configured Azure Monitor alert (`alert-la-hipaa-failed-runs-v2`, Severity 2) triggering within 5 minutes on Logic App failed runs exceeding 5 in a 5-minute window. Action group `ag-hipaa-pipeline-failures` routes alerts to email and SMS.

Configured an $80 budget with thresholds at 50%, 80%, and 99%.

**Key learning:** Budget alerts have a 12-24 hour billing lag and cannot serve as real-time protection. Azure Monitor metric alerts on Logic App run failures are the correct real-time mechanism.

---

### Week 3: Integration Services and HL7

Built the Logic App orchestration layer (`la-hipaa-hl7-processor`) with a Service Bus trigger on `hl7-inbound`. Established the HL7 v2 routing pattern using the AHDS `$convert-data` endpoint with `templateCollectionReference: microsofthealth/hl7v2templates:default`.

**Key learnings:**

- `ContentData` from Service Bus on Consumption tier uses `triggerBody()?['ContentData']` without array index notation.
- Content-Type headers must be set via a Compose action using `string()` to serialize the body. Without this, Logic Apps silently strips the header.
- Logic App Designer is the only reliable save mechanism for Consumption tier definition changes. Code View and CLI saves do not reliably persist to the live definition.

---

### Week 4: FHIR Transformation

Implemented the `$convert-data` transformation pipeline, converting ORU^R01 lab messages to FHIR R4 Patient, Observation, and DiagnosticReport resources. Validated FHIR resource structure against the HL7 FHIR R4 specification.

**Key learning:** AHDS does not support conditional references in resource fields. Direct server-assigned resource IDs must be used.

---

### Week 5: End-to-End Pipeline

Connected all components into a single pipeline: Service Bus ingest, Logic App orchestration, `$convert-data` transformation, and FHIR POST to Azure Health Data Services. Validated the full message flow from raw HL7 to persisted FHIR resource.

---

### Week 6: FHIR Search and DiagnosticReport

Implemented FHIR search queries against Patient and Observation resources. Built DiagnosticReport resources with LOINC-coded panel references.

**Key learning:** Established a pre-publication validation process for any clinical data claims. FHIR resource structure and LOINC code assignments must be validated against the FHIR R4 specification and LOINC User Guide before any public post or documentation. Incorrect LOINC codes in DiagnosticReport panels are a credibility risk in a clinical context.

---

### Week 7: Logic App Enhancement and SMART on FHIR

Registered Entra ID application (`fhir-client-joel`) and implemented the SMART on FHIR authorization flow. Tested the token acquisition and FHIR API request sequence using Postman (environment: `fhir-env`) and validated token claims using jwt.ms.

**Scope enforcement clarification:** Azure Health Data Services does not enforce SMART scopes at the resource level. Entra ID enforces scope at token issuance only. The FHIR service accepts any valid bearer token issued for the correct audience.

**Postman testing scope:** Postman was used to simulate the SMART EHR launch token flow. This does not represent a real EHR system initiating the launch sequence.

**Key learning (runaway loop incident):** A runaway message loop occurred when `rootTemplate` was incorrectly set to `ADT_A01` instead of `ORU_R01`, combined with a dead-letter action that re-queued failed messages back to the main queue. Both the correct template reference and a proper dead-letter routing action are required.

---

### Week 8: EHR Integration and Data Quality / Validation

Deployed an Azure Function (`func-hipaa-validate-joel`, Python 3.11, Linux, Consumption plan) to perform FHIR R4 OperationOutcome-based validation before any FHIR POST. The validation quality gate design calls the function via HTTP POST, parses the OperationOutcome response, and routes to FHIR POST on pass or Service Bus dead-letter on fail.

**Status:** The validation function is deployed and independently verified. Wiring of the quality gate into `la-hipaa-hl7-processor` via Logic App Designer is pending resolution of an Azure Portal incident (Designer and Code View loading indefinitely in East US). The Logic App remains disabled throughout this week.

---

### Week 9: FHIR Analytics, Bulk Export, and De-identification

Executed the FHIR `$export` operation against Azure Health Data Services. Confirmed 202 Accepted + polling to 200 OK. Exported Patient (3 resources) and Observation (2 resources) as NDJSON to ADLS Gen2.

Provisioned Azure Synapse Analytics (West US 2, serverless, HIPAA tags) and queried exported NDJSON using `OPENROWSET`, confirming 3 rows returned.

Executed a de-identification export (200 OK). Confirmed `name` and `birthDate` fields were redacted. `CRYPTOHASH` transformation tags applied via `anonymizationConfig.json`.

Documented CDS Hooks integration patterns as an architectural reference.

**Note:** Synapse Analytics workspace was deleted after Week 9 validation to manage lab costs. Export pipeline and query patterns are documented in `docs/` and `src/fhir/analytics/`.

---

## Lessons Learned

Real builds encounter real problems. A dedicated record of every significant incident, root cause, and resolution is documented in [docs/lessons-learned.md](docs/lessons-learned.md).

Incidents covered across W1-W9 include Logic App silent header stripping, budget alert billing lag, the W7 runaway message loop, SMART on FHIR scope enforcement misattribution, AHDS naming constraints, RBAC propagation delays, and the W8 Azure Portal incident.

---

## Compliance Posture

| Control | Implementation |
|---|---|
| PHI tagging | Azure Policy, applied to all resources |
| Secrets management | Azure Key Vault (`kv-hipaa-phi-joel`) |
| Audit logging | Log Analytics (`law-hipaa-joel`), KQL queries |
| Failed run alerting | Azure Monitor, Severity 2, 5-minute window |
| Budget governance | $80 budget, 50/80/99% thresholds |
| Data in transit | TLS enforced on all Azure service endpoints |
| FHIR access control | Entra ID RBAC, SMART on FHIR token flow |
| Dead-letter handling | Service Bus dead-letter queue for failed messages |

**Frameworks referenced:** HIPAA Security Rule, GDPR (data minimization, de-identification), FDA 21 CFR Part 11 (audit trail patterns)

---

## Repository Structure

```
azure-fhir-pipeline/
├── README.md
├── infrastructure/
│   ├── bicep/                         # IaC templates (Week 10)
│   └── policies/                      # Azure Policy definitions
├── src/
│   ├── functions/
│   │   └── validate/                  # FHIR validation Azure Function (Python 3.11)
│   ├── logic-apps/
│   │   └── la-hipaa-hl7-processor/    # Logic App definition
│   └── fhir/
│       ├── sample-messages/           # HL7 v2 input samples
│       ├── sample-output/             # FHIR R4 resource output samples
│       └── anonymization/             # De-identification config
├── docs/
│   ├── architecture/                  # Architecture overview and diagrams
│   ├── lessons-learned.md             # Problems encountered and root causes W1-W9
│   └── weekly-reflections/            # Week-by-week reflection documents
├── tests/
│   └── postman/                       # Postman collection and environment schema
└── .github/
    └── workflows/                     # CI/CD pipelines (Week 10)
```

---

## Weeks 10-12: Upcoming

| Week | Focus |
|---|---|
| W10 | DevOps, IaC (Bicep), CI/CD via GitHub Actions |
| W11 | GitHub portfolio completion, architecture PowerPoint, interview prep |
| W12 | LLC formation and consulting practice launch |

---

## Author

**Joel Onwuemene**
Healthcare Integration Architect | Azure | FHIR | HL7 | Epic | Cerner
[LinkedIn](https://linkedin.com/in/joel-onwuemene) | [GitHub](https://github.com/Joelonwuemene)

MSc Medical Informatics | AZ-305 Azure Solutions Architect Expert | HL7 FHIR Proficiency Certification (in progress)

---

*This is a self-directed portfolio lab project. All resource names, configurations, and architecture patterns reflect real deployments in a personal Azure lab environment. No real patient data is used at any stage.*
