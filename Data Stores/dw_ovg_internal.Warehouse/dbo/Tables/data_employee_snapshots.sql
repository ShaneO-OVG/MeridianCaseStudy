CREATE TABLE [dbo].[data_employee_snapshots] (
    [EmployeeID]   VARCHAR (50)    NULL,
    [MonthEnd]     DATE            NULL,
    [Email]        VARCHAR (400)   NULL,
    [Name]         VARCHAR (400)   NULL,
    [Role]         VARCHAR (200)   NULL,
    [State]        VARCHAR (50)    NULL,
    [HireDate]     DATE            NULL,
    [TermDate]     DATE            NULL,
    [EmployeeType] VARCHAR (100)   NULL,
    [PayType]      VARCHAR (100)   NULL,
    [Salary]       DECIMAL (18, 4) NULL,
    [HourlyRate]   DECIMAL (18, 4) NULL,
    [BonusPct]     DECIMAL (10, 4) NULL,
    [ReportingTo]  VARCHAR (400)   NULL
);


GO