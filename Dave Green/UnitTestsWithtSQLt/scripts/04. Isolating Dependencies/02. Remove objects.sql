/*
	Author: Dave Green
*/

USE CustomerManagement
GO


CREATE FUNCTION dbo.fcn_GetFirstOfMonth(
	@Date DATE)
RETURNS DATETIME AS
BEGIN
	DECLARE @FirstOfMonth DATETIME
	SET @FirstOfMonth = DATEADD(dd,1,EOMONTH(@Date,-1))
	
	RETURN @FirstOfMonth
END
GO


CREATE PROCEDURE dbo.RptContactsWithinPeriodUsingFunction(
	@WithinLastMonths INT,
	@RunAsAt DATE) AS
BEGIN
	DECLARE @StartDate DATETIME, @EndDate DATETIME
	SET @EndDate = dbo.fcn_GetFirstOfMonth(@RunAsAt)
	SET @StartDate = DATEADD(mm,-@WithinLastMonths,@EndDate)

	SELECT  
		IT.InteractionTypeText,
        COUNT(*) Occurrences,
        SUM(DATEDIFF(MI, InteractionStartDT, InteractionEndDT)) TotalTimeMins
	FROM    dbo.Interaction I
        INNER JOIN dbo.InteractionType IT ON IT.InteractionTypeID = I.InteractionTypeID
	WHERE   I.InteractionStartDT >= @Startdate
        AND I.InteractionStartDT < @Enddate
	GROUP BY 
		IT.InteractionTypeText
END
GO
