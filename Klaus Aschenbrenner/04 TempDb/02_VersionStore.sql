/*============================================================================
  Summary:  Demonstrates the Version Store
------------------------------------------------------------------------------
  Written by Klaus Aschenbrenner, SQLpassion.at

  (c) 2011, SQLpassion.at. All rights reserved.

  For more scripts and sample code, check out 
    http://www.SQLpassion.at

  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE master
GO

-- Create a new database
CREATE DATABASE VersionStoreDemo
GO

-- Enable RCSI
ALTER DATABASE VersionStoreDemo SET READ_COMMITTED_SNAPSHOT ON
GO

-- Use it
USE VersionStoreDemo
GO

-- Create a new table
CREATE TABLE TestTable
(
	Column1 INT,
	Column2 INT,
	Column3 CHAR(100)
)
GO

-- Insert a record
INSERT INTO TestTable VALUES (1, 1, REPLICATE('A', 100))
GO

-- Look into the version store - currently the Version Store is empty.
-- INSERT statements are not generating versions, only UPDATEs and DELETEs.
SELECT * FROM sys.dm_tran_version_store
WHERE database_id = DB_ID('VersionStoreDemo')
GO

-- Execute an UPDATE statement.
-- This generates now a new version in the Version Store.
UPDATE TestTable
SET Column3 = REPLICATE('B', 100)
WHERE Column1 = 1
GO

-- Query the Version Store again - now it returns one row for our database.
SELECT * FROM sys.dm_tran_version_store
WHERE database_id = DB_ID('VersionStoreDemo')
GO

-- Execute an UPDATE statement.
-- This generates now a new version in the Version Store.
UPDATE TestTable
SET Column3 = REPLICATE('C', 100)
WHERE Column1 = 1
GO

-- Query the Version Store again - now it returns several rows for our database.
SELECT * FROM sys.dm_tran_version_store
WHERE database_id = DB_ID('VersionStoreDemo')
GO

-- Execute an UPDATE statement.
-- This generates now a new version in the Version Store.
UPDATE TestTable
SET Column3 = REPLICATE('D', 100)
WHERE Column1 = 1
GO

-- Query the Version Store again - now it returns several rows for our database.
SELECT * FROM sys.dm_tran_version_store
WHERE database_id = DB_ID('VersionStoreDemo')
GO

-- Clean up
USE master
GO

DROP DATABASE VersionStoreDemo
GO