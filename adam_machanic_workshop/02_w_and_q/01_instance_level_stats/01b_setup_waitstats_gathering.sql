IF EXISTS (SELECT * FROM sys.objects WHERE [object_id] = OBJECT_ID(N'[dbo].[collect_wait_stats]') and OBJECTPROPERTY([object_id], N'IsProcedure') = 1)
	DROP PROCEDURE [dbo].[collect_wait_stats];
GO


CREATE PROCEDURE [dbo].[collect_wait_stats]
(
	@Clear INT = 0
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @DT DATETIME = GETDATE();

	IF OBJECT_ID(N'[dbo].[wait_stats]', N'U') IS NULL
	BEGIN	
		CREATE TABLE [dbo].[wait_stats] 
		(
			[wait_type] NVARCHAR(60) NOT NULL, 
			[waiting_tasks_count] BIGINT NOT NULL,
			[wait_time_ms] BIGINT NOT NULL,
			[max_wait_time_ms] BIGINT NOT NULL,
			[signal_wait_time_ms] BIGINT NOT NULL,
			[capture_time] DATETIME NOT NULL default GETDATE()
		);
		
		CREATE CLUSTERED INDEX IX_capture_time ON wait_stats (capture_time);
	END

	--  If 1 the clear out the wait_stats counters and the table
	IF @Clear = 1
	BEGIN
		DBCC SQLPERF([sys.dm_os_wait_stats], clear) WITH NO_INFOMSGS;
		TRUNCATE TABLE [dbo].[wait_stats];
	END


	INSERT INTO [dbo].[wait_stats] 
	(
		[wait_type],
		[waiting_tasks_count], 
		[wait_time_ms], 
		[max_wait_time_ms], 
		[signal_wait_time_ms], 
		[capture_time]
	)	
	SELECT 
		[wait_type], 
		[waiting_tasks_count], 
		[wait_time_ms], 
		[max_wait_time_ms], 
		[signal_wait_time_ms], 
		@DT
	FROM sys.dm_os_wait_stats;
END
GO
