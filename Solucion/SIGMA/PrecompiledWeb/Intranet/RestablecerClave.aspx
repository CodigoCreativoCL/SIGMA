<%@ page language="C#" autoeventwireup="true" inherits="RestablecerClave, App_Web_niiluyu0" %>

<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>Nueva contraseña · SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="theme-color" content="#0B0F1A" />

    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />

    <link href="Css/SweetAlert/sweetalert.css" rel="stylesheet" />
    <link href="Css/SweetAlert/sweetalert2.min.css" rel="stylesheet" />
    <link href="Css/Login/sigma-login.css?vrs=1" rel="stylesheet" />

    <script src="Js/jquery-1.9.1.js"></script>
    <script src="Css/SweetAlert/sweetalert2.min.js"></script>
    <script src="Js/Library.js"></script>
</head>
<body class="sg-login">
    <form id="form" runat="server" autocomplete="on">
        <asp:ScriptManager ID="ScriptManagerPrincipal" runat="server" />

        <div class="sg-login-layout">

            <aside class="sg-login-brand">
                <div class="sg-brand-logo">
                    <img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" />
                </div>

                <div class="sg-brand-copy">
                    <h1>Define tu contraseña nueva.</h1>
                    <p>
                        Al menos 8 caracteres, con una letra y un número.
                        No puede ser igual a ninguna de tus tres anteriores.
                    </p>
                </div>

                <div class="sg-brand-footer">
                    Código Creativo · SIGMA 2026
                </div>
            </aside>

            <main class="sg-login-form-panel">

                <%-- Enlace válido: se pide la contraseña nueva --%>
                <asp:Panel ID="pnlFormulario" runat="server" CssClass="sg-login-card" DefaultButton="btnGuardar">

                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>

                    <h2>Nueva contraseña</h2>
                    <p class="sg-sub">Elige una contraseña que no hayas usado antes.</p>

                    <asp:Panel ID="pnlError" runat="server" CssClass="sg-login-error" Visible="false">
                        <asp:Literal ID="litError" runat="server" />
                    </asp:Panel>

                    <div class="sg-field">
                        <asp:Label ID="lblClave" runat="server" AssociatedControlID="txtClave" Text="Contraseña nueva" />
                        <asp:TextBox ID="txtClave" runat="server" TextMode="Password"
                            autocomplete="new-password" MaxLength="100" />
                    </div>

                    <div class="sg-field">
                        <asp:Label ID="lblConfirmacion" runat="server" AssociatedControlID="txtConfirmacion" Text="Repetir contraseña" />
                        <asp:TextBox ID="txtConfirmacion" runat="server" TextMode="Password"
                            autocomplete="new-password" MaxLength="100" />
                    </div>

                    <asp:Button ID="btnGuardar" runat="server" OnClick="btnGuardar_Click"
                        CssClass="sg-btn-login" Text="Guardar contraseña" />
                </asp:Panel>

                <%-- Enlace vencido, usado o inexistente --%>
                <asp:Panel ID="pnlNoValido" runat="server" CssClass="sg-login-card" Visible="false">

                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>

                    <h2><asp:Literal ID="litTituloNoValido" runat="server" /></h2>
                    <p class="sg-sub"><asp:Literal ID="litMensajeNoValido" runat="server" /></p>

                    <p class="sg-login-foot">
                        <asp:HyperLink ID="lnkSolicitar" runat="server" NavigateUrl="~/RecuperarClave.aspx"
                            Text="Solicitar un enlace nuevo" />
                        &nbsp;·&nbsp;
                        <asp:HyperLink ID="lnkVolver" runat="server" NavigateUrl="~/Login.aspx" Text="Volver a ingresar" />
                    </p>
                </asp:Panel>

                <%-- Listo --%>
                <asp:Panel ID="pnlListo" runat="server" CssClass="sg-login-card" Visible="false">

                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>

                    <h2>Contraseña actualizada</h2>
                    <p class="sg-sub">Ya puedes ingresar a SIGMA con tu contraseña nueva.</p>

                    <p class="sg-login-foot">
                        <asp:HyperLink ID="lnkIngresar" runat="server" NavigateUrl="~/Login.aspx" Text="Ir a ingresar" />
                    </p>
                </asp:Panel>
            </main>

        </div>
    </form>
</body>
</html>
