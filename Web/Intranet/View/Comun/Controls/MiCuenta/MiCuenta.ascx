<%@ Control Language="C#" AutoEventWireup="true" CodeFile="MiCuenta.ascx.cs" Inherits="View_Comun_Controls_MiCuenta_MiCuenta" %>

<script type="text/javascript">
    function previsualizarFoto(input) {
        if (input.files && input.files[0]) {
            var reader = new FileReader();
            reader.onload = function (e) {
                document.getElementById('<%= imgFoto.ClientID %>').src = e.target.result;
            };
            reader.readAsDataURL(input.files[0]);
        }
    }

    function validarCorreoMiCuenta() {
        var txtCorreo = $('#<%= txtCorreo.ClientID %>');
        if (txtCorreo.val() != "" && !ValidaEmail(txtCorreo.val())) {
            AlertSweet('', 'Formato de correo invalido', 'alerta');
        }
    }

    function togglePasswordVisibility(inputId, icono) {
        var input = document.getElementById(inputId);
        if (!input) return;

        if (input.type === "password") {
            input.type = "text";
            icono.classList.remove("fa-eye");
            icono.classList.add("fa-eye-slash");
        } else {
            input.type = "password";
            icono.classList.remove("fa-eye-slash");
            icono.classList.add("fa-eye");
        }
    }

    function toggleCambiarPassword(checkbox) {
        var contenedor = document.getElementById('<%= pnlCambiarPassword.ClientID %>');
        if (!contenedor) return;

        if (checkbox.checked) {
            contenedor.classList.add("is-open");
        } else {
            contenedor.classList.remove("is-open");
        }
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <div class="cliente-container identidad-card mb-3">
            <div class="cliente-label">
                <i class="fas fa-user-circle"></i>
                <span>Información Personal</span>
            </div>

            <div class="row col-12">
                <div class="col-lg-3 col-md-3 col-xs-12 identidad-avatar-col identidad-avatar-col-divider">
                    <div class="identidad-avatar">
                        <div class="identidad-avatar-placeholder">
                            <i class="fas fa-user"></i>
                        </div>
                        <asp:Image ID="imgFoto" runat="server" CssClass="identidad-avatar-img" />
                        <asp:Panel ID="pnlFoto" runat="server" CssClass="identidad-avatar-upload">
                            <i class="fas fa-camera"></i>
                            <asp:FileUpload ID="fldFoto" runat="server" CssClass="identidad-avatar-input" onchange="previsualizarFoto(this)" />
                        </asp:Panel>
                    </div>
                    <div class="identidad-avatar-caption">
                        <span>Foto de Perfil</span>
                        <small>(.jpg, .png)</small>
                    </div>
                </div>

                <div class="col-lg-9 col-md-9 col-xs-12">
                    <div class="row col-12">
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Correo(*):</label>
                            <WebControls:TextBox2 ID="txtCorreo" runat="server" MaxLength="200" onblur="validarCorreoMiCuenta()" />
                            <asp:CustomValidator ID="cvCorreo" runat="server"
                                ControlToValidate="txtCorreo"
                                ValidateEmptyText="true"
                                ClientValidationFunction="validaControl"
                                ValidationGroup="MiCuenta" />
                        </div>
                        <div class="form-group col-lg-6 col-md-6 col-xs-12 identidad-field">
                            <label>Teléfono</label>
                            <div class="identidad-field-icon">
                                <i class="fas fa-phone"></i>
                                <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="20" />
                            </div>
                        </div>
                    </div>

                    <div class="identidad-section-divider">
                        <span>Datos de la cuenta</span>
                    </div>

                    <div class="identidad-readonly-grid">
                        <div class="identidad-readonly-item">
                            <label>Usuario</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblUsuario" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item">
                            <label>ID Usuario</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblId" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item">
                            <label>Identificador</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblIdentificador" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item">
                            <label>Nombre</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblNombre" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item">
                            <label>Apellido Paterno</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblApellidoPaterno" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item">
                            <label>Apellido Materno</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblApellidoMaterno" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item identidad-readonly-item-wide">
                            <label>Nombre Completo</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblNombreCompleto" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item">
                            <label>País</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblPais" runat="server"></asp:Label>
                            </div>
                        </div>
                        <div class="identidad-readonly-item identidad-readonly-item-wide">
                            <label>Perfil / Rol</label>
                            <div class="identidad-readonly-chip-sm">
                                <asp:Label ID="lblPerfil" runat="server"></asp:Label>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <asp:Panel ID="pnlClientes" runat="server" CssClass="cliente-container identidad-card identidad-card-cliente mb-3" Visible="false">
            <div class="cliente-label">
                <i class="fas fa-building"></i>
                <span>Clientes e Instalaciones Asociadas</span>
            </div>

            <div class="identidad-clientes-list">
                <asp:Repeater ID="rptClientes" runat="server" OnItemDataBound="rptClientes_ItemDataBound">
                    <ItemTemplate>
                        <div class="identidad-cliente-card">
                            <div class="identidad-cliente-header">
                                <span class="identidad-cliente-id">#<%# Eval("cli_id") %></span>
                                <span class="identidad-cliente-nombre"><%# Eval("cli_nombre") %></span>
                            </div>
                            <div class="identidad-instalaciones-tags">
                                <asp:Repeater ID="rptInstalacionesCliente" runat="server">
                                    <ItemTemplate>
                                        <span class="identidad-tag">
                                            <i class="fas fa-map-marker-alt"></i>
                                            <%# Eval("Value") %>
                                        </span>
                                    </ItemTemplate>
                                </asp:Repeater>
                                <asp:Panel ID="pnlSinInstalaciones" runat="server" CssClass="identidad-tag identidad-tag-empty">
                                    <span>Sin instalaciones asociadas</span>
                                </asp:Panel>
                            </div>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </asp:Panel>

        <div class="cliente-container identidad-card mb-3">
            <div class="cliente-label cliente-label-actions">
                <div class="cliente-label-titulo">
                    <i class="fas fa-lock"></i>
                    <span>Seguridad</span>
                </div>
                <div class="identidad-switch-row">
                    <span>Cambiar contraseña</span>
                    <label class="identidad-switch">
                        <asp:CheckBox ID="chkCambiarPassword" runat="server" onclick="toggleCambiarPassword(this)" />
                        <span class="identidad-switch-slider"></span>
                    </label>
                </div>
            </div>

            <div class="row col-12">
                <div class="form-group col-lg-4 col-md-6 col-xs-12 identidad-field">
                    <label>Contraseña Actual</label>
                    <div class="identidad-password-field">
                        <WebControls:TextBox2 ID="txtPasswordVer" runat="server" TextMode="Password" Enabled="false" />
                        <i class="fas fa-eye identidad-password-toggle" onclick="togglePasswordVisibility('<%= txtPasswordVer.ClientID %>', this)"></i>
                    </div>
                </div>
            </div>

            <asp:Panel ID="pnlCambiarPassword" runat="server" CssClass="identidad-collapse">
                <div class="row col-12">
                    <div class="form-group col-lg-4 col-md-6 col-xs-12 identidad-field">
                        <label>Contraseña Actual(*):</label>
                        <div class="identidad-password-field">
                            <WebControls:TextBox2 ID="txtPasswordActual" runat="server" TextMode="Password" MaxLength="100" />
                            <i class="fas fa-eye identidad-password-toggle" onclick="togglePasswordVisibility('<%= txtPasswordActual.ClientID %>', this)"></i>
                        </div>
                    </div>
                    <div class="form-group col-lg-4 col-md-6 col-xs-12 identidad-field">
                        <label>Nueva Contraseña(*):</label>
                        <div class="identidad-password-field">
                            <WebControls:TextBox2 ID="txtPasswordNueva" runat="server" TextMode="Password" MaxLength="100" />
                            <i class="fas fa-eye identidad-password-toggle" onclick="togglePasswordVisibility('<%= txtPasswordNueva.ClientID %>', this)"></i>
                        </div>
                    </div>
                    <div class="form-group col-lg-4 col-md-6 col-xs-12 identidad-field">
                        <label>Confirmar Contraseña(*):</label>
                        <div class="identidad-password-field">
                            <WebControls:TextBox2 ID="txtPasswordConfirmar" runat="server" TextMode="Password" MaxLength="100" />
                            <i class="fas fa-eye identidad-password-toggle" onclick="togglePasswordVisibility('<%= txtPasswordConfirmar.ClientID %>', this)"></i>
                            <asp:CompareValidator ID="cvPasswordConfirmar" runat="server"
                                ControlToValidate="txtPasswordConfirmar"
                                ControlToCompare="txtPasswordNueva"
                                Operator="Equal"
                                ErrorMessage="Las contraseñas no coinciden."
                                Display="Dynamic"
                                ValidationGroup="MiCuenta" />
                        </div>
                    </div>
                </div>
            </asp:Panel>
        </div>

        <div class="identidad-actions">
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="MiCuenta" />
        </div>
    </ContentTemplate>
</asp:UpdatePanel>
