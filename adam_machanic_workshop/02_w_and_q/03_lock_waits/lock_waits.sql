USE AdventureWorks
GO


--Create a lock situation
BEGIN TRAN

UPDATE TOP(10) Sales.SalesOrderDetail
SET OrderQty += 7
GO



--New window - block
SELECT TOP(1000) *
FROM Sales.SalesOrderDetail
ORDER BY
	SalesOrderDetailId DESC
GO



SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	blocking_session_id <> session_id
GO



--More info?
SELECT *
FROM sys.dm_os_waiting_tasks AS wt
INNER JOIN sys.dm_tran_locks AS l ON
	l.lock_owner_address = wt.resource_address
WHERE
	wt.blocking_session_id <> wt.session_id
GO



--And even more info...
SELECT
	l_blocked.request_session_id AS blocked_session_id,
	l_blocked.request_request_id AS blocked_request_id,
	l_blocked.request_exec_context_id AS blocked_exec_context_id,
	l_blocked.request_mode AS blocked_request_mode,	
	wt_blocked.wait_duration_ms AS blocked_wait_duration,
	l_blocker.request_session_id AS blocker_session_id,
	l_blocker.request_request_id AS blocker_request_id,
	l_blocker.request_exec_context_id AS blocker_exec_context_id,
	l_blocker.request_mode AS blocker_request_mode,
	l_blocker.request_status AS blocker_lock_status,
	wt_blocked.resource_description AS blocked_resource
FROM sys.dm_os_waiting_tasks AS wt_blocked
INNER JOIN sys.dm_tran_locks AS l_blocked ON
	l_blocked.lock_owner_address = wt_blocked.resource_address
INNER JOIN sys.dm_os_tasks AS t_blocker ON 
	t_blocker.task_address = wt_blocked.blocking_task_address
INNER JOIN sys.dm_tran_locks AS l_blocker ON
	l_blocker.request_session_id = t_blocker.session_id
	AND l_blocker.request_request_id = t_blocker.request_id
	AND l_blocker.request_exec_context_id = t_blocker.exec_context_id
WHERE
	wt_blocked.blocking_session_id <> wt_blocked.session_id
	AND l_blocker.resource_type = l_blocked.resource_type
	AND l_blocker.resource_database_id = l_blocked.resource_database_id
	AND l_blocker.resource_associated_entity_id = l_blocked.resource_associated_entity_id
	AND l_blocker.resource_description = l_blocked.resource_description
GO


--Fire up a second blocked session and try again...



--Use Who is Active to evaluate the blocking chain...
EXEC sp_whoisactive
	@find_block_leaders = 1,
	@sort_order = '[blocked_session_count] desc'
GO




--As an aside... which rows did we modify?
SELECT 
	tl.*
FROM sys.dm_tran_locks AS tl
INNER JOIN sys.partitions AS p ON
	p.hobt_id = tl.resource_associated_entity_id
WHERE 
	p.object_id = OBJECT_ID('Sales.SalesOrderDetail')
	AND tl.resource_type = 'KEY'
GO



--Find the actual rows using the %%LOCKRES%% virtual column
SELECT
	*
FROM Sales.SalesOrderDetail
WHERE
	%%LOCKRES%% IN
	(
		SELECT 
			tl.resource_description
		FROM sys.dm_tran_locks AS tl
		INNER JOIN sys.partitions AS p ON
			p.hobt_id = tl.resource_associated_entity_id
		WHERE 
			p.object_id = OBJECT_ID('Sales.SalesOrderDetail')
			AND tl.resource_type = 'KEY'
	)
GO
	


--Clean up
ROLLBACK
GO

