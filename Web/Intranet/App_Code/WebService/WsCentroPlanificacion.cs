using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections;
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
/// Centro de Planificación (MD/CENTRO_PLANIFICACION_ALCANCE.md): la lista de
/// planes, la ficha y TODAS sus escrituras. Las lecturas de Ejecuciones,
/// Cumplimiento y Cobertura siguen en WsPlanificacion360.
///
/// CADA MÉTODO VALIDA SESIÓN Y PERMISO
///   El id identifica, no autoriza: los SP vuelven a exigir el cliente y que
///   el registro sea de ese plan (UPS_PLAN_BORRADOR_ASEGURAR).
///
/// EL BORRADOR ES IMPLÍCITO (RP-04)
///   Una escritura sobre la estructura de un plan activo abre su borrador y
///   traduce los ids de la versión publicada a los del borrador. Cuando eso
///   pasa la respuesta trae recargar = true y la pantalla vuelve a pedir la
///   ficha (los ids cambiaron).
///
/// LOS MENSAJES SON LOS DEL SP
///   Solo se les quita el número («6.- ») y la caja alta; el texto no se
///   reescribe aquí ni en el navegador.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsCentroPlanificacion : System.Web.Services.WebService
{
    private const string P_VER = "VER PLANES MANTENIMIENTO";
    private const string P_EDITAR = "CREAR EDITAR PLANES MANTENIMIENTO";
    private const string P_OT = "CREAR ORDEN TRABAJO";
    private const string P_PROC_VER = "VER PROCEDIMIENTOS";
    private const string P_PROC_EDITAR = "CREAR EDITAR PROCEDIMIENTOS";
    private const string P_PROG_VER = "VER PROGRAMACIONES";
    private const int HORIZONTE = 90;

    // =====================================================================
    // LECTURAS
    // =====================================================================

    /// <summary>La lista del workspace y los conteos de los chips.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Lista(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<Dictionary<string, object>> planes = SoporteDatos.Filas("SEL_PLAN_CENTRO", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            foreach (Dictionary<string, object> p in planes) p["Q"] = Q(Entero(p, "PLAN_ID"));
            return new
            {
                planes = planes,
                conteos = new
                {
                    todos = planes.Count,
                    activos = planes.Count(p => Texto(p, "ESTADO") == "ACTIVO"),
                    borradores = planes.Count(p => Texto(p, "ESTADO") == "BORRADOR"),
                    cambios = planes.Count(p => Texto(p, "ESTADO") == "CAMBIOS"),
                    inactivos = planes.Count(p => Texto(p, "ESTADO") == "INACTIVO"),
                    atencion = planes.Count(p => Entero(p, "VENCIDAS") + Entero(p, "ATRASADAS") > 0)
                },
                permisos = Permisos()
            };
        });
    }

    /// <summary>Todo lo que pinta la ficha de un plan.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ficha(int plan)
    {
        return Ejecutar(() => { Exigir(P_VER); return ArmarFicha(plan); });
    }

    /// <summary>Los combos del Centro, una vez por carga de página.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Catalogos()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_PLAN_CENTRO_CATALOGO", "@CLIENTE", Cli());
            return new
            {
                plantas = SoporteDatos.Del(c, 0), tipos = SoporteDatos.Del(c, 1), modelos = SoporteDatos.Del(c, 2),
                personas = SoporteDatos.Del(c, 3), grupos = SoporteDatos.Del(c, 4), otTipos = SoporteDatos.Del(c, 5),
                prioridades = SoporteDatos.Del(c, 6), permisos = SoporteDatos.Del(c, 7), frecuencias = SoporteDatos.Del(c, 8),
                unidades = SoporteDatos.Del(c, 9), dias = SoporteDatos.Del(c, 10), calendarios = SoporteDatos.Del(c, 11),
                hoy = global::SitioBase.Hora.Hoy.ToString("yyyy-MM-dd"),
                horizonte = HORIZONTE
            };
        });
    }

    /// <summary>Los conteos de la confirmación de Activar, Aplicar cambios o Desactivar.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Impacto(int plan)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            return SoporteDatos.Fila("SEL_PLAN_IMPACTO", "@CLIENTE", Cli(), "@PLAN", plan, "@HORIZONTE", HORIZONTE);
        });
    }

    /// <summary>Las próximas fechas de una intervención (vista previa del editor).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Proyeccion(int hito)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            return new { fechas = SoporteDatos.Filas("SEL_PLAN_HITO_PROYECCION", "@CLIENTE", Cli(), "@HITO", hito, "@TOPE", 6) };
        });
    }

    /// <summary>Los activos que se pueden agregar, con su motivo si no calzan con el alcance.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Candidatos(int plan, string filtro)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_PLAN_ACTIVO_CANDIDATO", "@CLIENTE", Cli(),
                "@PLAN", plan > 0 ? (object)plan : null, "@FILTRO", Nulo(filtro));
            return new { activos = SoporteDatos.Del(c, 0), componentes = SoporteDatos.Del(c, 1), medidores = SoporteDatos.Del(c, 2) };
        });
    }

    /// <summary>Procedimientos del cliente (última versión, sin los globales) para elegir.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Procedimientos(string filtro, int tipo)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede(P_PROC_VER) && !Token.Puede(P_EDITAR)) throw new Exception("No tienes permiso para ver procedimientos.");
            List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", Cli(), "@FILTRO", Nulo(filtro),
                "@HABILITADO", true, "@ACTIVO_TIPO", tipo > 0 ? (object)tipo : null, "@SOLO_ULTIMA", true);
            List<Dictionary<string, object>> r = l.Where(x => !Bool(x, "ES_GLOBAL")).ToList();
            foreach (Dictionary<string, object> x in r) x["Q"] = Q(Entero(x, "PRC_ID"));
            return new { procedimientos = r };
        });
    }

    /// <summary>Los pasos de un procedimiento (vista previa al elegir).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ProcedimientoPasos(int procedimiento)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede(P_PROC_VER) && !Token.Puede(P_EDITAR)) throw new Exception("No tienes permiso para ver procedimientos.");
            return new { pasos = SoporteDatos.Filas("SEL_PROCEDIMIENTO_PASO", "@CLIENTE", Cli(), "@PROCEDIMIENTO", procedimiento, "@HABILITADO", true) };
        });
    }

    /// <summary>Sugerencias de repuestos para agregarlos en la fila de la actividad.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Repuestos(string filtro)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            string f = Nulo(filtro) as string;
            if (f == null || f.Length < 2) return new { repuestos = new List<object>() };
            return new
            {
                repuestos = SoporteDatos.Filas("SEL_REPUESTO", "@CLIENTE", Cli(), "@FILTRO", f, "@HABILITADO", true).Take(15)
                    .Select(r => new { id = Valor(r, "REP_ID", "rep_id"), codigo = Valor(r, "REP_CODIGO", "rep_codigo"), nombre = Valor(r, "REP_NOMBRE", "rep_nombre") })
                    .ToList()
            };
        });
    }

    // =====================================================================
    // PLAN
    // =====================================================================

    /// <summary>
    /// «Nuevo plan» (solo el nombre) y «Crear plan con estos activos»
    /// (Cobertura): crea el plan con su borrador v1 y agrega los activos.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CrearPlan(string nombre, int planta, int tipo, string activos)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            int id = ExecId("INS_PLAN_MANTENIMIENTO", "@CLIENTE", Cli(), "@CLIENTE_INSTALACION", planta > 0 ? (object)planta : null,
                "@CODIGO", "AUTO", "@NOMBRE", (nombre ?? "").Trim(), "@ACTIVO_TIPO", tipo > 0 ? (object)tipo : null, "@USUARIO", U());
            List<object> resultados = new List<object>();
            if (!string.IsNullOrWhiteSpace(activos))
                foreach (string a in activos.Split(','))
                {
                    int act; if (!int.TryParse(a, out act)) continue;
                    resultados.Add(AgregarActivo(id, act, null, null));
                }
            return new { plan = id, q = Q(id), resultados = resultados };
        });
    }

    /// <summary>
    /// Un campo de la cabecera: nombre, descripción, planta, tipo, modelo o
    /// planificador. Son datos del plan (no de la versión): no abren borrador.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarPlan(int plan, string campo, string valor)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            DelCliente(plan);
            List<object> p = new List<object> { "@ID", plan, "@USUARIO", U() };
            int n;
            bool vacio = string.IsNullOrWhiteSpace(valor);
            switch ((campo ?? "").ToLowerInvariant())
            {
                case "nombre": p.AddRange(new object[] { "@NOMBRE", (valor ?? "").Trim() }); break;
                case "descripcion": p.AddRange(new object[] { "@DESCRIPCION", vacio ? "" : valor.Trim() }); break;
                case "planta": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@CLIENTE_INSTALACION", n }); else p.AddRange(new object[] { "@QUITA_INSTALACION", true }); break;
                case "tipo":
                    if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@ACTIVO_TIPO", n, "@QUITA_MODELO", true });
                    else p.AddRange(new object[] { "@QUITA_TIPO", true, "@QUITA_MODELO", true });
                    break;
                case "modelo": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@ACTIVO_MODELO", n }); else p.AddRange(new object[] { "@QUITA_MODELO", true }); break;
                case "planificador": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@USUARIO_PLANIFICADOR", n }); else p.AddRange(new object[] { "@QUITA_PLANIFICADOR", true }); break;
                default: throw new Exception("El campo no existe.");
            }
            Exec("UPD_PLAN_MANTENIMIENTO", p.ToArray());
            return new { ok = true };
        });
    }

    // =====================================================================
    // ACTIVOS
    // =====================================================================

    /// <summary>Agregar varios activos de una vez; resultado por fila (CA-07).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AgregarActivos(int plan, string items)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, null, null, null);
            List<object> resultados = new List<object>();
            foreach (Dictionary<string, object> it in Lista(items))
                resultados.Add(AgregarActivo(plan, Entero(it, "activo"), EnteroNulo(it, "componente"), EnteroNulo(it, "medidor")));
            return new { resultados = resultados, recargar = true, borradorCreado = Bool(m, "CREADO") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarActivo(int plan, int vinculo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, null, vinculo, null);
            int v = Entero(m, "VINCULO");
            if (v <= 0) throw new Exception("El activo ya no está en la planificación.");
            Exec("DEL_PLAN_ACTIVO", "@ID", v);
            return new { ok = true, recargar = Bool(m, "CREADO") };
        });
    }

    // =====================================================================
    // INTERVENCIONES
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AgregarIntervencion(int plan, string nombre)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, null, null, null);
            int id = ExecId("INS_PLAN_HITO", "@CLIENTE", Cli(), "@PLAN", plan,
                "@NOMBRE", string.IsNullOrWhiteSpace(nombre) ? "Nueva intervención" : nombre.Trim(),
                "@DURACION_ESTIMADA_MINUTO", 60, "@ORDEN_TRABAJO_TIPO", 1, "@ORDEN_TRABAJO_PRIORIDAD", 2, "@USUARIO", U());
            return new { hito = id, recargar = true, borradorCreado = Bool(m, "CREADO") };
        });
    }

    /// <summary>Un campo de la intervención (datos de la OT y quién).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarIntervencion(int plan, int hito, string campo, string valor)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, hito, null, null, null);
            int h = Entero(m, "HITO");
            if (h <= 0) throw new Exception("La intervención ya no está en la planificación.");
            List<object> p = new List<object> { "@ID", h, "@USUARIO", U() };
            int n;
            bool vacio = string.IsNullOrWhiteSpace(valor);
            switch ((campo ?? "").ToLowerInvariant())
            {
                case "nombre": p.AddRange(new object[] { "@NOMBRE", (valor ?? "").Trim() }); break;
                case "descripcion": p.AddRange(new object[] { "@DESCRIPCION", vacio ? "" : valor.Trim() }); break;
                case "duracion":
                    if (vacio) p.AddRange(new object[] { "@QUITA_DURACION", true });
                    else if (int.TryParse(valor, out n)) p.AddRange(new object[] { "@DURACION_ESTIMADA_MINUTO", n });
                    else throw new Exception("La duración debe ser mayor que 0.");
                    break;
                case "parada": p.AddRange(new object[] { "@REQUIERE_PARADA", Si(valor) }); break;
                case "overhaul": p.AddRange(new object[] { "@ES_OVERHAUL", Si(valor) }); break;
                case "habilitado": p.AddRange(new object[] { "@HABILITADO", Si(valor) }); break;
                case "tipo": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@ORDEN_TRABAJO_TIPO", n }); else p.AddRange(new object[] { "@QUITA_OT_TIPO", true }); break;
                case "prioridad": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@ORDEN_TRABAJO_PRIORIDAD", n }); else p.AddRange(new object[] { "@QUITA_OT_PRIORIDAD", true }); break;
                case "responsable": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@USUARIO_RESPONSABLE", n }); else p.AddRange(new object[] { "@QUITA_RESPONSABLE", true }); break;
                case "grupo": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@GRUPO_TRABAJO", n }); else p.AddRange(new object[] { "@QUITA_GRUPO", true }); break;
                case "orden": if (int.TryParse(valor, out n)) p.AddRange(new object[] { "@ORDEN", n }); break;
                default: throw new Exception("El campo no existe.");
            }
            Exec("UPD_PLAN_HITO", p.ToArray());
            return new { ok = true, hito = h, recargar = Bool(m, "CREADO") };
        });
    }

    /// <summary>Quitar una intervención del borrador (solo si nunca generó).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarIntervencion(int plan, int hito)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, hito, null, null, null);
            int h = Entero(m, "HITO");
            if (h <= 0) throw new Exception("La intervención ya no está en la planificación.");
            Exec("DEL_PLAN_HITO_BORRADOR", "@CLIENTE", Cli(), "@ID", h, "@USUARIO", U());
            return new { ok = true, recargar = true };
        });
    }

    /// <summary>
    /// La frecuencia completa de una intervención (§15). La cabecera va por
    /// UPS_PLAN_HITO_FRECUENCIA (copia al escribir) y el detalle por los SP de
    /// siempre, sobre la programación que devuelve. Responde la vista previa.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarFrecuencia(int plan, int hito, string datos)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos ?? "{}");
            string tipo = Texto(d, "tipo").ToUpperInvariant();
            ValidarFrecuencia(tipo, d);

            Dictionary<string, object> m = Asegurar(plan, hito, null, null, null);
            int h = Entero(m, "HITO");
            if (h <= 0) throw new Exception("La intervención ya no está en la planificación.");
            int cli = Cli(), usu = U();

            object hasta = Fecha(d, "hasta");
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_PLAN_HITO_FRECUENCIA", "@CLIENTE", cli, "@HITO", h, "@TIPO_CODIGO", tipo,
                "@FECHA_INICIO", Fecha(d, "desde"), "@FECHA_FIN", hasta, "@QUITA_FIN", hasta == null,
                "@TOL_ANTES", Entero(d, "tolAntes"), "@TOL_DESPUES", Entero(d, "tolDespues"), "@USUARIO", usu);
            int pro = Entero(r, "PROGRAMACION");

            switch (tipo)
            {
                case "CALENDARIO":
                    {
                        Dictionary<string, object> c = Dicc(d, "calendario");
                        TimeSpan hora;
                        if (!TimeSpan.TryParse(Texto(c, "hora"), out hora)) hora = new TimeSpan(8, 0, 0);
                        SoporteDatos.Conjuntos("UPS_PROGRAMACION_CALENDARIO", "@PROGRAMACION", pro, "@CLIENTE", cli,
                            "@FRECUENCIA", Entero(c, "frecuencia"), "@INTERVALO", Math.Max(1, Entero(c, "intervalo")),
                            "@SEMANA_ORDINAL", EnteroNulo(c, "ordinal"), "@DIA_MES", EnteroNulo(c, "diaMes"), "@MES", EnteroNulo(c, "mes"),
                            "@HORA_LOCAL", hora, "@DIAS", Nulo(string.Join(",", ListaTexto(c, "dias"))), "@USUARIO", usu);
                        break;
                    }
                case "INTERVALO TIEMPO":
                    {
                        Dictionary<string, object> c = Dicc(d, "intervalo");
                        SoporteDatos.Conjuntos("UPS_PROGRAMACION_INTERVALO", "@PROGRAMACION", pro, "@CLIENTE", cli,
                            "@UNIDAD_TIEMPO", Entero(c, "unidad"), "@CANTIDAD", Entero(c, "cantidad"),
                            "@FECHA_ANCLA_UTC", FechaHora(c, "ancla"), "@USUARIO", usu);
                        break;
                    }
                case "MEDIDOR":
                    {
                        Dictionary<string, object> c = Dicc(d, "medidor");
                        object cada = Decimal(c, "cada");
                        SoporteDatos.Conjuntos("UPS_PROGRAMACION_MEDIDOR", "@PROGRAMACION", pro, "@CLIENTE", cli,
                            "@ACTIVO_MEDIDOR", null, "@VALOR_INICIAL", Decimal(c, "inicial"), "@CADA_CANTIDAD", cada,
                            "@AVISO_ANTICIPACION", Decimal(c, "aviso"), "@USUARIO", usu);
                        // RP-18: el «cada N» se escribe una sola vez; el hito lo refleja.
                        Exec("UPD_PLAN_HITO", "@ID", h, "@VALOR_MEDIDOR", cada, "@USUARIO", usu);
                        break;
                    }
                case "FECHA UNICA":
                    {
                        foreach (Dictionary<string, object> f in SoporteDatos.Filas("SEL_PROGRAMACION_FECHA", "@PROGRAMACION", pro, "@CLIENTE", cli))
                            SoporteDatos.Conjuntos("DEL_PROGRAMACION_FECHA", "@ID", Valor(f, "PFE_ID", "pfe_id", "ID"), "@CLIENTE", cli);
                        foreach (Dictionary<string, object> f in Lista(d, "fechas"))
                        {
                            TimeSpan hh; object hora = TimeSpan.TryParse(Texto(f, "hora"), out hh) ? (object)hh : null;
                            SoporteDatos.Conjuntos("INS_PROGRAMACION_FECHA", "@ID", null, "@PROGRAMACION", pro, "@CLIENTE", cli,
                                "@FECHA", Fecha(f, "fecha"), "@HORA", hora, "@INCLUIDA", true, "@USUARIO", usu);
                        }
                        break;
                    }
            }

            if (d.ContainsKey("exclusiones"))
            {
                foreach (Dictionary<string, object> e in SoporteDatos.Filas("SEL_PROGRAMACION_EXCLUSION", "@PROGRAMACION", pro, "@CLIENTE", cli, "@HABILITADO", true))
                    SoporteDatos.Conjuntos("DEL_PROGRAMACION_EXCLUSION", "@ID", Valor(e, "PXC_ID", "pxc_id", "ID"), "@CLIENTE", cli, "@USUARIO", usu);
                foreach (Dictionary<string, object> e in Lista(d, "exclusiones"))
                    SoporteDatos.Conjuntos("INS_PROGRAMACION_EXCLUSION", "@ID", null, "@PROGRAMACION", pro, "@CLIENTE", cli,
                        "@FECHA_INICIO", FechaHora(e, "desde"), "@FECHA_FIN", FinDelDia(e, "hasta"), "@MOTIVO", Texto(e, "motivo"),
                        "@DESPLAZA", Bool(e, "desplaza"), "@USUARIO", usu);
            }

            return new
            {
                ok = true, hito = h, programacion = pro, copiada = Bool(r, "COPIADA"), recargar = Bool(m, "CREADO"),
                fechas = SoporteDatos.Filas("SEL_PLAN_HITO_PROYECCION", "@CLIENTE", cli, "@HITO", h, "@TOPE", 6)
            };
        });
    }

    /// <summary>«Usar calendario compartido» o, con programacion = 0, «Convertir en propia».</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CalendarioCompartido(int plan, int hito, int programacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, hito, null, null, null);
            int h = Entero(m, "HITO");
            if (h <= 0) throw new Exception("La intervención ya no está en la planificación.");
            if (programacion > 0)
                SoporteDatos.Conjuntos("UPS_PLAN_HITO_FRECUENCIA", "@CLIENTE", Cli(), "@HITO", h, "@COMPARTIDA", programacion, "@USUARIO", U());
            else
                SoporteDatos.Conjuntos("UPS_PLAN_HITO_FRECUENCIA", "@CLIENTE", Cli(), "@HITO", h, "@COPIAR", true, "@USUARIO", U());
            return new { ok = true, recargar = true };
        });
    }

    /// <summary>
    /// Antes de abrir el editor de condición (la ficha de programación de
    /// siempre, en un panel): asegura que la intervención tenga su copia
    /// privada, para que el editor nunca toque la versión activa (RP-03).
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string PrepararCondicion(int plan, int hito)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, hito, null, null, null);
            int h = Entero(m, "HITO");
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_PLAN_HITO_FRECUENCIA", "@CLIENTE", Cli(), "@HITO", h, "@TIPO_CODIGO", "CONDICION", "@USUARIO", U());
            int pro = Entero(r, "PROGRAMACION");
            return new
            {
                hito = h, recargar = true,
                url = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Programaciones/Programacion.aspx") + "?query=" + Q(pro)
            };
        });
    }

    // =====================================================================
    // ACTIVIDADES Y REPUESTOS
    // =====================================================================

    /// <summary>
    /// «Agregar actividad» o «Agregar desde procedimiento»: con procedimiento,
    /// la actividad toma su nombre, su duración y su permiso.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AgregarActividad(int plan, int hito, string nombre, int procedimiento)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, hito, null, null, null);
            int h = Entero(m, "HITO");
            if (h <= 0) throw new Exception("La intervención ya no está en la planificación.");

            object duracion = null, permisoTipo = null; bool permiso = false;
            if (procedimiento > 0)
            {
                Dictionary<string, object> p = SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", Cli(), "@ID", procedimiento).FirstOrDefault();
                if (p == null) throw new Exception("El procedimiento no existe.");
                if (string.IsNullOrWhiteSpace(nombre)) nombre = Texto(p, "PRC_NOMBRE");
                int dur = Entero(p, "PRC_DURACION_ESTIMADA_MINUTO"); if (dur > 0) duracion = dur;
                permiso = Bool(p, "PRC_REQUIERE_PERMISO");
                int pt = Entero(p, "PRC_PERMISO_TRABAJO_TIPO"); if (pt > 0) permisoTipo = pt;
            }

            int id = ExecId("INS_PLAN_ACTIVIDAD", "@CLIENTE", Cli(), "@HITO", h,
                "@NOMBRE", string.IsNullOrWhiteSpace(nombre) ? "Nueva actividad" : nombre.Trim(),
                "@PROCEDIMIENTO", procedimiento > 0 ? (object)procedimiento : null, "@DURACION_ESTIMADA_MINUTO", duracion,
                "@REQUIERE_PERMISO", permiso && permisoTipo != null, "@PERMISO_TRABAJO_TIPO", permisoTipo, "@USUARIO", U());
            return new { actividad = id, recargar = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarActividad(int plan, int actividad, string campo, string valor)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, actividad, null, null);
            int a = Entero(m, "ACTIVIDAD");
            if (a <= 0) throw new Exception("La actividad ya no está en la planificación.");
            List<object> p = new List<object> { "@ID", a, "@USUARIO", U() };
            int n;
            bool vacio = string.IsNullOrWhiteSpace(valor);
            switch ((campo ?? "").ToLowerInvariant())
            {
                case "nombre": p.AddRange(new object[] { "@NOMBRE", (valor ?? "").Trim() }); break;
                case "descripcion": p.AddRange(new object[] { "@DESCRIPCION", vacio ? "" : valor.Trim() }); break;
                case "duracion":
                    if (vacio) p.AddRange(new object[] { "@QUITA_DURACION", true });
                    else if (int.TryParse(valor, out n)) p.AddRange(new object[] { "@DURACION_ESTIMADA_MINUTO", n });
                    else throw new Exception("La duración debe ser mayor que 0.");
                    break;
                case "obligatoria": p.AddRange(new object[] { "@OBLIGATORIA", Si(valor) }); break;
                case "parada": p.AddRange(new object[] { "@REQUIERE_PARADA", Si(valor) }); break;
                /* «Requiere permiso» y su tipo viajan juntos (CK_PAA_PERMISO): el valor
                   es el id del tipo, o vacío para quitar el permiso. Mientras falte el
                   tipo, la pantalla no guarda y muestra el error junto al campo. */
                case "permiso":
                    if (!vacio && int.TryParse(valor, out n) && n > 0) p.AddRange(new object[] { "@REQUIERE_PERMISO", true, "@PERMISO_TRABAJO_TIPO", n });
                    else p.AddRange(new object[] { "@REQUIERE_PERMISO", false, "@QUITA_PERMISO_TIPO", true });
                    break;
                case "procedimiento": if (!vacio && int.TryParse(valor, out n)) p.AddRange(new object[] { "@PROCEDIMIENTO", n }); else p.AddRange(new object[] { "@QUITA_PROCEDIMIENTO", true }); break;
                case "orden": if (int.TryParse(valor, out n)) p.AddRange(new object[] { "@ORDEN", n }); break;
                default: throw new Exception("El campo no existe.");
            }
            Exec("UPD_PLAN_ACTIVIDAD", p.ToArray());
            return new { ok = true, actividad = a, recargar = Bool(m, "CREADO") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarActividad(int plan, int actividad)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, actividad, null, null);
            int a = Entero(m, "ACTIVIDAD");
            if (a <= 0) throw new Exception("La actividad ya no está en la planificación.");
            Exec("DEL_PLAN_ACTIVIDAD", "@ID", a, "@USUARIO", U());
            return new { ok = true, recargar = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string AgregarRepuesto(int plan, int actividad, int repuesto, decimal cantidad)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, actividad, null, null);
            int a = Entero(m, "ACTIVIDAD");
            if (a <= 0) throw new Exception("La actividad ya no está en la planificación.");
            int id = ExecId("INS_PLAN_ACTIVIDAD_REPUESTO", "@CLIENTE", Cli(), "@ACTIVIDAD", a, "@REPUESTO", repuesto,
                "@CANTIDAD", cantidad <= 0 ? 1 : cantidad, "@USUARIO", U());
            return new { repuesto = id, recargar = Bool(m, "CREADO") };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarRepuesto(int plan, int id)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> m = Asegurar(plan, null, null, null, id);
            int r = Entero(m, "REPUESTO");
            if (r <= 0) throw new Exception("El repuesto ya no está en la actividad.");
            Exec("DEL_PLAN_ACTIVIDAD_REPUESTO", "@ID", r, "@USUARIO", U());
            return new { ok = true, recargar = Bool(m, "CREADO") };
        });
    }

    // =====================================================================
    // CICLO DE VIDA
    // =====================================================================

    /// <summary>Activar un borrador o aplicar los cambios de un plan activo (RP-05, RP-07).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Activar(int plan, string observacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            return SoporteDatos.Fila("UPD_PLAN_ACTIVAR", "@CLIENTE", Cli(), "@PLAN", plan, "@OBSERVACION", Nulo(observacion),
                "@HORIZONTE", HORIZONTE, "@USUARIO", U());
        });
    }

    /// <summary>«Reintentar»: solo genera, sobre lo ya publicado.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Generar(int plan)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            return SoporteDatos.Fila("UPD_PLAN_ACTIVAR", "@CLIENTE", Cli(), "@PLAN", plan, "@HORIZONTE", HORIZONTE,
                "@SOLO_GENERAR", true, "@USUARIO", U());
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string DescartarCambios(int plan)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Exec("DEL_PLAN_VERSION_BORRADOR", "@CLIENTE", Cli(), "@PLAN", plan, "@USUARIO", U());
            return new { ok = true, recargar = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Desactivar(int plan, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            return SoporteDatos.Fila("UPD_PLAN_DESACTIVAR", "@CLIENTE", Cli(), "@PLAN", plan, "@MOTIVO", motivo ?? "", "@USUARIO", U());
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Reactivar(int plan)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            return SoporteDatos.Fila("UPD_PLAN_REACTIVAR", "@CLIENTE", Cli(), "@PLAN", plan, "@HORIZONTE", HORIZONTE, "@USUARIO", U());
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Eliminar(int plan)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            DelCliente(plan);
            Exec("DEL_PLAN_MANTENIMIENTO", "@ID", plan, "@USUARIO", U());
            return new { ok = true };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Duplicar(int plan, string nombre, bool conActivos)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            Dictionary<string, object> r = SoporteDatos.Fila("INS_PLAN_DUPLICAR", "@CLIENTE", Cli(), "@PLAN", plan, "@NOMBRE", Nulo(nombre),
                "@CON_ACTIVOS", conActivos, "@USUARIO", U());
            r["Q"] = Q(Entero(r, "PLAN_ID"));
            return r;
        });
    }

    // =====================================================================
    // EJECUCIONES
    // =====================================================================

    /// <summary>Reprogramar desde el panel lateral de Ejecuciones (CA-25).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Reprogramar(string token, string fecha, string motivo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EDITAR);
            DateTime f;
            if (!DateTime.TryParseExact(fecha, new[] { "yyyy-MM-dd", "yyyy-MM-ddTHH:mm", "yyyy-MM-dd HH:mm" }, CultureInfo.InvariantCulture, DateTimeStyles.None, out f))
                throw new Exception("Indica la nueva fecha.");
            Respuesta r = new PlanOcurrenciaController().Reprogramar(IdDe(token), f, (motivo ?? "").Trim());
            if (r.error) throw new Exception(r.detalle);
            return new { ok = true, nueva = r.codigo };
        });
    }

    /// <summary>
    /// Las ejecuciones de la pestaña (§10.4). Lista: lo abierto hasta el
    /// horizonte. Semana y mes: todo lo del rango, también lo cerrado. Las
    /// cuentas por situación son las de lo que vuelve, para los chips.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ejecuciones(int planta, string desde, string hasta, int plan, int activo, bool abiertas)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<Dictionary<string, object>> filas = SoporteDatos.Filas("SEL_PLAN_OCURRENCIA_BANDEJA", "@CLIENTE", Cli(),
                "@PLAN", plan > 0 ? (object)plan : null, "@ACTIVO", activo > 0 ? (object)activo : null,
                "@INSTALACION", planta > 0 ? (object)planta : null,
                "@DESDE", FechaTxt(desde), "@HASTA", FechaTxt(hasta), "@SOLO_ABIERTAS", abiertas, "@PAGINA", 1, "@TAMANO", 3000);
            string urlOt = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=";
            foreach (Dictionary<string, object> f in filas)
            {
                f["TOKEN"] = Q(Entero(f, "PMO_ID"));
                if (Entero(f, "ORDEN_TRABAJO_ID") > 0) f["OT_URL"] = urlOt + Q(Entero(f, "ORDEN_TRABAJO_ID"));
            }
            return new { filas = filas, permisos = Permisos() };
        });
    }

    /// <summary>Lo que la OT hará: las actividades vigentes de la intervención de una ejecución.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EjecucionActividades(int hito)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            return new { actividades = SoporteDatos.Filas("SEL_PLAN_ACTIVIDAD", "@CLIENTE", Cli(), "@HITO", hito, "@HABILITADO", true) };
        });
    }

    /// <summary>
    /// Generar OT de una o varias ejecuciones (CA-24): el resultado va por
    /// fila; una que ya tenía OT no se duplica y una que falla no corta a las demás.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GenerarOt(string tokens)
    {
        return Ejecutar(() =>
        {
            Exigir(P_OT);
            List<object> res = new List<object>();
            string urlOt = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=";
            foreach (string t in (tokens ?? "").Split(',').Where(x => !string.IsNullOrWhiteSpace(x)))
            {
                try
                {
                    Dictionary<string, object> r = SoporteDatos.Fila("INS_ORDEN_TRABAJO_OCURRENCIA", "@ID", 0, "@CLIENTE", Cli(), "@OCURRENCIA", IdDe(t), "@USUARIO", U());
                    res.Add(new { token = t, r = Bool(r, "YA_EXISTIA") ? "ya" : "ok", ot = Valor(r, "OTR_CORRELATIVO"), url = urlOt + Q(Entero(r, "OTR_ID")), detalle = "" });
                }
                catch (Exception ex) { res.Add(new { token = t, r = "no", ot = (object)null, url = "", detalle = Limpio(ex.Message) }); }
            }
            return new { resultados = res };
        });
    }

    /// <summary>
    /// Cumplimiento (§10.5): el año, los últimos seis meses hasta el período
    /// elegido, y el período por plan y por activo. Se mide contra la fecha
    /// ORIGINAL, como en Planificación 360.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cumplimiento(int planta, string periodo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            int? inst = planta > 0 ? (int?)planta : null;
            DateTime hoy = global::SitioBase.Hora.Hoy.Date, m0;
            if (!DateTime.TryParseExact((periodo ?? "") + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out m0)) m0 = new DateTime(hoy.Year, hoy.Month, 1);
            Planificacion360Controller c = new Planificacion360Controller();
            Func<DateTime, DateTime, object> medir = (d, h) =>
            {
                List<PlanificacionCumplimientoEquipo> eq = c.GetCumplimientoEquipos(inst, d, h) ?? new List<PlanificacionCumplimientoEquipo>();
                int prog = eq.Sum(x => x.programadas), aT = eq.Sum(x => x.a_tiempo);
                return new { programadas = prog, aTiempo = aT, pc = prog == 0 ? (decimal?)null : Math.Round(100m * aT / prog, 0),
                    vencidas = eq.Sum(x => x.vencidas), reprogramadas = eq.Sum(x => x.reprogramadas) };
            };
            DateTime finPer = m0.AddMonths(1).AddDays(-1); if (finPer > hoy) finPer = hoy;
            var meses = new List<object>();
            for (int k = 5; k >= 0; k--)
            {
                DateTime a = m0.AddMonths(-k), b = a.AddMonths(1).AddDays(-1);
                if (a > hoy) continue;
                if (b > hoy) b = hoy;
                meses.Add(new { mes = a.ToString("yyyy-MM", CultureInfo.InvariantCulture), actual = b == hoy, datos = medir(a, b) });
            }
            List<PlanificacionCumplimientoEquipo> equipos = m0 > hoy ? new List<PlanificacionCumplimientoEquipo>() : (c.GetCumplimientoEquipos(inst, m0, finPer) ?? new List<PlanificacionCumplimientoEquipo>());
            PlanOcurrenciaController oc = new PlanOcurrenciaController();
            var planes = new List<Dictionary<string, object>>();
            if (m0 <= hoy)
                foreach (Dictionary<string, object> p in SoporteDatos.Filas("SEL_PLAN_CENTRO", "@CLIENTE", Cli(), "@INSTALACION", inst))
                {
                    if (Texto(p, "ESTADO") == "BORRADOR") continue;
                    PlanCumplimiento pc = oc.GetCumplimiento(Entero(p, "PLAN_ID"), m0, finPer);
                    if (pc == null || pc.programadas == 0) continue;
                    planes.Add(new Dictionary<string, object> { { "id", Entero(p, "PLAN_ID") }, { "codigo", Texto(p, "CODIGO") }, { "nombre", Texto(p, "NOMBRE") },
                        { "programadas", pc.programadas }, { "cumplidas", pc.cumplidas }, { "aTiempo", pc.a_tiempo_original }, { "vencidas", pc.vencidas },
                        { "reprogramadas", pc.reprogramadas }, { "pc", Math.Round(pc.cumplimiento, 0) } });
                }
            return new
            {
                anio = medir(new DateTime(hoy.Year, 1, 1), hoy),
                periodo = m0 > hoy ? null : medir(m0, finPer),
                desde = m0.ToString("yyyy-MM-dd"), hasta = finPer.ToString("yyyy-MM-dd"),
                meses = meses,
                planes = planes.OrderBy(x => (decimal)x["pc"]).ToList(),
                activos = equipos.OrderBy(x => x.cumplimiento).ThenBy(x => x.activo_nombre).Select(x => new { id = x.activo_id, codigo = x.activo_codigo, nombre = x.activo_nombre,
                    programadas = x.programadas, cumplidas = x.cumplidas, aTiempo = x.a_tiempo, vencidas = x.vencidas, pc = Math.Round(x.cumplimiento, 0) }).ToList()
            };
        });
    }

    /// <summary>Cobertura (§10.6): cada activo con los planes activos que lo cubren.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cobertura(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<Dictionary<string, object>> a = SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_PLAN_ACTIVO_CANDIDATO", "@CLIENTE", Cli(), "@PLAN", null, "@FILTRO", null), 0);
            if (planta > 0) a = a.Where(x => Entero(x, "PLANTA_ID") == planta).ToList();
            return new { activos = a };
        });
    }

    /// <summary>Calendarios compartidos de la Biblioteca: próximas fechas y dónde se usan (§10.7).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Calendarios()
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede(P_PROG_VER)) throw new Exception("No tienes permiso para ver calendarios.");
            ProgramacionController pc = new ProgramacionController();
            List<PlanificacionProgramacionUso> usos = new Planificacion360Controller().GetUsosProgramacion() ?? new List<PlanificacionProgramacionUso>();
            var lista = new List<object>();
            foreach (Programacion p in (pc.GetProgramaciones(new Programacion { pro_cliente = Cli(), filtro_habilitado = true }) ?? new List<Programacion>()).Where(x => x.tipo_codigo != "ABIERTA"))
            {
                int n = p.tipo_codigo == "FECHA UNICA" ? 1 : (p.tipo_codigo == "CALENDARIO" || p.tipo_codigo == "INTERVALO TIEMPO") ? 4 : 0;
                List<ProgramacionProyeccion> proy = n == 0 ? new List<ProgramacionProyeccion>() : (pc.GetProyeccion(p.pro_id, n) ?? new List<ProgramacionProyeccion>());
                lista.Add(new
                {
                    id = p.pro_id, nombre = p.pro_nombre, tipo = p.tipo_nombre, tipoCodigo = p.tipo_codigo, detalle = p.detalle,
                    fechas = proy.Take(n).Select(x => x.fecha.ToString("yyyy-MM-dd")).ToArray(),
                    usos = usos.Where(x => x.programacion_id == p.pro_id).Select(x => new { origen = x.origen, nombre = (string.IsNullOrEmpty(x.codigo) ? "" : x.codigo + " · ") + x.nombre }).ToList(),
                    url = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Programaciones/Programacion.aspx") + "?query=" + Q(p.pro_id)
                });
            }
            return new { calendarios = lista, nuevaUrl = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Programaciones/Programacion.aspx") };
        });
    }

    /// <summary>Combos del asistente «Nuevo calendario»: lo que no depende de la planta.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CalendarioCatalogos()
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede("CREAR EDITAR PROGRAMACIONES")) throw new Exception("No tienes permiso para crear calendarios.");
            ProgramacionController pc = new ProgramacionController();
            Func<List<CatalogoItem>, object> m = l => (l ?? new List<CatalogoItem>()).Select(x => new { id = x.id, n = x.nombre, codigo = x.codigo }).ToList();
            return new { zonas = m(pc.GetCatalogo("ZONA_HORARIA")), politicas = m(pc.GetCatalogo("CUMPLIMIENTO_POLITICA")), personas = m(pc.GetCatalogoAlcance("RESPONSABLE")) };
        });
    }

    /// <summary>Áreas, activos y grupos de una planta (paso Alcance y Asignación).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CalendarioAlcance(int planta)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede("CREAR EDITAR PROGRAMACIONES")) throw new Exception("No tienes permiso para crear calendarios.");
            ProgramacionController pc = new ProgramacionController();
            int? inst = planta > 0 ? (int?)planta : null;
            Func<List<CatalogoItem>, object> m = l => (l ?? new List<CatalogoItem>()).Select(x => new { id = x.id, n = x.nombre }).ToList();
            return new { areas = m(pc.GetCatalogoAlcance("AREA", inst)), activos = m(pc.GetCatalogoAlcance("ACTIVO", inst)), grupos = m(pc.GetGrupos(inst)) };
        });
    }

    /// <summary>
    /// «Nuevo calendario» de la Biblioteca: los seis pasos del asistente de
    /// Programación (información, alcance, asignación, frecuencia,
    /// exclusiones y revisión) en una sola llamada, dentro del Centro. Crea
    /// una programación NO privada de tipo calendario, intervalo o fechas
    /// puntuales, que cualquier intervención, tarea o pauta puede usar.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CrearCalendario(string datos)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede("CREAR EDITAR PROGRAMACIONES")) throw new Exception("No tienes permiso para crear calendarios.");
            Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos ?? "{}");
            string nombre = Texto(d, "nombre").Trim(), tipoCod = Texto(d, "tipo").ToUpperInvariant();
            if (nombre.Length == 0) throw new Exception("Indica el nombre del calendario.");
            if (tipoCod != "CALENDARIO" && tipoCod != "INTERVALO TIEMPO" && tipoCod != "FECHA UNICA") throw new Exception("Elige el tipo de frecuencia.");
            object desde = Fecha(d, "desde");
            if (desde == null) throw new Exception("Indica desde cuándo es vigente.");
            ValidarFrecuencia(tipoCod, d);

            int? planta = EnteroNulo(d, "planta") > 0 ? EnteroNulo(d, "planta") : null, area = EnteroNulo(d, "area") > 0 ? EnteroNulo(d, "area") : null, activo = EnteroNulo(d, "activo") > 0 ? EnteroNulo(d, "activo") : null;
            if (planta == null && (area != null || activo != null)) throw new Exception("Alcance: indica la planta antes del área o del activo.");
            string modo = Texto(d, "modo");
            List<string> personas = ListaTexto(d, "personas");
            if (modo == "persona" && personas.Count == 0) throw new Exception("Asignación: elige al menos una persona.");
            if (modo == "grupo" && !(EnteroNulo(d, "grupo") > 0)) throw new Exception("Asignación: elige el grupo de trabajo.");

            ProgramacionController pc = new ProgramacionController();
            CatalogoItem tipo = (pc.GetCatalogo("PROGRAMACION_TIPO") ?? new List<CatalogoItem>()).FirstOrDefault(x => string.Equals(x.codigo, tipoCod, StringComparison.OrdinalIgnoreCase));
            if (tipo == null) throw new Exception("El tipo de frecuencia no existe.");

            Programacion e = new Programacion();
            e.pro_nombre = nombre; e.pro_programacion_tipo = tipo.id;
            e.pro_fecha_inicio = (DateTime)desde; e.pro_fecha_fin = Fecha(d, "hasta") as DateTime?;
            if (EnteroNulo(d, "zona") > 0) e.pro_zona_horaria = EnteroNulo(d, "zona");
            e.pro_cliente_instalacion = planta; e.pro_instalacion_area = area; e.pro_activo = activo;
            if (modo == "grupo") e.pro_grupo_trabajo = EnteroNulo(d, "grupo");
            if (EnteroNulo(d, "politica") > 0) e.pro_cumplimiento_politica = EnteroNulo(d, "politica");
            e.pro_tolerancia_antes_minuto = Entero(d, "tolAntes"); e.pro_tolerancia_despues_minuto = Entero(d, "tolDespues");
            e.pro_permite_anticipada = Bool(d, "anticipada"); e.pro_permite_atrasada = Bool(d, "atrasada");
            e.pro_genera_automaticamente = Bool(d, "genera"); e.pro_habilitado = true;

            Respuesta r = pc.InsertProgramacion(e);
            if (r.error) throw new Exception(r.detalle);
            int pro = r.codigo, cli = Cli(), usu = U();
            try
            {
                if (modo == "persona") { Respuesta rp = pc.GuardarResponsables(pro, string.Join(",", personas)); if (rp.error) throw new Exception(rp.detalle); }
                switch (tipoCod)
                {
                    case "CALENDARIO":
                        {
                            Dictionary<string, object> c = Dicc(d, "calendario");
                            TimeSpan hora; if (!TimeSpan.TryParse(Texto(c, "hora"), out hora)) hora = new TimeSpan(8, 0, 0);
                            SoporteDatos.Conjuntos("UPS_PROGRAMACION_CALENDARIO", "@PROGRAMACION", pro, "@CLIENTE", cli,
                                "@FRECUENCIA", Entero(c, "frecuencia"), "@INTERVALO", Math.Max(1, Entero(c, "intervalo")),
                                "@SEMANA_ORDINAL", EnteroNulo(c, "ordinal"), "@DIA_MES", EnteroNulo(c, "diaMes"), "@MES", EnteroNulo(c, "mes"),
                                "@HORA_LOCAL", hora, "@DIAS", Nulo(string.Join(",", ListaTexto(c, "dias"))), "@USUARIO", usu);
                            break;
                        }
                    case "INTERVALO TIEMPO":
                        {
                            Dictionary<string, object> c = Dicc(d, "intervalo");
                            SoporteDatos.Conjuntos("UPS_PROGRAMACION_INTERVALO", "@PROGRAMACION", pro, "@CLIENTE", cli, "@UNIDAD_TIEMPO", Entero(c, "unidad"),
                                "@CANTIDAD", Entero(c, "cantidad"), "@FECHA_ANCLA_UTC", FechaHora(c, "ancla"), "@USUARIO", usu);
                            break;
                        }
                    case "FECHA UNICA":
                        foreach (Dictionary<string, object> f in Lista(d, "fechas"))
                        {
                            TimeSpan hh; object hora = TimeSpan.TryParse(Texto(f, "hora"), out hh) ? (object)hh : null;
                            SoporteDatos.Conjuntos("INS_PROGRAMACION_FECHA", "@ID", null, "@PROGRAMACION", pro, "@CLIENTE", cli, "@FECHA", Fecha(f, "fecha"), "@HORA", hora, "@INCLUIDA", true, "@USUARIO", usu);
                        }
                        break;
                }
                foreach (Dictionary<string, object> x in Lista(d, "exclusiones"))
                    SoporteDatos.Conjuntos("INS_PROGRAMACION_EXCLUSION", "@ID", null, "@PROGRAMACION", pro, "@CLIENTE", cli,
                        "@FECHA_INICIO", FechaHora(x, "desde"), "@FECHA_FIN", FinDelDia(x, "hasta"), "@MOTIVO", Texto(x, "motivo"), "@DESPLAZA", Bool(x, "desplaza"), "@USUARIO", usu);
            }
            catch (Exception ex)
            {
                throw new Exception("El calendario se creó, pero no se pudo completar: " + Limpio(ex.Message) + " Revísalo en Programaciones.");
            }
            return new { id = pro };
        });
    }

    /// <summary>La cabecera y los pasos de un procedimiento, para editarlo en el panel.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ProcedimientoDetalle(int id)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede(P_PROC_VER)) throw new Exception("No tienes permiso para ver procedimientos.");
            Dictionary<string, object> h = SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", Cli(), "@ID", id).FirstOrDefault();
            if (h == null) throw new Exception("El procedimiento no existe.");
            return new { cabecera = h, pasos = SoporteDatos.Filas("SEL_PROCEDIMIENTO_PASO", "@CLIENTE", Cli(), "@PROCEDIMIENTO", id, "@HABILITADO", true) };
        });
    }

    /// <summary>
    /// Crea o edita un procedimiento con sus pasos, en una sola llamada.
    /// Editar cambia la misma versión (nueva versión queda fuera de alcance);
    /// los pasos que ya no vienen se dan de baja y los nuevos se agregan.
    /// La medición de un paso existente no se toca aquí.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarProcedimiento(string datos)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROC_EDITAR);
            Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos ?? "{}");
            int cli = Cli(), usu = U(), id = Entero(d, "id");
            string nombre = Texto(d, "nombre").Trim();
            if (nombre.Length == 0) throw new Exception("El procedimiento necesita un nombre.");
            List<Dictionary<string, object>> pasos = Lista(d, "pasos");
            if (pasos.Count == 0 || pasos.Any(p => Texto(p, "nombre").Trim().Length == 0)) throw new Exception("Cada paso necesita un nombre.");
            object tipo = EnteroNulo(d, "tipo") > 0 ? EnteroNulo(d, "tipo") : null;
            object dur = EnteroNulo(d, "duracion") > 0 ? EnteroNulo(d, "duracion") : null;
            int permiso = Entero(d, "permiso");
            if (id <= 0)
            {
                int max = 0;
                foreach (Dictionary<string, object> r in SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", Cli(), "@SOLO_ULTIMA", true))
                {
                    int n; string c = Texto(r, "PRC_CODIGO"); if (c.StartsWith("PRC-") && int.TryParse(c.Substring(4), out n) && n > max) max = n;
                }
                id = ExecId("INS_PROCEDIMIENTO", "@CLIENTE", cli, "@CODIGO", "PRC-" + (max + 1).ToString("000"), "@NOMBRE", nombre, "@ACTIVO_TIPO", tipo,
                    "@DESCRIPCION", Nulo(Texto(d, "descripcion")), "@DURACION", dur, "@REQUIERE_PERMISO", permiso > 0, "@PERMISO_TIPO", permiso > 0 ? (object)permiso : null, "@USUARIO", usu);
            }
            else
            {
                Exec("UPD_PROCEDIMIENTO", "@ID", id, "@CLIENTE", cli, "@NOMBRE", nombre, "@ACTIVO_TIPO", tipo, "@QUITA_TIPO", tipo == null,
                    "@DESCRIPCION", Texto(d, "descripcion"), "@DURACION", dur, "@REQUIERE_PERMISO", permiso > 0, "@PERMISO_TIPO", permiso > 0 ? (object)permiso : null, "@USUARIO", usu);
                HashSet<int> quedan = new HashSet<int>(pasos.Select(p => Entero(p, "id")).Where(x => x > 0));
                foreach (Dictionary<string, object> e in SoporteDatos.Filas("SEL_PROCEDIMIENTO_PASO", "@CLIENTE", cli, "@PROCEDIMIENTO", id, "@HABILITADO", true))
                {
                    int pid = Entero(e, "PPA_ID"); if (!quedan.Contains(pid)) Exec("DEL_PROCEDIMIENTO_PASO", "@ID", pid, "@CLIENTE", cli, "@USUARIO", usu);
                }
            }
            int orden = 0;
            foreach (Dictionary<string, object> p in pasos)
            {
                orden++; int pid = Entero(p, "id"); object pdur = EnteroNulo(p, "duracion") > 0 ? EnteroNulo(p, "duracion") : null;
                if (pid > 0)
                    Exec("UPD_PROCEDIMIENTO_PASO", "@ID", pid, "@CLIENTE", cli, "@ORDEN", orden, "@NOMBRE", Texto(p, "nombre").Trim(), "@INSTRUCCION", Texto(p, "instruccion"),
                        "@ES_PUNTO_CONTROL", Bool(p, "ctrl"), "@REQUIERE_EVIDENCIA", Bool(p, "ev"), "@DURACION", pdur, "@USUARIO", usu);
                else
                    ExecId("INS_PROCEDIMIENTO_PASO", "@CLIENTE", cli, "@PROCEDIMIENTO", id, "@ORDEN", orden, "@NOMBRE", Texto(p, "nombre").Trim(), "@INSTRUCCION", Nulo(Texto(p, "instruccion")),
                        "@ES_PUNTO_CONTROL", Bool(p, "ctrl"), "@REQUIERE_EVIDENCIA", Bool(p, "ev"), "@DURACION", pdur, "@USUARIO", usu);
            }
            return new { id = id };
        });
    }

    private static object FechaTxt(string s)
    {
        DateTime f;
        return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f) ? (object)f : null;
    }

    // =====================================================================
    // FICHA
    // =====================================================================

    private object ArmarFicha(int plan)
    {
        int cli = Cli();
        List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_PLAN_FICHA", "@CLIENTE", cli, "@PLAN", plan);
        Dictionary<string, object> cab = SoporteDatos.Del(c, 0).FirstOrDefault() ?? new Dictionary<string, object>();
        List<Dictionary<string, object>> hitos = SoporteDatos.Del(c, 1);

        ILookup<int, Dictionary<string, object>> cal = SoporteDatos.Del(c, 2).ToLookup(r => Entero(r, "PROGRAMACION_ID"));
        ILookup<int, Dictionary<string, object>> inv = SoporteDatos.Del(c, 3).ToLookup(r => Entero(r, "PROGRAMACION_ID"));
        ILookup<int, Dictionary<string, object>> med = SoporteDatos.Del(c, 4).ToLookup(r => Entero(r, "PROGRAMACION_ID"));
        ILookup<int, Dictionary<string, object>> fec = SoporteDatos.Del(c, 5).ToLookup(r => Entero(r, "PROGRAMACION_ID"));
        ILookup<int, Dictionary<string, object>> exc = SoporteDatos.Del(c, 6).ToLookup(r => Entero(r, "PROGRAMACION_ID"));
        ILookup<int, Dictionary<string, object>> con = SoporteDatos.Del(c, 7).ToLookup(r => Entero(r, "PROGRAMACION_ID"));
        ILookup<int, Dictionary<string, object>> rep = SoporteDatos.Del(c, 9).ToLookup(r => Entero(r, "ACTIVIDAD_ID"));
        List<Dictionary<string, object>> acts = SoporteDatos.Del(c, 8);
        foreach (Dictionary<string, object> a in acts) a["REPUESTOS"] = rep[Entero(a, "ACTIVIDAD_ID")].ToList();
        ILookup<int, Dictionary<string, object>> actPorHito = acts.ToLookup(r => Entero(r, "HITO_ID"));
        ILookup<int, Dictionary<string, object>> proxPorHito = SoporteDatos.Del(c, 15).ToLookup(r => Entero(r, "HITO_ID"));

        foreach (Dictionary<string, object> h in hitos)
        {
            int p = Entero(h, "PROGRAMACION_ID");
            h["CALENDARIO"] = cal[p].FirstOrDefault();
            h["INTERVALO"] = inv[p].FirstOrDefault();
            h["MEDIDOR"] = med[p].FirstOrDefault();
            h["FECHAS_PUNTUALES"] = fec[p].ToList();
            h["EXCLUSIONES"] = exc[p].ToList();
            h["CONDICIONES"] = con[p].ToList();
            h["ACTIVIDADES"] = actPorHito[Entero(h, "HITO_ID")].ToList();
            h["FECHAS"] = proxPorHito[Entero(h, "HITO_ID")].ToList();
        }

        ActivoImagenController imagenes = new ActivoImagenController();
        List<Dictionary<string, object>> activos = SoporteDatos.Del(c, 10);
        foreach (Dictionary<string, object> a in activos)
        {
            int foto = imagenes.GetImagenId(Entero(a, "ACTIVO_ID"), cli);
            a["FOTO"] = foto > 0 ? UrlArchivo.Ver(foto) : null;
            a["URL"] = VirtualPathUtility.ToAbsolute("~/View/Activos/Ficha/ActivoFicha.aspx") + "?query=" + Q(Entero(a, "ACTIVO_ID"));
        }

        string urlOt = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=";
        List<Dictionary<string, object>> proximas = SoporteDatos.Del(c, 11);
        foreach (Dictionary<string, object> o in proximas)
        {
            o["TOKEN"] = Q(Entero(o, "OCURRENCIA_ID"));
            if (Entero(o, "OT_ID") > 0) o["OT_URL"] = urlOt + Q(Entero(o, "OT_ID"));
        }
        List<Dictionary<string, object>> ots = SoporteDatos.Del(c, 12);
        foreach (Dictionary<string, object> o in ots) o["URL"] = urlOt + Q(Entero(o, "OT_ID"));

        cab["Q"] = Q(plan);
        return new
        {
            plan = cab,
            intervenciones = hitos,
            activos = activos,
            proximas = proximas,
            ots = ots,
            versiones = SoporteDatos.Del(c, 13),
            proyeccion = SoporteDatos.Del(c, 14),
            permisos = Permisos()
        };
    }

    // =====================================================================
    // APOYO
    // =====================================================================

    private object AgregarActivo(int plan, int activo, int? componente, int? medidor)
    {
        try
        {
            ExecId("INS_PLAN_ACTIVO", "@CLIENTE", Cli(), "@PLAN", plan, "@ACTIVO", activo,
                "@ACTIVO_COMPONENTE", componente, "@ACTIVO_MEDIDOR", medidor, "@USUARIO", U());
            return new { activo = activo, ok = true, detalle = "" };
        }
        catch (Exception ex)
        {
            return new { activo = activo, ok = false, detalle = Limpio(ex.Message) };
        }
    }

    private Dictionary<string, object> Asegurar(int plan, int? hito, int? actividad, int? vinculo, int? repuesto)
    {
        return SoporteDatos.Fila("UPS_PLAN_BORRADOR_ASEGURAR", "@CLIENTE", Cli(), "@PLAN", plan, "@HITO", hito, "@ACTIVIDAD", actividad,
            "@VINCULO", vinculo, "@REPUESTO", repuesto, "@USUARIO", U());
    }

    /// <summary>El plan tiene que ser del cliente en sesión (para los SP que no lo exigen).</summary>
    private static void DelCliente(int plan)
    {
        if (SoporteDatos.Filas("SEL_PLAN_CENTRO", "@CLIENTE", Cli(), "@PLAN", plan).Count == 0)
            throw new Exception("El plan no existe para este cliente.");
    }

    private static void ValidarFrecuencia(string tipo, Dictionary<string, object> d)
    {
        switch (tipo)
        {
            case "CALENDARIO":
                {
                    Dictionary<string, object> c = Dicc(d, "calendario");
                    if (Entero(c, "frecuencia") <= 0) throw new Exception("Elige cada cuánto se repite.");
                    if (Entero(c, "intervalo") < 1) throw new Exception("El intervalo debe ser 1 o mayor.");
                    break;
                }
            case "INTERVALO TIEMPO":
                {
                    Dictionary<string, object> c = Dicc(d, "intervalo");
                    if (Entero(c, "cantidad") < 1) throw new Exception("Indica cada cuánto (1 o más).");
                    if (Entero(c, "unidad") <= 0) throw new Exception("Elige la unidad del intervalo.");
                    break;
                }
            case "FECHA UNICA":
                if (Lista(d, "fechas").Count == 0) throw new Exception("Agrega al menos una fecha.");
                break;
            case "MEDIDOR":
                {
                    object cada = Decimal(Dicc(d, "medidor"), "cada");
                    if (cada == null || Convert.ToDecimal(cada) <= 0) throw new Exception("Indica cada cuántas unidades del medidor.");
                    break;
                }
            case "CONDICION":
                break;
            default:
                throw new Exception("Elige el tipo de frecuencia.");
        }
    }

    private static object Permisos()
    {
        return new
        {
            ver = Token.Puede(P_VER),
            editar = Token.Puede(P_EDITAR),
            generarOt = Token.Puede(P_OT),
            procedimientos = Token.Puede(P_PROC_VER),
            editarProcedimientos = Token.Puede(P_PROC_EDITAR),
            calendarios = Token.Puede(P_PROG_VER)
        };
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

    /// <summary>
    /// El mensaje del SP para la pantalla: sin el número («6.- ») y en tipo
    /// oración si viene en caja alta. Lo que va entre comillas (nombres,
    /// códigos) se deja tal cual.
    /// </summary>
    internal static string Limpio(string m)
    {
        if (string.IsNullOrWhiteSpace(m)) return "No se pudo completar.";
        m = m.Replace("\r", "").Split('\n')[0].Trim();
        for (int i = 0; i < 3; i++) m = Regex.Replace(m, @"^\s*\d+\.-\s*", "");
        string[] partes = m.Split('"');
        string fuera = string.Concat(partes.Where((x, i) => i % 2 == 0));
        bool alta = fuera.Any(char.IsLetter) && fuera == fuera.ToUpper(new CultureInfo("es-CL"));
        if (alta)
        {
            for (int i = 0; i < partes.Length; i += 2) partes[i] = partes[i].ToLower(new CultureInfo("es-CL"));
            m = string.Join("\"", partes);
            m = Regex.Replace(m, @"\bot\b", "OT");
            if (m.Length > 0) m = char.ToUpper(m[0]) + m.Substring(1);
        }
        return m;
    }

    private static void Exigir(string permiso)
    {
        if (!Token.Puede(permiso)) throw new Exception("No tienes permiso para esta acción.");
    }

    private static int Cli() { return SitioBase.Session.ClienteId(); }
    private static int U() { return SoporteDatos.Usuario(); }

    private static string Q(int id) { return HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id)); }

    private static int IdDe(string token)
    {
        string plano = Tools.Crypto.Decrypt(HttpUtility.UrlDecode(token ?? ""));
        int id; if (!int.TryParse((plano ?? "").Split('=').Last(), out id)) throw new Exception("La ejecución no existe.");
        return id;
    }

    /// <summary>Ejecuta un SP sin @ID de salida (los result sets se descartan; los errores suben).</summary>
    private static void Exec(string sp, params object[] p)
    {
        SoporteDatos.Conjuntos(sp, p);
    }

    /// <summary>Ejecuta un SP con @ID OUTPUT y devuelve el id.</summary>
    private static int ExecId(string sp, params object[] p)
    {
        SqlCommand cmd = Conexion.GetCommand(sp);
        try
        {
            SqlParameter id = cmd.Parameters.Add("@ID", SqlDbType.Int);
            id.Direction = ParameterDirection.InputOutput;
            id.Value = DBNull.Value;
            for (int i = 0; i + 1 < p.Length; i += 2)
                cmd.Parameters.AddWithValue((string)p[i], p[i + 1] ?? DBNull.Value);
            using (SqlDataReader dr = cmd.ExecuteReader())
            {
                do { while (dr.Read()) { } } while (dr.NextResult());
            }
            return id.Value == DBNull.Value ? 0 : Convert.ToInt32(id.Value);
        }
        finally
        {
            if (cmd.Connection != null) cmd.Connection.Dispose();
        }
    }

    // ---- lectura de diccionarios (JSON del navegador y filas de SP) ----

    private static object Valor(Dictionary<string, object> d, params string[] claves)
    {
        if (d == null) return null;
        object v;
        foreach (string k in claves) if (d.TryGetValue(k, out v)) return v;
        // Los SP no siempre devuelven la columna con la misma caja (prc_nombre / PRC_NOMBRE).
        foreach (string k in claves)
            foreach (KeyValuePair<string, object> kv in d)
                if (string.Equals(kv.Key, k, StringComparison.OrdinalIgnoreCase)) return kv.Value;
        return null;
    }

    private static string Texto(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        return v == null ? "" : Convert.ToString(v, CultureInfo.InvariantCulture).Trim();
    }

    private static int Entero(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        if (v == null) return 0;
        if (v is bool) return (bool)v ? 1 : 0;
        decimal n;
        return decimal.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out n) ? (int)n : 0;
    }

    private static int? EnteroNulo(Dictionary<string, object> d, string k)
    {
        if (Valor(d, k) == null || Texto(d, k) == "") return null;
        int n = Entero(d, k);
        return n == 0 ? (int?)null : n;
    }

    private static object Decimal(Dictionary<string, object> d, string k)
    {
        string t = Texto(d, k).Replace(',', '.');
        decimal n;
        return decimal.TryParse(t, NumberStyles.Any, CultureInfo.InvariantCulture, out n) ? (object)n : null;
    }

    private static bool Bool(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        if (v == null) return false;
        if (v is bool) return (bool)v;
        string t = Convert.ToString(v).Trim().ToLowerInvariant();
        return t == "1" || t == "true" || t == "si" || t == "sí";
    }

    private static bool Si(string v)
    {
        string t = (v ?? "").Trim().ToLowerInvariant();
        return t == "1" || t == "true" || t == "si" || t == "sí";
    }

    private static object Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

    private static object Fecha(Dictionary<string, object> d, string k)
    {
        DateTime f;
        return DateTime.TryParseExact(Texto(d, k), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f) ? (object)f : null;
    }

    private static object FechaHora(Dictionary<string, object> d, string k)
    {
        DateTime f;
        string t = Texto(d, k);
        return DateTime.TryParseExact(t, new[] { "yyyy-MM-dd", "yyyy-MM-ddTHH:mm", "yyyy-MM-dd HH:mm", "yyyy-MM-ddTHH:mm:ss" },
            CultureInfo.InvariantCulture, DateTimeStyles.None, out f) ? (object)f : null;
    }

    /// <summary>El «hasta» de una exclusión incluye ese día completo.</summary>
    private static object FinDelDia(Dictionary<string, object> d, string k)
    {
        object f = FechaHora(d, k);
        if (f == null) return null;
        DateTime x = (DateTime)f;
        return x.TimeOfDay.TotalMinutes == 0 ? x.AddDays(1).AddMinutes(-1) : x;
    }

    private static Dictionary<string, object> Dicc(Dictionary<string, object> d, string k)
    {
        return Valor(d, k) as Dictionary<string, object> ?? new Dictionary<string, object>();
    }

    private static List<Dictionary<string, object>> Lista(Dictionary<string, object> d, string k)
    {
        List<Dictionary<string, object>> l = new List<Dictionary<string, object>>();
        IEnumerable e = Valor(d, k) as IEnumerable;
        if (e == null || Valor(d, k) is string) return l;
        foreach (object o in e) { Dictionary<string, object> x = o as Dictionary<string, object>; if (x != null) l.Add(x); }
        return l;
    }

    private static List<Dictionary<string, object>> Lista(string json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new List<Dictionary<string, object>>();
        object[] arr = new JavaScriptSerializer().Deserialize<object[]>(json) ?? new object[0];
        return arr.OfType<Dictionary<string, object>>().ToList();
    }

    private static List<string> ListaTexto(Dictionary<string, object> d, string k)
    {
        List<string> l = new List<string>();
        IEnumerable e = Valor(d, k) as IEnumerable;
        if (e == null || Valor(d, k) is string) return l;
        foreach (object o in e) if (o != null) l.Add(Convert.ToString(o, CultureInfo.InvariantCulture));
        return l;
    }
}
