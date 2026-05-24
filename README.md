<div align="center">

# ☁️ Azure FinOps Cockpit
### *The Power BI accelerator that turns raw Azure billing exports into boardroom-ready FinOps insights — in under 30 minutes.*

![Status](https://img.shields.io/badge/status-ready--to--deploy-brightgreen)
![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-F2C811?logo=powerbi&logoColor=black)
![FOCUS](https://img.shields.io/badge/FOCUS-1.0%20compliant-0078D4)
![Azure](https://img.shields.io/badge/Azure-Cost%20Management-0089D6?logo=microsoftazure&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

**No data warehouse. No paid SaaS. No code.** Just point it at your Azure Cost Management blob export and ship.

[**🚀 Quickstart**](docs/03-quickstart.md) • [**📊 What's Inside**](#-whats-inside) • [**🧭 Docs**](docs/) • [**🛠️ Customize**](docs/08-customization.md)

</div>

---

## 🎯 Why this exists

Every Azure customer asks the same three questions every month:

1. **Where did my money go?** (subscription, service, region, team)
2. **Am I wasting it?** (untagged resources, on-demand spend, missed reservation opportunities)
3. **Is it getting worse?** (month-over-month trend, projection vs. budget)

Microsoft's native Cost Management views answer #1, partially answer #3, and barely touch #2. Most teams end up paying a third-party FinOps SaaS just to get a unified executive view — or hand-rolling spreadsheets that go stale in a week.

**Azure FinOps Cockpit ships all three answers as a single, refreshable Power BI report**, built on top of the data you already have flowing into a storage account.

---

## ✨ What's inside

A three-page Power BI report with **68 pre-built FinOps measures**, dual data-model support (classic MCA exports **+** the open [FOCUS 1.0 specification](https://focus.finops.org)), and a robust Power Query pipeline that handles `.csv`, `.csv.gz`, schema drift, and dynamic resource tags.

| Page | Audience | Key questions answered |
|------|----------|------------------------|
| 🏛️ **Executive Summary** | CFO, CIO, FinOps lead | What did we spend? How does it compare to last month? What's the run-rate? |
| 🏷️ **Tags & Governance** | Platform team, cost-center owners | What % of spend is properly tagged? Which resources are leaking cost-center attribution? |
| 💡 **FinOps Optimization** | FinOps practitioner, cloud architects | How much are we paying at on-demand rates? What's the reservation/savings-plan coverage gap? |

📦 **Bundled artifacts**

- ✅ [`powerbi/Azure_Cost_Management_Template.pbit`](powerbi/Azure_Cost_Management_Template.pbit) — parameterized Power BI Template. Open in Desktop, enter your blob URL + container name when prompted, refresh. No tenant data baked in — drop-in IP for redistribution.
- ✅ [`powerbi/queries-templete/`](powerbi/queries-templete/) — three generic `.m` files (with `<YOUR_STORAGE_ACCOUNT>` placeholders) plus a consolidated `README.md` setup guide. Use these if you're building a model from scratch.
- ✅ [`powerbi/queries-original/`](powerbi/queries-original/) — the original `.m` files as extracted from the source `.pbix`, kept for reference so you can see what working, real-world values look like.
- ✅ [`powerbi/dax/all-measures.dax`](powerbi/dax/all-measures.dax) — all 68 measures in a single file, paste-ready for [Tabular Editor](https://tabulareditor.com) or DAX Studio.
- ✅ [`assets/architecture.svg`](assets/architecture.svg) — architecture diagram for slides and docs.
- ✅ A line-by-line walkthrough of every M query and every measure (in [`docs/`](docs/)).
- ✅ [`azure-setup/setup-azure-exports.md`](azure-setup/setup-azure-exports.md) — portal + Azure CLI + Bicep instructions for configuring the upstream Cost Management exports.

---

## 🧱 Architecture (30-second version)

```
   ┌──────────────────────┐      ┌──────────────────────┐      ┌──────────────────────┐
   │ Azure Cost Management│      │  Azure Blob Storage  │      │ Power BI Desktop /   │
   │   (Scheduled Export) │ ───▶ │  (CSV / CSV.GZ daily)│ ───▶ │ Power BI Service     │
   │  • Classic MCA       │      │  Container:          │      │  • 3 report pages    │
   │  • FOCUS 1.0         │      │  "cost-analysis"     │      │  • 68 DAX measures   │
   └──────────────────────┘      └──────────────────────┘      └──────────────────────┘
```

No middleware. No Synapse. No Databricks. The Power Query pipeline reads CSVs directly from blob, combines them, parses tags dynamically, conforms the FOCUS schema, and lands a star-shaped model. Refresh runs on your existing Power BI capacity (Pro or PPU).

📖 **Full architecture & data model →** [`docs/04-architecture.md`](docs/04-architecture.md)

---

## ⚡ 5-minute Quickstart

> **Prerequisites:** Power BI Desktop (latest), an Azure subscription, and Owner/Contributor on a storage account.

1. **Configure the export** in Azure Cost Management → *Exports* → New export
   - Type: *Daily export of month-to-date costs* (and a *FOCUS* export if you want page 3 lit up)
   - Storage: any blob container — we recommend naming it `cost-analysis`
   - Format: CSV (`.csv.gz` is also supported)
   - 📖 *Full step-by-step in [`azure-setup/setup-azure-exports.md`](azure-setup/setup-azure-exports.md)*
2. **Open** [`powerbi/Azure_Cost_Management_Template.pbit`](powerbi/Azure_Cost_Management_Template.pbit) in Power BI Desktop.
3. **Fill in the two parameter prompts:**
   - `BlobAccountUrl` → `https://<your-storage-account>.blob.core.windows.net`
   - `ContainerName` → `cost-analysis` (or whatever name you used in step 1)
4. **Sign in** with an account that has *Storage Blob Data Reader* on the container.
5. **Refresh** → done. Three dashboards, fully populated.

📖 **Full step-by-step →** [`docs/03-quickstart.md`](docs/03-quickstart.md)

---

## 🧭 Documentation

| # | Doc | Purpose |
|---|-----|---------|
| 01 | [Overview](docs/01-overview.md) | The "why" and the FinOps framing |
| 02 | [Prerequisites](docs/02-prerequisites.md) | Licensing, permissions, export config |
| 03 | [Quickstart](docs/03-quickstart.md) | 5-minute deploy |
| 04 | [Architecture](docs/04-architecture.md) | Data flow + ERD |
| 05 | [Data model](docs/05-data-model.md) | Tables, columns, relationships |
| 06 | [Power Query, explained](docs/06-power-query-explained.md) | Line-by-line walkthrough of all 3 M queries |
| 07 | [DAX measures reference](docs/07-dax-measures.md) | All 68 measures grouped by folder |
| 08 | [Customization](docs/08-customization.md) | Parameterize, rebrand, add measures |
| 09 | [Deployment](docs/09-deployment.md) | Publish to Service, schedule refresh, share |
| 10 | [Troubleshooting](docs/10-troubleshooting.md) | Common errors & fixes |


---

## 📂 Repository layout

```
azure-finops-cockpit/
├── README.md · LICENSE · CONTRIBUTING.md · CHANGELOG.md · .gitignore
├── docs/                              ← 11 markdown guides
├── assets/architecture.svg            ← high-level diagram
├── azure-setup/
│   └── setup-azure-exports.md         ← upstream Azure export configuration
└── powerbi/
    ├── Azure_Cost_Management_Template.pbit   ← parameterized template (open this)
    ├── dax/all-measures.dax                  ← all 68 measures, paste-ready
    ├── queries-templete/                     ← generic .m files + setup README
    │   ├── 01-cost-analysis.m
    │   ├── 02-cost-analysis-focus.m
    │   ├── 03-dim-tags.m
    │   └── README.md                         ← consolidated paste-in instructions
    └── queries-original/                     ← reference: original M code from source
        ├── 01-cost-analysis.m
        ├── 02-cost-analysis-focus.m
        └── 03-dim-tags.m
```

---

## 👥 Who is this for?

| Role | What you get |
|------|--------------|
| **FinOps practitioner** | A working baseline you can fork, extend, and rebrand per customer in hours, not weeks. |
| **Cloud architect / Platform lead** | A single source of truth for cloud spend with tag-governance visibility. |
| **CFO / Finance partner** | An executive-ready dashboard without a SaaS subscription or BI consultant. |
| **Consulting partner** | A presales asset + delivery accelerator you can ship as IP under your own brand. |

---

## 🪪 License & attribution

MIT — use it, fork it, rebrand it, ship it.

The FOCUS specification is © FinOps Foundation, released under CC-BY-4.0. Microsoft Azure and Power BI are trademarks of Microsoft Corporation.

---

## 🤝 Contributing

PRs welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the development workflow, naming conventions, and release process.

---

<div align="center">

**Built on the FinOps Foundation FOCUS spec • Refreshed daily • Zero SaaS lock-in**

</div>
