# 04 — Architecture

## Data flow

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              YOUR AZURE TENANT                                 │
│                                                                                │
│   ┌──────────────────────┐                                                     │
│   │ Cost Management      │                                                     │
│   │ + Billing            │                                                     │
│   │                      │                                                     │
│   │  • Scheduled export  │                                                     │
│   │  • Daily MTD         │                                                     │
│   │  • Classic + FOCUS   │                                                     │
│   └──────────┬───────────┘                                                     │
│              │ writes CSV / CSV.GZ                                             │
│              ▼                                                                 │
│   ┌──────────────────────┐                                                     │
│   │ Azure Blob Storage   │                                                     │
│   │                      │                                                     │
│   │  Container:          │                                                     │
│   │  cost-analysis/      │                                                     │
│   │    ├ 2026-01.csv     │                                                     │
│   │    ├ 2026-02.csv.gz  │                                                     │
│   │    ├ ...             │                                                     │
│   │    └ manifest.json   │  ← excluded by the M query                          │
│   └──────────┬───────────┘                                                     │
│              │                                                                 │
└──────────────┼─────────────────────────────────────────────────────────────────┘
               │ Storage Blob Data Reader
               ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                         POWER BI DESKTOP / SERVICE                             │
│                                                                                │
│   ┌──────────────────────────────────────────────────┐                         │
│   │ Power Query (M)                                  │                         │
│   │                                                  │                         │
│   │  ① AzureStorage.Blobs                            │                         │
│   │  ② Filter to .csv / .csv.gz, skip manifest       │                         │
│   │  ③ Decompress + parse CSV                        │                         │
│   │  ④ Combine, dedupe header rows                   │                         │
│   │  ⑤ Filter to valid chargeType rows               │                         │
│   │  ⑥ Parse JSON `tags` column                      │                         │
│   │  ⑦ Dynamically expand to Tag_* columns           │                         │
│   │  ⑧ Conform to FOCUS schema (rename)              │                         │
│   │  ⑨ Set data types                                │                         │
│   └──────────────────────┬───────────────────────────┘                         │
│                          ▼                                                     │
│   ┌──────────────────────────────────────────────────┐                         │
│   │ Tabular Model (Vertipaq, in-memory)              │                         │
│   │                                                  │                         │
│   │   cost-analysis ────┐                            │                         │
│   │   cost-analysis-fo. ┼─→ auto-Date tables         │                         │
│   │   Dim-tags ─────────┘    + _Measures + Date      │                         │
│   │                                                  │                         │
│   │   + 68 DAX measures (6 display folders)          │                         │
│   │   + 4 business calculated columns                │                         │
│   │   + 13 active relationships                      │                         │
│   └──────────────────────┬───────────────────────────┘                         │
│                          ▼                                                     │
│   ┌──────────────────────────────────────────────────┐                         │
│   │ Report Layer                                     │                         │
│   │                                                  │                         │
│   │  📄 Page 1 — Executive Summary       (25 visuals)│                         │
│   │  📄 Page 2 — Tags & Governance       (15 visuals)│                         │
│   │  📄 Page 3 — FinOps Optimization     (22 visuals)│                         │
│   └──────────────────────────────────────────────────┘                         │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

## Refresh cadence

| Component | Frequency | Notes |
|-----------|-----------|-------|
| Azure export | Daily | Configured in Cost Management |
| Power BI dataset refresh | Daily, aligned 1–2 h after export | Configured in Power BI Service after publish |

## Why two fact tables?

`cost-analysis` and `cost-analysis-focus` read the **same files** but apply **different transformations** — the first keeps Microsoft's classic MCA column names; the second conforms to the open FOCUS specification.

This duplication is deliberate. It lets you:

- ✅ Use the report **today** with classic exports (no waiting for FOCUS GA in your tenant)
- ✅ A/B compare numbers during your migration to FOCUS
- ✅ Eventually disable the classic query and run pure-FOCUS

If you only have one format flowing in, just disable load on the other query (right-click → *Enable load* off) and the visuals that depend on it will show blanks — non-fatal.

## Star vs. snowflake?

The model is intentionally **wide-and-flat** (a single big fact table), not a classic star. This is the right design for cost-management data because:

- The cardinality is dominated by `Date × Resource`, not dimension lookups
- Every meaningful dimension (Subscription, ResourceGroup, Service, Region) already lives as a column on the cost rows
- The auto-generated date tables provide time-intelligence without manual modeling
- The single `Dim-tags` table exists only because tags are unbounded and dynamic — they can't live as fixed columns

For tenants with > 100M cost rows, see [`08-customization.md`](08-customization.md) for the recommended composite-model upgrade.

## Security model

- Power BI Desktop uses the credentials of the person who opened the file
- Published to Service: refresh uses the credentials stored on the dataset by whoever clicks *Take Over* / *Configure*
- For row-level security (e.g. one cost center can only see their own rows), add a Role in *Modeling → Manage roles* — there's a template in [`docs/08-customization.md`](08-customization.md#row-level-security)

---

→ Next: [`05-data-model.md`](05-data-model.md)
