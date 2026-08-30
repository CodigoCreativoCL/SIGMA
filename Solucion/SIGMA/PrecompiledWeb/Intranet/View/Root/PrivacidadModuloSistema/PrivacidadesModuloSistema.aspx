<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Root_PrivacidadModuloSistema_PrivacidadesModuloSistema, App_Web_jfnkgi2u" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPrivacidad(query) {
            var oWin = $find("<%= rwiDetalle.ClientID %>");
            if (!query) query = '';
            oWin.setUrl('<%= ResolveUrl("~/View/Root/PrivacidadModuloSistema/NuevaPrivacidadModuloSistema.aspx") %>?query=' + encodeURIComponent(query));
            oWin.set_title(!query ? 'Nueva Política de Privacidad' : 'Editar Política de Privacidad');
            oWin.show();
        }
        function refreshPrivacidades() {
            __doPostBack('<%= Grid.ClientID %>', '');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Privacidad Módulos del Sistema
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="pms_id">
                    <CommandItemTemplate>
                        <div class="contenedor-botones">
                            <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="icono_guardar"
                                OnClientClick="abrirPrivacidad(''); return false;"
                                Text="Nuevo" ToolTip="Nueva política de privacidad" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="icono_eliminar"
                                OnClick="lnkEliminar_Click" Text="Eliminar"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro de que desea eliminar el o los registros seleccionados?');"
                                ToolTip="Eliminar" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
