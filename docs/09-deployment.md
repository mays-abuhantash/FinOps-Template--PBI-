# 09 — Deployment

Once you have a working `.pbix` on your laptop, deploy it to Power BI Service so your stakeholders can consume it.

## Step 1 — Publish to a workspace

1. In Power BI Desktop with your file open: **Home → Publish**
2. Sign in if prompted.
3. Pick a workspace. *(Don't publish to "My workspace" if more than one person will consume the report — it can't be shared.)*

You now have **a dataset** and **a report** in the workspace.

## Step 2 — Configure scheduled refresh

1. In Power BI Service, navigate to the workspace → **Datasets → ⋯ → Settings**
2. Expand **Data source credentials** → **Edit credentials** for the Azure Blob source
3. Authentication method:

   | Method | Use when |
   |--------|----------|
   | **OAuth2** | Storage account has Entra ID auth enabled and the service principal / your account has *Storage Blob Data Reader* |
   | **Account key** | Quick test / dev. Less secure — anyone who can read the dataset settings can read the key. |

4. **Privacy level:** *Organizational*
5. **Sign in / save**

6. Expand **Scheduled refresh**
7. Toggle **On**
8. Pick a daily window 1–2 hours **after** your Cost Management export's scheduled time (give Azure time to finish writing).
9. Optionally add a second time-slot if you want morning and afternoon refreshes.
10. **Apply**.

## Step 3 — Share

Two ways to share, depending on audience size:

### Option A — Share the report directly (small audience, <50 people)

- Open the report → **Share** → enter user emails → set permissions → Send

### Option B — Publish a Power BI App (preferred for org-wide rollout)

- Workspace → **Create app** (top-right)
- Add your three pages
- Set audience(s) — you can have a single audience or multiple audiences (e.g. "Executives" sees only page 1, "FinOps team" sees all three)
- Publish

App URL becomes a stable, shareable link that doesn't break when the underlying report is re-published.

## Step 4 — (Optional) Set up alerts

Power BI Service supports **data-driven alerts** on KPI / Card visuals. Useful here for:

- "Tagging Coverage % drops below 80%"
- "OnDemand % rises above 60%"
- "MoM Cost Change % exceeds +15%"

To set:

1. Click any KPI or Card visual in the published report
2. Click the bell icon → **Manage alerts** → **+ Add alert rule**
3. Choose the threshold and frequency
4. Save — you'll get an email + a Teams notification (if integrated) when the threshold is crossed.

## Step 5 — Embedding (optional)

If you want the report inside your own internal portal or SharePoint page:

| Method | Best for |
|--------|----------|
| **Embed → Website or portal** | Power BI handles auth, viewer needs a Power BI license |
| **SharePoint web part** | Drop the URL into a SharePoint Online page |
| **Teams tab** | Add the report as a tab inside a Teams channel |
| **Embed for your customers (Embedded SKUs)** | If you're an ISV reselling this as IP — needs an A or EM Embedded SKU |

## Promotion & certification

Once stable, mark the dataset as **Promoted** (any contributor can do this) or work with your Power BI admin to **Certify** it (admin-only). This surfaces it in search results and lets others build their own reports on top of the same model.

## CI/CD (optional, for serious consulting use)

For partner / consulting scenarios where you ship updates to multiple customers:

- **[Power BI Deployment Pipelines](https://learn.microsoft.com/en-us/power-bi/create-reports/deployment-pipelines-overview)** — built-in Dev → Test → Prod promotion
- **[Tabular Editor + Azure DevOps](https://docs.tabulareditor.com/onprem/te2/Advanced-features/Devops.html)** — full git-based model versioning
- **[pbi-tools](https://github.com/pbi-tools/pbi-tools)** — open-source CLI to source-control `.pbix` files as expanded JSON

---

→ Next: [`10-troubleshooting.md`](10-troubleshooting.md)
