--Row goal basic logic
--(SQL Server 2012 or 2014)
USE AdventureWorks
GO



--A query!
SELECT
	*
FROM Production.TransactionHistory
GO




--Is this (technically) the same query?
SELECT TOP(9223372036854775807)
	*
FROM Production.TransactionHistory
GO




--Easier to memorize?
SELECT TOP(CAST(0x7FFFFFFFFFFFFFFF AS BIGINT))
	*
FROM Production.TransactionHistory
GO




--This is probably fine for 99.999% of cases...
SELECT TOP(2147483647)
	*
FROM Production.TransactionHistory
GO




--This one? Not so much.
SELECT TOP 100 PERCENT
	*
FROM Production.TransactionHistory
GO




--The row goal forms a query optimization "wall"

--Logical equivalence may not mean physical equivalence!
SELECT TOP(2147483647)
	*
FROM Production.TransactionHistory
WHERE
	ProductId = 123
GO


SELECT
	*
FROM
(
	SELECT TOP(2147483647)
		*
	FROM Production.TransactionHistory
) AS x
WHERE
	ProductId = 123
GO




--Surprising "solution" to the TOP(1) problem...
--(Run on SQL 2012)
SELECT TOP(1)
	*
FROM
(
	SELECT TOP(2147483647)
		*
	FROM dbo.getProductSales(4, '20050101', '20060630')
) AS x
GO





--Example:
--Get all of the products we sold for less than their list prices...
SELECT
	th.TransactionID,
	p.Name,
	plp.ListPrice,
	th.ActualCost
FROM Production.Product AS p
INNER JOIN Production.ProductListPriceHistory AS plp ON
	plp.ProductID = p.ProductID
INNER JOIN Production.TransactionHistory AS th ON
	th.ProductID = plp.ProductID
	AND th.ActualCost < plp.ListPrice
	AND th.TransactionDate BETWEEN plp.StartDate AND ISNULL(plp.EndDate, '99991231')
GO




--Here's another way to write the same query, and the optimizer does its job
SELECT
	th.TransactionID,
	p.Name,
	plp.ListPrice,
	th.ActualCost
FROM Production.TransactionHistory AS th
INNER JOIN Production.Product AS p ON
	p.ProductID = th.ProductID
INNER JOIN Production.ProductListPriceHistory AS plp ON
	plp.ProductID = p.ProductID
	AND th.ActualCost < plp.ListPrice
	AND th.TransactionDate BETWEEN plp.StartDate AND ISNULL(plp.EndDate, '99991231')
GO




--What if I really want a direct join between Product and TransactionHistory?
SELECT
	x.TransactionID,
	x.Name,
	plp.ListPrice,
	x.ActualCost
FROM 
(
	SELECT 
		th.TransactionID,
		th.ActualCost,
		th.TransactionDate,
		p.Name,
		p.ProductID
	FROM Production.TransactionHistory AS th
	INNER JOIN Production.Product AS p ON
		p.ProductID = th.ProductID
) AS x
INNER JOIN Production.ProductListPriceHistory AS plp ON
	plp.ProductID = x.ProductID
	AND x.ActualCost < plp.ListPrice
	AND x.TransactionDate BETWEEN plp.StartDate AND ISNULL(plp.EndDate, '99991231')
GO




--A join hint sorta-kinda works, but...
SELECT
	th.TransactionID,
	p.Name,
	plp.ListPrice,
	th.ActualCost
FROM Production.TransactionHistory AS th
INNER HASH JOIN Production.Product AS p ON
	p.ProductID = th.ProductID
INNER JOIN Production.ProductListPriceHistory AS plp ON
	plp.ProductID = p.ProductID
	AND th.ActualCost < plp.ListPrice
	AND th.TransactionDate BETWEEN plp.StartDate AND ISNULL(plp.EndDate, '99991231')
GO




--What I really want...
--NO ORDER FORCING!
SELECT
	x.TransactionID,
	x.Name,
	plp.ListPrice,
	x.ActualCost
FROM 
(
	SELECT TOP(2147483647)
		th.TransactionID,
		th.ActualCost,
		th.TransactionDate,
		p.Name,
		p.ProductID
	FROM Production.TransactionHistory AS th
	INNER JOIN Production.Product AS p ON
		p.ProductID = th.ProductID
) AS x
INNER JOIN Production.ProductListPriceHistory AS plp ON
	plp.ProductID = x.ProductID
	AND x.ActualCost < plp.ListPrice
	AND x.TransactionDate BETWEEN plp.StartDate AND ISNULL(plp.EndDate, '99991231')
GO




--I wonder... is a merge join a good option?
SELECT
	x.TransactionID,
	x.Name,
	plp.ListPrice,
	x.ActualCost
FROM 
(
	SELECT TOP(2147483647)
		th.TransactionID,
		th.ActualCost,
		th.TransactionDate,
		p.Name,
		p.ProductID
	FROM Production.TransactionHistory AS th
	INNER JOIN Production.Product AS p ON
		p.ProductID = th.ProductID
	ORDER BY
		p.ProductID
) AS x
INNER JOIN Production.ProductListPriceHistory AS plp ON
	plp.ProductID = x.ProductID
	AND x.ActualCost < plp.ListPrice
	AND x.TransactionDate BETWEEN plp.StartDate AND ISNULL(plp.EndDate, '99991231')
GO




