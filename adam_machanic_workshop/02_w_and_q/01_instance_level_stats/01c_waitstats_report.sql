IF EXISTS (SELECT * FROM sys.objects WHERE [object_id] = OBJECT_ID(N'[dbo].[report_wait_stats]') and OBJECTPROPERTY([object_id], N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[report_wait_stats];
GO

CREATE PROCEDURE [dbo].[report_wait_stats]
(
	--date/time range
	@start_time DATETIME = NULL,
	@end_time DATETIME = NULL
)
AS
BEGIN
	SET NOCOUNT ON

	IF OBJECT_ID( N'[dbo].[wait_stats]', N'U') IS NULL
	BEGIN
		RAISERROR('Error [dbo].[wait_stats] table does not exist', 16, 1) WITH NOWAIT;
		RETURN;
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
				WHEN d.wait_type IS NULL THEN MIN(min_and_max.minTime) 
				ELSE NULL
			END AS first_capture_time,
			CASE 
				WHEN d.wait_type IS NULL THEN MAX(min_and_max.maxTime)
				ELSE NULL
			END AS last_capture_time
		FROM
		(
			SELECT
				MIN(capture_time) AS minTime,
				MAX(capture_time) AS maxTime
			FROM wait_stats
			WHERE
				capture_time BETWEEN COALESCE(@start_time, '19000101') AND COALESCE(@end_time, '99991231')
		) AS min_and_max
		CROSS APPLY
		(
			SELECT 
				maxData.wait_type,
				maxData.waiting_tasks_count - minData.waiting_tasks_count AS waiting_tasks_count_delta,
				--Subtract signal time from wait time to get the actual wait
				(maxData.wait_time_ms - maxData.signal_wait_time_ms) - (minData.wait_time_ms - minData.signal_wait_time_ms) AS wait_time_ms_delta,
				maxData.signal_wait_time_ms - minData.signal_wait_time_ms AS signal_wait_time_ms_delta
			FROM wait_stats AS maxData
			INNER JOIN wait_stats AS minData ON 
				minData.wait_type = maxData.wait_type
			WHERE
				maxData.capture_time = min_and_max.maxTime
				AND minData.capture_time = min_and_max.minTime
				AND maxData.wait_type NOT IN 
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
		pct_of_total_wait DESC;
END
GO


