CREATE TABLE [dbo].[dim_contracts] (
    [contract_id]     VARCHAR (50)    NULL,
    [created_on]      DATETIME2 (0)   NULL,
    [created_by]      VARCHAR (300)   NULL,
    [modified_on]     DATETIME2 (0)   NULL,
    [modified_by]     VARCHAR (300)   NULL,
    [contract_name]   VARCHAR (300)   NULL,
    [account_name]    VARCHAR (300)   NULL,
    [contract_status] VARCHAR (50)    NULL,
    [date_signed]     DATE            NULL,
    [start_date]      DATE            NULL,
    [end_date]        DATE            NULL,
    [owner]           VARCHAR (300)   NULL,
    [sow_link]        VARCHAR (500)   NULL,
    [signer_name]     VARCHAR (300)   NULL,
    [resource_budget] DECIMAL (12, 2) NULL,
    [travel_budget]   DECIMAL (12, 2) NULL
);


GO