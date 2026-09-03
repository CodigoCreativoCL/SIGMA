using SitioBase;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// La ficha que el panel lateral muestra de cada registro.
///
/// POR QUÉ HACE FALTA IR AL SERVIDOR
///   El panel se armaba leyendo las celdas de la fila de la grilla, así que
///   solo podía repetir lo que ya estaba a la vista: abrirlo no aportaba nada
///   que no se leyera dos centímetros más a la izquierda.
///
/// EL ID VIAJA CIFRADO
///   El mismo token que la fila ya usa para abrir su ficha. El navegador no
///   cifra ni descifra: solo devuelve lo que el servidor le dio.
///
/// LA ENTIDAD VA CONTRA UNA LISTA BLANCA
///   La comprueba el procedimiento. Un nombre que no esté en ella devuelve
///   una ficha vacía, y no hay SQL dinámico por donde colar otra cosa.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsDetalle : System.Web.Services.WebService
{
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Ficha(string entidad, string token)
    {
        Dictionary<string, object> r = new Dictionary<string, object>();
        List<Dictionary<string, string>> filas = new List<Dictionary<string, string>>();

        try
        {
            if (!Token.TokenSeguridad())
                throw new Exception("La sesión no es válida.");

            int id = LeerId(token);

            if (id <= 0) throw new Exception("Registro no identificado.");

            SqlCommand cmd = Conexion.GetCommand("SEL_DETALLE_FICHA");
            cmd.Parameters.AddWithValue("@ENTIDAD", (entidad ?? "").ToUpper());
            cmd.Parameters.AddWithValue("@ID", id);

            /* El cliente sale de la SESIÓN, nunca del navegador: si viniera de
               afuera, cambiarlo en el POST mostraría la ficha de otra empresa.
               El SP igual filtra por él. */
            /* SitioBase.Session con nombre completo: dentro de un WebService,
               `Session` resuelve al HttpSessionState de ASP.NET, que no tiene
               ClienteId(). */
            cmd.Parameters.AddWithValue("@CLIENTE", SitioBase.Session.ClienteId());

            using (SqlDataReader dr = Conexion.GetDataReader(cmd))
            {
                while (dr.Read())
                {
                    Dictionary<string, string> f = new Dictionary<string, string>();
                    f["seccion"] = dr["SECCION"].ToString();
                    f["etiqueta"] = dr["ETIQUETA"].ToString();
                    f["valor"] = dr["VALOR"].ToString();
                    filas.Add(f);
                }
            }

            cmd.Connection.Close();
            cmd.Dispose();

            r["error"] = false;
        }
        catch (Exception ex)
        {
            r["error"] = true;
            r["detalle"] = ex.Message;
        }

        r["filas"] = filas;

        return new System.Web.Script.Serialization.JavaScriptSerializer().Serialize(r);
    }

    /// <summary>
    /// Saca el id del token cifrado.
    ///
    /// Las pantallas cifran distinto: unas mandan "Id=7" y otras lo llevan
    /// entre varios pares separados por ";". Se recorren todos en vez de
    /// asumir la posición.
    /// </summary>
    private static int LeerId(string token)
    {
        if (string.IsNullOrEmpty(token)) return 0;

        string plano;

        try { plano = Tools.Crypto.Decrypt(token); }
        catch (Exception) { return 0; }

        if (string.IsNullOrEmpty(plano)) return 0;

        foreach (string parte in plano.Split(';', '&'))
        {
            string[] kv = parte.Split('=');

            if (kv.Length != 2) continue;

            if (kv[0].Trim().ToLower() != "id") continue;

            int id;
            if (int.TryParse(kv[1].Trim(), out id)) return id;
        }

        return 0;
    }
}
