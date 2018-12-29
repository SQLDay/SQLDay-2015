/*============================================================================
  Summary:  Demonstrates how to resolve GUID issues through the Fill Factor
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

-- Insert 50.000 records
DECLARE @i INT = 0
WHILE (@i <= 50000)
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

-- Check the size of our clustered index.
-- The index has 3 levels and the page count is 536.
-- The fragmentation is 99%.
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableGuid'), 
	NULL, 
	NULL, 
	'DETAILED'
)
GO

-- Add 10.000 additional records with the default fill factor
-- There are a lot of page splits occuring.
DECLARE @i INT = 0
WHILE (@i <= 10000)
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

-- Check the size of our clustered index.
-- The index has 3 levels and the page count is 594.
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableGuid'), 
	NULL, 
	NULL, 
	'DETAILED'
)
GO

-- Change the fill factor
ALTER INDEX PK__Customer__3214EC27B6FD9BF1 ON CustomersTableGuid REBUILD WITH
(
	FILLFACTOR = 50
)
GO

-- Check the size of our clustered index again.
-- The index has 3 levels and the page count is now 845 and the avg_page_space_used_in_percent is 50% - the new set fill factor.
-- The fragmentation is now 0% - everything is nice.
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableGuid'), 
	NULL, 
	NULL, 
	'DETAILED'
)
GO

-- Add 10.000 additional records with the new fill factor of 50%
-- There are now no page splits.
DECLARE @i INT = 0
WHILE (@i <= 10000)
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

-- Check the size of our clustered index again.
-- The index has 3 levels and the page count is now 845 and the avg_page_space_used_in_percent is 58%.
-- The fragmentation is now 0% - everything is nice.
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableGuid'), 
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