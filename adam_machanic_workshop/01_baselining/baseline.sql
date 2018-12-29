CREATE DATABASE baseline
GO


ALTER DATABASE baseline
SET READ_COMMITTED_SNAPSHOT ON
GO


USE baseline
GO


CREATE TABLE dbo.MetricCategories
(
	MetricCategory VARCHAR(50) NOT NULL,
	CONSTRAINT pk_MetricCategories PRIMARY KEY (MetricCategory)
)
GO


CREATE TABLE dbo.Metrics
(
	MetricId INT IDENTITY(1,1) NOT NULL,
	MetricName VARCHAR(350) NOT NULL,
	MetricCategory VARCHAR(50) NOT NULL REFERENCES dbo.MetricCategories (MetricCategory),
	CONSTRAINT pk_Metrics PRIMARY KEY (MetricId),
	CONSTRAINT un_CategoryName UNIQUE (MetricCategory, MetricName)
)
GO


CREATE TABLE dbo.Dates
(
	DateId SMALLINT IDENTITY(1,1) NOT NULL,
	TheDate DATE NOT NULL,
	TheYear SMALLINT NOT NULL,
	MonthInYear TINYINT NOT NULL,
	QuarterInYear TINYINT NOT NULL,
	WeekInYear TINYINT NOT NULL,
	WeekInMonth TINYINT NOT NULL,
	WeekInQuarter TINYINT NOT NULL,
	DayInYear SMALLINT NOT NULL CHECK (DayInYear BETWEEN 1 AND 366),
	DayInMonth TINYINT NOT NULL CHECK (DayInMonth BETWEEN 1 AND 31),
	DayInWeek TINYINT NOT NULL CHECK (DayInWeek BETWEEN 1 AND 7),
	NameOfMonth VARCHAR(50) NOT NULL CHECK (NameOfMonth IN ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December')),
	NameOfDay VARCHAR(50) NOT NULL CHECK (NameOfDay IN ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')),
	CONSTRAINT pk_Dates PRIMARY KEY (DateId),
	CONSTRAINT un_Dates UNIQUE (TheDate)
)
GO


CREATE TABLE dbo.FifteenMinuteSegments
(
	FifteenMinuteSegmentOfDay TINYINT NOT NULL,
	SegmentStartTime AS (DATEADD(minute, 15 * FifteenMinuteSegmentOfDay, CONVERT(TIME(0), '00:00:00'))),
	HourInDay AS (CONVERT(TINYINT, DATEPART(hour, (DATEADD(minute, 15 * FifteenMinuteSegmentOfDay, CONVERT(TIME(0), '00:00:00')))))),
	MinuteInHour AS (CONVERT(TINYINT, DATEPART(minute, (DATEADD(minute, 15 * FifteenMinuteSegmentOfDay, CONVERT(TIME(0), '00:00:00')))))),
	DuringWorkHours BIT NOT NULL,
	SegmentOfDay VARCHAR(20) NOT NULL CHECK (SegmentOfDay IN ('ETL Period', 'Morning', 'Busy Period', 'Afternoon', 'Evening')),	
	CONSTRAINT pk_FifteenMinuteSegments PRIMARY KEY (FifteenMinuteSegmentOfDay)
)
GO


CREATE TABLE dbo.Times
(
	TimeId SMALLINT IDENTITY(1,1) NOT NULL,
	TheTime TIME(0) NOT NULL CHECK (0 = DATEPART(second, TheTime) % 15),
	HourInDay TINYINT NOT NULL,
	MinuteInHour TINYINT NOT NULL,
	FifteenMinuteSegmentOfDay AS CONVERT(TINYINT, ((TimeId - 1) / 60)) PERSISTED REFERENCES FifteenMinuteSegments (FifteenMinuteSegmentOfDay),
	CONSTRAINT pk_Times PRIMARY KEY (TimeId),
	CONSTRAINT un_TheTime UNIQUE (TheTime),
)
GO


CREATE TABLE dbo.Servers
(
	ServerId SMALLINT IDENTITY(1,1) NOT NULL,
	ServerName VARCHAR(200) NOT NULL,
	CONSTRAINT pk_Servers PRIMARY KEY (ServerId),
	CONSTRAINT un_ServerName UNIQUE (ServerName)
)
GO


CREATE TABLE dbo.RecordedMetrics
(
	ServerId SMALLINT NOT NULL REFERENCES dbo.Servers (Serverid),
	DateId SMALLINT NOT NULL REFERENCES dbo.Dates (DateId),
	FifteenMinuteSegmentOfDay TINYINT NOT NULL REFERENCES dbo.FifteenMinuteSegments (FifteenMinuteSegmentOfDay),
	MetricId INT NOT NULL REFERENCES dbo.Metrics (MetricId),
	TotalMetricValue FLOAT NOT NULL,
	NumberOfSamples INT NOT NULL,
	MetricValue AS (TotalMetricValue / NumberOfSamples),
	CONSTRAINT pk_RecordedMetrics PRIMARY KEY (ServerId, MetricId, DateId, FifteenMinuteSegmentOfDay)
)
GO


CREATE TABLE dbo.Errors
(
	ErrorMessage VARCHAR(500) NOT NULL,
	ErrorDateTime DATETIME NOT NULL
)
GO

CREATE CLUSTERED INDEX i_ErrorDateTime 
ON dbo.Errors
(
	ErrorDateTime
)
GO


CREATE TYPE dbo.DataTransferFormat
AS TABLE
(
	ServerName VARCHAR(200) NOT NULL,
	MetricCategory VARCHAR(50) NOT NULL,
	MetricName VARCHAR(350) NOT NULL,
	CollectionTime DATETIME NOT NULL CHECK (0 = DATEPART(second, CollectionTime) % 15),
	MetricValue FLOAT NOT NULL
)
GO


CREATE TYPE dbo.ErrorFormat
AS TABLE
(
	ErrorMessage VARCHAR(500) NOT NULL,
	ErrorDateTime DATETIME NOT NULL
)
GO


CREATE PROC dbo.MetricUpdate
(
	@MetricData dbo.DataTransferFormat READONLY,
	@ErrorData dbo.ErrorFormat READONLY
)
AS
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON
	
	--tran for errors
	BEGIN TRAN
		INSERT dbo.Errors
		(
			ErrorMessage,
			ErrorDateTime
		)
		SELECT 
			ErrorMessage,
			ErrorDateTime
		FROM @ErrorData
	COMMIT
	
	--tran for metrics
	BEGIN TRAN
		--New metric category?
		INSERT dbo.MetricCategories
		(
			MetricCategory
		)
		SELECT DISTINCT
			md.MetricCategory
		FROM @MetricData AS md
		WHERE 
			NOT EXISTS
			(
				SELECT *
				FROM dbo.MetricCategories AS mc
				WHERE
					mc.MetricCategory = md.MetricCategory
			)
			
		--New metric?
		INSERT dbo.Metrics
		(
			MetricName,
			MetricCategory
		)
		SELECT DISTINCT
			md.MetricName,
			md.MetricCategory
		FROM @MetricData AS md
		WHERE
			NOT EXISTS
			(
				SELECT *
				FROM dbo.Metrics AS m
				WHERE
					m.MetricName = md.MetricName
					AND m.MetricCategory = md.MetricCategory
			)
			
		--new server?
		INSERT dbo.Servers
		(
			ServerName
		)
		SELECT DISTINCT
			md.ServerName
		FROM @MetricData AS md
		WHERE
			NOT EXISTS
			(
				SELECT *
				FROM dbo.Servers AS s
				WHERE
					s.ServerName = md.ServerName
			)

		MERGE 
		INTO dbo.RecordedMetrics AS tgt
		USING
		(
			SELECT
				s.ServerId,
				d.DateId,
				t.FifteenMinuteSegmentOfDay,
				m.MetricId,
				SUM(md.MetricValue) AS totalValue,
				COUNT(*) AS numRows
			FROM @MetricData AS md
			INNER JOIN dbo.Servers AS s ON
				s.ServerName = md.ServerName
			INNER JOIN dbo.Dates AS d ON
				d.TheDate = CONVERT(DATE, md.CollectionTime)
			INNER JOIN dbo.Times AS t ON
				t.TheTime = CONVERT(TIME(0), md.CollectionTime)
			INNER JOIN dbo.Metrics AS m ON
				m.MetricCategory = md.MetricCategory
				AND m.MetricName = md.MetricName
			GROUP BY
				s.ServerId,
				d.DateId,
				t.FifteenMinuteSegmentOfDay,
				m.MetricId		
		) AS src ON
			src.ServerId = tgt.ServerId
			AND src.MetricId = tgt.MetricId
			AND src.DateId = tgt.DateId
			AND src.FifteenMinuteSegmentOfDay = tgt.FifteenMinuteSegmentOfDay
		WHEN NOT MATCHED THEN
			INSERT
			(
				ServerId,
				DateId,
				FifteenMinuteSegmentOfDay,
				MetricId,
				TotalMetricValue,
				NumberOfSamples
			)
			VALUES
			(
				src.ServerId,
				src.DateId,
				src.FifteenMinuteSegmentOfDay,
				src.MetricId,
				src.totalValue,
				src.numRows
			)
		WHEN MATCHED THEN
			UPDATE
				SET
					tgt.TotalMetricValue += src.totalValue,
					tgt.NumberOfSamples += src.numRows;
	COMMIT
END
GO


--Populate the FifteenMinuteSegments dimension
INSERT dbo.FifteenMinuteSegments 
(
	FifteenMinuteSegmentOfDay,
	DuringWorkHours,
	SegmentOfDay
)
SELECT 
	number,
	CASE
		WHEN number BETWEEN 36 AND 71 THEN 1
		ELSE 0
	END AS DuringWorkHours,
	CASE
		WHEN number BETWEEN 0 AND 23 THEN 'ETL Period'
		WHEN number BETWEEN 24 AND 43 THEN 'Morning'
		WHEN number BETWEEN 44 AND 63 THEN 'Busy Period'
		WHEN number BETWEEN 64 AND 79 THEN 'Afternoon'
		ELSE 'Evening'
	END AS SegmentOfDay
FROM master..spt_values
WHERE 
	type = 'P'
	AND number between 0 AND 95
GO


--Populate the time dimension
WITH 
n0 AS (SELECT 1 AS a UNION ALL SELECT 1),
n1 AS (SELECT 1 AS a FROM n0 b, n0 c),
n2 AS (SELECT 1 AS a FROM n1 b, n1 c),
n3 AS (SELECT 1 AS a FROM n2 b, n2 c),
n4 AS (SELECT 1 AS a FROM n3 b, n3 c),
n5 AS (SELECT 1 AS a FROM n4 b, n4 c),
numbers AS 
(
	SELECT TOP(5760)
		ROW_NUMBER() OVER 
		(
			ORDER BY 
				(SELECT NULL)
		) AS number
	FROM n5
)
INSERT dbo.Times
SELECT
	TheTime,
	CONVERT(TINYINT, DATEPART(hour, TheTime)) AS HourInDay,
	CONVERT(TINYINT, DATEPART(minute, TheTime)) AS MinuteInHour
FROM
(
	SELECT
		DATEADD(second, 15 * (number-1), CONVERT(TIME(0), '00:00:00')) AS TheTime
	FROM numbers
) AS x
ORDER BY
	TheTime ASC
GO


--populate the date dimension
;WITH 
n0 AS (SELECT 1 AS a UNION ALL SELECT 1),
n1 AS (SELECT 1 AS a FROM n0 b, n0 c),
n2 AS (SELECT 1 AS a FROM n1 b, n1 c),
n3 AS (SELECT 1 AS a FROM n2 b, n2 c),
n4 AS (SELECT 1 AS a FROM n3 b, n3 c),
n5 AS (SELECT 1 AS a FROM n4 b, n4 c),
numbers AS 
(
	SELECT TOP(3650)
		ROW_NUMBER() OVER 
		(
			ORDER BY 
				(SELECT NULL)
		) AS number
	FROM n5
)
INSERT dbo.Dates
SELECT
	TheDate,
	CONVERT(SMALLINT, YEAR(TheDate)) AS TheYear,
	CONVERT(SMALLINT, MONTH(TheDate)) AS MonthInYear,
	CONVERT(SMALLINT, DATEPART(quarter, TheDate)) AS QuarterInYear,
	CONVERT(SMALLINT, DATEPART(week, TheDate)) AS WeekInYear,
	CONVERT
	(
		SMALLINT,
		DENSE_RANK() OVER 
		(
			PARTITION BY 
				YEAR(TheDate), 
				MONTH(TheDate) 
			ORDER BY 
				DATEPART(week, TheDate)
		)
	) AS WeekInMonth,
	CONVERT
	(
		SMALLINT,
		DENSE_RANK() OVER 
		(
			PARTITION BY 
				YEAR(TheDate), 
				MONTH(TheDate) 
			ORDER BY 
				DATEPART(quarter, TheDate)
		)
	) AS WeekInQuarter,
	CONVERT(SMALLINT, DATEPART(dayofyear, TheDate)) AS DayInYear,
	CONVERT(TINYINT, DATEPART(day, TheDate)) AS DayInMonth,
	CONVERT(TINYINT, DATEPART(weekday, TheDate)) AS DayInWeek,
	DATENAME(month, TheDate) AS NameOfMonth,
	DATENAME(weekday, TheDate) AS NameOfDay
FROM
(
	SELECT
		DATEADD(day, (number-1), CONVERT(DATE, DATEADD(year, DATEDIFF(year, 0, GETDATE()), 0))) AS TheDate
	FROM numbers
) AS x
ORDER BY
	TheDate ASC
GO


