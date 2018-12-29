/*============================================================================
  Summary:  Demonstrates how to work with Cross Joins
------------------------------------------------------------------------------
  Written by Klaus Aschenbrenner, www.SQLpassion.at

  For more scripts and sample code, check out 
    http://www.SQLpassion.at

  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

SET STATISTICS IO ON
SET STATISTICS TIME ON
GO

USE AdventureWorks2012
GO

-- =========================================
-- Demonstrate the basics of Cross Joins
-- =========================================

-- 105 records
SELECT COUNT(*) FROM Sales.Currency
GO

-- 104 records
SELECT COUNT(*) FROM Purchasing.Vendor
GO

-- Returns 10.920 (105 x 104) records.
-- The execution plan shows you a Nested Loop operator without a Join Predicate.
SELECT
	c.*,
	v.*
FROM Sales.Currency c -- 105 records
CROSS JOIN Purchasing.Vendor v -- 104 records
GO

-- Self-joining tables.
-- Generates currency pairs (with mirror and self pairs).
SELECT
	c1.CurrencyCode + ' - ' + c2.CurrencyCode
FROM Sales.Currency c1
CROSS JOIN Sales.Currency c2
GO

-- =================================================================
-- Demonstrate how to produce a sequence of numbers with Cross Joins
-- =================================================================

-- Create a helper table
CREATE TABLE Numbers
(
	Num INT NOT NULL PRIMARY KEY
)
GO

-- Insert all digits
INSERT INTO Numbers VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)
GO

-- Retrieve the inserted data
SELECT * FROM Numbers
GO

-- Retrieve a set with 10000 numbers.
-- The query has a linear complexity: O(N)
-- The more numbers we request the longer it takes.
-- Logical Reads: 2225
SELECT
	n4.Num * 1000 + 
	n3.Num * 100 + 
	n2.Num * 10 + 
	n1.Num + 1 AS 'Number'
FROM Numbers n1
CROSS JOIN Numbers n2
CROSS JOIN Numbers n3
CROSS JOIN Numbers n4
ORDER BY Number
GO

-- Retrieve a set with 100000 numbers.
-- The query has a linear complexity: O(N)
-- The more numbers we request the longer it takes.
-- Logical Reads: 22230
SELECT
	n5.Num * 10000 +
	n4.Num * 1000 + 
	n3.Num * 100 + 
	n2.Num * 10 + 
	n1.Num + 1 AS 'Number'
FROM Numbers n1
CROSS JOIN Numbers n2
CROSS JOIN Numbers n3
CROSS JOIN Numbers n4
CROSS JOIN Numbers n5
ORDER BY Number
GO

-- Retrieve a set with 1000000 numbers.
-- The query has a linear complexity: O(N)
-- The more numbers we request the longer it takes.
-- Logical Reads: 222232
SELECT
	n6.Num * 100000 + 
	n5.Num * 10000 +
	n4.Num * 1000 + 
	n3.Num * 100 + 
	n2.Num * 10 + 
	n1.Num + 1 AS 'Number'
FROM Numbers n1
CROSS JOIN Numbers n2
CROSS JOIN Numbers n3
CROSS JOIN Numbers n4
CROSS JOIN Numbers n5
CROSS JOIN Numbers n6
ORDER BY Number
GO

-- Clean up
DROP TABLE Numbers
GO

-- ===============================================================
-- Demonstrate how to calculate the percentage of the total value
-- ===============================================================

-- The percentage value and the difference to the average value is calculated through a sub query.
-- This technique doesn't really scale, because for every sub query we need a scan of the Clustered Index.

-- Logical reads: 2764
-- Scan count table "SalesOrderDetail": 2
SELECT
	SalesOrderID,
	ProductID,
	LineTotal,
	CAST(LineTotal / (SELECT SUM(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'PercentageValue'
FROM Sales.SalesOrderDetail
GO

-- Logical reads: 4146
-- Scan count table "SalesOrderDetail": 3
SELECT
	SalesOrderID,
	ProductID,
	LineTotal,
	CAST(LineTotal / (SELECT SUM(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'PercentageValue',
	CAST(LineTotal - (SELECT AVG(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'Difference'
FROM Sales.SalesOrderDetail
GO

-- The execution plan has also some parallel regions.
-- Logical reads: 5966
-- Scan count table "SalesOrderDetail": 4
SELECT
	SalesOrderID,
	ProductID,
	LineTotal,
	CAST(LineTotal / (SELECT SUM(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'PercentageValue',
	CAST(LineTotal - (SELECT AVG(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'Difference',
	CAST(LineTotal - (SELECT MIN(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'Calculation' -- Some additional "silly" calcuation ;-)
FROM Sales.SalesOrderDetail
GO

-- The scan of the complete Clustered Index for each sub query 
-- can be eliminated by providing a supporting Non-Clustered Index.
-- The columns "OrderQty", "UnitPrice", "UnitPriceDiscount" are
-- returned from the Clustered Index Scan.
-- They are part of the computed column "LineTotal".
CREATE NONCLUSTERED INDEX idx_Test ON Sales.SalesOrderDetail(OrderQty, UnitPrice, UnitPriceDiscount)
GO

-- The Query Optimizer has now also chosen a single threaded execution plan.
-- Logical reads: 2840
-- Scan count table "SalesOrderDetail": 4
SELECT
	SalesOrderID,
	ProductID,
	LineTotal,
	CAST(LineTotal / (SELECT SUM(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'PercentageValue',
	CAST(LineTotal - (SELECT AVG(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'Difference',
	CAST(LineTotal - (SELECT MIN(LineTotal) FROM Sales.SalesOrderDetail ) * 100. AS NUMERIC(12, 7)) AS 'Calculation' -- Some additional "silly" calcuation ;-)
FROM Sales.SalesOrderDetail
GO

-- The solution with the sub query doesn't really scale, because it has a linear complexity: O(N).
-- The more sub queries we have, the more page reads we need, and the longer the execution time of the query is.

-- The idea is to use a CTE to precalculate the aggreations, and cross join
-- it with the main query. In that case we need only 1 scan for all aggregations.

-- Logical Reads: 1868
-- Scan count table "SalesOrderDetail": 2
WITH Aggregations AS
(
	SELECT
		SUM(LineTotal) AS 'SumLineTotal',
		AVG(LineTotal) AS 'AvgLineTotal',
		MIN(LineTotal) AS 'MinLineTotal'
	FROM Sales.SalesOrderDetail
)
SELECT
	SalesOrderID,
	ProductID,
	LineTotal,
	CAST(LineTotal / SumLineTotal * 100. AS NUMERIC(12, 7)) AS 'PercentageValue',
	CAST(LineTotal - AvgLineTotal * 100. AS NUMERIC(12, 7)) AS 'Difference',
	CAST(LineTotal - MinLineTotal * 100. AS NUMERIC(12, 7)) AS 'Calculation'
FROM Sales.SalesOrderDetail
CROSS JOIN Aggregations
GO

-- Clean up 
DROP INDEX idx_Test ON Sales.SalesOrderDetail
GO