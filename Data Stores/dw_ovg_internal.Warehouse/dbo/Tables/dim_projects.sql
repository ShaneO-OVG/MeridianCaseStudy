CREATE TABLE [dbo].[dim_projects] (
    [project_id]    VARCHAR (100) NULL,
    [created_on]    DATETIME2 (0) NULL,
    [created_by]    VARCHAR (300) NULL,
    [modified_on]   DATETIME2 (0) NULL,
    [modified_by]   VARCHAR (300) NULL,
    [project_name]  VARCHAR (400) NULL,
    [account_name]  VARCHAR (300) NULL,
    [contract_name] VARCHAR (500) NULL,
    [active_flag]   VARCHAR (50)  NULL,
    [start_date]    DATE          NULL,
    [end_date]      DATE          NULL
);


GO