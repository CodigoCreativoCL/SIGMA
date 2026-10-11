using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Órdenes de trabajo (rediseño de Mantenimiento en cinco lugares, parte c): la lista y la
/// ficha de OT del lugar «Órdenes de trabajo» (Ordenes/Ordenes.aspx).
///
/// NO REESCRIBE EL CICLO DE VIDA: usa los SP de siempre. Iniciar = UPD_ORDEN_TRABAJO_TOMAR;
/// resolver un paso = API_UPD_ORDEN_TRABAJO_PASO; enviar a cierre = UPS_OT_INFORME +
/// UPD_ORDEN_TRABAJO_FINALIZAR; cerrar = UPD_ORDEN_TRABAJO_CERRAR_WEB. Lo nuevo (BD/398):
/// el informe, devolver a ejecución, el hallazgo encontrado en la OT y la OT manual.
///
/// CADA MÉTODO VALIDA SESIÓN Y PERMISO. La OT se identifica con su id cifrado (como en el resto
/// del sitio); los SP vuelven a exigir que sea del cliente de la sesión.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsOrdenes : System.Web.Services.WebService
{
    private const string P_VER = "VER ORDENES TRABAJO";
    private const string P_CREAR = "CREAR ORDEN TRABAJO";
    private const string P_EJECUTAR = "EJECUTAR ORDEN TRABAJO";
    private const string P_VALIDAR = "VALIDAR ORDEN TRABAJO";
    private const string P_FALLA = "REGISTRAR FALLA";

    // =====================================================================
    // LECTURAS
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Lista(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<Dictionary<string, object>> ots = SoporteDatos.Filas("SEL_OT_LISTA", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            foreach (Dictionary<string, object> o in ots) o["Q"] = Q(Entero(o, "OT_ID"));
            return new { ots = ots, permisos = Permisos() };
        });
    }

    /// <summary>Todo lo que la ficha pinta, en una sola llamada.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ficha(string token)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            return ArmarFicha(IdDe(token));
        });
    }

    /// <summary>Personas, activos y componentes para «Nueva OT» y para asignar responsables.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Catalogos(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<Dictionary<string, object>> personas = SoporteDatos.Filas("SEL_PLAN_CENTRO_PERSONAS", "@CLIENTE", Cli());
            foreach (Dictionary<string, object> p in personas)
            {
                int foto = Entero(p, "FOTO_ID");
                p["FOTO"] = foto > 0 ? SitioBase.UrlArchivo.Ver(foto) : "";
            }
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_AVISO_CATALOGO", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            List<object> proveedores = new List<object>();
            List<Proveedor> prv = new ProveedorController().GetProveedores(new Proveedor { filtro_habilitado = true, filtro_es_contratista = true });
            if (prv != null) foreach (Proveedor x in prv) proveedores.Add(new { ID = x.prv_id, NOMBRE = x.prv_razon_social });
            List<object> grupos = new List<object>();
            List<GrupoTrabajo> gr = new GrupoTrabajoController().GetGruposTrabajo(new GrupoTrabajo { gtr_cliente = Cli(), filtro_habilitado = true });
            if (gr != null) foreach (GrupoTrabajo g in gr) grupos.Add(new { ID = g.gtr_id, NOMBRE = g.gtr_codigo + " — " + g.gtr_nombre });
            List<object> procs = new List<object>();
            List<Procedimiento> pr = new ProcedimientoController().GetProcedimientos(new Procedimiento { prc_cliente = Cli(), filtro_habilitado = true });
            if (pr != null) foreach (Procedimiento x in pr) procs.Add(new { ID = x.prc_id, NOMBRE = (string.IsNullOrEmpty(x.prc_codigo) ? "" : x.prc_codigo + " · ") + x.prc_nombre });
            return new { personas = personas, activos = SoporteDatos.Del(c, 0), componentes = SoporteDatos.Del(c, 1), proveedores = proveedores, grupos = grupos, procedimientos = procs };
        });
    }

    // =====================================================================
    // ESCRITURAS DEL CICLO DE VIDA
    // =====================================================================

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Iniciar(string token)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EJECUTAR);
            int id = IdDe(token);
            Propia(id);
            SoporteDatos.Filas("UPD_ORDEN_TRABAJO_TOMAR", "@OTR_ID", id, "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>Resuelve un paso: 1 conforme · 2 no conforme · 3 no aplica · 4 pendiente (lo deja sin resolver).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Paso(string token, int paso, int resultado, string observacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EJECUTAR);
            int id = IdDe(token);
            Propia(id);
            if (!SoporteDatos.Filas("SEL_ORDEN_TRABAJO_PASO", "@CLIENTE", Cli(), "@ORDEN", id).Any(p => Entero(p, "otp_id") == paso))
                throw new Exception("El paso no es de esta orden.");
            SoporteDatos.Filas("API_UPD_ORDEN_TRABAJO_PASO", "@OTP_ID", paso, "@USUARIO", U(), "@CLIENTE", Cli(), "@RESULTADO_PASO", resultado,
                "@OBSERVACION", string.IsNullOrWhiteSpace(observacion) ? null : observacion.Trim());
            return ArmarFicha(id);
        });
    }

    /// <summary>Quien ejecuta entrega su informe y la OT pasa a «En espera de cierre».</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EnviarCierre(string token, string informe, string horas, int estadoActivo, string causa)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EJECUTAR);
            int id = IdDe(token);
            Propia(id);
            decimal h;
            object hor = decimal.TryParse((horas ?? "").Replace(',', '.'), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out h) ? (object)h : null;
            SoporteDatos.Filas("UPS_OT_INFORME", "@CLIENTE", Cli(), "@ID", id, "@INFORME", informe ?? "", "@HORAS_REALES", hor,
                "@ESTADO_ACTIVO", estadoActivo > 0 ? (object)estadoActivo : null, "@CAUSA", string.IsNullOrWhiteSpace(causa) ? null : causa.Trim(), "@USUARIO", U());
            string obs = (informe ?? "").Trim();
            SoporteDatos.Filas("UPD_ORDEN_TRABAJO_FINALIZAR", "@ORDEN_TRABAJO", id, "@USUARIO", U(), "@OBSERVACION", obs.Length > 500 ? obs.Substring(0, 500) : obs);
            return ArmarFicha(id);
        });
    }

    /// <summary>
    /// Cierra la OT. Pide la firma de quien cierra: se guarda ANTES de cerrar (si el cierre falla queda
    /// un archivo de más, que no miente; al revés quedaría una orden cerrada sin respaldo de quien la autorizó).
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Cerrar(string token, int motivo, string resultado, string firma)
    {
        return Ejecutar(() =>
        {
            if (!PuedeCerrar()) throw new Exception("Tu perfil no tiene la facultad de cerrar órdenes de trabajo.");
            int id = IdDe(token);
            Propia(id);
            // HU-117 · criterio 2: una OT con servicios de terceros no se cierra sin el informe de cada proveedor.
            List<Dictionary<string, object>> sinInforme = SoporteDatos.Filas("SEL_OT_SERVICIO_SIN_INFORME", "@CLIENTE", Cli(), "@ORDEN", id);
            if (sinInforme.Count > 0)
                throw new Exception("Falta el informe del proveedor en " + (sinInforme.Count == 1 ? "el servicio de " + Convert.ToString(Valor(sinInforme[0], "PROVEEDOR_NOMBRE")) : sinInforme.Count + " servicios") + ". Adjúntalo en Consumo › Servicios contratados antes de cerrar.");
            if (string.IsNullOrEmpty(firma))
            {
                // sin firma nueva: tiene que existir la de quien aprueba el cierre (validación aprobada) y la de recepción si el activo estuvo detenido
                List<OrdenTrabajoValidacion> fs = new OrdenTrabajoValidacionController().GetValidaciones(id);
                OrdenTrabajoValidacion ultima = fs.FirstOrDefault(x => x.tipo_codigo == "VALIDACION");
                if (ultima == null || !ultima.aprobada) throw new Exception("Falta la firma de quien aprueba el cierre.");
            }
            else
            {
                Respuesta f = new OrdenTrabajoArchivoController().GuardarFirma(id, firma);
                if (f.error) throw new Exception("No se pudo guardar la firma: " + f.detalle);
            }
            SoporteDatos.Filas("UPD_ORDEN_TRABAJO_CERRAR_WEB", "@ID", id, "@CLIENTE", Cli(), "@CIERRE_MOTIVO", motivo > 0 ? motivo : 1, "@RESULTADO", string.IsNullOrWhiteSpace(resultado) ? null : resultado.Trim(), "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>Registra una firma de aceptación, ejecución o validación (aprobada o rechazada).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Firmar(string token, int tipo, string resultado, string observacion, string firma)
    {
        return Ejecutar(() =>
        {
            Exigir(P_VALIDAR);
            int id = IdDe(token);
            Propia(id);
            if (resultado != "APROBADO" && resultado != "RECHAZADO") throw new Exception("Indica si apruebas o rechazas.");
            if (resultado == "RECHAZADO" && string.IsNullOrWhiteSpace(observacion)) throw new Exception("Indica el motivo del rechazo en la observación.");
            Respuesta r = new OrdenTrabajoValidacionController().Registrar(id, tipo, resultado, observacion, firma, Guid.NewGuid());
            if (r.error) throw new Exception(r.detalle);
            return ArmarFicha(id);
        });
    }

    /// <summary>Registra una indisponibilidad del activo ligada a esta orden.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Indisponibilidad(string token, string inicio, string fin, bool planificada, bool detuvo, int motivo, string detalle)
    {
        return Ejecutar(() =>
        {
            Exigir(P_FALLA);
            int id = IdDe(token);
            Propia(id);
            int activo = Entero(SoporteDatos.Filas("SEL_ORDEN_TRABAJO", "@ID", id, "@CLIENTE", Cli())[0], "otr_activo");
            if (activo <= 0) throw new Exception("Esta orden no tiene activo: no hay indisponibilidad que registrar.");
            DateTime ini, fi;
            if (!DateTime.TryParseExact(inicio ?? "", "yyyy-MM-dd HH:mm", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out ini)) throw new Exception("Indica el día y la hora en que empezó la detención.");
            DateTime? fin2 = DateTime.TryParseExact(fin ?? "", "yyyy-MM-dd HH:mm", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out fi) ? (DateTime?)fi : null;
            if (fin2 != null && fin2 <= ini) throw new Exception("El término debe ser posterior al inicio.");
            ActivoIndisponibilidad i = new ActivoIndisponibilidad { ain_activo = activo, ain_orden_trabajo = id, ain_fecha_inicio_utc = ini, ain_fecha_fin_utc = fin2, ain_planificada = planificada, ain_detuvo_produccion = detuvo };
            if (motivo > 0) i.ain_indisponibilidad_motivo = motivo;
            i.ain_motivo = string.IsNullOrWhiteSpace(detalle) ? null : detalle.Trim();
            Respuesta r = new IndisponibilidadController().Insert(i);
            if (r.error) throw new Exception(r.detalle);
            return ArmarFicha(id);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Devolver(string token, string motivo)
    {
        return Ejecutar(() =>
        {
            if (!PuedeCerrar()) throw new Exception("Tu perfil no tiene la facultad de cerrar órdenes de trabajo.");
            int id = IdDe(token);
            Propia(id);
            SoporteDatos.Filas("UPD_OT_DEVOLVER", "@CLIENTE", Cli(), "@ID", id, "@MOTIVO", motivo ?? "", "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    // =====================================================================
    // ASIGNACIÓN Y HALLAZGOS
    // =====================================================================

    /// <summary>
    /// Suma a una persona, a una empresa externa o a un grupo de trabajo. Si es responsable, el SP pasa
    /// al responsable anterior a apoyo (esa regla vive en el SP, no aquí).
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Asignar(string token, int usuario, int proveedor, int grupo, bool responsable, string observacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            if (usuario <= 0 && proveedor <= 0) throw new Exception("Elige la persona o la empresa externa que vas a asignar.");
            SoporteDatos.Filas("INS_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id,
                "@USUARIO_ASIG", usuario > 0 ? (object)usuario : null, "@PROVEEDOR", proveedor > 0 ? (object)proveedor : null,
                "@GRUPO_TRABAJO", grupo > 0 ? (object)grupo : null, "@ES_RESPONSABLE", responsable, "@ROL_EJECUCION", responsable ? 1 : 2,
                "@OBSERVACION", string.IsNullOrWhiteSpace(observacion) ? null : observacion.Trim(), "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>Cambia el grupo de trabajo del responsable: se vuelve a asignar con el grupo elegido.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GrupoDelResponsable(string token, int grupo)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            Dictionary<string, object> a = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id).FirstOrDefault(x => Entero(x, "ota_es_responsable") == 1);
            if (a == null) throw new Exception("Elige primero un responsable.");
            SoporteDatos.Filas("INS_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id,
                "@USUARIO_ASIG", Entero(a, "ota_usuario") > 0 ? (object)Entero(a, "ota_usuario") : null, "@PROVEEDOR", Entero(a, "ota_proveedor") > 0 ? (object)Entero(a, "ota_proveedor") : null,
                "@GRUPO_TRABAJO", grupo > 0 ? (object)grupo : null, "@ES_RESPONSABLE", true, "@ROL_EJECUCION", 1, "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>Nombrar responsable a quien ya está asignado: se vuelve a asignar con el rol cambiado.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string HacerResponsable(string token, int asignacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            Dictionary<string, object> a = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id).FirstOrDefault(x => Entero(x, "ota_id") == asignacion);
            if (a == null) throw new Exception("La asignación no es de esta orden.");
            SoporteDatos.Filas("INS_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id,
                "@USUARIO_ASIG", Entero(a, "ota_usuario") > 0 ? (object)Entero(a, "ota_usuario") : null, "@PROVEEDOR", Entero(a, "ota_proveedor") > 0 ? (object)Entero(a, "ota_proveedor") : null,
                "@GRUPO_TRABAJO", Entero(a, "ota_grupo_trabajo") > 0 ? (object)Entero(a, "ota_grupo_trabajo") : null, "@ES_RESPONSABLE", true, "@ROL_EJECUCION", 1, "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>Los datos de la orden (mientras no esté cerrada).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Guardar(string token, string titulo, string descripcion, string notas, int prioridad, int estrategia, string fecha, int duracionMin, bool requierePermiso)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            DateTime f;
            object fe = DateTime.TryParseExact(fecha ?? "", "yyyy-MM-dd HH:mm", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out f) ? (object)f : null;
            SoporteDatos.Filas("UPD_ORDEN_TRABAJO", "@ID", id, "@CLIENTE", Cli(), "@TITULO", titulo ?? "", "@DESCRIPCION", string.IsNullOrWhiteSpace(descripcion) ? null : descripcion.Trim(),
                "@PRIORIDAD", prioridad, "@ESTRATEGIA", estrategia, "@FECHA_PROGRAMADA_UTC", fe, "@DURACION_ESTIMADA_MINUTO", duracionMin > 0 ? (object)duracionMin : null,
                "@REQUIERE_PERMISO", requierePermiso, "@NOTAS", string.IsNullOrWhiteSpace(notas) ? null : notas.Trim(), "@QUITA_FECHA", fe == null, "@QUITA_DURACION", duracionMin <= 0, "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>Copia a la orden los pasos de un procedimiento (volver a agregarlo no duplica la lista).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string PasosDeProcedimiento(string token, int procedimiento)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            Respuesta r = new OrdenTrabajoController().AgregarPasosDeProcedimiento(id, procedimiento);
            if (r.error) throw new Exception(r.detalle);
            return new { mensaje = r.detalle, ficha = ArmarFicha(id) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarAsignacion(string token, int asignacion)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            if (!SoporteDatos.Filas("SEL_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id).Any(a => Entero(a, "ota_id") == asignacion))
                throw new Exception("La asignación no es de esta orden.");
            SoporteDatos.Filas("DEL_ORDEN_TRABAJO_ASIGNACION", "@ID", asignacion, "@CLIENTE", Cli(), "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>«¿Encontraste algo que no es parte de esta OT?»: crea un aviso de origen 9 enlazado a la OT.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string HallazgoEnOt(string token, string titulo, int componente, int severidad, string detalle)
    {
        return Ejecutar(() =>
        {
            Exigir(P_EJECUTAR);
            int id = IdDe(token);
            Propia(id);
            Dictionary<string, object> r = SoporteDatos.Fila("INS_OT_HALLAZGO_EN_OT", "@CLIENTE", Cli(), "@OT", id, "@TITULO", titulo ?? "",
                "@COMPONENTE", componente > 0 ? (object)componente : null, "@SEVERIDAD", severidad, "@DETALLE", string.IsNullOrWhiteSpace(detalle) ? null : detalle.Trim(), "@USUARIO", U());
            return new { hallazgo = Valor(r, "HALLAZGO_ID"), ficha = ArmarFicha(id) };
        });
    }

    /// <summary>OT manual (origen 1): activo, trabajo, tipo, prioridad, fecha y responsable.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Nueva(int activo, int componente, string titulo, string descripcion, int tipo, int prioridad, string fecha, int duracionMin, int responsable)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            DateTime f;
            object fe = DateTime.TryParseExact(fecha ?? "", "yyyy-MM-dd HH:mm", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out f) ? (object)f : null;
            Dictionary<string, object> r = SoporteDatos.Fila("UPS_OT_NUEVA", "@CLIENTE", Cli(), "@ACTIVO", activo, "@COMPONENTE", componente > 0 ? (object)componente : null,
                "@TITULO", titulo ?? "", "@DESCRIPCION", string.IsNullOrWhiteSpace(descripcion) ? null : descripcion.Trim(), "@TIPO", tipo, "@PRIORIDAD", prioridad,
                "@FECHA", fe, "@DURACION_MIN", duracionMin > 0 ? (object)duracionMin : null, "@RESPONSABLE", responsable > 0 ? (object)responsable : null, "@USUARIO", U());
            return new { ot = Valor(r, "OTR_CORRELATIVO"), q = Q(Entero(r, "OTR_ID")) };
        });
    }

    // =====================================================================
    // HU-117 · SERVICIOS CONTRATADOS
    // =====================================================================

    /// <summary>Tipos de servicio y monedas para el formulario del servicio.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ServicioCatalogos()
    {
        return Ejecutar(() =>
        {
            Exigir(P_VER);
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_OT_SERVICIO_CATALOGO", "@CLIENTE", Cli());
            return new { tipos = SoporteDatos.Del(c, 0), monedas = SoporteDatos.Del(c, 1) };
        });
    }

    /// <summary>Registra (servicio = 0) o corrige un servicio de un tercero. El SP valida que la OT no esté cerrada.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarServicio(string token, int servicio, int proveedor, int tipo, string descripcion, string cantidad, string monto, int moneda, string documento, string fecha)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            object cant = Numero(cantidad) ?? 1m, mto = Numero(monto);
            if (mto == null) throw new Exception("Indica el monto del servicio.");
            DateTime f; object fs = DateTime.TryParseExact(fecha ?? "", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out f) ? (object)f : null;
            object doc = string.IsNullOrWhiteSpace(documento) ? null : documento.Trim();
            if (servicio > 0)
                SoporteDatos.Filas("UPD_ORDEN_TRABAJO_SERVICIO", "@ID", servicio, "@CLIENTE", Cli(), "@PROVEEDOR", proveedor, "@SERVICIO_TIPO", tipo, "@DESCRIPCION", descripcion ?? "",
                    "@CANTIDAD", cant, "@MONTO_UNITARIO", null, "@MONTO", mto, "@MONEDA", moneda, "@DOCUMENTO", doc, "@FECHA_SERVICIO", fs, "@USUARIO", U());
            else
                SoporteDatos.Filas("INS_ORDEN_TRABAJO_SERVICIO", "@ID", null, "@CLIENTE", Cli(), "@ORDEN", id, "@PROVEEDOR", proveedor, "@SERVICIO_TIPO", tipo, "@DESCRIPCION", descripcion ?? "",
                    "@CANTIDAD", cant, "@MONTO_UNITARIO", null, "@MONTO", mto, "@MONEDA", moneda, "@DOCUMENTO", doc, "@FECHA_SERVICIO", fs, "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string QuitarServicio(string token, int servicio)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            SoporteDatos.Filas("DEL_ORDEN_TRABAJO_SERVICIO", "@ID", servicio, "@CLIENTE", Cli(), "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    /// <summary>
    /// Adjunta el informe que entregó el proveedor (PDF o imagen, en base64). Se guarda como un archivo
    /// más de la OT (categoría DOCUMENTO, así sale entre sus respaldos) y queda ligado a la línea del servicio.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string InformeServicio(string token, int servicio, string nombre, string datos)
    {
        return Ejecutar(() =>
        {
            Exigir(P_CREAR);
            int id = IdDe(token);
            Propia(id);
            if (string.IsNullOrEmpty(datos)) throw new Exception("Elige el archivo del informe.");
            int coma = datos.IndexOf(',');
            string cab = coma > 0 ? datos.Substring(0, coma) : "", mime = cab.StartsWith("data:") ? cab.Substring(5).Split(';')[0] : "application/octet-stream";
            if (mime != "application/pdf" && !mime.StartsWith("image/")) throw new Exception("El informe debe ser un PDF o una imagen.");
            byte[] bytes = Convert.FromBase64String(coma >= 0 ? datos.Substring(coma + 1) : datos);
            if (bytes.Length == 0) throw new Exception("El archivo llegó vacío.");
            if (bytes.Length > 10 * 1024 * 1024) throw new Exception("El informe supera los 10 MB.");
            Archivo a = new Archivo();
            a.arc_cliente = Cli();
            a.arc_archivo_categoria = CATEGORIA_DOCUMENTO;
            a.arc_nombre_original = string.IsNullOrWhiteSpace(nombre) ? "informe-proveedor-ot-" + id + (mime == "application/pdf" ? ".pdf" : ".jpg") : System.IO.Path.GetFileName(nombre);
            a.arc_mime = mime;
            a.contenido = bytes;
            Respuesta sub = new ArchivoController().InsertArchivo(a, "informes");
            if (sub.error) throw new Exception(sub.detalle);
            SoporteDatos.Filas("UPD_ORDEN_TRABAJO_SERVICIO_INFORME", "@ID", servicio, "@CLIENTE", Cli(), "@ARCHIVO", sub.codigo, "@USUARIO", U());
            SoporteDatos.Filas("VIN_ORDEN_TRABAJO_ARCHIVO", "@ORDEN", id, "@ARCHIVO", sub.codigo, "@PASO", null, "@TITULO", "Informe del proveedor", "@DESCRIPCION", null, "@USUARIO", U());
            return ArmarFicha(id);
        });
    }

    private const int CATEGORIA_DOCUMENTO = 9;

    /// <summary>Los servicios de la OT, con la URL del informe adjunto.</summary>
    private static List<Dictionary<string, object>> Servicios(int id)
    {
        List<Dictionary<string, object>> l = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_SERVICIO", "@CLIENTE", Cli(), "@ORDEN", id);
        foreach (Dictionary<string, object> s in l)
        {
            int arc = Entero(s, "INFORME_ID");
            s["INFORME_URL"] = arc > 0 ? SitioBase.UrlArchivo.Ver(arc) : "";
        }
        return l;
    }

    /// <summary>«1.250.000,5» o «1250000.5» → decimal (null si no es un número).</summary>
    private static object Numero(string s)
    {
        decimal n;
        string v = (s ?? "").Trim();
        if (v.IndexOf(',') >= 0) v = v.Replace(".", "").Replace(',', '.');
        return decimal.TryParse(v, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out n) ? (object)n : null;
    }

    // ---------------------------------------------------------------------

    private object ArmarFicha(int id)
    {
        List<Dictionary<string, object>> cab = SoporteDatos.Filas("SEL_ORDEN_TRABAJO", "@ID", id, "@CLIENTE", Cli());
        if (cab.Count == 0) throw new Exception("La orden de trabajo no existe.");
        Dictionary<string, object> ot = cab[0];
        List<List<Dictionary<string, object>>> ex = SoporteDatos.Conjuntos("SEL_OT_FICHA_EXTRA", "@CLIENTE", Cli(), "@ID", id);
        List<Dictionary<string, object>> origen = SoporteDatos.Del(ex, 0);
        int estado = Entero(ot, "otr_orden_trabajo_estado");
        return new
        {
            q = Q(id),
            yo = SitioBase.Session.UsuarioNombre(),
            ot = ot,
            pasos = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_PASO", "@CLIENTE", Cli(), "@ORDEN", id),
            repuestos = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_REPUESTO", "@CLIENTE", Cli(), "@ORDEN", id),
            manoObra = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_MANO_OBRA", "@CLIENTE", Cli(), "@ORDEN", id),
            servicios = Servicios(id),
            serviciosTotal = SoporteDatos.Filas("SEL_OT_SERVICIO_TOTAL", "@CLIENTE", Cli(), "@ORDEN", id),
            imprimirUrl = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/OrdenTrabajoImprimir.aspx") + "?query=" + Q(id),
            indisponibilidades = SoporteDatos.Filas("SEL_ACTIVO_INDISPONIBILIDAD", "@CLIENTE", Cli(), "@ORDEN", id),
            evidencias = Evidencias(id),
            firmas = Firmas(id),
            tiposFirma = new OrdenTrabajoValidacionController().GetTipos().Select(t => new { ID = t.id, CODIGO = t.codigo, NOMBRE = t.nombre }).ToList(),
            asignaciones = SoporteDatos.Filas("SEL_ORDEN_TRABAJO_ASIGNACION", "@CLIENTE", Cli(), "@ORDEN", id),
            origen = origen.Count > 0 ? origen[0] : null,
            avisos = SoporteDatos.Del(ex, 1),
            bitacora = SoporteDatos.Del(ex, 2),
            planUrl = Entero(origen.Count > 0 ? origen[0] : null, "PLAN_ID") > 0 ? VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Planificacion.aspx") + "#tab=planes&plan=" + HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + Entero(origen[0], "PLAN_ID"))) : null,
            fichaCompleta = VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/OrdenTrabajo.aspx") + "?legacy=1&query=" + Q(id),
            motivos = SoporteDatos.Filas("SEL_OT_CIERRE_MOTIVO"),
            permisos = Permisos(),
            estado = estado
        };
    }

    /// <summary>Las evidencias del trabajo (fotos, videos, audios y documentos), con su URL.</summary>
    private static List<object> Evidencias(int id)
    {
        List<object> l = new List<object>();
        foreach (OrdenTrabajoArchivo a in new OrdenTrabajoArchivoController().GetEvidencias(id))
            l.Add(new { ID = a.arc_id, NOMBRE = a.etiqueta, URL = SitioBase.UrlArchivo.Ver(a.arc_id), IMAGEN = a.es_imagen, VIDEO = a.es_video, AUDIO = a.es_audio, PASO = a.paso_nombre, QUIEN = a.usuario, FECHA = a.fecha.HasValue ? a.fecha.Value.ToString("yyyy-MM-ddTHH:mm:ss") : "", CATEGORIA = a.categoria_nombre, ES_FIRMA = a.categoria_codigo == "FIRMA" });
        return l;
    }

    /// <summary>El historial de firmas (aceptación, ejecución, validación) con la imagen de cada una.</summary>
    private static List<object> Firmas(int id)
    {
        List<object> l = new List<object>();
        foreach (OrdenTrabajoValidacion f in new OrdenTrabajoValidacionController().GetValidaciones(id))
            l.Add(new { ID = f.id, TIPO_ID = f.tipo_id, TIPO_CODIGO = f.tipo_codigo, TIPO = f.tipo_nombre, RESULTADO = f.resultado, FECHA = f.fecha.ToString("yyyy-MM-ddTHH:mm:ss"), OBSERVACION = f.observacion, QUIEN = f.usuario_nombre, FIRMA = f.archivo_firma.HasValue ? SitioBase.UrlArchivo.Ver(f.archivo_firma.Value) : null });
        return l;
    }

    private static object Permisos()
    {
        return new
        {
            crear = Token.Puede(P_CREAR),
            ejecutar = Token.Puede(P_EJECUTAR),
            cerrar = PuedeCerrar(),
            validar = Token.Puede(P_VALIDAR),
            reportar = Token.Puede(P_FALLA)
        };
    }

    /// <summary>
    /// La facultad «Cerrar» del perfil. Se pregunta a la base (la misma función que exigen los SP de
    /// cierre) porque Token.PuedeFuncion depende de la página en curso, y un servicio no es una página.
    /// </summary>
    private static bool PuedeCerrar()
    {
        Dictionary<string, object> r = SoporteDatos.Fila("SEL_OT_PUEDE_CERRAR", "@CLIENTE", Cli(), "@USUARIO", U());
        object v = Valor(r, "PUEDE");
        return v != null && (v is bool ? (bool)v : Convert.ToString(v) == "1");
    }

    /// <summary>La OT tiene que ser del cliente de la sesión (los SP también lo exigen).</summary>
    private static void Propia(int id)
    {
        if (SoporteDatos.Filas("SEL_ORDEN_TRABAJO", "@ID", id, "@CLIENTE", Cli()).Count == 0) throw new Exception("La orden de trabajo no existe.");
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
    private static string Q(int id) { return HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id)); }

    private static int IdDe(string token)
    {
        string plano = Tools.Crypto.Decrypt(HttpUtility.UrlDecode(token ?? ""));
        int id; if (!int.TryParse((plano ?? "").Split('=').Last(), out id)) throw new Exception("La orden de trabajo no existe.");
        return id;
    }

    private static object Valor(Dictionary<string, object> d, string k)
    {
        if (d == null) return null;
        foreach (KeyValuePair<string, object> kv in d)
            if (string.Equals(kv.Key, k, StringComparison.OrdinalIgnoreCase)) return kv.Value;
        return null;
    }

    private static int Entero(Dictionary<string, object> d, string k)
    {
        object v = Valor(d, k);
        if (v == null) return 0;
        if (v is bool) return (bool)v ? 1 : 0;
        decimal n;
        return decimal.TryParse(Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture), System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out n) ? (int)n : 0;
    }
}
