let
    Source = AzureStorage.Blobs(
        "https://hijazicostmanagment.blob.core.windows.net"),
    Container = Source{[Name="cost-analysis"]}[Data],

    // Exclude manifest JSON files
    CsvFiles = Table.SelectRows(Container, each
        (Text.Lower([Extension]) = ".csv"
          or Text.EndsWith(Text.Lower([Name]), ".csv.gz")
          or Text.Lower([Extension]) = ".gz")
        and not Text.StartsWith(Text.Lower([Name]), "manifest")),

    CsvContent = Table.AddColumn(CsvFiles, "CsvData",
        each Csv.Document(
            (if Text.EndsWith(Text.Lower([Name]), ".gz")
             then Binary.Decompress([Content], Compression.GZip)
             else [Content]),
            [Delimiter=",", Encoding=65001,
             QuoteStyle=QuoteStyle.Csv])),

    Combined  = Table.Combine(Table.Column(CsvContent, "CsvData")),
    Promoted  = Table.PromoteHeaders(Combined, [PromoteAllScalars=true]),

    // Remove duplicate header rows from subsequent files
    Deduped = Table.SelectRows(Promoted, each
        Record.Field(_, Table.ColumnNames(Promoted){0})
            <> Table.ColumnNames(Promoted){0}),

    // Keep only MCA rows with valid chargeType
    MCA_Rows = Table.SelectRows(Deduped, each
        List.Contains(
            {"Usage","Purchase","Tax","Adjustment",
             "Refund","UnusedReservation","RoundingAdjustment"},
            [chargeType])),

    // Drop the Column66-Column96 overflow columns
    CleanCols = Table.SelectColumns(MCA_Rows,
        List.Select(Table.ColumnNames(MCA_Rows),
            each not Text.StartsWith(_, "Column"))),

    // ============================================
    // TAGS PARSING - ROBUST & DYNAMIC
    // ============================================
    
    // Step 1: Parse Tags JSON (handles both formats)
    ParsedTags = Table.AddColumn(CleanCols, "TagsParsed", 
        each 
            let
                TagText = [tags],
                ParsedTag = 
                    if TagText = null or TagText = "" or TagText = "{}" then 
                        null
                    else 
                        try 
                            // Try parsing as-is first
                            Json.Document(TagText)
                        otherwise 
                            try 
                                // Try wrapping with braces if missing
                                Json.Document("{" & TagText & "}")
                            otherwise 
                                null
            in
                ParsedTag,
        type record),

    // Step 2: Get ALL unique tag names across all resources
    AllTagNames = List.Distinct(
        List.Combine(
            List.Transform(
                List.Select(
                    Table.Column(ParsedTags, "TagsParsed"), 
                    each _ <> null
                ),
                each Record.FieldNames(_)
            )
        )
    ),

    // Step 3: Dynamically expand ALL tag columns
    ExpandedTags = Table.ExpandRecordColumn(
        ParsedTags, 
        "TagsParsed", 
        AllTagNames,
        List.Transform(AllTagNames, each "Tag_" & _)
    ),

    // Set correct data types
    Typed = Table.TransformColumnTypes(ExpandedTags, {
        {"date",                       type date},
        {"servicePeriodStartDate",     type date},
        {"servicePeriodEndDate",       type date},
        {"costInBillingCurrency",      type number},
        {"costInPricingCurrency",      type number},
        {"costInUsd",                  type number},
        {"paygCostInBillingCurrency",  type number},
        {"paygCostInUsd",              type number},
        {"effectivePrice",             type number},
        {"unitPrice",                  type number},
        {"PayGPrice",                  type number},
        {"quantity",                   type number},
        {"exchangeRatePricingToBilling", type number}
    }, "en-US")
in
    Typed