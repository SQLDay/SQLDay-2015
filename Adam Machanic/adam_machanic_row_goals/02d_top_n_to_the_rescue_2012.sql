--TOP(N) to the Rescue!
--(SQL Server 2012)
USE baseline
GO




SET STATISTICS IO ON
GO




SELECT
	threeWeekAverage.MetricName,
	threeWeekAverage.AvgMetricValue AS NormalValue,
	threeWeekAverage.StandardDeviation AS NormalDeviation,
	interestingSegment.AvgMetricValue AS InterestingValue,
	(
		(interestingSegment.AvgMetricValue - threeWeekAverage.AvgMetricValue) / 
			ISNULL(NULLIF(threeWeekAverage.AvgMetricValue, 0), 1)
	) * 100 AS DifferenceFromNormal
FROM
(
	SELECT --TOP(2147483647)
		m.MetricId,
		m.MetricName,
		AVG(r.MetricValue) AS AvgMetricValue,
		STDEV(r.MetricValue) AS StandardDeviation
	FROM dbo.RecordedMetrics AS r
	INNER JOIN dbo.FifteenMinuteSegments AS f ON 
		r.FifteenMinuteSegmentOfDay = f.FifteenMinuteSegmentOfDay
	INNER JOIN dbo.Dates AS d ON 
		d.DateId = r.DateId
	INNER JOIN dbo.Metrics AS m ON 
		m.MetricId = r.MetricId
	INNER JOIN dbo.Servers AS s ON 
		s.ServerId = r.ServerId
	WHERE
		s.ServerName = 'Server1'
		AND d.TheDate BETWEEN DATEADD(week, -3, '2013-03-20') AND DATEADD(day, -1, '2013-03-20')
		AND d.NameOfDay NOT IN ('Saturday', 'Sunday')
		AND f.SegmentOfDay = 'Afternoon'
		AND m.MetricCategory = 'Performance Counter'
	GROUP BY
		m.MetricId,
		m.MetricName
) AS threeWeekAverage
INNER JOIN
(
	SELECT
		m.MetricId,
		AVG(r.MetricValue) AS AvgMetricValue
	FROM dbo.RecordedMetrics AS r
	INNER JOIN dbo.FifteenMinuteSegments AS f ON
		r.FifteenMinuteSegmentOfDay = f.FifteenMinuteSegmentOfDay
	INNER JOIN dbo.Dates AS d ON 
		d.DateId = r.DateId
	INNER JOIN dbo.Metrics AS m ON 
		m.MetricId = r.MetricId
	INNER JOIN dbo.Servers AS s ON 
		s.ServerId = r.ServerId
	WHERE
		s.ServerName = 'Server1'
		AND d.TheDate = '2013-03-20'
		AND d.NameOfDay NOT IN ('Saturday', 'Sunday')
		AND f.SegmentOfDay = 'Afternoon'
		AND m.MetricCategory = 'Performance Counter'
	GROUP BY
		m.MetricId
) AS interestingSegment ON
	interestingSegment.MetricId = threeWeekAverage.MetricId
ORDER BY
	(interestingSegment.AvgMetricValue - threeWeekAverage.AvgMetricValue) / 
		ISNULL(NULLIF(threeWeekAverage.AvgMetricValue, 0), 1) DESC
GO
