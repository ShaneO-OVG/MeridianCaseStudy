CREATE TABLE [dbo].[fcst_income_statement] (
    [AccountL6ID]   VARCHAR (20)    NULL,
    [AccountL6Name] VARCHAR (400)   NULL,
    [CustomerName]  VARCHAR (400)   NULL,
    [VendorName]    VARCHAR (400)   NULL,
    [Date]          DATE            NULL,
    [Scenario]      VARCHAR (300)   NULL,
    [Version]       VARCHAR (300)   NULL,
    [SourceModel]   VARCHAR (400)   NULL,
    [LoadDate]      DATETIME2 (6)   NULL,
    [Amount]        DECIMAL (18, 4) NULL
);


GO