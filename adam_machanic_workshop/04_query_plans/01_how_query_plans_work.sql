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




--Insight: Number of Executions
SELECT TOP(1000)
	p.ProductId,
	th.TransactionId
FROM Production.Product AS p
INNER LOOP JOIN Production.TransactionHistory AS th WITH (FORCESEEK) ON
	p.ProductId = th.ProductId
WHERE
	th.ActualCost > 50
	AND p.StandardCost < 10
GO










