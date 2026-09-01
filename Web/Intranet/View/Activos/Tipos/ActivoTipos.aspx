<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoTipos.aspx.cs" Inherits="View_Activos_Tipos_ActivoTipos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirActivoTipo(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Activos/Tipos/ActivoTipo.aspx") %>?query=' + query);
            oWin.show();
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
    Tipos de activo
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    La jerarquía con que se clasifican los equipos.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-6 col-md-6 col-xs-12 d-flex align-items-center"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="820" Height="520" />

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus tipos de activo.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrTipos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="ati_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="abrirActivoTipo(0)" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja los tipos seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
