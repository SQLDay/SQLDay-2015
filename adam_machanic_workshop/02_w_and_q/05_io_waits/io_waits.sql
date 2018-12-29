USE AdventureWorks
GO


--Create some IO waits
DBCC DROPCLEANBUFFERS
SELECT
	COUNT(*) 
FROM Sales.SalesOrderHeader sh
FULL OUTER JOIN Sales.SalesOrderDetail sd ON
	sh.rowguid = sd.rowguid
FULL OUTER JOIN Production.Product p ON
	p.rowguid = sd.rowguid
FULL OUTER JOIN Sales.Customer AS c ON
	c.rowguid = p.rowguid
FULL OUTER JOIN Person.Address AS a ON
	a.rowguid = c.rowguid
FULL OUTER JOIN Person.Contact AS pc ON
	pc.rowguid = a.rowguid
FULL OUTER JOIN Sales.ContactCreditCard AS ccc ON
	ccc.CreditCardId = pc.ContactId
FULL OUTER JOIN Production.TransactionHistoryArchive AS ta ON
	ta.transactionid = c.customerid
GO 500




--New window... Look at the waits in sys.dm_os_waiting_tasks
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	wait_type LIKE 'PAGEIOLATCH%'
GO




--Another cause for I/O waits: CPU pressure

--Set up a temp table with 5000 random transaction IDs
SELECT TOP(5000)
	CONVERT(INT, (RAND(CHECKSUM(NEWID())) * 31263601) + 1) AS TransactionId
INTO #x
FROM 
	master..spt_values AS a,
	master..spt_values AS b
GO



--Exacerbate the issue by disabling readahead
DBCC TRACEON(652)
GO



--run this, then watch wait stats
DBCC DROPCLEANBUFFERS
GO

SELECT 
	COUNT(*)
FROM #x AS x
INNER LOOP JOIN dbo.bigTransactionHistory AS th ON
	th.TransactionID = x.TransactionId
GO



--Start 16 preemptive threads that yield every 500ms
--Re-run the above, again watching wait stats
EXEC startSeeding
	@numThreads = 16, 
	@useAffinity = 1, 
	@yieldMS = 500
GO



--Stop the threads
EXEC stopSeeding
GO
--Re-enable readahead
DBCC TRACEOFF(652)
GO
