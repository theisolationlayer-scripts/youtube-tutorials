/*******************************************************************************
  THE ISOLATION LAYER - www.youtube.com/@theisolationlayer
  Changing instance collation on SQL Server

  IMPORTANT: Always test scripts in a development/staging environment before 
  running in production. The author is not responsible for any impact, data 
  loss, or downtime resulting from the use of this script.
*******************************************************************************/

--Method #1 - supported by Microsoft
sqlcmd -S win1 -U sa -P Password1234 -C
select convert(varchar(256), SERVERPROPERTY('collation'));
GO
select name from sys.databases;
GO
exit
  
net stop "SQL Server (MSSQLSERVER)"
  
C:\Program Files\Microsoft SQL Server\170\Setup Bootstrap\SQL2025> .\setup.exe /QUIET /ACTION=REBUILDDATABASE /INSTANCENAME=MSSQLServer /SQLSYSADMINACCOUNTS=“win1\administrator” /SQLCOLLATION=Latin1_General_CS_AS /SAPWD=Password1234

net start "SQL Server (MSSQLSERVER)"
    
sqlcmd -S win1 -U sa -P Password1234 -C
select convert(varchar(256), SERVERPROPERTY('collation'));
GO
select name from sys.databases;
GO

--Method #2 - not supported by Microsoft
sqlcmd -S win1 -U sa -P Password1234 -C
select convert(varchar(256), SERVERPROPERTY('collation'));
GO
select name from sys.databases;
GO
exit
  
net stop "SQL Server (MSSQLSERVER)"
  
“C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Binn\sqlservr.exe" -m -T4022 -T3659 =s”MSSQLServer” -q”SQL_Latin1_General_CP1_CI_AS”
  
--Control - C and then start the instance and check it all again:
  
net start "SQL Server (MSSQLSERVER)"
  
sqlcmd -S win1 -U sa -P Password1234 -C
select convert(varchar(256), SERVERPROPERTY('collation'));
GO
select name from sys.databases;
GO
exit
