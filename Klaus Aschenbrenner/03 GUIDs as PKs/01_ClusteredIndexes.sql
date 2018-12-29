/*============================================================================
  Summary:  Demonstrates Clustered Index Structures
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

CREATE DATABASE ClusteredIndexStructures
GO

USE ClusteredIndexStructures
GO

-- Create a table with 393 length + 7 bytes overhead = 400 bytes
CREATE TABLE Customers
(
	CustomerID UNIQUEIDENTIFIER NOT NULL,
	CustomerName CHAR(100) NOT NULL,
	CustomerAddress CHAR(100) NOT NULL,
	Comments CHAR(177) NOT NULL
)
GO

-- Create a non unique clustered index
CREATE UNIQUE CLUSTERED INDEX idx_Customers_CustomerID
ON Customers(CustomerID)
GO

-- Insert 80.000 records
DECLARE @i INT = 1
WHILE (@i <= 80000)
BEGIN
	INSERT INTO Customers VALUES
	(
		NEWID(),
		'CustomerName' + CAST(@i AS CHAR),
		'CustomerAddress' + CAST(@i AS CHAR),
		'Comments' + CAST(@i AS CHAR)
	)
	
	SET @i += 1
END
GO

-- Retrieve the inserted records
SELECT * FROM Customers
GO

-- Retrieve physical information about the clustered index
SELECT * FROM sys.dm_db_index_physical_stats
(
	DB_ID('ClusteredIndexStructures'),
	OBJECT_ID('Customers'),
	NULL,
	NULL,
	'DETAILED'
)
GO

-- Create a helper table
CREATE TABLE sp_table_pages
(
  PageFID TINYINT, 
  PagePID INT,   
  IAMFID TINYINT, 
  IAMPID INT, 
  ObjectID INT,
  IndexID TINYINT,
  PartitionNumber TINYINT,
  PartitionID BIGINT,
  iam_chain_type VARCHAR(30),    
  PageType TINYINT, 
  IndexLevel TINYINT,
  NextPageFID TINYINT,
  NextPagePID INT,
  PrevPageFID INT,
  PrevPagePID int, 
  PRIMARY KEY (PageFID, PagePID)
)
GO

-- Retrieve all pages for the clustered index
DBCC IND(ClusteredIndexStructures, Customers, 1)
GO

-- Write everything in a table for further analysis
INSERT INTO sp_table_pages EXEC('DBCC IND(ClusteredIndexStructures, Customers, 1)')
GO

-- Retrieve all index page
SELECT * FROM sp_table_pages
WHERE PageType = 2
ORDER BY IndexLevel DESC
GO

-- Retrieve all data page
SELECT * FROM sp_table_pages
WHERE PageType = 1
GO

-- Retrieve the root index page
SELECT * FROM sp_table_pages
WHERE IndexLevel = 2
GO

-- Retrieve the index pages from the intermediate level
SELECT * FROM sp_table_pages
WHERE IndexLevel = 1
GO

DBCC TRACEON (3604)
GO

-- Dump out the root index page
DBCC PAGE(ClusteredIndexStructures, 1, 628, 3)
GO

-- Dump out an intermediate index level page
DBCC PAGE(ClusteredIndexStructures, 1, 4699, 3)
GO

-- Dump out the leaf level data page of the clustered index.
DBCC PAGE(ClusteredIndexStructures, 1, 4531, 1)
GO

-- Cleanup
USE master
GO

DROP DATABASE ClusteredIndexStructures
GO