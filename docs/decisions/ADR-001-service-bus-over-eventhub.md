# ADR-001: Azure Service Bus over Event Hub for HL7 Message Ingestion

**Status:** Accepted  
**Date:** 2026-01  
**Component:** Message ingestion layer

## Context

The pipeline requires a durable message ingestion layer between HL7-generating devices and the Logic App orchestrator. Two Azure messaging services were evaluated: Azure Service Bus and Azure Event Hub.

In a clinical integration context, HL7 message delivery guarantees are not optional. A dropped or unprocessable ORU_R01 message represents a missing lab result in the clinical record. The ingestion layer must support failure recovery without data loss.

## Decision

Use Azure Service Bus with a standard queue (`hl7-inbound`).

## Rationale

Service Bus provides three capabilities that Event Hub does not:

**Dead-letter routing.** Messages that fail processing after the configured delivery count are automatically moved to the dead-letter queue (`hl7-inbound/$deadletterqueue`). This enables inspection, correction, and replay of failed HL7 messages without data loss. Event Hub has no equivalent dead-letter mechanism.

**Per-message lock token.** Service Bus locks a message to a single consumer for the duration of processing. This prevents duplicate processing across Logic App instances. With Event Hub's partition-offset model, duplicate processing under retry conditions is significantly harder to prevent.

**Message settlement actions.** Service Bus supports explicit Complete, Abandon, and Dead-Letter actions. This gives the Logic App orchestrator precise control over message lifecycle: a malformed HL7 message can be dead-lettered with a reason string rather than silently dropped or endlessly retried.

## Consequences

- Service Bus Standard tier incurs a small ongoing cost vs Event Hub consumption model. Acceptable for a HIPAA pipeline where delivery guarantees outweigh cost optimisation.
- Dead-letter queue must be monitored. A Log Analytics alert on dead-letter count is required to surface HL7 processing failures operationally.
- Logic App connector for Service Bus uses peek-lock mode. The lock timeout must be configured to exceed the expected Logic App execution time to prevent premature message release.
