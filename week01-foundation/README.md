# Week 01 - Azure Core Architecture

## Goal
Establish the Azure foundation for a HIPAA-compliant healthcare integration pipeline: resource group, Key Vault, mandatory PHI tagging policy, and a budget kill-switch.

## Key Azure Resources
- Resource group: `rg-hipaa-apps` (East US)
- Key Vault: `kv-hipaa-phi-joel` (RBAC access model)
- Azure Policy: deny effect blocking any deployment missing HIPAA tags
- Budget: $80/month with thresholds at 50%, 80%, 99%

## Outcome
All subsequent resources deployed with mandatory HIPAA tags enforced at infrastructure level. Azure Policy deny effect confirmed blocking untagged deployments before they reach the subscription.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
