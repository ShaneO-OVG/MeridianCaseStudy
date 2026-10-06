CREATE TABLE [dbo].[stg_workbook_validation] (
    [RunId]        VARCHAR (100) NULL,
    [SourceModel]  VARCHAR (400) NULL,
    [ErrorCount]   VARCHAR (100) NULL,
    [ControlTotal] VARCHAR (100) NULL,
    [SourceId]     VARCHAR (400) NULL,
    [ScenarioId]   VARCHAR (400) NULL,
    [FileName]     VARCHAR (400) NULL,
    [LoadDate]     DATETIME2 (6) NULL
);


GO