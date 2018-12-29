USE baseline
GO

--what if we could do graphing in SSMS..?

DECLARE @date DATE = '2013-03-30'

DECLARE @vz dbo.VisualizationFormat

INSERT @vz
(
	x_axis,
	y_axis,
	x_axis_partition
)
SELECT
	ROW_NUMBER() OVER 
	(
		ORDER BY 
			d.DateId, 
			t.FifteenMinuteSegmentOfDay
	),
	AVG(r.MetricValue) AS MetricValue,
	d.DateId
FROM dbo.RecordedMetrics AS r
INNER JOIN dbo.FifteenMinuteSegments AS t ON 
	r.FifteenMinuteSegmentOfDay = t.FifteenMinuteSegmentOfDay
INNER JOIN dbo.Dates AS d ON 
	d.DateId = r.DateId
INNER JOIN dbo.Metrics AS m ON 
	m.MetricId = r.MetricId
INNER JOIN dbo.Servers AS s ON 
	s.ServerId = r.ServerId
WHERE
	s.ServerName = 'Server1'
	AND m.MetricName = 'Disk Read Bytes/sec : F:\UserDBLog4'
	AND d.TheDate BETWEEN DATEADD(week, -3, @date) AND @date
	AND d.NameOfDay NOT IN ('Saturday', 'Sunday')
	AND t.SegmentOfDay = 'Afternoon'
GROUP BY
	t.FifteenMinuteSegmentOfDay,
	d.DateId

SELECT *
FROM dbo.VisualizationBox(@vz)

UNION ALL

SELECT *
FROM dbo.VisualizationLine(@vz)

UNION ALL

SELECT *
FROM dbo.VisualizationPartitionedLinearRegression(@vz)

GO



CREATE TYPE dbo.VisualizationFormat
AS TABLE
(
	x_axis INT NOT NULL PRIMARY KEY,
	y_axis FLOAT NOT NULL,
	x_axis_partition INT NULL
)
GO


CREATE FUNCTION VisualizationBox
(
	@vz dbo.VisualizationFormat READONLY
)
RETURNS TABLE
AS
RETURN
(
	SELECT
		geometry::STGeomFromText
		(
			'POLYGON 
			((' + 
				CONVERT(VARCHAR, MIN(x_axis)-1) + ' ' + CONVERT(VARCHAR, MIN(y_axis)-1) + ',' + 
				CONVERT(VARCHAR, MAX(x_axis)+1) + ' ' + CONVERT(VARCHAR, MIN(y_axis)-1) + ',' + 
				CONVERT(VARCHAR, MAX(x_axis)+1) + ' ' + CONVERT(VARCHAR, MAX(y_axis)+1) + ',' +
				CONVERT(VARCHAR, MIN(x_axis)-1) + ' ' + CONVERT(VARCHAR, MAX(y_axis)+1) + ',' + 
				CONVERT(VARCHAR, MIN(x_axis)-1) + ' ' + CONVERT(VARCHAR, MIN(y_axis)-1) + 
			')) ', 
			0
		).STBuffer(p.STBuffer) AS shape
	FROM
	(
		SELECT
			v.x_axis, 
			v.y_axis * factors.y_axis_scale_factor AS y_axis,
			factors.STBuffer
		FROM @vz AS v
		CROSS JOIN
		(
			SELECT 
				((MAX(x_axis) - MIN(x_axis)) / (MAX(y_axis) - MIN(y_axis))) * 0.55 AS y_axis_scale_factor,
				((MAX(x_axis) - MIN(x_axis)) / 100) * 0.25 AS STBuffer
			FROM @vz
		) AS factors
	) AS p
	GROUP BY
		p.STBuffer
)
GO


CREATE FUNCTION VisualizationPoints
(
	@vz dbo.VisualizationFormat READONLY
)
RETURNS TABLE
AS
RETURN
(
	SELECT
		geometry::STGeomCollFromText
		(
			'GEOMETRYCOLLECTION( ' +
				STUFF
				(
					(
						SELECT
							',POINT (' + CONVERT(VARCHAR, p.x_axis) + ' ' + CONVERT(VARCHAR, p.y_axis) + ')'
						FROM
						(
							SELECT
								v.x_axis, 
								v.y_axis * factors.y_axis_scale_factor AS y_axis
							FROM @vz AS v
							CROSS JOIN
							(
								SELECT 
									((MAX(x_axis) - MIN(x_axis)) / (MAX(y_axis) - MIN(y_axis))) * 0.55 AS y_axis_scale_factor
								FROM @vz
							) AS factors
						) AS p
						FOR XML 
							PATH(''),
							TYPE
					).value('.', 'VARCHAR(MAX)'),
					1,
					1,
					''
				) + 
			')', 
			0
		).STBuffer(q.STBuffer) AS shape
	FROM
	(
		SELECT
			((MAX(x_axis) - MIN(x_axis)) / 100) * 0.25 AS STBuffer
		FROM @vz
	) AS q
)
GO


CREATE FUNCTION VisualizationLine
(
	@vz dbo.VisualizationFormat READONLY
)
RETURNS TABLE
AS
RETURN
(
	SELECT
		geometry::STGeomFromText
		(
			'LINESTRING( ' +		
				STUFF
				(
					(
						SELECT
							',' + CONVERT(VARCHAR, p.x_axis) + ' ' + CONVERT(VARCHAR, p.y_axis)
						FROM
						(
							SELECT
								v.x_axis, 
								v.y_axis * factors.y_axis_scale_factor AS y_axis
							FROM @vz AS v
							CROSS JOIN
							(
								SELECT 
									((MAX(x_axis) - MIN(x_axis)) / (MAX(y_axis) - MIN(y_axis))) * 0.55 AS y_axis_scale_factor
								FROM @vz
							) AS factors
						) AS p
						FOR XML 
							PATH(''), 
							TYPE
					).value('.', 'VARCHAR(MAX)'),
					1,
					1,
					''
				) + 
			')', 
			0
		).STBuffer(q.STBuffer) AS shape
	FROM
	(
		SELECT
			((MAX(x_axis) - MIN(x_axis)) / 100) * 0.25 AS STBuffer
		FROM @vz
	) AS q
)
GO


--standard linear regression
CREATE FUNCTION VisualizationLinearRegression
(
	@vz dbo.VisualizationFormat READONLY
)
RETURNS TABLE
AS
RETURN
(
	WITH
	average AS
	(
		SELECT 
			MAX(x_axis) / COUNT(*) AS xbar,
			AVG(y_axis) AS ybar,
			MAX(x_axis) as maxx,
			MIN(x_axis) as minx
		FROM @vz AS s
	),
	beta AS
	(   
		SELECT      
			SUM((pd.x_axis - pa.xbar) * (pd.y_axis - pa.ybar)) / 
				SUM(SQUARE((pd.x_axis - pa.xbar))) AS Beta
		FROM @vz AS pd 
		CROSS JOIN average AS pa
	)
	SELECT
		geometry::STGeomFromText
		(
			'LINESTRING( ' +
				STUFF
				(
					(
						SELECT
							',' + CONVERT(VARCHAR, p.x_axis) + ' ' + CONVERT(VARCHAR, p.y_axis)
						FROM
						(
							SELECT
								CASE x.n 
									WHEN 1 THEN r.minx 
									ELSE r.maxx 
								END AS x_axis,
								CASE x.n 
									WHEN 1 THEN r.beta + r.alpha 
									ELSE (r.maxx * r.beta) + r.alpha 
								END * factors.y_axis_scale_factor AS y_axis 
							FROM
							(
								SELECT
									pa.ybar - (pa.xbar * pb.Beta) AS Alpha,
									pb.Beta,
									pa.minx,
									pa.maxx
								FROM beta AS pb
								CROSS JOIN average AS pa
							) AS r
							CROSS JOIN
							(
								SELECT 1
								UNION ALL
								SELECT 2
							) AS x (n)
							CROSS JOIN
							(
								SELECT 
									((MAX(x_axis) - MIN(x_axis)) / (MAX(y_axis) - MIN(y_axis))) * 0.55 AS y_axis_scale_factor
								FROM @vz
							) AS factors
						) AS p
						ORDER BY 
							p.x_axis
						FOR XML 
							PATH(''), 
							TYPE
					).value('.', 'VARCHAR(MAX)'),
					1,
					1,
					''
				) + 
			')', 
			0
		).STBuffer(q.STBuffer) AS shape
	FROM
	(
		SELECT
			((MAX(x_axis) - MIN(x_axis)) / 100) * 0.25 AS STBuffer
		FROM @vz
	) AS q
)
GO



--Theil-Sen regression: better elimination of outliers
CREATE FUNCTION VisualizationTheilSenLinearRegression
(
	@vz dbo.VisualizationFormat READONLY
)
RETURNS TABLE
AS
RETURN
(
	SELECT
		geometry::STGeomFromText
		(
			'LINESTRING( ' +
				STUFF
				(
					(
						SELECT
							',' + CONVERT(VARCHAR, final.x_axis) + ' ' + CONVERT(VARCHAR, final.y_axis * factors.y_axis_scale_factor)
						FROM
						(
							SELECT
								v4.x_axis,
								(z3.alpha * v4.x_axis) + z3.beta AS y_axis					
							FROM
							(
								SELECT
									MAX(z2.alpha) AS alpha,
									AVG(z2.beta) AS beta
								FROM
								(
									SELECT
										z1.*,
										ROW_NUMBER() OVER 
										(
											ORDER BY
												z1.beta,
												z1.x_axis
										) AS rn,
										ROW_NUMBER() OVER 
										(
											ORDER BY
												z1.beta DESC,
												z1.x_axis DESC
										) AS rnd
									FROM
									(
										SELECT
											v3.x_axis,
											z.slope AS alpha,
											v3.y_axis - (z.slope * v3.x_axis) AS beta	
										FROM
										(
											SELECT
												AVG(y.slope) AS slope
											FROM
											(
												SELECT
													x.*,
													ROW_NUMBER() OVER 
													(
														ORDER BY
															x.slope,
															x.v1x,
															x.v2x
													) AS rn,
													ROW_NUMBER() OVER 
													(
														ORDER BY
															x.slope DESC,
															x.v1x DESC,
															x.v2x DESC
													) AS rnd
												FROM
												(
													SELECT 
														v1.x_axis AS v1x,
														v2.x_axis AS v2x,
														(v2.y_axis - v1.y_axis) / NULLIF((v2.x_axis - v1.x_axis), 0) AS slope
													FROM @vz AS v1
													INNER JOIN @vz AS v2 ON
														v1.x_axis > v2.x_axis
												) AS x
											) AS y
											WHERE
												y.rn IN (y.rnd, y.rnd - 1, y.rnd + 1)
										) AS z
										CROSS JOIN @vz AS v3
									) AS z1
								) AS z2
								WHERE
									z2.rn IN (z2.rnd, z2.rnd - 1, z2.rnd + 1)
							) AS z3
							CROSS JOIN @vz AS v4
						) AS final
						CROSS JOIN
						(
							SELECT 
								((MAX(x_axis) - MIN(x_axis)) / (MAX(y_axis) - MIN(y_axis))) * 0.55 AS y_axis_scale_factor
							FROM @vz
						) AS factors
						ORDER BY 
							final.x_axis
						FOR XML 
							PATH(''), 
							TYPE
					).value('.', 'VARCHAR(MAX)'),
					1,
					1,
					''
				) + 
			')', 
			0
		).STBuffer(q.STBuffer) AS shape
	FROM
	(
		SELECT
			((MAX(x_axis) - MIN(x_axis)) / 100) * 0.25 AS STBuffer
		FROM @vz
	) AS q
)
GO




CREATE FUNCTION VisualizationPartitionedLinearRegression
(
	@vz dbo.VisualizationFormat READONLY
)
RETURNS TABLE
AS
RETURN
(
	WITH
	average AS
	(
		SELECT 
			MAX(x_axis) / COUNT(*) AS xbar,
			AVG(y_axis) AS ybar,
			MAX(x_axis) as maxx,
			MIN(x_axis) as minx,
			s.x_axis_partition
		FROM @vz AS s
		GROUP BY
			s.x_axis_partition
	),
	beta AS
	(   
		SELECT      
			SUM((pd.x_axis - pa.xbar) * (pd.y_axis - pa.ybar)) / 
				SUM(SQUARE((pd.x_axis - pa.xbar))) AS Beta,
			pd.x_axis_partition
		FROM @vz AS pd 
		INNER JOIN average AS pa ON
			pd.x_axis_partition = pa.x_axis_partition
		GROUP BY
			pd.x_axis_partition
	)
	SELECT
		geometry::STGeomFromText
		(
			'LINESTRING( ' +
				STUFF
				(
					(
						SELECT
							',' + CONVERT(VARCHAR, p.x_axis) + ' ' + CONVERT(VARCHAR, p.y_axis)
						FROM
						(
							SELECT
								CASE x.n 
									WHEN 1 THEN r.minx 
									ELSE r.maxx 
								END AS x_axis,
								CASE x.n 
									WHEN 1 THEN r.beta + r.alpha 
									ELSE (r.maxx * r.beta) + r.alpha 
								END * factors.y_axis_scale_factor AS y_axis 
							FROM
							(
								SELECT
									pa.ybar - (pa.xbar * pb.Beta) AS Alpha,
									pb.Beta,
									pa.minx,
									pa.maxx
								FROM beta AS pb
								INNER JOIN average AS pa ON 
									pb.x_axis_partition = pa.x_axis_partition
							) AS r
							CROSS JOIN
							(
								SELECT 1
								UNION ALL
								SELECT 2
							) AS x (n)
							CROSS JOIN
							(
								SELECT 
									((MAX(x_axis) - MIN(x_axis)) / (MAX(y_axis) - MIN(y_axis))) * 0.55 AS y_axis_scale_factor
								FROM @vz
							) AS factors
						) AS p
						ORDER BY 
							p.x_axis
						FOR XML 
							PATH(''), 
							TYPE
					).value('.', 'VARCHAR(MAX)'),
					1,
					1,
					''
				) + 
			')', 
			0
		).STBuffer(q.STBuffer) AS shape
	FROM
	(
		SELECT
			((MAX(x_axis) - MIN(x_axis)) / 100) * 0.25 AS STBuffer
		FROM @vz
	) AS q
)
GO

