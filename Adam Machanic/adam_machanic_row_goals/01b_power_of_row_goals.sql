--The power of row goals
--(SQL Server 2012)
USE AdventureWorks
GO

/*
--SETUP

SELECT
	*
INTO dbo.bigProductVacation
FROM
(
	SELECT DISTINCT
		ProductSubcategoryID 
	FROM dbo.bigProduct
	WHERE
		ProductSubcategoryID IS NOT NULL
) AS p
CROSS APPLY
(
	SELECT
		DATEADD(day, v.number, CONVERT(DATE, '20050101')) AS d,
		CASE
			WHEN b1.TransactionDate IS NOT NULL THEN 0
			ELSE 1
		END AS vacation_day
	FROM master..spt_values AS v
	LEFT OUTER JOIN
	(
		SELECT DISTINCT
			bth.TransactionDate
		FROM dbo.bigTransactionHistory AS bth
		WHERE
			bth.ProductID IN 
			(
				SELECT
					b0.productid 
				FROM dbo.bigProduct AS b0 
				WHERE
					b0.ProductSubcategoryID = p.ProductSubcategoryID
			)
	) AS b1 ON 
		b1.TransactionDate = DATEADD(day, v.number, CONVERT(DATE, '20050101'))
	WHERE
		v.type = 'p'
) AS x
GO

CREATE CLUSTERED INDEX category_date 
ON bigProductVacation
(
	d
)
GO

CREATE NONCLUSTERED INDEX ix_CategoryDate
ON [dbo].[bigTransactionHistory] 
(
	[ProductCategoryID],
	[TransactionDate]
)
INCLUDE 
(
	[ProductID],
	[ActualCost]
)
GO

CREATE NONCLUSTERED INDEX ix_date 
ON [dbo].[bigTransactionHistory]
(
	[TransactionDate]
)
INCLUDE
( 	
	[ProductID],
	[ActualCost]
)
GO

SELECT *
INTO dbo.bigProductSubCategory 
FROM AdventureWorks.Production.ProductSubcategory
GO

SELECT * 
INTO dbo.bigProductCategory 
FROM AdventureWorks.Production.Productcategory
GO

ALTER TABLE dbo.bigTransactionHistory 
ADD ProductCategoryID INT NULL

UPDATE bigT 
SET
	bigT.ProductCategoryID = 
	(
		SELECT 
			psc.productcategoryid 
		FROM dbo.bigproduct AS p 
		INNER JOIN Production.ProductSubcategory AS psc ON 
			p.productsubcategoryid = psc.ProductSubcategoryID 
		WHERE
			p.ProductID = bigT.ProductID
	)
FROM bigTransactionHistory AS bigT 
GO

CREATE FUNCTION dbo.getProductSales
(
	@ProductCategoryID INT,
	@startDate DATE,
	@endDate DATE
)
RETURNS TABLE
AS
RETURN
(
	SELECT
		y.ProductId,
		SUM(y.ActualCost) AS totalCost
	FROM
	(
		SELECT
			y0.*,
			--Favor non-backfilled products
			ROW_NUMBER() OVER
			(
				PARTITION BY
					y0.ProductId,
					y0.TransactionDate
				ORDER BY
					y0.backfill
			) AS r
		FROM
		(
			SELECT
				p_trn.ProductId,
				trn.TransactionDate,
				p_trn.ActualCost,
				1 AS backfill
			FROM bigProductCategory AS c
			CROSS APPLY
			(
					SELECT
					pv.ProductSubcategoryID,
					pv.d AS TransactionDate,
					(
						SELECT TOP(1)
							pv0.d
						FROM dbo.bigProductVacation AS pv0
						WHERE
							pv0.ProductSubcategoryID = pv.ProductSubcategoryID
							AND pv0.d < pv.d
							AND pv0.vacation_day = 0
					) AS PriorTransactionDate
				FROM dbo.bigProductVacation AS pv
				INNER JOIN bigProductSubcategory AS psc ON
					psc.ProductSubCategoryID = pv.ProductSubCategoryID
				WHERE
					psc.ProductCategoryID = c.ProductCategoryID
					AND pv.vacation_day = 1
					AND pv.d BETWEEN @startDate AND @endDate
			) AS trn
			CROSS APPLY
			(
				SELECT
					bth0.ProductID,
					bth0.ActualCost
				FROM dbo.bigTransactionHistory AS bth0
				INNER JOIN dbo.bigProduct AS p ON
					p.ProductID = bth0.ProductID
				WHERE
					bth0.TransactionDate = trn.PriorTransactionDate
					AND p.ProductSubCategoryId = trn.ProductSubcategoryID
			) AS p_trn
			WHERE
				c.ProductCategoryID = @ProductCategoryID

			UNION ALL

			SELECT
				bth.ProductID,
				bth.TransactionDate,
				bth.ActualCost,
				0 AS backfill
			FROM dbo.bigTransactionHistory AS bth
			WHERE
				bth.TransactionDate BETWEEN @startDate AND @endDate
				AND bth.ProductCategoryID = @ProductCategoryID
		) AS y0
	) AS y
	WHERE
		y.r = 1
	GROUP BY
		y.ProductID
)
GO
*/



SET STATISTICS TIME ON
GO




SELECT --TOP(1)
	*
FROM dbo.getProductSales(4, '20050101', '20060630')
GO





