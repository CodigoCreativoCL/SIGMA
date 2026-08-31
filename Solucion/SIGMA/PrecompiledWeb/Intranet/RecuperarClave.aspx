<%@ page language="C#" autoeventwireup="true" inherits="RecuperarClave, App_Web_bljzrotw" %>

<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>Recuperar contraseña · SIGMA</title>
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
                    <h1>Volvamos a dejarte trabajar.</h1>
                    <p>
                        Te enviamos un enlace a tu correo para que definas una contraseña nueva.
                        Sirve una sola vez y vence en 60 minutos.
                    </p>
                </div>

                <div class="sg-brand-footer">
                    Código Creativo · SIGMA 2026
                </div>
            </aside>

            <main class="sg-login-form-panel">
                <asp:Panel ID="pnlSolicitud" runat="server" CssClass="sg-login-card" DefaultButton="btnEnviar">

                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>

                    <h2>Recuperar contraseña</h2>
                    <p class="sg-sub">Indica el correo con el que ingresas a SIGMA.</p>

                    <asp:Panel ID="pnlError" runat="server" CssClass="sg-login-error" Visible="false">
                        <asp:Literal ID="litError" runat="server" />
                    </asp:Panel>

                    <div class="sg-field">
                        <asp:Label ID="lblCorreo" runat="server" AssociatedControlID="txtCorreo" Text="Correo electrónico" />
                        <asp:TextBox ID="txtCorreo" runat="server" TextMode="SingleLine"
                            placeholder="nombre@empresa.cl" autocomplete="username" MaxLength="200" />
                    </div>

                    <asp:Button ID="btnEnviar" runat="server" OnClick="btnEnviar_Click"
                        CssClass="sg-btn-login" Text="Enviarme el enlace" />

                    <p class="sg-login-foot">
                        <asp:HyperLink ID="lnkVolver" runat="server" NavigateUrl="~/Login.aspx" Text="Volver a ingresar" />
                    </p>
                </asp:Panel>

                <asp:Panel ID="pnlEnviado" runat="server" CssClass="sg-login-card" Visible="false">

                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>

                    <h2>Revisa tu correo</h2>
                    <p class="sg-sub"><asp:Literal ID="litMensaje" runat="server" /></p>

                    <p class="sg-login-foot">
                        <asp:HyperLink ID="lnkVolver2" runat="server" NavigateUrl="~/Login.aspx" Text="Volver a ingresar" />
                    </p>
                </asp:Panel>
            </main>

        </div>
    </form>
</body>
</html>
