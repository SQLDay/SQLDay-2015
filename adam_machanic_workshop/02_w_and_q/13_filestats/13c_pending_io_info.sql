
--Get more information about pending I/O requests
SELECT 
	*	
FROM [sys].dm_io_virtual_file_stats(NULL,NULL) AS fs
INNER JOIN sys.dm_io_pending_io_requests AS r ON
	r.io_handle = fs.file_handle;
GO



--Get the pending I/O count per scheduler
SELECT
	scheduler_id,
	pending_disk_io_count
FROM sys.dm_os_schedulers
WHERE
	status = 'VISIBLE ONLINE'
GO



--NOTE: "pending" counts in workers/tasks DMV are CUMULATIVE
--And remember, workers persist beyond the life of the task
SELECT
	s.session_id,
	SUM(t.pending_io_count) AS task_io_count,
	SUM(w.pending_io_count) AS worker_io_count
FROM sys.dm_exec_sessions AS s
INNER JOIN sys.dm_os_tasks AS t ON 
	t.session_id = s.session_id
INNER JOIN sys.dm_os_workers AS w ON
	w.worker_address = t.worker_address
WHERE
	s.is_user_process = 1
GROUP BY
	s.session_id
GO

