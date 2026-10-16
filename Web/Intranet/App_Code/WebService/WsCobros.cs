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
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Cobros del Centro Comercial (16-10-2026, prompt V2): suscripciones,
/// períodos, pagos y planes en drawers. Lo pinta sigma-cc-cobros.js.
///
/// NO CAMBIA LA LÓGICA, LA MUEVE
///   Las escrituras pasan por los mismos controllers y SP de las fichas que
///   reemplazan (SuscripcionController, SuscripcionPeriodoController,
///   SuscripcionPagoController, PlanComercialController). Aquí solo se
///   comprueba la facultad por su código y se arma lo que el drawer necesita.
///
/// MONEDA
///   Cada cliente cobra en UF (se paga en CLP con la UF del día) o en USD
///   (sin UF). Nunca se suman montos de monedas distintas: los totales van
///   separados por moneda.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsCobros : System.Web.Services.WebService
{
    private const string P_VER = "VER CENTRO COMERCIAL";
    private const string P_EDITAR = "CREAR EDITAR SUSCRIPCIONES";
    private const string P_CAMBIAR_PLAN = "CAMBIAR PLAN SUSCRIPCION";
    private const string P_REEMITIR = "REEMITIR KEY SUSCRIPCION";
    private const string P_EMITIR = "EMITIR PERIODOS SUSCRIPCION";
    private const string P_MONEDA = "CAMBIAR MONEDA COBRO CLIENTE";
    private const string P_PLANES ="CREAR EDITAR PLANES COMERCIALES";
    private const string P_VERIFICAR = "VERIFICAR PAGOS SUSCRIPCION";
    private const string P_DECLARAR = "DECLARAR PAGO SUSCRIPCION";

    // =====================================================================
    // LISTAS
    // =====================================================================

    /// <summary>Una subvista de la pestaña Suscripciones: suscripciones, periodos, pagos o planes.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Lista(string vista)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            switch (vista)
            {
                case "suscripciones":
                    ExigirPagina("~/View/Comercial/Suscripciones/Suscripciones.aspx", "ver suscripciones");
                    return new { filas = ListaSuscripciones(), crear = Token.Puede(P_EDITAR) };
                case "periodos":
                    ExigirPagina("~/View/Comercial/Suscripciones/Periodos.aspx", "ver períodos");
                    return new { filas = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO")), emitir = Token.Puede(P_EMITIR) };
                case "empresas":
                    ExigirPagina("~/View/Comercial/Clientes/Clientes.aspx", "ver clientes");
                    return new { filas = ListaClientes(), crear = Token.PuedePagina("~/View/Comercial/Clientes/Cliente.aspx") };
                case "planes":
                    ExigirPagina("~/View/Comercial/Suscripciones/Planes.aspx", "ver planes");
                    return new { filas = ListaPlanes(), crear = Token.Puede(P_PLANES) };
                default:
                    throw new Exception("Esa vista todavía no está disponible.");
            }
        });
    }

    /// <summary>Planes con su mensualidad vigente en UF y en USD (cada plan tiene las dos).</summary>
    private static object ListaPlanes()
    {
        List<Dictionary<string, object>> precios = Limpia(SoporteDatos.Filas("SEL_PLAN_COMERCIAL_PRECIO", "@SOLO_VIGENTES", true, "@PERIODICIDAD", 1));
        Func<int, string, object> precio = (plan, mon) =>
        {
            Dictionary<string, object> f = precios.FirstOrDefault(x => Convert.ToInt32(x["PCP_PLAN_COMERCIAL"]) == plan && Convert.ToString(x["PCP_MONEDA"]) == mon);
            return f == null ? null : f["PCP_VALOR_UF"];
        };
        return (new PlanComercialController().GetPlanesDistintos(false) ?? new List<SitioBase.Model.PlanComercial>())
            .Select(p => new { id = p.plc_id, codigo = p.plc_codigo, nombre = p.plc_nombre, descripcion = p.plc_descripcion, publico = p.plc_publico, habilitado = p.plc_habilitado,
                               gracia = p.plc_dias_gracia, orden = p.plc_orden, uf = precio(p.plc_id, "UF"), usd = precio(p.plc_id, "USD") })
            .OrderBy(x => x.orden).ThenBy(x => x.nombre).ToList();
    }

    private static object ListaSuscripciones()
    {
        Dictionary<string, Dictionary<string, object>> cobro = new Dictionary<string, Dictionary<string, object>>();
        foreach (Dictionary<string, object> c in SoporteDatos.Filas("SEL_COBRO_ESTADO_SUSCRIPCION")) cobro[Convert.ToString(c["ID"])] = c;
        List<Dictionary<string, object>> filas = new List<Dictionary<string, object>>();
        foreach (SitioBase.Model.Suscripcion s in new SuscripcionController().GetSuscripciones(new SitioBase.Model.Suscripcion()) ?? new List<SitioBase.Model.Suscripcion>())
        {
            Dictionary<string, object> c;
            cobro.TryGetValue(s.sus_id.ToString(), out c);
            c = c ?? new Dictionary<string, object>();
            filas.Add(new Dictionary<string, object>
            {
                { "id", s.sus_id }, { "cliente", s.cli_nombre }, { "clienteId", s.sus_cliente }, { "plan", s.plc_nombre },
                { "estado", s.estado ?? s.sue_nombre }, { "estadoNombre", s.sue_nombre }, { "desde", Fecha(s.sus_fecha_inicio) }, { "hasta", Fecha(s.sus_fecha_fin) },
                { "dias", s.dias_restantes }, { "opera", s.puede_operar }, { "contacto", s.sus_contacto_nombre }, { "correo", s.sus_contacto_email },
                { "key", s.sus_key_prefijo },
                { "moneda", c.ContainsKey("MONEDA") ? c["MONEDA"] : "UF" }, { "pais", c.ContainsKey("PAIS") ? c["PAIS"] : null },
                { "pendientes", c.ContainsKey("PERIODOS_PENDIENTES") ? c["PERIODOS_PENDIENTES"] : 0 }, { "saldo", c.ContainsKey("SALDO") ? c["SALDO"] : 0 },
                { "mora", c.ContainsKey("EN_MORA") && Convert.ToInt32(c["EN_MORA"]) == 1 }, { "porVerificar", c.ContainsKey("POR_VERIFICAR") ? c["POR_VERIFICAR"] : 0 },
                { "ultimoMedio", c.ContainsKey("ULTIMO_MEDIO") ? c["ULTIMO_MEDIO"] : null },
                { "diasSuspender", c.ContainsKey("DIAS_PARA_SUSPENDER") ? c["DIAS_PARA_SUSPENDER"] : null }
            });
        }
        return filas.OrderBy(f => Convert.ToString(f["cliente"])).ToList();
    }

    // =====================================================================
    // SUSCRIPCIÓN
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Suscripcion(int id)
    {
        return Ejecutar(() => { Exigir(P_VER); return FichaSuscripcion(id); });
    }

    private static object FichaSuscripcion(int id)
    {
        SitioBase.Model.Suscripcion s = new SuscripcionController().GetSuscripcion(new SitioBase.Model.Suscripcion { sus_id = id });
        if (s == null || s.sus_id == 0) throw new Exception("La suscripción no existe.");
        Dictionary<string, object> c = SoporteDatos.Filas("SEL_COBRO_ESTADO_SUSCRIPCION").FirstOrDefault(x => Convert.ToInt32(x["ID"]) == id) ?? new Dictionary<string, object>();
        string moneda = c.ContainsKey("MONEDA") ? Convert.ToString(c["MONEDA"]) : "UF";
        CatalogoController cat = new CatalogoController();
        int cliente = SitioBase.Session.ClienteId();
        return new
        {
            s = new
            {
                id = s.sus_id, cliente = s.cli_nombre, clienteId = s.sus_cliente, plan = s.plc_nombre, planId = s.sus_plan_comercial,
                estadoId = s.sus_suscripcion_estado, estadoNombre = s.sue_nombre, estado = s.estado, opera = s.puede_operar, habilitado = s.sus_habilitado,
                desde = Fecha(s.sus_fecha_inicio), hasta = Fecha(s.sus_fecha_fin), dias = s.dias_restantes, gracia = s.sus_dias_gracia,
                key = s.sus_key_prefijo, contactoNombre = s.sus_contacto_nombre, contactoCorreo = s.sus_contacto_email, contactoTelefono = s.sus_contacto_telefono,
                observacion = s.sus_observacion, moneda = moneda, pais = c.ContainsKey("PAIS") ? c["PAIS"] : null,
                saldo = c.ContainsKey("SALDO") ? c["SALDO"] : 0, mora = c.ContainsKey("EN_MORA") && Convert.ToInt32(c["EN_MORA"]) == 1
            },
            consumo = Limpia(SoporteDatos.Filas("SEL_COBRO_CONSUMO", "@CLIENTE", s.sus_cliente)),
            periodos = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@SUSCRIPCION", id)),
            pagos = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO", "@CLIENTE", s.sus_cliente)),
            planes = (new PlanComercialController().GetPlanesDistintos() ?? new List<SitioBase.Model.PlanComercial>()).Select(p => new { id = p.plc_id, n = p.plc_nombre }).ToList(),
            periodicidades = (cat.GetValoresPorCodigo("PERIODICIDAD_COBRO", cliente) ?? new List<SitioBase.Model.CatalogoValor>()).Select(v => new { id = v.valor_id, n = v.valor_nombre }).ToList(),
            estados = (cat.GetValoresPorCodigo("SUSCRIPCION_ESTADO", cliente) ?? new List<SitioBase.Model.CatalogoValor>()).Select(v => new { id = v.valor_id, n = v.valor_nombre }).ToList(),
            permisos = new { editar = Token.Puede(P_EDITAR), cambiarPlan = Token.Puede(P_CAMBIAR_PLAN), reemitir = Token.Puede(P_REEMITIR), emitir = Token.Puede(P_EMITIR) }
        };
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarSuscripcion(int id, int estado, bool habilitado, string contactoNombre, string contactoCorreo, string contactoTelefono, string observacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            SitioBase.Model.Suscripcion e = new SitioBase.Model.Suscripcion
            {
                sus_id = id, sus_suscripcion_estado = estado, sus_habilitado = habilitado,
                sus_contacto_nombre = (contactoNombre ?? "").Trim(), sus_contacto_email = (contactoCorreo ?? "").Trim(),
                sus_contacto_telefono = (contactoTelefono ?? "").Trim(), sus_observacion = (observacion ?? "").Trim()
            };
            Respuesta r = new SuscripcionController().UpdateSuscripcion(e);
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, ficha = FichaSuscripcion(id) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CambiarPlan(int id, int planNuevo, int? periodicidad)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CAMBIAR_PLAN);
            Respuesta r = new SuscripcionController().CambiarPlan(new SitioBase.Model.Suscripcion { sus_id = id }, planNuevo, periodicidad);
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, ficha = FichaSuscripcion(id) };
        });
    }

    /// <summary>
    /// Reemite la clave. El motivo es obligatorio y queda auditado (lo guarda
    /// UPD_SUSCRIPCION_KEY). La clave completa viaja una sola vez, en esta respuesta.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ReemitirClave(int id, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_REEMITIR);
            SitioBase.Model.Suscripcion e = new SitioBase.Model.Suscripcion { sus_id = id };
            Respuesta r = new SuscripcionController().ReemitirKey(e, motivo);
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, clave = e.key_texto, ficha = FichaSuscripcion(id) };
        });
    }

    // =====================================================================
    // PERÍODO
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Periodo(int id)
    {
        return Ejecutar(() => { Exigir(P_VER); return FichaPeriodo(id); });
    }

    private static object FichaPeriodo(int id)
    {
        Dictionary<string, object> p = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@ID", id)).FirstOrDefault();
        if (p == null) throw new Exception("El período no existe.");
        return new { periodo = p, pagos = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO", "@PERIODO", id)), permisos = new { informar = Token.Puede(P_DECLARAR) } };
    }

    /// <summary>Lo que el formulario «Emitir período» necesita: a quién, con qué plan y en qué moneda.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string OpcionesEmitir(int? suscripcion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EMITIR);
            CatalogoController cat = new CatalogoController();
            return new
            {
                suscripciones = ListaSuscripciones(),
                planes = (new PlanComercialController().GetPlanesDistintos() ?? new List<SitioBase.Model.PlanComercial>()).Select(p => new { id = p.plc_id, n = p.plc_nombre }).ToList(),
                periodicidades = (cat.GetValoresPorCodigo("PERIODICIDAD_COBRO", SitioBase.Session.ClienteId()) ?? new List<SitioBase.Model.CatalogoValor>()).Select(v => new { id = v.valor_id, n = v.valor_nombre }).ToList(),
                suscripcion = suscripcion
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EmitirPeriodo(int suscripcion, int periodicidad, int? plan, bool implantacion, string valor, string observacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EMITIR);
            SitioBase.Model.SuscripcionPeriodo e = new SitioBase.Model.SuscripcionPeriodo
            {
                spe_suscripcion = suscripcion, spe_periodicidad_cobro = periodicidad, spe_plan_comercial = plan,
                spe_es_implantacion = implantacion, spe_observacion = (observacion ?? "").Trim(), valor_uf_manual = Monto(valor)
            };
            Respuesta r = new SuscripcionPeriodoController().EmitirPeriodo(e);
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, id = r.codigo, ficha = FichaPeriodo(r.codigo) };
        });
    }

    // =====================================================================
    // CLIENTE
    // =====================================================================

    private static object ListaClientes()
    {
        Dictionary<string, Dictionary<string, object>> extra = new Dictionary<string, Dictionary<string, object>>();
        foreach (Dictionary<string, object> c in SoporteDatos.Filas("SEL_CLIENTE_COMERCIAL_LISTA")) extra[Convert.ToString(c["ID"])] = c;
        return (new ClienteController().GetClientes(new SitioBase.Model.Cliente { filtro_paises = SitioBase.Session.UsuarioIdPaises(), tipo_perfil = 1 }) ?? new List<SitioBase.Model.Cliente>())
            .Select(c =>
            {
                Dictionary<string, object> e;
                extra.TryGetValue(c.cli_id.ToString(), out e);
                return new
                {
                    id = c.cli_id, nombre = c.cli_nombre, razon = c.cli_razon_social, identificador = c.cli_identificador, habilitado = c.cli_habilitado,
                    desde = c.cli_fecha_creacion == DateTime.MinValue ? null : c.cli_fecha_creacion.ToString("yyyy-MM-dd"),
                    pais = e != null ? e["PAIS"] : null, moneda = e != null ? e["MONEDA_COBRO"] : "UF"
                };
            }).OrderBy(x => x.nombre).ToList();
    }

    private static object OpcionesCliente()
    {
        CatalogoController cat = new CatalogoController();
        Func<string, object> catalogo = cod => (cat.GetValoresPorCodigo(cod, 0) ?? new List<SitioBase.Model.CatalogoValor>()).Select(v => new { id = v.valor_id, n = v.valor_nombre }).ToList();
        return new
        {
            paises = Limpia(SoporteDatos.Filas("SEL_COBRO_PAISES")).Select(p => new { id = p["ID"], n = p["NOMBRE"], etiqueta = p["ETIQUETA"], validacion = p["VALIDACION"], largo = p["LARGO"], moneda = p["MONEDA"] }).ToList(),
            zonas = catalogo("ZONA_HORARIA"), idiomas = catalogo("IDIOMA"), monedas = catalogo("MONEDA")
        };
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cliente(int id)
    {
        return Ejecutar(() => { Exigir(P_VER); return FichaCliente(id); });
    }

    private static object FichaCliente(int id)
    {
        if (id <= 0)
            return new { opciones = OpcionesCliente(), cliente = (object)null, suscripcion = (object)null, contactos = new List<object>(), usuarios = new List<object>(), plantas = new List<object>(),
                         permisos = new { editar = Token.PuedePagina("~/View/Comercial/Clientes/Cliente.aspx"), cambiarMoneda = Token.Puede(P_MONEDA) } };
        List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_CLIENTE_COMERCIAL", "@ID", id);
        Dictionary<string, object> cli = Limpia(SoporteDatos.Del(c, 0)).FirstOrDefault();
        if (cli == null) throw new Exception("El cliente no existe.");
        return new
        {
            opciones = OpcionesCliente(), cliente = cli, suscripcion = Limpia(SoporteDatos.Del(c, 1)).FirstOrDefault(),
            contactos = Limpia(SoporteDatos.Del(c, 2)).Where(x => Convert.ToBoolean(x["ccn_habilitado"])).ToList(),
            usuarios = Limpia(SoporteDatos.Filas("SEL_CLIENTE_USUARIO", "@CLIENTE", id)).Select(u => new { id = u["USU_ID"], nombre = (Convert.ToString(u["USU_NOMBRE"]) + " " + Convert.ToString(u["USU_APELLIDO_PATERNO"])).Trim(), correo = u["USU_CORREO"], perfiles = u["PERFILES"], habilitado = u["USU_HABILITADO"] }).ToList(),
            plantas = Limpia(SoporteDatos.Filas("SEL_CLIENTE_INSTALACION", "@CLIENTE", id)).Select(p => new { id = p["CIN_ID"], nombre = p["CIN_NOMBRE"], direccion = p["CIN_DIRECCION"], codigo = p["CIN_CODIGO"], habilitada = p["CIN_HABILITADO"] }).ToList(),
            permisos = new { editar = Token.PuedePagina("~/View/Comercial/Clientes/Cliente.aspx"), cambiarMoneda = Token.Puede(P_MONEDA) }
        };
    }

    /// <summary>
    /// Crea o actualiza la identidad del cliente. La moneda de cobro nace del país (Chile = UF, el
    /// resto = USD) y no cambia sola: cambiarla exige la facultad y un motivo, y queda auditado.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarCliente(int id, string nombre, string razon, int pais, string identificador, string fantasia, int? zona, int? idioma, int? moneda, bool habilitado, string monedaCobro, string motivo)
    {
        return Ejecutar(() =>
        {
            if (!Token.PuedePagina("~/View/Comercial/Clientes/Cliente.aspx")) throw new Exception("No tienes la facultad para crear o editar clientes.");
            if (pais <= 0) throw new Exception("Indica el país del cliente.");
            SitioBase.Model.Cliente e = new SitioBase.Model.Cliente
            {
                cli_id = id, cli_nombre = (nombre ?? "").Trim(), cli_razon_social = (razon ?? "").Trim(), cli_pais = pais, cli_identificador = (identificador ?? "").Trim(),
                cli_nombre_fantasia = (fantasia ?? "").Trim(), cli_zona_horaria = zona, cli_idioma = idioma, cli_moneda = moneda, cli_habilitado = habilitado
            };
            ClienteController c = new ClienteController();
            int destino = id;
            string cobro = monedaCobro == "USD" ? "USD" : "UF";
            if (id > 0)
            {
                string actual = Convert.ToString(Limpia(SoporteDatos.Filas("SEL_CLIENTE_COMERCIAL_LISTA")).First(x => Convert.ToInt32(x["ID"]) == id)["MONEDA_COBRO"]);
                if (cobro != actual)
                {
                    if (!Token.Puede(P_MONEDA)) throw new Exception("No tienes la facultad para cambiar la moneda de cobro.");
                    if (string.IsNullOrWhiteSpace(motivo)) throw new Exception("Indica el motivo del cambio de moneda de cobro.");
                }
                Respuesta r = c.UpdateCliente(e);
                if (r.error) throw new Exception(r.detalle);
                if (cobro != actual) SpSalida("UPS_CLIENTE_MONEDA_COBRO", null, "@ID", id, "@MONEDA", cobro, "@MOTIVO", motivo.Trim(), "@USUARIO", SoporteDatos.Usuario());
                return new { mensaje = r.detalle, id = id, ficha = FichaCliente(id) };
            }
            Respuesta ins = c.InsertCliente(e);
            if (ins.error) throw new Exception(ins.detalle);
            destino = ins.codigo;
            // Moneda inicial según el país (el formulario ya la propuso; aquí se asegura).
            SpSalida("UPS_CLIENTE_MONEDA_COBRO", null, "@ID", destino, "@MONEDA", pais == 1 ? "UF" : "USD", "@MOTIVO", null, "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = ins.detalle, id = destino, ficha = FichaCliente(destino) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarContacto(int cliente, string nombre, string cargo, string correo, string telefono, bool principal)
    {
        return Ejecutar(() =>
        {
            if (!Token.PuedePagina("~/View/Comercial/Clientes/Cliente.aspx")) throw new Exception("No tienes la facultad para editar clientes.");
            if (string.IsNullOrWhiteSpace(nombre)) throw new Exception("Indica el nombre del contacto.");
            SpSalida("INS_CLIENTE_CONTACTO", new[] { "@ID" }, "@CLIENTE", cliente, "@NOMBRE", nombre.Trim(), "@CARGO", Nulo(cargo), "@EMPRESA", null, "@RUBRO", null, "@EMAIL", Nulo(correo),
                "@TELEFONO", Nulo(telefono), "@DIRECCION", null, "@NOTAS", null, "@PRINCIPAL", principal, "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = "Contacto agregado.", ficha = FichaCliente(cliente) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarContacto(int cliente, int contacto)
    {
        return Ejecutar(() =>
        {
            if (!Token.PuedePagina("~/View/Comercial/Clientes/Cliente.aspx")) throw new Exception("No tienes la facultad para editar clientes.");
            SpSalida("DEL_CLIENTE_CONTACTO", null, "@ID", contacto, "@CLIENTE", cliente, "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = "Contacto quitado.", ficha = FichaCliente(cliente) };
        });
    }

    private static object Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

    // =====================================================================
    // PLAN
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Plan(int id)
    {
        return Ejecutar(() => { Exigir(P_VER); return FichaPlan(id); });
    }

    private static object FichaPlan(int id)
    {
        PlanComercialController pc = new PlanComercialController();
        SitioBase.Model.PlanComercial p = id > 0 ? pc.GetPlan(new SitioBase.Model.PlanComercial { plc_id = id }) : new SitioBase.Model.PlanComercial { plc_habilitado = true, plc_dias_gracia = 5, plc_orden = 10 };
        if (id > 0 && (p == null || p.plc_id == 0)) throw new Exception("El plan no existe.");
        Dictionary<string, string> modulo = new Dictionary<string, string>();
        foreach (Dictionary<string, object> m in SoporteDatos.Filas("SEL_COMERCIAL_MODULO_FUNCIONALIDAD")) modulo[Convert.ToString(m["FUN_CODIGO"])] = Convert.ToString(m["MODULO"]);
        CatalogoController cat = new CatalogoController();
        return new
        {
            plan = new { id = p.plc_id, codigo = p.plc_codigo, nombre = p.plc_nombre, descripcion = p.plc_descripcion, orden = p.plc_orden, gracia = p.plc_dias_gracia, publico = p.plc_publico, habilitado = p.plc_habilitado },
            precios = id > 0 ? Limpia(SoporteDatos.Filas("SEL_PLAN_COMERCIAL_PRECIO", "@PLAN", id)) : new List<Dictionary<string, object>>(),
            funcionalidades = id > 0
                ? (pc.GetFuncionalidades(id) ?? new List<SitioBase.Model.PlanFuncionalidad>()).Select(f => (object)new
                {
                    id = f.fun_id, codigo = f.fun_codigo, nombre = f.fun_nombre, modulo = (f.EsLimite || f.fun_codigo.StartsWith("LIMITE ")) ? "LIMITES" : (modulo.ContainsKey(f.fun_codigo) ? modulo[f.fun_codigo] : "OTROS"),
                    limite = f.EsLimite || f.fun_codigo.StartsWith("LIMITE "), incluida = f.pcf_incluida && !f.caducada, tope = f.pcf_limite, origen = (f.origen ?? "").Trim(), caduca = f.pcf_vigencia_hasta.HasValue ? f.pcf_vigencia_hasta.Value.ToString("yyyy-MM-dd") : null
                }).ToList()
                : new List<object>(),
            modulos = Comercial.MODULOS.Select(m => new { id = m[0], n = m[1] }).ToList(),
            periodicidades = (cat.GetValoresPorCodigo("PERIODICIDAD_COBRO", SitioBase.Session.ClienteId()) ?? new List<SitioBase.Model.CatalogoValor>()).Select(v => new { id = v.valor_id, n = v.valor_nombre }).ToList(),
            editar = Token.Puede(P_PLANES)
        };
    }

    /// <summary>
    /// Crea o actualiza el plan. Dar de baja (habilitado = false) pasa PRIMERO por
    /// DeletePlan, que tiene guarda: un plan que clientes están pagando no cae.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarPlan(int id, string codigo, string nombre, string descripcion, int orden, int gracia, bool publico, bool habilitado)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PLANES);
            PlanComercialController c = new PlanComercialController();
            SitioBase.Model.PlanComercial e = new SitioBase.Model.PlanComercial
            {
                plc_id = id, plc_codigo = SitioBase.CodigoModulo.Componer("Plan_Comercial", codigo), plc_nombre = (nombre ?? "").Trim(), plc_descripcion = (descripcion ?? "").Trim(),
                plc_orden = orden, plc_dias_gracia = gracia, plc_publico = publico, plc_habilitado = id == 0 ? true : habilitado
            };
            if (id > 0 && !habilitado)
            {
                Respuesta baja = c.DeletePlan(id);
                if (baja.error) throw new Exception(baja.detalle);
            }
            Respuesta r = id > 0 ? c.UpdatePlan(e) : c.InsertPlan(e);
            if (r.error) throw new Exception(r.detalle);
            int nuevo = id > 0 ? id : r.codigo;
            return new { mensaje = r.detalle, id = nuevo, ficha = FichaPlan(nuevo) };
        });
    }

    /// <summary>Un precio vigente no se edita: se fija uno nuevo y el anterior queda cerrado. UF o USD.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string FijarPrecio(int plan, int periodicidad, string moneda, string valor, string descuento, string desde)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PLANES);
            decimal? v = Monto(valor);
            if (!v.HasValue || v.Value <= 0) throw new Exception("El valor debe ser mayor que cero.");
            DateTime d; DateTime? dd = DateTime.TryParseExact((desde ?? "").Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? (DateTime?)d.Date : null;
            SitioBase.Model.PlanComercialPrecio e = new SitioBase.Model.PlanComercialPrecio
            {
                pcp_plan_comercial = plan, pcp_periodicidad_cobro = periodicidad, pcp_moneda = moneda == "USD" ? "USD" : "UF",
                pcp_valor_uf = v.Value, pcp_descuento_porcentaje = Monto(descuento), vigencia_desde = dd
            };
            Respuesta r = new PlanComercialController().FijarPrecio(e);
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, ficha = FichaPlan(plan) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RetirarPrecio(int plan, int precio)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PLANES);
            Respuesta r = new PlanComercialController().RetirarPrecio(new SitioBase.Model.PlanComercialPrecio { pcp_id = precio });
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, ficha = FichaPlan(plan) };
        });
    }

    /// <summary>Qué incluye el plan. Tope vacío con la casilla marcada = sin límite; cero es no poder crear ninguno.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarFuncionalidades(int plan, List<Dictionary<string, object>> filas)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PLANES);
            PlanComercialController c = new PlanComercialController();
            int n = 0; string errores = "";
            foreach (Dictionary<string, object> f in filas ?? new List<Dictionary<string, object>>())
            {
                SitioBase.Model.PlanFuncionalidad e = new SitioBase.Model.PlanFuncionalidad { fun_id = Convert.ToInt32(f["id"]), pcf_incluida = Convert.ToBoolean(f["incluida"]) };
                string tope = f.ContainsKey("tope") && f["tope"] != null ? Convert.ToString(f["tope"]) : null;
                if (!string.IsNullOrWhiteSpace(tope)) e.pcf_limite = Monto(tope);
                Respuesta r = c.GuardarFuncionalidad(plan, e);
                if (r.error) errores += r.detalle + " "; else n++;
            }
            if (errores.Length > 0) throw new Exception(errores.Trim());
            return new { mensaje = "Contenido del plan actualizado: " + n + " funcionalidades.", ficha = FichaPlan(plan) };
        });
    }

    // =====================================================================
    // PAGO
    // =====================================================================

    /// <summary>
    /// El pago, su período y el comprobante. En un pago de Webpay trae además
    /// la tarjeta enmascarada, la autorización y la orden de compra, que se
    /// leen de Pago_Webpay por la orden que viaja en el número de operación.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Pago(int id)
    {
        return Ejecutar(() => { Exigir(P_VER); return FichaPago(id); });
    }

    private static object FichaPago(int id)
    {
        Dictionary<string, object> p = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO", "@ID", id)).FirstOrDefault();
        if (p == null) throw new Exception("El pago no existe.");
        Dictionary<string, object> per = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@ID", Convert.ToInt32(p["SPA_PERIODO"]))).FirstOrDefault();
        int arc = p["SPA_ARCHIVO"] == null ? 0 : Convert.ToInt32(p["SPA_ARCHIVO"]);
        object comprobante = null;
        if (arc > 0)
        {
            SitioBase.Model.Archivo a = new ArchivoController().GetArchivo(new SitioBase.Model.Archivo { arc_id = arc });
            if (a != null && a.arc_id > 0)
                comprobante = new { id = a.arc_id, nombre = a.arc_nombre_original, mime = a.arc_mime, bytes = a.arc_byte, ver = UrlArchivo.Ver(arc), bajar = UrlArchivo.Descargar(arc) };
        }
        object webpay = null;
        if (Convert.ToString(p["SPA_MEDIO"]) == "WEBPAY")
        {
            string[] partes = Convert.ToString(p["SPA_NUMERO_OPERACION"]).Split(new[] { " · " }, StringSplitOptions.None);
            if (partes.Length >= 2)
            {
                Dictionary<string, object> w = SoporteDatos.Fila("SEL_PAGO_WEBPAY", "@BUY_ORDER", partes[1].Trim());
                if (w.ContainsKey("ID"))
                    webpay = new { tarjeta = w["TARJETA"], autorizacion = w["AUTORIZACION"], orden = w["BUY_ORDER"], tipo = w["TIPO_PAGO"], cuotas = w["CUOTAS"], ambiente = w["AMBIENTE"] };
            }
        }
        return new
        {
            pago = p, periodo = per, comprobante = comprobante, webpay = webpay,
            datos = DatosBancarios(per != null && Convert.ToString(per["SPE_MONEDA"]) == "USD" ? "USD" : "CLP"),
            permisos = new { verificar = Token.Puede(P_VERIFICAR), declarar = Token.Puede(P_DECLARAR) }
        };
    }

    /// <summary>Datos para transferir según la moneda del cobro; salen de Configuración, no del código.</summary>
    private static object DatosBancarios(string moneda)
    {
        string grupo = moneda == "USD" ? "BANCO_INTERNACIONAL" : "BANCO_NACIONAL";
        return Limpia(SoporteDatos.Filas("SEL_CONFIG_COMERCIAL", "@GRUPO", grupo)).Select(f => new { clave = f["CLAVE"], etiqueta = f["ETIQUETA"], valor = f["VALOR"] }).ToList();
    }

    /// <summary>Pagos por verificar y recientes (pestaña Suscripciones › Pagos).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ListaPagos()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            ExigirPagina("~/View/Comercial/Suscripciones/Pagos.aspx", "ver pagos");
            List<Dictionary<string, object>> todos = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO"));
            return new
            {
                porVerificar = todos.Where(x => Convert.ToInt32(x["SPA_ESTADO"]) == 1 || Convert.ToInt32(x["SPA_ESTADO"]) == 2).ToList(),
                recientes = todos.Where(x => Convert.ToInt32(x["SPA_ESTADO"]) != 1 && Convert.ToInt32(x["SPA_ESTADO"]) != 2).Take(60).ToList(),
                verificar = Token.Puede(P_VERIFICAR), declarar = Token.Puede(P_DECLARAR), banco = Token.Puede(P_EDITAR)
            };
        });
    }

    /// <summary>Lo que pide acción en el Resumen: transferencias por verificar, mora y suscripciones por suspender.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Atencion()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            if (!Token.PuedePagina("~/View/Comercial/Suscripciones/Pagos.aspx")) return new { porVerificar = new List<Dictionary<string, object>>(), mora = new List<Dictionary<string, object>>() };
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_COBRO_ATENCION");
            return new { porVerificar = Limpia(SoporteDatos.Del(c, 0)), mora = Limpia(SoporteDatos.Del(c, 1)) };
        });
    }

    /// <summary>Períodos con saldo de una suscripción y los datos para transferir, para informar un pago.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string OpcionesPago(int suscripcion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_DECLARAR);
            List<Dictionary<string, object>> per = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@SUSCRIPCION", suscripcion, "@SOLO_IMPAGOS", true))
                .Where(x => Convert.ToBoolean(x["SPE_HABILITADO"]) && Convert.ToInt32(x["SPE_ESTADO"]) != 5).ToList();
            string moneda = per.Count > 0 && Convert.ToString(per[0]["SPE_MONEDA"]) == "USD" ? "USD" : "CLP";
            SitioBase.Model.Suscripcion s = new SuscripcionController().GetSuscripcion(new SitioBase.Model.Suscripcion { sus_id = suscripcion });
            return new { periodos = per, moneda = moneda, cliente = s.cli_nombre, clienteId = s.sus_cliente, datos = DatosBancarios(moneda), almacenamiento = Almacenamiento.Actual().Disponible };
        });
    }

    /// <summary>
    /// El cliente (o el ejecutivo por él) informa una transferencia con su comprobante.
    /// El comprobante se sube primero: sin él no hay nada que verificar. Si el pago no
    /// entra, el archivo se da de baja para no dejar uno colgando.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string InformarPago(int periodo, string monto, string fecha, string banco, string operacion, string archivoNombre, string archivoMime, string archivoBase64)
    {
        return Ejecutar(() =>
        {
            Exigir(P_DECLARAR);
            decimal? m = Monto(monto);
            if (!m.HasValue || m.Value <= 0) throw new Exception("El monto transferido debe ser mayor que cero.");
            DateTime f;
            if (!DateTime.TryParseExact((fecha ?? "").Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f)) throw new Exception("Elige la fecha de la transferencia.");
            if (f.Date > Hora.Hoy.Date) throw new Exception("La fecha de la transferencia no puede ser futura.");
            if (string.IsNullOrEmpty(archivoBase64)) throw new Exception("Debes adjuntar el comprobante de la transferencia.");

            Dictionary<string, object> per = SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@ID", periodo).FirstOrDefault();
            if (per == null) throw new Exception("El período no existe.");
            byte[] bytes = Convert.FromBase64String(archivoBase64);
            if (bytes.Length == 0 || bytes.Length > 8 * 1024 * 1024) throw new Exception("El comprobante debe pesar entre 1 byte y 8 MB.");

            ArchivoController archivos = new ArchivoController();
            SitioBase.Model.Archivo a = new SitioBase.Model.Archivo
            {
                arc_cliente = Convert.ToInt32(per["SUS_CLIENTE"]), arc_archivo_categoria = ArchivoController.CATEGORIA_COMPROBANTE_PAGO,
                arc_nombre_original = System.IO.Path.GetFileName(string.IsNullOrEmpty(archivoNombre) ? "comprobante" : archivoNombre),
                arc_mime = string.IsNullOrEmpty(archivoMime) ? "application/octet-stream" : archivoMime, contenido = bytes
            };
            Respuesta subida = archivos.InsertArchivo(a, "comprobantes");
            if (subida.error || subida.codigo <= 0) throw new Exception("No se pudo guardar el comprobante: " + subida.detalle);
            try
            {
                Dictionary<string, object> o = SpSalida("INS_SUSCRIPCION_PAGO", new[] { "@ID" }, "@PERIODO", periodo, "@MONTO_DECLARADO", m.Value, "@FECHA_TRANSFERENCIA", f.Date,
                    "@BANCO", (banco ?? "").Trim(), "@NUMERO_OPERACION", string.IsNullOrWhiteSpace(operacion) ? null : operacion.Trim(), "@ARCHIVO", subida.codigo, "@USUARIO", SoporteDatos.Usuario());
                int id = Convert.ToInt32(o["@ID"]);
                return new { mensaje = "Pago informado. Queda esperando verificación.", id = id, ficha = FichaPago(id) };
            }
            catch (Exception)
            {
                archivos.DeleteArchivo(new SitioBase.Model.Archivo { arc_id = subida.codigo });
                throw;
            }
        });
    }

    /// <summary>Corrige lo que se declaró mal; solo mientras el pago no esté verificado.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CorregirPago(int id, string monto, string fecha, string banco, string operacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_DECLARAR);
            decimal? m = Monto(monto);
            DateTime f; DateTime? ff = DateTime.TryParseExact((fecha ?? "").Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f) ? (DateTime?)f.Date : null;
            SpSalida("UPD_SUSCRIPCION_PAGO", null, "@ID", id, "@MONTO_DECLARADO", m, "@FECHA_TRANSFERENCIA", ff, "@BANCO", string.IsNullOrWhiteSpace(banco) ? null : banco.Trim(),
                "@NUMERO_OPERACION", string.IsNullOrWhiteSpace(operacion) ? null : operacion.Trim(), "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = "Pago corregido. Vuelve a quedar por verificar.", ficha = FichaPago(id) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string VerificarPago(int id, string montoVerificado)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VERIFICAR);
            decimal? m = Monto(montoVerificado);
            SpSalida("UPD_SUSCRIPCION_PAGO_VERIFICAR", null, "@ID", id, "@VERIFICADO", true, "@MONTO_VERIFICADO", m, "@MOTIVO_RECHAZO", null, "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = "Pago verificado. El período queda al día y el acceso se extiende.", ficha = FichaPago(id) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string RechazarPago(int id, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VERIFICAR);
            if (string.IsNullOrWhiteSpace(motivo) || motivo.Trim().Length < 5) throw new Exception("Indica el motivo del rechazo (al menos 5 letras).");
            SpSalida("UPD_SUSCRIPCION_PAGO_VERIFICAR", null, "@ID", id, "@VERIFICADO", false, "@MONTO_VERIFICADO", null, "@MOTIVO_RECHAZO", motivo.Trim(), "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = "Pago rechazado. El cliente puede corregirlo y volver a informarlo.", ficha = FichaPago(id) };
        });
    }

    // =====================================================================
    // DATOS PARA TRANSFERIR (Configuración)
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string DatosTransferencia()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            return new { filas = Limpia(SoporteDatos.Filas("SEL_CONFIG_COMERCIAL")), editar = Token.Puede(P_EDITAR) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarDatosTransferencia(List<Dictionary<string, object>> filas)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            foreach (Dictionary<string, object> f in filas ?? new List<Dictionary<string, object>>())
                SpSalida("UPD_CONFIG_COMERCIAL", null, "@CLAVE", Convert.ToString(f["clave"]), "@VALOR", f.ContainsKey("valor") ? Convert.ToString(f["valor"]) : null, "@USUARIO", SoporteDatos.Usuario());
            return new { mensaje = "Datos para transferir guardados.", filas = Limpia(SoporteDatos.Filas("SEL_CONFIG_COMERCIAL")) };
        });
    }

    // =====================================================================
    // APOYO
    // =====================================================================

    /// <summary>
    /// Ejecuta un SP con parámetros de entrada en pares. Los de salida (todos INT) se piden
    /// por nombre y vuelven en el diccionario. Los RAISERROR del SP llegan como excepción.
    /// </summary>
    private static Dictionary<string, object> SpSalida(string sp, string[] salidas, params object[] ps)
    {
        SqlCommand cmd = Conexion.GetCommand(sp);
        Dictionary<string, object> r = new Dictionary<string, object>();
        try
        {
            foreach (string s in salidas ?? new string[0]) cmd.Parameters.Add(s, SqlDbType.Int).Direction = ParameterDirection.Output;
            for (int i = 0; i + 1 < ps.Length; i += 2) cmd.Parameters.AddWithValue((string)ps[i], ps[i + 1] ?? DBNull.Value);
            cmd.ExecuteNonQuery();
            foreach (string s in salidas ?? new string[0]) r[s] = cmd.Parameters[s].Value == DBNull.Value ? null : cmd.Parameters[s].Value;
        }
        finally { if (cmd.Connection != null) cmd.Connection.Close(); }
        return r;
    }

    /// <summary>Acepta punto o coma, como el formulario de siempre: quien escribe en es-CL usa coma.</summary>
    private static decimal? Monto(string texto)
    {
        if (string.IsNullOrWhiteSpace(texto)) return null;
        decimal v;
        if (!decimal.TryParse(texto.Trim().Replace(",", "."), NumberStyles.Float, CultureInfo.InvariantCulture, out v)) throw new Exception("El monto no es un número válido.");
        if (v < 0) throw new Exception("El monto no puede ser negativo.");
        return v;
    }

    private static string Fecha(DateTime? d) { return d.HasValue ? d.Value.ToString("yyyy-MM-dd") : null; }

    /// <summary>Fechas como texto «aaaa-mm-dd»: el navegador no recibe objetos Date.</summary>
    private static List<Dictionary<string, object>> Limpia(List<Dictionary<string, object>> filas)
    {
        foreach (Dictionary<string, object> f in filas)
            foreach (string k in f.Keys.ToList())
                if (f[k] is DateTime) f[k] = ((DateTime)f[k]).ToString("yyyy-MM-dd");
        return filas;
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
            return WsSoporte.Json(new { error = true, detalle = WsComercial.Limpio(ex.Message) });
        }
    }

    private static void Exigir(string permiso)
    {
        if (!Token.Puede(permiso)) throw new Exception("No tienes la facultad para esta acción en los cobros.");
    }

    private static void ExigirPagina(string url, string accion)
    {
        if (!Token.PuedePagina(url)) throw new Exception("No tienes la facultad para " + accion + ".");
    }
}
