using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Usuario
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

        /// <summary>
        /// La foto, ahora en Blob Storage (bloque 100). Ver el comentario de
        /// Cliente.cli_archivo_logo: mismo motivo, misma forma.
        /// </summary>
        public int? usu_archivo_foto { get; set; }
        public bool devuelve_foto { get; set; }
        public string nombre_completo { get; set; }
        public string perfiles { get; set; }
        public string id_perfiles { get; set; }
        public string paises { get; set; }
        public string id_paises { get; set; }
        public string clientes { get; set; }
        public string id_clientes { get; set; }
        public string instalaciones { get; set; }
        public string id_instalaciones { get; set; }

        public string ids { get; set; }
        public string filtro { get; set; }

        public string Code { get; set; }
        public string Mensaje { get; set; }

    }
}