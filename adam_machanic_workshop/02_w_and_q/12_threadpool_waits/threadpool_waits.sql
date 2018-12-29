USE AdventureWorks
GO


--Threadpool Cause #1: No free schedulers

--Create just enough scheduler pressure to cause some thrashing
--6 (out of 8, on my laptop) cooperatively scheduled, non-yielding workers
EXEC startSeeding	
	@numThreads = 6,
	@useAffinity = 0,
	@yieldMS = 0
GO


--run the threadpool sqlstress load


--... log in with the DAC

--Note the lack of a session_id...
SELECT
	*
FROM sys.dm_os_waiting_tasks
WHERE
	wait_type = 'THREADPOOL'
GO



--Clean up
EXEC stopSeeding
GO



--Threadpool Cause #2: Too many workers

--Configure max worker threads to make things easier
EXEC sp_configure 'show advanced options', 1
RECONFIGURE
GO
EXEC sp_configure 'max worker threads', 128
RECONFIGURE
GO


--*Restart SQL Server*
--Reconnect via the DAC



--Create a blocking situation
BEGIN TRAN

UPDATE TOP(10) Sales.SalesOrderDetail
SET OrderQty += 7
GO




--run the threadpool sqlstress load

--to see dynamic DOP, look at #tasks in sp_WhoIsActive
--(do this in the DAC window)
EXEC sp_WhoIsActive 
	@get_task_info = 2,
	@get_plans = 1
GO


--Clean up
ROLLBACK
GO


EXEC sp_configure 'max worker threads', 0
RECONFIGURE
GO
--And restart again.

