// ============================================================================
// Azure FinOps Cockpit — Dim-tags (unpivoted tag dimension)
// ============================================================================
//
// Derives an unpivoted (TagName, TagValue, ResourceCount) dimension from the
// already-loaded cost-analysis-focus table. Use as a slicer source or for
// tag-governance visuals.
//
// 📖 NOTHING TO CONFIGURE. Paste as-is.
//    Full reference → README.md in this folder.
// ============================================================================

let
    // ─── SOURCE: the already-loaded cost-analysis-focus table ───
    // (The #"..." syntax is how M references query names containing hyphens.)
    Source = #"cost-analysis-focus",

    // ─── KEEP ONLY Tag_* COLUMNS ───
    TagColumns = Table.SelectColumns(
        Source,
        List.Select(
            Table.ColumnNames(Source),
            each Text.StartsWith(_, "Tag_"))),

    // ─── UNPIVOT TO TALL FORMAT ───
    Unpivoted = Table.UnpivotOtherColumns(TagColumns, {}, "TagName", "TagValue"),

    // ─── STRIP "Tag_" PREFIX FROM NAMES ───
    CleanedNames = Table.TransformColumns(
        Unpivoted,
        {{"TagName", each Text.Replace(_, "Tag_", ""), type text}}),

    // ─── REMOVE NULL / BLANK TAG VALUES ───
    FilteredRows = Table.SelectRows(
        CleanedNames,
        each [TagValue] <> null and [TagValue] <> ""),

    // ─── COLLAPSE TO DISTINCT (TagName, TagValue) WITH ROW COUNT ───
    GroupedCount = Table.Group(
        FilteredRows,
        {"TagName", "TagValue"},
        {{"ResourceCount", each Table.RowCount(_), Int64.Type}}),

    // ─── SORT ALPHABETICALLY ───
    Sorted = Table.Sort(
        GroupedCount,
        {{"TagName", Order.Ascending}, {"TagValue", Order.Ascending}})
in
    Sorted
