using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;

/// <summary>
/// Carga masiva de repuestos desde una planilla.
///
/// LA CARGA PASA POR EL MISMO CAMINO QUE LA FICHA
///   El controlador reusa InsertRepuesto fila por fila en vez de escribir su
///   propio INSERT. Con un INSERT propio habría que repetir cada validación
///   del SP —código único, unidad que exista— y esas copias se desincronizan
///   a la primera regla nueva: lo que se puede crear a mano tiene que ser
///   exactamente lo que se puede cargar en masa.
///
/// UNA FILA MALA NO DETIENE LA CARGA
///   Con doscientos repuestos, que la fila 40 tenga la unidad mal escrita no
///   puede obligar a rehacer la planilla entera. Se cargan las demás y se
///   informa cuál falló, con su número de fila y el motivo.
/// </summary>
public partial class View_Inventario_Repuestos_CargaMasivaRepuestos : System.Web.UI.Page
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
        bool puede = Token.Puede("CREAR EDITAR REPUESTOS");

        btnCargar.Visible = puede;
        fldArchivo.Enabled = puede;

        if (!puede)
            Tools.tools.ClientAlert("No tiene permiso para crear repuestos.", "alerta");
    }

    protected void btnPlantilla_Click(object sender, EventArgs e)
    {
        try
        {
            RepuestoController controller = new RepuestoController();
            controller.PlantillaRepuestos();
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
            if (!Token.Puede("CREAR EDITAR REPUESTOS"))
                throw new Exception("No tiene permiso para crear repuestos.");

            if (!fldArchivo.HasFile)
                throw new Exception("Adjunte la planilla que quiere cargar.");

            if (!fldArchivo.FileName.ToLower().EndsWith(".xlsx"))
                throw new Exception("El archivo tiene que ser .xlsx. " +
                                    "Si lo guardó como .xls o .csv, vuelva a guardarlo " +
                                    "como libro de Excel.");

            DateTime inicio = DateTime.Now;

            RepuestoController controller = new RepuestoController();
            Respuesta respuesta = controller.InsertRepuestosMasivo(fldArchivo.FileBytes);

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
