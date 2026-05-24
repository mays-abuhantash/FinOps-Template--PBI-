# 01 — Overview

## What is the Azure FinOps Cockpit?

A drop-in Power BI accelerator that gives any Azure customer three executive-grade dashboards on top of their existing **Azure Cost Management** exports — with zero middleware and no third-party SaaS.

It is built around the **FinOps Foundation's FOCUS 1.0 specification** (the open, vendor-neutral schema for cloud billing data) so the same model works across Azure, AWS, GCP, and OCI with only the Power Query source step changing.

## The three FinOps questions

The report is intentionally narrow. Every visual maps to one of three questions:

| Question | Where it's answered |
|----------|---------------------|
| **"Where did my money go?"** | Page 1 — Executive Summary |
| **"Am I leaking money?"** | Page 2 — Tags & Governance |
| **"Am I optimizing or just paying retail?"** | Page 3 — FinOps Optimization Analysis |

Anything that doesn't help answer those three questions is intentionally not in the report. This is what makes the accelerator *useful out of the box* instead of being a 47-page kitchen-sink template that no one ever reads.

## What "FinOps" means here

This template aligns with the [FinOps Foundation framework](https://www.finops.org/framework/):

- **Inform** — show stakeholders what is being spent and on what (Executive Summary)
- **Optimize** — surface opportunities to reduce spend (FinOps Optimization)
- **Operate** — enforce accountability via tagging governance (Tags & Governance)

## Two data sources, one model

The accelerator reads **two** Cost Management export formats from your blob storage:

| Export | Power Query table | When to use |
|--------|-------------------|-------------|
| Classic MCA (Microsoft Customer Agreement) export | `cost-analysis` | If you only have legacy exports configured, or you want fields like `tags` and `meterCategory` that aren't yet in FOCUS |
| FOCUS 1.0 export | `cost-analysis-focus` | Preferred. Standardised columns (`BilledCost`, `EffectiveCost`, `ServiceCategory`, etc.), portable across clouds. |

You can light up either one — or both. The Executive Summary uses classic columns, while the FinOps Optimization page uses FOCUS. (The duplication exists by design: it lets you A/B compare the two schemas during migration to FOCUS.)

## What this is **not**

- ❌ Not a budget-management tool — Azure Budgets does that natively
- ❌ Not an anomaly detector — Cost Management Anomaly Detection covers that
- ❌ Not a chargeback engine — for that you want Microsoft's [FinOps Toolkit](https://microsoft.github.io/finops-toolkit/) hubs or a paid solution

This is the **reporting & visibility** layer. It composes with all of the above.

## Why Power BI (and not Fabric / Synapse / Looker)?

- Every Microsoft customer already has Power BI Pro included or available cheaply
- Refresh runs on existing capacity — no extra Azure spend
- No data engineer required to operate; a finance analyst can own it
- The `.pbit` template makes it trivially redistributable as IP

For high-volume tenants (>$1M/month spend or >100M rows of billing data), see [`docs/08-customization.md`](08-customization.md) for the recommended Fabric/Direct Lake upgrade path.

---

→ Next: [`02-prerequisites.md`](02-prerequisites.md)
