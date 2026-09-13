using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;

/// <summary>
/// Carga masiva de planes de mantenimiento completos (plan + hitos + equipos).
///
/// La logica vive en PlanMantenimientoCargaController: aqui solo se recibe el
/// archivo, se valida el permiso y se muestra el resultado. Reusa los mismos
/// INS que las fichas, asi que lo que se puede crear a mano es exactamente lo
/// que se puede cargar en masa.
/// </summary>
public partial class View_Mantenimiento_Planes_CargaMasivaPlanes : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        if (!IsPostBack) Bloqueo();
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        /* Los dos escriben directo en la respuesta —uno un archivo, el otro
           necesita el FileUpload— y eso no sobrevive a un postback asíncrono:
           el UpdatePanel espera un fragmento y recibe un binario. */
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnPlantilla);
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnCargar);
    }

    protected void Bloqueo()
    {
        bool puede = Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO");

        btnCargar.Visible = puede;
        fldArchivo.Enabled = puede;

        if (!puede)
            Tools.tools.ClientAlert("No tiene permiso para crear planes de mantenimiento.", "alerta");
    }

    protected void btnPlantilla_Click(object sender, EventArgs e)
    {
        try
        {
            new PlanMantenimientoCargaController().Plantilla();
        }
        catch (System.Threading.ThreadAbortException)
        {
            /* Response.End() la lanza siempre: es cómo termina una descarga,
               no un fallo. Se deja pasar para que no llegue al catch de abajo
               y muestre una alerta sobre un archivo que sí se envió. */
            throw;
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }

    protected void btnCargar_Click(object sender, EventArgs e)
    {
        try
        {
            if (!Token.Puede("CREAR EDITAR PLANES MANTENIMIENTO"))
                throw new Exception("No tiene permiso para crear planes de mantenimiento.");

            if (!fldArchivo.HasFile)
                throw new Exception("Adjunte la planilla que quiere cargar.");

            if (!fldArchivo.FileName.ToLower().EndsWith(".xlsx"))
                throw new Exception("El archivo tiene que ser .xlsx. " +
                                    "Si lo guardó como .xls o .csv, vuelva a guardarlo " +
                                    "como libro de Excel.");

            DateTime inicio = DateTime.Now;

            Respuesta respuesta = new PlanMantenimientoCargaController().Cargar(fldArchivo.FileBytes);

            TimeSpan duro = DateTime.Now - inicio;

            /* Si no leyó ni una fila, no hay resultado que mostrar: es un
               problema con el archivo, no con su contenido. */
            if (respuesta.cantidaCargada == 0 && respuesta.cantidaError == 0)
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
                return;
            }

            pnlResultado.Visible = true;

            litCargados.Text = respuesta.cantidaCargada.ToString();
            litFallidos.Text = respuesta.cantidaError.ToString();
            litDuracion.Text = duro.Minutes.ToString() + " min " +
                               duro.Seconds.ToString() + " s";

            bool hayErrores = (respuesta.table != null && respuesta.table.Rows.Count > 0);

            pnlErrores.Visible = hayErrores;

            if (hayErrores)
            {
                rptErrores.DataSource = respuesta.table;
                rptErrores.DataBind();
            }

            Tools.tools.ClientAlert(respuesta.detalle,
                                    respuesta.cantidaError > 0 ? "alerta" : "ok");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "alerta");
        }
    }
}
