using System;

namespace Sigma.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad CLIENTE.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace Sigma.Model.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla (cli_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure SEL_CLIENTE.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class Cliente
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA CLIENTE
        // ------------------------------------------------------------------

        /// <summary>PK. Columna CLI_ID (IDENTITY).</summary>
        public int cli_id { get; set; }

        /// <summary>Columna CLI_NOMBRE.</summary>
        public string cli_nombre { get; set; }

        /// <summary>Columna CLI_HABILITADO. Baja logica: en tablas maestro NO se borra fisico.</summary>
        public bool cli_habilitado { get; set; }

        // ------------------------------------------------------------------
        // COLUMNAS DE AUDITORIA (van en TODAS las tablas del patron)
        // ------------------------------------------------------------------

        public int cli_usuario_creacion { get; set; }
        public DateTime? cli_fecha_creacion { get; set; }
        public int cli_usuario_act { get; set; }
        public DateTime? cli_fecha_act { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_CLIENTE. Son nullable para poder preguntar si vienen informados.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en nombre.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }
    }
}
