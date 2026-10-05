CREATE TABLE [dbo].[dim_bs_accounts] (
    [AccountL6ID]           VARCHAR (400) NULL,
    [AccountL6Name]         VARCHAR (400) NULL,
    [AccountL5ID]           VARCHAR (20)  NULL,
    [AccountL5Name]         VARCHAR (400) NULL,
    [AccountL4ID]           VARCHAR (20)  NULL,
    [AccountL4Name]         VARCHAR (400) NULL,
    [AccountL3ID]           VARCHAR (20)  NULL,
    [AccountL3Name]         VARCHAR (400) NULL,
    [AccountL2ID]           VARCHAR (20)  NULL,
    [AccountL2Name]         VARCHAR (400) NULL,
    [AccountL1ID]           VARCHAR (20)  NULL,
    [AccountL1Name]         VARCHAR (400) NULL,
    [LoadDate]              DATETIME2 (6) NULL,
    [QuickbooksAccountName] VARCHAR (400) NULL,
    [SignFlip]              INT           NULL
);


GO