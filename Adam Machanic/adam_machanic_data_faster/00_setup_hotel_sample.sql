CREATE DATABASE HotelSample
GO

ALTER DATABASE HotelSample SET TRUSTWORTHY ON
GO

USE HotelSample
GO

CREATE TABLE dbo.Hotels
(
	HotelId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	HotelName NVARCHAR(300) NOT NULL,
	AddressLine1 NVARCHAR(300) NOT NULL,
	AddressLine2 NVARCHAR(300) NULL,
	City NVARCHAR(50) NOT NULL,
	StateProvince NVARCHAR(50) NOT NULL,
	PostalCode NVARCHAR(50) NOT NULL,
	CountryRegion NVARCHAR(50) NOT NULL,
	NumberOfRooms SMALLINT NOT NULL
)
GO

--Insert the hotels...
INSERT dbo.Hotels
(
	HotelName,
	AddressLine1,
	AddressLine2,
	City,
	StateProvince,
	PostalCode,
	CountryRegion,
	NumberOfRooms
)
SELECT
	x.HotelName,
	x.AddressLine1,
	x.AddressLine2,
	x.City,
	x.StateProvince,
	x.PostalCode,
	x.CountryRegion,
	CASE 
		--Small: Between 10 and 74 rooms
		WHEN x.rVal < 5.5 THEN 10 + CONVERT(INT, RAND(CHECKSUM(NEWID())) * 64)
		--Medium: Between 75 and 174 rooms
		WHEN x.rVal >= 5.5 AND x.rVal < 8.0 THEN 75 + CONVERT(INT, RAND(CHECKSUM(NEWID())) * 99)
		--Large: Between 175 and 499 rooms
		WHEN x.rVal >= 8.0 AND x.rVal < 9.5 THEN 175 + CONVERT(INT, RAND(CHECKSUM(NEWID())) * 324)
		--Very large: Between 500 and 1500 rooms
		WHEN x.rVal > 9.5 THEN 500 + CONVERT(INT, RAND(CHECKSUM(NEWID())) * 1000)
	END AS NumberOfRooms
FROM
(
	SELECT
		n1.fullName + ' Hotel' AS HotelName,
		m1.AddressLine1,
		m1.AddressLine2,
		m1.City,
		m1.PostalCode,
		m1.StateProvince,
		m1.CountryRegion,
		RAND(CHECKSUM(NEWID())) * 10 AS rVal
	FROM
	(
		SELECT
			n.*,
			ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS r
		FROM
		(
			SELECT TOP(4000)
				FirstName + ' ' + LastName AS fullName
			FROM AdventureWorks.Person.Contact
			ORDER BY
				NEWID()
		) AS n
	) AS n1
	INNER JOIN
	(
		SELECT
			m.*,
			ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS r
		FROM
		(
			SELECT TOP(4000)
				a.AddressLine1,
				a.AddressLine2,
				a.City,
				a.PostalCode,
				sp.Name AS StateProvince,
				cr.Name AS CountryRegion
			FROM AdventureWorks.Person.Address AS a
			INNER JOIN Adventureworks.Person.StateProvince AS sp ON
				sp.StateProvinceID = a.StateProvinceID
			INNER JOIN AdventureWorks.Person.CountryRegion AS cr ON
				cr.CountryRegionCode = sp.CountryRegionCode
			ORDER BY
				NEWID()
		) AS m
	) AS m1 ON
		m1.r = n1.r
) AS x
GO


CREATE TABLE dbo.HotelStays
(
	StayId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	HotelId INT NOT NULL REFERENCES dbo.Hotels (HotelId),
	CheckInDate DATE NOT NULL,
	CheckOutDate DATE NOT NULL
)
GO


--How many weeks of data do we want to populate into the table?
DECLARE @numWeeks INT = 2

INSERT dbo.HotelStays WITH (TABLOCK)
(
	HotelId,
	CheckInDate,
	CheckOutDate
)
SELECT 
	h.HotelId,
	f.CheckInDate,
	f.CheckOutDate
FROM dbo.Hotels AS h 
CROSS APPLY
(
	SELECT
		MIN(x_final.theDate) AS CheckInDate,
		DATEADD(dd, 1, MAX(x_final.theDate)) AS CheckOutDate
	FROM
	(
		SELECT
			d_final.theDate,
			m.stayGroup,
			--Group for sequences of nights by the same customer
			DATEADD(dd, -ROW_NUMBER() OVER (PARTITION BY m.stayGroup ORDER BY d_final.theDate), d_final.theDate) AS sequenceGroup
		FROM
		(
			SELECT
				d2.theDate,
				CASE
					WHEN 
						1 = 
							LEAD(d2.shouldLag, d2.lagNumber) OVER (ORDER BY d2.theDate) 
								THEN
									LEAD(d2.OccupiedRooms, d2.lagNumber) OVER (ORDER BY d2.theDate) 
					ELSE d2.OccupiedRooms
				END AS OccupiedRooms
			FROM
			(
				--Final smoothing. 
				--If Wednesday or Saturday has fewer nights than Tuesday or Friday (respectively) then:
					--40% chance that the hotel is just as occupied on Sunday, Monday, and Tuesday, as it is on Wednesday
					--60% chance that the hotel is just as occupied on Thursday and Friday as it is on Saturday
				SELECT
					d1.*,
					--Should this value be lagged back?
					CASE
						WHEN
							(
								d1.OccupiedRooms <= LAG(d1.OccupiedRooms) OVER (ORDER BY d1.theDate)
							)
							AND
							(
								(
									DATENAME(dw, d1.theDate) = 'Wednesday' 
									AND CONVERT(INT, RAND(CHECKSUM(NEWID())) * 10) BETWEEN 1 AND 5
								)
								OR
								(
			
									DATENAME(dw, d1.theDate) = 'Saturday' 
									AND CONVERT(INT, RAND(CHECKSUM(NEWID())) * 10) BETWEEN 1 AND 7
								) 
							) THEN 1
						ELSE 0
					END AS shouldLag,
					CASE DATENAME(dw, d1.theDate)
						WHEN 'Sunday' THEN 3
						WHEN 'Monday' THEN 2
						WHEN 'Tuesday' THEN 1
						WHEN 'Wednesday' THEN 0
						WHEN 'Thursday' THEN 2
						WHEN 'Friday' THEN 1
						WHEN 'Saturday' THEN 0
					END AS lagNumber
				FROM
				(
					SELECT
						d0.theDate,
						--Add bonus for Wednesday (10%), Thursday (15%), and Friday/Saturday (20%)
						CASE
							WHEN 
								(
									d0.OccupiedRooms +
									CASE 
										WHEN DATENAME(dw, d0.theDate) = 'Wednesday' THEN CONVERT(INT, h.NumberOfRooms * 0.1)
										WHEN DATENAME(dw, d0.theDate) = 'Thursday' THEN CONVERT(INT, h.NumberOfRooms * 0.15)
										WHEN DATENAME(dw, d0.theDate) IN ('Friday', 'Saturday') THEN CONVERT(INT, h.NumberOfRooms * 0.2)
										ELSE 0
									END
								) > h.NumberOfRooms THEN h.NumberOfRooms
							ELSE 
								d0.OccupiedRooms +
								CASE 
									WHEN DATENAME(dw, d0.theDate) = 'Wednesday' THEN CONVERT(INT, h.NumberOfRooms * 0.1)
									WHEN DATENAME(dw, d0.theDate) = 'Thursday' THEN CONVERT(INT, h.NumberOfRooms * 0.15)
									WHEN DATENAME(dw, d0.theDate) IN ('Friday', 'Saturday') THEN CONVERT(INT, h.NumberOfRooms * 0.2)
									ELSE 0
								END
						END AS OccupiedRooms
					FROM
					(
						--Trailing two weeks worth of stays, starting last Saturday
						SELECT
							--find most recent Saturday by using a reference Saturday, 2013-01-05
							DATEADD(dd, -v.number, CONVERT(DATE, DATEADD(week, DATEDIFF(week, '2013-01-05', GETDATE()) - 1, '2013-01-05'))) AS theDate,
							--How many rooms were occupied that night?
							--50% base + up to 51% extra + outer bonus for specific days of the week
							CONVERT(INT, h.NumberOfRooms * 0.5) + CONVERT(INT, RAND(CHECKSUM(NEWID())) * (h.NumberOfRooms * 0.511)) AS OccupiedRooms
						FROM master..spt_values AS v
						WHERE
							v.type = 'P'
							AND v.number BETWEEN 0 AND ((@numWeeks * 7) - 1)
					) AS d0
				) AS d1
			) AS d2
		) AS d_final
		CROSS APPLY
		(
			--Each stay night will get a group ID so that we can put them back together
			--We'll randomize the nights with 75% more slots than we have actual rooms, in order to make sure
			--that we get SOME consecutive nights, but not way too many
			SELECT TOP(d_final.OccupiedRooms)
				v0.number AS stayGroup
			FROM master..spt_values AS v0
			WHERE
				v0.type = 'P'
				AND v0.number BETWEEN 1 AND h.NumberOfRooms * 1.75
			ORDER BY
				NEWID()
		) AS m
	) AS x_final
	GROUP BY
		x_final.stayGroup,
		x_final.sequenceGroup
) AS f
ORDER BY
	f.CheckInDate,
	f.CheckOutDate,
	h.HotelId
OPTION (QUERYTRACEON 8649, QUERYTRACEON 8690)
GO


--Index #1 for Itzik Ben-Gan Solution
--Will also support CLR solutions
CREATE INDEX ix_HotelId_CheckIn_StayId
ON dbo.HotelStays
(
	HotelId,
	CheckInDate,
	StayId
)
INCLUDE
(
	CheckOutDate
)
GO


--Index #2 for Itzik Ben-Gan solution
--(Unneeded for CLR solutions)
CREATE INDEX ix_HotelId_CheckOut_StayId
ON dbo.HotelStays
(
	HotelId,
	CheckOutDate,
	StayId
)
GO
