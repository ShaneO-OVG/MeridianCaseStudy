CREATE TABLE [dbo].[out_headcount] (
    [EmployeeID]     VARCHAR (50)    NULL,
    [MonthEnd]       DATE            NULL,
    [Email]          VARCHAR (400)   NULL,
    [Name]           VARCHAR (400)   NULL,
    [Role]           VARCHAR (200)   NULL,
    [State]          VARCHAR (50)    NULL,
    [HireDate]       DATE            NULL,
    [TermDate]       DATE            NULL,
    [EmployeeType]   VARCHAR (100)   NULL,
    [PayType]        VARCHAR (100)   NULL,
    [Salary]         DECIMAL (18, 4) NULL,
    [HourlyRate]     DECIMAL (18, 4) NULL,
    [BonusPct]       DECIMAL (10, 4) NULL,
    [ReportingTo]    VARCHAR (400)   NULL,
    [BeginningHC]    DECIMAL (10, 2) NULL,
    [NewHires]       DECIMAL (10, 2) NULL,
    [Terminations]   DECIMAL (10, 2) NULL,
    [ConversionsIn]  DECIMAL (10, 2) NULL,
    [ConversionsOut] DECIMAL (10, 2) NULL,
    [EndingHC]       DECIMAL (10, 2) NULL
);


GO