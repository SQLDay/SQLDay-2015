USE AdventureWorks
GO



SELECT
	MAX(ProductID) AS p,
	MAX(TransactionDate) AS t,
	MAX(c) AS c
FROM
(
	SELECT DISTINCT TOP(1000000)
		th.ProductID,
		th.TransactionDate,
		CONVERT(CHAR(6900), ' ') AS c
	FROM 
	(
		SELECT
			th0.*
		FROM bigTransactionHistory AS th0
		WHERE
			th0.ProductID BETWEEN 1 AND 10000
	) AS th
	WHERE 
		NOT EXISTS
		(
			SELECT
				*
			FROM bigTransactionHistory AS th1
			WHERE
				th1.ProductID = th.ProductID
				AND th1.TransactionDate = DATEADD(day, -1, th.TransactionDate)
		)
	ORDER BY
		ProductId,
		TransactionDate,
		c
) AS v
--OPTION (QUERYTRACEON 8649)
GO



--8649
	--undocumented
	--permissions
	--can't use it in a view



--Can't use it in a view
CREATE VIEW meaninglessView
AS
SELECT
	MAX(ProductID) AS p,
	MAX(TransactionDate) AS t,
	MAX(c) AS c
FROM
(
	SELECT DISTINCT TOP(1000000)
		th.ProductID,
		th.TransactionDate,
		CONVERT(CHAR(6900), ' ') AS c
	FROM 
	(
		SELECT
			th0.*
		FROM bigTransactionHistory AS th0
		WHERE
			th0.ProductID BETWEEN 1 AND 10000
	) AS th
	WHERE 
		NOT EXISTS
		(
			SELECT
				*
			FROM bigTransactionHistory AS th1
			WHERE
				th1.ProductID = th.ProductID
				AND th1.TransactionDate = DATEADD(day, -1, th.TransactionDate)
		)
	ORDER BY
		ProductId,
		TransactionDate,
		c
) AS v
OPTION (QUERYTRACEON 8649)
GO



--Permissions? SA.
--Re-connect with low_access login

