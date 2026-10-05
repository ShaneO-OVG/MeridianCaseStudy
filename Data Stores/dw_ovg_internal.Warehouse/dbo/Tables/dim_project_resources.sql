CREATE TABLE [dbo].[dim_project_resources] (
    [project_resource_id]   VARCHAR (50)    NULL,
    [created_by]            VARCHAR (300)   NULL,
    [created_on]            DATETIME2 (0)   NULL,
    [modified_by]           VARCHAR (300)   NULL,
    [modified_on]           DATETIME2 (0)   NULL,
    [project_resource_code] VARCHAR (150)   NULL,
    [project_resource_name] VARCHAR (500)   NULL,
    [account_name]          VARCHAR (300)   NULL,
    [active_flag]           VARCHAR (50)    NULL,
    [budgeted_hours]        DECIMAL (12, 2) NULL,
    [budgeted_rate]         DECIMAL (12, 2) NULL,
    [budgeted_revenue]      DECIMAL (12, 2) NULL,
    [employee_name]         VARCHAR (300)   NULL,
    [employee_email]        VARCHAR (300)   NULL,
    [contract_name]         VARCHAR (500)   NULL,
    [project_name]          VARCHAR (500)   NULL
);


GO