# 02 — Prerequisites

Before you start, make sure you have all of the following.

## 1. Azure permissions

| Resource | Required role |
|----------|---------------|
| Subscription, Resource Group, or Billing Account (whichever scope you want to report on) | **Cost Management Reader** (minimum) — needed to create the export |
| Storage account that will hold the exports | **Storage Blob Data Reader** (minimum to consume) or **Storage Blob Data Contributor** (if Cost Management is also writing here) |

> 💡 If you don't have permissions yet, ask your subscription owner to either grant the roles above or run the export themselves and share the storage container with you.

## 2. Azure Cost Management exports configured

You need at least one of the following exports flowing into a blob container:

### Option A — Classic export (works today on every tenant)

1. Azure portal → **Cost Management + Billing** → **Cost Management** → **Exports**
2. Click **+ Add**
3. Configure:
   - **Export type:** *Daily export of month-to-date costs*
   - **Storage account:** any (we recommend a dedicated one named `finops<env>`)
   - **Container:** `cost-analysis` *(this is the name the accelerator's M query expects — you can change it later)*
   - **Directory:** leave blank or use `mca/`
4. Save and wait for the next export run (24 h or trigger manually with **Run now**).

### Option B — FOCUS export (recommended, lights up page 3)

Same steps as above, but in step 3 choose **Export type: *FOCUS***. This emits the standardised FinOps Foundation schema. Drop the FOCUS files in the **same** container — the Power Query for `cost-analysis-focus` reads from the same path.

> Microsoft is gradually moving every tenant to FOCUS as the default. If your tenant doesn't yet show FOCUS as an option, stick with Option A and revisit later.

## 3. Power BI Desktop

- Download: <https://aka.ms/pbidesktop>
- Version: any modern build (≥ February 2024 recommended for FOCUS column types)
- 64-bit only (the M engine needs the memory headroom for the dynamic tag expansion step)

## 4. Power BI license (only needed for sharing)

| What you want to do | License you need |
|---------------------|------------------|
| Open the `.pbix` locally and refresh on your laptop | **Free** (Power BI Desktop) |
| Publish to *My Workspace* and share with named users | **Power BI Pro** ($10/user/mo) |
| Publish to a workspace + share read-only with a wider org | **Pro for authors + Premium Per User (PPU)** for consumers, or Premium Capacity / Fabric F-SKU |

## 5. Optional but useful

- **VS Code** with the [Power Query / M extension](https://marketplace.visualstudio.com/items?itemName=PowerQuery.vscode-powerquery) — for browsing the `.m` files in `powerbi/queries/`
- **[Tabular Editor 2 (free)](https://tabulareditor.com/)** — if you want to edit DAX measures faster than in Power BI Desktop
- **[DAX Studio](https://daxstudio.org/)** — for tuning measures on large datasets

---

→ Next: [`03-quickstart.md`](03-quickstart.md)
