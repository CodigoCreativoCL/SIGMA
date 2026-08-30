using System;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// Lectura tolerante del querystring cifrado.
    ///
    /// EL PROBLEMA QUE RESUELVE
    ///   Todos los listados del sitio abren su formulario con un
    ///   abrirAlgo(0) para "Nuevo", asi que a la ficha le llega literalmente
    ///   ?query=0. Eso NO es un texto cifrado valido: Tools.Crypto.Decrypt
    ///   lanza, la excepcion sube sin capturar y la pagina responde 500
    ///   antes de pintar nada. El boton "Nuevo" no funcionaba, y el error no
    ///   quedaba en Sis_Excepcion porque esa tabla solo recibe lo que
    ///   escriben los SPs.
    ///
    ///   Un querystring que no descifra tampoco es motivo para voltear la
    ///   pantalla en ningun otro caso: puede ser un enlace viejo, uno pegado
    ///   a medias, o alguien probando. Lo correcto es tratarlo como "no vino
    ///   ningun parametro", que en una ficha significa registro nuevo.
    ///
    /// POR QUE ACA Y NO UN try EN CADA PAGINA
    ///   Porque son casi treinta fichas con la misma linea copiada. Un
    ///   helper se arregla una vez; veintiocho try/catch se arreglan
    ///   veintiocho veces y el numero veintinueve nace con el bug otra vez.
    ///
    /// NO SUSTITUYE A Tools.Crypto
    ///   Cifrar sigue siendo Tools.Crypto.Encrypt. Esto es solo el camino de
    ///   vuelta, y solo para lo que llega del navegador.
    /// </summary>
    public static class Querystring
    {
        /// <summary>
        /// Descifra el valor que viene en la URL. Devuelve cadena vacia si
        /// no viene, viene vacio o no se puede descifrar. Nunca lanza.
        ///
        /// Hace el UrlDecode por dentro: es lo que hacian todas las
        /// llamadas y olvidarlo produce un fallo que solo aparece cuando el
        /// texto cifrado incluye un '+' o un '/'.
        /// </summary>
        public static string Descifrar(object valor)
        {
            if (valor == null) return "";

            string texto = valor.ToString();

            if (string.IsNullOrEmpty(texto)) return "";

            try
            {
                string plano = Tools.Crypto.Decrypt(HttpUtility.UrlDecode(texto));
                return plano ?? "";
            }
            catch (Exception ex)
            {
                return "";
            }
        }

        /// <summary>
        /// Descifra sin hacer UrlDecode, para las pocas llamadas que reciben
        /// el texto ya decodificado.
        /// </summary>
        public static string DescifrarCrudo(object valor)
        {
            if (valor == null) return "";

            string texto = valor.ToString();

            if (string.IsNullOrEmpty(texto)) return "";

            try
            {
                string plano = Tools.Crypto.Decrypt(texto);
                return plano ?? "";
            }
            catch (Exception ex)
            {
                return "";
            }
        }

        /// <summary>
        /// Lee un parametro entero del querystring cifrado. Devuelve 0 si no
        /// esta o no es un numero.
        ///
        /// Es el caso de lejos mas comun -Querystring.Entero(q, "Id")- y
        /// evita repetir el bucle de split en cada ficha.
        /// </summary>
        public static int Entero(object valor, string parametro)
        {
            string plano = Descifrar(valor);

            if (string.IsNullOrEmpty(plano)) return 0;

            foreach (string par in plano.Split('&'))
            {
                string[] partes = par.Split('=');

                if (partes.Length == 2 &&
                    string.Equals(partes[0], parametro, StringComparison.OrdinalIgnoreCase))
                {
                    int numero;
                    if (int.TryParse(partes[1], out numero)) return numero;
                }
            }

            return 0;
        }

        /// <summary>
        /// Lee un parametro de texto del querystring cifrado. Devuelve
        /// cadena vacia si no esta.
        /// </summary>
        public static string Texto(object valor, string parametro)
        {
            string plano = Descifrar(valor);

            if (string.IsNullOrEmpty(plano)) return "";

            foreach (string par in plano.Split('&'))
            {
                string[] partes = par.Split('=');

                if (partes.Length == 2 &&
                    string.Equals(partes[0], parametro, StringComparison.OrdinalIgnoreCase))
                    return partes[1];
            }

            return "";
        }
    }
}
