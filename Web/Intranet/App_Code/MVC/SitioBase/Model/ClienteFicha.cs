using System;

namespace SitioBase.Model
{
    /// <summary>
    /// La ficha corporativa del cliente: lo mismo que <see cref="Cliente"/>
    /// pero con los catálogos ya resueltos y los conteos hechos.
    ///
    /// POR QUÉ UNA CLASE APARTE Y NO MÁS CAMPOS EN Cliente
    ///   `Cliente` es la entidad que se guarda: lo que tiene son las columnas
    ///   de la tabla. Esto es una VISTA de lectura —nombres de catálogo,
    ///   cuántos usuarios, si la configuración está completa— y nada de eso
    ///   se escribe. Mezclarlas haría que el alta y la edición arrastraran
    ///   una docena de campos que nunca van a la base.
    /// </summary>
    public class ClienteFicha
    {
        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
        public string cli_razon_social { get; set; }
        public string cli_nombre_fantasia { get; set; }
        public string cli_identificador { get; set; }
        public bool cli_habilitado { get; set; }
        public int? cli_archivo_logo { get; set; }

        public int? cli_pais { get; set; }
        public string PAIS_NOMBRE { get; set; }

        /// <summary>
        /// Cómo se llama el identificador EN ESE PAÍS: RUT en Chile, CUIT en
        /// Argentina. Rotularlo siempre "RUT" es correcto en una sola parte
        /// del mapa.
        /// </summary>
        public string IDENTIFICADOR_ROTULO { get; set; }

        public int? cli_zona_horaria { get; set; }
        public string ZONA_HORARIA_NOMBRE { get; set; }
        public int? cli_idioma { get; set; }
        public string IDIOMA_NOMBRE { get; set; }
        public int? cli_moneda { get; set; }
        public string MONEDA_NOMBRE { get; set; }

        public int USUARIOS { get; set; }
        public int INSTALACIONES { get; set; }

        /// <summary>
        /// Zona horaria, idioma y moneda son las tres que hacen que las
        /// fechas, los formatos y los montos se muestren bien.
        /// </summary>
        public bool CONFIGURACION_COMPLETA { get; set; }

        /// <summary>Cuáles faltan. Un "incompleta" sin decir cuál obliga a revisar las tres.</summary>
        public string CONFIGURACION_FALTA { get; set; }

        public int? cli_usuario_creacion { get; set; }
        public DateTime? cli_fecha_creacion { get; set; }
        public string USUARIO_CREACION_NOMBRE { get; set; }

        public int? cli_usuario_actualizacion { get; set; }
        public DateTime? cli_fecha_actualizacion { get; set; }
        public string USUARIO_ACTUALIZACION_NOMBRE { get; set; }

        /// <summary>Lo que se muestra como título: la razón social si la hay.</summary>
        public string Titulo
        {
            get
            {
                if (!string.IsNullOrEmpty(cli_razon_social)) return cli_razon_social;
                if (!string.IsNullOrEmpty(cli_nombre)) return cli_nombre;
                return "Cliente";
            }
        }

        /// <summary>"zona horaria, idioma" → "zona horaria e idioma", sin la coma final.</summary>
        public string FaltaTexto
        {
            get
            {
                string t = (CONFIGURACION_FALTA ?? "").Trim();

                if (t.EndsWith(",")) t = t.Substring(0, t.Length - 1);

                int i = t.LastIndexOf(", ", StringComparison.Ordinal);
                if (i > 0) t = t.Substring(0, i) + " y " + t.Substring(i + 2);

                return t;
            }
        }
    }
}
