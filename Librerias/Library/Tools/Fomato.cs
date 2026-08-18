using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;

/// <summary>
/// Descripción breve de Fomato
/// </summary>
namespace Tools
{

    public static class Formato
    {

        public static string Miles(string str)
        {
            return String.Format("{0:N0}", Int64.Parse(str));
        }

        public static bool validaMail(string email)
        {
            String expresion;
            expresion = "\\w+([-+.']\\w+)*@\\w+([-.]\\w+)*\\.\\w+([-.]\\w+)*";
            if (Regex.IsMatch(email, expresion))
            {
                if (Regex.Replace(email, expresion, String.Empty).Length == 0)
                {
                    return true;
                }
                else
                {
                    return false;
                }
            }
            else
            {
                return false;
            }
        }

        public static bool RutEsValido(string rut)
        {
            rut = rut.Replace(".", "").ToUpper();
            Regex r = new Regex("^([0-9]+-[0-9K])$");
            if (r.IsMatch(rut))
                return rut.Substring(rut.Length - 1, 1) == CalcularDigito(int.Parse(rut.Substring(0, rut.Length - 2)));
            else
                return false;
        }

        public static string CalcularDigito(int rut)
        {
            int suma = 0;
            int multiplicador = 1;
            while (rut != 0)
            {
                multiplicador++;
                if (multiplicador == 8)
                    multiplicador = 2;
                suma += (rut % 10) * multiplicador;
                rut = rut / 10;
            }
            suma = 11 - (suma % 11);
            if (suma == 11)
                return "0";
            else if (suma == 10)
                return "K";
            else
                return suma.ToString();
        }

        public static bool isInt32(String num)
        {
            try
            {
                Int32.Parse(num);
                return true;
            }
            catch
            {
                return false;
            }
        }

        public static Boolean EsFecha(String fecha)
        {
            try
            {
                DateTime.Parse(fecha);
                return true;
            }
            catch
            {
                return false;
            }
        }

    }
}