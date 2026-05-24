# 05 — Data model

## Tables

| Table | Role | Source | Approx. rows per $1M monthly spend |
|-------|------|--------|------------------------------------|
| **`cost-analysis`** | Fact (classic MCA) | Azure blob — daily CSVs | ~250K |
| **`cost-analysis-focus`** | Fact (FOCUS-conformed) | Same blobs, re-shaped | ~250K |
| **`Dim-tags`** | Dimension | Derived from `cost-analysis-focus` | ~5K |
| **`_Measures`** | Measure-container only | `ROW("_", BLANK())` | 1 |
| **`Date`** | Marked date table | DAX `CALENDAR` | 365–730 |
| **`DateTableTemplate_*` + `LocalDateTable_*`** | Auto-generated time-intelligence | Power BI engine | hundreds each |

> The 12 `LocalDateTable_*` and `DateTableTemplate_*` tables are auto-created because **Auto Date/Time is enabled**. They are hidden in report view. If you want to keep the model lean, you can disable Auto Date/Time and rely solely on the manual `Date` table — see [`08-customization.md`](08-customization.md#disable-auto-datetime).

## `cost-analysis` (classic MCA fact)

Reads the **Microsoft Customer Agreement** export format. Keeps Microsoft's original column names so anyone familiar with the portal recognizes them.

Key columns (post-transform):

| Column | Type | Notes |
|--------|------|-------|
| `date` | Date | Usage / charge date |
| `subscriptionName`, `SubscriptionId` | Text | |
| `resourceGroupName`, `ResourceId` | Text | |
| `serviceFamily`, `meterCategory`, `meterSubCategory`, `meterName` | Text | The Microsoft taxonomy |
| `costInUsd`, `costInBillingCurrency`, `paygCostInUsd` | Number | USD is the canonical reporting currency |
| `quantity`, `effectivePrice`, `unitPrice`, `PayGPrice` | Number | For unit-economics analysis |
| `chargeType` | Text | Filtered to: `Usage`, `Purchase`, `Tax`, `Adjustment`, `Refund`, `UnusedReservation`, `RoundingAdjustment` |
| `tags` | Text (JSON) | Raw input — gets parsed into `Tag_*` columns |
| `Tag_<name>` | Text | One column per unique tag name found, prefixed `Tag_` |
| `servicePeriodStartDate`, `servicePeriodEndDate` | Date | |
| `Column66 … Column96` | (dropped) | The MCA export sometimes emits overflow columns; the M query removes them. |

## `cost-analysis-focus` (FOCUS-conformed fact)

Reads the same blob path but conforms to the [FOCUS 1.0 specification](https://focus.finops.org/wp-content/uploads/sites/12/2024/06/FOCUS_Specification-v1-0.pdf).

**Standardised FOCUS columns:**

| FOCUS column | Maps from MCA | Description |
|--------------|---------------|-------------|
| `BilledCost` | `costInBillingCurrency` | The cost a provider charges in the billing currency |
| `EffectiveCost` | `paygCostInBillingCurrency` | Amortised cost, post-discount |
| `ListCost` | (derived) | What you'd pay at full on-demand |
| `ChargePeriodStart`, `ChargePeriodEnd` | `billingPeriodStartDate/EndDate` | When the charge applies to |
| `BillingPeriodStart`, `BillingPeriodEnd` | `servicePeriodStartDate/EndDate` | The invoice period |
| `ServiceCategory`, `ServiceName` | `serviceFamily`, `consumedService` | |
| `ResourceId`, `ResourceRegion`, `ResourceGroupName` | passthrough | |
| `SubAccountId`, `SubAccountName` | `SubscriptionId`, `subscriptionName` | Generic "sub-account" across clouds |
| `ChargeCategory` | `chargeType` | |
| `CommitmentDiscountId`, `CommitmentDiscountName` | `benefitId`, `benefitName` | Reservations and Savings Plans |
| `BillingCurrency`, `PricingCurrency` | passthrough | |

**Provider-specific columns** are prefixed with `x_`:

| `x_BillingAccountId`, `x_BillingProfileId`, `x_InvoiceSectionId`, `x_PublisherId`, `x_CostCenter`, `x_ReservationId`, `x_PricingModel`, etc.

This makes it obvious at-a-glance which columns are portable across clouds (FOCUS) and which are Azure-specific (`x_` prefix).

## `Dim-tags`

Built **in the model** (Power Query references the `cost-analysis-focus` table directly — no separate blob read). Unpivots all `Tag_*` columns into a tall table with three columns:

| Column | Type | Notes |
|--------|------|-------|
| `TagName` | Text | The tag key (without the `Tag_` prefix) |
| `TagValue` | Text | The tag value |
| `ResourceCount` | Integer | Number of cost rows carrying this `TagName=TagValue` combination |

Use this for governance slicers ("show me all the `costCenter` values that have ever been used") without bloating the fact tables.

## Relationships (13 active, all M:1, all single-direction)

The fact tables connect to the auto-generated date tables on every date column:

```
cost-analysis
  ├ date                       ──▶  LocalDateTable_*
  ├ servicePeriodStartDate     ──▶  LocalDateTable_*
  └ servicePeriodEndDate       ──▶  LocalDateTable_*

cost-analysis-focus
  ├ ChargeDate                 ──▶  LocalDateTable_*
  ├ ChargePeriodStart          ──▶  LocalDateTable_*
  ├ ChargePeriodEnd            ──▶  LocalDateTable_*
  ├ BillingPeriodStart         ──▶  LocalDateTable_*
  ├ BillingPeriodEnd           ──▶  LocalDateTable_*
  ├ ChargePeriodStart_Date     ──▶  LocalDateTable_*    (calc column)
  ├ ChargePeriodEnd_Date       ──▶  LocalDateTable_*    (calc column)
  ├ BillingPeriodStart_Date    ──▶  LocalDateTable_*    (calc column)
  ├ BillingPeriodEnd_Date      ──▶  LocalDateTable_*    (calc column)
  └ x_BillingExchangeRateDate  ──▶  LocalDateTable_*
```

The `Dim-tags` table is **disconnected** by design — measures use it as a slicer/filter source via `TREATAS` / `IN VALUES()` patterns.

## Calculated columns (business-relevant)

Only four calculated columns exist on the business tables. All four are simple month-truncations used to power period-based aggregations:

| Table | Column | Expression |
|-------|--------|------------|
| `cost-analysis-focus` | `ChargePeriodStart_Date` | `DATE(YEAR([ChargePeriodStart]), MONTH([ChargePeriodStart]), 1)` |
| `cost-analysis-focus` | `ChargePeriodEnd_Date` | `DATE(YEAR([ChargePeriodEnd]), MONTH([ChargePeriodEnd]), 1)` |
| `cost-analysis-focus` | `BillingPeriodStart_Date` | `DATE(YEAR([BillingPeriodStart]), MONTH([BillingPeriodStart]), 1)` |
| `cost-analysis-focus` | `BillingPeriodEnd_Date` | `DATE(YEAR([BillingPeriodEnd]), MONTH([BillingPeriodEnd]), 1)` |

The remaining 72 calculated columns are inside the auto-generated date tables (year/month/quarter helpers). You can ignore them.

## `_Measures` table

A single-row, single-column table created with `ROW("_", BLANK())`. It exists purely as a **container** for all 68 measures, so they appear under one collapsible header in the field list instead of polluting the fact tables. Hide the underlying column; surface only the measures.

---

→ Next: [`06-power-query-explained.md`](06-power-query-explained.md)
