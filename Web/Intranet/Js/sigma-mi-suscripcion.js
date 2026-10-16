/* =====================================================================
   SIGMA · Mi suscripción (P6 del Centro Comercial V2, 16-10-2026)
   Lo que el administrador del cliente ve de su propia suscripción, en un cajón
   lateral: estado del cobro, uso contra los topes, historial, «Pagar ahora» y
   «Informar transferencia». Habla con WsMiSuscripcion.asmx, que siempre trabaja
   con el cliente en sesión y sigue respondiendo con la suscripción vencida.

   Estados: aldia · pendiente · mora. Modos del cajón: ver · informar.
   Convenciones: clases cp-/cc- bajo .cc-root; todo <button> con type="button";
   «activo», nunca «equipo»; mensajes por facultad, nunca por rol.
   ===================================================================== */
(function () {
'use strict';
function iniciar() {
var K = window.MantKit, CFG = K && K.CFG || {}, $ = K.$, esc = K.esc;
if (!K || !$('#cpRoot')) return;
function call(m, d) { return K.llamar(CFG.ws, m, d); }

var P = {
  wallet: '<path d="M4 7.5A1.5 1.5 0 0 1 5.5 6H18v3"/><path d="M4 7.5V18a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2H5.5A1.5 1.5 0 0 1 4 7.5z"/><circle cx="16" cy="14.5" r="1.2" fill="currentColor" stroke="none"/>',
  card: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/>', check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  upload: '<path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/>', flag: '<path d="M5 21V4M5 4h11l-2 4 2 4H5"/>', light: '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.8.8 1 1.5 1 2.5h6c0-1 .2-1.7 1-2.5A6 6 0 0 0 12 3z"/>',
  chevd: '<path d="M6 9l6 6 6-6"/>', chevu: '<path d="M6 15l6-6 6 6"/>', mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 6.5l8.5 6.5 8.5-6.5"/>'
};
function ic(k, n) { n = n || 18; return '<svg class="cc-ic" style="width:' + n + 'px;height:' + n + 'px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (P[k] || '') + '</svg>'; }
function chip(t, tono) { return '<span class="cc-chip cc-t-' + tono + '">' + esc(t) + '</span>'; }
function dmy(s) { return s ? K.fDN(String(s).slice(0, 10)).replace(/-/g, '/') : '—'; }
function fn(v, d) { return K.fN(v == null ? 0 : +v, d == null ? 0 : d); }
function money(v, usd) { return usd ? 'USD ' + fn(v, 2) : '$' + fn(Math.round(+v || 0), 0); }
var MEDIO = { WEBPAY: 'Webpay', TRANSFERENCIA_NACIONAL: 'Transferencia', TRANSFERENCIA_INTERNACIONAL: 'Transferencia internacional' };
var TONO_PAGO = { VERIFICADO: 'ok', RECHAZADO: 'da' };

var S = { d: null, modo: 'ver', open: { cobro: true, uso: true, hist: false }, f: {}, file: null, busy: false };

function cargar() {
  return call('Estado').then(function (d) { S.d = d; pintarPagina(); if (S.abierto) K.Panel.paint(); return d; })
    .catch(function (e) { $('#msBody').innerHTML = '<div class="cc-vacio">' + esc(e.message || 'No se pudo cargar tu suscripción.') + ' Si el problema sigue, escribe a comercial@codigocreativo.tech.</div>'; });
}

function titulo(d) {
  var s = d.suscripcion;
  if (d.estado === 'aldia') return ['Estás al día', 'ok', 'Tu suscripción está vigente' + (s.hasta ? ' hasta el ' + dmy(s.hasta) : '') + (s.dias != null && s.dias >= 0 ? ' · quedan ' + K.pl(s.dias, 'día', 'días') : '') + '.'];
  var e = (s.estado || '').toUpperCase();
  if (d.estado === 'mora') {
    if (e === 'VENCIDA') return ['Tu suscripción venció', 'da', 'El acceso está suspendido hasta regularizar el pago. Toda tu información sigue completa y se recupera al pagar.'];
    if (e === 'SUSPENDIDA') return ['Tu suscripción está suspendida', 'da', 'Contáctanos para revisar la situación y reactivarla.'];
    if (e === 'CANCELADA') return ['Tu suscripción está cancelada', 'da', 'Contáctanos si quieres volver a activarla. Tus datos siguen guardados.'];
    return ['Tienes un cobro en mora', 'da', 'Regulariza el pago para no perder el acceso.' + (s.gracia ? ' Estás dentro de los ' + s.gracia + ' días de gracia.' : '')];
  }
  return ['Tienes un cobro pendiente', 'wa', 'Págalo para que tu equipo siga usando SIGMA sin interrupciones.'];
}

function pintarPagina() {
  var d = S.d, b = $('#msBody'); if (!d) return;
  if (d.sinSuscripcion) { b.innerHTML = '<div class="cc-card"><div class="cc-vacio">Todavía no hay un plan contratado para ' + esc(d.cliente) + '. Mientras tanto no se aplica ningún límite de plan.</div></div>'; return; }
  var t = titulo(d);
  b.innerHTML = '<section class="cc-card"><div class="cc-card-h"><h2>' + esc(t[0]) + '</h2>' + chip(d.suscripcion.estado || 'Vigente', t[1]) + '</div><p style="margin:0 0 12px;color:var(--cc-lab);font-size:14px">' + esc(t[2]) + '</p>' +
    '<div class="cc-mini"><div><small>Plan</small><b>' + esc(d.suscripcion.plan || '—') + '</b></div><div><small>Vigente hasta</small><b>' + dmy(d.suscripcion.hasta) + '</b></div><div><small>Saldo pendiente</small><b>' + esc(d.totalTexto) + '</b></div></div></section>';
  if (!S.abierto && !S.cerro) abrir();
}

/* ------------------------------------------------------------ cajón */
function sec(k, icono, tono, titulo, resumen, cuerpo) {
  var o = S.open[k];
  return '<section class="cc-sec"><button type="button" class="cc-sec-h" data-a="sec" data-v="' + k + '" aria-expanded="' + !!o + '"><span style="color:var(--cc-' + tono + ')">' + ic(icono, 20) + '</span><b>' + titulo + '</b>' + (resumen || '') + ic(o ? 'chevu' : 'chevd', 20) + '</button>' +
    (o ? '<div class="cc-sec-b">' + cuerpo + '</div>' : '') + '</section>';
}
function aviso(txt, tono) { return '<div class="cc-info' + (tono === 'wa' ? ' cc-wa' : '') + '">' + ic(tono === 'wa' ? 'flag' : 'light') + '<span>' + txt + '</span></div>'; }
function consumo(filas) {
  return '<div class="cc-uso">' + filas.map(function (c) {
    var uso = +c.USO || 0, tope = c.TOPE == null ? null : +c.TOPE, pct = tope ? Math.min(100, Math.round(uso / tope * 100)) : 0, alto = pct >= 80;
    return '<div><div class="cc-uso-h"><span>' + esc(c.NOMBRE) + '</span><b class="' + (alto ? 'cc-alto' : '') + '">' + fn(uso, c.CODIGO === 'LIMITE ALMACENAMIENTO' ? 2 : 0) + (tope ? ' de ' + fn(tope, 0) : ' · sin tope') + '</b></div>' +
      (tope ? '<span class="cc-meter"><span class="' + (alto ? 'cc-alto' : '') + '" style="width:' + pct + '%"></span></span>' : '') + '</div>';
  }).join('') + '</div>';
}
function datosBanco(d) {
  var f = (d.datos || []).filter(function (x) { return x.v; });
  if (!f.length) return aviso('Los datos para transferir todavía no están cargados. Escríbele a ' + esc(d.ejecutivoCorreo || 'comercial@codigocreativo.tech') + ' y te los enviamos.', 'wa');
  return '<dl class="cc-dl">' + f.map(function (x) { return '<dt>' + esc(x.k) + '</dt><dd>' + esc(x.v) + '</dd>'; }).join('') + (d.referencia ? '<dt>Referencia</dt><dd><b>' + esc(d.referencia) + '</b></dd>' : '') + '</dl>';
}

function render() {
  var d = S.d;
  if (!d) return { w: 'c', s: 'Suscripción', t: 'Mi suscripción', b: '<div class="cc-cargando">Cargando…</div>' };
  if (d.sinSuscripcion) return { w: 'c', s: esc(d.cliente), t: 'Mi suscripción', b: '<div class="cc-vacio">Todavía no hay un plan contratado.</div>', f: '<div class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button></div>' };
  var usd = d.moneda === 'USD', t = titulo(d), dis = S.busy ? ' disabled' : '';

  if (S.modo === 'informar') {
    var f = S.f, pers = d.pendientes.map(function (p) { return { id: String(p.id), n: p.nombre + ' · ' + p.saldo }; });
    var fld = function (k, tt) { return '<div class="cp-fld"><label for="ms_' + k + '">' + tt + '</label><input class="cp-inp" id="ms_' + k + '" data-pv="m.' + k + '" value="' + esc(f[k] || '') + '"></div>'; };
    var b = '<section class="cc-sec"><div class="cc-sec-h" style="cursor:default"><span style="color:var(--cc-cyd)">' + ic('wallet', 20) + '</span><b>A dónde transferir</b><small>' + (usd ? 'Transferencia internacional' : 'Transferencia nacional') + '</small></div><div class="cc-sec-b">' + datosBanco(d) +
      (usd ? '<div class="cc-nota">Los gastos bancarios de la transferencia internacional corren por cuenta de tu empresa.</div>' : '') + '</div></section>' +
      '<div class="cp-fld"><label>Período que estás pagando</label>' + K.combo('msPer', pers, f.periodo, { ph: 'Elige el período', etiqueta: 'Período' }) + '</div>' +
      '<div class="cc-grid2"><div class="cp-fld"><label for="ms_monto">Monto transferido (' + (usd ? 'USD' : 'CLP') + ')</label><input class="cp-inp" id="ms_monto" inputmode="decimal" data-pv="m.monto" value="' + esc(f.monto || '') + '"></div>' +
      '<div class="cp-fld"><span class="cp-lb">Fecha de la transferencia</span>' + K.fecha('ms.fecha', f.fecha, { etiqueta: 'Fecha de la transferencia' }) + '</div>' + fld('banco', 'Banco') + fld('operacion', 'N° de operación') + '</div>' +
      '<label class="cc-drop" id="ccDrop"><input type="file" id="msFile" accept="application/pdf,image/*">' + ic('upload', 22) + (S.file ? '<b>' + esc(S.file.nombre) + '</b><span>' + K.fN(S.file.bytes / 1024, 0) + ' KB · pulsa para cambiarlo</span>' : '<b>Suelta aquí el comprobante</b><span>PDF o imagen, hasta 8 MB · o pulsa para elegirlo</span>') + '</label>';
    return { w: 'c', s: esc(d.cliente), t: 'Informar transferencia', b: b,
      f: '<button type="button" class="cp-btn cp-ghost" data-a="volver">Cancelar</button><div class="cp-r"><button type="button" class="cp-btn cp-pri" data-a="informarok"' + dis + (f.periodo && S.file ? '' : ' disabled') + '>' + ic('check') + (S.busy ? 'Informando…' : 'Informar pago') + '</button></div>' };
  }

  var hero = '<div class="cc-hero"><small>' + (d.estado === 'aldia' ? 'Estado' : 'A pagar') + '</small><strong>' + esc(d.estado === 'aldia' ? 'Al día' : d.totalTexto) + '</strong><span>' + esc(t[2]) + '</span></div>';
  var pend = d.pendientes.length ? '<div class="cc-sub">Por pagar</div>' + d.pendientes.map(function (p) { return '<div class="cc-li" style="grid-template-columns:minmax(0,1fr) auto"><span><b style="font-size:13px">' + esc(p.nombre) + '</b> <span class="cc-m">' + esc(p['base']) + '</span></span><b>' + esc(p.saldo) + '</b></div>'; }).join('') : '';
  var inf = d.informado ? aviso('Ya informaste una transferencia de <b>' + esc(d.informado) + '</b>. La estamos verificando contra nuestra cartola; te avisaremos por correo.', '') : '';
  var prueba = d.prueba ? aviso('<b>Modo de prueba.</b> El pago con Webpay no cobra dinero real: usa la tarjeta VISA 4051 8856 0044 6623, CVV 123.', 'wa') : '';
  var hist = '<div class="cc-sub">Pagos</div>' + (d.pagos.length ? d.pagos.map(function (x) {
    var u = x.SPA_MONEDA === 'USD';
    return '<div class="cc-li" style="grid-template-columns:96px minmax(0,1fr) auto"><span class="cc-m">' + dmy(x.SPA_FECHA_TRANSFERENCIA) + '</span><span>' + chip(x.SPO_NOMBRE, TONO_PAGO[x.SPO_CODIGO] || 'cy') + ' <span class="cc-m">' + esc(MEDIO[x.SPA_MEDIO] || '') + '</span></span><b>' + money(x.SPA_MONTO_DECLARADO_CLP, u) + '</b></div>';
  }).join('') : '<div class="cc-nota">Todavía no hay pagos.</div>') +
    '<div class="cc-sub" style="margin-top:6px">Períodos</div>' + (d.periodos.length ? d.periodos.map(function (x) {
      var u = x.SPE_MONEDA === 'USD';
      return '<div class="cc-li" style="grid-template-columns:minmax(0,1fr) auto auto"><span class="cc-m">' + dmy(x.SPE_FECHA_INICIO) + ' – ' + dmy(x.SPE_FECHA_FIN) + '</span>' + chip(x.SPD_NOMBRE, x.SPD_NOMBRE === 'Vigente' ? 'ok' : x.SPD_NOMBRE === 'Pendiente de pago' ? 'wa' : 'gr') + '<b>' + money(x.SPE_MONTO_CLP, u) + '</b></div>';
    }).join('') : '<div class="cc-nota">Sin períodos emitidos.</div>');
  var cuerpo = hero + inf + (d.estado === 'aldia' ? '' : sec('cobro', 'wallet', 'cy', 'Detalle del cobro', '', pend + prueba)) + sec('uso', 'check', 'cy', 'Uso de tu plan', '', consumo(d.consumo)) + sec('hist', 'mail', 'bl', 'Historial', '', hist) +
    '<div class="cc-nota">¿Dudas? Escribe a ' + esc(d.ejecutivo || 'Código Creativo') + ' · ' + esc(d.ejecutivoCorreo || 'comercial@codigocreativo.tech') + '</div>';
  var puede = d.permisos.declarar && d.pendientes.length > 0;
  var pie;
  if (d.pendientes.length === 0) pie = '<div class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button></div>';
  else if (usd) pie = '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button><div class="cp-r">' + (puede ? '<button type="button" class="cp-btn cp-pri" data-a="informar">' + ic('upload') + 'Informar transferencia</button>' : '') + '</div>';
  else pie = '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button><div class="cp-r">' + (puede ? '<button type="button" class="cp-btn cp-sec" data-a="informar">' + ic('upload') + 'Informar transferencia</button>' : '') +
    (d.pagarAhora ? '<a class="cp-btn cp-pri" href="' + esc(d.pagarAhora) + '">' + ic('card') + 'Pagar ahora</a>' : '') + '</div>';
  return { w: 'c', s: esc(d.cliente), t: 'Mi suscripción ' + chip(t[0], t[1]), b: cuerpo, f: pie };
}

function abrir() { S.abierto = true; S.modo = 'ver'; K.Panel.open({ st: S, render: render, onclose: function () { S.abierto = false; S.cerro = true; S.modo = 'ver'; } }); }

function leerArchivo(file) {
  if (!file) return;
  if (file.size > 8 * 1024 * 1024) { K.toastError('El comprobante pesa más de 8 MB.'); return; }
  var r = new FileReader();
  r.onload = function () { S.file = { nombre: file.name, mime: file.type, bytes: file.size, base64: String(r.result).split(',')[1] }; K.Panel.paint(); };
  r.readAsDataURL(file);
}
document.addEventListener('change', function (e) { if (e.target && e.target.id === 'msFile' && S.modo === 'informar') leerArchivo(e.target.files[0]); });
document.addEventListener('dragover', function (e) { var z = e.target.closest && e.target.closest('#ccDrop'); if (z && S.modo === 'informar') { e.preventDefault(); z.classList.add('cc-sobre'); } });
document.addEventListener('drop', function (e) { var z = e.target.closest && e.target.closest('#ccDrop'); if (z && S.modo === 'informar') { e.preventDefault(); leerArchivo(e.dataTransfer.files[0]); } });

var A = {
  abrir: function () { S.cerro = false; abrir(); },
  sec: function (ds) { S.open[ds.v] = !S.open[ds.v]; K.Panel.paint(); },
  informar: function () {
    var d = S.d, p = d.pendientes[0];
    S.modo = 'informar'; S.file = null;
    S.f = { periodo: String(p.id), monto: String(p.saldoNum == null ? '' : p.saldoNum).replace('.', ','), fecha: CFG.hoy, banco: '', operacion: '' };
    K.Panel.paint();
  },
  volver: function () { S.modo = 'ver'; S.busy = false; K.Panel.paint(); },
  informarok: function () {
    var f = S.f, a = S.file; if (!a) { K.toastError('Adjunta el comprobante de la transferencia.'); return; }
    S.busy = true; K.Panel.paint();
    call('InformarPago', { periodo: +f.periodo, monto: f.monto, fecha: f.fecha, banco: f.banco, operacion: f.operacion, archivoNombre: a.nombre, archivoMime: a.mime, archivoBase64: a.base64 })
      .then(function (r) { S.d = r.ficha; S.modo = 'ver'; S.busy = false; S.file = null; pintarPagina(); K.Panel.paint(); K.toast(r.mensaje); })
      .catch(function (e) { S.busy = false; K.Panel.paint(); K.toastError(e); });
  }
};
function pv(clave, valor) { if (clave.indexOf('m.') === 0) { S.f[clave.slice(2)] = valor; } }
function combo(span, valor) {
  var n = span.getAttribute('data-cb');
  if (n === 'msPer') {
    S.f.periodo = valor;
    var p = S.d.pendientes.filter(function (x) { return String(x.id) === String(valor); })[0];
    if (p) S.f.monto = String(p.saldoNum).replace('.', ',');
    K.Panel.paint();
  }
}
function fecha(el) { if (el.getAttribute('data-fe') === 'ms.fecha') S.f.fecha = K.deDN(el.value); }
K.bind({ A: A, pv: pv, combo: combo, fecha: fecha });
cargar();
}
if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar);
else iniciar();
})();
