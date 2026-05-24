let
    // CONNECT TO BLOB STORAGE
    Source = AzureStorage.Blobs("https://hijazicostmanagment.blob.core.windows.net"),
    Container = Source{[Name="cost-analysis"]}[Data],
    
    // Exclude manifest and JSON files
    CsvFiles = Table.SelectRows(Container, each (Text.Lower([Extension]) = ".csv" or Text.EndsWith([Name], ".csv.gz")) and not Text.StartsWith([Name], "manifest")),
    
    // Read CSV content (handle .gz compression)
    CsvContent = Table.AddColumn(CsvFiles, "CsvData", each 
        Csv.Document(
            if Text.EndsWith([Name], ".gz") then 
                Binary.Decompress([Content], Compression.GZip) 
            else 
                [Content],
            [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.Csv]
        )
    ),
    
    Combined = Table.Combine(Table.Column(CsvContent, "CsvData")),
    Promoted = Table.PromoteHeaders(Combined, [PromoteAllScalars=true]),
    
    // Remove duplicate header rows
    Deduped = Table.SelectRows(Promoted, each Record.Field(_, Table.ColumnNames(Promoted){0}) <> Table.ColumnNames(Promoted){0}),
    
    // ===========================
    // TAGS PARSING - BEFORE RENAMING
    // ===========================
    ParsedTags = Table.AddColumn(Deduped, "TagsParsed", each 
        let
            TagText = try [tags] otherwise null
        in
            if TagText = null or TagText = "" then 
                null 
            else 
                try Json.Document("{" & TagText & "}") otherwise 
                try Json.Document(TagText) otherwise 
                null,
        type record
    ),
    
    AllTagNames = List.Distinct(
        List.Combine(
            List.Transform(
                List.Select(Table.Column(ParsedTags, "TagsParsed"), each _ <> null),
                each Record.FieldNames(_)
            )
        )
    ),
    
    ExpandedTags = Table.ExpandRecordColumn(
        ParsedTags, 
        "TagsParsed", 
        AllTagNames, 
        List.Transform(AllTagNames, each "Tag_" & _)
    ),
    
    // ===========================
    // SAFE TYPE CONVERSION FIRST (before renaming)
    // ===========================
    // Convert numeric columns safely
    NumericConverted = Table.TransformColumns(ExpandedTags, {
        {"costInBillingCurrency", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"costInPricingCurrency", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"costInUsd", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"paygCostInBillingCurrency", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"paygCostInUsd", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"quantity", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"effectivePrice", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"unitPrice", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"PayGPrice", each try Number.From(_, "en-US") otherwise null, type nullable number},
        {"exchangeRatePricingToBilling", each try Number.From(_, "en-US") otherwise null, type nullable number}
    }),
    
    // Convert date columns safely
    DateConverted = Table.TransformColumns(NumericConverted, {
        {"billingPeriodStartDate", each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"billingPeriodEndDate", each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"servicePeriodStartDate", each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"servicePeriodEndDate", each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"date", each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date},
        {"exchangeRateDate", each try Date.From(DateTimeZone.FromText(_)) otherwise try Date.From(_) otherwise null, type nullable date}
    }),
    
    // ===========================
    // RENAME TO FOCUS SCHEMA
    // ===========================
    Renamed = Table.RenameColumns(DateConverted, {
        // Billing Account Info
        {"billingAccountId", "x_BillingAccountId"},
        {"billingAccountName", "x_BillingAccountName"},
        {"billingProfileId", "x_BillingProfileId"},
        {"billingProfileName", "x_BillingProfileName"},
        {"invoiceSectionId", "x_InvoiceSectionId"},
        {"invoiceSectionName", "x_InvoiceSectionName"},
        
        // Invoice Info
        {"invoiceId", "InvoiceId"},
        {"previousInvoiceId", "x_PreviousInvoiceId"},
        
        // Cost Center & Reseller
        {"costCenter", "x_CostCenter"},
        {"resellerName", "x_ResellerName"},
        {"resellerMpnId", "x_ResellerMpnId"},
        
        // Dates
        {"billingPeriodStartDate", "ChargePeriodStart"},
        {"billingPeriodEndDate", "ChargePeriodEnd"},
        {"servicePeriodStartDate", "BillingPeriodStart"},
        {"servicePeriodEndDate", "BillingPeriodEnd"},
        {"date", "ChargeDate"},
        
        // Service Info
        {"serviceFamily", "ServiceCategory"},
        {"consumedService", "ServiceName"},
        {"meterCategory", "x_MeterCategory"},
        {"meterSubCategory", "x_MeterSubCategory"},
        {"meterId", "SkuMeterId"},
        {"meterName", "x_MeterName"},
        {"meterRegion", "RegionName"},
        
        // Product Info
        {"productOrderId", "x_ProductOrderId"},
        {"productOrderName", "x_ProductOrderName"},
        {"ProductId", "x_ProductId"},
        {"ProductName", "ProductName"},
        
        // Resource Info
        {"ResourceId", "ResourceId"},
        {"resourceLocation", "ResourceRegion"},
        {"location", "x_Location"},
        {"resourceGroupName", "ResourceGroupName"},
        
        // Subscription Info
        {"SubscriptionId", "SubAccountId"},
        {"subscriptionName", "SubAccountName"},
        
        // Publisher Info
        {"publisherType", "PublisherType"},
        {"publisherId", "x_PublisherId"},
        {"publisherName", "PublisherName"},
        
        // Charge Info
        {"chargeType", "ChargeCategory"},
        {"frequency", "ChargeFrequency"},
        {"term", "x_Term"},
        
        // Costs
        {"costInBillingCurrency", "BilledCost"},
        {"costInPricingCurrency", "x_CostInPricingCurrency"},
        {"costInUsd", "x_BilledCostInUsd"},
        {"paygCostInBillingCurrency", "EffectiveCost"},
        {"paygCostInUsd", "x_EffectiveCostInUsd"},
        
        // Quantity & Pricing
        {"quantity", "ConsumedQuantity"},
        {"unitOfMeasure", "ConsumedUnit"},
        {"effectivePrice", "x_EffectiveUnitPrice"},
        {"unitPrice", "x_BilledUnitPrice"},
        {"PayGPrice", "x_PayGPrice"},
        
        // Currency & Exchange
        {"billingCurrency", "BillingCurrency"},
        {"pricingCurrency", "PricingCurrency"},
        {"exchangeRatePricingToBilling", "x_BillingExchangeRate"},
        {"exchangeRateDate", "x_BillingExchangeRateDate"},
        
        // Other
        {"isAzureCreditEligible", "x_IsAzureCreditEligible"},
        {"serviceInfo1", "x_ServiceInfo1"},
        {"serviceInfo2", "x_ServiceInfo2"},
        {"additionalInfo", "x_AdditionalInfo"},
        
        // Reservations & Benefits
        {"reservationId", "x_ReservationId"},
        {"reservationName", "x_ReservationName"},
        {"pricingModel", "x_PricingModel"},
        {"benefitId", "CommitmentDiscountId"},
        {"benefitName", "CommitmentDiscountName"},
        {"costAllocationRuleName", "x_CostAllocationRuleName"},
        {"provider", "x_Provider"}
    }, MissingField.Ignore),
    
    // Drop overflow columns and original tags
    CleanCols = Table.SelectColumns(Renamed, 
        List.Select(Table.ColumnNames(Renamed), each not Text.StartsWith(_, "Column") and _ <> "tags")
    )
in
    CleanCols