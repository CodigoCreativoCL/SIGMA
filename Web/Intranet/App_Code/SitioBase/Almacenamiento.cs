using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;

namespace SitioBase
{
    /// <summary>
    /// Lo que devuelve una subida: los datos que hay que guardar en la
    /// tabla Archivo. Nada más — el binario ya quedó del otro lado.
    /// </summary>
    [Serializable]
    public class ResultadoSubida
    {
        public string ruta { get; set; }               // contenedor/carpeta/nombre
        public string nombre_almacenado { get; set; }
        public string hash { get; set; }               // SHA-256 en hexadecimal
        public long tamano { get; set; }
        public string mime { get; set; }
        public string extension { get; set; }
    }

    /// <summary>
    /// El almacenamiento de binarios de SIGMA.
    ///
    /// POR QUÉ ES UNA INTERFAZ Y NO UNA CLASE
    ///   Los binarios van a Blob Storage, pero quien habla con Azure NO es
    ///   este sitio: es una API .NET aparte, que además atiende a la app
    ///   móvil. Que la web y la app suban por caminos distintos garantizaría
    ///   que un día un archivo quede en un contenedor que la otra no mira.
    ///
    ///   Mientras esa API no exista, el sitio tiene que compilar, abrir y
    ///   decir la verdad sobre lo que puede y no puede hacer. Por eso hay
    ///   una interfaz con Disponible: quien vaya a ofrecer una subida
    ///   pregunta primero, y si no se puede lo dice en pantalla en vez de
    ///   fallar al guardar.
    /// </summary>
    public interface IAlmacenamiento
    {
        /// <summary>
        /// Falso mientras el proveedor no esté configurado. Quien vaya a
        /// ofrecer una subida DEBE preguntar antes.
        /// </summary>
        bool Disponible { get; }

        /// <summary>Por qué no está disponible, para mostrárselo a quien corresponda.</summary>
        string Motivo { get; }

        ResultadoSubida Subir(int cliente, string carpeta, string nombreOriginal, byte[] contenido, string mime);

        byte[] Descargar(string ruta);

        void Eliminar(string ruta);
    }


    /// <summary>
    /// Fábrica. Devuelve la implementación configurada.
    /// </summary>
    public static class Almacenamiento
    {
        public static IAlmacenamiento Actual()
        {
            // Hoy hay una sola. Cuando existan varias (por ejemplo, una
            // local para desarrollo), este es el punto donde se elige, y
            // ningún controller se entera.
            return new AlmacenamientoApi();
        }

        /// <summary>
        /// SHA-256 en hexadecimal. Se calcula acá y no del otro lado para
        /// poder detectar el mismo contenido subido dos veces sin tener que
        /// bajarlo de vuelta.
        /// </summary>
        public static string Hash(byte[] contenido)
        {
            if (contenido == null || contenido.Length == 0) return null;

            using (SHA256 sha = SHA256.Create())
            {
                byte[] hash = sha.ComputeHash(contenido);
                StringBuilder sb = new StringBuilder(hash.Length * 2);
                for (int i = 0; i < hash.Length; i++) sb.Append(hash[i].ToString("x2"));
                return sb.ToString();
            }
        }

        /// <summary>
        /// Nombre con el que se guarda: un GUID más la extensión original.
        ///
        /// No se conserva el nombre que traía el archivo. Dos personas
        /// suben "comprobante.pdf" el mismo día y una pisaría a la otra; y
        /// un nombre elegido por quien sube es una ruta elegida por quien
        /// sube. El nombre original se guarda igual, en la columna
        /// arc_nombre_original, que es donde sirve: para mostrárselo a
        /// quien lo busca.
        /// </summary>
        public static string NombreAlmacenado(string nombreOriginal)
        {
            string extension = "";

            if (!string.IsNullOrEmpty(nombreOriginal))
            {
                extension = Path.GetExtension(nombreOriginal);
                if (extension != null && extension.Length > 20) extension = "";
            }

            return Guid.NewGuid().ToString("N") + extension;
        }
    }


    /// <summary>
    /// Almacenamiento a traves de la API de servicios (Services.cs).
    ///
    /// ESTADO: CONECTADO.
    ///   Hasta el 01-09 esta clase tenia su propio WebClient y su propia
    ///   forma de armar la ruta. Eso se mudo entero a `Services.cs`, que es
    ///   la unica puerta de la web hacia la API: dos clientes HTTP para el
    ///   mismo servicio son dos sitios donde arreglar el mismo error el dia
    ///   que cambie la autenticacion.
    ///
    ///   Lo que queda aca es la implementacion de IAlmacenamiento, para que
    ///   ArchivoController y las pantallas que ya preguntan por `Disponible`
    ///   sigan funcionando sin cambiar una linea.
    ///
    /// LA WEB NO CONOCE EL SAS
    ///   Solo la API lo tiene. Rotarlo es tocar una configuracion y no dos.
    /// </summary>
    public class AlmacenamientoApi : IAlmacenamiento
    {
        public bool Disponible
        {
            get { return Services.Disponible; }
        }

        public string Motivo
        {
            get { return Services.Motivo; }
        }

        public ResultadoSubida Subir(int cliente, string carpeta, string nombreOriginal, byte[] contenido, string mime)
        {
            if (!Disponible) throw new Exception(Motivo);

            return ServicioArchivos.Subir(cliente, NombreCliente(cliente), carpeta,
                                          nombreOriginal, contenido, mime);
        }

        public byte[] Descargar(string ruta)
        {
            if (!Disponible) throw new Exception(Motivo);

            return ServicioArchivos.Descargar(ruta);
        }

        public void Eliminar(string ruta)
        {
            if (!Disponible) throw new Exception(Motivo);

            ServicioArchivos.Eliminar(ruta);
        }

        /// <summary>
        /// El nombre del cliente, para que la carpeta se pueda leer.
        ///
        /// Se guarda en HttpContext.Items: subir tres adjuntos en la misma
        /// peticion consultaria tres veces lo mismo. Si no se puede resolver
        /// se devuelve vacio y la carpeta queda solo con el id, que es feo
        /// pero correcto: mejor eso que fallar la subida por el nombre.
        /// </summary>
        private string NombreCliente(int cliente)
        {
            string clave = "sigma-cliente-nombre-" + cliente;

            if (HttpContext.Current != null && HttpContext.Current.Items[clave] != null)
                return Convert.ToString(HttpContext.Current.Items[clave]);

            string nombre = "";

            try
            {
                global::SitioBase.Controller.ClienteController controller = new global::SitioBase.Controller.ClienteController();
                global::SitioBase.Model.Cliente c = controller.GetCliente(
                    new global::SitioBase.Model.Cliente { cli_id = cliente });

                if (c != null) nombre = c.cli_nombre;
            }
            catch (Exception)
            {
                // Queda el id solo.
            }

            if (HttpContext.Current != null) HttpContext.Current.Items[clave] = nombre;

            return nombre;
        }
    }
}
