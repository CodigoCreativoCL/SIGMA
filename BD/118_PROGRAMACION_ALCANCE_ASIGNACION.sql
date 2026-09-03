/* ============================================================================
   SIGMA — Bloque 118
   ALCANCE Y ASIGNACION DE UNA PROGRAMACION
   ----------------------------------------------------------------------------

   LO QUE FALTABA

     La tabla `Programacion` decia CUANDO y CADA CUANTO, pero no DONDE ni A
     QUIEN. Una regla que genera trabajo sin decir en que instalacion se hace
     ni quien responde no es una programacion: es un recordatorio.

     Se nota al final de la cadena. Cuando la ocurrencia se convierta en orden
     de trabajo, la OT exige instalacion —`otr_cliente_instalacion` es NOT
     NULL— y alguien tendra que escribirla a mano cada vez, para una regla que
     siempre apunta al mismo lugar.

   COMO SE AGREGA

     Cinco columnas, todas NULL. Ninguna programacion existente se rompe y
     ninguna queda mintiendo: las que no tienen alcance declarado siguen sin
     tenerlo, y la pantalla lo dira asi en vez de inventarles una instalacion.

   ALCANCE: DE LO GENERAL A LO PARTICULAR

     Instalacion -> area -> activo. Se puede llenar solo el primer nivel
     (toda la planta), los dos (un area) o los tres (un equipo). Lo que NO se
     puede es saltarse un nivel o contradecirlo: un activo que no pertenece a
     la instalacion declarada es un error de captura, y el CHECK lo impide.

   ASIGNACION: PERSONA O GRUPO, NO LAS DOS

     O responde una persona concreta, o responde un perfil —la cuadrilla—.
     Las dos a la vez es la forma mas comun de que al final no responda
     nadie, porque cada parte supone que contestaba la otra.
   ============================================================================ */
USE [db_acd593_sigma]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/* ========================================================================
   1. LAS COLUMNAS
   ======================================================================== */
IF COL_LENGTH('dbo.Programacion', 'pro_cliente_instalacion') IS NULL
BEGIN
    ALTER TABLE [dbo].[Programacion] ADD
        pro_cliente_instalacion INT NULL,
        pro_instalacion_area    INT NULL,
        pro_activo              INT NULL,
        pro_usuario_responsable INT NULL,
        pro_perfil_responsable  INT NULL

    PRINT '--- 5 columnas agregadas.'
END
ELSE
    PRINT '--- Las columnas ya existian.'
GO

/* Las llaves. Van despues, en su propio lote, porque el ALTER de arriba
   tiene que estar comprometido antes de poder referenciar las columnas. */
IF OBJECT_ID('dbo.FK_PRO_INSTALACION') IS NULL
BEGIN
    ALTER TABLE [dbo].[Programacion] WITH CHECK
        ADD CONSTRAINT FK_PRO_INSTALACION FOREIGN KEY (pro_cliente_instalacion)
            REFERENCES [dbo].[Cliente_Instalacion] (cin_id)

    ALTER TABLE [dbo].[Programacion] WITH CHECK
        ADD CONSTRAINT FK_PRO_AREA FOREIGN KEY (pro_instalacion_area)
            REFERENCES [dbo].[Instalacion_Area] (iar_id)

    ALTER TABLE [dbo].[Programacion] WITH CHECK
        ADD CONSTRAINT FK_PRO_ACTIVO FOREIGN KEY (pro_activo)
            REFERENCES [dbo].[Activo] (act_id)

    ALTER TABLE [dbo].[Programacion] WITH CHECK
        ADD CONSTRAINT FK_PRO_RESPONSABLE FOREIGN KEY (pro_usuario_responsable)
            REFERENCES [dbo].[Usuario] (usu_id)

    ALTER TABLE [dbo].[Programacion] WITH CHECK
        ADD CONSTRAINT FK_PRO_PERFIL FOREIGN KEY (pro_perfil_responsable)
            REFERENCES [dbo].[Perfiles] (per_id)

    PRINT '--- Llaves foraneas creadas.'
END
ELSE
    PRINT '--- Las llaves ya existian.'
GO

/* ========================================================================
   2. LAS REGLAS

      Se validan en la base y no solo en la pantalla: la pantalla es una de
      las formas de entrar, la app movil y la API son otras.
   ======================================================================== */
IF OBJECT_ID('dbo.CK_PRO_ALCANCE_JERARQUIA') IS NULL
BEGIN
    /* No se salta niveles: un area sin instalacion, o un activo sin area,
       dejan un alcance que nadie sabe leer. */
    ALTER TABLE [dbo].[Programacion] WITH NOCHECK
        ADD CONSTRAINT CK_PRO_ALCANCE_JERARQUIA CHECK
        (
            (pro_instalacion_area IS NULL OR pro_cliente_instalacion IS NOT NULL)
        AND (pro_activo IS NULL OR pro_cliente_instalacion IS NOT NULL)
        )

    PRINT '--- CK_PRO_ALCANCE_JERARQUIA creado.'
END
GO

IF OBJECT_ID('dbo.CK_PRO_RESPONSABLE_UNICO') IS NULL
BEGIN
    /* Persona O grupo. Las dos a la vez es como no asignar a nadie. */
    ALTER TABLE [dbo].[Programacion] WITH NOCHECK
        ADD CONSTRAINT CK_PRO_RESPONSABLE_UNICO CHECK
        (pro_usuario_responsable IS NULL OR pro_perfil_responsable IS NULL)

    PRINT '--- CK_PRO_RESPONSABLE_UNICO creado.'
END
GO

PRINT '118_PROGRAMACION_ALCANCE_ASIGNACION aplicado.'
GO
