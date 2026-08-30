/* ============================================================================
   SIGMA — Bloque 52
   LAS DECISIONES QUE ESTABAN ABIERTAS
   ----------------------------------------------------------------------------

   El MD arrastraba seis puntos sin resolver. Se cierran todos aqui, cada uno
   con el motivo escrito al lado: una decision sin su porque se vuelve a
   discutir dentro de tres meses.

     1. Donde vive "declarar pago" ahora que el cliente no entra a Comercial
     2. Que hace el perfil Soporte
     3. Que ve el Gerente Comercial fuera de lo comercial
     4. Prevencionista: perfil de verdad, o solo un nombre
     5. HU-010: eliminar un cliente es baja fisica o logica
     6. Digito verificador de RUC peruano, CUIT argentino y RUC ecuatoriano
   ============================================================================ */


/* ========================================================================
   1. LA FICHA DE PAGO CAMBIA DE PERMISO

      "Declarar pago" se mudo de Comercial > Pagos a Renovar.aspx, porque el
      bloque 49 le quito a los perfiles de cliente los permisos del modulo
      comercial -que es la vista de TODAS las suscripciones-.

      El boton ya esta en Renovar.aspx, pero abre Pago.aspx, y esa ficha
      pedia VER PAGOS SUSCRIPCION, que el Administrador del Cliente ya no
      tiene: el boton llevaba a una pantalla cerrada.

      Pasa a pedir DECLARAR PAGO SUSCRIPCION, que hoy tienen exactamente los
      tres que necesitan abrirla: Root, Gerente Comercial y Administrador del
      Cliente. Verificar el pago sigue siendo otro permiso distinto
      (VERIFICAR PAGOS SUSCRIPCION), comprobado dentro de la pagina: el
      cliente declara, SIGMA verifica.

      El LISTADO (Pagos.aspx) se queda con VER PAGOS SUSCRIPCION. Es la vista
      de plataforma y no cambia de dueno.
   ======================================================================== */

UPDATE [dbo].[Menus]
SET    mnu_permiso = (SELECT prm_id FROM [dbo].[Permiso] WHERE prm_codigo = N'DECLARAR PAGO SUSCRIPCION')
WHERE  LOWER(mnu_link) = N'~/view/comercial/suscripciones/pago.aspx' COLLATE DATABASE_DEFAULT
GO


/* ========================================================================
   2. SOPORTE MIRA, NO TOCA

      El perfil tenia UN permiso y estaba sin definir desde el principio.

      La regla es una sola frase: **Soporte ve todo y no modifica nada.**
      Quien atiende un problema necesita reproducir lo que el cliente ve -sus
      plantas, sus usuarios, sus permisos, sus pagos- y para eso alcanza con
      leer. Darle ademas los CREAR EDITAR convertiria cada consulta en un
      riesgo: es facil arreglar el dato de alguien "para probar" y dejarlo
      cambiado.

      Por eso se otorga por patron -todo permiso que empieza con VER- y no
      por lista: el dia que nazca una pantalla nueva, Soporte la ve sin que
      nadie tenga que acordarse de agregarla. Lo que NO empieza con VER
      -crear, editar, cerrar, autorizar, verificar, declarar, renovar- queda
      fuera por construccion.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  p.per_id, pr.prm_id, 1, GETDATE()
FROM    [dbo].[Perfiles] p
CROSS JOIN [dbo].[Permiso] pr
WHERE   p.per_nombre COLLATE DATABASE_DEFAULT = N'Soporte'
  AND   pr.prm_codigo LIKE N'VER %'
  AND   pr.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = p.per_id AND pp.ppe_permiso = pr.prm_id)
GO


/* ========================================================================
   3. EL GERENTE COMERCIAL VE LA ORGANIZACION DEL CLIENTE, EN SOLO LECTURA

      Su oficio -planes, suscripciones, periodos, pagos- ya lo tenia del
      bloque 43. Lo que faltaba decidir es que ve del cliente en si.

      Necesita ver la organizacion porque **es lo que determina el plan**: el
      tope de un plan se mide en plantas, usuarios y activos, y negociar una
      renovacion sin poder mirar cuantos hay es negociar a ciegas. El cliente
      pide subir de plan y la primera pregunta es "cuantas plantas tienes".

      Solo lectura, y nada de operacion. Ordenes de trabajo, activos,
      repuestos y permisos de trabajo no son suyos: no aporta nada al
      trabajo comercial y expone la operacion del cliente a alguien que no
      participa de ella.
   ======================================================================== */

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  p.per_id, pr.prm_id, 1, GETDATE()
FROM    [dbo].[Perfiles] p
CROSS JOIN [dbo].[Permiso] pr
WHERE   p.per_nombre COLLATE DATABASE_DEFAULT = N'Gerente Comercial'
  AND   pr.prm_codigo COLLATE DATABASE_DEFAULT IN
        (N'VER PLANTAS', N'VER AREAS', N'VER CENTROS COSTO',
         N'VER GRUPOS TRABAJO', N'VER ESPECIALIDADES USUARIO',
         N'VER CLIENTE IDENTIDAD', N'VER CLIENTE USUARIOS')
  AND   pr.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = p.per_id AND pp.ppe_permiso = pr.prm_id)
GO


/* ========================================================================
   4. PREVENCIONISTA ES UN PERFIL DE VERDAD

      La duda era si merecia perfil propio o si bastaba con transcribir el
      nombre en algun campo.

      Merece perfil, y el argumento es concreto: **existe el permiso
      AUTORIZAR PERMISO TRABAJO**. Si el prevencionista fuera solo un nombre,
      no podria autorizar nada, y el permiso de trabajo -que es justamente lo
      que su rol firma- tendria que autorizarlo un jefe de mantenimiento
      haciendose pasar por el. Un rol que no puede ejecutar su unica funcion
      distintiva no es un rol: es una etiqueta.

      Que ve: la organizacion en solo lectura -necesita saber en que planta y
      area esta el trabajo que autoriza- y los catalogos. Que NO hace: no
      cierra ordenes de trabajo, no crea activos, no toca repuestos. Su
      trabajo es decir si se puede trabajar, no hacer el trabajo.
   ======================================================================== */

/* per_usuario_act y per_fecha_act son NOT NULL en esta tabla, aunque el
   nombre diga "actualizacion": al nacer se sellan con la creacion. */
INSERT INTO [dbo].[Perfiles] (per_nombre, per_descripcion, per_tipo, per_habilitado,
                              per_usuario_creacion, per_fecha_creacion,
                              per_usuario_act, per_fecha_act, per_solo_ejecucion)
SELECT  N'Prevencionista de Riesgos',
        N'Autoriza permisos de trabajo. Ve la organizacion en solo lectura; no ejecuta ni cierra trabajo.',
        2, 1, 1, GETDATE(), 1, GETDATE(), 0
WHERE   NOT EXISTS (SELECT 1 FROM [dbo].[Perfiles]
                    WHERE per_nombre COLLATE DATABASE_DEFAULT = N'Prevencionista de Riesgos')
GO

INSERT INTO [dbo].[Perfil_Permiso] (ppe_perfil, ppe_permiso, ppe_usuario_creacion, ppe_fecha_creacion)
SELECT  p.per_id, pr.prm_id, 1, GETDATE()
FROM    [dbo].[Perfiles] p
CROSS JOIN [dbo].[Permiso] pr
WHERE   p.per_nombre COLLATE DATABASE_DEFAULT = N'Prevencionista de Riesgos'
  AND   pr.prm_codigo COLLATE DATABASE_DEFAULT IN
        (N'AUTORIZAR PERMISO TRABAJO',
         N'VER PLANTAS', N'VER AREAS', N'VER GRUPOS TRABAJO',
         N'VER ESPECIALIDADES USUARIO', N'VER CATALOGOS')
  AND   pr.prm_habilitado = 1
  AND   NOT EXISTS (SELECT 1 FROM [dbo].[Perfil_Permiso] pp
                    WHERE pp.ppe_perfil = p.per_id AND pp.ppe_permiso = pr.prm_id)
GO


/* ========================================================================
   5. HU-010: ELIMINAR UN CLIENTE ES BAJA LOGICA

      DEL_CLIENTE borraba de verdad: la fila de Cliente, sus afiliaciones y
      los perfiles de esas afiliaciones.

      No corresponde, por dos motivos.

      El primero es contable. Un cliente tiene suscripciones, periodos
      emitidos y pagos verificados. Eso es documentacion comercial que hay
      que conservar, y borrar el cliente deja periodos y pagos apuntando a
      una empresa que ya no existe: el historial de facturacion queda
      ilegible justo cuando alguien lo necesita.

      El segundo es que ya se comportaba a medias como baja logica: el SP se
      negaba a borrar si el cliente tenia plantas. O sea que el unico cliente
      que se podia borrar era el que no tenia nada, y para ese la diferencia
      entre borrar y deshabilitar es ninguna.

      Ahora deshabilita: el cliente deja de aparecer en el selector y sus
      usuarios no entran -SEL_LOGIN exige una afiliacion a cliente
      habilitado-, pero no se pierde un solo registro. Volver a habilitarlo
      es un UPDATE.

      Se conserva el guard de plantas. Con una baja logica ya no es
      estrictamente necesario, pero sigue siendo la conversacion correcta:
      dar de baja una empresa con plantas activas casi siempre es un error de
      quien aprieta el boton, y conviene que tenga que desarmarla primero.
   ======================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[DEL_CLIENTE]
 @ID      INT
,@USUARIO INT
AS
SET NOCOUNT ON

    IF (EXISTS(SELECT TOP 1 1 FROM [dbo].[Cliente_Instalacion] WHERE CIN_CLIENTE = @ID))
    BEGIN
        RAISERROR('1. No es posible dar de baja, el cliente posee plantas', 16, 1);
        RETURN -1;
    END

    BEGIN TRANSACTION

        /* Baja LOGICA. No se borra ni el cliente ni sus afiliaciones: se
           apagan. Los periodos y pagos siguen apuntando a una empresa que
           existe, y el dia que vuelva no hay que rearmarle los usuarios. */
        UPDATE  [dbo].[Cliente]
        SET     cli_habilitado            = 0,
                cli_usuario_actualizacion = @USUARIO,
                cli_fecha_actualizacion   = GETDATE()
        WHERE   cli_id = @ID
          AND   ISNULL(cli_habilitado, 0) = 1

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION
            DECLARE @VARIABLES VARCHAR(MAX) = 'DEL_CLIENTE ' + LTRIM(STR(@ID))
            EXEC [dbo].[INS_EXCEPCION]
                 @MSG       = '1.- El cliente no existe o ya estaba deshabilitado.',
                 @VARIABLES = @VARIABLES
            RETURN -1
        END

        /* Las afiliaciones se apagan tambien: sin esto la gente del cliente
           seguiria entrando, porque su fila en Cliente_Usuario sigue viva.
           SEL_LOGIN exige cliente habilitado, asi que con el UPDATE de
           arriba ya no entrarian; esto lo deja consistente ademas para las
           consultas que miran la afiliacion sin mirar al cliente. */
        UPDATE  [dbo].[Cliente_Usuario]
        SET     ucl_habilitado = 0
        WHERE   ucl_id_cliente = @ID

    COMMIT TRANSACTION

RETURN(0)
GO


/* ========================================================================
   6. DIGITO VERIFICADOR: PERU, ARGENTINA Y ECUADOR

      Hasta ahora esos tres paises validaban largo y que fueran digitos, y
      nada mas: cualquier numero del largo correcto pasaba.

      Los tres algoritmos se verificaron contra fuentes publicas antes de
      escribirlos, no se sacaron de memoria. Cada funcion lleva su ejemplo
      comprobable en el comentario.

      Van como funciones separadas y se enchufan al despachador por el valor
      de Paises.pai_identificador_validacion, igual que el RUT chileno: que
      regla toca es un dato, como se aplica es una funcion.
   ======================================================================== */


/* ---- PERU: RUC de 11 digitos ------------------------------------------
   Pesos 5,4,3,2,7,6,5,4,3,2 sobre los 10 primeros. DV = 11 - (suma mod 11),
   y si da 10 el digito es 0, si da 11 es 1.

   Comprobacion: el RUC de la propia SUNAT, 20131312955. La suma ponderada
   da 94; 94 mod 11 = 6; 11 - 6 = 5, que es el ultimo digito.
   ---------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION [dbo].[FNC_RUC_VALIDO_PE] (@RUC VARCHAR(100))
RETURNS BIT
AS
BEGIN
    DECLARE @N VARCHAR(20) = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@RUC, ''))), '.', ''), '-', ''), ' ', '')

    IF LEN(@N) <> 11 OR @N LIKE '%[^0-9]%' RETURN 0

    DECLARE @PESOS VARCHAR(10) = '5432765432'
    DECLARE @I INT = 1, @SUMA INT = 0

    WHILE @I <= 10
    BEGIN
        SET @SUMA = @SUMA + CAST(SUBSTRING(@N, @I, 1) AS INT) * CAST(SUBSTRING(@PESOS, @I, 1) AS INT)
        SET @I = @I + 1
    END

    DECLARE @DV INT = 11 - (@SUMA % 11)

    IF @DV = 10 SET @DV = 0
    IF @DV = 11 SET @DV = 1

    RETURN CASE WHEN @DV = CAST(SUBSTRING(@N, 11, 1) AS INT) THEN 1 ELSE 0 END
END
GO


/* ---- ARGENTINA: CUIT de 11 digitos ------------------------------------
   Mismos pesos que Peru, DISTINTO cierre: si da 11 el digito es 0, y si da
   10 el CUIT es invalido -no existe un digito 10, y el caso se resuelve
   cambiando el prefijo, no el verificador-.

   Los dos primeros digitos son el tipo: 20/23/24/27 personas fisicas,
   30/33/34 personas juridicas. Se validan porque un CUIT que empieza con
   otra cosa no es un CUIT aunque el modulo 11 cuadre.
   ---------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION [dbo].[FNC_CUIT_VALIDO_AR] (@CUIT VARCHAR(100))
RETURNS BIT
AS
BEGIN
    DECLARE @N VARCHAR(20) = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@CUIT, ''))), '.', ''), '-', ''), ' ', '')

    IF LEN(@N) <> 11 OR @N LIKE '%[^0-9]%' RETURN 0

    IF SUBSTRING(@N, 1, 2) NOT IN ('20', '23', '24', '27', '30', '33', '34') RETURN 0

    DECLARE @PESOS VARCHAR(10) = '5432765432'
    DECLARE @I INT = 1, @SUMA INT = 0

    WHILE @I <= 10
    BEGIN
        SET @SUMA = @SUMA + CAST(SUBSTRING(@N, @I, 1) AS INT) * CAST(SUBSTRING(@PESOS, @I, 1) AS INT)
        SET @I = @I + 1
    END

    DECLARE @DV INT = 11 - (@SUMA % 11)

    IF @DV = 11 SET @DV = 0
    IF @DV = 10 RETURN 0

    RETURN CASE WHEN @DV = CAST(SUBSTRING(@N, 11, 1) AS INT) THEN 1 ELSE 0 END
END
GO


/* ---- ECUADOR: RUC de 13 digitos ---------------------------------------
   Es el mas enredado de los tres porque no hay UN algoritmo sino tres, y
   cual toca lo dice el TERCER digito:

     0-5  persona natural   -> algoritmo de cedula, modulo 10, DV en la 10
     6    entidad publica   -> modulo 11, pesos 3,2,7,6,5,4,3,2, DV en la 9
     9    sociedad privada  -> modulo 11, pesos 4,3,2,7,6,5,4,3,2, DV en la 10

   Los dos primeros digitos son la provincia: 01 a 24, mas 30 para
   extranjeros sin cedula. Los ultimos digitos son el establecimiento y no
   entran en el calculo.
   ---------------------------------------------------------------------- */
CREATE OR ALTER FUNCTION [dbo].[FNC_RUC_VALIDO_EC] (@RUC VARCHAR(100))
RETURNS BIT
AS
BEGIN
    DECLARE @N VARCHAR(20) = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@RUC, ''))), '.', ''), '-', ''), ' ', '')

    IF LEN(@N) <> 13 OR @N LIKE '%[^0-9]%' RETURN 0

    DECLARE @PROV INT = CAST(SUBSTRING(@N, 1, 2) AS INT)
    IF NOT ((@PROV BETWEEN 1 AND 24) OR @PROV = 30) RETURN 0

    DECLARE @TIPO INT = CAST(SUBSTRING(@N, 3, 1) AS INT)
    DECLARE @I INT = 1, @SUMA INT = 0, @P INT, @D INT, @DV INT, @RESTO INT

    /* --- Persona natural: el mismo modulo 10 de la cedula --- */
    IF @TIPO BETWEEN 0 AND 5
    BEGIN
        WHILE @I <= 9
        BEGIN
            SET @D = CAST(SUBSTRING(@N, @I, 1) AS INT)
            SET @P = CASE WHEN @I % 2 = 1 THEN @D * 2 ELSE @D END
            IF @P > 9 SET @P = @P - 9
            SET @SUMA = @SUMA + @P
            SET @I = @I + 1
        END

        SET @DV = (10 - (@SUMA % 10)) % 10

        RETURN CASE WHEN @DV = CAST(SUBSTRING(@N, 10, 1) AS INT) THEN 1 ELSE 0 END
    END

    /* --- Entidad publica: DV en la posicion 9 --- */
    IF @TIPO = 6
    BEGIN
        DECLARE @PUB VARCHAR(8) = '32765432'

        WHILE @I <= 8
        BEGIN
            SET @SUMA = @SUMA + CAST(SUBSTRING(@N, @I, 1) AS INT) * CAST(SUBSTRING(@PUB, @I, 1) AS INT)
            SET @I = @I + 1
        END

        SET @RESTO = @SUMA % 11
        SET @DV = CASE WHEN @RESTO = 0 THEN 0 ELSE 11 - @RESTO END

        RETURN CASE WHEN @DV = CAST(SUBSTRING(@N, 9, 1) AS INT) THEN 1 ELSE 0 END
    END

    /* --- Sociedad privada: DV en la posicion 10 --- */
    IF @TIPO = 9
    BEGIN
        DECLARE @PRI VARCHAR(9) = '432765432'

        WHILE @I <= 9
        BEGIN
            SET @SUMA = @SUMA + CAST(SUBSTRING(@N, @I, 1) AS INT) * CAST(SUBSTRING(@PRI, @I, 1) AS INT)
            SET @I = @I + 1
        END

        SET @RESTO = @SUMA % 11
        SET @DV = CASE WHEN @RESTO = 0 THEN 0 ELSE 11 - @RESTO END

        RETURN CASE WHEN @DV = CAST(SUBSTRING(@N, 10, 1) AS INT) THEN 1 ELSE 0 END
    END

    -- Tercer digito 7 u 8: no corresponde a ningun tipo de contribuyente.
    RETURN 0
END
GO


/* ---- El despachador aprende los tres codigos nuevos ------------------- */

CREATE OR ALTER FUNCTION [dbo].[FNC_IDENTIFICADOR_VALIDO]
(
    @PAIS          INT,
    @IDENTIFICADOR VARCHAR(100)
)
RETURNS BIT
AS
BEGIN
    IF @IDENTIFICADOR IS NULL OR LTRIM(RTRIM(@IDENTIFICADOR)) = '' RETURN 0

    DECLARE @VALIDACION NVARCHAR(30)
    DECLARE @LARGO      INT
    DECLARE @LIMPIO     VARCHAR(100)

    SELECT @VALIDACION = pai_identificador_validacion,
           @LARGO      = pai_identificador_largo
      FROM [dbo].[Paises]
     WHERE pai_id = @PAIS

    -- Pais no informado o sin configurar: no se bloquea el alta.
    IF @VALIDACION IS NULL RETURN 1

    IF @VALIDACION = N'MODULO11_CL' RETURN [dbo].[FNC_RUT_VALIDO](@IDENTIFICADOR)
    IF @VALIDACION = N'MODULO11_PE' RETURN [dbo].[FNC_RUC_VALIDO_PE](@IDENTIFICADOR)
    IF @VALIDACION = N'MODULO11_AR' RETURN [dbo].[FNC_CUIT_VALIDO_AR](@IDENTIFICADOR)
    IF @VALIDACION = N'MODULO11_EC' RETURN [dbo].[FNC_RUC_VALIDO_EC](@IDENTIFICADOR)

    IF @VALIDACION = N'SOLO_DIGITOS'
    BEGIN
        SET @LIMPIO = REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@IDENTIFICADOR)), '.', ''), '-', ''), ' ', '')

        IF @LIMPIO LIKE '%[^0-9]%' RETURN 0
        IF @LARGO IS NOT NULL AND LEN(@LIMPIO) <> @LARGO RETURN 0

        RETURN 1
    END

    -- NINGUNO: basta con que venga algo.
    RETURN 1
END
GO


UPDATE [dbo].[Paises] SET pai_identificador_validacion = N'MODULO11_PE' WHERE pai_nombre = N'Perú'      COLLATE DATABASE_DEFAULT
UPDATE [dbo].[Paises] SET pai_identificador_validacion = N'MODULO11_AR' WHERE pai_nombre = N'Argentina' COLLATE DATABASE_DEFAULT
UPDATE [dbo].[Paises] SET pai_identificador_validacion = N'MODULO11_EC' WHERE pai_nombre = N'Ecuador'   COLLATE DATABASE_DEFAULT
GO


/* ========================================================================
   VERIFICACION
   ======================================================================== */

SELECT  'Pago.aspx pide DECLARAR PAGO' AS OBJETO,
        (SELECT COUNT(*) FROM [dbo].[Menus] m JOIN [dbo].[Permiso] p ON p.prm_id = m.mnu_permiso
          WHERE LOWER(m.mnu_link) = N'~/view/comercial/suscripciones/pago.aspx' COLLATE DATABASE_DEFAULT
            AND p.prm_codigo = N'DECLARAR PAGO SUSCRIPCION') AS HAY, 1 AS ESPERADO
UNION ALL
SELECT  'Soporte: permisos de solo lectura',
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp
           JOIN [dbo].[Perfiles] pe ON pe.per_id = pp.ppe_perfil
           JOIN [dbo].[Permiso]  pr ON pr.prm_id = pp.ppe_permiso
          WHERE pe.per_nombre COLLATE DATABASE_DEFAULT = N'Soporte'
            AND pr.prm_codigo LIKE N'VER %'),
        (SELECT COUNT(*) FROM [dbo].[Permiso] WHERE prm_codigo LIKE N'VER %' AND prm_habilitado = 1)
UNION ALL
SELECT  'Soporte: permisos que NO son de lectura',
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp
           JOIN [dbo].[Perfiles] pe ON pe.per_id = pp.ppe_perfil
           JOIN [dbo].[Permiso]  pr ON pr.prm_id = pp.ppe_permiso
          WHERE pe.per_nombre COLLATE DATABASE_DEFAULT = N'Soporte'
            AND pr.prm_codigo NOT LIKE N'VER %'), 0
UNION ALL
SELECT  'Gerente Comercial ve la organizacion',
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp
           JOIN [dbo].[Perfiles] pe ON pe.per_id = pp.ppe_perfil
           JOIN [dbo].[Permiso]  pr ON pr.prm_id = pp.ppe_permiso
          WHERE pe.per_nombre COLLATE DATABASE_DEFAULT = N'Gerente Comercial'
            AND pr.prm_modulo COLLATE DATABASE_DEFAULT = N'ORGANIZACION'), 5
UNION ALL
SELECT  'Prevencionista creado',
        (SELECT COUNT(*) FROM [dbo].[Perfiles]
          WHERE per_nombre COLLATE DATABASE_DEFAULT = N'Prevencionista de Riesgos'), 1
UNION ALL
SELECT  'Prevencionista autoriza permisos de trabajo',
        (SELECT COUNT(*) FROM [dbo].[Perfil_Permiso] pp
           JOIN [dbo].[Perfiles] pe ON pe.per_id = pp.ppe_perfil
           JOIN [dbo].[Permiso]  pr ON pr.prm_id = pp.ppe_permiso
          WHERE pe.per_nombre COLLATE DATABASE_DEFAULT = N'Prevencionista de Riesgos'
            AND pr.prm_codigo = N'AUTORIZAR PERMISO TRABAJO'), 1
UNION ALL
SELECT  'DEL_CLIENTE es baja logica',
        (SELECT COUNT(*) FROM sys.sql_modules
          WHERE object_id = OBJECT_ID('DEL_CLIENTE')
            AND definition LIKE '%cli_habilitado            = 0%'), 1
UNION ALL
SELECT  'funciones de DV nuevas',
        (SELECT COUNT(*) FROM sys.objects
          WHERE name IN ('FNC_RUC_VALIDO_PE','FNC_CUIT_VALIDO_AR','FNC_RUC_VALIDO_EC')), 3
UNION ALL
SELECT  'paises con validacion de DV',
        (SELECT COUNT(*) FROM [dbo].[Paises] WHERE pai_identificador_validacion LIKE N'MODULO11%'), 4
GO


/* ---- Los algoritmos, contra casos conocidos --------------------------- */

SELECT  CASO = 'PE 20131312955 (SUNAT)',           ESPERADO = 1, OBTENIDO = [dbo].[FNC_RUC_VALIDO_PE]('20131312955')
UNION ALL SELECT 'PE 20131312954 (DV cambiado)',   0, [dbo].[FNC_RUC_VALIDO_PE]('20131312954')
UNION ALL SELECT 'PE largo incorrecto',            0, [dbo].[FNC_RUC_VALIDO_PE]('2013131295')
/* AR 33-69345023-9 es el CUIT de AFIP. Comprobado a mano: la suma
   ponderada da 145, 145 mod 11 = 2, y 11 - 2 = 9. */
UNION ALL SELECT 'AR 33-69345023-9 (AFIP)',        1, [dbo].[FNC_CUIT_VALIDO_AR]('33-69345023-9')
UNION ALL SELECT 'AR 33-69345023-1 (DV cambiado)', 0, [dbo].[FNC_CUIT_VALIDO_AR]('33-69345023-1')
UNION ALL SELECT 'AR prefijo invalido 99...',      0, [dbo].[FNC_CUIT_VALIDO_AR]('99693450239')
/* EC 1760013210001 es el RUC del SRI: tercer digito 6, entidad publica.
   Suma ponderada 76, 76 mod 11 = 10, 11 - 10 = 1, y la posicion 9 es 1. */
UNION ALL SELECT 'EC 1760013210001 (SRI, publica)',1, [dbo].[FNC_RUC_VALIDO_EC]('1760013210001')
/* Privada calculada: base 179131019, suma 94, 94 mod 11 = 6, DV = 5. */
UNION ALL SELECT 'EC 1791310195001 (privada)',     1, [dbo].[FNC_RUC_VALIDO_EC]('1791310195001')
UNION ALL SELECT 'EC 1791310194001 DV cambiado',   0, [dbo].[FNC_RUC_VALIDO_EC]('1791310194001')
/* Natural: cedula 1710034065, modulo 10, DV 5. */
UNION ALL SELECT 'EC 1710034065001 (natural)',     1, [dbo].[FNC_RUC_VALIDO_EC]('1710034065001')
UNION ALL SELECT 'EC provincia 99 invalida',       0, [dbo].[FNC_RUC_VALIDO_EC]('9960013210001')
UNION ALL SELECT 'EC tercer digito 7 (no existe)', 0, [dbo].[FNC_RUC_VALIDO_EC]('1770013210001')
GO
