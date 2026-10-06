[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared pRunId = "manual-test" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text];
shared pSourceModel = "Operating Model" meta [IsParameterQuery = true, IsParameterQueryRequired = true, Type = type text];
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "Validation_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "RunId", DestinationColumnName = "RunId"], [SourceColumnName = "SourceModel", DestinationColumnName = "SourceModel"], [SourceColumnName = "ErrorCount", DestinationColumnName = "ErrorCount"], [SourceColumnName = "ControlTotal", DestinationColumnName = "ControlTotal"], [SourceColumnName = "SourceId", DestinationColumnName = "SourceId"], [SourceColumnName = "ScenarioId", DestinationColumnName = "ScenarioId"], [SourceColumnName = "FileName", DestinationColumnName = "FileName"], [SourceColumnName = "LoadDate", DestinationColumnName = "LoadDate"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared Validation = let
    FilePath = "https://openvalegroup-my.sharepoint.com/personal/shane_oneill_openvalegroup_com/Documents/Meridian%20Case%20Study/Operating%20Model.xlsx",
    FileName = Text.Replace(Text.AfterDelimiter(FilePath, "/", {0, RelativePosition.FromEnd}), "%20", " "),

    Source = Excel.Workbook(Web.Contents(FilePath), null, true),
    Sheet  = Source{[Item = "Validation", Kind = "Sheet"]}[Data],
    // Header row 1, one value row 2 (same as the A1:D2 range in the case study)
    Promoted = Table.PromoteHeaders(Table.FirstN(Sheet, 2), [PromoteAllScalars = true]),
    Row      = if Table.RowCount(Promoted) = 1 then Promoted{0} else [],

    // Everything lands as text; a missing header lands as null, an Excel error as "#ERROR".
    // The pipeline casts and treats both as a failed gate - never as zero.
    Get = (field as text) =>
        try (let v = Record.FieldOrDefault(Row, field, null)
             in if v = null then null else Text.From(v, "en-US"))
        otherwise "#ERROR",

    Result = #table(
        type table [RunId = text, SourceModel = text, ErrorCount = text, ControlTotal = text,
                    SourceId = text, ScenarioId = text, FileName = text, LoadDate = datetime],
        {{ pRunId, pSourceModel, Get("ErrorCount"), Get("ControlTotal"), Get("SourceId"), Get("ScenarioId"),
           FileName, DateTimeZone.RemoveZone(DateTimeZone.UtcNow()) }})
in
    Result;
shared Validation_DataDestination = let
  Pattern = Fabric.Warehouse([CreateNavigationProperties = false, HierarchicalNavigation = true]),
  Navigation_1 = Pattern{[workspaceId = "3d0a64fa-75cb-45d9-9a90-5222ad2ccf95"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f540adf4-911f-4272-a5cb-b69234ba7523"]}[Data],
  Navigation_3 = Navigation_2{[Schema = "dbo"]}[Data],
  TableNavigation = Navigation_3{[Name = "stg_workbook_validation"]}[Data]
in
  TableNavigation;
