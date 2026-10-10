using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Recursos (rediseño de Mantenimiento en cinco lugares, parte e): procedimientos, pautas
/// de inspección y ajustes (BD/406). Los calendarios compartidos siguen en
/// WsCentroPlanificacion (Calendarios, CalendarioDetalle, CrearCalendario).
///
/// CADA MÉTODO VALIDA SESIÓN Y PERMISO; el cliente sale de la sesión, nunca del navegador.
/// Los mensajes son los del SP, sin el número y sin la caja alta.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsRecursos : System.Web.Services.WebService
{
    private const string P_PROC_VER = "VER PROCEDIMIENTOS";
    private const string P_PROC_EDITAR = "CREAR EDITAR PROCEDIMIENTOS";
    private const string P_PAU_VER = "VER PAUTAS";
    private const string P_PAU_EDITAR = "CREAR EDITAR PAUTAS";
    private const string P_PROG_VER = "VER PROGRAMACIONES";
    private const string P_PROG_EDITAR = "CREAR EDITAR PROGRAMACIONES";
    private const string P_TAR_EDITAR = "CREAR EDITAR TAREAS";
    private const string P_PLAN_EDITAR = "CREAR EDITAR PLANES MANTENIMIENTO";
    private const string P_OT = "CREAR ORDEN TRABAJO";

    /// <summary>Tipos de respuesta del cajón de pauta (mockup) → Checklist_Item_Tipo.</summary>
    private static readonly Dictionary<string, int> TIPO_ITEM = new Dictionary<string, int> { { "ok", 5 }, { "num", 4 }, { "txt", 1 }, { "foto", 12 } };

    /// <summary>Todo lo que pintan las cuatro pestañas (menos los calendarios) y lo que la persona puede hacer.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cargar()
    {
        return Ejecutar(() =>
        {
            int cli = Cli();
            bool pv = Token.Puede(P_PROC_VER), av = Token.Puede(P_PAU_VER);
            List<List<Dictionary<string, object>>> aj = SoporteDatos.Conjuntos("SEL_RECURSOS_AJUSTES", "@CLIENTE", cli);
            return new
            {
                permisos = Permisos(),
                procedimientos = pv ? SoporteDatos.Filas("SEL_RECURSOS_PROCEDIMIENTOS", "@CLIENTE", cli) : null,
                pautas = av ? SoporteDatos.Filas("SEL_RECURSOS_PAUTAS", "@CLIENTE", cli) : null,
                ajustes = new { cat = SoporteDatos.Del(aj, 0), tipo = SoporteDatos.Del(aj, 1), mot = SoporteDatos.Del(aj, 2), jornada = SoporteDatos.Del(aj, 3) }
            };
        });
    }

    /// <summary>Los combos de los cajones: tipos de activo, permisos de trabajo, frecuencias, unidades, variables.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Catalogos()
    {
        return Ejecutar(() =>
        {
            if (!new[] { P_PROC_VER, P_PAU_VER, P_PROG_VER }.Any(Token.Puede)) throw new Exception("No tienes permiso para ver Recursos.");
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_PLAN_CENTRO_CATALOGO", "@CLIENTE", Cli());
            return new
            {
                tipos = SoporteDatos.Del(c, 1), permisos = SoporteDatos.Del(c, 7), frecuencias = SoporteDatos.Del(c, 8), unidades = SoporteDatos.Del(c, 9),
                variables = SoporteDatos.Filas("SEL_VARIABLE_MEDICION", "@CLIENTE", Cli(), "@HABILITADO", true),
                medidas = SoporteDatos.Filas("SEL_UNIDAD_MEDIDA_RECURSOS")
            };
        });
    }

    // =====================================================================
    // PROCEDIMIENTOS
    // =====================================================================

    /// <summary>La cabecera, los pasos y los planes que lo usan.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Procedimiento(int id)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROC_VER);
            Dictionary<string, object> h = SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", Cli(), "@ID", id).FirstOrDefault();
            if (h == null) throw new Exception("El procedimiento no existe.");
            return new
            {
                cabecera = h,
                pasos = SoporteDatos.Filas("SEL_PROCEDIMIENTO_PASO", "@CLIENTE", Cli(), "@PROCEDIMIENTO", id, "@HABILITADO", true),
                usos = SoporteDatos.Filas("SEL_RECURSOS_PROCEDIMIENTO_USOS", "@CLIENTE", Cli(), "@PROCEDIMIENTO", id)
            };
        });
    }

    /// <summary>
    /// Crea o edita un procedimiento con sus pasos en una sola llamada (incluye la medición
    /// de cada paso). Editar cambia la misma versión: las OT ya generadas conservan los pasos
    /// que copiaron; los pasos que ya no vienen se dan de baja.
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
            string nombre = Texto(d, "nombre");
            if (nombre.Length == 0) throw new Exception("El procedimiento necesita un nombre.");
            List<Dictionary<string, object>> pasos = Lista(d, "pasos");
            if (pasos.Count == 0 || pasos.Any(p => Texto(p, "nombre").Length == 0)) throw new Exception("Cada paso necesita un nombre.");
            if (pasos.Any(p => Bool(p, "med") && Entero(p, "variable") <= 0 && VariableNueva(p) == null)) throw new Exception("Elige qué mide cada paso que requiere medición.");
            if (pasos.Any(p => Bool(p, "med") && VariableNueva(p) != null && Entero(p, "unidad") <= 0)) throw new Exception("Elige la unidad de la variable nueva.");
            object tipo = Entero(d, "tipo") > 0 ? (object)Entero(d, "tipo") : null;
            object dur = Entero(d, "duracion") > 0 ? (object)Entero(d, "duracion") : null;
            int permiso = Entero(d, "permiso");
            if (id > 0)
            {
                Dictionary<string, object> ex = SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", cli, "@ID", id).FirstOrDefault();
                if (ex == null || Bool(ex, "ES_GLOBAL")) throw new Exception("Los procedimientos de Sistema no se editan: cópialo para usarlo.");
                SoporteDatos.Conjuntos("UPD_PROCEDIMIENTO", "@ID", id, "@CLIENTE", cli, "@NOMBRE", nombre, "@ACTIVO_TIPO", tipo, "@QUITA_TIPO", tipo == null,
                    "@DESCRIPCION", Texto(d, "descripcion"), "@DURACION", dur, "@REQUIERE_PERMISO", permiso > 0, "@PERMISO_TIPO", permiso > 0 ? (object)permiso : null, "@USUARIO", usu);
                HashSet<int> quedan = new HashSet<int>(pasos.Select(p => Entero(p, "id")).Where(x => x > 0));
                foreach (Dictionary<string, object> e in SoporteDatos.Filas("SEL_PROCEDIMIENTO_PASO", "@CLIENTE", cli, "@PROCEDIMIENTO", id, "@HABILITADO", true))
                {
                    int pid = Entero(e, "PPA_ID"); if (!quedan.Contains(pid)) SoporteDatos.Conjuntos("DEL_PROCEDIMIENTO_PASO", "@ID", pid, "@CLIENTE", cli, "@USUARIO", usu);
                }
            }
            else
                id = ExecId("INS_PROCEDIMIENTO", "@CLIENTE", cli, "@CODIGO", SiguienteCodigoProc(), "@NOMBRE", nombre, "@ACTIVO_TIPO", tipo,
                    "@DESCRIPCION", Nulo(Texto(d, "descripcion")), "@DURACION", dur, "@REQUIERE_PERMISO", permiso > 0, "@PERMISO_TIPO", permiso > 0 ? (object)permiso : null, "@USUARIO", usu);
            GuardarPasos(id, pasos);
            return new { id = id };
        });
    }

    /// <summary>«Copiar para usar»: copia un procedimiento de Sistema como uno propio del cliente.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CopiarProcedimiento(int id)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PROC_EDITAR);
            int cli = Cli(), usu = U();
            Dictionary<string, object> h = SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", cli, "@ID", id).FirstOrDefault();
            if (h == null) throw new Exception("El procedimiento no existe.");
            object perm = Valor(h, "PRC_PERMISO_TRABAJO_TIPO");
            int nuevo = ExecId("INS_PROCEDIMIENTO", "@CLIENTE", cli, "@CODIGO", SiguienteCodigoProc(), "@NOMBRE", Texto(h, "PRC_NOMBRE"), "@ACTIVO_TIPO", Valor(h, "PRC_ACTIVO_TIPO"),
                "@DESCRIPCION", Nulo(Texto(h, "PRC_DESCRIPCION")), "@DURACION", Valor(h, "PRC_DURACION_ESTIMADA_MINUTO"), "@REQUIERE_PERMISO", perm != null, "@PERMISO_TIPO", perm, "@USUARIO", usu);
            List<Dictionary<string, object>> pasos = SoporteDatos.Filas("SEL_PROCEDIMIENTO_PASO", "@CLIENTE", cli, "@PROCEDIMIENTO", id, "@HABILITADO", true).Select(p => new Dictionary<string, object>
            {
                { "nombre", Texto(p, "PPA_NOMBRE") }, { "instruccion", Texto(p, "PPA_INSTRUCCION") }, { "ctrl", Bool(p, "PPA_ES_PUNTO_CONTROL") }, { "ev", Bool(p, "PPA_REQUIERE_EVIDENCIA") },
                { "med", Bool(p, "PPA_REQUIERE_MEDICION") }, { "variable", Entero(p, "PPA_VARIABLE_MEDICION") }, { "duracion", Entero(p, "PPA_DURACION_ESTIMADA_MINUTO") }
            }).ToList();
            GuardarPasos(nuevo, pasos);
            return new { id = nuevo, codigo = Texto(SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", cli, "@ID", nuevo).FirstOrDefault(), "PRC_CODIGO") };
        });
    }

    private void GuardarPasos(int proc, List<Dictionary<string, object>> pasos)
    {
        int cli = Cli(), usu = U(), orden = 0;
        foreach (Dictionary<string, object> p in pasos)
        {
            orden++;
            int pid = Entero(p, "id"), vari = Entero(p, "variable");
            // «Crear» en el combo: la variable nueva queda en el catálogo de la empresa (la busca por nombre antes de crearla).
            string nueva = VariableNueva(p);
            if (Bool(p, "med") && nueva != null)
                vari = ExecId("UPS_VARIABLE_MEDICION_NOMBRE", "@CLIENTE", cli, "@NOMBRE", nueva, "@UNIDAD", Entero(p, "unidad"), "@USUARIO", usu);
            bool med = Bool(p, "med") && vari > 0;
            object pdur = Entero(p, "duracion") > 0 ? (object)Entero(p, "duracion") : null;
            if (pid > 0)
                SoporteDatos.Conjuntos("UPD_PROCEDIMIENTO_PASO", "@ID", pid, "@CLIENTE", cli, "@ORDEN", orden, "@NOMBRE", Texto(p, "nombre"), "@INSTRUCCION", Texto(p, "instruccion"),
                    "@ES_PUNTO_CONTROL", Bool(p, "ctrl"), "@REQUIERE_EVIDENCIA", Bool(p, "ev"), "@REQUIERE_MEDICION", med, "@VARIABLE", med ? (object)vari : null, "@QUITA_VARIABLE", !med,
                    "@DURACION", pdur, "@USUARIO", usu);
            else
                ExecId("INS_PROCEDIMIENTO_PASO", "@CLIENTE", cli, "@PROCEDIMIENTO", proc, "@ORDEN", orden, "@NOMBRE", Texto(p, "nombre"), "@INSTRUCCION", Nulo(Texto(p, "instruccion")),
                    "@ES_PUNTO_CONTROL", Bool(p, "ctrl"), "@REQUIERE_EVIDENCIA", Bool(p, "ev"), "@REQUIERE_MEDICION", med, "@VARIABLE", med ? (object)vari : null, "@DURACION", pdur, "@USUARIO", usu);
        }
    }

    /// <summary>El nombre de la variable escrita en el combo («nuevo:Presión de aceite»), o null si se eligió una existente.</summary>
    private static string VariableNueva(Dictionary<string, object> p)
    {
        string v = Texto(p, "variable");
        return v.StartsWith("nuevo:") && v.Length > 6 ? v.Substring(6).Trim() : null;
    }

    private string SiguienteCodigoProc()
    {
        int max = 0;
        foreach (Dictionary<string, object> r in SoporteDatos.Filas("SEL_PROCEDIMIENTO", "@CLIENTE", Cli()))
        {
            int n; string c = Texto(r, "PRC_CODIGO"); if (c.StartsWith("PRC-") && int.TryParse(c.Substring(4), out n) && n > max) max = n;
        }
        return "PRC-" + (max + 1).ToString("000");
    }

    // =====================================================================
    // PAUTAS
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Pauta(int id)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PAU_VER);
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_RECURSOS_PAUTA", "@CLIENTE", Cli(), "@PLANTILLA", id);
            Dictionary<string, object> h = SoporteDatos.Del(c, 0).FirstOrDefault();
            if (h == null) throw new Exception("La pauta no existe para este cliente.");
            return new { cabecera = h, secciones = SoporteDatos.Del(c, 1), items = SoporteDatos.Del(c, 2), dependencias = SoporteDatos.Del(c, 3), usos = SoporteDatos.Del(c, 4) };
        });
    }

    /// <summary>
    /// Crea una pauta o publica su versión siguiente con lo que trae el cajón. Secciones e
    /// ítems se identifican por su código (se conserva al clonar la versión publicada en el
    /// borrador): los que no vienen se dan de baja y los nuevos (sin código) se agregan.
    /// Al final se publica: la versión anterior queda retirada y rige desde la próxima inspección.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarPauta(string datos)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PAU_EDITAR);
            Dictionary<string, object> d = new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(datos ?? "{}");
            int cli = Cli(), usu = U(), id = Entero(d, "id");
            List<Dictionary<string, object>> secs = Lista(d, "secciones");
            if (!secs.Any(s => Lista(s, "items").Count > 0)) throw new Exception("La pauta necesita al menos un ítem.");
            if (id <= 0)
            {
                string nombre = Texto(d, "nombre");
                if (nombre.Length == 0) throw new Exception("La pauta necesita un nombre.");
                id = ExecId("INS_CHECKLIST_PLANTILLA", "@CLIENTE", cli, "@CODIGO", SiguienteCodigoPauta(), "@NOMBRE", nombre, "@USUARIO", usu);
            }
            else if (!SoporteDatos.Del(SoporteDatos.Conjuntos("SEL_RECURSOS_PAUTA", "@CLIENTE", cli, "@PLANTILLA", id), 0).Any())
                throw new Exception("La pauta no existe para este cliente.");

            int version = new ChecklistEstructuraController().GetBorradorVersion(id, usu.ToString());
            if (version <= 0) throw new Exception("No se pudo abrir la versión borrador de la pauta.");
            List<List<Dictionary<string, object>>> act = SoporteDatos.Conjuntos("SEL_RECURSOS_PAUTA_BORRADOR", "@VERSION", version);
            Dictionary<string, int> secId = SoporteDatos.Del(act, 0).ToDictionary(x => Texto(x, "CODIGO"), x => Entero(x, "ID"));
            Dictionary<string, int> itmId = SoporteDatos.Del(act, 1).ToDictionary(x => Texto(x, "CODIGO"), x => Entero(x, "ID"));
            HashSet<string> secVistas = new HashSet<string>(), itmVistos = new HashSet<string>();
            Dictionary<string, int> porClave = new Dictionary<string, int>(); // 417: clave del cajón («k») → id del ítem en el borrador
            int sorden = 0, nuevo = 0;
            foreach (Dictionary<string, object> s in secs)
            {
                sorden++;
                string sc = Texto(s, "codigo"); int sid;
                if (sc.Length > 0 && secId.TryGetValue(sc, out sid)) SoporteDatos.Conjuntos("UPD_CHECKLIST_SECCION", "@ID", sid, "@NOMBRE", Texto(s, "nombre"), "@ORDEN", sorden, "@USUARIO", usu);
                else
                {
                    sc = Unico("SEC-", secId.Keys.Concat(secVistas));
                    sid = ExecId("INS_CHECKLIST_SECCION", "@VERSION", version, "@CODIGO", sc, "@NOMBRE", Texto(s, "nombre").Length > 0 ? Texto(s, "nombre") : "General", "@ORDEN", sorden, "@USUARIO", usu);
                    if (sid <= 0) throw new Exception("No se pudo crear la sección «" + Texto(s, "nombre") + "».");
                }
                secVistas.Add(sc);
                int iorden = 0;
                foreach (Dictionary<string, object> it in Lista(s, "items"))
                {
                    iorden++;
                    string ic = Texto(it, "codigo"); int iid;
                    if (ic.Length > 0 && itmId.TryGetValue(ic, out iid))
                    {
                        if (Bool(it, "mod"))
                        {
                            // 417: el ítem se corrigió en el cajón (texto, unidad, rango); el tipo de respuesta no cambia.
                            string texto = Texto(it, "texto");
                            if (texto.Length == 0) throw new Exception("Cada ítem necesita decir qué se revisa.");
                            int tipo = Entero(it, "tipoId") > 0 ? Entero(it, "tipoId") : (TIPO_ITEM.ContainsKey(Texto(it, "tipo")) ? TIPO_ITEM[Texto(it, "tipo")] : 5);
                            bool num = tipo == 3 || tipo == 4;
                            int? unidad = num && Entero(it, "unidad") > 0 ? (int?)Entero(it, "unidad") : null;
                            SoporteDatos.Conjuntos("UPD_CHECKLIST_ITEM", "@ID", iid, "@SECCION", sid, "@TEXTO", texto, "@TIPO", tipo, "@ORDEN", iorden, "@OBLIGATORIO", true, "@UNIDAD", unidad, "@USUARIO", usu);
                            if (num)
                            {
                                object mn = Decimal(it, "min"), mx = Decimal(it, "max");
                                if (mn != null && mx != null && (decimal)mx < (decimal)mn) throw new Exception("En «" + texto + "» el máximo debe ser mayor o igual al mínimo.");
                                SoporteDatos.Conjuntos("UPS_RECURSOS_PAUTA_ITEM_RANGO", "@ITEM", iid, "@MINIMO", mn, "@MAXIMO", mx, "@GENERA_ALERTA", Bool(it, "crit"), "@USUARIO", usu);
                            }
                            SoporteDatos.Conjuntos("UPS_CHECKLIST_ITEM_REGLAS_RECURSOS", "@ITEM", iid, "@USUARIO", usu);
                        }
                        else SoporteDatos.Conjuntos("UPD_CHECKLIST_ITEM_ORDEN_RECURSOS", "@ID", iid, "@SECCION", sid, "@ORDEN", iorden, "@USUARIO", usu);
                    }
                    else
                    {
                        string texto = Texto(it, "texto"), t = Texto(it, "tipo");
                        if (texto.Length == 0) throw new Exception("Cada ítem necesita decir qué se revisa.");
                        int tipo = TIPO_ITEM.ContainsKey(t) ? TIPO_ITEM[t] : 5;
                        int? unidad = tipo == 4 && Entero(it, "unidad") > 0 ? (int?)Entero(it, "unidad") : null;
                        ic = Unico("ITM-", itmId.Keys.Concat(itmVistos));
                        iid = ExecId("INS_CHECKLIST_ITEM", "@VERSION", version, "@SECCION", sid, "@CODIGO", ic, "@TEXTO", texto, "@TIPO", tipo, "@ORDEN", iorden,
                            "@OBLIGATORIO", true, "@PERMITE_COMENTARIO", true, "@REQUIERE_EVIDENCIA", tipo == 12, "@UNIDAD", unidad, "@USUARIO", usu);
                        if (iid <= 0) throw new Exception("No se pudo agregar el ítem «" + texto + "».");
                        object mn = Decimal(it, "min"), mx = Decimal(it, "max");
                        if (tipo == 4 && (mn != null || mx != null))
                        {
                            if (mn != null && mx != null && (decimal)mx < (decimal)mn) throw new Exception("En «" + texto + "» el máximo debe ser mayor o igual al mínimo.");
                            SoporteDatos.Conjuntos("INS_CHECKLIST_VALIDACION", "@ITEM", iid, "@MINIMO", mn, "@MAXIMO", mx, "@ADVERTENCIA", null, "@CRITICO", null, "@GENERA_ALERTA", Bool(it, "crit"), "@USUARIO", usu);
                        }
                        // 412: lo que no cumple abre hallazgo (opciones SI/NO y validación con «genera hallazgo»).
                        SoporteDatos.Conjuntos("UPS_CHECKLIST_ITEM_REGLAS_RECURSOS", "@ITEM", iid, "@USUARIO", usu);
                        nuevo++;
                    }
                    SoporteDatos.Conjuntos("UPD_CHECKLIST_ITEM_CRITICO", "@ID", iid, "@CRITICO", Bool(it, "crit"), "@USUARIO", usu);
                    itmVistos.Add(ic);
                    string k = Texto(it, "k"); if (k.Length > 0) porClave[k] = iid;
                }
            }
            foreach (KeyValuePair<string, int> x in itmId) if (!itmVistos.Contains(x.Key)) SoporteDatos.Conjuntos("DEL_CHECKLIST_ITEM", "@ID", x.Value, "@USUARIO", usu);
            foreach (KeyValuePair<string, int> x in secId) if (!secVistas.Contains(x.Key)) SoporteDatos.Conjuntos("DEL_CHECKLIST_SECCION", "@ID", x.Value, "@USUARIO", usu);

            // 417: dependencias. El cajón manda la lista completa; se reemplazan las del borrador.
            if (d.ContainsKey("dependencias"))
            {
                List<List<Dictionary<string, object>>> bor = SoporteDatos.Conjuntos("SEL_RECURSOS_PAUTA_BORRADOR", "@VERSION", version);
                foreach (Dictionary<string, object> x in SoporteDatos.Del(bor, 2)) SoporteDatos.Conjuntos("DEL_CHECKLIST_ITEM_DEPENDENCIA", "@ID", Entero(x, "ID"), "@USUARIO", usu);
                Dictionary<int, Dictionary<string, int>> opciones = new Dictionary<int, Dictionary<string, int>>();
                Dictionary<string, int> idPorCodigo = SoporteDatos.Del(bor, 1).ToDictionary(x => Texto(x, "CODIGO"), x => Entero(x, "ID"));
                foreach (Dictionary<string, object> x in SoporteDatos.Del(bor, 3))
                {
                    int ii; if (!idPorCodigo.TryGetValue(Texto(x, "ITEM"), out ii)) continue;
                    if (!opciones.ContainsKey(ii)) opciones[ii] = new Dictionary<string, int>();
                    opciones[ii][Texto(x, "CODIGO")] = Entero(x, "ID");
                }
                foreach (Dictionary<string, object> dep in Lista(d, "dependencias"))
                {
                    int item, cond;
                    if (!porClave.TryGetValue(Texto(dep, "item"), out item) || !porClave.TryGetValue(Texto(dep, "cond"), out cond)) continue;
                    if (item == cond) throw new Exception("Un ítem no puede depender de sí mismo.");
                    int? opcion = null; Dictionary<string, int> ops; int oid;
                    if (Texto(dep, "opcion").Length > 0 && opciones.TryGetValue(cond, out ops) && ops.TryGetValue(Texto(dep, "opcion"), out oid)) opcion = oid;
                    string valor = Texto(dep, "valor");
                    if (opcion == null && valor.Length == 0) throw new Exception("Cada dependencia necesita el valor con que se compara.");
                    SoporteDatos.Conjuntos("INS_CHECKLIST_ITEM_DEPENDENCIA", "@CLIENTE", cli, "@ITEM", item, "@CONDICION", cond,
                        "@OPERADOR", Entero(dep, "op") > 0 ? Entero(dep, "op") : 1, "@VALOR", opcion == null ? (object)valor : null, "@OPCION", opcion,
                        "@ACCION", Entero(dep, "accion") > 0 ? Entero(dep, "accion") : 1, "@USUARIO", usu);
                }
            }

            SoporteDatos.Conjuntos("PUBLICAR_CHECKLIST_VERSION", "@PLANTILLA", id, "@CLIENTE", cli, "@USUARIO", usu);
            // 418: las ocurrencias pendientes sin ejecutar pasan a la versión nueva («rige desde la próxima inspección»).
            SoporteDatos.Conjuntos("UPD_CHECKLIST_OCURRENCIAS_VERSION_VIGENTE", "@PLANTILLA", id, "@USUARIO", usu);
            Dictionary<string, object> pub = SoporteDatos.Filas("SEL_RECURSOS_PAUTAS", "@CLIENTE", cli).FirstOrDefault(x => Entero(x, "ID") == id);
            return new { id = id, codigo = Texto(pub, "CODIGO"), version = Entero(pub, "VERSION") };
        });
    }

    private static string Unico(string prefijo, IEnumerable<string> usados)
    {
        HashSet<string> u = new HashSet<string>(usados);
        int n = u.Count + 1; string c;
        do { c = prefijo + n.ToString("000"); n++; } while (u.Contains(c));
        return c;
    }

    private string SiguienteCodigoPauta()
    {
        int max = 0;
        foreach (Dictionary<string, object> r in SoporteDatos.Filas("SEL_CHECKLIST_PLANTILLA", "@CLIENTE", Cli()))
        {
            int n; string c = Texto(r, "CPL_CODIGO"); if (c.StartsWith("PAU-") && int.TryParse(c.Substring(4), out n) && n > max) max = n;
        }
        return "PAU-" + (max + 1).ToString("000");
    }

    // =====================================================================
    // AJUSTES
    // =====================================================================

    /// <summary>Agrega (accion = ADD, nombre) o quita (accion = DEL, id) un ítem de un catálogo. tipo: CAT · TIPO · MOT.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ajuste(string tipo, string accion, int id, string nombre)
    {
        return Ejecutar(() =>
        {
            tipo = (tipo ?? "").ToUpperInvariant(); accion = (accion ?? "").ToUpperInvariant();
            Exigir(tipo == "CAT" ? P_TAR_EDITAR : tipo == "TIPO" ? P_PLAN_EDITAR : P_OT);
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_RECURSOS_AJUSTE", "@CLIENTE", Cli(), "@TIPO", tipo, "@ACCION", accion, "@ID", id > 0 ? (object)id : null, "@NOMBRE", nombre ?? "", "@USUARIO", U());
            List<List<Dictionary<string, object>>> aj = SoporteDatos.Conjuntos("SEL_RECURSOS_AJUSTES", "@CLIENTE", Cli());
            return new { id = Entero(r, "ID"), ajustes = new { cat = SoporteDatos.Del(aj, 0), tipo = SoporteDatos.Del(aj, 1), mot = SoporteDatos.Del(aj, 2), jornada = SoporteDatos.Del(aj, 3) } };
        });
    }

    /// <summary>415 · La jornada de trabajo de una planta (inicio y término «HH:mm»; vacíos = 06:00–22:00).
    /// Es la ventana donde se sugieren horas libres al resolver choques de horario.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Jornada(int planta, string inicio, string fin)
    {
        return Ejecutar(() =>
        {
            Exigir(P_PLAN_EDITAR);
            TimeSpan i, f;
            object vi = TimeSpan.TryParse(inicio ?? "", out i) ? (object)i : null, vf = TimeSpan.TryParse(fin ?? "", out f) ? (object)f : null;
            SoporteDatos.Conjuntos("UPS_PLANTA_JORNADA", "@CLIENTE", Cli(), "@PLANTA", planta, "@INICIO", vi, "@FIN", vf, "@USUARIO", U());
            List<List<Dictionary<string, object>>> aj = SoporteDatos.Conjuntos("SEL_RECURSOS_AJUSTES", "@CLIENTE", Cli());
            return new { ajustes = new { cat = SoporteDatos.Del(aj, 0), tipo = SoporteDatos.Del(aj, 1), mot = SoporteDatos.Del(aj, 2), jornada = SoporteDatos.Del(aj, 3) } };
        });
    }

    // ---------------------------------------------------------------------

    private static object Permisos()
    {
        return new
        {
            procVer = Token.Puede(P_PROC_VER), procEd = Token.Puede(P_PROC_EDITAR),
            pauVer = Token.Puede(P_PAU_VER), pauEd = Token.Puede(P_PAU_EDITAR),
            calVer = Token.Puede(P_PROG_VER), calEd = Token.Puede(P_PROG_EDITAR),
            catEd = Token.Puede(P_TAR_EDITAR), tipoEd = Token.Puede(P_PLAN_EDITAR), motEd = Token.Puede(P_OT)
        };
    }

    private static void Exigir(string permiso)
    {
        if (!Token.Puede(permiso)) throw new Exception("No tienes permiso para esta acción.");
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
            return WsSoporte.Json(new { error = true, detalle = WsCentroPlanificacion.Limpio(ex.Message) });
        }
    }

    private static int Cli() { return SitioBase.Session.ClienteId(); }
    private static int U() { return SoporteDatos.Usuario(); }

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

    private static object Valor(Dictionary<string, object> d, string k)
    {
        if (d == null) return null;
        object v;
        if (d.TryGetValue(k, out v)) return v;
        foreach (KeyValuePair<string, object> kv in d)
            if (string.Equals(kv.Key, k, StringComparison.OrdinalIgnoreCase)) return kv.Value;
        return null;
    }

    private static string Texto(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        return v == null || v == DBNull.Value ? "" : Convert.ToString(v, CultureInfo.InvariantCulture).Trim();
    }

    private static int Entero(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        if (v == null || v == DBNull.Value) return 0;
        if (v is bool) return (bool)v ? 1 : 0;
        decimal n;
        return decimal.TryParse(Convert.ToString(v, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out n) ? (int)n : 0;
    }

    private static object Decimal(Dictionary<string, object> d, string k)
    {
        string t = Texto(d, k).Replace(',', '.');
        decimal n;
        return t.Length > 0 && decimal.TryParse(t, NumberStyles.Any, CultureInfo.InvariantCulture, out n) ? (object)n : null;
    }

    private static bool Bool(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        if (v == null || v == DBNull.Value) return false;
        if (v is bool) return (bool)v;
        string t = Convert.ToString(v).Trim().ToLowerInvariant();
        return t == "1" || t == "true";
    }

    private static object Nulo(string s) { return string.IsNullOrWhiteSpace(s) ? null : s.Trim(); }

    private static List<Dictionary<string, object>> Lista(Dictionary<string, object> d, string k)
    {
        List<Dictionary<string, object>> l = new List<Dictionary<string, object>>();
        IEnumerable e = Valor(d, k) as IEnumerable;
        if (e == null || Valor(d, k) is string) return l;
        foreach (object o in e) { Dictionary<string, object> x = o as Dictionary<string, object>; if (x != null) l.Add(x); }
        return l;
    }
}
