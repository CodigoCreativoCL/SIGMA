using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE LISTADO DE TAREA.
///
/// PATRON (ver PATRON_MVC.md seccion 7):
///  - La pagina es el UNICO lugar donde se valida el permiso de entrada.
///    Si el perfil no tiene la funcion "Ver" del menu, SecurityManagerVer
///    redirige y la pagina ni siquiera se renderiza.
///  - Ademas traduce los permisos del menu a propiedades del UserControl.
///  - Regla del equipo: la seguridad SIEMPRE se declara en el .aspx.cs,
///    nunca dentro del UserControl.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class View_Mantenimiento_Tareas_Tareas : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // El acceso a la pagina lo resuelve el master con Token.ExigirPagina().

        // Ruta de la ficha: la usan el boton Nuevo y el link Editar del grid.
        wucTareas.URLNuevoTarea = "~/View/Mantenimiento/Tareas/Tarea.aspx";

        // Sin el permiso de escritura, el listado se muestra sin la barra de
        // comandos (Nuevo / Deshabilitar): mismo criterio que el resto del sitio.
        wucTareas.ReadOnly = !Token.Puede("CREAR EDITAR TAREAS");
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Se deja declarado aunque este vacio: es parte del esqueleto estandar.
    }
}
