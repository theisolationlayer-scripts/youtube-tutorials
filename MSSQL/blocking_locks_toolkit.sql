/*******************************************************************************
  THE ISOLATION LAYER - www.youtube.com/@theisolationlayer
  How to Detect and Resolve Blocking Locks in SQL Server

  IMPORTANT: Always test scripts in a development/staging environment before 
  running in production. The author is not responsible for any impact, data 
  loss, or downtime resulting from the use of this script.
*******************************************************************************/

--Simple query - determine if you have an issue
SELECT 
    session_id AS WaitingSessionID,
    blocking_session_id AS BlockerSessionID,
    wait_type AS WaitType,
    wait_time / 1000 AS WaitTimeSeconds,
    wait_resource AS WaitResource,
    status AS [Status]
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0;

--More details - what is the SQL running?
SELECT 
    r.session_id AS BlockedSessionID,
    r.blocking_session_id AS HeadBlockerSessionID,
    r.wait_time AS WaitTimeMS,
    r.wait_type AS WaitType,
    r.wait_resource AS BlockedResource,
    blocked_text.text AS BlockedQueryText,
    blocker_text.text AS BlockerQueryText,
    s.login_name AS BlockedUser,
    s.host_name AS BlockedHost,
    s.program_name AS BlockedApp
FROM sys.dm_exec_requests r
INNER JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS blocked_text
LEFT JOIN sys.dm_exec_connections c ON r.blocking_session_id = c.session_id
LEFT JOIN sys.dm_exec_sessions s_block ON r.blocking_session_id = s_block.session_id
CROSS APPLY sys.dm_exec_sql_text(COALESCE(c.most_recent_sql_handle, r.sql_handle)) AS blocker_text
WHERE r.blocking_session_id <> 0;

--Full picture - visual blocker tree
SET NOCOUNT ON 
GO
SELECT SPID, BLOCKED, REPLACE (REPLACE (T.TEXT, CHAR(10), ' '), CHAR (13), ' ' ) AS BATCH 
INTO #T 
FROM sys.sysprocesses R CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T 
GO
WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH) AS ( 
  SELECT SPID, 
  BLOCKED, 
  CAST (REPLICATE ('0', 4-LEN (CAST (SPID AS VARCHAR))) + CAST (SPID AS VARCHAR) AS VARCHAR (1000)) AS LEVEL, 
  BATCH FROM #T R 
  WHERE (BLOCKED = 0 OR BLOCKED = SPID) 
               AND EXISTS (SELECT * FROM #T R2 WHERE R2.BLOCKED = R.SPID AND R2.BLOCKED <> R2.SPID) 
  UNION ALL 
 SELECT R.SPID, R.BLOCKED, 
  CAST (BLOCKERS.LEVEL + RIGHT (CAST ((1000 + R.SPID) AS VARCHAR (100)), 4) AS VARCHAR (1000)) AS LEVEL, R.BATCH FROM #T AS R 
 INNER JOIN BLOCKERS ON R.BLOCKED = BLOCKERS.SPID WHERE R.BLOCKED > 0 AND R.BLOCKED <> R.SPID 
) 
SELECT N'    ' + REPLICATE (N'|         ', LEN (LEVEL)/4 - 1) + 
       CASE WHEN (LEN(LEVEL)/4 - 1) = 0 
  THEN 'HEAD -  ' 
  ELSE '|------  ' END 
  + CAST (SPID AS NVARCHAR (10)) + N' ' + BATCH AS BLOCKING_TREE 
FROM BLOCKERS ORDER BY LEVEL ASC 
GO
DROP TABLE #T 
GO



