<%@ Control Language="C#" AutoEventWireup="true" CodeFile="MiCuenta.ascx.cs" Inherits="View_Comun_Controls_MiCuenta_MiCuenta" %>

<script type="text/javascript">
    function previsualizarFoto(input) {
        if (input.files && input.files[0]) {
            var reader = new FileReader();
            reader.onload = function (e) {
                var img = document.getElementById('<%= imgFoto.ClientID %>');
                img.src = e.target.result;
                img.classList.add('has-foto');
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

        /* classList.add/remove no admiten clases con espacios: se cambia una por una. */
        if (input.type === "password") {
            input.type = "text";
            icono.classList.remove("mdi-eye-outline");
            icono.classList.add("mdi-eye-off-outline");
        } else {
            input.type = "password";
            icono.classList.remove("mdi-eye-off-outline");
            icono.classList.add("mdi-eye-outline");
        }
    }

    function toggleCambiarPassword(checkbox) {
        var contenedor = document.getElementById('<%= pnlCambiarPassword.ClientID %>');
        if (!contenedor) return;
        contenedor.classList.toggle("is-open", checkbox.checked);
    }
</script>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>
        <div class="sg-mc">

            <%-- ---- Información personal ---- --%>
            <div class="card-box sg-mc-card">
                <h3 class="sg-mc-tit"><i class="mdi mdi-account-circle-outline"></i> Información personal</h3>

                <div class="sg-mc-persona">
                    <div class="sg-mc-avatar-col">
                        <div class="sg-mc-avatar">
                            <i class="mdi mdi-account-outline sg-mc-avatar-ph"></i>
                            <asp:Image ID="imgFoto" runat="server" CssClass="sg-mc-avatar-img" AlternateText="Foto de perfil" />
                            <asp:Panel ID="pnlFoto" runat="server" CssClass="sg-mc-avatar-subir" ToolTip="Cambiar foto">
                                <i class="mdi mdi-camera-outline"></i>
                                <asp:FileUpload ID="fldFoto" runat="server" CssClass="sg-mc-avatar-input" onchange="previsualizarFoto(this)" />
                            </asp:Panel>
                        </div>
                        <span class="sg-mc-avatar-cap">Foto de perfil <small>(.jpg, .png)</small></span>
                    </div>

                    <div class="sg-mc-persona-datos">
                        <div class="sg-mc-campos">
                            <div class="sg-mc-campo">
                                <label>Correo (*)</label>
                                <WebControls:TextBox2 ID="txtCorreo" runat="server" MaxLength="200" onblur="validarCorreoMiCuenta()" />
                                <asp:CustomValidator ID="cvCorreo" runat="server"
                                    ControlToValidate="txtCorreo"
                                    ValidateEmptyText="true"
                                    ClientValidationFunction="validaControl"
                                    ValidationGroup="MiCuenta" />
                            </div>
                            <div class="sg-mc-campo">
                                <label>Teléfono</label>
                                <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="20" />
                            </div>
                        </div>

                        <h4 class="sg-mc-sub">Datos de la cuenta</h4>
                        <dl class="sg-mc-datos">
                            <div><dt>Usuario</dt><dd><asp:Label ID="lblUsuario" runat="server"></asp:Label></dd></div>
                            <div><dt>ID de usuario</dt><dd><asp:Label ID="lblId" runat="server"></asp:Label></dd></div>
                            <div><dt>Identificador</dt><dd><asp:Label ID="lblIdentificador" runat="server"></asp:Label></dd></div>
                            <div><dt>Nombre</dt><dd><asp:Label ID="lblNombre" runat="server"></asp:Label></dd></div>
                            <div><dt>Apellido paterno</dt><dd><asp:Label ID="lblApellidoPaterno" runat="server"></asp:Label></dd></div>
                            <div><dt>Apellido materno</dt><dd><asp:Label ID="lblApellidoMaterno" runat="server"></asp:Label></dd></div>
                            <div class="is-ancho"><dt>Nombre completo</dt><dd><asp:Label ID="lblNombreCompleto" runat="server"></asp:Label></dd></div>
                            <div><dt>País</dt><dd><asp:Label ID="lblPais" runat="server"></asp:Label></dd></div>
                            <div class="is-ancho"><dt>Perfil</dt><dd><asp:Label ID="lblPerfil" runat="server"></asp:Label></dd></div>
                        </dl>
                    </div>
                </div>
            </div>

            <%-- ---- Clientes y plantas ---- --%>
            <asp:Panel ID="pnlClientes" runat="server" CssClass="card-box sg-mc-card" Visible="false">
                <h3 class="sg-mc-tit"><i class="mdi mdi-office-building-outline"></i> Clientes y plantas asociadas</h3>

                <div class="sg-mc-clientes">
                    <asp:Repeater ID="rptClientes" runat="server" OnItemDataBound="rptClientes_ItemDataBound">
                        <ItemTemplate>
                            <div class="sg-mc-cliente">
                                <div class="sg-mc-cliente-cab">
                                    <span class="sg-mc-cliente-id">#<%# Eval("cli_id") %></span>
                                    <strong><%# Eval("cli_nombre") %></strong>
                                </div>
                                <div class="sg-mc-chips">
                                    <asp:Repeater ID="rptInstalacionesCliente" runat="server">
                                        <ItemTemplate>
                                            <span class="sg-mc-chip"><i class="mdi mdi-map-marker-outline"></i><%# Eval("Value") %></span>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                    <asp:Panel ID="pnlSinInstalaciones" runat="server" CssClass="sg-mc-chip is-vacio">
                                        <span>Sin plantas asociadas</span>
                                    </asp:Panel>
                                </div>
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </asp:Panel>

            <%-- ---- Seguridad ---- --%>
            <div class="card-box sg-mc-card">
                <div class="sg-mc-tit-fila">
                    <h3 class="sg-mc-tit"><i class="mdi mdi-lock-outline"></i> Seguridad</h3>
                    <div class="sg-mc-switch-fila">
                        <span>Cambiar contraseña</span>
                        <asp:CheckBox ID="chkCambiarPassword" runat="server" CssClass="sg-mc-switch" onclick="toggleCambiarPassword(this)" />
                    </div>
                </div>

                <div class="sg-mc-campos">
                    <div class="sg-mc-campo">
                        <label>Contraseña</label>
                        <div class="sg-mc-clave">
                            <WebControls:TextBox2 ID="txtPasswordVer" runat="server" TextMode="Password" Enabled="false" />
                            <i class="mdi mdi-eye-outline sg-mc-ojo" onclick="togglePasswordVisibility('<%= txtPasswordVer.ClientID %>', this)" title="Mostrar u ocultar"></i>
                        </div>
                    </div>
                </div>

                <asp:Panel ID="pnlCambiarPassword" runat="server" CssClass="sg-mc-colapso">
                    <div class="sg-mc-campos sg-mc-campos-3">
                        <div class="sg-mc-campo">
                            <label>Contraseña actual (*)</label>
                            <div class="sg-mc-clave">
                                <WebControls:TextBox2 ID="txtPasswordActual" runat="server" TextMode="Password" MaxLength="100" />
                                <i class="mdi mdi-eye-outline sg-mc-ojo" onclick="togglePasswordVisibility('<%= txtPasswordActual.ClientID %>', this)" title="Mostrar u ocultar"></i>
                            </div>
                        </div>
                        <div class="sg-mc-campo">
                            <label>Nueva contraseña (*)</label>
                            <div class="sg-mc-clave">
                                <WebControls:TextBox2 ID="txtPasswordNueva" runat="server" TextMode="Password" MaxLength="100" />
                                <i class="mdi mdi-eye-outline sg-mc-ojo" onclick="togglePasswordVisibility('<%= txtPasswordNueva.ClientID %>', this)" title="Mostrar u ocultar"></i>
                            </div>
                        </div>
                        <div class="sg-mc-campo">
                            <label>Confirmar contraseña (*)</label>
                            <div class="sg-mc-clave">
                                <WebControls:TextBox2 ID="txtPasswordConfirmar" runat="server" TextMode="Password" MaxLength="100" />
                                <i class="mdi mdi-eye-outline sg-mc-ojo" onclick="togglePasswordVisibility('<%= txtPasswordConfirmar.ClientID %>', this)" title="Mostrar u ocultar"></i>
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

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="btnGuardar" runat="server" CssClass="sigma-accion is-primaria" OnClick="btnGuardar_Click" ValidationGroup="MiCuenta">
                    <i class="mdi mdi-content-save-outline"></i><span>Guardar</span>
                </asp:LinkButton>
            </div>
        </div>
    </ContentTemplate>
</asp:UpdatePanel>
