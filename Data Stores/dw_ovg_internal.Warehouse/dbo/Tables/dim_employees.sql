CREATE TABLE [dbo].[dim_employees] (
    [employee_name]    VARCHAR (300) NULL,
    [employee_email]   VARCHAR (300) NULL,
    [employee_status]  VARCHAR (100) NULL,
    [employee_role]    VARCHAR (200) NULL,
    [hire_date]        DATE          NULL,
    [termination_date] DATE          NULL,
    [pay_type]         VARCHAR (200) NULL
);


GO