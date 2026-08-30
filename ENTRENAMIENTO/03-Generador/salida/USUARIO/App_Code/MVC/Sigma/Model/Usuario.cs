using System;

namespace Sigma.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad USUARIO.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace Sigma.Model.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla (usu_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure SEL_USUARIO.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class Usuario
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA USUARIO
        // ------------------------------------------------------------------

        /// <summary>PK. Columna USU_ID (IDENTITY).</summary>
        public int usu_id { get; set; }

        /// <summary>Columna USU_RUT.</summary>
        public string usu_rut { get; set; }

        /// <summary>Columna USU_NOMBRES.</summary>
        public string usu_nombres { get; set; }

        /// <summary>Columna USU_APELLIDOS.</summary>
        public string usu_apellidos { get; set; }

        /// <summary>Columna USU_EMAIL.</summary>
        public string usu_email { get; set; }

        /// <summary>Columna USU_TELEFONO.</summary>
        public string usu_telefono { get; set; }

        /// <summary>Columna USU_PASSWORD. Nunca se devuelve en los listados.</summary>
        public string usu_password { get; set; }

        /// <summary>FK a PERFIL. Columna USU_PERFIL.</summary>
        public int usu_perfil { get; set; }

        /// <summary>FK a PAISES. Columna USU_PAIS.</summary>
        public int usu_pais { get; set; }

        /// <summary>Columna USU_HABILITADO. Baja logica: en tablas maestro NO se borra fisico.</summary>
        public bool usu_habilitado { get; set; }

        // ------------------------------------------------------------------
        // COLUMNAS DE AUDITORIA (van en TODAS las tablas del patron)
        // ------------------------------------------------------------------

        public int usu_usuario_creacion { get; set; }
        public DateTime? usu_fecha_creacion { get; set; }
        public int usu_usuario_act { get; set; }
        public DateTime? usu_fecha_act { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DENORMALIZADOS QUE TRAE EL JOIN DEL SP
        // No son columnas de USUARIO: vienen de los JOIN. Sirven para que el
        // grid muestre el nombre en vez del id.
        // ------------------------------------------------------------------

        public string per_nombre { get; set; }   // PERFIL.PER_NOMBRE
        public string pai_nombre { get; set; }   // PAISES.PAI_NOMBRE

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_USUARIO. Son nullable para poder preguntar si vienen informados.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en rut, nombres, apellidos, email.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }

        /// <summary>Filtro por perfil (combo de la barra de filtros).</summary>
        public int? filtro_perfil { get; set; }

        /// <summary>CSV de paises a los que el usuario logueado tiene acceso.</summary>
        public string filtro_paises { get; set; }
    }
}
