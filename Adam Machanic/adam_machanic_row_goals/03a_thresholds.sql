--Thresholds
--(SQL Server 2012 or 2014)
USE AdventureWorks
GO



--An innocent hash join query...
SELECT
    p.ProductModelID,
    th.TransactionID
FROM Production.Product AS p
INNER JOIN Production.TransactionHistory AS th ON
    p.ProductID = th.ProductID
	AND p.DiscontinuedDate < th.ModifiedDate
GO




--...Now the proud owner of a DYNAMIC row goal!
DECLARE @i INT = 2147483647

SELECT TOP(@i)
    p.ProductModelID,
    th.TransactionID
FROM Production.Product AS p
INNER JOIN Production.TransactionHistory AS th ON
    p.ProductID = th.ProductID
	AND p.DiscontinuedDate < th.ModifiedDate
GO




--What kind of plan would we get if we only wanted 1 row?
DECLARE @i INT = 2147483647

SELECT TOP(@i)
    p.ProductModelID,
    th.TransactionID
FROM Production.Product AS p
INNER JOIN Production.TransactionHistory AS th ON
    p.ProductID = th.ProductID
	AND p.DiscontinuedDate < th.ModifiedDate
OPTION (OPTIMIZE FOR (@i = 1))
GO




--More targeted control...
DECLARE @i INT = 2147483647

SELECT
    p.ProductModelID,
    th.TransactionID
FROM 
(
	SELECT TOP(@i)
		*
	FROM Production.Product
) AS p
INNER JOIN Production.TransactionHistory AS th ON
    p.ProductID = th.ProductID
	AND p.DiscontinuedDate < th.ModifiedDate
OPTION (OPTIMIZE FOR (@i = 1))
GO




--I'd REALLY love a merge join...
DECLARE @i INT = 2147483647

SELECT
    p.ProductModelID,
    th.TransactionID
FROM Production.Product AS p
INNER JOIN 
(
	SELECT TOP(@i)
		*
	FROM Production.TransactionHistory
) AS th ON
    p.ProductID = th.ProductID
	AND p.DiscontinuedDate < th.ModifiedDate
OPTION (OPTIMIZE FOR (@i = 500))
GO



