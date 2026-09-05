<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Activos.aspx.cs" Inherits="View_Activos_Activos_Activos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirActivo(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Activos/Activo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo activo' : 'Editar activo',
                width: 1060,
                initialHeight: 620
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Activos
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Activos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Las máquinas y equipos del cliente.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <label for="cboArea" style="display:block; margin:0 0 4px;">Área:</label>
                    <rad:RadComboBox2 ID="cboArea" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <label for="cboLinea" style="display:block; margin:0 0 4px;">Línea:</label>
                    <rad:RadComboBox2 ID="cboLinea" runat="server" Width="100%" AutoPostBack="true" />
                </div>
            </div>
            <div class="row col-lg-12 col-md-12 col-xs-12" style="margin-top:10px;">
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <label for="cboHabilitado" style="display:block; margin:0 0 4px;">Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus activos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrActivos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="act_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirActivo(0);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja los activos seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
