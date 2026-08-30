using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un archivo del cliente. La fila son los METADATOS: el binario vive
    /// en el Blob Storage y acá solo queda la ruta.
    ///
    /// arc_ruta es la ruta del blob (contenedor/carpeta/nombre), no una URL
    /// firmada. Una URL con token caduca y quedaría inservible guardada;
    /// la ruta relativa sobrevive a que cambie la cuenta de almacenamiento
    /// o el dominio.
    ///
    /// contenido son los bytes recién subidos o recién descargados. Es de
    /// paso: no se guarda en la base ni se conserva en el modelo más allá
    /// de la operación que lo necesitó.
    /// </summary>
    [Serializable]
    public class Archivo
    {
        public int arc_id { get; set; }
        public Guid arc_uuid { get; set; }
        public int arc_cliente { get; set; }
        public int arc_archivo_categoria { get; set; }
        public string aca_nombre { get; set; }
        public string arc_nombre_original { get; set; }
        public string arc_nombre_almacenado { get; set; }
        public string arc_ruta { get; set; }
        public string arc_mime { get; set; }
        public string arc_extension { get; set; }
        public long arc_byte { get; set; }
        public string arc_hash { get; set; }
        public int arc_antivirus_estado { get; set; }
        public string aae_nombre { get; set; }
        public DateTime? arc_fecha_creacion { get; set; }
        public bool arc_habilitado { get; set; }

        /// <summary>Bytes de paso. No se persiste.</summary>
        [NonSerialized]
        public byte[] contenido;

        public int? filtro_cliente { get; set; }
        public int? filtro_categoria { get; set; }
        public bool? filtro_habilitado { get; set; }
    }
}
