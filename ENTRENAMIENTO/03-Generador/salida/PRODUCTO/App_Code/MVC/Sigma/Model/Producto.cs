using System;

namespace Sigma.Model
{
    /// <summary>
    /// MODEL (POCO) de la entidad PRODUCTO.
    ///
    /// REGLAS DEL PATRON (ver PATRON_MVC.md seccion 2):
    ///  1. Namespace Sigma.Model.
    ///  2. Clase [Serializable] porque viaja en ViewState / Session.
    ///  3. SOLO datos. Cero logica, cero acceso a BD, cero validaciones.
    ///  4. Nombre de propiedad = nombre de columna EN MINUSCULAS, con el
    ///     prefijo de 3 letras de la tabla (pro_).
    ///  5. Ademas de las columnas reales se agregan campos "filtro_*" que NO
    ///     existen en la tabla: solo los usa el Controller para armar los
    ///     parametros del Stored Procedure SEL_PRODUCTO.
    ///
    /// ARCHIVO GENERADO por 03-Generador. Si cambia la tabla, regeneralo.
    /// </summary>
    [Serializable]
    public class Producto
    {
        // ------------------------------------------------------------------
        // COLUMNAS REALES DE LA TABLA PRODUCTO
        // ------------------------------------------------------------------

        /// <summary>PK. Columna PRO_ID (IDENTITY).</summary>
        public int pro_id { get; set; }

        /// <summary>Columna PRO_CODIGO.</summary>
        public string pro_codigo { get; set; }

        /// <summary>Columna PRO_NOMBRE.</summary>
        public string pro_nombre { get; set; }

        /// <summary>Columna PRO_DESCRIPCION.</summary>
        public string pro_descripcion { get; set; }

        /// <summary>FK a CATEGORIA. Columna PRO_CATEGORIA.</summary>
        public int pro_categoria { get; set; }

        /// <summary>FK a PROVEEDOR. Columna PRO_PROVEEDOR.</summary>
        public int pro_proveedor { get; set; }

        /// <summary>Columna PRO_PRECIO.</summary>
        public decimal pro_precio { get; set; }

        /// <summary>Columna PRO_STOCK.</summary>
        public int pro_stock { get; set; }

        /// <summary>Columna PRO_VENCIMIENTO.</summary>
        public DateTime? pro_vencimiento { get; set; }

        /// <summary>Columna PRO_HABILITADO. Baja logica: en tablas maestro NO se borra fisico.</summary>
        public bool pro_habilitado { get; set; }

        // ------------------------------------------------------------------
        // COLUMNAS DE AUDITORIA (van en TODAS las tablas del patron)
        // ------------------------------------------------------------------

        public int pro_usuario_creacion { get; set; }
        public DateTime? pro_fecha_creacion { get; set; }
        public int pro_usuario_act { get; set; }
        public DateTime? pro_fecha_act { get; set; }

        // ------------------------------------------------------------------
        // CAMPOS DENORMALIZADOS QUE TRAE EL JOIN DEL SP
        // No son columnas de PRODUCTO: vienen de los JOIN. Sirven para que el
        // grid muestre el nombre en vez del id.
        // ------------------------------------------------------------------

        public string cat_nombre { get; set; }   // CATEGORIA.CAT_NOMBRE
        public string prv_nombre { get; set; }   // PROVEEDOR.PRV_NOMBRE

        // ------------------------------------------------------------------
        // CAMPOS DE FILTRO (NO EXISTEN EN LA TABLA)
        // Solo los lee el Controller para decidir que parametros le manda
        // al SP SEL_PRODUCTO. Son nullable para poder preguntar si vienen informados.
        // ------------------------------------------------------------------

        /// <summary>Texto libre de la barra de busqueda: busca en codigo, nombre.</summary>
        public string filtro { get; set; }

        /// <summary>null = todos, true = solo habilitados, false = solo deshabilitados.</summary>
        public bool? filtro_habilitado { get; set; }

        /// <summary>Filtro por categoria (combo de la barra de filtros).</summary>
        public int? filtro_categoria { get; set; }

        /// <summary>Filtro por proveedor (combo de la barra de filtros).</summary>
        public int? filtro_proveedor { get; set; }
    }
}
