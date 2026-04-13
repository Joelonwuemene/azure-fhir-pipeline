# Phase 10 - DevOps, IaC, and CI/CD

## Goal
Deploy the full pipeline from code using Bicep IaC and a GitHub Actions CI/CD pipeline with OIDC federated identity, a compliance gate, and automated FHIR endpoint validation.

## Key Azure Resources
- Bicep templates: `/iac` folder
- GitHub Actions: `.github/workflows/deploy-pipeline.yml`
- OIDC: federated identity between GitHub Actions and Azure — zero stored secrets
- Azure Policy: compliance gate job blocks deployment on HIPAA tag violations

## CI/CD Pipeline Jobs
1. `lint` — Bicep linter
2. `validate` — az deployment what-if
3. `deploy` — az deployment group create
4. `smoke-test` — curl against FHIR endpoint
5. `fhir-validate` — CapabilityStatement retrieval from /metadata

## Outcome
All 5 GitHub Actions jobs green on first full pipeline run. OIDC federated identity confirmed — zero stored credentials in any GitHub secret. Bicep lint and validate completed in under 90 seconds. CapabilityStatement committed to `/docs`.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
