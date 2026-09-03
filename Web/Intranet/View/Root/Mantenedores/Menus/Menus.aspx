<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Menus.aspx.cs" Inherits="View_Root_Mantenedores_Menus" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirMenu(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Root/Mantenedores/Menus/Menu.aspx") %>?query=' + query,
                title: 'Menu',
                width: 1000,
                initialHeight: 560
            });
        }

        function abrirFunciones(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Root/Mantenedores/Menus/MenuFuncion.aspx") %>?query=' + query,
                title: 'Menu funcion',
                width: 1000,
                initialHeight: 520
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Mantenedor de Menus
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <p style="margin: 0 0 10px 0;">
                    Cada página del sitio se autoriza por su propia URL contra este árbol.
                    Una página sin fila aquí no se puede abrir, y una página sin permiso
                    asociado solo la ve el perfil Root.
                </p>
            </div>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="mnu_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="abrirMenu(0); return false;" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
