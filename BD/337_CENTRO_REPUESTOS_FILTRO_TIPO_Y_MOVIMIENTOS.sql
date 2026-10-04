/* ============================================================================
   SIGMA - Bloque 337
   CENTRO DE REPUESTOS: EL FILTRO DE TIPO FILTRA Y EL MOVIMIENTO SE PUEDE REGISTRAR
   ----------------------------------------------------------------------------
   Bug 18. El combo "Tipo de repuesto" del centro armaba el filtro, pero
   SEL_REPUESTO no tenia @REPUESTO_TIPO: elegir Rodamientos seguia mostrando
   los 600 repuestos. Se agrega el parametro (opcional, como los demas).

   Bug 17. RepuestoCentro.aspx muestra "Registrar movimiento" -y los botones
   de mover stock de Existencias- solo a quien tiene el permiso
   REGISTRAR MOVIMIENTOS DE INVENTARIO, que nunca se creo: nadie veia el
   boton. Se crea y se asigna a los perfiles que ya mueven stock hoy
   (1 Root y 4 Bodeguero, los que tienen GESTIONAR STOCK).
   ============================================================================ */
SET NOCOUNT ON
GO

-- ---------------------------------------------------------------------------
-- 1) SEL_REPUESTO filtra por tipo
-- ---------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[SEL_REPUESTO]
    @ID             INT = NULL,
    @CLIENTE        INT,
    @FILTRO         NVARCHAR(200) = NULL,
    @HABILITADO     BIT = NULL,
    @REPUESTO_TIPO  INT = NULL
AS
SET NOCOUNT ON

    SELECT  r.rep_id, r.rep_cliente, r.rep_codigo, r.rep_nombre,
            r.rep_fabricante, r.rep_modelo, r.rep_descripcion,
            r.rep_unidad_medida, r.rep_es_reparable, r.rep_es_consumible,
            ISNULL(r.rep_repuesto_tipo, 0) AS REPUESTO_TIPO,
        ISNULL((SELECT t.rti_nombre FROM [dbo].[Repuesto_Tipo] t
                 WHERE t.rti_id = r.rep_repuesto_tipo), '') AS REPUESTO_TIPO_NOMBRE,
        r.rep_controla_lote, r.rep_costo_referencia, r.rep_moneda,
            r.rep_vida_util_hora, r.rep_vida_util_dia, r.rep_vida_util_ciclo,
            r.rep_habilitado,
            r.rep_usuario_creacion, r.rep_fecha_creacion,
            r.rep_usuario_actualizacion, r.rep_fecha_actualizacion,
            LTRIM(RTRIM(ISNULL(uc.usu_nombre,'') + ' ' + ISNULL(uc.usu_apellido_paterno,''))) AS USUARIO_CREACION_NOMBRE,
            LTRIM(RTRIM(ISNULL(ua.usu_nombre,'') + ' ' + ISNULL(ua.usu_apellido_paterno,''))) AS USUARIO_ACTUALIZACION_NOMBRE,
            ume.ume_nombre  AS UNIDAD_NOMBRE,
            ume.ume_simbolo AS UNIDAD_SIMBOLO,
            mon.mon_codigo  AS MONEDA_CODIGO,
            ISNULL((SELECT SUM(s.isa_cantidad) FROM [dbo].[Inventario_Saldo] s
                     WHERE s.isa_repuesto = r.rep_id), 0) AS EXISTENCIA_TOTAL,
            (SELECT COUNT(*) FROM [dbo].[Inventario_Saldo] s
              WHERE s.isa_repuesto = r.rep_id AND s.isa_cantidad > 0) AS BODEGAS_CON_SALDO
    FROM    [dbo].[Repuesto] r
    JOIN    [dbo].[Unidad_Medida] ume ON ume.ume_id = r.rep_unidad_medida
    LEFT JOIN [dbo].[Moneda] mon      ON mon.mon_id = r.rep_moneda
    LEFT JOIN [dbo].[Usuario] uc      ON uc.usu_id = r.rep_usuario_creacion
    LEFT JOIN [dbo].[Usuario] ua      ON ua.usu_id = r.rep_usuario_actualizacion
    WHERE   r.rep_cliente = @CLIENTE
      AND   r.rep_fusionado_en IS NULL      -- un repuesto fusionado ya no se ofrece
      AND   (@ID IS NULL OR r.rep_id = @ID)
      AND   (@HABILITADO IS NULL OR r.rep_habilitado = @HABILITADO)
      AND   (@REPUESTO_TIPO IS NULL OR r.rep_repuesto_tipo = @REPUESTO_TIPO)
      AND   (@FILTRO IS NULL OR r.rep_codigo     LIKE '%' + @FILTRO + '%'
                             OR r.rep_nombre     LIKE '%' + @FILTRO + '%'
                             OR r.rep_fabricante LIKE '%' + @FILTRO + '%'
                             OR r.rep_modelo     LIKE '%' + @FILTRO + '%')
    ORDER BY r.rep_codigo
GO

-- ---------------------------------------------------------------------------
-- 2) El permiso que la pantalla ya pedia
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM [dbo].[Permiso] WHERE prm_codigo = 'REGISTRAR MOVIMIENTOS DE INVENTARIO')
BEGIN
    INSERT INTO [dbo].[Permiso]
        (prm_codigo, prm_nombre, prm_modulo, prm_permiso_ambito, prm_descripcion,
         prm_usuario_creacion, prm_fecha_creacion, prm_habilitado, prm_asignable_usuario)
    VALUES
        ('REGISTRAR MOVIMIENTOS DE INVENTARIO', 'Registrar movimientos de inventario', 'INVENTARIO', 3,
         'Registra entradas, salidas y traspasos de un repuesto desde el centro de repuestos.',
         1, GETDATE(), 1, 0)
END
GO

DECLARE @MOV INT = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = 'REGISTRAR MOVIMIENTOS DE INVENTARIO')

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT v.p, @MOV, 1, GETDATE()
FROM (VALUES (1),(4)) v(p)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso]
                   WHERE ppe_perfil = v.p AND ppe_permiso = @MOV)
GO

-- ---------------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------------
SELECT 'PERFIL ' + CAST(pp.ppe_perfil AS VARCHAR(10)) + ' -> ' + p.prm_codigo AS RESULTADO
FROM [dbo].[Perfil_Permiso] pp
JOIN [dbo].[Permiso] p ON p.prm_id = pp.ppe_permiso
WHERE p.prm_codigo = 'REGISTRAR MOVIMIENTOS DE INVENTARIO'
GO
