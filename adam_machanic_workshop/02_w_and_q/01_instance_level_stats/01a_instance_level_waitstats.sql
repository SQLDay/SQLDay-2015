
--Flashback
DBCC SQLPERF(waitstats)
GO



--SQL Server 2005+
SELECT *
FROM sys.dm_os_wait_stats
GO



--Ignore waits for which we haven't had a wait
SELECT 
	*, 
	((wait_time_ms - signal_wait_time_ms) * 1.) / waiting_tasks_count AS avg_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE
	waiting_tasks_count > 0
ORDER BY
	max_wait_time_ms DESC
GO



