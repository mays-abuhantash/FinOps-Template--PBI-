# 03 — Quickstart (5 minutes)

This guide gets you from zero to a working dashboard on your own Azure tenant in about five minutes, assuming you've already completed [`02-prerequisites.md`](02-prerequisites.md).

## TL;DR

1. Open the `.pbit`
2. Enter your blob URL when prompted
3. Sign in
4. Click *Refresh*
5. ✅ Three working dashboards

## Step-by-step

### Step 1 — Open the template

In `powerbi/`, double-click **`Azure-Cost-Management.pbit`**.

Power BI Desktop opens with a parameter prompt asking for your storage account URL.

> 🪧 **Why a `.pbit` and not a `.pbix`?** A `.pbit` (Power BI Template) ships the report layout, data model, and queries — but **no data**. It's the right format for redistributing this as IP, because the recipient enters their own connection details and gets their own data, with no leakage of yours.

> If you'd rather work with the `.pbix`, see [Variation A](#variation-a--using-the-pbix-instead) at the bottom of this doc.

### Step 2 — Enter your blob URL

The prompt asks for **Storage account blob endpoint**. Format:

```
https://<your-storage-account-name>.blob.core.windows.net
```

Examples:
- `https://contoso-finops.blob.core.windows.net` ✅
- `https://contoso-finops.blob.core.windows.net/cost-analysis` ❌ (don't include the container; it's hardcoded in the query — see [`08-customization.md`](08-customization.md) to change it)

Click **Load**.

### Step 3 — Authenticate

Power BI prompts for credentials. Choose:

- **Account key** — paste the storage key from the portal *(simplest for a first run)*; **OR**
- **Organizational account** — sign in with your Entra ID account *(recommended for production; requires Storage Blob Data Reader on the container)*

Click **Connect**.

### Step 4 — Wait for refresh

The first refresh reads every CSV in the container, parses tags dynamically, conforms the FOCUS schema, and builds the model. Expect:

| Data volume | First-refresh time |
|-------------|--------------------|
| < 1 month of one subscription | < 1 minute |
| 1 year, multi-sub | 3–8 minutes |
| Enterprise (10+ subs, daily files for a year) | 10–25 minutes |

### Step 5 — Explore

You should now see three pages along the bottom:

1. **Executive Summary** — top-line KPIs, trend, breakdowns
2. **Tags & Governance** — tagging coverage, untagged spend
3. **FinOps Optimization Analysis** — on-demand vs. committed, RI/SP coverage, potential savings

If a page shows blanks or errors, jump to [`10-troubleshooting.md`](10-troubleshooting.md).

### Step 6 — Save your customized copy

**File → Save As → `MyCompany-FinOps-Cockpit.pbix`** — this saves *with your connection details and refreshed data*, ready to publish.

To create a redistributable template for a different customer, use **File → Export → Power BI template (.pbit)**.

---

## Variation A — Using the `.pbix` instead

If you opened `<MYCOMPANY>-Azure-Cost-Management.pbix` directly:

1. Power BI shows the **existing cached data** from when the model was last refreshed by the original author.
2. To re-point it at your tenant:
   - Home → **Transform data** → **Data source settings**
   - Select the existing blob source → **Change Source…**
   - Replace the URL with your own
   - Click **OK**, then **Refresh**.

---

## Variation B — Connecting to a different container name

If your container isn't named `cost-analysis`, edit the M code:

1. Home → **Transform data**
2. Select the `cost-analysis` query
3. In the **Container** step, change:
   ```m
   Container = Source{[Name="cost-analysis"]}[Data],
   ```
   to your container name, e.g.
   ```m
   Container = Source{[Name="my-finops-exports"]}[Data],
   ```
4. Repeat for the `cost-analysis-focus` query.
5. **Close & Apply**.

A cleaner approach is to parameterize the container name — see [`08-customization.md`](08-customization.md).

---

→ Next: [`04-architecture.md`](04-architecture.md)
