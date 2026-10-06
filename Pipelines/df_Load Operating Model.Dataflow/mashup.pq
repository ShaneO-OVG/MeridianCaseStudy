[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Operating Model_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "AccountL6ID", DestinationColumnName = "AccountL6ID"], [SourceColumnName = "AccountL6Name", DestinationColumnName = "AccountL6Name"], [SourceColumnName = "CustomerName", DestinationColumnName = "CustomerName"], [SourceColumnName = "VendorName", DestinationColumnName = "VendorName"], [SourceColumnName = "Date", DestinationColumnName = "Date"], [SourceColumnName = "Scenario", DestinationColumnName = "Scenario"], [SourceColumnName = "Version", DestinationColumnName = "Version"], [SourceColumnName = "SourceModel", DestinationColumnName = "SourceModel"], [SourceColumnName = "LoadDate", DestinationColumnName = "LoadDate"], [SourceColumnName = "Amount", DestinationColumnName = "Amount"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared #"Operating Model" = let
    // ---- Source: keep YOUR path from the existing Source step ----
    Source = Excel.Workbook(Web.Contents("https://openvalegroup-my.sharepoint.com/personal/shane_oneill_openvalegroup_com/Documents/Meridian%20Case%20Study/Operating%20Model.xlsx"), null, true),
    Sheet = Source{[Item = "Operating Model", Kind = "Sheet"]}[Data],

    // Row 6 = A/F flags, row 7 = month headers, data starts row 8
    FlagRow   = Sheet{5},
    HeaderRow = Sheet{6},
    MonthColumns = List.Transform({5..16}, each "Column" & Text.From(_)),
    ForecastColumns = List.Select(MonthColumns, each
        let v = Record.Field(FlagRow, _)
        in v <> null and Text.Upper(Text.Trim(Text.From(v))) = "F"),

    // Keep-list, never remove-list: new workbook columns cannot leak through
    DataRows    = Table.Skip(Sheet, 7),
    KeepColumns = Table.SelectColumns(DataRows, {"Column1", "Column2", "Column3", "Column4"} & ForecastColumns),

    // Blank = no account. A $0 row is NOT blank and must survive.
    NonBlank   = Table.SelectRows(KeepColumns, each [Column1] <> null and Text.Trim(Text.From([Column1])) <> ""),
    // Unpivot silently drops nulls, so an empty forecast cell becomes 0 first
    ZeroFilled = Table.ReplaceValue(NonBlank, null, 0, Replacer.ReplaceValue, ForecastColumns),
    Unpivoted  = Table.UnpivotOtherColumns(ZeroFilled, {"Column1", "Column2", "Column3", "Column4"}, "MonthColumn", "Amount"),
    WithDate   = Table.AddColumn(Unpivoted, "Date", each Date.From(Record.Field(HeaderRow, [MonthColumn])), type date),

    Renamed = Table.RenameColumns(WithDate, {
        {"Column1", "AccountL6ID"}, {"Column2", "AccountL6Name"},
        {"Column3", "CustomerName"}, {"Column4", "VendorName"}}),

    // Trim names: the warehouse collation is case- and whitespace-sensitive
    TrimOrNull = (x) => if x = null or Text.Trim(Text.From(x)) = "" then null else Text.Trim(Text.From(x)),
    Typed = Table.TransformColumns(Renamed, {
        {"AccountL6ID",   each Text.Trim(Text.From(_)), type text},
        {"AccountL6Name", TrimOrNull, type text},
        {"CustomerName",  TrimOrNull, type text},
        {"VendorName",    TrimOrNull, type text},
        {"Amount",        each Number.From(_), type number}}),

    // Stamp the slice from pipeline parameters - never from the workbook
    LoadTimestamp = DateTimeZone.RemoveZone(DateTimeZone.UtcNow()),
    Stamped = Table.AddColumn(
                Table.AddColumn(
                  Table.AddColumn(
                    Table.AddColumn(Typed, "Scenario", each pScenario, type text),
                  "Version", each pVersion, type text),
                "SourceModel", each pSourceModel, type text),
              "LoadDate", each LoadTimestamp, type datetime),

    Final = Table.SelectColumns(Stamped, {
        "AccountL6ID", "AccountL6Name", "CustomerName", "VendorName", "Date",
        "Scenario", "Version", "SourceModel", "LoadDate", "Amount"}),

    // Fail the refresh if a month is wrongly flagged F (or none are)
    FirstPeriod = List.Min(Final[Date]),
    Checked = if FirstPeriod = null or FirstPeriod <> pForecastStart
        then error Error.Record("ForecastStartMismatch",
            "Earliest F month is " & Text.From(FirstPeriod) & " but this cut starts "
            & Text.From(pForecastStart) & ". Check the A/F flags in row 6.")
        else Final
in
    Checked;
shared pScenario = "2026.09_September Forecast" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text];
shared pVersion = "Current Forecast" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text];
shared pSourceModel = "Operating Model" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text];
shared pForecastStart = #date(2026, 9, 1) meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type date];
shared #"Operating Model_DataDestination" = let
  Pattern = Fabric.Warehouse([CreateNavigationProperties = false, HierarchicalNavigation = true]),
  Navigation_1 = Pattern{[workspaceId = "3d0a64fa-75cb-45d9-9a90-5222ad2ccf95"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f540adf4-911f-4272-a5cb-b69234ba7523"]}[Data],
  Navigation_3 = Navigation_2{[Schema = "dbo"]}[Data],
  TableNavigation = Navigation_3{[Name = "fcst_income_statement"]}[Data]
in
  TableNavigation;
