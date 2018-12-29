/*============================================================================
  Summary:  Demonstrates Temp Tables and Table Variables
------------------------------------------------------------------------------
  Written by Klaus Aschenbrenner, SQLpassion.at

  (c) 2011, SQLpassion.at. All rights reserved.

  For more scripts and sample code, check out 
    http://www.SQLpassion.at

  You may alter this code for your own *non-commercial* purposes. You may
  republish altered code as long as you include this copyright and give due
  credit, but you must obtain prior permission before blogging this code.
  
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/

-- Create a local temp table
-- 1 record needs 1 data page
CREATE TABLE #TempTable
(
	ID INT IDENTITY(1, 1) PRIMARY KEY,
	FirstName CHAR(4000),
	LastName CHAR(4000)
)
GO

-- Insert 200 records into the temp table
INSERT INTO #TempTable (FirstName, LastName) VALUES
(
	'Klaus',
	'Aschenbrenner'
),
(
	'Philip',
	'Aschenbrenner'
)
GO 100

-- Retrieve the data from the temp table
-- The execution plan estimates 200 rows.
SELECT * FROM #TempTable
GO

-- Review the space used in TempDb.
-- Our temp table currently needs 208 pages (208 * 8.192 bytes) in TempDb.
SELECT * FROM sys.dm_db_session_space_usage
WHERE session_id = @@SPID
GO

-- Create a table variable
DECLARE @tempTable TABLE
(
	ID INT IDENTITY(1, 1) PRIMARY KEY,
	FirstName CHAR(4000),
	LastName CHAR(4000)
)

-- Insert 4 records into the table variable
INSERT INTO @tempTable (FirstName, LastName) VALUES
(
	'Klaus',
	'Aschenbrenner'
),
(
	'Philip',
	'Aschenbrenner'
),
(
	'Klaus',
	'Aschenbrenner'
),
(
	'Philip',
	'Aschenbrenner'
)

-- Retrieve the data from the table variable.
-- The execution plan estimates 1 row.
SELECT * FROM @tempTable
GO

-- Review the space used in TempDb.
-- Our table variable currently needs 5 (213 - 208) pages (5 * 8.192 bytes) in TempDb.
-- In sum our session needs 213 pages (213 * 8.192 bytes) in TempDb.
-- The 5 needed pages from the table variable are already marked for deallocation (column "user_objects_dealloc_page_count")
SELECT * FROM sys.dm_db_session_space_usage
WHERE session_id = @@SPID
GO

-- Drop the local temp table
DROP TABLE #TempTable
GO

-- Now the 208 pages from our temp table are also marked for deallocation (column "user_objects_dealloc_page_count")
SELECT * FROM sys.dm_db_session_space_usage
WHERE session_id = @@SPID
GO