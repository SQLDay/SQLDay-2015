--Parallel Filter Weirdness
--(SQL Server 2012 or 2014)
USE AdventureWorks
GO


--Try with and without MAXDOP 1
SELECT
	p.ProductID,
	p.Name,
	x.total
FROM dbo.bigProduct AS p
CROSS APPLY
(
	SELECT
		SUM(UnitPrice) AS total
	FROM
	(
		SELECT
			sd.UnitPrice
		FROM Sales.SalesOrderDetail AS sd
		WHERE
			sd.ProductID = p.ProductID

		UNION ALL

		SELECT
			th.ActualCost
		FROM Production.TransactionHistory AS th
		WHERE
			th.ProductID = p.ProductID
			AND CONVERT(DATE, p.SellEndDate) <= '2002-12-31'
			AND p.MakeFlag = 0
	) AS y
) AS x
OPTION (MAXDOP 1)
GO



--Control the filter with TOP(1)!
SELECT
	p.ProductID,
	p.Name,
	x.total
FROM dbo.bigProduct AS p
CROSS APPLY
(
	SELECT
		SUM(UnitPrice) AS total
	FROM
	(
		SELECT
			sd.UnitPrice
		FROM Sales.SalesOrderDetail AS sd
		WHERE
			sd.ProductID = p.ProductID

		UNION ALL

		SELECT 
			y0.*
		FROM
		(
			SELECT TOP(1)
				1
			WHERE
				CONVERT(DATE, p.SellEndDate) <= '2002-12-31'
				AND p.MakeFlag = 0
		) AS filter (f)
		CROSS APPLY
		(
			SELECT
				th.ActualCost
			FROM Production.TransactionHistory AS th
			WHERE
				th.ProductID = p.ProductID
		) AS y0
	) AS y
) AS x
GO


