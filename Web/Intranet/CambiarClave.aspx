<%@ Page Language="C#" AutoEventWireup="true" CodeFile="CambiarClave.aspx.cs" Inherits="CambiarClave" %>

<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>Crea tu contraseña · SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="robots" content="noindex" />
    <meta name="theme-color" content="#0B0F1A" />
    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />
    <link href="Css/Login/sigma-login.css?vrs=1" rel="stylesheet" />
    <%-- Diseño J del Centro Comercial (artefacto/J-Clave.dc.html): la misma
         cáscara del Login, con las reglas de la clave a la vista. --%>
    <style>
        .sg-cc-eyebrow{display:block;font-size:11px;font-weight:800;letter-spacing:.08em;color:#6732F4;margin-bottom:6px}
        .sg-cc-meter{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:-4px 0 14px}
        .sg-cc-meter span{height:5px;border-radius:999px;background:#E2E7F0;transition:background .15s}
        .sg-cc-reglas{list-style:none;margin:4px 0 18px;padding:0;display:flex;flex-direction:column;gap:6px}
        .sg-cc-reglas li{display:flex;align-items:center;gap:8px;font-size:13px;color:#68738A}
        .sg-cc-reglas li::before{content:"";width:14px;height:14px;border-radius:50%;border:2px solid #CFD6E3;box-sizing:border-box;flex:none}
        .sg-cc-reglas li.ok{color:#16855B;font-weight:700}
        .sg-cc-reglas li.ok::before{border-color:#16855B;background:#16855B;box-shadow:inset 0 0 0 2px #fff}
        .sg-cc-reglas li.srv{color:#68738A;font-style:italic}
        .sg-cc-ver{position:relative}
        .sg-cc-ver button{position:absolute;right:8px;top:50%;transform:translateY(-50%);border:0;background:transparent;color:#087BEA;font-weight:700;font-size:12px;cursor:pointer;padding:6px}
        .sg-btn-login[disabled]{opacity:.42;cursor:not-allowed}
        .sg-cc-salir{border:0;background:transparent;color:#087BEA;font:inherit;font-weight:700;cursor:pointer;padding:0;text-decoration:underline}
    </style>
</head>
<body class="sg-login">
    <form id="form" runat="server" autocomplete="off">
        <div class="sg-login-layout">
            <aside class="sg-login-brand">
                <div class="sg-brand-logo">
                    <img src="Imagen/sigma-logo-horizontal-dark.svg" alt="SIGMA · Sistema Integrado de Gestión de Mantenimiento Industrial" />
                </div>
                <div class="sg-brand-copy">
                    <h1>El mantenimiento industrial, bajo control.</h1>
                    <p>Órdenes de trabajo, activos, checklists, inventario e indicadores en un solo lugar. Del escritorio a la planta, y de vuelta.</p>
                    <ul class="sg-brand-points">
                        <li>Trabajo planificado y correctivo en un mismo flujo</li>
                        <li>Registro en terreno, incluso sin cobertura</li>
                        <li>SIGMA AI para voz, predicción de fallas y recomendaciones</li>
                    </ul>
                </div>
                <div class="sg-brand-footer">Código Creativo · SIGMA 2026</div>
            </aside>

            <main class="sg-login-form-panel">
                <asp:Panel ID="pnlClave" runat="server" CssClass="sg-login-card" DefaultButton="btnGuardar">
                    <div class="sg-login-logo-compact">
                        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
                    </div>
                    <span class="sg-cc-eyebrow">PRIMER INGRESO</span>
                    <h2>Crea tu contraseña</h2>
                    <p class="sg-sub">Entraste con la clave temporal que enviamos a <b><asp:Literal ID="litCorreo" runat="server" /></b>. Para seguir, reemplázala por una propia.</p>

                    <asp:Panel ID="pnlError" runat="server" CssClass="sg-login-error" Visible="false">
                        <asp:Literal ID="litError" runat="server" />
                    </asp:Panel>

                    <div class="sg-field">
                        <asp:Label ID="lblNueva" runat="server" AssociatedControlID="txtNueva" Text="Nueva contraseña" />
                        <span class="sg-cc-ver">
                            <asp:TextBox ID="txtNueva" runat="server" TextMode="Password" autocomplete="new-password" />
                            <button type="button" id="btnVer" aria-label="Mostrar u ocultar contraseña">Mostrar</button>
                        </span>
                    </div>
                    <div class="sg-cc-meter" aria-hidden="true"><span></span><span></span><span></span><span></span></div>

                    <div class="sg-field">
                        <asp:Label ID="lblRepite" runat="server" AssociatedControlID="txtRepite" Text="Repite la contraseña" />
                        <asp:TextBox ID="txtRepite" runat="server" TextMode="Password" autocomplete="new-password" placeholder="Escríbela otra vez" />
                    </div>

                    <ul class="sg-cc-reglas" aria-label="Requisitos" id="reglas">
                        <li data-r="largo">Al menos 10 caracteres</li>
                        <li data-r="caso">Una mayúscula y una minúscula</li>
                        <li data-r="num">Al menos un número</li>
                        <li data-r="sim">Al menos un símbolo (por ejemplo ! # $ %)</li>
                        <li class="srv">Distinta a la clave temporal (lo comprobamos al guardar)</li>
                        <li data-r="igual">Ambas contraseñas coinciden</li>
                    </ul>

                    <asp:Button ID="btnGuardar" runat="server" OnClick="btnGuardar_Click" CssClass="sg-btn-login" Text="Guardar y entrar" />

                    <p class="sg-login-foot">
                        Este paso es obligatorio para entrar a SIGMA.
                        <asp:LinkButton ID="lnkSalir" runat="server" CssClass="sg-cc-salir" OnClick="lnkSalir_Click" Text="Cerrar sesión" />
                    </p>
                </asp:Panel>
            </main>
        </div>
    </form>
    <script>
    (function () {
        var n = document.getElementById('<%= txtNueva.ClientID %>'), r = document.getElementById('<%= txtRepite.ClientID %>');
        var b = document.getElementById('<%= btnGuardar.ClientID %>'), ver = document.getElementById('btnVer');
        var barras = document.querySelectorAll('.sg-cc-meter span');
        function revisar() {
            var v = n.value, c = {
                largo: v.length >= 10, caso: /[A-Z]/.test(v) && /[a-z]/.test(v), num: /[0-9]/.test(v),
                sim: /[^A-Za-z0-9]/.test(v), igual: r.value.length > 0 && v === r.value
            };
            var fuerza = [c.largo, c.caso, c.num, c.sim].filter(Boolean).length, todo = fuerza === 4 && c.igual;
            var col = fuerza >= 4 ? '#16855B' : fuerza >= 3 ? '#16C6C9' : fuerza >= 2 ? '#B65C00' : '#C7352B';
            for (var i = 0; i < barras.length; i++) barras[i].style.background = i < fuerza ? col : '#E2E7F0';
            Array.prototype.forEach.call(document.querySelectorAll('#reglas [data-r]'), function (li) { li.classList.toggle('ok', !!c[li.getAttribute('data-r')]); });
            b.disabled = !todo;
        }
        n.addEventListener('input', revisar); r.addEventListener('input', revisar);
        ver.addEventListener('click', function () {
            var t = n.type === 'password' ? 'text' : 'password'; n.type = t; r.type = t;
            ver.textContent = t === 'password' ? 'Mostrar' : 'Ocultar';
        });
        revisar(); n.focus();
    })();
    </script>
</body>
</html>
