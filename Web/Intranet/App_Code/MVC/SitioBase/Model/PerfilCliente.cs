using System;

namespace SitioBase.Model
{
    /// <summary>
    /// Un perfil de la empresa (bloque 341): lo crea su Administrador y decide
    /// qué permisos da. El Administrador del Cliente es del sistema y se lista
    /// bloqueado (es_sistema).
    /// </summary>
    public class PerfilCliente
    {
        public int per_id { get; set; }
        public string per_nombre { get; set; }
        public string per_descripcion { get; set; }
        /// <summary>1 web, 2 app, 3 ambos (Permiso_Ambito).</summary>
        public int per_ambito { get; set; }
        public bool per_solo_ejecucion { get; set; }
        public bool per_habilitado { get; set; }
        public bool es_sistema { get; set; }
        public int usuarios { get; set; }
        public int permisos { get; set; }
        public DateTime? per_fecha_act { get; set; }

        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public bool filtro_plantillas { get; set; }
    }

    /// <summary>Un permiso que la empresa puede dar, marcado si el perfil lo tiene.</summary>
    public class PerfilClientePermiso
    {
        public int prm_id { get; set; }
        public string prm_codigo { get; set; }
        public string prm_nombre { get; set; }
        public string prm_descripcion { get; set; }
        public string prm_modulo { get; set; }
        public bool asignado { get; set; }
    }
}
