<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoModelos.aspx.cs" Inherits="View_Activos_Modelos_ActivoModelos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirModelo(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Activos/Modelos/ActivoModelo.aspx") %>?query=' + query);
            oWin.show();
        }
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Activos</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Modelos de activo</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El catálogo de modelos (fabricante y modelo) que puede tener cada tipo de activo.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-5 col-md-6 col-xs-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboHabilitado" style="margin: 0; white-space: nowrap;">Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="200px">
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
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="820" Height="560" />

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus modelos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrModelos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="amo_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="abrirModelo(0)" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja los modelos seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
