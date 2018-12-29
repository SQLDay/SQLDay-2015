USE AdventureWorks
GO



--Run each of the following with:
	-- Actual Execution Plan enabled
	-- Client statistics enabled



--A typical parallel query...
SELECT
	MAX(ProductId),
	MAX(ProductNumber),
	MAX(ReorderPoint),
	MAX(TransactionId),
	MAX(LineTotalRank),
	MAX(OrderQtyRank)
FROM
(
	SELECT 
		p.ProductId, 
		p.ProductNumber,
		p.ReorderPoint,
		th.TransactionId,
		RANK() OVER 
		(
			PARTITION BY
				p.ProductId
			ORDER BY
				th.ActualCost DESC
		) AS LineTotalRank,
		RANK() OVER
		(
			PARTITION BY
				p.ProductId
			ORDER BY 
				th.Quantity DESC
		) AS OrderQtyRank
	FROM bigProduct AS p
	INNER JOIN bigTransactionHistory AS th ON
		th.ProductId = p.ProductId
	WHERE
		p.ProductId BETWEEN 1001 AND 5001
) AS x
GO




--Will Columnstore fix my query?
SELECT
	MAX(ProductId),
	MAX(ProductNumber),
	MAX(ReorderPoint),
	MAX(TransactionId),
	MAX(LineTotalRank),
	MAX(OrderQtyRank)
FROM
(
	SELECT 
		p.ProductId, 
		p.ProductNumber,
		p.ReorderPoint,
		th.TransactionId,
		RANK() OVER 
		(
			PARTITION BY
				p.ProductId
			ORDER BY
				th.ActualCost DESC
		) AS LineTotalRank,
		RANK() OVER
		(
			PARTITION BY
				p.ProductId
			ORDER BY 
				th.Quantity DESC
		) AS OrderQtyRank
	FROM bigProduct AS p
	INNER JOIN bigTransactionHistory_cs AS th ON
		th.ProductId = p.ProductId
	WHERE
		p.ProductId BETWEEN 1001 AND 5001
) AS x
GO




--Think about the query a different way...
--Remember Mr. Amdahl!
SELECT
	MAX(ProductId),
	MAX(ProductNumber),
	MAX(ReorderPoint),
	MAX(TransactionId),
	MAX(LineTotalRank),
	MAX(OrderQtyRank)
FROM
(
	SELECT 
		p.ProductId,
		p.ProductNumber,
		p.ReorderPoint,
		d.*
	FROM bigProduct AS p
	CROSS APPLY
	(
		SELECT
			th.TransactionId,		
			RANK() OVER 
			(
				ORDER BY
					th.ActualCost DESC
			) AS LineTotalRank,
			RANK() OVER
			(
				ORDER BY 
					th.Quantity DESC
			) AS OrderQtyRank
		FROM bigTransactionHistory AS th
		WHERE
			th.ProductId = p.ProductId
	) AS d
	WHERE
		p.ProductId BETWEEN 1001 AND 5001
) AS x
GO


--Take a look at actual rows/thread



--Repartition to avoid skew?
SELECT
	MAX(ProductId),
	MAX(ProductNumber),
	MAX(ReorderPoint),
	MAX(TransactionId),
	MAX(LineTotalRank),
	MAX(OrderQtyRank)
FROM
(
	SELECT 
		p.ProductId,
		p.ProductNumber,
		p.ReorderPoint,
		d.*
	FROM 
	(
		SELECT TOP(2147483647)
			p0.ProductId,
			p0.ProductNumber,
			p0.ReorderPoint
		FROM bigProduct AS p0
		WHERE
			p0.ProductId BETWEEN 1001 AND 5001
	) AS p
	CROSS APPLY
	(
		SELECT
			th.TransactionId,		
			RANK() OVER 
			(
				ORDER BY
					th.ActualCost DESC
			) AS LineTotalRank,
			RANK() OVER
			(
				ORDER BY 
					th.Quantity DESC
			) AS OrderQtyRank
		FROM bigTransactionHistory AS th
		WHERE
			th.ProductId = p.ProductId
	) AS d
) AS x
GO




--Our slow scalar expression query...
SELECT
	MAX(x.SellStartDate),
	MAX(x.TransactionDate),
	MAX(x.SomeWeirdThing)
FROM
(
	SELECT TOP(2147483647)
		p.SellStartDate, 
		th.TransactionDate,
		DATENAME
		(
			dw, 
			DATEADD
			(
				dd, 
				0, 
				20 % 
					DATEDIFF
					(
						dd, 
						CONVERT(DATETIME, '20091125')-1, 
						DATEADD
						(
							dd, 
							DATEDIFF
							(
								dd, 
								0, 
								DATEADD
								(
									month, 
									DATEDIFF
									(
										dd, 
										p.SellStartDate, 
										th.TransactionDate
									), 
									DATEADD
									(
										month, 
										DATEDIFF
										(
											month, 
											th.TransactionDate, 
											p.SellStartDate
										), 
										0
									)
								)
							), 
							0
						)
					)
				)
			) AS SomeWeirdThing
	FROM bigProduct AS p
	INNER JOIN bigTransactionHistory AS th ON
		th.ProductId = p.ProductId
		AND th.ActualCost BETWEEN 0 AND 100000
	WHERE
		p.ProductId BETWEEN 1001 AND 20001
) AS x
GO



--Does it work with the APPLY pattern?
SELECT
	MAX(x.SellStartDate),
	MAX(x.TransactionDate),
	MAX(x.SomeWeirdThing)
FROM bigProduct AS p
CROSS /*OUTER*/ APPLY
(
	SELECT TOP(2147483647)
		p.SellStartDate, 
		th.TransactionDate,
		DATENAME
		(
			dw, 
			DATEADD
			(
				dd, 
				0, 
				20 % 
					DATEDIFF
					(
						dd, 
						CONVERT(DATETIME, '20091125')-1, 
						DATEADD
						(
							dd, 
							DATEDIFF
							(
								dd, 
								0, 
								DATEADD
								(
									month, 
									DATEDIFF
									(
										dd, 
										p.SellStartDate, 
										th.TransactionDate
									), 
									DATEADD
									(
										month, 
										DATEDIFF
										(
											month, 
											th.TransactionDate, 
											p.SellStartDate
										), 
										0
									)
								)
							), 
							0
						)
					)
				)
			) AS SomeWeirdThing
	FROM bigTransactionHistory AS th
	WHERE
		th.ProductId = p.ProductId
		AND th.ActualCost BETWEEN 0 AND 100000
) AS x
WHERE
	p.ProductId BETWEEN 1001 AND 20001
GO




--A more complex query?



--Find all "active" product time ranges:

--intervals during which the product has sold 
--within the prior N days

DECLARE @active_interval INT = 7

SELECT DISTINCT
	t_s.ProductID,
	t_s.TransactionDate AS StartDate,
	DATEADD
	(
		dd,
		@active_interval,
		(
			SELECT
				MIN(t_e.TransactionDate)
			FROM dbo.BigTransactionHistory AS t_e
			WHERE
				t_e.ProductID = t_s.ProductID
				AND t_e.TransactionDate >= t_s.TransactionDate
				AND NOT EXISTS
				(
					SELECT *
					FROM dbo.BigTransactionHistory AS t_ae
					WHERE
						t_ae.ProductID = t_s.ProductID
						AND t_ae.TransactionDate BETWEEN DATEADD(dd, 1, t_e.TransactionDate) AND DATEADD(dd, @active_interval, t_e.TransactionDate)
				)
		)
	) AS EndDate
FROM 
(
	SELECT DISTINCT
		bt0.ProductID,
		bt0.TransactionDate
	FROM dbo.BigTransactionHistory AS bt0
	WHERE
		bt0.ProductID BETWEEN 1001 AND 3618
) AS t_s
WHERE
	NOT EXISTS
	(
		SELECT *
		FROM dbo.BigTransactionHistory AS t_ps
		WHERE
			t_ps.ProductID = t_s.ProductID
			AND t_ps.TransactionDate BETWEEN DATEADD(dd, -@active_interval, t_s.TransactionDate) AND DATEADD(dd, -1, t_s.TransactionDate)
	)
GO




--Note: Columnstore makes this query several times *SLOWER*




--Active intervals, rewritten with the APPLY pattern...

DECLARE @active_interval INT = 7
/*DECLARE @i INT = 2147483647*/

SELECT
	x.* 
FROM dbo.bigProduct AS bp /*(SELECT DISTINCT 0%ProductId+ProductId AS Productid FROM dbo.bigProduct) AS bp*/
OUTER APPLY
(
	SELECT DISTINCT /*TOP(@i)*/
		t_s.ProductID,
		t_s.TransactionDate AS StartDate,
		DATEADD
		(
			dd,
			@active_interval,
			(
				SELECT
					MIN(t_e.TransactionDate)
				FROM dbo.BigTransactionHistory AS t_e
				WHERE
					t_e.ProductID = bp.ProductID
					AND t_e.TransactionDate >= t_s.TransactionDate
					AND NOT EXISTS
					(
						SELECT *
						FROM dbo.BigTransactionHistory AS t_ae
						WHERE
							t_ae.ProductID = bp.ProductID
							AND t_ae.TransactionDate BETWEEN DATEADD(dd, 1, t_e.TransactionDate) AND DATEADD(dd, @active_interval, t_e.TransactionDate)
					)
			)
		) AS EndDate
	FROM 
	(
		SELECT DISTINCT
			ProductID,
			TransactionDate
		FROM dbo.BigTransactionHistory
		WHERE
			ProductID = bp.ProductID
	) AS t_s
	WHERE
		NOT EXISTS
		(
			SELECT *
			FROM dbo.BigTransactionHistory AS t_ps
			WHERE
				t_ps.ProductID = bp.ProductID
				AND t_ps.TransactionDate BETWEEN DATEADD(dd, -@active_interval, t_s.TransactionDate) AND DATEADD(dd, -1, t_s.TransactionDate)
		)
) AS x
WHERE
	bp.ProductID BETWEEN 1001 AND 3618
	AND x.ProductID IS NOT NULL
GO




--ORDER BY == BAD?
/*
ORDER BY
	bp.ProductId
*/
--OPTION (OPTIMIZE FOR (@i = 1))
/*
--Check out the TF to evaluate why ORDER BY is problematic...
OPTION (QUERYTRACEON 8649)
*/
--Fix by reducing estimate coming out of the loop...
/*
OPTION (OPTIMIZE FOR (@i = 1))
*/
GO

