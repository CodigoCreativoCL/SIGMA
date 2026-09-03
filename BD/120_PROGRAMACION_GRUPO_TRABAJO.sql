/* ============================================================================
   SIGMA — Bloque 120
   EL GRUPO RESPONSABLE ES UN GRUPO DE TRABAJO, NO UN PERFIL
   ----------------------------------------------------------------------------

   EL ERROR QUE SE CORRIGE

     El bloque 118 colgo el responsable-grupo de `Perfiles`. Estaba mal.

     Un PERFIL es un rol de seguridad: dice que puede hacer alguien dentro del
     sistema. Un GRUPO DE TRABAJO es una cuadrilla: un conjunto de personas
     concretas, con lider, con especialidad y con vigencia. Asignarle una
     programacion a "Tecnico de Mantenimiento" es asignarsela a TODOS los que
     tengan ese permiso, incluidos los de otra planta. Asignarsela a la
     cuadrilla de turno es asignarsela a quien de verdad la va a ejecutar.

     `Grupo_Trabajo` ya existia en el modelo, con instalacion y especialidad.
     No habia que inventar nada: habia que mirar mejor.

   SE PUEDE RENOMBRAR SIN RIESGO

     La columna nacio en el bloque 118, en esta misma sesion, y todavia no la
     usa ninguna fila: no hay dato que migrar ni pantalla en produccion que se
     rompa.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* 1. Se sueltan las restricciones que apuntaban a Perfiles. */
IF OBJECT_ID('dbo.FK_PRO_PERFIL') IS NOT NULL
    ALTER TABLE [dbo].[Programacion] DROP CONSTRAINT FK_PRO_PERFIL
GO

IF OBJECT_ID('dbo.CK_PRO_RESPONSABLE_UNICO') IS NOT NULL
    ALTER TABLE [dbo].[Programacion] DROP CONSTRAINT CK_PRO_RESPONSABLE_UNICO
GO

/* 2. El nombre correcto. */
IF COL_LENGTH('dbo.Programacion', 'pro_perfil_responsable') IS NOT NULL
   AND COL_LENGTH('dbo.Programacion', 'pro_grupo_trabajo') IS NULL
BEGIN
    EXEC sp_rename 'dbo.Programacion.pro_perfil_responsable', 'pro_grupo_trabajo', 'COLUMN'
    PRINT '--- Columna renombrada a pro_grupo_trabajo.'
END
ELSE
    PRINT '--- La columna ya estaba correcta.'
GO

/* 3. Las restricciones, ahora contra la tabla que corresponde. */
IF OBJECT_ID('dbo.FK_PRO_GRUPO_TRABAJO') IS NULL
BEGIN
    ALTER TABLE [dbo].[Programacion] WITH CHECK
        ADD CONSTRAINT FK_PRO_GRUPO_TRABAJO FOREIGN KEY (pro_grupo_trabajo)
            REFERENCES [dbo].[Grupo_Trabajo] (gtr_id)

    PRINT '--- FK_PRO_GRUPO_TRABAJO creada.'
END
GO

IF OBJECT_ID('dbo.CK_PRO_RESPONSABLE_UNICO') IS NULL
BEGIN
    /* Persona O cuadrilla. Las dos a la vez es como no asignar a nadie. */
    ALTER TABLE [dbo].[Programacion] WITH NOCHECK
        ADD CONSTRAINT CK_PRO_RESPONSABLE_UNICO CHECK
        (pro_usuario_responsable IS NULL OR pro_grupo_trabajo IS NULL)

    PRINT '--- CK_PRO_RESPONSABLE_UNICO recreado.'
END
GO


/* ========================================================================
   4. EL CATALOGO

      Los grupos son por cliente y ademas por instalacion. Se filtra por
      @PADRE cuando hay instalacion elegida: ofrecerle a alguien la cuadrilla
      de otra planta es ofrecerle gente que no puede ir.
   ======================================================================== */
IF OBJECT_ID('dbo.SEL_PROGRAMACION_CATALOGO_GRUPO') IS NOT NULL
    DROP PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO_GRUPO]
GO

CREATE PROCEDURE [dbo].[SEL_PROGRAMACION_CATALOGO_GRUPO]
    @CLIENTE    INT,
    @PADRE      INT = NULL
AS
SET NOCOUNT ON

    /* El nombre lleva la especialidad y cuanta gente tiene: "Cuadrilla A" no
       dice si son dos personas o doce, y esa es justo la diferencia entre
       poder tomar el trabajo o no. */
    SELECT  ID = g.gtr_id,
            CODIGO = ISNULL(g.gtr_codigo, CAST(g.gtr_id AS NVARCHAR(100))),
            NOMBRE = g.gtr_nombre
                   + ISNULL(N'  ·  ' + e.esp_nombre, N'')
                   + N'  ·  ' + CAST(x.CUANTOS AS NVARCHAR(10))
                   + CASE WHEN x.CUANTOS = 1 THEN N' integrante' ELSE N' integrantes' END,
            ORDEN = 0
    FROM    [dbo].[Grupo_Trabajo] g
    LEFT JOIN [dbo].[Especialidad] e ON e.esp_id = g.gtr_especialidad
    OUTER APPLY (
        SELECT CUANTOS = COUNT(*)
        FROM   [dbo].[Grupo_Trabajo_Usuario] u
        WHERE  u.gtu_grupo_trabajo = g.gtr_id
          AND  (u.gtu_fecha_fin IS NULL OR u.gtu_fecha_fin >= CAST(GETDATE() AS DATE))
    ) x
    WHERE   g.gtr_cliente = @CLIENTE
      AND   g.gtr_habilitado = 1
      /* Sin instalacion elegida se muestran todos; con una elegida, los de
         esa planta y los que no estan amarrados a ninguna. */
      AND   (@PADRE IS NULL
             OR g.gtr_cliente_instalacion IS NULL
             OR g.gtr_cliente_instalacion = @PADRE)
    ORDER BY g.gtr_nombre
GO

PRINT '--- SEL_PROGRAMACION_CATALOGO_GRUPO creado.'
GO

EXEC [dbo].[SEL_PROGRAMACION_CATALOGO_GRUPO] @CLIENTE = 1
GO

PRINT '120_PROGRAMACION_GRUPO_TRABAJO aplicado.'
GO
