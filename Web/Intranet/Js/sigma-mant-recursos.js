/* =====================================================================
   RECURSOS · el material con que se arman planes, inspecciones y tareas (parte e)
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Biblioteca)
   Pestañas: Procedimientos · Pautas de inspección · Calendarios compartidos · Ajustes.
   Datos: WsRecursos.asmx (BD/406) y, para los calendarios, WsCentroPlanificacion.asmx.
   Los cajones son de UNA sola página, tal cual el mockup (PANELS.proc, PANELS.pau, PANELS.scal).
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG;
  var esc = K.esc, ic = K.ic, pl = K.pl, nrm = K.nrm, $ = K.$, $$ = K.$$, fH = K.fH, fN = K.fN;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var apiCP = function (m, d) { return K.llamar(CFG.base_ + 'WebService/WsCentroPlanificacion.asmx/', m, d); };
  var mc = function (cls, txt, ico) { return '<div class="cp-msg ' + (cls ? 'cp-' + cls : '') + '">' + ic(ico || (cls === 'i' ? 'help' : 'alert'), 13) + '<span>' + txt + '</span></div>'; };
  var skel = function (n, h) { var o = ''; for (var i = 0; i < (n || 4); i++) o += '<div class="cp-sk" style="height:' + (h || 56) + 'px"></div>'; return '<div style="padding:10px;display:flex;flex-direction:column;gap:10px">' + o + '</div>'; };
  var pad = function (n) { return (n < 10 ? '0' : '') + n; };
  var cap = function (s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; };

  var HINT = {
    procedimientos: 'Los procedimientos se usan en las actividades de los planes y en OT manuales. Los de «Sistema» se copian para usarlos.',
    pautas: 'Una pauta es la lista de verificación de una inspección: ítems, umbrales y dependencias. Cambiarla publica una versión nueva.',
    calendarios: 'Un calendario compartido lo usan varios planes, inspecciones o tareas. Cambiarlo cambia para todos.',
    ajustes: 'Catálogos del módulo. Solo se puede quitar lo que nadie usa.'
  };
  var U = { d: null, error: '', cals: null, calErr: '', cat: null, q: '', tipo: '', perm: {} };

  /* ------------------------------------------------------------ carga */
  function cargar() {
    U.error = '';
    return api('Cargar', {}).then(function (r) {
      U.d = r; U.perm = r.permisos || {};
      if (r.procedimientos) L.badge('procedimientos', r.procedimientos.length);
      if (r.pautas) L.badge('pautas', r.pautas.length);
      pintar();
    }).catch(function (e) { U.error = e.message; pintar(); });
  }
  function cargarCals() {
    U.calErr = '';
    return apiCP('Calendarios', {}).then(function (r) { U.cals = r.calendarios || []; L.badge('calendarios', U.cals.length); pintar(); })
      .catch(function (e) { U.calErr = e.message; U.cals = []; pintar(); });
  }
  function catalogos() {
    if (U.cat) return Promise.resolve(U.cat);
    return api('Catalogos', {}).then(function (c) { U.cat = c; return c; });
  }
  var cur = null;
  function pintar() {
    var b = $('#rcRoot'); if (!b || !cur) return;
    var fo = K.grabFocus(b), sy = window.scrollY;
    b.innerHTML = '<div class="cp-hint2" style="margin-bottom:12px">' + ic('help', 15) + '<span>' + HINT[cur] + '</span></div>' + (VISTA[cur] || function () { return ''; })();
    K.putFocus(fo, b); window.scrollTo(0, sy);
  }
  function errorBox(m, a) { return '<div class="cp-card"><div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudo cargar</b>' + esc(m) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="' + a + '">Reintentar</button></div></div>'; }
  function sinPermiso(t) { return '<div class="cp-card"><div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('shield', 20) + '</span><b>Sin acceso</b>' + t + '</div></div>'; }

  /* ============================================================ PROCEDIMIENTOS */
  var VISTA = {};
  VISTA.procedimientos = function () {
    if (U.error) return errorBox(U.error, 'rcreload');
    if (!U.d) return '<div class="cp-card">' + skel(5) + '</div>';
    if (!U.perm.procVer) return sinPermiso('Necesitas el permiso para ver procedimientos.');
    var all = U.d.procedimientos || [], q = nrm(U.q), tipos = {};
    all.forEach(function (p) { if (p.TIPO) tipos[p.TIPO] = 1; });
    var list = all.filter(function (p) { return (!q || nrm(p.CODIGO + ' ' + p.NOMBRE).indexOf(q) >= 0) && (!U.tipo || (U.tipo === '__sys' ? p.ES_GLOBAL : p.TIPO === U.tipo)); });
    var cols = 'grid-template-columns:96px minmax(0,1.6fr) minmax(0,1fr) 64px 70px minmax(0,.9fr) 118px';
    var tiposL = [{ id: '', n: 'Todos los tipos' }].concat(Object.keys(tipos).sort().map(function (t) { return { id: t, n: t }; }), [{ id: '__sys', n: 'Sistema' }]);
    return '<div class="cp-card" style="padding:8px 10px"><div class="cp-ex-bar" style="padding:6px 6px 10px">' +
      '<label class="cp-srch2" style="height:36px;flex:1;min-width:200px;max-width:380px">' + ic('search', 14) + '<input id="rcQ" data-pv="q" data-live="1" value="' + esc(U.q) + '" placeholder="Código o nombre del procedimiento" aria-label="Buscar procedimientos" autocomplete="off"></label>' +
      '<span style="min-width:200px">' + K.combo('rcTipo', tiposL, U.tipo, { etiqueta: 'Tipo de activo', ph: 'Todos los tipos' }) + '</span>' +
      (U.perm.procEd ? '<span class="cp-r" style="margin-left:auto"><button type="button" class="cp-btn cp-pri cp-sm" data-a="prnew">' + ic('plus', 15) + 'Nuevo procedimiento</button></span>' : '') + '</div>' +
      '<div class="cp-rows"><div class="cp-rw cp-h" style="' + cols + '"><span>Código</span><span>Nombre</span><span>Tipo de activo</span><span>Pasos</span><span>Duración</span><span>Dónde se usa</span><span></span></div>' +
      (list.map(function (p) {
        var det = [pl(+p.CONTROLES || 0, 'punto de control', 'puntos de control'), pl(+p.MEDICIONES || 0, 'medición', 'mediciones')].concat(p.PERMISO ? [p.PERMISO] : []).join(' · ');
        var uso = +p.ACTIVIDADES ? pl(+p.ACTIVIDADES, 'actividad', 'actividades') + ' · ' + pl(+p.PLANES, 'plan', 'planes') : 'Sin uso';
        var acc = p.ES_GLOBAL ? (U.perm.procEd ? '<button type="button" class="cp-btn cp-out cp-xs" data-a="prcopy" data-id="' + p.ID + '">Copiar para usar</button>' : '')
          : '<button type="button" class="cp-btn cp-plain cp-xs" data-a="propen" data-id="' + p.ID + '">' + (U.perm.procEd ? 'Editar' : 'Ver') + '</button>';
        return '<div class="cp-rw cp-click" style="' + cols + '" data-a="propen" data-id="' + p.ID + '" role="button" tabindex="0"><span class="cp-mono">' + esc(p.CODIGO) + ' v' + (p.VERSION || 1) + '</span>' +
          '<span class="cp-s"><b>' + esc(p.NOMBRE) + '</b><small>' + esc(det) + '</small></span>' +
          '<span class="cp-s"><b style="font-weight:600">' + (p.ES_GLOBAL ? '<span class="cp-tg cp-p">Sistema</span>' : esc(p.TIPO || 'Cualquier tipo')) + '</b></span>' +
          '<span class="cp-tn">' + (+p.PASOS || 0) + '</span><span class="cp-tn">' + (p.DURACION ? fH(p.DURACION) : '—') + '</span>' +
          '<span class="cp-s"><small style="color:var(--ink-2)">' + uso + '</small></span><span style="text-align:right">' + acc + '</span></div>';
      }).join('') || '<div class="cp-empty" style="margin:10px">' + ic('search', 18) + '<b>' + (all.length ? 'Ningún procedimiento coincide' : 'Aún no hay procedimientos') + '</b>' + (all.length ? '<button type="button" class="cp-lnk" data-a="rcqclr">Limpiar búsqueda</button>' : 'Crea el primero con «Nuevo procedimiento».') + '</div>') + '</div></div>';
  };

  /* ---- cajón del procedimiento (PANELS.proc del mockup) ---- */
  var paso = function () { return { id: 0, nombre: '', instruccion: '', ctrl: false, ev: false, med: false, variable: '', dur: '' }; };
  function abrirProc(id) {
    var st = { t: 'proc', d: { id: 0, codigo: '', version: 1, nombre: '', tipo: '', permiso: '', dur: '', descripcion: '', glob: false, pasos: [paso()] }, usos: [], err: false, err2: '', busy: false, cargando: id > 0 || !U.cat };
    K.Panel.open({ render: PPROC, st: st });
    Promise.all([catalogos(), id ? api('Procedimiento', { id: id }) : null]).then(function (x) {
      var r = x[1];
      if (r) {
        var h = r.cabecera;
        st.d = { id: id, codigo: h.prc_codigo, version: h.prc_version || 1, nombre: h.prc_nombre || '', tipo: h.prc_activo_tipo || '', permiso: h.prc_requiere_permiso ? (h.prc_permiso_trabajo_tipo || '') : '',
          dur: h.prc_duracion_estimada_minuto ? Math.round(h.prc_duracion_estimada_minuto / 60 * 100) / 100 : '', descripcion: h.prc_descripcion || '', glob: !!(+h.ES_GLOBAL),
          pasos: (r.pasos || []).map(function (s) { return { id: s.ppa_id, nombre: s.ppa_nombre || '', instruccion: s.ppa_instruccion || '', ctrl: !!s.ppa_es_punto_control, ev: !!s.ppa_requiere_evidencia, med: !!s.ppa_requiere_medicion, variable: s.ppa_variable_medicion || '', dur: s.ppa_duracion_estimada_minuto || '' }; }) };
        if (!st.d.pasos.length) st.d.pasos.push(paso());
        st.usos = r.usos || [];
      }
      st.cargando = false; if (K.Panel.state() === st) K.Panel.paint();
    }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  }
  var PPROC = function (st) {
    if (st.cargando) return { t: 'Procedimiento', s: 'Recursos · Procedimientos', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:260px;margin-top:12px"></div>' };
    var d = st.d, ro = d.glob || !U.perm.procEd, dis = ro ? ' disabled' : '', e = st.err, cat = U.cat || {};
    var sumMin = d.pasos.reduce(function (s, x) { return s + (+x.dur || 0); }, 0), durH = parseFloat(String(d.dur).replace(',', '.')) || 0;
    var vars = (cat.variables || []).map(function (v) { return { id: v.VME_ID, n: v.ETIQUETA || v.VME_NOMBRE, sub: +v.ES_GLOBAL ? 'Común de SIGMA' : '' }; });
    var medidas = (cat.medidas || []).map(function (m) { return { id: m.ID, n: m.SIMBOLO + ' · ' + m.NOMBRE, txt: m.SIMBOLO + ' ' + m.NOMBRE }; });
    var activos = st.usos.filter(function (u) { return +u.ESTADO === 2; }).length;
    var nAct = st.usos.reduce(function (s, u) { return s + (+u.ACTIVIDADES || 0); }, 0);
    var fila = function (s, k) {
      var nueva = /^nuevo:/.test(String(s.variable || '')), malN = e && !String(s.nombre).trim(), malV = e && s.med && (!s.variable || (nueva && !s.unidad));
      return '<div class="cp-stp"><span class="cp-o">' + (k + 1) + '</span><div class="cp-b">' +
        '<input class="cp-inp' + (malN ? ' cp-err' : '') + '" data-pv="s:' + k + '.nombre" value="' + esc(s.nombre) + '" placeholder="Nombre del paso" aria-label="Nombre del paso ' + (k + 1) + '" maxlength="200" autocomplete="off"' + dis + '>' + (malN ? mc('', 'El paso necesita un nombre.') : '') +
        '<textarea class="cp-inp" rows="1" data-pv="s:' + k + '.instruccion" placeholder="Instrucción para quien ejecuta" aria-label="Instrucción del paso ' + (k + 1) + '"' + dis + '>' + esc(s.instruccion) + '</textarea>' +
        '<div class="cp-fl2"><label class="cp-sw"><input type="checkbox" data-pv="s:' + k + '.ctrl"' + (s.ctrl ? ' checked' : '') + dis + '><i></i>Punto de control</label>' +
        '<label class="cp-sw"><input type="checkbox" data-pv="s:' + k + '.ev"' + (s.ev ? ' checked' : '') + dis + '><i></i>Requiere evidencia</label>' +
        '<label class="cp-sw"><input type="checkbox" data-pv="s:' + k + '.med"' + (s.med ? ' checked' : '') + dis + '><i></i>Requiere medición</label>' +
        '<span class="cp-unit" style="width:120px"><input class="cp-inp" type="number" min="0" data-pv="s:' + k + '.dur" value="' + esc(s.dur) + '" aria-label="Duración del paso"' + dis + ' style="height:32px"><span class="cp-u" style="height:32px">min</span></span></div>' +
        (s.med ? '<div>' + K.combo('rcVar' + k, vars, s.variable, { etiqueta: 'Variable a medir', ph: 'Variable a medir, ej.: Presión (bar)', err: malV && !nueva, dis: ro, crear: !ro, data: ' data-pp="s:' + k + '.variable"' }) +
          (nueva ? '<div class="cp-fld" style="margin-top:8px"><label>Unidad de «' + esc(String(s.variable).slice(6)) + '» <small>variable nueva de la empresa</small></label>' + K.combo('rcVarU' + k, medidas, s.unidad || '', { etiqueta: 'Unidad', ph: 'Elige la unidad: °C, bar, mm/s…', err: malV, data: ' data-pp="s:' + k + '.unidad"' }) + '</div>' : '') +
          (malV ? mc('', nueva ? 'Elige la unidad de la variable nueva.' : 'Elige qué se mide en este paso o escribe una nueva para crearla.') : '') + '</div>' : '') + '</div>' +
        (ro ? '<span></span>' : '<div class="cp-x"><button type="button" class="cp-ibx" data-a="stmv" data-v="' + k + '" data-d="-1"' + (k ? '' : ' disabled') + ' aria-label="Subir paso">' + ic('chev', 14).replace('<svg', '<svg style="transform:rotate(-90deg)"') + '</button>' +
          '<button type="button" class="cp-ibx" data-a="stmv" data-v="' + k + '" data-d="1"' + (k < d.pasos.length - 1 ? '' : ' disabled') + ' aria-label="Bajar paso">' + ic('chev', 14).replace('<svg', '<svg style="transform:rotate(90deg)"') + '</button>' +
          '<button type="button" class="cp-ibx cp-dn" data-a="strm" data-v="' + k + '"' + (d.pasos.length > 1 ? '' : ' disabled') + ' aria-label="Quitar paso">' + ic('x', 14) + '</button></div>') + '</div>';
    };
    var tiposL = [{ id: '', n: 'Cualquier tipo' }].concat((cat.tipos || []).map(function (r) { return { id: r.ID, n: r.NOMBRE }; }));
    var permL = [{ id: '', n: 'No requiere permiso' }].concat((cat.permisos || []).map(function (r) { return { id: r.ID, n: r.NOMBRE }; }));
    var b = (d.glob ? '<div class="cp-bnr cp-i">' + ic('shield', 18) + '<span>Es un procedimiento de <b>Sistema</b>: se ve, pero no se edita ni se usa directo. Cópialo para tener tu versión y usarla en actividades.</span></div>' : '') +
      (st.usos.length && !d.glob ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span>Usado por <b>' + pl(nAct, 'actividad', 'actividades') + '</b> de <b>' + pl(st.usos.length, 'plan', 'planes') + '</b>' + (activos ? ' (' + pl(activos, 'activo', 'activos') + ')' : '') + ': ' + st.usos.map(function (u) { return esc(u.PLAN_CODIGO); }).join(', ') + '. Las OT futuras tomarán los pasos nuevos; las ya generadas no cambian.</span></div>' : '') +
      '<div class="cp-grid4c"><div class="cp-fld" style="grid-column:span 2"><label>Nombre</label><input class="cp-inp' + (e && !String(d.nombre).trim() ? ' cp-err' : '') + '" data-pv="p.nombre" value="' + esc(d.nombre) + '" maxlength="400" data-autofocus="1" autocomplete="off"' + dis + '>' + (e && !String(d.nombre).trim() ? mc('', 'El procedimiento necesita un nombre.') : '') + '</div>' +
      '<div class="cp-fld"><label>Tipo de activo</label>' + K.combo('rcPrTipo', tiposL, d.tipo, { etiqueta: 'Tipo de activo', ph: 'Cualquier tipo', dis: ro, data: ' data-pp="p.tipo"' }) + '</div>' +
      '<div class="cp-fld"><label>Duración estimada</label><div class="cp-unit"><input class="cp-inp" type="number" min="0.25" step="0.25" data-pv="p.dur" value="' + esc(d.dur) + '" aria-label="Duración estimada"' + dis + '><span class="cp-u">horas</span></div></div>' +
      '<div class="cp-fld" style="grid-column:span 2"><label>Permiso de trabajo</label>' + K.combo('rcPrPerm', permL, d.permiso, { etiqueta: 'Permiso de trabajo', ph: 'No requiere permiso', dis: ro, data: ' data-pp="p.permiso"' }) + '</div></div>' +
      '<div class="cp-blk-h" style="margin:4px 0 -4px"><h4>Pasos · ' + d.pasos.length + '</h4><small>Los pasos suman ' + fN(sumMin) + ' min; el procedimiento estima ' + fH(durH * 60) + '.' + (durH && Math.abs(sumMin / 60 - durH) > .25 ? ' <span style="color:var(--amber);font-weight:700">Revisa la diferencia.</span>' : '') + '</small></div>' +
      '<div class="cp-steps">' + d.pasos.map(fila).join('') + '</div>' +
      (ro ? '' : '<button type="button" class="cp-btn cp-out cp-sm" style="align-self:flex-start" data-a="stadd">' + ic('plus', 15) + 'Agregar paso</button>') + (st.err2 ? mc('', esc(st.err2)) : '');
    var f = d.glob ? '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button>' + (U.perm.procEd ? '<button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="prcopy" data-id="' + d.id + '">Copiar para usar</button>' : '') + '</span>'
      : ro ? '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button></span>'
      : (e ? '<span class="cp-msg">' + ic('alert', 13) + '<span>Revisa los campos marcados.</span></span>' : '') + '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="prsave">' + ic('check', 16) + 'Guardar procedimiento</button></span>';
    return { t: d.id ? esc(d.codigo) + ' v' + d.version + ' · ' + esc(d.nombre || 'Procedimiento') : 'Nuevo procedimiento', s: d.glob ? 'Procedimiento del sistema · solo lectura' : 'Recursos · Procedimientos', w: 'w', b: b, f: f };
  };

  /* ============================================================ PAUTAS */
  VISTA.pautas = function () {
    if (U.error) return errorBox(U.error, 'rcreload');
    if (!U.d) return '<div class="cp-card">' + skel(4) + '</div>';
    if (!U.perm.pauVer) return sinPermiso('Necesitas el permiso para ver las pautas de inspección.');
    var all = U.d.pautas || [];
    var cols = 'grid-template-columns:104px minmax(0,1.5fr) minmax(0,1fr) 100px 90px minmax(0,1fr) 18px';
    return '<div class="cp-card" style="padding:8px 10px"><div class="cp-ex-bar" style="padding:6px 6px 10px"><span style="font-size:12.5px;color:var(--muted)">' + pl(all.length, 'pauta', 'pautas') + '</span>' +
      (U.perm.pauEd ? '<span class="cp-r" style="margin-left:auto"><button type="button" class="cp-btn cp-pri cp-sm" data-a="paunew">' + ic('plus', 15) + 'Nueva pauta</button></span>' : '') + '</div>' +
      '<div class="cp-rows"><div class="cp-rw cp-h" style="' + cols + '"><span>Código</span><span>Pauta</span><span>Alcance</span><span>Ítems</span><span>Umbrales</span><span>Se usa en</span><span></span></div>' +
      (all.map(function (p) {
        var sub = [pl(+p.SECCIONES || 0, 'sección', 'secciones')].concat(+p.DEPENDENCIAS ? [pl(+p.DEPENDENCIAS, 'dependencia', 'dependencias')] : []).join(' · ');
        return '<div class="cp-rw cp-click" style="' + cols + '" data-a="pauopen" data-id="' + p.ID + '" role="button" tabindex="0"><span class="cp-mono">' + esc(p.CODIGO) + ' v' + (+p.VERSION || 1) + '</span>' +
          '<span class="cp-s"><b>' + esc(p.NOMBRE) + (p.CAMBIOS ? ' <span class="cp-tg cp-p">Cambios sin publicar</span>' : !p.PUBLICADA ? ' <span class="cp-tg">Borrador</span>' : '') + '</b><small>' + sub + '</small></span>' +
          '<span class="cp-s"><b style="font-weight:600">' + esc(p.PLANTA || 'Todas las plantas') + '</b><small>' + esc(p.TIPO || 'Cualquier tipo de activo') + '</small></span>' +
          '<span class="cp-s"><b style="font-weight:600">' + (+p.ITEMS || 0) + '</b><small>' + pl(+p.CRITICOS || 0, 'crítico', 'críticos') + '</small></span><span class="cp-tn">' + (+p.UMBRALES || 0) + '</span>' +
          '<span class="cp-s"><small style="color:var(--ink-2)" title="' + esc(p.USOS_TXT) + '">' + (+p.USOS ? esc(p.USOS_TXT) : 'Sin uso') + '</small></span><span>' + ic('chev', 15) + '</span></div>';
      }).join('') || '<div class="cp-empty" style="margin:10px">' + ic('clip', 18) + '<b>Aún no hay pautas de inspección</b>' + (U.perm.pauEd ? 'Crea la primera con «Nueva pauta».' : '') + '</div>') + '</div></div>';
  };

  /* ---- cajón de la pauta (PANELS.pau del mockup) ---- */
  var ITT = { ok: 'Cumple / no cumple', num: 'Medición con rango', txt: 'Texto', foto: 'Foto' };
  var TIPO_A_ITT = { 5: 'ok', 4: 'num', 3: 'num', 1: 'txt', 2: 'txt', 12: 'foto' };
  var paAdd = function (s, t) { return { n: '', t: t || 'ok', s: s || 0, min: '', max: '', u: '', crit: false, err: false }; };
  var rng = function (it) { var a = it.min !== '' && it.min != null, b = it.max !== '' && it.max != null, u = it.u ? ' ' + it.u : ''; return a && b ? fN(+it.min, 2).replace(/,00$/, '') + '–' + fN(+it.max, 2).replace(/,00$/, '') + u : a ? '≥ ' + it.min + u : b ? '≤ ' + it.max + u : 'sin rango'; };
  function abrirPauta(id) {
    var st = { t: 'pau', id: id || 0, d: { n: '', secs: [{ codigo: '', n: 'General', items: [] }], deps: [] }, usos: [], cab: null, add: paAdd(), dep: depNueva(), edit: null, dirty: false, err: false, err2: '', busy: false, cargando: true, nsec: false, secN: '' };
    K.Panel.open({ render: PPAU, st: st });
    Promise.all([catalogos(), id ? api('Pauta', { id: id }) : null]).then(function (x) {
      var r = x[1];
      if (r) {
        st.cab = r.cabecera;
        var secs = (r.secciones || []).map(function (s) { return { codigo: s.CODIGO, n: s.NOMBRE, items: [] }; });
        (r.items || []).forEach(function (i) {
          var s = secs.filter(function (z) { return z.codigo === i.SECCION; })[0];
          if (!s) { s = { codigo: i.SECCION || '', n: 'General', items: [] }; secs.push(s); }
          s.items.push({ k: i.CODIGO, codigo: i.CODIGO, tipoId: i.TIPO, n: i.TEXTO, t: TIPO_A_ITT[i.TIPO] || 'txt', tipoN: i.TIPO_NOMBRE, min: i.MINIMO == null ? '' : i.MINIMO, max: i.MAXIMO == null ? '' : i.MAXIMO, unidad: i.UNIDAD || 0, u: i.UNIDAD_SIMBOLO || '', crit: !!i.CRITICO });
        });
        if (!secs.length) secs.push({ codigo: '', n: 'General', items: [] });
        st.d = { n: st.cab.NOMBRE, secs: secs, deps: (r.dependencias || []).map(function (z) { return { item: z.ITEM, cond: z.COND, accion: +z.ACCION || 1, op: +z.OPERADOR || 1, valor: z.VALOR || '', opcion: z.OPCION || '' }; }) };
        st.usos = r.usos || [];
      }
      st.cargando = false; if (K.Panel.state() === st) K.Panel.paint();
    }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  }
  /* 417 · dependencias entre ítems: «Mostrar X cuando Y no cumple». */
  var PA_SEQ = 0;
  var DACC = [{ id: 1, n: 'Mostrar' }, { id: 2, n: 'Ocultar' }, { id: 3, n: 'Exigir' }, { id: 4, n: 'Bloquear' }];
  var DOPN = [{ id: 1, n: 'es igual a' }, { id: 2, n: 'es distinto de' }, { id: 3, n: 'es mayor que' }, { id: 4, n: 'es mayor o igual que' }, { id: 5, n: 'es menor que' }, { id: 6, n: 'es menor o igual que' }];
  var DOPT = [{ id: 1, n: 'es igual a' }, { id: 2, n: 'es distinto de' }, { id: 8, n: 'contiene' }];
  var DOPC = [{ id: 'NO', n: 'no cumple' }, { id: 'SI', n: 'cumple' }];
  function depNueva() { return { accion: 1, item: '', cond: '', op: 1, valor: '', opcion: 'NO', err: '' }; }
  function itemsDe(s) { var l = []; s.d.secs.forEach(function (sc) { sc.items.forEach(function (it) { l.push(it); }); }); return l; }
  function itemDe(s, k) { return itemsDe(s).filter(function (it) { return it.k === k; })[0]; }
  function depTexto(s, x) {
    var a = itemDe(s, x.item), c = itemDe(s, x.cond), acc = (DACC.filter(function (z) { return z.id === +x.accion; })[0] || DACC[0]).n;
    var cmp = x.opcion ? ((DOPC.filter(function (z) { return z.id === x.opcion; })[0] || {}).n || x.opcion) : ((DOPN.concat(DOPT).filter(function (z) { return z.id === +x.op; })[0] || {}).n || '') + ' ' + x.valor;
    return '<b>' + acc + '</b> «' + esc(a ? a.n : '?') + '» cuando «' + esc(c ? c.n : '?') + '» ' + esc(cmp);
  }
  function depsHTML(s, ed) {
    var d = s.d, its = itemsDe(s).filter(function (it) { return it.k; }), x = s.dep;
    if (!d.deps.length && !(ed && its.length > 1)) return '';
    var c = itemDe(s, x.cond), opts = its.map(function (it) { return { id: it.k, n: it.n }; });
    return '<div class="cp-blk"><div class="cp-blk-h"><h4>Dependencias</h4><small>' + (d.deps.length ? pl(d.deps.length, 'regla', 'reglas') : 'Ej.: mostrar «Foto de la fuga» cuando «Sin fugas» no cumple') + '</small></div>' +
      (d.deps.length ? '<ul class="cp-pa-dl">' + d.deps.map(function (z, i) { return '<li><span>' + depTexto(s, z) + '</span>' + (ed ? '<button type="button" class="cp-ibx cp-sm" data-a="paudrm" data-v="' + i + '" aria-label="Quitar la dependencia">' + ic('x', 14) + '</button>' : '') + '</li>'; }).join('') + '</ul>' : '') +
      (ed && its.length > 1 ? '<div class="cp-pa-df"><div class="cp-fld"><label>Acción</label>' + K.combo('rcDa', DACC, x.accion, { etiqueta: 'Acción de la dependencia' }) + '</div>' +
        '<div class="cp-fld"><label>Ítem</label>' + K.combo('rcDi', opts, x.item, { etiqueta: 'Ítem que depende', ph: 'Elige el ítem' }) + '</div>' +
        '<div class="cp-fld"><label>Cuando</label>' + K.combo('rcDc', opts.filter(function (o) { return o.id !== x.item; }), x.cond, { etiqueta: 'Ítem del que depende', ph: 'Elige el ítem' }) + '</div>' +
        (c ? (c.t === 'ok' ? '<div class="cp-fld"><label>Respuesta</label>' + K.combo('rcDv', DOPC, x.opcion, { etiqueta: 'Respuesta que activa la regla' }) + '</div>'
          : '<div class="cp-fld"><label>Condición</label>' + K.combo('rcDo', c.t === 'num' ? DOPN : DOPT, x.op, { etiqueta: 'Comparación' }) + '</div><div class="cp-fld"><label for="rcDval">Valor</label><input id="rcDval" class="cp-inp' + (x.err && !String(x.valor).trim() ? ' cp-err' : '') + '"' + (c.t === 'num' ? ' type="number" step="any"' : '') + ' data-pv="pa.dep.valor" value="' + esc(x.valor) + '" autocomplete="off"></div>') : '') +
        '<div class="cp-pa-dfb"><button type="button" class="cp-btn cp-out cp-sm" data-a="paudadd">' + ic('plus', 15) + 'Agregar dependencia</button></div></div>' + (x.err ? mc('', esc(x.err)) : '') : '') + '</div>';
  }
  var PPAU = function (st) {
    if (st.cargando) return { t: 'Pauta de inspección', s: 'Recursos · Pautas', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:260px;margin-top:12px"></div>' };
    var d = st.d, a = st.add, e = st.err, ed = !!U.perm.pauEd, cab = st.cab, vPub = cab && cab.VERSION_PUBLICADA ? +cab.VERSION_PUBLICADA : 0;
    var medidas = (U.cat && U.cat.medidas || []).map(function (m) { return { id: m.ID, n: m.SIMBOLO + ' · ' + m.NOMBRE, txt: m.SIMBOLO + ' ' + m.NOMBRE }; });
    var b = (st.id ? '' : '<div class="cp-fld"><label for="rcPn">Nombre de la pauta <small>obligatorio</small></label><input id="rcPn" class="cp-inp' + (e && !d.n.trim() ? ' cp-err' : '') + '" data-pv="pa.n" value="' + esc(d.n) + '" data-autofocus="1" placeholder="Ej.: Inspección sala de bombas" maxlength="200" autocomplete="off">' + (e && !d.n.trim() ? mc('', 'La pauta necesita un nombre.') : '') + '</div>') +
      (st.usos.length ? '<div class="cp-bnr cp-p">' + ic('link', 18) + '<span>La usan ' + st.usos.map(function (u) { return '<b>' + esc(u.NOMBRE) + '</b>'; }).join(', ') + '. Una versión nueva rige desde su próxima inspección.</span></div>' : '') +
      (cab && cab.ES_BORRADOR && vPub ? mc('i', 'Hay cambios guardados sin publicar: se muestran aquí y se publican junto con lo que agregues.', 'help') : '') +
      d.secs.map(function (sc, si) {
        return '<div class="cp-pa-s"><h5>' + esc(sc.n) + '<small>' + pl(sc.items.length, 'ítem', 'ítems') + '</small></h5><ul>' + (sc.items.map(function (it, ii) {
          return '<li><span class="cp-pa-n"><b>' + esc(it.n) + '</b><small>' + (ITT[it.t] || it.tipoN || '') + (it.t === 'num' ? ' · ' + esc(rng(it)) : '') + '</small></span>' + (it.crit ? '<span class="cp-tg cp-w">Crítico</span>' : '') +
            (ed ? '<button type="button" class="cp-ibx cp-sm" data-a="pauedit" data-s="' + si + '" data-v="' + ii + '" aria-label="Editar ' + esc(it.n) + '" title="Editar">' + ic('pencil', 14) + '</button><button type="button" class="cp-ibx cp-sm" data-a="paurm" data-s="' + si + '" data-v="' + ii + '" aria-label="Quitar ' + esc(it.n) + '">' + ic('x', 14) + '</button>' : '') + '</li>';
        }).join('') || '<li class="cp-pa-e">Sin ítems</li>') + '</ul></div>';
      }).join('') +
      depsHTML(st, ed) +
      (ed ? '<div class="cp-blk" id="rcPaForm"><div class="cp-blk-h"><h4>' + (st.edit ? 'Editar ítem' : 'Agregar ítem') + '</h4></div>' +
        '<div class="cp-grid2c"><div class="cp-fld" style="grid-column:1/-1"><label for="rcPai">Qué se revisa</label><input id="rcPai" class="cp-inp' + (a.err ? ' cp-err' : '') + '" data-pv="pa.add.n" value="' + esc(a.n) + '" placeholder="Ej.: Temperatura del rodamiento" maxlength="500" autocomplete="off">' + (a.err ? mc('', 'Escribe qué se revisa.') : '') + '</div>' +
        '<div class="cp-fld"><label>Tipo de respuesta</label>' + (st.edit ? '<div class="cp-inp cp-ro" title="Para cambiar el tipo de respuesta, quita el ítem y agrégalo de nuevo">' + esc(ITT[a.t] || '') + '</div>' : K.combo('rcPaT', Object.keys(ITT).map(function (k) { return { id: k, n: ITT[k] }; }), a.t, { etiqueta: 'Tipo de respuesta' })) + '</div>' +
        '<div class="cp-fld"><label>Sección</label>' + K.combo('rcPaS', d.secs.map(function (s, i) { return { id: i, n: s.n }; }).concat([{ id: 'nueva', n: '+ Nueva sección…' }]), a.s, { etiqueta: 'Sección' }) + '</div>' +
        (st.nsec ? '<div class="cp-fld" style="grid-column:1/-1"><label for="rcPns">Nombre de la sección nueva</label><div style="display:flex;gap:8px"><input id="rcPns" class="cp-inp" data-pv="pa.secN" value="' + esc(st.secN) + '" placeholder="Ej.: Lubricación" maxlength="200" autocomplete="off"><button type="button" class="cp-btn cp-out cp-sm" data-a="pausec">Crear sección</button></div></div>' : '') +
        (a.t === 'num' ? '<div class="cp-fld"><label for="rcPmn">Mínimo</label><input id="rcPmn" class="cp-inp" type="number" step="any" data-pv="pa.add.min" value="' + esc(a.min) + '"></div><div class="cp-fld"><label for="rcPmx">Máximo</label><input id="rcPmx" class="cp-inp" type="number" step="any" data-pv="pa.add.max" value="' + esc(a.max) + '"></div>' +
          '<div class="cp-fld" style="grid-column:1/-1"><label>Unidad</label>' + K.combo('rcPaU', [{ id: '', n: 'Sin unidad' }].concat(medidas), a.u, { etiqueta: 'Unidad', ph: '°C, bar, mm/s' }) + '</div>' : '') + '</div>' +
        '<label class="cp-sw" style="margin-top:6px"><input type="checkbox" data-pv="pa.add.crit"' + (a.crit ? ' checked' : '') + '><i></i>Ítem crítico: el hallazgo nace con severidad alta</label>' +
        '<div style="display:flex;justify-content:flex-end;gap:8px;margin-top:10px">' + (st.edit ? '<button type="button" class="cp-btn cp-ghost cp-sm" data-a="paucan">Cancelar</button><button type="button" class="cp-btn cp-out cp-sm" data-a="pauadd">' + ic('check', 15) + 'Guardar cambios del ítem</button>' : '<button type="button" class="cp-btn cp-out cp-sm" data-a="pauadd">' + ic('plus', 15) + 'Agregar ítem</button>') + '</div></div>' : '') + (st.err2 ? mc('', esc(st.err2)) : '');
    var puede = ed && (st.dirty || !st.id || (cab && cab.ES_BORRADOR));
    var f = '<button type="button" class="cp-btn cp-ghost" data-a="pclose">' + (st.dirty ? 'Descartar cambios' : 'Cerrar') + '</button>' + (ed ? '<span class="cp-r"><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="pausave"' + (puede ? '' : ' aria-disabled="true" title="Sin cambios"') + '>' + ic('check', 16) + (st.id ? 'Publicar v' + (vPub + 1) : 'Crear pauta') + '</button></span>' : '');
    return { t: st.id ? esc(d.n) : 'Nueva pauta de inspección', s: st.id ? esc(cab.CODIGO) + (vPub ? ' · versión ' + vPub + ' vigente' : ' · sin publicar') : 'Recursos · pautas', w: 'w', b: b, f: f };
  };

  /* ============================================================ CALENDARIOS */
  VISTA.calendarios = function () {
    if (U.d && !U.perm.calVer) return sinPermiso('Necesitas el permiso para ver programaciones.');
    if (U.calErr) return errorBox(U.calErr, 'calreload');
    if (!U.cals) return skel(3, 120);
    var ed = U.perm.calEd;
    return (ed ? '<div style="display:flex;justify-content:flex-end;margin-bottom:12px"><button type="button" class="cp-btn cp-pri cp-sm" data-a="calnew">' + ic('plus', 15) + 'Nuevo calendario</button></div>' : '') +
      '<div style="display:flex;flex-direction:column;gap:12px">' + (U.cals.map(function (c) {
        var n = c.usos.length;
        return '<div class="cp-card cp-shc"><div class="cp-shc-h"><span class="cp-pci2">' + ic('link', 18) + '</span><div style="min-width:0;flex:1"><b>' + esc(c.nombre) + '</b><small>' + esc(c.tipo || '') + (c.detalle ? ' · ' + esc(c.detalle) : '') + '</small></div>' +
          '<div class="cp-r">' + (ed && (c.tipoCodigo === 'CALENDARIO' || c.tipoCodigo === 'INTERVALO TIEMPO' || c.tipoCodigo === 'FECHA UNICA') ? '<button type="button" class="cp-btn cp-plain cp-xs" data-a="caldup" data-id="' + c.id + '">Duplicar</button>' : '') + '<button type="button" class="cp-btn cp-out cp-xs" data-a="calopen" data-id="' + c.id + '">' + (ed ? 'Editar' : 'Ver') + '</button></div></div>' +
          '<div class="cp-shc-b"><div><span class="cp-lb2">Próximas fechas</span><div>' + (c.fechas.length ? c.fechas.map(function (d) { return '<span class="cp-tg">' + K.fD(d) + '</span>'; }).join(' ') : '<span style="font-size:12px;color:var(--muted)">' + (c.tipoCodigo === 'MEDIDOR' ? 'Se dispara por medidor' : c.tipoCodigo === 'CONDICION' ? 'Se dispara por condición' : 'Sin fechas próximas') + '</span>') + '</div></div>' +
          '<div><span class="cp-lb2">Dónde se usa · ' + n + '</span><div>' + c.usos.map(function (u) { return '<span class="cp-tg' + (u.origen === 'Plan' ? ' cp-c' : '') + '">' + ic(u.origen === 'Plan' ? 'calw' : u.origen === 'Tarea' ? 'check' : 'clip', 11) + esc(u.origen) + ' · ' + esc(u.nombre) + '</span>'; }).join('') + (n ? '' : '<span style="font-size:12px;color:var(--muted)">Nadie lo usa</span>') + '</div></div></div></div>';
      }).join('') || '<div class="cp-card"><div class="cp-empty" style="border:0">' + ic('link', 18) + '<b>Aún no hay calendarios compartidos</b>' + (ed ? 'Crea el primero con «Nuevo calendario».' : '') + '</div></div>') + '</div>';
  };

  /* ---- cajón del calendario (PANELS.scal del mockup): una sola página con las próximas fechas al lado ---- */
  var REP = { DIARIA: 'd', SEMANAL: 'w', MENSUAL: 'm', ANUAL: 'y' }, REPC = { d: 'DIARIA', w: 'SEMANAL', m: 'MENSUAL', y: 'ANUAL' };
  var TIPOC = { cal: 'CALENDARIO', int: 'INTERVALO TIEMPO', fec: 'FECHA UNICA', med: 'MEDIDOR', cond: 'CONDICION' }, TIPOF = { CALENDARIO: 'cal', 'INTERVALO TIEMPO': 'int', 'FECHA UNICA': 'fec', MEDIDOR: 'med', CONDICION: 'cond' };
  var UNI = { HORA: ['hora', 'horas'], DIA: ['día', 'días'], SEMANA: ['semana', 'semanas'], MES: ['mes', 'meses'], ANIO: ['año', 'años'] };
  var HORAS = (function () { var l = []; for (var k = 0; k < 48; k++) { var h = pad(Math.floor(k / 2)) + ':' + (k % 2 ? '30' : '00'); l.push({ id: h, n: h }); } return l; })();
  var DIAS31 = (function () { var l = []; for (var k = 1; k <= 31; k++) l.push({ id: k, n: String(k) }); return l; })();
  var ORD = [{ id: 1, n: 'Primer' }, { id: 2, n: 'Segundo' }, { id: 3, n: 'Tercer' }, { id: 4, n: 'Cuarto' }, { id: -1, n: 'Último' }];
  var DIA = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'], DIAC = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  var MES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var num = function (v) { return (+v || 0).toLocaleString('es-CL'); };
  var uniCod = function (id) { var u = (U.cat && U.cat.unidades || []).filter(function (x) { return +x.ID === +id; })[0]; return u ? u.CODIGO : ''; };
  var uniId = function (cod) { var u = (U.cat && U.cat.unidades || []).filter(function (x) { return x.CODIGO === cod; })[0]; return u ? u.ID : 0; };
  var frecId = function (rep) { var u = (U.cat && U.cat.frecuencias || []).filter(function (x) { return x.CODIGO === REPC[rep]; })[0]; return u ? u.ID : 0; };

  function calVacio() {
    var T = K.TODAY;
    return { id: 0, usos: 0, nombre: '', zona: '', planta: '', area: '', activo: '', personas: [], grupo: '', politica: '', anticipada: true, atrasada: true, genera: true, excl: [],
      f: { t: 'cal', rep: 'm', n: 1, days: [K.wday(T)], mmode: 'day', md: +T.slice(8, 10), ord: 1, wd: 1, month: +T.slice(5, 7), hour: '08:00', iu: uniId('MES'), anchor: T, dates: [], from: T, to: '', tb: 0, ta: 0 } };
  }
  function calDesde(r) {
    var d = calVacio(), f = d.f, c = r.calendario, i = r.intervalo;
    d.id = r.id; d.usos = r.usos || 0; d.nombre = r.nombre; d.zona = r.zona || ''; d.planta = r.planta || ''; d.area = r.area || ''; d.activo = r.activo || ''; d.grupo = r.grupo || ''; d.politica = r.politica || '';
    d.anticipada = !!r.anticipada; d.atrasada = !!r.atrasada; d.genera = !!r.genera; d.personas = r.personas || [];
    f.t = TIPOF[r.tipoCodigo]; f.from = r.desde || K.TODAY; f.to = r.hasta || ''; f.tb = Math.round((+r.tolAntes || 0) / 1440); f.ta = Math.round((+r.tolDespues || 0) / 1440);
    if (c) {
      var fc = (U.cat.frecuencias || []).filter(function (x) { return +x.ID === +c.frecuencia; })[0];
      f.rep = REP[fc ? fc.CODIGO : 'MENSUAL'] || 'm'; f.n = +c.intervalo || 1; f.hour = c.hora || '08:00'; f.days = (c.dias || []).map(Number).sort();
      if (c.ordinal != null) { f.mmode = 'ord'; f.ord = +c.ordinal; f.wd = f.days[0] || 1; if (f.rep !== 'w') f.days = []; } else { f.mmode = 'day'; f.md = c.diaMes && c.diaMes > 0 ? +c.diaMes : 31; }
      f.month = +c.mes || f.month;
    }
    if (i) { f.n = +i.cantidad || 1; f.iu = +i.unidad; f.anchor = String(i.ancla || '').slice(0, 10) || K.TODAY; f.hour = String(i.ancla || '').slice(11, 16) || f.hour; }
    f.dates = (r.fechas || []).map(function (x) { return { fecha: x.fecha, hora: x.hora || '' }; });
    /* 429 · por medidor: la regla; sin medidor fijo, cada equipo dispara con el suyo. Por condición: sus reglas, de solo lectura. */
    if (r.medidor) { f.mn = +r.medidor.cada || 0; f.mstart = +r.medidor.inicial || 0; f.mwarn = +r.medidor.aviso || 0; f.mnom = r.medidor.medidorNombre || ''; f.mact = r.medidor.activoNombre || ''; }
    d.conds = r.condiciones || [];
    d.excl = (r.exclusiones || []).map(function (x) { return { a: x.desde, b: x.hasta, why: x.motivo || '', shift: !!x.desplaza }; });
    return d;
  }
  function freqText(f) {
    var n = +f.n || 1, s = '';
    var o = { 1: 'primer', 2: 'segundo', 3: 'tercer', 4: 'cuarto', '-1': 'último' }[f.ord];
    if (f.t === 'cal') {
      if (f.rep === 'd') s = n === 1 ? 'Cada día' : 'Cada ' + n + ' días';
      if (f.rep === 'w') { var ds = f.days.slice().sort().map(function (x) { return DIA[x]; }); s = (n === 1 ? 'Cada semana, ' : 'Cada ' + n + ' semanas, ') + 'el ' + (ds.length > 1 ? ds.slice(0, -1).join(', ') + ' y ' + ds[ds.length - 1] : ds[0] || '—'); }
      if (f.rep === 'm') s = (n === 1 ? 'Cada mes' : 'Cada ' + n + ' meses') + (f.mmode === 'ord' ? ', el ' + o + ' ' + DIA[f.wd] : ', el día ' + f.md);
      if (f.rep === 'y') s = (n === 1 ? 'Cada año' : 'Cada ' + n + ' años') + (f.mmode === 'ord' ? ', el ' + o + ' ' + DIA[f.wd] + ' de ' + MES[f.month - 1] : ', el ' + f.md + ' de ' + MES[f.month - 1]);
      return s + ' a las ' + f.hour;
    }
    if (f.t === 'int') { var u = UNI[uniCod(f.iu)] || ['', '']; return 'Cada ' + n + ' ' + (n === 1 ? u[0] : u[1]) + ' desde el ' + K.fDY(f.anchor); }
    if (f.t === 'med') return 'Cada ' + num(f.mn) + ' del medidor' + (+f.mwarn > 0 ? ' · avisa ' + num(f.mwarn) + ' antes' : '');
    if (f.t === 'cond') return 'Cuando se cumple la condición';
    var fs = f.dates.map(function (x) { return x.fecha; }).sort();
    return fs.length ? 'En ' + pl(fs.length, 'fecha puntual', 'fechas puntuales') : 'Fechas puntuales (sin fechas)';
  }
  /* Las próximas fechas de la regla, calculadas aquí para la vista previa (las exclusiones se marcan). */
  function proximas(f, excl, tope) {
    var out = [], T = K.TODAY, desde = f.from > T ? f.from : T, hasta = f.to || '9999-12-31', guard = 0, n = Math.max(1, +f.n || 1);
    var D = K.D, iso = K.iso, addD = K.addD;
    var dim = function (y, m) { return new Date(y, m + 1, 0).getDate(); };
    var diaDe = function (y, m) {
      if (f.mmode === 'ord') { var last = dim(y, m), c = []; for (var d = 1; d <= last; d++) { var w = new Date(y, m, d).getDay() || 7; if (w === +f.wd) c.push(d); } return +f.ord === -1 ? c[c.length - 1] : c[+f.ord - 1]; }
      return Math.min(+f.md || 1, dim(y, m));
    };
    var push = function (s) { if (s >= desde && s <= hasta && out.indexOf(s) < 0) out.push(s); };
    if (f.t === 'fec') { f.dates.map(function (x) { return x.fecha; }).sort().forEach(push); }
    else if (f.t === 'cal') {
      var a = D(f.from);
      if (f.rep === 'd') { for (var s = f.from; out.length < tope && guard++ < 4000; s = addD(s, n)) push(s); }
      else if (f.rep === 'w') {
        var lun = addD(f.from, -(K.wday(f.from) - 1));
        for (var wk = 0; out.length < tope && guard++ < 600; wk += n) for (var k = 1; k <= 7; k++) { if (f.days.indexOf(k) >= 0) { var x = addD(lun, wk * 7 + k - 1); if (x >= f.from) push(x); } }
        out.sort();
      } else {
        var paso = f.rep === 'y' ? 12 * n : n, y0 = a.getFullYear(), m0 = f.rep === 'y' ? (+f.month || 1) - 1 : a.getMonth();
        for (var j = 0; out.length < tope && guard++ < 600; j += paso) { var y = y0 + Math.floor((m0 + j) / 12), m = (m0 + j) % 12, dd = diaDe(y, m); if (dd) { var z = iso(new Date(y, m, dd, 12)); if (z >= f.from) push(z); } }
      }
    } else if (f.t === 'int') {
      var cod = uniCod(f.iu), cur = D(f.anchor);
      for (var i = 0; out.length < tope && guard++ < 5000; i++) {
        var c2 = new Date(cur.getTime());
        if (cod === 'DIA') c2.setDate(c2.getDate() + i * n); else if (cod === 'SEMANA') c2.setDate(c2.getDate() + i * 7 * n);
        else if (cod === 'MES') c2.setMonth(c2.getMonth() + i * n); else if (cod === 'ANIO') c2.setFullYear(c2.getFullYear() + i * n);
        else if (cod === 'HORA') c2.setHours(c2.getHours() + i * n); else break;
        push(iso(c2));
      }
    }
    return out.slice(0, tope).map(function (s) { var ex = (excl || []).filter(function (x) { return s >= x.a && s <= x.b; })[0]; return { d: s, ex: ex }; });
  }
  function abrirCal(id, duplicar) {
    var st = { t: 'cal', d: calVacio(), ok: false, err: false, err2: '', busy: false, cargando: true, dup: !!duplicar };
    K.Panel.open({ render: PCAL, st: st });
    Promise.all([catalogos(), id ? apiCP('CalendarioDetalle', { id: id }) : null]).then(function (x) {
      var r = x[1];
      if (r) {
        st.d = calDesde(r);
        /* Un calendario por condición no se duplica: sus condiciones viven en la intervención que las mide. */
        if (duplicar && st.d.f.t === 'cond') { K.Panel.close(); K.toast('Un calendario por condición no se puede duplicar: créalo desde la intervención que lo usa.'); return; }
        if (duplicar) { st.d.id = 0; st.d.usos = 0; st.d.nombre = 'Copia de ' + st.d.nombre; }
      } else st.d.f.iu = uniId('MES');
      st.cargando = false; if (K.Panel.state() === st) K.Panel.paint();
    }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  }
  var calUso = function (id) { return (U.cals || []).filter(function (c) { return c.id === id; })[0]; };
  var PCAL = function (st) {
    if (st.cargando) return { t: 'Calendario compartido', s: 'Recursos · Calendarios', w: 'w', b: '<div class="cp-sk" style="height:40px"></div><div class="cp-sk" style="height:260px;margin-top:12px"></div>' };
    var d = st.d, f = d.f, ed = !!U.perm.calEd, e = st.err, c = d.id ? calUso(d.id) : null, usos = c ? c.usos : [], n = usos.length;
    var cuenta = function (o) { return usos.filter(function (u) { return u.origen === o; }).length; };
    var seg = function (k, opts) { return '<div class="cp-segc" role="group">' + opts.map(function (o) { return '<button type="button" data-a="scset" data-k="' + k + '" data-v="' + o[0] + '" aria-pressed="' + (String(f[k]) === String(o[0])) + '"' + (ed ? '' : ' disabled') + '>' + o[1] + '</button>'; }).join('') + '</div>'; };
    var cb = function (k, lista, val, etq) { return K.combo('rcSc_' + k, lista, val, { etiqueta: etq, dis: !ed, data: ' data-pp="f.' + k + '"' }); };
    var dis = ed ? '' : ' disabled', malN = e && !String(d.nombre).trim();
    var regla = '';
    if (f.t === 'cal') {
      regla = '<div class="cp-fld"><span class="cp-lb">Se repite</span>' + seg('rep', [['d', 'Diaria'], ['w', 'Semanal'], ['m', 'Mensual'], ['y', 'Anual']]) + '</div>' +
        '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><div class="cp-unit"><input class="cp-inp" type="number" min="1" data-pv="f.n" value="' + esc(f.n) + '" aria-label="Cada cuánto"' + dis + '><span class="cp-u">' + { d: 'días', w: 'semanas', m: 'meses', y: 'años' }[f.rep] + '</span></div></div><div class="cp-fld"><label>Hora</label>' + cb('hour', HORAS, f.hour, 'Hora') + '</div></div>' +
        (f.rep === 'w' ? '<div class="cp-fld"><span class="cp-lb">Días</span><div class="cp-days">' + [1, 2, 3, 4, 5, 6, 7].map(function (x) { return '<button type="button" data-a="scday" data-v="' + x + '" aria-pressed="' + (f.days.indexOf(x) >= 0) + '" aria-label="' + DIA[x] + '"' + dis + '>' + DIAC[x] + '</button>'; }).join('') + '</div>' + (e && !f.days.length ? mc('', 'Elige al menos un día.') : '') + '</div>' : '') +
        (f.rep === 'm' || f.rep === 'y' ? '<div class="cp-fld"><span class="cp-lb">Qué día</span>' + seg('mmode', [['day', 'Un día fijo'], ['ord', 'Un día de la semana']]) + '</div>' +
          '<div class="cp-grid3c">' + (f.rep === 'y' ? '<div class="cp-fld"><label>Mes</label>' + cb('month', MES.map(function (m, k) { return { id: k + 1, n: cap(m) }; }), f.month, 'Mes') + '</div>' : '') +
          (f.mmode === 'ord' ? '<div class="cp-fld"><label>Semana</label>' + cb('ord', ORD, f.ord, 'Semana') + '</div><div class="cp-fld"><label>Día</label>' + cb('wd', [1, 2, 3, 4, 5, 6, 7].map(function (x) { return { id: x, n: cap(DIA[x]) }; }), f.wd, 'Día') + '</div>'
            : '<div class="cp-fld"><label>Día del mes</label>' + cb('md', DIAS31, f.md, 'Día del mes') + '</div>') + '</div>' : '');
    }
    if (f.t === 'int') {
      var unis = (U.cat.unidades || []).filter(function (u) { return u.CODIGO !== 'MINUTO'; }).map(function (u) { return { id: u.ID, n: (UNI[u.CODIGO] || [u.NOMBRE, u.NOMBRE])[1] }; });
      regla = '<div class="cp-grid3c"><div class="cp-fld"><label>Cada</label><input class="cp-inp" type="number" min="1" data-pv="f.n" value="' + esc(f.n) + '" aria-label="Cada cuánto"' + dis + '></div><div class="cp-fld"><label>Unidad</label>' + cb('iu', unis, f.iu, 'Unidad') + '</div><div class="cp-fld"><label>A partir de</label>' + K.fecha('sc:anchor', f.anchor, { etiqueta: 'A partir de', dis: !ed }) + '</div></div>' +
        '<div class="cp-grid3c"><div class="cp-fld"><label>Hora</label>' + cb('hour', HORAS, f.hour, 'Hora') + '</div></div>';
    }
    if (f.t === 'fec') {
      regla = '<div class="cp-fld"><span class="cp-lb">Fechas</span><div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center">' + f.dates.slice().sort(function (a, b) { return a.fecha.localeCompare(b.fecha); }).map(function (x) { return '<span class="cp-fc" style="cursor:default">' + K.fDY(x.fecha) + (ed ? '<button type="button" class="cp-ibx" style="width:22px;height:22px" data-a="scrmdate" data-v="' + x.fecha + '" aria-label="Quitar ' + K.fDY(x.fecha) + '">' + ic('x', 12) + '</button>' : '') + '</span>'; }).join('') +
        (ed ? '<span style="width:170px">' + K.fecha('sc:fadd', '', { ph: 'Agregar fecha', etiqueta: 'Agregar fecha' }) + '</span>' : '') + '</div>' + (e && !f.dates.length ? mc('', 'Agrega al menos una fecha.') : '') + '</div>' +
        '<div class="cp-grid3c"><div class="cp-fld"><label>Hora</label>' + cb('hour', HORAS, f.hour, 'Hora') + '</div></div>';
    }
    if (f.t === 'med') {
      regla = '<div class="cp-grid3c"><div class="cp-fld"><label>Cada <small>unidades del medidor</small></label><input class="cp-inp' + (e && !(+f.mn > 0) ? ' cp-err' : '') + '" type="number" min="1" data-pv="f.mn" value="' + esc(f.mn || '') + '" aria-label="Cada cuántas unidades del medidor"' + dis + '></div>' +
        '<div class="cp-fld"><label>Desde la lectura</label><input class="cp-inp" type="number" min="0" data-pv="f.mstart" value="' + esc(f.mstart || 0) + '" aria-label="Lectura de partida"' + dis + '></div>' +
        '<div class="cp-fld"><label>Avisar antes <small>opcional</small></label><input class="cp-inp" type="number" min="0" data-pv="f.mwarn" value="' + esc(f.mwarn || 0) + '" aria-label="Avisar antes"' + dis + '></div></div>' +
        (e && !(+f.mn > 0) ? mc('', 'Indica cada cuántas unidades del medidor.') : '') +
        mc('i', f.mnom ? 'Usa el medidor «' + esc(f.mnom) + '»' + (f.mact ? ' de ' + esc(f.mact) : '') + '.' : 'Sin medidor fijo: cada equipo que lo usa dispara con su propio medidor (por ejemplo, su horómetro).', 'help');
    }
    if (f.t === 'cond') {
      regla = '<div class="cp-fld"><span class="cp-lb">Condiciones</span>' + ((d.conds || []).map(function (x) { return '<div class="cp-d">' + ic('alert', 14) + '<span>' + esc(x.texto) + (x.activo ? ' <small>· ' + esc(x.activo) + '</small>' : '') + (x.severidad ? ' <span class="cp-tg">' + esc(x.severidad) + '</span>' : '') + '</span></div>'; }).join('') || '<span style="font-size:12.5px;color:var(--muted)">Sin condiciones.</span>') + '</div>' +
        mc('i', 'Las condiciones se agregan o quitan en la intervención que las mide (Planificación › Frecuencia). Aquí se editan el nombre y la tolerancia.', 'help');
    }
    var ds = f.t === 'med' || f.t === 'cond' ? [] : proximas(f, d.excl, 6);
    var b = (n ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span>Lo usan <b>' + pl(cuenta('Plan'), 'plan', 'planes') + ', ' + pl(cuenta('Tarea'), 'tarea', 'tareas') + ' y ' + pl(n - cuenta('Plan') - cuenta('Tarea'), 'inspección', 'inspecciones') + '</b>. Un cambio aquí cambia las fechas de todos, sin versión nueva.</span></div>' : '') +
      '<div class="cp-fq-ed"><div class="cp-fq-f">' +
      '<div class="cp-fld"><label>Nombre</label><input class="cp-inp' + (malN ? ' cp-err' : '') + '" data-pv="c.nombre" value="' + esc(d.nombre) + '" data-autofocus="1" maxlength="400" placeholder="Ej.: Inspección semanal de bombas" autocomplete="off"' + dis + '>' + (malN ? mc('', 'Falta el nombre.') : '') + '</div>' +
      (d.id ? '' : '<div class="cp-fld"><span class="cp-lb">Tipo</span>' + seg('t', [['cal', 'Calendario'], ['int', 'Intervalo'], ['fec', 'Fechas puntuales'], ['med', 'Por medidor']]) + '</div>') +
      regla +
      '<div class="cp-grid2c"><div class="cp-fld"><label>Puede hacerse antes</label><div class="cp-unit"><input class="cp-inp" type="number" min="0" data-pv="f.tb" value="' + esc(f.tb) + '"' + dis + '><span class="cp-u">días</span></div></div><div class="cp-fld"><label>Vence después de</label><div class="cp-unit"><input class="cp-inp" type="number" min="0" data-pv="f.ta" value="' + esc(f.ta) + '"' + dis + '><span class="cp-u">días</span></div></div></div></div>' +
      '<div class="cp-pv"><h5>Próximas fechas</h5><div class="cp-nl">' + esc(freqText(f)) + '</div>' +
      (f.t === 'med' || f.t === 'cond' ? '<div class="cp-d">' + ic('gauge', 14) + '<span>' + (f.t === 'med' ? 'Se dispara al llegar a cada ' + num(f.mn) + ' del medidor de cada equipo' : 'Se dispara cuando se cumple la condición') + '</span></div>' : '') +
      (f.t === 'med' || f.t === 'cond' ? '' : ds.map(function (x) { return x.ex ? '<div class="cp-d cp-x">' + ic('x', 14) + '<span><s>' + cap(K.fDL(x.d)) + '</s><small>' + esc(x.ex.why || 'Exclusión') + (x.ex.shift ? ' · se corre' : ' · se omite') + '</small></span></div>' : '<div class="cp-d">' + ic('check', 14) + '<span>' + cap(K.fDL(x.d)) + '</span></div>'; }).join('') || '<div class="cp-d cp-x"><span></span><span>Sin fechas</span></div>') +
      (d.excl.length ? '<div class="cp-ft">' + pl(d.excl.length, 'exclusión', 'exclusiones') + ' · se editan en Programaciones</div>' : '') + '</div></div>' +
      (n && ed ? '<label class="cp-cfm"><input type="checkbox" class="cp-cbx" data-pv="c.ok"' + (st.ok ? ' checked' : '') + '><span>Entiendo que el cambio aplica a los <b>' + n + ' usos</b> de este calendario.</span></label>' : '') + (st.err2 ? mc('', esc(st.err2)) : '');
    var f2 = ed ? '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="scok"' + (n && !st.ok ? ' disabled' : '') + '>' + ic('check', 16) + (d.id ? 'Guardar calendario' : 'Crear calendario') + '</button></span>'
      : '<span class="cp-r"><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cerrar</button></span>';
    return { t: d.id ? esc(d.nombre || 'Calendario') : st.dup ? 'Duplicar calendario' : 'Nuevo calendario compartido', s: (d.id ? 'Calendario compartido' : 'Recursos · Calendarios'), w: 'w', b: b, f: f2 };
  };
  function calError(d) {
    var f = d.f;
    if (!String(d.nombre).trim()) return 'Falta el nombre.';
    if (f.t === 'cal' && f.rep === 'w' && !f.days.length) return 'Elige al menos un día de la semana.';
    if ((f.t === 'cal' || f.t === 'int') && !(+f.n >= 1)) return 'Indica cada cuánto (1 o más).';
    if (f.t === 'fec' && !f.dates.length) return 'Agrega al menos una fecha.';
    if (f.t === 'med' && !(+f.mn > 0)) return 'Indica cada cuántas unidades del medidor.';
    return '';
  }
  function calDatos(d) {
    var f = d.f, x = { id: d.id || 0, nombre: String(d.nombre).trim(), tipo: TIPOC[f.t], desde: f.from || K.TODAY, hasta: f.to || '', tolAntes: (+f.tb || 0) * 1440, tolDespues: (+f.ta || 0) * 1440,
      exclusiones: d.excl.map(function (z) { return { desde: z.a, hasta: z.b, motivo: z.why, desplaza: !!z.shift }; }),
      zona: +d.zona || 0, planta: +d.planta || 0, area: +d.area || 0, activo: +d.activo || 0,
      /* Un calendario compartido no tiene responsables: quién ejecuta se define en el plan, la inspección o la tarea que lo usa. */
      modo: 'nadie', personas: [], grupo: 0, politica: +d.politica || 0, anticipada: !!d.anticipada, atrasada: !!d.atrasada, genera: !!d.genera };
    if (f.t === 'cal') {
      var c = { frecuencia: frecId(f.rep), intervalo: Math.max(1, +f.n || 1), hora: f.hour || '08:00', dias: [] };
      if (f.rep === 'w') c.dias = f.days.slice();
      if (f.rep === 'm' || f.rep === 'y') { if (f.mmode === 'ord') { c.ordinal = +f.ord; c.dias = [+f.wd]; } else c.diaMes = +f.md; }
      if (f.rep === 'y') c.mes = +f.month;
      x.calendario = c;
    }
    if (f.t === 'int') x.intervalo = { cantidad: Math.max(1, +f.n || 1), unidad: +f.iu, ancla: (f.anchor || K.TODAY) + 'T' + (f.hour || '08:00') };
    if (f.t === 'fec') x.fechas = f.dates.map(function (z) { return { fecha: z.fecha, hora: z.hora || f.hour || '' }; });
    if (f.t === 'med') x.medidor = { cada: +f.mn, inicial: +f.mstart || 0, aviso: +f.mwarn || 0 };
    return x;
  }

  /* ============================================================ AJUSTES */
  VISTA.ajustes = function () {
    if (U.error) return errorBox(U.error, 'rcreload');
    if (!U.d) return '<div class="cp-ajg">' + [1, 2, 3].map(function () { return '<div class="cp-sk" style="height:220px"></div>'; }).join('') + '</div>';
    var aj = U.d.ajustes, P = U.perm;
    var card = function (k, t, s, items, puede, nota) {
      return '<section class="cp-card cp-aj"><div class="cp-sc-h"><h3>' + t + '</h3><small>' + s + '</small></div><ul class="cp-ajl">' + (items.map(function (x) {
        var n = +x.USOS || 0, bloq = n > 0 || x.SISTEMA;
        return '<li>' + (x.COLOR ? '<i style="background:' + esc(x.COLOR) + '"></i>' : '') + '<span>' + esc(x.NOMBRE) + (x.SISTEMA ? ' <span class="cp-tg cp-p">Sistema</span>' : '') + '</span><small>' + (n ? pl(n, 'uso', 'usos') : 'sin uso') + '</small>' +
          (puede ? '<button type="button" class="cp-ibx cp-sm" data-a="ajrm" data-k="' + k + '" data-id="' + x.ID + '" data-n="' + esc(x.NOMBRE) + '"' + (bloq ? ' disabled title="' + (x.SISTEMA ? 'Es un tipo base de SIGMA: no se quita' : 'En uso: no se puede quitar') + '"' : '') + ' aria-label="Quitar ' + esc(x.NOMBRE) + '">' + ic('x', 14) + '</button>' : '') + '</li>';
      }).join('') || '<li><span class="cp-muted2">Vacío</span></li>') + '</ul>' +
        (puede ? '<div class="cp-ajf"><input class="cp-inp" id="rcAj' + k + '" data-pv="aj.' + k + '" placeholder="Agregar…" aria-label="Agregar a ' + t + '" maxlength="100" autocomplete="off"><button type="button" class="cp-btn cp-out cp-sm" data-a="ajadd" data-k="' + k + '">' + ic('plus', 14) + 'Agregar</button></div>' : '') +
        (nota ? '<p style="margin:8px 0 0;font-size:11.5px;color:var(--muted)">' + nota + '</p>' : '') + '</section>';
    };
    return '<div class="cp-ajg">' + card('CAT', 'Categorías de tarea', 'Agrupan las tareas recurrentes', aj.cat || [], P.catEd) +
      card('TIPO', 'Tipos de OT', 'Se eligen al crear una OT', aj.tipo || [], P.tipoEd, 'Los tipos de OT son comunes a todas las empresas.') +
      card('MOT', 'Motivos de descarte', 'Atajos al descartar un aviso', aj.mot || [], P.motEd) + jornadaCard(aj.jornada || [], P.tipoEd) + '</div>';
  };

  /* 415 · Jornada de trabajo por planta: la ventana donde se sugieren horas libres al resolver choques de horario. */
  function jornadaCard(pls, puede) {
    var horas = [{ id: '', n: 'Sin definir' }].concat(HORAS);
    return '<section class="cp-card cp-aj"><div class="cp-sc-h"><h3>Jornada de trabajo</h3><small>Al resolver un choque de horario, SIGMA sugiere horas libres dentro de esta jornada</small></div><ul class="cp-ajl">' +
      (pls.map(function (x) {
        return '<li style="flex-wrap:wrap"><span>' + esc(x.NOMBRE) + '</span>' +
          (puede ? '<span style="display:flex;gap:6px;align-items:center;flex:none"><span style="width:128px">' + K.combo('rcJi' + x.ID, horas, x.INICIO || '', { etiqueta: 'Inicio de la jornada de ' + x.NOMBRE, ph: '06:00', data: ' data-jor="' + x.ID + ':i"' }) + '</span><small>a</small><span style="width:128px">' + K.combo('rcJf' + x.ID, horas, x.FIN || '', { etiqueta: 'Término de la jornada de ' + x.NOMBRE, ph: '22:00', data: ' data-jor="' + x.ID + ':f"' }) + '</span></span>'
            : '<small>' + (x.INICIO || '06:00') + '–' + (x.FIN || '22:00') + '</small>') + '</li>';
      }).join('') || '<li><span class="cp-muted2">Sin plantas</span></li>') + '</ul><p style="margin:8px 0 0;font-size:11.5px;color:var(--muted)">Sin definir: de 06:00 a 22:00.</p></section>';
  }
  function guardarJornada(planta) {
    var x = (U.d.ajustes.jornada || []).filter(function (j) { return +j.ID === +planta; })[0]; if (!x) return;
    api('Jornada', { planta: +planta, inicio: x.INICIO || '', fin: x.FIN || '' }).then(function (r) { U.d.ajustes = r.ajustes; pintar(); K.toast('Jornada de ' + x.NOMBRE + ': ' + (x.INICIO || '06:00') + '–' + (x.FIN || '22:00') + '.'); }).catch(function (e) { K.toastError(e); cargar(); });
  }

  /* ============================================================ acciones */
  var A = L.A;
  var st = function () { return K.Panel.state(); };
  function ocupado(s, p) {
    s.busy = true; K.Panel.paint();
    return p.then(function (r) { s.busy = false; return r; }, function (e) { s.busy = false; s.err2 = e.message; K.Panel.paint(); throw e; });
  }
  A.rcreload = function () { U.d = null; pintar(); cargar(); };
  A.calreload = function () { U.cals = null; pintar(); cargarCals(); };
  A.rcqclr = function () { U.q = ''; U.tipo = ''; pintar(); };
  /* procedimientos */
  A.prnew = function () { abrirProc(0); };
  A.propen = function (d) { abrirProc(+d.id); };
  A.prcopy = function (d, el, ev) {
    if (ev) ev.stopPropagation();
    var s = st(), p = api('CopiarProcedimiento', { id: +d.id });
    (s && s.t === 'proc' ? ocupado(s, p) : p).then(function (r) { K.Panel.close(); K.toastA(r.codigo + ' creado como copia. Ya puedes usarlo en actividades.', 'Abrir', function () { abrirProc(r.id); }); cargar(); }).catch(function (e) { if (!s) K.toastError(e); });
  };
  A.stadd = function () { st().d.pasos.push(paso()); K.Panel.paint(); var l = $$('#cpLayer .cp-stp .cp-b > .cp-inp:first-child'); if (l.length) l[l.length - 1].focus(); };
  A.strm = function (d) { st().d.pasos.splice(+d.v, 1); K.Panel.paint(); };
  A.stmv = function (d) { var p = st().d.pasos, k = +d.v, j = k + (+d.d); if (j < 0 || j >= p.length) return; var x = p[k]; p[k] = p[j]; p[j] = x; K.Panel.paint(); };
  A.prsave = function () {
    var s = st(), x = s.d;
    if (!String(x.nombre).trim() || x.pasos.some(function (p) { return !String(p.nombre).trim() || (p.med && (!p.variable || (/^nuevo:/.test(String(p.variable)) && !p.unidad))); })) { s.err = true; s.err2 = ''; K.Panel.paint(); return; }
    var dur = parseFloat(String(x.dur).replace(',', '.'));
    ocupado(s, api('GuardarProcedimiento', { datos: JSON.stringify({ id: x.id, nombre: String(x.nombre).trim(), tipo: +x.tipo || 0, permiso: +x.permiso || 0, descripcion: x.descripcion || '', duracion: dur > 0 ? Math.round(dur * 60) : 0,
      pasos: x.pasos.map(function (p) { return { id: p.id || 0, nombre: String(p.nombre).trim(), instruccion: p.instruccion, ctrl: !!p.ctrl, ev: !!p.ev, med: !!p.med, variable: /^nuevo:/.test(String(p.variable)) ? String(p.variable) : (+p.variable || 0), unidad: +p.unidad || 0, duracion: +p.dur || 0 }; }) }) }))
      .then(function () { var nv = x.pasos.some(function (p) { return /^nuevo:/.test(String(p.variable)); }); if (nv) U.cat = null; K.Panel.close(); K.toast('Procedimiento ' + (x.id ? 'guardado' : 'creado') + '.' + (nv ? ' La variable nueva quedó en el catálogo de la empresa.' : '')); cargar(); }).catch(function () { });
  };
  /* pautas */
  A.paunew = function () { abrirPauta(0); };
  A.pauopen = function (d) { abrirPauta(+d.id); };
  A.paurm = function (d) {
    var s = st(), it = s.d.secs[+d.s].items[+d.v], nd = s.d.deps.length;
    s.d.secs[+d.s].items.splice(+d.v, 1); s.d.deps = s.d.deps.filter(function (x) { return x.item !== it.k && x.cond !== it.k; });
    if (s.edit && s.edit.s === +d.s && s.edit.i === +d.v) { s.edit = null; s.add = paAdd(); }
    s.dirty = true; K.Panel.paint(); if (nd > s.d.deps.length) K.toast('Se quitaron también ' + pl(nd - s.d.deps.length, 'dependencia', 'dependencias') + ' de «' + it.n + '».');
  };
  /* 417 · editar un ítem existente: el formulario de abajo se llena con él; el tipo de respuesta no cambia. */
  A.pauedit = function (d) {
    var s = st(), it = s.d.secs[+d.s].items[+d.v]; if (!it) return;
    s.edit = { s: +d.s, i: +d.v }; s.nsec = false;
    s.add = { n: it.n, t: it.t, s: +d.s, min: it.min, max: it.max, u: it.unidad ? String(it.unidad) : '', crit: !!it.crit, err: false };
    K.Panel.paint(); var f = $('#rcPaForm'); if (f) f.scrollIntoView({ block: 'nearest' }); var el = $('#rcPai'); if (el) el.focus();
  };
  A.paucan = function () { var s = st(); s.edit = null; s.add = paAdd(); K.Panel.paint(); };
  /* 417 · dependencias */
  A.paudadd = function () {
    var s = st(), x = s.dep, c = itemDe(s, x.cond);
    x.err = !x.item ? 'Elige el ítem que depende.' : !x.cond ? 'Elige el ítem del que depende.' : x.item === x.cond ? 'Un ítem no puede depender de sí mismo.' : c && c.t !== 'ok' && !String(x.valor).trim() ? 'Escribe el valor con que se compara.' : '';
    if (!x.err && s.d.deps.some(function (z) { return z.item === x.cond && z.cond === x.item; })) x.err = '«' + c.n + '» ya depende de ese ítem: se formaría un ciclo.';
    if (x.err) { K.Panel.paint(); return; }
    s.d.deps.push({ item: x.item, cond: x.cond, accion: +x.accion || 1, op: c.t === 'ok' ? 1 : +x.op || 1, valor: c.t === 'ok' ? '' : String(x.valor).trim(), opcion: c.t === 'ok' ? x.opcion : '' });
    s.dep = depNueva(); s.dirty = true; K.Panel.paint();
  };
  A.paudrm = function (d) { var s = st(); s.d.deps.splice(+d.v, 1); s.dirty = true; K.Panel.paint(); };
  A.pausec = function () {
    var s = st(), n = String(s.secN || '').trim(); if (!n) { var el = $('#rcPns'); if (el) el.focus(); return; }
    s.d.secs.push({ codigo: '', n: n, items: [] }); s.add.s = s.d.secs.length - 1; s.nsec = false; s.secN = ''; K.Panel.paint();
  };
  A.pauadd = function () {
    var s = st(), a = s.add;
    if (!String(a.n).trim()) { a.err = true; K.Panel.paint(); var el = $('#rcPai'); if (el) el.focus(); return; }
    var med = (U.cat.medidas || []).filter(function (m) { return String(m.ID) === String(a.u); })[0];
    if (s.edit) {
      var it = s.d.secs[s.edit.s].items[s.edit.i];
      it.n = String(a.n).trim(); it.min = a.t === 'num' ? a.min : ''; it.max = a.t === 'num' ? a.max : ''; it.unidad = a.t === 'num' ? +a.u || 0 : 0; it.u = med ? med.SIMBOLO : ''; it.crit = !!a.crit; it.mod = true;
      if (+a.s !== s.edit.s) { s.d.secs[s.edit.s].items.splice(s.edit.i, 1); s.d.secs[+a.s].items.push(it); }
      s.edit = null; s.add = paAdd(); s.dirty = true; K.Panel.paint(); K.toast('Ítem actualizado. Se publica con la versión nueva.'); return;
    }
    s.d.secs[+a.s].items.push({ k: 'n' + (++PA_SEQ), codigo: '', n: String(a.n).trim(), t: a.t, min: a.t === 'num' ? a.min : '', max: a.t === 'num' ? a.max : '', unidad: a.t === 'num' ? +a.u || 0 : 0, u: med ? med.SIMBOLO : '', crit: !!a.crit });
    s.add = paAdd(a.s, a.t); s.dirty = true; K.Panel.paint(); var el2 = $('#rcPai'); if (el2) el2.focus();
  };
  A.pausave = function (d, el) {
    if (el.getAttribute('aria-disabled') === 'true') return;
    var s = st(), x = s.d;
    if (!s.id && !String(x.n).trim()) { s.err = true; K.Panel.paint(); return; }
    if (!x.secs.some(function (z) { return z.items.length; })) { s.err2 = 'Agrega al menos un ítem antes de ' + (s.id ? 'publicar' : 'crear la pauta') + '.'; K.Panel.paint(); return; }
    ocupado(s, api('GuardarPauta', { datos: JSON.stringify({ id: s.id, nombre: String(x.n).trim(),
      secciones: x.secs.filter(function (z) { return z.items.length || z.codigo; }).map(function (z) { return { codigo: z.codigo, nombre: z.n, items: z.items.map(function (i) { return { k: i.k || '', codigo: i.codigo || '', mod: !!i.mod, tipoId: i.tipoId || 0, texto: i.n, tipo: i.t, min: i.min, max: i.max, unidad: i.unidad || 0, crit: !!i.crit }; }) }; }),
      dependencias: x.deps.map(function (z) { return { item: z.item, cond: z.cond, accion: z.accion, op: z.op, valor: z.valor, opcion: z.opcion }; }) }) }))
      .then(function (r) { K.Panel.close(); K.toast(s.id ? r.codigo + ' v' + r.version + ' publicada. Rige desde la próxima inspección.' : r.codigo + ' creada. Ya puedes usarla en una inspección.'); cargar(); }).catch(function () { });
  };
  /* calendarios */
  A.calnew = function () { abrirCal(0); };
  A.calopen = function (d) { abrirCal(+d.id); };
  A.caldup = function (d) { abrirCal(+d.id, true); };
  A.scset = function (d) {
    var s = st(), f = s.d.f;
    if (d.k === 't') { f.t = d.v; if (d.v === 'int' && !f.iu) f.iu = uniId('MES'); }
    else if (d.k === 'rep' || d.k === 'mmode') { f[d.k] = d.v; if (d.v === 'w' && !f.days.length) f.days = [K.wday(K.TODAY)]; }
    K.Panel.paint();
  };
  A.scday = function (d) { var f = st().d.f, x = +d.v, i = f.days.indexOf(x); if (i >= 0) f.days.splice(i, 1); else f.days.push(x); f.days.sort(); K.Panel.paint(); };
  A.scrmdate = function (d) { var f = st().d.f; f.dates = f.dates.filter(function (x) { return x.fecha !== d.v; }); K.Panel.paint(); };
  A.scok = function (d, el) {
    if (el.disabled) return;
    var s = st(), m = calError(s.d);
    if (m) { s.err = true; s.err2 = m; K.Panel.paint(); return; }
    ocupado(s, apiCP('CrearCalendario', { datos: JSON.stringify(calDatos(s.d)) })).then(function () {
      K.Panel.close(); K.toast(s.d.id ? 'Calendario guardado. Las fechas cambian para todos los que lo usan.' : 'Calendario creado. Ya se puede usar desde cualquier plan, inspección o tarea.'); cargarCals();
    }).catch(function () { });
  };
  /* ajustes */
  var AJN = { CAT: 'categoría', TIPO: 'tipo de OT', MOT: 'motivo' };
  function ajuste(k, accion, id, nombre) {
    return api('Ajuste', { tipo: k, accion: accion, id: id || 0, nombre: nombre || '' }).then(function (r) { U.d.ajustes = r.ajustes; pintar(); return r; });
  }
  A.ajadd = function (d) {
    var el = $('#rcAj' + d.k), v = el ? el.value.trim() : '';
    if (v.length < 3) { K.toastError('Escribe un nombre de al menos 3 letras.'); if (el) el.focus(); return; }
    ajuste(d.k, 'ADD', 0, v).then(function () { K.toast('«' + v + '» agregado.'); var e2 = $('#rcAj' + d.k); if (e2) e2.focus(); }).catch(K.toastError);
  };
  A.ajrm = function (d) {
    ajuste(d.k, 'DEL', +d.id).then(function () { K.toast('«' + d.n + '» quitado.', function () { ajuste(d.k, 'ADD', 0, d.n).catch(K.toastError); }); }).catch(K.toastError);
  };

  /* campos, combos y fechas */
  function setPath(s, path, v) {
    var m;
    if ((m = /^s:(\d+)\.(\w+)$/.exec(path))) { var p = s.d.pasos[+m[1]]; if (!p) return false; p[m[2]] = v; return m[2] === 'med' || m[2] === 'variable' || (m[2] === 'unidad' && s.err); }
    if ((m = /^p\.(\w+)$/.exec(path))) { s.d[m[1]] = v; return false; }
    if ((m = /^pa\.add\.(\w+)$/.exec(path))) { s.add[m[1]] = v; if (m[1] === 'n' && s.add.err && String(v).trim()) { s.add.err = false; return true; } return m[1] === 'crit' ? false : false; }
    if (path === 'pa.n') { s.d.n = v; s.dirty = true; return false; }
    if (path === 'pa.secN') { s.secN = v; return false; }
    if (path === 'pa.dep.valor') { s.dep.valor = v; if (s.dep.err && String(v).trim()) { s.dep.err = ''; return true; } return false; }
    if ((m = /^f\.(\w+)$/.exec(path))) { var k = m[1]; s.d.f[k] = k === 'hour' ? v : (v === '' ? '' : +v); return true; }
    if (path === 'c.nombre') { s.d.nombre = v; return false; }
    if (path === 'c.ok') { s.ok = !!v; return true; }
    return false;
  }
  L.on({
    pv: function (k, v, el) {
      if (k === 'q') { U.q = v; pintar(); return; }
      if (/^aj\./.test(k)) return;
      var s = st(); if (!s) return;
      if (setPath(s, k, v)) K.Panel.paint();
    },
    combo: function (span, v) {
      var n = span.getAttribute('data-cb');
      if (n === 'rcTipo') { U.tipo = v; pintar(); return; }
      if (span.hasAttribute('data-jor')) { var jp = span.getAttribute('data-jor').split(':'), jx = (U.d.ajustes.jornada || []).filter(function (j) { return +j.ID === +jp[0]; })[0]; if (jx) { jx[jp[1] === 'i' ? 'INICIO' : 'FIN'] = v; guardarJornada(jp[0]); } return; }
      var s = st(); if (!s) return;
      if (n === 'rcPaT') { s.add.t = v || 'ok'; K.Panel.paint(); return; }
      if (n === 'rcPaS') { if (v === 'nueva') { s.nsec = true; K.Panel.paint(); setTimeout(function () { var e = $('#rcPns'); if (e) e.focus(); }, 30); } else { s.add.s = +v || 0; s.nsec = false; } return; }
      if (n === 'rcPaU') { s.add.u = v; return; }
      if (/^rcD[aicov]$/.test(n)) { var dk = { rcDa: 'accion', rcDi: 'item', rcDc: 'cond', rcDo: 'op', rcDv: 'opcion' }[n]; s.dep[dk] = v; s.dep.err = ''; K.Panel.paint(); return; }
      var path = span.getAttribute('data-pp'); if (path && setPath(s, path, v)) K.Panel.paint();
    },
    fecha: function (el) {
      var s = st(); if (!s || s.t !== 'cal') return;
      var b = el.getAttribute('data-fe'), v = K.deDN(el.value);
      if (b === 'sc:anchor' && v) { s.d.f.anchor = v; K.Panel.paint(); }
      if (b === 'sc:fadd' && v && !s.d.f.dates.some(function (x) { return x.fecha === v; })) { s.d.f.dates.push({ fecha: v, hora: s.d.f.hour }); K.Panel.paint(); }
    },
    key: function (e) {
      if (e.key === 'Enter' && e.target.id && /^rcAj/.test(e.target.id)) { e.preventDefault(); A.ajadd({ k: e.target.id.slice(4) }); }
      if (e.key === 'Enter' && e.target.id === 'rcPai') { e.preventDefault(); A.pauadd(); }
    }
  });

  /* ------------------------------------------------------------ registro de las pestañas */
  var cargado = null, calsCargados = false;
  function montar(k) {
    return function (body) {
      cur = k; body.innerHTML = '<div id="rcRoot"></div>'; pintar();
      if (!cargado) cargado = cargar();
      if (k === 'calendarios' && !calsCargados) { calsCargados = true; cargarCals(); }
      var m = /[#&]abrir=(\d+)/.exec(location.hash); if (m) { try { history.replaceState(null, '', '#' + k); } catch (e) { } (k === 'calendarios' ? abrirCal : k === 'pautas' ? abrirPauta : abrirProc)(+m[1]); }
      if (/[#&]nuevo=1/.test(location.hash)) { try { history.replaceState(null, '', '#' + k); } catch (e) { } (k === 'calendarios' ? abrirCal : k === 'pautas' ? abrirPauta : abrirProc)(0); }
    };
  }
  ['procedimientos', 'pautas', 'calendarios', 'ajustes'].forEach(function (k) { L.tab(k, { mount: montar(k) }); });
  /* Los contadores de las pestañas desde el primer pintado. */
  cargarCals().then(function () { calsCargados = true; });
})();
