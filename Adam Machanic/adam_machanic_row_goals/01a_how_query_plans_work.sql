--How do query plans actually work?
--(SQL Server 2012 or 2014)
USE AdventureWorks
GO



--Index scan -- reads the whole table?
SELECT 
	*
FROM Production.Product
GO




--What really controls a scan?
SELECT TOP(100)
	*
FROM Production.Product
GO




--Row goals can show up anywhere...
SELECT TOP(100)
	p.ProductModelID,
	th.Quantity
FROM 
(
	SELECT TOP(50)
		*
	FROM Production.Product
) AS p
INNER JOIN
(
	SELECT TOP(250)
		*
	FROM Production.TransactionHistory
) AS th ON
	th.ProductID = p.ProductID
GO




--...and not always in Top iterators
SELECT TOP(100)
	p.ProductModelID,
	th.Quantity
FROM 
(
	SELECT TOP(50)
		*
	FROM Production.Product
	ORDER BY
		DaysToManufacture
) AS p
INNER JOIN
(
	SELECT TOP(250)
		*
	FROM Production.TransactionHistory
) AS th ON
	th.ProductID = p.ProductID
GO



