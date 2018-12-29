/*============================================================================
  Summary:  Demonstrates how to work with Inner Joins
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
-- Demonstrate the basics of Inner Joins
-- =========================================

-- Returns 121317 rows
-- Returns for each SalesOrderHeader record all associated SalesOrderDetail records
-- SQL Server performs a Merge Join, because both tables are phyiscally sorted
-- by the column "SalesOrderID".
SELECT
	h.SalesOrderID,
	h.CustomerID,
	d.SalesOrderDetailID,
	d.ProductID,
	d.LineTotal
FROM Sales.SalesOrderHeader h
JOIN Sales.SalesOrderDetail d
ON h.SalesOrderID = d.SalesOrderID
ORDER BY SalesOrderID
GO

-- The logical ordering of the tables during an Inner Join
-- doesn't matter. It's up to the Query Optimnizer to arrange
-- the tables in the best order.
-- This query produces the same execution plan as the previous one.
SELECT
	h.SalesOrderID,
	h.CustomerID,
	d.SalesOrderDetailID,
	d.ProductID,
	d.LineTotal
FROM Sales.SalesOrderDetail d
JOIN Sales.SalesOrderHeader h
ON d.SalesOrderID = h.SalesOrderID
ORDER BY SalesOrderID
GO

-- Returns all customers that have placed orders.
-- There are some customers without orders.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader h
ON c.CustomerID = h.CustomerID
GO

-- *Never* ever use the old join syntax (ANSI SQL-89), because
-- it can lead to unwanted Cross Joins, if you forget the Join Predicate.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c, Sales.SalesOrderHeader h
GO

-- And now with a Join Predicate
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c, Sales.SalesOrderHeader h
WHERE c.CustomerID = h.CustomerID -- <<< The missing Join Predicate!
GO

-- ======================================================
-- Demonstrate how the Inner Join deals with NULL values
-- ======================================================

-- We have only 13976 rows with a Non-NULL value in the column "CurrencyRateID"
-- COUNT(*) also counts NULL values.
SELECT COUNT(CurrencyRateID), COUNT(*) FROM Sales.SalesOrderheader
GO

-- When we perform an Inner Join where the Join Predicate column has NULL values,
-- the rows with the NULL values are not returned.
-- If you want to preserve these rows, you need an Outer Join.
-- This query returns only the 13976 Non-NULL rows.
SELECT
	h.CurrencyRateID
FROM Sales.SalesOrderHeader h
JOIN Sales.CurrencyRate c
ON h.CurrencyRateID = c.CurrencyRateID
GO

-- ===========================
-- Demonstrate Non-Equi Joins
-- ===========================

-- Create a helper table
CREATE TABLE #t1
(
	Col1 INT
)
GO

-- Create another helper table
CREATE TABLE #t2
(
	Col1 INT
)
GO

-- Insert some test data
INSERT INTO #t1 VALUES (1), (2), (3)
INSERT INTO #t2 VALUES (1), (2), (3)
GO

-- Execute a Cross Join between the 2 tables
SELECT
	#t1.Col1,
	#t2.Col1
FROM #t1
CROSS JOIN #t2
GO

-- Now let's execute an Non-Equi Join between the 2 tables.
-- This query produces unique pairs of records.
-- => Mirrored pairs are removed (e.g. "1, 2" & "2, 1")
-- => Self pairs are removed (e.g. "1, 1")
SELECT
	#t1.Col1,
	#t2.Col1
FROM #t1
JOIN #t2
ON #t1.Col1 < #t2.Col1
ORDER BY #t1.Col1
GO

-- A Non-Equi Join can only use a Nested Loop operator.
-- For the following query the Query Optimizer can't produce an execution plan.
SELECT
	#t1.Col1,
	#t2.Col1
FROM #t1
INNER MERGE JOIN #t2 -- <<< Let's enforce a Merge Join
ON #t1.Col1 < #t2.Col1
ORDER BY #t1.Col1
GO

-- Cleanup
DROP TABLE #t1
DROP TABLE #t2
GO

-- The last joins were Equi-Joins, because the join condition involved an equality operator.
-- Let's execute an Non-Equi-Join.
-- A cross join will return self pairs (EUR/EUR) and mirrored pairs (EUR/USD, USD/EUR)
SELECT
	c1.CurrencyCode,
	c2.CurrencyCode
FROM Sales.Currency c1
CROSS JOIN Sales.Currency c2
GO

-- Self pairs are returned by the Cross Join
SELECT
	c1.CurrencyCode,
	c2.CurrencyCode
FROM Sales.Currency c1
CROSS JOIN Sales.Currency c2
WHERE c1.CurrencyCode = 'EUR' AND c2.CurrencyCode = 'EUR'
GO

-- Mirrored pairs are returned by the Cross Join
SELECT
	c1.CurrencyCode,
	c2.CurrencyCode
FROM Sales.Currency c1
CROSS JOIN Sales.Currency c2
WHERE (c1.CurrencyCode = 'EUR' AND c2.CurrencyCode = 'USD') OR (c1.CurrencyCode = 'USD' AND c2.CurrencyCode = 'EUR')
GO

-- Let's rewrite the query using an Non-Equi Join
SELECT
	c1.CurrencyCode,
	c2.CurrencyCode
FROM Sales.Currency c1
JOIN Sales.Currency c2
ON c1.CurrencyCode < c2.CurrencyCode
GO

-- Self pairs are removed by the Non-Equi Join.
SELECT
	c1.CurrencyCode,
	c2.CurrencyCode
FROM Sales.Currency c1
JOIN Sales.Currency c2
ON c1.CurrencyCode < c2.CurrencyCode
WHERE c1.CurrencyCode = 'EUR' AND c2.CurrencyCode = 'EUR'
GO

-- Mirrored pairs are removed by the Non-Equi Join.
-- Only one pair is returned instead of 2 pairs.
SELECT
	c1.CurrencyCode,
	c2.CurrencyCode
FROM Sales.Currency c1
JOIN Sales.Currency c2
ON c1.CurrencyCode < c2.CurrencyCode
WHERE (c1.CurrencyCode = 'EUR' AND c2.CurrencyCode = 'USD') OR (c1.CurrencyCode = 'USD' AND c2.CurrencyCode = 'EUR')
GO