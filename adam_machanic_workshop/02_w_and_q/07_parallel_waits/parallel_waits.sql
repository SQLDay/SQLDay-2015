USE AdventureWorks
GO


--Create a lock situation
BEGIN TRAN

UPDATE TOP(10) Sales.SalesOrderDetail
SET OrderQty += 7
GO



--New window - block
--check out the query plan to see the various
--parallel iterators
SELECT
	*
FROM
(
	SELECT
		sh.*,
		sd.ProductId,
		ROW_NUMBER() OVER 
		(
			PARTITION BY
				sd.SalesOrderDetailId
			ORDER BY
				sd.ProductId, 
				sd.OrderQty
		) AS r
	FROM
	(
		SELECT TOP(1000) 
			*
		FROM Sales.SalesOrderDetail
		ORDER BY
			SalesOrderDetailId DESC
	) AS sd
	INNER JOIN Sales.SalesOrderHeader AS sh ON
		sh.SalesOrderId = sd.SalesOrderId
) AS s
WHERE
	s.r = 1
GO




--Check out the waits
--Notes: 
	--nodeId in resource_description
	--exec_context_ids blocking each other
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	wait_type = 'CXPACKET'
GO



--clean up
ROLLBACK
GO




--EXECSYNC wait
SELECT 
	p.ProductID,
	b0.MaxCost
FROM bigProduct AS p
CROSS APPLY
(
	SELECT 
		MAX(bth.ActualCost) AS MaxCost
	FROM bigTransactionHistory AS bth
	WHERE
		bth.ActualCost BETWEEN p.ListPrice AND p.ListPrice + 10
) AS b0
GO




--ACCESS_METHODS latch

--Especially problematic for table scan
--Create a temp table w/o an index
SELECT TOP(2000000) 
	* 
INTO #bth
FROM dbo.bigTransactionHistory
GO

--Create some CPU pressure...
--16 preemptive threads that will not yield
EXEC dbo.startSeeding
	@numThreads = 16, 
	@useAffinity = 1,
	@yieldMS = 0
GO


--Force a parallel scan
SELECT 
	MAX(ActualCost) 
FROM #bth
GO


/*
--Observe in another window with

EXEC sp_whoisactive
	@get_task_info = 2
*/

--Clean up
EXEC dbo.stopSeeding
GO

