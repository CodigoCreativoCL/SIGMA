using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Linq;
using System.Web;

namespace SitioBase
{
    /// <summary>
    /// Cuánto tarda cada parte de una página en el servidor, en la cabecera estándar
    /// «Server-Timing» (Chrome: DevTools › Network › la petición › Timing).
    ///
    ///     using (Medida.Tramo("alertas")) { CargarAlertas(); }
    ///     ...
    ///     Medida.Emitir();   // en el PreRender del master
    ///
    /// No cambia lo que se muestra ni lo que se guarda: solo agrega una cabecera, y
    /// sirve igual en producción para saber si una pantalla lenta lo es por la base.
    /// </summary>
    public static class Medida
    {
        private const string CLAVE = "SIGMA_MEDIDA";

        private static Dictionary<string, double> Tramos()
        {
            HttpContext ctx = HttpContext.Current;
            if (ctx == null) return null;
            Dictionary<string, double> d = ctx.Items[CLAVE] as Dictionary<string, double>;
            if (d == null) { d = new Dictionary<string, double>(); ctx.Items[CLAVE] = d; }
            return d;
        }

        public static IDisposable Tramo(string nombre) { return new Reloj(nombre); }

        /// <summary>Agrega la cabecera con cada tramo y el total desde que entró la petición.</summary>
        public static void Emitir()
        {
            HttpContext ctx = HttpContext.Current;
            Dictionary<string, double> d = Tramos();
            if (ctx == null || d == null || ctx.Response.HeadersWritten) return;
            double total = (DateTime.Now - ctx.Timestamp).TotalMilliseconds;
            string v = string.Join(", ", d.Select(x => x.Key + ";dur=" + x.Value.ToString("0", CultureInfo.InvariantCulture))
                .Concat(new[] { "servidor;desc=\"hasta el master\";dur=" + total.ToString("0", CultureInfo.InvariantCulture) }));
            ctx.Response.AppendHeader("Server-Timing", v);
        }

        private sealed class Reloj : IDisposable
        {
            private readonly string _n; private readonly Stopwatch _s = Stopwatch.StartNew();
            public Reloj(string n) { _n = n; }
            public void Dispose()
            {
                Dictionary<string, double> d = Tramos(); if (d == null) return;
                double ms = _s.Elapsed.TotalMilliseconds;
                d[_n] = (d.ContainsKey(_n) ? d[_n] : 0) + ms;
            }
        }
    }
}
