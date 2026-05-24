// ============================================================================
// Azure FinOps Cockpit — cost-analysis-focus (FOCUS 1.0 conformed)
// ============================================================================
//
// Reads the SAME files as cost-analysis.m and reshapes them to match the
// open FinOps Foundation FOCUS 1.0 specification (focus.finops.org).
// Provider-portable columns get canonical FOCUS names; Azure-only columns
// get an x_ prefix.
//
// 📖 SETUP INSTRUCTIONS → see README.md in this folder.
//    Replace <YOUR_STORAGE_ACCOUNT> and <YOUR_CONTAINER_NAME> on lines 18-19
//    below — use the SAME two values as in 01-cost-analysis.m.
// ============================================================================

let
    // ─── ① CONNECTION SETTINGS — EDIT THESE TWO LINES ───
    AccountUrl    = "https://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net",
    ContainerName = "<YOUR_CONTAINER_NAME>",

    // ─── CONNECT TO BLOB STORAGE ───
    Source    = AzureStorage.Blobs(AccountUrl),
    Container = Source{[Name=ContainerName]}[Data],

    // ─── EXCLUDE MANIFESTS, KEEP CSV / GZipped-CSV ───
    CsvFiles = Table.SelectRows(Container, each
        (Text.Lower([Extension]) = ".csv"
         or Text.EndsWith([Name], ".csv.gz"))
        and not Text.StartsWith([Name], "manifest")),

    // ─── DECOMPRESS + PARSE ───
    CsvContent = Table.AddColumn(CsvFiles, "CsvData", each
        Csv.Document(
            if Text.EndsWith([Name], ".gz")
            then Binary.Decompress([Content], Compression.GZip)
            else [Content],
            [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv])),

    Combined = Table.Combine(Table.Column(CsvContent, "CsvData")),
    Promoted = Table.PromoteHeaders(Combined, [PromoteAllScalars=true]),

    // ─── REMOVE DUPLICATE HEADER ROWS ───
    Deduped = Table.SelectRows(Promoted, each
        Record.Field(_, Table.ColumnNames(Promoted){0})
            <> Table.ColumnNames(Promoted){0}),

    // ─── ADD HasTags FLAG (generic tag-coverage helper) ───
    // TRUE if the row has any tags at all. Used by 4 FOCUS DAX measures:
    // FOCUS Tagged Cost / FOCUS Untagged Cost /
    // FOCUS Tagged Resources Count / FOCUS Untagged Resources Count.
    WithHasTags = Table.AddColumn(Deduped, "HasTags",
        each let t = [tags] in t <> null and t <> "" and t <> "{}",
        type logical),

    // ─── PARSE Tags JSON ───
    ParsedTags = Table.AddColumn(WithHasTags, "TagsParsed", each
        let
            TagText = try [tags] otherwise null
        in
            if TagText = null or TagText = "" then null
            else
                try Json.Document("{" & TagText & "}")
                otherwise
                    try Json.Document(TagText)
                    otherwise null,
        type record),

    // ─── DYNAMIC TAG EXPANSION ───
    AllTagNames = List.Distinct(
        List.Combine(
            List.Transform(
                List.Select(Table.Column(ParsedTags, "TagsParsed"),
                            each _ <> null),
                each Record.FieldNames(_)))),

    ExpandedTags = Table.ExpandRecordColumn(
        ParsedTags, "TagsParsed", AllTagNames,
        List.Transform(AllTagNames, each "Tag_" & _)),

    // ─── SAFE TYPE CONVERSION BEFORE RENAMING ───
    NumericConverted = Table.TransformColumns(ExpandedTags, {
        {"costInBillingCurrency",        each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"costInPricingCurrency",        each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"costInUsd",                    each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"paygCostInBillingCurrency",    each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"paygCostInUsd",                each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"quantity",                     each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"effectivePrice",               each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"unitPrice",                    each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"PayGPrice",                    each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"exchangeRatePricingToBilling", each try Number.From(_, "en-US") otherwise null, type nullable number}
    }),

    DateConverted = Table.TransformColumns(NumericConverted, {
        {"billingPeriodStartDate",  each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"billingPeriodEndDate",    each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"servicePeriodStartDate",  each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"servicePeriodEndDate",    each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"date",                    each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"exchangeRateDate",        each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date}
    }),

    // ─── RENAME TO FOCUS 1.0 SCHEMA ───
    // FOCUS = canonical multi-cloud columns. x_ = Azure-specific extensions.
    // MissingField.Ignore protects against schema drift in older exports.
    Renamed = Table.RenameColumns(DateConverted, {
        // Billing account & profile
        {"billingAccountId",            "x_BillingAccountId"},
        {"billingAccountName",          "x_BillingAccountName"},
        {"billingProfileId",            "x_BillingProfileId"},
        {"billingProfileName",          "x_BillingProfileName"},
        {"invoiceSectionId",            "x_InvoiceSectionId"},
        {"invoiceSectionName",          "x_InvoiceSectionName"},
        // Invoice & cost-center
        {"invoiceId",                   "InvoiceId"},
        {"previousInvoiceId",           "x_PreviousInvoiceId"},
        {"costCenter",                  "x_CostCenter"},
        {"resellerName",                "x_ResellerName"},
        {"resellerMpnId",               "x_ResellerMpnId"},
        // Dates
        {"billingPeriodStartDate",      "ChargePeriodStart"},
        {"billingPeriodEndDate",        "ChargePeriodEnd"},
        {"servicePeriodStartDate",      "BillingPeriodStart"},
        {"servicePeriodEndDate",        "BillingPeriodEnd"},
        {"date",                        "ChargeDate"},
        // Service
        {"serviceFamily",               "ServiceCategory"},
        {"consumedService",             "ServiceName"},
        {"meterCategory",               "x_MeterCategory"},
        {"meterSubCategory",            "x_MeterSubCategory"},
        {"meterId",                     "SkuMeterId"},
        {"meterName",                   "x_MeterName"},
        {"meterRegion",                 "RegionName"},
        // Product
        {"productOrderId",              "x_ProductOrderId"},
        {"productOrderName",            "x_ProductOrderName"},
        {"ProductId",                   "x_ProductId"},
        {"ProductName",                 "ProductName"},
        // Resource
        {"ResourceId",                  "ResourceId"},
        {"resourceLocation",            "ResourceRegion"},
        {"location",                    "x_Location"},
        {"resourceGroupName",           "ResourceGroupName"},
        // Subscription → SubAccount in FOCUS
        {"SubscriptionId",              "SubAccountId"},
        {"subscriptionName",            "SubAccountName"},
        // Publisher
        {"publisherType",               "PublisherType"},
        {"publisherId",                 "x_PublisherId"},
        {"publisherName",               "PublisherName"},
        // Charge
        {"chargeType",                  "ChargeCategory"},
        {"frequency",                   "ChargeFrequency"},
        {"term",                        "x_Term"},
        // Costs
        {"costInBillingCurrency",       "BilledCost"},
        {"costInPricingCurrency",       "x_CostInPricingCurrency"},
        {"costInUsd",                   "x_BilledCostInUsd"},
        {"paygCostInBillingCurrency",   "EffectiveCost"},
        {"paygCostInUsd",               "x_EffectiveCostInUsd"},
        // Quantity & pricing
        {"quantity",                    "ConsumedQuantity"},
        {"unitOfMeasure",               "ConsumedUnit"},
        {"effectivePrice",              "x_EffectiveUnitPrice"},
        {"unitPrice",                   "x_BilledUnitPrice"},
        {"PayGPrice",                   "x_PayGPrice"},
        // Currency & FX
        {"billingCurrency",             "BillingCurrency"},
        {"pricingCurrency",             "PricingCurrency"},
        {"exchangeRatePricingToBilling","x_BillingExchangeRate"},
        {"exchangeRateDate",            "x_BillingExchangeRateDate"},
        // Credits & metadata
        {"isAzureCreditEligible",       "x_IsAzureCreditEligible"},
        {"serviceInfo1",                "x_ServiceInfo1"},
        {"serviceInfo2",                "x_ServiceInfo2"},
        {"additionalInfo",              "x_AdditionalInfo"},
        // Reservations & benefits
        {"reservationId",               "x_ReservationId"},
        {"reservationName",             "x_ReservationName"},
        {"pricingModel",                "x_PricingModel"},
        {"benefitId",                   "CommitmentDiscountId"},
        {"benefitName",                 "CommitmentDiscountName"},
        {"costAllocationRuleName",      "x_CostAllocationRuleName"},
        {"provider",                    "x_Provider"}
    }, MissingField.Ignore),

    // ─── DROP OVERFLOW COLUMNS AND RAW tags STRING ───
    CleanCols = Table.SelectColumns(Renamed,
        List.Select(Table.ColumnNames(Renamed),
            each not Text.StartsWith(_, "Column") and _ <> "tags"))
in
    CleanCols
