/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROCEDURE Assertions.[test Equals string] AS
BEGIN
	EXECUTE tSQLt.SpyProcedure 
		@ProcedureName = N'dbo.Maintenance_CalculateAverages'

	EXECUTE tSQLt.SpyProcedure 
		@ProcedureName = N'dbo.Maintenance_CustomersTakingMoreTime'

	DECLARE @Actual VARCHAR(MAX)
	EXECUTE dbo.Maintenance @Message = @Actual OUTPUT

	EXECUTE tSQLt.AssertEqualsString 
		@Expected = N'Completed',
		@Actual = @Actual,
		@Message = N'Expected message was not received in output variable.'
END
GO

