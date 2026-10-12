/* ============================================================================
   SIGMA — Bloque 436
   SP SEL_USUARIO_ACCESIBILIDAD (HU-162, T-5327)
   ----------------------------------------------------------------------------

   Un solo SP para las dos lecturas:
     · por @ID       -> la ficha (una fila).
     · por @USUARIO  -> las preferencias de esa persona (0 o 1 fila; el índice
                        único UX_UAC_USUARIO garantiza que no hay más).
   Filtros opcionales @HABILITADO y @FILTRO (nombre de la persona) para la
   grilla, y ORDER BY estable por uac_id.

   NO SE VE LO DE OTRA EMPRESA
     Se une a Usuario y, si viene @CLIENTE, se exige que la persona pertenezca a
     ese cliente. Aun así, la seguridad real es por USUARIO: la pantalla y la API
     consultan siempre con @USUARIO = la persona en sesión, así nadie lee las
     preferencias de otro.

   Idempotente (CREATE OR ALTER).
   ============================================================================ */
CREATE OR ALTER PROCEDURE [dbo].[SEL_USUARIO_ACCESIBILIDAD]
     @ID          INT            = NULL
    ,@USUARIO     INT            = NULL
    ,@CLIENTE     INT            = NULL
    ,@HABILITADO  BIT            = NULL
    ,@FILTRO      NVARCHAR(200)  = NULL
AS
SET NOCOUNT ON

    SELECT  uac.[uac_id]
           ,uac.[uac_usuario]
           ,ISNULL(u.[usu_nombre] + ' ' + ISNULL(u.[usu_apellido_paterno], ''), '') AS USUARIO_NOMBRE
           ,uac.[uac_entrada_voz]
           ,uac.[uac_lectura_voz]
           ,uac.[uac_confirmacion_hablada]
           ,uac.[uac_velocidad_voz]
           ,uac.[uac_texto_grande]
           ,uac.[uac_alto_contraste]
           ,uac.[uac_iconos_grandes]
           ,uac.[uac_idioma]
           ,uac.[uac_volumen]
           ,uac.[uac_silenciar_alertas]
           ,uac.[uac_habilitado]
           ,uac.[uac_fecha_creacion]
           ,uac.[uac_fecha_actualizacion]

      FROM  [dbo].[Usuario_Accesibilidad] uac
      JOIN  [dbo].[Usuario]               u  ON u.[usu_id] = uac.[uac_usuario]

     WHERE  (@ID         IS NULL OR uac.[uac_id]         = @ID)
       AND  (@USUARIO    IS NULL OR uac.[uac_usuario]    = @USUARIO)
       AND  (@HABILITADO IS NULL OR uac.[uac_habilitado] = @HABILITADO)
       AND  (@CLIENTE    IS NULL OR u.[usu_id] IN
                (SELECT cu.[ucl_id_usuario] FROM [dbo].[Cliente_Usuario] cu
                  WHERE cu.[ucl_id_cliente] = @CLIENTE AND ISNULL(cu.[ucl_habilitado], 0) = 1))
       AND  (@FILTRO IS NULL OR @FILTRO = ''
             OR (u.[usu_nombre] + ' ' + ISNULL(u.[usu_apellido_paterno], '')) LIKE '%' + @FILTRO + '%')

     ORDER BY uac.[uac_id]
GO

PRINT '--- SEL_USUARIO_ACCESIBILIDAD creado (bloque 436).'
GO
