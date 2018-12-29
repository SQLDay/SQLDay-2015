/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROCEDURE [Assertions].[test Equals table] AS
BEGIN
	CREATE TABLE Assertions.Expected (
		InteractionTypeText VARCHAR(100),
		Occurrences INT,
		TotalTimeMins INT)

	INSERT Assertions.Expected VALUES 
	('Complaint',206,78411),
	('Introduction',214,77837),
	('Meeting',190,69050),
	('Sale',202,75175),
	('Phone Call (Outbound)',188,64839)

	SELECT * INTO Assertions.Actual FROM dbo.RptContactTypes

	EXECUTE tSQLt.AssertEqualsTable 
		@Expected = N'Assertions.Expected',
		@Actual = N'Assertions.Actual',
		@FailMsg = N'The expected data was not returned.'
END
GO
