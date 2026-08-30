-- RESPALDO DE OBJETOS ANTES DEL DROP
-- Base: db_acd593_sigma

-- ============================================================
-- SQL_STORED_PROCEDURE : DEL_ARCHIVO
-- ============================================================
-- =============================================
-- AUTHOR:         HECTOR LOHAUS
-- FECHA CREACIÓN: 06-02-2025
-- DESCRIPTION:    ELIMINA ARCHIVOS
-- =============================================
CREATE PROCEDURE [dbo].[DEL_ARCHIVO]
@ID_ARCHIVO INT OUTPUT

AS
SET NOCOUNT ON


BEGIN TRANSACTION

    --1.- ELIMINO EL BINARIO EN LA TABLA ARCHIVO_BINARIO
	BEGIN 
        DELETE FROM ARCHIVO_BINARIO
        WHERE ABI_ID = @ID_ARCHIVO

        IF @@ROWCOUNT = 0 BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX)
            SET @VARIABLES = 'DEL_ARCHIVO_BINARIO ' + 
'                             @ID_ARCHIVO = ' + CAST(@ID_ARCHIVO AS VARCHAR(20))
            EXEC INS_EXCEPCION 
                @MSG = '1.- NO FUE POSIBLE ELIMINAR EL REGISTRO.',
                @VARIABLES = @VARIABLES
            RETURN -1
        END
    END

    --2.- ELIMINO EL ID EN LA TABLA ARCHIVO
    BEGIN 
        DELETE FROM ARCHIVO
        WHERE ARC_ID = @ID_ARCHIVO

        IF @@ROWCOUNT = 0 BEGIN
            ROLLBACK TRANSACTION
            SET @VARIABLES = 'DEL_ARCHIVO ' + 
                             '@ID_ARCHIVO = ' + CAST(@ID_ARCHIVO AS VARCHAR(20))

            EXEC INS_EXCEPCION 
                @MSG = '2.- NO FUE POSIBLE ELIMINAR EL REGISTRO.',
                @VARIABLES = @VARIABLES
            RETURN -2
        END 
    END

    COMMIT TRANSACTION
    RETURN 0
   
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : DEL_CHECKLIST
-- ============================================================
-- =============================================
-- AUTHOR:         CRUD
-- FECHA CREACIÓN: 05-02-2025
-- DESCRIPTION:    DELETE REGISTRO
-- =============================================
CREATE PROCEDURE [dbo].[DEL_CHECKLIST]
@ID INT
,@USUARIO INT 
AS
SET NOCOUNT ON

-- VALIDACION DE HORA
BEGIN
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = UPA_ID_PAIS
		FROM   USUARIO_PAISES
		WHERE  UPA_ID_USUARIO = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()
END

BEGIN TRANSACTION

	 -- Validar si existen elementos en CHECKLIST_DETALLE asociados al CHECKLIST
    IF EXISTS (SELECT TOP 1 1 FROM CHECKLIST_DETALLE WHERE CHD_ID_CHECKLIST = @ID)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('No se puede eliminar el checklist porque tiene elementos asociados.', 16, 1);
        RETURN -1
    END

		 -- Validar si existen elementos del checklist asociados a un Cliente Instalacion
    IF EXISTS (SELECT TOP 1 1 FROM CLIENTE_INSTALACION_ZONA_CHECKLIST WHERE czc_id_checklist  = @ID)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR('No se puede eliminar el checklist porque tiene un cliente / instalación asociado .', 16, 1);
        RETURN -1
    END


	-- ACTUALIZO USUARIO Y FECHA PARA LOG
	BEGIN
		UPDATE CHECKLIST 
		SET chk_usuario_act = @USUARIO,
			chk_fecha_act = @DATE_NOW
		WHERE CHK_ID = @ID
	END

	DELETE FROM CHECKLIST WHERE CHK_ID = @ID;

	IF @@ROWCOUNT = 0 
		BEGIN
			ROLLBACK TRANSACTION;
			RAISERROR('No fue posible eliminar el registro del CHECKLIST.', 16, 1);
			RETURN -2;
		END;

COMMIT TRANSACTION
RETURN(0)



GO

-- ============================================================
-- SQL_STORED_PROCEDURE : DEL_CHECKLIST_DETALLE
-- ============================================================
-- =============================================
-- Author:			BRYAN CHAVEZ
-- Fecha creación:	05-02-2025
-- Description:		ELIMINA CHECKLIST DETALLE
-- =============================================
CREATE PROCEDURE [dbo].[DEL_CHECKLIST_DETALLE]
@ID INT
,@USUARIO INT 
AS
SET NOCOUNT ON

-- VALIDACION DE HORA
BEGIN
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = UPA_ID_PAIS
		FROM   USUARIO_PAISES
		WHERE  UPA_ID_USUARIO = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()
END


BEGIN TRANSACTION

	IF EXISTS(SELECT TOP 1 1 FROM CHECKLIST_DETALLE_COMBOBOX WHERE CDC_ID_CHECKLIST_DETALLE = @ID) BEGIN

		DELETE	CHECKLIST_DETALLE_COMBOBOX
		WHERE	CDC_ID_CHECKLIST_DETALLE =  @ID

		IF @@ROWCOUNT = 0 BEGIN
			ROLLBACK TRANSACTION
			DECLARE @VARIABLES VARCHAR(MAX)
			SET @VARIABLES = 'DEL_CHECKLIST ' + LTRIM(STR(@ID)) 
		
			EXEC INS_EXCEPCION 
				@MSG = '2.- No fue posible eliminar el detalle del Checklist.',
				@VARIABLES = @VARIABLES
			RETURN -2  
		END
	END

	-- ACTUALIZO USUARIO Y FECHA PARA LOG
	BEGIN
		UPDATE CHECKLIST_DETALLE 
		SET chd_usuario_act = @USUARIO,
			chd_fecha_act = @DATE_NOW
		WHERE chd_id = @ID
	END

	DELETE	CHECKLIST_DETALLE
	WHERE	CHD_ID = @ID
	
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		SET @VARIABLES = 'DEL_CHECKLIST ' + LTRIM(STR(@ID)) 
		
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible eliminar el detalle del Checklist.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : DEL_CHECKLIST_DETALLE_OBJETO
-- ============================================================
-- =============================================
-- Author:			BRYAN CHAVEZ
-- Fecha creación:	06-02-2025
-- Description:		ELIMINA CHECKLIST DETALLE_ OBJETO
-- =============================================
CREATE PROCEDURE [dbo].[DEL_CHECKLIST_DETALLE_OBJETO]
@ID INT
,@USUARIO INT 
AS
SET NOCOUNT ON

-- VALIDACION DE HORA
BEGIN
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = UPA_ID_PAIS
		FROM   USUARIO_PAISES
		WHERE  UPA_ID_USUARIO = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()
END

BEGIN TRANSACTION


		-- ACTUALIZO USUARIO Y FECHA PARA LOG
		BEGIN
			UPDATE CHECKLIST_DETALLE_COMBOBOX 
			SET cdc_usuario_act = @USUARIO,
				cdc_fecha_act = @DATE_NOW
			WHERE cdc_id = @ID
		END

        DELETE FROM CHECKLIST_DETALLE_COMBOBOX WHERE CDC_ID = @ID;

        IF @@ROWCOUNT = 0 
        BEGIN
            ROLLBACK TRANSACTION;
			DECLARE @VARIABLES VARCHAR(MAX)
            SET @VARIABLES = 'DEL_CHECKLIST_DETALLE_OBJETO ' + LTRIM(STR(@ID));

            EXEC INS_EXCEPCION 
                @MSG = '1.- No fue posible eliminar el detalle del Checklist.',
                @VARIABLES = @VARIABLES;
            RETURN -2
        END
    
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : DEL_CLIENTE
-- ============================================================
-- =============================================
-- Author:			Diego Castillo
-- Fecha creación:	15-03-2023
-- Description:		Eliminar Cliente
-- =============================================
CREATE PROCEDURE [dbo].[DEL_CLIENTE]
@ID INT
,@USUARIO INT 
AS
SET NOCOUNT ON

IF (EXISTS(SELECT TOP 1 1 FROM CHECKLIST WHERE CHK_CLIENTE = @ID)) BEGIN
	RAISERROR('1. No es posible eliminar, el cliente posee CheckList', 16, 1);
	RETURN -1;
END

IF (EXISTS(SELECT TOP 1 1 FROM CLIENTE_INSTALACION WHERE CIN_CLIENTE = @ID)) BEGIN
	RAISERROR('1. No es posible eliminar, el cliente posee Instalaciones', 16, 1);
	RETURN -1;
END

-- VALIDACION DE HORA
BEGIN
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = CLI_PAIS
		FROM   CLIENTE
		WHERE  CLI_ID = @ID

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()
END


BEGIN TRANSACTION


	-- ACTUALIZO USUARIO Y FECHA PARA LOG
	BEGIN
		UPDATE CLIENTE_USUARIO 
		SET UCL_USUARIO_ACT = @USUARIO,
			UCL_FECHA_ACT = @DATE_NOW
		WHERE UCL_ID = @ID
	END

		-- ACTUALIZO USUARIO Y FECHA PARA LOG
	BEGIN
		UPDATE CLIENTE 
		SET CLI_USUARIO_ACTUALIZACION = @USUARIO,
			CLI_FECHA_ACTUALIZACION = @DATE_NOW
		WHERE CLI_ID = @ID
	END


	DELETE	CLIENTE_USUARIO_PERFIL
	WHERE	CUP_ID_CLIENTE_USUARIO IN (SELECT UCL_ID FROM CLIENTE_USUARIO WHERE	UCL_ID_CLIENTE = @ID)

	DELETE	CLIENTE_USUARIO
	WHERE	UCL_ID_CLIENTE = @ID

	DELETE	CLIENTE
	WHERE	CLI_ID = @ID
			
	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'DEL_CLIENTE ' + LTRIM(STR(@ID))
		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Eliminar el Cliente.',
			@VARIABLES = @VARIABLES
		RETURN -1 
	END

COMMIT TRANSACTION

RETURN(0)
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : INS_ARCHIVO
-- ============================================================
-- =============================================
-- AUTHOR:         HECTOR LOHAUS
-- FECHA CREACIÓN: 06-02-2025
-- DESCRIPTION:    INSERTA ARCHIVOS
-- =============================================
CREATE PROCEDURE [dbo].[INS_ARCHIVO]
@ID INT = NULL OUTPUT
,@NOMBRE_ARCHIVO VARCHAR(200)
,@DESCRIPCION VARCHAR(200)
,@CONTENIDO VARCHAR(200)
,@EXTENSION VARCHAR(200)
,@TAMANO VARCHAR(200)
,@ARCHIVO_BINARIO VARBINARY(MAX) = NULL

AS

SET NOCOUNT ON;
  
BEGIN TRANSACTION

    --1.- INSERTO EL BINARIO EN LA TABLA ARCHIVO_BINARIO
	BEGIN 
		INSERT INTO ARCHIVO_BINARIO
			(
				ABI_ARCHIVO_BINARIO
			)
		VALUES
			(
				@ARCHIVO_BINARIO
			)
			
		DECLARE @ARCHIVO INT
		SET @ARCHIVO = SCOPE_IDENTITY()

		IF @@ROWCOUNT = 0 BEGIN
			ROLLBACK TRANSACTION
			DECLARE @VARIABLES VARCHAR(MAX)
			SET @VARIABLES = 'INS_ARCHIVO ' + 
								'@NOMBRE_ARCHIVO = ' + LTRIM(@NOMBRE_ARCHIVO) + ', ' + 
								'@DESCRIPCION = ' + LTRIM(@DESCRIPCION) + ', ' + 
								'@CONTENIDO = ' + LTRIM(@CONTENIDO) + ', ' + 
								'@EXTENSION = ' + LTRIM(@EXTENSION) + ', ' + 
								'@TAMANO = ' + LTRIM(@TAMANO)

			EXEC INS_EXCEPCION 
				@MSG = '1.- NO FUE POSIBLE CREAR EL REGISTRO.',
				@VARIABLES = @VARIABLES
			RETURN -1
		END

	END

	--2.- INSERTO EL ID EN LA TABLA ARCHIVO
	BEGIN 
		INSERT INTO ARCHIVO
			(
				ARC_NOMBRE_ARCHIVO
				,ARC_DESCRIPCION
				,ARC_CONTENIDO
				,ARC_EXTENSION
				,ARC_TAMANO
				,ARC_ARCHIVO
			)
        VALUES
			(
				@NOMBRE_ARCHIVO
				,@DESCRIPCION
				,@CONTENIDO
				,@EXTENSION
				,@TAMANO
				,@ARCHIVO
			)

		SET @ID = SCOPE_IDENTITY()

		IF @@ROWCOUNT = 0 BEGIN
			ROLLBACK TRANSACTION
			SET @VARIABLES = 'INS_ARCHIVO ' + 
								'@NOMBRE_ARCHIVO = ' + LTRIM(@NOMBRE_ARCHIVO) + ', ' + 
								'@DESCRIPCION = ' + LTRIM(@DESCRIPCION) + ', ' + 
								'@CONTENIDO = ' + LTRIM(@CONTENIDO) + ', ' + 
								'@EXTENSION = ' + LTRIM(@EXTENSION) + ', ' + 
								'@TAMANO = ' + LTRIM(@TAMANO)

			EXEC INS_EXCEPCION 
				@MSG = '2.- NO FUE POSIBLE CREAR EL REGISTRO.',
				@VARIABLES = @VARIABLES
			RETURN -2
		END 

	END
		
COMMIT TRANSACTION
RETURN 0
   
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : INS_CHECKLIST
-- ============================================================
-- =============================================
-- AUTHOR:         CRUD
-- FECHA CREACIÓN: 05-02-2025
-- DESCRIPTION:    INSERTA REGISTRO
-- =============================================
CREATE PROCEDURE [dbo].[INS_CHECKLIST]
@ID INT OUTPUT,
@CLIENTE INT,
@NOMBRE VARCHAR(200),
@DESCRIPCION VARCHAR(MAX),
@USUARIO INT,
@HABILITADO BIT

AS
SET NOCOUNT ON

BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT

	SELECT	@PAIS = CLI_PAIS
	FROM	CLIENTE
	WHERE	CLI_ID = @CLIENTE
	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION

   INSERT INTO CHECKLIST
       (
           CHK_CLIENTE
           ,CHK_NOMBRE
           ,CHK_DESCRIPCION
           ,CHK_USUARIO_CREACION
           ,CHK_FECHA_CREACION
           ,CHK_USUARIO_ACT
           ,CHK_FECHA_ACT
		   ,CHK_HABILITADO
       )
   VALUES
       (
           @CLIENTE
           ,@NOMBRE
           ,@DESCRIPCION
           ,@USUARIO
           ,@DATE_NOW
           ,@USUARIO
           ,@DATE_NOW
		   ,@HABILITADO
       )

   SET @ID = SCOPE_IDENTITY()

   IF @@ROWCOUNT = 0 BEGIN
       ROLLBACK TRANSACTION
       DECLARE @VARIABLES VARCHAR(MAX)
         SET @VARIABLES = 'INS_CHECKLIST ' + 
                         '@ID = ' + LTRIM(STR(@ID)) + ', ' + 
                         '@CLIENTE = ' + LTRIM(STR(@CLIENTE)) + ', ' + 
                         '@NOMBRE = ' + LTRIM(@NOMBRE) + ', ' + 
						 '@HABILITADO = ' + LTRIM(@HABILITADO) + ', ' + 
                         '@DESCRIPCION = ' + LTRIM(@DESCRIPCION)

       EXEC INS_EXCEPCION 
           @MSG = '1.- NO FUE POSIBLE CREAR EL REGISTRO.',
           @VARIABLES = @VARIABLES
       RETURN -1
   END

COMMIT TRANSACTION
RETURN(0)





GO

-- ============================================================
-- SQL_STORED_PROCEDURE : INS_CHECKLIST_DETALLE
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		INSERTA CHECKLIST DETALLE
-- =============================================
CREATE PROCEDURE [dbo].[INS_CHECKLIST_DETALLE]
@ID INT = NULL OUTPUT,
@ID_CHECKLIST INT,
@PREGUNTA VARCHAR(8000),
@OBJETO INT,
@USUARIO INT,
@VALOR_PRED BIT = NULL,
@VALOR VARCHAR(200) = NULL,
@HABILITADO BIT = NULL,
@NOTIFICACION BIT = NULL

AS
SET NOCOUNT ON

DECLARE @ORDEN INT = 1

-- ORDEN DEL CHECKLIST
IF EXISTS(SELECT TOP 1 1 FROM CHECKLIST_DETALLE WHERE CHD_ID_CHECKLIST = @ID_CHECKLIST) BEGIN

	SELECT  @ORDEN = MAX(ISNULL(CHD_ORDEN, 0)) + 1
	FROM	CHECKLIST_DETALLE
	WHERE	CHD_ID_CHECKLIST = @ID_CHECKLIST

END

BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT
	DECLARE @CLIENTE INT
	
	SELECT TOP 1 @CLIENTE = CHK_CLIENTE
	FROM CHECKLIST 
	WHERE CHK_ID = @ID_CHECKLIST
 
	SELECT	@PAIS = CLI_PAIS
	FROM	CLIENTE
	WHERE	CLI_ID = @CLIENTE
	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION

	INSERT CHECKLIST_DETALLE
		(
			 CHD_ID_CHECKLIST
			,CHD_PREGUNTA
			,CHD_OBJETO
			,CHD_ORDEN
			,CHD_USUARIO_CREACION
			,CHD_FECHA_CREACION
			,CHD_USUARIO_ACT
			,CHD_FECHA_ACT
			,CHD_VALOR_PREDETERMINADO
			,CHD_VALOR
			,CHD_HABILITADO
			,CHD_NOTIFICACION
		)
	VALUES 
		(
			@ID_CHECKLIST,
			@PREGUNTA,
			@OBJETO,
			@ORDEN,
			@USUARIO,
			@DATE_NOW,
			@USUARIO,
			@DATE_NOW,
			@VALOR_PRED,
			@VALOR,
			@HABILITADO,
			@NOTIFICACION
		)
	
	SET @ID = SCOPE_IDENTITY()

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES ='INS_CHECKLIST_DETALLE ' + 											
						STR(@ID_CHECKLIST)  + ',' +
						@PREGUNTA	   + ',' +
						STR(@OBJETO)

		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible insertar El Detalle del CheckList.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : INS_CHECKLIST_DETALLE_OBJETO
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		INSERTA CHECKLIST DETALLE DEL OBJETO
-- =============================================
CREATE PROCEDURE [dbo].[INS_CHECKLIST_DETALLE_OBJETO]
@ID INT = NULL OUTPUT,
@ID_CHECKLIST_DETALLE INT,
@ORDEN INT,
@NOMBRE VARCHAR (200),
@USUARIO INT

AS
SET NOCOUNT ON


IF EXISTS (SELECT TOP 1 1 FROM  CHECKLIST_DETALLE_COMBOBOX
			              WHERE	CDC_ID_CHECKLIST_DETALLE = @ID_CHECKLIST_DETALLE
			              AND	CDC_ORDEN = @ORDEN) BEGIN

	RAISERROR('No es posible registrar el orden ya que está siendo utilizado por otro item',16,1)
	RETURN -1
END

BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT
	DECLARE @CLIENTE INT
	
	SELECT TOP 1 @CLIENTE = CHK_CLIENTE
	FROM CHECKLIST
		WHERE CHK_ID = (SELECT CHD_ID_CHECKLIST 
	FROM CHECKLIST_DETALLE 
		WHERE CHD_ID = @ID_CHECKLIST_DETALLE)
 
	SELECT	@PAIS = CLI_PAIS
	FROM	CLIENTE
	WHERE	CLI_ID = @CLIENTE

	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION

	INSERT CHECKLIST_DETALLE_COMBOBOX
		(
			 CDC_ID_CHECKLIST_DETALLE
			,CDC_ORDEN
			,CDC_NOMBRE
			,CDC_USUARIO_CREACION
			,CDC_FECHA_CREACION
			,CDC_USUARIO_ACT
			,CDC_FECHA_ACT
		)
	VALUES 
		(
			@ID_CHECKLIST_DETALLE,
			@ORDEN,
			@NOMBRE,
			@USUARIO,
			@DATE_NOW,
			@USUARIO,
			@DATE_NOW
		)
	
	SET @ID = SCOPE_IDENTITY()

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES ='INS_CHECKLIST_DETALLE_OBJETO ' + 											
						STR(@ID)	+ ',' +
						STR(@ID_CHECKLIST_DETALLE)	+ ',' +
						STR(@ORDEN)	+ ',' +
						@NOMBRE	+ ',' +
						STR(@USUARIO)

		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible insertar El Detalle del Objeto del CheckList.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_ARCHIVO
-- ============================================================
-- =============================================
-- AUTHOR:         HECTOR LOHAUS
-- FECHA CREACIÓN: 11-02-2025
-- DESCRIPTION:    SELECCIONA ARCHIVO BINARIO USANDO ARC_ID
-- =============================================
CREATE PROCEDURE [dbo].[SEL_ARCHIVO]
@ID INT
AS
SET NOCOUNT ON;

--SELECT
BEGIN
    
	DECLARE @SELECT VARCHAR(MAX)
	SET  @SELECT =	'SELECT ARC_ID
							,ARC_NOMBRE_ARCHIVO
							,ARC_DESCRIPCION
							,ARC_CONTENIDO
							,ARC_EXTENSION
							,ARC_TAMANO
							,ARC_ARCHIVO
							,ABI_ID
						    ,ABI_ARCHIVO_BINARIO
					'
END

--FROM
BEGIN
	DECLARE @FROM VARCHAR(MAX)
	SET @FROM = ' FROM	ARCHIVO
						INNER JOIN ARCHIVO_BINARIO  ON ABI_ID = ARC_ARCHIVO
				'
END

--WHERE
BEGIN
	DECLARE @WHERE VARCHAR(MAX)
	SET @WHERE =  ' WHERE 1=1
				'

	IF(@ID IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND ARC_ID = ' + LTRIM(@ID)
	END
END 

EXEC(@SELECT + @FROM + @WHERE)
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_ARCHIVOS_BINARIO
-- ============================================================

-- =============================================
-- DEVUELVE BINARIO PARA DESCARGA
-- =============================================

CREATE PROCEDURE [dbo].[SEL_ARCHIVOS_BINARIO]
@ID INT

AS

SET NOCOUNT ON 

SELECT	ABI_ID,
		ABI_ARCHIVO_BINARIO,
		ARC_NOMBRE_ARCHIVO
FROM	ARCHIVO_BINARIO 
		INNER JOIN ARCHIVO ON ARC_ARCHIVO = ABI_ID
WHERE	ABI_ID = @ID
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_CHECKLIST
-- ============================================================
-- =============================================
-- AUTHOR:         CRUD
-- FECHA CREACIÓN: 05-02-2025
-- DESCRIPTION:    SELECT REGISTRO
-- =============================================
CREATE PROCEDURE [dbo].[SEL_CHECKLIST]
@ID INT = NULL,
@NOMBRE VARCHAR(200) = NULL,
@HABILITADO BIT = NULL,
@FILTRO VARCHAR(MAX)=NULL,
@CLIENTE INT

AS
SET NOCOUNT ON
-- SEGURIDAD
	--IF @USUARIO 

--SELECT
BEGIN
   DECLARE @SELECT VARCHAR(MAX)
   SET  @SELECT = 'SELECT DISTINCT CHK_ID
								   ,CHK_CLIENTE
								   ,CHK_NOMBRE
								   ,CHK_DESCRIPCION
								   ,CHK_USUARIO_CREACION
								   ,CHK_FECHA_CREACION
								   ,CHK_USUARIO_ACT
								   ,CHK_FECHA_ACT
								   ,CHK_HABILITADO
                   '
END

--FROM
BEGIN
   DECLARE @FROM VARCHAR(MAX)
   SET @FROM = ' FROM CHECKLIST
				 INNER JOIN CLIENTE				ON CLI_ID = CHK_CLIENTE

               '
END

--WHERE
BEGIN
   DECLARE @WHERE VARCHAR(MAX)
   SET @WHERE = ' WHERE 1=1 
                '
	IF(@ID IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND CHK_ID = ' + LTRIM(@ID)
	END

	IF(@CLIENTE IS NOT NULL)BEGIN
       SET @WHERE = @WHERE + ' AND CHK_CLIENTE = ' + LTRIM(@CLIENTE)
	END

	IF(@NOMBRE IS NOT NULL)BEGIN
       SET @WHERE = @WHERE + ' AND CHK_NOMBRE = ' + @NOMBRE
	END

	IF(@HABILITADO IS NOT NULL)BEGIN
		SET @WHERE = @WHERE +  ' AND CHK_HABILITADO = ' + LTRIM(@HABILITADO)	
	END

	IF(@FILTRO IS NOT NULL)BEGIN
		SET @WHERE = @WHERE +  'AND		(CHK_NOMBRE LIKE ''%' + LTRIM(@FILTRO) + '%''
								OR		CHK_DESCRIPCION LIKE ''%' + LTRIM(@FILTRO) + '%''
								)'	
	END

END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)




GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_CHECKLIST_DETALLE
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		RETORNA CHECKLIST DETALLE
-- =============================================
CREATE PROCEDURE [dbo].[SEL_CHECKLIST_DETALLE]
@ID INT = NULL,
@ID_CHECKLIST INT = NULL,
@FILTRO VARCHAR(MAX) = NULL

AS

DECLARE @SELECT VARCHAR(MAX),
		@FROM VARCHAR(MAX),
		@WHERE VARCHAR(MAX),
		@ORDERBY VARCHAR(MAX)

BEGIN
	SET @SELECT =	'SELECT  CHD_ID
					   ,CHD_ID_CHECKLIST
					   ,CHK_NOMBRE
					   ,CHD_PREGUNTA
					   ,CHD_OBJETO
					   ,CHO_NOMBRE
					   ,CHT_NOMBRE
					   ,CHD_ORDEN
					   ,CHD_VALOR_PREDETERMINADO
					   ,CHD_VALOR
					   ,CHD_HABILITADO
					   ,CHD_NOTIFICACION

					'
END

BEGIN 

	SET @FROM =	 '
						FROM	CHECKLIST_DETALLE
						INNER JOIN CHECKLIST ON CHK_ID = CHD_ID_CHECKLIST
						INNER JOIN CHECKLIST_TIPO_OBJETO ON CHO_ID = CHD_OBJETO
						INNER JOIN CHECKLIST_TIPO_DATO ON  CHT_ID = CHO_TIPO_DATO
				 '
END

BEGIN
	
	SET @WHERE = '
						WHERE	1 = 1
				 '

	IF(@ID IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND CHD_ID = ' + LTRIM(@ID)
	END

	IF(@ID_CHECKLIST IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND CHD_ID_CHECKLIST = ' + LTRIM(@ID_CHECKLIST)
	END

	IF(@FILTRO IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND (CHK_NOMBRE LIKE ''%' + @FILTRO + '%''
						   OR CHK_DESCRIPCION LIKE ''%' + @FILTRO + '%''
						   OR CHD_PREGUNTA LIKE ''%' + @FILTRO + '%''
						   OR CHO_NOMBRE LIKE ''%' + @FILTRO + '%''
						   OR CHT_NOMBRE LIKE ''%' + @FILTRO + '%'')
						   '
	END

END
SET @ORDERBY = ' ORDER BY CHD_ORDEN  '


EXEC(@SELECT + @FROM + @WHERE + @ORDERBY)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_CHECKLIST_DETALLE_OBJETO
-- ============================================================
-- =============================================
-- AUTHOR:			DANIEL HIDALGO
-- FECHA CREACIÓN:	29-11-2017
-- DESCRIPTION:		RETORNA CHECKLIST DETALLE OBJETO
-- =============================================
CREATE PROCEDURE [dbo].[SEL_CHECKLIST_DETALLE_OBJETO]
@ID INT = NULL,
@ID_CHECKLIST_DETALLE INT = NULL,
@FILTRO VARCHAR(8000) = NULL

AS
SET NOCOUNT ON

--SELECT 
BEGIN
   DECLARE @SELECT VARCHAR(MAX)
   SET  @SELECT =	'SELECT  CDC_ID
							,CDC_ID_CHECKLIST_DETALLE
							,CDC_ORDEN
							,CDC_NOMBRE
							,CDC_USUARIO_CREACION
							,CDC_FECHA_CREACION
							,CDC_USUARIO_ACT
							,CDC_FECHA_ACT
		
					'
END

--FROM

BEGIN
   DECLARE	@FROM VARCHAR(MAX)
   SET		@FROM = 'FROM	CHECKLIST_DETALLE_COMBOBOX

               '
END

--WHERE
BEGIN
   DECLARE	@WHERE VARCHAR(MAX)
   SET		@WHERE = ' WHERE 1=1 

                '
	IF(@ID IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND CDC_ID = ' + LTRIM(@ID)
	END

	IF(@ID_CHECKLIST_DETALLE IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND CDC_ID_CHECKLIST_DETALLE = ' + LTRIM(@ID_CHECKLIST_DETALLE)
	END

	IF(@FILTRO IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND (CDC_NOMBRE LIKE ''%' + @FILTRO + '%'')
						   '
	END

	SET @WHERE = @WHERE + ' ORDER BY CDC_ID  '

END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_CHECKLIST_ESTADOS
-- ============================================================

-- =============================================
-- DEVUELVE ESTADOS CHECKLIST
-- =============================================

CREATE PROCEDURE [dbo].[SEL_CHECKLIST_ESTADOS]

AS

SET NOCOUNT ON 

SELECT	 CRE_ID
		,CRE_NOMBRE
FROM	Cliente_Instalacion_Zona_Checklist_Respuesta_Estado
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_CHECKLIST_TIPO
-- ============================================================

-- =============================================
-- AUTHOR:		   BRYAN CHAVEZ
-- FECHA CREACIÓN: 11-06-2026
-- DESCRIPTION:	   SELECT/LISTADO DE CHECKLIST_TIPO
-- =============================================
CREATE   PROCEDURE [dbo].[SEL_CHECKLIST_TIPO]
@ID INT = NULL,
@FILTRO VARCHAR(MAX) = NULL

AS
SET NOCOUNT ON

--SELECT
BEGIN
   DECLARE @SELECT VARCHAR(MAX)
   SET @SELECT = 'SELECT  ckt.ckt_id
                          ,ckt.ckt_nombre
                  '
END

--FROM
BEGIN
   DECLARE @FROM VARCHAR(MAX)
   SET @FROM = ' FROM Checklist_Tipo ckt
               '
END

--WHERE
BEGIN
   DECLARE @WHERE VARCHAR(MAX)
   SET @WHERE = ' WHERE 1=1
                '
    IF (@ID IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ckt.ckt_id = ' + LTRIM(STR(@ID))
    END

    IF (@FILTRO IS NOT NULL) BEGIN
        SET @WHERE = @WHERE + ' AND ckt.ckt_nombre LIKE ''%' + LTRIM(@FILTRO) + '%'''
    END
END

--print(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_CHECKLIST_TIPO_OBJETO
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		RETORNA CHECKLIST OBJETO
-- =============================================
CREATE PROCEDURE [dbo].[SEL_CHECKLIST_TIPO_OBJETO]
@ID INT = NULL
AS


DECLARE @SELECT VARCHAR(MAX),
		@FROM VARCHAR(MAX),
		@WHERE VARCHAR(MAX)



BEGIN
	SET @SELECT =	'SELECT  CHO_ID
							,CHO_NOMBRE
							,CHO_TIPO_DATO

					'
END

BEGIN 

	SET @FROM =	 '
					FROM	CHECKLIST_TIPO_OBJETO
						
				 '
END

BEGIN
	
	SET @WHERE = '
					WHERE	1=1
				 '

	IF(@ID IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND CHO_ID = ' + LTRIM(@ID)	
	END


END


EXEC(@SELECT + @FROM + @WHERE )



GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_LOG_APP_WEB
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	12-03-2025
-- DESCRIPTION:		LOG APP Y WEB POR TIPO
-- =============================================

CREATE PROCEDURE [dbo].[SEL_LOG_APP_WEB]
@TIPO_APP INT = NULL

AS

BEGIN 
    DECLARE @SELECT VARCHAR(MAX)

    SET @SELECT = 'SELECT LOG_ID
                         ,LOT_TABLA
                         ,LOG_COLUMNA
                         ,LOE_NOMBRE
                         ,USU_NOMBRE + '' '' + USU_APELLIDO_PATERNO + '' '' + USU_APELLIDO_MATERNO AS USUARIO_NOMBRE_COMPLETO
                         ,LOG_FECHA_EJECUCION
                         ,LOG_VALOR_ACTUAL
                         ,LOG_VALOR_NUEVO
						 
					'

END

BEGIN
	DECLARE @FROM VARCHAR(MAX)

	SET @FROM ='FROM	LOG 
						INNER JOIN USUARIO			  ON USU_ID		= LOG_USUARIO_EJECUCION
						INNER JOIN LOG_TABLA		  ON LOG_TABLA	= LOT_ID
						INNER JOIN LOG_TIPO_API_WEB   ON LOT_ID		= LTP_TABLA
						LEFT  JOIN LOG_ESTADO		  ON LOE_ID		= LOG_ACCION
					'
END

BEGIN
	DECLARE @WHERE VARCHAR(MAX)

		SET @WHERE =' WHERE	1=1
						'

	IF(@TIPO_APP IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND LTP_TIPO = ' + LTRIM(@TIPO_APP)
	END

	

END


---PRINT(@SELECT + @FROM + @WHERE)
EXEC(@SELECT + @FROM + @WHERE)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_LOG_SISTEMA
-- ============================================================
-- =============================================
-- AUTHOR:		DIEGO CASTILLO
-- CREATE DATE: 30-07-2024
-- =============================================
CREATE PROCEDURE [dbo].[SEL_LOG_SISTEMA]
@ID INT = NULL
,@ACCION VARCHAR(MAX) = NULL
,@TABLA  VARCHAR(MAX) = NULL		
,@USUARIO VARCHAR(MAX) = NULL

AS
--SELECT
BEGIN
	DECLARE @SELECT VARCHAR(MAX)

	SET @SELECT = 'SELECT LOG_ID
						,(USU_NOMBRE + '' '' + USU_APELLIDO_PATERNO + '' '' + USU_APELLIDO_MATERNO)		[USUARIO_NOMBRE] 
						,LOG_FECHA_EJECUCION
						,LOE_NOMBRE
						,LOT_TABLA
						,LOG_TABLA_ID
						,LOG_COLUMNA
						,LOG_VALOR_ACTUAL
						,LOG_VALOR_NUEVO
				  '
END
--FROM
BEGIN
	DECLARE @FROM VARCHAR(MAX)

	SET @FROM = ' FROM LOG
					LEFT JOIN LOG_TABLA			ON LOG_TABLA = LOT_ID
					LEFT JOIN LOG_ESTADO		ON LOG_ACCION = LOE_ID
					LEFT JOIN USUARIO			ON LOG_USUARIO_EJECUCION = USU_ID
				'
END
--WHERE
BEGIN
	DECLARE @WHERE VARCHAR(MAX)
	SET	@WHERE = ' WHERE 1 = 1 '

	IF(@ACCION IS NOT NULL)BEGIN
		SET @WHERE = @WHERE +  ' AND LOE_ID IN(' + LTRIM(@ACCION)	 + ') '	
	END

	IF(@TABLA IS NOT NULL)BEGIN
		SET @WHERE = @WHERE +  ' AND LOT_ID IN('  + LTRIM(@TABLA)	 + ') '	
	END

	IF(@USUARIO IS NOT NULL)BEGIN
		SET @WHERE = @WHERE +  ' AND USU_ID IN(' + LTRIM(@USUARIO) + ') '	
	END

END

--ORDER BY
BEGIN
	DECLARE @ORDER_BY VARCHAR(MAX)
	SET @ORDER_BY = ' ORDER BY LOG_ID DESC '
END

PRINT(@SELECT + @FROM + @WHERE + @ORDER_BY)
EXEC(@SELECT + @FROM + @WHERE + @ORDER_BY)
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : SEL_LOG_TABLA
-- ============================================================
-- =============================================
-- AUTHOR:		DIEGO CASTILLO
-- CREATE DATE: 30-07-2024
-- =============================================
CREATE PROCEDURE [dbo].[SEL_LOG_TABLA]
@ID INT = NULL

AS
--SELECT
BEGIN
	DECLARE @SELECT VARCHAR(MAX)

	SET @SELECT = 'SELECT	LOT_ID
							,LOT_TABLA
				  '
END
--FROM
BEGIN
	DECLARE @FROM VARCHAR(MAX)

	SET @FROM = ' FROM	LOG_TABLA
				'
END
--WHERE
BEGIN
	DECLARE @WHERE VARCHAR(MAX)
	SET	@WHERE = ' WHERE 1 = 1 '

END

--ORDER BY
BEGIN
	DECLARE @ORDER_BY VARCHAR(MAX)
	SET @ORDER_BY = ' ORDER BY LOT_ID ASC '
END

PRINT(@SELECT + @FROM + @WHERE + @ORDER_BY)
EXEC(@SELECT + @FROM + @WHERE + @ORDER_BY)
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : UPD_CHECKLIST
-- ============================================================
-- =============================================
-- AUTHOR:         CRUD
-- FECHA CREACIÓN: 05-02-2025
-- DESCRIPTION:    UPDATE REGISTRO
-- =============================================
CREATE PROCEDURE [dbo].[UPD_CHECKLIST]
@ID INT,
@CLIENTE INT = NULL,
@NOMBRE VARCHAR(200) = NULL,
@DESCRIPCION VARCHAR(MAX) = NULL,
@USUARIO INT,
@HABILITADO BIT = NULL

AS
SET NOCOUNT ON


BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT

	SELECT	@PAIS = CLI_PAIS
	FROM	CLIENTE
	WHERE	CLI_ID = @CLIENTE
	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END
BEGIN TRANSACTION

   UPDATE  CHECKLIST
   SET     CHK_CLIENTE = @CLIENTE
          ,CHK_NOMBRE = @NOMBRE
          ,CHK_DESCRIPCION = @DESCRIPCION
          ,CHK_USUARIO_ACT = @USUARIO
          ,CHK_FECHA_ACT = @DATE_NOW
		  ,CHK_HABILITADO = ISNULL (@HABILITADO, chk_habilitado)

   WHERE   CHK_ID = @ID

   IF @@ROWCOUNT = 0 BEGIN
       ROLLBACK TRANSACTION
       DECLARE @VARIABLES VARCHAR(MAX)
       SET @VARIABLES = 'UPD_CHECKLIST' + 
                           '@ID = ' + LTRIM(@ID) + ',' + 
                           '@CLIENTE = ' + LTRIM(@CLIENTE) + ',' + 
                           '@NOMBRE = ' + LTRIM(@NOMBRE) + ',' + 
						   '@HABILITADO = ' + LTRIM(@HABILITADO) + ',' + 
                           '@DESCRIPCION = ' + LTRIM(@DESCRIPCION) 

       EXEC INS_EXCEPCION 
           @MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL REGISTRO.',
           @VARIABLES = @VARIABLES
       RETURN -1
   END

COMMIT TRANSACTION
RETURN(0)



-- Procedimiento Delete

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : UPD_CHECKLIST_DETALLE
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		ACTUALIZA CHECKLIST DETALLE
-- =============================================
CREATE PROCEDURE [dbo].[UPD_CHECKLIST_DETALLE]
@ID INT,
@ID_CHECKLIST INT,
@PREGUNTA VARCHAR(MAX),
@OBJETO INT,
@USUARIO INT,
@VALOR_PRED BIT = NULL,
@VALOR VARCHAR(200) = NULL,
@HABILITADO BIT = NULL,
@NOTIFICACION BIT = NULL

AS
SET NOCOUNT ON


BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT
	DECLARE @CLIENTE INT
	
	SELECT TOP 1 @CLIENTE = CHK_CLIENTE
	FROM CHECKLIST 
	WHERE CHK_ID = @ID_CHECKLIST
 
	SELECT	@PAIS = CLI_PAIS
	FROM	CLIENTE
	WHERE	CLI_ID = @CLIENTE
	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION


	UPDATE CHECKLIST_DETALLE
	SET	   CHD_ID_CHECKLIST = @ID_CHECKLIST,
		   CHD_PREGUNTA = @PREGUNTA,
		   CHD_OBJETO = @OBJETO,
		   CHD_USUARIO_ACT = @USUARIO,
		   CHD_FECHA_ACT = @DATE_NOW,
		   CHD_VALOR_PREDETERMINADO = @VALOR_PRED,
		   CHD_VALOR = @VALOR,
		   CHD_HABILITADO = @HABILITADO,
		   CHD_NOTIFICACION = @NOTIFICACION
	WHERE  CHD_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES ='UPD_CHECKLIST_DETALLE ' + 		
						STR(@ID)  + ',' +
						STR(@ID_CHECKLIST)  + ',' +
						@PREGUNTA	   + ',' +
						STR(@OBJETO) + ',' +
						STR(@VALOR_PRED) + ',' +
						STR(@VALOR) + ',' +
						STR(@HABILITADO) + ',' +
						STR(@NOTIFICACION) + ',' +
						STR(@USUARIO)

		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Actualizar El CheckList Detalle.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : UPD_CHECKLIST_DETALLE_OBJETO
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		ACTUALIZA CHECKLIST DETALLE OBJETO
-- =============================================
CREATE PROCEDURE [dbo].[UPD_CHECKLIST_DETALLE_OBJETO]
@ID INT,
@ID_CHECKLIST_DETALLE INT,
@ORDEN INT,
@NOMBRE VARCHAR (200),
@USUARIO INT


AS
SET NOCOUNT ON

IF EXISTS (SELECT TOP 1 1 FROM  CHECKLIST_DETALLE_COMBOBOX
			              WHERE	CDC_ID_CHECKLIST_DETALLE = @ID_CHECKLIST_DETALLE
			              AND	CDC_ORDEN = @ORDEN
						  AND	CDC_ID <> @ID) BEGIN

	RAISERROR('No es posible registrar el orden ya que está siendo utilizado por otro item',16,1)
	RETURN -1
END

BEGIN
	--OBTENGO EL PAIS 
	DECLARE @PAIS INT
	DECLARE @CLIENTE INT
	
	SELECT TOP 1 @CLIENTE = CHK_CLIENTE
	FROM CHECKLIST
		WHERE CHK_ID = (SELECT CHD_ID_CHECKLIST 
	FROM CHECKLIST_DETALLE 
		WHERE CHD_ID = @ID_CHECKLIST_DETALLE)
 
	SELECT	@PAIS = CLI_PAIS
	FROM	CLIENTE
	WHERE	CLI_ID = @CLIENTE

	--OBTENGO LA HORA DEL PAIS
	DECLARE @DATE_NOW DATETIME 
	SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS)
END

BEGIN TRANSACTION

	UPDATE CHECKLIST_DETALLE_COMBOBOX
	SET	   CDC_ID_CHECKLIST_DETALLE = @ID_CHECKLIST_DETALLE,
		   CDC_ORDEN = @ORDEN,
		   CDC_NOMBRE = @NOMBRE,
		   CDC_USUARIO_ACT = @USUARIO,
		   CDC_FECHA_ACT = @DATE_NOW
	WHERE  CDC_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES ='INS_CHECKLIST_DETALLE_OBJETO ' + 											
						STR(@ID)	+ ',' +
						STR(@ID_CHECKLIST_DETALLE)	+ ',' +
						STR(@ORDEN)	+ ',' +
						@NOMBRE	+ ',' +
						STR(@USUARIO)

		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Actualizar El Detalle del Objeto del CheckList.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_STORED_PROCEDURE : UPD_CHECKLIST_ESTADO
-- ============================================================
-- =============================================
-- ACTUALIZA ESTADO CHEKLIST RESPUESTA
-- =============================================
CREATE PROCEDURE [dbo].[UPD_CHECKLIST_ESTADO]
@ID INT,
@OBSERVACION VARCHAR(MAX),
@USUARIO INT,
@ESTADO VARCHAR(200)

AS
SET NOCOUNT ON

BEGIN TRANSACTION

	UPDATE	 CLIENTE_INSTALACION_ZONA_CHECKLIST_RESPUESTA
	SET		 CCR_OBSERVACION	= @OBSERVACION
			,CCR_OBSERVACION_USUARIO = @USUARIO
			,CCR_OBSERVACION_FECHA = GETDATE()
			,CCR_FECHA_CREACION = GETDATE()
			,CCR_USUARIO_CREACION = @USUARIO
			,CCR_ESTADO = @ESTADO

	WHERE	CCR_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES = 'UPD_CHECKLIST_ESTADO ' + LTRIM(STR(@ID))
		EXEC INS_EXCEPCION 
			@MSG = '1.- NO FUE POSIBLE ACTUALIZAR EL REGISTRO.',
			@VARIABLES = @VARIABLES
		RETURN -1 
	END

COMMIT TRANSACTION

RETURN(0)
GO

-- ============================================================
-- SQL_STORED_PROCEDURE : UPD_CHECKLIST_ORDEN
-- ============================================================
-- =============================================
-- AUTHOR:			BRYAN CHAVEZ
-- FECHA CREACIÓN:	05-02-2025
-- DESCRIPTION:		ACTUALIZA CHECKLIST DETALLE
-- =============================================
CREATE PROCEDURE [dbo].[UPD_CHECKLIST_ORDEN]
@ID INT,
@ORDEN INT,
@ID_CHECK_LIST INT

AS
SET NOCOUNT ON


BEGIN TRANSACTION

	DECLARE @ORDEN_ANTERIOR INT
	DECLARE @ID_EXISTENTE INT

	-- Obtener el orden actual del elemento que se está modificando
	SELECT @ORDEN_ANTERIOR = CHD_ORDEN 
	FROM CHECKLIST_DETALLE
	WHERE CHD_ID = @ID

	-- Buscar si ya existe otro elemento con el nuevo orden
	SELECT TOP 1 @ID_EXISTENTE = CHD_ID
	FROM CHECKLIST_DETALLE
	WHERE CHD_ID_CHECKLIST = @ID_CHECK_LIST AND CHD_ORDEN = @ORDEN AND CHD_ID <> @ID

	-- Si existe un elemento con el mismo orden, restaurarle el orden anterior
	IF @ID_EXISTENTE IS NOT NULL
	BEGIN
		UPDATE CHECKLIST_DETALLE
		SET CHD_ORDEN = @ORDEN_ANTERIOR
		WHERE CHD_ID = @ID_EXISTENTE
	END

	-- Actualizar el orden del elemento actual
	UPDATE CHECKLIST_DETALLE
	SET CHD_ORDEN = @ORDEN
	WHERE CHD_ID = @ID

	IF @@ROWCOUNT = 0 BEGIN
		ROLLBACK TRANSACTION
		DECLARE @VARIABLES VARCHAR(MAX)
		SET @VARIABLES ='UPD_CHECKLIST_ORDEN ' + 		
						STR(@ID)  + ',' +
						STR(@ORDEN)

		EXEC INS_EXCEPCION 
			@MSG = '1.- No fue posible Actualizar El Orden del Checklist.',
			@VARIABLES = @VARIABLES
		RETURN -1  
	END
	
COMMIT TRANSACTION

RETURN(0)

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Cliente
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Cliente]
ON [dbo].[Cliente]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Cliente_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,cli_nombre VARCHAR(MAX) NULL ,cli_pais VARCHAR(MAX) NULL ,cli_razon_social VARCHAR(MAX) NULL ,cli_identificador VARCHAR(MAX) NULL ,cli_habilitado VARCHAR(MAX) NULL  ,N_cli_nombre VARCHAR(MAX) NULL ,N_cli_pais VARCHAR(MAX) NULL ,N_cli_razon_social VARCHAR(MAX) NULL ,N_cli_identificador VARCHAR(MAX) NULL ,N_cli_habilitado VARCHAR(MAX) NULL  ,I_cli_nombre BIT NULL ,I_cli_pais BIT NULL ,I_cli_razon_social BIT NULL ,I_cli_identificador BIT NULL ,I_cli_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.cli_usuario_actualizacion IS NOT NULL THEN
								I.cli_usuario_actualizacion
							ELSE
								D.cli_usuario_actualizacion
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.cli_id = D.cli_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Cliente_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,cli_nombre,cli_pais,cli_razon_social,cli_identificador,cli_habilitado
				)
		SELECT   cli_id
				,@ACCION
				,@USUARIO
				,cli_nombre,cli_pais,cli_razon_social,cli_identificador,cli_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Cliente_TEMP_LOG
			SET    N_cli_nombre = I.cli_nombre ,I_cli_nombre = (CASE WHEN ISNULL(I.cli_nombre,'') != ISNULL(D.cli_nombre,'') THEN 1 ELSE 0 END) ,N_cli_pais = I.cli_pais ,I_cli_pais = (CASE WHEN ISNULL(I.cli_pais,'') != ISNULL(D.cli_pais,'') THEN 1 ELSE 0 END) ,N_cli_razon_social = I.cli_razon_social ,I_cli_razon_social = (CASE WHEN ISNULL(I.cli_razon_social,'') != ISNULL(D.cli_razon_social,'') THEN 1 ELSE 0 END) ,N_cli_identificador = I.cli_identificador ,I_cli_identificador = (CASE WHEN ISNULL(I.cli_identificador,'') != ISNULL(D.cli_identificador,'') THEN 1 ELSE 0 END) ,N_cli_habilitado = I.cli_habilitado ,I_cli_habilitado = (CASE WHEN ISNULL(I.cli_habilitado,'') != ISNULL(D.cli_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.cli_id = I.cli_id
				   INNER JOIN ##Cliente_TEMP_LOG ON ID = I.cli_id

		END ELSE BEGIN

			INSERT INTO ##Cliente_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_cli_nombre,N_cli_pais,N_cli_razon_social,N_cli_identificador,N_cli_habilitado
					)
			SELECT   cli_id
					,@ACCION
					,@USUARIO
					,cli_nombre,cli_pais,cli_razon_social,cli_identificador,cli_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_nombre' ,cli_nombre ,N_cli_nombre FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_pais' ,cli_pais ,N_cli_pais FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_razon_social' ,cli_razon_social ,N_cli_razon_social FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_identificador' ,cli_identificador ,N_cli_identificador FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_habilitado' ,cli_habilitado ,N_cli_habilitado FROM ##Cliente_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_nombre' ,cli_nombre ,N_cli_nombre FROM ##Cliente_TEMP_LOG WHERE I_cli_nombre = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_pais' ,cli_pais ,N_cli_pais FROM ##Cliente_TEMP_LOG WHERE I_cli_pais = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_razon_social' ,cli_razon_social ,N_cli_razon_social FROM ##Cliente_TEMP_LOG WHERE I_cli_razon_social = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_identificador' ,cli_identificador ,N_cli_identificador FROM ##Cliente_TEMP_LOG WHERE I_cli_identificador = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_habilitado' ,cli_habilitado ,N_cli_habilitado FROM ##Cliente_TEMP_LOG WHERE I_cli_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_nombre' ,cli_nombre ,NULL FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_pais' ,cli_pais ,NULL FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_razon_social' ,cli_razon_social ,NULL FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_identificador' ,cli_identificador ,NULL FROM ##Cliente_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'25' , ID ,'cli_habilitado' ,cli_habilitado ,NULL FROM ##Cliente_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Cliente_TEMP_LOG

	DROP TABLE ##Cliente_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Cliente_App_Instalacion
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Cliente_App_Instalacion]
ON [dbo].[Cliente_App_Instalacion]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Cliente_App_Instalacion_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,cai_id_instalacion VARCHAR(MAX) NULL ,cai_id_app VARCHAR(MAX) NULL ,cai_habilitado VARCHAR(MAX) NULL  ,N_cai_id_instalacion VARCHAR(MAX) NULL ,N_cai_id_app VARCHAR(MAX) NULL ,N_cai_habilitado VARCHAR(MAX) NULL  ,I_cai_id_instalacion BIT NULL ,I_cai_id_app BIT NULL ,I_cai_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.cai_usuario_actualizacion IS NOT NULL THEN
								I.cai_usuario_actualizacion
							ELSE
								D.cai_usuario_actualizacion
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.cai_id = D.cai_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Cliente_App_Instalacion_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,cai_id_instalacion,cai_id_app,cai_habilitado
				)
		SELECT   cai_id
				,@ACCION
				,@USUARIO
				,cai_id_instalacion,cai_id_app,cai_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Cliente_App_Instalacion_TEMP_LOG
			SET    N_cai_id_instalacion = I.cai_id_instalacion ,I_cai_id_instalacion = (CASE WHEN ISNULL(I.cai_id_instalacion,'') != ISNULL(D.cai_id_instalacion,'') THEN 1 ELSE 0 END) ,N_cai_id_app = I.cai_id_app ,I_cai_id_app = (CASE WHEN ISNULL(I.cai_id_app,'') != ISNULL(D.cai_id_app,'') THEN 1 ELSE 0 END) ,N_cai_habilitado = I.cai_habilitado ,I_cai_habilitado = (CASE WHEN ISNULL(I.cai_habilitado,'') != ISNULL(D.cai_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.cai_id = I.cai_id
				   INNER JOIN ##Cliente_App_Instalacion_TEMP_LOG ON ID = I.cai_id

		END ELSE BEGIN

			INSERT INTO ##Cliente_App_Instalacion_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_cai_id_instalacion,N_cai_id_app,N_cai_habilitado
					)
			SELECT   cai_id
					,@ACCION
					,@USUARIO
					,cai_id_instalacion,cai_id_app,cai_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_id_instalacion' ,cai_id_instalacion ,N_cai_id_instalacion FROM ##Cliente_App_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_id_app' ,cai_id_app ,N_cai_id_app FROM ##Cliente_App_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_habilitado' ,cai_habilitado ,N_cai_habilitado FROM ##Cliente_App_Instalacion_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_id_instalacion' ,cai_id_instalacion ,N_cai_id_instalacion FROM ##Cliente_App_Instalacion_TEMP_LOG WHERE I_cai_id_instalacion = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_id_app' ,cai_id_app ,N_cai_id_app FROM ##Cliente_App_Instalacion_TEMP_LOG WHERE I_cai_id_app = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_habilitado' ,cai_habilitado ,N_cai_habilitado FROM ##Cliente_App_Instalacion_TEMP_LOG WHERE I_cai_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_id_instalacion' ,cai_id_instalacion ,NULL FROM ##Cliente_App_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_id_app' ,cai_id_app ,NULL FROM ##Cliente_App_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'26' , ID ,'cai_habilitado' ,cai_habilitado ,NULL FROM ##Cliente_App_Instalacion_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Cliente_App_Instalacion_TEMP_LOG

	DROP TABLE ##Cliente_App_Instalacion_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Cliente_Instalacion
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Cliente_Instalacion]
ON [dbo].[Cliente_Instalacion]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Cliente_Instalacion_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,cin_cliente VARCHAR(MAX) NULL ,cin_nombre VARCHAR(MAX) NULL ,cin_descripcion VARCHAR(MAX) NULL ,cin_direccion VARCHAR(MAX) NULL ,cin_habilitado VARCHAR(MAX) NULL  ,N_cin_cliente VARCHAR(MAX) NULL ,N_cin_nombre VARCHAR(MAX) NULL ,N_cin_descripcion VARCHAR(MAX) NULL ,N_cin_direccion VARCHAR(MAX) NULL ,N_cin_habilitado VARCHAR(MAX) NULL  ,I_cin_cliente BIT NULL ,I_cin_nombre BIT NULL ,I_cin_descripcion BIT NULL ,I_cin_direccion BIT NULL ,I_cin_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.cin_usuario_actualizacion IS NOT NULL THEN
								I.cin_usuario_actualizacion
							ELSE
								D.cin_usuario_actualizacion
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.cin_id = D.cin_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Cliente_Instalacion_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,cin_cliente,cin_nombre,cin_descripcion,cin_direccion,cin_habilitado
				)
		SELECT   cin_id
				,@ACCION
				,@USUARIO
				,cin_cliente,cin_nombre,cin_descripcion,cin_direccion,cin_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Cliente_Instalacion_TEMP_LOG
			SET    N_cin_cliente = I.cin_cliente ,I_cin_cliente = (CASE WHEN ISNULL(I.cin_cliente,'') != ISNULL(D.cin_cliente,'') THEN 1 ELSE 0 END) ,N_cin_nombre = I.cin_nombre ,I_cin_nombre = (CASE WHEN ISNULL(I.cin_nombre,'') != ISNULL(D.cin_nombre,'') THEN 1 ELSE 0 END) ,N_cin_descripcion = I.cin_descripcion ,I_cin_descripcion = (CASE WHEN ISNULL(I.cin_descripcion,'') != ISNULL(D.cin_descripcion,'') THEN 1 ELSE 0 END) ,N_cin_direccion = I.cin_direccion ,I_cin_direccion = (CASE WHEN ISNULL(I.cin_direccion,'') != ISNULL(D.cin_direccion,'') THEN 1 ELSE 0 END) ,N_cin_habilitado = I.cin_habilitado ,I_cin_habilitado = (CASE WHEN ISNULL(I.cin_habilitado,'') != ISNULL(D.cin_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.cin_id = I.cin_id
				   INNER JOIN ##Cliente_Instalacion_TEMP_LOG ON ID = I.cin_id

		END ELSE BEGIN

			INSERT INTO ##Cliente_Instalacion_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_cin_cliente,N_cin_nombre,N_cin_descripcion,N_cin_direccion,N_cin_habilitado
					)
			SELECT   cin_id
					,@ACCION
					,@USUARIO
					,cin_cliente,cin_nombre,cin_descripcion,cin_direccion,cin_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_cliente' ,cin_cliente ,N_cin_cliente FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_nombre' ,cin_nombre ,N_cin_nombre FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_descripcion' ,cin_descripcion ,N_cin_descripcion FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_direccion' ,cin_direccion ,N_cin_direccion FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_habilitado' ,cin_habilitado ,N_cin_habilitado FROM ##Cliente_Instalacion_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_cliente' ,cin_cliente ,N_cin_cliente FROM ##Cliente_Instalacion_TEMP_LOG WHERE I_cin_cliente = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_nombre' ,cin_nombre ,N_cin_nombre FROM ##Cliente_Instalacion_TEMP_LOG WHERE I_cin_nombre = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_descripcion' ,cin_descripcion ,N_cin_descripcion FROM ##Cliente_Instalacion_TEMP_LOG WHERE I_cin_descripcion = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_direccion' ,cin_direccion ,N_cin_direccion FROM ##Cliente_Instalacion_TEMP_LOG WHERE I_cin_direccion = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_habilitado' ,cin_habilitado ,N_cin_habilitado FROM ##Cliente_Instalacion_TEMP_LOG WHERE I_cin_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_cliente' ,cin_cliente ,NULL FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_nombre' ,cin_nombre ,NULL FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_descripcion' ,cin_descripcion ,NULL FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_direccion' ,cin_direccion ,NULL FROM ##Cliente_Instalacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'27' , ID ,'cin_habilitado' ,cin_habilitado ,NULL FROM ##Cliente_Instalacion_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Cliente_Instalacion_TEMP_LOG

	DROP TABLE ##Cliente_Instalacion_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Cliente_Usuario
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Cliente_Usuario]
ON [dbo].[Cliente_Usuario]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Cliente_Usuario_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,ucl_id_usuario VARCHAR(MAX) NULL ,ucl_id_cliente VARCHAR(MAX) NULL ,ucl_habilitado VARCHAR(MAX) NULL  ,N_ucl_id_usuario VARCHAR(MAX) NULL ,N_ucl_id_cliente VARCHAR(MAX) NULL ,N_ucl_habilitado VARCHAR(MAX) NULL  ,I_ucl_id_usuario BIT NULL ,I_ucl_id_cliente BIT NULL ,I_ucl_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.ucl_usuario_act IS NOT NULL THEN
								I.ucl_usuario_act
							ELSE
								D.ucl_usuario_act
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.ucl_id = D.ucl_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Cliente_Usuario_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,ucl_id_usuario,ucl_id_cliente,ucl_habilitado
				)
		SELECT   ucl_id
				,@ACCION
				,@USUARIO
				,ucl_id_usuario,ucl_id_cliente,ucl_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Cliente_Usuario_TEMP_LOG
			SET    N_ucl_id_usuario = I.ucl_id_usuario ,I_ucl_id_usuario = (CASE WHEN ISNULL(I.ucl_id_usuario,'') != ISNULL(D.ucl_id_usuario,'') THEN 1 ELSE 0 END) ,N_ucl_id_cliente = I.ucl_id_cliente ,I_ucl_id_cliente = (CASE WHEN ISNULL(I.ucl_id_cliente,'') != ISNULL(D.ucl_id_cliente,'') THEN 1 ELSE 0 END) ,N_ucl_habilitado = I.ucl_habilitado ,I_ucl_habilitado = (CASE WHEN ISNULL(I.ucl_habilitado,'') != ISNULL(D.ucl_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.ucl_id = I.ucl_id
				   INNER JOIN ##Cliente_Usuario_TEMP_LOG ON ID = I.ucl_id

		END ELSE BEGIN

			INSERT INTO ##Cliente_Usuario_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_ucl_id_usuario,N_ucl_id_cliente,N_ucl_habilitado
					)
			SELECT   ucl_id
					,@ACCION
					,@USUARIO
					,ucl_id_usuario,ucl_id_cliente,ucl_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_id_usuario' ,ucl_id_usuario ,N_ucl_id_usuario FROM ##Cliente_Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_id_cliente' ,ucl_id_cliente ,N_ucl_id_cliente FROM ##Cliente_Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_habilitado' ,ucl_habilitado ,N_ucl_habilitado FROM ##Cliente_Usuario_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_id_usuario' ,ucl_id_usuario ,N_ucl_id_usuario FROM ##Cliente_Usuario_TEMP_LOG WHERE I_ucl_id_usuario = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_id_cliente' ,ucl_id_cliente ,N_ucl_id_cliente FROM ##Cliente_Usuario_TEMP_LOG WHERE I_ucl_id_cliente = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_habilitado' ,ucl_habilitado ,N_ucl_habilitado FROM ##Cliente_Usuario_TEMP_LOG WHERE I_ucl_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_id_usuario' ,ucl_id_usuario ,NULL FROM ##Cliente_Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_id_cliente' ,ucl_id_cliente ,NULL FROM ##Cliente_Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'38' , ID ,'ucl_habilitado' ,ucl_habilitado ,NULL FROM ##Cliente_Usuario_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Cliente_Usuario_TEMP_LOG

	DROP TABLE ##Cliente_Usuario_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Marcacion
-- ============================================================
 
CREATE TRIGGER [dbo].[TRG_LOG_Marcacion]
ON [dbo].[Marcacion]
FOR INSERT, UPDATE, DELETE
AS 
BEGIN
SET NOCOUNT ON;
	
	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Marcacion_TEMP_LOG									
		(
			ID	INT 
			,ACCION INT 
			,USUARIO INT ,mar_id_usuario VARCHAR(MAX) NULL ,mar_tipo_marcacion VARCHAR(MAX) NULL ,mar_fecha_hora_marcacion VARCHAR(MAX) NULL ,mar_gps VARCHAR(MAX) NULL ,mar_latitud VARCHAR(MAX) NULL ,mar_longitud VARCHAR(MAX) NULL ,mar_modo_hora_dispositivo VARCHAR(MAX) NULL ,mar_hora_dispositivo_servidor VARCHAR(MAX) NULL ,mar_fecha_creacion VARCHAR(MAX) NULL ,mar_auto_manual VARCHAR(MAX) NULL ,mar_hash VARCHAR(MAX) NULL ,mar_dispositivo VARCHAR(MAX) NULL  ,N_mar_id_usuario VARCHAR(MAX) NULL ,N_mar_tipo_marcacion VARCHAR(MAX) NULL ,N_mar_fecha_hora_marcacion VARCHAR(MAX) NULL ,N_mar_gps VARCHAR(MAX) NULL ,N_mar_latitud VARCHAR(MAX) NULL ,N_mar_longitud VARCHAR(MAX) NULL ,N_mar_modo_hora_dispositivo VARCHAR(MAX) NULL ,N_mar_hora_dispositivo_servidor VARCHAR(MAX) NULL ,N_mar_fecha_creacion VARCHAR(MAX) NULL ,N_mar_auto_manual VARCHAR(MAX) NULL ,N_mar_hash VARCHAR(MAX) NULL ,N_mar_dispositivo VARCHAR(MAX) NULL  ,I_mar_id_usuario BIT NULL ,I_mar_tipo_marcacion BIT NULL ,I_mar_fecha_hora_marcacion BIT NULL ,I_mar_gps BIT NULL ,I_mar_latitud BIT NULL ,I_mar_longitud BIT NULL ,I_mar_modo_hora_dispositivo BIT NULL ,I_mar_hora_dispositivo_servidor BIT NULL ,I_mar_fecha_creacion BIT NULL ,I_mar_auto_manual BIT NULL ,I_mar_hash BIT NULL ,I_mar_dispositivo BIT NULL 

		)
	END
	 
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT
				
			SELECT	@USUARIO = (CASE WHEN I.mar_id_usuario IS NOT NULL THEN
								I.mar_id_usuario
							ELSE
								D.mar_id_usuario
							END)
			FROM INSERTED I
			FULL OUTER JOIN DELETED D ON I.mar_id = D.mar_id
	END
	 
	--DETERMINO ACCION,  SI ES UN INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX);
		SET @ACCION = '1' -- POR DEFECTO, ASUMIMOS QUE ES UN INSERT

		IF EXISTS (SELECT * FROM DELETED)BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN 
								'2' -- ES UN UPDATE
							ELSE 
								'3' -- ES UN DELETE
							END)
		END
	END
	 
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Marcacion_TEMP_LOG
				(
					ID
					,ACCION
					,USUARIO ,mar_id_usuario,mar_tipo_marcacion,mar_fecha_hora_marcacion,mar_gps,mar_latitud,mar_longitud,mar_modo_hora_dispositivo,mar_hora_dispositivo_servidor,mar_fecha_creacion,mar_auto_manual,mar_hash,mar_dispositivo
				)
		SELECT	mar_id
				,@ACCION 
				,@USUARIO 
				,mar_id_usuario,mar_tipo_marcacion,mar_fecha_hora_marcacion,mar_gps,mar_latitud,mar_longitud,mar_modo_hora_dispositivo,mar_hora_dispositivo_servidor,mar_fecha_creacion,mar_auto_manual,mar_hash,mar_dispositivo
		FROM	DELETED	
	END
	 
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Marcacion_TEMP_LOG
			SET	   N_mar_id_usuario = I.mar_id_usuario ,I_mar_id_usuario=(CASE WHEN ISNULL(I.mar_id_usuario ,'') != ISNULL(D.mar_id_usuario ,'') THEN 1 ELSE 0 END) ,N_mar_tipo_marcacion = I.mar_tipo_marcacion ,I_mar_tipo_marcacion=(CASE WHEN ISNULL(I.mar_tipo_marcacion ,'') != ISNULL(D.mar_tipo_marcacion ,'') THEN 1 ELSE 0 END) ,N_mar_fecha_hora_marcacion = I.mar_fecha_hora_marcacion ,I_mar_fecha_hora_marcacion=(CASE WHEN ISNULL(I.mar_fecha_hora_marcacion ,'') != ISNULL(D.mar_fecha_hora_marcacion ,'') THEN 1 ELSE 0 END) ,N_mar_gps = I.mar_gps ,I_mar_gps=(CASE WHEN ISNULL(I.mar_gps ,'') != ISNULL(D.mar_gps ,'') THEN 1 ELSE 0 END) ,N_mar_latitud = I.mar_latitud ,I_mar_latitud=(CASE WHEN ISNULL(I.mar_latitud ,'') != ISNULL(D.mar_latitud ,'') THEN 1 ELSE 0 END) ,N_mar_longitud = I.mar_longitud ,I_mar_longitud=(CASE WHEN ISNULL(I.mar_longitud ,'') != ISNULL(D.mar_longitud ,'') THEN 1 ELSE 0 END) ,N_mar_modo_hora_dispositivo = I.mar_modo_hora_dispositivo ,I_mar_modo_hora_dispositivo=(CASE WHEN ISNULL(I.mar_modo_hora_dispositivo ,'') != ISNULL(D.mar_modo_hora_dispositivo ,'') THEN 1 ELSE 0 END) ,N_mar_hora_dispositivo_servidor = I.mar_hora_dispositivo_servidor ,I_mar_hora_dispositivo_servidor=(CASE WHEN ISNULL(I.mar_hora_dispositivo_servidor ,'') != ISNULL(D.mar_hora_dispositivo_servidor ,'') THEN 1 ELSE 0 END) ,N_mar_fecha_creacion = I.mar_fecha_creacion ,I_mar_fecha_creacion=(CASE WHEN ISNULL(I.mar_fecha_creacion ,'') != ISNULL(D.mar_fecha_creacion ,'') THEN 1 ELSE 0 END) ,N_mar_auto_manual = I.mar_auto_manual ,I_mar_auto_manual=(CASE WHEN ISNULL(I.mar_auto_manual ,'') != ISNULL(D.mar_auto_manual ,'') THEN 1 ELSE 0 END) ,N_mar_hash = I.mar_hash ,I_mar_hash=(CASE WHEN ISNULL(I.mar_hash ,'') != ISNULL(D.mar_hash ,'') THEN 1 ELSE 0 END) ,N_mar_dispositivo = I.mar_dispositivo ,I_mar_dispositivo=(CASE WHEN ISNULL(I.mar_dispositivo ,'') != ISNULL(D.mar_dispositivo ,'') THEN 1 ELSE 0 END) 
				   	
			FROM	INSERTED I
					INNER JOIN DELETED D			ON D.mar_id = I.mar_id
					INNER JOIN ##Marcacion_TEMP_LOG ON ID = I.mar_id

		END ELSE BEGIN

			INSERT INTO ##Marcacion_TEMP_LOG
					(
						ID
						,ACCION
						,USUARIO ,N_mar_id_usuario,N_mar_tipo_marcacion,N_mar_fecha_hora_marcacion,N_mar_gps,N_mar_latitud,N_mar_longitud,N_mar_modo_hora_dispositivo,N_mar_hora_dispositivo_servidor,N_mar_fecha_creacion,N_mar_auto_manual,N_mar_hash,N_mar_dispositivo
					)
			SELECT	mar_id
					,@ACCION 
					,@USUARIO 
					,mar_id_usuario,mar_tipo_marcacion,mar_fecha_hora_marcacion,mar_gps,mar_latitud,mar_longitud,mar_modo_hora_dispositivo,mar_hora_dispositivo_servidor,mar_fecha_creacion,mar_auto_manual,mar_hash,mar_dispositivo
			FROM	INSERTED	

		END
	END 
	
	--INSERTO EN EL LOG
	BEGIN
		DECLARE @DATE_NOW DATETIME 
		SET @DATE_NOW = DBO.FNC_PAIS_HORA(1)
						
		IF(@ACCION = 1)BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_id_usuario' ,mar_id_usuario ,N_mar_id_usuario FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_tipo_marcacion' ,mar_tipo_marcacion ,N_mar_tipo_marcacion FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_fecha_hora_marcacion' ,mar_fecha_hora_marcacion ,N_mar_fecha_hora_marcacion FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_gps' ,mar_gps ,N_mar_gps FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_latitud' ,mar_latitud ,N_mar_latitud FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_longitud' ,mar_longitud ,N_mar_longitud FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_modo_hora_dispositivo' ,mar_modo_hora_dispositivo ,N_mar_modo_hora_dispositivo FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_hora_dispositivo_servidor' ,mar_hora_dispositivo_servidor ,N_mar_hora_dispositivo_servidor FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_fecha_creacion' ,mar_fecha_creacion ,N_mar_fecha_creacion FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_auto_manual' ,mar_auto_manual ,N_mar_auto_manual FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_hash' ,mar_hash ,N_mar_hash FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_dispositivo' ,mar_dispositivo ,N_mar_dispositivo FROM ##Marcacion_TEMP_LOG END  
		END

		IF(@ACCION = 2)BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_id_usuario' ,mar_id_usuario ,N_mar_id_usuario FROM ##Marcacion_TEMP_LOG WHERE I_mar_id_usuario = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_tipo_marcacion' ,mar_tipo_marcacion ,N_mar_tipo_marcacion FROM ##Marcacion_TEMP_LOG WHERE I_mar_tipo_marcacion = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_fecha_hora_marcacion' ,mar_fecha_hora_marcacion ,N_mar_fecha_hora_marcacion FROM ##Marcacion_TEMP_LOG WHERE I_mar_fecha_hora_marcacion = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_gps' ,mar_gps ,N_mar_gps FROM ##Marcacion_TEMP_LOG WHERE I_mar_gps = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_latitud' ,mar_latitud ,N_mar_latitud FROM ##Marcacion_TEMP_LOG WHERE I_mar_latitud = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_longitud' ,mar_longitud ,N_mar_longitud FROM ##Marcacion_TEMP_LOG WHERE I_mar_longitud = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_modo_hora_dispositivo' ,mar_modo_hora_dispositivo ,N_mar_modo_hora_dispositivo FROM ##Marcacion_TEMP_LOG WHERE I_mar_modo_hora_dispositivo = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_hora_dispositivo_servidor' ,mar_hora_dispositivo_servidor ,N_mar_hora_dispositivo_servidor FROM ##Marcacion_TEMP_LOG WHERE I_mar_hora_dispositivo_servidor = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_fecha_creacion' ,mar_fecha_creacion ,N_mar_fecha_creacion FROM ##Marcacion_TEMP_LOG WHERE I_mar_fecha_creacion = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_auto_manual' ,mar_auto_manual ,N_mar_auto_manual FROM ##Marcacion_TEMP_LOG WHERE I_mar_auto_manual = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_hash' ,mar_hash ,N_mar_hash FROM ##Marcacion_TEMP_LOG WHERE I_mar_hash = 1  END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_dispositivo' ,mar_dispositivo ,N_mar_dispositivo FROM ##Marcacion_TEMP_LOG WHERE I_mar_dispositivo = 1  END  
		END

		IF(@ACCION = 3)BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_id_usuario' ,mar_id_usuario ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_tipo_marcacion' ,mar_tipo_marcacion ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_fecha_hora_marcacion' ,mar_fecha_hora_marcacion ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_gps' ,mar_gps ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_latitud' ,mar_latitud ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_longitud' ,mar_longitud ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_modo_hora_dispositivo' ,mar_modo_hora_dispositivo ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_hora_dispositivo_servidor' ,mar_hora_dispositivo_servidor ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_fecha_creacion' ,mar_fecha_creacion ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_auto_manual' ,mar_auto_manual ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_hash' ,mar_hash ,NULL FROM ##Marcacion_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'17' , ID ,'mar_dispositivo' ,mar_dispositivo ,NULL FROM ##Marcacion_TEMP_LOG END  
		END
	END

	--SELECT * FROM ##Marcacion_TEMP_LOG

	DROP TABLE ##Marcacion_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Menu_Perfil
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Menu_Perfil]
ON [dbo].[Menu_Perfil]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Menu_Perfil_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,mpe_perfil VARCHAR(MAX) NULL ,mpe_menu VARCHAR(MAX) NULL ,mpe_habilitado VARCHAR(MAX) NULL ,mpe_host_creacion VARCHAR(MAX) NULL  ,N_mpe_perfil VARCHAR(MAX) NULL ,N_mpe_menu VARCHAR(MAX) NULL ,N_mpe_habilitado VARCHAR(MAX) NULL ,N_mpe_host_creacion VARCHAR(MAX) NULL  ,I_mpe_perfil BIT NULL ,I_mpe_menu BIT NULL ,I_mpe_habilitado BIT NULL ,I_mpe_host_creacion BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.mpe_usuario_act IS NOT NULL THEN
								I.mpe_usuario_act
							ELSE
								D.mpe_usuario_act
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.mpe_id = D.mpe_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Menu_Perfil_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,mpe_perfil,mpe_menu,mpe_habilitado,mpe_host_creacion
				)
		SELECT   mpe_id
				,@ACCION
				,@USUARIO
				,mpe_perfil,mpe_menu,mpe_habilitado,mpe_host_creacion
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Menu_Perfil_TEMP_LOG
			SET    N_mpe_perfil = I.mpe_perfil ,I_mpe_perfil = (CASE WHEN ISNULL(I.mpe_perfil,'') != ISNULL(D.mpe_perfil,'') THEN 1 ELSE 0 END) ,N_mpe_menu = I.mpe_menu ,I_mpe_menu = (CASE WHEN ISNULL(I.mpe_menu,'') != ISNULL(D.mpe_menu,'') THEN 1 ELSE 0 END) ,N_mpe_habilitado = I.mpe_habilitado ,I_mpe_habilitado = (CASE WHEN ISNULL(I.mpe_habilitado,'') != ISNULL(D.mpe_habilitado,'') THEN 1 ELSE 0 END) ,N_mpe_host_creacion = I.mpe_host_creacion ,I_mpe_host_creacion = (CASE WHEN ISNULL(I.mpe_host_creacion,'') != ISNULL(D.mpe_host_creacion,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.mpe_id = I.mpe_id
				   INNER JOIN ##Menu_Perfil_TEMP_LOG ON ID = I.mpe_id

		END ELSE BEGIN

			INSERT INTO ##Menu_Perfil_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_mpe_perfil,N_mpe_menu,N_mpe_habilitado,N_mpe_host_creacion
					)
			SELECT   mpe_id
					,@ACCION
					,@USUARIO
					,mpe_perfil,mpe_menu,mpe_habilitado,mpe_host_creacion
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_perfil' ,mpe_perfil ,N_mpe_perfil FROM ##Menu_Perfil_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_menu' ,mpe_menu ,N_mpe_menu FROM ##Menu_Perfil_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_habilitado' ,mpe_habilitado ,N_mpe_habilitado FROM ##Menu_Perfil_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_host_creacion' ,mpe_host_creacion ,N_mpe_host_creacion FROM ##Menu_Perfil_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_perfil' ,mpe_perfil ,N_mpe_perfil FROM ##Menu_Perfil_TEMP_LOG WHERE I_mpe_perfil = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_menu' ,mpe_menu ,N_mpe_menu FROM ##Menu_Perfil_TEMP_LOG WHERE I_mpe_menu = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_habilitado' ,mpe_habilitado ,N_mpe_habilitado FROM ##Menu_Perfil_TEMP_LOG WHERE I_mpe_habilitado = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_host_creacion' ,mpe_host_creacion ,N_mpe_host_creacion FROM ##Menu_Perfil_TEMP_LOG WHERE I_mpe_host_creacion = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_perfil' ,mpe_perfil ,NULL FROM ##Menu_Perfil_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_menu' ,mpe_menu ,NULL FROM ##Menu_Perfil_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_habilitado' ,mpe_habilitado ,NULL FROM ##Menu_Perfil_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'39' , ID ,'mpe_host_creacion' ,mpe_host_creacion ,NULL FROM ##Menu_Perfil_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Menu_Perfil_TEMP_LOG

	DROP TABLE ##Menu_Perfil_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Modulos_Sistema
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Modulos_Sistema]
ON [dbo].[Modulos_Sistema]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Modulos_Sistema_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,mds_nombre VARCHAR(MAX) NULL ,mds_habilitado VARCHAR(MAX) NULL  ,N_mds_nombre VARCHAR(MAX) NULL ,N_mds_habilitado VARCHAR(MAX) NULL  ,I_mds_nombre BIT NULL ,I_mds_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.mds_usuario_act IS NOT NULL THEN
								I.mds_usuario_act
							ELSE
								D.mds_usuario_act
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.mds_id = D.mds_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Modulos_Sistema_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,mds_nombre,mds_habilitado
				)
		SELECT   mds_id
				,@ACCION
				,@USUARIO
				,mds_nombre,mds_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Modulos_Sistema_TEMP_LOG
			SET    N_mds_nombre = I.mds_nombre ,I_mds_nombre = (CASE WHEN ISNULL(I.mds_nombre,'') != ISNULL(D.mds_nombre,'') THEN 1 ELSE 0 END) ,N_mds_habilitado = I.mds_habilitado ,I_mds_habilitado = (CASE WHEN ISNULL(I.mds_habilitado,'') != ISNULL(D.mds_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.mds_id = I.mds_id
				   INNER JOIN ##Modulos_Sistema_TEMP_LOG ON ID = I.mds_id

		END ELSE BEGIN

			INSERT INTO ##Modulos_Sistema_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_mds_nombre,N_mds_habilitado
					)
			SELECT   mds_id
					,@ACCION
					,@USUARIO
					,mds_nombre,mds_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'40' , ID ,'mds_nombre' ,mds_nombre ,N_mds_nombre FROM ##Modulos_Sistema_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'40' , ID ,'mds_habilitado' ,mds_habilitado ,N_mds_habilitado FROM ##Modulos_Sistema_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'40' , ID ,'mds_nombre' ,mds_nombre ,N_mds_nombre FROM ##Modulos_Sistema_TEMP_LOG WHERE I_mds_nombre = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'40' , ID ,'mds_habilitado' ,mds_habilitado ,N_mds_habilitado FROM ##Modulos_Sistema_TEMP_LOG WHERE I_mds_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'40' , ID ,'mds_nombre' ,mds_nombre ,NULL FROM ##Modulos_Sistema_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'40' , ID ,'mds_habilitado' ,mds_habilitado ,NULL FROM ##Modulos_Sistema_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Modulos_Sistema_TEMP_LOG

	DROP TABLE ##Modulos_Sistema_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Paises
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Paises]
ON [dbo].[Paises]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Paises_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,pai_nombre VARCHAR(MAX) NULL ,pai_suma_resta VARCHAR(MAX) NULL ,pai_hora VARCHAR(MAX) NULL ,pai_habilItado VARCHAR(MAX) NULL  ,N_pai_nombre VARCHAR(MAX) NULL ,N_pai_suma_resta VARCHAR(MAX) NULL ,N_pai_hora VARCHAR(MAX) NULL ,N_pai_habilItado VARCHAR(MAX) NULL  ,I_pai_nombre BIT NULL ,I_pai_suma_resta BIT NULL ,I_pai_hora BIT NULL ,I_pai_habilItado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.pai_usuario_actualizacion IS NOT NULL THEN
								I.pai_usuario_actualizacion
							ELSE
								D.pai_usuario_actualizacion
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.pai_id = D.pai_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Paises_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,pai_nombre,pai_suma_resta,pai_hora,pai_habilItado
				)
		SELECT   pai_id
				,@ACCION
				,@USUARIO
				,pai_nombre,pai_suma_resta,pai_hora,pai_habilItado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Paises_TEMP_LOG
			SET    N_pai_nombre = I.pai_nombre ,I_pai_nombre = (CASE WHEN ISNULL(I.pai_nombre,'') != ISNULL(D.pai_nombre,'') THEN 1 ELSE 0 END) ,N_pai_suma_resta = I.pai_suma_resta ,I_pai_suma_resta = (CASE WHEN ISNULL(I.pai_suma_resta,'') != ISNULL(D.pai_suma_resta,'') THEN 1 ELSE 0 END) ,N_pai_hora = I.pai_hora ,I_pai_hora = (CASE WHEN ISNULL(I.pai_hora,'') != ISNULL(D.pai_hora,'') THEN 1 ELSE 0 END) ,N_pai_habilItado = I.pai_habilItado ,I_pai_habilItado = (CASE WHEN ISNULL(I.pai_habilItado,'') != ISNULL(D.pai_habilItado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.pai_id = I.pai_id
				   INNER JOIN ##Paises_TEMP_LOG ON ID = I.pai_id

		END ELSE BEGIN

			INSERT INTO ##Paises_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_pai_nombre,N_pai_suma_resta,N_pai_hora,N_pai_habilItado
					)
			SELECT   pai_id
					,@ACCION
					,@USUARIO
					,pai_nombre,pai_suma_resta,pai_hora,pai_habilItado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_nombre' ,pai_nombre ,N_pai_nombre FROM ##Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_suma_resta' ,pai_suma_resta ,N_pai_suma_resta FROM ##Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_hora' ,pai_hora ,N_pai_hora FROM ##Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_habilItado' ,pai_habilItado ,N_pai_habilItado FROM ##Paises_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_nombre' ,pai_nombre ,N_pai_nombre FROM ##Paises_TEMP_LOG WHERE I_pai_nombre = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_suma_resta' ,pai_suma_resta ,N_pai_suma_resta FROM ##Paises_TEMP_LOG WHERE I_pai_suma_resta = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_hora' ,pai_hora ,N_pai_hora FROM ##Paises_TEMP_LOG WHERE I_pai_hora = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_habilItado' ,pai_habilItado ,N_pai_habilItado FROM ##Paises_TEMP_LOG WHERE I_pai_habilItado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_nombre' ,pai_nombre ,NULL FROM ##Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_suma_resta' ,pai_suma_resta ,NULL FROM ##Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_hora' ,pai_hora ,NULL FROM ##Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'42' , ID ,'pai_habilItado' ,pai_habilItado ,NULL FROM ##Paises_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Paises_TEMP_LOG

	DROP TABLE ##Paises_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Perfiles
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Perfiles]
ON [dbo].[Perfiles]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Perfiles_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,per_nombre VARCHAR(MAX) NULL ,per_descripcion VARCHAR(MAX) NULL ,per_tipo VARCHAR(MAX) NULL ,per_habilitado VARCHAR(MAX) NULL  ,N_per_nombre VARCHAR(MAX) NULL ,N_per_descripcion VARCHAR(MAX) NULL ,N_per_tipo VARCHAR(MAX) NULL ,N_per_habilitado VARCHAR(MAX) NULL  ,I_per_nombre BIT NULL ,I_per_descripcion BIT NULL ,I_per_tipo BIT NULL ,I_per_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.per_usuario_act IS NOT NULL THEN
								I.per_usuario_act
							ELSE
								D.per_usuario_act
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.per_id = D.per_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Perfiles_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,per_nombre,per_descripcion,per_tipo,per_habilitado
				)
		SELECT   per_id
				,@ACCION
				,@USUARIO
				,per_nombre,per_descripcion,per_tipo,per_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Perfiles_TEMP_LOG
			SET    N_per_nombre = I.per_nombre ,I_per_nombre = (CASE WHEN ISNULL(I.per_nombre,'') != ISNULL(D.per_nombre,'') THEN 1 ELSE 0 END) ,N_per_descripcion = I.per_descripcion ,I_per_descripcion = (CASE WHEN ISNULL(I.per_descripcion,'') != ISNULL(D.per_descripcion,'') THEN 1 ELSE 0 END) ,N_per_tipo = I.per_tipo ,I_per_tipo = (CASE WHEN ISNULL(I.per_tipo,'') != ISNULL(D.per_tipo,'') THEN 1 ELSE 0 END) ,N_per_habilitado = I.per_habilitado ,I_per_habilitado = (CASE WHEN ISNULL(I.per_habilitado,'') != ISNULL(D.per_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.per_id = I.per_id
				   INNER JOIN ##Perfiles_TEMP_LOG ON ID = I.per_id

		END ELSE BEGIN

			INSERT INTO ##Perfiles_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_per_nombre,N_per_descripcion,N_per_tipo,N_per_habilitado
					)
			SELECT   per_id
					,@ACCION
					,@USUARIO
					,per_nombre,per_descripcion,per_tipo,per_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_nombre' ,per_nombre ,N_per_nombre FROM ##Perfiles_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_descripcion' ,per_descripcion ,N_per_descripcion FROM ##Perfiles_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_tipo' ,per_tipo ,N_per_tipo FROM ##Perfiles_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_habilitado' ,per_habilitado ,N_per_habilitado FROM ##Perfiles_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_nombre' ,per_nombre ,N_per_nombre FROM ##Perfiles_TEMP_LOG WHERE I_per_nombre = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_descripcion' ,per_descripcion ,N_per_descripcion FROM ##Perfiles_TEMP_LOG WHERE I_per_descripcion = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_tipo' ,per_tipo ,N_per_tipo FROM ##Perfiles_TEMP_LOG WHERE I_per_tipo = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_habilitado' ,per_habilitado ,N_per_habilitado FROM ##Perfiles_TEMP_LOG WHERE I_per_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_nombre' ,per_nombre ,NULL FROM ##Perfiles_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_descripcion' ,per_descripcion ,NULL FROM ##Perfiles_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_tipo' ,per_tipo ,NULL FROM ##Perfiles_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'43' , ID ,'per_habilitado' ,per_habilitado ,NULL FROM ##Perfiles_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Perfiles_TEMP_LOG

	DROP TABLE ##Perfiles_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Privacidad_Modulos_Sistema
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Privacidad_Modulos_Sistema]
ON [dbo].[Privacidad_Modulos_Sistema]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Privacidad_Modulos_Sistema_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,PMS_ID_MODULO VARCHAR(MAX) NULL ,PMS_DESCRIPCION VARCHAR(MAX) NULL  ,N_PMS_ID_MODULO VARCHAR(MAX) NULL ,N_PMS_DESCRIPCION VARCHAR(MAX) NULL  ,I_PMS_ID_MODULO BIT NULL ,I_PMS_DESCRIPCION BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.PMS_USUARIO_ACT IS NOT NULL THEN
								I.PMS_USUARIO_ACT
							ELSE
								D.PMS_USUARIO_ACT
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.PMS_ID = D.PMS_ID
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Privacidad_Modulos_Sistema_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,PMS_ID_MODULO,PMS_DESCRIPCION
				)
		SELECT   PMS_ID
				,@ACCION
				,@USUARIO
				,PMS_ID_MODULO,PMS_DESCRIPCION
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Privacidad_Modulos_Sistema_TEMP_LOG
			SET    N_PMS_ID_MODULO = I.PMS_ID_MODULO ,I_PMS_ID_MODULO = (CASE WHEN ISNULL(I.PMS_ID_MODULO,'') != ISNULL(D.PMS_ID_MODULO,'') THEN 1 ELSE 0 END) ,N_PMS_DESCRIPCION = I.PMS_DESCRIPCION ,I_PMS_DESCRIPCION = (CASE WHEN ISNULL(I.PMS_DESCRIPCION,'') != ISNULL(D.PMS_DESCRIPCION,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.PMS_ID = I.PMS_ID
				   INNER JOIN ##Privacidad_Modulos_Sistema_TEMP_LOG ON ID = I.PMS_ID

		END ELSE BEGIN

			INSERT INTO ##Privacidad_Modulos_Sistema_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_PMS_ID_MODULO,N_PMS_DESCRIPCION
					)
			SELECT   PMS_ID
					,@ACCION
					,@USUARIO
					,PMS_ID_MODULO,PMS_DESCRIPCION
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'44' , ID ,'PMS_ID_MODULO' ,PMS_ID_MODULO ,N_PMS_ID_MODULO FROM ##Privacidad_Modulos_Sistema_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'44' , ID ,'PMS_DESCRIPCION' ,PMS_DESCRIPCION ,N_PMS_DESCRIPCION FROM ##Privacidad_Modulos_Sistema_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'44' , ID ,'PMS_ID_MODULO' ,PMS_ID_MODULO ,N_PMS_ID_MODULO FROM ##Privacidad_Modulos_Sistema_TEMP_LOG WHERE I_PMS_ID_MODULO = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'44' , ID ,'PMS_DESCRIPCION' ,PMS_DESCRIPCION ,N_PMS_DESCRIPCION FROM ##Privacidad_Modulos_Sistema_TEMP_LOG WHERE I_PMS_DESCRIPCION = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'44' , ID ,'PMS_ID_MODULO' ,PMS_ID_MODULO ,NULL FROM ##Privacidad_Modulos_Sistema_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'44' , ID ,'PMS_DESCRIPCION' ,PMS_DESCRIPCION ,NULL FROM ##Privacidad_Modulos_Sistema_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Privacidad_Modulos_Sistema_TEMP_LOG

	DROP TABLE ##Privacidad_Modulos_Sistema_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Usuario
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Usuario]
ON [dbo].[Usuario]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Usuario_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,usu_login VARCHAR(MAX) NULL ,usu_password VARCHAR(MAX) NULL ,usu_nombre VARCHAR(MAX) NULL ,usu_apellido_paterno VARCHAR(MAX) NULL ,usu_apellido_materno VARCHAR(MAX) NULL ,usu_identificador VARCHAR(MAX) NULL ,usu_correo VARCHAR(MAX) NULL ,usu_telefono VARCHAR(MAX) NULL ,usu_habilitado VARCHAR(MAX) NULL  ,N_usu_login VARCHAR(MAX) NULL ,N_usu_password VARCHAR(MAX) NULL ,N_usu_nombre VARCHAR(MAX) NULL ,N_usu_apellido_paterno VARCHAR(MAX) NULL ,N_usu_apellido_materno VARCHAR(MAX) NULL ,N_usu_identificador VARCHAR(MAX) NULL ,N_usu_correo VARCHAR(MAX) NULL ,N_usu_telefono VARCHAR(MAX) NULL ,N_usu_habilitado VARCHAR(MAX) NULL  ,I_usu_login BIT NULL ,I_usu_password BIT NULL ,I_usu_nombre BIT NULL ,I_usu_apellido_paterno BIT NULL ,I_usu_apellido_materno BIT NULL ,I_usu_identificador BIT NULL ,I_usu_correo BIT NULL ,I_usu_telefono BIT NULL ,I_usu_habilitado BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.usu_usuario_act IS NOT NULL THEN
								I.usu_usuario_act
							ELSE
								D.usu_usuario_act
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.usu_id = D.usu_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Usuario_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,usu_login,usu_password,usu_nombre,usu_apellido_paterno,usu_apellido_materno,usu_identificador,usu_correo,usu_telefono,usu_habilitado
				)
		SELECT   usu_id
				,@ACCION
				,@USUARIO
				,usu_login,usu_password,usu_nombre,usu_apellido_paterno,usu_apellido_materno,usu_identificador,usu_correo,usu_telefono,usu_habilitado
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Usuario_TEMP_LOG
			SET    N_usu_login = I.usu_login ,I_usu_login = (CASE WHEN ISNULL(I.usu_login,'') != ISNULL(D.usu_login,'') THEN 1 ELSE 0 END) ,N_usu_password = I.usu_password ,I_usu_password = (CASE WHEN ISNULL(I.usu_password,'') != ISNULL(D.usu_password,'') THEN 1 ELSE 0 END) ,N_usu_nombre = I.usu_nombre ,I_usu_nombre = (CASE WHEN ISNULL(I.usu_nombre,'') != ISNULL(D.usu_nombre,'') THEN 1 ELSE 0 END) ,N_usu_apellido_paterno = I.usu_apellido_paterno ,I_usu_apellido_paterno = (CASE WHEN ISNULL(I.usu_apellido_paterno,'') != ISNULL(D.usu_apellido_paterno,'') THEN 1 ELSE 0 END) ,N_usu_apellido_materno = I.usu_apellido_materno ,I_usu_apellido_materno = (CASE WHEN ISNULL(I.usu_apellido_materno,'') != ISNULL(D.usu_apellido_materno,'') THEN 1 ELSE 0 END) ,N_usu_identificador = I.usu_identificador ,I_usu_identificador = (CASE WHEN ISNULL(I.usu_identificador,'') != ISNULL(D.usu_identificador,'') THEN 1 ELSE 0 END) ,N_usu_correo = I.usu_correo ,I_usu_correo = (CASE WHEN ISNULL(I.usu_correo,'') != ISNULL(D.usu_correo,'') THEN 1 ELSE 0 END) ,N_usu_telefono = I.usu_telefono ,I_usu_telefono = (CASE WHEN ISNULL(I.usu_telefono,'') != ISNULL(D.usu_telefono,'') THEN 1 ELSE 0 END) ,N_usu_habilitado = I.usu_habilitado ,I_usu_habilitado = (CASE WHEN ISNULL(I.usu_habilitado,'') != ISNULL(D.usu_habilitado,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.usu_id = I.usu_id
				   INNER JOIN ##Usuario_TEMP_LOG ON ID = I.usu_id

		END ELSE BEGIN

			INSERT INTO ##Usuario_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_usu_login,N_usu_password,N_usu_nombre,N_usu_apellido_paterno,N_usu_apellido_materno,N_usu_identificador,N_usu_correo,N_usu_telefono,N_usu_habilitado
					)
			SELECT   usu_id
					,@ACCION
					,@USUARIO
					,usu_login,usu_password,usu_nombre,usu_apellido_paterno,usu_apellido_materno,usu_identificador,usu_correo,usu_telefono,usu_habilitado
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO

		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_login' ,usu_login ,N_usu_login FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_password' ,usu_password ,N_usu_password FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_nombre' ,usu_nombre ,N_usu_nombre FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_apellido_paterno' ,usu_apellido_paterno ,N_usu_apellido_paterno FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_apellido_materno' ,usu_apellido_materno ,N_usu_apellido_materno FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_identificador' ,usu_identificador ,N_usu_identificador FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_correo' ,usu_correo ,N_usu_correo FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_telefono' ,usu_telefono ,N_usu_telefono FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_habilitado' ,usu_habilitado ,N_usu_habilitado FROM ##Usuario_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_login' ,usu_login ,N_usu_login FROM ##Usuario_TEMP_LOG WHERE I_usu_login = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_password' ,usu_password ,N_usu_password FROM ##Usuario_TEMP_LOG WHERE I_usu_password = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_nombre' ,usu_nombre ,N_usu_nombre FROM ##Usuario_TEMP_LOG WHERE I_usu_nombre = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_apellido_paterno' ,usu_apellido_paterno ,N_usu_apellido_paterno FROM ##Usuario_TEMP_LOG WHERE I_usu_apellido_paterno = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_apellido_materno' ,usu_apellido_materno ,N_usu_apellido_materno FROM ##Usuario_TEMP_LOG WHERE I_usu_apellido_materno = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_identificador' ,usu_identificador ,N_usu_identificador FROM ##Usuario_TEMP_LOG WHERE I_usu_identificador = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_correo' ,usu_correo ,N_usu_correo FROM ##Usuario_TEMP_LOG WHERE I_usu_correo = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_telefono' ,usu_telefono ,N_usu_telefono FROM ##Usuario_TEMP_LOG WHERE I_usu_telefono = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_habilitado' ,usu_habilitado ,N_usu_habilitado FROM ##Usuario_TEMP_LOG WHERE I_usu_habilitado = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_login' ,usu_login ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_password' ,usu_password ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_nombre' ,usu_nombre ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_apellido_paterno' ,usu_apellido_paterno ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_apellido_materno' ,usu_apellido_materno ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_identificador' ,usu_identificador ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_correo' ,usu_correo ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_telefono' ,usu_telefono ,NULL FROM ##Usuario_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'45' , ID ,'usu_habilitado' ,usu_habilitado ,NULL FROM ##Usuario_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Usuario_TEMP_LOG

	DROP TABLE ##Usuario_TEMP_LOG
END

GO

-- ============================================================
-- SQL_TRIGGER : TRG_LOG_Usuario_Paises
-- ============================================================

CREATE TRIGGER [dbo].[TRG_LOG_Usuario_Paises]
ON [dbo].[Usuario_Paises]
FOR INSERT, UPDATE, DELETE
AS
BEGIN
SET NOCOUNT ON;

	--CREO LA TABLA TEMP
	BEGIN
		CREATE TABLE ##Usuario_Paises_TEMP_LOG
		(
			 ID      INT
			,ACCION  INT
			,USUARIO INT,upa_id_usuario VARCHAR(MAX) NULL ,upa_id_pais VARCHAR(MAX) NULL  ,N_upa_id_usuario VARCHAR(MAX) NULL ,N_upa_id_pais VARCHAR(MAX) NULL  ,I_upa_id_usuario BIT NULL ,I_upa_id_pais BIT NULL 
		)
	END
	
	--OBTENGO EL USUARIO Y EL ID DEL O LOS REGISTROS A PROCESAR
	BEGIN
		DECLARE @USUARIO INT

		SELECT @USUARIO = (CASE WHEN I.upa_usuario_act IS NOT NULL THEN
								I.upa_usuario_act
							ELSE
								D.upa_usuario_act
							END)
		FROM   INSERTED I
		FULL OUTER JOIN DELETED D ON I.upa_id = D.upa_id
	END
	
	--DETERMINO ACCION: INSERT, UPDATE O DELETE
	BEGIN
		DECLARE @ACCION VARCHAR(MAX)
		SET @ACCION = '1' -- POR DEFECTO: INSERT

		IF EXISTS (SELECT * FROM DELETED) BEGIN
			SET @ACCION = (CASE WHEN EXISTS (SELECT * FROM INSERTED) THEN
								'2' -- UPDATE
							ELSE
								'3' -- DELETE
							END)
		END
	END
	
	--INSERTO LOS VALORES ANTERIORES
	BEGIN
		INSERT INTO ##Usuario_Paises_TEMP_LOG
				(
					 ID
					,ACCION
					,USUARIO,upa_id_usuario,upa_id_pais
				)
		SELECT   upa_id
				,@ACCION
				,@USUARIO
				,upa_id_usuario,upa_id_pais
		FROM   DELETED
	END
	
	--INSERTO LOS NUEVOS VALORES
	BEGIN
		IF EXISTS(SELECT 1 FROM DELETED) BEGIN

			UPDATE ##Usuario_Paises_TEMP_LOG
			SET    N_upa_id_usuario = I.upa_id_usuario ,I_upa_id_usuario = (CASE WHEN ISNULL(I.upa_id_usuario,'') != ISNULL(D.upa_id_usuario,'') THEN 1 ELSE 0 END) ,N_upa_id_pais = I.upa_id_pais ,I_upa_id_pais = (CASE WHEN ISNULL(I.upa_id_pais,'') != ISNULL(D.upa_id_pais,'') THEN 1 ELSE 0 END) 
			FROM   INSERTED I
				   INNER JOIN DELETED D         ON D.upa_id = I.upa_id
				   INNER JOIN ##Usuario_Paises_TEMP_LOG ON ID = I.upa_id

		END ELSE BEGIN

			INSERT INTO ##Usuario_Paises_TEMP_LOG
					(
						 ID
						,ACCION
						,USUARIO,N_upa_id_usuario,N_upa_id_pais
					)
			SELECT   upa_id
					,@ACCION
					,@USUARIO
					,upa_id_usuario,upa_id_pais
			FROM   INSERTED

		END
	END
	
	--INSERTO EN EL LOG
	BEGIN
		--OBTENGO LA FECHA SEGUN EL PAIS DEL USUARIO
		--SI EL USUARIO NO TIENE PAIS ASIGNADO SE USA GETDATE()
		DECLARE @DATE_NOW    DATETIME
		DECLARE @PAIS_USUARIO INT

		SELECT TOP 1 @PAIS_USUARIO = upa_id_pais
		FROM   Usuario_Paises
		WHERE  upa_id_usuario = @USUARIO


		IF @PAIS_USUARIO IS NOT NULL
			SET @DATE_NOW = DBO.FNC_PAIS_HORA(@PAIS_USUARIO)
		ELSE
			SET @DATE_NOW = GETDATE()

		IF(@ACCION = 1) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'46' , ID ,'upa_id_usuario' ,upa_id_usuario ,N_upa_id_usuario FROM ##Usuario_Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'46' , ID ,'upa_id_pais' ,upa_id_pais ,N_upa_id_pais FROM ##Usuario_Paises_TEMP_LOG END 
		END

		IF(@ACCION = 2) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'46' , ID ,'upa_id_usuario' ,upa_id_usuario ,N_upa_id_usuario FROM ##Usuario_Paises_TEMP_LOG WHERE I_upa_id_usuario = 1 END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'46' , ID ,'upa_id_pais' ,upa_id_pais ,N_upa_id_pais FROM ##Usuario_Paises_TEMP_LOG WHERE I_upa_id_pais = 1 END 
		END

		IF(@ACCION = 3) BEGIN
			 BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'46' , ID ,'upa_id_usuario' ,upa_id_usuario ,NULL FROM ##Usuario_Paises_TEMP_LOG END  BEGIN INSERT INTO LOG SELECT @USUARIO ,@DATE_NOW ,@ACCION ,'46' , ID ,'upa_id_pais' ,upa_id_pais ,NULL FROM ##Usuario_Paises_TEMP_LOG END 
		END
	END

	--SELECT * FROM ##Usuario_Paises_TEMP_LOG

	DROP TABLE ##Usuario_Paises_TEMP_LOG
END

GO
