using System;

namespace SitioBase.Model
{
    [Serializable]
    public class UsuarioClienteInstalacion
    {
        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
        public int? cin_id { get; set; }
        public string cin_nombre { get; set; }
    }
}
