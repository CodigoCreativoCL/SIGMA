/* =====================================================================
   AVISOS · la bandeja única de lo detectado que todavía no es trabajo (parte b)
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (Avisos)
   Datos: WsAvisos.asmx (VW_AVISOS, BD/397). Un aviso se identifica por (origen, ref).
   Estados: NUEVO (sin tratar) · OT (ya tiene OT) · DESCARTADO · RESUELTO.
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG;
  var esc = K.esc, ic = K.ic, pl = K.pl, nrm = K.nrm, $ = K.$;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };

  var ORG = { 7: ['Falla', 'alert'], 4: ['Hallazgo de inspección', 'clip'], 9: ['Hallazgo en OT', 'wrench'], 5: ['SIGMA AI', 'spark'], 6: ['Alerta de medidor', 'gauge'] };
  var ORG_ORDEN = [7, 4, 9, 5, 6];
  var SEV = { 1: 'Baja', 2: 'Media', 3: 'Alta', 4: 'Crítica' };
  var POST = { 1: 'Operativo', 2: 'Operativo con restricción', 3: 'Detenido' };
  var AVF = [['new', 'NUEVO', 'Sin tratar'], ['ot', 'OT', 'Con OT'], ['desc', 'DESCARTADO', 'Descartados'], ['all', '', 'Todos']];

  var U = { f: 'new', o: 0, q: '', lista: null, motivos: [], perm: {}, error: '' };
  var key = function (a) { return a.ORIGEN + '-' + a.REF; };
  var find = function (o, r) { return (U.lista || []).filter(function (a) { return String(a.ORIGEN) === String(o) && String(a.REF) === String(r); })[0]; };
  var cap = function (s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; };
  var otTxt = function (n) { return 'OT-' + n; };
  var otEst = function (e) { return ({ 1: 'por iniciar', 2: 'en ejecución', 3: 'en espera de cierre', 4: 'cerrada' })[e] || ''; };

  /* ------------------------------------------------------------ lista */
  function filtrada() {
    var q = nrm(U.q), est = (AVF.filter(function (x) { return x[0] === U.f; })[0] || [])[1];
    return (U.lista || []).filter(function (a) {
      if (est && a.ESTADO !== est) return false;
      if (U.o && +a.ORIGEN !== +U.o) return false;
      return !q || nrm([a.AVISO, a.TITULO, a.ACTIVO_CODIGO, a.ACTIVO, a.COMPONENTE, a.QUIEN].join(' ')).indexOf(q) >= 0;
    }).sort(function (a, b) {
      return ((a.ESTADO === 'NUEVO') === (b.ESTADO === 'NUEVO') ? 0 : a.ESTADO === 'NUEVO' ? -1 : 1) || (b.SEVERIDAD - a.SEVERIDAD) || String(b.FECHA).localeCompare(String(a.FECHA));
    });
  }
  function orgChip(o) {
    var x = ORG[o] || ['Aviso', 'alert'];
    return '<span class="cp-og' + (+o === 5 ? ' cp-ai' : '') + '">' + ic(x[1], 13) + x[0] + '</span>';
  }
  var sevChip = function (s) { return '<span class="cp-sv cp-s' + s + '">' + (SEV[s] || '') + '</span>'; };
  function origenTxt(a) {
    if (+a.ORIGEN === 4) return 'Inspección · ' + esc(a.QUIEN);
    if (+a.ORIGEN === 9) return a.OT_ORIGEN_NUMERO ? 'Al ejecutar la ' + otTxt(a.OT_ORIGEN_NUMERO) : 'Al ejecutar una OT';
    if (+a.ORIGEN === 5) return 'SIGMA AI' + (a.CONFIANZA ? ' · confianza ' + a.CONFIANZA + ' %' : '');
    return esc(a.QUIEN);
  }
  function cuando(a) { var d = K.dIso(a.FECHA); return cap(K.rel(d)) + ' a las ' + K.hIso(a.FECHA); }
  function otBtn(a) {
    return '<a class="cp-btn cp-out cp-sm" href="' + esc(a.OT_URL || '#') + '">' + otTxt(a.OT_NUMERO) + (a.OT_ESTADO ? ' · ' + otEst(a.OT_ESTADO) : '') + '</a>';
  }
  function fila(a) {
    var nuevo = a.ESTADO === 'NUEVO', pm = U.perm;
    var acc = nuevo
      ? (pm.generar ? '<button type="button" class="cp-btn cp-sec cp-sm" data-a="avgen" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '">' + ic('plus', 15) + 'Generar OT</button><button type="button" class="cp-btn cp-out cp-sm" data-a="avlink" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '">' + ic('link', 15) + 'Vincular</button><button type="button" class="cp-btn cp-plain cp-sm" data-a="avopen" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '" data-dsc="1">Descartar</button>' : '')
      : a.ESTADO === 'OT' ? '<span class="cp-av-res">' + ic('check', 14) + 'En la</span>' + otBtn(a)
      : a.ESTADO === 'DESCARTADO' ? '<span class="cp-av-res cp-mut">' + ic('x', 14) + 'Descartado</span><small class="cp-av-mot" title="' + esc(a.MOTIVO) + '">' + esc(a.MOTIVO) + '</small>'
      : '<span class="cp-av-res cp-mut">' + ic('check', 14) + 'Resuelto</span>';
    return '<div class="cp-avr cp-s' + a.SEVERIDAD + (nuevo ? '' : ' cp-done') + '" data-a="avopen" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '" role="button" tabindex="0" aria-label="Abrir ' + esc(a.TITULO) + '"><span class="cp-av-bar"></span>' +
      '<div class="cp-av-m"><div class="cp-av-top">' + orgChip(a.ORIGEN) + sevChip(a.SEVERIDAD) + (+a.ORIGEN === 5 && a.CONFIANZA ? '<span class="cp-conf">' + a.CONFIANZA + ' % de confianza</span>' : '') + (a.DETUVO ? '<span class="cp-tg cp-w">Detuvo producción</span>' : '') + '<span class="cp-av-id">' + esc(a.AVISO) + '</span></div>' +
      '<b class="cp-av-t">' + esc(a.TITULO) + '</b>' +
      '<span class="cp-av-p">' + ic('cog', 13) + '<span>' + esc(a.ACTIVO) + ' <small>' + esc(a.ACTIVO_CODIGO) + (a.COMPONENTE ? ' › ' + esc(a.COMPONENTE) : '') + (a.AREA ? ' · ' + esc(a.AREA) : '') + '</small></span></span>' +
      '<span class="cp-av-w">' + cuando(a) + ' · ' + origenTxt(a) + '</span></div>' +
      '<div class="cp-av-r">' + acc + '</div></div>';
  }
  function cuerpo() {
    if (U.error) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudieron cargar los avisos</b>' + esc(U.error) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="avreload">Reintentar</button></div>';
    if (!U.lista) return '<div style="padding:10px;display:flex;flex-direction:column;gap:10px">' + [1, 2, 3, 4].map(function () { return '<div class="cp-sk" style="height:86px"></div>'; }).join('') + '</div>';
    var base = U.lista, lista = filtrada();
    var n = function (est) { return base.filter(function (a) { return !est || a.ESTADO === est; }).length; };
    var porOrigen = ORG_ORDEN.filter(function (o) { return base.some(function (a) { return +a.ORIGEN === o && a.ESTADO === 'NUEVO'; }); });
    var chips = AVF.map(function (x) { return '<button type="button" class="cp-fc" data-a="avf" data-v="' + x[0] + '" aria-pressed="' + (U.f === x[0]) + '">' + (x[0] === 'new' ? '<i style="background:var(--red)"></i>' : '') + x[2] + '<b>' + n(x[1]) + '</b></button>'; }).join('');
    var origenes = [{ id: 0, n: 'Todos los orígenes' }].concat(ORG_ORDEN.map(function (o) { return { id: o, n: ORG[o][0] }; }));
    var vacio = '<div class="cp-card"><div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('check', 20) + '</span><b>' + (U.f === 'new' && !U.q && !U.o ? 'No hay avisos sin tratar' : 'Ningún aviso coincide') + '</b>' + (U.f === 'new' && !U.q && !U.o ? 'Todo lo detectado ya tiene OT o fue descartado con motivo.' : 'Prueba con otro estado u origen.') + '</div></div>';
    return '<div class="cp-avbar"><div class="cp-avbar-r"><div class="cp-chips">' + chips + '</div>' +
      '<div class="cp-avbar-f">' + K.combo('avOrigen', origenes, U.o, { etiqueta: 'Origen', ph: 'Todos los orígenes' }) +
      '<label class="cp-srch2" style="min-width:200px;flex:1;max-width:300px">' + ic('search', 14) + '<input id="avQ" data-pv="q" data-live="1" value="' + esc(U.q) + '" placeholder="Activo, componente o aviso" aria-label="Buscar avisos" autocomplete="off"></label></div></div>' +
      (U.f === 'new' && porOrigen.length ? '<div class="cp-av-sum">' + porOrigen.map(function (o) { return '<button type="button" class="cp-avs-i' + (+U.o === o ? ' cp-on' : '') + '" data-a="avof" data-v="' + o + '">' + ic(ORG[o][1], 14) + '<b>' + base.filter(function (a) { return +a.ORIGEN === o && a.ESTADO === 'NUEVO'; }).length + '</b>' + ORG[o][0] + '</button>'; }).join('') + '</div>' : '') + '</div>' +
      '<div class="cp-avl" id="avList">' + (lista.map(fila).join('') || vacio) + '</div>';
  }
  function pintar() {
    var b = $('#mlBody'); if (!b || !$('#avRoot')) return;
    var fo = K.grabFocus(b), sy = window.scrollY;
    b.querySelector('#avRoot').innerHTML = cuerpo();
    K.putFocus(fo, b); window.scrollTo(0, sy);
  }
  function listaSolo() { var l = $('#avList'); if (l) l.innerHTML = filtrada().map(fila).join('') || ''; }

  function cargar() {
    U.error = ''; U.lista = null; pintar();
    return api('Cargar', { planta: L.planta() }).then(function (r) {
      U.lista = r.avisos || []; U.motivos = r.motivos || []; U.perm = r.permisos || {};
      pintar(); L.heroRefresh();
    }).catch(function (e) { U.error = e.message || 'Error'; pintar(); });
  }

  /* ------------------------------------------------------------ OT abiertas del activo (anti-duplicado y «Vincular») */
  var OTS = {};   // activo -> lista | 'cargando'
  function otsDe(activo) {
    if (OTS[activo] && OTS[activo] !== 'cargando') return Promise.resolve(OTS[activo]);
    return api('OtAbiertas', { activo: +activo }).then(function (r) { OTS[activo] = r.ots || []; return OTS[activo]; });
  }

  /* ------------------------------------------------------------ panel del aviso */
  var PA = function (st) {
    var a = find(st.o, st.r);
    if (!a) return { t: 'Aviso', b: '<div class="cp-empty" style="border:0">El aviso ya no está en la bandeja.</div>', f: '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-plain" data-a="pclose">Cerrar</button></span>', w: 'n' };
    var dups = (st.ots || []).filter(function (o) { return o.MISMO_ACTIVO; });
    var nuevo = a.ESTADO === 'NUEVO';
    var hechos = '<dl class="cp-kv"><dt>Origen</dt><dd>' + esc(ORG[a.ORIGEN] ? ORG[a.ORIGEN][0] : '') + '</dd><dt>Severidad</dt><dd>' + (SEV[a.SEVERIDAD] || '') + '</dd><dt>Detectado</dt><dd>' + cuando(a) + '</dd><dt>Por</dt><dd>' + origenTxt(a) + '</dd>' +
      (a.ESTADO_ACTIVO ? '<dt>Estado del activo</dt><dd>' + esc(a.ESTADO_ACTIVO) + '</dd>' : '') + (a.DETUVO ? '<dt>Producción</dt><dd>Se detuvo</dd>' : '') + '</dl>';
    var b = '<div class="cp-eqbox">' + ic('cog', 20) + '<span><b>' + esc(a.ACTIVO) + '</b><small>' + esc(a.ACTIVO_CODIGO) + (a.COMPONENTE ? ' › ' + esc(a.COMPONENTE) : '') + (a.AREA ? ' · ' + esc(a.AREA) : '') + (a.PLANTA ? ' · ' + esc(a.PLANTA) : '') + '</small></span></div>' +
      (a.DETALLE ? '<p style="margin:12px 0 0;font-size:13px;line-height:1.5;color:var(--ink-2)">' + esc(a.DETALLE) + '</p>' : '') +
      '<div class="cp-blk">' + hechos + '</div>' +
      (a.ESTADO === 'OT' ? '<div class="cp-bnr cp-ok" style="margin-top:12px">' + ic('check', 18) + '<span><b>Resuelto por la ' + otTxt(a.OT_NUMERO) + '.</b> ' + otEst(a.OT_ESTADO).replace(/^./, function (c) { return c.toUpperCase(); }) + '.</span></div>' : '') +
      (a.ESTADO === 'DESCARTADO' ? '<div class="cp-bnr" style="margin-top:12px">' + ic('x', 18) + '<span><b>Descartado' + (a.DESCARTA ? ' por ' + esc(a.DESCARTA) : '') + '.</b> ' + esc(a.MOTIVO) + '</span></div>' : '') +
      (nuevo && dups.length && !st.dsc ? '<div class="cp-bnr cp-w" style="margin-top:12px">' + ic('alert', 18) + '<span><b>' + esc(a.ACTIVO_CODIGO) + ' ya tiene ' + (dups.length === 1 ? 'la ' + otTxt(dups[0].OT_NUMERO) + ' abierta' : dups.length + ' OT abiertas') + '.</b> Si es el mismo problema, vincula el aviso en vez de crear otra OT.' +
        '<span class="cp-bnr-a">' + dups.slice(0, 2).map(function (o) { return '<button type="button" class="cp-btn cp-out cp-xs" data-a="avlinkto" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '" data-ot="' + o.OT_ID + '">Vincular a ' + otTxt(o.OT_NUMERO) + '</button>'; }).join('') + '</span></span></div>' : '') +
      (st.dsc ? '<div class="cp-blk" id="dscf"><h4>Descartar el aviso</h4><div class="cp-chips" style="margin-bottom:8px">' + U.motivos.map(function (m) { return '<button type="button" class="cp-fc" data-a="avmot" data-v="' + esc(m.NOMBRE) + '" aria-pressed="' + (st.mot === m.NOMBRE) + '">' + esc(m.NOMBRE) + '</button>'; }).join('') + '</div>' +
        '<div class="cp-fld"><label for="avm">Motivo <small>obligatorio · mínimo 10 caracteres</small></label><textarea id="avm" class="cp-inp' + (st.err ? ' cp-err' : '') + '" rows="2" data-pv="mot" placeholder="Por qué este aviso no necesita trabajo" data-autofocus="1">' + esc(st.mot || '') + '</textarea>' + (st.err ? '<div class="cp-msg">' + ic('alert', 13) + '<span>Escribe el motivo (mínimo 10 caracteres): queda en el historial del aviso.</span></div>' : '') + '</div></div>' : '');
    var f = !nuevo || !U.perm.generar ? '<span></span><span class="cp-r"><button type="button" class="cp-btn cp-plain" data-a="pclose">Cerrar</button></span>'
      : st.dsc ? '<button type="button" class="cp-btn cp-ghost" data-a="avdsc">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="avdscok">Confirmar descarte</button></span>'
      : '<button type="button" class="cp-btn cp-plain" data-a="avdsc">Descartar</button><span class="cp-r"><button type="button" class="cp-btn cp-out" data-a="avlink" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '">' + ic('link', 16) + 'Vincular a OT</button><button type="button" class="cp-btn cp-sec' + (st.busy ? ' cp-load' : '') + '" data-a="avgen" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '">' + ic('plus', 16) + 'Generar OT</button></span>';
    return { t: esc(a.TITULO), s: esc(a.AVISO) + ' · ' + esc(ORG[a.ORIGEN] ? ORG[a.ORIGEN][0] : ''), b: b, f: f, w: 'n' };
  };

  /* ------------------------------------------------------------ reportar falla */
  var PF = function (st) {
    var e = st.err, cat = st.cat;
    if (!cat) return { t: 'Reportar falla', s: 'Avisos · lo detectado pasa a la bandeja y de ahí a una OT', b: '<div class="cp-sk" style="height:46px"></div><div class="cp-sk" style="height:46px;margin-top:12px"></div><div class="cp-sk" style="height:120px;margin-top:12px"></div>', w: 'n' };
    var activos = cat.activos.map(function (a) { return { id: a.ID, n: a.CODIGO + ' · ' + a.NOMBRE, sub: a.AREA }; });
    var comps = [{ id: 0, n: 'Activo completo' }].concat(cat.componentes.filter(function (c) { return +c.ACTIVO_ID === +st.act; }).map(function (c) { return { id: c.ID, n: c.NOMBRE }; }));
    var dups = (st.ots || []).filter(function (o) { return o.MISMO_ACTIVO; });
    var sev = [1, 2, 3, 4].map(function (s) { return '<button type="button" data-a="fsev" data-v="' + s + '" aria-pressed="' + (+st.sev === s) + '">' + SEV[s] + '</button>'; }).join('');
    var post = [1, 2, 3].map(function (s) { return '<button type="button" data-a="fpost" data-v="' + s + '" aria-pressed="' + (+st.post === s) + '">' + POST[s] + '</button>'; }).join('');
    var malT = e && (st.t || '').trim().length < 5;
    var b = '<div class="cp-fld"><label>Activo <small>obligatorio</small></label>' + K.combo('avAct', activos, st.act || '', { etiqueta: 'Activo', ph: 'Elige el activo', err: e && !st.act }) + (e && !st.act ? '<div class="cp-msg">' + ic('alert', 13) + '<span>Elige el activo con la falla.</span></div>' : '') + '</div>' +
      (st.act ? '<div class="cp-fld"><label>Objeto mantenible <small>activo o componente</small></label>' + K.combo('avComp', comps, st.comp || 0, { etiqueta: 'Componente', ph: 'Activo completo' }) + '</div>' : '') +
      (dups.length ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span><b>Este activo ya tiene ' + pl(dups.length, 'OT abierta', 'OT abiertas') + ':</b> ' + dups.map(function (o) { return otTxt(o.OT_NUMERO) + ' · ' + esc(o.TITULO); }).join('; ') + '. Si es lo mismo, podrás vincular el aviso a esa OT.</span></div>' : '') +
      '<div class="cp-fld"><label for="ft">Qué está fallando <small>obligatorio</small></label><input id="ft" class="cp-inp' + (malT ? ' cp-err' : '') + '" data-pv="t" value="' + esc(st.t || '') + '" placeholder="Ej.: Ruido metálico al arrancar" autocomplete="off">' + (malT ? '<div class="cp-msg">' + ic('alert', 13) + '<span>Describe la falla en pocas palabras (mínimo 5 caracteres).</span></div>' : '') + '</div>' +
      '<div class="cp-fld"><label>Criticidad</label><div class="cp-segc">' + sev + '</div></div>' +
      '<div class="cp-fld"><label>Estado del activo ahora</label><div class="cp-segc">' + post + '</div></div>' +
      '<label class="cp-sw"><input type="checkbox" data-pv="detuvo"' + (st.detuvo ? ' checked' : '') + '><i></i>Detuvo la producción</label>' +
      '<div class="cp-fld" style="margin-top:12px"><label for="fd">Detalle</label><textarea id="fd" class="cp-inp" rows="3" data-pv="det" placeholder="Qué viste, cuándo empezó, qué hiciste">' + esc(st.det || '') + '</textarea></div>' +
      (U.perm.generar ? '<label class="cp-sw"><input type="checkbox" data-pv="gen"' + (st.gen ? ' checked' : '') + '><i></i>Generar la OT de inmediato</label>' +
        '<div class="cp-msg cp-i" style="margin-top:8px">' + ic('help', 13) + '<span>' + (st.gen ? 'Se crea el aviso y su OT correctiva.' : 'El aviso queda en la bandeja para que se decida qué hacer con él.') + '</span></div>' : '');
    return { t: 'Reportar falla', s: 'Avisos · lo detectado pasa a la bandeja y de ahí a una OT', b: b,
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="fallaok">' + ic('send', 16) + 'Reportar falla</button></span>', w: 'n' };
  };

  /* ------------------------------------------------------------ popover «Vincular» */
  var PV = function (pp) {
    var a = find(pp.org, pp.ref); if (!a) return '';
    if (!pp.ots) return '<div class="cp-ppt"><b>Vincular ' + esc(a.AVISO) + ' a una OT abierta</b><small>Buscando las OT abiertas…</small></div>';
    var mismo = pp.ots.filter(function (o) { return o.MISMO_ACTIVO; }), area = pp.ots.filter(function (o) { return !o.MISMO_ACTIVO; });
    var it = function (o) { return '<button type="button" class="cp-mi2 cp-otp" role="menuitem" data-a="avlinkto" data-o="' + a.ORIGEN + '" data-r="' + a.REF + '" data-ot="' + o.OT_ID + '"><span class="cp-mono">' + otTxt(o.OT_NUMERO) + '</span><span><b>' + esc(o.TITULO) + '</b><small>' + esc(o.ACTIVO_CODIGO) + (o.COMPONENTE ? ' › ' + esc(o.COMPONENTE) : '') + ' · ' + otEst(o.ESTADO) + '</small></span></button>'; };
    return '<div class="cp-ppt"><b>Vincular ' + esc(a.AVISO) + ' a una OT abierta</b><small>El aviso queda resuelto por esa OT; no se crea otra.</small></div>' +
      (mismo.length ? '<div class="cp-ppg">Mismo activo · ' + esc(a.ACTIVO_CODIGO) + '</div>' + mismo.map(it).join('') : '') +
      (area.length ? '<div class="cp-ppg">Misma área · ' + esc(a.AREA || '') + '</div>' + area.slice(0, 6).map(it).join('') : '') +
      (mismo.length || area.length ? '' : '<p class="cp-ppe">No hay OT abiertas en ' + esc(a.ACTIVO_CODIGO) + ' ni en su área. Genera una OT nueva.</p>');
  };

  /* ------------------------------------------------------------ acciones */
  var A = L.A;
  function panelAviso(o, r, dsc) {
    var st = { o: o, r: r, dsc: !!dsc, mot: '', err: false, ots: null, busy: false }, a = find(o, r);
    K.Panel.open({ render: PA, st: st });
    if (a) otsDe(a.ACTIVO_ID).then(function (ots) { st.ots = ots; if (K.Panel.state() === st) K.Panel.paint(); }).catch(function () { });
    if (dsc) setTimeout(function () { var m = $('#avm'); if (m) m.focus(); }, 40);
  }
  A.avopen = function (d) { panelAviso(d.o, d.r, d.dsc === '1'); };
  A.avreload = function () { cargar(); };
  A.avf = function (d) { U.f = d.v; pintar(); };
  A.avof = function (d) { U.o = +U.o === +d.v ? 0 : +d.v; pintar(); };
  A.avdsc = function () { var st = K.Panel.state(); if (!st) return; st.dsc = !st.dsc; st.err = false; K.Panel.paint(); if (st.dsc) setTimeout(function () { var m = $('#avm'); if (m) m.focus(); }, 30); };
  A.avmot = function (d) { var st = K.Panel.state(); if (!st) return; st.mot = d.v; st.err = false; K.Panel.paint(); };

  function abrirOt(url) { if (url) location.href = url; }
  function tras(promesa, st) {
    if (st) { st.busy = true; K.Panel.paint(); }
    return promesa.then(function (r) { if (st) st.busy = false; return r; }, function (e) { if (st) { st.busy = false; K.Panel.paint(); } K.toastError(e); throw e; });
  }
  A.avgen = function (d) {
    var a = find(d.o, d.r), st = K.Panel.state(); if (!a || (st && !st.o)) st = null;
    tras(api('Generar', { origen: +d.o, refId: +d.r }), st).then(function (r) {
      K.Panel.close(); K.Pop.close();
      K.toastA((r.ya ? 'El aviso ya tenía la ' + otTxt(r.ot) + '.' : a.AVISO + ' → ' + otTxt(r.ot) + ' generada. No se creó otra OT sobre el mismo aviso.'), 'Abrir OT', function () { abrirOt(r.url); });
      cargar();
    }).catch(function () { });
  };
  A.avlink = function (d, el) {
    var a = find(d.o, d.r); if (!a) return;
    var pp = { org: d.o, ref: d.r, right: true, ots: null, render: PV };   // «r» lo usa el kit para la posición
    K.Pop.open(el, pp);
    otsDe(a.ACTIVO_ID).then(function (ots) { pp.ots = ots; if (K.Pop.state() === pp) K.Pop.paint(); }).catch(function (e) { K.Pop.close(); K.toastError(e); });
  };
  A.avlinkto = function (d) {
    var a = find(d.o, d.r), st = K.Panel.state(); if (st && !st.o) st = null;
    tras(api('Vincular', { origen: +d.o, refId: +d.r, ot: +d.ot }), st).then(function (r) {
      K.Pop.close(); K.Panel.close();
      K.toastA(a.AVISO + ' vinculado a ' + otTxt(r.ot) + '. No se creó otra OT.', 'Abrir OT', function () { abrirOt(r.url); });
      cargar();
    }).catch(function () { });
  };
  A.avdscok = function () {
    var st = K.Panel.state(); if (!st) return;
    if ((st.mot || '').trim().length < 10) { st.err = true; K.Panel.paint(); return; }
    var a = find(st.o, st.r), o = st.o, r = st.r;
    tras(api('Descartar', { origen: +o, refId: +r, motivo: st.mot.trim() }), st).then(function () {
      K.Panel.close();
      K.toast(a.AVISO + ' descartado.', function () { api('Reabrir', { origen: +o, refId: +r }).then(cargar).catch(K.toastError); });
      cargar();
    }).catch(function () { });
  };

  /* reportar falla */
  function panelFalla() {
    var st = { cat: null, ots: null, act: '', comp: 0, t: '', sev: 2, post: 1, detuvo: false, det: '', gen: false, err: false, busy: false };
    K.Panel.open({ render: PF, st: st });
    api('Catalogo', { planta: L.planta() }).then(function (c) { st.cat = c; if (K.Panel.state() === st) K.Panel.paint(); }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  }
  A.falla = function () { panelFalla(); };
  A.fsev = function (d) { var st = K.Panel.state(); st.sev = +d.v; if (+d.v === 4 && U.perm.generar) st.gen = true; K.Panel.paint(); };
  A.fpost = function (d) { var st = K.Panel.state(); st.post = +d.v; if (+d.v === 3) st.detuvo = true; K.Panel.paint(); };
  A.fallaok = function () {
    var st = K.Panel.state(); if (!st) return;
    if (!st.act || (st.t || '').trim().length < 5) { st.err = true; K.Panel.paint(); return; }
    tras(api('ReportarFalla', { activo: +st.act, componente: +st.comp || 0, titulo: st.t.trim(), detalle: st.det || '', criticidad: +st.sev, estadoPosterior: +st.post, detuvo: !!st.detuvo, generar: !!st.gen }), st).then(function (r) {
      K.Panel.close();
      if (r.ot) K.toastA('FAL-' + r.falla + ' reportada y ' + otTxt(r.ot) + ' generada.', 'Abrir OT', function () { abrirOt(r.url); });
      else K.toastA('FAL-' + r.falla + ' reportada. Quedó en la bandeja de Avisos.', 'Ver sin tratar', function () { U.f = 'new'; U.o = 0; pintar(); });
      U.f = 'new'; cargar();
    }).catch(function () { });
  };

  /* campos del panel y combos */
  L.on({
    pv: function (k, v) {
      if (k === 'q') { U.q = v; listaSolo(); return; }
      var st = K.Panel.state(); if (!st) return;
      st[k] = v;
      if (k === 'detuvo' || k === 'gen') K.Panel.paint();
      else if (k === 't' && st.err && String(v).trim().length >= 5) { st.err = false; K.Panel.paint(); }
      else if (k === 'mot') st.err = false;
    },
    combo: function (span, v) {
      var n = span.getAttribute('data-cb');
      if (n === 'avOrigen') { U.o = +v || 0; pintar(); return; }
      var st = K.Panel.state(); if (!st) return;
      if (n === 'avAct') {
        st.act = v; st.comp = 0; st.ots = null; K.Panel.paint();
        if (v) otsDe(v).then(function (ots) { st.ots = ots; if (K.Panel.state() === st) K.Panel.paint(); }).catch(function () { });
      }
      if (n === 'avComp') st.comp = +v || 0;
    }
  });

  /* ------------------------------------------------------------ registro de la pestaña */
  L.tab('avisos', {
    mount: function (body) { body.innerHTML = '<div id="avRoot"></div>'; var abrir = /[#&]nuevo=1/.test(location.hash); cargar().then(function () { if (abrir && U.perm.reportar) { try { history.replaceState(null, '', '#avisos'); } catch (e) { } panelFalla(); } }); },
    hero: function () { return U.perm.reportar ? '<button type="button" class="cp-btn cp-pri" data-a="falla">' + ic('alert', 16) + 'Reportar falla</button>' : ''; },
    planta: function () { cargar(); }
  });
})();
