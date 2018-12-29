-- quick waits report
-- configure @waittime and wait for results

DECLARE 
	@waittime VARCHAR(10) = '00:00:10',
	@recursion TINYINT = 0;


DECLARE @t TABLE 
(
	id INT IDENTITY(1,1),
	wait_type SYSNAME,
	waiting_tasks_count BIGINT,
	wait_time_ms BIGINT,
	signal_wait_time_ms BIGINT,
	dt DATETIME
);

WHILE @recursion <= 1
BEGIN
	DECLARE @dt DATETIME = GETDATE();
	
	INSERT @t
	(
		wait_type,
		waiting_tasks_count,
		wait_time_ms,
		signal_wait_time_ms,
		dt
	)
	SELECT 
		wait_type,
		waiting_tasks_count,
		wait_time_ms,
		signal_wait_time_ms,
		@dt
	FROM sys.dm_os_wait_stats;
	
	IF @recursion < 1
		WAITFOR DELAY @waittime;
	
	SET @recursion = @recursion + 1;
END

SELECT
	c.wait_type,
	c.waiting_tasks_count_delta,
	c.wait_time_ms_delta,
	(100. * c.wait_time_ms_delta) / NULLIF(MAX(c.wait_time_ms_delta) OVER (), 0) AS pct_of_total_wait,
	c.signal_wait_time_ms_delta,
	c.first_capture_time,
	c.last_capture_time
FROM
(
	SELECT
		COALESCE(d.wait_type, '## TOTAL ##') AS wait_type,
		SUM(d.waiting_tasks_count_delta) AS waiting_tasks_count_delta,
		SUM(d.wait_time_ms_delta) AS wait_time_ms_delta,
		CASE 
			WHEN d.wait_type IS NULL THEN SUM(d.signal_wait_time_ms_delta) 
			ELSE NULL
		END AS signal_wait_time_ms_delta,
		CASE 
			WHEN d.wait_type IS NULL THEN MIN(minTime) 
			ELSE NULL
		END AS first_capture_time,
		CASE 
			WHEN d.wait_type IS NULL THEN MAX(maxTime)
			ELSE NULL
		END AS last_capture_time
	FROM
	(
		SELECT 
			maxData.wait_type,
			maxData.waiting_tasks_count - COALESCE(minData.waiting_tasks_count, 0) AS waiting_tasks_count_delta,
			(maxData.wait_time_ms - maxData.signal_wait_time_ms) - COALESCE((minData.wait_time_ms - minData.signal_wait_time_ms), 0) AS wait_time_ms_delta,
			maxData.signal_wait_time_ms - minData.signal_wait_time_ms AS signal_wait_time_ms_delta,
			minData.dt AS minTime,
			maxData.dt AS maxTime
		FROM @t AS maxData
		INNER JOIN @t AS minData ON
			minData.wait_type = maxData.wait_type
			AND minData.id < maxData.id
		WHERE
			maxData.wait_type NOT IN 
			(
				'CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
				'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','LOGMGR_QUEUE',
				'REQUEST_FOR_DEADLOCK_SEARCH','XE_TIMER_EVENT','BROKER_TO_FLUSH',
				'BROKER_TASK_STOP', 'OLEDB', 'FT_IFTS_SCHEDULER_IDLE_WAIT'
			)
	) AS d
	GROUP BY GROUPING SETS ((d.wait_type), ())
) AS c
WHERE
	c.waiting_tasks_count_delta > 0
ORDER BY
	CASE 
		WHEN wait_type = '## TOTAL ##' THEN 1
		ELSE 99 
	END,
	pct_of_total_wait DESC;