# Phase 02 - HIPAA Compliance Controls

## Goal
Implement audit, alerting, and cost control infrastructure so HIPAA compliance is structural and observable — not a post-deployment checklist.

## Key Azure Resources
- Log Analytics: `law-hipaa-joel` (single audit sink for all diagnostic logs)
- Monitor alert: `alert-la-hipaa-failed-runs-v2` (Severity 2, fires in ~5 min on RunsFailed > 5)
- Action group: `ag-hipaa-pipeline-failures` (email + SMS)
- Budget thresholds: 50% / 80% / 99% of $80/month

## Outcome
Dual-layer cost control confirmed: Monitor alert fires within 5 minutes (primary), budget email alert fires within 12-24 hours (backstop). Log Analytics capturing all diagnostic logs from pipeline resources.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
