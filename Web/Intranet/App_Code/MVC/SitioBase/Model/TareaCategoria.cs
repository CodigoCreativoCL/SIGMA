using System;

namespace SitioBase.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad TAREA_CATEGORIA.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace SitioBase.Model.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla (tca_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure SEL_TAREA_CATEGORIA.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class TareaCategoria
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA TAREA_CATEGORIA
        // ------------------------------------------------------------------

        /// <summary>PK. Columna TCA_ID (IDENTITY).</summary>
        public int tca_id { get; set; }

        /// <summary>Columna TCA_CODIGO.</summary>
        public string tca_codigo { get; set; }

        /// <summary>Columna TCA_NOMBRE.</summary>
        public string tca_nombre { get; set; }

        /// <summary>Columna TCA_COLOR.</summary>
        public string tca_color { get; set; }

        /// <summary>Columna TCA_ORDEN.</summary>
        public int tca_orden { get; set; }

        /// <summary>Columna TCA_HABILITADO. Baja logica: en tablas maestro NO se borra fisico.</summary>
        public bool tca_habilitado { get; set; }

        // ------------------------------------------------------------------
        // COLUMNAS DE AUDITORIA (van en TODAS las tablas del patron)
        // ------------------------------------------------------------------

        public int tca_usuario_creacion { get; set; }
        public DateTime? tca_fecha_creacion { get; set; }
        public int tca_usuario_act { get; set; }
        public DateTime? tca_fecha_act { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_TAREA_CATEGORIA. Son nullable para poder preguntar si vienen informados.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en codigo, nombre, color.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }
    }
}
