<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PrivacidadesModuloSistema.aspx.cs" Inherits="View_Root_PrivacidadModuloSistema_PrivacidadesModuloSistema" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPrivacidad(query) {
            return SigmaModal.open({
                url: '<%= ResolveUrl("~/View/Root/PrivacidadModuloSistema/NuevaPrivacidadModuloSistema.aspx") %>?query=' + encodeURIComponent(query));
            oWin.set_title(!query ? 'Nueva Política de Privacidad' : 'Editar Política de Privacidad',
                title: 'Nueva privacidad modulo sistema',
                width: 1000,
                initialHeight: 380
            });
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
