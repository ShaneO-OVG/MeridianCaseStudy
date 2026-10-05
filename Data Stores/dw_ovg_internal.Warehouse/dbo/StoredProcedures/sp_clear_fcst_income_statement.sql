/*  Step 3 - sp_clear_fcst_income_statement
    Removes the prior staged attempt for ONE slice (Scenario + Version + SourceModel) so a re-run
    cannot double the rows (BR-4). Scoped DELETE only - never TRUNCATE: the staging table is shared
    by other scenarios and other source models (BR-3, BR-5).

    Equality contract: exact match on all three stamps, no trimming or UPPER() here.
    sp_publish_income_statement uses the IDENTICAL predicate, so what one clears the other replaces.

    Audit: exactly one row in sys_publish_audit per run, success or failure.
    sys_publish_audit has no Scenario/Version columns, so the slice is written into
    ScopeSourceModels as "Scenario=...; Version=...; SourceModel=..." (gap to note in the design note).
*/
CREATE   PROCEDURE dbo.sp_clear_fcst_income_statement
    @RunId       VARCHAR(36),
    @Scenario    VARCHAR(300),
    @Version     VARCHAR(300),
    @SourceModel VARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartUtc    DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @RowsDeleted BIGINT = 0;
    DECLARE @Scope       VARCHAR(4000) =
        CONCAT('Scenario=', @Scenario, '; Version=', @Version, '; SourceModel=', @SourceModel);

    BEGIN TRY
        -- A NULL or blank scope matches nothing and would report success - refuse it loudly.
        IF NULLIF(LTRIM(RTRIM(@Scenario)), '')    IS NULL
        OR NULLIF(LTRIM(RTRIM(@Version)), '')     IS NULL
        OR NULLIF(LTRIM(RTRIM(@SourceModel)), '') IS NULL
            THROW 50001, 'sp_clear_fcst_income_statement: Scenario, Version and SourceModel are all required.', 1;

        IF NULLIF(LTRIM(RTRIM(@RunId)), '') IS NULL
            THROW 50002, 'sp_clear_fcst_income_statement: RunId is required.', 1;

        BEGIN TRANSACTION;

            DELETE FROM dbo.fcst_income_statement
            WHERE Scenario    = @Scenario
              AND Version     = @Version
              AND SourceModel = @SourceModel;

            SET @RowsDeleted = @@ROWCOUNT;

            -- Audit before COMMIT: nothing runs after the commit on the success path.
            INSERT INTO dbo.sys_publish_audit
                (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
                 RowsDeleted, RowsInserted, ScopeSourceModels)
            VALUES
                (@RunId, 'sp_clear_fcst_income_statement', @StartUtc, SYSUTCDATETIME(), 'SUCCESS', 1,
                 @RowsDeleted, 0, @Scope);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO dbo.sys_publish_audit
            (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
             RowsDeleted, RowsInserted, ScopeSourceModels, ErrorNumber, ErrorMessage)
        VALUES
            (@RunId, 'sp_clear_fcst_income_statement', @StartUtc, SYSUTCDATETIME(), 'FAILED', 1,
             0, 0, @Scope, ERROR_NUMBER(), LEFT(ERROR_MESSAGE(), 4000));

        THROW;  -- re-throw the ORIGINAL error so the pipeline fails with the real number and message
    END CATCH
END;

GO