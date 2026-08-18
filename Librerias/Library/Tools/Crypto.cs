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

        //Codificar Base 64
        public static string Encrypt(string str)
        {
            byte[] encbuff = System.Text.Encoding.UTF8.GetBytes(str);
            return Convert.ToBase64String(encbuff);
        }

        //Decodificar Base 64
        public static string Decrypt(string str)
        {
            try
            {
                byte[] decbuff = Convert.FromBase64String(str);
                return System.Text.Encoding.UTF8.GetString(decbuff);
            }
            catch
            {
                { return ""; }
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