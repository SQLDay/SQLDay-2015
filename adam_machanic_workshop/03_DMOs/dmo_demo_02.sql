
/*2*/ --Execution Details

SELECT *
FROM sys.databases

WAITFOR DELAY '00:10:00'

SELECT *
FROM sys.tables
GO



USE AdventureWorks
GO


/*3a*/ --Transaction Information

BEGIN TRAN

SELECT *
FROM HumanResources.Employee e (HOLDLOCK)
WHERE
	EmployeeID = 123
GO



/*3b*/ --...

UPDATE HumanResources.Employee
SET SickLeaveHours = 100



ROLLBACK
GO



/*4*/

--Create a lock situation
BEGIN TRAN

UPDATE TOP(10) Sales.SalesOrderDetail
SET OrderQty += 7
GO



--New window - block
SELECT
	*
FROM
(
	SELECT
		sh.*,
		sd.ProductId,
		ROW_NUMBER() OVER 
		(
			PARTITION BY
				sd.SalesOrderDetailId
			ORDER BY
				sd.ProductId, 
				sd.OrderQty
		) AS r
	FROM
	(
		SELECT TOP(1000) 
			*
		FROM Sales.SalesOrderDetail
		ORDER BY
			SalesOrderDetailId DESC
	) AS sd
	INNER JOIN Sales.SalesOrderHeader AS sh ON
		sh.SalesOrderId = sd.SalesOrderId
) AS s
WHERE
	s.r = 1
GO



ROLLBACK
GO



--Task space
SELECT TOP(100000)
	a.*
INTO #x 
FROM master..spt_values a, master..spt_values b

WAITFOR DELAY '00:10:00'
GO

