using SitioBase.Controller;
using SitioBase.Model;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// Perfiles de la empresa (bloque 341, bug 8 del cliente).
///
/// El Administrador del Cliente crea los cargos de su empresa y decide qué
/// puede hacer cada uno. Una sola página con dos vistas -listado y ficha- sin
/// modales: el cliente pidió no abrir ventanas encima de ventanas.
///
/// LO QUE PROTEGE NO ES LA PANTALLA
///   El cliente sale de la sesión (controller) y los SP comprueban que el
///   perfil sea de esa empresa y que solo se den permisos asignables. Lo que
///   hace la pantalla -bloquear combinaciones, avisar, confirmar- es para que
///   la persona no se equivoque, no para que no pueda hacer trampa.
/// </summary>
public partial class View_Clientes_Perfiles_PerfilesCliente : System.Web.UI.Page
{
    /// <summary>Perfil abierto en la ficha. 0 = nuevo; -1 = listado.</summary>
    private int PerfilId
    {
        get { return ViewState["PerfilId"] != null ? (int)ViewState["PerfilId"] : -1; }
        set { ViewState["PerfilId"] = value; }
    }

    /// <summary>Recién guardado, para resaltarlo en el listado.</summary>
    private int Resaltar
    {
        get { return ViewState["Resaltar"] != null ? (int)ViewState["Resaltar"] : 0; }
        set { ViewState["Resaltar"] = value; }
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        SitioBase.Token.ExigirPagina();
        hlUsuarios.NavigateUrl = ResolveUrl("~/View/Clientes/Cliente/Usuarios.aspx");
        if (!IsPostBack) MostrarLista();
    }

    // =========================================================== listado

    protected void Filtro_Changed(object sender, EventArgs e) { litMensaje.Text = ""; MostrarLista(); }

    private void MostrarLista()
    {
        PerfilId = -1;
        pnlLista.Visible = true;
        pnlFicha.Visible = false;

        PerfilCliente f = new PerfilCliente { filtro = txtBuscar.Text };
        if (!chkInactivos.Checked) f.filtro_habilitado = true;
        List<PerfilCliente> lista = new PerfilClienteController().GetPerfilesCliente(f);

        if (lista.Count == 0)
        {
            litLista.Text = "<div class=\"pc-card pc-vacio\"><i class=\"mdi mdi-badge-account-horizontal-outline\"></i>"
                + (string.IsNullOrWhiteSpace(txtBuscar.Text)
                    ? "<b>Todavía no hay perfiles</b>Cree el primero con «Nuevo perfil»."
                    : "<b>Ningún perfil coincide con «" + Esc(txtBuscar.Text) + "»</b>Pruebe con otra palabra.")
                + "</div>";
            return;
        }

        StringBuilder s = new StringBuilder("<div class=\"pc-grilla\">");
        foreach (PerfilCliente p in lista) s.Append(Tarjeta(p));
        s.Append("</div>");
        litLista.Text = s.ToString();
        Resaltar = 0;
    }

    private string Tarjeta(PerfilCliente p)
    {
        string clases = "pc-perfil" + (p.es_sistema ? " es-sistema" : "") + (p.per_habilitado ? "" : " es-off")
                      + (p.per_id == Resaltar ? " es-nuevo" : "");
        StringBuilder s = new StringBuilder("<div class=\"" + clases + "\">");
        s.Append("<div class=\"pc-perfil-cab\"><span class=\"pc-avatar\"><i class=\"mdi mdi-")
         .Append(p.es_sistema ? "shield-account-outline" : "badge-account-horizontal-outline").Append("\"></i></span><div>")
         .Append("<div class=\"pc-perfil-nombre\">").Append(Esc(p.per_nombre)).Append("</div>")
         .Append("<div class=\"pc-perfil-desc\">")
         .Append(string.IsNullOrWhiteSpace(p.per_descripcion) ? "<em>Sin descripción</em>" : Esc(p.per_descripcion))
         .Append("</div></div></div>");

        s.Append("<div class=\"pc-chips\">");
        if (p.es_sistema) s.Append(Chip("cyan", "lock-outline", "Del sistema"));
        if (!p.per_habilitado) s.Append(Chip("gris", "eye-off-outline", "Desactivado"));
        s.Append(Chip("blue", AmbitoIcono(p.per_ambito), AmbitoTexto(p.per_ambito)));
        s.Append(Chip("purple", "account-multiple-outline", p.usuarios == 1 ? "1 usuario" : p.usuarios + " usuarios"));
        s.Append(Chip(p.permisos == 0 ? "warning" : "purple", "key-outline",
            p.permisos == 0 ? "Sin permisos" : (p.permisos == 1 ? "1 permiso" : p.permisos + " permisos")));
        if (p.per_solo_ejecucion) s.Append(Chip("gris", "hammer-wrench", "Solo ejecuta"));
        s.Append("</div>");

        s.Append("<div class=\"pc-perfil-acc\">");
        if (p.es_sistema)
        {
            s.Append(Boton("contorno", "eye-outline", "Ver permisos", "pcAccion('editar'," + p.per_id + ")"));
            s.Append(Boton("contorno", "content-copy", "Duplicar", "pcAccion('duplicar'," + p.per_id + ")"));
            s.Append("<span class=\"pc-aviso-uso\">Lo administra SIGMA: no se modifica.</span>");
        }
        else
        {
            s.Append(Boton("contorno", "pencil-outline", "Editar", "pcAccion('editar'," + p.per_id + ")"));
            s.Append(Boton("contorno", "content-copy", "Duplicar", "pcAccion('duplicar'," + p.per_id + ")"));
            if (!p.per_habilitado)
                s.Append(Boton("contorno", "eye-outline", "Activar", "pcAccion('activar'," + p.per_id + ")"));
            else if (p.usuarios > 0)
                s.Append("<button type=\"button\" class=\"pc-btn es-peligro es-chico\" disabled title=\"Tiene "
                    + p.usuarios + (p.usuarios == 1 ? " usuario" : " usuarios")
                    + ". Asígneles otro perfil en Usuarios antes de desactivarlo.\"><i class=\"mdi mdi-eye-off-outline\"></i>Desactivar</button>");
            else
                s.Append("<button type=\"button\" class=\"pc-btn es-peligro es-chico\" onclick=\"return pcDesactivar(" + p.per_id
                    + ",'" + JsEsc(p.per_nombre) + "');\"><i class=\"mdi mdi-eye-off-outline\"></i>Desactivar</button>");
        }
        s.Append("</div></div>");
        return s.ToString();
    }

    // ======================================================= acciones

    protected void lnkNuevo_Click(object sender, EventArgs e) { litMensaje.Text = ""; AbrirFicha(0, 0); }

    protected void lnkAccion_Click(object sender, EventArgs e)
    {
        litMensaje.Text = "";
        int id;
        int.TryParse(hdnAccionId.Value, out id);
        PerfilClienteController c = new PerfilClienteController();

        switch (hdnAccion.Value)
        {
            case "editar": AbrirFicha(id, id); break;
            case "duplicar": AbrirFicha(0, id); break;
            case "volver": MostrarLista(); break;
            case "activar":
            case "desactivar":
                Respuesta r = c.CambiarEstado(id, hdnAccion.Value == "activar");
                Mensaje(r.error ? "error" : "ok", r.detalle);
                if (!r.error) Resaltar = id;
                MostrarLista();
                break;
        }
    }

    protected void ddlPlantilla_Changed(object sender, EventArgs e)
    {
        int plantilla;
        int.TryParse(ddlPlantilla.SelectedValue, out plantilla);
        PintarPermisos(plantilla, false);
        litMensaje.Text = "";
        ScriptManager.RegisterStartupScript(this, GetType(), "pcPlantilla",
            "setTimeout(function(){pcMarcarSucio();pcToast('" + (plantilla > 0
                ? "Se copiaron los permisos de «" + JsEsc(ddlPlantilla.SelectedItem.Text) + "». Revíselos antes de guardar."
                : "Se quitaron todos los permisos.") + "');},50);", true);
    }

    protected void lnkGuardar_Click(object sender, EventArgs e)
    {
        litMensaje.Text = "";
        if (PerfilId < 0) { MostrarLista(); return; }

        PerfilCliente p = new PerfilCliente
        {
            per_id = PerfilId,
            per_nombre = txtNombre.Text.Trim(),
            per_descripcion = txtDescripcion.Text.Trim(),
            per_ambito = rdbWeb.Checked ? 1 : (rdbApp.Checked ? 2 : 3),
            per_solo_ejecucion = chkSoloEjecucion.Checked,
            per_habilitado = true
        };
        if (PerfilId > 0)
        {
            PerfilCliente actual = new PerfilClienteController().GetPerfilCliente(PerfilId);
            if (actual == null || actual.es_sistema)
            {
                Mensaje("error", "Este perfil lo administra SIGMA y no se puede modificar.");
                return;
            }
            p.per_habilitado = actual.per_habilitado;
        }

        List<int> permisos = new List<int>();
        foreach (string x in (hdnPermisos.Value ?? "").Split(','))
        {
            int v;
            if (int.TryParse(x, out v) && v > 0) permisos.Add(v);
        }

        Respuesta r = new PerfilClienteController().Guardar(p, permisos);
        if (r.error)
        {
            // Si el perfil alcanzó a crearse, la ficha sigue sobre él: reintentar no lo duplica.
            if (PerfilId == 0 && r.codigo > 0) PerfilId = r.codigo;
            Mensaje("error", Limpio(r.detalle));
            return;
        }

        Resaltar = r.codigo;
        Mensaje("ok", "Perfil «" + Esc(p.per_nombre) + "» guardado. "
            + "<a href=\"" + ResolveUrl("~/View/Clientes/Cliente/Usuarios.aspx") + "\">Asígnelo a sus usuarios →</a>", false);
        MostrarLista();
    }

    // ========================================================= ficha

    /// <param name="id">Perfil a editar (0 = nuevo).</param>
    /// <param name="permisosDe">De qué perfil se leen los permisos (editar: el mismo; duplicar: el original).</param>
    private void AbrirFicha(int id, int permisosDe)
    {
        PerfilClienteController c = new PerfilClienteController();
        PerfilCliente p = id > 0 ? c.GetPerfilCliente(id) : null;
        PerfilCliente origen = permisosDe > 0 ? c.GetPerfilCliente(permisosDe) : null;
        if (id > 0 && p == null) { Mensaje("error", "Ese perfil ya no existe."); MostrarLista(); return; }

        PerfilId = id;
        pnlLista.Visible = false;
        pnlFicha.Visible = true;
        bool soloLectura = p != null && p.es_sistema;

        if (p != null)
        {
            litFichaTitulo.Text = Esc(p.per_nombre);
            litMiga.Text = Esc(p.per_nombre);
            litFichaSub.Text = soloLectura ? "Perfil del sistema" :
                (p.usuarios == 1 ? "1 usuario lo tiene" : p.usuarios + " usuarios lo tienen")
                + (p.usuarios > 0 ? ". Los cambios les llegan la próxima vez que entren." : ".");
        }
        else
        {
            litFichaTitulo.Text = origen != null ? "Nuevo perfil (copia de " + Esc(origen.per_nombre) + ")" : "Nuevo perfil";
            litMiga.Text = "Nuevo";
            litFichaSub.Text = "Tres pasos: el nombre, dónde trabaja y qué puede hacer.";
        }

        PerfilCliente datos = p ?? origen;
        txtNombre.Text = p != null ? p.per_nombre : (origen != null ? origen.per_nombre + " (copia)" : "");
        txtDescripcion.Text = datos != null ? datos.per_descripcion : "";
        int ambito = datos != null ? datos.per_ambito : 3;
        rdbWeb.Checked = ambito == 1; rdbApp.Checked = ambito == 2; rdbAmbos.Checked = ambito == 3;
        chkSoloEjecucion.Checked = datos != null && datos.per_solo_ejecucion;

        // "Empezar con los permisos de" solo al crear
        pnlPlantilla.Visible = p == null;
        if (p == null) CargarPlantillas(permisosDe);

        txtNombre.Enabled = txtDescripcion.Enabled = rdbWeb.Enabled = rdbApp.Enabled = rdbAmbos.Enabled = chkSoloEjecucion.Enabled = !soloLectura;
        lnkGuardar.Visible = !soloLectura;
        litSoloLectura.Text = soloLectura
            ? "<div class=\"pc-msg es-info\"><i class=\"mdi mdi-lock-outline\"></i><div><b>Este perfil lo administra SIGMA.</b> "
              + "Puede ver qué permite, pero no cambiarlo. Si necesita algo parecido, use «Duplicar» en el listado y edite la copia.</div></div>"
            : "";

        PintarPermisos(permisosDe, soloLectura);
    }

    private void CargarPlantillas(int elegido)
    {
        PerfilClienteController c = new PerfilClienteController();
        ddlPlantilla.Items.Clear();
        ddlPlantilla.Items.Add(new ListItem("Empezar en blanco", "0"));
        foreach (PerfilCliente x in c.GetPerfilesCliente(new PerfilCliente()))
            ddlPlantilla.Items.Add(new ListItem(x.per_nombre + (x.es_sistema ? " (sistema)" : ""), x.per_id.ToString()));
        foreach (PerfilCliente x in c.GetPerfilesCliente(new PerfilCliente { filtro_plantillas = true }))
            ddlPlantilla.Items.Add(new ListItem("Modelo SIGMA: " + x.per_nombre, x.per_id.ToString()));
        ListItem it = ddlPlantilla.Items.FindByValue(elegido.ToString());
        if (it != null) ddlPlantilla.SelectedValue = it.Value;
    }

    /// <summary>Los permisos agrupados por área, como interruptores.</summary>
    private void PintarPermisos(int deQuien, bool soloLectura)
    {
        List<PerfilClientePermiso> lista = new PerfilClienteController().GetPermisos(deQuien);
        Dictionary<string, int> porCodigo = lista.ToDictionary(x => x.prm_codigo, x => x.prm_id);

        StringBuilder s = new StringBuilder();
        foreach (IGrouping<string, PerfilClientePermiso> g in lista.GroupBy(x => x.prm_modulo).OrderBy(x => Area(x.Key)[2]))
        {
            string[] area = Area(g.Key);
            int marcados = g.Count(x => x.asignado);
            // Se abren solas las áreas que ya tienen algo: lo demás no distrae
            s.Append("<div class=\"pc-modulo" + (marcados > 0 ? " es-abierto" : "") + "\">")
             .Append("<div class=\"pc-mod-cab\" onclick=\"this.parentNode.classList.toggle('es-abierto')\">")
             .Append("<span class=\"pc-mod-ico\"><i class=\"mdi mdi-" + area[1] + "\"></i></span>")
             .Append("<div><b>" + Esc(area[0]) + "</b><small>" + Esc(area[3]) + "</small></div>")
             .Append("<span class=\"pc-mod-cuenta\">" + marcados + " de " + g.Count() + "</span>");
            if (!soloLectura)
                s.Append("<label class=\"pc-mod-todo\" onclick=\"event.stopPropagation()\" title=\"Marcar o quitar todo el área\">Todo"
                       + "<span class=\"pc-sw\"><input type=\"checkbox\" class=\"pc-todo\" onclick=\"pcTodoModulo(this, event)\" /><i></i></span></label>");
            s.Append("<i class=\"mdi mdi-chevron-down pc-flecha\"></i></div><div class=\"pc-mod-cuerpo\">");

            foreach (PerfilClientePermiso x in g)
            {
                string requiere = "";
                if (x.prm_codigo.StartsWith("CREAR EDITAR ", StringComparison.Ordinal))
                {
                    int ver;
                    if (porCodigo.TryGetValue("VER " + x.prm_codigo.Substring(13), out ver)) requiere = ver.ToString();
                }
                string desc = string.Equals(x.prm_descripcion, x.prm_nombre, StringComparison.OrdinalIgnoreCase) ? "" : x.prm_descripcion;
                string buscar = Plano(x.prm_nombre + " " + desc + " " + area[0]);

                s.Append("<label class=\"pc-permiso" + (soloLectura ? " es-bloqueado" : "") + "\" data-buscar=\"" + Esc(buscar) + "\">")
                 .Append("<span class=\"pc-sw\"><input type=\"checkbox\" data-prm=\"" + x.prm_id + "\" data-codigo=\"" + Esc(x.prm_codigo)
                       + "\" data-nombre=\"" + Esc(Mayus(x.prm_nombre)) + "\"" + (requiere != "" ? " data-requiere=\"" + requiere + "\"" : "")
                       + (x.asignado ? " checked" : "") + (soloLectura ? " disabled data-ro=\"1\"" : " onchange=\"pcCambio(this)\"") + " /><i></i></span>")
                 .Append("<div><b>" + Esc(Mayus(x.prm_nombre)) + "</b>" + (desc != "" ? "<span class=\"d\">" + Esc(desc) + "</span>" : "") + "</div>")
                 .Append("<span class=\"pc-tipo\">" + TipoChip(x.prm_codigo) + "</span></label>");
            }
            s.Append("</div></div>");
        }
        litPermisos.Text = s.Length > 0 ? s.ToString()
            : "<div class=\"pc-vacio\"><i class=\"mdi mdi-key-outline\"></i><b>No hay permisos disponibles</b>Contacte a SIGMA.</div>";
        hdnPermisos.Value = string.Join(",", lista.Where(x => x.asignado).Select(x => x.prm_id.ToString()).ToArray());
    }

    // ======================================================= ayudas

    /// <summary>Nombre amigable, icono, orden y explicación de cada área.</summary>
    private static string[] Area(string modulo)
    {
        switch ((modulo ?? "").ToUpperInvariant())
        {
            case "ACTIVOS": return new[] { "Activos y equipos", "cog-outline", "01", "Máquinas, componentes, medidores y su estado." };
            case "MANTENIMIENTO": return new[] { "Mantenimiento", "wrench-outline", "02", "Planes, pautas, tareas, checklists y predicciones." };
            case "ORDEN TRABAJO": return new[] { "Órdenes de trabajo", "clipboard-check-outline", "03", "Cerrar, validar y completar órdenes." };
            case "INVENTARIO": return new[] { "Bodegas e inventario", "warehouse", "04", "Stock, movimientos, etiquetas y alertas de bodega." };
            case "REPUESTOS": return new[] { "Repuestos", "package-variant-closed", "05", "El catálogo de repuestos de la empresa." };
            case "PERMISO TRABAJO": return new[] { "Permisos de trabajo", "shield-check-outline", "06", "Autorizar trabajos de riesgo." };
            case "TERCEROS": return new[] { "Proveedores y contratistas", "account-hard-hat-outline", "07", "Proveedores y permisos de trabajo de terceros." };
            case "ORGANIZACION": return new[] { "Organización", "sitemap-outline", "08", "Plantas, áreas, centros de costo, grupos y especialidades." };
            case "CLIENTES": return new[] { "Empresa y usuarios", "domain", "09", "Los datos de la empresa y sus usuarios." };
            case "SEGURIDAD": return new[] { "Seguridad y accesos", "lock-outline", "10", "Perfiles y permisos especiales de los usuarios." };
            case "UTILIDADES": return new[] { "Utilidades", "tools", "11", "Carga de datos desde planillas." };
            case "COMERCIAL": return new[] { "Suscripción", "credit-card-outline", "12", "Renovar y pagar el plan de SIGMA." };
            case "SISTEMA": return new[] { "Catálogos", "format-list-bulleted", "13", "Listas de valores que usa la empresa." };
            default: return new[] { CultureInfo.GetCultureInfo("es-CL").TextInfo.ToTitleCase((modulo ?? "Otros").ToLowerInvariant()), "dots-horizontal", "99", "" };
        }
    }

    private static string TipoChip(string codigo)
    {
        if (codigo.StartsWith("VER ", StringComparison.Ordinal))
            return "<span class=\"pc-chip es-cyan\"><i class=\"mdi mdi-eye-outline\"></i>Ver</span>";
        if (codigo.StartsWith("CREAR EDITAR ", StringComparison.Ordinal))
            return "<span class=\"pc-chip es-purple\"><i class=\"mdi mdi-pencil-outline\"></i>Crear y editar</span>";
        return "<span class=\"pc-chip es-blue\"><i class=\"mdi mdi-lightning-bolt-outline\"></i>Acción</span>";
    }

    private static string AmbitoTexto(int a) { return a == 1 ? "Solo web" : (a == 2 ? "Solo app" : "Web y app"); }
    private static string AmbitoIcono(int a) { return a == 1 ? "monitor" : (a == 2 ? "cellphone" : "devices"); }

    private static string Chip(string tono, string icono, string texto)
    {
        return "<span class=\"pc-chip es-" + tono + "\"><i class=\"mdi mdi-" + icono + "\"></i>" + Esc(texto) + "</span>";
    }

    private static string Boton(string tipo, string icono, string texto, string js)
    {
        return "<button type=\"button\" class=\"pc-btn es-" + tipo + " es-chico\" onclick=\"return " + js + ";\"><i class=\"mdi mdi-"
             + icono + "\"></i>" + Esc(texto) + "</button>";
    }

    private void Mensaje(string tipo, string texto, bool escapar = true)
    {
        string icono = tipo == "ok" ? "check-circle-outline" : (tipo == "error" ? "alert-circle-outline" : "information-outline");
        litMensaje.Text = "<div class=\"pc-msg es-" + tipo + "\"><i class=\"mdi mdi-" + icono + "\"></i><div>"
                        + (escapar ? Esc(texto) : texto) + "</div></div>";
    }

    /// <summary>Los RAISERROR vienen como "4.- YA EXISTE…": a la persona se le muestra en frase normal.</summary>
    private static string Limpio(string m)
    {
        if (string.IsNullOrEmpty(m)) return "No se pudo guardar. Intente de nuevo.";
        m = m.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries)[0].Trim();
        int i = m.IndexOf(".- ", StringComparison.Ordinal);
        if (i >= 0 && i < 4) m = m.Substring(i + 3);
        return Mayus(m.ToLower(CultureInfo.GetCultureInfo("es-CL")));
    }

    private static string Mayus(string t)
    {
        return string.IsNullOrEmpty(t) ? t : char.ToUpper(t[0], CultureInfo.GetCultureInfo("es-CL")) + t.Substring(1);
    }

    private static string Plano(string t)
    {
        string n = (t ?? "").ToLowerInvariant().Normalize(NormalizationForm.FormD);
        StringBuilder b = new StringBuilder();
        foreach (char ch in n) if (CharUnicodeInfo.GetUnicodeCategory(ch) != UnicodeCategory.NonSpacingMark) b.Append(ch);
        return b.ToString();
    }

    private static string Esc(string t) { return System.Web.HttpUtility.HtmlEncode(t ?? ""); }
    private static string JsEsc(string t) { return System.Web.HttpUtility.JavaScriptStringEncode(t ?? ""); }
}
