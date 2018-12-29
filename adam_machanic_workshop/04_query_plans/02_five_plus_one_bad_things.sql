USE AdventureWorks
GO


--For Best Experience:
	--Enable Actual Execution Plan


/*****************************
--Bad Thing #1: Lookups (that sneak in)
*****************************/

--Make the situation as bad as it can be
DBCC DROPCLEANBUFFERS
GO


--Our query, totally tuned up...
--Find the most recent 1000 transactions per product
SELECT
	x.*
INTO #x
FROM dbo.bigProduct AS p
CROSS APPLY
(
	SELECT TOP(1000)
		*
	FROM dbo.bigTransactionHistory AS bth
	WHERE 
		bth.ProductId = p.ProductID
	ORDER BY
		TransactionDate DESC
) AS x
WHERE
	p.ProductID BETWEEN 1000 AND 7000
GO

	
ALTER TABLE dbo.bigTransactionHistory
ADD CustomerId INT NULL
GO


DROP TABLE #x
GO


DBCC DROPCLEANBUFFERS
GO


--The same query... a bit slower
SELECT
	x.*
INTO #x
FROM dbo.bigProduct AS p
CROSS APPLY
(
	SELECT TOP(1000)
		*
	FROM dbo.bigTransactionHistory AS bth
	WHERE 
		bth.ProductId = p.ProductID
	ORDER BY
		TransactionDate DESC
) AS x
WHERE
	p.ProductID BETWEEN 1000 AND 7000
GO


--Clean up
ALTER TABLE dbo.bigTransactionHistory
DROP COLUMN CustomerId
GO




/*****************************
--Bad Thing #2: Spool
*****************************/

--prep -- create a table of non-distinct product IDs
SELECT 
	ProductId
INTO #products
FROM bigProduct
CROSS APPLY 
(
	SELECT 
		1

	UNION ALL

	SELECT
		2
	WHERE
		ProductId % 5 = 0

	UNION ALL

	SELECT
		3
	WHERE
		ProductId % 7 = 0
) x(m)
WHERE
	ProductId BETWEEN 1001 AND 20001
GO



--The dreaded "performance spool"
SELECT
	p.ProductId,
	AVG(x.ActualCost) AS AvgCostTop40
FROM #products AS p
CROSS APPLY
(
	SELECT
		t.*,
		ROW_NUMBER() OVER 
		(
			PARTITION BY 
				p.ProductId 
			ORDER BY 
				t.ActualCost DESC
		) AS r
	FROM bigTransactionHistory AS t 
	WHERE
		p.ProductId = t.ProductId
) AS x
WHERE
	x.r BETWEEN 1 AND 40
GROUP BY
	p.ProductId
GO


--Two options:
	--Give the optimizer more information (yes!)
	--Use TF 8690 (last resort)



--How non-unique does it have to be to actually be better?
--Try once, then do 8690 vs normal
INSERT #products
SELECT *
FROM #products
GO


--Still not faster..? Try again...
INSERT #products
SELECT *
FROM #products
GO



--Clean up
DROP TABLE #products
GO





/*****************************
--Bad Thing #3: Oversized Sorts
*****************************/

--Find the 500 (or so) products that sold for the highest cost, among those that sold for > 1500
SELECT TOP(500) WITH TIES
	ProductId,
	ActualCost
FROM
(

	SELECT
		ProductId,
		ActualCost,
		ROW_NUMBER() OVER
		(
			PARTITION BY
				ProductId
			ORDER BY
				ActualCost DESC
		) AS r
	FROM bigTransactionHistory
	WHERE
		ActualCost >= 1500
) AS x
WHERE
	x.r = 1
ORDER BY
	x.ActualCost DESC
GO


--Not giving the optimizer enough information == SLOW!

--Solution: Create an index. OR, give the optimizer more to work with...
--Remember: Scan == O(N). Sort == O(N * LOG(N)).

--More, smaller sorts == better performance
SELECT TOP(500) WITH TIES
	p.ProductId,
	x.ActualCost
FROM bigProduct AS p
CROSS APPLY
(
	SELECT
		bt.ActualCost,
		ROW_NUMBER() OVER
		(
			ORDER BY
				bt.ActualCost DESC
		) AS r
	FROM bigTransactionHistory AS bt
	WHERE
		bt.ProductId = p.ProductId
		AND bt.ActualCost >= 1500
) AS x
WHERE
	x.r = 1
ORDER BY
	x.ActualCost DESC
GO





/*****************************
--Bad Thing #4: Inappropriate Hash Match
*****************************/

--Scenario: we've loaded some transactions from an external source
--We want to verify the data against our existing transactions


--Here are our new transactions, in a temp table
SELECT TOP(5000000)
	ProductId,
	TransactionDate,
	Quantity,
	ActualCost
INTO #bth
FROM dbo.bigTransactionHistory
WHERE
	ProductId BETWEEN 1 AND 40001
GO


--Exacerbate the problem
DBCC DROPCLEANBUFFERS
GO

--hash match MAY indicate lack of appropriate indexes

--how many transactions do we have in our temp table for products 1501 through 5201?
--Note: View estimated plan first, then DROPCLEANBUFFERS
--Reason: Estimated plan will cause autostats to kick in
SELECT 
	COUNT(*)
FROM #bth AS b
WHERE 
	EXISTS
	(
		SELECT 
			*
		FROM dbo.bigTransactionHistory AS bth
		WHERE
			bth.TransactionDate = b.TransactionDate
			AND bth.ProductID = b.ProductID
			AND bth.ProductID BETWEEN 1501 AND 5201
	)
OPTION (MAXDOP 1)
GO


--Try creating an index...
CREATE CLUSTERED INDEX ix_ProductID_TransactionDate
ON #bth
(
	ProductId,
	TransactionDate
)
GO




/*****************************
--Bad Thing #5: Serial Nested Loops
--Run this on SQL Server 2012!
*****************************/

--Set up a temp table with most of the products...
SELECT 
	ProductId,
	Name
INTO #p
FROM dbo.bigProduct
WHERE
	ProductId <= 44999
GO


--Index the table
CREATE UNIQUE CLUSTERED INDEX ix_x 
ON #p 
(
	ProductId
)
GO


--Now insert some more products... 
INSERT #p 
(
	ProductId
)
SELECT 
	ProductId
FROM dbo.bigProduct
WHERE
	ProductId > 44999
GO


--Fast query?
SELECT
	p.Name AS ProductName,
	x.TheYear,
	x.TheMonth,
	x.TotalSales
FROM #p AS p
INNER JOIN
(
	SELECT
		ProductId,
		YEAR(TransactionDate) AS TheYear,
		MONTH(TransactionDate) AS TheMonth,
		SUM(ActualCost) AS TotalSales
	FROM dbo.bigTransactionHistory
	GROUP BY
		ProductId,
		YEAR(TransactionDate),
		MONTH(TransactionDate)
) AS x ON
	p.ProductId = x.ProductId
WHERE
	p.ProductID > 44999
GO


--Try again after a stats update...
UPDATE STATISTICS #p
GO

--Trouble with autostats thresholds on large tables?
--SQL Server 2008 R2+ -- TF 2371
--https://blogs.msdn.com/b/saponsqlserver/archive/2011/09/07/changes-to-automatic-update-statistics-in-sql-server-traceflag-2371.aspx

--...or upgrade to SQL Server 2014!





/*****************************
--Bad Thing #6: Scans That Don't Look Like Scans
*****************************/

--A tiny estimate. Cheap query, right?
SELECT
	ProductId,
	ActualCost,
	TransactionDate,
	Quantity
FROM bigTransactionHistory_ue AS bth
WHERE
	ProductId BETWEEN 1001 AND 50001
	AND ActualCost > 5000000
GO


--Do a bit more evaluation...
SET STATISTICS IO ON
GO

SELECT
	*
FROM bigTransactionHistory_ue AS bth
WHERE
	ProductId BETWEEN 1001 AND 50001
	AND ActualCost > 5000000
GO


--UNDOCUMENTED trace flag to see more detail...
SELECT
	*
FROM bigTransactionHistory_ue AS bth
WHERE
	ProductId BETWEEN 1001 AND 50001
	AND ActualCost > 5000000
OPTION (QUERYTRACEON 9130)
GO



--Optional


--Scenario:
--For reporting purposes, we need to constrain the dates for products
--So we put that information into a table somewhere...
CREATE TABLE #validProductRanges
(
	ProductId INT,
	StartDate DATETIME,
	EndDate DATETIME,
	PRIMARY KEY (ProductId)
)

INSERT #validProductRanges 
SELECT
	ProductId,
	CASE
		WHEN ProductID BETWEEN 1001 AND 20001 THEN '20040101'
		WHEN ProductID BETWEEN 20002 AND 40001 THEN '20040630'
		WHEN ProductID > 40002 THEN '20050101'
	END,
	'20120101'
FROM dbo.bigProduct
GO



--Exacerbate problems...
DBCC DROPCLEANBUFFERS
GO



--Ask for the first 100 transactions per product, in range, after a certain start date
DECLARE @start_date DATE = '2010-08-10'

SELECT
	p.*
FROM #validProductRanges AS vr
CROSS APPLY
(
	SELECT TOP(100)
		bt.TransactionDate,
		bt.ProductID,
		bt.ActualCost
	FROM dbo.bigTransactionHistory AS bt
	WHERE
		bt.ProductId = vr.ProductId
		AND bt.TransactionDate BETWEEN vr.StartDate and vr.EndDate
		AND bt.TransactionDate >= @start_date
	ORDER BY
		bt.TransactionDate
) AS p
GO



DBCC DROPCLEANBUFFERS
GO


--Try again, but re-write the date predicates
DECLARE @start_date DATE = '2010-08-10'

SELECT
	p.*
FROM #validProductRanges AS vr
CROSS APPLY
(
	SELECT TOP(100)
		bt.TransactionDate,
		bt.ProductID,
		bt.ActualCost
	FROM dbo.bigTransactionHistory AS bt
	WHERE
		bt.ProductId = vr.ProductId
		AND bt.TransactionDate >= 
			CASE
				WHEN @start_date > vr.StartDate THEN @start_date
				ELSE vr.StartDate
			END 
		AND bt.TransactionDate <= vr.EndDate
) AS p
GO












