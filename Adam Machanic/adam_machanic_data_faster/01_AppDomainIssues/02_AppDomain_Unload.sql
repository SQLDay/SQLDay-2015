USE HotelSample
GO

--Window #1
SELECT
	*
FROM dbo.GetNumbers(1, 10000000) AS x
GO


--Window #2 -- Hit stop after a few seconds
EXEC [dbo].[EnterMonitorAndSleep]
GO
