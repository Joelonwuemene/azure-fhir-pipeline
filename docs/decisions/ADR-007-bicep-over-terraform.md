# ADR-007: Bicep over Terraform for Infrastructure as Code

**Status:** Accepted  
**Date:** 2026-01  
**Component:** Infrastructure as Code

## Context

Two IaC toolchains were evaluated for provisioning the Azure pipeline infrastructure: Azure Bicep and HashiCorp Terraform.

## Decision

Use Azure Bicep.

## Rationale

**Native Azure type system.** Bicep compiles to ARM templates and has first-class support for every Azure resource type at GA. Terraform's AzureRM provider lags behind GA by weeks to months for new services. Azure Health Data Services resource types (`Microsoft.HealthcareApis/workspaces`, `Microsoft.HealthcareApis/workspaces/fhirservices`) were available in Bicep before the Terraform provider was updated.

**No state file management.** Terraform requires a remote state backend - typically Azure Storage - which is itself infrastructure that must be managed, secured, and backed up. Bicep deployments are stateless from the toolchain perspective; resource state lives in Azure Resource Manager.

**GitHub Actions integration.** The `azure/arm-deploy` and native `az deployment group create` actions integrate with Bicep without additional tooling. Terraform requires a separate action, provider authentication configuration, and state locking setup.

**Simpler dependency model.** Bicep's `existing` resource references and module system handle cross-resource dependencies clearly within a single deployment scope. For a single-subscription, single-resource-group pipeline, this is sufficient and easier to audit.

## Consequences

- Bicep is Azure-only. If this pattern is ported to a multi-cloud environment, Terraform or Pulumi would be more appropriate.
- Bicep module outputs must be explicitly declared. Implicit resource property access across module boundaries is not supported and produces cryptic compilation errors.
- The `environment` parameter in `main.bicep` drives resource naming via a `prefix` parameter. All resource names are constructed as `${prefix}-${component}-${environment}` to enable multi-environment deployments without naming collisions.
