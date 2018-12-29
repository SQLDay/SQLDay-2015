/*============================================================================
  Summary:  Demonstrates Non-Clustered Index Structures
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

CREATE DATABASE NonClusteredIndexStructures
GO

USE NonClusteredIndexStructures
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

-- Create a non unique clustered index on the previous created table
CREATE CLUSTERED INDEX idx_Customers ON Customers(CustomerID)
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

-- Retrieve the inserted data
SELECT * FROM Customers
GO

-- Create a non-unique non clustered index on the clustered table
CREATE NONCLUSTERED INDEX idx_CustomerID
ON Customers(CustomerName)
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

-- Retrieve all index pages for the non-unique non-clustered index
DBCC IND(NonClusteredIndexStructures, Customers, 2)
GO

-- Write everything in a table for further analysis
INSERT INTO sp_table_pages EXEC('DBCC IND(NonClusteredIndexStructures, Customers, 2)')
GO

-- Retrieve the index root-page of the non-unique non-clustered index
SELECT * FROM sp_table_pages
WHERE IndexLevel = 2 AND IndexID = 2
GO

DBCC TRACEON(3604)
GO

-- Dump out the root index page of the non-unique non-clustered index
DBCC PAGE(NonClusteredIndexStructures, 1, 6250, 3)
GO

-- Dump out an intermediate level index page of the non-unique non-clustered index
DBCC PAGE(NonClusteredIndexStructures, 1, 6258, 3)
GO

-- Dump out the leaf-level index page of the non-unique non-clustered index
DBCC PAGE(NonClusteredIndexStructures, 1, 7388, 3)
GO

-- Cleanup
USE master
GO

DROP DATABASE NonClusteredIndexStructures
GO