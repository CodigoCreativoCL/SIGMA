using System;

namespace SitioBase.Model
{
    /// <summary>
    /// A quién llamar en el cliente.
    ///
    /// POR QUÉ UNA ENTIDAD Y NO TRES CAMPOS EN Cliente
    ///   Una empresa no tiene "un" contacto: tiene el de operaciones —a quien
    ///   se avisa que la cuadrilla llega mañana—, el comercial y el de
    ///   facturación. Poner `cli_email` en la cabecera obliga a elegir cuál de
    ///   los tres cabe, y el día que hagan falta dos ya no se puede sin migrar.
    /// </summary>
    [Serializable]
    public class ClienteContacto
    {
        public int ccn_id { get; set; }
        public int ccn_cliente { get; set; }

        /// <summary>Correlativo por cliente, desde 1. La pantalla lo muestra como 001.</summary>
        public int? ccn_numero { get; set; }

        public string ccn_nombre { get; set; }
        public string ccn_cargo { get; set; }      // Función del contacto
        public string ccn_empresa { get; set; }
        public string ccn_rubro { get; set; }
        public string ccn_email { get; set; }
        public string ccn_telefono { get; set; }
        public string ccn_direccion { get; set; }
        public string ccn_notas { get; set; }

        /// <summary>
        /// El que la ficha muestra arriba y el que usaría cualquier aviso
        /// automático. Hay exactamente uno por cliente: la base lo garantiza
        /// con un índice único filtrado, no la pantalla.
        /// </summary>
        public bool ccn_principal { get; set; }

        public bool ccn_habilitado { get; set; }

        public int ccn_usuario_creacion { get; set; }
        public DateTime? ccn_fecha_creacion { get; set; }
        public int? ccn_usuario_actualizacion { get; set; }
        public DateTime? ccn_fecha_actualizacion { get; set; }

        public string usuario_creacion_nombre { get; set; }
        public string usuario_actualizacion_nombre { get; set; }

        /// <summary>El correlativo con tres dígitos: 1 → "001".</summary>
        public string NumeroTexto
        {
            get { return (ccn_numero ?? 0).ToString("000"); }
        }

        /// <summary>Las iniciales, para el avatar.</summary>
        public string Iniciales
        {
            get
            {
                string n = (ccn_nombre ?? "").Trim();

                if (n.Length == 0) return "?";

                string[] partes = n.Split(new char[] { ' ' },
                                          StringSplitOptions.RemoveEmptyEntries);

                if (partes.Length == 1) return partes[0].Substring(0, 1).ToUpper();

                return (partes[0].Substring(0, 1) + partes[1].Substring(0, 1)).ToUpper();
            }
        }

        /// <summary>
        /// Cómo alcanzarlo, en una línea. La base garantiza que hay al menos
        /// una de las dos, así que esto nunca sale vacío.
        /// </summary>
        public string ContactoTexto
        {
            get
            {
                string t = "";

                if (!string.IsNullOrEmpty(ccn_email)) t = ccn_email;

                if (!string.IsNullOrEmpty(ccn_telefono))
                    t += (t == "" ? "" : "  ·  ") + ccn_telefono;

                return t;
            }
        }
    }
}
