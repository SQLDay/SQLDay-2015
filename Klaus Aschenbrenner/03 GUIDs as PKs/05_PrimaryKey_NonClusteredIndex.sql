/*=================================================================================
  Summary:  Demonstrates how to enforce a Primary Key through a Non-Clustered Index
-----------------------------------------------------------------------------------
  Written by Klaus Aschenbrenner, SQLpassion.at

  For more scripts and sample code, check out 
    http://www.SQLpassion.at

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
===================================================================================*/

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

-- Insert 10.000 records
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

-- 1. Change the database to single user mode
ALTER DATABASE CustomersDatabase SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO

-- 2. Disable all FKs
-- There is now no referential integrity, therefore we've set the database to single user mode.
-- ...

-- 3. Disable all defined Non-Clustered Indexes
-- Therefore it's not possible to rebuild those indexes when the clustered index is dropped.
-- ...

-- 4. Drop the primary key constraint
ALTER TABLE CustomersTableGuid DROP CONSTRAINT PK__Customer__3214EC277A2D2706
GO

-- 5. Add a new clustered key column
ALTER TABLE CustomersTableGuid ADD
	PK_INT int NOT NULL IDENTITY (1, 1)
GO

SELECT * FROM CustomersTableGuid
GO

-- 6. Create the new Clustered Index on the previous added column
CREATE UNIQUE CLUSTERED INDEX idx_ci ON CustomersTableGuid(PK_INT)
GO

-- 7. Create the primary key as a Non-Clustered Index
ALTER TABLE CustomersTableGuid
ADD CONSTRAINT Constraint_PK
PRIMARY KEY NONCLUSTERED (ID)
GO

-- 8. Enable all FKs and Non-Clustered Indexes
-- ...

-- 9. Bring the database online
ALTER DATABASE CustomersDatabase SET MULTI_USER
GO

-- Check the size of our indexes.
-- CI:  fragmentation: 1,8%
-- NCI: fragmentation: 8,9%
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('CustomersDatabase'), 
	OBJECT_ID('CustomersTableGuid'), 
	NULL, 
	NULL, 
	'DETAILED'
)
GO

-- Let's now insert 10.000 additional records.
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

-- Check the size of our indexes.
-- CI:  fragmentation: 2,8%
-- NCI: fragmentation: 99%
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