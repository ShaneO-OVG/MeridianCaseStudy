CREATE TABLE [dbo].[out_income_statement] (
    [AccountL6ID]   VARCHAR (20)    NULL,
    [AccountL6Name] VARCHAR (400)   NULL,
    [CustomerName]  VARCHAR (400)   NULL,
    [VendorName]    VARCHAR (400)   NULL,
    [Date]          DATE            NULL,
    [Scenario]      VARCHAR (300)   NULL,
    [Version]       VARCHAR (300)   NULL,
    [SourceModel]   VARCHAR (400)   NULL,
    [LoadDate]      DATETIME2 (6)   NULL,
    [AccountL5ID]   VARCHAR (20)    NULL,
    [AccountL4ID]   VARCHAR (20)    NULL,
    [AccountL3ID]   VARCHAR (20)    NULL,
    [AccountL2ID]   VARCHAR (20)    NULL,
    [AccountL1ID]   VARCHAR (20)    NULL,
    [AccountL5Name] VARCHAR (400)   NULL,
    [AccountL4Name] VARCHAR (400)   NULL,
    [AccountL3Name] VARCHAR (400)   NULL,
    [AccountL2Name] VARCHAR (400)   NULL,
    [AccountL1Name] VARCHAR (400)   NULL,
    [Amount]        DECIMAL (18, 4) NULL
);


GO