using System;

namespace SitioBase.Model
{
    [Serializable]
    public class Cliente
    {


        public int cli_id { get; set; }
        public string cli_nombre { get; set; }
        public int cli_pais { get; set; }
        public string cli_razon_social { get; set; }
        public string cli_identificador { get; set; }
        public bool cli_habilitado { get; set; }
        public int cli_usuario_creacion { get; set; }
        public DateTime cli_fecha_creacion { get; set; }
        public int cli_usuario_actualizacion { get; set; }
        public DateTime cli_fecha_actualizacion { get; set; }
        
        // HU-010. Columnas agregadas en el bloque 25 de base de datos.
        public string cli_nombre_fantasia { get; set; }
        public int? cli_zona_horaria { get; set; }
        public int? cli_idioma { get; set; }
        public int? cli_moneda { get; set; }

        // Nombres legibles que resuelve SEL_CLIENTE por JOIN
        public string zho_nombre { get; set; }
        public string idi_nombre { get; set; }
        public string mon_nombre { get; set; }

        /// <summary>
        /// True solo cuando el formulario adjunto un logotipo nuevo.
        ///
        /// Sin esta bandera, guardar la ficha sin volver a subir la imagen
        /// mandaba cli_logo en null y BORRABA el logo existente.
        /// </summary>
        public bool cambia_logo { get; set; }

        public string pai_nombre { get; set; }
        public string filtro { get; set; }
        public bool? filtro_habilitado { get; set; }
        public string filtro_paises { get; set; }
        public string filtro_instalacion { get; set; }
        public string filtro_usuarios { get; set; }
        public int tipo_perfil { get; set; }
        public string filtro_pais { get; set; }
        public byte[] cli_logo { get; set; }

        /// <summary>
        /// El logo, ahora en Blob Storage (bloque 100).
        ///
        /// `cli_logo` queda muerta: era el binario DENTRO de SQL Server, y se
        /// servia como data:base64 incrustado en el HTML, asi que el logo
        /// viajaba entero en cada carga de pagina y ningun navegador lo podia
        /// cachear. Ahora es un id de Archivo y la imagen se pide por URL.
        /// </summary>
        public int? cli_archivo_logo { get; set; }

    }
}