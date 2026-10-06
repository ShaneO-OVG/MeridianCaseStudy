/*  Step 4 - sp_add_customers_and_vendors
    Conforms customer and vendor names in ONE staged slice to dim_customers / dim_vendors (BR-6).

    Matching rule: names are compared case- and whitespace-insensitively (UPPER(TRIM(x))),
    because the warehouse collation is BIN2 and 'Abacum ' / 'abacum' would otherwise be new members.

      1. Conform  - a staged name with exactly ONE case-insensitive match in the dimension is rewritten
                    to the dimension's spelling (audit: RowsUpdated). No case-variant duplicate is created.
      2. Insert   - a staged name with NO case-insensitive match is inserted once (one spelling per name)
                    (audit: RowsInserted). Nulls ignored. Re-running inserts nothing.
      3. Surface  - anything still not an exact match afterwards (e.g. a name that matches two dimension
                    members differing only by case) is counted in UnmappedRows / UnmappedAmount, with a
                    TOP 5 sample appended to ScopeSourceModels, for the notification step. It is never dropped.

    Gap vs case study: dim_customers / dim_vendors are name-only (no ID column), so there is no ID to assign.
    Audit: exactly one row per run, written before COMMIT; on failure roll back, log FAILED, re-throw.
*/
CREATE   PROCEDURE dbo.sp_add_customers_and_vendors
    @RunId       VARCHAR(36),
    @Scenario    VARCHAR(300),
    @Version     VARCHAR(300),
    @SourceModel VARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartUtc        DATETIME2(6) = SYSUTCDATETIME();
    DECLARE @Updated         BIGINT = 0, @Inserted BIGINT = 0, @n BIGINT;
    DECLARE @UnmappedRows    BIGINT = 0, @UnmappedAmount DECIMAL(38,4) = 0;
    DECLARE @Sample          VARCHAR(4000) = NULL;
    DECLARE @Scope           VARCHAR(4000) =
        CONCAT('Scenario=', @Scenario, '; Version=', @Version, '; SourceModel=', @SourceModel);

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Scenario)), '')    IS NULL
        OR NULLIF(LTRIM(RTRIM(@Version)), '')     IS NULL
        OR NULLIF(LTRIM(RTRIM(@SourceModel)), '') IS NULL
            THROW 50001, 'sp_add_customers_and_vendors: Scenario, Version and SourceModel are all required.', 1;
        IF NULLIF(LTRIM(RTRIM(@RunId)), '') IS NULL
            THROW 50002, 'sp_add_customers_and_vendors: RunId is required.', 1;

        BEGIN TRANSACTION;

            /* ---------- 1. Conform spelling to an existing single match ---------- */
            UPDATE dbo.fcst_income_statement
            SET CustomerName = (SELECT MIN(d.CustomerName) FROM dbo.dim_customers d
                                WHERE UPPER(TRIM(d.CustomerName)) = UPPER(TRIM(fcst_income_statement.CustomerName)))
            WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel
              AND CustomerName IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM dbo.dim_customers d WHERE d.CustomerName = fcst_income_statement.CustomerName)
              AND (SELECT COUNT(*) FROM dbo.dim_customers d
                   WHERE UPPER(TRIM(d.CustomerName)) = UPPER(TRIM(fcst_income_statement.CustomerName))) = 1;
            SET @Updated += @@ROWCOUNT;

            UPDATE dbo.fcst_income_statement
            SET VendorName = (SELECT MIN(d.VendorName) FROM dbo.dim_vendors d
                              WHERE UPPER(TRIM(d.VendorName)) = UPPER(TRIM(fcst_income_statement.VendorName)))
            WHERE Scenario = @Scenario AND Version = @Version AND SourceModel = @SourceModel
              AND VendorName IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM dbo.dim_vendors d WHERE d.VendorName = fcst_income_statement.VendorName)
              AND (SELECT COUNT(*) FROM dbo.dim_vendors d
                   WHERE UPPER(TRIM(d.VendorName)) = UPPER(TRIM(fcst_income_statement.VendorName))) = 1;
            SET @Updated += @@ROWCOUNT;

            /* ---------- 2. Insert genuinely new members (one spelling per name) ---------- */
            INSERT INTO dbo.dim_customers (CustomerName)
            SELECT MIN(TRIM(s.CustomerName))
            FROM dbo.fcst_income_statement s
            WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
              AND NULLIF(TRIM(s.CustomerName), '') IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM dbo.dim_customers d
                              WHERE UPPER(TRIM(d.CustomerName)) = UPPER(TRIM(s.CustomerName)))
            GROUP BY UPPER(TRIM(s.CustomerName));
            SET @n = @@ROWCOUNT; SET @Inserted += @n;

            INSERT INTO dbo.dim_vendors (VendorName)
            SELECT MIN(TRIM(s.VendorName))
            FROM dbo.fcst_income_statement s
            WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
              AND NULLIF(TRIM(s.VendorName), '') IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM dbo.dim_vendors d
                              WHERE UPPER(TRIM(d.VendorName)) = UPPER(TRIM(s.VendorName)))
            GROUP BY UPPER(TRIM(s.VendorName));
            SET @n = @@ROWCOUNT; SET @Inserted += @n;

            /* ---------- 3. Surface anything still unresolved (never drop it) ---------- */
            SELECT @UnmappedRows = COUNT(*), @UnmappedAmount = ISNULL(SUM(s.Amount), 0)
            FROM dbo.fcst_income_statement s
            WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
              AND (   (s.CustomerName IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.dim_customers d WHERE d.CustomerName = s.CustomerName))
                   OR (s.VendorName   IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.dim_vendors   d WHERE d.VendorName   = s.VendorName)));

            IF @UnmappedRows > 0
                SELECT @Sample = LEFT(CONCAT('UNRESOLVED (top 5): ', STRING_AGG(u.Label, ' | ')), 4000)
                FROM (
                    SELECT TOP 5 Label
                    FROM (
                        SELECT DISTINCT CONCAT('Customer: ', s.CustomerName) AS Label
                        FROM dbo.fcst_income_statement s
                        WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
                          AND s.CustomerName IS NOT NULL
                          AND NOT EXISTS (SELECT 1 FROM dbo.dim_customers d WHERE d.CustomerName = s.CustomerName)
                        UNION
                        SELECT DISTINCT CONCAT('Vendor: ', s.VendorName)
                        FROM dbo.fcst_income_statement s
                        WHERE s.Scenario = @Scenario AND s.Version = @Version AND s.SourceModel = @SourceModel
                          AND s.VendorName IS NOT NULL
                          AND NOT EXISTS (SELECT 1 FROM dbo.dim_vendors d WHERE d.VendorName = s.VendorName)
                    ) x
                    ORDER BY Label
                ) u;

            -- The unresolved sample goes in the free-text scope column, not ErrorMessage, so that
            -- "ErrorMessage IS NOT NULL" keeps meaning "this run failed".
            INSERT INTO dbo.sys_publish_audit
                (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
                 RowsDeleted, RowsInserted, RowsUpdated, UnmappedRows, UnmappedAmount,
                 ScopeSourceModels)
            VALUES
                (@RunId, 'sp_add_customers_and_vendors', @StartUtc, SYSUTCDATETIME(), 'SUCCESS', 1,
                 0, @Inserted, @Updated, @UnmappedRows, @UnmappedAmount,
                 LEFT(CONCAT(@Scope, CASE WHEN @Sample IS NOT NULL THEN CONCAT('; ', @Sample) END), 4000));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        INSERT INTO dbo.sys_publish_audit
            (RunId, ProcName, StartUtc, EndUtc, Status, Attempt,
             RowsDeleted, RowsInserted, RowsUpdated, ScopeSourceModels, ErrorNumber, ErrorMessage)
        VALUES
            (@RunId, 'sp_add_customers_and_vendors', @StartUtc, SYSUTCDATETIME(), 'FAILED', 1,
             0, @Inserted, @Updated, @Scope, ERROR_NUMBER(), LEFT(ERROR_MESSAGE(), 4000));

        THROW;
    END CATCH
END;

GO