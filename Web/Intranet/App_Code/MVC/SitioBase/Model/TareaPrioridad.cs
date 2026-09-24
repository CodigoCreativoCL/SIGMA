using System;

namespace SitioBase.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad TAREA_PRIORIDAD.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace SitioBase.Model.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla (tpa_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure SEL_TAREA_PRIORIDAD.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class TareaPrioridad
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA TAREA_PRIORIDAD
        // ------------------------------------------------------------------

        /// <summary>PK. Columna TPA_ID (IDENTITY).</summary>
        public int tpa_id { get; set; }

        /// <summary>Columna TPA_CODIGO.</summary>
        public string tpa_codigo { get; set; }

        /// <summary>Columna TPA_NOMBRE.</summary>
        public string tpa_nombre { get; set; }

        /// <summary>Columna TPA_ORDEN.</summary>
        public int tpa_orden { get; set; }

        /// <summary>Columna TPA_HABILITADO. Baja logica: en tablas maestro NO se borra fisico.</summary>
        public bool tpa_habilitado { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_TAREA_PRIORIDAD. Son nullable para poder preguntar si vienen informados.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en codigo, nombre.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }
    }
}
