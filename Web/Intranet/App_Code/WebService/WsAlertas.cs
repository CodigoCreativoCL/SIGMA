using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Endpoints AJAX de alertas.
///
/// LO QUE PREGUNTA EL NAVEGADOR CADA TANTO: "¿hay algo nuevo?"
///
/// POR QUE ASMX Y NO UN HANDLER
///   Primero se hizo con un .ashx, que es exactamente lo que
///   PATRON_WEBSERVICE_AJAX.md prohíbe en su primera línea. El patrón del
///   proyecto es ASMX con [ScriptService], en dos archivos, y hay razones:
///   el ciclo de sesión, el envoltorio .d que el cliente ya sabe leer, y que
///   todo el resto del sitio se llama igual.
///
/// EL DETECTOR VIVE DETRAS DE ESTA LLAMADA
///   No en la carga de cada página: la cabecera se dibuja en TODAS las
///   pantallas y eso serían cientos de recorridos por minuto para encontrar
///   las mismas tres alertas. Acá el freno de la base decide si toca — casi
///   siempre contesta "todavía no" y solo cuenta filas.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsAlertas : System.Web.Services.WebService
{
    /// <summary>
    /// Los contadores, y de paso dispara el detector si al freno le toca.
    ///
    /// Devuelve también la alerta sin leer más urgente, para el aviso
    /// emergente. El navegador decide si lo muestra —solo cuando el contador
    /// subió desde la consulta anterior—: que lo decida el servidor obligaría
    /// a guardar por usuario qué fue lo último que vio, y eso ya lo sabe la
    /// pestaña que está abierta.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Resumen()
    {
        Dictionary<string, object> r = new Dictionary<string, object>();

        try
        {
            if (!Token.TokenSeguridad())
            {
                /* Sesión caída. Se dice con un dato y no con un error HTTP,
                   para que el JS deje de preguntar en silencio en vez de
                   llenar la consola mientras alguien tiene una pestaña
                   olvidada. */
                r["sesion"] = false;
                return Serializar(r);
            }

            AlertaController controller = new AlertaController();
            AlertaResumen resumen = controller.Detectar();

            r["sesion"] = true;
            r["abiertas"] = resumen.Abiertas;
            r["noLeidas"] = resumen.NoLeidas;
            r["menus"] = resumen.PorMenu;

            List<Alerta> urgentes = controller.GetAlertas(true, 1);

            if (urgentes.Count > 0 && !urgentes[0].LEIDA)
                r["nueva"] = Aviso(urgentes[0]);
        }
        catch (Exception ex)
        {
            /* Un contador que falla no puede romper la pantalla de nadie: se
               contesta el error y el sitio sigue con lo que tenía. */
            r["sesion"] = true;
            r["error"] = true;
            r["detalle"] = ex.Message;
        }

        return Serializar(r);
    }

    /// <summary>
    /// Marca una alerta como leída.
    ///
    /// El id viaja CIFRADO, como cualquier parámetro sensible del proyecto:
    /// sin eso, cualquiera podría marcar como vistas las alertas de otro
    /// desde la consola del navegador.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Leer(string datos)
    {
        Respuesta respuesta = new Respuesta();

        try
        {
            if (!Token.TokenSeguridad())
                throw new Exception("La sesión expiró.");

            string plano = Tools.Crypto.Decrypt(datos);

            AlertaController controller = new AlertaController();
            int marcadas = 0;

            /* Puede venir una o varias: al abrir el panel se marcan las que se
               mostraron, y son hasta diez. Una llamada por cada una serían
               diez viajes para lo que cabe en uno. */
            foreach (string parte in plano.Split(','))
            {
                int id;
                if (int.TryParse(parte.Trim(), out id) && id > 0)
                    marcadas += controller.Leer(id);
            }

            respuesta.error = false;
            respuesta.codigo = marcadas;
            respuesta.detalle = marcadas.ToString() + " marcada(s).";
        }
        catch (Exception ex)
        {
            respuesta.error = true;
            respuesta.detalle = ex.Message;
        }

        return Serializar(respuesta);
    }

    /// <summary>Lo que el aviso emergente necesita para dibujarse.</summary>
    private Dictionary<string, object> Aviso(Alerta a)
    {
        Dictionary<string, object> d = new Dictionary<string, object>();

        d["id"] = a.ale_id;
        d["tipo"] = a.alt_nombre;
        d["titulo"] = a.ale_titulo;
        d["detalle"] = a.ale_descripcion;
        d["severidad"] = a.sev_codigo;
        d["icono"] = IconoSigma(a.alt_codigo);

        /* El destino ya cifrado: el JS no tiene con qué cifrar, y mandarle el
           id en claro para que arme la URL abriría un camino sin la reja que
           tiene el resto del sitio. */
        if (!string.IsNullOrEmpty(a.FICHA_LINK) && a.FICHA_ID != null && a.FICHA_ID > 0)
        {
            d["ficha"] = VirtualPathUtility.ToAbsolute(a.FICHA_LINK);
            d["query"] = HttpContext.Current.Server.UrlEncode(
                             Tools.Crypto.Encrypt("Id=" + a.FICHA_ID.Value));
        }

        return d;
    }

    /// <summary>
    /// Qué ilustración de SIGMA le corresponde a cada tipo.
    ///
    /// NO TODO ES UNA PREDICCION
    ///   El icono de predicción es para lo que SALE DE UN MODELO. Un stock
    ///   bajo el mínimo es una resta contra un umbral que alguien escribió:
    ///   llamarlo predicción le atribuiría al sistema una inteligencia que no
    ///   usó, y el día que exista una predicción de verdad nadie la
    ///   distinguiría.
    ///
    ///   Lo de umbrales va con "realtime", que es lo que efectivamente es:
    ///   vigilancia continua de un valor.
    /// </summary>
    private string IconoSigma(string tipo)
    {
        switch (tipo)
        {
            case "PREDICCION RIESGO":
                return "sigma-ai-status-prediction.svg";

            case "STOCK MINIMO":
            case "STOCK MAXIMO":
            case "MEDICION FUERA RANGO":
            case "MEDIDOR SIN LECTURA":
            case "LOTE VENCIDO":
            case "LOTE POR VENCER":
                return "sigma-ai-status-realtime.svg";

            case "MEDIDOR PROXIMO MANTENIMIENTO":
                return "sigma-ai-status-recommendation.svg";
        }

        return "sigma-ai-status-analyzing.svg";
    }

    private string Serializar(object o)
    {
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(o);
    }
}
