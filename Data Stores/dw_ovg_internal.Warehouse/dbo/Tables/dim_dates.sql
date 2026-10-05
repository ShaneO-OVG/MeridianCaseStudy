CREATE TABLE [dbo].[dim_dates] (
    [date_id]             DATE         NULL,
    [day_number]          INT          NULL,
    [month_number]        INT          NULL,
    [month_name]          VARCHAR (20) NULL,
    [quarter_number]      INT          NULL,
    [quarter_name]        VARCHAR (20) NULL,
    [year_number]         INT          NULL,
    [is_weekday]          INT          NULL,
    [is_holiday]          INT          NULL,
    [is_work_day]         INT          NULL,
    [work_hours]          INT          NULL,
    [date_key]            VARCHAR (20) NULL,
    [day_name]            VARCHAR (10) NULL,
    [day_of_week_number]  INT          NULL,
    [week_start_date]     DATE         NULL,
    [week_of_year]        INT          NULL,
    [month_year]          VARCHAR (12) NULL,
    [year_name]           VARCHAR (4)  NULL,
    [fiscal_year]         INT          NULL,
    [fiscal_quarter]      INT          NULL,
    [fiscal_quarter_name] VARCHAR (2)  NULL,
    [fiscal_month_number] INT          NULL,
    [fiscal_year_name]    VARCHAR (6)  NULL,
    [is_weekend]          INT          NULL
);


GO