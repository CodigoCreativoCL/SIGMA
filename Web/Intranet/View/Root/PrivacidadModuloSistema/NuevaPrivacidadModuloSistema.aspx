<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="NuevaPrivacidadModuloSistema.aspx.cs" Inherits="View_Root_PrivacidadModuloSistema_NuevaPrivacidadModuloSistema" %>

<asp:Content ID="contentHeader" ContentPlaceHolderID="cphHeder" runat="server">
    <style>
        .prv-audit fieldset { border: 1px solid #dee2e6; border-radius: 6px; padding: 14px 16px; }
        .prv-audit legend   { font-size: .85rem; font-weight: 600; width: auto; padding: 0 8px; color: #555; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var win = getRadWindow();
            if (win.BrowserWindow.refreshPrivacidades) win.BrowserWindow.refreshPrivacidades();
            win.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Política de Privacidad — Módulo del Sistema</div>

            <%-- ID (solo edición) --%>
            <div class="row col-lg-12 col-md-12 col-xs-12" id="divID" runat="server" visible="false">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>ID</label></div>
                <div class="col-lg-10 col-md-10 col-xs-10">
                    <asp:Label ID="lblID" runat="server" />
                </div>
            </div>

            <%-- Módulo del Sistema --%>
            <div class="row col-lg-12 col-md-12 col-xs-12 mt-2">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Módulo (*):</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <rad:RadComboBox2 ID="cboModulo" runat="server" Width="100%"
                        MarkFirstMatch="true" Filter="Contains" OnLoad="LoadControls" />
                    <asp:CustomValidator ID="cvModulo" runat="server"
                        ControlToValidate="cboModulo"
                        ValidateEmptyText="true"
                        ClientValidationFunction="validaControl"
                        ErrorMessage="Seleccione un módulo."
                        ValidationGroup="Privacidad" />
                </div>
            </div>

            <%-- Editor HTML --%>
            <div class="row col-lg-12 col-md-12 col-xs-12 mt-3">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Descripción (*):</label></div>
                <div class="col-lg-10 col-md-10 col-xs-12">
                    <WebControls:Editor ID="txtDescripcion" runat="server" Width="100%" Height="420px" />
                </div>
            </div>

            <%-- Auditoría --%>
            <asp:Panel ID="pnlAuditoria" runat="server" Visible="false" CssClass="prv-audit mt-3 col-lg-12">
                <fieldset>
                    <legend>Auditoría</legend>
                    <div class="row col-lg-12 col-md-12 col-xs-12">
                        <div class="col-lg-3 col-md-3 col-xs-12"><label>Creado por</label></div>
                        <div class="col-lg-9 col-md-9 col-xs-12">
                            <asp:Label ID="lblUsuarioCreacion" runat="server" />
                        </div>
                    </div>
                    <div class="row col-lg-12 col-md-12 col-xs-12">
                        <div class="col-lg-3 col-md-3 col-xs-12"><label>Fecha creación</label></div>
                        <div class="col-lg-9 col-md-9 col-xs-12">
                            <asp:Label ID="lblFechaCreacion" runat="server" />
                        </div>
                    </div>
                    <div class="row col-lg-12 col-md-12 col-xs-12">
                        <div class="col-lg-3 col-md-3 col-xs-12"><label>Actualizado por</label></div>
                        <div class="col-lg-9 col-md-9 col-xs-12">
                            <asp:Label ID="lblUsuarioAct" runat="server" />
                        </div>
                    </div>
                    <div class="row col-lg-12 col-md-12 col-xs-12">
                        <div class="col-lg-3 col-md-3 col-xs-12"><label>Fecha actualización</label></div>
                        <div class="col-lg-9 col-md-9 col-xs-12">
                            <asp:Label ID="lblFechaAct" runat="server" />
                        </div>
                    </div>
                </fieldset>
            </asp:Panel>

            <%-- Botones --%>
            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center mt-3">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
                    OnClick="btnGuardar_Click" ValidationGroup="Privacidad" />
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                    CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>
        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</asp:Content>
