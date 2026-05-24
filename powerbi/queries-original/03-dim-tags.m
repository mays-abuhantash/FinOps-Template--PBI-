let
    // Get all tag columns from cost-analysis-focus (has more rows)
    Source = #"cost-analysis-focus",
    
    // Select only Tag_ columns
    TagColumns = Table.SelectColumns(
        Source,
        List.Select(
            Table.ColumnNames(Source),
            each Text.StartsWith(_, "Tag_")
        )
    ),
    
    // Unpivot to create TagName and TagValue
    Unpivoted = Table.UnpivotOtherColumns(TagColumns, {}, "TagName", "TagValue"),
    
    // Clean tag names (remove "Tag_" prefix)
    CleanedNames = Table.TransformColumns(
        Unpivoted,
        {{"TagName", each Text.Replace(_, "Tag_", ""), type text}}
    ),
    
    // Remove nulls and blanks
    FilteredRows = Table.SelectRows(
        CleanedNames, 
        each [TagValue] <> null and [TagValue] <> ""
    ),
    
    // Get distinct combinations
    DistinctTags = Table.Distinct(FilteredRows),
    
    // Add count of resources using this tag (optional)
    GroupedCount = Table.Group(
        FilteredRows, 
        {"TagName", "TagValue"}, 
        {{"ResourceCount", each Table.RowCount(_), Int64.Type}}
    ),
    
    // Sort
    Sorted = Table.Sort(
        GroupedCount, 
        {{"TagName", Order.Ascending}, {"TagValue", Order.Ascending}}
    )
in
    Sorted