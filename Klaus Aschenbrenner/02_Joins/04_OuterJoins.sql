/*============================================================================
  Summary:  Demonstrates how to work with Outer Joins
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

-- =======================
-- Demonstrate Outer Joins
-- =======================

-- Returns all customers that have placed orders.
-- There are some customers without orders.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader h
ON c.CustomerID = h.CustomerID
GO

-- Execute the query with an Outer Join.
-- Now we are also getting back customers that haven't placed orders.
-- The left table is the preserving one, and missing rows from the right table are added with NULL values.
-- SQL Server performs a "Merge Join (Left Outer Join)" in the execution plan.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c
LEFT JOIN Sales.SalesOrderHeader h
ON c.CustomerID = h.CustomerID
GO

-- If you change the order of the tables in the query, it leads to a different result.
-- The ordering of the tables is the same in the execution plan (Customer, SalesOrderHeader),
-- but this time SQL Server performs a "Merge Join (Right Outer Join)" in the execution plan.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.SalesOrderHeader h
LEFT JOIN Sales.Customer c
ON c.CustomerID = h.CustomerID
GO

-- You can rewrite the query from above with a Right Outer Join when you swap the order
-- of the tables. This time you get back the same result (32166 rows).
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.SalesOrderHeader h
RIGHT JOIN Sales.Customer c
ON c.CustomerID = h.CustomerID
GO

-- Performs a Full Outer Join between both tables.
-- Both tables are preserved, and missing rows are substituted by NULL values.
-- The execution plan shows you a "Merge Join (Full Outer Join)" operator.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.SalesOrderHeader h
FULL JOIN Sales.Customer c
ON c.CustomerID = h.CustomerID
GO

-- Demonstrates a Left Excluding Join.
-- The following query returns all customers that haven't placed orders.
-- The WHERE predicate is evaluated through an explicit Filter operator in the execution plan.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c
LEFT JOIN Sales.SalesOrderHeader h
ON c.CustomerID = h.CustomerID
WHERE h.CustomerID IS NULL
GO

-- Demonstrates a Right Excluding Join.
-- The query produces the same execution plan as the previous one.
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.SalesOrderHeader h
RIGHT JOIN Sales.Customer c
ON c.CustomerID = h.CustomerID
WHERE h.CustomerID IS NULL
GO

-- Demonstrates an Outer Excluding Join
SELECT
	c.CustomerID,
	h.SalesOrderID
FROM Sales.Customer c
FULL OUTER JOIN Sales.SalesOrderHeader h
ON c.CustomerID = h.CustomerID
WHERE c.CustomerID IS NULL OR h.CustomerID IS NULL
GO

-- =================================================================
-- Demonstrate Outer Joins to find days were no orders where placed
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

-- Create a helper table
CREATE TABLE #NumbersTemp
(
	Num INT PRIMARY KEY
)
GO

-- Insert 10000 rows into the helper table
INSERT INTO #NumbersTemp
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

-- Retrieve the inserted records
SELECT * FROM #NumbersTemp
GO

-- The following SELECT statement produces all days in a given date interval
SELECT
	DATEADD(DAY, Num - 1, '20050101') AS 'OrderDate',
	Num
FROM #NumbersTemp
WHERE Num <= DATEDIFF(DAY, '20050101', '20051231') + 1
GO

-- Use that SELECT statement to make an outer join to the sales table
SELECT
	DATEADD(DAY, Num - 1, '20050101') AS 'OrderDate',
	h.SalesOrderID
FROM #NumbersTemp n
LEFT JOIN Sales.SalesOrderHeader h
ON DATEADD(DAY, Num - 1, '20050101') = h.OrderDate
WHERE Num <= DATEDIFF(DAY, '20050101', '20051231') + 1
AND h.OrderDate IS NULL -- <<< Restrict only on these days where are no sales records
ORDER BY OrderDate
GO

-- Calculates how many days the gap to the next order is
SELECT t1.* FROM
(
	SELECT
		t.*,
		LEAD(OrderDate) OVER(ORDER BY OrderDate) AS 'NextOrderDate',
		DATEDIFF(DAY, OrderDate, LEAD(OrderDate) OVER(ORDER BY OrderDate)) - 1 AS 'Difference'
	FROM
	(
		SELECT
			DATEADD(DAY, Num - 1, '20050101') AS 'OrderDate',
			h.SalesOrderID
		FROM #NumbersTemp n
		LEFT JOIN Sales.SalesOrderHeader h
		ON DATEADD(DAY, Num - 1, '20050101') = h.OrderDate
		WHERE Num <= DATEDIFF(DAY, '20050101', '20051231') + 1
		AND h.OrderDate IS NULL -- <<< Restrict only on these days where are no sales records
	) AS t
) AS t1
WHERE t1.Difference > 0
GO

-- Cleanup
DROP TABLE #NumbersTemp
DROP TABLE Numbers
GO

-- =====================================================================
-- Demonstrate how to use Outer Joins to find the minimum missing value
-- =====================================================================

-- Create a simple test table
CREATE TABLE TestData
(
	Col1 INT NOT NULL PRIMARY KEY CLUSTERED,
	Col2 CHAR(100),
	Col3 CHAR(100)
)
GO

-- Insert some test data.
-- The value "6" is the minimum missing value.
INSERT INTO TestData VALUES (1, 'a', 'a'), (2, 'b', 'b'), (3, 'c', 'c'), (4, 'd', 'd'),
(5, 'e', 'e'), (9, 'f', 'f')
GO

-- Retrieve the minimum missing value through the use of an Outer Join.
-- We get back 2 NULL extended rows:
-- => For the minimum missing value
-- => For the last row
SELECT
	t1.*,
	t2.*
FROM TestData t1
LEFT JOIN TestData t2 ON t2.Col1 = t1.Col1 + 1 -- <<< Perform an Outer Join to the next record
GO

-- Therefore we have to use the MIN aggregate and restrict only on NULL extended rows
SELECT
	MIN(t1.Col1) + 1 -- Just add 1 to get the next minimum missing value
FROM TestData t1
LEFT JOIN TestData t2 ON t2.Col1 = t1.Col1 + 1
WHERE t2.Col1 IS NULL -- <<< Restrict on the 1st occurance where the Outer Join doesn't find a matching record
GO

-- Calculates the size of the largest gap with the ROW_NUMBER() function
SELECT t.Grp AS 'MaxGap' FROM
(
	SELECT
		*,
		ROW_NUMBER() OVER (ORDER BY Col1) AS 'RowNumber',
		Col1 - ROW_NUMBER() OVER (ORDER BY Col1) AS 'Grp'
	FROM TestData t1
) AS t
WHERE t.Grp > 0
GROUP BY t.Grp
GO

-- Calculates the size of the largest gap with the LEAD() windowing function
SELECT t.Diff FROM
(
	SELECT
		*, 
		LEAD(Col1) OVER (ORDER BY Col1) - Col1 - 1 AS 'Diff'
	FROM TestData
) AS t
WHERE t.Diff IS NOT NULL AND t.Diff > 0
GROUP BY t.Diff
GO

-- Clean up
DROP TABLE TestData
GO