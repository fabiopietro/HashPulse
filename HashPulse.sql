--USE [BTB_EDW01]

SET NOCOUNT ON;

------------------------------------------------------------
-- INTERNAL TABLE AUDIT – ENTROPY AND INTEGRITY
-- Author: Fábio Pietro Paulo
-- Description: Diagnosis of redundancy, diversity, and reliability
-- in a single table (without comparison between environments).

------------------------------------------------------------

DECLARE @startDateTime          DATETIME2 = SYSDATETIME();
DECLARE @endDateTime            DATETIME2;

------------------------------------------------------------
-- PARAMETERIZATION
------------------------------------------------------------
DECLARE @TargetTable          SYSNAME       = N'tbDuplicados';  -- Target table name
DECLARE @SchemaName           SYSNAME       = N'dbo';         -- Schema
DECLARE @KeyColumns           NVARCHAR(MAX) = N'cod_simulacao,modelo';
DECLARE @ExclusionColumns     NVARCHAR(MAX) = N'data_parametro';
DECLARE @LimiterColumn        NVARCHAR(MAX) = N'';            -- Ex: date_ref or id_batch
DECLARE @CaseSensitiveCheck   BIT           = 1;
DECLARE @SeparatorChar        CHAR(1)       = CHAR(30);
DECLARE @MaxDetailRows        INT           = 1000;
DECLARE @Debug                BIT           = 0;

------------------------------------------------------------
-- WORKING VARIABLES
------------------------------------------------------------
DECLARE @SQL                  NVARCHAR(MAX) = N'';
DECLARE @ColumnName           SYSNAME;
DECLARE @DataType             SYSNAME;
DECLARE @expr                 NVARCHAR(MAX);

DECLARE @Entropy              DECIMAL(10,6);
DECLARE @EntropyDescription   NVARCHAR(500);
DECLARE @TotalCount           BIGINT;
DECLARE @DuplicateKeysCount   BIGINT;
DECLARE @DuplicateHashesCount BIGINT;
DECLARE @Score                DECIMAL(5,2);
DECLARE @AcceptableScore      DECIMAL(5,2) = 99.90;

------------------------------------------------------------
-- TABLE EXISTENCE CHECK
------------------------------------------------------------
DECLARE @ObjectFullName NVARCHAR(300);
SET @TargetTable = QUOTENAME(@TargetTable);
SET @SchemaName = QUOTENAME(@SchemaName);
SET @ObjectFullName = @SchemaName + '.' + @TargetTable;

IF OBJECT_ID(@ObjectFullName, 'U') IS NULL
BEGIN
    THROW 50000, N'Target table not found.', 1;
END;

------------------------------------------------------------
-- CREATE TEMPORARY STRUCTURES
------------------------------------------------------------
DROP TABLE IF EXISTS #HashTable;
DROP TABLE IF EXISTS #Audit;
DROP TABLE IF EXISTS #Columns;

CREATE TABLE #HashTable
(
    [Key]       NVARCHAR(900),
    KeyHash    VARCHAR(64),
    [Hash]     VARCHAR(200)
);

CREATE TABLE #Audit
(
    [Key]       NVARCHAR(900),
    KeyHash    VARCHAR(64),
    DeltaType  VARCHAR(20),
    Severity   TINYINT,
    [Message]  VARCHAR(300)
);

CREATE TABLE #Columns
(
    ColumnName SYSNAME,
    DataType   SYSNAME
);

------------------------------------------------------------
-- LOAD COLUMN METADATA
------------------------------------------------------------
INSERT INTO #Columns (ColumnName, DataType)
SELECT c.name, t.name
FROM sys.columns c
JOIN sys.types t ON t.user_type_id = c.user_type_id
JOIN sys.objects o ON o.object_id = c.object_id
WHERE CONCAT('[', o.name, ']') = @TargetTable
AND o.type = 'U'
AND (
      LEN(@ExclusionColumns) = 0 OR
      CHARINDEX(',' + c.name + ',', ',' + @ExclusionColumns + ',') = 0
);

------------------------------------------------------------
-- BUILD HASH EXPRESSIONS
------------------------------------------------------------
DECLARE cCol CURSOR FOR SELECT ColumnName, DataType FROM #Columns;
OPEN cCol;
FETCH NEXT FROM cCol INTO @ColumnName, @DataType;

DECLARE @ColumnList NVARCHAR(MAX) = N'';

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ColumnName = QUOTENAME(@ColumnName);

    IF @DataType IN ('date','datetime','smalldatetime','datetime2','datetimeoffset','time')
        SET @expr = N'ISNULL(CONVERT(CHAR(33), ' + @ColumnName + ', 126), '''')';
    ELSE IF @DataType IN ('uniqueidentifier')
        SET @expr = N'ISNULL(CONVERT(CHAR(36), ' + @ColumnName + '), '''')';
    ELSE IF @DataType IN ('int','bigint','smallint','tinyint','bit','decimal','numeric','money','smallmoney','float','real')
        SET @expr = N'ISNULL(CONVERT(VARCHAR(100), ' + @ColumnName + '), '''')';
    ELSE
        SET @expr = N'ISNULL(LTRIM(RTRIM(CAST(' + @ColumnName + ' AS NVARCHAR(MAX)))), '''')';

    IF @CaseSensitiveCheck = 1
        SET @ColumnList += REPLICATE(' ', 55) + @expr + ',' + CHAR(13);
    ELSE
        SET @ColumnList += REPLICATE(' ', 55) + N'UPPER(' + @expr + '),' + CHAR(13);

    FETCH NEXT FROM cCol INTO @ColumnName, @DataType;
END;

CLOSE cCol;
DEALLOCATE cCol;

SET @ColumnList = LEFT(@ColumnList, LEN(@ColumnList) - 2);

------------------------------------------------------------
-- GENERATE CONTENT AND KEY HASHES
------------------------------------------------------------
SET @KeyColumns = REPLACE(@KeyColumns, ' ', '');
SET @KeyColumns = REPLACE(@KeyColumns, ',', ',''' + @SeparatorChar + ''',');

SET @SQL = N'
INSERT INTO #HashTable
SELECT 
    CONCAT(' + @KeyColumns + N') AS [Key],
    CONVERT(VARCHAR(64), HASHBYTES(''SHA2_256'', CONCAT(' + @KeyColumns + N')), 2) AS KeyHash,
    CONVERT(VARCHAR(64), HASHBYTES(''SHA2_256'', CONCAT(' + CHAR(13) + @ColumnList + N')), 2) AS [Hash]
FROM ' + @TargetTable + N';';

IF @Debug = 1 RAISERROR(@SQL,0,1) WITH NOWAIT;
EXEC (@SQL);

------------------------------------------------------------
-- METRICS
------------------------------------------------------------
SELECT @TotalCount = COUNT_BIG(*) FROM #HashTable;

;WITH DupsKey AS (
    SELECT KeyHash, COUNT(*) AS Qty
    FROM #HashTable
    GROUP BY KeyHash
    HAVING COUNT(*) > 1
)
INSERT INTO #Audit
SELECT H.[Key], H.KeyHash, 'DUP_KEY', 3, 'Duplicate key detected'
FROM #HashTable H
JOIN DupsKey D ON D.KeyHash = H.KeyHash;

;WITH DupsHash AS (
    SELECT [Hash], COUNT(*) AS Qty
    FROM #HashTable
    GROUP BY [Hash]
    HAVING COUNT(*) > 1
)
INSERT INTO #Audit
SELECT H.[Key], H.KeyHash, 'DUP_HASH', 2, 'Duplicate content (identical hash)'
FROM #HashTable H
JOIN DupsHash D ON D.[Hash] = H.[Hash];

SELECT 
    @DuplicateKeysCount = COUNT_BIG(*) FROM #Audit WHERE DeltaType = 'DUP_KEY';
SELECT 
    @DuplicateHashesCount = COUNT_BIG(*) FROM #Audit WHERE DeltaType = 'DUP_HASH';

------------------------------------------------------------
-- ENTROPY AND SCORE
------------------------------------------------------------
SELECT @Entropy = COUNT_BIG(DISTINCT [Hash]) * 1.0 / @TotalCount FROM #HashTable;

IF @Entropy < 0.01
    SET @EntropyDescription = N'Critical – Massive repetition, possible loop or redundant load.';
ELSE IF @Entropy < 0.10
    SET @EntropyDescription = N'Low – High structural replication, review deduplication.';
ELSE IF @Entropy < 0.50
    SET @EntropyDescription = N'Moderate – Partial diversity, repetition clusters.';
ELSE
    SET @EntropyDescription = N'High – Good record diversity.';

SELECT @Score = COALESCE(1 - ((@DuplicateKeysCount + @DuplicateHashesCount * 0.5) / NULLIF(@TotalCount,0)), 1);

------------------------------------------------------------
-- EXECUTIVE REPORT
------------------------------------------------------------
PRINT N'━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT N'📊 TABLE AUDIT – EXECUTIVE SUMMARY REPORT';
PRINT N'Execution Date: ' + CONVERT(VARCHAR(19), @startDateTime, 120);
PRINT N'Table Under Analysis : ' + @TargetTable;
PRINT N'━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '';
PRINT 'Total Records:      ' + FORMAT(@TotalCount, 'N0', 'en-US');
PRINT 'Duplicate Keys:     ' + FORMAT(@DuplicateKeysCount, 'N0', 'en-US');
PRINT 'Duplicate Hashes:   ' + FORMAT(@DuplicateHashesCount, 'N0', 'en-US');
PRINT 'Entropy:            ' + FORMAT(@Entropy, 'P2', 'en-US');
PRINT 'Diagnosis:          ' + @EntropyDescription;
PRINT 'Reliability:        ' + FORMAT(@Score, 'P2', 'en-US');
PRINT '------------------------------------------------------------------------------';

IF @Score < @AcceptableScore / 100 
    PRINT N'⚠️ Attention: Reliability below expected threshold.';
ELSE
    PRINT N'✅ Integrity within expected range.';

------------------------------------------------------------
-- EXECUTION TIME
------------------------------------------------------------
SET @endDateTime = SYSDATETIME();
DECLARE @TotalTimeMs INT = DATEDIFF(ms, @startDateTime, @endDateTime);
PRINT '';
PRINT 'Total time: ' + 
      CASE WHEN @TotalTimeMs > 1000 
           THEN FORMAT(@TotalTimeMs/1000.0, 'N2') + ' s'
           ELSE CAST(@TotalTimeMs AS VARCHAR(10)) + ' ms' END;

------------------------------------------------------------
-- OPTIONAL OUTPUT
------------------------------------------------------------
SELECT * FROM #Audit;