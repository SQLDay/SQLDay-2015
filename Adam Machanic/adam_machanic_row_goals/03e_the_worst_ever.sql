--The worst, ever
--(Since SQL Server 2000)
USE AdventureWorks
GO




--The worst offender in the history of estimates..?
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'returnTransactionDates')
	DROP FUNCTION dbo.returnTransactionDates
GO

CREATE FUNCTION dbo.returnTransactionDates
(
	@minProductID INT, 
	@maxProductID INT
)
RETURNS @t TABLE 
(
	ProductID INT,
	TransactionDate DATE
)
AS
BEGIN
    INSERT @t 
	(
		ProductID,
		TransactionDate
	)
    SELECT 
		ProductID,
		TransactionDate
    FROM dbo.bigTransactionHistory
    WHERE
        ProductID BETWEEN @minProductId AND @maxProductId

	RETURN
END
GO




--Test it...
SELECT
	*
FROM dbo.returnTransactionDates(1001, 5001)
GO




--Is this REALLY the most appropriate plan?
SELECT
	MAX(rt.ProductId),
	MAX(rt.TransactionDate),
	MAX(p.Name)
FROM dbo.returnTransactionDates(1001, 5001) AS rt
INNER JOIN bigProduct AS p ON 
	p.ProductID = rt.ProductID
GO




--Solve with Many()?
--(Not quite.)
SELECT
	MAX(rt.ProductId),
	MAX(rt.TransactionDate),
	MAX(p.Name)
FROM dbo.returnTransactionDates(1001, 5001) AS rt
LEFT OUTER JOIN dbo.Many(10000) AS m ON
	1=1
INNER JOIN bigProduct AS p ON 
	p.ProductID = rt.ProductID
GO




--Hash match?
SELECT
	MAX(rt.ProductID),
	MAX(rt.TransactionDate),
	MAX(p.Name)
FROM dbo.returnTransactionDates(1001, 5001) AS rt
LEFT OUTER JOIN dbo.Many(10000) AS m ON
	1=1
INNER JOIN bigProduct AS p ON 
	p.ProductID = ISNULL(m.x, rt.ProductID)
GO



