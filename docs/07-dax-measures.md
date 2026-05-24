# 07 — DAX Measures Reference

All 68 measures, grouped by display folder, with descriptions and the actual DAX expression.

The full source is also available as a single file: [`/powerbi/dax/all-measures.dax`](../powerbi/dax/all-measures.dax) — paste-ready for [Tabular Editor](https://tabulareditor.com) or DAX Studio.

## Table of contents

- [💰 Cost Totals](#💰-cost-totals) — 11 measures
- [📅 Time Intelligence](#📅-time-intelligence) — 14 measures
- [📊 Counts](#📊-counts) — 10 measures
- [🔍 Breakdowns](#🔍-breakdowns) — 12 measures
- [🏷️ Tags](#🏷️-tags) — 9 measures
- [💰 FinOps Optimization](#💰-finops-optimization) — 12 measures

---

## 💰 Cost Totals

11 measures.

### `Total Cost USD`

> Total actual cost in USD

```DAX
SUMX('cost-analysis', 'cost-analysis'[costInUsd])
```

### `Total Billed Cost`

> Total cost in billing currency

```DAX
SUMX('cost-analysis', 'cost-analysis'[costInBillingCurrency])
```

### `Total PayG Cost`

> Total Pay-as-you-Go list price cost

```DAX
SUMX('cost-analysis', 'cost-analysis'[paygCostInUsd])
```

### `Total Savings USD`

> Savings vs Pay-as-you-Go price

```DAX
[Total PayG Cost] - [Total Cost USD]
```

### `Savings %`

> Savings percentage vs list price

```DAX
DIVIDE([Total Savings USD], [Total PayG Cost], 0)
```

### `Credit Eligible Cost`

> Cost eligible for Azure credits

```DAX
CALCULATE([Total Cost USD], 'cost-analysis'[isAzureCreditEligible] = "True")
```

### `FOCUS Total Billed Cost`

> FOCUS: Total billed cost

```DAX
SUMX('cost-analysis-focus', 'cost-analysis-focus'[BilledCost])
```

### `FOCUS Effective Cost`

> FOCUS: Effective cost after discounts

```DAX
SUMX('cost-analysis-focus', 'cost-analysis-focus'[EffectiveCost])
```

### `FOCUS Total Savings USD`

> FOCUS: Savings vs Pay-as-you-Go list price

```DAX
SUMX('cost-analysis-focus', 'cost-analysis-focus'[x_PayGPrice] - 'cost-analysis-focus'[BilledCost])
```

### `FOCUS Savings %`

> FOCUS: Savings percentage vs list price

```DAX
DIVIDE([FOCUS Total Savings USD], SUMX('cost-analysis-focus', 'cost-analysis-focus'[x_PayGPrice]), 0)
```

### `FOCUS Credit Eligible Cost`

> FOCUS: Cost eligible for Azure credits

```DAX
CALCULATE([FOCUS Total Billed Cost], 'cost-analysis-focus'[x_IsAzureCreditEligible] = "True")
```

---

## 📅 Time Intelligence

14 measures.

### `MTD Cost`

> Month-to-date cost

```DAX
CALCULATE(
    [Total Cost USD],
    DATESMTD(LASTDATE('cost-analysis'[date]))
)
```

### `Last Month Cost`

> Cost in the previous month

```DAX
CALCULATE([Total Cost USD], DATEADD('Date'[Date], -1, MONTH))
```

### `MoM Cost Change`

> Month-over-month cost change in USD

```DAX
[Total Cost USD] - [Last Month Cost]
```

### `MoM Cost Change %`

> Month-over-month cost change percentage

```DAX
DIVIDE([MoM Cost Change], [Last Month Cost], 0)
```

### `Daily Avg Cost`

> Average daily cost

```DAX
DIVIDE([Total Cost USD], DISTINCTCOUNT('Date'[Date]), 0)
```

### `Projected Monthly Cost`

> Projected full month cost based on daily average

```DAX
VAR _DaysInMonth = DAY(EOMONTH(MAX('Date'[Date]), 0))
VAR _DaysElapsed = DAY(MAX('Date'[Date]))
RETURN DIVIDE([Total Cost USD], _DaysElapsed, 0) * _DaysInMonth
```

### `Report Month`

> Current report month label for header

```DAX
FORMAT(LASTDATE('cost-analysis'[date]), "MMMM YYYY")
```

### `FOCUS Daily Avg Cost`

> FOCUS: Average daily cost

```DAX
DIVIDE([FOCUS Total Billed Cost], DISTINCTCOUNT('Date'[Date]), 0)
```

### `FOCUS Projected Monthly Cost`

> FOCUS: Projected full month cost

```DAX
VAR _DaysInMonth = DAY(EOMONTH(MAX('Date'[Date]), 0))
VAR _DaysElapsed = DAY(MAX('Date'[Date]))
RETURN DIVIDE([FOCUS Total Billed Cost], _DaysElapsed, 0) * _DaysInMonth
```

### `FOCUS MTD Cost`

> FOCUS: Month-to-date billed cost

```DAX
CALCULATE(
    [FOCUS Total Billed Cost],
    DATESMTD(LASTDATE('cost-analysis-focus'[ChargePeriodStart_Date]))
)
```

### `FOCUS Last Month Cost`

> FOCUS: Cost in the previous month

```DAX
CALCULATE([FOCUS Total Billed Cost], DATEADD('Date'[Date], -1, MONTH))
```

### `FOCUS MoM Cost Change`

> FOCUS: Month-over-month cost change in USD

```DAX
[FOCUS Total Billed Cost] - [FOCUS Last Month Cost]
```

### `FOCUS MoM Cost Change %`

> FOCUS: Month-over-month cost change percentage

```DAX
DIVIDE([FOCUS MoM Cost Change], [FOCUS Last Month Cost], 0)
```

### `FOCUS Report Month`

> FOCUS: Current report month label

```DAX
FORMAT(LASTDATE('cost-analysis-focus'[ChargePeriodStart_Date]), "MMMM YYYY")
```

---

## 📊 Counts

10 measures.

### `Distinct Subscriptions`

> Number of distinct subscriptions

```DAX
DISTINCTCOUNT('cost-analysis'[subscriptionName])
```

### `Distinct Resource Groups`

> Number of distinct resource groups

```DAX
DISTINCTCOUNT('cost-analysis'[resourceGroupName])
```

### `Distinct Services`

> Number of distinct Azure services

```DAX
DISTINCTCOUNT('cost-analysis'[meterCategory])
```

### `Distinct Resources`

> Number of distinct resources

```DAX
DISTINCTCOUNT('cost-analysis'[ResourceId])
```

### `Billing Account`

> Billing account name for report header

```DAX
MAX('cost-analysis'[billingAccountName])
```

### `Invoice Section`

> Invoice section for report header

```DAX
MAX('cost-analysis'[invoiceSectionName])
```

### `FOCUS Distinct Subscriptions`

> FOCUS: Distinct subscriptions

```DAX
DISTINCTCOUNT('cost-analysis-focus'[SubAccountName])
```

### `FOCUS Distinct Services`

> FOCUS: Distinct service names

```DAX
DISTINCTCOUNT('cost-analysis-focus'[ServiceName])
```

### `FOCUS Distinct Resources`

> FOCUS: Distinct resource IDs

```DAX
DISTINCTCOUNT('cost-analysis-focus'[ResourceId])
```

### `FOCUS Distinct Resource Groups`

> FOCUS: Number of distinct resource groups

```DAX
DISTINCTCOUNT('cost-analysis-focus'[ResourceGroupName])
```

---

## 🔍 Breakdowns

12 measures.

### `Cost by Subscription`

> Cost grouped by subscription

```DAX
CALCULATE([Total Cost USD], ALLEXCEPT('cost-analysis', 'cost-analysis'[subscriptionName]))
```

### `Cost by Service Family`

> Cost grouped by service family

```DAX
CALCULATE([Total Cost USD], ALLEXCEPT('cost-analysis', 'cost-analysis'[serviceFamily]))
```

### `Cost by Resource Group`

> Cost grouped by resource group

```DAX
CALCULATE([Total Cost USD], ALLEXCEPT('cost-analysis', 'cost-analysis'[resourceGroupName]))
```

### `Cost by Location`

> Cost grouped by Azure region

```DAX
CALCULATE([Total Cost USD], ALLEXCEPT('cost-analysis', 'cost-analysis'[location]))
```

### `% of Total Cost`

> Share of total cost in current filter context

```DAX
DIVIDE([Total Cost USD], CALCULATE([Total Cost USD], ALL('cost-analysis')), 0)
```

### `Top Service Cost`

> Highest cost single service

```DAX
MAXX(VALUES('cost-analysis'[meterCategory]), [Total Cost USD])
```

### `FOCUS Cost by Service`

> FOCUS: Cost grouped by service name

```DAX
CALCULATE([FOCUS Total Billed Cost], ALLEXCEPT('cost-analysis-focus', 'cost-analysis-focus'[ServiceName]))
```

### `FOCUS Cost by Subscription`

> FOCUS: Cost grouped by subscription

```DAX
CALCULATE([FOCUS Total Billed Cost], ALLEXCEPT('cost-analysis-focus', 'cost-analysis-focus'[SubAccountName]))
```

### `FOCUS Cost by Region`

> FOCUS: Cost grouped by region

```DAX
CALCULATE([FOCUS Total Billed Cost], ALLEXCEPT('cost-analysis-focus', 'cost-analysis-focus'[RegionName]))
```

### `FOCUS % of Total`

> FOCUS: Share of total cost

```DAX
DIVIDE([FOCUS Total Billed Cost], CALCULATE([FOCUS Total Billed Cost], ALL('cost-analysis-focus')), 0)
```

### `FOCUS Cost by Resource Group`

> FOCUS: Cost grouped by resource group

```DAX
CALCULATE([FOCUS Total Billed Cost], ALLEXCEPT('cost-analysis-focus', 'cost-analysis-focus'[ResourceGroupName]))
```

### `FOCUS Top Service Cost`

> FOCUS: Highest cost single service

```DAX
MAXX(VALUES('cost-analysis-focus'[ServiceName]), [FOCUS Total Billed Cost])
```

---

## 🏷️ Tags

9 measures.

### `Tagged Resources Cost`

> Cost of resources that have tags

```DAX
CALCULATE([Total Cost USD], 'cost-analysis'[tags] <> "")
```

### `Untagged Resources Cost`

> Cost of resources with no tags

```DAX
CALCULATE([Total Cost USD], 'cost-analysis'[tags] = "")
```

### `Tagging Coverage %`

> Percentage of cost covered by tagged resources

```DAX
DIVIDE([Tagged Resources Cost], [Total Cost USD], 0)
```

### `FOCUS Tagged Cost`

> FOCUS: Cost of resources that have at least one business tag

```DAX
CALCULATE([FOCUS Total Billed Cost],
    'cost-analysis-focus'[Tag_Environment]      <> "" ||
    'cost-analysis-focus'[Tag_Project]           <> "" ||
    'cost-analysis-focus'[Tag_Version]           <> "" ||
    'cost-analysis-focus'[Tag__deployed_by_amba] <> "" ||
    'cost-analysis-focus'[Tag_business owner]    <> "" ||
    'cost-analysis-focus'[Tag_IT owner]          <> "" ||
    'cost-analysis-focus'[Tag_department]        <> "" ||
    'cost-analysis-focus'[Tag_application ]      <> ""
)
```

### `FOCUS Untagged Cost`

> FOCUS: Cost of resources with no business tags at all

```DAX
CALCULATE([FOCUS Total Billed Cost],
    'cost-analysis-focus'[Tag_Environment]      = "" &&
    'cost-analysis-focus'[Tag_Project]           = "" &&
    'cost-analysis-focus'[Tag_Version]           = "" &&
    'cost-analysis-focus'[Tag__deployed_by_amba] = "" &&
    'cost-analysis-focus'[Tag_business owner]    = "" &&
    'cost-analysis-focus'[Tag_IT owner]          = "" &&
    'cost-analysis-focus'[Tag_department]        = "" &&
    'cost-analysis-focus'[Tag_application ]      = ""
)
```

### `FOCUS Tagging Coverage %`

> FOCUS: Tagging coverage percentage

```DAX
DIVIDE([FOCUS Tagged Cost], [FOCUS Total Billed Cost], 0)
```

### `Tagging Target`

> Target for tagging coverage — 100%

```DAX
1
```

### `FOCUS Tagged Resources Count`

> FOCUS: Count of resources that have at least one business tag

```DAX
CALCULATE([FOCUS Distinct Resources],
    'cost-analysis-focus'[Tag_Environment]      <> "" ||
    'cost-analysis-focus'[Tag_Project]           <> "" ||
    'cost-analysis-focus'[Tag_Version]           <> "" ||
    'cost-analysis-focus'[Tag__deployed_by_amba] <> "" ||
    'cost-analysis-focus'[Tag_business owner]    <> "" ||
    'cost-analysis-focus'[Tag_IT owner]          <> "" ||
    'cost-analysis-focus'[Tag_department]        <> "" ||
    'cost-analysis-focus'[Tag_application ]      <> ""
)
```

### `FOCUS Untagged Resources Count`

> FOCUS: Count of resources with no business tags at all

```DAX
CALCULATE([FOCUS Distinct Resources],
    'cost-analysis-focus'[Tag_Environment]      = "" &&
    'cost-analysis-focus'[Tag_Project]           = "" &&
    'cost-analysis-focus'[Tag_Version]           = "" &&
    'cost-analysis-focus'[Tag__deployed_by_amba] = "" &&
    'cost-analysis-focus'[Tag_business owner]    = "" &&
    'cost-analysis-focus'[Tag_IT owner]          = "" &&
    'cost-analysis-focus'[Tag_department]        = "" &&
    'cost-analysis-focus'[Tag_application ]      = ""
)
```

---

## 💰 FinOps Optimization

12 measures.

### `FOCUS OnDemand Cost`

> FOCUS: Cost billed at OnDemand rates (no commitment discount)

```DAX
CALCULATE([FOCUS Total Billed Cost], 'cost-analysis-focus'[x_PricingModel] = "OnDemand")
```

### `FOCUS Reservation Cost`

> FOCUS: Cost covered by Reserved Instances

```DAX
IF(ISBLANK(CALCULATE([FOCUS Total Billed Cost], 'cost-analysis-focus'[x_PricingModel] = "Reservation")), 0, CALCULATE([FOCUS Total Billed Cost], 'cost-analysis-focus'[x_PricingModel] = "Reservation"))
```

### `FOCUS Savings Plan Cost`

> FOCUS: Cost covered by Savings Plans

```DAX
IF(ISBLANK(CALCULATE([FOCUS Total Billed Cost], 'cost-analysis-focus'[x_PricingModel] = "SavingsPlan")), 0, CALCULATE([FOCUS Total Billed Cost], 'cost-analysis-focus'[x_PricingModel] = "SavingsPlan"))
```

### `FOCUS OnDemand Resources`

> FOCUS: Count of resources paying full OnDemand price

```DAX
CALCULATE([FOCUS Distinct Resources], 'cost-analysis-focus'[x_PricingModel] = "OnDemand")
```

### `FOCUS Reserved Resources`

> FOCUS: Count of resources covered by Reserved Instances

```DAX
IF(ISBLANK(CALCULATE([FOCUS Distinct Resources], 'cost-analysis-focus'[x_PricingModel] = "Reservation")), 0, CALCULATE([FOCUS Distinct Resources], 'cost-analysis-focus'[x_PricingModel] = "Reservation"))
```

### `FOCUS RI Coverage %`

> FOCUS: % of resources covered by Reserved Instances vs total

```DAX
DIVIDE([FOCUS Reserved Resources], [FOCUS Distinct Resources], 0)
```

### `FOCUS OnDemand %`

> FOCUS: % of total cost at OnDemand rates — optimization opportunity

```DAX
DIVIDE([FOCUS OnDemand Cost], [FOCUS Total Billed Cost], 0)
```

### `FOCUS Commitment Coverage %`

> FOCUS: % of spend covered by any commitment (RI + Savings Plan)

```DAX
DIVIDE([FOCUS Reservation Cost] + [FOCUS Savings Plan Cost], [FOCUS Total Billed Cost], 0)
```

### `FOCUS Potential Savings USD`

> FOCUS: Estimated savings if 35% of OnDemand spend moved to Reserved Instances

```DAX
CALCULATE([FOCUS OnDemand Cost], 'cost-analysis-focus'[x_PricingModel] = "OnDemand") * 0.35
```

### `FOCUS Effective vs Billed Gap`

> FOCUS: Difference between Effective and Billed cost — shows reservation amortization impact

```DAX
[FOCUS Effective Cost] - [FOCUS Total Billed Cost]
```

### `OnDemand Target`

> Target for OnDemand % gauge — goal is 0% OnDemand (fully committed)

```DAX
0
```

### `FinOps Recommendations`

> Dynamic FinOps recommendations text that updates automatically based on actual data values

```DAX
VAR _RICoverage      = [FOCUS RI Coverage %]
VAR _OnDemandPct     = [FOCUS OnDemand %]
VAR _OnDemandCost    = [FOCUS OnDemand Cost]
VAR _PotentialSaving = [FOCUS Potential Savings USD]
VAR _EffBilledGap    = [FOCUS Effective vs Billed Gap]
VAR _TotalRes        = [FOCUS Distinct Resources]
VAR _CommitCoverage  = [FOCUS Commitment Coverage %]

VAR _Rec1 =
    IF(_RICoverage = 0,
        "🔴 RI COVERAGE — CRITICAL" & UNICHAR(10) &
        "0% of " & FORMAT(_TotalRes,"#,##0") & " resources use RIs. " &
        "Buy 1-yr RIs to save " & FORMAT(_PotentialSaving,"$#,##0") & "/mo.",
        "🟢 RI COVERAGE — " & FORMAT(_RICoverage,"0%") & " covered.")

VAR _Rec2 =
    IF(_OnDemandPct >= 0.9,
        UNICHAR(10) & UNICHAR(10) &
        "🔴 ONDEMAND — CRITICAL" & UNICHAR(10) &
        FORMAT(_OnDemandPct,"0%") & " of spend (" & FORMAT(_OnDemandCost,"$#,##0") & ") at full price. " &
        "Consider Savings Plans (20-40% off).",
        UNICHAR(10) & UNICHAR(10) &
        "🟢 ONDEMAND — " & FORMAT(_OnDemandPct,"0%") & " OnDemand.")

VAR _Rec3 =
    IF(_EffBilledGap > 0,
        UNICHAR(10) & UNICHAR(10) &
        "🟡 BILLED GAP — " & FORMAT(_EffBilledGap,"$#,##0.00") & UNICHAR(10) &
        "Effective vs Billed gap detected. Review reservation amortization.",
        "")

VAR _Rec4 =
    IF(_CommitCoverage = 0,
        UNICHAR(10) & UNICHAR(10) &
        "🔴 SAVINGS PLANS — NOT IN USE" & UNICHAR(10) &
        "No Savings Plans active. Purchase Compute Savings Plans for 20-40% discount.",
        UNICHAR(10) & UNICHAR(10) &
        "🟢 SAVINGS PLANS — " & FORMAT(_CommitCoverage,"0%") & " covered.")

RETURN _Rec1 & _Rec2 & _Rec3 & _Rec4
```

---

→ Next: [`08-customization.md`](08-customization.md)
