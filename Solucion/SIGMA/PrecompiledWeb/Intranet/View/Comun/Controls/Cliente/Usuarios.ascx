<%@ control language="C#" autoeventwireup="true" inherits="View_Comun_Controls_Cliente_Usuarios, App_Web_ggf4pkqo" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>
<%@ Register Src="~/View/Comun/Controls/PanelSinSeleccion.ascx" TagPrefix="wuc" TagName="PanelSinSeleccion" %>
<script type="text/javascript">
    function abrirUsuario(query) {
        var oWin = $find("<%=rwiDetalle.ClientID %>");
        oWin.setUrl('<%=ResolveUrl("~/View/Comun/Clientes/NuevoUsuario.aspx") %>?query=' + query);
        oWin.show();
    }

    function asociarUsuario(query) {
        var oWin = $find("<%=rwiDetalle.ClientID %>");
        oWin.setUrl('<%=ResolveUrl("~/View/Comun/Clientes/AsociarUsuario.aspx") %>?query=' + query);
        oWin.show();
    }

    function cargaMasiva(query) {
        var oWin = $find("<%=rwiDetalle.ClientID %>");
        oWin.setUrl('<%=ResolveUrl("~/View/Comun/Clientes/CargaMasivaUsuarios.aspx") %>?query=' + query);
        oWin.show();
    }


    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>

<rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1000" Height="380" />

<asp:UpdatePanel runat="server" ID="udPanelContenedor" UpdateMode="Conditional">
    <ContentTemplate>
        <wuc:PanelSinSeleccion runat="server" ID="wucPanelSinSeleccion" Icono="mdi mdi-account-group-outline" Titulo="Seleccione un cliente"
            Descripcion="Para administrar los usuarios, primero seleccione un cliente en el panel superior." />

        <asp:Panel runat="server" ID="pnlContenido">
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-12 col-md-12 col-xs-12">
                    <wuc:Filtro runat="server" ID="wucFiltro">
                        <FiltroPersonalizado>
                            <div class="container-fluid mt-2">
                                <div class="row">
                                    <div class="col-lg-3 col-md-3 col-xs-12">
                                        <div class="col-lg-2 col-md-2 col-xs-12">
                                            <label>Habilitado:</label>
                                        </div>
                                        <div class="col-lg-2 col-md-2 col-xs-12">
                                            <rad:RadComboBox2 ID="cboHabilitado" runat="server" MarkFirstMatch="true">
                                                <Items>
                                                    <rad:RadComboBoxItem Text="Seleccione" Value="" />
                                                    <rad:RadComboBoxItem Text="Si" Value="1" />
                                                    <rad:RadComboBoxItem Text="No" Value="0" />
                                                </Items>
                                            </rad:RadComboBox2>
                                        </div>
                                    </div>
                                    <div class="col-lg-3 col-md-3 col-xs-12" runat="server" id="cboTipoPanel" visible="false">
                                        <div class="col-lg-2 col-md-2 col-xs-12">
                                            <label>Tipo:</label>
                                        </div>
                                        <div class="col-lg-2 col-md-2 col-xs-12">
                                            <rad:RadComboBox2 ID="cboTipo" runat="server">
                                                <Items>
                                                    <rad:RadComboBoxItem Text="Seleccione..." Value="0" />
                                                    <rad:RadComboBoxItem Text="Sistema" Value="1" />
                                                    <rad:RadComboBoxItem Text="Cliente" Value="2" />
                                                </Items>
                                            </rad:RadComboBox2>
                                        </div>
                                    </div>
                                    <div class="col-lg-3 col-md-3 col-xs-12">
                                        <div class="col-lg-2 col-md-2 col-xs-12">
                                            <label>Perfiles:</label>
                                        </div>
                                        <div class="col-lg-2 col-md-2 col-xs-12">
                                            <rad:RadComboBox2 ID="cboPerfiles" runat="server" OnLoad="LoadControls" MarkFirstMatch="true" EnableLoadOnDemand="true" Filter="Contains" />
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </FiltroPersonalizado>

                    </wuc:Filtro>
                </div>
                <div class="col-lg-12 col-md-12 col-xs-12">
                    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
                        <ContentTemplate>
                            <asp:UpdatePanel runat="server" ID="UpdatePanel1" UpdateMode="Conditional">
                                <ContentTemplate>
                                    <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                                        <MasterTableView CommandItemDisplay="Top" DataKeyNames="usu_id">
                                            <CommandItemTemplate>
                                                <div style="margin-bottom: 5px;">
                                                    <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClick="lnkNuevoUsuario_Click" Visible="false" />
                                                    <asp:LinkButton ID="lnkDeshabilitar" runat="server" Text="Habilitar / Deshabilitar" CssClass="icono_eliminar" OnClick="lnkDeshabilitar_Click"
                                                        OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea habilitar/deshabilitar los registros seleccionados?');" Visible="false" />

                                                    <asp:LinkButton ID="lnkCargaMasiva" runat="server" Text="Carga Masiva" CssClass="icono_carga_masiva" OnClick="lnkCargaMasiva_Click" Visible="false" />


                                                    <asp:LinkButton ID="lnkAsociar" runat="server" Text="Asociar" CssClass="icono_guardar" OnClick="lnkAsociar_Click" Visible="false" />
                                                    <asp:LinkButton ID="lnkDesasociar" runat="server" Text="Desasociar" CssClass="icono_eliminar" OnClick="lnkDesasociar_Click"
                                                        OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desasociar los registros seleccionados?');" Visible="false" />


                                                </div>
                                            </CommandItemTemplate>
                                        </MasterTableView>
                                    </rad:RadGrid2>
                                </ContentTemplate>
                            </asp:UpdatePanel>

                        </ContentTemplate>
                    </asp:UpdatePanel>
                </div>
            </div>
        </asp:Panel>
    </ContentTemplate>
</asp:UpdatePanel>
