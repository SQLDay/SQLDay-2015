USE baseline
GO

DECLARE @date DATE = '2013-03-20'

--Why is it slow?!?! 
--Let's ask!
SELECT
	threeWeekAverage.MetricName,
	threeWeekAverage.AvgMetricValue AS NormalValue,
	threeWeekAverage.StandardDeviation AS NormalDeviation,
	interestingSegment.AvgMetricValue AS InterestingValue,
	(
		(interestingSegment.AvgMetricValue - (ABS(threeWeekAverage.AvgMetricValue) + threeWeekAverage.StandardDeviation)) / 
			ISNULL(NULLIF((ABS(threeWeekAverage.AvgMetricValue) + threeWeekAverage.StandardDeviation), 0), 1)
	) * 100 AS DifferenceFromNormal
FROM
(
	SELECT TOP(2147483647)
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
		AND d.TheDate BETWEEN DATEADD(week, -3, @date) AND DATEADD(day, -1, @date)
		AND d.NameOfDay NOT IN ('Saturday', 'Sunday')
		AND f.SegmentOfDay = 'Afternoon'
		AND m.MetricCategory = 'Performance Counter'
	GROUP BY
		m.MetricId,
		m.MetricName
) AS threeWeekAverage
INNER JOIN
(
	SELECT TOP(2147483647)
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
		AND d.TheDate = @date
		AND d.NameOfDay NOT IN ('Saturday', 'Sunday')
		AND f.SegmentOfDay = 'Afternoon'
		AND m.MetricCategory = 'Performance Counter'
	GROUP BY
		m.MetricId
) AS interestingSegment ON
	interestingSegment.MetricId = threeWeekAverage.MetricId
ORDER BY
	DifferenceFromNormal DESC
GO


--Are things getting worse? Better? Not changing at all?
--Linear regression can give us an indication...

DECLARE @date DATE = '2013-03-20'

;WITH
segmented_metrics AS
(
	SELECT TOP(2147483647)
		m.MetricName,
		r.MetricValue,
		DENSE_RANK() OVER
		(
			ORDER BY
				r.DateId
		) AS DateNumber
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
		AND d.TheDate BETWEEN DATEADD(week, -3, @date) AND @date
		AND d.NameOfDay NOT IN ('Saturday', 'Sunday')
		AND f.SegmentOfDay = 'Afternoon'
		AND m.MetricCategory = 'Performance Counter'
),
average AS
(
	SELECT 
		MAX(DateNumber) / COUNT(*) AS xbar,
		AVG(MetricValue) AS ybar,
		s.MetricName
	FROM segmented_metrics AS s
	GROUP BY
		s.MetricName
),
beta AS
(   
	SELECT      
		SUM((pd.DateNumber - pa.xbar) * (pd.MetricValue - pa.ybar)) / 
			SUM(SQUARE((pd.DateNumber - pa.xbar))) AS Beta,
		pd.MetricName
	FROM segmented_metrics AS pd 
	INNER JOIN average AS pa ON
		pd.MetricName = pa.MetricName
	GROUP BY
		pd.MetricName
)
SELECT
	pa.MetricName,
	pa.ybar - (pa.xbar * pb.Beta) AS Alpha,
	pb.Beta,
	(pb.Beta / ISNULL(NULLIF((pa.ybar - pa.xbar * pb.Beta), 0), 1)) * 100 AS SlopePercent
FROM beta AS pb
INNER JOIN average AS pa ON 
	pb.metricname = pa.metricname
ORDER BY
	ABS((pb.Beta / ISNULL(NULLIF((pa.ybar - pa.xbar * pb.Beta), 0), 1))) DESC
GO

