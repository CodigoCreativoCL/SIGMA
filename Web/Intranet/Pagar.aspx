<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Pagar.aspx.cs" Inherits="Pagar" EnableViewState="false" %>

<!DOCTYPE html>
<html lang="es">
<head runat="server">
    <meta charset="utf-8" />
    <title>Pagar · SIGMA</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="robots" content="noindex, nofollow" />
    <meta name="referrer" content="no-referrer" />
    <link href="Imagen/sigma-favicon.svg" rel="icon" type="image/svg+xml" />
    <link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
    <link href="Css/sigma-publico.css?v=3" rel="stylesheet" />
    <%-- Pago de la suscripción con Webpay Plus (bloque 462). Mismo estilo que la
         página de firma. El enlace (?t=) identifica la suscripción; Webpay vuelve
         aquí con token_ws (o TBK_TOKEN si se anuló). --%>
</head>
<body>
    <header>
        <img src="Imagen/sigma-logo-horizontal-light.svg" alt="SIGMA" />
        <span class="sep" aria-hidden="true"></span>
        <span class="cc">Código Creativo</span>
        <span class="seg"><svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>Pago seguro</span>
    </header>
    <main id="app" aria-live="polite"></main>
    <footer>Código Creativo · SIGMA <%= DateTime.Now.Year %></footer>

    <script>
    (function () {
        'use strict';
        var M = <%= ModeloJson %>, WS = '<%= ResolveUrl("~/WebService/WsComercial.asmx/") %>';
        var app = document.getElementById('app');
        var esc = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
        var I = { card: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/>', ok: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
                  x: '<path d="M6 6l12 12M18 6L6 18"/>', alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>', clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
                  flask: '<path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3"/>' };
        var ic = function (k) { return '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + I[k] + '</svg>'; };
        var prueba = M.prueba ? '<div class="prueba">' + ic('flask') + '<span><b>Modo de prueba.</b> No se cobra dinero real. Usa la tarjeta VISA 4051 8856 0044 6623, CVV 123, cualquier fecha; si te pide RUT y clave: 11.111.111-1 / 123.</span></div>' : '';
        var ayuda = function () { return '<small>¿Dudas? Escribe a ' + esc(M.ejecutivo || 'Código Creativo') + ' · ' + esc(M.ejecutivoCorreo || 'comercial@codigocreativo.tech') + '</small>'; };

        function estado(icono, fondo, color, titulo, texto, extra, acciones) {
            app.innerHTML = '<div class="estado"><section><span class="ic" style="background:' + fondo + ';color:' + color + '">' + ic(icono) + '</span>' +
                '<h1>' + titulo + '</h1><p>' + texto + '</p>' + (extra || '') + (acciones ? '<div class="acc">' + acciones + '</div>' : '') + prueba + ayuda() + '</section></div>';
        }

        var usd = M.moneda === 'USD';
        var I2 = { up: '<path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/>', bank: '<path d="M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18"/>' };
        var ic2 = function (k) { return '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (I[k] || I2[k]) + '</svg>'; };

        /* Datos para transferir: salen de Configuración, no del código. */
        function datos() {
            var d = (M.datos || []).filter(function (x) { return x.v; });
            if (!d.length) return '<p class="nota">Los datos para transferir todavía no están cargados. Escribe a tu ejecutivo y te los enviamos.</p>';
            return '<dl class="datos">' + d.map(function (x) { return '<dt>' + esc(x.k) + '</dt><dd>' + esc(x.v) + '</dd>'; }).join('') +
                '<dt>Referencia</dt><dd><b>' + esc(M.referencia) + '</b></dd><dt>Monto</dt><dd><b>' + esc(M.total) + '</b></dd></dl>' +
                '<p class="nota">Pon la referencia en la glosa de la transferencia.' + (usd ? ' Los gastos bancarios de la transferencia internacional corren por cuenta de tu empresa.' : '') + '</p>';
        }

        function resumen() {
            return '<div><div class="eyebrow">Pago de suscripción</div><h1>' + esc(M.empresa) + '</h1><span class="sub">Plan ' + esc(M.plan) + (M.contacto ? ' · ' + esc(M.contacto) : '') + '</span></div>' +
                '<dl class="items">' + M.items.map(function (x) { return '<dt>' + esc(x.n) + '<small>' + esc(x.uf) + '</small></dt><dd>' + esc(x.monto) + '</dd>'; }).join('') +
                '<dt class="tot">Total a pagar</dt><dd class="tot">' + esc(M.total) + '</dd></dl>';
        }

        function pendiente() {
            document.title = 'Pagar · ' + M.empresa + ' · SIGMA';
            var tarjeta = usd
                ? '<button type="button" class="btn" disabled title="Disponible cuando se habilite un procesador de tarjetas en dólares">' + ic('card') + 'Pagar con tarjeta en USD · próximamente</button>'
                : '<button type="button" class="btn" id="pBtn">' + ic('card') + 'Pagar ' + esc(M.total) + ' con Webpay</button>';
            var transf = usd
                ? '<div class="transf"><div class="transf-h">' + ic2('bank') + '<b>Transferencia internacional (SWIFT)</b></div>' + datos() +
                  '<button type="button" class="btn" id="pInf">' + ic('ok') + 'Ya transferí: informar el pago</button></div>'
                : '<details class="transf"><summary>' + ic2('bank') + '<b>¿Prefieres transferir?</b><small>Datos para una transferencia nacional</small></summary>' + datos() +
                  '<button type="button" class="btn sec" id="pInf">' + ic2('up') + 'Informar transferencia</button></details>';
            app.innerHTML = '<div class="pago"><section>' + resumen() + (usd ? '' : prueba) + '<div class="error" id="pErr" role="alert"></div>' +
                (usd ? transf + tarjeta : tarjeta + transf) +
                '<p class="nota">' + (usd ? 'Tu cobro es en dólares y no lleva conversión. ' : 'Te llevamos al sitio seguro de Transbank para pagar con tarjeta de crédito o débito, y vuelves aquí con el comprobante. Montos con IVA según la UF del día de emisión. ') + '</p>' +
                ayuda() + '</section></div>';
            var b = document.getElementById('pBtn'), e = document.getElementById('pErr');
            document.getElementById('pInf').addEventListener('click', informar);
            if (!b) return;
            b.addEventListener('click', function () {
                b.disabled = true; b.innerHTML = ic('card') + 'Conectando con Webpay…'; e.style.display = 'none';
                fetch(WS + 'IniciarPago', { method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify({ t: M.t }) })
                    .then(function (r) { if (!r.ok) throw new Error('No se pudo conectar con el servidor.'); return r.json(); })
                    .then(function (j) {
                        var x = typeof j.d === 'string' ? JSON.parse(j.d) : j.d;
                        if (x.error) throw new Error(x.detalle);
                        /* Webpay pide un POST del token a su URL. */
                        var f = document.createElement('form'); f.method = 'POST'; f.action = x.url;
                        var i = document.createElement('input'); i.type = 'hidden'; i.name = 'token_ws'; i.value = x.token; f.appendChild(i);
                        document.body.appendChild(f); f.submit();
                    })
                    .catch(function (er) { e.textContent = er.message; e.style.display = 'block'; b.disabled = false; b.innerHTML = ic('card') + 'Pagar ' + esc(M.total) + ' con Webpay'; });
            });
        }

        /* Informar una transferencia: monto, fecha, banco, operación y comprobante. */
        function informar() {
            var hoy = new Date(), iso = hoy.getFullYear() + '-' + ('0' + (hoy.getMonth() + 1)).slice(-2) + '-' + ('0' + hoy.getDate()).slice(-2);
            app.innerHTML = '<div class="pago"><section><div><div class="eyebrow">Informar transferencia</div><h1>' + esc(M.empresa) + '</h1><span class="sub">Referencia ' + esc(M.referencia) + ' · total ' + esc(M.total) + '</span></div>' +
                '<div class="fila2"><label class="fld"><span>Monto transferido (' + (usd ? 'USD' : 'CLP') + ')</span><input type="text" id="iMonto" inputmode="decimal" value="' + esc(String(M.montoNum).replace('.', ',')) + '"></label>' +
                '<label class="fld"><span>Fecha de la transferencia</span><input type="date" id="iFecha" max="' + iso + '" value="' + iso + '"></label>' +
                '<label class="fld"><span>Banco de origen</span><input type="text" id="iBanco" autocomplete="off"></label>' +
                '<label class="fld"><span>N° de operación</span><input type="text" id="iOp" autocomplete="off"></label></div>' +
                '<label class="fld" id="lArch"><span>Comprobante (PDF o imagen, hasta 8 MB)</span><input type="file" id="iArch" accept="application/pdf,image/*"></label>' +
                '<div class="error" id="iErr" role="alert"></div>' +
                '<button type="button" class="btn" id="iBtn" disabled>' + ic('ok') + 'Informar el pago</button>' +
                '<button type="button" class="btn out" id="iVol">Volver</button>' +
                '<p class="nota">Revisaremos el comprobante contra nuestra cartola y te avisamos por correo cuando quede verificado. Hasta entonces tu acceso sigue como hoy.</p>' + ayuda() + '</section></div>';
            var arch = document.getElementById('iArch'), btn = document.getElementById('iBtn'), er = document.getElementById('iErr'), datosArch = null;
            function revisar() { btn.disabled = !(datosArch && +String(document.getElementById('iMonto').value).replace(/[^0-9]/g, '') > 0 && document.getElementById('iFecha').value); }
            arch.addEventListener('change', function () {
                var f = arch.files[0]; datosArch = null; revisar(); if (!f) return;
                if (f.size > 8 * 1024 * 1024) { er.textContent = 'El comprobante pesa más de 8 MB.'; er.style.display = 'block'; return; }
                er.style.display = 'none';
                var r = new FileReader(); r.onload = function () { datosArch = { nombre: f.name, mime: f.type, base64: String(r.result).split(',')[1] }; revisar(); }; r.readAsDataURL(f);
            });
            ['iMonto', 'iFecha'].forEach(function (id) { document.getElementById(id).addEventListener('input', revisar); });
            document.getElementById('iVol').addEventListener('click', pendiente);
            btn.addEventListener('click', function () {
                btn.disabled = true; btn.innerHTML = ic('ok') + 'Enviando…'; er.style.display = 'none';
                fetch(WS + 'InformarPagoPublico', { method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify({
                    t: M.t, monto: document.getElementById('iMonto').value, fecha: document.getElementById('iFecha').value, banco: document.getElementById('iBanco').value, operacion: document.getElementById('iOp').value,
                    archivoNombre: datosArch.nombre, archivoMime: datosArch.mime, archivoBase64: datosArch.base64 }) })
                    .then(function (r) { if (!r.ok) throw new Error('No se pudo conectar con el servidor.'); return r.json(); })
                    .then(function (j) { var x = typeof j.d === 'string' ? JSON.parse(j.d) : j.d; if (x.error) throw new Error(x.detalle); M.estado = 'informado'; M.informadoMonto = document.getElementById('iMonto').value; informado(); })
                    .catch(function (e2) { er.textContent = e2.message; er.style.display = 'block'; btn.disabled = false; btn.innerHTML = ic('ok') + 'Informar el pago'; });
            });
        }

        function informado() {
            document.title = 'Pago informado · SIGMA';
            estado('ok', '#E8F6EF', '#16855B', 'Recibimos tu comprobante', 'Verificaremos la transferencia contra nuestra cartola y te avisaremos por correo. Mientras tanto no necesitas hacer nada más.',
                '<dl><dt>Referencia</dt><dd>' + esc(M.referencia) + '</dd><dt>Monto informado</dt><dd>' + esc(M.informadoMonto || M.total) + '</dd></dl>', '<a class="btn" href="<%= ResolveUrl("~/Login.aspx") %>">Entrar a SIGMA</a>');
        }

        var reintentar = M.t ? '<a class="btn" href="?t=' + encodeURIComponent(M.t) + '">' + ic('card') + 'Intentar de nuevo</a>' : '';
        if (M.estado === 'pendiente') pendiente();
        else if (M.estado === 'informado') informado();
        else if (M.estado === 'aprobado')
            estado('ok', '#E8F6EF', '#16855B', 'Pago recibido', 'Gracias. El pago quedó registrado y tu acceso a SIGMA sigue activo.' + (M.correo ? ' Te enviamos el comprobante por correo.' : ''),
                '<dl><dt>Monto</dt><dd>' + esc(M.monto) + '</dd><dt>Tarjeta</dt><dd>****' + esc(M.tarjeta) + '</dd><dt>Autorización</dt><dd>' + esc(M.autorizacion) + '</dd><dt>Orden</dt><dd>' + esc(M.orden) + '</dd></dl>',
                '<a class="btn" href="<%= ResolveUrl("~/Login.aspx") %>">Entrar a SIGMA</a>');
        else if (M.estado === 'rechazado') estado('x', '#FDEDEB', '#C7352B', 'No se pudo completar el pago', esc(M.mensaje), '', reintentar);
        else if (M.estado === 'anulado') estado('alert', '#FFF3E4', '#B65C00', 'Pago anulado', esc(M.mensaje), '', reintentar);
        else if (M.estado === 'aldia') estado('ok', '#E8F6EF', '#16855B', 'Estás al día', 'No tienes cobros pendientes. ¡Gracias!', '', '<a class="btn" href="<%= ResolveUrl("~/Login.aspx") %>">Entrar a SIGMA</a>');
        else if (M.estado === 'vencido') estado('clock', '#FFF3E4', '#B65C00', 'El enlace venció', 'Por seguridad los enlaces de pago duran unos días. Responde el correo de cobro y te enviamos uno nuevo.', '', '');
        else if (M.estado === 'invalido') estado('x', '#FDEDEB', '#C7352B', 'Este enlace no es válido', 'Revisa el último correo de cobro que te enviamos.', '', '');
        else estado('alert', '#FDEDEB', '#C7352B', 'No pudimos procesar el pago', esc(M.mensaje || 'Intenta de nuevo en unos minutos.'), '', reintentar);
    })();
    </script>
</body>
</html>
