# Deployment Guide

This guide covers deploying the Azure HIPAA FHIR Pipeline to your own Azure subscription. It documents both IaC-deployed components and components that require manual provisioning.

## Prerequisites

- Azure subscription with Contributor access on the target resource group
- Azure CLI 2.50+ installed and authenticated (`az login`)
- Bicep CLI (installed via `az bicep install`)
- Python 3.11+ (for local Function testing)
- Postman (for pipeline validation)

## Step 1 — Create Resource Group

```bash
RESOURCE_GROUP="rg-hipaa-apps"
LOCATION="eastus"

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags DataClassification=PHI ComplianceFramework=HIPAA Environment=lab Owner=your-name
```

## Step 2 — Deploy IaC (Bicep)

Set your deployment prefix. This drives all resource names. Use a short lowercase alphanumeric string (3-10 characters).

```bash
PREFIX="myfhir"

# What-if (dry run)
az deployment group what-if \
  --resource-group $RESOURCE_GROUP \
  --template-file iac/main.bicep \
  --parameters @iac/parameters.lab.json \
  --parameters prefix=$PREFIX

# Deploy
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file iac/main.bicep \
  --parameters @iac/parameters.lab.json \
  --parameters prefix=$PREFIX
```

This deploys: Log Analytics workspace, Service Bus namespace and queue, Key Vault, Azure Function App (with System-Assigned Managed Identity).

## Step 3 — Manual Provisioning: AHDS and FHIR Service

Azure Health Data Services requires manual provisioning. AHDS workspace names must be lowercase alphanumeric with no hyphens (Azure validation constraint).

```bash
# Register the resource provider if not already registered
az provider register --namespace Microsoft.HealthcareApis

# Create AHDS workspace (lowercase alphanumeric name only)
AHDS_WORKSPACE="myfhirws"
az healthcareapis workspace create \
  --resource-group $RESOURCE_GROUP \
  --name $AHDS_WORKSPACE \
  --location $LOCATION

# Create FHIR R4 service within the workspace
FHIR_SERVICE="myfhirfhir"
az healthcareapis fhir-service create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $AHDS_WORKSPACE \
  --name $FHIR_SERVICE \
  --fhir-version R4 \
  --location $LOCATION

# Note your FHIR endpoint
echo "FHIR endpoint: https://${AHDS_WORKSPACE}-${FHIR_SERVICE}.fhir.azurehealthcareapis.com"
```

## Step 4 — Assign FHIR RBAC Roles

```bash
FHIR_SERVICE_ID=$(az healthcareapis fhir-service show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $AHDS_WORKSPACE \
  --name $FHIR_SERVICE \
  --query id -o tsv)

# Get Function App Managed Identity principal ID
FUNC_PRINCIPAL_ID=$(az functionapp identity show \
  --resource-group $RESOURCE_GROUP \
  --name "${PREFIX}-func-validate-lab" \
  --query principalId -o tsv)

# Assign FHIR Data Reader to Function App MI (for $validate)
az role assignment create \
  --assignee $FUNC_PRINCIPAL_ID \
  --role "FHIR Data Reader" \
  --scope $FHIR_SERVICE_ID
```

## Step 5 — Deploy Azure Function Code

```bash
cd src/functions/validate

# Install dependencies locally
pip install -r requirements.txt

# Deploy to Azure
func azure functionapp publish "${PREFIX}-func-validate-lab" --python
```

## Step 6 — Update Function App Settings

```bash
FHIR_URL="https://${AHDS_WORKSPACE}-${FHIR_SERVICE}.fhir.azurehealthcareapis.com"

az functionapp config appsettings set \
  --resource-group $RESOURCE_GROUP \
  --name "${PREFIX}-func-validate-lab" \
  --settings "FHIR_URL=${FHIR_URL}"
```

## Step 7 — Manual Provisioning: Logic App

The Logic App workflow definition must be configured in Azure Portal Designer. This is a known Consumption tier constraint documented in [ADR-002](decisions/ADR-002-logic-app-consumption-designer-save.md).

1. Create a Logic App (Consumption) in the Azure Portal in `$RESOURCE_GROUP`.
2. Open Designer and configure the workflow following the structure in `src/logic-apps/la-hipaa-hl7-processor/definition.json`.
3. Connect the Service Bus trigger to the `hl7-inbound` queue.
4. Wire the validation gate HTTP action to your deployed Function App URL.
5. Save via the Designer Save button. Code View saves do not reliably persist.

## Step 8 — Configure anonymizationConfig

Before running `$export`, update `anonymizationConfig.json` to reference your Key Vault secrets:

```json
"cryptoHashKey": "@Microsoft.KeyVault(SecretUri=https://<your-kv-name>.vault.azure.net/secrets/anonymization-crypto-key/)"
```

Store the crypto key in Key Vault:

```bash
az keyvault secret set \
  --vault-name "${PREFIX}-kv-lab" \
  --name "anonymization-crypto-key" \
  --value "$(openssl rand -base64 32)"
```

## Step 9 — CI/CD Setup

See [docs/ci-cd-setup.md](ci-cd-setup.md) for OIDC configuration and GitHub Actions secrets setup.

## Validation

Test the validation gate directly via Postman using the collection in `tests/postman/`. A valid Observation resource should return HTTP 200 with an informational OperationOutcome. An invalid resource should return HTTP 422 with error-severity issues.

## Known Manual Steps Summary

| Component | Reason | Reference |
|---|---|---|
| AHDS workspace and FHIR service | No Bicep module in this release | Step 3 above |
| Logic App workflow | Consumption tier Designer constraint | [ADR-002](decisions/ADR-002-logic-app-consumption-designer-save.md) |
| FHIR RBAC role assignments | Requires FHIR service ID post-provisioning | Step 4 above |
| anonymizationConfig Key Vault reference | Deployment-time secret configuration | Step 8 above |
