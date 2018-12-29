/*============================================================================
  Summary:  Demonstrates Joins in SQL Server.
------------------------------------------------------------------------------
  Written by Klaus Aschenbrenner, www.SQLpassion.at

  For more scripts and sample code, check out 
    http://www.SQLpassion.at

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

USE AdventureWorks2012
GO

SET STATISTICS IO ON
SET STATISTICS TIME ON
GO

-- ===============================
-- Demonstrates Nested Loop Joins
-- ===============================

-- Demonstrates the Nested Loop operator when joining 2 tables
SELECT
	soh.*,
	d.*
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.SalesOrderDetail d ON soh.SalesOrderID = d.SalesOrderID
WHERE soh.SalesOrderID = 71832
GO

-- Demonstrate the Nested Loop operator when performing a Bookmark Lookup
SELECT
	EmailAddressID,
	EmailAddress,
	ModifiedDate
FROM Person.EmailAddress
WHERE EmailAddress LIKE 'sab%'
GO

-- When you perform a join against a Table Variable, the
-- Table Variable is always chosen as the outer table
DECLARE @tempTable TABLE
(
	ID INT IDENTITY(1, 1) PRIMARY KEY,
	FirstName CHAR(4000),
	LastName CHAR(4000)
)
	
INSERT INTO @TempTable (FirstName, LastName)
SELECT TOP 20000 name, name FROM master.dbo.syscolumns
	
-- The physical Join Operator will be a Nested Loop
-- because Nested Loop is optimized for 1 row in the outer loop.
SELECT * FROM Person.Person p
INNER JOIN @tempTable t ON t.ID = p.BusinessEntityID
GO

-- We can fix that behavior by using the query hint
-- OPTION (RECOMPILE).
-- Therefore the Query Optimizer knows how many records
-- are stored in the Table Variable and can choose
-- the correct physical join operator - Merge Join - in our case
DECLARE @tempTable TABLE
(
	ID INT IDENTITY(1, 1) PRIMARY KEY,
	FirstName CHAR(4000),
	LastName CHAR(4000)
)
	
INSERT INTO @TempTable (FirstName, LastName)
SELECT TOP 20000 name, name FROM master.dbo.syscolumns
	
-- The physical Join Operator will be a Nested Loop,
-- because Nested Loop is optimized for 1 row in the outer loop.
SELECT * FROM Person.Person p
INNER JOIN @tempTable t ON t.ID = p.BusinessEntityID
OPTION (RECOMPILE)
GO

-- =========================
-- Demonstrates Merge Joins
-- =========================

CREATE TABLE Table1
(
	Column1 INT IDENTITY (1, 1) PRIMARY KEY,
	Column2 INT
)
GO

-- Insert 1500 records into Table1
SELECT TOP 1500 IDENTITY(INT, 1, 1) AS n INTO #Nums
FROM
master.dbo.syscolumns sc1

INSERT INTO Table1 (Column2)
SELECT n FROM #nums
DROP TABLE #nums
GO

-- Create another test table
CREATE TABLE Table2
(
	Column1 INT IDENTITY (1, 1) PRIMARY KEY,
	Column2 INT
)
GO

-- Insert 1500 records into Table2
SELECT TOP 1500 IDENTITY(INT, 1, 1) AS n INTO #Nums
FROM
master.dbo.syscolumns sc1

INSERT INTO Table2 (Column2)
SELECT n FROM #nums
DROP TABLE #nums
GO

-- Retrieve the inserted data from both tables.
-- In the 2nd column we have unique values, but the query optimizer doesn't know
-- that fact (no check constraint, no unique index defined)
SELECT * FROM Table1
SELECT * FROM Table2
GO

-- Let's perform a join between both tables:
-- We have to hint SQL Server, so that we get a Merge Join operator in the execution plan.
-- The Query Optimizer introduces an explicit Sort operator to be able to perform the Merge Join.
-- In addition the Merge Join is "Many to Many", because the Query Optimizer has no idea about
-- the unique values in both columns "Column2".
-- The "Many to Many" operation of the Merge Join creates a Worktable in TempDb.
-- Table1 is the outer table, Table2 is the inner table
SELECT a.*, b.* FROM Table1 a
INNER JOIN Table2 b ON a.column2 = b.Column2
OPTION (MERGE JOIN)
GO

-- Now let's create a unique Non-Clustered Index on Column2 of Table2.
CREATE UNIQUE NONCLUSTERED INDEX idx_Col2 ON Table2(Column2)
GO

-- When we now rerun our query, we get a Merge Join operator by default.
-- Because the Query Optimizer now knows that we have unique values in the 2nd table,
-- Table2 is the outer table, and the Merge Join isn't executed as a "Many to Many" operation anymore.
-- The explicit Sort operator on Table2 is also eliminated, because we get a sorted input directly
-- from the accessed Non-Clustered Index.
-- Therefore the query doesn't create a Worktable in TempDb.
SELECT a.*, b.* FROM Table1 a
INNER JOIN Table2 b ON a.column2 = b.Column2
GO

-- When we create another unique Non-Clustered Index on Table1, 
-- we can also eliminate the explicit Sort operator for that table in the execution plan.
CREATE UNIQUE NONCLUSTERED INDEX idx_Col2 ON Table1(Column2)
GO

-- Rerun the query
SELECT a.*, b.* FROM Table1 a
INNER JOIN Table2 b ON a.Column2 = b.Column2
GO

-- Clean up
DROP TABLE Table1
DROP TABLE Table2
GO

-- ========================
-- Demonstrates Hash Joins
-- ========================

-- Demonstrates a simple Hash Join
SELECT
	p1.FirstName,
	p1.LastName,
	p2.PhoneNumber
FROM Person.Person p1
INNER JOIN Person.PersonPhone p2
ON p1.BusinessEntityID = p2.BusinessEntityID
GO

-- Create a test table
CREATE TABLE Table1
(
	Column1 INT IDENTITY PRIMARY KEY,
	Column2 INT,
	Column3 CHAR(2000)
)
GO

-- Create a Non-Clustered Index on column Column2
CREATE NONCLUSTERED INDEX idxTable1_Column2 ON Table1(Column2)
GO

-- Insert 1500 records into Table1
SELECT TOP 1500 IDENTITY(INT, 1, 1) AS n INTO #Nums
FROM
master.dbo.syscolumns sc1

INSERT INTO Table1 (Column2, Column3)
SELECT n, REPlICATE('x', 2000) FROM #nums
DROP TABLE #nums
GO

-- Retrieve the inserted records
SELECT * FROM Table1
GO

-- Create a test table
CREATE TABLE Table2
(
	Column1 INT IDENTITY PRIMARY KEY,
	Column2 INT,
	Column3 CHAR(2000)
)
GO

-- Create a Non-Clustered Index on column Column2
CREATE NONCLUSTERED INDEX idxTable2_Column2 ON Table2(Column2)
GO

-- Insert 1500 records into Table1
SELECT TOP 1500 IDENTITY(INT, 1, 1) AS n INTO #Nums
FROM
master.dbo.syscolumns sc1

INSERT INTO Table2 (Column2, Column3)
SELECT n, REPlICATE('x', 2000) FROM #nums
DROP TABLE #nums
GO

-- Retrieve the inserted records
SELECT * FROM Table2
GO

-- Execute our "problematic" SQL statement in the 1st step.
-- Therefore SQL Server is able to produce and cache a suboptimal
-- Execution Plan, which will be reused afterwards.
SELECT * FROM Table1 t1
INNER HASH JOIN Table2 t2 ON t2.Column2 = t1.Column2
WHERE t1.Column2 = 2
GO

-- Insert 799 additional rows into the 1st table.
-- In that case SQL Server WILL NOT update the statistics,
-- because we have not hit the threshold of 800 data changes (20% + 500 rows).
SELECT TOP 799 IDENTITY(INT, 1, 1) AS n INTO #Nums
FROM
master.dbo.syscolumns sc1

INSERT INTO Table1 (Column2, Column3)
SELECT 2, REPLICATE('x', 2000) FROM #nums
DROP TABLE #nums
GO

-- Insert 799 additional rows into the 1st table.
-- In that case SQL Server WILL NOT update the statistics,
-- because we have not hit the threshold of 800 data changes (20% + 500 rows).
SELECT TOP 799 IDENTITY(INT, 1, 1) AS n INTO #Nums
FROM
master.dbo.syscolumns sc1

INSERT INTO Table2 (Column2, Column3)
SELECT 2, REPLICATE('x', 2000) FROM #nums
DROP TABLE #nums
GO

-- This query will produce a Hash Spill because of inaccurate statistics.
-- SQL Server estimates 1 row for the Hash Join, and requests a memory grant of 1 MB.
-- The query runs for around 1 minute.
SELECT * FROM Table1 t1
INNER HASH JOIN Table2 t2 ON t2.Column2 = t1.Column2
WHERE t1.Column2 = 2
GO

-- Update the statistics on both tables.
-- Therefore SQL Server is able to estimate the memory grant correctly.
UPDATE STATISTICS Table1 WITH FULLSCAN
UPDATE STATISTICS Table2 WITH FULLSCAN
GO

-- The Hash Join is now running in memory.
-- SQL Server estimates now 800 rows, and requests a memory grant of 8.5 MB.
-- The query runs for around 30 seconds.
SELECT * FROM Table1 t1
INNER HASH JOIN Table2 t2 ON t2.Column2 = t1.Column2
WHERE t1.Column2 = 2
GO

-- Clean up
DROP TABLE Table1
DROP TABLE Table2
GO