
--run the simulate_slow_app project


--Note wait_duration_ms
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	wait_type = 'ASYNC_NETWORK_IO'
GO

