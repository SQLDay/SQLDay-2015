USE AdventureWorks
GO


SET STATISTICS TIME ON
GO


--Common override
--Is the query fast enough if we limit DOP?
SELECT TOP(1000)
	*
FROM Sales.SalesOrderDetail
ORDER BY
	SalesOrderDetailId DESC
OPTION (MAXDOP 1)
GO

