IF EXISTS (SELECT * FROM sys.objects WHERE [object_id] = OBJECT_ID(N'[dbo].[report_file_stats]') and OBJECTPROPERTY([object_id], N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[report_file_stats];
GO

CREATE PROCEDURE [dbo].[report_file_stats] 
(
	--date/time range
	@start_time DATETIME = NULL,
	@end_time DATETIME = NULL
)
AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID( N'[dbo].[file_stats]', N'U') IS NULL
	BEGIN
		RAISERROR('Error [dbo].[file_stats] table does not exist', 16, 1) WITH NOWAIT;
		RETURN;
	END

	SELECT
		d.*
	FROM
	(
		SELECT
			MIN(capture_time) AS minTime,
			MAX(capture_time) AS maxTime
		FROM dbo.file_stats
		WHERE
			capture_time BETWEEN COALESCE(@start_time, '19000101') AND COALESCE(@end_time, '99991231')
	) AS min_and_max
	CROSS APPLY
	(
		SELECT 
			maxData.database_id,
			DB_NAME(maxData.Database_id) AS database_name,
			maxData.file_id,
			mf.name AS logical_file_name,
			mf.physical_name AS physical_file_name,
			maxData.num_of_reads - COALESCE(minData.num_of_reads, 0) AS num_of_reads_delta,
			maxData.io_stall_read_ms - COALESCE(minData.io_stall_read_ms, 0) AS io_stall_read_ms_delta,
			maxData.num_of_writes - COALESCE(minData.num_of_writes, 0) AS num_of_writes_delta,
			(maxData.num_of_bytes_written - COALESCE(minData.num_of_bytes_written, 0)) / 1048576.0 AS num_of_MB_written_delta,
			maxData.io_stall_write_ms - COALESCE(minData.io_stall_write_ms, 0) AS io_stall_write_ms_delta,
			maxData.io_stall - COALESCE(minData.io_stall, 0) AS io_stall_delta,
			(maxData.size_on_disk_bytes - COALESCE(minData.size_on_disk_bytes, 0)) / 1048576.0 AS size_on_disk_MB_delta,
			maxData.size_on_disk_bytes / 1048576.0 AS size_on_disk_MB_current,		
			maxData.capture_time AS last_capture_time,
			RIGHT
			(
				'00' + CONVERT(VARCHAR, (-1 * DATEDIFF(second, maxData.capture_time, minData.capture_time)) / 86400),
				2
			) +
				RIGHT
				(
					CONVERT(VARCHAR, DATEADD(second, (-1 * DATEDIFF(second, maxData.capture_time, minData.capture_time)), 0), 120),
					9
				)
			 AS [duration dd hh:mm:ss]
		FROM dbo.file_stats AS maxData
		LEFT OUTER JOIN 
		(
			SELECT 
				*
			FROM dbo.file_stats
			WHERE
				capture_time = min_and_max.minTime
		) AS minData ON
			maxData.database_id = minData.database_id
			AND maxData.file_id = minData.file_id
		LEFT OUTER JOIN sys.master_files AS mf ON
			mf.database_id = maxData.database_id AND
			mf.file_id = maxData.file_id
		WHERE
			maxData.capture_time = min_and_max.maxTime
	) AS d;
END
GO
