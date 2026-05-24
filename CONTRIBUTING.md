# Contributing to Azure FinOps Cockpit

Thanks for your interest. Contributions of any size are welcome — bug fixes, new measures, new report pages, documentation polish, themes, or multi-cloud adaptations. This document explains how the project is laid out, the conventions we follow, and the workflow for getting changes merged.

If anything below is unclear or contradicts the code, **the code wins** — please open an issue or PR to fix the docs.

---

## Quick links

- 🐛 [File a bug](../../issues/new?labels=bug) — include the error message, the step that produced it, and your Power BI Desktop version.
- 💡 [Propose a feature](../../issues/new?labels=enhancement) — for anything non-trivial, open this *before* you start coding to align on scope.
- 📖 [Improve docs](../../issues/new?labels=docs) — typos, broken links, unclear instructions all welcome.
- ❓ [Ask a question](../../issues/new?labels=question) — when you're not sure if it's a bug or expected behavior.

---

## Repository layout (what lives where)

```
azure-finops-cockpit/
├── README.md                                   ← entry point — start here when you fork
├── LICENSE                                     ← MIT
├── CHANGELOG.md                                ← every meaningful change goes here
├── CONTRIBUTING.md                             ← this file
├── .gitignore
│
├── assets/
│   └── architecture.svg                        ← high-level data-flow diagram
│
├── azure-setup/
│   └── setup-azure-exports.md                  ← upstream Azure Cost Management config
│
├── docs/                                       ← 11 markdown guides, numbered for reading order
│   ├── 01-overview.md  …  10-troubleshooting.md
│   ├── faq.md
│   └── how-to-generate-pbit.md                 ← maintainer-side .pbit regeneration
│
└── powerbi/
    ├── Azure_Cost_Management_Template.pbit     ← the parameterized deliverable
    ├── dax/all-measures.dax                    ← all 68 measures as a single source file
    ├── queries-templete/                       ← generic, redistributable .m files + README
    └── queries-original/                       ← reference: pre-template .m files
```

A change touching the data model usually touches *several* of these files at once. The "Update the right files" checklist below shows which.

---

## Development workflow

### 1. Open an issue first (for non-trivial changes)

Anything that adds a measure, changes the model schema, or alters report behavior should start with an issue. It saves you from building something we'd want to scope differently. Typos and one-line fixes don't need this — go straight to PR.

### 2. Fork and branch

Branch naming:

| Prefix | Use for |
|--------|---------|
| `feat/` | new measure, new page, new visual, new query parameter |
| `fix/` | bug fix in M code, DAX, or docs |
| `docs/` | documentation-only changes |
| `chore/` | refactors, formatting, dependency bumps |

Example: `feat/add-anomaly-detection-measures`, `fix/dim-tags-null-handling`.

### 3. Set up locally

You'll need:

- **Power BI Desktop** (latest stable, 64-bit).
- An Azure tenant with at least one Cost Management export flowing into a blob container, or a sample dataset you own.
- *(Optional but recommended)* [Tabular Editor 2](https://tabulareditor.com) and [DAX Studio](https://daxstudio.org/) — both free, both make DAX work much faster than the built-in Power BI editor.

### 4. Make changes — and edit the right files

The project ships several parallel views of the same model. When you change one, **you almost always have to change the others too**. Use this checklist:

| Change | Files to update |
|--------|----------------|
| Add/edit a **DAX measure** | • `Azure_Cost_Management_Template.pbit` (the model itself) <br> • `powerbi/dax/all-measures.dax` <br> • `docs/07-dax-measures.md` |
| Change a **Power Query (M)** | • `Azure_Cost_Management_Template.pbit` (the model itself) <br> • `powerbi/queries-templete/<file>.m` (keep `<YOUR_…>` placeholders) <br> • Leave `powerbi/queries-original/` alone — it's a historical reference, not a current artifact <br> • `docs/06-power-query-explained.md` if the change is visible end-to-end |
| Add a **new report page** | • The `.pbit` <br> • `docs/01-overview.md` (page table) <br> • `README.md` (page table) |
| Change the **data model** (tables, columns, relationships) | • The `.pbit` <br> • `docs/05-data-model.md` |
| Add a **new dependency or parameter** | • The `.pbit` <br> • `docs/02-prerequisites.md` and/or `docs/03-quickstart.md` |
| Anything visible to the user | • `CHANGELOG.md` under `## [Unreleased]` |

### 5. Test against real data

The accelerator's behavior is impossible to validate without real billing data. Before opening a PR:

1. Open `powerbi/Azure_Cost_Management_Template.pbit` in Power BI Desktop.
2. Fill in the two parameters with **your own** storage account and container.
3. Wait for the first refresh.
4. Open every page; confirm:
   - No visual displays an error icon.
   - The KPIs on Executive Summary are non-zero (sanity check that data is flowing).
   - Slicers update visuals (sanity check that relationships work).
5. If your change touches the Tags page, verify with a tenant that has tags *and* one that has none.
6. **File → Save As → `working.pbix`** to keep your local working copy. **Do not commit the `.pbix`** — only the regenerated `.pbit` (see step 7).

### 6. Keep PRs small

One feature or fix per PR. A PR that adds two unrelated measures and rewrites four queries is hard to review and risky to revert. Split it.

### 7. Regenerate the `.pbit` before pushing

After you've edited the model in Desktop and saved your working `.pbix`:

1. **File → Export → Power BI template**.
2. Description: leave generic — e.g. *"Azure FinOps Cockpit — Power BI accelerator on Azure Cost Management exports"*.
3. Save over `powerbi/Azure_Cost_Management_Template.pbit`.
4. Commit the regenerated `.pbit` along with your code/doc changes.

Full instructions in [`docs/how-to-generate-pbit.md`](docs/how-to-generate-pbit.md).

### 8. Update the CHANGELOG

Add a one-line bullet under `## [Unreleased]` in the appropriate subsection (`### Added`, `### Changed`, `### Fixed`, `### Removed`). Don't bump the version — the maintainer cuts releases.

### 9. Open the PR

In the PR description, include:

- A one-sentence summary of what changes and why.
- A link to the issue (if applicable).
- A screenshot of the relevant report page **before** and **after**, when the change is visible.
- The list of files in the checklist above that you actually edited.
- Anything reviewers should specifically pay attention to.

---

## Naming conventions

### Measures

- **Title Case with spaces** — `Total Billed Cost`, not `total_billed_cost` or `TotalBilledCost`.
- **FOCUS-spec measures get a `FOCUS ` prefix** — `FOCUS Total Billed Cost`. The prefix groups them in the field list and makes the schema explicit.
- **Abbreviations** — only well-known ones: `MTD`, `YoY`, `MoM`, `RI` (Reserved Instance), `SP` (Savings Plan), `USD`. Spell out everything else.
- **Always set a `Description`** (Properties pane → Description). It surfaces as a tooltip in the field list, and Q&A / Copilot use it.
- **Format string** is set on the measure, not the visual — so it persists if the visual is rebuilt.

### Display folders

The leading emoji is intentional. Power BI sorts folders alphabetically and the emoji forces a deterministic order. Stick to these six:

| Folder | Use for |
|--------|---------|
| `💰 Cost Totals` | Sum / aggregate cost measures |
| `📅 Time Intelligence` | MTD, YoY, MoM, projections, daily averages |
| `📊 Counts` | Distinct counts, headcounts, max/min |
| `🔍 Breakdowns` | Group-by-dimension, top-N, share-of-total |
| `🏷️ Tags` | Tagging coverage & governance |
| `💰 FinOps Optimization` | Reservation/Savings-Plan coverage, on-demand %, potential savings |

If your measure doesn't fit any of these, propose a new folder in the PR description — don't quietly invent one.

### Power Query (M) code

- **No hardcoded column lists** in `Table.SelectColumns` — always derive dynamically from `Table.ColumnNames`. The tag-expansion pattern is the canonical example.
- **Defensive types** — use `try Number.From(_, "en-US") otherwise null` (or the equivalent for dates). The export schema drifts; don't let one bad row break a year of refresh.
- **`MissingField.Ignore`** on every `Table.RenameColumns` block that renames source columns. Older exports won't have the newest columns.
- **Step names in PascalCase** — `ParsedTags`, `ExpandedTags`, `CleanCols`. One concern per step.
- **Comment liberally** — Power Query gets opaque fast. Every non-obvious step deserves a one-line `//` comment above it.
- **Parameterize, don't hardcode** — the `.pbit` references `BlobAccountUrl` and `ContainerName` parameters. Don't merge a PR that hardcodes a storage URL in a redistributable file.

### DAX

- **No deprecated patterns** — use `DIVIDE(a, b, 0)`, not `IF(b = 0, 0, a/b)`.
- **`VAR` for clarity** — long expressions get variables, not nested chains.
- **Measure-on-measure composition** preferred over re-summing physical columns.
- **Use the `_Measures` table** — all measures live there. Don't attach measures to fact tables.

### Documentation

- Doc files are numbered (`01-`, `02-`, …) to control reading order in GitHub's file browser.
- One `#` H1 per file, at the top.
- Code blocks always have language hints — ` ```m `, ` ```DAX `, ` ```bash `, ` ```json `.
- Cross-link with relative paths: `[03-quickstart.md](03-quickstart.md)`. Never hardcode `github.com/...` URLs.
- Each numbered doc ends with a `→ Next: [...]` link.

---

## Release process *(maintainers)*

A release goes out when meaningful change has accumulated under `## [Unreleased]`.

1. **Reconcile `CHANGELOG.md`**
   - Rename `## [Unreleased]` to `## [vX.Y.Z] — YYYY-MM-DD`.
   - Create a fresh empty `## [Unreleased]` section above it.
2. **Confirm the `.pbit` is current** — open it in Power BI Desktop, refresh against a known tenant, and re-export if the model changed since the last commit (see [`docs/how-to-generate-pbit.md`](docs/how-to-generate-pbit.md)).
3. **Tag the release** in git:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```
4. **Cut a GitHub Release** from the tag.
   - Title: `vX.Y.Z`
   - Body: paste the CHANGELOG section for this version.
   - Attach: `Azure_Cost_Management_Template.pbit` as a release asset.
5. **Update README badges** if the version is referenced anywhere.

Versioning follows [SemVer](https://semver.org/):

| Bump | When |
|------|------|
| **MAJOR** (1.x → 2.0) | Breaking model change — a measure or table is removed/renamed, requiring downstream report rework. |
| **MINOR** (1.0 → 1.1) | New measures, new pages, new docs — backwards-compatible additions. |
| **PATCH** (1.0.0 → 1.0.1) | Bug fixes, doc fixes, refactors with no visible change. |

---

## Code of conduct

Be excellent to each other. Critique ideas, not people. We follow the [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

---

## License

By submitting a contribution, you agree it's licensed under the project's [MIT License](LICENSE).
