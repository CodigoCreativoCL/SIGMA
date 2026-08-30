<%@ control language="C#" autoeventwireup="true" inherits="View_Comun_Controls_Cliente_Identidad, App_Web_ggf4pkqo" %>
<%@ Register Src="~/View/Comun/Controls/PanelSinSeleccion.ascx" TagPrefix="wuc" TagName="PanelSinSeleccion" %>

<script type="text/javascript">
    function previsualizarLogo(input) {
        if (input.files && input.files[0]) {
            var reader = new FileReader();
            reader.onload = function (e) {
                document.getElementById('<%= imgLogo.ClientID %>').src = e.target.result;
            };
            reader.readAsDataURL(input.files[0]);
        }
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <wuc:PanelSinSeleccion runat="server" ID="wucPanelSinSeleccion" Icono="mdi mdi-office-building" Titulo="Seleccione un cliente"
            Descripcion="Para ver la identidad del cliente, primero seleccione un cliente en el panel superior." />

        <asp:Panel runat="server" ID="pnlContenido" CssClass="cliente-container identidad-card">

            <div class="SubTitulos">Identidad</div>

            <div class="row col-12">
                <div class="col-lg-3 col-md-3 col-xs-12 identidad-avatar-col">
                    <div class="identidad-avatar">
                        <div class="identidad-avatar-placeholder">
                            <i class="mdi mdi-office-building"></i>
                        </div>
                        <asp:Image ID="imgLogo" runat="server" CssClass="identidad-avatar-img" />
                        <asp:Panel ID="pnlLogo" runat="server" CssClass="identidad-avatar-upload">
                            <i class="mdi mdi-camera-outline"></i>
                            <asp:FileUpload ID="fldLogo" runat="server" CssClass="identidad-avatar-input" onchange="previsualizarLogo(this)" />
                        </asp:Panel>
                    </div>
                    <div class="identidad-avatar-caption">
                        <span>Logo Corporativo</span>
                        <small>(.jpg, .png)</small>
                    </div>
                </div>

                <div class="col-lg-9 col-md-9 col-xs-12">
                    <div class="row col-12">
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>ID</label>
                            <div class="identidad-readonly-chip">
                                <asp:Label ID="lblId" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field identidad-field-spacer"></div>

                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Nombre(*):</label>
                            <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                            <asp:CustomValidator ID="CustomValidator3" runat="server"
                                ControlToValidate="txtNombre"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>País(*):</label>
                            <rad:RadComboBox2 ID="cboPais" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                                AutoPostBack="true" OnSelectedIndexChanged="cboPais_SelectedIndexChanged" />
                            <asp:CustomValidator ID="CustomValidator6" runat="server"
                                ControlToValidate="cboPais"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>

                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <%-- La etiqueta la pone el país: RUT en Chile, RUC en Perú,
                                 CUIT en Argentina. Antes decía siempre "Identificacion". --%>
                            <asp:Label ID="lblIdentificador" runat="server" AssociatedControlID="txtIdentificacion" Text="Identificación(*):" />
                            <WebControls:TextBox2 ID="txtIdentificacion" runat="server" MaxLength="200" />
                            <asp:CustomValidator ID="CustomValidator2" runat="server"
                                ControlToValidate="txtIdentificacion"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Razon Social(*):</label>
                            <WebControls:TextBox2 ID="txtRazonSocial" runat="server" MaxLength="200" />
                            <asp:CustomValidator ID="CustomValidator1" runat="server"
                                ControlToValidate="txtRazonSocial"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>

                        <%-- Campos que agrega HU-010. Todos salen de
                             catalogos del sistema y se leen por el registro
                             de catalogos, no con un controller por cada uno. --%>
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Nombre de fantasía:</label>
                            <WebControls:TextBox2 ID="txtNombreFantasia" runat="server" MaxLength="200" />
                        </div>

                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Zona horaria(*):</label>
                            <rad:RadComboBox2 ID="cboZonaHoraria" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                            <asp:CustomValidator ID="cvZonaHoraria" runat="server"
                                ControlToValidate="cboZonaHoraria"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>

                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Idioma(*):</label>
                            <rad:RadComboBox2 ID="cboIdioma" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                            <asp:CustomValidator ID="cvIdioma" runat="server"
                                ControlToValidate="cboIdioma"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>

                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Moneda(*):</label>
                            <rad:RadComboBox2 ID="cboMoneda" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                            <asp:CustomValidator ID="cvMoneda" runat="server"
                                ControlToValidate="cboMoneda"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="Cliente" />
                        </div>

                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Habilitado(*):</label>
                            <div class="identidad-radio-group">
                                <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Cliente" />
                                <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Cliente" />
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="identidad-actions">
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Cliente" />
            </div>
        </asp:Panel>
    </ContentTemplate>
</asp:UpdatePanel>
