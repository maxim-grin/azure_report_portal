# Going to Production — Azure

This repo is built as a learning deployment: spin up, exercise the flow, `terraform destroy`. This document covers what changes when it needs to serve real traffic — assumed here as roughly 5,000 reports/day (~150,000/month).

The headline: at that volume the metered usage is nearly noise. What you start paying for is availability, and what breaks first is the request shape, not the throughput.

---

## 1. The burst problem

Payroll traffic isn't smooth. It's near-zero for thirteen days, then tens of thousands of requests in the two hours after payday notifications go out. **Peak concurrency sizes this system, not average throughput.**

PDF rendering takes 1–3 seconds and is CPU-heavy. Doing that inside a request that's holding an HTTP connection open means, on a burst: request timeouts, Function concurrency limits, and a client sitting on a spinner. Cold starts on the Consumption plan hit hardest at exactly the moment load spikes.

## 2. Refactor to asynchronous generation

The single most important change. Split the API from the work:

```
POST /reports/generate
  → validate, enqueue, return 202 Accepted + job_id     (fast, milliseconds)

Storage Queue
  → queue-triggered Function renders PDF, uploads to Blob,
    issues SAS URL, sends via ACS                        (slow, seconds)
```

The client either polls a `GET /reports/{job_id}` status endpoint or simply waits for the email — which is the actual deliverable anyway.

**What this gets you:** the queue absorbs the spike instead of the gateway; retries and poison-message handling come free from the Functions queue trigger; and `/reports/send-report-email` stops being a separate client call — the worker just does it.

**Terraform sketch:**

```hcl
resource "azurerm_storage_queue" "report_jobs" {
  name                 = "report-jobs"
  storage_account_name = module.storage.storage_account_name
}
```

Then a second Function with a `queueTrigger` binding on `report-jobs`. Use Service Bus instead of Storage Queue if you need scheduled delivery, sessions, or larger messages; Storage Queue is sufficient for this shape and cheaper.

Set the queue's `maxDequeueCount` and configure a poison queue — a malformed report record shouldn't retry forever.

## 3. Idempotency and reuse

Every call currently re-renders from scratch. Store the blob path and generation timestamp on the report row, and reissue a SAS URL against the existing blob if it's still fresh. On a payday burst where people click twice, this eliminates a large fraction of rendering load.

Add an idempotency key to `POST /reports/generate` so a double-submitted request returns the existing `job_id` rather than enqueueing twice.

## 4. Fix the retention bug before launch

`storage.tf`'s lifecycle rule deletes blobs after 7 days. That's correct for a demo and wrong for payroll — paystubs are financial records with multi-year retention obligations in most jurisdictions.

The **SAS URL** expiring after 48 hours is right. The **blob** disappearing is not. Decouple them: keep objects for the retention period your legal requirements dictate, and issue a fresh short-lived SAS on each re-request. Someone asking for their March paystub in November should get it.

Consider a blob immutability policy (`azurerm_storage_container_immutability_policy`) if the retention requirement is regulatory rather than merely operational.

## 5. Tier decisions — the expensive part

This is where Azure costs materially more than the demo suggests.

**Edge protection.** With API Management removed, decide deliberately whether this endpoint needs an edge tier at all. Azure Front Door Standard (~$35/month) buys rate limiting, WAF rules, DDoS protection, and TLS termination. If the portal is only reachable from a corporate network, even that may be unnecessary.

**Functions.** Consumption → Premium (EP1, ~$150–250/month) buys warm instances (no cold-start penalty at the start of a burst) and VNet integration. This also resolves `CKV_AZURE_225` and `CKV_AZURE_212` — zone redundancy and minimum instance counts become configurable, so those suppressions come out too. Note zone redundancy requires a minimum of three always-ready instances, which is a real cost step beyond EP1 alone.

**Azure SQL.** The important one, and easy to miss: **serverless stops being cheap once traffic is steady.** Auto-pause was the entire reason `GP_S_Gen5_1` was attractive, and with continuous traffic it will essentially never trigger. Continuous serverless billing runs well above equivalent provisioned compute. Re-run the numbers for provisioned General Purpose at your actual duty cycle — this is an active decision to make, not a setting to inherit from the demo.

**Function App public access.** `https_only = true` is already set. `CKV_AZURE_221` stays suppressed by design — the browser client calls the Function App directly, so it must stay publicly reachable, with Easy Auth as the access boundary. If you later put Front Door in front with Private Link (Premium plan), public access can be disabled and that suppression removed.

## 6. Operational changes

**Key Vault secret expiry is now a scheduled outage.** The secrets carry a hardcoded `expiration_date` a year out. Azure enforces expiry — the Function's Key Vault reference will fail to resolve once it passes. Either implement rotation (Event Grid on the near-expiry event → rotation Function) or, at minimum, alert well ahead of the date.

**Per-user rate limits.** There is no gateway and therefore no rate limiting at all right now — this is the most significant thing the APIM removal gave up. Implement per-user throttling in application code keyed on the `x-ms-client-principal-id` header, or add Azure Front Door + WAF (~$35/month) for rate limiting, DDoS protection, and WAF rules at the edge. Front Door is the better answer if the endpoint is genuinely internet-facing.

**Observability.** Application Insights ingestion is frequently a top-three line item at this scale — often more than compute. Budget $10–50/month and sample aggressively. Alert on queue depth and poison-queue count, not just HTTP error rates; a growing queue is the earliest signal that rendering can't keep up with a burst.

**Backups.** Enable point-in-time restore and configure a retention window on the SQL database. Nothing in the demo config addresses this.

## 7. Cost estimate at ~150,000 reports/month

| Service                        | Production configuration                              | Rough monthly |
| ------------------------------ | ----------------------------------------------------- | ------------- |
| Front Door Standard (optional) | WAF + rate limiting at the edge                       | ~$35          |
| Functions                      | Premium EP1                                           | ~$150–250     |
| Azure SQL                      | Serverless (never pausing) or provisioned — re-decide | ~$60–380      |
| Blob Storage                   | ~30 GB/month generated, plus transactions             | ~$2–5         |
| Communication Services         | 150k emails                                           | ~$40–120      |
| Key Vault                      | Operations                                            | ~$3–5         |
| Private endpoints              | 4 × hourly                                            | ~$30          |
| Application Insights           | Log ingestion, sampled                                | ~$10–50       |
| Storage Queue                  | 150k messages                                         | ~$0           |
| **Total**                      |                                                       | **~$150–400** |

The dominant costs are fixed floors bought for availability — the Premium plan and always-on database compute — not per-request charges. At 150k requests/month the metered portion is close to noise. Removing API Management took roughly $210/month out of this estimate.

The ACS email figure has the widest uncertainty: published per-email rates vary across sources, and Microsoft's own documentation labels its example rate as illustrative. Re-derive against the Azure pricing calculator before budgeting.

## 8. Order of work

1. Fix the retention bug — it's a correctness issue, not an optimization.
2. Refactor to async. Everything else is easier once the API is fast and the work is queued.
3. Move Functions to a Premium plan, removing the `CKV_AZURE_225` and `CKV_AZURE_212` suppressions as zone redundancy and minimum instances become configurable. Decide separately whether Front Door is warranted.
4. Re-decide the SQL tier against real duty-cycle numbers.
5. Add rotation, per-user limits, alerting, and backups.
