/*************************************************
NOTE:

If you see a number in comments, like this:

/*1*/

... go to the other script and run the code with 
the same number to get the demo working. This is 
how I write myself notes in my demo scripts.
*************************************************/


--Execution environment


--Legacy
SELECT *
FROM sys.sysprocesses
GO



--Session-based information
SELECT *
FROM sys.dm_exec_sessions
GO



--Requests -- related to sessions via session_id
SELECT
	s.login_name,
	s.session_id,
	s.status,
	s.memory_usage,
	r.granted_query_memory,
	r.cpu_time,
	r.reads,
	r.logical_reads,
	r.writes,
	r.percent_complete,
	r.estimated_completion_time
FROM sys.dm_exec_sessions AS s 
LEFT OUTER JOIN sys.dm_exec_requests AS r ON
	s.session_id = r.session_id
WHERE
	s.is_user_process = 1
GO




/*2*/

--Execution details
SELECT 
	sql_handle,
	plan_handle
FROM sys.dm_exec_requests
WHERE
	--SPID from other window
	session_id = 53
GO



SELECT *
FROM sys.dm_exec_sql_text(0x02000000B3A401369CC352FF7B1AA2E214339395654ABB36)
GO



--use XML?
SELECT 
	text AS [text()]
FROM sys.dm_exec_sql_text(0x02000000B3A401369CC352FF7B1AA2E214339395654ABB36)
FOR XML 
	PATH('query')
GO



--Get only the statement actually running?
SELECT 
	sql_handle,
	plan_handle,
	statement_start_offset,
	statement_end_offset
FROM sys.dm_exec_requests
WHERE
	session_id = 53
GO



DECLARE
	@start INT = 64,
	@end INT = 118

--The text is stored in Unicode format, and start/end are byte offsets...
SELECT 
	SUBSTRING(text, @start/2, (@end - @start)/2)
FROM sys.dm_exec_sql_text(0x02000000B3A401369CC352FF7B1AA2E214339395654ABB36)
GO



--Query plan?
SELECT *
FROM sys.dm_exec_query_plan(0x06000100B3A40136B8805410000000000000000000000000)
GO



--Byte offsets also work here!
SELECT *
FROM sys.dm_exec_text_query_plan
(
	0x06000100B3A40136B8805410000000000000000000000000,
	64,
	118
)
GO



--...better
SELECT 
	CONVERT(XML, query_plan)
FROM sys.dm_exec_text_query_plan
(
	0x06000100B3A40136B8805410000000000000000000000000,
	64,
	118
)
GO


--Note, these things block...




--Transaction Information

/*3a*/

--What locks are being held?
SELECT *
FROM sys.dm_tran_locks



--Get information about tran log activity
SELECT
	DB_NAME(dt.database_id) AS database_name,
	dt.database_transaction_begin_time,
	dt.database_transaction_log_record_count,
	dt.database_transaction_log_bytes_used
FROM sys.dm_tran_session_transactions AS st
INNER JOIN sys.dm_tran_database_transactions AS dt ON 
	st.transaction_id = dt.transaction_id
WHERE
	st.session_id = 55
	
--... /*3b*/ ...
GO



--Query Processor Components

--General system info
SELECT *
FROM sys.dm_os_sys_info
GO


/*4*/


--Find blockers?
SELECT *
FROM sys.dm_exec_requests
WHERE 
	blocking_session_id <> 0
GO



--Better...
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	session_id <> blocking_session_id
GO



--Get all waiting task info
SELECT *
FROM sys.dm_os_waiting_tasks
WHERE
	session_id = 54
GO



--Get information on active tasks - including realtime metrics
SELECT
	*
FROM sys.dm_os_tasks
WHERE
	session_id = 54
GO



--Full sysprocesses-style report, with metrics and waits?
SELECT
	s.session_id,
	s.login_time,
	s.login_name,
	s.host_name,
	s.program_name,	
	t.context_switches_count,
	t.pending_io_count,
	t.pending_io_byte_count,
	wt.wait_type,
	wt.wait_duration_ms,
	wt.resource_description,
	CASE 
		WHEN wt.blocking_session_id <> wt.session_id THEN wt.blocking_session_id
		ELSE NULL
	END AS blocking_session_id
FROM sys.dm_exec_sessions AS s
JOIN sys.dm_exec_requests AS r ON 
	r.session_id = s.session_id
JOIN sys.dm_os_tasks AS t ON 
	t.session_id = s.session_id
	AND t.request_id = r.request_id
JOIN sys.dm_os_waiting_tasks AS wt ON
	wt.waiting_task_address = t.task_address
WHERE
	s.is_user_process = 1
GO


/*5*/

--TempDB
SELECT *
FROM sys.dm_db_task_space_usage
WHERE
	session_id = 54
GO

SELECT *
FROM sys.dm_db_session_space_usage
WHERE
	session_id = 54
GO




--Putting it all together...
EXEC sp_whoisactive
	@get_task_info = 2,
	@show_sleeping_spids = 2,
	@get_plans = 1
GO

