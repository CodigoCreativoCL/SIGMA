/* =====================================================================
   SIGMA · Carga laboral (BD/420) — componente reutilizable
   Calendario mensual de en qué está una persona, un grupo de trabajo o una empresa externa:
   planes, inspecciones, tareas y OT pendientes o en curso, con su duración estimada y los choques.
   Se usa en toda vista donde se asignan responsables (cajones de inspección y tarea, paso 4 del
   plan, avisos de choque, ficha y nueva OT).

   API (window.SigmaCarga):
     abrir({ clave: 'U:5'|'G:3'|'E:7', nombre, detalle, fecha: 'yyyy-mm-dd' })  abre el calendario
     resumen(['U:5','G:3'])  → Promise({ 'U:5': { MINUTOS, TRABAJOS, CHOQUES, DIAS_SOBRE } })  (30 días, caché 60 s)
     chip(r)                 → HTML con «N h · 30 días» y «N choques»
     boton(clave, nombre, detalle, txt) → HTML del botón «Ver carga» (abre solo, por delegación)
   No depende de MantKit: la usan también Planificación y la ficha de OT.
   ===================================================================== */
(function () {
  if (window.SigmaCarga) return;
  var src = (document.currentScript && document.currentScript.src) || '';
  var BASE = src ? src.replace(/Js\/sigma-carga\.js.*$/i, '') : '/';
  var WS = BASE + 'WebService/WsCentroPlanificacion.asmx/';
  var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var DIAS = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'], DIASL = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
  var TIPO = { PLAN: ['Plan', 'sgc-k-plan'], INS: ['Inspección', 'sgc-k-ins'], TAR: ['Tarea', 'sgc-k-tar'], OT: ['OT', 'sgc-k-ot'] };
  var CAP = 480;

  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function iso(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function D(s) { var p = String(s).slice(0, 10).split('-'); return new Date(+p[0], +p[1] - 1, +p[2]); }
  function add(d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; }
  function hm(s) { return String(s || '').slice(11, 16); }
  function horas(min) { var h = (+min || 0) / 60; return (Math.round(h * 10) / 10).toString().replace('.', ',') + ' h'; }
  function ini(n) { return String(n || '?').split(/\s+/).filter(Boolean).slice(0, 2).map(function (x) { return x.charAt(0).toUpperCase(); }).join(''); }
  var HOY = iso(new Date());
  var I = {
    x: '<path d="M6 6l12 12M18 6L6 18"/>', l: '<path d="M15 6l-6 6 6 6"/>', r: '<path d="M9 6l6 6-6 6"/>',
    cal: '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.5v.5"/>', ext: '<path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
    users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.2A6.5 6.5 0 0 1 21.5 20"/>',
    bld: '<path d="M4 21V5l8-2v18M12 9l8 2v10M8 8v.5M8 12v.5M8 16v.5M16 14v.5M16 18v.5"/>'
  };
  function ic(k, n) { n = n || 16; return '<svg width="' + n + '" height="' + n + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (I[k] || '') + '</svg>'; }

  function llamar(m, d) {
    return fetch(WS + m, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify(d || {}) })
      .then(function (r) { if (!r.ok) throw new Error('No se pudo conectar con el servidor.'); return r.json(); })
      .then(function (j) { var x = typeof j.d === 'string' ? JSON.parse(j.d) : j.d; if (x && x.error) throw new Error(x.detalle || 'No se pudo completar.'); return x; });
  }

  /* ------------------------------------------------------------ resumen para los selectores */
  var CACHE = {}, CT = 0;
  function resumen(claves) {
    claves = (claves || []).filter(function (c) { return /^[UGE]:\d+$/.test(c); });
    if (Date.now() - CT > 60000) { CACHE = {}; CT = Date.now(); }
    var faltan = claves.filter(function (c) { return !CACHE[c]; });
    var p = faltan.length ? llamar('CargaResumen', { claves: faltan.join(','), desde: HOY, hasta: iso(add(new Date(), 30)) }).then(function (r) {
      (r.filas || []).forEach(function (f) { CACHE[f.CLAVE] = f; });
      faltan.forEach(function (c) { if (!CACHE[c]) CACHE[c] = { CLAVE: c, MINUTOS: 0, TRABAJOS: 0, CHOQUES: 0, DIAS_SOBRE: 0 }; });
    }) : Promise.resolve();
    return p.then(function () { var o = {}; claves.forEach(function (c) { o[c] = CACHE[c]; }); return o; });
  }
  function nivel(min, dias) { var hDia = (+min || 0) / 22; return +dias > 0 || hDia > CAP * 0.9 ? 'sgc-n3' : hDia > CAP * 0.6 ? 'sgc-n2' : 'sgc-n1'; }
  function chip(r) {
    if (!r) return '<span class="sgc-chip sgc-ld">Carga…</span>';
    return '<span class="sgc-chip ' + nivel(r.MINUTOS, r.DIAS_SOBRE) + '" title="Próximos 30 días: ' + r.TRABAJOS + ' trabajos, ' + horas(r.MINUTOS) + (+r.DIAS_SOBRE ? ', ' + r.DIAS_SOBRE + ' días sobre 8 h' : '') + '">' + horas(r.MINUTOS) + ' · 30 días</span>' +
      (+r.CHOQUES ? '<span class="sgc-chip sgc-ch" title="Trabajos que se pisan en el horario">' + ic('alert', 11) + r.CHOQUES + (+r.CHOQUES === 1 ? ' choque' : ' choques') + '</span>' : '');
  }
  function boton(clave, nombre, detalle, txt, fecha) {
    return '<button type="button" class="sgc-btn" data-sgc-clave="' + esc(clave) + '" data-sgc-nombre="' + esc(nombre || '') + '" data-sgc-detalle="' + esc(detalle || '') + '"' + (fecha ? ' data-sgc-fecha="' + esc(String(fecha).slice(0, 10)) + '"' : '') + ' title="Ver en qué está ' + esc(nombre || '') + ' (calendario del mes)">' + ic('cal', 14) + (txt == null ? 'Ver carga' : esc(txt)) + '</button>';
  }
  /* El chip ya listo si está en caché; si no, un hueco que pintarResumen() llena. */
  function chipDe(clave) { var r = Date.now() - CT < 60000 ? CACHE[clave] : null; return '<span class="sgc-res" data-sgc-res="' + esc(clave) + '"' + (r ? ' data-ok="1"' : '') + '>' + (r ? chip(r) : '') + '</span>'; }
  /* Rellena los chips de resumen que una vista dejó como <span data-sgc-res="U:5"></span>. */
  function pintarResumen(root) {
    var els = Array.prototype.slice.call((root || document).querySelectorAll('[data-sgc-res]:not([data-ok])')); if (!els.length) return;
    resumen(els.map(function (e) { return e.getAttribute('data-sgc-res'); })).then(function (m) {
      els.forEach(function (e) { var r = m[e.getAttribute('data-sgc-res')]; if (r) { e.innerHTML = chip(r); e.setAttribute('data-ok', '1'); } });
    }).catch(function () { els.forEach(function (e) { e.innerHTML = ''; }); });
  }

  /* ------------------------------------------------------------ el calendario */
  var S = null;
  function abrir(o) {
    if (!o || !/^[UGE]:\d+$/.test(o.clave || '')) return;
    var f = o.fecha ? D(o.fecha) : new Date();
    S = { clave: o.clave, nombre: o.nombre || '', detalle: o.detalle || '', mes: new Date(f.getFullYear(), f.getMonth(), 1), dia: iso(f), datos: null, error: '', cargando: true, prev: document.activeElement };
    var el = document.getElementById('sgcLayer');
    if (!el) { el = document.createElement('div'); el.id = 'sgcLayer'; document.body.appendChild(el); }
    el.hidden = false; document.documentElement.classList.add('sgc-open');
    pintar(); cargar();
    setTimeout(function () { var b = el.querySelector('.sgc-x'); if (b) b.focus(); }, 30);
  }
  function cerrar() {
    var el = document.getElementById('sgcLayer'); if (el) { el.hidden = true; el.innerHTML = ''; }
    document.documentElement.classList.remove('sgc-open');
    if (S && S.prev && S.prev.focus) try { S.prev.focus(); } catch (e) { }
    S = null;
  }
  function rango() { var lun = add(S.mes, -((S.mes.getDay() + 6) % 7)); return { d: lun, h: add(lun, 41) }; }
  function cargar() {
    var r = rango(), k = S.clave + iso(r.d); S.cargando = true; S.error = ''; S.k = k; pintar();
    llamar('CargaMes', { clave: S.clave, desde: iso(r.d), hasta: iso(r.h) }).then(function (x) {
      if (!S || S.k !== k) return;
      S.datos = x; S.cargando = false; if (x.recurso && x.recurso.NOMBRE) S.nombre = x.recurso.NOMBRE; pintar();
    }).catch(function (e) { if (!S) return; S.cargando = false; S.error = e.message || 'No se pudo leer la carga.'; pintar(); });
  }
  function porDia() {
    var m = {}; ((S.datos && S.datos.trabajos) || []).forEach(function (t) { var k = String(t.INICIO).slice(0, 10); (m[k] = m[k] || []).push(t); }); return m;
  }
  function claseCarga(min) { var p = min / CAP; return p > 1 ? 'sgc-n3' : p > 0.75 ? 'sgc-n2' : 'sgc-n1'; }
  function pintar() {
    var el = document.getElementById('sgcLayer'); if (!el || !S) return;
    var r = rango(), m = porDia(), mes = S.mes.getMonth(), all = (S.datos && S.datos.trabajos) || [];
    var delMes = all.filter(function (t) { return D(t.INICIO).getMonth() === mes; });
    var min = delMes.reduce(function (s, t) { return s + (+t.MINUTOS || 0); }, 0), choques = delMes.filter(function (t) { return t.CHOQUE; }).length;
    var sobre = Object.keys(m).filter(function (k) { return D(k).getMonth() === mes && m[k].reduce(function (s, t) { return s + (+t.MINUTOS || 0); }, 0) > CAP; }).length;
    var rec = (S.datos && S.datos.recurso) || {}, t0 = S.clave.charAt(0);
    var av = t0 === 'U' ? '<span class="sgc-av">' + esc(ini(S.nombre)) + '</span>' : '<span class="sgc-av sgc-av2">' + ic(t0 === 'G' ? 'users' : 'bld', 20) + '</span>';
    var sub = [rec.TIPO_RECURSO || (t0 === 'U' ? 'Persona' : t0 === 'G' ? 'Grupo de trabajo' : 'Empresa externa'), S.detalle, rec.INTEGRANTES != null ? rec.INTEGRANTES + ' integrantes vigentes' : ''].filter(Boolean).map(esc).join(' · ');

    var cells = '';
    for (var i = 0; i < 42; i++) {
      var d = add(r.d, i), k = iso(d), l = (m[k] || []).slice().sort(function (a, b) { return a.INICIO < b.INICIO ? -1 : 1; }), mm = l.reduce(function (s, t) { return s + (+t.MINUTOS || 0); }, 0), ch = l.some(function (t) { return t.CHOQUE; });
      var fuera = d.getMonth() !== mes;
      cells += '<button type="button" class="sgc-d' + (fuera ? ' sgc-out' : '') + (k === HOY ? ' sgc-hoy' : '') + (k === S.dia ? ' sgc-sel' : '') + (ch ? ' sgc-dch' : '') + '" data-sgc-dia="' + k + '" aria-pressed="' + (k === S.dia) + '" aria-label="' + DIASL[d.getDay()] + ' ' + d.getDate() + ' de ' + MESES[d.getMonth()] + ': ' + (l.length ? l.length + ' trabajos, ' + horas(mm) : 'libre') + (ch ? ', con choque' : '') + '">' +
        '<span class="sgc-dh"><b>' + d.getDate() + '</b>' + (l.length ? '<small>' + horas(mm) + '</small>' : '') + '</span>' +
        (l.length ? '<span class="sgc-bar ' + claseCarga(mm) + '"><i style="width:' + Math.min(100, Math.round(mm / CAP * 100)) + '%"></i></span>' : '') +
        l.slice(0, 2).map(function (t) { return '<span class="sgc-it ' + (TIPO[t.TIPO] || TIPO.OT)[1] + (t.CHOQUE ? ' sgc-itch' : '') + '"><em>' + hm(t.INICIO) + '</em>' + esc(t.OT_NUMERO ? 'OT-' + t.OT_NUMERO : t.REF_CODIGO) + '</span>'; }).join('') +
        (l.length > 2 ? '<span class="sgc-more">+' + (l.length - 2) + ' más</span>' : '') + '</button>';
    }
    var dl = (m[S.dia] || []).slice().sort(function (a, b) { return a.INICIO < b.INICIO ? -1 : 1; }), dmin = dl.reduce(function (s, t) { return s + (+t.MINUTOS || 0); }, 0), dd = D(S.dia);
    var det = '<div class="sgc-side-h"><b>' + DIASL[dd.getDay()].charAt(0).toUpperCase() + DIASL[dd.getDay()].slice(1) + ' ' + dd.getDate() + ' de ' + MESES[dd.getMonth()] + '</b>' +
      '<small>' + (dl.length ? dl.length + (dl.length === 1 ? ' trabajo' : ' trabajos') + ' · ' + horas(dmin) + ' de 8 h' : 'Sin trabajos asignados') + '</small>' +
      (dl.length ? '<span class="sgc-bar sgc-bar-lg ' + claseCarga(dmin) + '"><i style="width:' + Math.min(100, Math.round(dmin / CAP * 100)) + '%"></i></span>' : '') + '</div>' +
      (dl.length ? '<ol class="sgc-tl">' + dl.map(function (t) {
        var tp = TIPO[t.TIPO] || TIPO.OT;
        return '<li class="' + (t.CHOQUE ? 'sgc-tlch' : '') + '"><span class="sgc-tl-h"><b>' + hm(t.INICIO) + '</b><small>' + hm(t.FIN) + '</small></span><span class="sgc-tl-c"><span class="sgc-tl-t"><span class="sgc-k ' + tp[1] + '">' + tp[0] + '</span><b>' + esc(t.OT_NUMERO ? 'OT-' + t.OT_NUMERO : t.REF_CODIGO) + '</b>' + (t.CHOQUE ? '<span class="sgc-chip sgc-ch">' + ic('alert', 11) + 'Choca</span>' : '') + '</span>' +
          '<span class="sgc-tl-n">' + esc(t.REF_NOMBRE) + '</span>' + (t.ACTIVO ? '<small>' + esc(t.ACTIVO_CODIGO) + ' · ' + esc(t.ACTIVO) + '</small>' : '') + (t.VIA ? '<small>Asignado vía ' + esc(t.VIA) + '</small>' : '') +
          (t.URL ? '<a class="sgc-lnk" href="' + esc(t.URL) + '">' + ic('ext', 13) + 'Abrir OT-' + esc(t.OT_NUMERO) + '</a>' : '') + '</span></li>';
      }).join('') + '</ol>' : '<div class="sgc-free">' + ic('cal', 22) + '<b>Día libre</b><span>Se le puede asignar trabajo sin choques.</span></div>');

    el.innerHTML = '<div class="sgc-bk" data-sgc-cerrar="1"></div><div class="sgc-m" role="dialog" aria-modal="true" aria-labelledby="sgcT">' +
      '<div class="sgc-h">' + av + '<div class="sgc-ht"><span class="sgc-ey">Carga laboral</span><b id="sgcT">' + esc(S.nombre || 'Sin nombre') + '</b><small>' + sub + '</small></div><button type="button" class="sgc-x" data-sgc-cerrar="1" aria-label="Cerrar">' + ic('x', 18) + '</button></div>' +
      '<div class="sgc-bar2"><div class="sgc-nav"><button type="button" class="sgc-ib" data-sgc-mes="-1" aria-label="Mes anterior">' + ic('l') + '</button><b>' + MESES[mes].charAt(0).toUpperCase() + MESES[mes].slice(1) + ' ' + S.mes.getFullYear() + '</b><button type="button" class="sgc-ib" data-sgc-mes="1" aria-label="Mes siguiente">' + ic('r') + '</button><button type="button" class="sgc-hoyb" data-sgc-mes="0">Hoy</button></div>' +
      '<div class="sgc-kpis"><span><small>Horas asignadas</small><b>' + horas(min) + '</b></span><span><small>Trabajos</small><b>' + delMes.length + '</b></span><span class="' + (sobre ? 'sgc-kw' : '') + '"><small>Días sobre 8 h</small><b>' + sobre + '</b></span><span class="' + (choques ? 'sgc-kr' : '') + '"><small>Choques</small><b>' + choques + '</b></span></div></div>' +
      '<div class="sgc-b">' + (S.error ? '<div class="sgc-err">' + ic('alert', 16) + esc(S.error) + ' <button type="button" class="sgc-hoyb" data-sgc-mes="0">Reintentar</button></div>' : '') +
      '<div class="sgc-cal' + (S.cargando ? ' sgc-busy' : '') + '"><div class="sgc-wk">' + DIAS.map(function (x) { return '<span>' + x + '</span>'; }).join('') + '</div><div class="sgc-g">' + cells + '</div>' +
      '<div class="sgc-leg"><span><i class="sgc-k-plan"></i>Plan</span><span><i class="sgc-k-ins"></i>Inspección</span><span><i class="sgc-k-tar"></i>Tarea</span><span><i class="sgc-k-ot"></i>OT</span><span><i class="sgc-lch"></i>Choque</span><span class="sgc-legb"><i class="sgc-n1"></i>Holgado <i class="sgc-n2"></i>Cerca de 8 h <i class="sgc-n3"></i>Sobre 8 h</span></div></div>' +
      '<aside class="sgc-side" aria-live="polite">' + (S.cargando && !S.datos ? '<div class="sgc-sk"></div><div class="sgc-sk"></div>' : det) + '</aside></div></div>';
  }

  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('[data-sgc-clave]');
    if (b) { e.preventDefault(); e.stopPropagation(); abrir({ clave: b.getAttribute('data-sgc-clave'), nombre: b.getAttribute('data-sgc-nombre'), detalle: b.getAttribute('data-sgc-detalle'), fecha: b.getAttribute('data-sgc-fecha') || '' }); return; }
    if (!S) return;
    var t = e.target.closest && e.target.closest('#sgcLayer [data-sgc-cerrar],#sgcLayer [data-sgc-mes],#sgcLayer [data-sgc-dia]'); if (!t) return;
    e.stopPropagation();
    if (t.hasAttribute('data-sgc-cerrar')) { cerrar(); return; }
    if (t.hasAttribute('data-sgc-dia')) { S.dia = t.getAttribute('data-sgc-dia'); var dd = D(S.dia); if (dd.getMonth() !== S.mes.getMonth()) { S.mes = new Date(dd.getFullYear(), dd.getMonth(), 1); cargar(); } else pintar(); return; }
    var v = +t.getAttribute('data-sgc-mes');
    if (v === 0) { var h = new Date(); S.mes = new Date(h.getFullYear(), h.getMonth(), 1); S.dia = HOY; }
    else { S.mes = new Date(S.mes.getFullYear(), S.mes.getMonth() + v, 1); S.dia = iso(S.mes); }
    cargar();
  }, true);
  document.addEventListener('keydown', function (e) {
    if (!S) return;
    if (e.key === 'Escape') { e.stopPropagation(); e.preventDefault(); cerrar(); return; }
    if (e.key === 'Tab') { var f = Array.prototype.slice.call(document.querySelectorAll('#sgcLayer button, #sgcLayer a')); if (!f.length) return; var a = f[0], z = f[f.length - 1]; if (e.shiftKey && document.activeElement === a) { e.preventDefault(); z.focus(); } else if (!e.shiftKey && document.activeElement === z) { e.preventDefault(); a.focus(); } }
  }, true);

  /* Los chips aparecen solos: cuando una vista pinta <span data-sgc-res>, se llenan con el resumen. */
  var PEND = 0;
  if (window.MutationObserver) new MutationObserver(function () {
    if (PEND) return; PEND = setTimeout(function () { PEND = 0; if (document.querySelector('[data-sgc-res]:not([data-ok])')) pintarResumen(document); }, 60);
  }).observe(document.documentElement, { childList: true, subtree: true });
  window.SigmaCarga = { abrir: abrir, cerrar: cerrar, resumen: resumen, chip: chip, chipDe: chipDe, boton: boton, pintarResumen: pintarResumen };
})();
