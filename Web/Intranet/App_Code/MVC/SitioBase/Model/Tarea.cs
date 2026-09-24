using System;

namespace SitioBase.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad TAREA.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace SitioBase.Model.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla (tar_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure SEL_TAREA.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class Tarea
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA TAREA
        // ------------------------------------------------------------------

        /// <summary>PK. Columna TAR_ID (IDENTITY).</summary>
        public int tar_id { get; set; }

        /// <summary>Columna TAR_CODIGO.</summary>
        public string tar_codigo { get; set; }

        /// <summary>Columna TAR_TITULO.</summary>
        public string tar_titulo { get; set; }

        /// <summary>Columna TAR_DESCRIPCION.</summary>
        public string tar_descripcion { get; set; }

        /// <summary>FK a TAREA_PRIORIDAD. Columna TAR_TAREA_PRIORIDAD.</summary>
        public int tar_tarea_prioridad { get; set; }

        /// <summary>FK a TAREA_CATEGORIA. Columna TAR_TAREA_CATEGORIA.</summary>
        public int tar_tarea_categoria { get; set; }

        /// <summary>FK a CLIENTE_INSTALACION. Columna TAR_CLIENTE_INSTALACION.</summary>
        public int tar_cliente_instalacion { get; set; }

        /// <summary>FK a INSTALACION_AREA. Columna TAR_INSTALACION_AREA.</summary>
        public int tar_instalacion_area { get; set; }

        /// <summary>FK a ACTIVO. Columna TAR_ACTIVO.</summary>
        public int tar_activo { get; set; }

        /// <summary>Columna TAR_DURACION_ESTIMADA_MINUTO.</summary>
        public int tar_duracion_estimada_minuto { get; set; }

        /// <summary>Columna TAR_REQUIERE_EVIDENCIA.</summary>
        public bool tar_requiere_evidencia { get; set; }

        /// <summary>Columna TAR_HABILITADO. Baja logica: en tablas maestro NO se borra fisico.</summary>
        public bool tar_habilitado { get; set; }

        // ------------------------------------------------------------------
        // COLUMNAS DE AUDITORIA (van en TODAS las tablas del patron)
        // ------------------------------------------------------------------

        public int tar_usuario_creacion { get; set; }
        public DateTime? tar_fecha_creacion { get; set; }
        public int tar_usuario_act { get; set; }
        public DateTime? tar_fecha_act { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DENORMALIZADOS QUE TRAE EL JOIN DEL SP
        // No son columnas de TAREA: vienen de los JOIN. Sirven para que el
        // grid muestre el nombre en vez del id.
        // ------------------------------------------------------------------

        public string tpa_nombre { get; set; }   // TAREA_PRIORIDAD.TPA_NOMBRE
        public string tca_nombre { get; set; }   // TAREA_CATEGORIA.TCA_NOMBRE
        public string cin_nombre { get; set; }   // CLIENTE_INSTALACION.CIN_NOMBRE
        public string iar_nombre { get; set; }   // INSTALACION_AREA.IAR_NOMBRE
        public string act_nombre { get; set; }   // ACTIVO.ACT_NOMBRE

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_TAREA. Son nullable para poder preguntar si vienen informados.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en codigo, titulo.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }

        /// <summary>Filtro por prioridad (combo de la barra de filtros).</summary>
        public int? filtro_tarea_prioridad { get; set; }

        /// <summary>Filtro por categoria (combo de la barra de filtros).</summary>
        public int? filtro_tarea_categoria { get; set; }

        /// <summary>Filtro por planta (combo de la barra de filtros).</summary>
        public int? filtro_cliente_instalacion { get; set; }

        /// <summary>Filtro por area (combo de la barra de filtros).</summary>
        public int? filtro_instalacion_area { get; set; }

        /// <summary>Filtro por equipo (combo de la barra de filtros).</summary>
        public int? filtro_activo { get; set; }
    }
}
