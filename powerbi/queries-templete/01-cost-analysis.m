// ============================================================================
// Azure FinOps Cockpit — cost-analysis (classic MCA export)
// ============================================================================
//
// Reads Microsoft's classic MCA (Microsoft Customer Agreement) cost-management
// export CSV files from Azure Blob Storage and reshapes them into a clean,
// query-friendly fact table.
//
// 📖 SETUP INSTRUCTIONS → see README.md in this folder.
//    Replace <YOUR_STORAGE_ACCOUNT> and <YOUR_CONTAINER_NAME> on lines 18-19
//    below. Both values come from your Azure Cost Management export config.
// ============================================================================

let
    // ─── ① CONNECTION SETTINGS — EDIT THESE TWO LINES ───
    AccountUrl    = "https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net",
    ContainerName = "<YOUR_CONTAINER_NAME>",

    // ─── CONNECT TO BLOB STORAGE ───
    Source    = AzureStorage.Blobs(AccountUrl),
    Container = Source{[Name=ContainerName]}[Data],

    // ─── KEEP ONLY CSV / GZipped-CSV FILES — EXCLUDE MANIFEST JSON ───
    CsvFiles = Table.SelectRows(Container, each
        (Text.Lower([Extension]) = ".csv"
          or Text.EndsWith(Text.Lower([Name]), ".csv.gz")
          or Text.Lower([Extension]) = ".gz")
        and not Text.StartsWith(Text.Lower([Name]), "manifest")),

    // ─── DECOMPRESS (if .gz) AND PARSE EACH FILE AS CSV ───
    CsvContent = Table.AddColumn(CsvFiles, "CsvData",
        each Csv.Document(
            (if Text.EndsWith(Text.Lower([Name]), ".gz")
             then Binary.Decompress([Content], Compression.GZip)
             else [Content]),
            [Delimiter=",", Encoding=65001,
             QuoteStyle=QuoteStyle.Csv])),

    // ─── COMBINE ALL FILES AND PROMOTE FIRST ROW TO HEADERS ───
    Combined = Table.Combine(Table.Column(CsvContent, "CsvData")),
    Promoted = Table.PromoteHeaders(Combined, [PromoteAllScalars=true]),

    // ─── REMOVE DUPLICATE HEADER ROWS FROM SUBSEQUENT FILES ───
    Deduped = Table.SelectRows(Promoted, each
        Record.Field(_, Table.ColumnNames(Promoted){0})
            <> Table.ColumnNames(Promoted){0}),

    // ─── KEEP ONLY MCA ROWS WITH VALID chargeType VALUES ───
    MCA_Rows = Table.SelectRows(Deduped, each
        List.Contains(
            {"Usage","Purchase","Tax","Adjustment",
             "Refund","UnusedReservation","RoundingAdjustment"},
            [chargeType])),

    // ─── DROP "ColumnN" OVERFLOW COLUMNS (artifact of ragged source rows) ───
    CleanCols = Table.SelectColumns(MCA_Rows,
        List.Select(Table.ColumnNames(MCA_Rows),
            each not Text.StartsWith(_, "Column"))),

    // ─── ADD HasTags FLAG (generic tag-coverage helper) ───
    // TRUE if the row has any tags. Used by DAX measures:
    // Tagged Resources Cost / Untagged Resources Cost / Tagging Coverage %.
    WithHasTags = Table.AddColumn(CleanCols, "HasTags",
        each let t = [tags] in t <> null and t <> "" and t <> "{}",
        type logical),

    // ─── PARSE Tags JSON (handles {"k":"v"} and bare "k":"v" formats) ───
    ParsedTags = Table.AddColumn(WithHasTags, "TagsParsed",
        each
            let
                TagText = [tags],
                ParsedTag =
                    if TagText = null or TagText = "" or TagText = "{}" then null
                    else
                        try Json.Document(TagText)
                        otherwise
                            try Json.Document("{" & TagText & "}")
                            otherwise null
            in
                ParsedTag,
        type record),

    // ─── DISCOVER ALL UNIQUE TAG KEYS, EXPAND DYNAMICALLY INTO Tag_<name> ───
    AllTagNames = List.Distinct(
        List.Combine(
            List.Transform(
                List.Select(Table.Column(ParsedTags, "TagsParsed"),
                            each _ <> null),
                each Record.FieldNames(_)))),

    ExpandedTags = Table.ExpandRecordColumn(
        ParsedTags, "TagsParsed", AllTagNames,
        List.Transform(AllTagNames, each "Tag_" & _)),

    // ─── SET DATA TYPES ON KNOWN COLUMNS ───
    Typed = Table.TransformColumnTypes(ExpandedTags, {
        {"date",                         type date},
        {"servicePeriodStartDate",       type date},
        {"servicePeriodEndDate",         type date},
        {"costInBillingCurrency",        type number},
        {"costInPricingCurrency",        type number},
        {"costInUsd",                    type number},
        {"paygCostInBillingCurrency",    type number},
        {"paygCostInUsd",                type number},
        {"effectivePrice",               type number},
        {"unitPrice",                    type number},
        {"PayGPrice",                    type number},
        {"quantity",                     type number},
        {"exchangeRatePricingToBilling", type number}
    }, "en-US")
in
    Typed
