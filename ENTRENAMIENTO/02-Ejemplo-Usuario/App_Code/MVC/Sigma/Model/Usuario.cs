using System;

namespace Sigma.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad USUARIO.
    ///
    /// REGLAS DEL PATRON (ver 00-Patrones-Originales/PATRON_MVC.md, seccion 2):
    ///  1. Namespace <Proyecto>.Model  -> aqui Sigma.Model (en FacilityGes es Facilityges.Model).
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS,
    ///     con el prefijo de 3 letras de la tabla (usu_).
    ///     Tabla USUARIO -> columna USU_NOMBRE -> propiedad usu_nombre.
    ///  5. Ademas de las columnas reales, se agregan campos "filtro_*" que
    ///     NO existen en la tabla: solo los usa el Controller para armar
    ///     los parametros del Stored Procedure SEL_USUARIO.
    ///  6. Los campos que pueden no venir informados se declaran nullable (int?, bool?)
    ///     para poder distinguir "no filtrar" de "filtrar por 0/false".
    /// </summary>
    [Serializable]
    public class Usuario
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA USUARIO
        // ------------------------------------------------------------------

        /// <summary>PK. Columna USU_ID (IDENTITY).</summary>
        public int usu_id { get; set; }

        /// <summary>Columna USU_RUT. Identificador legal del usuario.</summary>
        public string usu_rut { get; set; }

        /// <summary>Columna USU_NOMBRES.</summary>
        public string usu_nombres { get; set; }

        /// <summary>Columna USU_APELLIDOS.</summary>
        public string usu_apellidos { get; set; }

        /// <summary>Columna USU_EMAIL. Se usa como nombre de inicio de sesion.</summary>
        public string usu_email { get; set; }

        /// <summary>Columna USU_TELEFONO.</summary>
        public string usu_telefono { get; set; }

        /// <summary>Columna USU_PASSWORD. Nunca se devuelve en los listados (SEL no la selecciona).</summary>
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
        // CAMPOS "DENORMALIZADOS" QUE TRAE EL JOIN DEL SP
        // No son columnas de USUARIO, vienen del INNER JOIN con PERFIL / PAISES.
        // Sirven para que el grid muestre el nombre en vez del id.
        // ------------------------------------------------------------------

        public string per_nombre { get; set; }
        public string pai_nombre { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_USUARIO. Son nullable / string para poder preguntar
        // "if (filtro != null)" antes de agregar el parametro.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en nombres, apellidos, rut y email.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }

        /// <summary>Filtro por perfil seleccionado en el combo.</summary>
        public int? filtro_perfil { get; set; }

        /// <summary>Filtro por un pais puntual.</summary>
        public int? filtro_pais { get; set; }

        /// <summary>CSV de paises a los que el usuario logueado tiene acceso (seguridad por pais).</summary>
        public string filtro_paises { get; set; }
    }
}
