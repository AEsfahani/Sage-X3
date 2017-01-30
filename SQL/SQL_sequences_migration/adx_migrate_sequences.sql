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

CREATE PROCEDURE adx_migrate_sequences @schema_name SYSNAME, @schema_mother_name SYSNAME, @test INTEGER
AS
DECLARE @val INTEGER
DECLARE @tb_name SYSNAME
DECLARE @sq_name SYSNAME
DECLARE @pr_name SYSNAME
DECLARE @seq_create NVARCHAR(max)
DECLARE @seq_grant NVARCHAR(max)
DECLARE @fullname NVARCHAR(100)
DECLARE @schema_id INTEGER
DECLARE @schema_mother_id INTEGER
DECLARE @mother_role NVARCHAR(100)
DECLARE @ok	INTEGER
BEGIN	
	SET NOCOUNT ON;
	SET @schema_id = 0
	SET @schema_mother_id = 0

	/* check x3 database ---------------------------------------------------------- */
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

	/* check parameters	----------------------------------------------------------- */
	SELECT @schema_id = sch.schema_id FROM sys.schemas sch
	WHERE sch.name = @schema_name 
	IF (@schema_id = 0)
	BEGIN
		PRINT 'Schema ' + @schema_name+' not exists'
		RETURN
	END

	SET @mother_role = ''
	SELECT @mother_role = name FROM sys.database_principals WHERE name = @schema_mother_name+'_ADX_SYS'
	IF (@mother_role = '')
	BEGIN
		PRINT 'Schema '+@schema_mother_name+' is not associated to a mother application'
		RETURN
	END

	SELECT @schema_mother_id = sch.schema_id FROM sys.schemas sch
	WHERE sch.name = @schema_mother_name 
	IF (@schema_mother_id = 0)
	BEGIN
		PRINT 'Schema '+@schema_mother_name+' not exists'
		RETURN
	END

	/* retrieve tables from schema name -------------------------------------------- */
	DECLARE tables_cursor CURSOR FOR
	SELECT tb.name FROM sys.tables tb
		INNER JOIN sys.schemas sch
			ON tb.schema_id = sch.schema_id
	WHERE sch.name = @schema_name AND tb.name NOT LIKE '$SEQ%'
	ORDER BY tb.name
	
	OPEN tables_cursor
	FETCH NEXT FROM tables_cursor INTO @tb_name
	
	WHILE @@fetch_status = 0
	BEGIN
		SET @val = 0
		
		/* check old sequence existence ------------------------------------------------ */
		SET @sq_name = ''
		SELECT @sq_name = tb.name FROM sys.tables tb
			INNER JOIN sys.schemas sch
				ON tb.schema_id = sch.schema_id
		WHERE sch.name = @schema_name AND tb.name = '$SEQ_'+@tb_name
		ORDER BY tb.name

		IF (@sq_name = '')
		BEGIN
			IF (@test <> 0)			
				PRINT 'Warning : Sequence '+@schema_name+'.$SEQ_'+@tb_name+' doesn''t exist'

			FETCH NEXT FROM tables_cursor INTO @tb_name
			CONTINUE
		END

		/* check new sequence existence -----------------------------------------------*/
		SET @sq_name = ''
		SELECT @sq_name = tb.name FROM sys.sequences tb
			INNER JOIN sys.schemas sch
				ON tb.schema_id = sch.schema_id
		WHERE sch.name = @schema_name AND tb.name = 'SEQ_'+@tb_name
		ORDER BY tb.name
		
		IF (@sq_name <> '')
		BEGIN
			IF (@test <> 0)			
				PRINT 'Warning : Sequence '+@schema_name+'.SEQ_'+@tb_name+' already exists'

			FETCH NEXT FROM tables_cursor INTO @tb_name
			CONTINUE
		END

		/* retrieve sequence value ---------------------------------------------------- */
		SET @fullname = [dbo].[adx_get_sequence_table](@schema_name, @tb_name)
		SET @val = IDENT_CURRENT(@fullname)+1

		IF ((@val <> 0) AND (@val IS NOT NULL))
		BEGIN						
			IF (@test <> 0) PRINT 'Current sequence value of '+@fullname+' : '+CAST( @val-1 AS NVARCHAR )

			/* create query	---------------------------------------------------------*/
			SET @seq_create = N'Create Sequence '+ @schema_name+'.SEQ_'+@tb_name+'  AS INT START WITH ' +CAST( @val AS NVARCHAR ) +' INCREMENT BY 1'
			IF (@test <> 0) PRINT @seq_create
			SET @seq_grant = N'Grant Update On '+ @schema_name+'.SEQ_'+@tb_name+' to '+@schema_mother_name+'_ADX_SYS'
			IF (@test <> 0) PRINT @seq_grant

			/* query execution	---------------------------------------------------- */
			IF (@test = 0)
			BEGIN
				PRINT @tb_name+' sequence migration...'
				BEGIN TRY 
					EXEC sp_executesql @seq_create
					EXEC sp_executesql @seq_grant
					PRINT @tb_name+' sequence migrated'
				END TRY
				BEGIN CATCH
					PRINT cast( error_number() AS NVARCHAR) + ' '+ error_message( )
				END CATCH
			END						
		END
		ELSE
			PRINT @tb_name + ' has no value ('+CAST( @val AS NVARCHAR )+')'
		
		FETCH NEXT FROM tables_cursor INTO @tb_name
	END
	
	CLOSE tables_cursor
	DEALLOCATE tables_cursor
END
GO
SET NOEXEC OFF
GO
