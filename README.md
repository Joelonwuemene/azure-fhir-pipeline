# Azure HIPAA FHIR Pipeline

A reference implementation of a HIPAA-compliant HL7 v2.x to FHIR R4 transformation pipeline on Microsoft Azure. Designed for medical device manufacturers and health systems connecting clinical devices to FHIR-based EHR platforms including Epic and Cerner.

## The Problem

Medical devices generate HL7 v2.x messages. Modern EHR platforms consume FHIR R4 resources. The gap between these two standards is where integration failures occur - and in a clinical context, a message that converts successfully but writes malformed data to a FHIR store is more dangerous than one that fails outright. Most integration architectures catch the failure. Few catch the silent corruption before write.

This pipeline enforces a validation gate at the transformation layer. A resource that fails FHIR $validate never reaches the FHIR store. The rejection is logged, auditable, and recoverable. That is the architectural decision most teams miss.

## Architecture

```
HL7 Device / Simulator
        │
        ▼
  Azure Service Bus
  (hl7-inbound queue)
        │
        ▼
  Logic App Orchestrator
  (la-hipaa-hl7-processor)
        │
        ├──► Azure Function: FHIR Validation Gate
        │    ($validate before write - rejects malformed resources)
        │
        ▼
  Azure Health Data Services
  (FHIR R4 Service)
        │
        ├──► ADLS Gen2 (bulk export + de-identification)
        │
        └──► Synapse Analytics (OPENROWSET queries on FHIR NDJSON)

Cross-cutting:
  Key Vault       - secrets and crypto key management
  Log Analytics   - KQL audit trail for all pipeline events
  Azure Policy    - deny-effect guardrails on resource compliance
  GitHub Actions  - OIDC-authenticated CI/CD with Bicep IaC
```

Full architecture diagram: [docs/architecture/overview.md](docs/architecture/overview.md)

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Service Bus over Event Hub | Dead-letter routing, per-message lock token, and replay support for HL7 message recovery |
| Validation gate before FHIR write | Silent data corruption in a clinical store is a HIPAA liability, not just a quality issue |
| AHDS over Azure API for FHIR | Azure API for FHIR is retired. AHDS is the current Microsoft-supported path |
| OIDC over client secret in CI/CD | Eliminates stored credentials in GitHub secrets, uses federated identity |
| Entra ID scope enforcement | SMART scopes are enforced at token issuance, not at the FHIR resource layer |

Full decision log: [docs/decisions/](docs/decisions/)

## Stack

| Component | Service |
|---|---|
| Message ingestion | Azure Service Bus |
| Orchestration | Azure Logic Apps (Consumption) |
| Validation | Azure Functions (Python v2) |
| FHIR store | Azure Health Data Services - FHIR R4 |
| Analytics | Azure Synapse Analytics + ADLS Gen2 |
| De-identification | AHDS $export with anonymizationConfig |
| Secrets | Azure Key Vault |
| Observability | Log Analytics + KQL |
| Compliance guardrails | Azure Policy (deny effect) |
| IaC | Bicep |
| CI/CD | GitHub Actions with OIDC |

## Repository Structure

```
├── docs/
│   ├── architecture/          Architecture overview and Mermaid diagrams
│   ├── decisions/             Architecture Decision Records (ADRs)
│   ├── security.md            RBAC model, encryption posture, audit trail design
│   ├── ci-cd-setup.md         OIDC configuration, app registration, RBAC roles
│   └── deployment-guide.md    Step-by-step deployment instructions
│
├── iac/                       Bicep IaC - parameterized, prefix-driven naming
│   ├── main.bicep
│   ├── parameters.lab.json
│   ├── parameters.prod.json
│   └── modules/
│
├── src/
│   ├── functions/validate/    Azure Function - FHIR validation gate (Python v2)
│   ├── logic-apps/            Logic App workflow definition
│   └── fhir/                  CapabilityStatement
│
├── fhir-samples/              Sample HL7 messages and FHIR R4 resources
├── tests/postman/             Postman collection for pipeline testing
├── anonymizationConfig.json   AHDS $export de-identification configuration
└── .github/workflows/         GitHub Actions CI/CD pipeline
```

## Deployment Quick Start

**Prerequisites**

- Azure subscription with Contributor access
- Azure CLI installed and authenticated (`az login`)
- GitHub repository with OIDC configured (see [docs/ci-cd-setup.md](docs/ci-cd-setup.md))

**Deploy IaC**

```bash
# Clone the repo
git clone https://github.com/Joelonwuemene/azure-fhir-pipeline.git
cd azure-fhir-pipeline

# Set your deployment prefix (drives all resource naming)
PREFIX=yourprefix

# Deploy to lab environment
az deployment group create \
  --resource-group rg-hipaa-apps \
  --template-file iac/main.bicep \
  --parameters @iac/parameters.lab.json \
  --parameters prefix=$PREFIX

# Validate (what-if)
az deployment group what-if \
  --resource-group rg-hipaa-apps \
  --template-file iac/main.bicep \
  --parameters @iac/parameters.lab.json \
  --parameters prefix=$PREFIX
```

**Manual Provisioning**

The following components were provisioned manually due to Azure portal dependencies and are not yet in Bicep. They are documented in [docs/deployment-guide.md](docs/deployment-guide.md):

- Azure Health Data Services workspace and FHIR R4 service
- Logic App workflow definition (Designer-saved, not CLI-exportable reliably)
- Managed Identity role assignments on FHIR service
- ADLS Gen2 containers and AHDS $export configuration

Parameterized Bicep coverage for these components is a planned improvement.

## HIPAA Compliance Posture

- All PHI in transit encrypted via TLS 1.2+
- All PHI at rest encrypted via Azure-managed keys
- RBAC enforced at FHIR service level via Managed Identity
- Audit trail in Log Analytics for all FHIR read/write operations
- De-identification via CRYPTOHASH before any data leaves the FHIR store
- Azure Policy deny-effect prevents untagged or unencrypted resource creation
- Key Vault enforces secret lifecycle and access logging

Full security documentation: [docs/security.md](docs/security.md)

## CI/CD Pipeline

The GitHub Actions pipeline (`deploy-iac.yml`) runs five jobs on every push to `main`:

| Job | Purpose |
|---|---|
| lint | Bicep linting |
| validate | ARM template validation against subscription |
| deploy | Bicep deployment to lab resource group |
| smoke-test | FHIR endpoint availability check |
| fhir-validate | OperationOutcome response verification |

Authentication uses OIDC federated credentials. No client secrets stored in GitHub. See [docs/ci-cd-setup.md](docs/ci-cd-setup.md) for setup instructions.

## Portfolio and Contact

Built as a reference implementation demonstrating end-to-end Azure healthcare integration architecture across a 12-week structured programme.

- **LinkedIn:** [linkedin.com/in/joel-onwuemene](https://linkedin.com/in/joel-onwuemene)
- **Contact:** [joel.azurearchitect@proton.me](mailto:joel.azurearchitect@proton.me)

## License

MIT. See [LICENSE](LICENSE).
