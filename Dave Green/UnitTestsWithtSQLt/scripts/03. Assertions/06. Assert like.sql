/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROC dbo.Maintenance_CalculateAverages AS 
BEGIN
	DECLARE @rnd CHAR(2) = FLOOR(RAND() * 100)
	DECLARE @delay VARCHAR(100) = '00:00:00.'+@rnd

	WAITFOR DELAY @delay
END
GO


CREATE PROC dbo.Maintenance_CustomersTakingMoreTime AS 
BEGIN
	WAITFOR DELAY '00:00:01'
END
GO


CREATE PROCEDURE dbo.Maintenance @Message VARCHAR(MAX) OUTPUT AS
BEGIN
	DECLARE @StartTime DATETIME
	SET @StartTime = GETDATE()
	SET @Message = 'Failed to complete.'

	EXECUTE dbo.Maintenance_CalculateAverages

	EXECUTE dbo.Maintenance_CustomersTakingMoreTime

	SELECT @Message = 'Completed in '+CONVERT(VARCHAR(10),DATEDIFF(ms,@StartTime,GETDATE())) +' milliseconds'
END
GO


DECLARE @Message VARCHAR(MAX)

EXECUTE dbo.Maintenance @Message = @Message OUTPUT

SELECT @Message

