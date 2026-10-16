using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// «Mi suscripción» (P6 del Centro Comercial, prompt V2): lo que el administrador del cliente ve de su
/// propia suscripción, dentro de SIGMA. Estado del cobro, uso contra los topes, historial, pagar con
/// Webpay e informar una transferencia.
///
/// ALCANCE: SIEMPRE EL CLIENTE EN SESIÓN
///   Ningún método recibe el id del cliente: se toma de la sesión. Informar un pago comprueba además que
///   el período sea de ese cliente. Quien tenga la facultad DECLARAR PAGO SUSCRIPCION puede informar;
///   no se pregunta por un rol fijo.
///
/// NO SE BLOQUEA CON LA SUSCRIPCIÓN CAÍDA
///   Es la pantalla que sigue abierta cuando el acceso se corta: el servicio responde igual, porque
///   bloquear sin dejar adónde ir encerraría al cliente (ver SuscripcionAcceso.EXENTAS).
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsMiSuscripcion : System.Web.Services.WebService
{
    private const string P_DECLARAR = "DECLARAR PAGO SUSCRIPCION";

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Estado()
    {
        return Ejecutar(() => Ficha());
    }

    private static object Ficha()
    {
        int cliente = SitioBase.Session.ClienteId();
        if (cliente <= 0) throw new Exception("Elige un cliente para ver su suscripción.");
        SitioBase.Model.Suscripcion s = new SuscripcionController().GetSuscripcion(new SitioBase.Model.Suscripcion { sus_cliente = cliente });
        if (s == null || s.sus_id == 0) return new { sinSuscripcion = true, cliente = SitioBase.Session.ClienteNombre() };
        Cobros.Estado e = Cobros.Leer(s.sus_id);
        bool usd = e.EsUsd;
        Dictionary<string, object> c = SoporteDatos.Filas("SEL_COBRO_ESTADO_SUSCRIPCION").FirstOrDefault(x => Convert.ToInt32(x["ID"]) == s.sus_id) ?? new Dictionary<string, object>();
        bool mora = c.ContainsKey("EN_MORA") && Convert.ToInt32(c["EN_MORA"]) == 1;
        string estado = !s.puede_operar || mora ? "mora" : e.Pendientes.Count > 0 ? "pendiente" : "aldia";
        string enlace = null;
        if (e.Pendientes.Count > 0) { try { enlace = Cobros.EnlacePago(s.sus_id); } catch (Exception) { } }
        return new
        {
            estado = estado, moneda = usd ? "USD" : "CLP", cliente = SitioBase.Session.ClienteNombre(),
            suscripcion = new { id = s.sus_id, plan = s.plc_nombre, estado = s.estado, opera = s.puede_operar, hasta = s.sus_fecha_fin.HasValue ? s.sus_fecha_fin.Value.ToString("yyyy-MM-dd") : null, dias = s.dias_restantes, gracia = s.sus_dias_gracia },
            total = e.Total, totalTexto = Cobros.Monto(e.Total, usd),
            pendientes = e.Pendientes.Select(p => new { id = p["ID"], nombre = Cobros.Periodo(p), desde = p["DESDE"], hasta = p["HASTA"], @base = Cobros.Base(p["UF"], usd), saldo = Cobros.Monto(p["SALDO"], usd), saldoNum = p["SALDO"] }).ToList(),
            informado = e.PorVerificarN > 0 ? Cobros.Monto(e.PorVerificarMonto, usd) : null,
            consumo = SoporteDatos.Filas("SEL_COBRO_CONSUMO", "@CLIENTE", cliente),
            periodos = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@CLIENTE", cliente)).Take(12).ToList(),
            pagos = Limpia(SoporteDatos.Filas("SEL_SUSCRIPCION_PAGO", "@CLIENTE", cliente)).Take(12).ToList(),
            datos = Cobros.DatosTransferencia(usd).Select(d => new { k = d.Key, v = d.Value }).ToList(),
            referencia = e.Pendientes.Count > 0 ? Cobros.Referencia(e) : "",
            pagarAhora = usd ? null : enlace, prueba = !usd && Webpay.EsPrueba(),
            ejecutivo = Comercial.Txt(e.Cabecera, "EJECUTIVO"), ejecutivoCorreo = Comercial.Txt(e.Cabecera, "EJECUTIVO_CORREO"),
            permisos = new { declarar = Token.Puede(P_DECLARAR) }
        };
    }

    /// <summary>Informar una transferencia de este cliente, con su comprobante. Queda por verificar.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string InformarPago(int periodo, string monto, string fecha, string banco, string operacion, string archivoNombre, string archivoMime, string archivoBase64)
    {
        return Ejecutar(() =>
        {
            if (!Token.Puede(P_DECLARAR)) throw new Exception("No tienes la facultad para informar pagos.");
            int cliente = SitioBase.Session.ClienteId();
            Dictionary<string, object> per = SoporteDatos.Filas("SEL_SUSCRIPCION_PERIODO", "@ID", periodo).FirstOrDefault();
            // El período tiene que ser de ESTE cliente: el id solo identifica, no autoriza.
            if (per == null || Convert.ToInt32(per["SUS_CLIENTE"]) != cliente) throw new Exception("El período no existe.");
            decimal m = ParseMonto(monto);
            if (m <= 0) throw new Exception("El monto transferido debe ser mayor que cero.");
            DateTime f;
            if (!DateTime.TryParseExact((fecha ?? "").Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out f)) throw new Exception("Elige la fecha de la transferencia.");
            if (f.Date > Hora.Hoy.Date) throw new Exception("La fecha de la transferencia no puede ser futura.");
            if (string.IsNullOrEmpty(archivoBase64)) throw new Exception("Debes adjuntar el comprobante de la transferencia.");
            byte[] bytes = Convert.FromBase64String(archivoBase64);
            if (bytes.Length == 0 || bytes.Length > 8 * 1024 * 1024) throw new Exception("El comprobante debe pesar entre 1 byte y 8 MB.");

            ArchivoController archivos = new ArchivoController();
            SitioBase.Model.Archivo a = new SitioBase.Model.Archivo
            {
                arc_cliente = cliente, arc_archivo_categoria = ArchivoController.CATEGORIA_COMPROBANTE_PAGO,
                arc_nombre_original = System.IO.Path.GetFileName(string.IsNullOrEmpty(archivoNombre) ? "comprobante" : archivoNombre),
                arc_mime = string.IsNullOrEmpty(archivoMime) ? "application/octet-stream" : archivoMime, contenido = bytes
            };
            Respuesta subida = archivos.InsertArchivo(a, "comprobantes");
            if (subida.error || subida.codigo <= 0) throw new Exception("No se pudo guardar el comprobante: " + subida.detalle);
            try
            {
                Cobros.SpSalida("INS_SUSCRIPCION_PAGO", "@ID", "@PERIODO", periodo, "@MONTO_DECLARADO", m, "@FECHA_TRANSFERENCIA", f.Date,
                    "@BANCO", string.IsNullOrWhiteSpace(banco) ? null : banco.Trim(), "@NUMERO_OPERACION", string.IsNullOrWhiteSpace(operacion) ? null : operacion.Trim(),
                    "@ARCHIVO", subida.codigo, "@USUARIO", SoporteDatos.Usuario());
            }
            catch (Exception)
            {
                archivos.DeleteArchivo(new SitioBase.Model.Archivo { arc_id = subida.codigo });
                throw;
            }
            return new { mensaje = "Pago informado. Lo verificaremos contra nuestra cartola y te avisaremos por correo.", ficha = Ficha() };
        });
    }

    private static decimal ParseMonto(string s)
    {
        s = (s ?? "").Trim().Replace(" ", "").Replace("$", "");
        if (s.IndexOf(',') >= 0) s = s.Replace(".", "").Replace(",", ".");
        else if (System.Text.RegularExpressions.Regex.IsMatch(s, @"^\d{1,3}(\.\d{3})+$")) s = s.Replace(".", "");
        decimal v;
        if (!decimal.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out v)) throw new Exception("El monto no es un número válido.");
        return v;
    }

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
}
