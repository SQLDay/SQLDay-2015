--Start the buffer latch sqlstress load...


--Look at the waits in sys.dm_os_waiting_tasks
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE 
	wait_type LIKE 'PAGELATCH_%'
GO


--Check them out with Who is Active
EXEC sp_whoisactive
GO

