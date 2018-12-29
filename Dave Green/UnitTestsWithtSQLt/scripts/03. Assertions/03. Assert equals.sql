/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROCEDURE [Assertions].[test Equals] AS
BEGIN
	EXECUTE tSQLt.AssertEquals 12345.6789, 12345.6789; -- pass
    EXECUTE tSQLt.AssertEquals 'hello', 'hello'; -- pass
    EXECUTE tSQLt.AssertEquals N'hello', N'hello'; -- pass

    DECLARE @datetime DATETIME; SET @datetime = CAST('12-13-2005' AS DATETIME);
    EXECUTE tSQLt.AssertEquals @datetime, @datetime; -- pass

    DECLARE @bit BIT; SET @bit = CAST(1 AS BIT);
    EXECUTE tSQLt.AssertEquals @bit, @bit; -- pass

    EXECUTE tSQLt.AssertEquals NULL, NULL; -- pass
    EXECUTE tSQLt.AssertEquals 17, NULL; -- fail
    EXECUTE tSQLt.AssertEquals NULL, 17; -- fail

    EXECUTE tSQLt.AssertEquals 12345.6789, 54321.123; -- fail
    EXECUTE tSQLt.AssertEquals 'hello', 'goodbye'; -- fail

    DECLARE @datetime1 DATETIME; SET @datetime1 = CAST('12-13-2005' AS DATETIME);
    DECLARE @datetime2 DATETIME; SET @datetime2 = CAST('07-19-2005' AS DATETIME);
    EXECUTE tSQLt.AssertEquals @datetime1, @datetime2; -- fail

    DECLARE @bit1 BIT; SET @bit1 = CAST(1 AS BIT);
    DECLARE @bit2 BIT; SET @bit2 = CAST(1 AS BIT);
    EXECUTE tSQLt.AssertEquals @bit1, @bit2; -- pass
END
GO