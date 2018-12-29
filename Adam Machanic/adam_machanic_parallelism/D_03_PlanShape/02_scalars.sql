USE AdventureWorks
GO


--Scalar Expressions can cost... a LOT

--Example query that doesn't demo well...

SELECT
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


--Test query

--Run with:
	--Include Client Statistics
	--Actual Query Plan 

--Note the run time with
	--the basic query
	--with MAXDOP 1
	--with the scalar expression commented out


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
--OPTION (MAXDOP 1)
GO
