SELECT
	t.session_id,
	ct.type,
	ct.forced_yield_count,
	w.is_preemptive,
	w.scheduler_address
FROM sys.dm_clr_tasks AS ct
JOIN sys.dm_os_tasks AS t ON
	t.task_address = ct.sos_task_address
JOIN sys.dm_os_workers AS w ON
	w.worker_address = t.worker_address
