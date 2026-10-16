<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Firma.aspx.cs" Inherits="Firma" EnableViewState="false" %>

<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>Firma de contrato · SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="robots" content="noindex, nofollow" />
    <meta name="referrer" content="no-referrer" />
    <meta name="theme-color" content="#FFFFFF" />
    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
    <%-- Página pública de firma (diseño H/I del Centro Comercial). Sin master
         ni sidebar: solo el contrato y la firma. El token viaja en la URL y
         el servidor lo busca por su SHA-256; el id del contrato nunca aparece. --%>
    <link href="Css/sigma-publico.css?v=2" rel="stylesheet" />
</head>
<body>
    <header>
        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
        <span class="sep" aria-hidden="true"></span>
        <span class="cc">Código Creativo</span>
        <span class="seg"><svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>Conexión segura</span>
    </header>
    <main id="app" aria-live="polite"><div class="cargando">Cargando el contrato…</div></main>
    <footer>Código Creativo · SIGMA <%= DateTime.Now.Year %></footer>

    <script>
    (function () {
        'use strict';
        var T = <%= TokenJson %>, WS = '<%= ResolveUrl("~/WebService/WsComercial.asmx/") %>';
        var PDF = location.pathname + '?t=' + encodeURIComponent(T) + '&pdf=1';
        var app = document.getElementById('app'), PAGAR = null;
        var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
        var I = {
            pdf: '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/>', down: '<path d="M12 4v11M7 10.5l5 5 5-5"/><path d="M5 19.5h14"/>',
            sign: '<path d="M4 20h16"/><path d="M6 16l9.5-9.5a2.1 2.1 0 0 1 3 3L9 19H6z"/>', shield: '<path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6z"/><path d="M9.5 12l2 2 3.5-4"/>',
            ok: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>', x: '<path d="M6 6l12 12M18 6L6 18"/>',
            alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>'
        };
        var ic = function (k) { return '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + I[k] + '</svg>'; };
        function ws(m, d) {
            return fetch(WS + m, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify(d || {}) })
                .then(function (r) { if (!r.ok) throw new Error('No se pudo conectar con el servidor.'); return r.json(); })
                .then(function (j) { var x = typeof j.d === 'string' ? JSON.parse(j.d) : j.d; if (x && x.error) throw new Error(x.detalle || 'No se pudo completar.'); return x; });
        }
        function contacto(c) { return '<small>¿Dudas? Escribe a ' + esc(c.ejecutivo || 'Código Creativo') + ' · ' + esc(c.ejecutivoCorreo || 'comercial@codigocreativo.tech') + '</small>'; }

        function pendiente(c) {
            document.title = 'Firmar contrato · ' + c.empresa + ' · SIGMA';
            app.innerHTML =
                '<div class="pend">' +
                '<section class="doc" aria-label="Documento del contrato">' +
                  '<div class="doc-bar"><span class="pdf">' + ic('pdf') + '</span><b>Contrato SIGMA · ' + esc(c.empresa) + ' · v' + esc(c.version) + '</b>' +
                  '<a class="ibtn" href="' + PDF + '&bajar=1" aria-label="Descargar PDF" title="Descargar PDF">' + ic('down') + '</a></div>' +
                  '<div class="visor"><iframe src="' + PDF + '" title="Contrato en PDF"></iframe>' +
                  '<div class="alt">Para leer el contrato en tu teléfono, ábrelo o descárgalo:<br><br><a class="btn out" href="' + PDF + '" target="_blank" rel="noopener">' + ic('pdf') + 'Abrir el contrato (PDF)</a></div></div>' +
                '</section>' +
                '<aside class="firma">' +
                  '<div><div class="eyebrow">Contrato para firmar</div><h1>' + esc(c.empresa) + '</h1><span class="sub">Para ' + esc(c.contacto) + '</span></div>' +
                  '<dl class="res"><dt>Plan</dt><dd>' + esc(c.plan) + '</dd><dt>Mensualidad</dt><dd>' + esc(c.mensual) + '</dd>' +
                  '<dt>Implementación</dt><dd>' + esc(c.implementacion) + '</dd><dt>Vigencia</dt><dd>' + esc(c.vigencia) + '</dd><dt>Versión</dt><dd>v' + esc(c.version) + '</dd></dl>' +
                  '<label class="acepto"><input type="checkbox" id="fAcepto"><span>He leído y acepto los términos del contrato.</span></label>' +
                  '<label class="fld" id="lNom"><span>Nombre completo</span><input type="text" id="fNom" autocomplete="name" placeholder="' + esc(c.contacto) + '"></label>' +
                  '<label class="fld" id="lRut"><span>' + esc(c.rutEtiqueta || 'RUT') + ' de quien firma</span><input type="text" id="fRut" inputmode="text" autocomplete="off" placeholder="' + (c.esChile === false ? '' : '12.345.678-5') + '"></label>' +
                  '<div class="error" id="fErr" role="alert"></div>' +
                  '<button type="button" class="btn" id="fBtn" disabled>' + ic('sign') + 'Firmar contrato</button>' +
                  '<p class="nota">' + ic('shield') + '<span>Este enlace es personal y vence el ' + esc(c.expira) + '. Al firmar registramos fecha, IP y navegador junto con una huella SHA-256 del documento.</span></p>' +
                '</aside></div>';
            var a = document.getElementById('fAcepto'), n = document.getElementById('fNom'), r = document.getElementById('fRut'), b = document.getElementById('fBtn'), e = document.getElementById('fErr');
            function rutOk(v) {
                v = String(v || '').replace(/[.\s]/g, '').toUpperCase(); var m = /^(\d{6,8})-?([\dK])$/.exec(v); if (!m) return false;
                var s = 0, k = 2; for (var i = m[1].length - 1; i >= 0; i--) { s += +m[1][i] * k; k = k === 7 ? 2 : k + 1; }
                var d = 11 - s % 11; return (d === 11 ? '0' : d === 10 ? 'K' : String(d)) === m[2];
            }
            /* Solo el RUT chileno se valida con dígito verificador; los demás identificadores, por largo. */
            function idOk(v) { return c.esChile === false ? String(v || '').trim().length >= 4 : rutOk(v); }
            function revisar() {
                document.getElementById('lRut').classList.toggle('err', r.value.trim().length > 7 && !idOk(r.value));
                b.disabled = !(a.checked && n.value.trim().length >= 3 && idOk(r.value));
            }
            [a, n, r].forEach(function (x) { x.addEventListener('input', revisar); x.addEventListener('change', revisar); });
            b.addEventListener('click', function () {
                if (b.disabled) return;
                b.disabled = true; b.innerHTML = ic('sign') + 'Firmando…'; e.style.display = 'none';
                ws('FirmarContrato', { t: T, nombre: n.value.trim(), rut: r.value.trim(), acepto: a.checked })
                    .then(function (x) { PAGAR = x.pagar || null; pintar(x.estado); })
                    .catch(function (er) { e.textContent = er.message; e.style.display = 'block'; b.innerHTML = ic('sign') + 'Firmar contrato'; revisar(); });
            });
        }

        function estado(icono, fondo, color, titulo, texto, extra, acciones, c) {
            app.innerHTML = '<div class="estado"><section><span class="ic" style="background:' + fondo + ';color:' + color + '">' + ic(icono) + '</span>' +
                '<h1>' + titulo + '</h1><p>' + texto + '</p>' + (extra || '') + (acciones ? '<div class="acc">' + acciones + '</div>' : '') + contacto(c || {}) + '</section></div>';
        }

        function pintar(c) {
            if (!c || c.estado === 'invalido')
                return estado('x', '#FDEDEB', '#C7352B', 'Este enlace no es válido', 'Puede que esté incompleto o que el contrato se haya reemplazado por una versión nueva. Revisa el último correo que te enviamos.', '', '', c);
            if (c.estado === 'firmado')
                return estado('ok', '#E8F6EF', '#16855B', 'Contrato firmado', esc(c.empresa) + ' ya es cliente SIGMA. Te enviamos una copia del contrato firmado' + (c.correo ? ' a ' + esc(c.correo) : '') + '.' + (PAGAR ? ' Último paso: paga la implementación y la primera mensualidad para activar el servicio.' : ''),
                    '<dl><dt>Firmado por</dt><dd>' + esc(c.firmante) + '</dd><dt>Fecha</dt><dd>' + esc(c.firmado) + '</dd><dt>Huella SHA-256</dt><dd style="font-family:Consolas,monospace;font-size:12px">' + esc(c.sha.slice(0, 8)) + '…' + esc(c.sha.slice(-8)) + '</dd></dl>',
                    PAGAR ? '<a class="btn" href="' + esc(PAGAR) + '">' + ic('sign') + 'Pagar ahora con Webpay</a><a class="btn out" href="<%= ResolveUrl("~/Login.aspx") %>">Entrar a SIGMA</a>'
                          : '<a class="btn" href="<%= ResolveUrl("~/Login.aspx") %>">Ir a SIGMA</a>', c);
            if (c.estado === 'usado')
                return estado('alert', '#FFF3E4', '#B65C00', 'Este enlace ya se usó', 'Los enlaces de firma sirven una sola vez. Si necesitas firmar de nuevo, pide un enlace nuevo a tu ejecutivo.', '', '', c);
            if (c.estado === 'vencido') {
                estado('clock', '#FFF3E4', '#B65C00', 'El enlace venció', 'Por seguridad, los enlaces de firma duran unos días. Pide uno nuevo y te lo enviamos al mismo correo.', '',
                    '<button type="button" class="btn" id="eNuevo">Pedir un enlace nuevo</button>', c);
                var bn = document.getElementById('eNuevo');
                bn.addEventListener('click', function () {
                    bn.disabled = true;
                    ws('SolicitarNuevoEnlace', { t: T }).then(function () { bn.textContent = 'Listo: te escribiremos pronto'; }).catch(function () { bn.disabled = false; });
                });
                return;
            }
            pendiente(c);
        }

        ws('ContratoPorToken', { t: T }).then(pintar).catch(function (er) {
            app.innerHTML = '<div class="estado"><section><h1>No pudimos abrir el contrato</h1><p>' + esc(er.message) + '</p></section></div>';
        });
    })();
    </script>
</body>
</html>
