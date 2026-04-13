# Lessons Learned: W1-W9

This document records every significant problem encountered during the 12-week Azure Healthcare Integration build. Each entry includes what happened, what I initially believed, the actual root cause, and how it was resolved or worked around.

These are not failures. They are the evidence that this is a real build, not a tutorial walkthrough.

---

## W2: Budget Alerts Cannot Protect Against Runaway Costs in Real Time

**What happened:**
I configured Azure budget alerts at 50%, 80%, and 99% of an $80 monthly budget and assumed this would serve as real-time cost protection if a pipeline went into a runaway state.

**What I initially believed:**
Budget threshold alerts would fire quickly enough to catch a runaway Logic App or Function consuming unexpected compute.

**Actual root cause:**
Azure budget alerts have a 12-24 hour billing lag. By the time the alert fires, the damage is already done. This is a platform constraint, not a configuration error.

**Resolution:**
Real-time protection requires Azure Monitor metric alerts on Logic App failed runs. The alert `alert-la-hipaa-failed-runs-v2` was configured to fire within 5 minutes when failed runs exceed 5 in a 5-minute window. Budget alerts remain in place as a secondary billing backstop, not a first line of defense.

**Architectural principle:**
Use Azure Monitor for operational alerting. Use budget alerts for financial governance. Do not conflate the two.

---

## W3: Logic App Silently Strips Content-Type Headers Without Body Serialization

**What happened:**
HTTP action calls from the Logic App to the FHIR endpoint were failing with content negotiation errors. The Content-Type header was being set in the action, but the FHIR service was not receiving it.

**What I initially believed:**
Setting the Content-Type header directly in the Logic App HTTP action header field was sufficient.

**Actual root cause:**
Azure Logic Apps (Consumption tier) silently strips Content-Type headers when the body is passed as a raw expression. The header only persists when the body is explicitly serialized using a preceding Compose action with `string()` wrapping the body expression.

**Resolution:**
Added a Compose action before each HTTP call. The body expression is wrapped in `string()`, converting it to a serialized string. The HTTP action then references the Compose output. This forces Logic Apps to treat the body as a raw string and preserve the Content-Type header.

**Related quirk:**
`ContentData` from a Service Bus trigger on Consumption tier uses `triggerBody()?['ContentData']` without array index notation. Adding an array index (`[0]`) causes a null reference at runtime.

---

## W3: Logic App Designer Is the Only Reliable Save Mechanism

**What happened:**
After making edits to the Logic App definition via Code View and saving, the changes appeared to persist in the portal but did not take effect at runtime. The live definition continued executing the previous version.

**What I initially believed:**
Code View saves and CLI-based definition updates (`az logic workflow create --definition`) were equivalent to Designer saves.

**Actual root cause:**
On the Consumption tier, Code View and CLI saves do not reliably update the live workflow definition. The Designer serializes and commits the definition through a different path that correctly propagates changes.

**Resolution:**
All Logic App definition changes are made exclusively through the Designer. Code View is used for reference only. This constraint applies to all Consumption tier Logic Apps throughout this project.

---

## W4: AHDS Workspace Names Must Be Lowercase Alphanumeric With No Hyphens

**What happened:**
Initial provisioning of the Azure Health Data Services workspace failed with a validation error.

**What I initially believed:**
Azure resource naming conventions allow hyphens, as they do for most resource types.

**Actual root cause:**
AHDS workspace names have a stricter naming constraint than most Azure resources: lowercase alphanumeric characters only, no hyphens, no underscores. This is not clearly surfaced in the portal creation flow.

**Resolution:**
Reprovisioned with the name `ahdshipaajoell`. All AHDS resources follow this convention.

---

## W4: RBAC Propagation for $convert-data Takes Up to 5 Minutes

**What happened:**
After assigning the required RBAC role to enable the `$convert-data` operation, the endpoint continued returning 403 Forbidden.

**What I initially believed:**
RBAC assignments take effect immediately.

**Actual root cause:**
Azure RBAC propagation can take up to 5 minutes. Calls made immediately after role assignment will fail with 403 until propagation completes.

**Resolution:**
Wait 5 minutes after any RBAC assignment before testing the affected endpoint. Do not assume a 403 immediately after role assignment indicates a configuration error.

---

## W7: Runaway Message Loop Caused by Wrong Template and Incorrect Dead-Letter Routing

**What happened:**
The pipeline entered a runaway loop. Messages were being continuously re-processed, consuming Service Bus credits rapidly. The Logic App was making conversion calls but producing no valid FHIR output.

**What I initially believed:**
The dead-letter action was correctly routing failed messages out of the main queue, and the conversion template was correctly configured.

**Actual root cause:**
Two compounding errors:

1. `rootTemplate` was set to `ADT_A01` instead of `ORU_R01`. Every ORU^R01 message was being processed against the wrong template, producing malformed output and triggering the failure branch every time.

2. The failure branch dead-letter action was routing failed messages back to the main `hl7-inbound` queue instead of the dead-letter queue. Each failed message was immediately re-queued and reprocessed, creating an unbounded loop.

A third issue was also identified: `templateCollectionReference` (`microsofthealth/hl7v2templates:default`) was missing from the `$convert-data` call, which is a required parameter.

**Resolution:**
Corrected `rootTemplate` to `ORU_R01`, updated the dead-letter action to route to the actual dead-letter queue (not the main queue), and added the missing `templateCollectionReference`. Logic App was disabled during remediation and re-enabled only after all three fixes were verified.

**Architectural principle:**
Always disable a Logic App before debugging a loop condition. Leaving it enabled during investigation will continue consuming resources and may exhaust queue credits.

---

## W7: AHDS Does Not Enforce SMART on FHIR Scopes at the Resource Level

**What happened:**
During SMART on FHIR implementation, I initially documented that the FHIR service itself validates and enforces SMART scopes on incoming requests.

**What I initially believed:**
Azure Health Data Services inspects the scopes in the bearer token and rejects requests where the token scope does not match the requested FHIR resource type or operation.

**Actual root cause:**
This is incorrect. Azure Health Data Services does not enforce SMART scopes at the resource level. Scope enforcement occurs exclusively at token issuance in Microsoft Entra ID. If a token is issued with a given scope, AHDS accepts any valid bearer token issued for the correct audience regardless of scope granularity.

**Resolution:**
Corrected documentation across all weeks. Scope enforcement design must account for this behavior: access control is applied at the Entra ID layer, not the FHIR service layer.

**Why this matters:**
Overstating FHIR service-level scope enforcement gives a false sense of defense in depth. In a production system, row-level or resource-level access control requires additional controls beyond SMART token scopes.

---

## W7: Postman Cannot Validate a Real EHR-Initiated SMART Launch

**What happened:**
During SMART on FHIR testing, Postman was used to acquire a token and make FHIR API calls. I initially described this as testing the SMART on FHIR EHR launch flow end to end.

**What I initially believed:**
Postman simulating the token acquisition and FHIR call sequence constitutes a valid end-to-end EHR launch test.

**Actual root cause:**
Postman simulates the token acquisition and API call portions of the SMART flow. It does not replicate an EHR system initiating the launch sequence, passing a launch context, or validating the app response against an EHR session. A real EHR-initiated launch requires a conformant EHR sandbox (e.g., Epic Sandbox, SMART Health IT launcher).

**Resolution:**
Corrected documentation to accurately describe Postman testing scope. The token flow was simulated and verified. End-to-end EHR launch was not tested.

---

## W8: Azure Portal Silent Spinner Was a Session Timeout, Not a Code Error

**What happened:**
During Week 8, the Logic App Designer and Code View both loaded indefinitely with a spinner and no error message. The portal appeared functional in other areas.

**What I initially believed:**
The Logic App definition had become corrupted, or a recent change had introduced an error that was causing the Designer to fail to render.

**Actual root cause:**
The Azure Portal in East US was experiencing an incident affecting Logic App Designer and Code View rendering. The silent spinner was caused by a session timeout interacting with the portal incident, not by any error in the workflow definition.

**Resolution:**
Waited for the portal incident to resolve. No changes were made to the Logic App definition during the incident. Week 8 Task 9 (wiring the validation quality gate into the Logic App via Designer) remains pending and will be completed as the first action in Week 10.

**Principle confirmed:**
When the portal produces a silent failure with no error message, check the Azure Service Health dashboard before debugging your own configuration. A silent spinner in Designer is almost always a platform or session issue, not a definition error.

---

## W8 and W9: AHDS Does Not Support Conditional References

**What happened:**
Attempts to use conditional references in FHIR resource fields (e.g., referencing a Patient by a conditional identifier expression rather than a server-assigned ID) resulted in errors from the AHDS FHIR endpoint.

**What I initially believed:**
FHIR R4 conditional references (`identifier=system|value`) are a standard feature and would be supported by the managed AHDS FHIR service.

**Actual root cause:**
Azure Health Data Services does not support conditional references in resource fields. This is a documented platform limitation. Only direct server-assigned resource IDs (`Patient/[id]`) are accepted in reference fields.

**Resolution:**
All resource references updated to use direct server-assigned IDs. The pipeline resolves resource IDs via a preceding FHIR search before constructing references in subsequent resources.

---

## Summary Table

| Week | Incident | Category |
|---|---|---|
| W2 | Budget alert billing lag | Platform behavior |
| W3 | Content-Type header stripping | Logic Apps quirk |
| W3 | Designer-only reliable save | Logic Apps quirk |
| W4 | AHDS naming constraint | Provisioning |
| W4 | RBAC propagation delay | Platform behavior |
| W7 | Runaway loop: wrong template + dead-letter routing | Configuration error |
| W7 | SMART scope enforcement misattributed to FHIR service | Architectural misunderstanding |
| W7 | Postman EHR launch simulation limits | Testing scope |
| W8 | Portal silent spinner: session timeout | Platform incident |
| W8/W9 | AHDS conditional references not supported | Platform limitation |
