<%--
    USERCONTROL DE LISTADO (GRID) - Clientes.ascx

    PATRON (ver PATRON_MVC.md seccion 4 y PATRON_CONTROLES.md seccion 1):
      - El listado NUNCA vive en el .aspx: vive en un UserControl reutilizable.
      - El grid va SIEMPRE dentro de un asp:UpdatePanel UpdateMode="Conditional".
      - Los botones de accion van en el CommandItemTemplate.
      - La navegacion al formulario usa un querystring CIFRADO.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Clientes.ascx.cs" Inherits="View_Comun_Controls_Cliente_Clientes" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>

<script type="text/javascript">

    // Abre el formulario de Cliente. 'query' llega ya cifrado desde el code-behind.
    function abrirCliente(query) {
        window.location = ('<%=ResolveUrl(URLNuevoCliente) %>?query=' + query);
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

        <rad:RadGrid2 ID="Grid" runat="server"
            OnItemDataBound="rgrClientes_ItemDataBound">

            <%-- DataKeyNames: columnas que luego se leen con GetDataKeyValue(...) --%>
            <MasterTableView CommandItemDisplay="Top" DataKeyNames="cli_id">

                <CommandItemTemplate>
                    <div style="margin-bottom: 5px;">

                        <%-- Solo navega por JS: no necesita OnClick de servidor --%>
                        <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo"
                            CssClass="icono_guardar"
                            OnClientClick="abrirCliente(0)" />

                        <%-- ConfirSweetAlert devuelve false si el usuario cancela:
                             el "return" evita el postback y por lo tanto el OnClick. --%>
                        <asp:LinkButton ID="lnkDeshabilitar" runat="server" Text="Deshabilitar"
                            CssClass="icono_eliminar"
                            OnClick="lnkDeshabilitar_Click"
                            OnClientClick="return ConfirSweetAlert(this, '', 'Esta seguro que desea deshabilitar los registros seleccionados?');" />

                    </div>
                </CommandItemTemplate>

            </MasterTableView>

        </rad:RadGrid2>

    </ContentTemplate>
</asp:UpdatePanel>
