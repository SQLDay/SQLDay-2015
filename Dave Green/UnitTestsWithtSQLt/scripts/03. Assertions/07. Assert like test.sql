/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROC Assertions.[test Like] AS
BEGIN
	EXEC tSQLt.SpyProcedure
		@ProcedureName = N'dbo.Maintenance_CalculateAverages',
		@CommandToExecute = N'DECLARE @rnd CHAR(2) = FLOOR(RAND() * 100) 
						DECLARE @delay VARCHAR(100) = ''00:00:00.''+@rnd 
						WAITFOR DELAY @delay'

	EXEC tSQLt.SpyProcedure 
		@ProcedureName = N'dbo.Maintenance_CustomersTakingMoreTime'

	DECLARE @Actual VARCHAR(MAX)
	EXECUTE dbo.Maintenance @Message = @Actual OUTPUT

	EXEC tSQLt.AssertLike 
		@ExpectedPattern = N'Completed in % milliseconds',
		@Actual = @Actual,
		@Message = N'Expected message was not received in output variable.'
END
GO

