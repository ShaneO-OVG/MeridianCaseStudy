CREATE TABLE [dbo].[dim_accounts] (
    [account_id]             VARCHAR (50)  NULL,
    [account_name]           VARCHAR (500) NULL,
    [created_on]             DATETIME2 (0) NULL,
    [created_by]             VARCHAR (200) NULL,
    [modified_on]            DATETIME2 (0) NULL,
    [modified_by]            VARCHAR (200) NULL,
    [account_owner]          VARCHAR (300) NULL,
    [active_flag]            VARCHAR (50)  NULL,
    [account_type]           VARCHAR (100) NULL,
    [primary_contact]        VARCHAR (300) NULL,
    [industry]               VARCHAR (300) NULL,
    [estimated_revenue]      BIGINT        NULL,
    [estimated_employees]    BIGINT        NULL,
    [address_street_1]       VARCHAR (500) NULL,
    [address_city]           VARCHAR (300) NULL,
    [address_state_province] VARCHAR (50)  NULL,
    [address_country_region] VARCHAR (200) NULL,
    [website]                VARCHAR (500) NULL,
    [linkedin_company_page]  VARCHAR (500) NULL
);


GO