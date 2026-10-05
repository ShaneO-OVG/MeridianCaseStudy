CREATE TABLE [dbo].[sys_publish_audit] (
    [RunId]              VARCHAR (36)    NULL,
    [ProcName]           VARCHAR (200)   NULL,
    [StartUtc]           DATETIME2 (6)   NULL,
    [EndUtc]             DATETIME2 (6)   NULL,
    [Status]             VARCHAR (20)    NULL,
    [Attempt]            INT             NULL,
    [RowsDeleted]        BIGINT          NULL,
    [RowsInserted]       BIGINT          NULL,
    [ExpectedRows]       BIGINT          NULL,
    [PublishedRows]      BIGINT          NULL,
    [ExpectedAmount]     DECIMAL (38, 4) NULL,
    [PublishedAmount]    DECIMAL (38, 4) NULL,
    [ReconMismatches]    INT             NULL,
    [OrphanScenarioRows] BIGINT          NULL,
    [ScopeSourceModels]  VARCHAR (4000)  NULL,
    [ErrorNumber]        INT             NULL,
    [ErrorMessage]       VARCHAR (4000)  NULL,
    [ExcludedRows]       BIGINT          NULL,
    [ExcludedAmount]     DECIMAL (38, 4) NULL,
    [UnmappedRows]       BIGINT          NULL,
    [UnmappedAmount]     DECIMAL (38, 4) NULL,
    [RowsUpdated]        BIGINT          NULL
);


GO