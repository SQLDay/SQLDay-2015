/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROC [Isolating Dependencies].[test Remove object] AS
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

	EXECUTE tSQLt.RemoveObject 'dbo.fcn_GetFirstOfMonth';
    EXECUTE ('CREATE FUNCTION dbo.fcn_GetFirstOfMonth (@Date DATE) RETURNS datetime AS 
			BEGIN RETURN ''2013-02-01 00:00:00''; END;');

	CREATE TABLE [Isolating Dependencies].Expected (
		InteractionTypeText VARCHAR(100),
		Occurrences INT,
		TotalTimeMins INT)

	CREATE TABLE [Isolating Dependencies].Actual (
		InteractionTypeText VARCHAR(100),
		Occurrences INT,
		TotalTimeMins INT)

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
	
	EXECUTE tSQLt.RemoveObject 'dbo.fcn_GetFirstOfMonth';
    EXECUTE ('CREATE FUNCTION dbo.fcn_GetFirstOfMonth (@Date DATE) RETURNS datetime AS 
			BEGIN RETURN ''2013-02-01 00:00:00''; END;');

	CREATE TABLE [Isolating Dependencies].Expected (
		InteractionTypeText VARCHAR(100),
		Occurrences INT,
		TotalTimeMins INT)

	CREATE TABLE [Isolating Dependencies].Actual (
		InteractionTypeText VARCHAR(100),
		Occurrences INT,
		TotalTimeMins INT)

	INSERT dbo.Interaction(InteractionTypeID, InteractionStartDT, InteractionEndDT)
	VALUES
		(5, CONVERT(DATETIME,'2013-01-03 09:00:00',120), CONVERT(DATETIME,'2013-01-03 09:30:00',120)),
		(5, CONVERT(DATETIME,'2013-01-02 09:00:00',120), CONVERT(DATETIME,'2013-01-02 10:30:00',120)),
		(5, CONVERT(DATETIME,'2013-02-02 09:00:00',120), CONVERT(DATETIME,'2013-02-02 10:30:00',120)), 
        (5, CONVERT(DATETIME,'2012-12-08 09:00:00',120), CONVERT(DATETIME,'2012-12-08 10:30:00',120)), 
        (2, CONVERT(DATETIME,'2013-01-03 09:01:00',120), CONVERT(DATETIME,'2013-01-03 09:13:00',120))

	INSERT [Isolating Dependencies].Expected 
	VALUES 
		('Meeting',2,120), 
		('Phone Call (Outbound)',1,12)

	INSERT [Isolating Dependencies].Actual
	EXECUTE dbo.RptContactsWithinPeriodUsingFunction 
		@WithinLastMonths = 1, 
		@RunAsAt = '2013-02-05'

	EXECUTE tSQLt.AssertEqualsTable 
		@Expected = N'[Isolating Dependencies].Expected',
		@Actual = N'[Isolating Dependencies].Actual',
		@FailMsg = N'The expected results were not returned'
END
GO