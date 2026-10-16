/* =====================================================================
   SIGMA · Centro Comercial · Cobros en drawers (16-10-2026, prompt V2)
   Suscripciones, Períodos, Pagos y Planes: lista en la pestaña
   «Suscripciones» y ficha en el cajón lateral (K.Panel). Nada de modales.

   Se carga ANTES de sigma-centro-comercial.js y se engancha con
   window.CCCobros(X), donde X es lo que el Centro ya tiene a mano (kit,
   estado, acciones). Habla con WsCobros.asmx, que valida facultad en cada
   llamada. Moneda: UF (se cobra en CLP con la UF del día) o USD (sin UF);
   nunca se suman montos de monedas distintas.

   Convenciones: clases cc-/cp- bajo .cc-root; todo <button> type="button";
   «activo», nunca «equipo»; mensajes por facultad, nunca por rol.
   ===================================================================== */
(function () {
'use strict';
window.CCCobros = function (X) {
var K = X.K, S = X.S, A = X.A, esc = K.esc, $ = K.$, ic = X.ic, chip = X.chip, dmy = X.dmy, hoyIso = X.hoyIso;
function call(m, d) { return K.llamar(X.ws, m, d); }

/* ------------------------------------------------------------ formato (es-CL) */
function fn(v, d) { return K.fN(v == null ? 0 : +v, d == null ? 0 : d); }
/* m: 'CLP' | 'UF' | 'USD'. CLP sin decimales; UF y USD con dos. */
function money(v, m) {
  if (v == null || v === '') return '—';
  if (m === 'UF') return fn(v, 2) + ' UF';
  if (m === 'USD') return 'USD ' + fn(v, 2);
  return '$' + fn(Math.round(+v), 0);
}
function cod(prefijo, id) { return prefijo + '-' + ('0000' + id).slice(-4); }
var MEDIO = { WEBPAY: 'Webpay', TRANSFERENCIA_NACIONAL: 'Transferencia', TRANSFERENCIA_INTERNACIONAL: 'Transferencia internacional' };
/* Un cliente que cobra en UF paga en pesos; uno que cobra en USD, en dólares. */
function chipCobro(moneda) { return moneda === 'USD' ? chip('USD · transferencia', 'pu') : chip('UF · CLP', 'bl'); }
function tonoPeriodo(n) { return { 'Pendiente de pago': 'wa', 'Con abono parcial': 'cy', 'Vigente': 'ok', 'Cerrado': 'gr', 'Anulado': 'da' }[n] || 'gr'; }
function tonoPago(c) { return c === 'VERIFICADO' ? 'ok' : c === 'RECHAZADO' ? 'da' : 'cy'; }

/* ------------------------------------------------------------ estado */
var C = { lista: {}, filtro: 'todas' };
var D = null;   // el drawer abierto de cobros

function cargar(v) {
  C.lista[v] = { cargando: true };
  var p = v === 'pagos' ? call('ListaPagos') : call('Lista', { vista: v });
  return p.then(function (r) { C.lista[v] = r; X.pintar(); }).catch(function (e) { C.lista[v] = { error: e.message }; X.pintar(); });
}
function recargar() {
  var v = S.sub.suscripciones || 'suscripciones';
  if (C.lista[v] && !C.lista[v].cargando) cargar(v);
  cargarAtencion();
}
/* Lo que pide acción (transferencias por verificar, mora): alimenta el grupo «Cobros» del Resumen. */
function cargarAtencion() {
  return call('Atencion').then(function (r) { C.atencion = r; if (S.tab === 'resumen') X.pintar(); }).catch(function () { C.atencion = null; });
}
var VISTAS = ['suscripciones', 'periodos', 'pagos', 'planes', 'empresas'];

/* ------------------------------------------------------------ componentes del drawer (DrawerComponentes) */
/* Sección colapsable en tarjeta blanca; la de la tarea actual va abierta. */
function sec(st, k, icono, tono, titulo, resumen, cuerpo) {
  var o = st.open[k];
  return '<section class="cc-sec"><button type="button" class="cc-sec-h" data-a="csec" data-v="' + k + '" aria-expanded="' + !!o + '">' +
    '<span style="color:var(--cc-' + tono + ')">' + ic(icono, 20) + '</span><b>' + titulo + '</b>' + (resumen || '') + ic(o ? 'chevu' : 'chevd', 20) + '</button>' +
    (o ? '<div class="cc-sec-b">' + cuerpo + '</div>' : '') + '</section>';
}
/* Barra inferior: destructiva (rojo de contorno) a la izquierda; a la derecha,
   contorno azul y UNA sola acción morada. */
function barra(destructiva, contorno, principal) {
  return (destructiva || '') + '<div class="cp-r">' + (contorno || '') + (principal || '') + '</div>';
}
function btn(clase, accion, texto, extra, icono) {
  return '<button type="button" class="cp-btn ' + clase + '" data-a="' + accion + '"' + (extra || '') + '>' + (icono ? ic(icono) : '') + texto + '</button>';
}
/* Barra de consumo: turquesa bajo 80 %, ámbar desde 80 %. */
function consumo(filas) {
  return '<div class="cc-uso">' + filas.map(function (c) {
    var uso = +c.USO || 0, tope = c.TOPE == null ? null : +c.TOPE, pct = tope ? Math.min(100, Math.round(uso / tope * 100)) : 0, alto = pct >= 80;
    return '<div><div class="cc-uso-h"><span>' + esc(c.NOMBRE) + '</span><b class="' + (alto ? 'cc-alto' : '') + '">' + fn(uso, c.CODIGO === 'LIMITE ALMACENAMIENTO' ? 2 : 0) + (tope ? ' de ' + fn(tope, 0) : ' · sin tope') + '</b></div>' +
      (tope ? '<span class="cc-meter"><span class="' + (alto ? 'cc-alto' : '') + '" style="width:' + pct + '%"></span></span>' : '') + '</div>';
  }).join('') + '</div>';
}
/* Clave de suscripción: completa una sola vez, con botón copiar. */
function cajaClave(clave) {
  return '<div class="cc-clave"><small>Clave de suscripción</small><div class="cc-clave-v"><code>' + esc(clave) + '</code>' +
    '<button type="button" class="cp-btn cp-out cp-sm" data-a="ccopiar" data-v="' + esc(clave) + '">' + ic('copy', 16) + 'Copiar</button></div>' +
    '<p>Se muestra completa <b>una sola vez</b>. Después solo queda el prefijo: si se pierde, hay que reemitirla. La clave anterior ya no sirve.</p></div>';
}
function fld(k, t, o) {
  o = o || {};
  var v = (D.f || {})[k];
  return '<div class="cp-fld' + (o.full ? ' cc-full' : '') + '"><label for="cc_' + k + '">' + t + '</label><input class="cp-inp" id="cc_' + k + '" data-pv="c.' + k + '" value="' + esc(v == null ? '' : v) + '"' +
    (o.ph ? ' placeholder="' + esc(o.ph) + '"' : '') + (o.ro ? ' readonly' : '') + (o.af ? ' data-autofocus="1"' : '') + '></div>';
}
function area(k, t, ph) {
  return '<div class="cp-fld cc-full"><label for="cc_' + k + '">' + t + '</label><textarea class="cp-inp" id="cc_' + k + '" data-pv="c.' + k + '"' + (ph ? ' placeholder="' + esc(ph) + '"' : '') + '>' + esc((D.f || {})[k] || '') + '</textarea></div>';
}
function aviso(txt, tono) { return '<div class="cc-info' + (tono === 'wa' ? ' cc-wa' : '') + '">' + ic(tono === 'wa' ? 'flag' : 'light') + '<span>' + txt + '</span></div>'; }

/* ------------------------------------------------------------ LISTAS */
function chipEstadoCobro(x) {
  if (x.mora) return ['En mora', 'da'];
  if (+x.porVerificar > 0) return ['Por verificar', 'cy'];
  if (+x.pendientes > 0) return ['Pendiente', 'wa'];
  if (x.ultimoMedio === 'WEBPAY') return ['Pagado en línea', 'ok'];
  if (x.ultimoMedio) return ['Transferencia verificada', 'ok'];
  return ['Sin cobros', 'gr'];
}
var FILTROS = [['todas', 'Todas', function () { return true; }],
  ['online', 'Pagado en línea', function (x) { return !x.mora && +x.pendientes === 0 && x.ultimoMedio === 'WEBPAY'; }],
  ['transf', 'Transferencia verificada', function (x) { return !x.mora && +x.pendientes === 0 && x.ultimoMedio && x.ultimoMedio !== 'WEBPAY'; }],
  ['pend', 'Pendiente', function (x) { return !x.mora && +x.pendientes > 0; }],
  ['mora', 'En mora', function (x) { return !!x.mora; }]];

function vistaSuscripciones(d) {
  var q = K.nrm(S.aq.trim());
  var base = d.filas.filter(function (x) { return !q || K.nrm([x.cliente, x.plan, x.contacto, x.correo, x.pais].join(' ')).indexOf(q) >= 0; });
  var f = FILTROS.filter(function (z) { return z[0] === C.filtro; })[0] || FILTROS[0];
  var rows = base.filter(f[2]);
  var chips = '<div class="cc-chips">' + FILTROS.map(function (z) {
    return '<button type="button" class="cc-fchip" aria-pressed="' + (C.filtro === z[0]) + '" data-a="cfiltro" data-v="' + z[0] + '">' + (z[0] === 'mora' ? '<span class="cc-dot"></span>' : '') + z[1] + ' <b>' + base.filter(z[2]).length + '</b></button>';
  }).join('') + '</div>';
  var cols = 'grid-template-columns:minmax(220px,2fr) 130px 150px 170px 130px minmax(160px,1.2fr)';
  var fila = function (x) {
    var e = chipEstadoCobro(x), t = !x.opera ? 'da' : x.dias != null && x.dias <= 30 ? 'wa' : 'ok';
    return '<div class="cc-crow" role="button" tabindex="0" style="' + cols + '" data-a="csus" data-id="' + x.id + '">' +
      '<span class="cc-c2"><b>' + esc(x.cliente) + '</b><span>' + esc(cod('SUS', x.id)) + (x.pais ? ' · ' + esc(x.pais) : '') + '</span></span>' +
      '<span style="font-size:13px;font-weight:600">' + esc(x.plan || '—') + '</span>' +
      '<span>' + chipCobro(x.moneda) + '</span>' +
      '<span class="cc-st">' + chip(e[0], e[1]) + (+x.pendientes > 0 ? '<span style="font-size:11.5px;color:var(--muted)">' + K.pl(+x.pendientes, 'período', 'períodos') + ' · ' + money(x.saldo, x.moneda === 'USD' ? 'USD' : 'CLP') + '</span>' : '') + '</span>' +
      '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + (x.hasta ? dmy(x.hasta) : 'Sin término') + '</span><span>' + chip(x.estadoNombre || x.estado || '—', t) + '</span></span>' +
      '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + esc(x.contacto || '—') + '</span><span>' + esc(x.correo || '') + '</span></span></div>';
  };
  var th = ['Cliente', 'Plan', 'Cobro', 'Estado del cobro', 'Vigente hasta', 'Contacto'];
  return '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccAQ" value="' + esc(S.aq) + '" placeholder="Cliente, plan, país o contacto" aria-label="Buscar"></label>' + chips + '</div>' +
    '<div class="cc-scroll"><div class="cc-tabla" style="min-width:1100px"><div class="cc-th" style="' + cols + '">' + th.map(function (h) { return '<span>' + h + '</span>'; }).join('') + '</div>' +
    '<div class="cc-filas">' + (rows.length ? rows.map(fila).join('') : '<div class="cc-vacio">No hay suscripciones con este filtro.</div>') + '</div></div></div>' +
    '<div class="cc-pie"><span>' + rows.length + ' de ' + d.filas.length + '</span><span>Clic en una fila para abrir su ficha</span></div></section>';
}

function vistaPeriodos(d) {
  var q = K.nrm(S.aq.trim());
  var rows = d.filas.filter(function (x) { return !q || K.nrm([x.CLI_NOMBRE, x.PLC_NOMBRE, x.SPD_NOMBRE].join(' ')).indexOf(q) >= 0; });
  var cols = 'grid-template-columns:minmax(200px,2fr) 120px 190px 140px 140px 130px 150px';
  var fila = function (x) {
    var usd = x.SPE_MONEDA === 'USD', m = usd ? 'USD' : 'CLP';
    return '<div class="cc-crow" role="button" tabindex="0" style="' + cols + '" data-a="cper" data-id="' + x.SPE_ID + '">' +
      '<span class="cc-c2"><b>' + esc(x.CLI_NOMBRE) + '</b><span>' + esc(x.PCB_NOMBRE || '') + (x.SPE_ES_IMPLANTACION ? ' · implementación' : '') + '</span></span>' +
      '<span style="font-size:13px;font-weight:600">' + esc(x.PLC_NOMBRE || '—') + '</span>' +
      '<span class="cc-num">' + dmy(x.SPE_FECHA_INICIO) + ' – ' + dmy(x.SPE_FECHA_FIN) + '</span>' +
      '<span class="cc-num cc-r">' + money(x.SPE_VALOR_UF_PLAN, usd ? 'USD' : 'UF') + '</span>' +
      '<span class="cc-num cc-r">' + money(x.SPE_MONTO_CLP, m) + '</span>' +
      '<span class="cc-num cc-r">' + money(x.SALDO_CLP, m) + '</span>' +
      '<span>' + chip(x.SPD_NOMBRE || '—', tonoPeriodo(x.SPD_NOMBRE)) + '</span></div>';
  };
  var th = ['Cliente', 'Plan', 'Período', 'Base', 'Monto', 'Saldo', 'Estado'];
  return '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccAQ" value="' + esc(S.aq) + '" placeholder="Cliente, plan o estado" aria-label="Buscar"></label></div>' +
    '<div class="cc-scroll"><div class="cc-tabla" style="min-width:1040px"><div class="cc-th" style="' + cols + '">' + th.map(function (h, i) { return '<span' + (i >= 3 && i <= 5 ? ' style="text-align:right"' : '') + '>' + h + '</span>'; }).join('') + '</div>' +
    '<div class="cc-filas">' + (rows.length ? rows.map(fila).join('') : '<div class="cc-vacio">Sin resultados.</div>') + '</div></div></div>' +
    '<div class="cc-pie"><span>' + rows.length + ' de ' + d.filas.length + '</span><span>Base: UF o USD según el cliente · Monto: CLP o USD · Los totales nunca mezclan monedas</span></div></section>';
}

/* Pagos: arriba la bandeja «Por verificar» con su botón; abajo los pagos recientes. */
function vistaPagos(d) {
  var q = K.nrm(S.aq.trim());
  var f = function (x) { return !q || K.nrm([x.CLI_NOMBRE, x.SPA_BANCO, x.SPA_NUMERO_OPERACION, x.SPO_NOMBRE].join(' ')).indexOf(q) >= 0; };
  var por = d.porVerificar.filter(f), rec = d.recientes.filter(f);
  var monto = function (x) { return money(x.SPA_MONTO_DECLARADO_CLP, x.SPA_MONEDA === 'USD' ? 'USD' : 'CLP'); };
  var fila = function (x, pend) {
    return '<div class="cc-li" style="grid-template-columns:minmax(160px,1.6fr) 110px 140px minmax(140px,1.2fr) 130px auto" role="button" tabindex="0" data-a="cpago" data-id="' + x.SPA_ID + '">' +
      '<span class="cc-c2"><b style="font-size:14px">' + esc(x.CLI_NOMBRE) + '</b><span>' + (x.SPE_FECHA_INICIO ? 'Período del ' + dmy(x.SPE_FECHA_INICIO) : '') + '</span></span>' +
      '<span class="cc-num">' + dmy(x.SPA_FECHA_TRANSFERENCIA) + '</span><b class="cc-num cc-r" style="text-align:left">' + monto(x) + '</b>' +
      '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + esc(x.SPA_BANCO || '—') + '</span><span>' + esc(x.SPA_NUMERO_OPERACION || '') + '</span></span>' +
      '<span>' + chip(MEDIO[x.SPA_MEDIO] || '—', x.SPA_MEDIO === 'WEBPAY' ? 'ok' : x.SPA_MEDIO === 'TRANSFERENCIA_INTERNACIONAL' ? 'pu' : 'bl') + '</span>' +
      (pend ? (d.verificar ? '<button type="button" class="cp-btn cp-pri cp-sm" data-a="cpago" data-id="' + x.SPA_ID + '">Verificar</button>' : '<span></span>') : '<span>' + chip(x.SPO_NOMBRE, tonoPago(x.SPO_CODIGO)) + '</span>') + '</div>';
  };
  var encabezado = '<div class="cc-th" style="grid-template-columns:minmax(160px,1.6fr) 110px 140px minmax(140px,1.2fr) 130px 110px"><span>Cliente</span><span>Transferido</span><span>Monto</span><span>Banco · operación</span><span>Medio</span><span></span></div>';
  return '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccAQ" value="' + esc(S.aq) + '" placeholder="Cliente, banco u operación" aria-label="Buscar"></label>' +
    (d.banco ? '<button type="button" class="cp-btn cp-out" data-a="cbanco">' + ic('badge') + 'Datos para transferir</button>' : '') + '</div>' +
    '<div class="cc-grp-t" style="padding-top:2px">' + ic('clock', 16) + 'Por verificar<b>' + por.length + '</b></div>' +
    '<div class="cc-scroll"><div class="cc-tabla" style="min-width:900px">' + encabezado + '<div class="cc-filas">' +
    (por.length ? por.map(function (x) { return fila(x, true); }).join('') : '<div class="cc-vacio">No hay transferencias esperando verificación.</div>') + '</div></div></div>' +
    '<div class="cc-grp-t" style="padding-top:8px">' + ic('check', 16) + 'Pagos recientes<b>' + rec.length + '</b></div>' +
    '<div class="cc-scroll"><div class="cc-tabla" style="min-width:900px"><div class="cc-filas">' +
    (rec.length ? rec.map(function (x) { return fila(x, false); }).join('') : '<div class="cc-vacio">Sin pagos.</div>') + '</div></div></div></section>';
}

function vista(v) {
  var d = C.lista[v];
  if (!d) { cargar(v); d = C.lista[v]; }
  var cab = X.segSub(v === 'empresas' ? 'clientes' : 'suscripciones');
  if (d.cargando) return cab + '<div class="cc-cargando">Cargando…</div>';
  if (d.error) return cab + '<div class="cc-vacio">' + esc(d.error) + '</div>';
  return cab + (v === 'periodos' ? vistaPeriodos(d) : v === 'pagos' ? vistaPagos(d) : v === 'planes' ? vistaPlanes(d) : v === 'empresas' ? vistaEmpresas(d) : vistaSuscripciones(d));
}

/* Grupo «Cobros» al inicio de «Requiere atención» del Resumen. item(...) lo arma el Centro. */
function grupoCobros() {
  var a = C.atencion; if (!a) return null;
  var it = function (icono, tono, titulo, sub, ch, accion, id) {
    return '<button type="button" class="cc-att" data-a="' + accion + '" data-id="' + id + '">' + X.icb(icono, tono, 36) +
      '<span class="cc-tx"><b>' + esc(titulo) + '</b><span>' + esc(sub) + '</span></span>' + (ch ? chip(ch[0], ch[1]) : '') +
      '<span class="cc-ver">' + (accion === 'cpago' ? 'Verificar' : 'Ver suscripción') + ic('chev') + '</span></button>';
  };
  var filas = [];
  (a.porVerificar || []).forEach(function (x) {
    filas.push(it('wallet', 'cy', x.CLIENTE + ' · transferencia por verificar', money(x.MONTO, x.MONEDA === 'USD' ? 'USD' : 'CLP') + (x.BANCO ? ' · ' + x.BANCO : '') + ' · transferida el ' + dmy(x.FECHA), ['Por verificar', 'cy'], 'cpago', x.ID));
  });
  (a.mora || []).forEach(function (x) {
    var d = x.DIAS_PARA_SUSPENDER;
    filas.push(it('timer', 'da', x.CLIENTE + ' · cobro en mora', 'Saldo ' + money(x.SALDO, x.MONEDA === 'USD' ? 'USD' : 'CLP') + ' · ' + K.pl(+x.DIAS_MORA, 'día', 'días') + ' de atraso', ['En mora', 'da'], 'csus', x.SUSCRIPCION));
    if (d != null && d >= 0 && d <= 10) filas.push(it('clock', 'wa', x.CLIENTE + ' · se suspende en ' + K.pl(+d, 'día', 'días'), 'Si no paga, el acceso se corta al terminar los días de gracia', ['Se suspende en ' + d + ' d', 'wa'], 'csus', x.SUSCRIPCION));
  });
  return filas.length ? ['wallet', 'Cobros', filas] : null;
}

/* Botón principal del encabezado según la pestaña (prompt V2 §1). */
function boton() {
  if (S.tab === 'suscripciones') {
    var sub = S.sub.suscripciones || X.subPorDefecto('suscripciones');
    var puede = C.lista.periodos ? C.lista.periodos.emitir : true;
    if (puede) return '<button type="button" class="cp-btn cp-pri" data-a="cemitir">' + ic('plus', 20) + 'Emitir período</button>';
    void sub;
  }
  /* «Nuevo cliente», nunca «Nueva empresa» (prompt V2 §1). */
  if (S.tab === 'clientes') return '<button type="button" class="cp-btn cp-pri" data-a="cclientenuevo">' + ic('plus', 20) + 'Nuevo cliente</button>';
  return null;
}

/* ------------------------------------------------------------ DRAWER · SUSCRIPCIÓN (600 px) */
function formSus(d) {
  var s = d.s;
  return { estado: String(s.estadoId), habilitado: !!s.habilitado, contactoNombre: s.contactoNombre || '', contactoCorreo: s.contactoCorreo || '', contactoTelefono: s.contactoTelefono || '', observacion: s.observacion || '' };
}
function abrirSuscripcion(id) {
  D = { tipo: 'sus', id: +id, data: null, modo: 'ver', open: { datos: true, contacto: false, uso: true, vig: false, acc: false }, f: {}, busy: false, motivo: '', plan: '', per: '', clave: null };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; recargar(); } });
  call('Suscripcion', { id: +id }).then(function (d) { if (D && D.id === +id) { D.data = d; D.f = formSus(d); K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function actualizar(d, msg) {
  if (!D) return;
  D.data = d.ficha || d; D.f = D.tipo === 'sus' ? formSus(D.data) : D.f; D.busy = false; D.modo = 'ver';
  K.Panel.paint();
  if (msg) K.toast(msg);
}
function ocupado(p) { if (D) { D.busy = true; K.Panel.paint(); } return p.catch(function (e) { if (D) { D.busy = false; K.Panel.paint(); } K.toastError(e); throw e; }); }

function renderSus(st) {
  var d = st.data;
  if (!d) return { w: 'c', s: 'Cobros', t: 'Suscripción', b: '<div class="cc-cargando">Cargando la suscripción…</div>' };
  var s = d.s, p = d.permisos;
  var tono = !s.opera ? 'da' : (s.estado || '').toUpperCase() === 'EN GRACIA' ? 'bl' : 'ok';
  var cab = { w: 'c', s: esc(cod('SUS', s.id)) + ' · ' + esc(s.cliente), t: 'Suscripción ' + (s.hasta ? chip(s.estado || s.estadoNombre, tono) : chip('Sin períodos', 'gr')) };
  var dis = st.busy ? ' disabled' : '';

  if (st.modo === 'clave-emitida') {
    cab.b = cajaClave(st.clave) + aviso('Cópiala ahora y hazla llegar al cliente. Su instalación queda desconectada hasta que cargue esta clave.', 'wa');
    cab.f = barra('', '', btn('cp-pri', 'cvolver', 'Listo', '', 'check'));
    return cab;
  }
  if (st.modo === 'clave') {
    cab.b = aviso('<b>Esto corta lo que funcionaba.</b> La clave actual deja de servir en el momento: la instalación del cliente se desconecta hasta que le cargues la nueva.', 'wa') +
      area('motivo', 'Motivo de la reemisión (queda auditado)', 'Ej.: el cliente perdió la clave al migrar de servidor') +
      '<div class="cc-nota">El motivo es obligatorio y queda en el historial de la clave junto a tu usuario y la fecha.</div>';
    cab.f = btn('cp-ghost', 'cvolver', 'Cancelar') + '<div class="cp-r">' + btn('cp-pri', 'creemitir', st.busy ? 'Reemitiendo…' : 'Reemitir clave', dis, 'refresh') + '</div>';
    return cab;
  }
  if (st.modo === 'plan') {
    var planes = d.planes.filter(function (x) { return x.id !== s.planId; });
    var pers = [{ id: '', n: 'La misma de hoy' }].concat(d.periodicidades);
    cab.b = '<div class="cc-info">' + ic('light') + '<span>Plan actual: <b>' + esc(s.plan || '—') + '</b>. Si subes de plan, se cobra solo la diferencia prorrateada de los días que quedan. Si bajas, se aplica al cierre del período y no hay devolución.</span></div>' +
      '<div class="cc-grid2"><div class="cp-fld"><label>Plan nuevo</label>' + K.combo('ccPlanNuevo', planes.map(function (x) { return { id: String(x.id), n: x.n }; }), st.plan, { ph: 'Elige un plan', etiqueta: 'Plan nuevo' }) + '</div>' +
      '<div class="cp-fld"><label>Periodicidad</label>' + K.combo('ccPerNueva', pers.map(function (x) { return { id: String(x.id), n: x.n }; }), st.per, { ph: 'La misma de hoy', etiqueta: 'Periodicidad' }) + '</div></div>';
    cab.f = btn('cp-ghost', 'cvolver', 'Cancelar') + '<div class="cp-r">' + btn('cp-pri', 'cplanok', st.busy ? 'Cambiando…' : 'Cambiar de plan', dis + (st.plan ? '' : ' disabled'), 'refresh') + '</div>';
    return cab;
  }

  /* modo ver */
  var f = st.f, ed = p.editar;
  var estados = d.estados.map(function (x) { return { id: String(x.id), n: x.n }; });
  var ro = ed ? '' : ' readonly';
  var datos = '<dl class="cc-dl"><dt>ID</dt><dd>' + esc(cod('SUS', s.id)) + '</dd>' +
    '<dt>Clave</dt><dd><code style="font-family:Consolas,monospace">' + (s.key ? esc(s.key) + '-••••-••••-••••' : '—') + '</code></dd>' +
    '<dt>Plan</dt><dd>' + esc(s.plan || '—') + '</dd>' +
    '<dt>Cobro</dt><dd>' + chipCobro(s.moneda) + (s.pais ? ' <span style="color:var(--muted);font-weight:500">· ' + esc(s.pais) + '</span>' : '') + '</dd></dl>' +
    '<div class="cc-grid2"><div class="cp-fld"><label>Estado</label>' + (ed ? K.combo('ccSusEstado', estados, f.estado, { etiqueta: 'Estado' }) : '<input class="cp-inp" value="' + esc(s.estadoNombre) + '" readonly>') + '</div>' +
    '<div class="cp-fld"><label for="cc_hab">Habilitada</label><label class="cc-acu" style="height:40px"><input type="checkbox" id="cc_hab" data-pv="c.habilitado"' + (f.habilitado ? ' checked' : '') + (ed ? '' : ' disabled') + '><span style="font-size:13px">' + (f.habilitado ? 'Sí, puede operar' : 'No, deshabilitada') + '</span></label></div></div>' +
    '<div class="cp-fld cc-full"><label for="cc_observacion">Observación</label><textarea class="cp-inp" id="cc_observacion" data-pv="c.observacion"' + ro + '>' + esc(f.observacion) + '</textarea></div>';
  var contacto = '<div class="cc-grid2">' + fld('contactoNombre', 'Nombre', { full: 1, ro: !ed }) + fld('contactoCorreo', 'Correo', { ro: !ed }) + fld('contactoTelefono', 'Teléfono', { ro: !ed }) + '</div>' +
    '<div class="cc-nota">A este contacto le llegan los cobros y recordatorios, con copia al ejecutivo a cargo.</div>';
  var vig = '<div class="cc-mini"><div><small>Desde</small><b>' + (s.desde ? dmy(s.desde) : '—') + '</b></div><div><small>Hasta</small><b>' + (s.hasta ? dmy(s.hasta) : '—') + '</b></div><div><small>Días de gracia</small><b>' + fn(s.gracia, 0) + '</b></div></div>' +
    (s.hasta ? aviso(s.dias != null && s.dias >= 0 ? 'Quedan <b>' + K.pl(s.dias, 'día', 'días') + '</b> de vigencia. El acceso dura mientras haya meses pagados.' : 'Venció hace <b>' + K.pl(Math.abs(s.dias || 0), 'día', 'días') + '</b>.' + (s.opera ? ' Está usando los días de gracia.' : ' <b>El cliente no puede operar.</b>'), s.opera && s.dias >= 0 ? '' : 'wa')
      : aviso('Todavía no se emitió ningún período: la suscripción existe pero no habilita nada hasta que se cobre el primero.', 'wa'));
  var per = d.periodos.slice(0, 5), pag = d.pagos.slice(0, 5);
  var acc = '<div class="cc-sub">Períodos</div>' + (per.length ? per.map(function (x) {
    var m = x.SPE_MONEDA === 'USD' ? 'USD' : 'CLP';
    return '<div class="cc-li" style="grid-template-columns:96px minmax(0,1fr) auto auto"><span class="cc-m">' + dmy(x.SPE_FECHA_INICIO) + '</span><span>' + chip(x.SPD_NOMBRE, tonoPeriodo(x.SPD_NOMBRE)) + '</span><b>' + money(x.SPE_MONTO_CLP, m) + '</b><button type="button" class="cc-lnk" data-a="cper" data-id="' + x.SPE_ID + '">Ver</button></div>';
  }).join('') : '<div class="cc-nota">Sin períodos emitidos.</div>') +
    '<div class="cc-sub" style="margin-top:6px">Pagos</div>' + (pag.length ? pag.map(function (x) {
    var m = x.SPA_MONEDA === 'USD' ? 'USD' : 'CLP';
    return '<div class="cc-li" style="grid-template-columns:96px minmax(0,1fr) auto auto"><span class="cc-m">' + dmy(x.SPA_FECHA_TRANSFERENCIA) + '</span><span>' + chip(x.SPO_NOMBRE, tonoPago(x.SPO_CODIGO)) + ' <span class="cc-m">' + esc(MEDIO[x.SPA_MEDIO] || '') + '</span></span><b>' + money(x.SPA_MONTO_DECLARADO_CLP, m) + '</b><button type="button" class="cc-lnk" data-a="cpago" data-id="' + x.SPA_ID + '">Ver</button></div>';
  }).join('') : '<div class="cc-nota">Sin pagos registrados.</div>');
  cab.b = sec(st, 'datos', 'badge', 'pu', 'Datos', '', datos) +
    sec(st, 'contacto', 'person', 'bl', 'Contacto de cobro', '<small>' + esc(s.contactoNombre || 'Sin contacto') + '</small>', contacto) +
    sec(st, 'uso', 'dash', 'cy', 'Uso contra topes', '', consumo(d.consumo)) +
    sec(st, 'vig', 'clock', 'wa', 'Vigencia', s.dias != null ? '<small>' + (s.dias >= 0 ? s.dias + ' d' : 'vencida') + '</small>' : '', vig) +
    sec(st, 'acc', 'list', 'pu', 'Períodos y pagos', '', acc);
  cab.f = barra(p.reemitir ? btn('cp-dano', 'cclave', 'Reemitir clave', dis, 'refresh') : '',
    p.cambiarPlan ? btn('cp-out', 'cplan', 'Cambiar de plan', dis, 'arrow') : '',
    ed ? btn('cp-pri', 'csusok', st.busy ? 'Guardando…' : 'Guardar', dis) : '');
  return cab;
}

/* ------------------------------------------------------------ DRAWER · PERÍODO (600 px) */
function abrirPeriodo(id) {
  D = { tipo: 'per', id: +id, data: null, modo: 'emitido', open: { detalle: true, calculo: true, pagos: true }, f: {}, busy: false };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; recargar(); } });
  call('Periodo', { id: +id }).then(function (d) { if (D && D.id === +id) { D.data = d; K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function abrirEmitir(susId) {
  D = { tipo: 'per', id: 0, data: null, modo: 'emitir', open: {}, busy: false, op: null,
    f: { sus: susId ? String(susId) : '', per: '', plan: '', valor: '', impl: false, obs: '' } };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; recargar(); } });
  call('OpcionesEmitir', { suscripcion: susId || null }).then(function (o) { if (D && D.modo === 'emitir') { D.op = o; if (!D.f.sus && o.suscripciones.length === 1) D.f.sus = String(o.suscripciones[0].id); K.Panel.paint(); } })
    .catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function susDe(st) { return st.op ? st.op.suscripciones.filter(function (x) { return String(x.id) === String(st.f.sus); })[0] : null; }

function renderPer(st) {
  var dis = st.busy ? ' disabled' : '';
  if (st.modo === 'emitir') {
    if (!st.op) return { w: 'c', s: 'Cobros', t: 'Emitir período', b: '<div class="cc-cargando">Cargando…</div>' };
    var f = st.f, sus = susDe(st), usd = sus && sus.moneda === 'USD';
    var items = st.op.suscripciones.map(function (x) { return { id: String(x.id), n: x.cliente + ' · ' + (x.plan || 'sin plan') + ' · ' + (x.moneda === 'USD' ? 'USD' : 'UF') }; });
    var planes = [{ id: '', n: 'El plan contratado' }].concat(st.op.planes.map(function (x) { return { id: String(x.id), n: x.n }; }));
    var pers = st.op.periodicidades.map(function (x) { return { id: String(x.id), n: x.n }; });
    var b = '<div class="cp-fld"><label>Suscripción</label>' + K.combo('ccEmSus', items, f.sus, { ph: 'Elige un cliente', etiqueta: 'Suscripción' }) + '</div>' +
      (sus ? '<div class="cc-wrap">' + chipCobro(sus.moneda) + '<span>' + (usd ? 'Se cobra en dólares, sin conversión: el monto es el precio vigente en USD.' : 'Se cobra en pesos, con la UF del día de emisión. Ese valor queda congelado.') + '</span></div>' : '') +
      '<div class="cc-grid2"><div class="cp-fld"><label>Periodicidad</label>' + K.combo('ccEmPer', pers, f.per, { ph: 'Elige', etiqueta: 'Periodicidad' }) + '</div>' +
      '<div class="cp-fld"><label>Plan</label>' + K.combo('ccEmPlan', planes, f.plan, { ph: 'El plan contratado', etiqueta: 'Plan' }) + '</div></div>' +
      '<div class="cp-fld"><label for="cc_valor">Monto en ' + (usd ? 'USD' : 'UF') + ' (opcional)</label><input class="cp-inp" id="cc_valor" inputmode="decimal" data-pv="c.valor" value="' + esc(f.valor) + '" placeholder="Vacío = precio vigente del plan"></div>' +
      '<label class="cc-acu"><input type="checkbox" data-pv="c.impl"' + (f.impl ? ' checked' : '') + '><span style="font-size:13px"><b>Es implementación</b> (sin un monto explícito se emite en cero)</span></label>' +
      area('obs', 'Observación');
    return { w: 'c', s: 'Cobros', t: 'Emitir período ' + chip('Sin emitir', 'gr'), b: b + aviso('Emitir es cobrar: el período arranca donde terminó el anterior y no se puede editar después.', ''),
      f: btn('cp-ghost', 'pclose', 'Cancelar') + '<div class="cp-r">' + btn('cp-pri', 'cemitirok', st.busy ? 'Emitiendo…' : 'Emitir período', dis + (f.sus && f.per ? '' : ' disabled'), 'check') + '</div>' };
  }
  var d = st.data;
  if (!d) return { w: 'c', s: 'Cobros', t: 'Período', b: '<div class="cc-cargando">Cargando el período…</div>' };
  var p = d.periodo, usd2 = p.SPE_MONEDA === 'USD', m = usd2 ? 'USD' : 'CLP';
  var detalle = '<dl class="cc-dl"><dt>Cliente</dt><dd>' + esc(p.CLI_NOMBRE) + '</dd><dt>Plan</dt><dd>' + esc(p.PLC_NOMBRE || '—') + '</dd><dt>Periodicidad</dt><dd>' + esc(p.PCB_NOMBRE || '—') + '</dd>' +
    '<dt>Desde – hasta</dt><dd>' + dmy(p.SPE_FECHA_INICIO) + ' – ' + dmy(p.SPE_FECHA_FIN) + '</dd><dt>Cobro</dt><dd>' + chipCobro(p.SPE_MONEDA) + '</dd>' +
    (p.SPE_ES_IMPLANTACION ? '<dt>Tipo</dt><dd>Implementación</dd>' : '') + (p.SPE_OBSERVACION ? '<dt>Observación</dt><dd>' + esc(p.SPE_OBSERVACION) + '</dd>' : '') + '</dl>';
  var calculo = usd2
    ? '<dl class="cc-dl2"><dt>Precio del plan en USD</dt><dd>' + money(p.SPE_VALOR_UF_PLAN, 'USD') + '</dd><dt>Conversión</dt><dd>Ninguna</dd><dt class="cc-tot">Monto a cobrar</dt><dd class="cc-tot">' + money(p.SPE_MONTO_CLP, 'USD') + '</dd></dl>'
    : '<dl class="cc-dl2"><dt>Precio del plan</dt><dd>' + money(p.SPE_VALOR_UF_PLAN, 'UF') + '</dd><dt>Valor de la UF el ' + (p.SPE_FECHA_VALOR_UF ? dmy(p.SPE_FECHA_VALOR_UF) : 'día de emisión') + '</dt><dd>' + money(p.SPE_VALOR_UF_DIA, 'CLP') + '</dd><dt class="cc-tot">Monto a cobrar</dt><dd class="cc-tot">' + money(p.SPE_MONTO_CLP, 'CLP') + '</dd></dl>';
  var pagos = d.pagos.length ? d.pagos.map(function (x) {
    var mm = x.SPA_MONEDA === 'USD' ? 'USD' : 'CLP';
    return '<div class="cc-li" style="grid-template-columns:96px minmax(0,1fr) auto auto"><span class="cc-m">' + dmy(x.SPA_FECHA_TRANSFERENCIA) + '</span><span>' + chip(x.SPO_NOMBRE, tonoPago(x.SPO_CODIGO)) + ' <span class="cc-m">' + esc(MEDIO[x.SPA_MEDIO] || '') + (x.SPA_BANCO ? ' · ' + esc(x.SPA_BANCO) : '') + '</span></span><b>' + money(x.SPA_MONTO_DECLARADO_CLP, mm) + '</b><button type="button" class="cc-lnk" data-a="cpago" data-id="' + x.SPA_ID + '">Ver</button></div>';
  }).join('') : '<div class="cc-nota">Todavía no hay pagos en este período.</div>';
  var hero = '<div class="cc-hero"><small>' + (p.SPE_ES_IMPLANTACION ? 'Implementación' : 'Mensualidad') + '</small><strong>' + money(p.SPE_MONTO_CLP, m) + '</strong>' +
    '<span>Pagado ' + money(p.SPE_MONTO_PAGADO_CLP, m) + ' · saldo <b>' + money(p.SALDO_CLP, m) + '</b></span></div>';
  return { w: 'c', s: esc(p.CLI_NOMBRE), t: 'Período ' + dmy(p.SPE_FECHA_INICIO) + ' – ' + dmy(p.SPE_FECHA_FIN) + ' ' + chip(p.SPD_NOMBRE, tonoPeriodo(p.SPD_NOMBRE)),
    b: hero + sec(st, 'detalle', 'badge', 'pu', 'Detalle', '', detalle) + sec(st, 'calculo', 'quote', 'cy', 'Cómo se calculó', '', calculo +
      '<div class="cc-nota">' + (usd2 ? 'El precio quedó fijado al emitir; no se recalcula.' : 'Estos números quedaron congelados al emitir: no se recalculan con la UF de hoy.') + '</div>') +
      sec(st, 'pagos', 'list', 'ok', 'Pagos', '<small>' + d.pagos.length + '</small>', pagos),
    f: barra('', btn('cp-out', 'csus', 'Ver suscripción', ' data-id="' + p.SPE_SUSCRIPCION + '"', 'open'),
      d.permisos && d.permisos.informar && +p.SALDO_CLP > 0 ? btn('cp-sec', 'cinformar', 'Informar transferencia', ' data-sus="' + p.SPE_SUSCRIPCION + '" data-per="' + p.SPE_ID + '"', 'wallet') : '') };
}

/* ------------------------------------------------------------ DRAWER · PAGO (informar 600 · verificar 760) */
function formPago(d) {
  var p = d.pago;
  return { monto: String(p.SPA_MONTO_VERIFICADO_CLP != null ? p.SPA_MONTO_VERIFICADO_CLP : p.SPA_MONTO_DECLARADO_CLP), mdec: String(p.SPA_MONTO_DECLARADO_CLP),
    fecha: p.SPA_FECHA_TRANSFERENCIA ? String(p.SPA_FECHA_TRANSFERENCIA).slice(0, 10) : '', banco: p.SPA_BANCO || '', operacion: p.SPA_NUMERO_OPERACION || '', motivo: '' };
}
function abrirPago(id, modo) {
  D = { tipo: 'pago', id: +id, data: null, modo: modo || 'ver', open: { datos: true, periodo: true, medio: true }, f: {}, busy: false, rechazar: false };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; recargar(); } });
  call('Pago', { id: +id }).then(function (d) { if (D && D.id === +id) { D.data = d; D.f = formPago(d); K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
/* Informar una transferencia (período + monto + fecha + banco + operación + comprobante). */
function abrirInformar(susId, periodoId) {
  D = { tipo: 'pago', id: 0, data: null, modo: 'informar', open: {}, busy: false, sus: +susId, op: null, file: null,
    f: { periodo: periodoId ? String(periodoId) : '', monto: '', fecha: hoyIso(), banco: '', operacion: '' } };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; recargar(); } });
  call('OpcionesPago', { suscripcion: +susId }).then(function (o) {
    if (!D || D.modo !== 'informar') return;
    D.op = o;
    if (!D.f.periodo && o.periodos.length) D.f.periodo = String(o.periodos[0].SPE_ID);
    var p = o.periodos.filter(function (x) { return String(x.SPE_ID) === String(D.f.periodo); })[0];
    if (p && !D.f.monto) D.f.monto = String(p.SALDO_CLP);
    K.Panel.paint();
  }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function datosBanco(datos) {
  var f = (datos || []).filter(function (x) { return x.valor; });
  if (!f.length) return aviso('Los datos bancarios todavía no están cargados. Pídele a quien administra la configuración comercial que los complete en «Datos para transferir».', 'wa');
  return '<dl class="cc-dl">' + f.map(function (x) { return '<dt>' + esc(x.etiqueta) + '</dt><dd>' + esc(x.valor) + '</dd>'; }).join('') + '</dl>';
}
function visor(c) {
  if (!c) return '<div class="cc-visor"><div class="cc-visor-v">Este pago no tiene comprobante adjunto.</div></div>';
  var m = (c.mime || '').toLowerCase();
  var cuerpo = m.indexOf('image/') === 0 ? '<img src="' + esc(c.ver) + '" alt="Comprobante de la transferencia">'
    : m === 'application/pdf' ? '<iframe src="' + esc(c.ver) + '" title="Comprobante de la transferencia"></iframe>'
    : '<div class="cc-visor-v">Este tipo de archivo no se puede mostrar aquí. Ábrelo en otra pestaña.</div>';
  return '<div class="cc-visor"><div class="cc-visor-h">' + ic('pdf', 16) + '<b>' + esc(c.nombre) + '</b><a class="cc-lnk" href="' + esc(c.ver) + '" target="_blank" rel="noopener">Abrir</a><a class="cc-lnk" href="' + esc(c.bajar) + '">Bajar</a></div>' + cuerpo + '</div>';
}
function resumenPago(d) {
  var p = d.pago, per = d.periodo || {}, m = p.SPA_MONEDA === 'USD' ? 'USD' : 'CLP';
  return '<dl class="cc-dl"><dt>Cliente</dt><dd>' + esc(p.CLI_NOMBRE) + '</dd>' +
    '<dt>Período</dt><dd>' + (per.SPE_FECHA_INICIO ? dmy(per.SPE_FECHA_INICIO) + ' – ' + dmy(per.SPE_FECHA_FIN) + ' · ' + money(per.SPE_MONTO_CLP, m) : '—') + '</dd>' +
    '<dt>Medio</dt><dd>' + esc(MEDIO[p.SPA_MEDIO] || '—') + '</dd>' +
    '<dt>Declarado</dt><dd>' + money(p.SPA_MONTO_DECLARADO_CLP, m) + '</dd>' +
    (p.SPA_MONTO_VERIFICADO_CLP != null ? '<dt>Verificado</dt><dd>' + money(p.SPA_MONTO_VERIFICADO_CLP, m) + '</dd>' : '') +
    '<dt>Transferido el</dt><dd>' + dmy(p.SPA_FECHA_TRANSFERENCIA) + '</dd>' +
    '<dt>Banco</dt><dd>' + esc(p.SPA_BANCO || '—') + '</dd><dt>N° de operación</dt><dd>' + esc(p.SPA_NUMERO_OPERACION || '—') + '</dd></dl>';
}

function avisoDif(dif, m) {
  return Math.abs(dif) > 0.004 ? aviso('El monto verificado difiere del declarado en <b>' + money(Math.abs(dif), m) + '</b>. Si el período no queda cubierto, seguirá con saldo.', 'wa') : '';
}
function renderPago(st) {
  var dis = st.busy ? ' disabled' : '';
  if (st.modo === 'informar') {
    if (!st.op) return { w: 'c', s: 'Cobros', t: 'Informar transferencia', b: '<div class="cc-cargando">Cargando…</div>' };
    var o = st.op, f = st.f, m = o.moneda === 'USD' ? 'USD' : 'CLP';
    var pers = o.periodos.map(function (x) { return { id: String(x.SPE_ID), n: dmy(x.SPE_FECHA_INICIO) + ' – ' + dmy(x.SPE_FECHA_FIN) + ' · saldo ' + money(x.SALDO_CLP, m) }; });
    var b = (o.almacenamiento ? '' : aviso('<b>No se puede informar todavía.</b> El almacenamiento de comprobantes no está configurado y el comprobante es obligatorio.', 'wa')) +
      '<section class="cc-sec"><div class="cc-sec-h" style="cursor:default"><span style="color:var(--cc-cyd)">' + ic('wallet', 20) + '</span><b>A dónde transferir</b><small>' + (m === 'USD' ? 'Transferencia internacional' : 'Transferencia nacional') + '</small></div>' +
        '<div class="cc-sec-b">' + datosBanco(o.datos) + (m === 'USD' ? '<div class="cc-nota">Los gastos bancarios de la transferencia internacional corren por cuenta del cliente.</div>' : '') + '</div></section>' +
      (pers.length ? '<div class="cp-fld"><label>Período que se está pagando</label>' + K.combo('ccPagoPer', pers, f.periodo, { ph: 'Elige el período', etiqueta: 'Período' }) + '</div>'
        : aviso('Este cliente no tiene períodos con saldo por pagar.', 'wa')) +
      '<div class="cc-grid2"><div class="cp-fld"><label for="cc_monto">Monto transferido (' + (m === 'USD' ? 'USD' : 'CLP') + ')</label><input class="cp-inp" id="cc_monto" inputmode="decimal" data-pv="c.monto" value="' + esc(f.monto) + '"></div>' +
      '<div class="cp-fld"><span class="cp-lb">Fecha de la transferencia</span>' + K.fecha('pago.fecha', f.fecha, { etiqueta: 'Fecha de la transferencia' }) + '</div>' +
      fld('banco', 'Banco') + fld('operacion', 'N° de operación') + '</div>' +
      '<label class="cc-drop" id="ccDrop"><input type="file" id="ccFile" accept="application/pdf,image/*">' + ic('upload', 22) + (st.file ? '<b>' + esc(st.file.nombre) + '</b><span>' + K.fN(st.file.bytes / 1024, 0) + ' KB · pulsa para cambiarlo</span>' : '<b>Suelta aquí el comprobante</b><span>PDF o imagen, hasta 8 MB · o pulsa para elegirlo</span>') + '</label>';
    return { w: 'c', s: esc(o.cliente), t: 'Informar transferencia ' + chip('Sin informar', 'gr'), b: b,
      f: btn('cp-ghost', 'pclose', 'Cancelar') + '<div class="cp-r">' + btn('cp-pri', 'cinformok', st.busy ? 'Informando…' : 'Informar pago', dis + (f.periodo && st.file && o.almacenamiento ? '' : ' disabled'), 'check') + '</div>' };
  }
  var d = st.data;
  if (!d) return { w: 'w', s: 'Cobros', t: 'Pago', b: '<div class="cc-cargando">Cargando el pago…</div>' };
  var p = d.pago, per = d.periodo || {}, m2 = p.SPA_MONEDA === 'USD' ? 'USD' : 'CLP', f2 = st.f;
  var pendiente = +p.SPA_ESTADO === 1 || +p.SPA_ESTADO === 2, rechazado = +p.SPA_ESTADO === 4;
  var chipE = chip(p.SPO_NOMBRE, tonoPago(p.SPO_CODIGO));
  var tit = 'Pago ' + cod('PAG', p.SPA_ID) + ' ' + chipE;
  var sub = esc(p.CLI_NOMBRE) + ' · ' + esc(MEDIO[p.SPA_MEDIO] || '');

  if (d.webpay || p.SPA_MEDIO === 'WEBPAY') {
    var w = d.webpay || {};
    return { w: 'c', s: sub, t: tit,
      b: '<div class="cc-hero"><small>Pagado con Webpay</small><strong>' + money(p.SPA_MONTO_DECLARADO_CLP, m2) + '</strong><span>' + dmy(p.SPA_FECHA_TRANSFERENCIA) + ' · ' + chip('Verificado automáticamente', 'ok') + '</span></div>' +
        (w.ambiente && w.ambiente !== 'PRODUCCION' ? aviso('<b>Modo de prueba.</b> Este pago se hizo en el ambiente de integración de Transbank: no se cobró dinero real.', 'wa') : '') +
        '<dl class="cc-dl"><dt>Tarjeta</dt><dd>' + (w.tarjeta ? '****' + esc(w.tarjeta) : '—') + '</dd><dt>Autorización</dt><dd>' + esc(w.autorizacion || '—') + '</dd><dt>Orden de compra</dt><dd>' + esc(w.orden || '—') + '</dd>' +
        '<dt>Tipo de pago</dt><dd>' + esc(w.tipo || '—') + (w.cuotas ? ' · ' + w.cuotas + ' cuotas' : '') + '</dd><dt>Período</dt><dd>' + (per.SPE_FECHA_INICIO ? dmy(per.SPE_FECHA_INICIO) + ' – ' + dmy(per.SPE_FECHA_FIN) : '—') + '</dd></dl>' +
        '<div class="cc-nota">Es solo lectura: el pago entró solo, quedó verificado y extendió el acceso hasta el fin del período.</div>',
      f: barra('', d.comprobante ? '<a class="cp-btn cp-out" href="' + esc(d.comprobante.ver) + '" target="_blank" rel="noopener">' + ic('pdf') + 'Ver comprobante</a>' : '', btn('cp-ghost', 'pclose', 'Cerrar')) };
  }

  if (st.modo === 'corregir') {
    return { w: 'c', s: sub, t: 'Corregir pago ' + chipE,
      b: aviso(rechazado ? 'Este pago fue rechazado' + (p.SPA_MOTIVO_RECHAZO ? ': <b>' + esc(p.SPA_MOTIVO_RECHAZO) + '</b>.' : '.') + ' Al corregirlo vuelve a quedar por verificar.' : 'Mientras el pago no esté verificado puedes corregir lo que se declaró mal.', rechazado ? 'wa' : '') +
        '<div class="cc-grid2"><div class="cp-fld"><label for="cc_mdec">Monto (' + m2 + ')</label><input class="cp-inp" id="cc_mdec" inputmode="decimal" data-pv="c.mdec" value="' + esc(f2.mdec) + '"></div>' +
        '<div class="cp-fld"><span class="cp-lb">Fecha</span>' + K.fecha('pago.fecha', f2.fecha, { etiqueta: 'Fecha de la transferencia' }) + '</div>' + fld('banco', 'Banco') + fld('operacion', 'N° de operación') + '</div>',
      f: btn('cp-ghost', 'cvolver', 'Cancelar') + '<div class="cp-r">' + btn('cp-pri', 'ccorregirok', st.busy ? 'Guardando…' : 'Guardar corrección', dis, 'check') + '</div>' };
  }

  /* verificar (también el detalle de un pago ya resuelto) */
  var puedeV = pendiente && d.permisos.verificar, puedeC = (pendiente || rechazado) && d.permisos.declarar;
  var dif = +f2.monto - +p.SPA_MONTO_DECLARADO_CLP;
  var der = '<div class="cc-der">' + resumenPago(d) +
    (rechazado && p.SPA_MOTIVO_RECHAZO ? aviso('Rechazado: <b>' + esc(p.SPA_MOTIVO_RECHAZO) + '</b>', 'wa') : '') +
    (puedeV ? '<div class="cp-fld"><label for="cc_monto">Monto verificado contra la cartola (' + m2 + ')</label><input class="cp-inp" id="cc_monto" inputmode="decimal" data-pv="c.monto" value="' + esc(f2.monto) + '"></div>' +
      '<div id="ccDif">' + avisoDif(dif, m2) + '</div>' : '') +
    (st.rechazar ? '<div class="cp-fld"><label for="cc_motivo">Motivo del rechazo (se le informa al cliente)</label><textarea class="cp-inp" id="cc_motivo" data-pv="c.motivo" data-autofocus="1">' + esc(f2.motivo) + '</textarea></div>' : '') + '</div>';
  var cuerpo = '<div class="cc-verif">' + visor(d.comprobante) + der + '</div>';
  var pie;
  if (st.rechazar) pie = btn('cp-ghost', 'crechx', 'Cancelar') + '<div class="cp-r">' + btn('cp-dan', 'crechok', st.busy ? 'Rechazando…' : 'Rechazar pago', dis + (f2.motivo.trim().length >= 5 ? '' : ' disabled'), 'x') + '</div>';
  else pie = barra(puedeV ? btn('cp-dano', 'crech', 'Rechazar', dis, 'x') : '', puedeC ? btn('cp-out', 'ccorregir', 'Corregir', dis, 'note') : '',
    puedeV ? btn('cp-pri', 'cverifok', st.busy ? 'Verificando…' : 'Verificar', dis, 'check') : btn('cp-ghost', 'pclose', 'Cerrar'));
  return { w: 'w', s: sub, t: tit, b: cuerpo, f: pie };
}

/* El comprobante se lee en el navegador y viaja en base64 (como las fotos de las OT). */
function leerArchivo(file) {
  if (!file) return;
  if (file.size > 8 * 1024 * 1024) { K.toastError('El comprobante pesa más de 8 MB.'); return; }
  var r = new FileReader();
  r.onload = function () { if (D && D.modo === 'informar') { D.file = { nombre: file.name, mime: file.type, bytes: file.size, base64: String(r.result).split(',')[1] }; K.Panel.paint(); } };
  r.readAsDataURL(file);
}
document.addEventListener('change', function (e) { if (e.target && e.target.id === 'ccFile' && D) leerArchivo(e.target.files[0]); });
document.addEventListener('dragover', function (e) { var z = e.target.closest && e.target.closest('#ccDrop'); if (z && D) { e.preventDefault(); z.classList.add('cc-sobre'); } });
document.addEventListener('dragleave', function (e) { var z = e.target.closest && e.target.closest('#ccDrop'); if (z) z.classList.remove('cc-sobre'); });
document.addEventListener('drop', function (e) { var z = e.target.closest && e.target.closest('#ccDrop'); if (z && D) { e.preventDefault(); leerArchivo(e.dataTransfer.files[0]); } });

/* ------------------------------------------------------------ PLANES: lista y drawer (760 px) */
function vistaPlanes(d) {
  var q = K.nrm(S.aq.trim());
  var rows = d.filas.filter(function (x) { return !q || K.nrm([x.codigo, x.nombre, x.descripcion].join(' ')).indexOf(q) >= 0; });
  var tarjeta = function (x) {
    return '<button type="button" class="cc-pcard" data-a="cplanver" data-id="' + x.id + '"><span class="cc-wrap" style="justify-content:space-between"><span style="font-size:11px;font-weight:800;letter-spacing:.06em;color:var(--muted)">' + esc(x.codigo) + '</span>' +
      chip(!x.habilitado ? 'Deshabilitado' : x.publico ? 'Público' : 'No público', !x.habilitado ? 'gr' : x.publico ? 'ok' : 'bl') + '</span>' +
      '<h3>' + esc(x.nombre) + '</h3><p>' + esc(x.descripcion || 'Sin descripción') + '</p>' +
      '<span class="cc-precio"><strong>' + (x.uf != null ? money(x.uf, 'UF') : '—') + '</strong><span>/ mes · Chile</span></span>' +
      '<span class="cc-precio"><strong>' + (x.usd != null ? money(x.usd, 'USD') : '—') + '</strong><span>/ mes · exterior</span></span>' +
      '<span class="cc-nota">' + K.pl(+x.gracia, 'día de gracia', 'días de gracia') + '</span></button>';
  };
  return '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccAQ" value="' + esc(S.aq) + '" placeholder="Código o nombre" aria-label="Buscar"></label>' +
    (d.crear ? '<button type="button" class="cp-btn cp-pri" data-a="cplanver" data-id="0">' + ic('plus') + 'Nuevo plan</button>' : '') + '</div>' +
    '<div class="cc-pcards">' + (rows.length ? rows.map(tarjeta).join('') : '<div class="cc-vacio">Sin resultados.</div>') + '</div></section>';
}

function abrirPlan(id) {
  D = { tipo: 'plan', id: +id, data: null, modo: 'ver', open: { datos: true, precio: true, incluye: true }, f: {}, fun: {}, pr: { abierto: false, moneda: 'UF', per: '', valor: '', desc: '', desde: '' }, hist: false, busy: false };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; recargar(); } });
  call('Plan', { id: +id }).then(function (d) { if (D && D.tipo === 'plan') { cargarPlan(d); K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function cargarPlan(d) {
  D.data = d; D.id = d.plan.id;
  D.f = { codigo: d.plan.codigo || '', nombre: d.plan.nombre || '', descripcion: d.plan.descripcion || '', orden: String(d.plan.orden), gracia: String(d.plan.gracia), publico: !!d.plan.publico, habilitado: d.plan.habilitado !== false };
  D.fun = {};
  d.funcionalidades.forEach(function (x) { D.fun[x.id] = { incluida: !!x.incluida, tope: x.tope == null ? '' : String(x.tope) }; });
  if (!D.pr.per && d.periodicidades.length) D.pr.per = String(d.periodicidades[0].id);
}
var MODN = { LIMITES: 'Límites', OTROS: 'Otras' };
function renderPlan(st) {
  var d = st.data, dis = st.busy ? ' disabled' : '';
  if (!d) return { w: 'w', s: 'Planes', t: 'Plan', b: '<div class="cc-cargando">Cargando el plan…</div>' };
  var f = st.f, ed = d.editar, ro = ed ? '' : ' readonly', nuevo = st.id === 0;
  var tog = function (k, t, h) { return '<label class="cc-acu"><input type="checkbox" data-pv="c.' + k + '"' + (f[k] ? ' checked' : '') + (ed ? '' : ' disabled') + '><span style="font-size:13px"><b>' + t + '</b>' + (h ? ' <span style="color:var(--muted)">' + h + '</span>' : '') + '</span></label>'; };
  var datos = '<div class="cc-grid2"><div class="cp-fld"><label for="cc_codigo">Código</label><input class="cp-inp" id="cc_codigo" data-pv="c.codigo" value="' + esc(f.codigo) + '"' + (nuevo ? ' placeholder="Automático"' : ' readonly') + '></div>' +
    '<div class="cp-fld"><label for="cc_nombre">Nombre</label><input class="cp-inp" id="cc_nombre" data-pv="c.nombre" value="' + esc(f.nombre) + '"' + ro + (nuevo ? ' data-autofocus="1"' : '') + '></div>' +
    '<div class="cp-fld cc-full"><label for="cc_descripcion">Descripción</label><textarea class="cp-inp" id="cc_descripcion" data-pv="c.descripcion"' + ro + '>' + esc(f.descripcion) + '</textarea></div>' +
    '<div class="cp-fld"><label for="cc_orden">Orden</label><input class="cp-inp" id="cc_orden" inputmode="numeric" data-pv="c.orden" value="' + esc(f.orden) + '"' + ro + '></div>' +
    '<div class="cp-fld"><label for="cc_gracia">Días de gracia</label><input class="cp-inp" id="cc_gracia" inputmode="numeric" data-pv="c.gracia" value="' + esc(f.gracia) + '"' + ro + '></div></div>' +
    tog('publico', 'Público', 'se ofrece en las propuestas estándar') + (nuevo ? '' : tog('habilitado', 'Habilitado', 'un plan con clientes activos no se puede deshabilitar'));

  /* Precio versionado: nunca se edita el vigente; se fija uno nuevo (UF o USD). */
  var P = d.precios, vig = P.filter(function (x) { return x.ESTADO === 'VIGENTE' || x.ESTADO === 'PROGRAMADO'; });
  var filaP = function (x) {
    var m = x.PCP_MONEDA === 'USD' ? 'USD' : 'UF';
    return '<div class="cc-li" style="grid-template-columns:70px minmax(0,1fr) 150px 110px 70px"><span>' + chip(m, m === 'USD' ? 'pu' : 'bl') + '</span><span><b>' + esc(x.PCB_NOMBRE) + '</b> <span class="cc-m">desde ' + dmy(x.PCP_VIGENCIA_DESDE) + (x.PCP_VIGENCIA_HASTA ? ' hasta ' + dmy(x.PCP_VIGENCIA_HASTA) : '') + '</span></span>' +
      '<b>' + money(x.PCP_VALOR_UF, m) + (x.PCP_DESCUENTO_PORCENTAJE ? ' <span class="cc-m">−' + fn(x.PCP_DESCUENTO_PORCENTAJE, 0) + '%</span>' : '') + '</b>' +
      '<span>' + chip(x.ESTADO, x.ESTADO === 'VIGENTE' ? 'ok' : x.ESTADO === 'PROGRAMADO' ? 'cy' : 'gr') + '</span>' +
      (ed && (x.ESTADO === 'VIGENTE' || x.ESTADO === 'PROGRAMADO') ? '<button type="button" class="cc-lnk" data-a="cpreciorety" data-id="' + x.PCP_ID + '">Retirar</button>' : '<span></span>') + '</div>';
  };
  var pr = st.pr;
  var form = '<div class="cc-correo" style="display:flex;flex-direction:column;gap:12px"><b>Fijar precio nuevo</b>' +
    '<div class="cc-seg cc-full" role="group" aria-label="Moneda"><button type="button" aria-pressed="' + (pr.moneda === 'UF') + '" data-a="cprmon" data-v="UF">UF · Chile</button><button type="button" aria-pressed="' + (pr.moneda === 'USD') + '" data-a="cprmon" data-v="USD">USD · exterior</button></div>' +
    '<div class="cc-grid2"><div class="cp-fld"><label>Periodicidad</label>' + K.combo('ccPrPer', d.periodicidades.map(function (x) { return { id: String(x.id), n: x.n }; }), pr.per, { etiqueta: 'Periodicidad' }) + '</div>' +
    '<div class="cp-fld"><label for="cc_pr_valor">Valor en ' + pr.moneda + '</label><input class="cp-inp" id="cc_pr_valor" inputmode="decimal" data-pv="c.pr_valor" value="' + esc(pr.valor) + '"></div>' +
    '<div class="cp-fld"><label for="cc_pr_desc">Descuento % (opcional)</label><input class="cp-inp" id="cc_pr_desc" inputmode="decimal" data-pv="c.pr_desc" value="' + esc(pr.desc) + '"></div>' +
    '<div class="cp-fld"><span class="cp-lb">Rige desde</span>' + K.fecha('plan.desde', pr.desde, { etiqueta: 'Rige desde' }) + '</div></div>' +
    '<div class="cc-acc"><span class="cc-nota" style="flex:1">El precio anterior queda cerrado, no borrado. Vacío = rige desde hoy.</span>' + btn('cp-ghost cp-sm', 'cprecioabrir', 'Cancelar') + btn('cp-sec cp-sm', 'cpreciook', 'Fijar precio', dis) + '</div></div>';
  var precio = (vig.length ? vig.map(filaP).join('') : '<div class="cc-nota">Este plan todavía no tiene precio: sin precio no se vende.</div>') +
    (ed ? (pr.abierto ? form : '<div class="cc-acc">' + btn('cp-out cp-sm', 'cprecioabrir', 'Fijar precio nuevo', '', 'plus') + '</div>') : '') +
    (P.length > vig.length ? '<button type="button" class="cc-lnk" data-a="chist">' + (st.hist ? 'Ocultar el historial' : 'Ver el historial de precios (' + (P.length - vig.length) + ')') + '</button>' +
      (st.hist ? P.filter(function (x) { return !(x.ESTADO === 'VIGENTE' || x.ESTADO === 'PROGRAMADO'); }).map(filaP).join('') : '') : '');

  /* Qué incluye: funcionalidades por módulo comercial, con «incluida» y «tope». */
  var orden = ['LIMITES'].concat(d.modulos.map(function (m) { return m.id; })).concat(['OTROS']);
  var nombreMod = function (id) { var m = d.modulos.filter(function (x) { return x.id === id; })[0]; return m ? m.n : (MODN[id] || id); };
  var tabla = '<table class="cc-func"><thead><tr><th>Funcionalidad</th><th style="width:80px">Incluida</th><th style="width:130px">Tope</th></tr></thead><tbody>' +
    orden.map(function (mo) {
      var fs = d.funcionalidades.filter(function (x) { return x.modulo === mo; }); if (!fs.length) return '';
      return '<tr class="cc-mod-h"><td colspan="3">' + esc(nombreMod(mo)) + '</td></tr>' + fs.map(function (x) {
        var s = st.fun[x.id] || {};
        return '<tr><td>' + esc(x.nombre) + (x.origen === 'EXCEPCIÓN' ? ' ' + chip('Excepción', 'bl') : '') + (x.caduca ? ' ' + chip('Hasta ' + dmy(x.caduca), 'wa') : '') + '</td>' +
          '<td><input type="checkbox" data-pv="c.fun_' + x.id + '"' + (s.incluida ? ' checked' : '') + (ed ? '' : ' disabled') + ' aria-label="Incluida"></td>' +
          '<td>' + (x.limite ? '<input class="cp-inp" inputmode="decimal" data-pv="c.top_' + x.id + '" value="' + esc(s.tope) + '" placeholder="sin límite"' + (ed ? '' : ' readonly') + '>' : '') + '</td></tr>';
      }).join('');
    }).join('') + '</tbody></table>';
  var incluidas = d.funcionalidades.filter(function (x) { return (st.fun[x.id] || {}).incluida; }).length;
  return { w: 'w', s: nuevo ? 'Planes' : esc(f.codigo) + ' · Plan', t: (nuevo ? 'Nuevo plan' : esc(f.nombre)) + ' ' + (nuevo ? chip('Sin crear', 'gr') : chip(f.habilitado ? (f.publico ? 'Público' : 'No público') : 'Deshabilitado', f.habilitado ? (f.publico ? 'ok' : 'bl') : 'gr')),
    b: sec(st, 'datos', 'badge', 'pu', 'Datos', '', datos) +
      (nuevo ? aviso('Guarda el plan para fijarle precio y elegir lo que incluye. Un plan sin precio no se vende.', '') :
        sec(st, 'precio', 'wallet', 'cy', 'Precio versionado', '<small>UF y USD</small>', precio) +
        sec(st, 'incluye', 'list', 'ok', 'Qué incluye', '<small>' + incluidas + ' de ' + d.funcionalidades.length + '</small>', tabla)),
    f: btn('cp-ghost', 'pclose', 'Cerrar') + '<div class="cp-r">' + (ed ? btn('cp-pri', 'cplanguardar', st.busy ? 'Guardando…' : 'Guardar', dis) : '') + '</div>' };
}
A.cplanver = function (ds) { abrirPlan(ds.id); };
A.cprecioabrir = function () { D.pr.abierto = !D.pr.abierto; K.Panel.paint(); };
A.cprmon = function (ds) { D.pr.moneda = ds.v; K.Panel.paint(); };
A.chist = function () { D.hist = !D.hist; K.Panel.paint(); };
A.cpreciook = function () {
  var p = D.pr;
  ocupado(call('FijarPrecio', { plan: D.id, periodicidad: +p.per, moneda: p.moneda, valor: p.valor, descuento: p.desc, desde: p.desde }))
    .then(function (r) { cargarPlan(r.ficha); D.pr.abierto = false; D.pr.valor = ''; D.pr.desc = ''; D.pr.desde = ''; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};
A.cpreciorety = function (ds) {
  ocupado(call('RetirarPrecio', { plan: D.id, precio: +ds.id })).then(function (r) { cargarPlan(r.ficha); D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};
A.cplanguardar = function () {
  var f = D.f, nuevo = D.id === 0;
  ocupado(call('GuardarPlan', { id: D.id, codigo: f.codigo, nombre: f.nombre, descripcion: f.descripcion, orden: +f.orden || 0, gracia: +f.gracia || 0, publico: !!f.publico, habilitado: !!f.habilitado }))
    .then(function (r) {
      if (nuevo) { cargarPlan(r.ficha); D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); return; }
      var filas = r.ficha.funcionalidades.map(function (x) { var s = D.fun[x.id] || {}; return { id: x.id, incluida: !!s.incluida, tope: x.limite ? s.tope : null }; });
      return call('GuardarFuncionalidades', { plan: D.id, filas: filas }).then(function (r2) { cargarPlan(r2.ficha); D.busy = false; K.Panel.paint(); K.toast('Plan guardado'); recargar(); });
    }).catch(function (e) { if (D) { D.busy = false; K.Panel.paint(); } K.toastError(e); });
};

/* ------------------------------------------------------------ CLIENTES: lista y drawer (600 px) */
function vistaEmpresas(d) {
  var q = K.nrm(S.aq.trim());
  var rows = d.filas.filter(function (x) { return !q || K.nrm([x.nombre, x.razon, x.identificador, x.pais].join(' ')).indexOf(q) >= 0; });
  var cols = 'grid-template-columns:minmax(200px,2fr) minmax(160px,1.4fr) 120px 150px 150px 100px 120px';
  var fila = function (x) {
    return '<div class="cc-crow" role="button" tabindex="0" style="' + cols + '" data-a="ccli" data-id="' + x.id + '">' +
      '<span class="cc-c2"><b>' + esc(x.nombre) + '</b></span><span class="cc-c2"><span>' + esc(x.razon || '') + '</span></span>' +
      '<span style="font-size:13px">' + esc(x.pais || '—') + '</span><span class="cc-num">' + esc(x.identificador || '') + '</span><span>' + chipCobro(x.moneda) + '</span>' +
      '<span class="cc-num">' + (x.desde ? dmy(x.desde) : '') + '</span><span>' + chip(x.habilitado ? 'Habilitada' : 'Deshabilitada', x.habilitado ? 'ok' : 'gr') + '</span></div>';
  };
  var th = ['Empresa', 'Razón social', 'País', 'Identificador', 'Cobro', 'Desde', 'Estado'];
  return '<section class="cc-panel"><div class="cc-bar"><label class="cc-buscar">' + ic('search', 20) + '<input type="search" id="ccAQ" value="' + esc(S.aq) + '" placeholder="Empresa, razón social, país o identificador" aria-label="Buscar"></label></div>' +
    '<div class="cc-scroll"><div class="cc-tabla" style="min-width:1040px"><div class="cc-th" style="' + cols + '">' + th.map(function (h) { return '<span>' + h + '</span>'; }).join('') + '</div>' +
    '<div class="cc-filas">' + (rows.length ? rows.map(fila).join('') : '<div class="cc-vacio">Sin resultados.</div>') + '</div></div></div>' +
    '<div class="cc-pie"><span>' + rows.length + ' de ' + d.filas.length + '</span><span>Clic en una fila para abrir su ficha</span></div></section>';
}

function formCli(d) {
  var c = d.cliente || {};
  return { nombre: c.NOMBRE || '', razon: c.RAZON_SOCIAL || '', fantasia: c.FANTASIA || '', pais: c.PAIS_ID ? String(c.PAIS_ID) : '1', identificador: c.IDENTIFICADOR || '',
    zona: c.ZONA_HORARIA ? String(c.ZONA_HORARIA) : '', idioma: c.IDIOMA ? String(c.IDIOMA) : '', moneda: c.MONEDA_ID ? String(c.MONEDA_ID) : '', habilitado: c.HABILITADO !== false,
    cobro: c.MONEDA_COBRO || 'UF', motivo: '' };
}
function abrirCliente(id) {
  D = { tipo: 'cli', id: +id, data: null, open: { ident: true, cont: false, usu: false, pla: false }, f: {}, nc: { nombre: '', cargo: '', correo: '', telefono: '', principal: false }, busy: false };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; if (C.lista.empresas) cargar('empresas'); } });
  call('Cliente', { id: +id }).then(function (d) { if (D && D.tipo === 'cli') { D.data = d; D.f = formCli(d); if (+id === 0) D.f.cobro = 'UF'; K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function paisDe(st) { return st.data.opciones.paises.filter(function (p) { return String(p.id) === String(st.f.pais); })[0]; }
function renderCli(st) {
  var d = st.data, dis = st.busy ? ' disabled' : '';
  if (!d) return { w: 'c', s: 'Clientes', t: 'Cliente', b: '<div class="cc-cargando">Cargando el cliente…</div>' };
  var f = st.f, o = d.opciones, p = d.permisos, nuevo = st.id === 0, ed = p.editar, c = d.cliente || {}, pa = paisDe(st) || { etiqueta: 'Identificador tributario', moneda: 'UF' };
  var resumen = nuevo ? '' : '<div class="cc-mini"><div><small>Suscripción</small><b>' + (d.suscripcion && d.suscripcion.SUSCRIPCION ? esc(cod('SUS', d.suscripcion.SUSCRIPCION)) : '—') + '</b></div>' +
    '<div><small>Plan</small><b>' + esc(d.suscripcion && d.suscripcion.PLAN_NOMBRE || '—') + '</b></div><div><small>Ejecutivo</small><b>' + esc(d.suscripcion && d.suscripcion.EJECUTIVO || '—') + '</b></div></div>';
  var cat = function (k, lista, ph, t) { return '<div class="cp-fld"><label>' + t + '</label>' + K.combo('ccCli_' + k, [{ id: '', n: ph }].concat(lista.map(function (x) { return { id: String(x.id), n: x.n }; })), f[k], { ph: ph, etiqueta: t }) + '</div>'; };
  var explica = f.cobro === 'USD'
    ? 'Se cotiza y se cobra en <b>dólares (USD)</b>. Se paga por <b>transferencia internacional (SWIFT)</b>; los gastos bancarios corren por cuenta del cliente. La tarjeta en USD queda «próximamente».'
    : 'Se cotiza en <b>UF</b> y se cobra en <b>pesos (CLP)</b> con la UF del día de emisión. Se paga con <b>Webpay Plus</b> o transferencia nacional.';
  var cambia = !nuevo && c.MONEDA_COBRO && f.cobro !== c.MONEDA_COBRO;
  var ident = '<div class="cc-grid2"><div class="cp-fld cc-full"><label for="cc_nombre">Nombre</label><input class="cp-inp" id="cc_nombre" data-pv="c.nombre" value="' + esc(f.nombre) + '"' + (ed ? '' : ' readonly') + (nuevo ? ' data-autofocus="1"' : '') + '></div>' +
    fld('razon', 'Razón social', { ro: !ed }) + fld('fantasia', 'Nombre de fantasía', { ro: !ed }) +
    '<div class="cp-fld"><label>País</label>' + K.combo('ccCli_pais', o.paises.map(function (x) { return { id: String(x.id), n: x.n }; }), f.pais, { ph: 'Elige el país', etiqueta: 'País' }) + '</div>' +
    fld('identificador', pa.etiqueta, { ro: !ed, ph: pa.id === 1 ? '12.345.678-9' : '' }) +
    cat('zona', o.zonas, 'Sin definir', 'Zona horaria') + cat('idioma', o.idiomas, 'Sin definir', 'Idioma') + cat('moneda', o.monedas, 'Sin definir', 'Moneda operativa') +
    '<div class="cp-fld"><label for="cc_hab">Habilitada</label><label class="cc-acu" style="height:40px"><input type="checkbox" id="cc_hab" data-pv="c.habilitado"' + (f.habilitado ? ' checked' : '') + (ed ? '' : ' disabled') + '><span style="font-size:13px">' + (f.habilitado ? 'Sí' : 'No') + '</span></label></div></div>' +
    '<div class="cp-fld"><label>Moneda de cobro</label><div class="cc-seg cc-full" role="group" aria-label="Moneda de cobro"><button type="button" aria-pressed="' + (f.cobro === 'UF') + '" data-a="ccobro" data-v="UF"' + (nuevo || p.cambiarMoneda ? '' : ' disabled') + '>UF · Chile</button>' +
    '<button type="button" aria-pressed="' + (f.cobro === 'USD') + '" data-a="ccobro" data-v="USD"' + (nuevo || p.cambiarMoneda ? '' : ' disabled') + '>USD · exterior</button></div></div>' +
    '<div class="cc-info">' + ic('light') + '<span>' + explica + '</span></div>' +
    (!nuevo && !p.cambiarMoneda ? '<div class="cc-nota">La moneda de cobro se fijó al crear el cliente. Cambiarla exige una facultad especial y queda auditado; los períodos ya emitidos conservan su moneda.</div>' : '') +
    (cambia ? '<div class="cp-fld"><label for="cc_motivo">Motivo del cambio de moneda (queda auditado)</label><textarea class="cp-inp" id="cc_motivo" data-pv="c.motivo">' + esc(f.motivo) + '</textarea></div>' : '');
  var cs = d.contactos.map(function (x) {
    return '<div class="cc-li" style="grid-template-columns:minmax(0,1.3fr) minmax(0,1.4fr) auto auto"><span class="cc-c2"><b style="font-size:13px">' + esc(x.ccn_nombre) + '</b><span>' + esc(x.ccn_cargo || '') + '</span></span>' +
      '<span class="cc-c2"><span style="color:var(--ink);font-size:13px">' + esc(x.ccn_email || '—') + '</span><span>' + esc(x.ccn_telefono || '') + '</span></span><span>' + (x.ccn_principal ? chip('Principal', 'pu') : '') + '</span>' +
      (ed ? '<button type="button" class="cc-lnk" data-a="cconquitar" data-id="' + x.ccn_id + '">Quitar</button>' : '<span></span>') + '</div>';
  }).join('') || '<div class="cc-nota">Sin contactos.</div>';
  var nc = st.nc;
  var alta = ed && !nuevo ? '<div class="cc-correo" style="display:flex;flex-direction:column;gap:10px"><b>Agregar contacto</b><div class="cc-grid2">' +
    ['nombre:Nombre', 'cargo:Cargo', 'correo:Correo', 'telefono:Teléfono'].map(function (z) { var k = z.split(':')[0]; return '<div class="cp-fld"><label for="cc_nc_' + k + '">' + z.split(':')[1] + '</label><input class="cp-inp" id="cc_nc_' + k + '" data-pv="c.nc_' + k + '" value="' + esc(nc[k]) + '"></div>'; }).join('') + '</div>' +
    '<div class="cc-acc"><label class="cc-acu" style="flex:1"><input type="checkbox" data-pv="c.nc_principal"' + (nc.principal ? ' checked' : '') + '><span style="font-size:13px">Contacto principal</span></label>' + btn('cp-out cp-sm', 'cconagregar', 'Agregar', dis, 'plus') + '</div></div>' : '';
  var us = d.usuarios.map(function (x) {
    return '<div class="cc-li" style="grid-template-columns:minmax(0,1.3fr) minmax(0,1.2fr) auto"><span class="cc-c2"><b style="font-size:13px">' + esc(x.nombre) + '</b><span>' + esc(x.correo || '') + '</span></span><span style="font-size:12.5px;color:var(--cc-lab)">' + esc(x.perfiles || 'Sin perfil') + '</span>' + chip(x.habilitado ? 'Activo' : 'Deshabilitado', x.habilitado ? 'ok' : 'gr') + '</div>';
  }).join('') || '<div class="cc-nota">Sin usuarios.</div>';
  var pl = d.plantas.map(function (x) {
    return '<div class="cc-li" style="grid-template-columns:minmax(0,1fr) minmax(0,1.4fr) auto"><b style="font-size:13px">' + esc(x.nombre) + '</b><span class="cc-m">' + esc(x.direccion || '—') + '</span>' + chip(x.habilitada ? 'Habilitada' : 'Deshabilitada', x.habilitada ? 'ok' : 'gr') + '</div>';
  }).join('') || '<div class="cc-nota">Sin plantas.</div>';
  return { w: 'c', s: nuevo ? 'Clientes' : esc(c.IDENT_ETIQUETA || 'ID') + ' ' + esc(c.IDENTIFICADOR || ''), t: (nuevo ? 'Nuevo cliente' : esc(c.NOMBRE)) + ' ' + (nuevo ? chip('Sin crear', 'gr') : chipCobro(c.MONEDA_COBRO)),
    b: resumen + sec(st, 'ident', 'badge', 'pu', 'Identidad', '', ident) +
      (nuevo ? aviso('Guarda el cliente para agregar contactos. Sus usuarios y plantas se administran desde Cliente.', '') :
        sec(st, 'cont', 'users', 'bl', 'Contactos', '<small>' + d.contactos.length + '</small>', cs + alta) +
        sec(st, 'usu', 'person', 'cy', 'Usuarios', '<small>' + d.usuarios.length + '</small>', us + '<div class="cc-nota">Para invitar o cambiar perfiles, el cliente usa Cliente › Usuarios.</div>') +
        sec(st, 'pla', 'pin', 'ok', 'Plantas', '<small>' + d.plantas.length + '</small>', pl)),
    f: btn('cp-ghost', 'pclose', 'Cerrar') + '<div class="cp-r">' + (ed ? btn('cp-pri', 'cclientok', st.busy ? 'Guardando…' : (nuevo ? 'Crear cliente' : 'Guardar'), dis + (f.nombre.trim() && f.identificador.trim() ? '' : ' disabled')) : '') + '</div>' };
}
A.ccli = function (ds) { abrirCliente(ds.id); };
A.cclientenuevo = function () { abrirCliente(0); };
A.ccobro = function (ds) { D.f.cobro = ds.v; K.Panel.paint(); };
A.cclientok = function () {
  var f = D.f, nuevo = D.id === 0;
  ocupado(call('GuardarCliente', { id: D.id, nombre: f.nombre, razon: f.razon || f.nombre, pais: +f.pais, identificador: f.identificador, fantasia: f.fantasia, zona: f.zona ? +f.zona : null, idioma: f.idioma ? +f.idioma : null,
    moneda: f.moneda ? +f.moneda : null, habilitado: !!f.habilitado, monedaCobro: f.cobro, motivo: f.motivo }))
    .then(function (r) { D.id = r.id; D.data = r.ficha; D.f = formCli(r.ficha); D.busy = false; K.Panel.paint(); K.toast(r.mensaje); if (C.lista.empresas) cargar('empresas'); void nuevo; }).catch(function () { });
};
A.cconagregar = function () {
  var n = D.nc;
  ocupado(call('GuardarContacto', { cliente: D.id, nombre: n.nombre, cargo: n.cargo, correo: n.correo, telefono: n.telefono, principal: !!n.principal }))
    .then(function (r) { D.data = r.ficha; D.nc = { nombre: '', cargo: '', correo: '', telefono: '', principal: false }; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); }).catch(function () { });
};
A.cconquitar = function (ds) {
  ocupado(call('QuitarContacto', { cliente: D.id, contacto: +ds.id })).then(function (r) { D.data = r.ficha; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); }).catch(function () { });
};

/* ------------------------------------------------------------ DRAWER · DATOS PARA TRANSFERIR (Configuración) */
function abrirBanco() {
  D = { tipo: 'banco', data: null, open: {}, busy: false, f: {} };
  K.Panel.open({ st: D, render: render, onclose: function () { D = null; } });
  call('DatosTransferencia').then(function (r) { if (D && D.tipo === 'banco') { D.data = r; r.filas.forEach(function (x) { D.f[x.CLAVE] = x.VALOR || ''; }); K.Panel.paint(); } }).catch(function (e) { K.toastError(e); K.Panel.close(); });
}
function renderBanco(st) {
  if (!st.data) return { w: 'c', s: 'Configuración comercial', t: 'Datos para transferir', b: '<div class="cc-cargando">Cargando…</div>' };
  var grupo = function (g, titulo, nota) {
    return '<section class="cc-sec"><div class="cc-sec-h" style="cursor:default"><b>' + titulo + '</b></div><div class="cc-sec-b"><div class="cc-grid2">' +
      st.data.filas.filter(function (x) { return x.GRUPO === g; }).map(function (x) {
        return '<div class="cp-fld' + (x.CLAVE === 'INT_DIRECCION' || x.CLAVE === 'NAC_TITULAR' || x.CLAVE === 'INT_BENEFICIARIO' ? ' cc-full' : '') + '"><label for="cb_' + x.CLAVE + '">' + esc(x.ETIQUETA) + '</label><input class="cp-inp" id="cb_' + x.CLAVE + '" data-pv="c.' + x.CLAVE + '" value="' + esc(st.f[x.CLAVE]) + '"' + (st.data.editar ? '' : ' readonly') + '></div>';
      }).join('') + '</div><div class="cc-nota">' + nota + '</div></div></section>';
  };
  return { w: 'c', s: 'Configuración comercial', t: 'Datos para transferir',
    b: aviso('Estos datos salen en la página de pago, en los correos de cobro y en «Informar transferencia». No están fijos en el código: se cambian aquí.', '') +
      grupo('BANCO_NACIONAL', 'Transferencia nacional (CLP)', 'Para clientes de Chile que prefieren transferir en vez de pagar con Webpay.') +
      grupo('BANCO_INTERNACIONAL', 'Transferencia internacional (USD)', 'Para clientes de otros países. Los gastos bancarios corren por cuenta del cliente.'),
    f: btn('cp-ghost', 'pclose', 'Cancelar') + '<div class="cp-r">' + (st.data.editar ? btn('cp-pri', 'cbancook', st.busy ? 'Guardando…' : 'Guardar', st.busy ? ' disabled' : '') : '') + '</div>' };
}

function render(st) { return st.tipo === 'per' ? renderPer(st) : st.tipo === 'pago' ? renderPago(st) : st.tipo === 'banco' ? renderBanco(st) : st.tipo === 'plan' ? renderPlan(st) : st.tipo === 'cli' ? renderCli(st) : renderSus(st); }

/* ------------------------------------------------------------ acciones */
A.cfiltro = function (ds) { C.filtro = ds.v; X.pintar(); };
A.csus = function (ds) { abrirSuscripcion(ds.id); };
A.cper = function (ds) { abrirPeriodo(ds.id); };
A.cpago = function (ds) { abrirPago(ds.id); };
A.cemitir = function () { abrirEmitir(null); };
A.cbanco = function () { abrirBanco(); };
A.cinformar = function (ds) { abrirInformar(ds.sus, ds.per); };
A.cbancook = function () {
  var filas = D.data.filas.map(function (x) { return { clave: x.CLAVE, valor: D.f[x.CLAVE] || '' }; });
  ocupado(call('GuardarDatosTransferencia', { filas: filas })).then(function (r) { D.busy = false; K.Panel.paint(); K.toast(r.mensaje); }).catch(function () { });
};
A.cinformok = function () {
  var f = D.f, a = D.file;
  if (!a) { K.toastError('Adjunta el comprobante de la transferencia.'); return; }
  ocupado(call('InformarPago', { periodo: +f.periodo, monto: f.monto, fecha: f.fecha, banco: f.banco, operacion: f.operacion, archivoNombre: a.nombre, archivoMime: a.mime, archivoBase64: a.base64 }))
    .then(function (r) { D.modo = 'ver'; D.id = r.id; D.data = r.ficha; D.f = formPago(r.ficha); D.file = null; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};
A.ccorregir = function () { D.modo = 'corregir'; K.Panel.paint(); };
A.ccorregirok = function () {
  var f = D.f;
  ocupado(call('CorregirPago', { id: D.id, monto: f.mdec, fecha: f.fecha, banco: f.banco, operacion: f.operacion }))
    .then(function (r) { D.data = r.ficha; D.f = formPago(r.ficha); D.modo = 'ver'; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};
A.cverifok = function () {
  ocupado(call('VerificarPago', { id: D.id, montoVerificado: D.f.monto }))
    .then(function (r) { D.data = r.ficha; D.f = formPago(r.ficha); D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};
A.crech = function () { D.rechazar = true; D.f.motivo = ''; K.Panel.paint(); };
A.crechx = function () { D.rechazar = false; K.Panel.paint(); };
A.crechok = function () {
  ocupado(call('RechazarPago', { id: D.id, motivo: D.f.motivo }))
    .then(function (r) { D.data = r.ficha; D.f = formPago(r.ficha); D.rechazar = false; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};
A.csec = function (ds) { D.open[ds.v] = !D.open[ds.v]; K.Panel.paint(); };
A.cvolver = function () { if (D.modo === 'clave-emitida') D.clave = null; D.modo = 'ver'; D.busy = false; K.Panel.paint(); };
A.ccopiar = function (ds) { try { navigator.clipboard.writeText(ds.v).then(function () { K.toast('Clave copiada'); }); } catch (e) { } };
A.cplan = function () { D.modo = 'plan'; D.plan = ''; D.per = ''; K.Panel.paint(); };
A.cclave = function () { D.modo = 'clave'; D.f.motivo = ''; K.Panel.paint(); };
A.csusok = function () {
  var f = D.f;
  ocupado(call('GuardarSuscripcion', { id: D.id, estado: +f.estado, habilitado: !!f.habilitado, contactoNombre: f.contactoNombre, contactoCorreo: f.contactoCorreo, contactoTelefono: f.contactoTelefono, observacion: f.observacion }))
    .then(function (r) { actualizar(r, r.mensaje); recargar(); }).catch(function () { });
};
A.cplanok = function () {
  ocupado(call('CambiarPlan', { id: D.id, planNuevo: +D.plan, periodicidad: D.per ? +D.per : null }))
    .then(function (r) { actualizar(r, r.mensaje); recargar(); }).catch(function () { });
};
A.creemitir = function () {
  if (!D.f.motivo || D.f.motivo.trim().length < 5) { K.toastError('Indica el motivo de la reemisión (al menos 5 letras).'); return; }
  ocupado(call('ReemitirClave', { id: D.id, motivo: D.f.motivo }))
    .then(function (r) { D.data = r.ficha; D.f = formSus(r.ficha); D.clave = r.clave; D.modo = 'clave-emitida'; D.busy = false; K.Panel.paint(); recargar(); }).catch(function () { });
};
A.cemitirok = function () {
  var f = D.f;
  ocupado(call('EmitirPeriodo', { suscripcion: +f.sus, periodicidad: +f.per, plan: f.plan ? +f.plan : null, implantacion: !!f.impl, valor: f.valor, observacion: f.obs }))
    .then(function (r) { D.tipo = 'per'; D.id = r.id; D.data = r.ficha; D.modo = 'emitido'; D.open = { detalle: true, calculo: true, pagos: true }; D.busy = false; K.Panel.paint(); K.toast(r.mensaje); recargar(); }).catch(function () { });
};

/* ------------------------------------------------------------ campos y combos */
function pv(clave, valor) {
  if (clave.indexOf('c.') !== 0 || !D) return false;
  var k = clave.slice(2);
  if (D.tipo === 'cli' && k.indexOf('nc_') === 0) { D.nc[k.slice(3)] = valor; return true; }
  if (D.tipo === 'plan') {
    /* Funcionalidades y formulario de precio van aparte del resto de los campos del plan. */
    if (k.indexOf('fun_') === 0) { var fi = D.fun[k.slice(4)] || (D.fun[k.slice(4)] = {}); fi.incluida = !!valor; return true; }
    if (k.indexOf('top_') === 0) { var ti = D.fun[k.slice(4)] || (D.fun[k.slice(4)] = {}); ti.tope = valor; return true; }
    if (k === 'pr_valor') { D.pr.valor = valor; return true; }
    if (k === 'pr_desc') { D.pr.desc = valor; return true; }
  }
  D.f[k] = valor;
  if (k === 'habilitado') K.Panel.paint();
  /* Sin repintar el cajón: un repintado entre el clic y el soltar perdería el botón. */
  if (k === 'motivo' && D.rechazar) { var b = $('#cpLayer [data-a=crechok]'); if (b) b.disabled = D.busy || valor.trim().length < 5; }
  if (k === 'monto' && D.tipo === 'pago' && D.modo !== 'informar' && D.data) { var z = $('#ccDif'); if (z) z.innerHTML = avisoDif(+valor - +D.data.pago.SPA_MONTO_DECLARADO_CLP, D.data.pago.SPA_MONEDA === 'USD' ? 'USD' : 'CLP'); }
  return true;
}
function fecha(el) {
  if (!D) return false;
  var b = el.getAttribute('data-fe');
  if (b === 'pago.fecha') { D.f.fecha = K.deDN(el.value); return true; }
  if (b === 'plan.desde') { D.pr.desde = K.deDN(el.value); return true; }
  return false;
}
function combo(n, valor) {
  if (!D) return false;
  if (n === 'ccSusEstado') { D.f.estado = valor; return true; }
  if (n === 'ccPlanNuevo') { D.plan = valor; K.Panel.paint(); return true; }
  if (n === 'ccPerNueva') { D.per = valor; return true; }
  if (n === 'ccEmSus') { D.f.sus = valor; K.Panel.paint(); return true; }
  if (n === 'ccEmPer') { D.f.per = valor; K.Panel.paint(); return true; }
  if (n === 'ccEmPlan') { D.f.plan = valor; return true; }
  if (n.indexOf('ccCli_') === 0) {
    var kc = n.slice(6); D.f[kc] = valor;
    // En un cliente nuevo la moneda de cobro sigue al país (Chile = UF, el resto = USD).
    if (kc === 'pais' && D.id === 0) { var pa = D.data.opciones.paises.filter(function (x) { return String(x.id) === String(valor); })[0]; if (pa) D.f.cobro = pa.moneda; }
    if (kc === 'pais') K.Panel.paint();
    return true;
  }
  if (n === 'ccPrPer') { D.pr.per = valor; return true; }
  if (n === 'ccPagoPer') {
    D.f.periodo = valor;
    var p = D.op.periodos.filter(function (x) { return String(x.SPE_ID) === String(valor); })[0];
    if (p) D.f.monto = String(p.SALDO_CLP);
    K.Panel.paint(); return true;
  }
  return false;
}

cargarAtencion();
return { maneja: function (v) { return VISTAS.indexOf(v) >= 0; }, vista: vista, boton: boton, pv: pv, combo: combo, fecha: fecha, recargar: recargar, grupoCobros: grupoCobros,
  K: { money: money, cod: cod, sec: sec, barra: barra, btn: btn, consumo: consumo, cajaClave: cajaClave, aviso: aviso, chipCobro: chipCobro, tonoPeriodo: tonoPeriodo, tonoPago: tonoPago, MEDIO: MEDIO } };
};
})();
