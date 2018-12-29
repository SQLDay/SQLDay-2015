--Commanding row goals in odd places...
--(SQL Server 2012 or 2014)
USE AdventureWorks
GO




SET STATISTICS TIME ON
GO




--How about this case?
SELECT
	bp.ProductID,
	bp.Name,
	MAX(bt.TransactionDate) AS mostRecentTransaction
FROM dbo.bigProduct AS bp
INNER JOIN dbo.bigTransactionHistory AS bt ON
	bt.ProductID = bp.ProductID
GROUP BY
	bp.ProductID,
	bp.Name
GO




--Logically equivalent (more or less)
SELECT
	bp.Name,
	bp.productid,
	(
		SELECT
			MAX(bt.TransactionDate)
		FROM dbo.bigTransactionHistory AS bt
		WHERE
			bt.ProductID = bp.ProductID
	) AS mostRecentTransaction
FROM dbo.bigProduct AS bp
GO




--How many rows does the subquery return?
SELECT
	bp.Name,
	bp.productid,
	(
		SELECT TOP(1)
			MAX(bt.TransactionDate)
		FROM dbo.bigTransactionHistory AS bt
		WHERE
			bt.ProductID = bp.ProductID
	) AS mostRecentTransaction
FROM dbo.bigProduct AS bp
GO




--I like this one more
SELECT
	bp.Name,
	bp.productid,
	(
		SELECT TOP(1)
			bt.TransactionDate
		FROM dbo.bigTransactionHistory AS bt
		WHERE
			bt.ProductID = bp.ProductID
		ORDER BY
			bt.TransactionDate DESC
	) AS mostRecentTransaction
FROM dbo.bigProduct AS bp
GO




