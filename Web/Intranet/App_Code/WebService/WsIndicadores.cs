using OfficeOpenXml;
using OfficeOpenXml.Style;
using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Globalization;
using System.Linq;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Indicadores de gestión (EP-18, BD/474): tablero, detalle de cada indicador y costos por moneda.
/// El cliente sale de la sesión, nunca del navegador; la autorización la decide VER INDICADORES.
/// La exportación a Excel usa los MISMOS filtros que la pantalla y lleva el encabezado con cliente, período y filtros.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsIndicadores : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Filtros(int planta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_INDICADORES_FILTROS", "@CLIENTE", Cli(), "@INSTALACION", planta > 0 ? (object)planta : null);
            return new { areas = SoporteDatos.Del(c, 0), activos = SoporteDatos.Del(c, 1) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Tablero(int planta, int area, int activo, string desde, string hasta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_INDICADORES_TABLERO", "@CLIENTE", Cli(), "@INSTALACION", Nul(planta), "@AREA", Nul(area),
                "@ACTIVO", Nul(activo), "@DESDE", Fecha(desde), "@HASTA", Fecha(hasta));
            List<Dictionary<string, object>> k = SoporteDatos.Del(c, 0);
            return new { kpi = k.Count > 0 ? k[0] : null, peores = SoporteDatos.Del(c, 1) };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Detalle(string indicador, int planta, int area, int activo, string desde, string hasta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            return DetalleDatos(indicador, planta, area, activo, desde, hasta);
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Costos(int planta, int area, int activo, string desde, string hasta)
    {
        return Ejecutar(() =>
        {
            Exigir();
            return CostosDatos(planta, area, activo, desde, hasta);
        });
    }

    /// <summary>Excel del tablero, de un indicador o de los costos, con los filtros de la pantalla.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Exportar(string que, string indicador, int planta, int area, int activo, string desde, string hasta, string filtros)
    {
        return Ejecutar(() =>
        {
            Exigir();
            Color morado = ColorTranslator.FromHtml("#6732F4"), suave = ColorTranslator.FromHtml("#F2EFFF"), gris = ColorTranslator.FromHtml("#68738A");
            using (ExcelPackage x = new ExcelPackage())
            {
                string titulo = que == "costos" ? "Costos de mantenimiento" : que == "detalle" ? "Detalle · " + (indicador ?? "") : "Indicadores de mantenimiento";
                ExcelWorksheet h = x.Workbook.Worksheets.Add(que == "costos" ? "Costos" : que == "detalle" ? "Detalle" : "Indicadores");
                Encabezado(h, titulo, desde, hasta, filtros, morado, gris);
                int r = 6;
                if (que == "costos")
                {
                    dynamic o = CostosDatos(planta, area, activo, desde, hasta);
                    r = Tabla(h, r, "Por equipo", (List<Dictionary<string, object>>)o.equipos, new[] { "CODIGO", "ACTIVO", "MONEDA", "REPUESTOS", "MANO_OBRA", "SERVICIOS", "TOTAL", "ORDENES" },
                        new[] { "Código", "Equipo", "Moneda", "Repuestos", "Mano de obra", "Servicios", "Total", "Órdenes" }, suave);
                    r = Tabla(h, r + 1, "Por centro de costo (incluye sus dependientes)", (List<Dictionary<string, object>>)o.centros, new[] { "CODIGO", "CENTRO", "PADRE_CODIGO", "MONEDA", "PROPIO", "DEPENDIENTES", "TOTAL" },
                        new[] { "Código", "Centro de costo", "Depende de", "Moneda", "Propio", "Dependientes", "Total" }, suave);
                    r = Tabla(h, r + 1, "Comparación con el período anterior", (List<Dictionary<string, object>>)o.comparacion, new[] { "MONEDA", "TOTAL_ACT", "TOTAL_ANT", "VARIACION", "VARIACION_PCT" },
                        new[] { "Moneda", "Período actual", "Período anterior", "Variación", "Variación %" }, suave);
                }
                else if (que == "detalle")
                {
                    dynamic o = DetalleDatos(indicador, planta, area, activo, desde, hasta);
                    List<Dictionary<string, object>> filas = (List<Dictionary<string, object>>)o.filas;
                    string[] cols = filas.Count > 0 ? filas[0].Keys.Where(k => k != "Q" && k != "QOT").ToArray() : new string[0];
                    Tabla(h, r, "Registros que componen el indicador", filas, cols, cols, suave);
                }
                else
                {
                    List<Dictionary<string, object>> k = new List<Dictionary<string, object>>();
                    List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_INDICADORES_TABLERO", "@CLIENTE", Cli(), "@INSTALACION", Nul(planta), "@AREA", Nul(area), "@ACTIVO", Nul(activo), "@DESDE", Fecha(desde), "@HASTA", Fecha(hasta));
                    Dictionary<string, object> f = SoporteDatos.Del(c, 0).FirstOrDefault() ?? new Dictionary<string, object>();
                    Func<string, object> g = n => f.ContainsKey(n) ? f[n] : null;
                    k.Add(Ind("Cumplimiento del plan (%)", g("CUMPL_ACT"), g("CUMPL_ANT")));
                    k.Add(Ind("Disponibilidad (%)", g("DISP_ACT"), g("DISP_ANT")));
                    k.Add(Ind("Tiempo medio entre fallas (h)", g("MTBF_H_ACT"), g("MTBF_H_ANT")));
                    k.Add(Ind("Tiempo medio de reparación (min)", g("MTTR_MIN_ACT"), g("MTTR_MIN_ANT")));
                    k.Add(Ind("Órdenes pendientes de cierre", g("PEND_ACT"), g("PEND_ANT")));
                    k.Add(Ind("Fallas del período", g("FALLAS_ACT"), g("FALLAS_ANT")));
                    r = Tabla(h, r, "Indicadores y su variación", k, new[] { "INDICADOR", "ACTUAL", "ANTERIOR", "VARIACION" }, new[] { "Indicador", "Período actual", "Período anterior", "Variación" }, suave);
                    Tabla(h, r + 1, "Equipos con más trabajo vencido sin hacer", SoporteDatos.Del(c, 1), new[] { "CODIGO", "NOMBRE", "VENCIDAS", "HECHAS" }, new[] { "Código", "Equipo", "Vencidas", "Hechas" }, suave);
                }
                h.Cells[h.Dimension.Address].AutoFitColumns(12, 60);
                string nombre = "SIGMA_" + (que == "costos" ? "Costos" : que == "detalle" ? "Detalle_" + (indicador ?? "") : "Indicadores") + "_" + DateTime.Now.ToString("yyyyMMdd") + ".xlsx";
                return new { nombre = nombre, base64 = Convert.ToBase64String(x.GetAsByteArray()) };
            }
        });
    }

    // ------------------------------------------------------------------ datos
    private static object DetalleDatos(string indicador, int planta, int area, int activo, string desde, string hasta)
    {
        string ind = (indicador ?? "").ToUpperInvariant();
        if (new[] { "CUMPLIMIENTO", "DISPONIBILIDAD", "MTBF", "MTTR", "PENDIENTES" }.All(x => x != ind)) throw new Exception("Indicador desconocido.");
        List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_INDICADOR_DETALLE", "@CLIENTE", Cli(), "@INDICADOR", ind, "@INSTALACION", Nul(planta), "@AREA", Nul(area),
            "@ACTIVO", Nul(activo), "@DESDE", Fecha(desde), "@HASTA", Fecha(hasta));
        List<Dictionary<string, object>> filas = SoporteDatos.Del(c, 0);
        foreach (Dictionary<string, object> f in filas)
            if (f.ContainsKey("OT_ID") && f["OT_ID"] != null) f["QOT"] = Q(Convert.ToInt32(f["OT_ID"]));
        return new { indicador = ind, filas = filas, porEquipo = SoporteDatos.Del(c, 1), urlOt = System.Web.VirtualPathUtility.ToAbsolute("~/View/Mantenimiento/Ordenes/Ordenes.aspx") };
    }

    private static object CostosDatos(int planta, int area, int activo, string desde, string hasta)
    {
        List<List<Dictionary<string, object>>> c = SoporteDatos.Conjuntos("SEL_INDICADORES_COSTOS", "@CLIENTE", Cli(), "@INSTALACION", Nul(planta), "@AREA", Nul(area),
            "@ACTIVO", Nul(activo), "@DESDE", Fecha(desde), "@HASTA", Fecha(hasta));
        return new { equipos = SoporteDatos.Del(c, 0), centros = SoporteDatos.Del(c, 1), comparacion = SoporteDatos.Del(c, 2) };
    }

    // ------------------------------------------------------------------ Excel
    private static void Encabezado(ExcelWorksheet h, string titulo, string desde, string hasta, string filtros, Color morado, Color gris)
    {
        h.Cells["A1"].Value = "SIGMA · " + titulo;
        h.Cells["A1"].Style.Font.Size = 16; h.Cells["A1"].Style.Font.Bold = true; h.Cells["A1"].Style.Font.Color.SetColor(morado);
        h.Cells["A2"].Value = "Cliente: " + SitioBase.Session.ClienteNombre();
        h.Cells["A3"].Value = "Período: " + FechaTexto(desde) + " al " + FechaTexto(hasta);
        h.Cells["A4"].Value = "Filtros: " + (string.IsNullOrWhiteSpace(filtros) ? "ninguno" : filtros);
        h.Cells["A2:A4"].Style.Font.Color.SetColor(gris);
    }

    private static int Tabla(ExcelWorksheet h, int fila, string titulo, List<Dictionary<string, object>> filas, string[] claves, string[] cabeceras, Color suave)
    {
        h.Cells[fila, 1].Value = titulo; h.Cells[fila, 1].Style.Font.Bold = true; h.Cells[fila, 1].Style.Font.Size = 12;
        fila++;
        for (int i = 0; i < cabeceras.Length; i++)
        {
            ExcelRange c = h.Cells[fila, i + 1];
            c.Value = cabeceras[i]; c.Style.Font.Bold = true; c.Style.Fill.PatternType = ExcelFillStyle.Solid; c.Style.Fill.BackgroundColor.SetColor(suave);
        }
        fila++;
        if (filas.Count == 0) { h.Cells[fila, 1].Value = "Sin datos en el período."; return fila + 1; }
        foreach (Dictionary<string, object> f in filas)
        {
            for (int i = 0; i < claves.Length; i++)
            {
                object v = f.ContainsKey(claves[i]) ? f[claves[i]] : null;
                DateTime d;
                if (v is string && DateTime.TryParseExact((string)v, "yyyy-MM-ddTHH:mm:ss", CultureInfo.InvariantCulture, DateTimeStyles.None, out d)) { h.Cells[fila, i + 1].Value = d; h.Cells[fila, i + 1].Style.Numberformat.Format = "dd-mm-yyyy hh:mm"; }
                else h.Cells[fila, i + 1].Value = v;
            }
            fila++;
        }
        return fila;
    }

    private static Dictionary<string, object> Ind(string nombre, object act, object ant)
    {
        double a, b;
        object var = null;
        if (act != null && ant != null && double.TryParse(Convert.ToString(act, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out a) && double.TryParse(Convert.ToString(ant, CultureInfo.InvariantCulture), NumberStyles.Any, CultureInfo.InvariantCulture, out b))
            var = Math.Round(a - b, 2);
        return new Dictionary<string, object> { { "INDICADOR", nombre }, { "ACTUAL", act }, { "ANTERIOR", ant }, { "VARIACION", var } };
    }

    // ------------------------------------------------------------------ comunes
    private static object Nul(int v) { return v > 0 ? (object)v : null; }

    private static object Fecha(string s)
    {
        DateTime d;
        return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? (object)d : null;
    }

    private static string FechaTexto(string s)
    {
        DateTime d;
        return DateTime.TryParseExact(s ?? "", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out d) ? d.ToString("dd-MM-yyyy") : "—";
    }

    private static void Exigir()
    {
        if (!Token.Puede("VER INDICADORES")) throw new Exception("No tienes permiso para ver los indicadores.");
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
    private static string Q(int id) { return System.Web.HttpUtility.UrlEncode(Tools.Crypto.Encrypt("Id=" + id)); }
}
