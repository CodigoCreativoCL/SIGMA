using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Centro de repuestos: lo que se crea y edita en la misma pestaña, sin modal
/// (los tipos de repuesto). Las bodegas y sus ubicaciones usan WsBodegaMapa,
/// que ya tiene su propio juego de permisos.
///
/// Pasa por los mismos controllers y SP de siempre (RepuestoTipoController):
/// lo que se puede hacer aqui es exactamente lo que permite RepuestoTipo.aspx.
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsRepuestoCentro : System.Web.Services.WebService
{
    private const string PERMISO = "CREAR EDITAR REPUESTOS";
    private const string TABLA = "Repuesto_Tipo";

    /// <summary>Crea o edita un tipo de repuesto. datos: {id, codigo?, nombre, descripcion, orden}.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string GuardarTipo(string datos)
    {
        return Ejecutar(() =>
        {
            var d = Leer(datos);
            RepuestoTipo t = new RepuestoTipo
            {
                rti_id = Entero(d, "id"),
                rti_codigo = CodigoModulo.Componer(TABLA, Texto(d, "codigo")),
                rti_nombre = Texto(d, "nombre"),
                rti_descripcion = Texto(d, "descripcion"),
                rti_orden = Entero(d, "orden"),
                rti_habilitado = true
            };
            if (string.IsNullOrEmpty(t.rti_nombre)) throw new Exception("Indique el nombre del tipo.");

            RepuestoTipoController c = new RepuestoTipoController();
            if (t.rti_id > 0)
            {
                /* El codigo no se cambia al editar: va en etiquetas y cargas. */
                RepuestoTipo actual = null;
                List<RepuestoTipo> todos = c.GetRepuestoTipos(new RepuestoTipo());
                if (todos != null) actual = todos.Find(x => x.rti_id == t.rti_id);
                if (actual != null) t.rti_codigo = actual.rti_codigo;
            }
            Respuesta r = t.rti_id > 0 ? c.UpdateRepuestoTipo(t) : c.InsertRepuestoTipo(t);
            return new { error = r.error, detalle = r.detalle, id = t.rti_id > 0 ? t.rti_id : r.codigo };
        });
    }

    /// <summary>Quita un tipo (el SP no deja si tiene repuestos asignados).</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string EliminarTipo(int id)
    {
        return Ejecutar(() =>
        {
            Respuesta r = new RepuestoTipoController().DeleteRepuestoTipo(id);
            return new { error = r.error, detalle = r.detalle, id = id };
        });
    }

    // ---------------------------------------------------------------- utilidades

    private static string Ejecutar(Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            if (!Token.Puede(PERMISO))
                return Json(new { error = true, sinPermiso = true, detalle = "No tienes permiso para esta acción." });
            return Json(accion());
        }
        catch (Exception ex)
        {
            return Json(new { error = true, detalle = ex.Message });
        }
    }

    private static Dictionary<string, object> Leer(string datos)
    {
        return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(string.IsNullOrEmpty(datos) ? "{}" : datos)
               ?? new Dictionary<string, object>();
    }
    private static string Texto(Dictionary<string, object> d, string k)
    {
        object v; return d.TryGetValue(k, out v) && v != null ? Convert.ToString(v).Trim() : "";
    }
    private static int Entero(Dictionary<string, object> d, string k)
    {
        int n; return int.TryParse(Texto(d, k), out n) ? n : 0;
    }
    private static string Json(object o)
    {
        JavaScriptSerializer js = new JavaScriptSerializer();
        js.MaxJsonLength = int.MaxValue;
        return js.Serialize(o);
    }
}
