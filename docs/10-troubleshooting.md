# 10 — Troubleshooting

Common errors when first opening or refreshing the report, with their fixes.

## "We couldn't authenticate with the credentials provided"

| Symptom | Cause | Fix |
|---------|-------|-----|
| Auth fails repeatedly with org account | Account doesn't have Storage Blob Data Reader on the container | Ask the storage owner to grant the role; wait 5 min for propagation |
| Auth fails with account key | Wrong key, or key was rotated | Copy the key fresh from the portal (Storage account → Access keys → key1) |
| Auth window closes immediately | Conditional Access policy blocking | Talk to your Entra ID admin — may need to add Power BI as a trusted app |

## Refresh succeeds but visuals show "(Blank)"

Almost always one of these:

1. **Wrong container name.** The query looks for a container literally named `cost-analysis`. Check spelling, casing, and that the container exists. Fix in `Source` step or via the parameter (see [Customization](08-customization.md#parameterize-the-container-name)).
2. **Container is empty.** Check that Cost Management has actually written any files yet — first export run can take up to 24h.
3. **Files all named `manifest*`.** The M query filters these out. If you only have manifest files and no data files, your export hasn't run yet.
4. **Files have unexpected extensions** (`.txt`, `.zip`, etc). The filter expects `.csv` or `.csv.gz` only.

## "Expression.Error: The column 'X' of the table wasn't found"

Cost Management changed an export column name. Two paths:

- **Quick fix:** Open Power Query → find the failing step (usually one of the `Rename` steps) → click the gear icon → re-pick the new column name.
- **Robust fix:** Wrap the failing step in a `try ... otherwise` and provide a fallback. The `Renamed` step in `cost-analysis-focus` already uses `MissingField.Ignore` — extend the same idea to the failing step.

## Refresh runs forever / times out at 2 hours

Power BI Service has a hard 2-hour refresh limit (Pro) / longer on Premium. If you hit it:

1. **Add a date-range filter** in M to limit how far back the query reads — see [Customization → Add a date-range filter](08-customization.md#add-a-date-range-filter-faster-refresh-on-multi-year-archives).
2. **Move to Fabric / Direct Lake** — see [Customization → Upgrade to Fabric](08-customization.md#upgrade-to-fabric--direct-lake-large-tenants).
3. **Pre-compress** files at the source (Cost Management can emit `.csv.gz` directly — switch the export to compressed if it isn't already).

## "Expression.Error: We cannot convert the value null to type Logical"

The `chargeType` column is missing from older Microsoft exports. Two options:

- Update the filter to be null-safe:
  ```m
  MCA_Rows = Table.SelectRows(Deduped, each
    [chargeType] <> null and List.Contains({"Usage","Purchase",...}, [chargeType])),
  ```
- Or remove the charge-type filter entirely if you're working with a single-month dataset where it doesn't matter.

## Tags show up but are all `null`

The `tags` column format changed in mid-2024 — older exports use `"key": "value"` (no surrounding braces), newer ones use `{"key": "value"}`. The shipped query handles both via cascaded `try ... otherwise`. If yours still fails:

1. Open Power Query → click on a row in the `tags` column → look at the actual raw value in the *Value* preview pane (bottom).
2. Adjust the `Json.Document` step to match the format you see.

Example for a third format `key=value;key2=value2`:
```m
ParsedTag = try
    Record.FromList(
        List.Transform(Text.Split(TagText, ";"),
            each Text.AfterDelimiter(_, "=")),
        List.Transform(Text.Split(TagText, ";"),
            each Text.BeforeDelimiter(_, "=")))
    otherwise null
```

## DAX measures return blank where I expect a number

Most common cause: the measure references the **wrong fact table** for the data you have loaded. If you only loaded FOCUS exports, the `Total Cost USD` measure (which uses `cost-analysis`) will be blank — use `FOCUS Total Billed Cost` instead. And vice versa.

Cross-reference your data source:

| If you only have… | Use measures starting with… |
|-------------------|----------------------------|
| Classic MCA exports | `Total`, `MTD`, `Distinct`, `Cost by`, `Tagged`, `Untagged`, `Daily Avg` |
| FOCUS exports | `FOCUS …` |

## Auto Date/Time errors after disabling it

If you turn off Auto Date/Time without first repointing visuals at a manual date table, you'll get "Field is invalid" errors on every visual that used an auto-date hierarchy. Fix:

1. For each broken visual, drop the broken hierarchy
2. Drag in `Date[Date]` from the manually-defined `Date` table (the one with the `_StartDate = DATE(2026, 1, 1)` expression — adjust years to your data range)
3. Re-apply formatting

## "Formula.Firewall: Query references other queries, so it may not directly access a data source"

Power BI's privacy-firewall thinks the `Dim-tags` query (which references `cost-analysis-focus`) is unsafe.

Fix: **File → Options → Current file → Privacy → Always ignore Privacy Level settings**.

(Yes, the toggle is a no-op for this scenario but it's the documented workaround.)

## I see ".gz" files but the M query says it can't read them

You're on an older Power BI Desktop. `Binary.Decompress(_, Compression.GZip)` requires the November 2020 release or newer. Update Desktop.

---

Anything not covered here? Open an issue in the repo (`label: bug` or `label: question`), or check the [Power BI community](https://community.fabric.microsoft.com/).
