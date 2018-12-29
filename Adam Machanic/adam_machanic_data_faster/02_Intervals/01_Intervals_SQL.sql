USE HotelSample
GO

--Include Actual Execution Plan--

SET STATISTICS TIME ON
GO



--First work with Itzik Ben-Gan Solution
--Huge thanks to Itzik!!!

DECLARE 
	@minHotel INT = 1,
	@maxHotel INT = 500

SELECT
	h.HotelName,
	x.*
FROM dbo.Hotels AS h
CROSS APPLY
(
	SELECT
		MIN(C5.starttime) AS intervalStart,
		MAX(C5.endtime) AS intervalEnd,
		MAX(C5.cnt) AS numberOfRooms
	FROM
	(
		SELECT 
			C4.*,
			COUNT(C4.isstart) OVER (ORDER BY C4.starttime) AS grp
		FROM
		(
			SELECT
				C3.ts AS starttime,
				DATEADD(dd, -1, C3.nextts) AS endtime,
				C3.cnt,
				CASE WHEN C3.cnt = LAG(C3.cnt) OVER (ORDER BY C3.ts) THEN NULL ELSE 1 END isstart
			FROM
			(
				SELECT
					*,
					LEAD(C2.ts) OVER (ORDER BY C2.ts, C2.type, C2.StayId) AS nextts
				FROM
				(
					SELECT 
						C1.*,
						ROW_NUMBER() OVER (ORDER BY C1.ts, C1.type, C1.StayId) AS se -- start or end ordinal
					FROM
					(
						SELECT
							hs.CheckInDate AS ts, 
							+1 AS type, 
							hs.StayId,
							ROW_NUMBER() OVER (ORDER BY hs.CheckInDate) AS s, -- start ordinal
							NULL AS e
						FROM dbo.HotelStays AS hs
						WHERE 
							hs.HotelId = h.HotelId

						UNION ALL

						SELECT 
							hs.CheckOutDate, 
							-1 AS type, 
							hs.StayId, 
							NULL AS s,
							ROW_NUMBER() OVER (ORDER BY hs.CheckOutDate, hs.StayId) AS e -- end ordinal
						FROM dbo.HotelStays AS hs
						WHERE
							hs.HotelId = h.HotelId
					) AS C1
				) AS C2
				CROSS APPLY
				(
					VALUES
					(
						COALESCE
						(
							C2.s - (C2.se - C2.s), -- count of active intervals after start event
							(C2.se - C2.e) - C2.e -- count of active intervals after end event
						)
					)
				) AS A (cnt)
			) AS C3
			WHERE
				C3.ts <> C3.nextts
		) AS C4
	) AS C5
	WHERE
		C5.cnt > 0 --remove intervals with 0 count
	GROUP BY
		C5.grp
) AS x
WHERE
	h.HotelId BETWEEN @minHotel AND @maxHotel
OPTION (RECOMPILE)
GO



--Try reading 500 hotels -- and not doing any work
--(Note the read time, for later)
EXEC dbo.ReadHotelStays
	@MinHotelId = 1,
	@MaxHotelId = 500
GO



--Now actually exercise the algorithm
EXEC dbo.GetHotelStayIntervalCounts
	@MinHotelId = 1,
	@MaxHotelId = 500
GO



--Now try everything above, again, for 4000 hotels



--A bit of brute-force parallelization to save the day?
DECLARE 
	@MinHotelId INT = 1,
	@MaxHotelId INT = 4000,
	@numThreads INT =
	(
		SELECT
			CONVERT(INT, value_in_use)
		FROM sys.configurations
		WHERE
			name = 'max degree of parallelism'
	)

EXEC dbo.GetHotelStayIntervalCounts_Parallelizer 
	@MinHotelId, 
	@MaxHotelId, 
	@numThreads
GO



--How about reading into an aggregate?
--(Compare with stored procedure read from above)
DECLARE 
	@minHotel INT = 1,
	@maxHotel INT = 500

SELECT
	hs.HotelId,
	dbo.IntervalAgg_Readonly
	(
		hs.CheckInDate,
		hs.CheckOutDate
	)
FROM dbo.HotelStays AS hs
WHERE
	hs.HotelId BETWEEN @minHotel AND @maxHotel
GROUP BY
	hs.HotelId
OPTION (RECOMPILE)
GO



--Test the "table-valued aggregate" pattern
DECLARE 
	@minHotel INT = 1,
	@maxHotel INT = 4000

SELECT
    h.HotelName,
    x.*
FROM dbo.Hotels AS h
CROSS APPLY
(
    SELECT
        CONVERT(DATE, v.StartDate) AS intervalStart,
        CONVERT(DATE, v.EndDate) AS intervalEnd,
        v.Count AS numberOfRooms
    FROM
    (
        SELECT
            dbo.IntervalAgg
			(
				hs.CheckInDate, 
				hs.CheckOutDate, 
				1
			) AS aggregation_token
        FROM 
		(
			SELECT
				*, 
				ROW_NUMBER() OVER 
				(
					ORDER BY
						hs.CheckInDate
				) AS r
			FROM dbo.HotelStays AS hs
			WHERE
				hs.HotelId = h.HotelId
		) as hs
    ) AS a
    CROSS APPLY dbo.IntervalValues(a.aggregation_token) AS v
) AS x
WHERE
	h.HotelId BETWEEN @minHotel AND @maxHotel
OPTION (RECOMPILE)
GO



/*** OPTIONAL ***/



--Parameter Scalability: Aggregate vs. ADO.NET
SELECT
	dbo.IntervalAgg_Readonly_MoreParams
	(
        hs.CheckInDate,
        hs.CheckOutDate,
        hs.StayId,
        h.HotelId,
        h.HotelName,
        h.AddressLine1,
        h.AddressLine2,
        h.City,
        h.StateProvince,
        h.PostalCode,
        h.CountryRegion,
        h.NumberOfRooms
	)
FROM dbo.HotelStays AS hs
INNER JOIN dbo.Hotels AS h ON
    h.HotelId = hs.HotelId
WHERE
	h.HotelId between 1 and 500
OPTION (MAXDOP 1)
GO



--Try the same thing with a stored proc
EXEC dbo.ReadHotelStays_MoreData 
	@MinHotelId = 1, 
	@MaxHotelId = 500
GO



--Don't read the data in if you can cache it!
--Exercise the cache a bit...
EXEC dbo.ReadHotelStays_MoreDataFromCache
	@MinHotelId = 1,
	@MaxHotelId = 500
GO
