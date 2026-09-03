using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Endpoints AJAX de la ficha de programación.
///
/// PARA QUÉ
///   Las fechas de una programación por FECHA ÚNICA se agregan, corrigen y
///   quitan de a una. Cada una de esas es una microacción sobre una fila: no
///   justifica devolver la ficha entera al servidor y volver a dibujar los
///   seis pasos, y hacerlo se sentía lento sin motivo.
///
/// EL PERMISO SE VALIDA ACÁ Y OTRA VEZ ABAJO
///   Esconder el botón de borrar no es seguridad: quien arma el POST a mano
///   se lo salta. Cada método comprueba la función antes de tocar nada, y el
///   SP vuelve a comprobar que la fila sea del cliente de la sesión —una fila
///   sola no sabe de quién es—.
///
/// LOS IDS VIAJAN CIFRADOS
///   Igual que en los querystring del sitio. Un id de fila en claro dentro de
///   un POST invita a probar el de al lado.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsProgramacion : System.Web.Services.WebService
{
    private const string FUNCION = "Crear y editar";

    /// <summary>
    /// Las fechas de una programación, ya formateadas para pintar.
    ///
    /// El formato lo arma el servidor y no el navegador: la web y la app
    /// tienen que decir lo mismo, y "05-03-2026" contra "3/5/2026" es
    /// exactamente la clase de diferencia que hace dudar del dato.
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ListarFechas(string datos)
    {
        Respuesta respuesta = new Respuesta();
        List<Dictionary<string, object>> filas = new List<Dictionary<string, object>>();

        try
        {
            int programacion = IdDe(datos);

            ProgramacionController controller = new ProgramacionController();

            foreach (ProgramacionFecha f in controller.GetFechas(programacion))
                filas.Add(Fila(f));

            respuesta.error = false;
            respuesta.codigo = programacion;
        }
        catch (Exception ex)
        {
            respuesta.error = true;
            respuesta.detalle = ex.Message;
        }

        Dictionary<string, object> r = new Dictionary<string, object>();
        r["error"] = respuesta.error;
        r["detalle"] = respuesta.detalle;
        r["filas"] = filas;
        r["puedeEditar"] = Token.PuedeFuncion(FUNCION);

        return Json(r);
    }

    /// <summary>
    /// Agrega o corrige una fecha.
    ///
    /// Con id en 0 agrega; con id se corrige ESA fila. La diferencia importa:
    /// corregir con un borrar + insertar cambiaría el id, y el id es lo que
    /// cuelga la ocurrencia. "Corregí el día" se convertiría en "borré el
    /// trabajo del 5 y creé otro el 6".
    /// </summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarFecha(string datos, string token, string fecha, string hora)
    {
        Respuesta respuesta = new Respuesta();

        try
        {
            if (!Token.PuedeFuncion(FUNCION))
                throw new Exception("No tiene permiso para editar las fechas de la programación.");

            /* `datos` es la programación; `token` la fila que se corrige.
               Vacío significa alta, y entonces no hay fila que descifrar. */
            int programacion = IdDe(datos);
            int id = string.IsNullOrEmpty((token ?? "").Trim()) ? 0 : IdDe(token);

            DateTime dia;

            /* Formato fijo y cultura invariante: el navegador manda
               "dd-MM-yyyy" siempre. Dejarlo a la cultura del servidor haría
               que 05-03 fuera marzo o mayo según dónde esté desplegado. */
            if (!DateTime.TryParseExact((fecha ?? "").Trim(), "dd-MM-yyyy",
                                        CultureInfo.InvariantCulture,
                                        DateTimeStyles.None, out dia))
                throw new Exception("La fecha no es válida.");

            TimeSpan? h = null;

            if (!string.IsNullOrEmpty((hora ?? "").Trim()))
            {
                TimeSpan t;

                if (!TimeSpan.TryParseExact(hora.Trim(), @"hh\:mm",
                                            CultureInfo.InvariantCulture, out t))
                    throw new Exception("La hora no es válida.");

                h = t;
            }

            ProgramacionController controller = new ProgramacionController();

            ProgramacionFecha entidad = new ProgramacionFecha();
            entidad.pfe_id = id;
            entidad.pfe_programacion = programacion;
            entidad.pfe_fecha = dia;
            entidad.pfe_hora = h;
            entidad.pfe_incluida = true;

            respuesta = id > 0 ? controller.UpdateFecha(entidad)
                               : controller.InsertFecha(entidad);
        }
        catch (Exception ex)
        {
            respuesta.error = true;
            respuesta.detalle = ex.Message;
        }

        return Json(respuesta);
    }

    /// <summary>Quita una fecha.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EliminarFecha(string token)
    {
        Respuesta respuesta = new Respuesta();

        try
        {
            if (!Token.PuedeFuncion(FUNCION))
                throw new Exception("No tiene permiso para eliminar fechas de la programación.");

            respuesta = new ProgramacionController().DeleteFecha(IdDe(token));
        }
        catch (Exception ex)
        {
            respuesta.error = true;
            respuesta.detalle = ex.Message;
        }

        return Json(respuesta);
    }

    #region Auxiliares

    /// <summary>Un id suelto, cifrado como "Id=123".</summary>
    private static int IdDe(string datos)
    {
        string plano = Tools.Crypto.Decrypt(datos);
        return int.Parse(plano.Split('=')[1]);
    }

    private static Dictionary<string, object> Fila(ProgramacionFecha f)
    {
        Dictionary<string, object> d = new Dictionary<string, object>();

        d["id"] = f.pfe_id;
        d["fecha"] = f.pfe_fecha.ToString("dd-MM-yyyy");
        d["hora"] = f.pfe_hora != null ? f.pfe_hora.Value.ToString(@"hh\:mm") : "";

        /* El día de la semana se manda resuelto: es lo que deja ver de un
           vistazo que la "inspección de los lunes" cayó un domingo. */
        d["dia"] = CultureInfo.GetCultureInfo("es-CL")
                              .DateTimeFormat.GetDayName(f.pfe_fecha.DayOfWeek);

        d["pasada"] = f.pfe_fecha.Date < DateTime.Today;

        /* El token de la fila lo emite el SERVIDOR. El navegador no cifra:
           no puede, y no debe —una clave dentro del JS es una clave
           publicada—. Se le entrega ya cifrado y él solo lo devuelve. */
        d["token"] = Tools.Crypto.Encrypt("Id=" + f.pfe_id);

        return d;
    }

    private static string Json(object o)
    {
        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(o);
    }

    #endregion
}
