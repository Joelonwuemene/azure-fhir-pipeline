# Phase 03 - HL7 Integration and Service Bus

## Goal
Ingest HL7 v2.x ORU_R01 lab result messages via Azure Service Bus and trigger the Logic App orchestration layer.

## Key Azure Resources
- Service Bus namespace: `sb-hipaa-hl7-joel`
- Queue: `hl7-inbound`
- Dead-letter subqueue: `hl7-inbound/$deadletterqueue`
- Logic App trigger: Service Bus peek-lock on `hl7-inbound`

## Outcome
Service Bus queue confirmed receiving HL7 messages. Logic App trigger firing on new messages. Dead-letter subqueue routing validated — failed messages do not re-queue to main queue.

## Evidence
Screenshot evidence per task completion checklist. See root [README.md](../README.md) for full project overview.
