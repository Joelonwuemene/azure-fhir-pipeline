# ADR-005: OIDC Federated Identity over Client Secret for CI/CD Authentication

**Status:** Accepted  
**Date:** 2026-01  
**Component:** CI/CD pipeline authentication

## Context

The GitHub Actions pipeline deploys Bicep IaC to Azure. This requires the pipeline to authenticate to Azure. Two approaches were evaluated: a long-lived client secret stored as a GitHub Actions secret, and OIDC federated identity using GitHub's identity provider.

## Decision

Use OIDC federated credentials. The pipeline authenticates via `azure/login@v2` with `client-id`, `tenant-id`, and `subscription-id`. No client secret is stored anywhere.

## Rationale

**No stored credentials.** A client secret stored in GitHub Actions secrets is a long-lived credential. If the secret is exposed - via a log, a fork, a misconfigured environment - it provides persistent access to the Azure subscription until manually rotated. OIDC tokens are short-lived (minutes) and scoped to a specific workflow run.

**Federated subject claim scoping.** The OIDC federated credential is configured with a subject claim (`repo:Joelonwuemene/azure-fhir-pipeline:ref:refs/heads/main`) that restricts token issuance to a specific repository and branch. A token cannot be obtained by a fork or a branch that does not match the claim.

**HIPAA alignment.** Eliminating stored credentials from the CI/CD chain reduces the credential management surface that must be accounted for in a HIPAA access control review.

## Consequences

- The Entra ID app registration requires a federated credential configured with the exact GitHub repository and branch ref. Misconfigured subject claims silently prevent authentication - the pipeline fails at the login step with no credential stored to inspect.
- Three values must be configured as GitHub Actions secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. These are identifiers, not credentials, but they must be present.
- The service principal requires Contributor role on the resource group scope. Subscription-level Contributor is not required and should not be granted.
- See [docs/ci-cd-setup.md](../ci-cd-setup.md) for the full OIDC configuration procedure.
