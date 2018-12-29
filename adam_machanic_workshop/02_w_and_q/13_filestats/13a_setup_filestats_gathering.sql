IF EXISTS (SELECT * FROM sys.objects WHERE [object_id] = OBJECT_ID(N'[dbo].[collect_file_stats]') AND OBJECTPROPERTY([object_id], N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[collect_file_stats] ;
GO

CREATE PROCEDURE [dbo].[collect_file_stats] 
(
	@Clear INT = 0
)
AS
BEGIN
	SET NOCOUNT ON ;

	DECLARE @DT DATETIME;
	SET @DT = GETDATE();

	IF OBJECT_ID(N'[dbo].[file_stats]', N'U') IS NULL
	BEGIN
		CREATE TABLE [dbo].[file_stats]
		(
			[database_id] [smallint] NOT NULL,
			[file_id] [smallint] NOT NULL,
			[num_of_reads] [bigint] NOT NULL,
			[num_of_bytes_read] [bigint] NOT NULL,
			[io_stall_read_ms] [bigint] NOT NULL,
			[num_of_writes] [bigint] NOT NULL,
			[num_of_bytes_written] [bigint] NOT NULL,
			[io_stall_write_ms] [bigint] NOT NULL,
			[io_stall] [bigint] NOT NULL,
			[size_on_disk_bytes] [bigint] NOT NULL,
			[capture_time] [datetime] NOT NULL
		);
		
		CREATE CLUSTERED INDEX IX_capture_time ON dbo.file_stats (capture_time);
	END

	--  If 1 the clear out the table
	IF @Clear = 1
	BEGIN
		TRUNCATE TABLE [dbo].[file_stats];
	END

	INSERT INTO [dbo].[file_stats]
	(
		[database_id],
		[file_id],
		[num_of_reads],
		[num_of_bytes_read],
		[io_stall_read_ms],
		[num_of_writes],
		[num_of_bytes_written],
		[io_stall_write_ms],
		[io_stall],
		[size_on_disk_bytes],
		[capture_time]
	)
	SELECT 
		[database_id],
		[file_id],
		[num_of_reads],
		[num_of_bytes_read],
		[io_stall_read_ms],
		[num_of_writes],
		[num_of_bytes_written],
		[io_stall_write_ms],
		[io_stall],
		[size_on_disk_bytes],
		@DT
	FROM [sys].dm_io_virtual_file_stats(NULL,NULL);
END
GO
