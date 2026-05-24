# Power Query (M) — Setup instructions

This folder contains three Power Query / M files that load and reshape Azure Cost Management exports into a clean star-shaped model:

| File | What it does | External source | Needs configuration? |
|------|--------------|-----------------|----------------------|
| [`01-cost-analysis.m`](01-cost-analysis.m) | Reads classic MCA cost-management CSV exports and lands them as the `cost-analysis` table. | Azure Blob Storage | ✅ Yes — 2 values |
| [`02-cost-analysis-focus.m`](02-cost-analysis-focus.m) | Reads the **same files** and reshapes them to match the open [FOCUS 1.0 specification](https://focus.finops.org). | Azure Blob Storage | ✅ Yes — same 2 values |
| [`03-dim-tags.m`](03-dim-tags.m) | Derives an unpivoted tag dimension from `cost-analysis-focus`. | None (in-model only) | ❌ No |

> 💡 **If you're using the shipped `.pbit` template** (`../CAIT-Azure-Cost-Management.pbit`), the two configuration values below are already wired up as Power Query parameters — you'll be prompted for them on first open and don't need to edit any M code by hand. The instructions on this page apply only if you're pasting these `.m` files into a new model from scratch.

---

## The two values you need to configure

Both query 1 and query 2 read from the same storage location. You'll plug the same two values into both files.

### ① Storage account name → goes into `AccountUrl`

| Field | Detail |
|-------|--------|
| **What it is** | The name of the Azure Storage account that receives Cost Management exports. |
| **Where to find it** | Azure portal → **Cost Management + Billing** → **Cost Management** → **Exports** → click your export → look under **Destination** for **Storage account**. |
| **Example value** | `contosofinops` |
| **Where it gets used** | The `AccountUrl` line at the top of the `let` block in `01-cost-analysis.m` and `02-cost-analysis-focus.m`. |

The full URL the M code expects is `https://<that-name>.blob.core.windows.net`, e.g. `https://contosofinops.blob.core.windows.net`.

### ② Container name → goes into `ContainerName`

| Field | Detail |
|-------|--------|
| **What it is** | The blob container inside the storage account that the export writes its CSV files into. |
| **Where to find it** | Same export-config page as above — the **Container** field, right below **Storage account**. |
| **Common value** | `cost-analysis` |
| **Where it gets used** | The `ContainerName` line at the top of the `let` block in `01-cost-analysis.m` and `02-cost-analysis-focus.m`. |

> 📦 Don't have exports configured yet? See [`../../scripts/setup-azure-exports.md`](../../scripts/setup-azure-exports.md) for click-by-click portal, Azure CLI, and Bicep setup paths.

---

## Per-file walkthrough

### `01-cost-analysis.m`

Open the file. Near the top of the `let` block, find these two lines:

```m
AccountUrl    = "https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net",
ContainerName = "<YOUR_CONTAINER_NAME>",
```

Replace `<YOUR_STORAGE_ACCOUNT>` with your value from ① and `<YOUR_CONTAINER_NAME>` with your value from ②. Keep the quotation marks.

**Output table name:** `cost-analysis` (set automatically when you paste into Power Query — see the *Pasting into Power BI Desktop* section below).

**What the query does, in order:**

1. Connects to blob storage and selects the container.
2. Filters to `.csv` and `.csv.gz` files, skipping manifest JSON.
3. Decompresses gzipped files inline.
4. Combines all files, promotes headers, removes duplicate header rows.
5. Keeps only rows with a valid `chargeType` (`Usage`, `Purchase`, `Tax`, `Adjustment`, `Refund`, `UnusedReservation`, `RoundingAdjustment`).
6. Drops `ColumnN` overflow columns (artifact of ragged source rows).
7. Adds a **`HasTags` boolean column** (true if the row has any tags) — used by the tag-coverage measures.
8. Parses the `tags` JSON column — handles both `{"k":"v"}` and bare `"k":"v"` formats.
9. **Dynamically expands** discovered tag keys into `Tag_*` columns (no hardcoded tag list).
10. Sets data types on known numeric and date columns.

### `02-cost-analysis-focus.m`

Same two replacements as query 1. The values are identical:

```m
AccountUrl    = "https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net",
ContainerName = "<YOUR_CONTAINER_NAME>",
```

**Output table name:** `cost-analysis-focus`.

**What's different from query 1:**

- Adds a **`HasTags` boolean column** before tag expansion. This is the generic, tenant-independent way to power the 4 FOCUS tag-coverage measures — no hardcoded tag names.
- Defensive numeric and date conversion (`try ... otherwise null`) on every cost / quantity / date column, with `nullable` types so bad rows don't blow up the whole refresh.
- **Renames ~50 columns** to the FOCUS 1.0 canonical schema (`BilledCost`, `EffectiveCost`, `ServiceCategory`, `ResourceRegion`, etc.). Azure-only columns get an `x_` prefix (`x_BillingAccountId`, `x_PricingModel`, etc.). `MissingField.Ignore` makes the rename block resilient to schema drift in older exports.
- Drops the raw `tags` column and `ColumnN` overflow columns at the end.

### `03-dim-tags.m`

**Nothing to configure.** This query doesn't connect to external storage — it derives its rows from the already-loaded `cost-analysis-focus` table.

If you rename the `cost-analysis-focus` query, update the `Source` step in this file:

```m
Source = #"cost-analysis-focus",   // ← change "cost-analysis-focus" if you renamed it
```

**Output table name:** `Dim-tags`.

**What the query does:**

1. References the `cost-analysis-focus` table by name (the `#"..."` syntax is how M references query names containing hyphens).
2. Keeps only `Tag_*` columns.
3. Unpivots them into a tall `(TagName, TagValue)` shape.
4. Strips the `Tag_` prefix from `TagName` for readability.
5. Filters out null / blank tag values.
6. Groups to one row per distinct `(TagName, TagValue)` pair with a `ResourceCount`.
7. Sorts alphabetically.

Use this as the source for slicers, governance visuals, and Q&A questions like *"how many resources carry the environment=prod tag?"*.

---

## Better practice: use Power Query parameters

Instead of editing the M code by hand each time you redeploy to a new tenant, define two **Power Query parameters** and reference them from the queries. This is what the shipped `.pbit` does.

### Setup (one-time, ~30 seconds)

1. In Power BI Desktop: **Home → Transform data** to open the Power Query Editor.
2. **Home → Manage parameters → New** — create two parameters:

   | Name | Type | Suggested values | Current value |
   |------|------|------------------|---------------|
   | `BlobAccountUrl` | Text | Any value | `https://<your-storage-account>.blob.core.windows.net` |
   | `ContainerName` | Text | Any value | `cost-analysis` |

3. In `01-cost-analysis.m` and `02-cost-analysis-focus.m`, replace the literal strings with the parameter names (no quotes):

   ```m
   AccountUrl    = BlobAccountUrl,
   ContainerName = ContainerName,
   ```

4. **Close & Apply.**

Now switching tenants is two clicks (**Home → Transform data → Edit parameters**) instead of opening and re-editing every `.m` file.

---

## Pasting into Power BI Desktop

If you're building the model from scratch using these three `.m` files (rather than opening the shipped `.pbit`):

1. Open Power BI Desktop → **Home → Get data → Blank query → Connect**.
2. **Home → Advanced Editor**.
3. Paste the contents of `01-cost-analysis.m` (with your two values filled in).
4. **Done**. In the *Queries* pane on the left, **rename the query** to `cost-analysis` (must match exactly — query 3 references this name).
5. Repeat for `02-cost-analysis-focus.m` → rename to `cost-analysis-focus`.
6. Repeat for `03-dim-tags.m` → rename to `Dim-tags`.
7. **Home → Close & Apply.**
8. First refresh may take 1–10 minutes depending on how many CSV files are in your container.

---

## Validation checklist

Before you click *Close & Apply* for the first time, sanity-check:

- [ ] Both `01-cost-analysis.m` and `02-cost-analysis-focus.m` have **the same** `AccountUrl` and `ContainerName` values.
- [ ] `AccountUrl` includes `https://` and ends with `.blob.core.windows.net` (no trailing slash, no container in the URL).
- [ ] `ContainerName` is the container name only (e.g. `cost-analysis`), not a path.
- [ ] The account you signed in with has **Storage Blob Data Reader** on the storage account.
- [ ] At least one `.csv` or `.csv.gz` file exists in the container (not just `manifest.json`).

Stuck? → [`../../docs/10-troubleshooting.md`](../../docs/10-troubleshooting.md) covers the common errors.

---

## See also

- [`../../docs/06-power-query-explained.md`](../../docs/06-power-query-explained.md) — line-by-line walkthrough of every M step
- [`../../docs/05-data-model.md`](../../docs/05-data-model.md) — full data-model reference (tables, columns, types, relationships)
- [`../../docs/08-customization.md`](../../docs/08-customization.md) — ADLS Gen2, date-range filters, subscription pre-filters, multi-cloud variants
