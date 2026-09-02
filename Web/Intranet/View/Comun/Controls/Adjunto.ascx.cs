using SitioBase;
using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Web.UI;

/// <summary>
/// El documento adjunto de cualquier ficha: verlo, bajarlo o subirlo.
///
/// POR QUE UN CONTROL Y NO CINCO COPIAS
///   Cada módulo que adjunta algo —el comprobante de pago, el permiso de
///   trabajo firmado, lo que venga— necesita exactamente lo mismo. Repetirlo
///   en cada ficha son N sitios donde arreglar el mismo enlace roto, y donde
///   el día que cambie la comprobación de permiso quede una sin cambiar.
///
/// COMO SE USA
///
///     &lt;wuc:Adjunto runat="server" ID="wucAdjunto"
///                  Modulo="permisos-trabajo"
///                  Categoria="13" /&gt;
///
///     // Al cargar la ficha:
///     wucAdjunto.Mostrar(entidad.ptr_archivo);
///
///     // Al guardar:
///     int archivo = wucAdjunto.Guardar();   // 0 si no se eligió nada
///
/// VER Y DESCARGAR SON ENLACES, NO BOTONES
///   Un LinkButton con target _blank pierde el postback y no abre nada. Y un
///   postback que escribe un binario en la respuesta rompe el UpdatePanel,
///   que espera un fragmento y recibe un PDF. Son &lt;a&gt; de verdad hacia
///   VerArchivo.aspx, con el id cifrado.
/// </summary>
public partial class Comun_Controls_Adjunto : System.Web.UI.UserControl
{
    /// <summary>
    /// La carpeta del módulo dentro del cliente: "permisos-trabajo",
    /// "comprobantes-pago". Es lo que hace que la búsqueda sea específica.
    /// </summary>
    public string Modulo
    {
        get { return ViewState["Modulo"] != null ? (string)ViewState["Modulo"] : "otros"; }
        set { ViewState["Modulo"] = value; }
    }

    /// <summary>La categoría de Archivo_Categoria con la que se registra.</summary>
    public int Categoria
    {
        get { return ViewState["Categoria"] != null ? (int)ViewState["Categoria"] : 9; }
        set { ViewState["Categoria"] = value; }
    }

    /// <summary>El texto de ayuda bajo el selector de archivo.</summary>
    public string Ayuda
    {
        get { return ViewState["Ayuda"] != null ? (string)ViewState["Ayuda"] : ""; }
        set { ViewState["Ayuda"] = value; }
    }

    /// <summary>Con solo lectura no se ofrece subir, pero sí ver y bajar.</summary>
    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] != null && (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>El archivo que tiene hoy. 0 = ninguno.</summary>
    public int IdArchivo
    {
        get { return ViewState["IdArchivo"] != null ? (int)ViewState["IdArchivo"] : 0; }
        set { ViewState["IdArchivo"] = value; }
    }

    /// <summary>Si el usuario eligió un archivo para subir.</summary>
    public bool HayArchivoNuevo
    {
        get { return pnlSubir.Visible && fup.HasFile; }
    }

    /// <summary>
    /// Dibuja el estado que corresponda.
    ///
    /// Se llama en PreRender de la ficha, no en Load: el id del archivo puede
    /// haber cambiado durante el postback —se acaba de subir uno— y dibujarlo
    /// antes mostraría el estado anterior.
    /// </summary>
    public void Mostrar(int? idArchivo)
    {
        IdArchivo = (idArchivo != null && idArchivo.Value > 0) ? idArchivo.Value : 0;

        pnlTiene.Visible = false;
        pnlSubir.Visible = false;
        pnlNoSePuede.Visible = false;
        pnlVacio.Visible = false;

        if (IdArchivo > 0)
        {
            Dibujar();
            return;
        }

        if (ReadOnly)
        {
            pnlVacio.Visible = true;
            return;
        }

        /* SE PREGUNTA ANTES DE OFRECER.
           Un selector de archivo que al guardar responde "todavía no se puede
           adjuntar" hace perder el trabajo de elegirlo. */
        if (!Services.Disponible)
        {
            pnlNoSePuede.Visible = true;

            litMotivo.Text = "<strong>Todavía no se puede adjuntar.</strong> " +
                             Server.HtmlEncode(Services.Motivo);
            return;
        }

        pnlSubir.Visible = true;
        litAyudaSubir.Text = Ayuda;
    }

    /// <summary>
    /// El nombre, el peso y los dos enlaces.
    ///
    /// Si el archivo no se puede leer NO se rompe la ficha: se muestra el
    /// nombre sin los enlaces y se dice qué pasa. Que no se pueda abrir un
    /// adjunto no es razón para no poder ver el permiso.
    /// </summary>
    private void Dibujar()
    {
        pnlTiene.Visible = true;

        try
        {
            ArchivoController controller = new ArchivoController();
            Archivo a = controller.GetArchivo(new Archivo { arc_id = IdArchivo });

            if (a == null || a.arc_id == 0 || a.arc_cliente != SitioBase.Session.ClienteId())
            {
                litNombre.Text = "Documento no disponible";
                litMeta.Text = "No se encontró el registro del archivo.";
                lnkVer.Visible = false;
                lnkDescargar.Visible = false;
                return;
            }

            litNombre.Text = Server.HtmlEncode(a.arc_nombre_original);

            string meta = Peso(a.arc_byte);

            if (a.arc_fecha_creacion != null)
                meta += (meta.Length > 0 ? " · " : "") +
                        "subido el " + a.arc_fecha_creacion.Value.ToString("dd-MM-yyyy");

            litMeta.Text = meta;

            /* El id va cifrado: con la ruta a la vista cualquiera podría pedir
               otra cambiando el texto de la URL. */
            string q = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.arc_id + "&Modo=VER"));
            string d = Server.UrlEncode(Tools.Crypto.Encrypt("Id=" + a.arc_id + "&Modo=BAJAR"));

            string pagina = ResolveUrl("~/View/Comun/Archivos/VerArchivo.aspx");

            lnkVer.NavigateUrl = pagina + "?query=" + q;
            lnkDescargar.NavigateUrl = pagina + "?query=" + d;

            lnkVer.Visible = true;
            lnkDescargar.Visible = true;
        }
        catch (Exception ex)
        {
            litNombre.Text = "Documento no disponible";
            litMeta.Text = Server.HtmlEncode(ex.Message);
            lnkVer.Visible = false;
            lnkDescargar.Visible = false;
        }
    }

    /// <summary>
    /// Sube lo que se haya elegido y devuelve el id de Archivo. Devuelve el
    /// que ya tenía si no se eligió nada nuevo.
    ///
    /// Lanza si la subida falla: guardar la ficha diciendo que todo salió
    /// bien cuando el documento no quedó es lo peor que puede pasar acá.
    /// </summary>
    public int Guardar()
    {
        if (!HayArchivoNuevo) return IdArchivo;

        Archivo archivo = new Archivo();

        archivo.arc_cliente = SitioBase.Session.ClienteId();
        archivo.arc_archivo_categoria = Categoria;
        archivo.arc_nombre_original = fup.FileName;
        archivo.arc_mime = fup.PostedFile.ContentType;
        archivo.contenido = fup.FileBytes;

        ArchivoController controller = new ArchivoController();
        Respuesta respuesta = controller.InsertArchivo(archivo, Modulo);

        if (respuesta.error)
            throw new Exception("No se pudo adjuntar el documento: " + respuesta.detalle);

        IdArchivo = respuesta.codigo;

        return IdArchivo;
    }

    private string Peso(long bytes)
    {
        if (bytes <= 0) return "";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1048576) return (bytes / 1024.0).ToString("N0") + " KB";

        return (bytes / 1048576.0).ToString("N1") + " MB";
    }
}
