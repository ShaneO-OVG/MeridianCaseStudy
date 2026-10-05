CREATE TABLE [dbo].[data_timesheets] (
    [timesheet_id]          VARCHAR (50)    NULL,
    [created_on]            DATETIME2 (0)   NULL,
    [created_by]            VARCHAR (200)   NULL,
    [modified_on]           DATETIME2 (0)   NULL,
    [modified_by]           VARCHAR (200)   NULL,
    [timesheet_month_start] DATE            NULL,
    [timesheet_week_start]  DATE            NULL,
    [employee_lookup]       VARCHAR (200)   NULL,
    [email_lookup]          VARCHAR (200)   NULL,
    [account_lookup]        VARCHAR (300)   NULL,
    [contract_lookup]       VARCHAR (400)   NULL,
    [project_lookup]        VARCHAR (400)   NULL,
    [total_hours]           DECIMAL (9, 2)  NULL,
    [budgeted_rate]         DECIMAL (9, 2)  NULL,
    [revenue]               DECIMAL (12, 2) NULL,
    [training_credit_type]  VARCHAR (100)   NULL,
    [timesheet_notes]       VARCHAR (500)   NULL,
    [billed_flag]           VARCHAR (50)    NULL,
    [billed_date]           DATE            NULL
);


GO