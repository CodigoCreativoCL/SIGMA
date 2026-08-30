using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Area o subarea dentro de una planta (HU-012).
    ///
    /// NIVEL y RUTA no son columnas de la tabla: los calcula
    /// SEL_INSTALACION_AREA recorriendo el arbol, para que la grilla pueda
    /// indentar sin volver a consultar por cada rama.
    /// </summary>
    [Serializable]
    public class InstalacionArea
    {
        public int iar_id { get; set; }
        public int iar_cliente { get; set; }
        public int iar_cliente_instalacion { get; set; }
        public int? iar_area_padre { get; set; }
        public int? iar_instalacion_area_tipo { get; set; }
        public string iar_codigo { get; set; }
        public string iar_nombre { get; set; }
        public string iar_descripcion { get; set; }
        public int iar_usuario_creacion { get; set; }
        public DateTime? iar_fecha_creacion { get; set; }
        public int iar_usuario_actualizacion { get; set; }
        public DateTime? iar_fecha_actualizacion { get; set; }
        public bool iar_habilitado { get; set; }

        // Columnas que trae el JOIN del SEL_
        public string cin_nombre { get; set; }
        public string padre_nombre { get; set; }
        public string iat_nombre { get; set; }
        public int nivel { get; set; }
        public string ruta { get; set; }

        // Filtros que usa el Controller para armar la llamada
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_solo_raiz { get; set; }

        /// <summary>
        /// El UPD_ distingue "no me toques el padre" de "dejalo sin padre".
        /// Sin esta bandera no hay forma de subir un area al primer nivel,
        /// porque un padre en NULL se interpreta como "sin cambios".
        /// </summary>
        public bool quita_padre { get; set; }
    }
}
