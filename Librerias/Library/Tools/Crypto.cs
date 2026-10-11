using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.Security.Cryptography;
using System.IO;
using System.Text;
using System.Configuration;
using System.Web.UI.WebControls;


namespace Tools
{

    public static class Crypto
    {

        /* ------------------------------------------------------------------------------------
           IDS DE URL FIRMADOS (11-10-2026)
           Encrypt/Decrypt protegen lo que viaja en ?query= y en los tokens de los WebMethod
           ("Id=1", "IdCliente=3&TipoPerfil=2", ...). Hasta esta fecha eran solo base64: "Id=1"
           salía como SWQ9MQ== y cualquiera podía armar el id de otro registro cambiando el número.

           Ahora el texto va FIRMADO con HMAC-SHA256 y una clave secreta (appSettings «IdFirma»):
               base64url(texto) + "." + base64url(primeros 16 bytes del HMAC)
           El contenido sigue legible, pero alterarlo invalida la firma y Decrypt devuelve "",
           igual que antes con un texto mal formado: quien llama ya trata "" como «no vino».
           Es determinista (la misma URL para el mismo registro) y usa base64url, así que no lleva
           '+', '/' ni '=' y no se rompe con o sin UrlEncode/UrlDecode.
           Los enlaces viejos (base64 sin firma) dejan de abrir a propósito: aceptarlos dejaría
           el hueco abierto. Decisión de Catalina, 11-10-2026.
           ------------------------------------------------------------------------------------ */
        private const int BytesFirma = 16;
        private static byte[] _claveFirma;

        private static byte[] ClaveFirma()
        {
            if (_claveFirma != null) return _claveFirma;
            string clave = ConfigurationManager.AppSettings["IdFirma"];
            if (string.IsNullOrEmpty(clave) || clave.Length < 32)
                throw new ConfigurationErrorsException("Falta la clave «IdFirma» (32 caracteres o más) en appSettings: sin ella no se pueden firmar los ids de las URL.");
            _claveFirma = Encoding.UTF8.GetBytes(clave);
            return _claveFirma;
        }

        private static byte[] Firma(string datos)
        {
            using (HMACSHA256 h = new HMACSHA256(ClaveFirma()))
            {
                byte[] completa = h.ComputeHash(Encoding.ASCII.GetBytes(datos));
                byte[] corta = new byte[BytesFirma];
                Buffer.BlockCopy(completa, 0, corta, 0, BytesFirma);
                return corta;
            }
        }

        private static string B64Url(byte[] b)
        {
            return Convert.ToBase64String(b).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        }

        private static byte[] DeB64Url(string s)
        {
            string b = s.Replace('-', '+').Replace('_', '/');
            switch (b.Length % 4) { case 2: b += "=="; break; case 3: b += "="; break; case 1: throw new FormatException(); }
            return Convert.FromBase64String(b);
        }

        /// <summary>Compara en tiempo constante: el tiempo de respuesta no revela cuántos bytes de la firma acertó.</summary>
        private static bool Iguales(byte[] a, byte[] b)
        {
            if (a == null || b == null || a.Length != b.Length) return false;
            int dif = 0;
            for (int i = 0; i < a.Length; i++) dif |= a[i] ^ b[i];
            return dif == 0;
        }

        /// <summary>Firma el texto para la URL: base64url(texto).firma.</summary>
        public static string Encrypt(string str)
        {
            string datos = B64Url(Encoding.UTF8.GetBytes(str ?? ""));
            return datos + "." + B64Url(Firma(datos));
        }

        /// <summary>Devuelve el texto si la firma es válida; "" si falta, está mal formado o fue alterado.</summary>
        public static string Decrypt(string str)
        {
            try
            {
                if (string.IsNullOrEmpty(str)) return "";
                int punto = str.LastIndexOf('.');
                if (punto <= 0 || punto == str.Length - 1) return "";
                string datos = str.Substring(0, punto);
                if (!Iguales(DeB64Url(str.Substring(punto + 1)), Firma(datos))) return "";
                return Encoding.UTF8.GetString(DeB64Url(datos));
            }
            catch (ConfigurationErrorsException)
            {
                throw;
            }
            catch
            {
                return "";
            }
        }

        //Encriptacion 
        public static string encripta(string cadena)
        {
            return Encriptar(cadena, ConfigurationManager.AppSettings["Crypto"].ToString());
        }

        public static string desencriptar(string cadena)
        {
            return Desencriptar(cadena, ConfigurationManager.AppSettings["Crypto"].ToString());
        }

        private static string Encriptar(string strAEncriptar, string clave)
        {
            if (strAEncriptar == "") return "";

            try
            {
                //Plain Text to be encrypted
                byte[] PlainText = System.Text.Encoding.Unicode.GetBytes(strAEncriptar);

                StringBuilder sb = new StringBuilder();
                sb.Append(clave);

                StringBuilder _sbSalt = new StringBuilder();
                for (int i = 0; i < 8; i++)
                {
                    _sbSalt.Append("," + sb.Length.ToString());
                }
                byte[] Salt = Encoding.ASCII.GetBytes(_sbSalt.ToString());

                Rfc2898DeriveBytes pwdGen = new Rfc2898DeriveBytes(sb.ToString(), Salt, 10000);
                RijndaelManaged _RijndaelManaged = new RijndaelManaged();
                _RijndaelManaged.BlockSize = 256;

                byte[] key = pwdGen.GetBytes(_RijndaelManaged.KeySize / 8);
                byte[] iv = pwdGen.GetBytes(_RijndaelManaged.BlockSize / 8);

                _RijndaelManaged.Key = key;
                _RijndaelManaged.IV = iv;

                byte[] cipherText2 = null;
                using (MemoryStream ms = new MemoryStream())
                {
                    using (CryptoStream cs = new CryptoStream(ms, _RijndaelManaged.CreateEncryptor(), CryptoStreamMode.Write))
                    {
                        cs.Write(PlainText, 0, PlainText.Length);



                    }
                    cipherText2 = ms.ToArray();

                }

                iv = null;
                key = null;
                _RijndaelManaged = null;
                pwdGen = null;
                Salt = null;
                _sbSalt = null;
                sb = null;
                PlainText = null;

                //return cipherText2;
                return Convert.ToBase64String(cipherText2);
            }
            catch (Exception ex)
            {
                string strError = ex.Message;
                return "-1";
            }

        }

        private static string Desencriptar(string strEncriptado, string clave)
        {
            if (strEncriptado == "") return "";

            try
            {
                byte[] cipherText2 = Convert.FromBase64String(strEncriptado);

                StringBuilder sb = new StringBuilder();
                sb.Append(clave);

                StringBuilder _sbSalt = new StringBuilder();
                for (int i = 0; i < 8; i++)
                {
                    _sbSalt.Append("," + sb.Length.ToString());
                }
                byte[] Salt = Encoding.ASCII.GetBytes(_sbSalt.ToString());

                Rfc2898DeriveBytes pwdGen = new Rfc2898DeriveBytes(sb.ToString(), Salt, 10000);
                RijndaelManaged _RijndaelManaged = new RijndaelManaged();
                _RijndaelManaged.BlockSize = 256;

                byte[] key = pwdGen.GetBytes(_RijndaelManaged.KeySize / 8);
                byte[] iv = pwdGen.GetBytes(_RijndaelManaged.BlockSize / 8);

                _RijndaelManaged.Key = key;
                _RijndaelManaged.IV = iv;

                byte[] plainText2 = null;
                using (MemoryStream ms = new MemoryStream())
                {
                    using (CryptoStream cs = new CryptoStream(ms, _RijndaelManaged.CreateDecryptor(), CryptoStreamMode.Write))
                    {
                        cs.Write(cipherText2, 0, cipherText2.Length);
                    }
                    plainText2 = ms.ToArray();
                }

                iv = null;
                key = null;
                _RijndaelManaged = null;
                pwdGen = null;
                Salt = null;
                _sbSalt = null;
                sb = null;
                cipherText2 = null;

                return System.Text.Encoding.Unicode.GetString(plainText2);

            }
            catch (Exception ex)
            {
                string strError = ex.Message;
                return "-1";
            }
        }

        public static string GetMD5(string str)
        {
            MD5 md5 = MD5CryptoServiceProvider.Create();

            ASCIIEncoding encoding = new ASCIIEncoding();

            byte[] stream = null;

            StringBuilder sb = new StringBuilder();

            stream = md5.ComputeHash(encoding.GetBytes(str));

            for (int i = 0; i < stream.Length; i++)
            {
                sb.AppendFormat("{0:x2}", stream[i]);
            }

            return sb.ToString();
        }


        //public static string encripta(string cadena)
        //{
        //    return encriptar(cadena, ConfigurationManager.AppSettings["Crypto"].ToString());
        //    //return encriptar(cadena, "FC1N%MED$LEONZ0LDIKLINUX123$%SAA");
        //}

        //public static string desencriptar(string cadena)
        //{
        //    return desencriptar(cadena, ConfigurationManager.AppSettings["Crypto"].ToString());
        //    //return desencriptar(cadena, "FC1N%MED$LEONZ0LDIKLINUX123$%SAA");
        //}

        //private static string encriptar(string cadena, string clave)
        //{
        //    // Convierto la cadena y la clave en arreglos de bytes
        //    // para poder usarlas en las funciones de encriptacion
        //    byte[] cadenaBytes = Encoding.UTF8.GetBytes(cadena);
        //    byte[] claveBytes = Encoding.UTF8.GetBytes(clave);

        //    // Creo un objeto de la clase Rijndael
        //    RijndaelManaged rij = new RijndaelManaged();

        //    // Configuro para que utilice el modo ECB
        //    rij.Mode = CipherMode.ECB;

        //    // Configuro para que use encriptacion de 256 bits.
        //    rij.BlockSize = 256;

        //    // Declaro que si necesitara mas bytes agregue ceros.
        //    rij.Padding = PaddingMode.Zeros;

        //    // Declaro un encriptador que use mi clave secreta y un vector
        //    // de inicializacion aleatorio
        //    ICryptoTransform encriptador;
        //    encriptador = rij.CreateEncryptor(claveBytes, rij.IV);

        //    // Declaro un stream de memoria para que guarde los datos
        //    // encriptados a medida que se van calculando
        //    MemoryStream memStream = new MemoryStream();

        //    // Declaro un stream de cifrado para que pueda escribir aqui
        //    // la cadena a encriptar. Esta clase utiliza el encriptador
        //    // y el stream de memoria para realizar la encriptacion
        //    // y para almacenarla
        //    CryptoStream cifradoStream;
        //    cifradoStream = new CryptoStream(memStream, encriptador, CryptoStreamMode.Write);

        //    // Escribo los bytes a encriptar. A medida que se va escribiendo
        //    // se va encriptando la cadena
        //    cifradoStream.Write(cadenaBytes, 0, cadenaBytes.Length);

        //    // Aviso que la encriptación se terminó
        //    cifradoStream.FlushFinalBlock();

        //    // Convert our encrypted data from a memory stream into a byte array.
        //    byte[] cipherTextBytes = memStream.ToArray();

        //    // Cierro los dos streams creados
        //    memStream.Close();
        //    cifradoStream.Close();

        //    // Convierto el resultado en base 64 para que sea legible
        //    // y devuelvo el resultado
        //    return Convert.ToBase64String(cipherTextBytes);
        //}

        //private static string desencriptar(string cadena, string clave)
        //{
        //    // Convierto la cadena y la clave en arreglos de bytes
        //    // para poder usarlas en las funciones de encriptacion
        //    // En este caso la cadena la convierta usando base 64
        //    // que es la codificacion usada en el metodo encriptar
        //    byte[] cadenaBytes = Convert.FromBase64String(cadena);
        //    byte[] claveBytes = Encoding.UTF8.GetBytes(clave);

        //    // Creo un objeto de la clase Rijndael
        //    RijndaelManaged rij = new RijndaelManaged();

        //    // Configuro para que utilice el modo ECB
        //    rij.Mode = CipherMode.ECB;

        //    // Configuro para que use encriptacion de 256 bits.
        //    rij.BlockSize = 256;

        //    // Declaro que si necesitara mas bytes agregue ceros.
        //    rij.Padding = PaddingMode.Zeros;

        //    // Declaro un desencriptador que use mi clave secreta y un vector
        //    // de inicializacion aleatorio
        //    ICryptoTransform desencriptador;
        //    desencriptador = rij.CreateDecryptor(claveBytes, rij.IV);

        //    // Declaro un stream de memoria para que guarde los datos
        //    // encriptados
        //    MemoryStream memStream = new MemoryStream(cadenaBytes);

        //    // Declaro un stream de cifrado para que pueda leer de aqui
        //    // la cadena a desencriptar. Esta clase utiliza el desencriptador
        //    // y el stream de memoria para realizar la desencriptacion
        //    CryptoStream cifradoStream;
        //    cifradoStream = new CryptoStream(memStream, desencriptador, CryptoStreamMode.Read);

        //    // Declaro un lector para que lea desde el stream de cifrado.
        //    // A medida que vaya leyendo se ira desencriptando.
        //    StreamReader lectorStream = new StreamReader(cifradoStream);

        //    // Leo todos los bytes y lo almaceno en una cadena
        //    string resultado = lectorStream.ReadToEnd();

        //    // Cierro los dos streams creados
        //    memStream.Close();
        //    cifradoStream.Close();

        //    // Devuelvo la cadena
        //    return resultado;
        //}


    }

}