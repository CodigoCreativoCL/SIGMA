<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Login.aspx.cs" Inherits="Login" %>

<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>Ingresar · SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="theme-color" content="#0B0F1A" />

    <!-- Favicon de marca -->
    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />

    <!-- SweetAlert: lo usa Tools.tools.ClientAlert -->
    <link href="Css/SweetAlert/sweetalert.css" rel="stylesheet" />
    <link href="Css/SweetAlert/sweetalert2.min.css" rel="stylesheet" />

    <!-- SIGMA: pantalla de acceso -->
    <link href="Css/Login/sigma-login.css?vrs=1" rel="stylesheet" />

    <script src="Js/jquery-1.9.1.js"></script>
    <script src="Css/SweetAlert/sweetalert2.min.js"></script>
    <script src="Js/Library.js"></script>
</head>
<body class="sg-login">
    <form id="form" runat="server" autocomplete="on">
        <asp:ScriptManager ID="ScriptManagerPrincipal" runat="server" />

        <div class="sg-login-layout">

            <!-- ---------- Panel de marca ---------- -->
            <aside class="sg-login-brand">
                <div class="sg-brand-logo">
                    <img src="Imagen/sigma-logo-horizontal-dark.svg"
                         alt="SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial" />
                </div>

                <div class="sg-brand-copy">
                    <h1>El mantenimiento industrial, bajo control.</h1>
                    <p>
                        Órdenes de trabajo, activos, checklists, inventario e indicadores
                        en un solo lugar. Del escritorio a la planta, y de vuelta.
                    </p>
                    <ul class="sg-brand-points">
                        <li>Trabajo planificado y correctivo en un mismo flujo</li>
                        <li>Registro en terreno, incluso sin cobertura</li>
                        <li>SIGMA AI para voz, predicción de fallas y recomendaciones</li>
                    </ul>
                </div>

                <div class="sg-brand-footer">
                    Código Creativo · SIGMA 2026
                </div>
            </aside>

            <!-- ---------- Panel del formulario ---------- -->
            <main class="sg-login-form-panel">
                <asp:Panel ID="pnlLogin" runat="server" CssClass="sg-login-card" DefaultButton="btnLogin">

                    <!-- Solo visible cuando el panel de marca se pliega -->
                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>

                    <h2>Ingresar</h2>
                    <p class="sg-sub">Usa las credenciales de tu cuenta SIGMA.</p>

                    <asp:Panel ID="pnlError" runat="server" CssClass="sg-login-error" Visible="false">
                        <asp:Literal ID="litError" runat="server" />
                    </asp:Panel>

                    <div class="sg-field">
                        <asp:Label ID="lblCorreo" runat="server" AssociatedControlID="txtCorreo" Text="Correo" />
                        <asp:TextBox ID="txtCorreo" runat="server" TextMode="SingleLine"
                            placeholder="nombre@empresa.cl" autocomplete="username" />
                    </div>

                    <div class="sg-field">
                        <asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" Text="Contraseña" />
                        <asp:TextBox ID="txtPassword" runat="server" TextMode="Password"
                            placeholder="Tu contraseña" autocomplete="current-password" />
                    </div>

                    <asp:Button ID="btnLogin" runat="server" OnClick="btnLogin_Click"
                        CssClass="sg-btn-login" Text="Iniciar sesión" />

                    <p class="sg-login-foot">
                        <asp:HyperLink ID="lnkRecuperar" runat="server"
                            NavigateUrl="~/RecuperarClave.aspx" Text="Olvidé mi contraseña" />
                        <br />
                        ¿Problemas para entrar? Contacta al administrador de tu planta.
                    </p>
                </asp:Panel>
            </main>

        </div>
    </form>
</body>
</html>
