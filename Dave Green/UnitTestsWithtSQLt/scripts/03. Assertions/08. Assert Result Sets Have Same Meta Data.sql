/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROCEDURE [Assertions].[test Result Sets Have Same Meta Data OneLessColinActualThanExpected]
AS
BEGIN
	CREATE TABLE [Assertions].Expected (
		Col1 int,
		Col2 int,  
		col3 int)

	CREATE TABLE [Assertions].Actual (
		Col1 int,  
		Col2 int)

	EXEC tSQLt.AssertResultSetsHaveSameMetaData
		@expectedCommand = N'Select * from [Assertions].Expected', 
		@actualCommand = N'Select * from [Assertions].Actual'
END
GO


CREATE PROCEDURE [Assertions].[test Result Sets Have Same Meta Data OneMoreColInActualThanExpected]
AS
BEGIN
	CREATE TABLE [Assertions].Expected (
		Col1 int,  
		Col2 int)

	CREATE TABLE [Assertions].Actual (
		Col1 int,  
		Col2 int,  
		Col3 int)

	EXEC tSQLt.AssertResultSetsHaveSameMetaData
		@expectedCommand = N'Select * from [Assertions].Expected', 
		@actualCommand = N'Select * from [Assertions].Actual'    
END
GO


CREATE PROCEDURE [Assertions].[test Result Sets Have Same Meta Data OneLessDataInActualColThanExpected]
AS
BEGIN
	CREATE TABLE [Assertions].Expected (
		Col1 int,  
		Col2 int,  
		col3 int)

	CREATE TABLE [Assertions].Actual (
		Col1 int,  
		Col2 int,  
		Col3 int)

	INSERT [Assertions].Expected (col1,col2,col3) 
	VALUES (1,2,3)
	INSERT [Assertions].Actual (col1,col2) 
	VALUES (1,2)
  
	INSERT [Assertions].Expected (col1,col2) 
	VALUES (4,5)
	INSERT [Assertions].Actual (col1,col2,col3) 
	VALUES (4,5,6)

	INSERT [Assertions].Expected (col1,col2) 
	VALUES (7,8)
	INSERT [Assertions].Actual (col1,col2) 
	VALUES (7,8)

	EXEC tSQLt.AssertResultSetsHaveSameMetaData 
		@expectedCommand = N'Select * from [Assertions].Expected', 
		@actualCommand = N'Select * from [Assertions].Actual'
END
GO


CREATE PROCEDURE [Assertions].[test Result Sets Have Same Meta Data Cols in different order]
AS
BEGIN
	CREATE TABLE [Assertions].Expected (
		Col1 int,
		Col2 int,  
		col3 int)

	CREATE TABLE [Assertions].Actual (
		Col1 int,  
		Col3 int,  
		Col2 int)

	EXEC tSQLt.AssertResultSetsHaveSameMetaData 
		@expectedCommand = N'Select * from [Assertions].Expected', 
		@actualCommand = N'Select * from [Assertions].Actual'
END
GO


CREATE PROCEDURE [Assertions].[test Result Sets Have Same Meta Data Col3 has different datatype]
AS
BEGIN
	CREATE TABLE [Assertions].Expected (
		Col1 int,  
		Col2 int,  
		col3 int)

	CREATE TABLE [Assertions].Actual (
		Col1 int,  
		Col2 int,  
		col3 varchar(10))

	EXEC tSQLt.AssertResultSetsHaveSameMetaData 
		@expectedCommand = N'Select * from [Assertions].Expected', 
		@actualCommand = N'Select * from [Assertions].Actual'
END
GO