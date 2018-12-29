CREATE DATABASE [testlog] 
ON PRIMARY
(
	NAME = N'testlog', 
	FILENAME = N'C:\temp\testlog.mdf', 
	SIZE = 4096KB, 
	FILEGROWTH = 1024KB 
)
LOG ON
(
	NAME = N'testlog_log', 
	FILENAME = N'C:\temp\testlog_log.ldf', 
	SIZE = 1024KB,
	--Nice big grow that should take a long time
	FILEGROWTH = 6144000KB
)
GO


USE testlog
GO


CREATE TABLE x (i INT);

INSERT x 
SELECT 1
GO


BEGIN TRAN
GO

INSERT x
SELECT * 
FROM x
GO 1000



--meanwhile go to another window and...
CREATE TABLE y (i INT)
GO



--and in a third window...
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	wait_type LIKE 'PREEMPTIVE%'
	OR wait_type LIKE 'LATCH%'
GO



--Clean up
ROLLBACK
GO
USE master
GO
DROP DATABASE testlog
GO