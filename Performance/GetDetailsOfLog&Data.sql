USE x3v6
GO
DECLARE @SQL VARCHAR(8000), @sname VARCHAR(3)
SELECT @sname=CONVERT(VARCHAR(3),SERVERPROPERTY('PRODUCTVERSION'))
SELECT @sname=CONVERT(TINYINT,SUBSTRING(@sname,1,CHARINDEX('.',@sname)-1))
IF @sname<>8
BEGIN
SET @SQL ='SELECT DB_NAME() [DBName]
,[name] [Filename]
,type_desc [Type]
,physical_name [FilePath]
,CONVERT(FLOAT,[size]/128) [TotalSize_MB]
,size/128.0 - CONVERT(INT,FILEPROPERTY(name, ''SpaceUsed''))/128.0 AS [Available_Space_MB]
,CASE is_percent_growth
WHEN 1 THEN CONVERT(VARCHAR(5),growth)+''%''
ELSE CONVERT(VARCHAR(20),(growth/128))+'' MB''
END [Autogrow_Value]
,CASE max_size
WHEN -1 THEN CASE growth
WHEN 0 THEN CONVERT(VARCHAR(30),''Restricted'')
ELSE CONVERT(VARCHAR(30),''Unlimited'') END
ELSE CONVERT(VARCHAR(25),max_size/128)
END [Max_Size]
FROM sys.database_files'
END
ELSE
BEGIN
SET @SQL ='SELECT DB_NAME() [DBName]
,[name] [Filename]
,CASE STATUS & 0x40 WHEN 0x40 THEN ''LOG'' ELSE ''ROWS'' END [Type]
,filename [FilePath]
,size/128.0 AS [TotalSize_MB]
,CONVERT(INT,FILEPROPERTY(name, ''SpaceUsed''))/128.0 [Space_Used_MB]
,CASE STATUS & 0x100000 WHEN 0x100000 THEN convert(NVARCHAR(3), growth) + ''%''
ELSE CONVERT(NVARCHAR(15), (growth * 8)/1024) + '' MB'' END [Autogrow_Value]
,CASE maxsize WHEN -1 THEN CASE growth WHEN 0 THEN ''Restricted'' ELSE N''Unlimited'' END
ELSE CONVERT(NVARCHAR(15), (maxsize * 8)/1024) + '' MB'' END [Max_Size]
FROM sysfiles
END'
END
EXEC (@SQL)
