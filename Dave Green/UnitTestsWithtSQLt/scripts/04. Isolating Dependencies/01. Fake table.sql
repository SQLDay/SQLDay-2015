/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROCEDURE [Isolating Dependencies].[test Fake table] AS
BEGIN
	EXECUTE tSQLt.FakeTable 
		@TableName = N'dbo.InteractionType'
  
	EXECUTE tSQLt.FakeTable 
		@TableName = N'dbo.Interaction'
      
	INSERT dbo.InteractionType(InteractionTypeID, InteractionTypeText)
	VALUES	 
		(1,'Introduction'),
		(2,'Phone Call (Outbound)'),
		(3,'Complaint'),
		(4,'Sale'),
		(5,'Meeting')

	INSERT dbo.Interaction(InteractionTypeID, InteractionStartDT, InteractionEndDT)
	VALUES  
		(5, CONVERT(DATETIME,'2013-01-03 09:00:00',120), CONVERT(DATETIME,'2013-01-03 09:30:00',120)),
		(5, CONVERT(DATETIME,'2013-01-02 09:00:00',120), CONVERT(DATETIME,'2013-01-02 10:30:00',120)),
		(2, CONVERT(DATETIME,'2013-01-03 09:01:00',120), CONVERT(DATETIME,'2013-01-03 09:13:00',120))

	CREATE TABLE [Isolating Dependencies].Expected (
		InteractionTypeText VARCHAR(100),
		Occurrences INT,
		TotalTimeMins INT)

	INSERT [Isolating Dependencies].Expected 
	VALUES 
		('Meeting',2,120), 
		('Phone Call (Outbound)',1,12)

	SELECT 
		* 
	INTO [Isolating Dependencies].Actual 
	FROM dbo.RptContactTypes

	EXECUTE tSQLt.AssertEqualsTable 
		@Expected = N'[Isolating Dependencies].Expected',
		@Actual = N'[Isolating Dependencies].Actual',
		@FailMsg = N'The expected data was not returned.'
END
GO