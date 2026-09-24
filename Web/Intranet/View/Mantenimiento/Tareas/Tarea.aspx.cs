using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE FORMULARIO DE TAREA.
///
/// Hace exactamente dos cosas:
///   1. Valida el permiso de entrada (igual que la pagina de listado).
///   2. DESCIFRA el querystring que armo el grid y pasa los valores al UserControl.
///
/// Por que se cifra el querystring?
///   Si la URL fuera Tarea.aspx?IdTarea=5, cualquiera podria escribir
///   otro numero y abrir la ficha ajena. Con Tools.Crypto el parametro es opaco.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Mantenimiento_Tareas_Tarea : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // El acceso a la pagina lo resuelve el master con Token.ExigirPagina().

        if (!IsPostBack)
        {
            // El grid navega a: Tarea.aspx?query=<cadena cifrada>
            if (!string.IsNullOrEmpty(Request.QueryString["query"]))
            {
                // 1. Descifrar -> "IdTarea=5&ReadOnly=False"
                string parametros = Tools.Crypto.Decrypt(Request.QueryString["query"]);

                // 2. Parsear el string en pares clave=valor.
                foreach (string par in parametros.Split('&'))
                {
                    string[] kv = par.Split('=');
                    if (kv.Length != 2) continue;

                    switch (kv[0])
                    {
                        case "IdTarea":
                            int id;
                            if (int.TryParse(kv[1], out id))
                                wucTarea.IdTarea = id;
                            break;

                        case "ReadOnly":
                            bool ro;
                            if (bool.TryParse(kv[1], out ro))
                                wucTarea.ReadOnly = ro;
                            break;
                    }
                }
            }

            // Sin query -> alta de un registro nuevo (IdTarea queda en 0).

            // Refuerzo de seguridad: si el perfil no tiene el permiso de
            // escritura, el formulario se abre siempre en modo consulta.
            if (!Token.Puede("CREAR EDITAR TAREAS"))
                wucTarea.ReadOnly = true;
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
    }
}
