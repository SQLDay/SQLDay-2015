--parallel inhibitors

USE AdventureWorks
GO

--(Almost) fully parallel plan
SELECT 
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint,
    SUM(th.ActualCost) AS ActualCostSum
FROM bigProduct AS p
INNER JOIN bigTransactionHistory AS th ON
    th.ProductId = p.ProductId
WHERE
	p.ProductId BETWEEN 1001 AND 10001
GROUP BY
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint
GO



--Serial region due to TOP
SELECT 
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint,
    SUM(th.ActualCost) AS ActualCostSum
FROM
(
	SELECT TOP(2000000)
		*
	FROM bigProduct AS bp
	WHERE
		bp.ProductId BETWEEN 1001 AND 10001
) AS p
INNER JOIN bigTransactionHistory AS th ON
    th.ProductId = p.ProductId
GROUP BY
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint
GO



--Serial region due to query global aggregate
SELECT 
    SUM(q.ActualCostSum) AS ActualCostSumSum
FROM 
(
	SELECT 
		p.ProductId, 
		p.ProductNumber,
		p.ReorderPoint,
		SUM(th.ActualCost) AS ActualCostSum
	FROM bigProduct AS p
	INNER JOIN bigTransactionHistory AS th ON
		th.ProductId = p.ProductId
	WHERE
		p.ProductId BETWEEN 1001 AND 10001
	GROUP BY
		p.ProductId, 
		p.ProductNumber,
		p.ReorderPoint
) AS q
GO



--Another consideration in the temp table vs. variable debate...

CREATE TABLE #stuff
(
	ProductId INT,
	ProductNumber NVARCHAR(80),
	ReorderPoint SMALLINT,
	ActualCostSum MONEY
)

INSERT #stuff
SELECT 
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint,
    SUM(th.ActualCost) AS ActualCostSum
FROM bigProduct AS p
INNER JOIN bigTransactionHistory AS th ON
    th.ProductId = p.ProductId
WHERE
	p.ProductId BETWEEN 1001 AND 10001
GROUP BY
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint
GO



DECLARE @stuff TABLE
(
	ProductId INT,
	ProductNumber NVARCHAR(80),
	ReorderPoint SMALLINT,
	ActualCostSum MONEY
)

INSERT @stuff
SELECT 
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint,
    SUM(th.ActualCost) AS ActualCostSum
FROM bigProduct AS p
INNER JOIN bigTransactionHistory AS th ON
    th.ProductId = p.ProductId
WHERE
	p.ProductId BETWEEN 1001 AND 10001
GROUP BY
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint
GO



--Create a function to play with...
IF (OBJECT_ID('dbo.returnInput') IS NOT NULL)
	DROP FUNCTION returnInput
GO

CREATE FUNCTION returnInput 
(
	@input INT
)
RETURNS INT
AS
BEGIN
	RETURN (@input)
END
GO



--Massive (not-so-)parallel fail..!
SELECT 
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint,
    dbo.ReturnInput(SUM(th.ActualCost)) AS ActualCostSum
FROM bigProduct AS p
INNER JOIN bigTransactionHistory AS th ON
    th.ProductId = p.ProductId
WHERE
	p.ProductId BETWEEN 1001 AND 10001
GROUP BY
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint
GO



--Another excuse for CLR functions
--(as if I needed one)
SELECT 
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint,
    dbo.ReturnInput_CLR(SUM(th.ActualCost)) AS ActualCostSum
FROM bigProduct AS p
INNER JOIN bigTransactionHistory AS th ON
    th.ProductId = p.ProductId
WHERE
	p.ProductId BETWEEN 1001 AND 10001
GROUP BY
    p.ProductId, 
    p.ProductNumber,
    p.ReorderPoint
GO





