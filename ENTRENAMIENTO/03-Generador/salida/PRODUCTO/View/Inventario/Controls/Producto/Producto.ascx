<%--
    USERCONTROL DE FORMULARIO (CONTENEDOR DE TABS) - Producto.ascx

    PATRON (ver PATRON_MVC.md seccion 5):
      - Este control NO tiene campos ni logica de guardado. Es solo el "marco":
        un TabStrip vertical + un MultiPage con un PageView por tab.
      - Cada tab es a su vez un UserControl independiente.
      - Su unica responsabilidad es propagar ReadOnly / IdProducto a los hijos.
      - Asi el formulario crece agregando tabs, sin tocar los existentes.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Producto.ascx.cs" Inherits="View_Inventario_Controls_Producto_Producto" %>
<%@ Register Src="~/View/Inventario/Controls/Producto/Identidad.ascx" TagPrefix="wuc" TagName="Identidad" %>

<script type="text/javascript">

    // Vuelve al listado. URLVolverProducto lo setea la pagina padre.
    function closeWindow() {
        window.location = ('<%=ResolveUrl(URLVolverProducto) %>');
    }

</script>

<div class="row col-lg-12 col-md-12 col-xs-12">

    <div class="col-lg-2 col-md-3 col-xs-12">
        <rad:RadTabStrip2 ID="tabProducto" runat="server"
            MultiPageID="mpProducto"
            Orientation="VerticalLeft"
            SelectedIndex="0">
            <Tabs>
                <rad:RadTab Text="Identidad" PageViewID="pvIdentidad" />
            </Tabs>
        </rad:RadTabStrip2>
    </div>

    <div class="col-lg-10 col-md-9 col-xs-12">
        <rad:RadMultiPage ID="mpProducto" runat="server" SelectedIndex="0" RenderSelectedPageOnly="false">

            <rad:RadPageView ID="pvIdentidad" runat="server">
                <wuc:Identidad ID="wucIdentidad" runat="server" />
            </rad:RadPageView>

        </rad:RadMultiPage>
    </div>

    <div class="col-lg-12 col-md-12 col-xs-12" style="text-align: right;">
        <%-- "return false" evita el postback: este boton solo navega. --%>
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Volver"
            CssClass="ButtonCerrar IcoVolver"
            OnClientClick="closeWindow(); return false;" />
    </div>

</div>
