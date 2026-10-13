using System;
using System.Collections;
using System.Collections.Generic;
using System.Web;
using System.Web.Caching;

namespace SitioBase
{
    /// <summary>
    /// Caché corta para lo que el master lee en CADA página y casi nunca cambia.
    ///
    /// POR QUÉ
    ///   Con la base a ~250 ms de distancia, el master tardaba ~2 s en servirse:
    ///   menú (3 consultas), alertas (2), empresas elegibles (1). Medido con
    ///   SitioBase.Medida (cabecera Server-Timing).
    ///
    /// DÓNDE VIVE
    ///   En HttpRuntime.Cache, no en Session: la sesión corre en modo StateServer y
    ///   serializa todo lo que se le guarda (los modelos no son [Serializable]). La
    ///   clave lleva usuario y cliente, así que cada persona ve lo suyo y cambiar de
    ///   empresa ya lee de nuevo.
    ///
    /// QUÉ NO SE CACHEA AQUÍ
    ///   Los permisos. Token.Permisos() se lee una vez por petición a propósito:
    ///   un permiso revocado tiene que dejar de valer en el clic siguiente. El
    ///   menú cacheado puede mostrar un enlace unos minutos más, pero la página
    ///   igual la bloquea Token.ExigirPagina() con los permisos del momento.
    /// </summary>
    public static class CacheSesion
    {
        private const string PREFIJO = "SIGMA_CS_";

        private static string ClavePersona(string clave) { return PREFIJO + clave + "_" + Session.UsuarioId() + "_" + Session.ClienteId(); }

        /// <summary>Por persona y empresa.</summary>
        public static T Sesion<T>(string clave, int minutos, Func<T> leer) where T : class
        {
            if (HttpContext.Current == null || string.IsNullOrEmpty(Session.UsuarioId())) return leer();
            return Leer(ClavePersona(clave), minutos, leer);
        }

        /// <summary>Igual para todos.</summary>
        public static T Global<T>(string clave, int minutos, Func<T> leer) where T : class
        {
            return Leer(PREFIJO + "G_" + clave, minutos, leer);
        }

        private static T Leer<T>(string k, int minutos, Func<T> leer) where T : class
        {
            T v = HttpRuntime.Cache[k] as T;
            if (v != null) return v;
            v = leer();
            if (v != null) HttpRuntime.Cache.Insert(k, v, null, DateTime.UtcNow.AddMinutes(minutos), Cache.NoSlidingExpiration);
            return v;
        }

        /// <summary>Olvida una clave de la persona actual, en todas sus empresas.</summary>
        public static void BorrarSesion(string clave)
        {
            if (HttpContext.Current == null) return;
            string k = PREFIJO + clave + "_" + Session.UsuarioId() + "_";
            List<string> borrar = new List<string>();
            foreach (DictionaryEntry e in HttpRuntime.Cache) { string x = e.Key as string; if (x != null && x.StartsWith(k)) borrar.Add(x); }
            foreach (string x in borrar) HttpRuntime.Cache.Remove(x);
        }

        public static void BorrarGlobal(string clave) { HttpRuntime.Cache.Remove(PREFIJO + "G_" + clave); }
    }
}
