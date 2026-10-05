CREATE TABLE [dbo].[data_trial_balance] (
    [TransactionDate]  DATE            NULL,
    [AccountName]      VARCHAR (400)   NULL,
    [ItemSplitAccount] VARCHAR (400)   NULL,
    [DebitAmount]      DECIMAL (18, 4) NULL,
    [CreditAmount]     DECIMAL (18, 4) NULL,
    [Balance]          DECIMAL (18, 4) NULL,
    [LoadDate]         DATETIME2 (6)   NULL
);


GO