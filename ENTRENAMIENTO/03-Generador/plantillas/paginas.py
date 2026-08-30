# -*- coding: utf-8 -*-
"""Generacion de las paginas .aspx y sus code-behind - PATRON_MVC.md seccion 7."""

from nucleo import util


# ===========================================================================
# 1. PAGINA DE LISTADO .aspx
# ===========================================================================
def listado_aspx(d):
    e = d.entidad
    p = d.proyecto

    plantilla = r'''<%--
    PAGINA DE LISTADO - {{PLURAL}}.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - La pagina casi no tiene HTML propio: hereda el Master y coloca
        el UserControl de listado dentro del placeholder cphBody.
      - Su unica responsabilidad real esta en el code-behind: validar
        permisos y setear las propiedades de seguridad del UserControl.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="{{MASTER}}" AutoEventWireup="true"
    CodeFile="{{PLURAL}}.aspx.cs" Inherits="{{CLASE}}" %>

<%@ Register Src="{{SRC_CONTROL}}" TagPrefix="wuc" TagName="{{PLURAL}}" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    {{TITULO}}
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <%-- URLNuevo{{SINGULAR}} se pasa como ruta relativa con ~: el UserControl
         la resuelve con ResolveUrl para que funcione en cualquier carpeta. --%>
    <wuc:{{PLURAL}} ID="wuc{{PLURAL}}" runat="server"
        URLNuevo{{SINGULAR}}="{{URL_FORMULARIO}}" />

</asp:Content>'''

    return util.render(plantilla, {
        'PLURAL': e.plural,
        'SINGULAR': e.singular,
        'MASTER': p.master,
        'CLASE': e.clase_pagina_listado,
        'SRC_CONTROL': e.src_control_listado,
        'TITULO': e.titulo_listado,
        'URL_FORMULARIO': e.url_pagina_formulario,
    })


# ===========================================================================
# 2. PAGINA DE LISTADO .aspx.cs
# ===========================================================================
def listado_aspx_cs(d):
    e = d.entidad

    asignaciones = ['    wuc{{PLURAL}}.Ver_Todo = (int)SitioBase.Paginas.{{MENU}}.Ver_Todo;']
    if e.seguridad_por_pais:
        asignaciones.append('    wuc{{PLURAL}}.VerTodoPaises = (int)SitioBase.Paginas.{{MENU}}.Ver_Todo_Paises;')
    asignaciones.append('    wuc{{PLURAL}}.Crear_Editar = (int)SitioBase.Paginas.{{MENU}}.Crear_Editar;')

    plantilla = r'''using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE LISTADO DE {{TABLA}}.
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
public partial class {{CLASE}} : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina

        // {{MENU}} es el identificador del menu de {{TITULO}} en SitioBase.Paginas.
        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.{{MENU}}.Ver;

        // Si el perfil no tiene el permiso, este metodo corta la ejecucion.
        SitioBase.Token.SecurityManagerVer(ver);

        #endregion

        // Se le pasan al UserControl los ids de funcion que necesita para
        // decidir que puede mostrar.
{{ASIGNACIONES}}
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
        // Se deja declarado aunque este vacio: es parte del esqueleto estandar.
    }
}'''

    cuerpo = util.render(plantilla, {
        'TABLA': e.tabla,
        'CLASE': e.clase_pagina_listado,
        'MENU': e.menu,
        'TITULO': e.titulo_listado,
        'ASIGNACIONES': '\n'.join(asignaciones),
    })
    # Segunda pasada: los tokens que quedaron dentro de ASIGNACIONES.
    return util.render(cuerpo, {'PLURAL': e.plural, 'MENU': e.menu})


# ===========================================================================
# 3. PAGINA DE FORMULARIO .aspx
# ===========================================================================
def formulario_aspx(d):
    e = d.entidad
    p = d.proyecto

    plantilla = r'''<%--
    PAGINA DE FORMULARIO - {{SINGULAR}}.aspx

    PATRON (ver PATRON_MVC.md seccion 7):
      - Misma estructura que la pagina de listado, pero coloca el UserControl
        de FORMULARIO y ademas lee el querystring CIFRADO que le mando el grid.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Page Language="C#" MasterPageFile="{{MASTER}}" AutoEventWireup="true"
    CodeFile="{{SINGULAR}}.aspx.cs" Inherits="{{CLASE}}" %>

<%@ Register Src="{{SRC_CONTROL}}" TagPrefix="wuc" TagName="{{SINGULAR}}" %>

<asp:Content ID="Content1" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="Content2" ContentPlaceHolderID="chpScript" runat="server">
</asp:Content>

<asp:Content ID="Content3" ContentPlaceHolderID="cphTitulo" runat="server">
    {{TITULO}}
</asp:Content>

<asp:Content ID="Content4" ContentPlaceHolderID="cphFiltro" runat="server">
</asp:Content>

<asp:Content ID="Content5" ContentPlaceHolderID="cphBody" runat="server">

    <wuc:{{SINGULAR}} ID="wuc{{SINGULAR}}" runat="server"
        URLVolver{{SINGULAR}}="{{URL_LISTADO}}" />

</asp:Content>'''

    return util.render(plantilla, {
        'SINGULAR': e.singular,
        'MASTER': p.master,
        'CLASE': e.clase_pagina_formulario,
        'SRC_CONTROL': e.src_control_formulario,
        'TITULO': e.titulo_formulario,
        'URL_LISTADO': e.url_pagina_listado,
    })


# ===========================================================================
# 4. PAGINA DE FORMULARIO .aspx.cs
# ===========================================================================
def formulario_aspx_cs(d):
    e = d.entidad

    plantilla = r'''using System;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using SitioBase;

/// <summary>
/// CODE-BEHIND DE LA PAGINA DE FORMULARIO DE {{TABLA}}.
///
/// Hace exactamente dos cosas:
///   1. Valida el permiso de entrada (igual que la pagina de listado).
///   2. DESCIFRA el querystring que armo el grid y pasa los valores al UserControl.
///
/// Por que se cifra el querystring?
///   Si la URL fuera {{SINGULAR}}.aspx?Id{{SINGULAR}}=5, cualquiera podria escribir
///   otro numero y abrir la ficha ajena. Con Tools.Crypto el parametro es opaco.
///
/// ARCHIVO GENERADO por 03-Generador.
/// </summary>
public partial class {{CLASE}} : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        #region SeguridadPagina

        MenuPerfil ver = new MenuPerfil();
        ver.mpe_menu = (int)SitioBase.Paginas.{{MENU}}.Ver;
        SitioBase.Token.SecurityManagerVer(ver);

        #endregion

        if (!IsPostBack)
        {
            // El grid navega a: {{SINGULAR}}.aspx?query=<cadena cifrada>
            if (!string.IsNullOrEmpty(Request.QueryString["query"]))
            {
                // 1. Descifrar -> "Id{{SINGULAR}}=5&ReadOnly=False"
                string parametros = Tools.Crypto.Decrypt(Request.QueryString["query"]);

                // 2. Parsear el string en pares clave=valor.
                foreach (string par in parametros.Split('&'))
                {
                    string[] kv = par.Split('=');
                    if (kv.Length != 2) continue;

                    switch (kv[0])
                    {
                        case "Id{{SINGULAR}}":
                            int id;
                            if (int.TryParse(kv[1], out id))
                                wuc{{SINGULAR}}.Id{{SINGULAR}} = id;
                            break;

                        case "ReadOnly":
                            bool ro;
                            if (bool.TryParse(kv[1], out ro))
                                wuc{{SINGULAR}}.ReadOnly = ro;
                            break;
                    }
                }
            }

            // Sin query -> alta de un registro nuevo (Id{{SINGULAR}} queda en 0).

            // Refuerzo de seguridad: si el perfil no tiene Crear/Editar,
            // el formulario se abre siempre en modo consulta.
            MenuFuncion crearEditar = new MenuFuncion();
            crearEditar.mfu_funcion = (int)SitioBase.Paginas.{{MENU}}.Crear_Editar;

            if (!SitioBase.Token.SecurityManager(crearEditar))
                wuc{{SINGULAR}}.ReadOnly = true;
        }
    }

    protected void Page_PreRender(object sender, EventArgs e)
    {
    }
}'''

    return util.render(plantilla, {
        'TABLA': e.tabla,
        'CLASE': e.clase_pagina_formulario,
        'SINGULAR': e.singular,
        'MENU': e.menu,
    })
