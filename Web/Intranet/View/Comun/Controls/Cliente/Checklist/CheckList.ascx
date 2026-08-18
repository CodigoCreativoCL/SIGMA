<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Checklist.ascx.cs" Inherits="View_Comun_Controls_Cliente_Checklist_Checklist" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>


<script type="text/javascript">
    function abrir(query) {
        var oWin = $find("<%=rwiDetalle.ClientID %>");
        oWin.setUrl('<%=ResolveUrl("~/View/Comun/Clientes/Checklist/NuevoCheckList.aspx") %>?query=' + query);
        oWin.show();

    }

    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>

<rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />
<div class="row col-lg-12 col-md-12 col-xs-12">
    <div class="col-lg-12 col-md-12 col-xs-12">
        <div class="SubTitulos">Checklist</div>
        <wuc:Filtro runat="server" ID="wucFiltro">
            <FiltroPersonalizado>
                <div class="container-fluid mt-2">
                    <div class="row">
                        <div class="col-lg-2 col-md-2 col-xs-12">
                            <label>Habilitado:</label>
                        </div>
                        <div class="col-lg-6 col-md-6 col-xs-12">
                            <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="100%" MarkFirstMatch="true" AutoPostBack="true">
                                <Items>
                                    <rad:RadComboBoxItem Text="Seleccione" Value="" />
                                    <rad:RadComboBoxItem Text="Si" Value="1" />
                                    <rad:RadComboBoxItem Text="No" Value="0" />
                                </Items>
                            </rad:RadComboBox2>
                        </div>
                        <div class="col-lg-4 col-md-4 col-xs-12">
                        </div>
                    </div>
                </div>
            </FiltroPersonalizado>
        </wuc:Filtro>
    </div>
    <div class="col-lg-12 col-md-12 col-xs-12">
        <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
            <ContentTemplate>

                <rad:RadGrid2 ID="Grid" runat="server" Width="100%" OnItemDataBound="Grid_ItemDataBound">
                    <MasterTableView CommandItemDisplay="Top" DataKeyNames="chk_id">
                        <CommandItemTemplate>
                            <div>
                                <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClick="lnkNuevo_Click" />
                                <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                    OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
                            </div>
                        </CommandItemTemplate>
                    </MasterTableView>
                </rad:RadGrid2>
            </ContentTemplate>
        </asp:UpdatePanel>
    </div>
</div>
