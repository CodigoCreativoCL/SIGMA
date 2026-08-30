<%@ page language="C#" masterpagefile="~/Master/Default.master" autoeventwireup="true" inherits="View_Root_ModulosSistema_ModulosSistema, App_Web_ejfbsunh" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirModulo(query) {
            var oWin = $find("<%= rwiDetalle.ClientID %>");
            if (!query) query = '';
            oWin.setUrl('<%= ResolveUrl("~/View/Root/ModulosSistema/NuevoModuloSistema.aspx") %>?query=' + encodeURIComponent(query));
            oWin.set_title(!query ? 'Nuevo Módulo' : 'Editar Módulo');
            oWin.show();
        }
        function refreshModulos() {
            __doPostBack('<%= Grid.ClientID %>', '');
        }
    </script>
</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Modulos del Sistema
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-3 col-md-3 col-sm-6 mb-2">
                    <label>Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" Selected="true" />
                            <rad:RadComboBoxItem Text="Sí" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>

</asp:Content>
<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="mds_id">
                    <CommandItemTemplate>
                        <div class="contenedor-botones">
                            <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="icono_guardar" OnClientClick="abrirModulo(''); return false;" Text="Nuevo" ToolTip="Nuevo módulo" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="icono_eliminar" OnClick="lnkEliminar_Click" Text="Eliminar"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro de que desea eliminar el o los registros seleccionados?');"
                                ToolTip="Eliminar" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
