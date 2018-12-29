
--Create a linked server
EXEC sp_addlinkedserver 
	@server = N'loopback',
	@srvproduct = N' ',
	@provider = N'SQLNCLI', 
	@datasrc = @@SERVERNAME
GO


--new window: Wait :-)
SELECT
	*
FROM OPENQUERY(loopback, 'WAITFOR DELAY ''00:10:10'' SELECT 1')
GO




--great info in sys.dm_os_waiting_tasks!
SELECT * 
FROM sys.dm_os_waiting_tasks
WHERE 
	wait_type = 'OLEDB'
GO





--Clean up
EXEC sp_dropserver 'loopback'
GO

