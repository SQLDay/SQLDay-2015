SET STATISTICS TIME ON
GO

DBCC SQLPERF(waitstats, clear)
GO

IF OBJECT_ID('tempdb..#x') IS NOT NULL
	DROP TABLE #x
GO

WITH
nums AS
(
	SELECT 
		number
	FROM master..spt_values
	WHERE 
		type = 'p'
		AND number BETWEEN 1 AND 10
)
SELECT 
	POWER(2, a.number)
		+ POWER(2,b.number)
		+ POWER(2, c.number)
		+ POWER(2, d.number)
		+ POWER(2, e.number)
		+ POWER(2, f.number) AS x
INTO #x
FROM
	nums AS a, 
	nums AS b, 
	nums AS c, 
	nums AS d, 
	nums AS e, 
	nums AS f
OPTION (MAXDOP 1)
go


--look at elapsed time
--divide by 4 (quantum duration)
SELECT 532 / 4
go


--check out sos_scheduler_yield...
SELECT *
FROM sys.dm_os_wait_stats
WHERE
	wait_type = 'sos_scheduler_yield'
GO


--Try again, with some scheduler pressure
USE AdventureWorks
GO

--8 cooperatively scheduled threads, which will only yield every 200ms
EXEC startSeeding
	@numThreads = 8,
	@useAffinity = 0, 
	@yieldMS = 200
GO


--[new window]

--Why is it slower?
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE 
	session_id = [other window's session]
GO



--Find stuff on the runnable queue
SELECT 	
	(
		SELECT 
			ms_ticks 
		FROM sys.dm_os_sys_info
	) - 
		w.wait_resumed_ms_ticks
FROM sys.dm_os_workers AS w
JOIN sys.dm_os_tasks AS t ON
	t.worker_address = w.worker_address
WHERE
	t.session_id = 53
GO



--Check out Who is Active's "RUNNABLE" wait type
EXEC sp_whoisactive 
	@get_task_info = 2
GO



--Clean up
EXEC stopSeeding
GO

