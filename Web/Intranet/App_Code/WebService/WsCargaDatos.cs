using SitioBase;
using SitioBase.Controller;
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;

/// <summary>
/// Centro de carga de datos: todo por aqui, sin postback. Cada metodo exige
/// GESTIONAR CARGAS MASIVAS (Administrador del Cliente, o el usuario al que se
/// lo delego).
/// </summary>
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
[System.ComponentModel.ToolboxItem(false)]
[ScriptService]
public class WsCargaDatos : System.Web.Services.WebService
{
    /// <summary>La carga de INVENTARIO se abre tambien desde el Centro de repuestos.</summary>
    private const string PERMISO_REPUESTOS = "CREAR EDITAR REPUESTOS";

    /// <summary>Los modulos con sus hojas y columnas, lo que ya tiene cada uno y la ultima carga.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Inicio()
    {
        return Ejecutar(() =>
        {
            CargaMasivaController c = new CargaMasivaController();
            DataTable res = c.ResumenModulos(), hist = c.Historial();
            var modulos = CargaMasivaController.Modulos().Select(m => new
            {
                m.clave, m.nombre, m.descripcion, m.icono, m.color, m.disponible,
                hojas = m.hojas.Select(h => new
                {
                    h.clave, h.titulo, h.descripcion, h.icono,
                    columnas = h.columnas.Select(k => new { k.titulo, k.obligatoria, k.ayuda })
                }),
                datos = res.Rows.Cast<DataRow>().Where(r => Convert.ToString(r["MODULO"]) == m.clave)
                           .Select(r => new { dato = Convert.ToString(r["DATO"]), cantidad = Convert.ToInt32(r["CANTIDAD"]) }),
                ultima = hist.Rows.Cast<DataRow>().Where(r => Convert.ToString(r["MODULO"]) == m.clave).Select(Fila).FirstOrDefault()
            }).ToList();
            object enCurso = hist.Rows.Cast<DataRow>().Where(r => Convert.ToString(r["ESTADO"]) == "LEYENDO" || Convert.ToString(r["ESTADO"]) == "EN_COLA" || Convert.ToString(r["ESTADO"]) == "PROCESANDO")
                                .Select(r => (object)Convert.ToInt32(r["ID"])).FirstOrDefault();
            return new { error = false, modulos, historial = hist.Rows.Cast<DataRow>().Select(Fila), enCurso };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Plantilla(string modulo)
    {
        return Ejecutar(() =>
        {
            ExigirModulo(modulo);
            CargaMasivaController.Modulo m = CargaMasivaController.Buscar(modulo);
            byte[] b = new CargaMasivaController().Plantilla(modulo);
            return new { error = false, nombre = "SIGMA carga de datos - " + (m != null ? m.nombre : modulo) + ".xlsx", base64 = Convert.ToBase64String(b) };
        });
    }

    /// <summary>Sube la planilla y deja el proceso en segundo plano. modo: VALIDAR | CARGAR.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Iniciar(string modulo, string nombre, string base64, string modo, string existentes)
    {
        return Ejecutar(() =>
        {
            ExigirModulo(modulo);
            byte[] archivo = Convert.FromBase64String(base64 ?? "");
            CargaMasivaController.Inicio i = new CargaMasivaController().Iniciar(modulo, nombre, archivo, (modo ?? "").ToUpperInvariant(), (existentes ?? "").ToUpperInvariant());
            return new { error = false, id = i.id, hojas = i.porHoja, avisos = i.avisos };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string CargarRevision(int id, string existentes)
    {
        return Ejecutar(() => new { error = false, id = new CargaMasivaController().CargarRevision(id, (existentes ?? "").ToUpperInvariant()) });
    }

    /// <summary>El avance: lo consulta la pantalla cada segundo mientras corre.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Estado(int id)
    {
        return Ejecutar(() =>
        {
            DataSet ds = new CargaMasivaController().EstadoCompleto(id);
            if (ds.Tables.Count == 0 || ds.Tables[0].Rows.Count == 0) throw new Exception("La carga no existe.");
            DataRow r = ds.Tables[0].Rows[0];
            var hojas = ds.Tables.Count > 1 ? ds.Tables[1].Rows.Cast<DataRow>().Select(h => new
            {
                hoja = Convert.ToString(h["HOJA"]), filas = Convert.ToInt32(h["FILAS"]), creadas = Convert.ToInt32(h["CREADAS"]),
                actualizadas = Convert.ToInt32(h["ACTUALIZADAS"]), omitidas = Convert.ToInt32(h["OMITIDAS"]), errores = Convert.ToInt32(h["ERRORES"])
            }).ToList() : null;
            return new
            {
                error = false,
                carga = new
                {
                    id = Convert.ToInt32(r["ID"]), modulo = Convert.ToString(r["MODULO"]), archivo = Convert.ToString(r["ARCHIVO"]),
                    modo = Convert.ToString(r["MODO"]), existentes = Convert.ToString(r["EXISTENTES"]), estado = Convert.ToString(r["ESTADO"]),
                    fase = Convert.ToString(r["FASE"]), total = Convert.ToInt32(r["TOTAL"]), procesadas = Convert.ToInt32(r["PROCESADAS"]),
                    creadas = Convert.ToInt32(r["CREADAS"]), actualizadas = Convert.ToInt32(r["ACTUALIZADAS"]), omitidas = Convert.ToInt32(r["OMITIDAS"]),
                    errores = Convert.ToInt32(r["ERRORES"]), segundos = Convert.ToInt32(r["SEGUNDOS"]), mensaje = Convert.ToString(r["MENSAJE"]),
                    usuario = Convert.ToString(r["USUARIO"]), inicio = Fecha(r["INICIO"])
                },
                hojas
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Errores(int id)
    {
        return Ejecutar(() =>
        {
            DataTable e = new CargaMasivaController().Errores(id);
            return new
            {
                error = false,
                total = e.Rows.Count,
                errores = e.Rows.Cast<DataRow>().Take(1000).Select(r => new
                {
                    hoja = Convert.ToString(r["HOJA"]), fila = Convert.ToInt32(r["FILA"]), columna = Convert.ToString(r["COLUMNA"]),
                    valor = Convert.ToString(r["VALOR"]), mensaje = Convert.ToString(r["MENSAJE"])
                })
            };
        });
    }

    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string ErroresExcel(int id)
    {
        return Ejecutar(() => new { error = false, nombre = "SIGMA errores carga " + id + ".xlsx", base64 = Convert.ToBase64String(new CargaMasivaController().ErroresExcel(id)) });
    }

    /// <summary>"Alertar un problema": lo que vio quien cargaba, con el contexto del momento.</summary>
    [WebMethod(EnableSession = true)]
    [ScriptMethod(ResponseFormat = ResponseFormat.Json)]
    public string Incidencia(int carga, string comentario, string contexto)
    {
        return Ejecutar(() =>
        {
            Respuesta r = new CargaMasivaController().Incidencia(carga, comentario, contexto);
            return new { error = r.error, detalle = r.detalle, id = r.codigo };
        });
    }

    // ------------------------------------------------------------------ apoyo
    private static object Fila(DataRow r)
    {
        return new
        {
            id = Convert.ToInt32(r["ID"]), modulo = Convert.ToString(r["MODULO"]), archivo = Convert.ToString(r["ARCHIVO"]),
            modo = Convert.ToString(r["MODO"]), estado = Convert.ToString(r["ESTADO"]), total = Convert.ToInt32(r["TOTAL"]),
            creadas = Convert.ToInt32(r["CREADAS"]), actualizadas = Convert.ToInt32(r["ACTUALIZADAS"]), omitidas = Convert.ToInt32(r["OMITIDAS"]),
            errores = Convert.ToInt32(r["ERRORES"]), inicio = Fecha(r["INICIO"]), segundos = Convert.ToInt32(r["SEGUNDOS"]),
            usuario = Convert.ToString(r["USUARIO"])
        };
    }

    private static string Fecha(object v)
    {
        return v == null || v == DBNull.Value ? "" : Convert.ToDateTime(v).ToString("dd-MM-yyyy HH:mm", CultureInfo.InvariantCulture);
    }

    private static string Ejecutar(Func<object> accion)
    {
        try
        {
            if (!Token.TokenSeguridad())
                return Json(new { error = true, sesion = true, detalle = "La sesión expiró. Vuelve a entrar." });
            /* La carga de ACTIVOS tambien la usa quien crea activos (se abre
               desde el Centro de activos); las demas exigen el permiso de cargas. */
            if (!Token.Puede(CargaMasivaController.PERMISO) && !Token.Puede("CREAR EDITAR ACTIVOS") && !Token.Puede(PERMISO_REPUESTOS))
                return Json(new { error = true, sinPermiso = true, detalle = "No tienes permiso para cargar datos. Pídeselo al administrador de tu empresa." });
            return Json(accion());
        }
        catch (Exception ex)
        {
            return Json(new { error = true, detalle = ex.Message });
        }
    }

    /// <summary>Sin el permiso de cargas: ACTIVOS para quien crea activos e INVENTARIO para quien crea repuestos.</summary>
    private static void ExigirModulo(string modulo)
    {
        if (Token.Puede(CargaMasivaController.PERMISO)) return;
        if (string.Equals(modulo, "ACTIVOS", StringComparison.OrdinalIgnoreCase) && Token.Puede("CREAR EDITAR ACTIVOS")) return;
        if (string.Equals(modulo, "INVENTARIO", StringComparison.OrdinalIgnoreCase) && Token.Puede(PERMISO_REPUESTOS)) return;
        throw new Exception("No tienes permiso para cargar datos de ese módulo.");
    }

    private static string Json(object o)
    {
        JavaScriptSerializer js = new JavaScriptSerializer();
        js.MaxJsonLength = int.MaxValue;
        return js.Serialize(o);
    }
}
