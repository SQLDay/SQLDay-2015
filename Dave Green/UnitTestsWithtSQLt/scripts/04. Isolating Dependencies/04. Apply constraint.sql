/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROC [Isolating Dependencies].[test Apply constraint Invalid inputs] AS
BEGIN
	EXECUTE tSQLt.FakeTable 
		@TableName = N'dbo.Interaction'

	EXECUTE tSQLt.FakeTable 
		@TableName = N'dbo.Customer'

	EXECUTE tSQLt.ApplyConstraint 
		@TableName = N'dbo.Interaction',
		@ConstraintName = N'FK_Interaction_Customer'
    
	EXECUTE tSQLt.ExpectException

	INSERT dbo.Interaction(CustomerID)       
	VALUES(1)
END
GO


CREATE PROC [Isolating Dependencies].[test Apply constraint Valid inputs] AS
BEGIN
	EXECUTE tSQLt.FakeTable 
		@TableName = N'dbo.Interaction'

	EXECUTE tSQLt.FakeTable 
		@TableName = N'dbo.Customer'

	EXECUTE tSQLt.ApplyConstraint 
		@TableName = N'dbo.Interaction',
		@ConstraintName = N'FK_Interaction_Customer'
    
	INSERT dbo.Customer(CustomerID) 
	VALUES(1)

	EXECUTE tSQLt.ExpectNoException

	INSERT dbo.Interaction(CustomerID)
	VALUES(1)
END
GO