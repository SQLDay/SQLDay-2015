--sp_whoisactive and memory over-utilization

DECLARE @blocker BIT;
SET @blocker = 0;
DECLARE @i INT;
SET @i = 2147483647;

DECLARE @sessions TABLE
(
	session_id SMALLINT NOT NULL,
	request_id INT NOT NULL,
	login_time DATETIME,
	last_request_end_time DATETIME,
	status VARCHAR(30),
	statement_start_offset INT,
	statement_end_offset INT,
	sql_handle BINARY(20),
	host_name NVARCHAR(128),
	login_name NVARCHAR(128),
	program_name NVARCHAR(128),
	database_id SMALLINT,
	memory_usage INT,
	open_tran_count SMALLINT, 
	wait_type NVARCHAR(32),
			wait_resource NVARCHAR(256),
			wait_time BIGINT, 
			blocked SMALLINT,
	is_user_process BIT,
	cmd VARCHAR(32),
	PRIMARY KEY CLUSTERED (session_id, request_id) WITH (IGNORE_DUP_KEY = ON)
);

DECLARE @blockers TABLE
(
	session_id INT NOT NULL PRIMARY KEY
);

BLOCKERS:;

INSERT @sessions
(
	session_id,
	request_id,
	login_time,
	last_request_end_time,
	status,
	statement_start_offset,
	statement_end_offset,
	sql_handle,
	host_name,
	login_name,
	program_name,
	database_id,
	memory_usage,
	open_tran_count, 
	wait_type,
			wait_resource,
			wait_time, 
			blocked,
	is_user_process,
	cmd 
)
SELECT TOP(@i)
	spy.session_id,
	spy.request_id,
	spy.login_time,
	spy.last_request_end_time,
	spy.status,
	spy.statement_start_offset,
	spy.statement_end_offset,
	spy.sql_handle,
	spy.host_name,
	spy.login_name,
	spy.program_name,
	spy.database_id,
	spy.memory_usage,
	spy.open_tran_count,
	spy.wait_type,
			CASE
				WHEN
					spy.wait_type LIKE N'PAGE%LATCH_%'
					OR spy.wait_type = N'CXPACKET'
					OR spy.wait_type LIKE N'LATCH[_]%'
					OR spy.wait_type = N'OLEDB' THEN
						spy.wait_resource
				ELSE
					NULL
			END AS wait_resource,
			spy.wait_time, 
			spy.blocked,
	spy.is_user_process,
	spy.cmd
FROM
(
	SELECT TOP(@i)
		spx.*, 
		ROW_NUMBER() OVER
				(
					PARTITION BY
						spx.session_id,
						spx.request_id
					ORDER BY
						CASE
							WHEN spx.wait_type LIKE N'LCK[_]%' THEN 
								1
							ELSE
								99
						END,
						spx.wait_time DESC,
						spx.blocked DESC
				) AS r 
				FROM
	(
		SELECT TOP(@i)
			sp0.session_id,
			sp0.request_id,
			sp0.login_time,
			sp0.last_request_end_time,
			LOWER(sp0.status) AS status,
			CASE
				WHEN sp0.cmd = 'CREATE INDEX' THEN
					0
				ELSE
					sp0.stmt_start
			END AS statement_start_offset,
			CASE
				WHEN sp0.cmd = N'CREATE INDEX' THEN
					-1
				ELSE
					COALESCE(NULLIF(sp0.stmt_end, 0), -1)
			END AS statement_end_offset,
			sp0.sql_handle,
			sp0.host_name,
			sp0.login_name,
			sp0.program_name,
			sp0.database_id,
			sp0.memory_usage,
			sp0.open_tran_count, 
			CASE
						WHEN sp0.wait_time > 0 AND sp0.wait_type <> N'CXPACKET' THEN
							sp0.wait_type
						ELSE
							NULL
					END AS wait_type,
					CASE
						WHEN sp0.wait_time > 0 AND sp0.wait_type <> N'CXPACKET' THEN 
							sp0.wait_resource
						ELSE
							NULL
					END AS wait_resource,
					CASE
						WHEN sp0.wait_type <> N'CXPACKET' THEN
							sp0.wait_time
						ELSE
							0
					END AS wait_time, 
					sp0.blocked,
			sp0.is_user_process,
			sp0.cmd
		FROM
		(
			SELECT TOP(@i)
				sp1.session_id,
				sp1.request_id,
				sp1.login_time,
				sp1.last_request_end_time,
				sp1.status,
				sp1.cmd,
				sp1.stmt_start,
				sp1.stmt_end,
				MAX(NULLIF(sp1.sql_handle, 0x00)) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS sql_handle,
				sp1.host_name,
				MAX(sp1.login_name) OVER (PARTITION BY sp1.session_id, sp1.request_id) AS login_name,
				sp1.program_name,
				sp1.database_id,
				MAX(sp1.memory_usage)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS memory_usage,
				MAX(sp1.open_tran_count)  OVER (PARTITION BY sp1.session_id, sp1.request_id) AS open_tran_count,
				sp1.wait_type,
				sp1.wait_resource,
				sp1.wait_time,
				sp1.blocked,
				sp1.hostprocess,
				sp1.is_user_process
			FROM
			(
				SELECT TOP(@i)
					sp2.spid AS session_id,
					CASE sp2.status
						WHEN 'sleeping' THEN
							CONVERT(INT, 0)
						ELSE
							sp2.request_id
					END AS request_id,
					MAX(sp2.login_time) AS login_time,
					MAX(sp2.last_batch) AS last_request_end_time,
					MAX(CONVERT(VARCHAR(30), RTRIM(sp2.status)) COLLATE Latin1_General_Bin2) AS status,
					MAX(CONVERT(VARCHAR(32), RTRIM(sp2.cmd)) COLLATE Latin1_General_Bin2) AS cmd,
					MAX(sp2.stmt_start) AS stmt_start,
					MAX(sp2.stmt_end) AS stmt_end,
					MAX(sp2.sql_handle) AS sql_handle,
					MAX(CONVERT(sysname, RTRIM(sp2.hostname)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS host_name,
					MAX(CONVERT(sysname, RTRIM(sp2.loginame)) COLLATE SQL_Latin1_General_CP1_CI_AS) AS login_name,
					MAX
					(
						CASE
							WHEN blk.queue_id IS NOT NULL THEN
								N'Service Broker
									database_id: ' + CONVERT(NVARCHAR, blk.database_id) +
									N' queue_id: ' + CONVERT(NVARCHAR, blk.queue_id)
							ELSE
								CONVERT
								(
									sysname,
									RTRIM(sp2.program_name)
								)
						END COLLATE SQL_Latin1_General_CP1_CI_AS
					) AS program_name,
					MAX(sp2.dbid) AS database_id,
					MAX(sp2.memusage) AS memory_usage,
					MAX(sp2.open_tran) AS open_tran_count,
					RTRIM(sp2.lastwaittype) AS wait_type,
					RTRIM(sp2.waitresource) AS wait_resource,
					MAX(sp2.waittime) AS wait_time,
					COALESCE(NULLIF(sp2.blocked, sp2.spid), 0) AS blocked,
					MAX
					(
						CASE
							WHEN blk.session_id = sp2.spid THEN
								'blocker'
							ELSE
								RTRIM(sp2.hostprocess)
						END
					) AS hostprocess,
					CONVERT
					(
						BIT,
						MAX
						(
							CASE
								WHEN sp2.hostprocess > '' THEN
									1
								ELSE
									0
							END
						)
					) AS is_user_process
				FROM
				(
					SELECT TOP(@i)
						session_id,
						CONVERT(INT, NULL) AS queue_id,
						CONVERT(INT, NULL) AS database_id
					FROM @blockers

					UNION ALL

					SELECT TOP(@i)
						CONVERT(SMALLINT, 0),
						CONVERT(INT, NULL) AS queue_id,
						CONVERT(INT, NULL) AS database_id
					WHERE
						@blocker = 0

					UNION ALL

					SELECT TOP(@i)
						CONVERT(SMALLINT, spid),
						queue_id,
						database_id
					FROM sys.dm_broker_activated_tasks
					WHERE
						@blocker = 0
				) AS blk
				INNER JOIN sys.sysprocesses AS sp2 ON
					sp2.spid = blk.session_id
					OR
					(
						blk.session_id = 0
						AND @blocker = 0
					)
				GROUP BY
					sp2.spid,
					CASE sp2.status
						WHEN 'sleeping' THEN
							CONVERT(INT, 0)
						ELSE
							sp2.request_id
					END,
					RTRIM(sp2.lastwaittype),
					RTRIM(sp2.waitresource),
					COALESCE(NULLIF(sp2.blocked, sp2.spid), 0)
			) AS sp1
		) AS sp0
		WHERE
			@blocker = 1
			OR
			(1=1 
			AND sp0.session_id <> @@spid 
						)
	) AS spx
) AS spy
WHERE
	spy.r = 1; 
IF @@ROWCOUNT > 0
		BEGIN;
			INSERT @blockers
			(
				session_id
			)
			SELECT TOP(@i)
				blocked
			FROM @sessions
			WHERE
				NULLIF(blocked, 0) IS NOT NULL

			EXCEPT

			SELECT TOP(@i)
				session_id
			FROM @sessions; 
			IF @@ROWCOUNT > 0
					BEGIN;
						SET @blocker = 1;
						GOTO BLOCKERS;
					END; 
					END; 

insert @sessions 
(
	session_id,
	request_id,
	login_time,
	last_request_end_time,
	status,
	statement_start_offset,
	statement_end_offset,
	sql_handle,
	host_name,
	login_name,
	program_name,
	database_id,
	memory_usage,
	open_tran_count, 
	wait_type,
			wait_resource,
			wait_time, 
			blocked,
	is_user_process,
	cmd 
)

--Make the situation a bit worse than usual...
select 
	(rand(checksum(newid())) * 10000) + 1000,
	request_id,
	login_time,
	last_request_end_time,
	status,
	statement_start_offset,
	statement_end_offset,
	sql_handle,
	host_name,
	login_name,
	program_name,
	database_id,
	memory_usage,
	open_tran_count, 
	wait_type,
			wait_resource,
			wait_time, 
			blocked,
	is_user_process,
	cmd 
from @sessions
cross apply
(
	select number from master..spt_values where type = 'p' and number between 1 and 200
) as v (i)


SELECT TOP(@i)
	x.session_id,
	x.request_id,
	DENSE_RANK() OVER
	(
		ORDER BY
			x.session_id
	) AS session_number,
	x.elapsed_time AS elapsed_time, 
		NULL AS avg_elapsed_time, 
		x.physical_io AS physical_io, 
		x.reads AS reads, 
		x.physical_reads AS physical_reads, 
		x.writes AS writes, 
		x.tempdb_allocations AS tempdb_allocations, 
		x.tempdb_current AS tempdb_current, 
		x.CPU AS CPU, 
		0 AS thread_CPU_snapshot, 
		x.context_switches AS context_switches, 
		x.used_memory AS used_memory, 
		x.tasks AS tasks, 
		x.status AS status, 
		COALESCE(x.task_wait_info, x.sys_wait_info) AS wait_info, 
		x.transaction_id AS transaction_id, 
		x.open_tran_count AS open_tran_count, 
		x.sql_handle AS sql_handle, 
		x.statement_start_offset AS statement_start_offset, 
		x.statement_end_offset AS statement_end_offset, 
		NULL AS sql_text, 
		NULL AS plan_handle, 
		NULLIF(x.blocking_session_id, 0) AS blocking_session_id, 
		x.percent_complete AS percent_complete, 
		x.host_name AS host_name, 
		x.login_name AS login_name, 
		DB_NAME(x.database_id) AS database_name, 
		x.program_name AS program_name, 
		(
						SELECT TOP(@i)
							x.text_size,
							x.language,
							x.date_format,
							x.date_first,
							CASE x.quoted_identifier
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS quoted_identifier,
							CASE x.arithabort
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS arithabort,
							CASE x.ansi_null_dflt_on
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS ansi_null_dflt_on,
							CASE x.ansi_defaults
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS ansi_defaults,
							CASE x.ansi_warnings
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS ansi_warnings,
							CASE x.ansi_padding
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS ansi_padding,
							CASE ansi_nulls
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS ansi_nulls,
							CASE x.concat_null_yields_null
								WHEN 0 THEN 'OFF'
								WHEN 1 THEN 'ON'
							END AS concat_null_yields_null,
							CASE x.transaction_isolation_level
								WHEN 0 THEN 'Unspecified'
								WHEN 1 THEN 'ReadUncomitted'
								WHEN 2 THEN 'ReadCommitted'
								WHEN 3 THEN 'Repeatable'
								WHEN 4 THEN 'Serializable'
								WHEN 5 THEN 'Snapshot'
							END AS transaction_isolation_level,
							x.lock_timeout,
							x.deadlock_priority,
							x.row_count,
							x.command_type, 
							(
										SELECT TOP(1)
											CONVERT(uniqueidentifier, CONVERT(XML, '').value('xs:hexBinary( substring(sql:column("agent_info.job_id_string"), 0) )', 'binary(16)')) AS job_id,
											agent_info.step_id,
											(
												SELECT TOP(1)
													NULL
												FOR XML
													PATH('job_name'),
													TYPE
											),
											(
												SELECT TOP(1)
													NULL
												FOR XML
													PATH('step_name'),
													TYPE
											)
										FROM
										(
											SELECT TOP(1)
												SUBSTRING(x.program_name, CHARINDEX('0x', x.program_name) + 2, 32) AS job_id_string,
												SUBSTRING(x.program_name, CHARINDEX(': Step ', x.program_name) + 7, CHARINDEX(')', x.program_name, CHARINDEX(': Step ', x.program_name)) - (CHARINDEX(': Step ', x.program_name) + 7)) AS step_id
											WHERE
												x.program_name LIKE N'SQLAgent - TSQL JobStep (Job 0x%'
										) AS agent_info
										FOR XML
											PATH('agent_job_info'),
											TYPE
									),
									CONVERT(XML, x.block_info) AS block_info, 
									x.host_process_id 
						FOR XML
							PATH('additional_info'),
							TYPE
					) AS additional_info, 
	x.start_time, 
		x.login_time AS login_time, 
	x.last_request_start_time
FROM
(
	SELECT TOP(@i)
		y.*,
		CASE
			WHEN DATEDIFF(day, y.start_time, GETDATE()) > 24 THEN
				DATEDIFF(second, GETDATE(), y.start_time)
			ELSE DATEDIFF(ms, y.start_time, GETDATE())
		END AS elapsed_time,
		COALESCE(tempdb_info.tempdb_allocations, 0) AS tempdb_allocations,
		COALESCE
		(
			CASE
				WHEN tempdb_info.tempdb_current < 0 THEN 0
				ELSE tempdb_info.tempdb_current
			END,
			0
		) AS tempdb_current, 
		N'(' + CONVERT(NVARCHAR, y.wait_duration_ms) + N'ms)' +
						y.wait_type +
							CASE
								WHEN y.wait_type LIKE N'PAGE%LATCH_%' THEN
									N':' +
									COALESCE(DB_NAME(CONVERT(INT, LEFT(y.resource_description, CHARINDEX(N':', y.resource_description) - 1))), N'(null)') +
									N':' +
									SUBSTRING(y.resource_description, CHARINDEX(N':', y.resource_description) + 1, LEN(y.resource_description) - CHARINDEX(N':', REVERSE(y.resource_description)) - CHARINDEX(N':', y.resource_description)) +
									N'(' +
										CASE
											WHEN
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) = 1 OR
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) % 8088 = 0
													THEN 
														N'PFS'
											WHEN
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) = 2 OR
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) % 511232 = 0
													THEN 
														N'GAM'
											WHEN
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) = 3 OR
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) % 511233 = 0
													THEN
														N'SGAM'
											WHEN
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) = 6 OR
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) % 511238 = 0 
													THEN 
														N'DCM'
											WHEN
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) = 7 OR
												CONVERT(INT, RIGHT(y.resource_description, CHARINDEX(N':', REVERSE(y.resource_description)) - 1)) % 511239 = 0 
													THEN 
														N'BCM'
											ELSE 
												N'*'
										END +
									N')'
								WHEN y.wait_type = N'CXPACKET' THEN
									N':' + SUBSTRING(y.resource_description, CHARINDEX(N'nodeId', y.resource_description) + 7, 4)
								WHEN y.wait_type LIKE N'LATCH[_]%' THEN
									N' [' + LEFT(y.resource_description, COALESCE(NULLIF(CHARINDEX(N' ', y.resource_description), 0), LEN(y.resource_description) + 1) - 1) + N']'
								WHEN
									y.wait_type = N'OLEDB'
									AND y.resource_description LIKE N'%(SPID=%)' THEN
										N'[' + LEFT(y.resource_description, CHARINDEX(N'(SPID=', y.resource_description) - 2) +
											N':' + SUBSTRING(y.resource_description, CHARINDEX(N'(SPID=', y.resource_description) + 6, CHARINDEX(N')', y.resource_description, (CHARINDEX(N'(SPID=', y.resource_description) + 6)) - (CHARINDEX(N'(SPID=', y.resource_description) + 6)) + ']'
								ELSE
									N''
							END COLLATE Latin1_General_Bin2 AS sys_wait_info, 
							tasks.physical_io,
					tasks.context_switches,
					tasks.tasks,
					tasks.block_info,
					tasks.wait_info AS task_wait_info,
					tasks.thread_CPU_snapshot,
					CONVERT(INT, NULL) AS avg_elapsed_time 
	FROM
	(
		SELECT TOP(@i)
			sp.session_id,
			sp.request_id,
			COALESCE(r.logical_reads, s.logical_reads) AS reads,
			COALESCE(r.reads, s.reads) AS physical_reads,
			COALESCE(r.writes, s.writes) AS writes,
			COALESCE(r.CPU_time, s.CPU_time) AS CPU,
			sp.memory_usage + COALESCE(r.granted_query_memory, 0) AS used_memory,
			LOWER(sp.status) AS status,
			COALESCE(r.sql_handle, sp.sql_handle) AS sql_handle,
			COALESCE(r.statement_start_offset, sp.statement_start_offset) AS statement_start_offset,
			COALESCE(r.statement_end_offset, sp.statement_end_offset) AS statement_end_offset,
			sp.wait_type COLLATE Latin1_General_Bin2 AS wait_type,
					sp.wait_resource COLLATE Latin1_General_Bin2 AS resource_description,
					sp.wait_time AS wait_duration_ms, 
					NULLIF(sp.blocked, 0) AS blocking_session_id,
			r.plan_handle,
			NULLIF(r.percent_complete, 0) AS percent_complete,
			sp.host_name,
			sp.login_name,
			sp.program_name,
			s.host_process_id,
			COALESCE(r.text_size, s.text_size) AS text_size,
			COALESCE(r.language, s.language) AS language,
			COALESCE(r.date_format, s.date_format) AS date_format,
			COALESCE(r.date_first, s.date_first) AS date_first,
			COALESCE(r.quoted_identifier, s.quoted_identifier) AS quoted_identifier,
			COALESCE(r.arithabort, s.arithabort) AS arithabort,
			COALESCE(r.ansi_null_dflt_on, s.ansi_null_dflt_on) AS ansi_null_dflt_on,
			COALESCE(r.ansi_defaults, s.ansi_defaults) AS ansi_defaults,
			COALESCE(r.ansi_warnings, s.ansi_warnings) AS ansi_warnings,
			COALESCE(r.ansi_padding, s.ansi_padding) AS ansi_padding,
			COALESCE(r.ansi_nulls, s.ansi_nulls) AS ansi_nulls,
			COALESCE(r.concat_null_yields_null, s.concat_null_yields_null) AS concat_null_yields_null,
			COALESCE(r.transaction_isolation_level, s.transaction_isolation_level) AS transaction_isolation_level,
			COALESCE(r.lock_timeout, s.lock_timeout) AS lock_timeout,
			COALESCE(r.deadlock_priority, s.deadlock_priority) AS deadlock_priority,
			COALESCE(r.row_count, s.row_count) AS row_count,
			COALESCE(r.command, sp.cmd) AS command_type,
			COALESCE
			(
				CASE
					WHEN
					(
						s.is_user_process = 0
						AND r.total_elapsed_time >= 0
					) THEN
						DATEADD
						(
							ms,
							1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())),
							DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
						)
				END,
				NULLIF(COALESCE(r.start_time, sp.last_request_end_time), CONVERT(DATETIME, '19000101', 112)),
				(
					SELECT TOP(1)
						DATEADD(second, -(ms_ticks / 1000), GETDATE())
					FROM sys.dm_os_sys_info
				)
			) AS start_time,
			sp.login_time,
			CASE
				WHEN s.is_user_process = 1 THEN
					s.last_request_start_time
				ELSE
					COALESCE
					(
						DATEADD
						(
							ms,
							1000 * (DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())) / 500) - DATEPART(ms, DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())),
							DATEADD(second, -(r.total_elapsed_time / 1000), GETDATE())
						),
						s.last_request_start_time
					)
			END AS last_request_start_time,
			r.transaction_id,
			sp.database_id,
			sp.open_tran_count
		FROM @sessions AS sp
		LEFT OUTER LOOP JOIN sys.dm_exec_sessions AS s ON
			s.session_id = sp.session_id
			AND s.login_time = sp.login_time
		LEFT OUTER LOOP JOIN sys.dm_exec_requests AS r ON
			sp.status <> 'sleeping'
			AND r.session_id = sp.session_id
			AND r.request_id = sp.request_id
			AND
			(
				(
					s.is_user_process = 0
					AND sp.is_user_process = 0
				)
				OR
				(
					r.start_time = s.last_request_start_time
					AND s.last_request_end_time = sp.last_request_end_time
				)
			)
	) AS y
	LEFT OUTER HASH JOIN
			(
				SELECT TOP(@i)
					task_nodes.task_node.value('(session_id/text())[1]', 'SMALLINT') AS session_id,
					task_nodes.task_node.value('(request_id/text())[1]', 'INT') AS request_id,
					task_nodes.task_node.value('(physical_io/text())[1]', 'BIGINT') AS physical_io,
					task_nodes.task_node.value('(context_switches/text())[1]', 'BIGINT') AS context_switches,
					task_nodes.task_node.value('(tasks/text())[1]', 'INT') AS tasks,
					task_nodes.task_node.value('(block_info/text())[1]', 'NVARCHAR(4000)') AS block_info,
					task_nodes.task_node.value('(waits/text())[1]', 'NVARCHAR(4000)') AS wait_info,
					task_nodes.task_node.value('(thread_CPU_snapshot/text())[1]', 'BIGINT') AS thread_CPU_snapshot
				FROM
				(
					SELECT TOP(@i)
						CONVERT
						(
							XML,
							REPLACE
							(
								CONVERT(NVARCHAR(MAX), tasks_raw.task_xml_raw) COLLATE Latin1_General_Bin2,
								N'</waits></tasks><tasks><waits>',
								N', '
							)
						) AS task_xml
					FROM
					(
						SELECT TOP(@i)
							CASE waits.r
								WHEN 1 THEN
									waits.session_id
								ELSE
									NULL
							END AS [session_id],
							CASE waits.r
								WHEN 1 THEN
									waits.request_id
								ELSE
									NULL
							END AS [request_id],											
							CASE waits.r
								WHEN 1 THEN
									waits.physical_io
								ELSE
									NULL
							END AS [physical_io],
							CASE waits.r
								WHEN 1 THEN
									waits.context_switches
								ELSE
									NULL
							END AS [context_switches],
							CASE waits.r
								WHEN 1 THEN
									waits.thread_CPU_snapshot
								ELSE
									NULL
							END AS [thread_CPU_snapshot],
							CASE waits.r
								WHEN 1 THEN
									waits.tasks
								ELSE
									NULL
							END AS [tasks],
							CASE waits.r
								WHEN 1 THEN
									waits.block_info
								ELSE
									NULL
							END AS [block_info],
							REPLACE
							(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
								REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
									CONVERT
									(
										NVARCHAR(MAX),
										N'(' +
											CONVERT(NVARCHAR, num_waits) + N'x: ' +
											CASE num_waits
												WHEN 1 THEN
													CONVERT(NVARCHAR, min_wait_time) + N'ms'
												WHEN 2 THEN
													CASE
														WHEN min_wait_time <> max_wait_time THEN
															CONVERT(NVARCHAR, min_wait_time) + N'/' + CONVERT(NVARCHAR, max_wait_time) + N'ms'
														ELSE
															CONVERT(NVARCHAR, max_wait_time) + N'ms'
													END
												ELSE
													CASE
														WHEN min_wait_time <> max_wait_time THEN
															CONVERT(NVARCHAR, min_wait_time) + N'/' + CONVERT(NVARCHAR, avg_wait_time) + N'/' + CONVERT(NVARCHAR, max_wait_time) + N'ms'
														ELSE 
															CONVERT(NVARCHAR, max_wait_time) + N'ms'
													END
											END +
										N')' + wait_type COLLATE Latin1_General_Bin2
									),
									NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
									NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
									NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
								NCHAR(0),
								N''
							) AS [waits]
						FROM
						(
							SELECT TOP(@i)
								w1.*,
								ROW_NUMBER() OVER
								(
									PARTITION BY
										w1.session_id,
										w1.request_id
									ORDER BY
										w1.block_info DESC,
										w1.num_waits DESC,
										w1.wait_type
								) AS r
							FROM
							(
								SELECT TOP(@i)
									task_info.session_id,
									task_info.request_id,
									task_info.physical_io,
									task_info.context_switches,
									task_info.thread_CPU_snapshot,
									task_info.num_tasks AS tasks,
									CASE
										WHEN task_info.runnable_time IS NOT NULL THEN
											'RUNNABLE'
										ELSE
											wt2.wait_type
									END AS wait_type,
									NULLIF(COUNT(COALESCE(task_info.runnable_time, wt2.waiting_task_address)), 0) AS num_waits,
									MIN(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS min_wait_time,
									AVG(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS avg_wait_time,
									MAX(COALESCE(task_info.runnable_time, wt2.wait_duration_ms)) AS max_wait_time,
									MAX(wt2.block_info) AS block_info
								FROM
								(
									SELECT TOP(@i)
										t.session_id,
										t.request_id,
										SUM(CONVERT(BIGINT, t.pending_io_count)) OVER (PARTITION BY t.session_id, t.request_id) AS physical_io,
										SUM(CONVERT(BIGINT, t.context_switches_count)) OVER (PARTITION BY t.session_id, t.request_id) AS context_switches, 
										CONVERT(BIGINT, NULL)  AS thread_CPU_snapshot, 
										COUNT(*) OVER (PARTITION BY t.session_id, t.request_id) AS num_tasks,
										t.task_address,
										t.task_state,
										CASE
											WHEN
												t.task_state = 'RUNNABLE'
												AND w.runnable_time > 0 THEN
													w.runnable_time
											ELSE
												NULL
										END AS runnable_time
									FROM sys.dm_os_tasks AS t
									CROSS APPLY
									(
										SELECT TOP(1)
											sp2.session_id
										FROM @sessions AS sp2
										WHERE
											sp2.session_id = t.session_id
											AND sp2.request_id = t.request_id
											AND sp2.status <> 'sleeping'
									) AS sp20
									LEFT OUTER HASH JOIN
									(
										SELECT TOP(@i)
											(
												SELECT TOP(@i)
													ms_ticks
												FROM sys.dm_os_sys_info
											) -
												w0.wait_resumed_ms_ticks AS runnable_time,
											w0.worker_address,
											w0.thread_address,
											w0.task_bound_ms_ticks
										FROM sys.dm_os_workers AS w0
										WHERE
											w0.state = 'RUNNABLE'
									) AS w ON
										w.worker_address = t.worker_address 
									) AS task_info
								LEFT OUTER HASH JOIN
								(
									SELECT TOP(@i)
										wt1.wait_type,
										wt1.waiting_task_address,
										MAX(wt1.wait_duration_ms) AS wait_duration_ms,
										MAX(wt1.block_info) AS block_info
									FROM
									(
										SELECT DISTINCT TOP(@i)
											wt.wait_type +
												CASE
													WHEN wt.wait_type LIKE N'PAGE%LATCH_%' THEN
														':' +
														COALESCE(DB_NAME(CONVERT(INT, LEFT(wt.resource_description, CHARINDEX(N':', wt.resource_description) - 1))), N'(null)') +
														N':' +
														SUBSTRING(wt.resource_description, CHARINDEX(N':', wt.resource_description) + 1, LEN(wt.resource_description) - CHARINDEX(N':', REVERSE(wt.resource_description)) - CHARINDEX(N':', wt.resource_description)) +
														N'(' +
															CASE
																WHEN
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) = 1 OR
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) % 8088 = 0
																		THEN 
																			N'PFS'
																WHEN
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) = 2 OR
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) % 511232 = 0 
																		THEN 
																			N'GAM'
																WHEN
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) = 3 OR
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) % 511233 = 0 
																		THEN 
																			N'SGAM'
																WHEN
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) = 6 OR
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) % 511238 = 0 
																		THEN 
																			N'DCM'
																WHEN
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) = 7 OR
																	CONVERT(INT, RIGHT(wt.resource_description, CHARINDEX(N':', REVERSE(wt.resource_description)) - 1)) % 511239 = 0
																		THEN 
																			N'BCM'
																ELSE
																	N'*'
															END +
														N')'
													WHEN wt.wait_type = N'CXPACKET' THEN
														N':' + SUBSTRING(wt.resource_description, CHARINDEX(N'nodeId', wt.resource_description) + 7, 4)
													WHEN wt.wait_type LIKE N'LATCH[_]%' THEN
														N' [' + LEFT(wt.resource_description, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 1) + N']'
													ELSE 
														N''
												END COLLATE Latin1_General_Bin2 AS wait_type,
											CASE
												WHEN
												(
													wt.blocking_session_id IS NOT NULL
													AND wt.wait_type LIKE N'LCK[_]%'
												) THEN
													(
														SELECT TOP(@i)
															x.lock_type,
															REPLACE
															(
																REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
																	DB_NAME
																	(
																		CONVERT
																		(
																			INT,
																			SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'dbid=', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'dbid=', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'dbid=', wt.resource_description) - 5)
																		)
																	),
																	NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
																	NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
																	NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
																NCHAR(0),
																N''
															) AS database_name,
															CASE x.lock_type
																WHEN N'objectlock' THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'objid=', wt.resource_description), 0) + 6, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'objid=', wt.resource_description) + 6), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'objid=', wt.resource_description) - 6)
																ELSE
																	NULL
															END AS object_id,
															CASE x.lock_type
																WHEN N'filelock' THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'fileid=', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'fileid=', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'fileid=', wt.resource_description) - 7)
																ELSE
																	NULL
															END AS file_id,
															CASE
																WHEN x.lock_type in (N'pagelock', N'extentlock', N'ridlock') THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'associatedObjectId=', wt.resource_description), 0) + 19, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'associatedObjectId=', wt.resource_description) + 19), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'associatedObjectId=', wt.resource_description) - 19)
																WHEN x.lock_type in (N'keylock', N'hobtlock', N'allocunitlock') THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'hobtid=', wt.resource_description), 0) + 7, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'hobtid=', wt.resource_description) + 7), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'hobtid=', wt.resource_description) - 7)
																ELSE
																	NULL
															END AS hobt_id,
															CASE x.lock_type
																WHEN N'applicationlock' THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'hash=', wt.resource_description), 0) + 5, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'hash=', wt.resource_description) + 5), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'hash=', wt.resource_description) - 5)
																ELSE
																	NULL
															END AS applock_hash,
															CASE x.lock_type
																WHEN N'metadatalock' THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'subresource=', wt.resource_description), 0) + 12, COALESCE(NULLIF(CHARINDEX(N' ', wt.resource_description, CHARINDEX(N'subresource=', wt.resource_description) + 12), 0), LEN(wt.resource_description) + 1) - CHARINDEX(N'subresource=', wt.resource_description) - 12)
																ELSE
																	NULL
															END AS metadata_resource,
															CASE x.lock_type
																WHEN N'metadatalock' THEN
																	SUBSTRING(wt.resource_description, NULLIF(CHARINDEX(N'classid=', wt.resource_description), 0) + 8, COALESCE(NULLIF(CHARINDEX(N' dbid=', wt.resource_description) - CHARINDEX(N'classid=', wt.resource_description), 0), LEN(wt.resource_description) + 1) - 8)
																ELSE
																	NULL
															END AS metadata_class_id
														FROM
														(
															SELECT TOP(1)
																LEFT(wt.resource_description, CHARINDEX(N' ', wt.resource_description) - 1) COLLATE Latin1_General_Bin2 AS lock_type
														) AS x
														FOR XML
															PATH('')
													)
												ELSE NULL
											END AS block_info,
											wt.wait_duration_ms,
											wt.waiting_task_address
										FROM
										(
											SELECT TOP(@i)
												wt0.wait_type COLLATE Latin1_General_Bin2 AS wait_type,
												wt0.resource_description COLLATE Latin1_General_Bin2 AS resource_description,
												wt0.wait_duration_ms,
												wt0.waiting_task_address,
												CASE
													WHEN wt0.blocking_session_id = p.blocked THEN
														wt0.blocking_session_id
													ELSE
														NULL
												END AS blocking_session_id
											FROM sys.dm_os_waiting_tasks AS wt0
											CROSS APPLY
											(
												SELECT TOP(1)
													s0.blocked
												FROM @sessions AS s0
												WHERE
													s0.session_id = wt0.session_id
													AND COALESCE(s0.wait_type, N'') <> N'OLEDB'
													AND wt0.wait_type <> N'OLEDB'
											) AS p
										) AS wt
									) AS wt1
									GROUP BY
										wt1.wait_type,
										wt1.waiting_task_address
								) AS wt2 ON
									wt2.waiting_task_address = task_info.task_address
									AND wt2.wait_duration_ms > 0
									AND task_info.runnable_time IS NULL
								GROUP BY
									task_info.session_id,
									task_info.request_id,
									task_info.physical_io,
									task_info.context_switches,
									task_info.thread_CPU_snapshot,
									task_info.num_tasks,
									CASE
										WHEN task_info.runnable_time IS NOT NULL THEN
											'RUNNABLE'
										ELSE
											wt2.wait_type
									END
							) AS w1
						) AS waits
						ORDER BY
							waits.session_id,
							waits.request_id,
							waits.r
						FOR XML
							PATH(N'tasks'),
							TYPE
					) AS tasks_raw (task_xml_raw)
				) AS tasks_final
				CROSS APPLY tasks_final.task_xml.nodes(N'/tasks') AS task_nodes (task_node)
				WHERE
					task_nodes.task_node.exist(N'session_id') = 1
			) AS tasks ON
				tasks.session_id = y.session_id
				AND tasks.request_id = y.request_id 
			LEFT OUTER HASH JOIN
	(
		SELECT TOP(@i)
			t_info.session_id,
			COALESCE(t_info.request_id, -1) AS request_id,
			SUM(t_info.tempdb_allocations) AS tempdb_allocations,
			SUM(t_info.tempdb_current) AS tempdb_current
		FROM
		(
			SELECT TOP(@i)
				tsu.session_id,
				tsu.request_id,
				tsu.user_objects_alloc_page_count +
					tsu.internal_objects_alloc_page_count AS tempdb_allocations,
				tsu.user_objects_alloc_page_count +
					tsu.internal_objects_alloc_page_count -
					tsu.user_objects_dealloc_page_count -
					tsu.internal_objects_dealloc_page_count AS tempdb_current
			FROM sys.dm_db_task_space_usage AS tsu
			CROSS APPLY
			(
				SELECT TOP(1)
					s0.session_id
				FROM @sessions AS s0
				WHERE
					s0.session_id = tsu.session_id
			) AS p

			UNION ALL

			SELECT TOP(@i)
				ssu.session_id,
				NULL AS request_id,
				ssu.user_objects_alloc_page_count +
					ssu.internal_objects_alloc_page_count AS tempdb_allocations,
				ssu.user_objects_alloc_page_count +
					ssu.internal_objects_alloc_page_count -
					ssu.user_objects_dealloc_page_count -
					ssu.internal_objects_dealloc_page_count AS tempdb_current
			FROM sys.dm_db_session_space_usage AS ssu
			CROSS APPLY
			(
				SELECT TOP(1)
					s0.session_id
				FROM @sessions AS s0
				WHERE
					s0.session_id = ssu.session_id
			) AS p
		) AS t_info
		GROUP BY
			t_info.session_id,
			COALESCE(t_info.request_id, -1)
	) AS tempdb_info ON
		tempdb_info.session_id = y.session_id
		AND tempdb_info.request_id =
			CASE
				WHEN y.status = N'sleeping' THEN
					-1
				ELSE
					y.request_id
			END
	) AS x
OPTION (RECOMPILE)
--OPTION (KEEPFIXED PLAN, OPTIMIZE FOR (@i = 1)); 







