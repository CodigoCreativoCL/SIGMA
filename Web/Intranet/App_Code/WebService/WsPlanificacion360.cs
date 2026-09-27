using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Datos de las siete pestañas de Planificación 360. Cada pestaña se pide al
/// abrirla (carga diferida) y cada llamada vuelve a validar sesión y permiso:
/// el id cifrado identifica, no autoriza.
///
/// Programaciones exige VER PROGRAMACIONES (92); el resto, VER PLANES
/// MANTENIMIENTO (116). Generar OT exige CREAR ORDEN TRABAJO, y el SP que la
/// crea devuelve la existente si ya había una (no duplica ni bajo doble clic).
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsPlanificacion360 : System.Web.Services.WebService
{
    private static readonly CultureInfo ES = CultureInfo.GetCultureInfo("es-CL");
    private static readonly string[] MES = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" };

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GenerarOrden(string token)
    {
        try
        {
            if (!Token.Puede("CREAR ORDEN TRABAJO")) throw new Exception("No tiene permiso para generar órdenes de trabajo.");
            int id = Id(token);
            Respuesta r = new PlanOcurrenciaController().GenerarOrden(id);
            return Json(new { error = r.error, detalle = r.detalle, orden = r.codigo, ordenUrl = r.error ? "" : Url("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" + Q(r.codigo) });
        }
        catch (Exception ex) { return Json(new { error = true, detalle = ex.Message }); }
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cargar(string seccion, int planta, string desde, string hasta, int pagina, string filtro, bool soloParada,
                         string situacion, int plan, int equipo, int tipo, int area, int criticidad, string vista)
    {
        try
        {
            if (!Token.TokenSeguridad()) throw new Exception("La sesión expiró. Vuelve a entrar.");
            string s = (seccion ?? "").Trim().ToLowerInvariant();
            bool programaciones = s == "programaciones";
            if (programaciones ? !Token.Puede("VER PROGRAMACIONES") : !Token.Puede("VER PLANES MANTENIMIENTO"))
                return Json(new { error = true, sinPermiso = true, detalle = "No tienes permiso para ver esta información." });

            DateTime d, h;
            if (!DateTime.TryParseExact(desde, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ||
                !DateTime.TryParseExact(hasta, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out h) || h < d)
                throw new Exception("El período seleccionado no es válido.");

            int? inst = planta > 0 ? (int?)planta : null;
            object datos;
            switch (s)
            {
                case "kpis": datos = Kpis(inst); break;
                case "resumen": datos = Resumen(inst); break;
                case "bandeja": datos = Bandeja(inst, h, pagina, situacion, plan, filtro, soloParada); break;
                case "calendario": datos = Calendario(inst, d, h, plan, equipo, soloParada); break;
                case "planes": datos = Planes(inst, d, h, filtro, vista); break;
                case "programaciones": datos = Programaciones(planta, filtro, vista); break;
                case "cumplimiento": datos = Cumplimiento(inst, d, h); break;
                case "cobertura": datos = Cobertura(inst, vista, tipo, area, criticidad, pagina); break;
                default: throw new Exception("La pestaña solicitada no existe.");
            }
            return Json(new { error = false, datos = datos });
        }
        catch (Exception ex) { return Json(new { error = true, detalle = ex.Message }); }
    }

    // ---------------------------------------------------------------- KPIs

    /// <summary>
    /// Los cuatro números de la cabecera. Atención y disponibles son el
    /// estado a hoy (no los esconde el período); cumplimiento es enero a hoy;
    /// carga, las próximas cuatro semanas con su rango.
    /// </summary>
    private object Kpis(int? inst)
    {
        PlanOcurrenciaController c = new PlanOcurrenciaController();
        DateTime hoy = Hora.Hoy.Date;
        BandejaResumen r;
        c.GetBandeja(new PlanOcurrencia { filtro_instalacion = inst, solo_abiertas = true, pagina = 1, tamano = 1 }, out r);
        BandejaResumen rc;
        List<PlanOcurrencia> carga = c.GetBandeja(new PlanOcurrencia { filtro_instalacion = inst, filtro_desde = hoy, filtro_hasta = hoy.AddDays(27), solo_abiertas = true, pagina = 1, tamano = 5000 }, out rc) ?? new List<PlanOcurrencia>();
        List<PlanificacionCumplimientoEquipo> eq = new Planificacion360Controller().GetCumplimientoEquipos(inst, new DateTime(hoy.Year, 1, 1), hoy);
        int prog = eq.Sum(x => x.programadas), aTiempo = eq.Sum(x => x.a_tiempo);
        return new {
            urgente = r.vencidas + r.atrasadas, vencidas = r.vencidas, atrasadas = r.atrasadas, disponibles = r.disponibles,
            cumplimiento = prog == 0 ? (decimal?)null : Math.Round(100m * aTiempo / prog, 0),
            cumplimientoPie = "Ene – " + MES[hoy.Month - 1] + " " + hoy.Year + " · Fecha original",
            carga = Math.Round(carga.Sum(x => (decimal)(x.duracion_estimada_minuto ?? 0)) / 60m, 0),
            cargaPie = Corta(hoy) + " – " + Corta(hoy.AddDays(27))
        };
    }

    // ------------------------------------------------------------- Resumen

    private object Resumen(int? inst)
    {
        PlanOcurrenciaController c = new PlanOcurrenciaController();
        DateTime hoy = Hora.Hoy.Date;
        BandejaResumen r;
        List<PlanOcurrencia> abiertas = c.GetBandeja(new PlanOcurrencia { filtro_instalacion = inst, solo_abiertas = true, pagina = 1, tamano = 50 }, out r) ?? new List<PlanOcurrencia>();
        List<PlanOcurrencia> urgencias = abiertas.Where(x => x.situacion == "VENCIDA" || x.situacion == "ATRASADA")
            .OrderBy(x => x.situacion == "VENCIDA" ? 0 : 1).ThenBy(x => x.fecha_limite ?? x.fecha_programada).Take(5).ToList();
        BandejaResumen rp;
        List<PlanOcurrencia> paradas = c.GetBandeja(new PlanOcurrencia { filtro_instalacion = inst, filtro_desde = hoy, filtro_hasta = hoy.AddDays(30), solo_abiertas = true, solo_parada = true, pagina = 1, tamano = 5 }, out rp) ?? new List<PlanOcurrencia>();

        var borradores = new Planificacion360Controller().GetBorradores(inst).Select(b => new {
            codigo = b.codigo, nombre = b.nombre, familia = b.familia, version = b.version_numero, cambios = b.cambios,
            fecha = Larga(b.ultima_edicion), hace = Hace(b.ultima_edicion), responsable = b.responsable,
            url = Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") + "?query=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + b.plan_id + "&Sec=configuracion"))
        }).ToList();

        List<PlanificacionActividad> act = new Planificacion360Controller().GetActividad(inst, hoy.AddDays(-7), 5);
        return new {
            puedeGenerar = Token.Puede("CREAR ORDEN TRABAJO"),
            urgencias = urgencias.Select(Ocurrencia).ToList(),
            paradas = paradas.Select(Ocurrencia).ToList(),
            borradores = borradores,
            actividad = act.Select(x => new { orden = x.orden_correlativo, url = Url("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" + Q(x.orden_id),
                equipo = x.activo_nombre, hito = x.hito_nombre, fecha = Larga(x.fecha), estado = x.estado_nombre, estadoCodigo = x.estado_codigo }).ToList()
        };
    }

    // ------------------------------------------------------------- Bandeja

    /// <summary>
    /// Lo abierto hasta el fin del período: una vencida de agosto sigue
    /// apareciendo en septiembre. Los contadores son la botonera y no se
    /// filtran a sí mismos por situación.
    /// </summary>
    private object Bandeja(int? inst, DateTime hasta, int pagina, string situacion, int plan, string filtro, bool soloParada)
    {
        const int TAM = 25;
        BandejaResumen resumen;
        List<PlanOcurrencia> filas = new PlanOcurrenciaController().GetBandeja(new PlanOcurrencia {
            filtro_instalacion = inst, filtro_hasta = hasta, filtro_plan = plan > 0 ? (int?)plan : null,
            filtro_situacion = string.IsNullOrWhiteSpace(situacion) ? null : situacion.Trim().ToUpperInvariant(),
            filtro = string.IsNullOrWhiteSpace(filtro) ? null : filtro.Trim(), solo_parada = soloParada ? (bool?)true : null,
            solo_abiertas = true, pagina = Math.Max(1, pagina), tamano = TAM
        }, out resumen) ?? new List<PlanOcurrencia>();
        int todas = resumen.vencidas + resumen.atrasadas + resumen.disponibles + resumen.futuras;
        return new {
            resumen = new { todas = todas, vencidas = resumen.vencidas, atrasadas = resumen.atrasadas, disponibles = resumen.disponibles, futuras = resumen.futuras },
            puedeGenerar = Token.Puede("CREAR ORDEN TRABAJO"),
            planes = ListaPlanes(inst),
            filas = filas.Select(Ocurrencia).ToList(), pagina = Math.Max(1, pagina), total = resumen.total,
            paginas = Math.Max(1, (int)Math.Ceiling(resumen.total / (decimal)TAM)),
            exportarUrl = Url("~/View/Mantenimiento/Planes/PlanOcurrenciaBandeja.aspx")
        };
    }

    // ---------------------------------------------------------- Calendario

    private object Calendario(int? inst, DateTime desde, DateTime hasta, int plan, int equipo, bool soloParada)
    {
        const int TOPE = 1500;
        BandejaResumen resumen;
        List<PlanOcurrencia> filas = new PlanOcurrenciaController().GetBandeja(new PlanOcurrencia {
            filtro_instalacion = inst, filtro_desde = desde, filtro_hasta = hasta,
            filtro_plan = plan > 0 ? (int?)plan : null, filtro_activo = equipo > 0 ? (int?)equipo : null,
            solo_parada = soloParada ? (bool?)true : null, solo_abiertas = false, pagina = 1, tamano = TOPE
        }, out resumen) ?? new List<PlanOcurrencia>();
        filas = filas.OrderBy(x => x.fecha_programada).ToList();
        var equipos = filas.GroupBy(x => x.activo_id).Select(g => new { id = g.Key, texto = g.First().activo_codigo + " · " + g.First().activo_nombre })
            .OrderBy(x => x.texto).ToList();
        return new { filas = filas.Select(Ocurrencia).ToList(), total = resumen.total, truncado = resumen.total > filas.Count,
            planes = ListaPlanes(inst), equipos = equipos };
    }

    // -------------------------------------------------------------- Planes

    private object Planes(int? inst, DateTime desde, DateTime hasta, string filtro, string estado)
    {
        List<PlanMantenimiento> planes = new PlanMantenimientoController().GetPlanesMantenimiento(new PlanMantenimiento {
            pma_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true, filtro_instalacion = inst,
            filtro = string.IsNullOrWhiteSpace(filtro) ? null : filtro.Trim()
        }) ?? new List<PlanMantenimiento>();
        PlanOcurrenciaController ocurrencias = new PlanOcurrenciaController();
        PlanVersionController versiones = new PlanVersionController();
        DateTime hoy = Hora.Hoy.Date;
        var salida = new List<object>();
        foreach (PlanMantenimiento p in planes)
        {
            List<PlanVersion> vs = versiones.GetVersiones(p.pma_id, SitioBase.Session.ClienteId()) ?? new List<PlanVersion>();
            PlanVersion pub = vs.Where(v => v.estado_codigo == "PUBLICADO").OrderByDescending(v => v.pmv_numero).FirstOrDefault();
            PlanVersion bor = vs.Where(v => v.estado_codigo == "BORRADOR").OrderByDescending(v => v.pmv_numero).FirstOrDefault();
            if (estado == "PUBLICADO" && pub == null) continue;
            if (estado == "BORRADOR" && bor == null) continue;

            decimal? cumplimiento = null; string proxima = null;
            if (pub != null)
            {
                PlanCumplimiento c = ocurrencias.GetCumplimiento(p.pma_id, desde, hasta);
                if (c.programadas > 0) cumplimiento = Math.Round(c.cumplimiento, 0);
                List<PlanOcurrencia> prox = ocurrencias.GetCalendario(new PlanOcurrencia { filtro_plan = p.pma_id, filtro_desde = hoy, pagina = 1, tamano = 1 }) ?? new List<PlanOcurrencia>();
                if (prox.Count > 0) proxima = Larga(prox[0].fecha_programada);
            }
            PlanVersion vista = pub ?? bor;
            string q = Q(p.pma_id);
            salida.Add(new {
                codigo = p.pma_codigo, nombre = p.pma_nombre, familia = p.tipo_nombre, planta = p.planta_nombre,
                version = vista != null ? "v" + vista.pmv_numero : "—",
                publicada = pub == null ? null : new { numero = pub.pmv_numero, fecha = pub.pmv_fecha_publicacion.HasValue ? Larga(pub.pmv_fecha_publicacion.Value) : "—", por = pub.usuario_publicacion_nombre },
                borrador = bor == null ? null : new { numero = bor.pmv_numero, fecha = bor.pmv_fecha_creacion.HasValue ? Larga(bor.pmv_fecha_creacion.Value) : "—", por = bor.usuario_creacion_nombre },
                hitos = vista != null ? vista.hitos : 0, equipos = vista != null ? vista.activos : 0,
                cumplimiento = cumplimiento, proxima = proxima,
                url = Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") + "?query=" + q,
                editarUrl = Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") + "?query=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + p.pma_id + "&Sec=configuracion"))
            });
        }
        return new { planes = salida, puedeCrear = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"),
            nuevoUrl = Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx"),
            cargaUrl = Url("~/View/Mantenimiento/Planes/CargaMasivaPlanes.aspx") };
    }

    // ------------------------------------------------------ Programaciones

    /// <summary>
    /// Las fechas son PROYECCIONES: fecha única muestra una, calendario e
    /// intervalo hasta tres; medidor y condición muestran su disparador y no
    /// inventan fechas.
    /// </summary>
    private object Programaciones(int planta, string filtro, string tipo)
    {
        List<PlanificacionProgramacionUso> usos = new Planificacion360Controller().GetUsosProgramacion();
        ProgramacionController controller = new ProgramacionController();
        List<Programacion> lista = controller.GetProgramaciones(new Programacion { filtro_habilitado = true }) ?? new List<Programacion>();
        if (planta > 0) lista = lista.Where(x => x.pro_cliente_instalacion == null || x.pro_cliente_instalacion == planta).ToList();
        if (!string.IsNullOrWhiteSpace(filtro))
        {
            string f = filtro.Trim().ToLowerInvariant();
            lista = lista.Where(x => (x.pro_nombre ?? "").ToLowerInvariant().Contains(f) || (x.AlcanceTexto ?? "").ToLowerInvariant().Contains(f)).ToList();
        }
        if (!string.IsNullOrWhiteSpace(tipo)) lista = lista.Where(x => x.tipo_codigo == tipo).ToList();

        var salida = new List<object>();
        foreach (Programacion p in lista)
        {
            int n = p.tipo_codigo == "FECHA UNICA" ? 1 : (p.tipo_codigo == "CALENDARIO" || p.tipo_codigo == "INTERVALO TIEMPO") ? 3 : 0;
            List<ProgramacionProyeccion> proy = n == 0 ? new List<ProgramacionProyeccion>() : (controller.GetProyeccion(p.pro_id, n) ?? new List<ProgramacionProyeccion>());
            string disparador = p.tipo_codigo == "MEDIDOR" ? "Al alcanzar el umbral" : p.tipo_codigo == "CONDICION" ? "Al cumplirse la condición" : p.tipo_codigo == "ABIERTA" ? "Sin fecha fija" : null;
            salida.Add(new {
                nombre = p.pro_nombre, alcance = p.AlcanceTexto, tipoCodigo = p.tipo_codigo, tipo = p.tipo_nombre, detalle = p.detalle,
                fechas = proy.Take(n).Select(x => x.fecha.Day.ToString("00") + " " + MES[x.fecha.Month - 1] + (x.fecha.Year != Hora.Hoy.Year ? " " + x.fecha.Year : "")).ToArray(),
                disparador = disparador,
                usos = usos.Where(x => x.programacion_id == p.pro_id).Select(x => new { origen = x.origen, nombre = (string.IsNullOrEmpty(x.codigo) ? "" : x.codigo + " · ") + x.nombre,
                    url = UrlUso(x), modal = x.origen == "Pauta" }).ToList(),
                vigente = p.vigente,
                url = Url("~/View/Mantenimiento/Programaciones/Programacion.aspx") + "?query=" + Q(p.pro_id)
            });
        }
        return new { reglas = salida, puedeEditar = Token.Puede("CREAR EDITAR PROGRAMACIONES"),
            nuevaUrl = Url("~/View/Mantenimiento/Programaciones/Programacion.aspx") + "?query=0" };
    }

    private string UrlUso(PlanificacionProgramacionUso u)
    {
        if (u.origen == "Plan") return Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") + "?query=" + Q(u.id);
        if (u.origen == "Tarea") return Url("~/View/Mantenimiento/Tareas/Tarea.aspx") + "?query=" + Q(u.id);
        return Url("~/View/Mantenimiento/Checklist/ChecklistProgramacion.aspx") + "?query=" + Q(u.id);
    }

    // -------------------------------------------------------- Cumplimiento

    /// <summary>
    /// Cohorte: ocurrencias cuya fecha ORIGINAL cae en el período.
    /// Denominador: programadas. Numerador: completadas a tiempo contra la
    /// fecha original (más la tolerancia del hito). Reprogramadas es una
    /// condición transversal y no se suma a los estados.
    /// </summary>
    private object Cumplimiento(int? inst, DateTime desde, DateTime hasta)
    {
        List<PlanificacionCumplimientoEquipo> eq = new Planificacion360Controller().GetCumplimientoEquipos(inst, desde, hasta);
        int prog = eq.Sum(x => x.programadas), aT = eq.Sum(x => x.a_tiempo), aV = eq.Sum(x => x.a_tiempo_vigente);
        return new {
            programadas = prog, aTiempo = aT, aTiempoVigente = aV,
            original = prog == 0 ? (decimal?)null : Math.Round(100m * aT / prog, 0),
            vigente = prog == 0 ? (decimal?)null : Math.Round(100m * aV / prog, 0),
            completadas = eq.Sum(x => x.cumplidas), atrasadas = eq.Sum(x => x.atrasadas), vencidas = eq.Sum(x => x.vencidas),
            omitidas = eq.Sum(x => x.omitidas), reprogramadas = eq.Sum(x => x.reprogramadas),
            equipos = eq.OrderBy(x => x.cumplimiento).ThenBy(x => x.activo_nombre).Select(x => new {
                id = x.activo_id, codigo = x.activo_codigo, nombre = x.activo_nombre, programadas = x.programadas, completadas = x.cumplidas,
                aTiempo = x.a_tiempo, cumplimiento = x.cumplimiento }).ToList()
        };
    }

    // ----------------------------------------------------------- Cobertura

    private object Cobertura(int? inst, string vista, int tipo, int area, int criticidad, int pagina)
    {
        const int TAM = 10;
        Planificacion360Controller c = new Planificacion360Controller();
        bool varios = vista == "varios";
        List<PlanificacionCobertura> todos = c.GetCobertura(inst, varios);
        List<PlanificacionCobertura> filas = todos.Where(x => (tipo <= 0 || x.tipo_id == tipo) && (area <= 0 || x.area_id == area) && (criticidad <= 0 || x.criticidad_id == criticidad)).ToList();
        int pag = Math.Max(1, pagina), paginas = Math.Max(1, (int)Math.Ceiling(filas.Count / (decimal)TAM));
        pag = Math.Min(pag, paginas);
        List<PlanificacionCobertura> coincidencias = varios ? todos : c.GetCobertura(inst, true);
        return new {
            resumen = c.GetCoberturaResumen(inst),
            tipos = todos.Where(x => x.tipo_id != null).GroupBy(x => x.tipo_id).Select(g => new { id = g.Key, texto = g.First().tipo_nombre }).OrderBy(x => x.texto).ToList(),
            areas = todos.Where(x => x.area_id != null).GroupBy(x => x.area_id).Select(g => new { id = g.Key, texto = g.First().area_nombre }).OrderBy(x => x.texto).ToList(),
            criticidades = todos.Where(x => x.criticidad_id != null).GroupBy(x => x.criticidad_id).Select(g => new { id = g.Key, texto = g.First().criticidad_nombre }).OrderByDescending(x => x.id).ToList(),
            filas = filas.Skip((pag - 1) * TAM).Take(TAM).Select(Equipo).ToList(),
            total = filas.Count, pagina = pag, paginas = paginas,
            coincidencias = coincidencias.Take(3).Select(Equipo).ToList()
        };
    }

    private object Equipo(PlanificacionCobertura x)
    {
        return new { codigo = x.activo_codigo, nombre = x.activo_nombre, tipo = x.tipo_nombre, planta = x.planta_nombre,
            area = x.area_nombre, criticidad = x.criticidad_nombre, criticidadCodigo = x.criticidad_codigo,
            planes = x.planes, planesNombres = string.IsNullOrEmpty(x.planes_nombres) ? new string[0] : x.planes_nombres.Split(new[] { "; " }, StringSplitOptions.None),
            url = Url("~/View/Activos/Ficha/ActivoFicha.aspx") + "?query=" + Q(x.activo_id) };
    }

    // ------------------------------------------------------------ Comunes

    private object ListaPlanes(int? inst)
    {
        return (new PlanMantenimientoController().GetPlanesMantenimiento(new PlanMantenimiento { pma_cliente = SitioBase.Session.ClienteId(), filtro_habilitado = true, filtro_instalacion = inst }) ?? new List<PlanMantenimiento>())
            .Select(p => new { id = p.pma_id, texto = p.pma_codigo + " · " + p.pma_nombre }).ToList();
    }

    /// <summary>
    /// Una ocurrencia como la pintan todas las pestañas. El registro que se
    /// abre es la OT si ya existe; si no, el Centro del plan en su
    /// calendario, que es donde la ocurrencia vive.
    /// </summary>
    private Dictionary<int, PlanificacionHitoRequisito> requisitos;

    private object Ocurrencia(PlanOcurrencia o)
    {
        if (requisitos == null) requisitos = new Planificacion360Controller().GetHitoRequisitos();
        PlanificacionHitoRequisito rq;
        requisitos.TryGetValue(o.hito_id, out rq);
        DateTime hoy = Hora.Hoy.Date;
        DateTime f = o.fecha_programada;
        bool conHora = f.TimeOfDay.TotalMinutes > 0;
        int dur = o.duracion_estimada_minuto ?? 0;
        int atraso = (hoy - f.Date).Days;
        string otUrl = o.orden_trabajo_id != null ? Url("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?query=" + Q(o.orden_trabajo_id.Value) : null;
        string planCal = Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") + "?query=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + o.plan_id + "&Sec=calendario"));
        return new {
            token = Q(o.pmo_id), fecha = f.ToString("yyyy-MM-dd"), fechaTexto = Larga(f),
            relativo = atraso == 0 ? "Hoy" : atraso > 0 ? "Hace " + atraso + (atraso == 1 ? " día" : " días") : "En " + (-atraso) + (atraso == -1 ? " día" : " días"),
            atraso = atraso > 0 ? atraso : 0,
            hora = conHora ? f.ToString("HH:mm") : "", horaFin = conHora && dur > 0 ? f.AddMinutes(dur).ToString("HH:mm") : "",
            duracion = dur, duracionTexto = dur == 0 ? "" : (dur % 60 == 0 ? (dur / 60) + " h" : Math.Round(dur / 60m, 1).ToString(ES) + " h"),
            limite = o.fecha_limite != null ? Larga(o.fecha_limite.Value) : "",
            limiteSuperado = o.fecha_limite != null && o.fecha_limite.Value < Hora.Hoy,
            original = Larga(o.fecha_original ?? f), vigente = Larga(f), reprogramada = o.fue_reprogramada,
            planCodigo = o.plan_codigo, planNombre = o.plan_nombre, hitoCodigo = o.hito_codigo, hito = o.hito_nombre,
            activoCodigo = o.activo_codigo, equipo = o.activo_nombre, planta = o.planta_nombre, componente = o.componente_nombre,
            situacion = o.situacion, estado = o.estado_nombre,
            personas = rq != null ? rq.personas : 0, repuestos = rq != null ? rq.repuestos : 0,
            repuesto = rq != null ? rq.repuesto_principal : null, permiso = rq != null && rq.permiso, parada = o.requiere_parada, overhaul = o.es_overhaul, actividades = o.actividades,
            orden = o.orden_trabajo_correlativo, ordenUrl = otUrl,
            reprogramable = o.orden_trabajo_id == null && (o.estado_id == 1 || o.estado_id == 2),
            registroUrl = otUrl ?? planCal, registroTexto = otUrl != null ? "OT-" + o.orden_trabajo_correlativo : "Centro del plan",
            planUrl = Url("~/View/Mantenimiento/Planes/PlanMantenimiento.aspx") + "?query=" + Q(o.plan_id),
            reprogramarUrl = Url("~/View/Mantenimiento/Planes/PlanOcurrenciaReprogramar.aspx") + "?query=" + Q(o.pmo_id)
        };
    }

    private static string Larga(DateTime d) { return d.Day.ToString("00") + " " + MES[d.Month - 1] + " " + d.Year; }
    private static string Corta(DateTime d) { return d.Day + " " + MES[d.Month - 1] + "."; }
    private static string Hace(DateTime d)
    {
        TimeSpan t = Hora.Ahora - d;
        if (t.TotalHours < 1) return "hace minutos";
        if (t.TotalDays < 1) return "hace " + (int)t.TotalHours + ((int)t.TotalHours == 1 ? " hora" : " horas");
        return "hace " + (int)t.TotalDays + ((int)t.TotalDays == 1 ? " día" : " días");
    }
    private int Id(string token)
    {
        string plano = Tools.Crypto.Decrypt(HttpUtility.UrlDecode(token ?? ""));
        return int.Parse(plano.Split('=')[1]);
    }
    private string Q(int id) { return HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id)); }
    private string Url(string ruta) { return VirtualPathUtility.ToAbsolute(ruta); }
    private string Json(object valor) { return new System.Web.Script.Serialization.JavaScriptSerializer { MaxJsonLength = 4194304 }.Serialize(valor); }
}
