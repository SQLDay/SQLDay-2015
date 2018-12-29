--Under-estimation sucks.
--(SQL Server 2012)
USE AdventureWorks
GO



CREATE TABLE #t
(
	ProductId INT,
	TransactionDate DATE,
	PRIMARY KEY (ProductId, TransactionDate)
)
GO



INSERT #t
SELECT TOP(1000)
	ProductId,
	TransactionDate
FROM bigTransactionHistory
GO



--Find the most recent transaction per product, and its actual cost
--Include actual execution plan...
SELECT
	*
FROM
(
	SELECT
		ProductId,
		TransactionDate,
		ActualCost,
		ROW_NUMBER() OVER
		(
			PARTITION BY
				ProductId
			ORDER BY
				TransactionDate DESC
		) AS r
	FROM dbo.bigTransactionHistory AS bt
	WHERE
		bt.ProductID BETWEEN 1001 AND 10001
		AND NOT EXISTS
		(
			SELECT 
				*
			FROM #t AS t
			WHERE
				t.ProductId = bt.ProductID
				AND t.TransactionDate = bt.TransactionDate
		)
) AS x
WHERE
	x.r = 1
GO




--Check out 3d




--Many() to the rescue?
SELECT
	*
FROM
(
	SELECT
		ProductId,
		TransactionDate,
		ActualCost,
		ROW_NUMBER() OVER
		(
			PARTITION BY
				ProductId
			ORDER BY
				TransactionDate DESC,
				m.x
		) AS r
	FROM dbo.bigTransactionHistory AS bt
	LEFT OUTER JOIN dbo.Many(185364) AS m ON
		1=1
	WHERE
		bt.ProductID BETWEEN 1001 AND 10001
		AND NOT EXISTS
		(
			SELECT 
				*
			FROM #t AS t
			WHERE
				t.ProductId = bt.ProductID
				AND t.TransactionDate = bt.TransactionDate
		)
) AS x
WHERE
	x.r = 1
GO



