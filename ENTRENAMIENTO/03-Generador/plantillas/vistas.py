# -*- coding: utf-8 -*-
"""
Generacion de los UserControls (.ascx + .ascx.cs):
  - Listado (grid)          -> PATRON_MVC.md seccion 4
  - Formulario (tabs)       -> PATRON_MVC.md seccion 5
  - Tab / sub-formulario    -> PATRON_MVC.md seccion 6
"""

from nucleo import util


# ===========================================================================
# HELPERS DE MARKUP
# ===========================================================================
def _validador(c, grupo):
    return ('\n                <asp:CustomValidator ID="cv%s" runat="server"\n'
            '                    ControlToValidate="%s"\n'
            '                    ValidateEmptyText="true"\n'
            '                    ClientValidationFunction="validaControl"\n'
            '                    ValidationGroup="%s" />'
            % (util.pascal(c.nombre), c.control_id, grupo))


def _campo_markup(d, c):
    """Devuelve el bloque <div class="form-group"> de una columna."""
    p = d.proyecto
    e = d.entidad
    tag = p.controles[c.control]
    maxlen = ' MaxLength="%d"' % c.max_length if c.max_length else ''

    if c.control == 'texto':
        extra = ''
        if c.upper:
            extra += ' UpperCase="true"'
        if c.lower:
            extra += ' LowerCase="true"'
        control = '<%s ID="%s" runat="server"%s%s />' % (tag, c.control_id, maxlen, extra)
        if c.icono:
            control = ('<%%-- Campo con icono dentro del input (PATRON_CONTROLES.md 7.4) --%%>\n'
                       '                <div class="identidad-field-icon">\n'
                       '                    <i class="fas %s"></i>\n'
                       '                    %s\n'
                       '                </div>' % (c.icono, control))

    elif c.control == 'textarea':
        control = '<%s ID="%s" runat="server"%s />' % (tag, c.control_id, maxlen)

    elif c.control == 'numero':
        control = ('<%s ID="%s" runat="server" Width="100%%">\n'
                   '                    <NumberFormat DecimalDigits="%d" />\n'
                   '                </%s>'
                   % (tag, c.control_id, c.tipo.decimales, tag))

    elif c.control == 'combo':
        control = ('<%%-- OnLoad="LoadControls": el combo se puebla desde el Controller\n'
                   '                     una sola vez (dentro del !IsPostBack del code-behind). --%%>\n'
                   '                <%s ID="%s" runat="server"\n'
                   '                    OnLoad="LoadControls" Filter="Contains" Width="100%%" />'
                   % (tag, c.control_id))

    elif c.control == 'check':
        marcado = ' Checked="true"' if (c.defecto in (1, '1', True) or c is d.col_habilitado) else ''
        control = '<%s ID="%s" runat="server"%s />' % (tag, c.control_id, marcado)

    elif c.control == 'fecha':
        control = '<%s ID="%s" runat="server" Width="100%%" />' % (tag, c.control_id)

    elif c.control == 'password':
        control = ('<%%-- Password: NUNCA usar ReadOnly="true" en un TextBox2 de tipo Password,\n'
                   '                     porque renderiza un <span> con el texto plano. Usar Enabled="false". --%%>\n'
                   '                <div class="identidad-password-field">\n'
                   '                    <%s ID="%s" runat="server" TextMode="Password"%s />\n'
                   '                    <i class="fas fa-eye identidad-password-toggle"\n'
                   '                       onclick="togglePasswordVisibility(\'<%%= %s.ClientID %%>\', this)"></i>\n'
                   '                </div>'
                   % (tag, c.control_id, maxlen, c.control_id))
    else:
        return ''

    validador = _validador(c, e.singular) if c.valida else ''

    return ('            <div class="form-group %s">\n'
            '                <label>%s</label>\n'
            '                %s%s\n'
            '            </div>' % (c.ancho_form, c.etiqueta, control, validador))


# ===========================================================================
# 1. LISTADO .ascx
# ===========================================================================
def listado_ascx(d):
    e = d.entidad
    p = d.proyecto

    if e.usa_baja_logica:
        texto_boton, id_boton, confirmacion = ('Deshabilitar', 'lnkDeshabilitar',
                                               'Esta seguro que desea deshabilitar los registros seleccionados?')
    else:
        texto_boton, id_boton, confirmacion = ('Eliminar', 'lnkEliminar',
                                               'Esta seguro que desea eliminar los registros seleccionados?')

    plantilla = r'''<%--
    USERCONTROL DE LISTADO (GRID) - {{PLURAL}}.ascx

    PATRON (ver PATRON_MVC.md seccion 4 y PATRON_CONTROLES.md seccion 1):
      - El listado NUNCA vive en el .aspx: vive en un UserControl reutilizable.
      - El grid va SIEMPRE dentro de un asp:UpdatePanel UpdateMode="Conditional".
      - Los botones de accion van en el CommandItemTemplate.
      - La navegacion al formulario usa un querystring CIFRADO.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="{{PLURAL}}.ascx.cs" Inherits="{{CLASE}}" %>
<%@ Register Src="{{SRC_FILTRO}}" TagPrefix="wuc" TagName="Filtro" %>

<script type="text/javascript">

    // Abre el formulario de {{SINGULAR}}. 'query' llega ya cifrado desde el code-behind.
    function abrir{{SINGULAR}}(query) {
        window.location = ('<%=ResolveUrl(URLNuevo{{SINGULAR}}) %>?query=' + query);
    }

    // Refresca el grid via AJAX sin recargar la pagina.
    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '');
    }

</script>

<%-- Barra de filtros: control comun del proyecto, no se reescribe por pantalla --%>
<wuc:Filtro ID="wucFiltro" runat="server" />

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

        <{{TAG_GRID}} ID="Grid" runat="server"
            OnItemDataBound="rgr{{PLURAL}}_ItemDataBound">

            <%-- DataKeyNames: columnas que luego se leen con GetDataKeyValue(...) --%>
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="{{ID_PROP}}">

                <CommandItemTemplate>
                    <div style="margin-bottom: 5px;">

                        <%-- Solo navega por JS: no necesita OnClick de servidor --%>
                        <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo"
                            CssClass="icono_guardar"
                            OnClientClick="abrir{{SINGULAR}}(0)" />

                        <%-- ConfirSweetAlert devuelve false si el usuario cancela:
                             el "return" evita el postback y por lo tanto el OnClick. --%>
                        <asp:LinkButton ID="{{ID_BOTON}}" runat="server" Text="{{TEXTO_BOTON}}"
                            CssClass="icono_eliminar"
                            OnClick="{{ID_BOTON}}_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', '{{CONFIRMACION}}');" />

                    </div>
                </CommandItemTemplate>

            </MasterTableView>

        </{{TAG_GRID}}>

    </ContentTemplate>
</asp:UpdatePanel>'''

    return util.render(plantilla, {
        'PLURAL': e.plural,
        'SINGULAR': e.singular,
        'CLASE': e.clase_listado,
        'SRC_FILTRO': p.ruta_filtro,
        'TAG_GRID': p.controles['grid'],
        'ID_PROP': e.id_prop,
        'ID_BOTON': id_boton,
        'TEXTO_BOTON': texto_boton,
        'CONFIRMACION': confirmacion,
    })


# ===========================================================================
# 2. LISTADO .ascx.cs
# ===========================================================================
def listado_cs(d):
    e = d.entidad
    p = d.proyecto
    var = util.camel(e.singular)

    # --- columnas del grid ---
    def _con_comentario(codigo, comentario):
        return '            ' + codigo.ljust(48) + '// ' + comentario

    cols = [_con_comentario('Grid.AddSelectColumn();', 'checkbox de seleccion por fila'),
            _con_comentario('Grid.AddColumn("%s", "", Width: "3%%");' % e.id_prop,
                            'celda donde se inyecta el link Editar')]

    for c in d.columnas_grid:
        if c.control == 'check':
            cols.append('            Grid.AddCheckboxColumn("%s", "%s");' % (c.prop, c.grid_titulo))
            continue
        campo = c.fk.prop_denormalizada if c.fk else c.prop
        extra = ''
        if c.tipo.categoria == 'fecha':
            extra = ', DataFormat: "{0:dd-MM-yyyy}"'
        elif c.tipo.es_numero and not c.fk:
            # Las FK muestran el texto del JOIN, no un numero: no se alinean a la derecha.
            extra = ', Align: HorizontalAlign.Right'
        cols.append('            Grid.AddColumn("%s", "%s", Width: "%s"%s);'
                    % (campo, c.grid_titulo, c.grid_ancho, extra))

    # --- propiedades de seguridad ---
    props_seguridad = [r'''    /// <summary>Id de la funcion "Ver todo" del menu.</summary>
    public int Ver_Todo
    {
        get { return ViewState["Ver_Todo"] == null ? 0 : (int)ViewState["Ver_Todo"]; }
        set { ViewState["Ver_Todo"] = value; }
    }''']

    if e.seguridad_por_pais:
        props_seguridad.append(r'''    /// <summary>Id de la funcion "Ver todo paises".</summary>
    public int VerTodoPaises
    {
        get { return ViewState["VerTodoPaises"] == null ? 0 : (int)ViewState["VerTodoPaises"]; }
        set { ViewState["VerTodoPaises"] = value; }
    }''')

    props_seguridad.append(r'''    /// <summary>Id de la funcion "Crear/Editar": si no la tiene, el grid va en ReadOnly.</summary>
    public int Crear_Editar
    {
        get { return ViewState["Crear_Editar"] == null ? 0 : (int)ViewState["Crear_Editar"]; }
        set { ViewState["Crear_Editar"] = value; }
    }''')

    # --- CargarGrid ---
    carga = []
    if e.seguridad_por_pais:
        carga.append('''        #region SeguridadPagina

        // Si el perfil NO tiene la funcion "Ver todo paises", se le limita
        // el listado a los paises que tiene asignados en su sesion.
        MenuFuncion verTodoPaises = new MenuFuncion();
        verTodoPaises.mfu_funcion = VerTodoPaises;

        if (!SitioBase.Token.SecurityManager(verTodoPaises))
            filtro.filtro_paises = SitioBase.Session.UsuarioIdPaises();

        #endregion
''')

    if d.columnas_busqueda:
        carga.append('        // Texto libre de la barra de filtros comun.')
        carga.append('        filtro.filtro = wucFiltro.Filtro();')
        carga.append('')

    if e.habilitado:
        carga.append('        // Controles que viven dentro del UserControl de filtro:')
        carga.append('        // se buscan con FindControl y se ignoran si no existen.')
        carga.append('        RadComboBox2 cboHabilitado = (RadComboBox2)wucFiltro.FindControl("cboHabilitado");')
        carga.append('        if (cboHabilitado != null && !string.IsNullOrEmpty(cboHabilitado.SelectedValue))')
        carga.append('            filtro.filtro_habilitado = bool.Parse(cboHabilitado.SelectedValue);')
        carga.append('')

    for c in d.columnas_filtro:
        nombre_cbo = 'cbo' + util.pascal(c.nombre)
        carga.append('        RadComboBox2 %s = (RadComboBox2)wucFiltro.FindControl("%s");'
                     % (nombre_cbo, nombre_cbo))
        carga.append('        if (%s != null && !string.IsNullOrEmpty(%s.SelectedValue))'
                     % (nombre_cbo, nombre_cbo))
        carga.append('            filtro.filtro_%s = int.Parse(%s.SelectedValue);'
                     % (c.nombre.lower(), nombre_cbo))
        carga.append('')

    # --- boton masivo ---
    if e.usa_baja_logica:
        id_boton, metodo = 'lnkDeshabilitar', 'Deshabilitar' + e.singular
    else:
        id_boton, metodo = 'lnkEliminar', 'Delete' + e.singular

    plantilla = r'''using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using {{NS_MODEL}};
using {{NS_CONTROLLER}};
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL LISTADO DE {{TABLA}}.
///
/// PATRON (ver PATRON_MVC.md seccion 4, PATRON_CONTROLES.md seccion 1,
/// PATRON_GRID_EVENTS.md secciones 2-4):
///  1. Clase partial que hereda de System.Web.UI.UserControl.
///     El nombre = ruta del archivo con "_".
///  2. Las propiedades publicas se guardan en ViewState, NO en campos privados.
///  3. Las columnas del grid se construyen por codigo en !IsPostBack.
///  4. La carga de datos va en Page_PreRender, no en Page_Load.
///  5. El code-behind NUNCA toca la base de datos: siempre pasa por el Controller.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class {{CLASE}} : System.Web.UI.UserControl
{
    #region PROPIEDADES (siempre en ViewState)

    /// <summary>Modo solo lectura: oculta la barra de comandos del grid.</summary>
    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>Ruta del formulario. La setea la pagina padre (.aspx).</summary>
    public string URLNuevo{{SINGULAR}}
    {
        get { return ViewState["URLNuevo{{SINGULAR}}"] == null ? "" : ViewState["URLNuevo{{SINGULAR}}"].ToString(); }
        set { ViewState["URLNuevo{{SINGULAR}}"] = value; }
    }

    // --- Propiedades de SEGURIDAD que setea la pagina padre desde SitioBase.Paginas ---

{{PROPS_SEGURIDAD}}

    #endregion

    #region CICLO DE VIDA

    /// <summary>
    /// PreRender: ultimo evento antes de renderizar. Cargar aqui garantiza
    /// que el grid muestre el resultado de los clicks ya procesados.
    /// </summary>
    protected void Page_PreRender(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            // --- Construccion de columnas. Solo la primera vez. ---

{{COLUMNAS}}
        }

        // En solo lectura se oculta toda la barra de comandos.
        if (ReadOnly)
            Grid.MasterTableView.CommandItemDisplay = GridCommandItemDisplay.None;

        CargarGrid();
        Grid.DataBind();
        udPanel.Update();

        // Registra el script que permite refresh() desde JS (__doPostBack).
        Tools.tools.RegisterPostBackScript(Grid);
    }

    #endregion

    #region CARGA DE DATOS

    /// <summary>
    /// Arma el Model de filtros y se lo entrega al Controller.
    /// Aqui NO hay SQL: solo se traducen los controles de pantalla a filtros.
    /// </summary>
    protected void CargarGrid()
    {
        {{CLASE_CONTROLLER}} {{VAR}}Controller = new {{CLASE_CONTROLLER}}();
        {{CLASE_MODEL}} filtro = new {{CLASE_MODEL}}();

{{CARGA}}
        // Unica llamada a datos de todo el archivo.
        Grid.DataSource = {{VAR}}Controller.Get{{PLURAL}}(filtro);
    }

    #endregion

    #region EVENTOS DEL GRID

    /// <summary>
    /// Se ejecuta UNA VEZ POR FILA ya con datos.
    /// Aqui se inyecta el link "Editar" que abre el formulario.
    ///
    /// El id NO viaja en claro por la URL: se cifra con Tools.Crypto.Encrypt
    /// para que nadie pueda editar otro registro cambiando el numero a mano.
    /// </summary>
    protected void rgr{{PLURAL}}_ItemDataBound(object sender, GridItemEventArgs e)
    {
        // Solo filas de datos: ni encabezado, ni footer, ni paginador.
        if (e.Item.ItemType == GridItemType.AlternatingItem | e.Item.ItemType == GridItemType.Item)
        {
            if (e.Item is GridDataItem)
            {
                GridDataItem item = e.Item as GridDataItem;

                // La columna debe estar declarada en DataKeyNames del MasterTableView.
                string id = item.GetDataKeyValue("{{ID_PROP}}").ToString();

                string query = Server.UrlEncode(
                    Tools.Crypto.Encrypt("Id{{SINGULAR}}=" + id + "&ReadOnly=" + ReadOnly));

                // Para NAVEGAR se usa HyperLink (sin postback), no LinkButton.
                HyperLink Editar = new HyperLink();
                Editar.ID = "lnkEditar" + id;
                Editar.CssClass = "icono_Editar";
                Editar.NavigateUrl = "javascript:void(0)";
                Editar.Attributes.Add("onclick", "abrir{{SINGULAR}}('" + query + "')");

                item["{{ID_PROP}}"].Controls.Add(Editar);
            }
        }
    }

    /// <summary>
    /// Accion masiva sobre las filas seleccionadas.
    /// Patron: validar seleccion -> recorrer SelectedIndexes -> llamar al Controller
    /// -> avisar con Tools.tools.ClientAlert.
    /// </summary>
    protected void {{ID_BOTON}}_Click(object sender, EventArgs e)
    {
        try
        {
            if (Grid.SelectedIndexes.Count == 0)
            {
                Tools.tools.ClientAlert("Debe seleccionar al menos un registro.");
                return;
            }

            Respuesta respuesta = new Respuesta();
            {{CLASE_CONTROLLER}} {{VAR}}Controller = new {{CLASE_CONTROLLER}}();

            foreach (string idx in Grid.SelectedIndexes)
            {
                Telerik.Web.UI.DataKey value = Grid.MasterTableView.DataKeyValues[int.Parse(idx)];
                int id = int.Parse(value["{{ID_PROP}}"].ToString());

                {{CLASE_MODEL}} {{VAR}} = new {{CLASE_MODEL}} { {{ID_PROP}} = id };
                respuesta = {{VAR}}Controller.{{METODO_MASIVO}}({{VAR}});
            }

            // El tercer parametro true cierra el modal / dispara refresh().
            if (!respuesta.error)
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            else
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.Message, "error");
        }
    }

    #endregion
}'''

    return util.render(plantilla, {
        'NS_MODEL': p.ns_model,
        'NS_CONTROLLER': p.ns_controller,
        'TABLA': e.tabla,
        'CLASE': e.clase_listado,
        'SINGULAR': e.singular,
        'PLURAL': e.plural,
        'PROPS_SEGURIDAD': '\n\n'.join(props_seguridad),
        'COLUMNAS': '\n'.join(cols),
        'CLASE_CONTROLLER': e.clase_controller,
        'CLASE_MODEL': e.clase_model,
        'VAR': var,
        'CARGA': '\n'.join(carga),
        'ID_PROP': e.id_prop,
        'ID_BOTON': id_boton,
        'METODO_MASIVO': metodo,
    })


# ===========================================================================
# 3. FORMULARIO .ascx (contenedor de tabs)
# ===========================================================================
def formulario_ascx(d):
    e = d.entidad
    p = d.proyecto

    plantilla = r'''<%--
    USERCONTROL DE FORMULARIO (CONTENEDOR DE TABS) - {{SINGULAR}}.ascx

    PATRON (ver PATRON_MVC.md seccion 5):
      - Este control NO tiene campos ni logica de guardado. Es solo el "marco":
        un TabStrip vertical + un MultiPage con un PageView por tab.
      - Cada tab es a su vez un UserControl independiente.
      - Su unica responsabilidad es propagar ReadOnly / Id{{SINGULAR}} a los hijos.
      - Asi el formulario crece agregando tabs, sin tocar los existentes.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="{{SINGULAR}}.ascx.cs" Inherits="{{CLASE}}" %>
<%@ Register Src="{{SRC_TAB}}" TagPrefix="wuc" TagName="{{TAB}}" %>

<script type="text/javascript">

    // Vuelve al listado. URLVolver{{SINGULAR}} lo setea la pagina padre.
    function closeWindow() {
        window.location = ('<%=ResolveUrl(URLVolver{{SINGULAR}}) %>');
    }

</script>

<div class="row col-lg-12 col-md-12 col-xs-12">

    <div class="col-lg-2 col-md-3 col-xs-12">
        <{{TAG_TABSTRIP}} ID="tab{{SINGULAR}}" runat="server"
            MultiPageID="mp{{SINGULAR}}"
            Orientation="VerticalLeft"
            SelectedIndex="0">
            <Tabs>
                <{{TAG_TAB}} Text="{{TAB}}" PageViewID="pv{{TAB}}" />
            </Tabs>
        </{{TAG_TABSTRIP}}>
    </div>

    <div class="col-lg-10 col-md-9 col-xs-12">
        <{{TAG_MULTIPAGE}} ID="mp{{SINGULAR}}" runat="server" SelectedIndex="0" RenderSelectedPageOnly="false">

            <{{TAG_PAGEVIEW}} ID="pv{{TAB}}" runat="server">
                <wuc:{{TAB}} ID="wuc{{TAB}}" runat="server" />
            </{{TAG_PAGEVIEW}}>

        </{{TAG_MULTIPAGE}}>
    </div>

    <div class="col-lg-12 col-md-12 col-xs-12" style="text-align: right;">
        <%-- "return false" evita el postback: este boton solo navega. --%>
        <{{TAG_BOTON}} ID="btnCerrar" runat="server" Text="Volver"
            CssClass="ButtonCerrar IcoVolver"
            OnClientClick="closeWindow(); return false;" />
    </div>

</div>'''

    return util.render(plantilla, {
        'SINGULAR': e.singular,
        'CLASE': e.clase_formulario,
        'SRC_TAB': e.src_control_tab,
        'TAB': e.tab,
        'TAG_TABSTRIP': p.controles['tabstrip'],
        'TAG_TAB': p.controles['tab'],
        'TAG_MULTIPAGE': p.controles['multipage'],
        'TAG_PAGEVIEW': p.controles['pageview'],
        'TAG_BOTON': p.controles['boton'],
    })


# ===========================================================================
# 4. FORMULARIO .ascx.cs
# ===========================================================================
def formulario_cs(d):
    e = d.entidad

    plantilla = r'''using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

/// <summary>
/// CODE-BEHIND DEL CONTENEDOR DE TABS DE {{TABLA}}.
///
/// PATRON (ver PATRON_MVC.md seccion 5):
///  - Este archivo es intencionalmente MINIMO.
///  - No carga datos, no guarda, no llama al Controller.
///  - Solo declara las propiedades publicas y se las pasa a los tabs hijos.
///
/// Regla para el equipo: si estas escribiendo logica de negocio aqui,
/// esa logica va en el tab ({{TAB}}.ascx.cs) o en el Controller.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class {{CLASE}} : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    /// <summary>0 = alta de un registro nuevo. > 0 = edicion de uno existente.</summary>
    public int Id{{SINGULAR}}
    {
        get { return ViewState["Id{{SINGULAR}}"] == null ? 0 : (int)ViewState["Id{{SINGULAR}}"]; }
        set { ViewState["Id{{SINGULAR}}"] = value; }
    }

    public string URLVolver{{SINGULAR}}
    {
        get { return ViewState["URLVolver{{SINGULAR}}"] == null ? "" : ViewState["URLVolver{{SINGULAR}}"].ToString(); }
        set { ViewState["URLVolver{{SINGULAR}}"] = value; }
    }

    #endregion

    /// <summary>
    /// Propaga el estado a los tabs. Se hace en PreRender para que los valores
    /// que la pagina padre seteo en su Page_Load ya esten disponibles.
    /// </summary>
    protected void Page_PreRender(object sender, EventArgs e)
    {
        wuc{{TAB}}.ReadOnly = ReadOnly;
        wuc{{TAB}}.Id{{SINGULAR}} = Id{{SINGULAR}};

        // Si en el futuro se agregan tabs, se les pasan las mismas
        // propiedades aqui y nada mas cambia.
    }
}'''

    return util.render(plantilla, {
        'TABLA': e.tabla,
        'CLASE': e.clase_formulario,
        'SINGULAR': e.singular,
        'TAB': e.tab,
    })


# ===========================================================================
# 5. TAB .ascx
# ===========================================================================
def tab_ascx(d):
    e = d.entidad
    p = d.proyecto

    campos = [_campo_markup(d, c) for c in d.columnas_formulario]
    campos = [c for c in campos if c]

    script_password = ''
    if d.columnas_password:
        script_password = r'''

<script type="text/javascript">
    function togglePasswordVisibility(inputId, icono) {
        var input = document.getElementById(inputId);
        if (input.type === "password") {
            input.type = "text";
            icono.classList.replace("fa-eye", "fa-eye-slash");
        } else {
            input.type = "password";
            icono.classList.replace("fa-eye-slash", "fa-eye");
        }
    }
</script>'''

    plantilla = r'''<%--
    USERCONTROL DE TAB / SUB-FORMULARIO - {{TAB}}.ascx  ({{TABLA}})

    PATRON (ver PATRON_MVC.md seccion 6 y PATRON_CONTROLES.md secciones 5 y 6):
      - Todo el contenido va dentro de un asp:UpdatePanel UpdateMode="Conditional".
      - Layout con la grilla Bootstrap de 12 columnas.
      - Se usan SIEMPRE los controles propios del proyecto, nunca los nativos.
      - Cada campo obligatorio lleva su asp:CustomValidator con
        ClientValidationFunction="validaControl" y el MISMO ValidationGroup
        que el boton Guardar.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="{{TAB}}.ascx.cs" Inherits="{{CLASE}}" %>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

        <div class="row col-lg-12 col-md-12 col-xs-12">

{{CAMPOS}}

        </div>

        <div class="row col-lg-12 col-md-12 col-xs-12" style="text-align: right;">
            <%-- ValidationGroup DEBE coincidir con el de todos los CustomValidator. --%>
            <{{TAG_BOTON}} ID="btnGuardar" runat="server" Text="Guardar"
                CssClass="Button IcoGuardar"
                OnClick="btnGuardar_Click"
                ValidationGroup="{{SINGULAR}}" />
        </div>

    </ContentTemplate>
</asp:UpdatePanel>{{SCRIPT_PASSWORD}}'''

    return util.render(plantilla, {
        'TAB': e.tab,
        'TABLA': e.tabla,
        'CLASE': e.clase_tab,
        'CAMPOS': '\n\n'.join(campos),
        'TAG_BOTON': p.controles['boton'],
        'SINGULAR': e.singular,
        'SCRIPT_PASSWORD': script_password,
    })


# ===========================================================================
# 6. TAB .ascx.cs
# ===========================================================================
def _asignar_desde_modelo(d, var, indent):
    pad = ' ' * indent
    l = []
    for c in d.columnas_formulario:
        prop = '%s.%s' % (var, c.prop)
        if c.control in ('texto', 'textarea'):
            l.append(pad + '%s.Text = %s;' % (c.control_id, prop))
        elif c.control == 'numero':
            cast = '(double)' if c.tipo.categoria == 'decimal' else ''
            l.append(pad + '%s.Value = %s%s;' % (c.control_id, cast, prop))
        elif c.control == 'combo':
            l.append(pad + '%s.SelectedValue = %s.ToString();' % (c.control_id, prop))
        elif c.control == 'check':
            l.append(pad + '%s.Checked = %s;' % (c.control_id, prop))
        elif c.control == 'fecha':
            l.append(pad + '%s.SelectedDate = %s;' % (c.control_id, prop))
        elif c.control == 'password':
            l.append('')
            l.append(pad + '// La password NUNCA se rellena: viaja vacia y solo se')
            l.append(pad + '// actualiza si el usuario escribe una nueva.')
            l.append(pad + '%s.Text = string.Empty;' % c.control_id)
    return '\n'.join(l)


def _limpiar(d, indent):
    pad = ' ' * indent
    l = []
    for c in d.columnas_formulario:
        if c.control in ('texto', 'textarea', 'password'):
            l.append(pad + '%s.Text = string.Empty;' % c.control_id)
        elif c.control == 'numero':
            l.append(pad + '%s.Value = null;' % c.control_id)
        elif c.control == 'combo':
            l.append(pad + '%s.SelectedValue = "";' % c.control_id)
        elif c.control == 'check':
            valor = 'true' if (c is d.col_habilitado or c.defecto in (1, '1', True)) else 'false'
            l.append(pad + '%s.Checked = %s;' % (c.control_id, valor))
        elif c.control == 'fecha':
            l.append(pad + '%s.SelectedDate = null;' % c.control_id)
    return '\n'.join(l)


def _bloqueo(d, indent):
    pad = ' ' * indent
    l = []
    for c in d.columnas_formulario:
        if c.control in ('texto', 'textarea', 'numero', 'combo'):
            l.append(pad + '%s.ReadOnly = ReadOnly;' % c.control_id)
    l.append('')
    for c in d.columnas_formulario:
        if c.control in ('check', 'fecha'):
            l.append(pad + '%s.Enabled = !ReadOnly;' % c.control_id)
    for c in d.columnas_formulario:
        if c.control == 'password':
            l.append(pad + '// En Password se usa Enabled, no ReadOnly (ver comentario del .ascx).')
            l.append(pad + '%s.Enabled = !ReadOnly;' % c.control_id)
    l.append('')
    l.append(pad + 'btnGuardar.Visible = !ReadOnly;')
    return '\n'.join(x for x in l)


def _armar_modelo(d, var, indent):
    e = d.entidad
    pad = ' ' * indent
    l = [pad + '%s.%s = Id%s;' % (var, e.id_prop, e.singular)]
    for c in d.columnas_formulario:
        destino = '%s.%s' % (var, c.prop)
        if c.control in ('texto', 'textarea', 'password'):
            l.append(pad + '%s = %s.Text.Trim();' % (destino, c.control_id))
        elif c.control == 'numero':
            tipo = {'entero': 'int', 'largo': 'long', 'decimal': 'decimal'}[c.tipo.categoria]
            l.append(pad + '%s = %s.Value.HasValue ? (%s)%s.Value.Value : 0;'
                     % (destino, c.control_id, tipo, c.control_id))
        elif c.control == 'combo':
            if c.requerido:
                l.append(pad + '%s = int.Parse(%s.SelectedValue);' % (destino, c.control_id))
            else:
                l.append(pad + '%s = string.IsNullOrEmpty(%s.SelectedValue) ? 0 : int.Parse(%s.SelectedValue);'
                         % (destino, c.control_id, c.control_id))
        elif c.control == 'check':
            l.append(pad + '%s = %s.Checked;' % (destino, c.control_id))
        elif c.control == 'fecha':
            l.append(pad + '%s = %s.SelectedDate;' % (destino, c.control_id))
    return '\n'.join(l)


def _load_controls(d, indent):
    pad = ' ' * indent
    bloques = []
    for c in d.columnas_combo:
        fk = c.fk
        nombre_var = util.camel(c.nombre)
        if fk.filtro_habilitado == 'bool':
            filtro = '%s filtro%s = new %s { filtro_habilitado = true };' % (
                fk.modelo, util.pascal(c.nombre), fk.modelo)
            arg = 'filtro%s' % util.pascal(c.nombre)
        elif fk.filtro_habilitado == 'string':
            filtro = '%s filtro%s = new %s { filtro_habilitado = "1" };' % (
                fk.modelo, util.pascal(c.nombre), fk.modelo)
            arg = 'filtro%s' % util.pascal(c.nombre)
        else:
            filtro = None
            arg = ''

        lineas = [pad + 'case "%s":' % c.control_id, '']
        lineas.append(pad + '    %s %sController = new %s();' % (fk.controller, nombre_var, fk.controller))
        if filtro:
            lineas.append(pad + '    ' + filtro)
        lineas.append('')
        lineas.append(pad + '    // El item vacio se agrega ANTES del DataBind')
        lineas.append(pad + '    // y se conserva gracias a AppendDataBoundItems.')
        lineas.append(pad + '    ctrl.Items.Add(new RadComboBoxItem("Seleccione...", ""));')
        lineas.append(pad + '    ctrl.AppendDataBoundItems = true;')
        lineas.append(pad + '    ctrl.DataSource = %sController.%s(%s);' % (nombre_var, fk.metodo_lista, arg))
        lineas.append(pad + '    ctrl.DataValueField = "%s";   // debe existir en el Model' % fk.prop_valor)
        lineas.append(pad + '    ctrl.DataTextField = "%s";' % fk.prop_texto)
        lineas.append(pad + '    ctrl.DataBind();')
        lineas.append(pad + '    break;')
        bloques.append('\n'.join(lineas))
    return '\n\n'.join(bloques)


def tab_cs(d):
    e = d.entidad
    p = d.proyecto
    var = util.camel(e.singular)

    # Region de combos: solo si hay alguno.
    region_combos = ''
    if d.columnas_combo:
        region_combos = util.render(r'''
    #region CARGA DE COMBOS

    /// <summary>
    /// Un unico metodo atiende a TODOS los combos del control.
    /// Se engancha desde el markup con OnLoad="LoadControls" y se
    /// desambigua con switch (ctrl.ID).
    ///
    /// El !IsPostBack es clave: sin el, el combo se recargaria en cada
    /// postback y perderia la seleccion del usuario.
    /// </summary>
    public void LoadControls(object sender, EventArgs e)
    {
        if (!IsPostBack)
        {
            if (sender is RadComboBox2)
            {
                RadComboBox2 ctrl = (RadComboBox2)sender;

                switch (ctrl.ID)
                {
{{CASES}}
                }
            }
        }
    }

    #endregion
''', {'CASES': _load_controls(d, 20)})

    # Validaciones extra de negocio (password obligatoria en el alta).
    validaciones = []
    for c in d.columnas_password:
        validaciones.append(
            '            // 2. Validaciones de negocio que el CustomValidator no cubre.\n'
            '            if (Id%s == 0 && string.IsNullOrEmpty(%s.%s))\n'
            '            {\n'
            '                Tools.tools.ClientAlert("Debe ingresar %s para el registro nuevo.", "alerta");\n'
            '                return;\n'
            '            }\n'
            % (e.singular, var, c.prop, util.sin_acentos(c.etiqueta).lower()))

    plantilla = r'''using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using Telerik.Web.UI;
using {{NS_MODEL}};
using {{NS_CONTROLLER}};
using SitioBase;

/// <summary>
/// CODE-BEHIND DEL TAB / SUB-FORMULARIO DE {{TABLA}}.
///
/// Aqui vive el CRUD real de la pantalla. Siempre los mismos metodos:
///
///   LoadControls()     -> puebla los combos (una sola vez, en !IsPostBack).
///   CargarDatos()      -> si Id{{SINGULAR}} > 0 trae el registro y llena los controles.
///   Bloqueo()          -> aplica ReadOnly a cada control.
///   btnGuardar_Click() -> arma el Model desde los controles y llama Insert/Update.
///
/// PATRON (ver PATRON_MVC.md seccion 6):
///  - Nunca se llama a la BD desde aqui: siempre a traves del Controller.
///  - El "alta vs edicion" se decide con un solo if: Id{{SINGULAR}} > 0.
///  - Todo va envuelto en try/catch que termina en Tools.tools.ClientAlert.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class {{CLASE}} : System.Web.UI.UserControl
{
    #region PROPIEDADES

    public bool ReadOnly
    {
        get { return ViewState["ReadOnly"] == null ? false : (bool)ViewState["ReadOnly"]; }
        set { ViewState["ReadOnly"] = value; }
    }

    public int Id{{SINGULAR}}
    {
        get { return ViewState["Id{{SINGULAR}}"] == null ? 0 : (int)ViewState["Id{{SINGULAR}}"]; }
        set { ViewState["Id{{SINGULAR}}"] = value; }
    }

    #endregion

    #region CICLO DE VIDA

    protected void Page_PreRender(object sender, EventArgs e)
    {
        CargarDatos();
        Bloqueo();

        // Sin esta linea el boton Guardar NO dispara postback dentro del UpdatePanel.
        ScriptManager.GetCurrent(Page).RegisterPostBackControl(btnGuardar);

        udPanel.Update();
    }

    #endregion
{{REGION_COMBOS}}
    #region CARGA Y BLOQUEO

    /// <summary>
    /// Modo edicion -> trae el registro y llena los controles.
    /// Modo alta    -> limpia todo.
    /// </summary>
    protected void CargarDatos()
    {
        if (IsPostBack) return;

        if (Id{{SINGULAR}} > 0)
        {
            {{CLASE_CONTROLLER}} {{VAR}}Controller = new {{CLASE_CONTROLLER}}();
            {{CLASE_MODEL}} {{VAR}} = {{VAR}}Controller.Get{{SINGULAR}}(new {{CLASE_MODEL}} { {{ID_PROP}} = Id{{SINGULAR}} });

            if ({{VAR}} == null) return;

{{ASIGNAR}}
        }
        else
        {
{{LIMPIAR}}
        }
    }

    /// <summary>
    /// Un unico lugar donde se aplica el modo consulta.
    /// ReadOnly en los controles del proyecto renderiza un span con el valor
    /// y oculta el input: no se puede editar ni por inspector.
    /// </summary>
    protected void Bloqueo()
    {
{{BLOQUEO}}
    }

    #endregion

    #region GUARDAR

    /// <summary>
    /// Unico punto de escritura de la pantalla.
    /// Secuencia: armar Model -> validar -> Insert o Update -> avisar.
    /// </summary>
    protected void btnGuardar_Click(object sender, EventArgs e)
    {
        try
        {
            // 1. Armar el Model desde los controles.
            {{CLASE_MODEL}} {{VAR}} = new {{CLASE_MODEL}}();
{{ARMAR}}

{{VALIDACIONES}}            // {{PASO}}. Insert o Update segun el modo.
            {{CLASE_CONTROLLER}} {{VAR}}Controller = new {{CLASE_CONTROLLER}}();
            Respuesta respuesta;

            if (Id{{SINGULAR}} > 0)
                respuesta = {{VAR}}Controller.Update{{SINGULAR}}({{VAR}});
            else
                respuesta = {{VAR}}Controller.Insert{{SINGULAR}}({{VAR}});

            // {{PASO_AVISO}}. Avisar. En el alta guardamos el id devuelto para que
            //    el siguiente Guardar sea un Update y no otro Insert.
            if (!respuesta.error)
            {
                Id{{SINGULAR}} = respuesta.codigo;
                Tools.tools.ClientAlert(respuesta.detalle, "ok", true);
            }
            else
            {
                Tools.tools.ClientAlert(respuesta.detalle, "alerta");
            }
        }
        catch (Exception ex)
        {
            Tools.tools.ClientAlert(ex.ToString(), "error");
        }
    }

    #endregion
}'''

    return util.render(plantilla, {
        'NS_MODEL': p.ns_model,
        'NS_CONTROLLER': p.ns_controller,
        'TABLA': e.tabla,
        'CLASE': e.clase_tab,
        'SINGULAR': e.singular,
        'CLASE_CONTROLLER': e.clase_controller,
        'CLASE_MODEL': e.clase_model,
        'VAR': var,
        'ID_PROP': e.id_prop,
        'REGION_COMBOS': region_combos,
        'ASIGNAR': _asignar_desde_modelo(d, var, 12),
        'LIMPIAR': _limpiar(d, 12),
        'BLOQUEO': _bloqueo(d, 8),
        'ARMAR': _armar_modelo(d, var, 12),
        'VALIDACIONES': ('\n'.join(validaciones) + '\n') if validaciones else '',
        'PASO': 3 if validaciones else 2,
        'PASO_AVISO': 4 if validaciones else 3,
    })
