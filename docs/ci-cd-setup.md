# CI/CD Setup - OIDC Configuration

This document covers the one-time setup required to run the GitHub Actions pipeline (`deploy-iac.yml`) against your own Azure subscription using OIDC federated identity. No client secrets are stored.

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Contributor access on the target Azure subscription or resource group
- Admin access to the GitHub repository

## Step 1 - Create the Entra ID App Registration

```bash
# Create the app registration
az ad app create --display-name "github-fhir-pipeline-deploy"

# Note the appId from the output - this is AZURE_CLIENT_ID
APP_ID=$(az ad app list --display-name "github-fhir-pipeline-deploy" --query "[0].appId" -o tsv)
echo "App ID (AZURE_CLIENT_ID): $APP_ID"
```

## Step 2 - Create a Service Principal

```bash
az ad sp create --id $APP_ID

# Note the id (object ID) of the service principal
SP_ID=$(az ad sp show --id $APP_ID --query "id" -o tsv)
echo "Service Principal Object ID: $SP_ID"
```

## Step 3 - Add OIDC Federated Credential

This restricts token issuance to your specific repository and the `main` branch only.

```bash
# Replace with your GitHub username and repository name
GITHUB_ORG="Joelonwuemene"
REPO_NAME="azure-fhir-pipeline"

az ad app federated-credential create \
  --id $APP_ID \
  --parameters "{
    \"name\": \"github-actions-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${REPO_NAME}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
```

## Step 4 - Assign RBAC Role

Grant the service principal Contributor on the resource group (not subscription).

```bash
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
RESOURCE_GROUP="rg-hipaa-apps"

az role assignment create \
  --assignee $SP_ID \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
```

## Step 5 - Configure GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add three secrets:

| Secret Name | Value | How to Get It |
|---|---|---|
| `AZURE_CLIENT_ID` | App registration `appId` | Step 1 output |
| `AZURE_TENANT_ID` | Your Entra ID tenant ID | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID | `az account show --query id -o tsv` |

These are identifiers, not credentials. They enable the OIDC token exchange but do not grant access on their own.

## Step 6 - Verify Pipeline

Push a commit to `main`. The pipeline should authenticate and proceed through lint, validate, and deploy jobs. If the login step fails, the most common cause is a subject claim mismatch - verify the federated credential subject exactly matches `repo:<org>/<repo>:ref:refs/heads/main`.

## Troubleshooting

**Login step fails with AADSTS error:** The federated credential subject claim does not match the workflow trigger. Check the exact `ref` value in the federated credential and ensure the pipeline is triggered from `main`.

**Deploy step fails with AuthorizationFailed:** The service principal does not have Contributor on the resource group. Re-run Step 4 and verify the scope.

**Smoke-test step fails:** The FHIR endpoint referenced in the smoke-test job may not have been provisioned by IaC. See the manual provisioning section in [deployment-guide.md](deployment-guide.md).
