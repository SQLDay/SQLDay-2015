/*============================================================================
  Summary:  Demonstrates the disadvantages of GUIDs as Clustered Keys
------------------------------------------------------------------------------
  Written by Klaus Aschenbrenner, www.SQLpassion.at

  For more scripts and sample code, check out 
    http://www.SQLpassion.at

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE master
GO

CREATE DATABASE CustomersDatabase
GO

USE CustomersDatabase
GO

-- Create a new table with a UNIQUEIDENTIFIER column as primary key.
-- SQL Server will enforce the primary key constraint through unique clustered index in the background.
CREATE TABLE CustomersTableGuid
(
	ID UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	FirstName VARCHAR(50),
	LastName VARCHAR(50)
)
GO

-- Insert 100.000 records
DECLARE @i INT = 0
WHILE (@i <= 100000)
BEGIN
	INSERT INTO CustomersTableGuid (ID, FirstName, LastName)
	VALUES
	(
		NEWID(),
		'FirstName' + CAST(@i AS VARCHAR),
		'LastName' + CAST(@i AS VARCHAR)
	)
	
	SET @i +=1
END
GO

-- Check the fragmentation
-- Around 99% in the leaf level!
-- The index has 3 levels!!!
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableGuid'), 
	NULL, 
	NULL, 
	'DETAILED'
)
GO

-- Create a new table with a INT column as primary key.
CREATE TABLE CustomersTableINT
(
	ID INT NOT NULL IDENTITY(1, 1) PRIMARY KEY,
	FirstName VARCHAR(50),
	LastName VARCHAR(50)
)
GO

-- Insert 100.000 records
DECLARE @i INT = 0
WHILE (@i <= 100000)
BEGIN
	INSERT INTO CustomersTableINT (FirstName, LastName)
	VALUES
	(
		'FirstName' + CAST(@i AS VARCHAR),
		'LastName' + CAST(@i AS VARCHAR)
	)
	
	SET @i +=1
END
GO

-- Check the fragmentation
-- Around 0,88% in the leaf level!
-- The clustered index has only 2 levels!!!
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableINT'), 
	NULL, 
	NULL, 
	'DETAILED'
)
GO

-- Clean up
USE master
GO

DROP DATABASE CustomersDatabase
GO