using System;


namespace SitioBase.Model
{
    [Serializable]
    public class ClienteAppInstalacion
    {
        public int cai_id { get; set; }
        public int id_cliente { get; set; }
        public int cai_id_instalacion { get; set; }
        public int cai_id_app { get; set; }
        public bool? cai_habilitado { get; set; }
        public int cai_usuario_creacion { get; set; }
        public DateTime cai_fecha_creacion { get; set; }
        public int cai_usuario_actualizacion { get; set; }
        public DateTime cai_fecha_actualizacion { get; set; }
        public int app_id { get; set; }
        public string app_nombre { get; set; }
        /* app_tipo es una ETIQUETA de agrupacion -TERRENO, VOZ, CONSULTA-,
           no un numero. Era int porque en el modelo heredado el 1 significaba
           "funcionalidad base" y servia para bloquear el interruptor. Ese
           concepto desaparecio: lo que no se puede apagar directamente no
           esta en la lista. */
        public string app_tipo { get; set; }

        /* De que historia del backlog sale esta funcionalidad. No se muestra
           al cliente; sirve para que dentro de un ano se sepa por que existe
           la fila. */
        public string app_origen { get; set; }
        public int cap_id { get; set; }

    }
}