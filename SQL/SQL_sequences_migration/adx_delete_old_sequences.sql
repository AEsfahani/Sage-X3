USE CHANGE_TO_YOUR_X3_DATABASE
GO

/* check SQL Server version --------------------------------------------------- */	
DECLARE @char_vers NVARCHAR(100)
SET @char_vers = CAST( SERVERPROPERTY('ProductVersion') AS NVARCHAR)
SET @char_vers = SUBSTRING(@char_vers, 1, CHARINDEX('.', @char_vers)-1)
IF (CAST( @char_vers AS INTEGER) < 11)
BEGIN
	PRINT 'Version '+@char_vers+' of SQL Server doesn''t suport sequence object'
	SET NOEXEC ON
END
GO

/* check x3 database ---------------------------------------------------------- */
DECLARE @pr_name SYSNAME
SET @pr_name = ''
SELECT @pr_name = pr.name FROM sys.procedures pr
	INNER JOIN sys.schemas sch
		ON pr.schema_id = sch.schema_id
WHERE sch.name = 'dbo' AND pr.name = 'adx_get_sequence_next_value'
ORDER BY pr.name
IF (@pr_name = '')
BEGIN
	print 'The procedure dbo.adx_get_sequence_next_value doesn''t exist, check your current database'
	SET NOEXEC ON
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE adx_delete_old_sequences @schema_name SYSNAME, @test INTEGER
AS
DECLARE @schema_id INTEGER
DECLARE @tb_name SYSNAME
DECLARE @pr_name SYSNAME
DECLARE @sq_name SYSNAME
DECLARE @drop_seq NVARCHAR(max)
BEGIN
	SET NOCOUNT ON;
	
	/* check x3 database ---------------------------------------------------------- */
	SELECT @pr_name = pr.name FROM sys.procedures pr
		INNER JOIN sys.schemas sch
			ON pr.schema_id = sch.schema_id
	WHERE sch.name = 'dbo' AND pr.name = 'adx_get_sequence_next_value'
	ORDER BY pr.name
	IF (@pr_name = '')
	BEGIN
		PRINT 'The procedure dbo.adx_get_sequence_next_value doesn''t exist, check your current database'
		RETURN
	END

	/* check parameters	----------------------------------------------------------- */
	SELECT @schema_id = sch.schema_id FROM sys.schemas sch
	WHERE sch.name = @schema_name 
	IF (@schema_id = 0)
	BEGIN
		PRINT 'Schema ' + @schema_name+' not exists'
		RETURN
	END
		
	/* retrieve tables from schema name -------------------------------------------- */
	DECLARE tables_cursor cursor for
	SELECT tb.name FROM sys.tables tb
		INNER JOIN sys.schemas sch
			ON tb.schema_id = sch.schema_id
	WHERE sch.name = @schema_name AND tb.name LIKE '$SEQ%'
	ORDER BY tb.name
	
	OPEN tables_cursor
	FETCH NEXT FROM tables_cursor INTO @tb_name
		
	WHILE @@fetch_status = 0
	BEGIN
		set @drop_seq = 'drop table ['+@schema_name+'].['+@tb_name+']'
		IF (@test <> 0)
		BEGIN
			PRINT @drop_seq
		END
		ELSE
		BEGIN
			BEGIN TRY 
				EXEC sp_executesql @drop_seq
				PRINT 'sequence '+@tb_name+' dropped'
			END TRY
			BEGIN CATCH
				PRINT CAST( error_number() AS NVARCHAR) + ' '+ error_message( )
			END CATCH
		END		
		FETCH NEXT FROM tables_cursor INTO @tb_name
	END

	CLOSE tables_cursor
	DEALLOCATE tables_cursor
END
GO
SET NOEXEC OFF
GO
