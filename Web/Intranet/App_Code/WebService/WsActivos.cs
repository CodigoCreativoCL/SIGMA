using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Las vistas de la planta del Centro de activos (rediseño 05-10-2026,
/// docs/rediseno-activos): Lista, Tarjetas, Mapa por áreas, Vista 3D y el
/// explorador del activo.
///
/// LA PLANTA SE ARMA CON LO QUE HAY EN LA BASE
///   Planta() devuelve todo en la forma que dibujan las vistas: lugares en
///   arbol, activos con su portada, subactivos, componentes y repuestos con
///   su stock. Se lee en una llamada (SEL_ACTIVO_PLANTA, bloque 346).
///
/// LO QUE SE CAMBIA DESDE LAS VISTAS PASA POR LOS MISMOS SP
///   Mover un activo de lugar, crear o renombrar un lugar, la portada y el
///   estado usan los SP de siempre, con sus reglas (el cambio de estado pide
///   motivo igual que la ficha).
///
/// CADA LLAMADA VUELVE A VALIDAR SESION, PERMISO Y EMPRESA
///   Leer pide VER ACTIVOS; cambiar, CREAR EDITAR ACTIVOS (o CREAR EDITAR
///   COMPONENTES para una pieza). Todo activo que llega se comprueba contra
///   el cliente de la sesion antes de tocarlo.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsActivos : System.Web.Services.WebService
{
    private const string P_VER = "VER ACTIVOS";
    private const string P_EDITAR = "CREAR EDITAR ACTIVOS";
    private const string P_COMP = "CREAR EDITAR COMPONENTES";
    private const string P_AREAS = "CREAR EDITAR AREAS";

    // ================================================================ lectura

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Planta(int planta)
    {
        return Ejecutar(P_VER, () =>
        {
            int cliente = SitioBase.Session.ClienteId();
            ClienteInstalacion fp = new ClienteInstalacion();
            fp.filtro_cliente = cliente.ToString();
            fp.filtro_habilitado = "1";

            /* TODO A LA VEZ (05-10-2026)
               Eran trece consultas en fila a ~250 ms cada una: ~3,4 s antes
               de dibujar nada. Las que no dependen de nada salen juntas; la
               planta sale tambien de inmediato con la que pidio el navegador
               (la ultima que se vio) y solo se vuelve a pedir si esa no es una
               de las plantas de la persona. Los permisos ya los leyo Ejecutar
               en este hilo. Ver SitioBase.Paralelo. */
            var tMias = Paralelo.Pedir(() => PlantasPermitidas());
            var tPlantas = Paralelo.Pedir(() => new ClienteInstalacionController().GetClienteInstalaciones(fp) ?? new List<ClienteInstalacion>());
            int pedida = planta;
            var tPlanta = pedida > 0 ? Paralelo.Pedir(() => new ActivoPlantaController().GetPlanta(pedida)) : null;
            var tResumen = Paralelo.Pedir(() => new ActivoCentroController().GetResumenLista() ?? new Dictionary<int, ActivoResumenLista>());
            var tImgs = Paralelo.Pedir(() => new ActivoImagenController().GetImagenesLista(cliente));
            var tFotosRep = Paralelo.Pedir(() => PortadasRepuesto());
            var tEstAct = Paralelo.Pedir(() => new ActivoEstadoController().GetActivoEstados(new ActivoEstado { filtro_habilitado = true }) ?? new List<ActivoEstado>());
            var tEstComp = Paralelo.Pedir(() => new ActivoComponenteEstadoController().GetEstados(new ActivoComponenteEstado { filtro_habilitado = true }) ?? new List<ActivoComponenteEstado>());
            var tConteos = ConteosEnParalelo();

            /* Solo las plantas de la persona (si tiene asignadas); sin asignacion, todas. */
            HashSet<int> mias = tMias.Result;
            var plantas = tPlantas.Result
                .Where(p => mias == null || mias.Contains(p.cin_id))
                .Select(p => new { id = p.cin_id, nombre = p.cin_nombre }).ToList();
            if (planta <= 0 || !plantas.Any(p => p.id == planta)) planta = plantas.Count > 0 ? plantas[0].id : 0;

            /* La que se adelanto solo sirve si es la que quedo. */
            DataSet ds = tPlanta != null && planta == pedida ? tPlanta.Result : new ActivoPlantaController().GetPlanta(planta);
            if (ds.Tables.Count < 6) return new { error = false, vacio = true, planta = planta, plantas = plantas };

            // ---- tipos de lugar
            var tipos = ds.Tables[0].Rows.Cast<DataRow>()
                .Select(r => new { id = "t" + r["ID"], s = Txt(r, "SINGULAR"), p = Txt(r, "PLURAL"), propio = r["CLIENTE"] != DBNull.Value }).ToList();

            // ---- lugares en arbol
            Dictionary<string, Dictionary<string, object>> lugares = new Dictionary<string, Dictionary<string, object>>();
            List<string> raiz = new List<string>();
            foreach (DataRow r in ds.Tables[1].Rows)
                lugares["u" + r["ID"]] = new Dictionary<string, object> {
                    { "nombre", Txt(r, "NOMBRE") }, { "tipo", "t" + r["TIPO"] },
                    { "padre", r["PADRE"] == DBNull.Value ? null : "u" + r["PADRE"] },
                    { "hijos", new List<string>() }, { "activos", new List<string>() } };
            foreach (DataRow r in ds.Tables[1].Rows)
            {
                string id = "u" + r["ID"];
                string padre = lugares[id]["padre"] as string;
                if (padre != null && lugares.ContainsKey(padre)) ((List<string>)lugares[padre]["hijos"]).Add(id);
                else { lugares[id]["padre"] = null; raiz.Add(id); }
            }

            // ---- activos
            Dictionary<int, ActivoResumenLista> resumen = tResumen.Result;
            Dictionary<string, int> fotos = ds.Tables[5].Rows.Cast<DataRow>().ToDictionary(r => "a" + r["ACTIVO"], r => Convert.ToInt32(r["FOTOS"]));
            Dictionary<string, Dictionary<string, object>> activos = new Dictionary<string, Dictionary<string, object>>();
            List<string> tray = new List<string>();
            foreach (DataRow r in ds.Tables[2].Rows)
            {
                int aid = Convert.ToInt32(r["ID"]);
                string id = "a" + aid;
                ActivoResumenLista res; resumen.TryGetValue(aid, out res);
                int portada = r["PORTADA"] == DBNull.Value ? 0 : Convert.ToInt32(r["PORTADA"]);
                activos[id] = new Dictionary<string, object> {
                    { "aid", aid }, { "nombre", Txt(r, "NOMBRE") }, { "codigo", Txt(r, "CODIGO") },
                    { "tipo", IconoTipo(Txt(r, "TIPO")) }, { "tipoNombre", Txt(r, "TIPO") }, { "modelo", Txt(r, "MODELO") },
                    { "estado", ClaveEstado(Txt(r, "ESTADO_CODIGO") + " " + Txt(r, "ESTADO")) }, { "estadoNombre", Txt(r, "ESTADO") },
                    { "crit", ClaveCriticidad(Txt(r, "CRITICIDAD")) },
                    { "padre", r["PADRE"] == DBNull.Value ? null : "a" + r["PADRE"] },
                    { "subs", new List<string>() }, { "comps", new List<object>() }, { "reps", new List<object>() },
                    { "foto", portada > 0 ? UrlArchivo.Ver(portada) : null }, { "nfotos", fotos.ContainsKey(id) ? fotos[id] : 0 },
                    { "ot", res != null ? res.ot_abiertas : 0 }, { "fallas", res != null ? res.fallas_abiertas : 0 },
                    { "prox", res != null && res.proxima_mantencion != null ? res.proxima_mantencion.Value.ToString("dd MMM yyyy", new CultureInfo("es-CL")) : null },
                    { "url360", Url360(aid) }, { "qComp", Cifrar("Id=0&Activo=" + aid) },
                    { "qSub", Cifrar("Id=0&Padre=" + aid) },
                    // ISO para ordenar por fecha de creacion en el navegador (bloque 357).
                    { "creado", r.Table.Columns.Contains("CREADO") && r["CREADO"] != DBNull.Value ? ((DateTime)r["CREADO"]).ToString("yyyy-MM-ddTHH:mm:ss") : null } };
                activos[id]["_area"] = r["AREA"] == DBNull.Value ? null : "u" + r["AREA"];
            }
            foreach (var kv in activos)
            {
                string padre = kv.Value["padre"] as string;
                if (padre != null && activos.ContainsKey(padre)) { ((List<string>)activos[padre]["subs"]).Add(kv.Key); continue; }
                kv.Value["padre"] = null;
                string area = kv.Value["_area"] as string;
                if (area != null && lugares.ContainsKey(area)) ((List<string>)lugares[area]["activos"]).Add(kv.Key);
                else tray.Add(kv.Key);
            }
            foreach (var a in activos.Values) a.Remove("_area");

            // ---- componentes y repuestos (con su foto: bloque 349/353)
            Dictionary<string, int> imgs = tImgs.Result;
            foreach (DataRow r in ds.Tables[3].Rows)
            {
                string id = "a" + r["ACTIVO"];
                if (!activos.ContainsKey(id)) continue;
                ((List<object>)activos[id]["comps"]).Add(new {
                    id = Convert.ToInt32(r["ID"]), n = Txt(r, "NOMBRE"), c = Txt(r, "CODIGO"), tipo = Txt(r, "TIPO"), lado = Txt(r, "LADO"),
                    e = ClaveEstado(Txt(r, "ESTADO_CODIGO") + " " + Txt(r, "ESTADO")), en = Txt(r, "ESTADO"),
                    padre = r["PADRE"] == DBNull.Value ? 0 : Convert.ToInt32(r["PADRE"]), nota = Txt(r, "MOTIVO"),
                    foto = imgs.ContainsKey("C" + r["ID"]) ? UrlArchivo.Ver(imgs["C" + r["ID"]]) : null,
                    q = Cifrar("Id=" + r["ID"]) });
            }
            Dictionary<int, int> fotosRep = tFotosRep.Result;
            foreach (DataRow r in ds.Tables[4].Rows)
            {
                string id = "a" + r["ACTIVO"];
                if (!activos.ContainsKey(id)) continue;
                ((List<object>)activos[id]["reps"]).Add(new {
                    id = Convert.ToInt32(r["ID"]), n = Txt(r, "NOMBRE"), c = Txt(r, "CODIGO"),
                    stock = Convert.ToDecimal(r["EXISTENCIA"]), min = Convert.ToDecimal(r["MINIMO"]), u = Txt(r, "UNIDAD"),
                    para = Txt(r, "PARA") == "" ? null : Txt(r, "PARA"),
                    paraId = r["PARA_ID"] == DBNull.Value ? 0 : Convert.ToInt32(r["PARA_ID"]),
                    vinculo = r.Table.Columns.Contains("VINCULO") && r["VINCULO"] != DBNull.Value ? Convert.ToInt32(r["VINCULO"]) : 0,
                    foto = FotoRepuesto(fotosRep, Convert.ToInt32(r["ID"])),
                    url = "~/View/Inventario/Repuestos/Repuesto.aspx?query=" + Cifrar("Id=" + r["ID"]) });
            }

            return new
            {
                error = false,
                planta = planta,
                plantaNombre = plantas.Where(p => p.id == planta).Select(p => p.nombre).FirstOrDefault() ?? "",
                plantas = plantas,
                permisos = new { editar = Token.Puede(P_EDITAR), comp = Token.Puede(P_COMP), lugares = Token.Puede(P_AREAS) },
                tipos = tipos,
                raiz = raiz,
                lugares = lugares,
                tray = tray,
                activos = activos,
                estados = new
                {
                    activo = tEstAct.Result
                             .Select(e => new { id = e.aes_id, n = e.aes_nombre, k = ClaveEstado(e.aes_codigo + " " + e.aes_nombre) }),
                    comp = tEstComp.Result
                             .Select(e => new { id = e.ace_id, n = e.ace_nombre, k = ClaveEstado(e.ace_codigo + " " + e.ace_nombre) })
                },
                urlOt = ResolverUrl("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx"),
                conteos = Conteos(ds.Tables[3].Rows.Count, tConteos)
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Fotos(int activo)
    {
        return Ejecutar(P_VER, () =>
        {
            DelCliente(activo);
            return new
            {
                error = false,
                fotos = new ActivoPlantaController().GetFotos(activo).Rows.Cast<DataRow>().Select(r => new
                {
                    id = Convert.ToInt32(r["ARC_ID"]), nombre = Txt(r, "NOMBRE"),
                    url = UrlArchivo.Ver(Convert.ToInt32(r["ARC_ID"])), portada = Convert.ToBoolean(r["ES_PORTADA"])
                }).ToList()
            };
        });
    }

    /// <summary>
    /// Las pestañas Variables, Medidores, Tipos de activo y Modelos, como
    /// filas listas para dibujar (sin grilla del servidor). Cada fila trae su
    /// query cifrado para abrir la ficha de siempre en un modal.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Catalogo(string cual)
    {
        return Ejecutar(P_VER, () =>
        {
            int cli = SitioBase.Session.ClienteId();
            CultureInfo cl = new CultureInfo("es-CL");
            Func<decimal?, string> n = v => v == null ? "" : v.Value.ToString("#,0.##", cl);
            switch ((cual ?? "").ToLowerInvariant())
            {
                case "variables":
                    return new
                    {
                        error = false, editar = Token.Puede("CREAR EDITAR VARIABLES ACTIVO"),
                        opciones = new { activos = OpcionesActivos(), unidades = OpcionesUnidades(), vars = OpcionesVariables() },
                        filas = (new ActivoVariableController().GetVariables(new ActivoVariable()) ?? new List<ActivoVariable>()).Select(v => new
                        {
                            id = v.ava_id, activoId = v.ava_activo, unidadId = v.ava_unidad_medida ?? 0,
                            minNum = v.ava_valor_minimo, maxNum = v.ava_valor_maximo, horas = v.ava_frecuencia_esperada_hora,
                            q = Cifrar("Id=" + v.ava_id), serie = Cifrar("Id=" + v.ava_id),
                            activo = v.activo_nombre, codigo = v.activo_codigo, pieza = v.componente_nombre ?? "",
                            nombre = v.variable_nombre, unidad = v.unidad_simbolo ?? "",
                            normal = (v.ava_valor_minimo == null && v.ava_valor_maximo == null) ? "" :
                                     (v.ava_valor_minimo == null ? "hasta " + n(v.ava_valor_maximo) : v.ava_valor_maximo == null ? "desde " + n(v.ava_valor_minimo) : n(v.ava_valor_minimo) + " a " + n(v.ava_valor_maximo)),
                            cada = v.ava_frecuencia_esperada_hora == null ? "" : v.ava_frecuencia_esperada_hora + " h",
                            lecturas = v.mediciones, activa = v.ava_habilitado
                        }).ToList()
                    };
                case "medidores":
                    return new
                    {
                        error = false, editar = Token.Puede("CREAR EDITAR MEDIDORES"),
                        opciones = new { activos = OpcionesActivos(), unidades = OpcionesUnidades() },
                        filas = (new ActivoMedidorController().GetActivoMedidores(new ActivoMedidor { ame_cliente = cli }) ?? new List<ActivoMedidor>()).Select(m => new
                        {
                            id = m.ame_id, activoId = m.ame_activo, unidadId = m.ame_unidad_medida, valorNum = m.ame_valor_actual,
                            q = Cifrar("Id=" + m.ame_id), codigo = m.ame_codigo, nombre = m.ame_nombre,
                            activo = m.activo_nombre, codActivo = m.activo_codigo, unidad = m.unidad_simbolo ?? m.unidad_nombre ?? "",
                            valor = n(m.ame_valor_actual), activa = m.ame_habilitado
                        }).ToList()
                    };
                case "tipos":
                    return new
                    {
                        error = false, editar = Token.Puede("CREAR EDITAR TIPOS ACTIVO"),
                        opciones = new { tipos = OpcionesTipos() },
                        filas = (new ActivoTipoController().GetActivoTipos(new ActivoTipo { filtro_cliente = cli }) ?? new List<ActivoTipo>()).Select(t => new
                        {
                            id = t.ati_id, padreId = t.ati_activo_tipo_padre ?? 0, global = t.es_global,
                            q = Cifrar("Id=" + t.ati_id), codigo = t.ati_codigo, nombre = t.ati_nombre, padre = t.padre_nombre ?? "",
                            ambito = t.es_global ? "De SIGMA" : "De tu empresa", activa = t.ati_habilitado
                        }).ToList()
                    };
                case "modelos":
                    return new
                    {
                        error = false, editar = Token.Puede("CREAR EDITAR MODELOS ACTIVO"),
                        opciones = new { tipos = OpcionesTipos(), marcas = new FabricanteController().Catalogo().Select(f => f.nombre).ToList() },
                        filas = (new ActivoModeloController().GetModelos(new ActivoModelo { filtro_cliente = cli }) ?? new List<ActivoModelo>()).Select(m => new
                        {
                            id = m.amo_id, tipoId = m.amo_activo_tipo, global = m.es_global,
                            q = Cifrar("Id=" + m.amo_id), marca = m.amo_fabricante ?? "", nombre = m.amo_nombre, tipo = m.tipo_nombre ?? "",
                            ambito = m.es_global ? "De SIGMA" : "De tu empresa", activa = m.amo_habilitado
                        }).ToList()
                    };
            }
            throw new Exception("Esa lista no existe.");
        });
    }

    // ======================================================= catalogos en linea
    /* Variables, Medidores, Tipos y Modelos se crean, editan y borran en la
       misma fila de su pestaña, sin abrir la ficha en un modal. Las reglas son
       las de siempre: los mismos controllers y SP de las fichas. */

    private static List<object> OpcionesActivos()
    {
        return (new ActivoController().GetActivos(new Activo { act_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true }) ?? new List<Activo>())
               .OrderBy(a => a.act_nombre).Select(a => (object)new { id = a.act_id, n = a.act_nombre + " · " + a.act_codigo }).ToList();
    }

    private static List<object> OpcionesUnidades()
    {
        return (new UnidadMedidaController().GetUnidades() ?? new List<UnidadMedida>())
               .Select(u => (object)new { id = u.ume_id, n = string.IsNullOrEmpty(u.ume_simbolo) ? u.ume_nombre : u.ume_nombre + " (" + u.ume_simbolo + ")" }).ToList();
    }

    private static List<string> OpcionesVariables()
    {
        return (new VariableMedicionController().GetVariables(SitioBase.Session.ClienteId()) ?? new List<VariableMedicion>())
               .Select(v => v.vme_nombre).Distinct().OrderBy(x => x).ToList();
    }

    private static List<object> OpcionesTipos()
    {
        return (new ActivoTipoController().GetActivoTipos(new ActivoTipo { filtro_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true }) ?? new List<ActivoTipo>())
               .OrderBy(t => t.ati_nombre).Select(t => (object)new { id = t.ati_id, n = t.ati_nombre }).ToList();
    }

    private static decimal? Numero(string t)
    {
        t = (t ?? "").Trim();
        if (t == "") return null;
        // Llega del <input type=number> (punto decimal); si alguien escribe coma, es decimal.
        decimal d;
        if (decimal.TryParse(t.Replace(',', '.'), NumberStyles.Float, CultureInfo.InvariantCulture, out d)) return d;
        throw new Exception("«" + t + "» no es un número.");
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarVariable(int id, int activo, string que, int unidad, string min, string max, string horas, bool activa)
    {
        return Ejecutar("CREAR EDITAR VARIABLES ACTIVO", () =>
        {
            ActivoVariableController c = new ActivoVariableController();
            if (id > 0)
            {
                ActivoVariable previa = c.GetVariable(id);
                if (previa == null || previa.ava_id == 0) throw new Exception("La variable no existe.");
                DelCliente(previa.ava_activo);
                activo = previa.ava_activo;
            }
            else DelCliente(activo);
            if (unidad <= 0) throw new Exception("Elige la unidad.");
            int vme = 0;
            if (id == 0)
            {
                // Lo que se mide se elige al crear; despues solo cambian rango, unidad y frecuencia.
                if (string.IsNullOrWhiteSpace(que)) throw new Exception("Escribe qué se mide.");
                vme = new VariableMedicionController().ResolverPorNombre(que, unidad);
                if (vme <= 0) throw new Exception("No se pudo guardar «" + que + "».");
            }

            ActivoVariable v = new ActivoVariable();
            v.ava_id = id; v.ava_activo = activo; v.ava_variable_medicion = vme; v.ava_unidad_medida = unidad;
            v.ava_valor_minimo = Numero(min); v.quita_minimo = v.ava_valor_minimo == null;
            v.ava_valor_maximo = Numero(max); v.quita_maximo = v.ava_valor_maximo == null;
            v.quita_advertencia = v.quita_critico = true;
            decimal? h = Numero(horas);
            if (h != null && h.Value <= 0) throw new Exception("«Cada» tiene que ser un número de horas mayor que cero.");
            if (h != null) v.ava_frecuencia_esperada_hora = (int)h.Value; else v.quita_frecuencia = true;
            v.ava_habilitado = activa;
            return Resultado(id > 0 ? c.Update(v) : c.Insert(v));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string BorrarVariable(int id)
    {
        return Ejecutar("CREAR EDITAR VARIABLES ACTIVO", () =>
        {
            ActivoVariableController c = new ActivoVariableController();
            ActivoVariable v = c.GetVariable(id);
            if (v == null || v.ava_id == 0) throw new Exception("La variable no existe.");
            DelCliente(v.ava_activo);
            return Resultado(c.Delete(id));
        });
    }

    /// <summary>Las ultimas lecturas de una variable, para verlas en su fila (sin abrir otra pagina).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Lecturas(int variable)
    {
        return Ejecutar(P_VER, () =>
        {
            ActivoVariableController c = new ActivoVariableController();
            ActivoVariable v = c.GetVariable(variable);
            if (v == null || v.ava_id == 0) throw new Exception("La variable no existe.");
            DelCliente(v.ava_activo);
            DateTime hasta = global::SitioBase.Hora.Hoy.AddDays(1), desde = hasta.AddDays(-90);
            CultureInfo cl = new CultureInfo("es-CL");
            List<MedicionSerie> serie = c.GetSerie(variable, desde, hasta) ?? new List<MedicionSerie>();
            MedicionSerieResumen r = c.GetSerieResumen(variable, desde, hasta) ?? new MedicionSerieResumen();
            return new
            {
                error = false,
                min = v.ava_valor_minimo, max = v.ava_valor_maximo, unidad = v.unidad_simbolo ?? "",
                resumen = new { puntos = r.puntos, fuera = r.fuera_rango + r.criticos, aviso = r.advertencias, ultimo = r.ultimo_valor, promedio = r.promedio },
                lecturas = serie.OrderByDescending(x => x.fecha).Take(40).Select(x => new
                {
                    f = x.fecha.ToString("dd MMM yyyy HH:mm", cl), v = x.valor, nivel = x.nivel ?? "", quien = x.usuario_nombre ?? "", origen = x.origen ?? ""
                }).ToList()
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarMedidor(int id, int activo, string nombre, int unidad, string valor, bool activa)
    {
        return Ejecutar("CREAR EDITAR MEDIDORES", () =>
        {
            ActivoMedidorController c = new ActivoMedidorController();
            string codigo = SitioBase.CodigoModulo.Componer("Activo_Medidor", "");
            if (id > 0)
            {
                ActivoMedidor previo = c.GetActivoMedidor(id);
                if (previo == null || previo.ame_id == 0) throw new Exception("El medidor no existe.");
                DelCliente(previo.ame_activo);
                codigo = previo.ame_codigo;
                if (activo <= 0) activo = previo.ame_activo;
            }
            DelCliente(activo);
            if (string.IsNullOrWhiteSpace(nombre)) throw new Exception("Escribe qué cuenta el medidor.");
            if (unidad <= 0) throw new Exception("Elige la unidad.");
            decimal? val = Numero(valor);
            if (val != null && val.Value < 0) throw new Exception("La lectura no puede ser negativa.");

            ActivoMedidor m = id > 0 ? c.GetActivoMedidor(id) : new ActivoMedidor();
            m.ame_id = id; m.ame_cliente = SitioBase.Session.ClienteId(); m.ame_activo = activo; m.ame_unidad_medida = unidad;
            m.ame_codigo = codigo; m.ame_nombre = nombre.Trim(); m.ame_valor_actual = val ?? 0m; m.ame_habilitado = activa;
            return Resultado(id > 0 ? c.UpdateActivoMedidor(m) : c.InsertActivoMedidor(m));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string BorrarMedidor(int id)
    {
        return Ejecutar("CREAR EDITAR MEDIDORES", () =>
        {
            ActivoMedidorController c = new ActivoMedidorController();
            ActivoMedidor m = c.GetActivoMedidor(id);
            if (m == null || m.ame_id == 0) throw new Exception("El medidor no existe.");
            DelCliente(m.ame_activo);
            return Resultado(c.DeleteActivoMedidor(m));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarTipo(int id, string nombre, int padre, bool activa)
    {
        return Ejecutar("CREAR EDITAR TIPOS ACTIVO", () =>
        {
            ActivoTipoController c = new ActivoTipoController();
            ActivoTipo t = new ActivoTipo();
            if (id > 0)
            {
                t = c.GetActivoTipo(id);
                if (t == null || t.ati_id == 0) throw new Exception("El tipo no existe.");
                if (t.es_global) throw new Exception("Los tipos de SIGMA no se cambian; crea uno de tu empresa.");
            }
            else t.ati_codigo = SitioBase.CodigoModulo.Componer("Activo_Tipo", "");
            if (string.IsNullOrWhiteSpace(nombre)) throw new Exception("Escribe el nombre del tipo.");
            if (padre == id && id > 0) throw new Exception("Un tipo no puede depender de sí mismo.");
            t.ati_id = id; t.ati_cliente = SitioBase.Session.ClienteId(); t.ati_nombre = nombre.Trim(); t.ati_habilitado = activa;
            if (padre > 0) t.ati_activo_tipo_padre = padre; else { t.ati_activo_tipo_padre = null; t.quita_padre = true; }
            return Resultado(id > 0 ? c.UpdateActivoTipo(t) : c.InsertActivoTipo(t));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string BorrarTipo(int id)
    {
        return Ejecutar("CREAR EDITAR TIPOS ACTIVO", () =>
        {
            ActivoTipoController c = new ActivoTipoController();
            ActivoTipo t = c.GetActivoTipo(id);
            if (t == null || t.ati_id == 0) throw new Exception("El tipo no existe.");
            if (t.es_global) throw new Exception("Los tipos de SIGMA no se borran.");
            return Resultado(c.DeleteActivoTipo(t));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarModelo(int id, int tipo, string marca, string nombre, bool activa)
    {
        return Ejecutar("CREAR EDITAR MODELOS ACTIVO", () =>
        {
            ActivoModeloController c = new ActivoModeloController();
            ActivoModelo m = new ActivoModelo();
            if (id > 0)
            {
                m = c.GetModelo(id);
                if (m == null || m.amo_id == 0) throw new Exception("El modelo no existe.");
                if (m.es_global) throw new Exception("Los modelos de SIGMA no se cambian; crea uno de tu empresa.");
            }
            if (tipo <= 0) throw new Exception("Elige el tipo de activo.");
            if (string.IsNullOrWhiteSpace(nombre)) throw new Exception("Escribe el modelo.");
            m.amo_id = id; m.amo_cliente = SitioBase.Session.ClienteId(); m.amo_activo_tipo = tipo;
            m.amo_nombre = nombre.Trim(); m.amo_fabricante = string.IsNullOrWhiteSpace(marca) ? null : marca.Trim(); m.amo_habilitado = activa;
            return Resultado(id > 0 ? c.UpdateModelo(m) : c.InsertModelo(m));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string BorrarModelo(int id)
    {
        return Ejecutar("CREAR EDITAR MODELOS ACTIVO", () =>
        {
            ActivoModeloController c = new ActivoModeloController();
            ActivoModelo m = c.GetModelo(id);
            if (m == null || m.amo_id == 0) throw new Exception("El modelo no existe.");
            if (m.es_global) throw new Exception("Los modelos de SIGMA no se borran.");
            return Resultado(c.DeleteModelo(m));
        });
    }


    // ================================================= repuestos compatibles
    /* «Agregar repuesto compatible» en el explorador de la planta y en el
       asistente del centro: el repuesto le sirve a ESTE activo (o subactivo)
       o a uno de sus componentes (bloque 351). */

    private static Dictionary<int, int> PortadasRepuesto()
    {
        try { return new RepuestoFotoController().GetPortadas() ?? new Dictionary<int, int>(); }
        catch (Exception) { return new Dictionary<int, int>(); }
    }

    private static string FotoRepuesto(Dictionary<int, int> portadas, int repuesto)
    {
        int arc;
        return portadas.TryGetValue(repuesto, out arc) && arc > 0 ? UrlArchivo.Ver(arc) : null;
    }

    /// <summary>Los repuestos del cliente para el combo: nombre, codigo, stock y su foto.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Repuestos()
    {
        return Ejecutar(P_VER, () =>
        {
            Dictionary<int, int> fotos = PortadasRepuesto();
            CultureInfo cl = new CultureInfo("es-CL");
            DataTable t = new ActivoPlantaController().GetRepuestosElegir();
            return new
            {
                error = false,
                filas = t.Rows.Cast<DataRow>().Select(r => new
                {
                    id = Convert.ToInt32(r["ID"]), n = Txt(r, "NOMBRE"), c = Txt(r, "CODIGO"),
                    stock = Convert.ToDecimal(r["EXISTENCIA"]).ToString("#,0.##", cl), u = Txt(r, "UNIDAD"),
                    foto = FotoRepuesto(fotos, Convert.ToInt32(r["ID"]))
                }).ToList()
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string VincularRepuesto(int repuesto, int activo, int componente, string observacion)
    {
        return Ejecutar(P_EDITAR, () =>
        {
            if (repuesto <= 0) throw new Exception("Elige el repuesto.");
            if (componente > 0)
            {
                ActivoComponente x = new ActivoComponenteController().GetComponente(componente);
                if (x == null || x.aco_id == 0) throw new Exception("El componente no existe.");
                DelCliente(x.aco_activo);
                activo = 0;
            }
            else DelCliente(activo);
            return Resultado(new ActivoPlantaController().VincularRepuesto(repuesto, activo, componente, observacion));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarVinculoRepuesto(int vinculo)
    {
        return Ejecutar(P_EDITAR, () => Resultado(new ActivoPlantaController().QuitarVinculoRepuesto(vinculo)));
    }

    // ============================================================== cambios

    /// <summary>Lleva un activo a un lugar (0 = «Por ubicar») en una posicion (-1 = al final).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string MoverActivo(int activo, int lugar, int posicion)
    {
        return Ejecutar(P_EDITAR, () =>
        {
            Activo a = DelCliente(activo);
            PlantaPermitida(a.act_cliente_instalacion);
            if (lugar > 0) LugarPermitido(lugar);
            return Resultado(new ActivoPlantaController().MoverActivo(activo, lugar, posicion));
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarLugar(int id, int planta, int padre, int tipo, string nombre)
    {
        return Ejecutar(P_AREAS, () => { PlantaPermitida(planta); if (id > 0) LugarPermitido(id); return Resultado(new ActivoPlantaController().GuardarLugar(id, planta, padre, tipo, nombre)); });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string OrdenLugar(int id, int delta)
    {
        return Ejecutar(P_AREAS, () => { LugarPermitido(id); return Resultado(new ActivoPlantaController().OrdenLugar(id, delta)); });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarLugar(int id)
    {
        return Ejecutar(P_AREAS, () => { LugarPermitido(id); return Resultado(new ActivoPlantaController().QuitarLugar(id)); });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarTipoLugar(string singular, string plural)
    {
        return Ejecutar(P_AREAS, () => Resultado(new ActivoPlantaController().GuardarTipoLugar(singular, plural)));
    }

    /// <summary>
    /// Sube una foto (base64, ya achicada en el navegador) y la agrega al
    /// activo. Sin portada, o si se pide, queda de portada.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string SubirFoto(int activo, string nombre, string mime, string base64, bool portada)
    {
        return Ejecutar(P_EDITAR, () =>
        {
            DelCliente(activo);
            if (string.IsNullOrEmpty(mime) || !mime.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Solo se pueden agregar imágenes (PNG o JPG).");
            byte[] bytes = Convert.FromBase64String(base64 ?? "");
            if (bytes.Length == 0) throw new Exception("La foto llegó vacía.");
            if (bytes.Length > 8 * 1024 * 1024) throw new Exception("La foto es muy grande (más de 8 MB).");

            Archivo arc = new Archivo();
            arc.arc_cliente = SitioBase.Session.ClienteId();
            arc.arc_archivo_categoria = 10;   // REFERENCIA
            arc.arc_nombre_original = System.IO.Path.GetFileName(string.IsNullOrEmpty(nombre) ? "foto.jpg" : nombre);
            arc.arc_mime = mime;
            arc.contenido = bytes;
            ArchivoController.Alivianar(arc);   // la foto llega liviana al blob
            Respuesta ra = new ArchivoController().InsertArchivo(arc, "activos");
            if (ra.error || ra.codigo <= 0) throw new Exception(ra.detalle ?? "No se pudo subir la foto.");

            Respuesta r = new ActivoPlantaController().AgregarFoto(activo, ra.codigo, portada);
            return new { error = r.error, detalle = r.detalle, id = ra.codigo, url = UrlArchivo.Ver(ra.codigo) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Portada(int activo, int archivo)
    {
        return Ejecutar(P_EDITAR, () => { DelCliente(activo); return Resultado(new ActivoPlantaController().CambiarPortada(activo, archivo)); });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarFoto(int activo, int archivo)
    {
        return Ejecutar(P_EDITAR, () => { DelCliente(activo); return Resultado(new ActivoPlantaController().QuitarFoto(activo, archivo)); });
    }

    /// <summary>Cambia el estado del activo con el mismo SP de la ficha (pide motivo).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EstadoActivo(int activo, int estado, string motivo)
    {
        return Ejecutar(P_EDITAR, () =>
        {
            DelCliente(activo);
            if (string.IsNullOrWhiteSpace(motivo)) throw new Exception("Cuéntanos por qué cambia el estado.");
            ActivoEstadoHistorial e = new ActivoEstadoHistorial();
            e.aeh_activo = activo;
            e.nuevo_estado = estado;
            return Resultado(new ActivoEstadoHistorialController().CambiarEstado(e, SitioBase.Session.ClienteId(), motivo.Trim()));
        });
    }

    /// <summary>Cambia el estado de un componente (UPD_ACTIVO_COMPONENTE exige motivo y deja la huella).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EstadoComponente(int componente, int estado, string motivo)
    {
        return Ejecutar(P_COMP, () =>
        {
            ActivoComponenteController c = new ActivoComponenteController();
            ActivoComponente x = c.GetComponente(componente);
            if (x == null || x.aco_id == 0) throw new Exception("El componente no existe.");
            DelCliente(x.aco_activo);
            if (string.IsNullOrWhiteSpace(motivo)) throw new Exception("Cuéntanos por qué cambia el estado.");
            x.aco_cliente = SitioBase.Session.ClienteId();
            x.aco_activo_componente_estado = estado;
            x.aco_motivo_estado = motivo.Trim();
            return Resultado(c.UpdateComponente(x));
        });
    }

    /// <summary>
    /// Los numeros de las pestañas del modulo. Cada conteo va blindado: si uno
    /// falla, la planta igual se dibuja con un cero en esa pestaña.
    /// </summary>
    private static System.Threading.Tasks.Task<int>[] ConteosEnParalelo()
    {
        int cli = SitioBase.Session.ClienteId();
        return new[]
        {
            Paralelo.Pedir(() => (new ActivoVariableController().GetVariables(new ActivoVariable { filtro_habilitado = true }) ?? new List<ActivoVariable>()).Count, 0),
            Paralelo.Pedir(() => (new ActivoMedidorController().GetActivoMedidores(new ActivoMedidor { ame_cliente = cli, filtro_habilitado = true }) ?? new List<ActivoMedidor>()).Count, 0),
            Paralelo.Pedir(() => (new ActivoTipoController().GetActivoTipos(new ActivoTipo { filtro_cliente = cli, filtro_habilitado = true }) ?? new List<ActivoTipo>()).Count, 0),
            Paralelo.Pedir(() => (new ActivoModeloController().GetModelos(new ActivoModelo { filtro_cliente = cli, filtro_habilitado = true }) ?? new List<ActivoModelo>()).Count, 0)
        };
    }

    /// <param name="n">Los cuatro conteos ya lanzados por ConteosEnParalelo.</param>
    private static object Conteos(int componentes, System.Threading.Tasks.Task<int>[] n)
    {
        return new { componentes = componentes, variables = n[0].Result, medidores = n[1].Result, tipos = n[2].Result, modelos = n[3].Result };
    }

    // ================================================================ ayuda

    private static string Ejecutar(string permiso, Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            if (!Token.Puede(permiso))
                return Json(new { error = true, sinPermiso = true, detalle = "No tienes permiso para hacer esto." });
            return Json(accion());
        }
        catch (Exception ex)
        {
            /* Lo que falla en una consulta en paralelo llega envuelto: se
               muestra el error de verdad, no "One or more errors occurred". */
            AggregateException ag = ex as AggregateException;
            if (ag != null && ag.Flatten().InnerException != null) ex = ag.Flatten().InnerException;
            return Json(new { error = true, detalle = ex.Message });
        }
    }

    private static object Resultado(Respuesta r)
    {
        return new { error = r.error, detalle = r.detalle, id = r.codigo };
    }

    private static string Json(object o)
    {
        return new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Serialize(o);
    }

    /// <summary>El activo tiene que ser de la empresa de la sesion; si no, se corta aqui.</summary>
    private static Activo DelCliente(int activo)
    {
        Activo a = new ActivoController().GetActivo(activo);
        if (a == null || a.act_id == 0 || a.act_cliente != SitioBase.Session.ClienteId())
            throw new Exception("El activo no existe.");
        return a;
    }

    /// <summary>
    /// Las plantas asignadas a la persona en este cliente, vigentes. Null = no
    /// tiene asignacion (por ejemplo, el administrador de SIGMA): ve todas.
    /// </summary>
    private static HashSet<int> PlantasPermitidas()
    {
        int u; if (!int.TryParse(SitioBase.Session.UsuarioId(), out u)) return null;
        List<ClienteUsuarioPlanta> l;
        try { l = new ClienteUsuarioController().PlantasDelUsuario(u, SitioBase.Session.ClienteId()) ?? new List<ClienteUsuarioPlanta>(); }
        catch (Exception) { return null; }
        if (l.Count == 0) return null;
        DateTime hoy = global::SitioBase.Hora.Hoy;
        return new HashSet<int>(l.Where(p => p.habilitada && (p.fecha_inicio == null || p.fecha_inicio.Value.Date <= hoy) && (p.fecha_fin == null || p.fecha_fin.Value.Date >= hoy))
                                 .Select(p => p.instalacion));
    }

    private static void PlantaPermitida(int planta)
    {
        HashSet<int> mias = PlantasPermitidas();
        if (mias != null && !mias.Contains(planta)) throw new Exception("No tienes acceso a esa planta.");
    }

    /// <summary>El lugar es de la empresa y de una planta de la persona.</summary>
    private static void LugarPermitido(int lugar)
    {
        InstalacionArea l = (new InstalacionAreaController().GetInstalacionAreas(new InstalacionArea()) ?? new List<InstalacionArea>())
                            .FirstOrDefault(x => x.iar_id == lugar);
        if (l == null) throw new Exception("El lugar no existe.");
        PlantaPermitida(l.iar_cliente_instalacion);
    }

    private static string Txt(DataRow r, string c) { return r[c] == DBNull.Value ? "" : Convert.ToString(r[c]); }

    private static string Cifrar(string s) { return System.Web.HttpUtility.UrlEncode(Tools.Crypto.Encrypt(s)); }

    private static string ResolverUrl(string ruta) { return System.Web.VirtualPathUtility.ToAbsolute(ruta); }

    private static string Url360(int activo)
    {
        return ResolverUrl("~/View/Activos/Ficha/ActivoFicha.aspx") + "?query=" + Cifrar("Id=" + activo);
    }

    private static string Sin(string s)
    {
        string n = (s ?? "").Normalize(NormalizationForm.FormD);
        StringBuilder b = new StringBuilder();
        foreach (char ch in n) if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark) b.Append(ch);
        return b.ToString().ToUpperInvariant();
    }

    /// <summary>Estado de negocio como clave de las vistas: operativo, observacion, mantenimiento, detenido o fuera.</summary>
    private static string ClaveEstado(string s)
    {
        string c = Sin(s);
        if (c.Contains("FUERA") || c.Contains("BAJA") || c.Contains("FALLA")) return "fuera";
        if (c.Contains("DETEN") || c.Contains("PARAD")) return "detenido";
        if (c.Contains("MANTEN") || c.Contains("REPARA") || c.Contains("TALLER")) return "mantenimiento";
        if (c.Contains("OBSERV") || c.Contains("DEGRAD") || c.Contains("REVIS")) return "observacion";
        return "operativo";
    }

    private static string ClaveCriticidad(string s)
    {
        string c = Sin(s);
        if (c.Contains("CRIT")) return "critica";
        if (c.Contains("ALTA")) return "alta";
        if (c.Contains("BAJA")) return "baja";
        return "media";
    }

    /// <summary>El dibujo por tipo cuando el activo no tiene foto.</summary>
    private static string IconoTipo(string tipo)
    {
        string t = Sin(tipo);
        if (t.Contains("CAMARA") || t.Contains("FRIO") || t.Contains("REFRIGER")) return "camara";
        if (t.Contains("HORNO")) return "horno";
        if (t.Contains("AMASADORA") || t.Contains("MEZCLADORA")) return "amasadora";
        if (t.Contains("BOMBA")) return "bomba";
        if (t.Contains("CALDERA")) return "caldera";
        if (t.Contains("COMPRESOR")) return "compresor";
        if (t.Contains("DOSIFIC")) return "dosificador";
        return "otro";
    }
}
