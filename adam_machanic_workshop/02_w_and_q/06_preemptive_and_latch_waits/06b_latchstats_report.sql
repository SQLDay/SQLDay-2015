-- quick report on latches
-- configure @waittime and wait for results


DECLARE 
	@waittime VARCHAR(10) = '00:00:05',
	@recursion TINYINT = 0;

DECLARE @t TABLE 
(
	id INT IDENTITY(1,1), 
	latch_class SYSNAME, 
	waiting_requests_count BIGINT, 
	wait_time_ms BIGINT, 
	max_wait_time_ms BIGINT
);

WHILE @recursion <= 1
BEGIN
	INSERT @t
	(
 		latch_class, 
		waiting_requests_count,
		wait_time_ms,
		max_wait_time_ms
	)
	SELECT
		latch_class,
		waiting_requests_count,
		wait_time_ms,
		max_wait_time_ms
	FROM sys.dm_os_latch_stats;

	IF @recursion < 1
		WAITFOR DELAY @waittime;

	SET @recursion = @recursion + 1;
END

SELECT 
	v.*,
	(v.wait_time_ms * 1.) / v.waiting_requests_count AS wait_time_ms_per_request
FROM 
(
	SELECT 
		T1.latch_class,
		(AVG(T2.waiting_requests_count - T1.waiting_requests_count)) waiting_requests_count,
		(AVG(T2.wait_time_ms - T1.wait_time_ms)) wait_time_ms,
		(AVG(T2.max_wait_time_ms - T1.max_wait_time_ms)) max_wait_time_ms
	FROM @T AS t1
	JOIN @T AS t2 ON
		T1.latch_class = T2.latch_class
		AND t1.id < T2.id
	GROUP BY 
		T1.latch_class
) AS v
WHERE 
	waiting_requests_count > 0
ORDER BY 
	3 DESC,
	2 DESC;
