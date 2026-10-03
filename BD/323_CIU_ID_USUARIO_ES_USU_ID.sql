/* ============================================================================
   SIGMA - Bloque 323
   LOS DOS SP QUE QUEDARON LEYENDO Cliente_Instalacion_Usuario AL REVES
   ----------------------------------------------------------------------------

   CIU_ID_USUARIO GUARDA UN usu_id, NO UN ucl_id.

   Lo fija la clave foranea -ciu_id_usuario -> Usuario.usu_id- y lo respetan
   los SP que escriben: UPS_CLIENTE_USUARIO_PLANTA inserta @USUARIO_DESTINO, e
   INS_GRUPO_TRABAJO_USUARIO compara contra el id del integrante.

   Es un error conocido en este proyecto: el bloque 47 ya lo corrigio en
   INS_CLIENTE_USUARIO_ASOCIAR -que escribia el ucl_id- y agrego la FK que lo
   obliga, y el bloque 50 lo corrigio en DEL_USUARIO_ASOCIACION. Estos dos
   quedaron del lado viejo, y se encontraron armando los grupos de trabajo de
   Hamburgo el 02-10-2026.

   Por que no se habia notado: con la tabla vacia ninguno de los dos hace nada
   visible. El dano aparece justo cuando se empieza a usar, que es lo peor,
   porque para entonces el sintoma ya no apunta al origen.

     1. SEL_USUARIO_CLIENTE_INSTALACION  (Mi Cuenta)
        LEFT JOIN ... ON CIU_ID_USUARIO = UCL_ID
        Compara el id de la persona contra la PK de la afiliacion. A alguien le
        muestra plantas que no son suyas -las del usuario cuyo usu_id coincide
        con su ucl_id- y a los demas ninguna.

     2. SEL_CLIENTE_USUARIO_ASOCIAR_INSTALACION  (asociar responsables a una
        planta)
        El NOT IN que saca de la lista a quien ya esta en la planta hace
        INNER JOIN CLIENTE_USUARIO ON UCL_ID = CIU_ID_USUARIO y devuelve
        UCL_ID_USUARIO: excluye a la persona equivocada. Con la tabla vacia el
        listado salia completo y parecia sano; al autorizar a los 24 de Renca
        habria empezado a esconder gente al azar y a ofrecer a quienes ya
        estaban.

   No se cambia nada mas de los dos SP: ni columnas, ni filtros, ni el orden.
   Solo la condicion de union.
   ============================================================================ */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. SEL_USUARIO_CLIENTE_INSTALACION

      Las plantas de una persona dentro de cada uno de sus clientes.
      El LEFT JOIN se mantiene: quien no tiene ninguna planta asignada
      igual tiene que aparecer con su cliente.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_CLIENTE_INSTALACION]
@ID_USUARIO INT
AS
BEGIN
    SELECT  DISTINCT
            CLI_ID,
            CLI_NOMBRE,
            CIN_ID,
            CIN_NOMBRE
    FROM    CLIENTE_USUARIO
            INNER JOIN CLIENTE                     ON CLI_ID = UCL_ID_CLIENTE
            LEFT JOIN  CLIENTE_INSTALACION_USUARIO ON CIU_ID_USUARIO = UCL_ID_USUARIO
            LEFT JOIN  CLIENTE_INSTALACION         ON CIN_ID = CIU_ID_INSTALACION
                                                  AND CIN_CLIENTE = CLI_ID
    WHERE   UCL_ID_USUARIO = @ID_USUARIO
    ORDER BY CLI_NOMBRE, CIN_NOMBRE
END
GO


/* ========================================================================
   2. SEL_CLIENTE_USUARIO_ASOCIAR_INSTALACION

      Los candidatos para asociar a una planta. Lo unico que cambia es el
      NOT IN de abajo: ahora pregunta por el id de la persona, que es lo que
      esa columna guarda, y sin pasar por Cliente_Usuario, que no hacia
      falta para nada.
   ======================================================================== */
CREATE OR ALTER PROCEDURE [dbo].[SEL_CLIENTE_USUARIO_ASOCIAR_INSTALACION]
@CLIENTE INT,
@TIPO_PERFIL INT = NULL,
@PERFILES VARCHAR(MAX) = NULL,
@INSTALACION INT = NULL,
@FILTRO VARCHAR(MAX) = NULL

AS

--SELECT
BEGIN
	DECLARE @SELECT VARCHAR(MAX)
	DECLARE @TIPO VARCHAR(MAX) = ''

	SET @SELECT = ' SELECT DISTINCT USU_ID
							,USU_NOMBRE
							,USU_APELLIDO_PATERNO
							,USU_APELLIDO_MATERNO
							,USU_IDENTIFICADOR
							,USU_CORREO
							,USU_TELEFONO
				  '
	IF(@TIPO_PERFIL IS NOT NULL)BEGIN
		SET @TIPO = '	,PER_NOMBRE					[PERFILES]
						,PER_ID						[ID_PERFILES_USUARIO]
				'
	END
	IF(@TIPO_PERFIL = 1)BEGIN
		SET @TIPO = '
						,REVERSE(STUFF(REVERSE(((SELECT	DISTINCT LTRIM(PER_NOMBRE) + '',''
													FROM	USUARIO_PERFIL
															INNER JOIN PERFILES					ON PER_ID = UPE_PERFIL
															INNER JOIN CLIENTE_USUARIO			ON UCL_ID_USUARIO = UPE_USUARIO AND
																								   UCL_ID_CLIENTE = ' + LTRIM(@CLIENTE) + '
															INNER JOIN CLIENTE_USUARIO_PERFIL	ON CUP_ID_CLIENTE_USUARIO = UCL_ID AND
																								   CUP_ID_PERFIL = UPE_PERFIL
													WHERE	UPE_USUARIO = USU_ID
													FOR XML PATH (''''))
												   )
										), 1, 1, '''')) [PERFILES]
				'
	END
END

--FROM
BEGIN
	DECLARE	@FROM VARCHAR(MAX)

	SET	@FROM = ' FROM	USUARIO
						INNER JOIN USUARIO_PERFIL						ON	UPE_USUARIO = USU_ID
						INNER JOIN PERFILES								ON	PER_ID = UPE_PERFIL
						LEFT JOIN  CLIENTE_USUARIO						ON	UCL_ID_USUARIO = USU_ID
						LEFT JOIN  CLIENTE								ON	CLI_ID = UCL_ID_CLIENTE
						LEFT JOIN  CLIENTE_USUARIO_PERFIL				ON  CUP_ID_CLIENTE_USUARIO = UCL_ID
																		AND CUP_ID_PERFIL = UPE_PERFIL
				'
END

--WHERE
BEGIN
	DECLARE @WHERE VARCHAR(MAX)

	SET @WHERE = '	WHERE 1=1
					AND USU_HABILITADO = 1
					AND	UCL_HABILITADO = 1
				 '

	IF(@CLIENTE IS NOT NULL AND @INSTALACION IS NULL)BEGIN
		SET @WHERE = @WHERE + ' AND	USU_ID NOT IN(SELECT UCL_ID_USUARIO
												  FROM CLIENTE_USUARIO
												  WHERE UCL_ID_CLIENTE = ' + LTRIM(@CLIENTE) + '
												  )
							  '
	END

	IF(@TIPO_PERFIL IS NOT NULL)BEGIN
		SET @WHERE = @WHERE + ' AND	PER_TIPO = ' + LTRIM(@TIPO_PERFIL) + ' AND USU_HABILITADO = 1 '
		IF(@PERFILES IS NOT NULL)BEGIN
			SET @WHERE = @WHERE + ' AND PER_ID IN(' + @PERFILES + ')'
		END
	END

	IF(@TIPO_PERFIL = 2)BEGIN
		IF(@PERFILES IS NOT NULL)BEGIN
			SET @WHERE = @WHERE + ' AND	UPE_PERFIL IN(' + @PERFILES + ')'
		END
		SET @WHERE = @WHERE + ' AND	UCL_ID_CLIENTE = ' + LTRIM(@CLIENTE) + '
								AND	UCL_HABILITADO = 1
							'
	END

	IF(@CLIENTE IS NOT NULL AND @INSTALACION IS NOT NULL)BEGIN

		SET @WHERE = @WHERE + '	AND CLI_ID = ' + LTRIM(@CLIENTE)

		/* CIU_ID_USUARIO ya es el usu_id: no hay que pasar por
		   Cliente_Usuario para traducirlo, y hacerlo excluia a otra persona. */
		SET @WHERE = @WHERE + ' AND	USU_ID NOT IN (SELECT CIU_ID_USUARIO
													FROM	CLIENTE_INSTALACION_USUARIO
													WHERE	CIU_ID_INSTALACION IN (' + LTRIM(@INSTALACION) + ')
													  AND	ISNULL(CIU_HABILITADO, 0) = 1
												)
								  '

	END

	IF(@FILTRO IS NOT NULL)BEGIN
		SET @WHERE = @WHERE +  ' AND (USU_NOMBRE LIKE ''%' + @FILTRO + '%''
										OR USU_APELLIDO_PATERNO LIKE ''%' + @FILTRO + '%''
										OR USU_APELLIDO_MATERNO LIKE ''%' + @FILTRO + '%''
										OR USU_IDENTIFICADOR LIKE ''%' + @FILTRO + '%''
										OR USU_ID LIKE ''%' + LTRIM(@FILTRO) + '%''
										OR USU_LOGIN LIKE ''%' + LTRIM(@FILTRO) + '%''
									)'
	END
END

EXEC(@SELECT + @TIPO + @FROM + @WHERE)
GO


/* ============================================================================
   COMPROBACION

   Con los 24 de Renca autorizados, el listado de candidatos para esa planta
   tiene que venir VACIO -ya estan todos- y el de otra planta, completo.
   Antes del arreglo venian los 24 igual, porque el NOT IN preguntaba por el
   id equivocado.
   ============================================================================ */
PRINT '--- candidatos para una planta donde ya estan todos (esperado: 0) ---'
GO
