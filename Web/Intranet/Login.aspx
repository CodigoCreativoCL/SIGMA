<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Login.aspx.cs" Inherits="Login" %>

<!DOCTYPE html>
<html lang="es-CL">
<head runat="server">
    <meta charset="utf-8" />
    <title>Ingresar · SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <meta name="theme-color" content="#070A14" />

    <!-- Favicon de marca -->
    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />

    <!-- SweetAlert: lo usa Tools.tools.ClientAlert -->
    <link href="Css/SweetAlert/sweetalert.css" rel="stylesheet" />
    <link href="Css/SweetAlert/sweetalert2.min.css" rel="stylesheet" />

    <!-- SIGMA: pantalla de acceso (rediseño cinematográfico) -->
    <link href="Css/Login/sigma-landing.css?vrs=1" rel="stylesheet" />
    <link href="Css/Login/sigma-login.css?vrs=2" rel="stylesheet" />

    <script src="Js/jquery-1.9.1.js"></script>
    <script src="Css/SweetAlert/sweetalert2.min.js"></script>
    <script src="Js/Library.js"></script>
    <script src="Js/gsap/gsap.min.js" defer></script>
    <script src="Js/Login/sigma-login.js?vrs=1" type="module"></script>
</head>
<body style="margin: 0">
    <form id="form" runat="server" autocomplete="on" novalidate="novalidate">
        <asp:ScriptManager ID="ScriptManagerPrincipal" runat="server" />

        <div id="lg-root" class="sg" style="font-family: 'Sora', 'Segoe UI', system-ui, sans-serif; color: #17223B; background: #F4F6FA; position: relative">
            <div class="lg-film" aria-hidden="true"></div>
            <main class="lg">

                <!-- ---------- Panel de marca ---------- -->
                <section class="lg-brand" aria-label="SIGMA">
                    <canvas id="lg-gl" class="lg-gl" aria-hidden="true"></canvas>
                    <div class="sg-grain" aria-hidden="true"></div>
                    <a class="lg-logo lg-in" href="Inicio.aspx" aria-label="SIGMA, volver al inicio"><img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA" width="157" height="52" /></a>
                    <div class="lg-copy">
                        <h1><span class="sg-line"><span>Mantenimiento</span></span><span class="sg-line"><span class="sg-grad">bajo control.</span></span></h1>
                        <p class="lg-in">Órdenes de trabajo, activos, checklists, inventario e indicadores en un solo lugar. Del escritorio a la planta, y de vuelta.</p>
                        <ul class="lg-points lg-in">
                            <li><span class="sg-mono">01</span>Trabajo planificado y correctivo en un mismo flujo</li>
                            <li><span class="sg-mono">02</span>Registro en terreno, incluso sin cobertura</li>
                            <li><span class="sg-mono">03</span><img src="Imagen/sigma-ai/sigma-ai-logo-horizontal-dark.svg" alt="SIGMA AI" width="66" height="18" />voz, predicción de fallas y recomendaciones</li>
                            <li><span class="sg-mono">04</span><img src="Imagen/sigma-twin/sigma-twin-logo-horizontal-dark.svg" alt="SIGMA Twin" width="72" height="18" />tu bodega en 3D</li>
                        </ul>
                        <a class="lg-news lg-in" href="Inicio.aspx#spots">
                            <span class="lg-news-thumb"><img src="Imagen/landing/poster-twin.jpg" alt="" width="108" height="61" /><i><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><polygon points="7 4 20 12 7 20 7 4"></polygon></svg></i></span>
                            <span><span class="sg-mono" style="color: #16C6C9">Nuevo</span><b>Conoce SIGMA Twin en 30 segundos</b><small>Mira el spot en la página de inicio</small></span>
                        </a>
                    </div>
                    <div class="lg-brand-foot lg-in">
                        <span class="sg-mono">SIGMA · 2026</span>
                        <img src="Imagen/landing/codigo-creativo-logo.png" alt="Código Creativo" width="63" height="30" />
                    </div>
                </section>

                <!-- ---------- Panel del formulario ---------- -->
                <section class="lg-side" aria-labelledby="lg-t">
                    <div class="lg-top">
                        <a class="lg-back" href="Inicio.aspx"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 19 5 12 12 5"></polyline></svg>Volver al inicio</a>
                        <span class="sg-mono" style="color: #68738A">Acceso seguro</span>
                    </div>

                    <asp:Panel ID="pnlLogin" runat="server" CssClass="lg-card" DefaultButton="btnLogin">
                        <div>
                            <h2 id="lg-t">Ingresar</h2>
                        </div>
                        <p>Usa las credenciales de tu cuenta SIGMA.</p>

                        <asp:Panel ID="pnlError" runat="server" CssClass="sg-alert sg-alert-danger" role="alert" Visible="false">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg><asp:Literal ID="litError" runat="server" />
                        </asp:Panel>

                        <div class="lg-field" id="lgFieldCorreo">
                            <asp:Label ID="lblCorreo" runat="server" AssociatedControlID="txtCorreo" Text="Correo" />
                            <div class="lg-input-wrap">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="2" y="4" width="20" height="16" rx="2"></rect><polyline points="22 6 12 13 2 6"></polyline></svg>
                                <asp:TextBox ID="txtCorreo" runat="server" TextMode="Email" CssClass="sg-input"
                                    placeholder="nombre@empresa.cl" autocomplete="username" required="required"
                                    aria-required="true" aria-invalid="false" aria-describedby="lgCorreoErr" />
                            </div>
                            <span id="lgCorreoErr" class="sg-err" hidden></span>
                        </div>

                        <div class="lg-field" id="lgFieldPass">
                            <asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" Text="Contraseña" />
                            <div class="lg-input-wrap">
                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
                                <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" CssClass="sg-input"
                                    placeholder="Tu contraseña" autocomplete="current-password" required="required"
                                    aria-required="true" aria-invalid="false" aria-describedby="lgPassErr lgCaps" style="padding-right: 52px" />
                                <button type="button" class="lg-eye" id="lgEye" aria-label="Mostrar contraseña" aria-pressed="false">
                                    <svg id="lgEyeOff" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" hidden><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"></path><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"></path><line x1="1" y1="1" x2="23" y2="23"></line></svg>
                                    <svg id="lgEyeOn" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle></svg>
                                </button>
                            </div>
                            <span id="lgPassErr" class="sg-err" hidden></span>
                            <span id="lgCaps" class="lg-caps" role="status" hidden>Bloq Mayús está activado</span>
                        </div>

                        <div class="lg-row">
                            <label class="lg-remember" for="chkRecordar"><input id="chkRecordar" type="checkbox" />Recordar mi correo</label>
                            <asp:HyperLink ID="lnkRecuperar" runat="server" CssClass="lg-link"
                                NavigateUrl="~/RecuperarClave.aspx" Text="Olvidé mi contraseña" />
                        </div>

                        <asp:LinkButton ID="btnLogin" runat="server" OnClick="btnLogin_Click" CssClass="sg-btn sg-btn-primary sg-btn-block lg-submit"
                            OnClientClick="return window.sgLoginValidar ? window.sgLoginValidar() : true;" role="button"><span id="lgSubmitSpin" class="sg-spin" aria-hidden="true" hidden></span><span id="lgSubmitTxt">Iniciar sesión</span><svg id="lgSubmitArrow" class="sg-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg></asp:LinkButton>

                        <p class="lg-help">¿Problemas para entrar? Contacta al administrador de tu planta.</p>
                        <p class="lg-secure"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>Conexión cifrada · la sesión se cierra sola por inactividad</p>
                    </asp:Panel>

                    <div class="lg-foot"><span>© 2026 Código Creativo · SIGMA</span><a class="lg-link" href="Inicio.aspx#asesoria">¿Aún no tienes SIGMA? Pide una demo</a></div>
                </section>
            </main>
        </div>
    </form>
</body>
</html>
