using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;

namespace SitioBase
{
    /// <summary>
    /// Ejecutor de los jobs programados (bloque 461). El catálogo vive en la tabla
    /// Job de la base: qué corre, a qué hora o cada cuántos minutos y cuándo toca.
    /// Este ejecutor no decide horarios: pide a SEL_JOB_PENDIENTES los que tocan
    /// (ya marcados «en ejecución»), los corre y cierra cada uno con UPD_JOB_FIN,
    /// que deja el resultado y calcula la próxima.
    ///
    /// Lo llama Jobs.aspx, que a su vez llama la tarea programada de Plesk cada
    /// 5–15 minutos. Un job que falla no detiene a los demás.
    /// </summary>
    public static class Jobs
    {
        public static string Ejecutar(string forzar)
        {
            StringBuilder log = new StringBuilder();
            foreach (Dictionary<string, object> j in SoporteDatos.Filas("SEL_JOB_PENDIENTES", "@CODIGO", string.IsNullOrEmpty(forzar) ? null : forzar))
            {
                int id = Convert.ToInt32(j["ID"]);
                string codigo = Convert.ToString(j["CODIGO"]);
                Stopwatch reloj = Stopwatch.StartNew();
                bool ok = true; string detalle; int? generadas = null;
                try
                {
                    if (Convert.ToString(j["TIPO"]) == "SQL")
                    {
                        Cobros.Ejecutar("EXE_JOB_SQL", "@JOB", id);
                        detalle = "OK";
                    }
                    else
                    {
                        int n; detalle = Web(codigo, out n); generadas = n;
                    }
                }
                catch (Exception ex)
                {
                    ok = false; detalle = ex.Message;
                    Correo.Registrar("Jobs." + codigo, ex.Message);
                }
                detalle += " · " + reloj.ElapsedMilliseconds + " ms";
                try { Cobros.Ejecutar("UPD_JOB_FIN", "@JOB", id, "@OK", ok, "@DETALLE", detalle, "@GENERADAS", generadas); }
                catch (Exception ex) { Correo.Registrar("Jobs.UPD_JOB_FIN " + codigo, ex.Message); }
                log.Append(codigo).Append(ok ? " OK: " : " ERROR: ").Append(detalle).Append("\n");
            }
            return log.Length == 0 ? "Nada que ejecutar." : log.ToString();
        }

        /// <summary>Los jobs que necesitan el sitio (correos, Webpay, la fuente de la UF).</summary>
        private static string Web(string codigo, out int n)
        {
            n = 0;
            switch (codigo)
            {
                case "UF_DIARIA":
                    Respuesta r = new UfController().Alimentar();
                    if (r != null && r.error) throw new Exception(r.detalle);
                    return r != null && !string.IsNullOrEmpty(r.detalle) ? r.detalle : "UF actualizada";

                case "COBROS_EMITIR":
                {
                    List<string> errores = new List<string>(); int correos = 0;
                    int rezagados = Cobros.RegistrarPendientes();   // pagos autorizados que no alcanzaron a registrarse
                    foreach (Dictionary<string, object> s in SoporteDatos.Filas("SEL_COBROS_POR_EMITIR"))
                    {
                        int sus = Convert.ToInt32(s["SUSCRIPCION"]);
                        try
                        {
                            Cobros.Ejecutar("INS_COBRO_SUSCRIPCION", "@SUSCRIPCION", sus, "@IMPLANTACION", false, "@USUARIO", Cobros.USUARIO_SISTEMA);
                            n++;
                            if (Cobros.CorreoCobro(sus, "COBRO")) correos++;
                        }
                        catch (Exception ex) { errores.Add("suscripción " + sus + ": " + ex.Message); }
                    }
                    if (errores.Count > 0) throw new Exception(n + " emitidos; " + string.Join(" | ", errores));
                    return n + " cobros emitidos, " + correos + " correos enviados" + (rezagados > 0 ? ", " + rezagados + " pagos rezagados registrados" : "");
                }

                case "CORREOS_COLA":
                {
                    int enviados = Correo.ProcesarCola(50, null);
                    n = enviados;
                    return enviados + " correos enviados desde la cola";
                }

                case "ALERTAS_CORREO":
                {
                    n = Notificaciones.Alertas();
                    return n + " correos de alertas puestos en cola";
                }

                case "DEMOS_AVISO":
                {
                    n = Notificaciones.DemosPorVencer();
                    return n + " avisos de demos por vencer";
                }

                case "COBROS_RECORDATORIOS":
                {
                    int correos = 0;
                    // Un correo por suscripción y tipo, aunque tenga varios períodos pendientes.
                    foreach (var g in SoporteDatos.Filas("SEL_COBROS_RECORDATORIO")
                                 .GroupBy(x => new { s = Convert.ToInt32(x["SUSCRIPCION"]), t = Convert.ToString(x["TIPO"]) }))
                    {
                        n++;
                        if (Cobros.CorreoCobro(g.Key.s, g.Key.t)) correos++;
                    }
                    return n + " avisos, " + correos + " correos enviados";
                }
            }
            throw new Exception("El job web «" + codigo + "» no tiene código en el sitio.");
        }
    }
}
