using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI.WebControls;

namespace SitioBase.Model
{
    [Serializable]
    public class ClienteUsuario
    {
        public int usu_id { get; set; }
        public string usu_login { get; set; }
        public string usu_password { get; set; }
        public string usu_nombres { get; set; }
        public string usu_apellido_paterno { get; set; }
        public string usu_apellido_materno { get; set; }
        public string usu_identificador { get; set; }
        public string usu_correo { get; set; }
        public string usu_telefono { get; set; }
        public bool? usu_habilitado { get; set; }
        public byte[] usu_foto { get; set; }
        public string usu_foto_extension { get; set; }

        /// <summary>La foto en Blob Storage (bloque 100).</summary>
        public int? usu_archivo_foto { get; set; }
        public bool devuelve_foto { get; set; }
        public string nombre_completo { get; set; }
        public string perfiles { get; set; }
        public string id_perfiles { get; set; }
        public string perfiles_usuario { get; set; }
        public string id_perfiles_usuario { get; set; }
        public string paises { get; set; }
        public string id_paises { get; set; }

        public int ucl_id_cliente { get; set; }

        public int tipo_perfil { get; set; }

        public int cin_id_instalacion { get; set; }
        public string id_cliente { get; set; }
        public bool cliente_nuevo { get; set; }

        public int usuario { get; set; }
        public string filtro_paises { get; set; }
        public string filtro_cliente { get; set; }
        public string filtro_instalacion { get; set; }
        public int ucl_id { get; set; }
        public int instalacion { get; set; }
        public string filtro { get; set; }

        public bool filtro_sin_instalacion { get; set; }
     
        public byte[] abi_archivo { get; set; }
        public FileUpload fileUpload { get; set; }
    }
}