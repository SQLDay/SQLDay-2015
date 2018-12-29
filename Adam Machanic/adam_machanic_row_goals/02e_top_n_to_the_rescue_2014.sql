--TOP(N) to the Rescue!
--(SQL Server 2014)
USE AdventureWorks
GO




;WITH 
x AS
(
	SELECT --TOP(2147483647)
		th.ProductID,
		th.ActualCost,
		bp.SellStartDate AS startDate,
		TransactionDate AS EndDate
	FROM bigTransactionHistory AS th
	INNER JOIN bigproduct AS bp ON
		bp.ProductID = th.ProductID
	WHERE
		th.ProductID BETWEEN 1001 AND 5001
)
SELECT
	COUNT(*)
FROM x
INNER JOIN bigProductVacation AS bp ON
	bp.d BETWEEN x.startDate AND x.endDate
	AND bp.vacation_day = 1
GO



