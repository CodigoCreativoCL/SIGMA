using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// La mesa de ayuda: reportar, atender y seguir problemas.
///
/// QUIEN PUEDE QUE LO DECIDE EL SP
///   Todos los metodos pasan el usuario de la sesion y el SP responde segun
///   sea del equipo de soporte (SOPORTE GESTIONAR) o quien reporto. Aca solo
///   se valida que haya sesion.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsSoporte : System.Web.Services.WebService
{
    /* ---------------- Bandeja y detalle ---------------- */

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Bandeja(bool soloMios)
    {
        return Ejecutar(() => new { tickets = SoporteDatos.Filas("SEL_SOPORTE_BANDEJA", "@USUARIO", U(), "@SOLO_MIOS", soloMios) });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ticket(int id)
    {
        return Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_SOPORTE_TICKET_360", "@TICKET", id, "@USUARIO", U());
            List<Dictionary<string, object>> eventos = SoporteDatos.Del(c, 1);
            foreach (Dictionary<string, object> e in eventos)
            {
                int arc = e["ste_archivo"] == null ? 0 : Convert.ToInt32(e["ste_archivo"]);
                e["ARCHIVO_URL"] = arc > 0 ? UrlArchivo.Ver(arc) : null;
                e["ARCHIVO_BAJAR"] = arc > 0 ? UrlArchivo.Descargar(arc) : null;
            }
            return new
            {
                ticket = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null,
                eventos = eventos,
                encuesta = SoporteDatos.Del(c, 2).Count > 0 ? SoporteDatos.Del(c, 2)[0] : null,
                ayuda = SoporteDatos.Del(c, 3),
                recurrente = SoporteDatos.Del(c, 4).Count > 0 ? SoporteDatos.Del(c, 4)[0] : null
            };
        });
    }

    /* ---------------- Reportar ---------------- */

    /// <summary>
    /// Crea el ticket. El contexto lo manda la pagina; cliente y planta salen
    /// de la sesion, no de lo que diga el navegador.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Crear(string datos)
    {
        return Ejecutar(() =>
        {
            Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos ?? "{}");
            int cliente = SitioBase.Session.ClienteId();
            if (cliente <= 0) throw new Exception("Elige un cliente antes de reportar.");
            int usuario = Entero(d, "usuario");
            if (usuario <= 0) usuario = U();

            Dictionary<string, object> f = SoporteDatos.Fila("INS_SOPORTE_TICKET",
                "@CLIENTE", cliente,
                "@INSTALACION", Entero(d, "planta") > 0 ? (object)Entero(d, "planta") : null,
                "@USUARIO", usuario,
                "@USUARIO_CREACION", U(),
                "@TITULO", Texto(d, "titulo"),
                "@DESCRIPCION", Texto(d, "descripcion"),
                "@CATEGORIA", Texto(d, "categoria"),
                "@PRIORIDAD", Texto(d, "prioridad"),
                "@MODULO", Texto(d, "modulo"),
                "@SUBMODULO", Texto(d, "submodulo"),
                "@PANTALLA", Texto(d, "pantalla"),
                "@SECCION", Texto(d, "seccion"),
                "@RUTA", Texto(d, "ruta"),
                "@REGISTRO", Texto(d, "registro"),
                "@NAVEGADOR", Texto(d, "navegador"),
                "@SUGERIDO", Entero(d, "sugerido") > 0 ? (object)Entero(d, "sugerido") : null,
                "@SUGERIDO_VISTO", Entero(d, "sugeridoVisto") > 0);
            SoportePlan.Olvidar();
            return new { id = f["stk_id"], folio = f["stk_folio"] };
        });
    }

    /// <summary>«Sí, se resolvió»: la ayuda sugerida evito un ticket.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Evitado(int contenido, string titulo, string modulo, string pantalla)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("INS_SOPORTE_TICKET_EVITADO", "@USUARIO", U(), "@CLIENTE", SitioBase.Session.ClienteId(),
                "@CONTENIDO", contenido > 0 ? (object)contenido : null, "@TITULO", titulo, "@MODULO", modulo, "@PANTALLA", pantalla);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Sugerencia(string texto, string modulo, string pantalla)
    {
        return Ejecutar(() => new
        {
            sugerencias = SoporteDatos.Filas("SEL_AYUDA_SUGERENCIA", "@USUARIO", U(), "@CLIENTE", SitioBase.Session.ClienteId(),
                                             "@TEXTO", texto, "@MODULO", Nulo(modulo), "@PANTALLA", Nulo(pantalla))
        });
    }

    /// <summary>Planta y perfil de la persona, para el contexto del reporte.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cabecera()
    {
        return Ejecutar(() => SoporteDatos.Fila("SEL_SOPORTE_CABECERA", "@USUARIO", U(), "@CLIENTE", SitioBase.Session.ClienteId()));
    }

    /// <summary>Personas del cliente en sesion, para reportar en nombre de alguien.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Usuarios()
    {
        return Ejecutar(() => new { usuarios = SoporteDatos.Filas("SEL_SOPORTE_USUARIOS_CLIENTE", "@USUARIO", U(), "@CLIENTE", SitioBase.Session.ClienteId()) });
    }

    /* ---------------- Atender ---------------- */

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Evento(int ticket, string tipo, string texto, int contenido)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("INS_SOPORTE_EVENTO", "@TICKET", ticket, "@USUARIO", U(), "@TIPO", tipo, "@TEXTO", texto,
                              "@CONTENIDO", contenido > 0 ? (object)contenido : null);
            return new { ok = true };
        });
    }

    /// <summary>
    /// Adjunta un archivo al ticket. Va al blob con el cliente DEL TICKET, no
    /// el de la sesion: el agente atiende tickets de cualquier cliente.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Adjuntar(int ticket, string nombre, string mime, string base64)
    {
        return Ejecutar(() =>
        {
            /* Antes de subir nada: que la persona pueda tocar el ticket. */
            List<Dictionary<string, object>> acceso = SoporteDatos.Filas("SEL_SOPORTE_TICKET_ACCESO", "@TICKET", ticket, "@USUARIO", U());
            if (acceso.Count == 0) throw new Exception("Ese problema no existe.");
            int cliente = Convert.ToInt32(acceso[0]["stk_cliente"]);

            byte[] crudo = Convert.FromBase64String(base64 ?? "");
            int id = SoporteDatos.SubirArchivo(cliente, "global/soporte-tickets", nombre, mime, base64, 25);
            SoporteDatos.Fila("INS_SOPORTE_EVENTO", "@TICKET", ticket, "@USUARIO", U(), "@TIPO", "file",
                              "@ARCHIVO", id, "@ARCHIVO_NOMBRE", nombre, "@ARCHIVO_BYTE", (long)crudo.Length);
            return new { id = id, url = UrlArchivo.Ver(id) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Estado(int ticket, string estado, string nota)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_SOPORTE_TICKET_ESTADO", "@TICKET", ticket, "@USUARIO", U(), "@ESTADO", estado, "@NOTA", nota);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Asignar(int ticket, int responsable, int area)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_SOPORTE_TICKET_ASIGNAR", "@TICKET", ticket, "@USUARIO", U(), "@RESPONSABLE", responsable,
                              "@AREA", area > 0 ? (object)area : null);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Prioridad(int ticket, string prioridad)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_SOPORTE_TICKET_PRIORIDAD", "@TICKET", ticket, "@USUARIO", U(), "@PRIORIDAD", prioridad);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Vincular(int ticket, int recurrente)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_SOPORTE_TICKET_VINCULAR", "@TICKET", ticket, "@USUARIO", U(), "@RECURRENTE", recurrente);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Encuesta(int ticket, string respuesta, int estrellas, string comentario, bool reabrir)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("INS_SOPORTE_ENCUESTA", "@TICKET", ticket, "@USUARIO", U(), "@RESPUESTA", respuesta,
                              "@ESTRELLAS", estrellas, "@COMENTARIO", comentario, "@REABRIR", reabrir);
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Agentes()
    {
        return Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_SOPORTE_AGENTES", "@USUARIO", U());
            return new { agentes = SoporteDatos.Del(c, 0), areas = SoporteDatos.Del(c, 1), yo = U() };
        });
    }

    /* ---------------- Inicio, analitica y recurrentes ---------------- */

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Resumen()
    {
        return Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_SOPORTE_RESUMEN", "@USUARIO", U());
            return new
            {
                mesa = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null,
                actividad = SoporteDatos.Del(c, 1),
                campanas = SoporteDatos.Del(c, 2).Count > 0 ? SoporteDatos.Del(c, 2)[0] : null,
                ayuda = SoporteDatos.Del(c, 3).Count > 0 ? SoporteDatos.Del(c, 3)[0] : null,
                ayudaTop = SoporteDatos.Del(c, 4).Count > 0 ? SoporteDatos.Del(c, 4)[0] : null,
                ayudaReciente = SoporteDatos.Del(c, 5).Count > 0 ? SoporteDatos.Del(c, 5)[0] : null,
                recurrentes = SoporteDatos.Filas("SEL_SOPORTE_RECURRENTES", "@USUARIO", U())
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Analitica(int dias)
    {
        return Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_SOPORTE_ANALITICA", "@USUARIO", U(), "@DIAS", dias);
            return new
            {
                kpi = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null,
                dias = SoporteDatos.Del(c, 1),
                modulos = SoporteDatos.Del(c, 2),
                clientes = SoporteDatos.Del(c, 3),
                categorias = SoporteDatos.Del(c, 4),
                prioridades = SoporteDatos.Del(c, 5),
                responsables = SoporteDatos.Del(c, 6),
                recurrentes = SoporteDatos.Filas("SEL_SOPORTE_RECURRENTES", "@USUARIO", U())
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Recurrente(int id)
    {
        return Ejecutar(() =>
        {
            var c = SoporteDatos.Conjuntos("SEL_SOPORTE_RECURRENTE", "@ID", id, "@USUARIO", U());
            return new
            {
                recurrente = SoporteDatos.Del(c, 0).Count > 0 ? SoporteDatos.Del(c, 0)[0] : null,
                semanas = SoporteDatos.Del(c, 1),
                donde = SoporteDatos.Del(c, 2),
                tickets = SoporteDatos.Del(c, 3)
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Recurrentes()
    {
        return Ejecutar(() => new { recurrentes = SoporteDatos.Filas("SEL_SOPORTE_RECURRENTES", "@USUARIO", U()) });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarRecurrente(int id, string causa)
    {
        return Ejecutar(() =>
        {
            SoporteDatos.Fila("UPD_SOPORTE_RECURRENTE", "@ID", id, "@CAUSA", causa, "@CONTENIDO", null, "@USUARIO", U());
            return new { ok = true };
        });
    }

    /* ---------------- Utilidades ---------------- */

    private static int U() { return SoporteDatos.Usuario(); }

    private static object Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

    private static string Texto(Dictionary<string, object> d, string k)
    {
        object v;
        return d.TryGetValue(k, out v) && v != null ? Convert.ToString(v).Trim() : null;
    }

    private static int Entero(Dictionary<string, object> d, string k)
    {
        object v; int n;
        if (!d.TryGetValue(k, out v) || v == null) return 0;
        if (v is bool) return (bool)v ? 1 : 0;
        return int.TryParse(Convert.ToString(v), out n) ? n : 0;
    }

    internal static string Ejecutar(Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            return Json(accion());
        }
        catch (Exception ex)
        {
            return Json(new { error = true, detalle = ex.Message });
        }
    }

    internal static string Json(object o)
    {
        return new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Serialize(o);
    }
}
