/*  Step 5 - sp_publish_income_statement_copy
    Moves ONE validated staged slice into out_income_statement in a single transaction (BR-9):
        delete slice -> enrich (L1-L5 from dim_is_accounts, SignFlip) -> insert -> audit -> clear staging -> COMMIT

    Pre-transaction gates (each raises, and is logged as one FAILED audit row by CATCH):
        50001/50002  blank scope or RunId
        50003        ControlTotal not supplied
        50004        nothing staged for this slice (would otherwise delete the live slice and insert nothing)
        50005        staged total <> workbook ControlTotal (Excel-to-Fabric tie-out)
        50006        staged AccountL6ID with no match in dim_is_accounts (would vanish in the join - never drop)
        50007        AccountL6ID duplicated in dim_is_accounts (join would multiply rows)
        50009        staged rows with a NULL Amount or Date (SUM ignores NULLs, so the tie-out would pass)
        50010        SignFlip NULL or not in (-1, 1) for an account in the slice (no silent default)
    In-transaction check (read back from the TARGET, before COMMIT):
        50008        published rows or published ledger amount <> expected
                     (expected amount = staged Amount x SignFlip, computed before the transaction)

    Scope predicate is IDENTICAL to sp_clear_fcst_income_statement: exact match on Scenario, Version, SourceModel.
    Actuals carry SourceModel 'QBO', and that tag is the only thing keeping them out of the delete.

    Sign: the workbook holds revenue and costs as positives; out_income_statement uses the ledger convention
    (revenue negative). Amount * SignFlip is applied here, never in the dataflow.
    Audit amounts (both in ledger convention): ExpectedAmount = staged Amount x SignFlip computed before the
    transaction; PublishedAmount = SUM(Amount) read back from out_income_statement. The workbook ControlTotal
    tie (pre-flip) is enforced by 50005 and recorded in ScopeSourceModels.
    Account names: L6 and L1-L5 labels all come from dim_is_accounts, so the hierarchy cannot disagree with itself.
*/
CREATE   PROCEDURE dbo.sp_publish_income_statement_copy
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
    DECLARE @NullRows     BIGINT = 0, @BadSigns BIGINT = 0;
    DECLARE @ExpectedLedgerAmount DECIMAL(38,4) = 0;
    DECLARE @PublishedRows BIGINT = 0, @PublishedAmount DECIMAL(38,4) = 0;
    DECLARE @Msg          VARCHAR(4000);
    DECLARE @Scope        VARCHAR(4000) =
        CONCAT('Scenario=', @Scenario, '; Version=', @Version, '; SourceModel=', @SourceModel);

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Scenario)), '')    IS NULL
        OR NULLIF(LTRIM(RTRIM(@Version)), '')     IS NULL
        OR NULLIF(LTRIM(RTRIM(@SourceModel)), '') IS NULL
            THROW 50001, 'sp_publish_income_statement_copy: Scenario, Version and SourceModel are all required.', 1;
        IF NULLIF(LTRIM(RTRIM(@RunId)), '') IS NULL
            THROW 50002, 'sp_publish_income_statement_copy: RunId is required.', 1;
        IF @ControlTotal IS NULL
            THROW 50003, 'sp_publish_income_statement_copy: ControlTotal is required (from the workbook Validation row).', 1;

        SELECT @StagedRows = COUNT(*), @StagedAmount = ISNULL(SUM(Amount), 0)
        FROM dbo.fcst_income_statement
        WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel;

        IF @StagedRows = 0
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement_copy: nothing staged for ', @Scope, '. Refusing to publish an empty slice.');
            THROW 50004, @Msg, 1;
        END;

        -- NULL amounts are skipped by SUM, so they would slip past the tie-out; NULL dates vanish from every period filter
        SELECT @NullRows = COUNT(*)
        FROM dbo.fcst_income_statement
        WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel
          AND (Amount IS NULL OR Date IS NULL);

        IF @NullRows > 0
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement_copy: ', @NullRows, ' staged rows have a NULL Amount or Date for ', @Scope, '.');
            THROW 50009, @Msg, 1;
        END;

        -- Excel-to-Fabric tie-out, before the transaction opens
        IF @StagedAmount <> @ControlTotal
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement_copy: control total mismatch. Staged ', @StagedAmount,
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
            SELECT @Msg = LEFT(CONCAT('sp_publish_income_statement_copy: ', @BadAccounts, ' staged rows (', @BadAmount,
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
            SET @Msg = CONCAT('sp_publish_income_statement_copy: ', @DupAccounts, ' AccountL6ID values are duplicated in dim_is_accounts; the join would multiply rows.');
            THROW 50007, @Msg, 1;
        END;

        -- SignFlip must be exactly -1 or 1: NULL would silently publish unflipped, 0 would zero the row
        SELECT @BadSigns = COUNT(DISTINCT a.AccountL6ID)
        FROM dbo.fcst_income_statement s
        JOIN dbo.dim_is_accounts a ON a.AccountL6ID = s.AccountL6ID
        WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
          AND (a.SignFlip IS NULL OR a.SignFlip NOT IN (-1, 1));

        IF @BadSigns > 0
        BEGIN
            SET @Msg = CONCAT('sp_publish_income_statement_copy: ', @BadSigns, ' accounts in the slice have a SignFlip that is NULL or not -1/1 in dim_is_accounts.');
            THROW 50010, @Msg, 1;
        END;

        -- Expected ledger total, computed independently of the insert, to reconcile against the target afterwards
        SELECT @ExpectedLedgerAmount = ISNULL(SUM(s.Amount * a.SignFlip), 0)
        FROM dbo.fcst_income_statement s
        JOIN dbo.dim_is_accounts a ON a.AccountL6ID = s.AccountL6ID
        WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel;

        SET @Scope = CONCAT(@Scope, '; ControlTotal=', @ControlTotal, ' (tied to staged ', @StagedAmount, ' before the flip)');

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
                 s.AccountL6ID, a.AccountL6Name, s.CustomerName, s.VendorName, s.Date,
                 s.Scenario, s.Version, s.SourceModel, s.LoadDate,
                 a.AccountL5ID, a.AccountL4ID, a.AccountL3ID, a.AccountL2ID, a.AccountL1ID,
                 a.AccountL5Name, a.AccountL4Name, a.AccountL3Name, a.AccountL2Name, a.AccountL1Name,
                 s.Amount * a.SignFlip
            FROM dbo.fcst_income_statement s
            JOIN dbo.dim_is_accounts a ON a.AccountL6ID = s.AccountL6ID
            WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel;
            SET @RowsInserted = @@ROWCOUNT;

            -- Reconcile against what actually landed in the target, not against what we meant to write
            SELECT @PublishedRows = COUNT(*), @PublishedAmount = ISNULL(SUM(Amount), 0)
            FROM dbo.out_income_statement
            WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel;

            IF @PublishedRows <> @StagedRows OR @PublishedAmount <> @ExpectedLedgerAmount
            BEGIN
                SET @Msg = CONCAT('sp_publish_income_statement_copy: reconciliation failed. Rows staged ', @StagedRows, ', published ', @PublishedRows,
                                  '; expected ledger amount ', @ExpectedLedgerAmount, ', published ', @PublishedAmount, '.');
                THROW 50008, @Msg, 1;
            END;

            -- 3. Audit: exactly one success row, inside the transaction
            INSERT INTO dbo.sys_publish_audit
                (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
                 RowsDeleted, RowsInserted, ExpectedRows, PublishedRows,
                 ExpectedAmount, PublishedAmount, ReconMismatches, ScopeSourceModels)
            VALUES
                (@RunId, 'sp_publish_income_statement_copy', @StartUtc, SYSUTCDATETIME(), 'SUCCESS', 1,
                 @RowsDeleted, @RowsInserted, @StagedRows, @PublishedRows,
                 @ExpectedLedgerAmount, @PublishedAmount, 0, @Scope);

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
            (@RunId, 'sp_publish_income_statement_copy', @StartUtc, SYSUTCDATETIME(), 'FAILED', 1,
             @RowsDeleted, @RowsInserted, @StagedRows, @PublishedRows,
             @ExpectedLedgerAmount, @PublishedAmount, @BadAccounts, @BadAmount,
             @Scope, ERROR_NUMBER(), LEFT(ERROR_MESSAGE(), 4000));

        THROW;   -- original error number and message, not a new generic one
    END CATCH
END;

GO
