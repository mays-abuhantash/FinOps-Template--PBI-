# 06 — Power Query, explained

This is a line-by-line tour of every M query in the model. The full source for each is also available as a standalone `.m` file in [`/powerbi/queries/`](../powerbi/queries/).

There are three queries:

1. [`cost-analysis`](#1-cost-analysis-classic-mca-format) — classic MCA export
2. [`cost-analysis-focus`](#2-cost-analysis-focus-focus-10-conformed) — FOCUS-conformed version
3. [`Dim-tags`](#3-dim-tags-unpivoted-tag-dimension) — derived tag dimension

All three apply the same defensive design principles:

- **No hardcoded schema** — column lists are discovered at refresh, not baked in
- **Defensive type conversion** — `try ... otherwise null` on every numeric and date cast
- **Resilience to schema drift** — handles `.csv` and `.csv.gz`, manifest exclusion, overflow columns, header rows mixed in with data
- **Dynamic tag expansion** — every unique tag key in the data becomes a `Tag_*` column automatically

---

## 1. `cost-analysis` (classic MCA format)

### Source connection

```m
Source = AzureStorage.Blobs(
    "https://hijazicostmanagment.blob.core.windows.net"),
Container = Source{[Name="cost-analysis"]}[Data],
```

Connects to a blob storage account and selects the `cost-analysis` container. The container's contents come back as a Power Query table with one row per blob.

> ⚠️ This URL is the **only thing you need to change for your deployment**. See [`08-customization.md`](08-customization.md#parameterize-the-blob-url) for the parameterized version.

### File filter

```m
CsvFiles = Table.SelectRows(Container, each
    (Text.Lower([Extension]) = ".csv"
      or Text.EndsWith(Text.Lower([Name]), ".csv.gz")
      or Text.Lower([Extension]) = ".gz")
    and not Text.StartsWith(Text.Lower([Name]), "manifest")),
```

Cost Management drops both data files **and** `manifest.json` metadata files in the same container. This step keeps only CSV / GZipped-CSV files and excludes manifests.

Also lowercases everything so case-insensitive comparisons work on case-sensitive blob names.

### CSV decompression + parse

```m
CsvContent = Table.AddColumn(CsvFiles, "CsvData",
    each Csv.Document(
        (if Text.EndsWith(Text.Lower([Name]), ".gz")
         then Binary.Decompress([Content], Compression.GZip)
         else [Content]),
        [Delimiter=",", Encoding=65001,
         QuoteStyle=QuoteStyle.Csv])),
```

For each blob:
- If the file is gzipped → decompress with `Binary.Decompress(..., Compression.GZip)`
- Either way → parse as CSV with UTF-8 encoding (`65001`) and proper quote handling

The result is a new `CsvData` column where each cell is itself a parsed table.

### Combine + promote headers

```m
Combined  = Table.Combine(Table.Column(CsvContent, "CsvData")),
Promoted  = Table.PromoteHeaders(Combined, [PromoteAllScalars=true]),
```

`Table.Combine` stacks every file's parsed contents into a single table. `Table.PromoteHeaders` turns the first row of the first file into column names.

### Dedupe duplicate header rows

```m
Deduped = Table.SelectRows(Promoted, each
    Record.Field(_, Table.ColumnNames(Promoted){0})
        <> Table.ColumnNames(Promoted){0}),
```

When multiple CSVs are combined, every file (except the first) contributes its own header row as a data row. This step removes them by checking that the value of the first column never equals the name of the first column.

### Charge-type filter

```m
MCA_Rows = Table.SelectRows(Deduped, each
    List.Contains(
        {"Usage","Purchase","Tax","Adjustment",
         "Refund","UnusedReservation","RoundingAdjustment"},
        [chargeType])),
```

The export occasionally emits informational rows like `OpeningBalance` and `ClosingBalance`. Keeping only valid `chargeType` values guarantees the cost columns sum correctly without double-counting.

### Drop overflow columns

```m
CleanCols = Table.SelectColumns(MCA_Rows,
    List.Select(Table.ColumnNames(MCA_Rows),
        each not Text.StartsWith(_, "Column"))),
```

MCA exports sometimes have ragged rows that produce trailing `Column66`, `Column67`, ... columns. This drops anything starting with literal `Column`.

### Dynamic tag parsing

```m
ParsedTags = Table.AddColumn(CleanCols, "TagsParsed",
    each
        let
            TagText = [tags],
            ParsedTag =
                if TagText = null or TagText = "" or TagText = "{}" then null
                else
                    try Json.Document(TagText)
                    otherwise
                        try Json.Document("{" & TagText & "}")
                        otherwise null
        in
            ParsedTag,
    type record),
```

The `tags` column arrives as a string that **sometimes** has surrounding braces and **sometimes** doesn't (Microsoft changed this format mid-2024). The cascading `try ... otherwise` handles both formats and gracefully returns `null` if parsing fails entirely.

```m
AllTagNames = List.Distinct(
    List.Combine(
        List.Transform(
            List.Select(Table.Column(ParsedTags, "TagsParsed"),
                        each _ <> null),
            each Record.FieldNames(_)))),
```

Walks every parsed tag record, extracts the field names, and collects the distinct set across the entire dataset.

```m
ExpandedTags = Table.ExpandRecordColumn(
    ParsedTags, "TagsParsed", AllTagNames,
    List.Transform(AllTagNames, each "Tag_" & _)),
```

Pivots the record column into one column per discovered tag, prefixed with `Tag_` to keep the namespace clean.

> 💡 This is the single most powerful idea in the whole accelerator. You never have to hardcode tag names. Roll out a new tag (`environment`, `owner`, `dataClassification`, ...) on Monday, refresh on Tuesday, slicer appears on Tuesday afternoon.

### Type conversion

```m
Typed = Table.TransformColumnTypes(ExpandedTags, {
    {"date",                       type date},
    {"servicePeriodStartDate",     type date},
    {"servicePeriodEndDate",       type date},
    {"costInBillingCurrency",      type number},
    ...
}, "en-US")
```

Forces correct types using US locale (consistent with the export's number format). Cost columns become `number`, dates become `date`.

---

## 2. `cost-analysis-focus` (FOCUS 1.0 conformed)

This query reads the **same blob files** as `cost-analysis` but applies a different transformation pipeline to produce FOCUS-spec-conformant output.

The first ~50 lines are nearly identical: source, filter, decompress, combine, dedupe, parse + expand tags. Two differences appear after that:

### Difference 1 — Safe type conversion *before* renaming

```m
NumericConverted = Table.TransformColumns(ExpandedTags, {
    {"costInBillingCurrency",
        each try Number.From(_, "en-US") otherwise null,
        type nullable number},
    ...
}),
```

Notice `type nullable number` and `try ... otherwise null`. This is more defensive than the classic query because FOCUS will *also* rename these columns; doing the conversion now ensures we don't lose the chance to catch bad data after the rename.

The same pattern repeats for date columns:

```m
DateConverted = Table.TransformColumns(NumericConverted, {
    {"billingPeriodStartDate",
        each try Date.From(DateTimeZone.FromText(_))
             otherwise try Date.From(_)
             otherwise null,
        type nullable date},
    ...
}),
```

Two fallbacks: first try parsing as a full ISO-8601 datetime-with-timezone, then fall back to a plain date, then give up and return null. Real-world Cost Management exports mix both formats.

### Difference 2 — Massive rename block to FOCUS schema

```m
Renamed = Table.RenameColumns(DateConverted, {
    {"billingAccountId", "x_BillingAccountId"},
    {"billingProfileId", "x_BillingProfileId"},
    ...
    {"costInBillingCurrency", "BilledCost"},
    {"costInUsd", "x_BilledCostInUsd"},
    {"paygCostInBillingCurrency", "EffectiveCost"},
    {"quantity", "ConsumedQuantity"},
    {"unitOfMeasure", "ConsumedUnit"},
    {"benefitId", "CommitmentDiscountId"},
    {"benefitName", "CommitmentDiscountName"},
    ...
}, MissingField.Ignore),
```

Renames ~50 columns to match the FOCUS 1.0 spec. Provider-specific (Azure-only) columns get the `x_` prefix; cloud-portable columns get the FOCUS canonical name.

`MissingField.Ignore` makes the step tolerant of columns that don't exist (e.g. when running against an older export that hasn't been backfilled with all the new fields).

### Final cleanup

```m
CleanCols = Table.SelectColumns(Renamed,
    List.Select(Table.ColumnNames(Renamed),
        each not Text.StartsWith(_, "Column") and _ <> "tags"))
```

Drops the overflow `ColumnN` columns *and* the original `tags` string column (the parsed `Tag_*` columns are kept).

---

## 3. `Dim-tags` (unpivoted tag dimension)

This query is special: it does **not** reach out to blob storage. It references the already-loaded `cost-analysis-focus` table and reshapes it.

### Step 1 — Reference the fact table

```m
Source = #"cost-analysis-focus",
```

The `#"..."` syntax is how M references another query by name when the name contains hyphens.

### Step 2 — Select only `Tag_*` columns

```m
TagColumns = Table.SelectColumns(
    Source,
    List.Select(
        Table.ColumnNames(Source),
        each Text.StartsWith(_, "Tag_")))
```

### Step 3 — Unpivot

```m
Unpivoted = Table.UnpivotOtherColumns(TagColumns, {}, "TagName", "TagValue"),
```

Turns the wide format (one column per tag key) into a tall format (one row per resource-tag pair).

### Step 4 — Clean tag names

```m
CleanedNames = Table.TransformColumns(
    Unpivoted,
    {{"TagName", each Text.Replace(_, "Tag_", ""), type text}}),
```

Strips the `Tag_` prefix that was added in the fact-table expansion step. Now `TagName` reads `costCenter` instead of `Tag_costCenter`.

### Step 5 — Filter, group, count, sort

```m
FilteredRows = Table.SelectRows(CleanedNames,
    each [TagValue] <> null and [TagValue] <> ""),

GroupedCount = Table.Group(
    FilteredRows,
    {"TagName", "TagValue"},
    {{"ResourceCount", each Table.RowCount(_), Int64.Type}}),

Sorted = Table.Sort(GroupedCount,
    {{"TagName", Order.Ascending}, {"TagValue", Order.Ascending}})
```

- Drops null and empty tag values
- Groups to one row per distinct `TagName, TagValue` pair
- Adds a `ResourceCount` showing how many cost rows carried that pair
- Sorts alphabetically

The result is a compact dimension table you can use in slicers, drop into governance visuals, or join via `TREATAS` for tag-scoped measures.

---

## Performance notes

| Concern | Mitigation already in place |
|---------|-----------------------------|
| Refresh time on large containers | The query is **streaming** — Power Query reads each blob lazily and combines them, never holding more than one file in memory at once |
| Schema drift between months | Dynamic tag expansion + `MissingField.Ignore` on every rename |
| Header rows in combined data | The `Deduped` step removes them by self-reference |
| Bad data (corrupted rows, weird dates) | Every type conversion is `try ... otherwise null` |
| Gzipped vs uncompressed CSVs in the same container | Conditional `Binary.Decompress` per row |

## Customization patterns

See [`08-customization.md`](08-customization.md) for:

- Parameterizing the blob URL and container name
- Switching to ADLS Gen2 / Data Lake Storage
- Adding a date-range filter at the query level (faster refresh on multi-year archives)
- Pre-filtering by subscription ID
- Replacing the blob source with a Fabric Lakehouse / SQL endpoint

---

→ Next: [`07-dax-measures.md`](07-dax-measures.md)
