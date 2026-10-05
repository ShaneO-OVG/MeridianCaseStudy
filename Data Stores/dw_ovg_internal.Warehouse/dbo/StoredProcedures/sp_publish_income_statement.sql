/*  Step 5 - sp_publish_income_statement
    Moves ONE validated staged slice into out_income_statement in a single transaction (BR-9):
        delete slice -> enrich (L1-L5 from dim_is_accounts, SignFlip) -> insert -> audit -> clear staging -> COMMIT

    Pre-transaction gates (each raises, and is logged as one FAILED audit row by CATCH):
        50001/50002  blank scope or RunId
        50003        ControlTotal not supplied
        50004        nothing staged for this slice (would otherwise delete the live slice and insert nothing)
        50005        staged total <> workbook ControlTotal (Excel-to-Fabric tie-out)
        50006        staged AccountL6ID with no match in dim_is_accounts (would vanish in the join - never drop)
        50007        AccountL6ID duplicated in dim_is_accounts (join would multiply rows)
    In-transaction check:
        50008        inserted rows <> staged rows

    Scope predicate is IDENTICAL to sp_clear_fcst_income_statement: exact match on Scenario, Version, SourceModel.
    Actuals carry SourceModel 'QBO', and that tag is the only thing keeping them out of the delete.

    Sign: the workbook holds revenue and costs as positives; out_income_statement uses the ledger convention
    (revenue negative). Amount * ISNULL(SignFlip, 1) is applied here, never in the dataflow.
    Audit amounts: ExpectedAmount = ControlTotal, PublishedAmount = staged total before the sign flip,
    so the two are directly comparable.
*/
CREATE   PROCEDURE dbo.sp_publish_income_statement
    @RunId        VARCHAR(36),
    @Scenario     VARCHAR(300),
    @Version      VARCHAR(300),
    @SourceModel  VARCHAR(400),
    @ControlTotal DECIMAL(18,4)
AS
BEGIN
    SET NOCOUNT ON;

    -- Start time and counters initialised before anything can fail
    DECLARE @StartUtc     DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @RowsDeleted  BIGINT = 0, @RowsInserted BIGINT = 0;
    DECLARE @StagedRows   BIGINT = 0, @StagedAmount DECIMAL(38,4) = 0;
    DECLARE @BadAccounts  BIGINT = 0, @BadAmount DECIMAL(38,4) = 0, @DupAccounts BIGINT = 0;
    DECLARE @Msg          VARCHAR(4000);
    DECLARE @Scope        VARCHAR(4000) =
        CONCAT('Scenario=', @Scenario, '; Version=', @Version, '; SourceModel=', @SourceModel);

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Scenario)), '')    IS NULL
        OR NULLIF(LTRIM(RTRIM(@Version)), '')     IS NULL
        OR NULLIF(LTRIM(RTRIM(@SourceModel)), '') IS NULL
            THROW 50001, 'sp_publish_income_statement: Scenario, Version and SourceModel are all required.', 1;
        IF NULLIF(LTRIM(RTRIM(@RunId)), '') IS NULL
            THROW 50002, 'sp_publish_income_statement: RunId is required.', 1;
        IF @ControlTotal IS NULL
            THROW 50003, 'sp_publish_income_statement: ControlTotal is required (from the workbook Validation row).', 1;

        SELECT @StagedRows = COUNT(*), @StagedAmount = ISNULL(SUM(Amount), 0)
        FROM dbo.fcst_income_statement
        WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel;

        IF @StagedRows = 0
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement: nothing staged for ', @Scope, '. Refusing to publish an empty slice.');
            THROW 50004, @Msg, 1;
        END;

        -- Excel-to-Fabric tie-out, before the transaction opens
        IF @StagedAmount <> @ControlTotal
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement: control total mismatch. Staged ', @StagedAmount,
                              ' vs workbook ControlTotal ', @ControlTotal, ' (difference ', @StagedAmount - @ControlTotal,
                              '). Recalculate and save the workbook, then re-run.');
            THROW 50005, @Msg, 1;
        END;

        -- Rows whose account is not in the hierarchy would silently vanish in the join: refuse instead
        SELECT @BadAccounts = COUNT(*), @BadAmount = ISNULL(SUM(s.Amount), 0)
        FROM dbo.fcst_income_statement s
        WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
          AND NOT EXISTS (SELECT 1 FROM dbo.dim_is_accounts a WHERE a.AccountL6ID = s.AccountL6ID);

        IF @BadAccounts > 0
        BEGIN
            SELECT @Msg = LEFT(CONCAT('sp_publish_income_statement: ', @BadAccounts, ' staged rows (', @BadAmount,
                              ') have an AccountL6ID not in dim_is_accounts. Top 5: ', STRING_AGG(x.AccountL6ID, ', ')), 4000)
            FROM (SELECT DISTINCT TOP 5 s.AccountL6ID
                  FROM dbo.fcst_income_statement s
                  WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
                    AND NOT EXISTS (SELECT 1 FROM dbo.dim_is_accounts a WHERE a.AccountL6ID = s.AccountL6ID)
                  ORDER BY s.AccountL6ID) x;
            THROW 50006, @Msg, 1;
        END;

        SELECT @DupAccounts = COUNT(*)
        FROM (SELECT a.AccountL6ID FROM dbo.dim_is_accounts a
              WHERE a.AccountL6ID IN (SELECT s.AccountL6ID FROM dbo.fcst_income_statement s
                                      WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel)
              GROUP BY a.AccountL6ID HAVING COUNT(*) > 1) d;

        IF @DupAccounts > 0
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement: ', @DupAccounts, ' AccountL6ID values are duplicated in dim_is_accounts; the join would multiply rows.');
            THROW 50007, @Msg, 1;
        END;

        BEGIN TRANSACTION;

            -- 1. Delete the target slice only
            DELETE FROM dbo.out_income_statement
            WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel;
            SET @RowsDeleted = @@ROWCOUNT;

            -- 2. Enrich and insert (explicit column list: out_income_statement's column order differs from staging)
            INSERT INTO dbo.out_income_statement
                (AccountL6ID, AccountL6Name, CustomerName, VendorName, Date,
                 Scenario, Version, SourceModel, LoadDate,
                 AccountL5ID, AccountL4ID, AccountL3ID, AccountL2ID, AccountL1ID,
                 AccountL5Name, AccountL4Name, AccountL3Name, AccountL2Name, AccountL1Name,
                 Amount)
            SELECT
                 s.AccountL6ID, s.AccountL6Name, s.CustomerName, s.VendorName, s.Date,
                 s.Scenario, s.Version, s.SourceModel, s.LoadDate,
                 a.AccountL5ID, a.AccountL4ID, a.AccountL3ID, a.AccountL2ID, a.AccountL1ID,
                 a.AccountL5Name, a.AccountL4Name, a.AccountL3Name, a.AccountL2Name, a.AccountL1Name,
                 s.Amount * ISNULL(a.SignFlip, 1)
            FROM dbo.fcst_income_statement s
            JOIN dbo.dim_is_accounts a ON a.AccountL6ID = s.AccountL6ID
            WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel;
            SET @RowsInserted = @@ROWCOUNT;

            IF @RowsInserted <> @StagedRows
            BEGIN
                SET @Msg = CONCAT('sp_publish_income_statement: inserted ', @RowsInserted, ' rows but ', @StagedRows, ' were staged.');
                THROW 50008, @Msg, 1;
            END;

            -- 3. Audit: exactly one success row, inside the transaction
            INSERT INTO dbo.sys_publish_audit
                (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
                 RowsDeleted, RowsInserted, ExpectedRows, PublishedRows,
                 ExpectedAmount, PublishedAmount, ReconMismatches, ScopeSourceModels)
            VALUES
                (@RunId, 'sp_publish_income_statement', @StartUtc, SYSUTCDATETIME(), 'SUCCESS', 1,
                 @RowsDeleted, @RowsInserted, @StagedRows, @RowsInserted,
                 @ControlTotal, @StagedAmount, 0, @Scope);

            -- 4. Clear the now-published slice from staging
            DELETE FROM dbo.fcst_income_statement
            WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel;

        COMMIT TRANSACTION;   -- nothing runs after this on the success path
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO dbo.sys_publish_audit
            (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
             RowsDeleted, RowsInserted, ExpectedRows, PublishedRows,
             ExpectedAmount, PublishedAmount, UnmappedRows, UnmappedAmount,
             ScopeSourceModels, ErrorNumber, ErrorMessage)
        VALUES
            (@RunId, 'sp_publish_income_statement', @StartUtc, SYSUTCDATETIME(), 'FAILED', 1,
             @RowsDeleted, @RowsInserted, @StagedRows, 0,
             @ControlTotal, @StagedAmount, @BadAccounts, @BadAmount,
             @Scope, ERROR_NUMBER(), LEFT(ERROR_MESSAGE(), 4000));

        THROW;   -- original error number and message, not a new generic one
    END CATCH
END;

GO