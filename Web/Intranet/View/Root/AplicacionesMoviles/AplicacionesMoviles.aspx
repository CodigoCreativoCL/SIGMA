<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="AplicacionesMoviles.aspx.cs" Inherits="View_Root_AplicacionesMoviles_AplicacionesMoviles" %>

<asp:Content ID="cntHeader" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="cntScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirApp(query) {
            var oWin = $find("<%= rwiApp.ClientID %>");
            if (!query) query = '';
            oWin.setUrl('<%= ResolveUrl("~/View/Root/AplicacionesMoviles/NuevaAplicacionMovil.aspx") %>?query=' + encodeURIComponent(query));
            oWin.set_title(!query ? 'Nueva Aplicación' : 'Editar Aplicación');
            oWin.show();
        }
        function abrirVersiones(query) {
            var oWin = $find("<%= rwiVersiones.ClientID %>");
            oWin.setUrl('<%= ResolveUrl("~/View/Root/AplicacionesMoviles/AplicacionMovilVersiones.aspx") %>?query=' + encodeURIComponent(query));
            oWin.set_title('Versiones');
            oWin.show();
        }
        function refreshApps() {
            __doPostBack('<%= Grid.ClientID %>', '');
        }
    </script>
</asp:Content>

<asp:Content ID="cntTitulo" ContentPlaceHolderID="cphTitulo" runat="server">
    Aplicaciones Móviles
</asp:Content>

<asp:Content ID="cntBody" ContentPlaceHolderID="cphBody" runat="server">
    <rad:RadWindow2 ID="rwiApp"       runat="server" Title="Aplicación" Width="700" Height="560" />
    <rad:RadWindow2 ID="rwiVersiones" runat="server" Title="Versiones"  Width="1000" Height="620" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="app_id">
                    <CommandItemTemplate>
                        <div class="contenedor-botones">
                            <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="icono_guardar" Text="Nueva App"
                                OnClientClick="abrirApp(''); return false;" ToolTip="Nueva Aplicación" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="icono_eliminar" Text="Habilitar / Deshabilitar"
                                OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Habilitar / Deshabilitar las aplicaciones seleccionadas?');"
                                ToolTip="Habilitar / Deshabilitar" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
