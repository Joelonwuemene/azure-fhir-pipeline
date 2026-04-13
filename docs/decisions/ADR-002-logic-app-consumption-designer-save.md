# ADR-002: Logic App Designer Save as Source of Truth for Workflow Definition

**Status:** Accepted  
**Date:** 2026-01  
**Component:** Logic App orchestration

## Context

Logic App Consumption tier workflow definitions can be modified via three mechanisms: Azure Portal Designer, Code View editor, and Azure CLI (`az logic workflow update`). During implementation, inconsistent persistence behaviour was observed across these methods.

## Decision

All Logic App workflow definition changes are made and saved exclusively through Azure Portal Designer. Code View and CLI are used for inspection only, never for saving.

## Rationale

During pipeline development, workflow definition changes saved via Code View and via CLI were not reliably persisted. Subsequent Designer opens reverted to the prior state. The Azure Portal Designer Save action is the only mechanism that consistently and verifiably persists workflow definition changes in the Consumption tier.

This is a known behavioural characteristic of the Consumption tier. The Standard tier (single-tenant) does not have this constraint and supports code-first workflow authoring reliably.

## Consequences

- The Logic App workflow definition cannot be fully managed as code in this implementation. The Designer is the authoritative editor.
- `src/logic-apps/la-hipaa-hl7-processor/definition.json` documents the workflow structure but is not a deployable artifact. Any deployment of this component requires manual Designer configuration.
- Teams requiring fully code-managed Logic App orchestration should evaluate the Standard tier, which supports stateful and stateless workflows as JSON files in source control.
- This constraint is documented in the deployment guide to prevent time loss for anyone attempting CLI-based workflow deployment.
