# 08 — Customization

Patterns for adapting the accelerator to your tenant, brand, and scale.

## Parameterize the blob URL

The shipped query hardcodes the storage account URL in the `Source` step. For redistributable IP, replace that with a parameter.

1. **Home → Manage parameters → New**
   - Name: `BlobAccountUrl`
   - Type: Text
   - Suggested values: Any value
   - Current value: *(leave blank for `.pbit`, or put your URL for `.pbix`)*

2. Edit each query's first step from:
   ```m
   Source = AzureStorage.Blobs("https://hijazicostmanagment.blob.core.windows.net"),
   ```
   to:
   ```m
   Source = AzureStorage.Blobs(BlobAccountUrl),
   ```

3. **Close & Apply.**

Now when you re-save as `.pbit`, opening the template will prompt the user for `BlobAccountUrl` interactively.

## Parameterize the container name

Repeat the parameter pattern for the container.

1. New parameter:
   - Name: `ContainerName`
   - Type: Text
   - Current value: `cost-analysis`

2. Edit the `Container` step from:
   ```m
   Container = Source{[Name="cost-analysis"]}[Data],
   ```
   to:
   ```m
   Container = Source{[Name=ContainerName]}[Data],
   ```

3. Repeat for `cost-analysis-focus`.

## Switch to ADLS Gen2 / Data Lake Storage

If your exports go to a Data Lake Storage Gen2 account (hierarchical namespace) instead of plain blob storage:

```m
// Replace AzureStorage.Blobs with this:
Source = AzureStorage.DataLake(BlobAccountUrl),
Container = Source{[Name="cost-analysis"]}[Data],
```

The rest of the query is unchanged.

## Add a date-range filter (faster refresh on multi-year archives)

For a tenant with multiple years of files, you can short-circuit the load to a rolling window:

```m
// New parameters:
RollingMonths = 13,  // number-typed parameter

// Add this step right after `CsvFiles`:
RecentOnly = Table.SelectRows(CsvFiles, each
    [Date Modified] >= Date.AddMonths(DateTime.LocalNow(), -RollingMonths)),
```

Refreshes now skip files older than the rolling window. Adjust as needed.

## Pre-filter by subscription

Add right after the `MCA_Rows` step:

```m
// New parameter:
SubscriptionFilter = "00000000-0000-0000-0000-000000000000",  // or list

OnlyMySub = Table.SelectRows(MCA_Rows, each
    [SubscriptionId] = SubscriptionFilter)
```

For multi-subscription filtering:

```m
SubscriptionList = {"sub-id-1", "sub-id-2", "sub-id-3"},
OnlyMySubs = Table.SelectRows(MCA_Rows, each
    List.Contains(SubscriptionList, [SubscriptionId]))
```

## Disable Auto Date/Time

The model ships with **Auto Date/Time enabled**, which auto-creates a `LocalDateTable_*` per date column (12 in total). To slim the model:

1. **File → Options and settings → Options → Current file → Data Load → Time intelligence**
2. Uncheck **Auto date/time**.
3. Use only the manually-defined `Date` table for time intelligence.

You'll need to:
- Re-create relationships from the fact tables to `Date[Date]`
- Update any visual that was implicitly using an auto-date hierarchy

This reduces model size by ~20–40% for typical tenants and makes refresh measurably faster.

## Row-level security (per cost center / business unit)

Goal: a finance partner for "Marketing" can only see rows where `Tag_costCenter = "Marketing"`.

1. **Modeling → Manage roles → New**
2. Name: `CostCenterFilter`
3. Filter on `cost-analysis-focus`:
   ```DAX
   [Tag_costCenter] = USERPRINCIPALNAME()
   ```
   *(or use a mapping table keyed on the user's UPN if cost centers aren't email-like)*

4. Repeat the same filter on `cost-analysis` (`[Tag_costCenter]`).
5. **Test as role** to validate.
6. Once published, assign Entra ID groups to the role under **Workspace → Dataset → Security**.

## Rebrand the report

Quick rebrand checklist:

| Element | How to change |
|---------|---------------|
| Logo | Insert → Image → upload your logo on each page; delete the default placeholder |
| Color theme | View → Themes → Browse for themes → load your `.json` theme |
| Page name (`CAIT`-prefixed) | Right-click page tab → Rename |
| Report title text | Top-left text box on each page — edit in place |
| Header strip color | Selection pane → find the rectangle named `HeaderBar` → Format → Fill |

## Add a new page / measure

1. Add the page (`+` at the bottom of the page tabs)
2. New measures go on `_Measures` (so they appear in one folder)
3. Match the existing display-folder convention (the leading emoji is just to control sort order — Power BI sorts folders alphabetically):
   - 💰 Cost Totals → for sum / aggregate cost measures
   - 📅 Time Intelligence → for MTD / YoY / projection
   - 📊 Counts → for distinct counts
   - 🔍 Breakdowns → for max / top / share
   - 🏷️ Tags → for tagging-related
   - 💰 FinOps Optimization → for RI / SP / waste analysis

## Upgrade to Fabric / Direct Lake (large tenants)

For tenants > $1M/month spend or > 100M cost rows:

1. Land the same blob exports into a **Fabric Lakehouse** via a scheduled Pipeline or Notebook.
2. Replace the Power Query source with a **Direct Lake** semantic model on the Lakehouse table.
3. Keep all 68 measures unchanged — DAX is identical.

Result: sub-second visual rendering on billions of rows, refresh becomes effectively free.

## Add cost forecasting / anomaly detection

Two low-effort additions you can make:

- **Forecast line** — On any line-chart visual, **Analytics pane → Forecast → Add**. Set forecast length to 30 days, confidence interval 95%, seasonality 30. Free, built into Power BI.
- **Anomaly visual** — Select a line chart → **Analytics pane → Find anomalies → Add**. Tunes itself automatically.

For real ML-based anomaly detection, consume Azure Cost Management's native [Anomaly Detection API](https://learn.microsoft.com/en-us/azure/cost-management-billing/understand/analyze-unexpected-charges) instead of rebuilding it.

---

→ Next: [`09-deployment.md`](09-deployment.md)
