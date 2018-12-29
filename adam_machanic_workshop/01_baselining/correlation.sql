USE baseline
GO

--(NOTE: both methods use Pearson's Coefficient)

--------------------------------------------
-- value-based correlation
--------------------------------------------

DECLARE @dateid INT = 
	(
		SELECT 
			DateId
		FROM dbo.dates
		WHERE
			TheDate = '2013-03-20'
	)


SELECT
	x.MetricId,
	x.MetricValue,
	x.FifteenMinuteSegmentOfDay
INTO #values
FROM
(
	SELECT 
		f.MetricId,
		f.MetricValue,
		f.FifteenMinuteSegmentOfDay,
		COUNT(*) OVER 
		(
			PARTITION BY
				f.MetricId
		) AS SampleCount,
		MAX(MetricValue) OVER 
		(
			PARTITION BY
				f.MetricId
		) AS MaxValue
	FROM dbo.RecordedMetrics AS f
	WHERE 
		ServerId = 1
		AND DateId = @dateid
		AND EXISTS
		(
			SELECT
				*
			FROM dbo.Metrics AS m
			WHERE
				m.MetricId = f.MetricId
				AND m.MetricCategory = 'Performance Counter'
		)
) AS x
WHERE
	x.SampleCount > 50
	AND x.MaxValue > 0;


CREATE CLUSTERED INDEX ix_metric_segment
ON #values
(
	MetricId, 
	FifteenMinuteSegmentOfDay
);


WITH
n AS
(
	SELECT DISTINCT
		t1.MetricId AS m1, 
		t2.MetricId AS m2 
	FROM 
		#values AS t1,
		#values AS t2
	WHERE
		t1.MetricId < t2.MetricId
)
SELECT 
	l.*,
	(
		SELECT 
			MetricName 
		FROM dbo.Metrics AS m 
		WHERE 
			m.MetricId = n.m1
	) AS m1_name,
	(
		SELECT 
			MetricName
		FROM dbo.Metrics m WHERE
			m.MetricId = n.m2
	) AS m2_name
FROM n
CROSS APPLY
(
	SELECT
		SUM
		(
			(
				(z.xval - z.avgxval) / NULLIF(z.stdevx, 0)
			) *
				(
					(z.yval - z.avgyval) / nullif(z.stdevy, 0)
				)
		) / 
			(MAX(z.numrows) - 1) AS c
	FROM
	(
		SELECT
			x.MetricValue AS xval,
			y.MetricValue AS yval,
			COUNT(*) OVER() AS numrows,
			AVG(x.MetricValue) OVER() AS avgxval,
			AVG(y.MetricValue) OVER() AS avgyval,
			STDEV(x.MetricValue) OVER() AS stdevx,
			STDEV(y.MetricValue) OVER() AS stdevy
		FROM #values AS x
		INNER JOIN #values AS y ON
			x.FifteenMinuteSegmentOfDay = y.FifteenMinuteSegmentOfDay
		WHERE
			x.MetricId = n.m1
			AND y.MetricId = n.m2
	) AS z
) AS l
ORDER BY
	ABS(c) DESC;
GO
	

--------------------------------------------------
-- delta-based correlation
--------------------------------------------------

DECLARE @dateid INT = 
	(
		SELECT 
			DateId
		FROM dbo.dates
		WHERE
			TheDate = '2013-03-20'
	)


SELECT
	*
INTO #deltas
FROM
(
	SELECT 
		x.*,
		MAX(x.delta) OVER
		(
			PARTITION BY
				x.MetricId
		) AS maxd,
		COUNT(*) OVER 
		(
			PARTITION BY
				x.MetricId
		) AS numSamples
	FROM
	(
		SELECT 
			f.*,
			ABS
			(
				(
					SELECT TOP(1) 
						f2.MetricValue 
					FROM dbo.RecordedMetrics AS f2
					WHERE 
						f2.ServerId = 1
						AND f2.MetricId = f.MetricId
						AND f2.DateId = @dateid
						AND f2.FifteenMinuteSegmentOfDay < f.FifteenMinuteSegmentOfDay
					ORDER BY
						f2.FifteenMinuteSegmentOfDay DESC
				) - f.MetricValue
			) AS delta
		FROM dbo.RecordedMetrics AS f
		WHERE
			f.ServerId = 1
			AND f.DateId = @dateid
			AND EXISTS
			(
				SELECT
					*
				FROM dbo.Metrics AS m
				WHERE
					m.MetricId = f.MetricId
					AND m.MetricCategory = 'Performance Counter'
			)
	) AS x
) AS y
WHERE
	y.maxd > 0
	AND y.numsamples >= 50
	AND y.delta IS NOT NULL;


CREATE CLUSTERED INDEX ix_metric_segment
ON #deltas 
(
	MetricId, 
	FifteenMinuteSegmentOfDay
);


WITH
n AS
(
	SELECT DISTINCT
		t1.MetricId AS m1, 
		t2.MetricId AS m2 
	FROM 
		#deltas AS t1,
		#deltas AS t2
	WHERE
		t1.MetricId < t2.MetricId
)
SELECT
	l.*,
	(
		SELECT 
			MetricName 
		FROM dbo.Metrics AS m 
		WHERE 
			m.MetricId = n.m1
	) AS m1_name,
	(
		SELECT 
			MetricName
		FROM dbo.Metrics m WHERE
			m.MetricId = n.m2
	) AS m2_name
FROM n
CROSS APPLY
(
	SELECT
		SUM
		(
			(
				(xval - avgxval) / NULLIF(stdevx, 0)
			) *
				(
					(yval - avgyval) / NULLIF(stdevy, 0)
				)
		) / 
			(MAX(numrows) - 1) AS c
	FROM
	(
		SELECT
			x.delta AS xval,
			y.delta AS yval,
			COUNT(*) OVER() AS numrows,
			AVG(x.delta) OVER() AS avgxval,
			AVG(y.delta) OVER() AS avgyval,
			STDEV(x.delta) OVER() AS stdevx,
			STDEV(y.delta) OVER() AS stdevy
		FROM #deltas AS x
		INNER JOIN #deltas AS y ON
			x.FifteenMinuteSegmentOfDay = y.FifteenMinuteSegmentOfDay
		WHERE
			x.MetricId = m1
			AND y.MetricId = m2
	) AS z
) AS l
ORDER BY
	ABS(c) DESC;
GO

