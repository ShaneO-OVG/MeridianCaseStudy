CREATE TABLE [dbo].[data_income_statement] (
    [DistributionAccount] VARCHAR (400)   NULL,
    [TransactionDate]     DATE            NULL,
    [TransactionType]     VARCHAR (300)   NULL,
    [Num]                 VARCHAR (100)   NULL,
    [Name]                VARCHAR (400)   NULL,
    [Description]         VARCHAR (1000)  NULL,
    [AccountName]         VARCHAR (400)   NULL,
    [ItemSplitAccount]    VARCHAR (400)   NULL,
    [Customer]            VARCHAR (400)   NULL,
    [ProductService]      VARCHAR (400)   NULL,
    [Quantity]            DECIMAL (18, 4) NULL,
    [Rate]                DECIMAL (18, 4) NULL,
    [Vendor]              VARCHAR (400)   NULL,
    [LoadDate]            DATETIME2 (6)   NULL,
    [AccountL6ID]         VARCHAR (400)   NULL,
    [VendorName]          VARCHAR (400)   NULL,
    [CustomerName]        VARCHAR (400)   NULL,
    [Amount]              DECIMAL (18, 4) NULL,
    [Balance]             DECIMAL (18, 4) NULL
);


GO