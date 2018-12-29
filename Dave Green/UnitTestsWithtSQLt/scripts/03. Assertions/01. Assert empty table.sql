/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROCEDURE [Assertions].[test Empty table] AS
BEGIN
	EXECUTE tSQLt.AssertEmptyTable 
		@TableName = N'dbo.Employee'
END
GO
