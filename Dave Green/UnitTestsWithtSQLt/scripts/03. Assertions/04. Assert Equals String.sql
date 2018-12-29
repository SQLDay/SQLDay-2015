/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE PROC dbo.Maintenance_CalculateAverages AS 
BEGIN
	WAITFOR DELAY '00:00:01'
END
GO


CREATE PROC dbo.Maintenance_CustomersTakingMoreTime AS 
BEGIN
	WAITFOR DELAY '00:00:02'
END
GO


CREATE PROCEDURE dbo.Maintenance @Message VARCHAR(MAX) OUTPUT AS
BEGIN
	SET @Message = 'Failed to complete.'

	EXECUTE dbo.Maintenance_CalculateAverages

	EXECUTE dbo.Maintenance_CustomersTakingMoreTime

	SELECT @Message = 'Completed.'
END
GO


DECLARE @Message VARCHAR(MAX)

EXECUTE dbo.Maintenance @Message = @Message OUTPUT

SELECT @Message

