using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;


namespace SitioBase.Model
{
    [Serializable]
    public class Archivo
    {
        public int arc_id { get; set; }
        public string arc_nombre_archivo { get; set; }
        public string arc_descripcion { get; set; }
        public string arc_contenido { get; set; }
        public string arc_extension { get; set; }
        public string arc_tamano { get; set; }
        public int arc_archivo { get; set; }
        public ArchivoBinario archivoBinario { get; set; }
        public byte[] abi_archivo { get; set; }
        public DateTime fecha { get; set; }
    }
}