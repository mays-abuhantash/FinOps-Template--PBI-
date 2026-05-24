# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial public release.
- Three Power BI report pages: Executive Summary, Tags & Governance, FinOps Optimization Analysis.
- Two fact-table queries: `cost-analysis` (classic MCA) and `cost-analysis-focus` (FOCUS 1.0).
- One derived dimension: `Dim-tags`.
- 68 DAX measures across 6 display folders, each with a description.
- Dynamic tag-column expansion (no hardcoded tag names — every distinct tag key in your tenant becomes its own `Tag_*` column at refresh).
- `HasTags` boolean column on the fact tables — a tenant-independent helper that powers the tag-coverage measures.
- Parameterized `.pbit` template with `BlobAccountUrl` and `ContainerName` Power Query parameters; both prompted on first open.
- Two parallel query sets in [`powerbi/`](powerbi/):
  - [`queries-templete/`](powerbi/queries-templete/) — generic `.m` files with `<YOUR_STORAGE_ACCOUNT>` and `<YOUR_CONTAINER_NAME>` placeholders, plus a consolidated `README.md` paste-in guide.
  - [`queries-original/`](powerbi/queries-original/) — original `.m` files preserved as a reference example of working real-world values.
- Consolidated `.dax` file with all 68 measures in [`powerbi/dax/all-measures.dax`](powerbi/dax/all-measures.dax) — paste-ready for Tabular Editor / DAX Studio.
- Full Power Query line-by-line documentation in [`docs/06-power-query-explained.md`](docs/06-power-query-explained.md).
- Full DAX measures reference in [`docs/07-dax-measures.md`](docs/07-dax-measures.md).
- Architecture diagram at [`assets/architecture.svg`](assets/architecture.svg).
- Maintainer-side guide for regenerating the `.pbit` after model changes: [`docs/how-to-generate-pbit.md`](docs/how-to-generate-pbit.md).
- Azure-side export configuration walkthroughs (portal, Azure CLI, Bicep) in [`azure-setup/setup-azure-exports.md`](azure-setup/setup-azure-exports.md).

### Changed
- 4 FOCUS tag-coverage measures (`FOCUS Tagged Cost`, `FOCUS Untagged Cost`, `FOCUS Tagged Resources Count`, `FOCUS Untagged Resources Count`) rewritten to use the `HasTags` boolean column instead of hardcoded tenant-specific tag column names. The original versions referenced `Tag_Environment`, `Tag_Project`, `Tag_business owner`, etc. — those columns don't exist outside the original tenant and would have broken on any other deployment.
- Power BI artifact renamed to `Azure_Cost_Management_Template.pbit` (previously `CAIT-Azure-Cost-Management.pbit`) to drop tenant-specific branding from the redistributable filename.
- Setup-azure-exports moved from `scripts/` to a top-level `azure-setup/` folder to make it more discoverable.
- The `queries/` folder was split into `queries-templete/` (parameterized, generic) and `queries-original/` (reference, original).

### Removed
- The pre-shipped `.pbix` — only the parameterized `.pbit` is now distributed, so the package contains no tenant data and no hardcoded connection strings.
- The `scripts/pbix_to_pbit.py` Python converter — superseded by Power BI Desktop's built-in *File → Export → Power BI template*. See [`docs/how-to-generate-pbit.md`](docs/how-to-generate-pbit.md).

## [1.0.0] — TBD

First tagged release.
