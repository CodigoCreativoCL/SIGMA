using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Excepcion de permiso concedida o denegada a una persona (HU-007).
    ///
    /// El AMBITO no es una columna: se deduce de hasta donde se acoto la
    /// excepcion. Sin planta ni area es de Cliente; con planta es de
    /// Planta; con area es de Area. El SP lo devuelve ya resuelto.
    ///
    /// cpm_otorgado = 0 es una DENEGACION explicita, y prevalece sobre lo
    /// que diga el perfil. Por eso revocar no es lo mismo que denegar:
    /// revocar (cpm_habilitado = 0) devuelve a la persona a su perfil,
    /// denegar le quita el permiso aunque el perfil se lo de.
    /// </summary>
    [Serializable]
    public class ClienteUsuarioPermiso
    {
        public int cpm_id { get; set; }
        public int cpm_cliente_usuario { get; set; }
        public int cpm_permiso { get; set; }
        public int? cpm_cliente_instalacion { get; set; }
        public int? cpm_instalacion_area { get; set; }
        public bool cpm_otorgado { get; set; }
        public DateTime? cpm_fecha_inicio { get; set; }
        public DateTime? cpm_fecha_fin { get; set; }
        public string cpm_motivo { get; set; }
        public bool cpm_habilitado { get; set; }
        public int cpm_usuario_creacion { get; set; }
        public DateTime? cpm_fecha_creacion { get; set; }

        // Columnas del JOIN
        public int usu_id { get; set; }
        public string usu_nombre { get; set; }
        public string usu_correo { get; set; }
        public string prm_codigo { get; set; }
        public string prm_nombre { get; set; }
        public string prm_modulo { get; set; }
        public string cin_nombre { get; set; }
        public string iar_nombre { get; set; }
        public string otorgado_por { get; set; }
        public string estado { get; set; }
        public string ambito { get; set; }

        // Datos que necesita el INS_ y que no son columnas de la tabla
        public int cliente { get; set; }
        public int usuario_destino { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_solo_vigentes { get; set; }
    }
}
