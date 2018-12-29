--The old standby... Task-level wait list
--lastwaittype:
	--if waittime > 0, current wait type
	--else, last wait type
SELECT 
	*
FROM sys.sysprocesses
GO




--Newer/better technology?
--"Request-level" wait list
SELECT
	session_id,
	wait_type,
	wait_time,
	wait_resource,
	blocking_session_id
FROM sys.dm_exec_requests
GO



--The root task's wait is NOT the entire story...
USE AdventureWorks
GO

BEGIN TRAN

UPDATE TOP(10) Sales.SalesOrderDetail
SET OrderQty += 7
GO

--New window
SELECT TOP(1000) *
FROM Sales.SalesOrderDetail
ORDER BY
	SalesOrderDetailId DESC
GO


--oops.
SELECT
	session_id,
	wait_type,
	wait_time,
	wait_resource,
	blocking_session_id
FROM sys.dm_exec_requests
WHERE
	blocking_session_id <> 0
GO



--better
SELECT *
FROM sys.sysprocesses
WHERE
	blocked <> 0
GO



--... or ...
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	blocking_session_id <> session_id
GO





--Who is Active?
EXEC sp_whoisactive
GO



--Get more in-depth wait info
EXEC sp_whoisactive @get_task_info = 2
GO



/*clean up!*/
ROLLBACK
GO

