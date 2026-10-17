using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Centro Comercial (15-10-2026): leads, demos, propuestas, contratos,
/// reuniones y clientes concretados. Lo pinta sigma-centro-comercial.js.
/// Prompt: MD/PROMPT_CLAUDE_IMPLEMENTAR_CENTRO_COMERCIAL.md.
///
/// CADA MÉTODO VALIDA SESIÓN Y PERMISO
///   Por facultad, no por perfil: VER CENTRO COMERCIAL para leer,
///   GESTIONAR LEADS / DEMOS / PROPUESTAS para escribir. El id del lead
///   identifica; los SP vuelven a comprobar el estado antes de escribir.
///
/// TRES MÉTODOS SON PÚBLICOS
///   CrearLeadPublico (formulario de Inicio.aspx), ContratoPorToken y
///   FirmarContrato (Firma.aspx). No piden sesión: los protege el honeypot,
///   el límite por IP y el token de un solo uso con vencimiento.
///
/// LOS CORREOS NO DESHACEN NADA
///   Si el SMTP falla, la acción ya quedó hecha; la respuesta trae
///   correo = false y la pantalla lo dice.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsComercial : System.Web.Services.WebService
{
    private const string P_VER = "VER CENTRO COMERCIAL";
    private const string P_LEADS = "GESTIONAR LEADS";
    private const string P_DEMOS = "GESTIONAR DEMOS";
    private const string P_PROP = "GESTIONAR PROPUESTAS";

    // =====================================================================
    // LECTURAS
    // =====================================================================

    /// <summary>Los ejecutivos comerciales (perfiles Gerente Comercial y Ejecutivo Comercial) con su foto y su perfil.</summary>
    private static List<Dictionary<string, object>> Ejecutivos()
    {
        List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_LEAD_EJECUTIVOS");
        foreach (Dictionary<string, object> f in l)
        {
            int foto = f["FOTO_ID"] == null ? 0 : Convert.ToInt32(f["FOTO_ID"]);
            // Sin foto propia: el avatar de ejecutivo (Imagen/avatares/ejecutivo.png) hasta que la persona suba la suya en Cliente › Usuarios.
            f["FOTO"] = foto > 0 ? SitioBase.UrlArchivo.Ver(foto) : System.Web.VirtualPathUtility.ToAbsolute("~/Imagen/avatares/ejecutivo.png");
        }
        return l;
    }

    /// <summary>Lo que la pantalla pide una vez: catálogo, ejecutivos, límites por defecto y permisos.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Iniciar()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<List<Dictionary<string, object>>> cat = SoporteDatos.Conjuntos("SEL_COMERCIAL_CATALOGO");
            Dictionary<string, object> uf = SoporteDatos.Del(cat, 1).FirstOrDefault();
            return new
            {
                planes = SoporteDatos.Del(cat, 0),
                uf = uf != null && uf["UF"] != null ? uf["UF"] : null,
                ejecutivos = Ejecutivos(),
                paises = SoporteDatos.Filas("SEL_COBRO_PAISES"),
                modulos = Comercial.MODULOS.Select(m => new { id = m[0], n = m[1] }).ToList(),
                demo = new { dias = Entero(Comercial.Parametro("COMERCIAL_DEMO_DIAS", "7"), 7), limites = LimitesDemo() },
                permisos = Permisos(),
                administrar = Administrar(),
                usuario = U(),
                hoy = Hora.Hoy.ToString("yyyy-MM-dd"),
                ahora = Hora.Ahora.ToString("yyyy-MM-dd HH:mm")
            };
        });
    }

    /// <summary>Todos los leads (el navegador filtra y cuenta). Antes, deja constancia de las demos vencidas.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Centro()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            try { SoporteDatos.Filas("UPD_LEAD_DEMO_VENCER"); } catch (Exception ex) { Correo.Registrar("WsComercial.Centro vencer", ex.Message); }
            return new { leads = SoporteDatos.Filas("SEL_LEAD_CENTRO"), ahora = Hora.Ahora.ToString("yyyy-MM-dd HH:mm"), hoy = Hora.Hoy.ToString("yyyy-MM-dd") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Clientes()
    {
        return Ejecutar(() => { Exigir(P_VER); return new { clientes = SoporteDatos.Filas("SEL_COMERCIAL_CLIENTES") }; });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ficha(int lead)
    {
        return Ejecutar(() => { Exigir(P_VER); return ArmarFicha(lead); });
    }

    /// <summary>El PDF de una propuesta o de un contrato, para verlo en el navegador.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string VerPdf(string tipo, int id)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            Dictionary<string, object> f = tipo == "propuesta"
                ? SoporteDatos.Fila("SEL_PROPUESTA_PDF", "@ID", id)
                : SoporteDatos.Fila("SEL_CONTRATO_PDF", "@ID", id, "@FIRMADO", tipo == "firmado");
            byte[] pdf = f.ContainsKey("PDF") ? f["PDF"] as byte[] : null;
            if (pdf == null || pdf.Length == 0) throw new Exception("El documento todavía no está generado.");
            string nombre = (tipo == "propuesta" ? "Propuesta" : tipo == "firmado" ? "Contrato_Firmado" : "Contrato") + "_SIGMA_" +
                            Archivo(Comercial.Txt(f, "EMPRESA")) + "_v" + Comercial.Txt(f, "VERSION") + ".pdf";
            return new { nombre = nombre, base64 = Convert.ToBase64String(pdf) };
        });
    }

    /// <summary>
    /// Las vistas de «Suscripciones» y «Clientes» del Centro (lo que antes eran
    /// seis menús, bloque 459). Reutiliza los controladores de esas pantallas;
    /// cada fila trae el query cifrado de su ficha, que se abre con SigmaModal
    /// igual que en el Centro de Planificación. Sin filtro por cliente en
    /// sesión: el Centro Comercial es de la plataforma.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Administracion(string vista)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            Func<int, string> q = id => HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id));
            Func<DateTime?, string> f = d => d.HasValue ? d.Value.ToString("yyyy-MM-dd") : null;
            Func<string, bool> puede = url => Token.PuedePagina(url);
            switch (vista)
            {
                case "suscripciones":
                    if (!puede("~/View/Comercial/Suscripciones/Suscripciones.aspx")) throw new Exception("No tienes la facultad para ver suscripciones.");
                    return new
                    {
                        filas = (new SuscripcionController().GetSuscripciones(new SitioBase.Model.Suscripcion()) ?? new List<SitioBase.Model.Suscripcion>())
                            .Select(s => new { id = s.sus_id, q = q(s.sus_id), cliente = s.cli_nombre, plan = s.plc_nombre, estado = s.estado ?? s.sue_nombre, estadoNombre = s.sue_nombre,
                                               desde = f(s.sus_fecha_inicio), hasta = f(s.sus_fecha_fin), dias = s.dias_restantes, opera = s.puede_operar, contacto = s.sus_contacto_nombre, correo = s.sus_contacto_email })
                            .OrderBy(x => x.cliente).ToList(),
                        ficha = VirtualPathUtility.ToAbsolute("~/View/Comercial/Suscripciones/Suscripcion.aspx")
                    };
                case "periodos":
                    if (!puede("~/View/Comercial/Suscripciones/Periodos.aspx")) throw new Exception("No tienes la facultad para ver períodos.");
                    return new
                    {
                        filas = (new SuscripcionPeriodoController().GetPeriodos(new SitioBase.Model.SuscripcionPeriodo()) ?? new List<SitioBase.Model.SuscripcionPeriodo>())
                            .Select(p => new { id = p.spe_id, q = q(p.spe_id), cliente = p.cli_nombre, plan = p.plc_nombre, cobro = p.pcb_nombre, desde = f(p.spe_fecha_inicio), hasta = f(p.spe_fecha_fin),
                                               uf = p.spe_valor_uf_plan, monto = p.spe_monto_clp, pagado = p.spe_monto_pagado_clp, saldo = p.saldo_clp, estado = p.spd_nombre, implantacion = p.spe_es_implantacion })
                            .OrderByDescending(x => x.desde).ToList(),
                        ficha = VirtualPathUtility.ToAbsolute("~/View/Comercial/Suscripciones/Periodo.aspx")
                    };
                case "pagos":
                    if (!puede("~/View/Comercial/Suscripciones/Pagos.aspx")) throw new Exception("No tienes la facultad para ver pagos.");
                    return new
                    {
                        filas = (new SuscripcionPagoController().GetPagos(new SitioBase.Model.SuscripcionPago()) ?? new List<SitioBase.Model.SuscripcionPago>())
                            .Select(p => new { id = p.spa_id, q = q(p.spa_id), cliente = p.cli_nombre, fecha = f(p.spa_fecha_transferencia), declarado = p.spa_monto_declarado_clp,
                                               verificado = p.spa_monto_verificado_clp, banco = p.spa_banco, operacion = p.spa_numero_operacion, estado = p.spo_nombre, codigo = p.spo_codigo,
                                               periodo = f(p.spe_fecha_inicio), motivo = p.spa_motivo_rechazo })
                            .OrderByDescending(x => x.fecha).ToList(),
                        ficha = VirtualPathUtility.ToAbsolute("~/View/Comercial/Suscripciones/Pago.aspx")
                    };
                case "planes":
                    if (!puede("~/View/Comercial/Suscripciones/Planes.aspx")) throw new Exception("No tienes la facultad para ver planes.");
                    return new
                    {
                        filas = (new PlanComercialController().GetPlanesDistintos(false) ?? new List<SitioBase.Model.PlanComercial>())
                            .Select(p => new { id = p.plc_id, q = q(p.plc_id), codigo = p.plc_codigo, nombre = p.plc_nombre, descripcion = p.plc_descripcion, publico = p.plc_publico,
                                               habilitado = p.plc_habilitado, gracia = p.plc_dias_gracia, orden = p.plc_orden })
                            .OrderBy(x => x.orden).ThenBy(x => x.nombre).ToList(),
                        ficha = VirtualPathUtility.ToAbsolute("~/View/Comercial/Suscripciones/Plan.aspx"),
                        crear = Token.Puede("CREAR EDITAR PLANES COMERCIALES")
                    };
                case "empresas":
                    if (!puede("~/View/Comercial/Clientes/Clientes.aspx")) throw new Exception("No tienes la facultad para ver clientes.");
                    return new
                    {
                        filas = (new ClienteController().GetClientes(new SitioBase.Model.Cliente { filtro_paises = SitioBase.Session.UsuarioIdPaises(), tipo_perfil = 1 }) ?? new List<SitioBase.Model.Cliente>())
                            .Select(c => new { id = c.cli_id, q = q(c.cli_id), nombre = c.cli_nombre, razon = c.cli_razon_social, rut = c.cli_identificador, habilitado = c.cli_habilitado,
                                               desde = c.cli_fecha_creacion == DateTime.MinValue ? null : c.cli_fecha_creacion.ToString("yyyy-MM-dd") })
                            .OrderBy(x => x.nombre).ToList(),
                        ficha = VirtualPathUtility.ToAbsolute("~/View/Comercial/Clientes/Cliente.aspx"),
                        crear = Token.Puede("CREAR EDITAR CLIENTES")
                    };
            }
            throw new Exception("Vista desconocida.");
        });
    }

    /// <summary>Total en vivo de una propuesta. Mismo cálculo que el SP, el PDF y el navegador.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CalcularPropuesta(decimal implementacion, decimal mensual, decimal descuento, int vigencia)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            return new { mensualNeta = Comercial.MensualNeta(mensual, descuento), total = Comercial.Total(implementacion, mensual, descuento, vigencia) };
        });
    }

    // =====================================================================
    // LEAD
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CrearLead(string empresa, string contacto, string cargo, string correo, string telefono, string mensaje,
                            int? pais, string identificador, string activos, string intereses, string origen, int? ejecutivo, string proxTipo, string proxTexto, string proxFecha)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            Dictionary<string, object> o = Sp("INS_LEAD_PUBLICO", new[] { "@ID", "@CODIGO" },
                "@EMPRESA", empresa, "@CONTACTO", contacto, "@CARGO", cargo, "@CORREO", correo, "@TELEFONO", telefono,
                "@PAIS_ID", pais, "@IDENTIFICADOR", string.IsNullOrWhiteSpace(identificador) ? null : identificador.Trim(),
                "@N_ACTIVOS", Corta(activos, 40), "@INTERESES", Corta(intereses, 500),
                "@MENSAJE", mensaje, "@CONSENTIMIENTO", false, "@ORIGEN", "MANUAL", "@USUARIO", U());
            int id = Convert.ToInt32(o["@ID"]);
            // Quien lo crea queda de ejecutivo; si eligió a otra persona, se reasigna.
            if (ejecutivo.HasValue && ejecutivo.Value > 0 && ejecutivo.Value != U())
                Sp("UPD_LEAD_EJECUTIVO", null, "@LEAD", id, "@EJECUTIVO", ejecutivo.Value, "@USUARIO", U());
            DateTime? pf = FechaHora(proxFecha);
            if (pf.HasValue && !string.IsNullOrWhiteSpace(proxTipo))
                Sp("UPD_LEAD_PROXIMA_ACCION", null, "@LEAD", id, "@TIPO", proxTipo, "@TEXTO", Corta(proxTexto, 200), "@FECHA", pf.Value, "@USUARIO", U());
            if (!string.IsNullOrWhiteSpace(origen))
                Sp("INS_LEAD_ACTIVIDAD", new[] { "@ID" }, "@LEAD", id, "@TIPO", "NOTA", "@ICONO", "note", "@TITULO", "Origen: " + Corta(origen, 60), "@DETALLE", "Registrado a mano desde el Centro Comercial", "@USUARIO", U());
            return new { lead = o["@ID"], codigo = o["@CODIGO"] };
        });
    }

    /// <summary>
    /// ¿El dominio del correo ya está en otro lead o en un cliente? Es un aviso, no un bloqueo:
    /// dos personas de una misma empresa pueden pedir una demo. Los dominios de correo gratuito no cuentan.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string DominioExistente(string correo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            return new { filas = SoporteDatos.Filas("SEL_LEAD_DOMINIO", "@CORREO", correo ?? "") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarDatos(int lead, string empresa, string rut, string rubro, string contacto, string cargo, string correo, string telefono, string intereses, int? pais)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            /* El identificador se valida en el SP según el país (solo el RUT chileno lleva dígito verificador).
               Para Chile se normaliza igual que siempre. */
            string ident = string.IsNullOrWhiteSpace(rut) ? null : (pais.GetValueOrDefault(1) == 1 ? Comercial.RutNormal(rut) : rut.Trim());
            Sp("UPD_LEAD_DATOS", null, "@LEAD", lead, "@EMPRESA", empresa, "@PAIS_ID", pais, "@IDENTIFICADOR", ident,
               "@RUBRO", rubro, "@CONTACTO", contacto, "@CARGO", cargo, "@CORREO", correo, "@TELEFONO", telefono, "@INTERESES", intereses, "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AsignarEjecutivo(int lead, int ejecutivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            Sp("UPD_LEAD_EJECUTIVO", null, "@LEAD", lead, "@EJECUTIVO", ejecutivo, "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CambiarEstado(int lead, string estado, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            Sp("UPD_LEAD_ESTADO", null, "@LEAD", lead, "@ESTADO", estado, "@MOTIVO", motivo, "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RegistrarActividad(int lead, string tipo, string detalle)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            string[] tipos = { "LLAMADA", "EMAIL", "REUNION", "NOTA" };
            if (!tipos.Contains(tipo)) throw new Exception("Elige el tipo de actividad.");
            if (string.IsNullOrWhiteSpace(detalle)) throw new Exception("Escribe qué pasó.");
            string titulo = tipo == "LLAMADA" ? "Llamada" : tipo == "EMAIL" ? "Email" : tipo == "REUNION" ? "Reunión" : "Nota";
            string icono = tipo == "LLAMADA" ? "phone" : tipo == "EMAIL" ? "mail" : tipo == "REUNION" ? "users" : "note";
            Sp("INS_LEAD_ACTIVIDAD", new[] { "@ID" }, "@LEAD", lead, "@TIPO", tipo, "@TITULO", titulo, "@DETALLE", detalle.Trim(), "@ICONO", icono, "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarProximaAccion(int lead, string tipo, string texto, string fecha)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            Sp("UPD_LEAD_PROXIMA_ACCION", null, "@LEAD", lead, "@TIPO", tipo, "@TEXTO", texto, "@FECHA", FechaHora(fecha), "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    // =====================================================================
    // DEMO
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CrearDemo(int lead, int dias, string modulos, Dictionary<string, object> limites)
    {
        return Ejecutar(() =>
        {
            Exigir(P_DEMOS);
            Func<string, int> L = k => { object v; return limites != null && limites.TryGetValue(k, out v) ? Convert.ToInt32(v) : 0; };
            string clave = Comercial.ClaveTemporal();
            Dictionary<string, object> o = Sp("INS_LEAD_DEMO", new[] { "@ID", "@CLIENTE", "@USUARIO_DEMO" },
                "@LEAD", lead, "@DIAS", dias, "@MODULOS", modulos,
                "@LIM_USUARIOS", L("usuarios"), "@LIM_ACTIVOS", L("activos"), "@LIM_OT", L("ot"), "@LIM_PROGRAMACIONES", L("programaciones"),
                "@LIM_CHECKLISTS", L("checklists"), "@LIM_REPUESTOS", L("repuestos"), "@LIM_BODEGAS", L("bodegas"), "@LIM_PLANTAS", L("plantas"),
                "@CLAVE_TEMPORAL", clave, "@KEY_TEXTO", Comercial.ClaveSuscripcion(), "@USUARIO", U());
            Dictionary<string, object> f = ArmarFicha(lead);
            bool enviado = CorreoCredenciales(f, clave, false);
            return new { ficha = f, correo = enviado };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ExtenderDemo(int lead, int dias)
    {
        return Ejecutar(() =>
        {
            Exigir(P_DEMOS);
            Sp("UPD_LEAD_DEMO_EXTENDER", null, "@LEAD", lead, "@DIAS", dias, "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ReenviarCredenciales(int lead)
    {
        return Ejecutar(() =>
        {
            Exigir(P_DEMOS);
            string clave = Comercial.ClaveTemporal();
            Sp("UPD_LEAD_DEMO_CLAVE", new[] { "@CORREO" }, "@LEAD", lead, "@CLAVE_TEMPORAL", clave, "@USUARIO", U());
            Dictionary<string, object> f = ArmarFicha(lead);
            return new { ficha = f, correo = CorreoCredenciales(f, clave, true) };
        });
    }

    // =====================================================================
    // PROPUESTA
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarPropuesta(int lead, Dictionary<string, object> p, bool enviar)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROP);
            Func<string, object> V = k => { object v; return p != null && p.TryGetValue(k, out v) ? v : null; };
            Func<string, object> N = k => { object v = V(k); return v == null || v.ToString().Trim() == "" ? null : (object)Convert.ToInt32(v, CultureInfo.InvariantCulture); };
            Func<string, decimal> D = k => { object v = V(k); return v == null || v.ToString().Trim() == "" ? 0 : Convert.ToDecimal(v, CultureInfo.InvariantCulture); };
            string tipo = Convert.ToString(V("tipo")) == "PERSONALIZADA" ? "PERSONALIZADA" : "ESTANDAR";
            Dictionary<string, object> o = Sp("INS_PROPUESTA", new[] { "@ID", "@VERSION" },
                "@LEAD", lead, "@TIPO", tipo, "@PLAN_COMERCIAL", tipo == "ESTANDAR" ? N("plan") : null,
                "@NOMBRE_PLAN", Convert.ToString(V("nombre")), "@MODULOS", Convert.ToString(V("modulos")),
                "@LIM_USUARIOS", N("usuarios"), "@LIM_ACTIVOS", N("activos"), "@LIM_PLANTAS", N("plantas"), "@LIM_BODEGAS", N("bodegas"), "@LIM_GB", N("gb"),
                "@IMPLEMENTACION_UF", D("implementacion"), "@MENSUAL_UF", D("mensual"), "@DESCUENTO_PCT", D("descuento"),
                "@VIGENCIA_MESES", N("vigencia") ?? 12, "@CONDICIONES", Convert.ToString(V("condiciones")), "@USUARIO", U());
            int id = Convert.ToInt32(o["@ID"]);
            GenerarPdfPropuesta(lead, id);
            bool correo = true;
            if (enviar) correo = EnviarPropuestaInterna(lead, id);
            return new { ficha = ArmarFicha(lead), propuesta = id, correo = correo };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EnviarPropuesta(int lead, int propuesta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROP);
            bool correo = EnviarPropuestaInterna(lead, propuesta);
            return new { ficha = ArmarFicha(lead), correo = correo };
        });
    }

    // =====================================================================
    // CONTRATO
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GenerarContrato(int lead, int propuesta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROP);
            Dictionary<string, object> o = Sp("INS_CONTRATO", new[] { "@ID", "@VERSION" }, "@LEAD", lead, "@PROPUESTA", propuesta, "@USUARIO", U());
            int id = Convert.ToInt32(o["@ID"]), version = Convert.ToInt32(o["@VERSION"]);
            List<List<Dictionary<string, object>>> fi = SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", lead);
            Dictionary<string, object> l = SoporteDatos.Del(fi, 0).First();
            Dictionary<string, object> p = SoporteDatos.Del(fi, 3).First(x => Convert.ToInt32(x["ID"]) == propuesta);
            byte[] pdf = Comercial.PdfContrato(l, p, version);
            Sp("UPD_CONTRATO_PDF", null, "@ID", id, "@PDF", pdf, "@SHA256", Comercial.Sha256(pdf));
            bool correo = EnviarContratoInterno(id, l, p);
            return new { ficha = ArmarFicha(lead), contrato = id, correo = correo };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ReenviarContrato(int lead, int contrato)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROP);
            List<List<Dictionary<string, object>>> fi = SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", lead);
            Dictionary<string, object> l = SoporteDatos.Del(fi, 0).First();
            Dictionary<string, object> c = SoporteDatos.Del(fi, 4).FirstOrDefault(x => Convert.ToInt32(x["ID"]) == contrato);
            if (c == null) throw new Exception("El contrato no es de este lead.");
            Dictionary<string, object> p = SoporteDatos.Del(fi, 3).First(x => Convert.ToInt32(x["ID"]) == Convert.ToInt32(c["PROPUESTA"]));
            bool correo = EnviarContratoInterno(contrato, l, p);
            return new { ficha = ArmarFicha(lead), correo = correo };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AnularContrato(int lead, int contrato, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROP);
            Sp("UPD_CONTRATO_ANULAR", null, "@ID", contrato, "@MOTIVO", motivo, "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    // =====================================================================
    // REUNIONES (Jitsi Meet: la sala vive fuera de SIGMA, sin costo)
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string NuevaSala(string empresa)
    {
        return Ejecutar(() => { Exigir(P_LEADS); return new { enlace = Comercial.SalaJitsi(empresa) }; });
    }

    /// <summary>
    /// Agenda la reunión y manda el correo L5 con la invitación .ics a cada
    /// participante. Quien organiza recibe copia.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AgendarReunion(int lead, string inicio, int duracion, string lugar, string enlace, string direccion, string motivo, List<Dictionary<string, object>> participantes)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            DateTime? ini = FechaHora(inicio);
            if (ini == null) throw new Exception("Elige la fecha y la hora.");
            string[] lugares = { "VIDEO", "PRESENCIAL", "TELEFONO" };
            if (!lugares.Contains(lugar)) throw new Exception("Elige dónde será la reunión.");
            if (duracion != 30 && duracion != 45 && duracion != 60) duracion = 30;

            Dictionary<string, object> yo = SoporteDatos.Filas("SEL_LEAD_EJECUTIVOS").FirstOrDefault(x => Convert.ToInt32(x["ID"]) == U());
            string yoNombre = yo != null ? Comercial.Txt(yo, "NOMBRE") : "Código Creativo";
            string yoCorreo = yo != null ? Comercial.Txt(yo, "CORREO") : Comercial.Parametro("COMERCIAL_CORREO_AVISO", "comercial@codigocreativo.tech");
            List<object> lista = (participantes ?? new List<Dictionary<string, object>>())
                .Where(x => x != null && x.ContainsKey("c") && Convert.ToString(x["c"]).Contains("@"))
                .Select(x => (object)new Dictionary<string, object> { { "n", Convert.ToString(x.ContainsKey("n") ? x["n"] : "") }, { "c", Convert.ToString(x["c"]).Trim() }, { "o", 0 } })
                .ToList();
            if (!string.IsNullOrEmpty(yoCorreo)) lista.Add(new Dictionary<string, object> { { "n", yoNombre }, { "c", yoCorreo }, { "o", 1 } });

            SqlCommand cmd = Conexion.GetCommand("INS_REUNION");
            List<Dictionary<string, object>> creados = new List<Dictionary<string, object>>();
            int id;
            try
            {
                SqlParameter pid = cmd.Parameters.Add("@ID", SqlDbType.Int); pid.Direction = ParameterDirection.Output;
                cmd.Parameters.AddWithValue("@LEAD", lead);
                cmd.Parameters.AddWithValue("@INICIO", ini.Value);
                cmd.Parameters.AddWithValue("@DURACION", duracion);
                cmd.Parameters.AddWithValue("@LUGAR", lugar);
                cmd.Parameters.AddWithValue("@ENLACE", (object)enlace ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@DIRECCION", (object)direccion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@MOTIVO", (object)motivo ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@PARTICIPANTES", new JavaScriptSerializer().Serialize(lista));
                cmd.Parameters.AddWithValue("@USUARIO", U());
                using (SqlDataReader dr = cmd.ExecuteReader())
                    while (dr.Read())
                        creados.Add(new Dictionary<string, object> { { "ID", dr.GetInt32(0) }, { "NOMBRE", dr.IsDBNull(1) ? "" : dr.GetString(1) }, { "CORREO", dr.GetString(2) }, { "ORG", dr.GetBoolean(3) } });
                id = Convert.ToInt32(pid.Value);
            }
            finally { if (cmd.Connection != null) cmd.Connection.Close(); }

            Dictionary<string, object> l = SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", lead), 0).First();
            string cuando = ini.Value.ToString("dddd dd/MM/yyyy · HH:mm", Comercial.CL) + " a " + ini.Value.AddMinutes(duracion).ToString("HH:mm", Comercial.CL);
            string donde = lugar == "VIDEO" ? (enlace.Contains("meet.jit.si") ? "Jitsi Meet (desde el navegador, sin cuenta ni instalar nada)" : enlace)
                         : lugar == "PRESENCIAL" ? direccion : "Por teléfono · " + Comercial.Txt(l, "TELEFONO");
            string titulo = "Reunión SIGMA · " + Comercial.Txt(l, "EMPRESA") + " · " + ini.Value.ToString("ddd dd/MM HH:mm", Comercial.CL);
            byte[] ics = Comercial.Ics(id, ini.Value, duracion, titulo, (motivo ?? "") + (lugar == "VIDEO" ? "\nEnlace: " + enlace : ""),
                                       lugar == "VIDEO" ? enlace : lugar == "PRESENCIAL" ? direccion : "Teléfono",
                                       lugar == "VIDEO" ? enlace : null, yoNombre, yoCorreo,
                                       creados.Select(c => new KeyValuePair<string, string>(Convert.ToString(c["NOMBRE"]), Convert.ToString(c["CORREO"]))));
            int enviados = 0;
            foreach (Dictionary<string, object> c in creados)
            {
                string prim = Comercial.Primero(Convert.ToString(c["NOMBRE"]));
                string html = Correo.Plantilla(new Correo.Pieza
                {
                    Pre = Convert.ToBoolean(c["ORG"]) ? "Reunión · tu copia" : "Reunión",
                    Titulo = "Conversemos sobre " + (string.IsNullOrEmpty(motivo) ? "SIGMA" : motivo.ToLower(Comercial.CL)),
                    Texto = (prim != "" ? Correo.Html(prim) + ", " : "") + Correo.Html(yoNombre) + " te invita a conversar con Código Creativo sobre " +
                            Correo.Html(Comercial.Txt(l, "EMPRESA")) + ".",
                    Detalles = new[] { "Cuándo", cuando, "Dónde", donde, "Con", yoNombre + " · Código Creativo" },
                    Boton = lugar == "VIDEO" ? "Unirme a la reunión" : null, Enlace = lugar == "VIDEO" ? enlace : null,
                    Cierre = "Adjuntamos la invitación (.ics) para tu calendario. ¿No puedes? Responde este correo y buscamos otro horario.",
                    Pie = "Recibes este correo porque estás en conversaciones con Código Creativo."
                });
                if (Correo.Enviar(Convert.ToString(c["CORREO"]), titulo, html, new Correo.Adjunto("invitacion-sigma.ics", "text/calendar; method=REQUEST; charset=utf-8", ics)))
                {
                    enviados++;
                    Sp("UPD_REUNION_INVITACION", null, "@PARTICIPANTE", Convert.ToInt32(c["ID"]));
                }
            }
            return new { ficha = ArmarFicha(lead), reunion = id, enviados = enviados, total = creados.Count };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RegistrarReunion(int lead, int reunion, string notas, string resumen, List<Dictionary<string, object>> acuerdos, string objecion,
                                   Dictionary<string, object> datosPropuesta, string proxTipo, string proxTexto, string proxFecha)
    {
        return Ejecutar(() =>
        {
            Exigir(P_LEADS);
            JavaScriptSerializer js = new JavaScriptSerializer();
            Sp("UPD_REUNION_REGISTRAR", null, "@ID", reunion, "@NOTAS", notas, "@RESUMEN", resumen,
               "@ACUERDOS_JSON", acuerdos != null ? js.Serialize(acuerdos) : null, "@OBJECION", objecion,
               "@DATOS_PROPUESTA_JSON", datosPropuesta != null ? js.Serialize(datosPropuesta) : null,
               "@PROX_TIPO", proxTipo, "@PROX_TEXTO", proxTexto, "@PROX_FECHA", FechaHora(proxFecha), "@USUARIO", U());
            return ArmarFicha(lead);
        });
    }

    // =====================================================================
    // PÚBLICOS (sin sesión)
    // =====================================================================

    /// <summary>
    /// El formulario de Inicio.aspx. «web» es el honeypot: un campo oculto
    /// que una persona deja vacío y un robot llena. Si viene lleno se responde
    /// ok sin guardar nada, para no enseñarle al robot qué lo delató.
    /// </summary>
    [WebMethod(EnableSession = false)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CrearLeadPublico(string nombre, string apellido, string empresa, string rubro, string cargo, string correo, string telefono, string pais, string identificador,
                                   string activos, string plan, string mensaje, bool consentimiento, string web)
    {
        try
        {
            if (!string.IsNullOrEmpty(web)) return WsSoporte.Json(new { ok = true });
            string contacto = ((nombre ?? "").Trim() + " " + (apellido ?? "").Trim()).Trim();
            string ip = Ip();
            Dictionary<string, object> o = Sp("INS_LEAD_PUBLICO", new[] { "@ID", "@CODIGO" },
                "@EMPRESA", Corta(empresa, 200), "@CONTACTO", Corta(contacto, 200), "@RUBRO", Corta(rubro, 200), "@CARGO", Corta(cargo, 200), "@CORREO", Corta(correo, 200),
                "@TELEFONO", Corta(telefono, 50), "@PAIS", Corta(pais, 80), "@IDENTIFICADOR", string.IsNullOrWhiteSpace(identificador) ? null : Corta(identificador, 30), "@N_ACTIVOS", Corta(activos, 40), "@PLAN_INTERES", Corta(plan, 80),
                "@INTERESES", Corta(plan, 80), "@MENSAJE", Corta(mensaje, 2000), "@CONSENTIMIENTO", consentimiento, "@IP", ip, "@ORIGEN", "FORM_WEB");
            int id = Convert.ToInt32(o["@ID"]);
            bool aviso = CorreoLeadNuevo(id);
            if (aviso)
                try { Sp("INS_LEAD_ACTIVIDAD", new[] { "@ID" }, "@LEAD", id, "@TIPO", "SISTEMA", "@ICONO", "mail", "@TITULO", "Email a comercial",
                         "@DETALLE", "Aviso automático a " + Comercial.Parametro("COMERCIAL_CORREO_AVISO", "comercial@codigocreativo.tech")); }
                catch (Exception) { }
            return WsSoporte.Json(new { ok = true });
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) });
        }
    }

    /// <summary>
    /// Lo que la página de firma necesita para pintarse. La primera lectura
    /// de un enlace vigente marca el contrato VISUALIZADO.
    /// Estados: pendiente, firmado, vencido, usado, invalido.
    /// </summary>
    [WebMethod(EnableSession = false)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ContratoPorToken(string t)
    {
        try { return WsSoporte.Json(EstadoFirma(t, true)); }
        catch (Exception ex) { return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) }); }
    }

    /// <summary>
    /// Firma electrónica simple. Valida el RUT (módulo 11), que el enlace siga
    /// vigente y sin usar; calcula el SHA-256 del PDF que se leyó, guarda IP y
    /// navegador, y en la misma transacción concreta el lead y deja al cliente
    /// con su suscripción activa. Después, los correos (L4).
    /// </summary>
    [WebMethod(EnableSession = false)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string FirmarContrato(string t, string nombre, string rut, bool acepto)
    {
        try
        {
            if (!acepto) throw new Exception("Marca «He leído y acepto» para firmar.");
            if (string.IsNullOrWhiteSpace(nombre) || nombre.Trim().Length < 3) throw new Exception("Escribe tu nombre completo.");
            byte[] hash = Comercial.HashToken(t);
            Dictionary<string, object> c = SoporteDatos.Fila("SEL_CONTRATO_TOKEN", "@TOKEN_HASH", hash);
            if (!c.ContainsKey("ID")) throw new Exception("El enlace no es válido.");
            // Solo el RUT chileno se valida con dígito verificador; los demás identificadores, por formato y largo en el SP.
            bool chile = Convert.ToInt32(c["PAIS_ID"]) == 1;
            if (chile && !Comercial.RutValido(rut)) throw new Exception("El RUT no es válido. Revisa el dígito verificador.");
            if (!chile && (string.IsNullOrWhiteSpace(rut) || rut.Trim().Length < 4)) throw new Exception("Escribe tu " + Comercial.Txt(c, "IDENT_ETIQUETA") + ".");
            int id = Convert.ToInt32(c["ID"]);

            Dictionary<string, object> doc = SoporteDatos.Fila("SEL_CONTRATO_PDF", "@ID", id, "@FIRMADO", false);
            byte[] original = doc["PDF"] as byte[];
            string sha = Comercial.Sha256(original);
            if (!string.Equals(sha, Comercial.Txt(c, "PDF_SHA256"), StringComparison.OrdinalIgnoreCase))
                throw new Exception("El documento no coincide con el que se envió. Pide un enlace nuevo a tu ejecutivo.");

            string ip = Ip(), ua = Corta(HttpContext.Current.Request.UserAgent, 500), rutN = chile ? Comercial.RutNormal(rut) : rut.Trim().ToUpperInvariant(), nom = nombre.Trim();
            DateTime fecha = Hora.Ahora;
            string firmaHash = Comercial.Sha256(id + "|" + sha + "|" + nom + "|" + rutN + "|" + fecha.ToString("yyyy-MM-ddTHH:mm:ss") + "|" + ip + "|" + ua);
            byte[] firmado = Comercial.PdfFirmado(original, sha, c, nom, rutN, fecha, ip, ua, firmaHash);
            string clave = Comercial.ClaveTemporal();

            Dictionary<string, object> o = Sp("UPD_CONTRATO_FIRMAR", new[] { "@CLIENTE", "@USUARIO_NUEVO" },
                "@ID", id, "@TOKEN_HASH", hash, "@NOMBRE", nom, "@RUT", rutN, "@IP", ip, "@USER_AGENT", ua, "@FIRMA_HASH", firmaHash,
                "@PDF_FIRMADO", firmado, "@PDF_FIRMADO_SHA256", Comercial.Sha256(firmado), "@KEY_TEXTO", Comercial.ClaveSuscripcion(),
                "@CLAVE_TEMPORAL", clave);

            bool correo = CorreoFirmado(c, firmado, nom, fecha, o["@USUARIO_NUEVO"] != null ? clave : null);

            /* Bloque 462: firmar y pagar en el mismo paso. Se emiten la
               implementación y la primera mensualidad, sale el correo de cobro
               (con copia al ejecutivo) y la página ofrece «Pagar ahora». Si algo
               de esto falla, la firma ya quedó hecha: se registra y sigue. */
            string pagar = null, pagarTexto = null; bool pagarUsd = false;
            try
            {
                int sus = Cobros.SuscripcionDeCliente(Convert.ToInt32(o["@CLIENTE"]));
                if (sus > 0)
                {
                    Cobros.EmitirInicial(sus);
                    pagar = Cobros.EnlacePago(sus);
                    Cobros.Estado est = Cobros.Leer(sus);
                    pagarUsd = est.EsUsd; pagarTexto = Cobros.Monto(est.Total, est.EsUsd);
                    Cobros.CorreoCobro(sus, "COBRO");
                }
            }
            catch (Exception ex) { Correo.Registrar("WsComercial.FirmarContrato cobro inicial", ex.Message); }
            return WsSoporte.Json(new { ok = true, correo = correo, estado = EstadoFirma(t, false), pagar = pagar, pagarTexto = pagarTexto, pagarUsd = pagarUsd });
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) });
        }
    }

    /// <summary>
    /// Pagar.aspx: crea la transacción Webpay por todo lo pendiente y devuelve
    /// la URL y el token a los que el navegador hace POST. Público: lo protege
    /// el enlace de pago.
    /// </summary>
    [WebMethod(EnableSession = false)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string IniciarPago(string t)
    {
        try
        {
            string retorno = HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority) + VirtualPathUtility.ToAbsolute("~/Pagar.aspx") + "?t=" + HttpUtility.UrlEncode(t);
            Webpay.Transaccion tx = Cobros.IniciarPago(t, retorno);
            return WsSoporte.Json(new { url = tx.Url, token = tx.Token });
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) });
        }
    }

    /// <summary>
    /// Pagar.aspx: el cliente informa una transferencia (nacional o internacional) con su comprobante.
    /// Público: lo protege el enlace de pago. Queda por verificar; el ejecutivo recibe el aviso.
    /// </summary>
    [WebMethod(EnableSession = false)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string InformarPagoPublico(string t, string monto, string fecha, string banco, string operacion, string archivoNombre, string archivoMime, string archivoBase64)
    {
        try
        {
            decimal m = ParseMonto(monto);
            DateTime f;
            if (!DateTime.TryParseExact((fecha ?? "").Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f)) throw new Exception("Indica la fecha de la transferencia.");
            int n = Cobros.InformarTransferencia(t, m, f, Corta(banco, 100), Corta(operacion, 100), Corta(archivoNombre, 200), Corta(archivoMime, 100), string.IsNullOrEmpty(archivoBase64) ? null : Convert.FromBase64String(archivoBase64));
            return WsSoporte.Json(new { ok = true, pagos = n });
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) });
        }
    }

    /// <summary>Monto escrito a la chilena: «1.950,50», «3.065.335» o «1950.5». La coma es decimal; un punto seguido de 3 dígitos, miles.</summary>
    private static decimal ParseMonto(string s)
    {
        s = (s ?? "").Trim().Replace(" ", "").Replace("$", "");
        if (s.IndexOf(',') >= 0) s = s.Replace(".", "").Replace(",", ".");
        else if (System.Text.RegularExpressions.Regex.IsMatch(s, @"^\d{1,3}(\.\d{3})+$")) s = s.Replace(".", "");
        decimal v;
        if (!decimal.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out v)) throw new Exception("El monto no es un número válido.");
        return v;
    }

    /// <summary>Enlace vencido: avisa al ejecutivo para que reenvíe. No revela nada del contrato.</summary>
    [WebMethod(EnableSession = false)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string SolicitarNuevoEnlace(string t)
    {
        try
        {
            Dictionary<string, object> c = SoporteDatos.Fila("SEL_CONTRATO_TOKEN", "@TOKEN_HASH", Comercial.HashToken(t));
            if (c.ContainsKey("ID"))
            {
                string para = Comercial.Txt(c, "EJECUTIVO_CORREO");
                if (para == "") para = Comercial.Parametro("COMERCIAL_CORREO_AVISO", "comercial@codigocreativo.tech");
                Correo.Enviar(para, "Piden un enlace nuevo de firma · " + Comercial.Txt(c, "EMPRESA"),
                    Correo.Plantilla(new Correo.Pieza
                    {
                        Pre = "Centro Comercial", Titulo = "Piden un enlace nuevo de firma",
                        Texto = Correo.Html(Comercial.Txt(c, "CONTACTO")) + " intentó firmar el contrato v" + Comercial.Txt(c, "VERSION") + " de " +
                                Correo.Html(Comercial.Txt(c, "EMPRESA")) + " con un enlace vencido.",
                        Boton = "Abrir en Centro Comercial", Enlace = Correo.UrlSitio() + "/View/Comercial/CentroComercial.aspx?lead=" + Comercial.Txt(c, "LEAD"),
                        Cierre = "Reenvíalo desde la ficha del lead: el enlace nuevo invalida el anterior.", Pie = "Aviso interno del Centro Comercial de SIGMA."
                    }));
                try { Sp("INS_LEAD_ACTIVIDAD", new[] { "@ID" }, "@LEAD", Convert.ToInt32(c["LEAD"]), "@TIPO", "SISTEMA", "@ICONO", "clock",
                         "@TITULO", "Piden un enlace nuevo", "@DETALLE", "El cliente abrió un enlace de firma vencido"); } catch (Exception) { }
            }
            return WsSoporte.Json(new { ok = true });
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) });
        }
    }

    internal static object EstadoFirma(string t, bool marcarVisto)
    {
        if (string.IsNullOrWhiteSpace(t) || t.Length < 30) return new { estado = "invalido" };
        Dictionary<string, object> c = SoporteDatos.Fila("SEL_CONTRATO_TOKEN", "@TOKEN_HASH", Comercial.HashToken(t));
        if (!c.ContainsKey("ID")) return new { estado = "invalido" };
        string est = Comercial.Txt(c, "ESTADO");
        string estado = est == "FIRMADO" ? "firmado" : est == "ANULADO" ? "invalido"
                      : Convert.ToBoolean(c["USADO"]) ? "usado" : Convert.ToInt32(c["VENCIDO"]) == 1 ? "vencido" : "pendiente";
        if (estado == "pendiente" && marcarVisto && est == "ENVIADO")
            try { Sp("UPD_CONTRATO_VISUALIZADO", null, "@ID", Convert.ToInt32(c["ID"])); } catch (Exception) { }
        decimal mens = Comercial.Dec(c["MENSUAL_UF"]), desc = Comercial.Dec(c["DESCUENTO_PCT"]);
        return new
        {
            estado = estado,
            empresa = Comercial.Txt(c, "EMPRESA"), rutEmpresa = Comercial.Txt(c, "RUT_EMPRESA"), contacto = Comercial.Txt(c, "CONTACTO"),
            correo = estado == "firmado" ? Comercial.Txt(c, "CORREO") : "",
            version = Comercial.Txt(c, "VERSION"), plan = Comercial.Txt(c, "PLAN_NOMBRE"),
            moneda = Comercial.Moneda(c), rutEtiqueta = Comercial.Txt(c, "IDENT_ETIQUETA") == "" ? "RUT" : Comercial.Txt(c, "IDENT_ETIQUETA"), esChile = Convert.ToInt32(c["PAIS_ID"]) == 1,
            mensual = Comercial.Mon1(Comercial.MensualNeta(mens, desc), Comercial.Moneda(c)), implementacion = Comercial.Mon1(c["IMPLEMENTACION_UF"], Comercial.Moneda(c)),
            vigencia = Comercial.Txt(c, "VIGENCIA_MESES") + " meses", total = Comercial.Mon1(c["TOTAL_UF"], Comercial.Moneda(c)),
            expira = Comercial.FechaHora(Comercial.Txt(c, "EXPIRA")), sha = Comercial.Txt(c, "PDF_SHA256"),
            firmado = Comercial.FechaHora(Comercial.Txt(c, "FIRMADO")), firmante = Comercial.Txt(c, "FIRMANTE"),
            ejecutivo = Comercial.Txt(c, "EJECUTIVO"), ejecutivoCorreo = Comercial.Txt(c, "EJECUTIVO_CORREO")
        };
    }

    private bool CorreoFirmado(Dictionary<string, object> c, byte[] pdf, string firmante, DateTime fecha, string claveNueva)
    {
        string empresa = Comercial.Txt(c, "EMPRESA");
        string archivo = "Contrato_SIGMA_" + Archivo(empresa) + "_Firmado.pdf";
        int kb = (int)Math.Ceiling((pdf != null ? pdf.Length : 0) / 1024.0);
        Correo.Adjunto adj = new Correo.Adjunto(archivo, "application/pdf", pdf);
        string[] datos = { "Cliente", empresa, "Plan", Comercial.Txt(c, "PLAN_NOMBRE"), "Fecha", fecha.ToString("dd/MM/yyyy HH:mm", Comercial.CL), "Firmó", firmante };
        string ejecutivo = Comercial.Txt(c, "EJECUTIVO");
        bool cliente = Correo.Enviar(Comercial.Txt(c, "CORREO"), "Contrato firmado: bienvenido a SIGMA", Correo.Plantilla(new Correo.Pieza
        {
            Pre = "Contrato firmado",
            Titulo = "Listo, " + Comercial.Primero(Comercial.Txt(c, "CONTACTO")) + ": " + empresa + " ya es cliente SIGMA",
            Texto = "Firmaste el contrato el " + fecha.ToString("dd/MM/yyyy", Comercial.CL) + " a las " + fecha.ToString("HH:mm", Comercial.CL) +
                    ". Adjuntamos el PDF firmado para tus registros. Tu suscripción " + Correo.Html(Comercial.Txt(c, "PLAN_NOMBRE")) + " está activa desde hoy.",
            Detalles = datos, Usuario = claveNueva != null ? Comercial.Txt(c, "CORREO") : null, Clave = claveNueva,
            Adjunto = archivo, AdjuntoKb = kb, Boton = "Ir a SIGMA", Enlace = Correo.UrlSitio() + "/Login.aspx",
            Cierre = Correo.Html(ejecutivo == "" ? "Tu ejecutivo" : ejecutivo) + " te escribirá para coordinar la implementación.",
            Pie = "Guarda este correo: incluye tu copia del contrato."
        }), adj);
        List<string> internos = new List<string>();
        if (Comercial.Txt(c, "EJECUTIVO_CORREO") != "") internos.Add(Comercial.Txt(c, "EJECUTIVO_CORREO"));
        internos.Add(Comercial.Parametro("COMERCIAL_CORREO_AVISO", "comercial@codigocreativo.tech"));
        Correo.Enviar(internos.Distinct(StringComparer.OrdinalIgnoreCase), null, "Contrato firmado · " + empresa, Correo.Plantilla(new Correo.Pieza
        {
            Pre = "Centro Comercial", Titulo = "Contrato firmado correctamente",
            Texto = Correo.Html(empresa) + " firmó el contrato. El lead quedó CONCRETADO y la suscripción está activa.",
            Detalles = datos, Adjunto = archivo, AdjuntoKb = kb,
            Boton = "Abrir en Centro Comercial", Enlace = Correo.UrlSitio() + "/View/Comercial/CentroComercial.aspx?lead=" + Comercial.Txt(c, "LEAD"),
            Pie = "Aviso interno del Centro Comercial de SIGMA."
        }), adj);
        return cliente;
    }

    // =====================================================================
    // INTERNOS
    // =====================================================================

    private Dictionary<string, object> ArmarFicha(int lead)
    {
        List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", lead);
        Dictionary<string, object> l = SoporteDatos.Del(c, 0).FirstOrDefault();
        if (l == null) throw new Exception("El lead no existe.");
        Dictionary<string, object> demo = SoporteDatos.Del(c, 2).FirstOrDefault();
        Dictionary<string, object> uso = demo != null ? SoporteDatos.Filas("SEL_LEAD_DEMO_USO", "@LEAD", lead).FirstOrDefault() : null;
        return new Dictionary<string, object>
        {
            { "lead", l }, { "actividad", SoporteDatos.Del(c, 1) }, { "demo", demo }, { "uso", uso },
            { "propuestas", SoporteDatos.Del(c, 3) }, { "contratos", SoporteDatos.Del(c, 4) }, { "reuniones", SoporteDatos.Del(c, 5) },
            { "ahora", Hora.Ahora.ToString("yyyy-MM-dd HH:mm") }
        };
    }

    private void GenerarPdfPropuesta(int lead, int propuesta)
    {
        List<List<Dictionary<string, object>>> fi = SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", lead);
        Dictionary<string, object> l = SoporteDatos.Del(fi, 0).First();
        Dictionary<string, object> p = SoporteDatos.Del(fi, 3).First(x => Convert.ToInt32(x["ID"]) == propuesta);
        string ejecutivo = Comercial.Txt(l, "EJECUTIVO");
        byte[] pdf = Comercial.PdfPropuesta(l, p, ejecutivo == "" ? "Código Creativo" : ejecutivo);
        Sp("UPD_PROPUESTA_PDF", null, "@ID", propuesta, "@PDF", pdf);
    }

    private bool EnviarPropuestaInterna(int lead, int propuesta)
    {
        Sp("UPD_PROPUESTA_ENVIADA", null, "@ID", propuesta, "@USUARIO", U());
        List<List<Dictionary<string, object>>> fi = SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", lead);
        Dictionary<string, object> l = SoporteDatos.Del(fi, 0).First();
        Dictionary<string, object> p = SoporteDatos.Del(fi, 3).First(x => Convert.ToInt32(x["ID"]) == propuesta);
        Dictionary<string, object> pdf = SoporteDatos.Fila("SEL_PROPUESTA_PDF", "@ID", propuesta);
        string ejec = Comercial.Txt(l, "EJECUTIVO");
        string html = Correo.Plantilla(new Correo.Pieza
        {
            Pre = "Propuesta · versión " + Comercial.Txt(p, "VERSION"),
            Titulo = "Tu propuesta SIGMA está lista",
            Texto = Correo.Html(Comercial.Primero(Comercial.Txt(l, "CONTACTO"))) + ", te enviamos la propuesta de SIGMA para " + Correo.Html(Comercial.Txt(l, "EMPRESA")) + ".",
            Detalles = new[] { "Plan", Comercial.Txt(p, "NOMBRE_PLAN"), "Módulos", Comercial.NombresModulos(Comercial.Txt(p, "MODULOS")),
                               "Mensualidad", Comercial.Mon1(Comercial.MensualNeta(Comercial.Dec(p["MENSUAL_UF"]), Comercial.Dec(p["DESCUENTO_PCT"])), Comercial.Moneda(p)),
                               "Implementación", Comercial.Mon1(p["IMPLEMENTACION_UF"], Comercial.Moneda(p)), "Vigencia", Comercial.Txt(p, "VIGENCIA_MESES") + " meses" },
            Adjunto = "Propuesta_SIGMA_" + Archivo(Comercial.Txt(l, "EMPRESA")) + "_v" + Comercial.Txt(p, "VERSION") + ".pdf",
            AdjuntoKb = pdf["PDF"] is byte[] ? (int)Math.Ceiling(((byte[])pdf["PDF"]).Length / 1024.0) : 0,
            Cierre = "Si la aceptas, te enviamos el contrato para firmarlo en línea. ¿Dudas? Responde este correo." + (ejec != "" ? "<br>" + Correo.Html(ejec) + " · Código Creativo" : ""),
            Pie = "Recibes este correo porque estás en conversaciones con Código Creativo."
        });
        return Correo.Enviar(new[] { Comercial.Txt(l, "CORREO") }, Copia(l), "Propuesta SIGMA · " + Comercial.Txt(l, "EMPRESA"), html,
            new Correo.Adjunto("Propuesta_SIGMA_" + Archivo(Comercial.Txt(l, "EMPRESA")) + "_v" + Comercial.Txt(p, "VERSION") + ".pdf", "application/pdf", pdf["PDF"] as byte[]));
    }

    private bool EnviarContratoInterno(int contrato, Dictionary<string, object> l, Dictionary<string, object> p)
    {
        string token = Comercial.Token();
        int dias = Entero(Comercial.Parametro("COMERCIAL_FIRMA_DIAS", "7"), 7);
        DateTime expira = Hora.Ahora.AddDays(dias);
        Sp("UPD_CONTRATO_ENVIADO", null, "@ID", contrato, "@TOKEN_HASH", Comercial.HashToken(token), "@EXPIRA", expira, "@USUARIO", U());
        string enlace = Correo.UrlSitio() + "/Firma.aspx?t=" + HttpUtility.UrlEncode(token);
        string html = Correo.Plantilla(new Correo.Pieza
        {
            Pre = "Contrato · versión " + Comercial.Txt(SoporteDatos.Fila("SEL_CONTRATO_PDF", "@ID", contrato, "@FIRMADO", false), "VERSION"),
            Titulo = "Tu contrato está listo para firmar",
            Texto = Correo.Html(Comercial.Primero(Comercial.Txt(l, "CONTACTO"))) + ", preparamos el contrato de suscripción de " + Correo.Html(Comercial.Txt(l, "EMPRESA")) +
                    ". Revísalo y fírmalo en línea; toma menos de dos minutos.",
            Detalles = new[] { "Plan", Comercial.Txt(p, "NOMBRE_PLAN"),
                               "Mensualidad", Comercial.Mon1(Comercial.MensualNeta(Comercial.Dec(p["MENSUAL_UF"]), Comercial.Dec(p["DESCUENTO_PCT"])), Comercial.Moneda(p)),
                               "Implementación", Comercial.Mon1(p["IMPLEMENTACION_UF"], Comercial.Moneda(p)), "Vigencia", Comercial.Txt(p, "VIGENCIA_MESES") + " meses" },
            Boton = "Revisar y firmar", Enlace = enlace,
            Cierre = "El enlace es personal y vence el " + expira.ToString("dd/MM/yyyy", Comercial.CL) + ". Por seguridad, no lo reenvíes.",
            Pie = "Este enlace de firma es de un solo uso."
        });
        return Correo.Enviar(new[] { Comercial.Txt(l, "CORREO") }, null, "Revisa y firma tu contrato SIGMA", html);
    }

    private bool CorreoCredenciales(Dictionary<string, object> f, string clave, bool reenvio)
    {
        Dictionary<string, object> l = (Dictionary<string, object>)f["lead"];
        Dictionary<string, object> d = (Dictionary<string, object>)f["demo"];
        if (d == null) return false;
        string login = Correo.UrlSitio() + "/Login.aspx";
        string ejec = Comercial.Txt(l, "EJECUTIVO");
        string html = Correo.Plantilla(new Correo.Pieza
        {
            Pre = "Demo SIGMA · hasta el " + Comercial.Fecha(Comercial.Txt(d, "EXPIRA")),
            Titulo = reenvio ? "Tus nuevas credenciales de la demo" : "Hola, " + Comercial.Primero(Comercial.Txt(l, "CONTACTO")) + ": tu demo está lista",
            Texto = Correo.Html(ejec == "" ? "Código Creativo" : ejec) + " preparó una demo de SIGMA para " + Correo.Html(Comercial.Txt(l, "EMPRESA")) +
                    ". Puedes usarla hasta el " + Comercial.Fecha(Comercial.Txt(d, "EXPIRA")) + ".",
            Usuario = Comercial.Txt(d, "USUARIO_CORREO"), Clave = clave,
            Boton = "Entrar a SIGMA", Enlace = login,
            Cierre = "Incluye " + Comercial.Txt(d, "LIM_USUARIOS") + " usuarios, " + Comercial.Txt(d, "LIM_ACTIVOS") + " activos, " + Comercial.Txt(d, "LIM_OT") + " OT, " +
                     Comercial.Txt(d, "LIM_PROGRAMACIONES") + " programaciones y " + Comercial.Txt(d, "LIM_CHECKLISTS") + " checklists. ¿Dudas? Responde este correo y te llamamos.",
            Pie = "Recibes este correo porque pediste una demo en codigocreativo.tech."
        });
        return Correo.Enviar(Comercial.Txt(d, "USUARIO_CORREO"), "Tu demo de SIGMA está lista", html);
    }

    private bool CorreoLeadNuevo(int id)
    {
        Dictionary<string, object> l = SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_LEAD_FICHA", "@LEAD", id), 0).FirstOrDefault();
        if (l == null) return false;
        string para = Comercial.Parametro("COMERCIAL_CORREO_AVISO", "comercial@codigocreativo.tech");
        string enlace = Correo.UrlSitio() + "/View/Comercial/CentroComercial.aspx?lead=" + id;
        string html = Correo.Plantilla(new Correo.Pieza
        {
            Pre = "Centro Comercial", Titulo = "Llegó un lead nuevo",
            Texto = Correo.Html(Comercial.Txt(l, "EMPRESA")) + " completó el formulario de inicio.aspx el " + Comercial.FechaHora(Comercial.Txt(l, "FECHA_CREACION")).Replace(" ", " a las ") +
                    ". Todavía no tiene ejecutivo asignado." + (Comercial.Txt(l, "MENSAJE") != "" ? "<br><br><i>«" + Correo.Html(Comercial.Txt(l, "MENSAJE")) + "»</i>" : ""),
            Detalles = new[] { "Contacto", Comercial.Txt(l, "CONTACTO") + (Comercial.Txt(l, "CARGO") != "" ? " · " + Comercial.Txt(l, "CARGO") : ""),
                               "Correo", Comercial.Txt(l, "CORREO"), "Teléfono", Comercial.Txt(l, "TELEFONO"),
                               "Activos", Comercial.Txt(l, "N_ACTIVOS"), "Interés", Comercial.Txt(l, "PLAN_INTERES") },
            Boton = "Abrir en Centro Comercial", Enlace = enlace,
            Cierre = "Asígnale un ejecutivo para que deje de aparecer en «Requiere atención».",
            Pie = "Aviso interno del Centro Comercial de SIGMA."
        });
        return Correo.Enviar(para, "Nuevo lead: " + Comercial.Txt(l, "EMPRESA") + " (formulario web)", html);
    }

    private static IEnumerable<string> Copia(Dictionary<string, object> l)
    {
        string e = Comercial.Txt(l, "EJECUTIVO_CORREO");
        return string.IsNullOrEmpty(e) ? null : new[] { e };
    }

    private static object LimitesDemo()
    {
        Dictionary<string, int> d = new Dictionary<string, int> { { "usuarios", 2 }, { "activos", 10 }, { "ot", 20 }, { "programaciones", 5 }, { "checklists", 5 }, { "repuestos", 20 }, { "bodegas", 1 }, { "plantas", 1 } };
        foreach (string par in Comercial.Parametro("COMERCIAL_DEMO_LIMITES", "").Split(';'))
        {
            string[] kv = par.Split('='); int n;
            if (kv.Length == 2 && int.TryParse(kv[1].Trim(), out n) && d.ContainsKey(kv[0].Trim().ToLowerInvariant())) d[kv[0].Trim().ToLowerInvariant()] = n;
        }
        return d;
    }

    /// <summary>
    /// Las pantallas comerciales que salieron del menú (bloque 459) y ahora se
    /// abren desde el Centro. Solo las que la persona puede abrir.
    /// </summary>
    private static object Administrar()
    {
        string[][] p =
        {
            new[] { "Suscripciones", "~/View/Comercial/Suscripciones/Suscripciones.aspx", "Estado, plan y clave de cada cliente" },
            new[] { "Períodos", "~/View/Comercial/Suscripciones/Periodos.aspx", "Lo que se cobra cada mes" },
            new[] { "Pagos", "~/View/Comercial/Suscripciones/Pagos.aspx", "Declarar y verificar pagos" },
            new[] { "Planes", "~/View/Comercial/Suscripciones/Planes.aspx", "Planes estándar, precios y topes" },
            new[] { "Clientes", "~/View/Comercial/Clientes/Clientes.aspx", "Todas las empresas de SIGMA" }
        };
        return p.Where(x => Token.PuedePagina(x[1]))
                .Select(x => new { n = x[0], url = VirtualPathUtility.ToAbsolute(x[1]), d = x[2] }).ToList();
    }

    private static object Permisos()
    {
        return new { leads = Token.Puede(P_LEADS), demos = Token.Puede(P_DEMOS), propuestas = Token.Puede(P_PROP) };
    }

    /// <summary>
    /// Ejecuta un SP con parámetros de entrada en pares y devuelve los de
    /// salida. Los RAISERROR del SP llegan como excepción con su mensaje.
    /// </summary>
    private static Dictionary<string, object> Sp(string sp, string[] salidas, params object[] ps)
    {
        SqlCommand cmd = Conexion.GetCommand(sp);
        Dictionary<string, object> r = new Dictionary<string, object>();
        try
        {
            foreach (string s in salidas ?? new string[0])
            {
                SqlParameter p = s == "@CODIGO" || s == "@CORREO" ? cmd.Parameters.Add(s, SqlDbType.NVarChar, 200) : cmd.Parameters.Add(s, SqlDbType.Int);
                p.Direction = ParameterDirection.Output;
            }
            for (int i = 0; i + 1 < ps.Length; i += 2)
            {
                object v = ps[i + 1];
                if (v is byte[]) cmd.Parameters.Add((string)ps[i], SqlDbType.VarBinary, -1).Value = v;
                else cmd.Parameters.AddWithValue((string)ps[i], v ?? DBNull.Value);
            }
            cmd.ExecuteNonQuery();
            foreach (string s in salidas ?? new string[0]) r[s] = cmd.Parameters[s].Value == DBNull.Value ? null : cmd.Parameters[s].Value;
        }
        finally { if (cmd.Connection != null) cmd.Connection.Close(); }
        return r;
    }

    private static string Ejecutar(Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return WsSoporte.Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            return WsSoporte.Json(accion());
        }
        catch (Exception ex)
        {
            return WsSoporte.Json(new { error = true, detalle = Limpio(ex.Message) });
        }
    }

    private static void Exigir(string permiso)
    {
        if (!Token.Puede(permiso)) throw new Exception("No tienes la facultad para esta acción en el Centro Comercial.");
    }

    /// <summary>Mensaje del SP sin número ni caja alta, con las siglas de vuelta.</summary>
    public static string Limpio(string m)
    {
        string s = WsCentroPlanificacion.Limpio(m);
        s = Regex.Replace(s, @"\brut\b", "RUT");
        s = Regex.Replace(s, @"\bsigma\b", "SIGMA", RegexOptions.IgnoreCase);
        s = Regex.Replace(s, @"\bhttps://", "https://", RegexOptions.IgnoreCase);
        s = s.Replace("comercial@codigocreativo.tech", "comercial@codigocreativo.tech");
        s = Regex.Replace(s, @"\buf\b", "UF");
        return s;
    }

    private static int U() { return SoporteDatos.Usuario(); }
    private static int Entero(string s, int d) { int n; return int.TryParse(s, out n) ? n : d; }
    private static string Corta(string s, int n) { s = (s ?? "").Trim(); return s.Length > n ? s.Substring(0, n) : s; }
    private static string Archivo(string s) { return Regex.Replace(Regex.Replace(s ?? "", @"[^\p{L}\p{N}]+", "_"), "_+", "_").Trim('_'); }

    private static DateTime? FechaHora(string s)
    {
        DateTime d;
        if (string.IsNullOrWhiteSpace(s)) return null;
        string[] f = { "yyyy-MM-dd HH:mm", "yyyy-MM-ddTHH:mm", "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss" };
        return DateTime.TryParseExact(s.Trim(), f, CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? (DateTime?)d : null;
    }

    private static string Ip()
    {
        HttpRequest r = HttpContext.Current.Request;
        string ip = r.UserHostAddress;
        return string.IsNullOrEmpty(ip) ? null : (ip.Length > 64 ? ip.Substring(0, 64) : ip);
    }
}
