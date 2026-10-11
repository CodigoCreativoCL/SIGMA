/* =====================================================================
   ÓRDENES DE TRABAJO · lista y ficha COMPLETA (parte c)
   Referencia: docs/rediseno-mantenimiento/sigma-mantenimiento-referencia.html (OT)
   Datos: WsOrdenes.asmx (SEL_OT_LISTA, SEL_ORDEN_TRABAJO y SEL_OT_FICHA_EXTRA; BD/398).
   La ficha reúne TODO lo que tenía la pantalla anterior, sin mandar a otro menú:
     Resumen (datos editables, asignación a personas, empresas y grupos, avisos y bitácora)
     Pasos (resolver, agregar desde un procedimiento, evidencias)
     Consumo (repuestos, mano de obra y servicios)
     Indisponibilidad (la del activo ligada a la OT)
     Cierre (requisitos, informe, firmas, validación y cierre con firma)
   NO reescribe el ciclo de vida: Iniciar / pasos / enviar a cierre / cerrar usan los SP de siempre.
   Los perfiles son dinámicos por cliente: ningún texto nombra un perfil fijo.
   URL: #ordenes (lista) · #ordenes&ot=<id cifrado>&t=<pestaña> (ficha).
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar, CFG = K.CFG;
  var esc = K.esc, ic = K.ic, pl = K.pl, nrm = K.nrm, $ = K.$;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  /* 413 · Choques de horario: mientras dura el trabajo el equipo está parado; otra OT, inspección, tarea o
     plan sobre el mismo activo, subactivo o componente en esa ventana se advierte antes de guardar. */
  var apiCP = function (m, d) { return K.llamar(CFG.base_ + 'WebService/WsCentroPlanificacion.asmx/', m, d); };
  var TIPN = { PLAN: 'Plan', INS: 'Inspección', TAR: 'Tarea', OT: 'OT' };
  /* 420 · carga laboral de quien está asignado a la OT (persona o empresa externa). */
  function cargaOT(a, nombre, sub, fecha) {
    var cl = +a.ota_usuario ? 'U:' + a.ota_usuario : +a.ota_proveedor ? 'E:' + a.ota_proveedor : +a.ota_grupo_trabajo ? 'G:' + a.ota_grupo_trabajo : '';
    return cl && window.SigmaCarga ? '<span class="cp-carga">' + SigmaCarga.chipDe(cl) + SigmaCarga.boton(cl, nombre, sub, null, fecha || '') + '</span>' : '';
  }
  function choquesHTML(l) {
    if (!l || !l.length) return '';
    return '<div class="cp-bnr cp-w" style="margin-top:12px">' + ic('alert', 18) + '<span><b>Choque de horario</b>: en esa ventana el equipo, o quienes la ejecutan, ya tienen otro trabajo.' +
      '<ul class="cp-olst" style="margin-top:6px">' + l.slice(0, 5).map(function (c) {
        return '<li>' + (c.CLASE === 'RECURSO' ? '<span class="cp-tg">Ocupado</span> ' : '') + '<b>' + esc(c.OBJETO) + '</b> · ' + (TIPN[c.CON_TIPO] || '') + ' ' + esc(c.CON_CODIGO) + ' · ' + esc(c.CON_NOMBRE) + '<small>' + K.fD(K.dIso(c.CON_INICIO)) + ' ' + K.hIso(c.CON_INICIO) + '–' + K.hIso(c.CON_FIN) + '</small>' + (c.CLASE === 'RECURSO' && c.CLAVE && window.SigmaCarga ? ' ' + SigmaCarga.boton(c.CLAVE, String(c.OBJETO).replace(/\s*\(grupo.*$/, ''), '', null, c.CON_INICIO) : '') + '</li>';
      }).join('') + (l.length > 5 ? '<li><small>y ' + (l.length - 5) + ' más</small></li>' : '') + '</ul><small style="display:block;margin-top:6px">Si es intencional, guarda igual; si no, cambia la fecha, la hora o la duración.</small></span></div>';
  }
  /* true = esperar (revisando o mostrando choques); false = seguir guardando. */
  function choquesAntes(st, ref, activo, componente, fechaHora, durMin, seguir, recursos) {
    if (st.choqOk || !fechaHora || !(+activo)) return false;
    st.busy = true; K.Panel.paint();
    apiCP('ChoquesCandidato', { datos: JSON.stringify({ tipo: 'OT', ref: ref || 0, objetos: [{ activo: +activo, componente: +componente || 0 }], fechas: [fechaHora.replace(' ', 'T')], duracion: durMin || 60, recursos: recursos || [] }) }).then(function (r) {
      if (K.Panel.state() !== st) return;
      st.busy = false; st.choq = r.choques || [];
      if (!st.choq.length) { st.choqOk = true; seguir(); return; }
      K.Panel.paint(); var b = $('#cpLayer .cp-pnl-b'); if (b) b.scrollTop = b.scrollHeight;
    }).catch(function () { if (K.Panel.state() !== st) return; st.busy = false; st.choqOk = true; seguir(); });
    return true;
  }

  var ESTADOS = { 1: ['Por iniciar', 'a'], 2: ['En ejecución', 'e'], 3: ['En espera de cierre', 'w'], 4: ['Cerrada', 'c'] };
  var TIPOS = { 1: 'Preventiva', 2: 'Correctiva', 3: 'Predictiva' };
  var PRIO = { 1: 'Baja', 2: 'Media', 3: 'Alta', 4: 'Crítica' };
  var ESTRATEGIAS = { 1: 'Rutinario', 2: 'Programado', 3: 'Emergencia', 4: 'Inspección', 5: 'Overhaul', 6: 'Mejora' };
  var ORIGEN = { 1: ['Manual', 'pencil'], 2: ['Plan', 'calw'], 3: ['Tarea', 'check'], 4: ['Hallazgo de inspección', 'clip'], 5: ['SIGMA AI', 'spark'], 6: ['Alerta de medidor', 'gauge'], 7: ['Falla', 'alert'], 8: ['Bitácora', 'pencil'], 9: ['Hallazgo en OT', 'wrench'] };
  var POST = { 1: 'Operativo', 2: 'Operativo con observación', 3: 'Detenido' };
  var MOTIVOS_IND = { 1: 'Mantenimiento planificado', 2: 'Falla', 3: 'Espera de repuesto', 4: 'Espera de personal', 5: 'Causa externa', 6: 'Parada de producción' };
  var FILTROS = [['open', 'Abiertas'], ['n', 'Creadas'], ['a', 'Asignadas'], ['2', 'En progreso'], ['3', 'Completadas'], ['late', 'Vencidas'], ['4', 'Cerradas'], ['all', 'Todas']];
  var HORAS = (function () { var r = []; for (var h = 0; h <= 23; h++) { ['00', '30'].forEach(function (m) { r.push((h < 10 ? '0' : '') + h + ':' + m); }); } return r; })();

  var U = { lista: null, perm: {}, error: '', f: 'open', o: 0, t: 0, q: '', ficha: null, tab: 'resumen', cat: null, cargandoFicha: false, ed: null, asig: null, ind: null, fr: null, firmaCierre: '', confirma: false, formCierre: { informe: '', horas: '', post: 0, causa: '', motivo: 1 } };
  var otTxt = function (n) { return 'OT-' + n; };
  var cap = function (s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; };
  var f2 = function (s) { return s ? K.fD(K.dIso(s)) + ' ' + K.hIso(s) : '—'; };
  var fe = function (s) { return s ? K.fDN(K.dIso(s)) : ''; };
  var he = function (s) { return s ? K.hIso(s) : '08:00'; };

  /* ---------------------------------------------------------------- piezas */
  var ESTV = { n: ['Creada', 'n'], a: ['Asignada', 'a'], 2: ['En progreso', 'e'], 3: ['Completada', 'w'], 4: ['Cerrada', 'c'] };
  var estChip = function (e, asignada) { var x = ESTV[+e === 1 ? (asignada ? 'a' : 'n') : e] || ['', '']; return '<span class="cp-oe cp-oe-' + x[1] + '"><i></i>' + x[0] + '</span>'; };
  var vencida = function (o) { return +o.ESTADO_ID !== 4 && o.PROGRAMADA && K.dIso(o.PROGRAMADA) < K.TODAY; };
  var prioChip = function (p) { return '<span class="cp-sv cp-s' + p + '">' + (PRIO[p] || '') + '</span>'; };
  function orgChip(id, ref) { var x = ORIGEN[id] || ORIGEN[1]; return '<span class="cp-og cp-o' + id + '">' + ic(x[1], 13) + x[0] + '</span>' + (ref ? '<small class="cp-og-r">' + esc(ref) + '</small>' : ''); }
  var avatares = function (nombres) {
    var n = (nombres || '').split('|').filter(Boolean);
    return n.length ? '<span class="cp-avs">' + n.slice(0, 3).map(K.avatar).join('') + (n.length > 3 ? '<span class="cp-av cp-more">+' + (n.length - 3) + '</span>' : '') + '</span>' : '<span class="cp-muted2">Sin asignar</span>';
  };
  var seg = function (obj, a, key, cur) { return '<div class="cp-segc">' + Object.keys(obj).map(function (k) { return '<button type="button" data-a="' + a + '" data-k="' + key + '" data-v="' + k + '" aria-pressed="' + (+cur === +k) + '">' + obj[k] + '</button>'; }).join('') + '</div>'; };
  var msgErr = function (t) { return '<div class="cp-msg">' + ic('alert', 13) + '<span>' + t + '</span></div>'; };
  var tabla = function (cols, cab, filas, vacio) {
    return filas.length ? '<div class="cp-rows"><div class="cp-rw cp-h" style="grid-template-columns:' + cols + '">' + cab.map(function (c) { return '<span>' + c + '</span>'; }).join('') + '</div>' + filas.join('') + '</div>' : '<p class="cp-muted2" style="margin:6px 0 0">' + vacio + '</p>';
  };

  /* ---------------------------------------------------------------- lista */
  function matchF(o, f) {
    if (f === 'all') return true;
    if (f === 'open') return +o.ESTADO_ID !== 4;
    if (f === 'n') return +o.ESTADO_ID === 1 && !o.RESPONSABLES;
    if (f === 'a') return +o.ESTADO_ID === 1 && !!o.RESPONSABLES;
    if (f === 'late') return !!vencida(o);
    return String(o.ESTADO_ID) === f;
  }
  function coincide(o) {
    if (!matchF(o, U.f)) return false;
    if (U.o && +o.ORIGEN_ID !== +U.o) return false;
    if (U.t && +o.TIPO_ID !== +U.t) return false;
    var q = nrm(U.q);
    return !q || nrm([otTxt(o.NUMERO), o.TITULO, o.ACTIVO_CODIGO, o.ACTIVO, o.COMPONENTE, o.REFERENCIA, o.RESPONSABLES].join(' ')).indexOf(q) >= 0;
  }
  var RANGO = { 2: 0, 1: 1, 3: 2, 4: 3 };
  function ordenada() {
    var cerr = U.f === '4' || U.f === 'all';
    return (U.lista || []).filter(coincide).sort(function (a, b) {
      if (cerr) return String(b.CIERRE || b.PROGRAMADA || '').localeCompare(String(a.CIERRE || a.PROGRAMADA || ''));
      return (RANGO[a.ESTADO_ID] - RANGO[b.ESTADO_ID]) || String(a.PROGRAMADA || '9').localeCompare(String(b.PROGRAMADA || '9'));
    });
  }
  var COLS = 'grid-template-columns:84px minmax(0,1.5fr) minmax(0,1.1fr) 128px 118px 96px 150px';
  function filaOt(o) {
    var prog = o.PROGRAMADA ? '<b>' + K.fD(K.dIso(o.PROGRAMADA)) + '</b><small>' + (o.ESTADO_ID === 4 ? 'cerrada' : K.rel(K.dIso(o.PROGRAMADA))) + '</small>' : '<small>Sin fecha</small>';
    return '<div class="cp-rw cp-click" style="' + COLS + '" data-a="otabrir" data-q="' + esc(o.Q) + '" role="button" tabindex="0" aria-label="Abrir ' + otTxt(o.NUMERO) + '">' +
      '<span class="cp-mono">' + otTxt(o.NUMERO) + '</span>' +
      '<span class="cp-s"><b>' + esc(o.TITULO) + '</b><small>' + esc(o.ACTIVO_CODIGO) + ' · ' + esc(o.ACTIVO) + (o.COMPONENTE ? ' › ' + esc(o.COMPONENTE) : '') + '</small></span>' +
      '<span class="cp-s">' + orgChip(o.ORIGEN_ID, o.REFERENCIA) + '</span>' +
      '<span class="cp-s"><b style="font-weight:600">' + (TIPOS[o.TIPO_ID] || '') + '</b><small>Prioridad ' + (PRIO[o.PRIORIDAD_ID] || '').toLowerCase() + (o.PARADA ? ' · parada' : '') + '</small></span>' +
      '<span class="cp-dt">' + prog + '</span><span>' + avatares(o.RESPONSABLES) + '</span><span>' + estChip(o.ESTADO_ID, !!o.RESPONSABLES) + '</span></div>';
  }
  function listaHTML() {
    if (U.error) return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudieron cargar las órdenes de trabajo</b>' + esc(U.error) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="otreload">Reintentar</button></div>';
    if (!U.lista) return '<div style="padding:10px;display:flex;flex-direction:column;gap:10px">' + [1, 2, 3, 4].map(function () { return '<div class="cp-sk" style="height:56px"></div>'; }).join('') + '</div>';
    var base = U.lista, lista = ordenada(), shown = lista.slice(0, 100);
    var n = function (k) { return base.filter(function (o) { return matchF(o, k); }).length; };
    var origenes = [{ id: 0, n: 'Todos los orígenes' }].concat(Object.keys(ORIGEN).map(function (k) { return { id: +k, n: ORIGEN[k][0] }; }));
    var tipos = [{ id: 0, n: 'Todos los tipos' }].concat(Object.keys(TIPOS).map(function (k) { return { id: +k, n: TIPOS[k] }; }));
    return '<div class="cp-card cp-exc"><div class="cp-avbar"><div class="cp-avbar-r"><div class="cp-chips">' + FILTROS.map(function (x) { return '<button type="button" class="cp-fc" data-a="otf" data-v="' + x[0] + '" aria-pressed="' + (U.f === x[0]) + '">' + x[1] + '<b>' + n(x[0]) + '</b></button>'; }).join('') + '</div>' +
      '<div class="cp-avbar-f" style="flex:1 1 100%;justify-content:flex-start">' + K.combo('otOrigen', origenes, U.o, { etiqueta: 'Origen', ph: 'Todos los orígenes' }) + K.combo('otTipo', tipos, U.t, { etiqueta: 'Tipo', ph: 'Todos los tipos' }) +
      '<label class="cp-srch2" style="min-width:200px;flex:1;max-width:300px">' + ic('search', 14) + '<input id="otQ" data-pv="otq" data-live="1" value="' + esc(U.q) + '" placeholder="OT, activo o trabajo" aria-label="Buscar órdenes" autocomplete="off"></label></div></div></div>' +
      '<div class="cp-rows cp-otl"><div class="cp-rw cp-h" style="' + COLS + '"><span>OT</span><span>Trabajo · activo</span><span>Viene de</span><span>Tipo</span><span>Programada</span><span></span><span>Estado</span></div><div id="otFilas">' +
      (shown.map(filaOt).join('') || '<div class="cp-empty" style="margin:10px"><span class="cp-ei">' + ic('check', 20) + '</span><b>Ninguna OT coincide</b>Prueba con otro estado, origen o tipo.</div>') + '</div>' +
      (lista.length > shown.length ? '<p class="cp-more-n">Mostrando ' + shown.length + ' de ' + lista.length + '. Afina con los filtros para ver el resto.</p>' : '') + '</div></div>';
  }

  /* ---------------------------------------------------------------- ficha: la estructura del mockup */
  var FIRMAS = { ej: '', rec: '', sup: '' };
  var ROLES = {
    ej: ['Ejecutó el trabajo', 'EJECUCION', 'Quien ejecutó el trabajo'],
    rec: ['Recibe el activo', 'ACEPTACION', 'Obligatoria: la OT detuvo el activo'],
    sup: ['Aprueba el cierre', 'VALIDACION', 'Quien tiene la facultad de cerrar OT']
  };
  var CAUSAS = ['Desgaste normal', 'Falta de lubricación', 'Operación incorrecta', 'Material defectuoso', 'Montaje incorrecto', 'Otra'];
  var fHM = function (min) { min = Math.round(+min || 0); return Math.floor(min / 60) + ' h ' + (min % 60) + ' min'; };
  var editable = function (F) { return F.permisos.crear && +F.ot.otr_orden_trabajo_estado < 4; };
  var firmaDe = function (F, rol) { return (F.firmas || []).filter(function (f) { return f.TIPO_CODIGO === ROLES[rol][1] && f.RESULTADO === 'APROBADO'; })[0] || null; };
  var necesitaRec = function (F) { return +F.ot.otr_minuto_parada_activo > 0 || F.indisponibilidades.some(function (i) { return i.ain_detuvo_produccion; }); };
  var faltan = function (F) { return ['rec', 'sup'].filter(function (r) { return (r !== 'rec' || necesitaRec(F)) && !firmaDe(F, r); }); };
  var tipoId = function (F, rol) { var t = (F.tiposFirma || []).filter(function (x) { return x.CODIGO === ROLES[rol][1]; })[0]; return t ? t.ID : 0; };
  var minutosReg = function (F) { var m = F.manoObra.reduce(function (a, x) { return a + (+x.MINUTOS || 0); }, 0); return m || +F.ot.otr_duracion_real_minuto || 0; };
  var tieneAsignado = function (F) { return F.asignaciones.some(function (a) { return a.ota_usuario || a.ota_proveedor; }); };
  var estadoVisual = function (F) { var e = +F.ot.otr_orden_trabajo_estado; return e === 1 ? (tieneAsignado(F) ? 1 : 0) : e; };   // 0 creada · 1 asignada · 2 en progreso · 3 completada · 4 cerrada
  var objChip = function (o) {
    var comp = !!o.COMPONENTE_NOMBRE;
    return '<span class="cp-objv"><span class="cp-objk">' + ic(comp ? 'wrench' : 'cog', 12) + (comp ? 'COMPONENTE' : 'ACTIVO') + '</span><span class="cp-objt">' + esc(o.ACTIVO_NOMBRE) + (comp ? ' › ' + esc(o.COMPONENTE_NOMBRE) : '') + '<small>' + esc(o.ACTIVO_CODIGO) + (comp ? '' : ' · activo completo') + '</small></span></span>';
  };

  function bc(o) {
    var l = ordenada(), i = l.map(function (x) { return x.Q; }).indexOf(U.ficha.q);
    var prev = i > 0 ? l[i - 1] : null, next = i >= 0 && i < l.length - 1 ? l[i + 1] : null;
    return '<div class="cp-crumb cp-otcr"><button type="button" class="cp-lnk" data-a="otlista">' + ic('chev', 14).replace('<svg ', '<svg style="transform:rotate(180deg)" ') + 'Órdenes de trabajo</button><span class="cp-sep2">/</span><b>' + otTxt(o.otr_correlativo) + '</b><span class="cp-r">' +
      '<button type="button" class="cp-ibx" data-a="otabrir" data-q="' + (prev ? esc(prev.Q) : '') + '"' + (prev ? '' : ' disabled') + ' aria-label="OT anterior">' + ic('chev', 16).replace('<svg ', '<svg style="transform:rotate(180deg)" ') + '</button>' +
      '<button type="button" class="cp-ibx" data-a="otabrir" data-q="' + (next ? esc(next.Q) : '') + '"' + (next ? '' : ' disabled') + ' aria-label="OT siguiente">' + ic('chev', 16) + '</button></span></div>';
  }
  function vieneDe(F) {
    var o = F.ot, g = F.origen || {}, id = +o.otr_orden_trabajo_origen, x = ORIGEN[id] || ORIGEN[1];
    var avisos = CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx#avisos';
    if (id === 2 && g.PLAN_CODIGO) return '<span class="cp-vd-k">' + ic('calw', 15) + 'Viene del plan</span>' + (F.planUrl ? '<a class="cp-lnk" href="' + esc(F.planUrl) + '">' + esc(g.PLAN_CODIGO) + ' · ' + esc(g.PLAN_NOMBRE || '') + '</a>' : '<b>' + esc(g.PLAN_CODIGO) + '</b>') + '<span class="cp-vd-s">Intervención «' + esc(g.INTERVENCION || o.otr_titulo) + '» · ejecución del ' + K.fD(K.dIso(o.otr_fecha_programada_utc)) + '</span>';
    if (id === 3 && g.TAREA_CODIGO) return '<span class="cp-vd-k">' + ic('check', 15) + 'Escalada desde una tarea</span><b>' + esc(g.TAREA_CODIGO) + ' · ' + esc(g.TAREA_TITULO || '') + '</b>';
    if (id === 1) return '<span class="cp-vd-k">' + ic('pencil', 15) + 'Creada a mano</span><span class="cp-vd-s">Sin plan ni aviso de origen</span>';
    var ref = id === 7 ? 'FAL-' + g.FALLA_ID : (id === 4 || id === 9) ? 'HAL-' + g.HALLAZGO_ID : '';
    var tit = id === 7 && o.FALLA_TITULO ? o.FALLA_TITULO : '';
    return '<span class="cp-vd-k">' + ic(x[1], 15) + 'Viene de un aviso · ' + x[0].toLowerCase() + '</span><a class="cp-lnk" href="' + esc(avisos) + '">' + esc(ref) + (tit ? ' · ' + esc(tit) : '') + '</a>' + (id === 9 && g.OT_ORIGEN_NUMERO ? '<span class="cp-vd-s">Encontrado al ejecutar la ' + otTxt(g.OT_ORIGEN_NUMERO) + '</span>' : '');
  }
  var FLUJO = ['Creada', 'Asignada', 'En progreso', 'Completada', 'Cerrada'];
  function accionPrincipal(F) {
    var e = +F.ot.otr_orden_trabajo_estado, p = F.permisos;
    if (e === 1 && !tieneAsignado(F) && p.crear) return '<button type="button" class="cp-btn cp-pri" data-a="ottab" data-v="resumen">' + ic('plus', 16) + 'Asignar</button>';
    if (e === 1 && p.ejecutar) return '<button type="button" class="cp-btn cp-pri" data-a="otiniciar">' + ic('plus', 16) + 'Iniciar trabajo</button>';
    if (e === 2 && p.ejecutar) return '<button type="button" class="cp-btn cp-pri" data-a="ottab" data-v="cierre">' + ic('check', 16) + 'Completar</button>';
    if (e === 3 && p.cerrar) return '<button type="button" class="cp-btn cp-plain" data-a="otdev">Devolver</button><button type="button" class="cp-btn cp-pri" data-a="ottab" data-v="cierre">' + ic('check', 16) + 'Cerrar OT</button>';
    return '';
  }
  function cabecera(F) {
    var o = F.ot, e = +o.otr_orden_trabajo_estado, parada = necesitaRec(F), fi = estadoVisual(F), resp = F.asignaciones.filter(function (a) { return +a.ota_es_responsable === 1; })[0];
    var nResp = F.asignaciones.filter(function (a) { return +a.ota_es_responsable === 1; }).length;
    var nombreResp = resp ? (resp.USUARIO_NOMBRE || resp.PROVEEDOR_NOMBRE) : '', est = +o.otr_duracion_estimada_minuto || 0, hrs = minutosReg(F), ratio = est ? hrs / est : 0;
    var prog = o.otr_fecha_programada_utc ? K.dIso(o.otr_fecha_programada_utc) : '';
    return '<section class="cp-card cp-oth"><div class="cp-oth-t"><div style="min-width:0"><div class="cp-oth-id"><span class="cp-mono">' + otTxt(o.otr_correlativo) + '</span>' + estChip(e, tieneAsignado(F)) + '<span class="cp-tg">' + (TIPOS[o.otr_orden_trabajo_tipo] || '') + '</span><span class="cp-tg' + (+o.otr_orden_trabajo_prioridad >= 3 ? ' cp-w' : '') + '">Prioridad ' + (PRIO[o.otr_orden_trabajo_prioridad] || '').toLowerCase() + '</span>' + (parada ? '<span class="cp-tg cp-w">Con parada</span>' : '') + '</div>' +
      '<h2>' + esc(o.otr_titulo) + '</h2><p class="cp-oth-a">' + ic('cog', 15) + '<span><b>' + esc(o.ACTIVO_NOMBRE) + '</b> <span class="cp-cmpp">' + esc(o.ACTIVO_CODIGO) + (o.COMPONENTE_NOMBRE ? ' › ' + esc(o.COMPONENTE_NOMBRE) : '') + '</span> · ' + esc(o.AREA_NOMBRE || '') + (o.PLANTA_NOMBRE ? ' · ' + esc(o.PLANTA_NOMBRE) : '') + '</span></p></div>' +
      '<div class="cp-oth-r">' + (F.imprimirUrl ? '<a class="cp-btn cp-out" href="' + esc(F.imprimirUrl) + '" target="_blank" rel="noopener">' + ic('clip', 16) + 'Imprimir</a>' : '') + accionPrincipal(F) + '</div></div>' +
      '<div class="cp-otm"><div><span>' + (nResp > 1 ? 'Responsables' : 'Responsable') + '</span><b>' + (nombreResp ? K.avatar(nombreResp) + esc(nombreResp) + (nResp > 1 ? ' <span class="cp-tg">+' + (nResp - 1) + '</span>' : '') : '<span style="color:var(--amber)">Sin asignar</span>') + '</b><small>' + (resp && resp.GRUPO_NOMBRE ? esc(resp.GRUPO_NOMBRE) : resp ? esc(resp.ROL_NOMBRE || '') : 'Elige un responsable') + '</small></div>' +
      '<div><span>Programada</span><b>' + (prog ? K.fD(prog) : '—') + '</b><small>' + (prog ? (e === 4 ? 'cerrada' : K.rel(prog)) : 'Sin fecha') + '</small></div>' +
      '<div><span>Duración estimada</span><b>' + (est ? K.fH(est) : '—') + '</b><small>' + (+o.otr_requiere_permiso ? 'Requiere permiso de trabajo' : 'Sin permiso especial') + '</small></div>' +
      '<div><span>Tiempo registrado</span><b>' + fHM(hrs) + '</b><small><span class="cp-tbar"><i class="' + (ratio > 1 ? 'cp-ov' : '') + '" style="width:' + Math.min(100, ratio * 100) + '%"></i></span>de ' + (est ? K.fH(est) : '—') + ' estimadas' + (e === 2 ? ' · <span class="cp-pulse2"></span>en curso' : '') + '</small></div></div>' +
      '<div class="cp-vd">' + vieneDe(F) + '</div>' +
      '<ol class="cp-flow cp-f5" aria-label="Estado de la OT">' + FLUJO.map(function (l, i) { return '<li class="' + (i < fi ? 'cp-ok' : i === fi ? 'cp-on' : '') + '"><i>' + (i < fi ? ic('check', 12) : i + 1) + '</i><span>' + l + '</span></li>'; }).join('') + '</ol></section>';
  }
  function tabsF(F) {
    var np = F.pasos.length, hechos = F.pasos.filter(function (p) { return +p.otp_resultado_paso !== 4; }).length, ne = (F.evidencias || []).filter(function (a) { return !a.ES_FIRMA; }).length;
    var T = [['resumen', 'Resumen', null], ['pasos', 'Pasos', np ? hechos + '/' + np : null], ['rep', 'Repuestos', F.repuestos.length], ['cierre', 'Cierre', null]];
    return '<div class="cp-tabs" role="tablist">' + T.map(function (t) { return '<button type="button" role="tab" aria-selected="' + (U.tab === t[0]) + '" data-a="ottab" data-v="' + t[0] + '">' + t[1] + (t[2] != null ? '<em>' + t[2] + '</em>' : '') + '</button>'; }).join('') + '</div>';
  }
  var fact = function (k, v) { return '<div><span>' + k + '</span><b>' + v + '</b></div>'; };

  /* ---------------------------------------------------------------- Resumen */
  function iniEdicion(F) {
    var o = F.ot;
    return { titulo: o.otr_titulo || '', desc: o.otr_descripcion || '', notas: o.otr_notas || '', prio: +o.otr_orden_trabajo_prioridad, estr: +o.otr_orden_trabajo_estrategia, fecha: fe(o.otr_fecha_programada_utc), hora: he(o.otr_fecha_programada_utc), dur: o.otr_duracion_estimada_minuto ? String(Math.round(o.otr_duracion_estimada_minuto / 6) / 10).replace('.', ',') : '', permiso: !!o.otr_requiere_permiso, err: false, busy: false };
  }
  var PE = function (e) {
    return { t: 'Editar la orden', s: otTxt(U.ficha.ot.otr_correlativo) + ' · se guarda al pulsar «Guardar cambios»', w: 'n',
      b: '<div class="cp-fld"><label for="edT">Título <small>obligatorio</small></label><input id="edT" class="cp-inp' + (e.err && !e.titulo.trim() ? ' cp-err' : '') + '" data-pv="ed_titulo" value="' + esc(e.titulo) + '" autocomplete="off"></div>' +
        '<div class="cp-fld"><label for="edD">Qué hacer</label><textarea id="edD" class="cp-inp" rows="4" data-pv="ed_desc">' + esc(e.desc) + '</textarea></div>' +
        '<div class="cp-fld"><label>Prioridad</label>' + seg(PRIO, 'ored', 'prio', e.prio) + '</div>' +
        '<div class="cp-fld2"><div class="cp-fld"><label>Estrategia</label>' + K.combo('edEstr', Object.keys(ESTRATEGIAS).map(function (k) { return { id: +k, n: ESTRATEGIAS[k] }; }), e.estr, { etiqueta: 'Estrategia', ph: 'Rutinario' }) + '</div>' +
        '<div class="cp-fld"><label for="edDu">Duración estimada (horas)</label><input id="edDu" class="cp-inp" data-pv="ed_dur" value="' + esc(e.dur) + '" inputmode="decimal" placeholder="Ej.: 2"></div></div>' +
        '<div class="cp-fld2"><div class="cp-fld"><label>Fecha programada</label>' + K.fecha('ed_fecha', K.deDN(e.fecha), { ph: 'dd-mm-aaaa' }) + '</div><div class="cp-fld"><label>Hora</label>' + K.combo('edHora', HORAS.map(function (h) { return { id: h, n: h }; }), e.hora, { etiqueta: 'Hora', ph: '08:00' }) + '</div></div>' +
        '<label class="cp-sw"><input type="checkbox" data-pv="ed_permiso"' + (e.permiso ? ' checked' : '') + '><i></i>Requiere permiso de trabajo</label>' +
        '<div class="cp-fld" style="margin-top:12px"><label for="edN">Notas</label><textarea id="edN" class="cp-inp" rows="2" data-pv="ed_notas">' + esc(e.notas) + '</textarea></div>' + choquesHTML(e.choq),
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (e.busy ? ' cp-load' : '') + '" data-a="otguardar">' + (e.choq && e.choq.length ? ic('alert', 16) + 'Guardar igual' : 'Guardar cambios') + '</button></span>' };
  };
  var PQ = function (a) {
    var c = U.cat, ya = U.ficha.asignaciones.map(function (x) { return +x.ota_usuario; });
    if (!c) return { t: a.resp ? 'Agregar responsable' : 'Agregar al equipo', b: '<div class="cp-sk" style="height:46px"></div>', w: 'n' };
    var lista = a.tipo === 1 ? c.personas.filter(function (p) { return ya.indexOf(+p.ID) < 0; }).map(function (p) { return { id: p.ID, n: p.NOMBRE, sub: [p.PERFIL, p.ESPECIALIDAD].filter(Boolean).join(' · ') || 'Sin perfil', img: p.FOTO || '', ini: K.ini(p.NOMBRE) }; }) : c.proveedores.map(function (p) { return { id: p.ID, n: p.NOMBRE }; });
    return { t: a.resp ? 'Agregar responsable' : 'Agregar al equipo', s: otTxt(U.ficha.ot.otr_correlativo) + ' · queda en la bitácora', w: 'n',
      b: '<div class="cp-segc" style="margin-bottom:12px"><button type="button" data-a="otatipo" data-v="1" aria-pressed="' + (a.tipo === 1) + '">Persona</button><button type="button" data-a="otatipo" data-v="2" aria-pressed="' + (a.tipo === 2) + '">Empresa externa</button></div>' +
        '<div class="cp-fld"><label>' + (a.tipo === 1 ? 'Persona' : 'Empresa externa') + '</label>' + K.combo('otaQuien', lista, a.quien || '', { etiqueta: a.tipo === 1 ? 'Persona' : 'Empresa externa', ph: a.tipo === 1 ? 'Elige la persona…' : 'Elige la empresa…' }) +
          (a.quien && window.SigmaCarga ? '<div class="cp-carga-row">' + SigmaCarga.chipDe((a.tipo === 1 ? 'U:' : 'E:') + a.quien) + ' ' + SigmaCarga.boton((a.tipo === 1 ? 'U:' : 'E:') + a.quien, (lista.filter(function (x) { return String(x.id) === String(a.quien); })[0] || {}).n || '', '', null, U.ficha.ot.otr_fecha_programada_utc || '') + '</div>' : '') + '</div>' +
        '<div class="cp-fld"><label>Grupo de trabajo</label>' + K.combo('otaGrupo', [{ id: 0, n: 'Sin grupo' }].concat(c.grupos.map(function (g) { return { id: g.ID, n: g.NOMBRE }; })), a.grupo || 0, { etiqueta: 'Grupo de trabajo', ph: 'Sin grupo' }) + '</div>' +
        '<label class="cp-sw"><input type="checkbox" data-pv="oa_resp"' + (a.resp ? ' checked' : '') + '><i></i>Queda como responsable</label>' +
        '<div class="cp-fld" style="margin-top:12px"><label for="oaO">Observación</label><input id="oaO" class="cp-inp" data-pv="oa_obs" value="' + esc(a.obs) + '" placeholder="Opcional"></div>',
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (a.busy ? ' cp-load' : '') + '" data-a="otasignar"' + (a.quien ? '' : ' disabled') + '>Asignar</button></span>' };
  };
  function resumenHTML(F) {
    var o = F.ot, e = +o.otr_orden_trabajo_estado, np = F.pasos.length, hechos = F.pasos.filter(function (p) { return +p.otp_resultado_paso !== 4; }).length, ne = (F.evidencias || []).filter(function (a) { return !a.ES_FIRMA; }).length;
    var puede = editable(F), c = U.cat;
    var resps = F.asignaciones.filter(function (a) { return +a.ota_es_responsable === 1; });
    var apoyo = F.asignaciones.filter(function (a) { return +a.ota_es_responsable !== 1; });
    var fila = function (a, esResp) {
      var nombre = a.USUARIO_NOMBRE || a.PROVEEDOR_NOMBRE || a.GRUPO_NOMBRE || 'Sin nombre', pr = c && a.ota_usuario ? c.personas.filter(function (x) { return +x.ID === +a.ota_usuario; })[0] : null;
      var av = pr && pr.FOTO ? '<img class="cp-av cp-avi cp-lg" src="' + esc(pr.FOTO) + '" alt="" loading="lazy">' : K.avatar(nombre).replace('class="cp-av"', 'class="cp-av cp-lg"');
      var sub = pr ? [pr.PERFIL, pr.ESPECIALIDAD].filter(Boolean).join(' · ') : (a.ROL_NOMBRE || '');
      return '<div class="cp-rp">' + av + '<span class="cp-s"><b>' + esc(nombre) + (a.PROVEEDOR_NOMBRE && !a.USUARIO_NOMBRE ? ' <span class="cp-tg">Empresa externa</span>' : '') + '</b><small>' + esc(sub || 'Sin perfil') + (a.GRUPO_NOMBRE && a.USUARIO_NOMBRE ? ' · ' + esc(a.GRUPO_NOMBRE) : '') + '</small></span>' +
        cargaOT(a, nombre, sub, o.otr_fecha_programada_utc || o.otr_fecha_programada) +
        (puede ? (esResp ? '' : '<button type="button" class="cp-btn cp-plain cp-xs" data-a="otresp" data-v="' + a.ota_id + '">Hacer responsable</button>') + '<button type="button" class="cp-ibx" data-a="otquitar" data-v="' + a.ota_id + '" aria-label="Quitar a ' + esc(nombre) + '">' + ic('x', 13) + '</button>' : '') + '</div>';
    };
    var asig = '<section class="cp-card" id="asig"><div class="cp-sc-h"><h3>Asignación</h3>' + (e === 4 ? '<small>OT cerrada</small>' : !tieneAsignado(F) ? '<small style="color:var(--amber)">Elige al menos un responsable para pasarla a Asignada</small>' : '<small>Puede haber más de un responsable</small>') + '</div>' +
      '<div class="cp-sc-h" style="margin:4px 0"><h3 style="font-size:13px">Responsables</h3>' + (puede ? '<div class="cp-r"><button type="button" class="cp-btn cp-out cp-xs" data-a="otaadd" data-v="1">' + ic('plus', 13) + 'Agregar responsable</button></div>' : '') + '</div>' +
      (resps.length ? resps.map(function (a) { return fila(a, true); }).join('') : '<small class="cp-muted2">Sin responsable asignado.</small>') +
      (apoyo.length || puede ? '<div class="cp-sc-h" style="margin:16px 0 4px"><h3 style="font-size:13px">Equipo de apoyo</h3>' + (puede ? '<div class="cp-r"><button type="button" class="cp-btn cp-out cp-xs" data-a="otaadd">' + ic('plus', 13) + 'Agregar apoyo</button></div>' : '') + '</div>' +
        (apoyo.length ? apoyo.map(function (a) { return fila(a, false); }).join('') : '<small class="cp-muted2">Sin personas de apoyo.</small>') : '') + '</section>';
    var av = F.avisos.length ? '<div class="cp-mini">' + F.avisos.map(function (a) { return '<a class="cp-mini-r" href="' + esc(CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx#avisos') + '"><span class="cp-og">' + ic((ORIGEN[a.ORIGEN] || ORIGEN[1])[1], 13) + (ORIGEN[a.ORIGEN] || ORIGEN[1])[0] + '</span><span class="cp-s"><b>' + esc(a.TITULO) + '</b><small>' + esc(a.AVISO) + (a.RESUELTO_AQUI ? ' · resuelto por esta OT' : ' · encontrado al ejecutarla') + '</small></span>' + ic('chev', 14) + '</a>'; }).join('') + '</div>' : '<p class="cp-foot" style="margin:0">Cuando un aviso del mismo activo se vincula a esta OT aparece aquí.</p>';
    var COL = '<div style="min-width:0;display:flex;flex-direction:column;gap:14px">';
    return '<div class="cp-otg">' + COL +
      '<section class="cp-card"><div class="cp-sc-h"><h3>Qué hay que hacer</h3>' + (puede ? '<div class="cp-r"><button type="button" class="cp-btn cp-out cp-xs" data-a="otedit">' + ic('pencil', 13) + 'Editar</button></div>' : '') + '</div>' +
      '<p class="cp-otd">' + esc(o.otr_descripcion || 'Ejecutar la intervención según las tareas y procedimientos vinculados.') + '</p>' +
      '<div class="cp-facts" style="margin-top:12px">' + fact('Objeto mantenible', objChip(o)) + fact('Duración estimada', o.otr_duracion_estimada_minuto ? K.fH(o.otr_duracion_estimada_minuto) : '—') +
      fact('Requiere parada', necesitaRec(F) ? '<span style="color:var(--amber)">Sí, detiene el activo</span>' : 'No') + fact('Creada', f2(o.otr_fecha_creacion)) + (o.otr_notas ? fact('Notas', esc(o.otr_notas)) : '') + '</div>' +
      '<div class="cp-otsum"><button type="button" data-a="ottab" data-v="pasos">' + ic('check', 15) + '<b>' + hechos + '/' + np + '</b>tareas</button><button type="button" data-a="ottab" data-v="pasos">' + ic('clip', 15) + '<b>' + ne + '</b>evidencias</button><button type="button" data-a="ottab" data-v="rep">' + ic('box', 15) + '<b>' + F.repuestos.length + '</b>repuestos</button><button type="button" data-a="ottab" data-v="pasos">' + ic('clock', 15) + '<b>' + F.indisponibilidades.length + '</b>detenciones</button></div></section>' + asig + '</div>' + COL +
      '<section class="cp-card"><div class="cp-sc-h"><h3>Avisos vinculados</h3><small>' + (F.avisos.length ? pl(F.avisos.length, 'aviso', 'avisos') : 'Ninguno') + '</small></div>' + av + '</section>' + historialHTML(F) + '</div></div>';
  }

  /* ---------------------------------------------------------------- Trabajo (tareas, mano de obra, servicios, indisponibilidad) */
  function trabajoHTML(F) {
    var e = +F.ot.otr_orden_trabajo_estado, can = e === 2 && F.permisos.ejecutar, c = U.cat;
    var aviso = !can && e === 1 ? '<div class="cp-bnr cp-p">' + ic('help', 18) + '<span>Inicia el trabajo para marcar tareas y registrar el consumo.</span></div>' : '';
    var lista = F.pasos.length ? '<ol class="cp-osteps">' + F.pasos.map(function (p, i) {
      var r = +p.otp_resultado_paso;
      return '<li class="' + (r === 1 ? 'cp-ok' : '') + '"><label><input type="checkbox" class="cp-cbx" data-a="otstep" data-p="' + p.otp_id + '"' + (r === 1 ? ' checked' : '') + (can ? '' : ' disabled') + ' aria-label="Tarea ' + (i + 1) + '"><span class="cp-tk"><b>' + esc(p.otp_nombre) + '</b><small>' + (r !== 4 && p.EJECUTOR_NOMBRE ? esc(p.EJECUTOR_NOMBRE) + ' · ' : '') + (r === 2 ? 'No conforme' : r === 3 ? 'No aplica' : esc(p.otp_descripcion || '')) + (p.otp_resultado ? ' — ' + esc(p.otp_resultado) : '') + (+p.otp_obligatorio ? '' : ' · opcional') + '</small></span>' + (+p.otp_obligatorio && r === 4 ? '<span class="cp-tg cp-w">Obligatorio</span>' : '') + (r === 2 ? '<span class="cp-tg cp-w">No conforme</span>' : r === 3 ? '<span class="cp-tg">No aplica</span>' : '') + '</label>' +
        (can ? '<div style="display:flex;gap:6px;padding:0 0 8px 38px"><button type="button" class="cp-btn cp-plain cp-xs" data-a="otpaso" data-p="' + p.otp_id + '" data-v="2">No conforme</button><button type="button" class="cp-btn cp-plain cp-xs" data-a="otpaso" data-p="' + p.otp_id + '" data-v="3">No aplica</button></div>' : '') + '</li>';
    }).join('') + '</ol>' : '<p class="cp-foot" style="margin:0">Esta OT no tiene tareas. Agrégalas desde un procedimiento.</p>';
    var agregar = editable(F) && c && c.procedimientos.length ? '<div class="cp-sc-h" style="margin:14px 0 6px"><h3 style="font-size:13px">Agregar tareas desde un procedimiento</h3></div><div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap"><span style="flex:1;min-width:240px">' + K.combo('otProc', c.procedimientos.map(function (p) { return { id: p.ID, n: p.NOMBRE }; }), U.proc || '', { etiqueta: 'Procedimiento', ph: 'Elige un procedimiento…' }) + '</span><button type="button" class="cp-btn cp-out cp-sm" data-a="otproc"' + (U.proc ? '' : ' disabled') + '>' + ic('plus', 15) + 'Agregar tareas</button></div><small class="cp-muted2" style="display:block;margin-top:6px">Se copian el nombre y la instrucción de cada paso. Volver a agregarlo no duplica la lista.</small>' : '';
    var mo = tabla('minmax(0,1.6fr) minmax(0,1fr) 150px 80px 110px', ['Quién', 'Especialidad', 'Inicio', 'Horas', 'Costo'], F.manoObra.map(function (m) { return '<div class="cp-rw" style="grid-template-columns:minmax(0,1.6fr) minmax(0,1fr) 150px 80px 110px"><span class="cp-s"><b>' + esc(m.USUARIO_NOMBRE || m.PROVEEDOR_NOMBRE || '—') + '</b>' + (+m.HORA_EXTRA ? '<small>Hora extra</small>' : '') + '</span><span>' + esc(m.ESPECIALIDAD || '—') + '</span><span>' + f2(m.omo_fecha_inicio_utc) + '</span><span>' + K.fN((+m.MINUTOS || 0) / 60, 1) + ' h</span><span>' + (m.COSTO != null ? esc(m.MONEDA || '') + ' ' + K.fN(m.COSTO, 0) : '—') + '</span></div>'; }), 'Todavía no hay horas registradas por quienes ejecutan.');
    return aviso + '<section class="cp-card"><div class="cp-sc-h"><h3>Tareas</h3><small>Acciones concretas que alguien realiza</small></div>' + lista + agregar + '</section>' +
      '<section class="cp-card"><div class="cp-sc-h"><h3>Mano de obra</h3><small>Horas registradas por quienes ejecutan</small></div>' + mo + '</section>' +
      serviciosHTML(F) + indispHTML(F) + evidenciasHTML(F);
  }
  /* HU-117 · Lo que se le pagó a un tercero. El monto se suma al costo de terceros SEPARADO POR MONEDA
     (nunca UF con pesos) y cada servicio necesita el informe del proveedor para poder cerrar la OT. */
  var dec = function (m) { return m === 'UF' ? 2 : 0; };
  function svPuede(F) { return F.permisos.crear && +F.ot.otr_orden_trabajo_estado < 4; }
  function serviciosHTML(F) {
    var puede = svPuede(F), cols = 'minmax(0,1.3fr) minmax(0,1.7fr) 130px minmax(0,1fr)' + (puede ? ' 76px' : '');
    var filas = F.servicios.map(function (s) {
      var inf = s.INFORME_URL ? '<a class="cp-tg cp-c" href="' + esc(s.INFORME_URL) + '" target="_blank" rel="noopener">' + ic('check', 11) + 'Informe</a>'
        : puede ? '<label class="cp-btn cp-out cp-xs" style="cursor:pointer">' + ic('plus', 12) + 'Adjuntar informe<input type="file" accept="application/pdf,image/*" data-svinf="' + s.ots_id + '" hidden></label>' : '<span class="cp-tg cp-w">Sin informe</span>';
      return '<div class="cp-rw" style="grid-template-columns:' + cols + '"><span class="cp-s"><b>' + esc(s.PROVEEDOR_NOMBRE || '—') + '</b>' + (s.DOCUMENTO ? '<small>Doc. ' + esc(s.DOCUMENTO) + '</small>' : '') + '</span>' +
        '<span class="cp-s"><b>' + esc(s.TIPO || '') + '</b><small>' + esc(s.DESCRIPCION || '') + '</small></span>' +
        '<span style="font-weight:800">' + esc(s.MONEDA || '') + ' ' + K.fN(s.COSTO, dec(s.MONEDA)) + '</span><span>' + inf + '</span>' +
        (puede ? '<span style="display:flex;gap:4px;justify-content:flex-end"><button type="button" class="cp-ibx" data-a="otsvedit" data-v="' + s.ots_id + '" aria-label="Editar servicio">' + ic('pencil', 13) + '</button><button type="button" class="cp-ibx" data-a="otsvdel" data-v="' + s.ots_id + '" aria-label="Quitar servicio">' + ic('x', 13) + '</button></span>' : '') + '</div>';
    });
    var tot = (F.serviciosTotal || []).map(function (x) { return '<span class="cp-tg cp-p" style="font-size:12px">' + esc(x.MONEDA) + ' ' + K.fN(x.TOTAL, dec(x.MONEDA)) + '</span>'; }).join(' ');
    var sinInf = F.servicios.filter(function (s) { return !s.INFORME_URL; }).length;
    return '<section class="cp-card" id="otServicios"><div class="cp-sc-h"><h3>Servicios contratados</h3><small>' + (tot ? 'Costo de terceros ' + tot : 'Lo que se le pagó a un tercero por esta intervención') + '</small>' +
      (puede ? '<div class="cp-r"><button type="button" class="cp-btn cp-out cp-xs" data-a="otsvnew">' + ic('plus', 13) + 'Registrar servicio</button></div>' : '') + '</div>' +
      tabla(cols, ['Proveedor', 'Servicio', 'Monto', 'Informe'].concat(puede ? [''] : []), filas, 'Sin servicios contratados.') +
      (sinInf ? '<p class="cp-foot" style="margin:8px 0 0;color:var(--warning)">' + ic('alert', 13) + ' ' + (sinInf === 1 ? 'Un servicio no tiene' : sinInf + ' servicios no tienen') + ' el informe del proveedor: es obligatorio para cerrar la OT.</p>' : '') + '</section>';
  }
  /* El cajón del servicio: todo en una página, con el informe opcional en el mismo paso. */
  var PSV = function (s) {
    var c = U.svCat, prov = (U.cat && U.cat.proveedores || []).map(function (p) { return { id: p.ID, n: p.NOMBRE }; });
    if (!c || !U.cat) return { t: s.id ? 'Editar servicio' : 'Registrar servicio', w: 'n', b: '<div class="cp-sk" style="height:46px"></div><div class="cp-sk" style="height:46px;margin-top:10px"></div>' };
    var e = s.err;
    return { t: s.id ? 'Editar servicio' : 'Registrar servicio', s: otTxt(U.ficha.ot.otr_correlativo) + ' · costo de terceros', w: 'n',
      b: '<div class="cp-fld"><label>Proveedor</label>' + K.combo('svProv', prov, s.prov || '', { etiqueta: 'Proveedor', ph: prov.length ? 'Elige el proveedor…' : 'No hay contratistas registrados', err: e && !s.prov }) + '</div>' +
        '<div class="cp-fld"><label>Tipo de servicio</label>' + K.combo('svTipo', c.tipos.map(function (x) { return { id: x.ID, n: x.NOMBRE }; }), s.tipo || '', { etiqueta: 'Tipo de servicio', ph: 'Elige el tipo…', err: e && !s.tipo }) + '</div>' +
        '<div class="cp-fld"><label for="svD">Descripción</label><textarea id="svD" class="cp-inp' + (e && !String(s.desc).trim() ? ' cp-err' : '') + '" rows="2" data-pv="sv_desc" placeholder="Qué hizo el proveedor">' + esc(s.desc) + '</textarea></div>' +
        '<div class="cp-fld2"><div class="cp-fld"><label for="svM">Monto</label><input id="svM" class="cp-inp' + (e && !(numero(s.monto) > 0) ? ' cp-err' : '') + '" data-pv="sv_monto" value="' + esc(s.monto) + '" inputmode="decimal" placeholder="Ej.: 350.000"></div>' +
        '<div class="cp-fld"><label>Moneda</label>' + K.combo('svMon', c.monedas.map(function (x) { return { id: x.ID, n: x.CODIGO + ' · ' + x.NOMBRE }; }), s.mon || '', { etiqueta: 'Moneda', ph: 'Moneda', err: e && !s.mon }) + '</div></div>' +
        '<div class="cp-fld2"><div class="cp-fld"><label for="svDoc">N.º de factura u orden de compra <small>opcional</small></label><input id="svDoc" class="cp-inp" data-pv="sv_doc" value="' + esc(s.doc) + '" maxlength="100"></div>' +
        '<div class="cp-fld"><label>Fecha del servicio</label>' + K.fecha('sv_fecha', K.deDN(s.fecha), { ph: 'dd-mm-aaaa' }) + '</div></div>' +
        (s.id ? '' : '<div class="cp-fld"><label>Informe del proveedor <small>PDF o imagen · puedes adjuntarlo después</small></label><input type="file" class="cp-inp" accept="application/pdf,image/*" data-svnuevo="1">' + (s.archivo ? '<small class="cp-muted2">' + esc(s.archivo.name) + '</small>' : '') + '</div>') +
        (e ? '<div class="cp-bnr cp-w" style="margin-top:10px">' + ic('alert', 16) + '<span>Completa proveedor, tipo, descripción, monto mayor que cero y moneda.</span></div>' : ''),
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (s.busy ? ' cp-load' : '') + '" data-a="otsvsave">' + ic('check', 16) + (s.id ? 'Guardar cambios' : 'Registrar servicio') + '</button></span>' };
  };
  var numero = function (v) { var s = String(v || '').trim(); if (s.indexOf(',') >= 0) s = s.replace(/\./g, '').replace(',', '.'); else if (/^\d{1,3}(\.\d{3})+$/.test(s)) s = s.replace(/\./g, ''); var n = parseFloat(s); return isNaN(n) ? 0 : n; };
  var leerArchivo = function (f) { return new Promise(function (ok, mal) { var r = new FileReader(); r.onload = function () { ok(r.result); }; r.onerror = function () { mal(new Error('No se pudo leer el archivo.')); }; r.readAsDataURL(f); }); };
  function subirInforme(servicio, f) {
    if (!f) return Promise.resolve();
    if (f.size > 10 * 1024 * 1024) return Promise.reject(new Error('El informe supera los 10 MB.'));
    return leerArchivo(f).then(function (d) { return llamar('InformeServicio', { servicio: +servicio, nombre: f.name, datos: d }, 'Informe adjuntado.'); });
  }
  function abrirServicio(s0) {
    var s = { id: s0 ? +s0.ots_id : 0, prov: s0 ? s0.PROVEEDOR_ID : '', tipo: s0 ? s0.TIPO_ID : '', desc: s0 ? s0.DESCRIPCION : '', monto: s0 ? String(s0.COSTO).replace('.', ',') : '', mon: s0 ? s0.MONEDA_ID : '', doc: s0 ? s0.DOCUMENTO : '', fecha: s0 && s0.ots_fecha_servicio_utc ? K.fDN(K.dIso(s0.ots_fecha_servicio_utc)) : K.fDN(K.TODAY), archivo: null, err: false, busy: false };
    if (!s.mon && U.svCat) { var clp = U.svCat.monedas.filter(function (m) { return m.CODIGO === 'CLP'; })[0]; if (clp) s.mon = clp.ID; }
    U.sv = s; K.Panel.open({ render: function () { return PSV(U.sv); }, st: s, onclose: function () { U.sv = null; } });
    var pide = [];
    if (!U.svCat) pide.push(api('ServicioCatalogos', {}).then(function (c) { U.svCat = c; if (!s.mon) { var clp = c.monedas.filter(function (m) { return m.CODIGO === 'CLP'; })[0]; if (clp) s.mon = clp.ID; } }));
    if (!U.cat) pide.push(api('Catalogos', { planta: 0 }).then(function (c) { U.cat = c; }));
    if (pide.length) Promise.all(pide).then(function () { if (K.Panel.state() === s) K.Panel.paint(); }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  }
  function indispHTML(F) {
    var puede = F.permisos.reportar && +F.ot.otr_orden_trabajo_estado < 4 && +F.ot.otr_activo > 0;
    var lista = tabla('150px 150px 90px minmax(0,1fr) 120px', ['Inicio', 'Término', 'Duración', 'Motivo', 'Tipo'], F.indisponibilidades.map(function (i) {
      return '<div class="cp-rw" style="grid-template-columns:150px 150px 90px minmax(0,1fr) 120px"><span>' + f2(i.ain_fecha_inicio_utc) + '</span><span>' + (i.ain_fecha_fin_utc ? f2(i.ain_fecha_fin_utc) : '<span class="cp-tg cp-w">En curso</span>') + '</span><span>' + K.fH(i.MINUTOS_ACUMULADOS || i.ain_minuto || 0) + '</span><span class="cp-s"><b>' + esc(i.MOTIVO_NOMBRE || 'Sin motivo') + '</b>' + (i.ain_motivo ? '<small>' + esc(i.ain_motivo) + '</small>' : '') + '</span><span>' + (i.ain_planificada ? 'Planificada' : 'No planificada') + (i.ain_detuvo_produccion ? '<br><small class="cp-muted2">Detuvo producción</small>' : '') + '</span></div>'; }), 'No se ha registrado ninguna detención del activo por esta OT.');
    var imp = F.indisponibilidades.reduce(function (a, i) { return a + (+(i.MINUTOS_ACUMULADOS || i.ain_minuto || 0)); }, 0);
    var s = '<section class="cp-card"><div class="cp-sc-h"><h3>Indisponibilidad del activo</h3><small>' + (imp ? K.fH(imp) + ' en total' : 'Sin detenciones') + '</small></div>' + lista + '</section>';
    if (!puede) return s;
    var d = U.ind || (U.ind = { ini: K.fDN(K.TODAY), hini: '08:00', fin: '', hfin: '', plan: 1, detuvo: false, motivo: 0, det: '', err: false, busy: false });
    return s + '<section class="cp-card"><div class="cp-sc-h"><h3>Registrar indisponibilidad</h3></div>' +
      '<div class="cp-grid2c"><div class="cp-fld"><label>Empezó</label>' + K.fecha('in_ini', K.deDN(d.ini), { ph: 'dd-mm-aaaa', err: d.err && !d.ini }) + '</div><div class="cp-fld"><label>Hora</label>' + K.combo('inHIni', HORAS.map(function (h) { return { id: h, n: h }; }), d.hini, { etiqueta: 'Hora de inicio', ph: '08:00' }) + '</div>' +
      '<div class="cp-fld"><label>Terminó <small>vacío si sigue detenido</small></label>' + K.fecha('in_fin', K.deDN(d.fin), { ph: 'dd-mm-aaaa' }) + '</div><div class="cp-fld"><label>Hora</label>' + K.combo('inHFin', HORAS.map(function (h) { return { id: h, n: h }; }), d.hfin, { etiqueta: 'Hora de término', ph: '—' }) + '</div>' +
      '<div class="cp-fld"><label>Tipo</label><div class="cp-segc"><button type="button" data-a="otind" data-k="plan" data-v="1" aria-pressed="' + (+d.plan === 1) + '">Planificada</button><button type="button" data-a="otind" data-k="plan" data-v="0" aria-pressed="' + (+d.plan === 0) + '">No planificada</button></div></div>' +
      '<div class="cp-fld"><label>Motivo</label>' + K.combo('inMotivo', [{ id: 0, n: 'Sin motivo' }].concat(Object.keys(MOTIVOS_IND).map(function (k) { return { id: +k, n: MOTIVOS_IND[k] }; })), d.motivo, { etiqueta: 'Motivo', ph: 'Sin motivo' }) + '</div></div>' +
      '<label class="cp-sw"><input type="checkbox" data-pv="in_detuvo"' + (d.detuvo ? ' checked' : '') + '><i></i>Detuvo la producción</label>' +
      '<div class="cp-fld" style="margin-top:12px"><label for="inD">Detalle</label><textarea id="inD" class="cp-inp" rows="2" data-pv="in_det">' + esc(d.det) + '</textarea></div>' + (d.err ? msgErr('Indica el día en que empezó la detención.') : '') +
      '<div style="display:flex;justify-content:flex-end"><button type="button" class="cp-btn cp-out' + (d.busy ? ' cp-load' : '') + '" data-a="otindok">' + ic('plus', 15) + 'Registrar</button></div></section>';
  }

  /* ---------------------------------------------------------------- Evidencias, Repuestos, Historial */
  function evidenciasHTML(F) {
    var ev = (F.evidencias || []).filter(function (a) { return !a.ES_FIRMA; });
    return '<section class="cp-card"><div class="cp-sc-h"><h3>Evidencias</h3><small>' + pl(ev.length, 'archivo', 'archivos') + '</small></div>' + (ev.length ? '<div class="cp-evg">' + ev.map(function (a) {
      var cuerpo = a.IMAGEN ? '<img src="' + esc(a.URL) + '" alt="' + esc(a.NOMBRE) + '" loading="lazy">' : '<span class="cp-ev-i">' + ic(a.VIDEO ? 'gauge' : 'clip', 26) + '</span>';
      return '<a class="cp-ev2" href="' + esc(a.URL) + '" target="_blank" rel="noopener"><figure style="margin:0">' + cuerpo + '<figcaption><b>' + esc(a.NOMBRE) + '</b><small>' + (a.PASO ? esc(a.PASO) + ' · ' : '') + esc(a.QUIEN || '') + '</small></figcaption></figure></a>';
    }).join('') + '</div>' : '<div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('clip', 20) + '</span><b>Sin evidencias aún</b>Las fotos, videos y documentos de respaldo se adjuntan desde la app al ejecutar el trabajo.</div>') + '</section>';
  }
  function repuestosHTML(F) {
    var e = +F.ot.otr_orden_trabajo_estado, cols = '96px minmax(0,1fr) 90px 90px 90px 90px';
    return '<section class="cp-card">' + (F.repuestos.length ? '<div class="cp-rows"><div class="cp-rw cp-h" style="grid-template-columns:' + cols + '"><span>Código</span><span>Repuesto · material del trabajo</span><span>Planificada</span><span>Reservada</span><span>Consumida</span><span>Devuelta</span></div>' +
      F.repuestos.map(function (r) { return '<div class="cp-rw" style="grid-template-columns:' + cols + '"><span class="cp-mono">' + esc(r.REPUESTO_CODIGO) + '</span><span class="cp-s"><b>' + esc(r.REPUESTO_NOMBRE) + '</b><small>' + esc(r.UNIDAD || '') + (r.LOTE ? ' · lote ' + esc(r.LOTE) : '') + '</small></span><span class="cp-tn">' + K.fN(r.PLANIFICADA, 2) + '</span><span class="cp-tn">' + K.fN(r.RESERVADA, 2) + '</span><span class="cp-tn">' + K.fN(r.CONSUMIDA, 2) + '</span><span class="cp-tn">' + K.fN(r.DEVUELTA, 2) + '</span></div>'; }).join('') + '</div>' :
      '<div class="cp-empty" style="border:0"><b>Esta OT no lleva repuestos</b></div>') + '<p class="cp-foot">El repuesto es material que se consume en el trabajo; el objeto mantenible es ' + objChip(F.ot) + '.</p></section>';
  }
  function historialHTML(F) {
    var items = F.bitacora.map(function (b) { return { t: b.MOTIVO || (b.ESTADO_NUEVO ? 'Pasó a ' + (ESTADOS[b.ESTADO_NUEVO] || [''])[0].toLowerCase() : ''), s: f2(b.FECHA) + (b.QUIEN ? ' · ' + b.QUIEN : '') }; });
    return '<section class="cp-card"><div class="cp-sc-h"><h3>Bitácora</h3></div>' + (items.length ? '<ol class="cp-tl cp-tl2">' + items.map(function (x) { return '<li><b>' + esc(x.t) + '</b><small>' + esc(x.s) + '</small></li>'; }).join('') + '</ol>' : '<p class="cp-foot" style="margin:0">Sin movimientos.</p>') + '</section>';
  }

  /* ---------------------------------------------------------------- Cierre */
  function sigBox(F, rol, puede) {
    var s = firmaDe(F, rol), R = ROLES[rol], fr = U.fr || (U.fr = { obs: '', err: '', busy: '' });
    var head = '<div class="cp-sg-h"><span><b>' + R[0] + '</b><small>' + R[2] + '</small></span>';
    if (s) return '<div class="cp-sg cp-ok">' + head + '<span class="cp-vst cp-v-ok"><i></i>Firmado</span></div><div class="cp-sg-img">' + (s.FIRMA ? '<img src="' + esc(s.FIRMA) + '" alt="Firma de ' + esc(s.QUIEN) + '">' : '') + '</div><div class="cp-sg-f"><b>' + esc(s.QUIEN) + '</b><small>' + f2(s.FECHA) + (s.OBSERVACION ? ' · ' + esc(s.OBSERVACION) : '') + '</small></div></div>';
    if (!puede) return '<div class="cp-sg cp-pend">' + head + '<span class="cp-vst"><i></i>Pendiente</span></div><div class="cp-sg-img cp-sg-wait">' + ic('pencil', 18) + '<span>' + (rol === 'ej' ? 'Firma al completar el trabajo' : 'Se firma cuando la OT está completada') + '</span></div></div>';
    return '<div class="cp-sg cp-edit' + (fr.err === rol ? ' cp-err' : '') + '" id="sgb-' + rol + '">' + head + '<span class="cp-vst cp-v-warn"><i></i>Por firmar</span></div>' +
      '<div class="cp-fld cp-sg-n"><label>Firma de</label><input class="cp-inp" value="' + esc(F.yo || '') + '" readonly></div>' +
      (rol !== 'ej' ? '<div class="cp-fld"><label for="sgo-' + rol + '">Observación</label><input id="sgo-' + rol + '" class="cp-inp" data-pv="sg_obs_' + rol + '" value="' + esc(fr['obs_' + rol] || '') + '" placeholder="Opcional al aprobar; obligatoria al rechazar"></div>' : '') +
      '<div class="cp-sg-pad"><canvas data-sig="' + rol + '" aria-label="Recuadro para firmar: dibuja tu firma con el dedo o el mouse"></canvas><span class="cp-sg-ph"' + (FIRMAS[rol] ? ' hidden' : '') + '>' + ic('pencil', 16) + 'Firma aquí con el dedo o el mouse</span><span class="cp-sg-line"></span></div>' +
      '<div class="cp-sg-a"><button type="button" class="cp-btn cp-plain cp-xs" data-a="otsigclr" data-v="' + rol + '">Limpiar</button>' + (rol !== 'ej' ? '<button type="button" class="cp-btn cp-out cp-xs" data-a="otsigno" data-v="' + rol + '">Rechazar</button>' : '') +
      '<button type="button" class="cp-btn cp-pri cp-sm' + (fr.busy === rol ? ' cp-load' : '') + '" data-a="otsigok" data-v="' + rol + '"' + (FIRMAS[rol] ? '' : ' disabled') + '>' + ic('check', 14) + 'Confirmar firma</button></div></div>';
  }
  function hallazgoHTML(F) {
    var hf = U.hf || (U.hf = { t: '', comp: 0, sev: 2, d: '', err: false, busy: false }), c = U.cat;
    var comps = [{ id: 0, n: 'Activo completo' }].concat(((c && c.componentes) || []).filter(function (x) { return +x.ACTIVO_ID === +F.ot.otr_activo; }).map(function (x) { return { id: x.ID, n: x.NOMBRE }; }));
    return '<section class="cp-card"><div class="cp-sc-h"><h3>¿Encontraste algo que no es parte de esta OT?</h3><small>Se crea un aviso «Hallazgo en OT»</small></div>' +
      '<div class="cp-grid2c"><div class="cp-fld" style="grid-column:1/-1"><label for="hft">Qué viste</label><input id="hft" class="cp-inp' + (hf.err && (hf.t || '').trim().length < 5 ? ' cp-err' : '') + '" data-pv="hf_t" value="' + esc(hf.t) + '" placeholder="Ej.: Rodamiento del tambor de cola con juego" autocomplete="off"></div>' +
      '<div class="cp-fld"><label>Objeto mantenible</label>' + K.combo('hfComp', comps, hf.comp || 0, { etiqueta: 'Componente', ph: 'Activo completo' }) + '</div>' +
      '<div class="cp-fld"><label>Severidad</label>' + seg(PRIO, 'othsev', 'sev', hf.sev) + '</div></div>' +
      '<div style="display:flex;justify-content:flex-end;margin-top:10px"><button type="button" class="cp-btn cp-out cp-sm' + (hf.busy ? ' cp-load' : '') + '" data-a="othok">' + ic('bell', 15) + 'Crear aviso</button></div></section>';
  }
  function cierreHTML(F) {
    var o = F.ot, e = +o.otr_orden_trabajo_estado, p = F.permisos, fc = U.formCierre, corr = +o.otr_orden_trabajo_tipo === 2, rec = necesitaRec(F);
    var okTxt = (fc.informe || '').trim().length >= 10;
    var informado = !!(o.otr_resultado || '').trim() && e >= 3;
    var pasos = [['Informe', informado || (e === 2 && okTxt)], ['Firma de quien ejecutó', !!firmaDe(F, 'ej')]].concat(rec ? [['Recepción del área', !!firmaDe(F, 'rec')]] : [], [['Firma de quien aprueba', !!firmaDe(F, 'sup')], ['Cerrada', e === 4]]);
    var steps = '<ol class="cp-cstep">' + pasos.map(function (x, i) { return '<li class="' + (x[1] ? 'cp-ok' : '') + '"><i>' + (x[1] ? ic('check', 11) : i + 1) + '</i>' + x[0] + '</li>'; }).join('') + '</ol>';
    if (e === 1) return '<section class="cp-card"><div class="cp-empty" style="border:0"><span class="cp-ei">' + ic('clock', 20) + '</span><b>El cierre se registra al terminar el trabajo</b>' + (tieneAsignado(F) ? 'Inicia la OT, marca las tareas y luego vuelve aquí para el informe y las firmas.' : 'Primero asigna un responsable; luego inicia la OT.') + (p.ejecutar && tieneAsignado(F) ? '<button type="button" class="cp-btn cp-pri cp-sm" data-a="otiniciar">Iniciar trabajo</button>' : '') + '</div></section>';
    var sigs = function (puede) { return '<div class="cp-sgg">' + ['ej'].concat(rec ? ['rec'] : [], ['sup']).map(function (r) { return sigBox(F, r, puede(r)); }).join('') + '</div>'; };
    if (e === 4) {
      var hrs = +o.otr_duracion_real_minuto || minutosReg(F);
      return '<section class="cp-card cp-acta"><div class="cp-acta-h"><div><span class="cp-ey2">' + ic('check', 13) + 'Acta de cierre</span><h3>' + otTxt(o.otr_correlativo) + ' · ' + esc(o.otr_titulo) + '</h3><small>' + esc(o.ACTIVO_NOMBRE) + ' · ' + esc(o.ACTIVO_CODIGO) + (o.COMPONENTE_NOMBRE ? ' › ' + esc(o.COMPONENTE_NOMBRE) : '') + ' · cerrada ' + f2(o.otr_fecha_cierre) + (o.CIERRE_USUARIO_NOMBRE ? ' por ' + esc(o.CIERRE_USUARIO_NOMBRE) : '') + '</small></div>' + estChip(4) + '</div>' +
        '<div class="cp-facts"><div style="grid-column:1/-1"><span>Trabajo realizado</span><b style="font-weight:600">' + esc(o.otr_resultado || 'Sin informe.') + '</b></div>' + fact('Horas reales', hrs ? fHM(hrs) : '—') + fact('Motivo de cierre', esc(o.CIERRE_MOTIVO_NOMBRE || '—')) + (o.otr_notas ? fact('Notas', esc(o.otr_notas)) : '') + '</div>' +
        '<p class="cp-foot" style="margin:10px 0 0">' + (+o.otr_orden_trabajo_origen === 2 ? 'La ejecución del plan cuenta como cumplida. ' : '') + (F.avisos.some(function (a) { return a.RESUELTO_AQUI; }) ? 'Los avisos vinculados quedaron resueltos.' : '') + '</p><h4 class="cp-acta-t">Firmas</h4>' + sigs(function () { return false; }) + '</section>';
    }
    if (e === 3) {
      var miss = faltan(F), svMiss = F.servicios.filter(function (s) { return !s.INFORME_URL; }).length;
      return '<section class="cp-card">' + steps + '<div class="cp-sc-h"><h3>Informe de cierre</h3></div><div class="cp-facts"><div style="grid-column:1/-1"><span>Trabajo realizado</span><b style="font-weight:600">' + esc(o.otr_resultado || 'Sin informe.') + '</b></div>' + fact('Horas reales', (+o.otr_duracion_real_minuto || minutosReg(F)) ? fHM(+o.otr_duracion_real_minuto || minutosReg(F)) : '—') + (o.otr_notas ? fact('Notas', esc(o.otr_notas)) : '') + '</div></section>' +
        (svMiss ? '<div class="cp-bnr cp-w">' + ic('alert', 18) + '<span>Falta el informe del proveedor en ' + (svMiss === 1 ? 'un servicio contratado' : svMiss + ' servicios contratados') + '. Es obligatorio para cerrar. <button type="button" class="cp-lnk" data-a="otsvir">Adjuntarlo</button></span></div>' : '') +
        '<section class="cp-card"><div class="cp-sc-h"><h3>Firmas</h3><small>' + (miss.length ? (miss.length === 1 ? 'Falta una firma' : 'Faltan ' + miss.length + ' firmas') + ' para cerrar' : 'Todo firmado: ya se puede cerrar') + '</small></div>' + sigs(function (r) { return r !== 'ej' && p.validar && (r !== 'sup' || p.cerrar); }) +
        (p.cerrar ? '<div class="cp-fld" style="margin-top:12px"><label>Motivo de cierre</label>' + K.combo('ciMotivo', (F.motivos || []).map(function (m) { return { id: m.ID, n: m.NOMBRE }; }), fc.motivo || 1, { etiqueta: 'Motivo de cierre', ph: 'Trabajo realizado' }) + '</div>' : '') +
        '<div class="cp-sg-end">' + (p.cerrar ? '<button type="button" class="cp-btn cp-plain" data-a="otdev">Devolver a ejecución</button><button type="button" class="cp-btn cp-pri' + (fc.busy ? ' cp-load' : '') + '" data-a="otcerrar"' + (miss.length || svMiss ? ' aria-disabled="true"' : '') + '>' + ic('check', 16) + 'Cerrar OT</button>' : '<span class="cp-sg-why">Esperando que alguien con la facultad de cerrar OT revise el informe y la cierre.</span>') + '</div></section>' + hallazgoHTML(F);
    }
    /* en ejecución */
    var causas = CAUSAS.map(function (x) { return { id: x, n: x }; });
    return '<section class="cp-card">' + steps + '<div class="cp-sc-h"><h3>Informe de cierre</h3><small>Lo completa quien ejecutó el trabajo</small></div>' +
      '<div class="cp-fld"><label for="ciInf">Trabajo realizado <small>obligatorio</small></label><textarea id="ciInf" class="cp-inp' + (fc.err && !okTxt ? ' cp-err' : '') + '" rows="3" data-pv="ci_informe" placeholder="Qué se hizo, qué se cambió y cómo quedó">' + esc(fc.informe) + '</textarea>' + (fc.err && !okTxt ? msgErr('Describe el trabajo en al menos 10 caracteres.') : '') + '</div>' +
      '<div class="cp-grid2c" style="margin-top:10px"><div class="cp-fld"><label for="ciH">Horas reales</label><div class="cp-unit"><input id="ciH" class="cp-inp" data-pv="ci_horas" value="' + esc(fc.horas) + '" inputmode="decimal" placeholder="Ej.: 2,5"><span class="cp-u">horas</span></div></div>' +
      (corr ? '<div class="cp-fld"><label>Causa de la falla</label>' + K.combo('ciCausa', causas, fc.causa || '', { etiqueta: 'Causa de la falla', ph: 'Elige la causa', err: fc.err && !(fc.causa || '').trim() }) + '</div>' : '<div></div>') +
      '<div class="cp-fld" style="grid-column:1/-1"><label>Estado del activo al terminar</label><div class="cp-segc">' + [1, 2, 3].map(function (k) { return '<button type="button" data-a="otpost" data-v="' + k + '" aria-pressed="' + (+fc.post === k) + '">' + POST[k] + '</button>'; }).join('') + '</div></div></div></section>' +
      '<section class="cp-card"><div class="cp-sc-h"><h3>Firmas</h3><small>Quien ejecutó firma al completar; ' + (rec ? 'producción recibe el activo y ' : '') + 'quien tiene la facultad de cerrar aprueba el cierre</small></div>' + sigs(function (r) { return r === 'ej' && p.validar && p.ejecutar; }) +
      '<div class="cp-sg-end"><span class="cp-sg-why">' + (!okTxt ? 'Falta el informe' : !firmaDe(F, 'ej') ? 'Falta la firma de quien ejecutó' : 'Listo para completar') + '</span><button type="button" class="cp-btn cp-pri' + (fc.busy ? ' cp-load' : '') + '" data-a="otenviar"' + (okTxt && firmaDe(F, 'ej') ? '' : ' aria-disabled="true"') + '>' + ic('check', 16) + 'Firmar y completar</button></div></section>' + hallazgoHTML(F);
  }
  function fichaHTML() {
    var F = U.ficha; if (!F) return '';
    var t = U.tab === 'evi' ? 'pasos' : U.tab === 'his' ? 'resumen' : U.tab;
    var cuerpo = t === 'pasos' ? '<div class="cp-otb">' + trabajoHTML(F) + '</div>' : t === 'rep' ? '<div class="cp-otb">' + repuestosHTML(F) + '</div>' : t === 'cierre' ? '<div class="cp-otb">' + cierreHTML(F) + '</div>' : resumenHTML(F);
    return bc(F.ot) + cabecera(F) + tabsF(F) + cuerpo;
  }

  /* ---------------------------------------------------------------- firmas dibujadas (como el mockup: canvas por rol) */
  function montarFirmas() {
    Array.prototype.slice.call(document.querySelectorAll('canvas[data-sig]')).forEach(function (cv) {
      var rol = cv.getAttribute('data-sig'), r = cv.getBoundingClientRect(), dpr = window.devicePixelRatio || 1; if (!r.width) return;
      cv.width = Math.round(r.width * dpr); cv.height = Math.round(r.height * dpr);
      var ctx = cv.getContext('2d'); ctx.scale(dpr, dpr); ctx.lineWidth = 2.2; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.strokeStyle = '#1E2A5A';
      if (FIRMAS[rol]) { var im = new Image(); im.onload = function () { ctx.drawImage(im, 0, 0, r.width, r.height); }; im.src = FIRMAS[rol]; }
      var dib = false, pos = function (e) { var b = cv.getBoundingClientRect(); return [e.clientX - b.left, e.clientY - b.top]; };
      cv.style.touchAction = 'none';
      cv.addEventListener('pointerdown', function (e) { e.preventDefault(); dib = true; var p = pos(e); ctx.beginPath(); ctx.moveTo(p[0], p[1]); ctx.lineTo(p[0] + .1, p[1] + .1); ctx.stroke(); try { cv.setPointerCapture(e.pointerId); } catch (er) { } var ph = cv.parentElement.querySelector('.cp-sg-ph'); if (ph) ph.hidden = true; });
      cv.addEventListener('pointermove', function (e) { if (!dib) return; var p = pos(e); ctx.lineTo(p[0], p[1]); ctx.stroke(); });
      var fin = function () { if (!dib) return; dib = false; FIRMAS[rol] = cv.toDataURL('image/png'); var b = document.querySelector('[data-a=otsigok][data-v=' + rol + ']'); if (b) b.disabled = false; };
      cv.addEventListener('pointerup', fin); cv.addEventListener('pointerleave', fin);
    });
  }

  /* ---------------------------------------------------------------- pintado y carga */
  function pintar() {
    var b = $('#otRoot'); if (!b) return;
    var fo = K.grabFocus(b), sy = window.scrollY;
    b.innerHTML = U.ficha ? fichaHTML() : (U.cargandoFicha ? '<div class="cp-sk" style="height:200px;margin:12px"></div>' : listaHTML());
    K.putFocus(fo, b); K.conectarFechas(b); montarFirmas(); window.scrollTo(0, sy);
    L.heroRefresh();
  }
  function hashOt(q, t) { try { history.replaceState(null, '', '#ordenes' + (q ? '&ot=' + q + (t && t !== 'resumen' ? '&t=' + t : '') : '')); } catch (e) { } }
  function leerHash() { var o = {}; String(location.hash || '').replace(/^#/, '').split('&').forEach(function (kv) { var i = kv.indexOf('='); if (i > 0) o[kv.slice(0, i)] = kv.slice(i + 1); }); return o; }
  function cargarLista() {
    U.error = ''; U.lista = null; pintar();
    return api('Lista', { planta: L.planta() }).then(function (r) { U.lista = r.ots || []; U.perm = r.permisos || {}; pintar(); }).catch(function (e) { U.error = e.message || 'Error'; pintar(); });
  }
  function catalogos() {
    if (U.cat) return Promise.resolve(U.cat);
    return api('Catalogos', { planta: L.planta() }).then(function (c) { U.cat = c; return c; });
  }
  function reiniciarFormularios() { U.ed = null; U.asig = null; U.ind = null; U.fr = null; U.hf = null; U.confirma = false; U.proc = ''; FIRMAS.ej = ''; FIRMAS.rec = ''; FIRMAS.sup = ''; U.formCierre = { informe: '', horas: '', post: 0, causa: '', motivo: 1 }; }
  function abrir(q, tab) {
    U.cargandoFicha = true; U.ficha = null; U.tab = tab || 'resumen'; pintar();
    return Promise.all([api('Ficha', { token: q }), catalogos().catch(function () { return null; })]).then(function (r) {
      U.cargandoFicha = false; U.ficha = r[0]; reiniciarFormularios();
      hashOt(q, U.tab); document.title = otTxt(U.ficha.ot.otr_correlativo) + ' · Órdenes de trabajo · SIGMA'; pintar(); window.scrollTo(0, 0);
    }).catch(function (e) { try { console.error('OT ficha', e && e.stack || e); } catch (x) { } U.cargandoFicha = false; K.toastError(e); hashOt(''); pintar(); });
  }
  function aplicar(F, msg) { U.ficha = F; if (msg) K.toast(msg); pintar(); refrescarFila(F); }
  function refrescarFila(F) { (U.lista || []).forEach(function (o) { if (o.Q === F.q) o.ESTADO_ID = +F.ot.otr_orden_trabajo_estado; }); }
  function llamar(m, d, msg) {
    d = d || {}; d.token = U.ficha.q;
    return api(m, d).then(function (r) { aplicar(r.ficha || r, msg || (r.mensaje || '')); return r; }).catch(function (e) { K.toastError(e); pintar(); throw e; });
  }
  var nada = function () { };

  /* ---------------------------------------------------------------- acciones */
  var A = L.A;
  A.otreload = function () { cargarLista(); };
  A.otf = function (d) { U.f = d.v; pintar(); };
  A.otabrir = function (d) { if (d.q) abrir(d.q); };
  A.otlista = function () { U.ficha = null; hashOt(''); document.title = 'Órdenes de trabajo · SIGMA'; pintar(); };
  A.ottab = function (d) { U.tab = d.v; hashOt(U.ficha.q, U.tab); pintar(); window.scrollTo(0, 0); };
  A.otiniciar = function () { llamar('Iniciar', {}, 'Trabajo iniciado. Ya puedes marcar las tareas.').then(function () { U.tab = 'pasos'; hashOt(U.ficha.q, 'pasos'); pintar(); }).catch(nada); };
  /* tareas: la casilla es «conforme» (volver a marcarla la deja pendiente); No conforme y No aplica van aparte */
  A.otstep = function (d) {
    var p = U.ficha.pasos.filter(function (x) { return String(x.otp_id) === d.p; })[0];
    llamar('Paso', { paso: +d.p, resultado: p && +p.otp_resultado_paso === 1 ? 4 : 1, observacion: '' }).catch(nada);
  };
  A.otpaso = function (d) {
    var p = U.ficha.pasos.filter(function (x) { return String(x.otp_id) === d.p; })[0];
    var nuevo = +d.v; if (p && +p.otp_resultado_paso === nuevo) nuevo = 4;
    llamar('Paso', { paso: +d.p, resultado: nuevo, observacion: '' }).catch(nada);
  };
  /* editar la orden (panel lateral) */
  A.otedit = function () { U.ed = iniEdicion(U.ficha); K.Panel.open({ render: function () { return PE(U.ed); }, st: U.ed, onclose: function () { U.ed = null; } }); };
  A.ored = function (d) { var e = U.ed; if (!e) return; e[d.k] = +d.v; K.Panel.paint(); };
  A.otguardar = function () {
    var e = U.ed; if (!e) return;
    if (!e.titulo.trim()) { e.err = true; K.Panel.paint(); return; }
    var f = e.fecha ? K.deDN(e.fecha) : '', dur = parseFloat(String(e.dur || '').replace(',', '.')) || 0;
    var o = U.ficha.ot;
    var rec = (U.ficha.asignaciones || []).map(function (x) { return +x.ota_usuario ? 'U:' + x.ota_usuario : +x.ota_proveedor ? 'E:' + x.ota_proveedor : +x.ota_grupo_trabajo ? 'G:' + x.ota_grupo_trabajo : ''; }).filter(Boolean);
    if (choquesAntes(e, +o.otr_id, o.otr_activo, o.otr_activo_componente, f ? f + ' ' + (e.hora || '08:00') : '', Math.round(dur * 60), A.otguardar, rec)) return;
    e.busy = true; K.Panel.paint();
    llamar('Guardar', { titulo: e.titulo.trim(), descripcion: e.desc, notas: e.notas, prioridad: e.prio, estrategia: e.estr, fecha: f ? f + ' ' + (e.hora || '08:00') : '', duracionMin: Math.round(dur * 60), requierePermiso: !!e.permiso }, 'Cambios guardados.').then(function () { U.ed = null; K.Panel.close(); }).catch(function () { e.busy = false; K.Panel.paint(); });
  };
  /* equipo */
  A.otaadd = function (d) { U.asig = { tipo: 1, quien: 0, grupo: 0, resp: !!(d && d.v), obs: '', busy: false }; K.Panel.open({ render: function () { return PQ(U.asig); }, st: U.asig, onclose: function () { U.asig = null; } }); };
  A.otatipo = function (d) { U.asig.tipo = +d.v; U.asig.quien = 0; K.Panel.paint(); };
  A.otasignar = function () {
    var a = U.asig; if (!a || !a.quien) return;
    a.busy = true; K.Panel.paint();
    llamar('Asignar', { usuario: a.tipo === 1 ? +a.quien : 0, proveedor: a.tipo === 2 ? +a.quien : 0, grupo: +a.grupo || 0, responsable: !!a.resp, observacion: a.obs }, 'Asignación guardada.').then(function () { U.asig = null; K.Panel.close(); }).catch(function () { a.busy = false; K.Panel.paint(); });
  };
  A.otresp = function (d) { llamar('HacerResponsable', { asignacion: +d.v }, 'Responsable actualizado.').catch(nada); };
  A.otquitar = function (d) { llamar('QuitarAsignacion', { asignacion: +d.v }, 'Asignación quitada.').catch(nada); };
  A.otproc = function () { if (!U.proc) return; llamar('PasosDeProcedimiento', { procedimiento: +U.proc }).then(function () { U.proc = ''; pintar(); }).catch(nada); };
  /* indisponibilidad */
  A.otind = function (d) { U.ind[d.k] = +d.v; pintar(); };
  A.otindok = function () {
    var d = U.ind; if (!d) return;
    if (!d.ini) { d.err = true; pintar(); return; }
    var i = K.deDN(d.ini), fi = d.fin ? K.deDN(d.fin) : '';
    d.busy = true; pintar();
    llamar('Indisponibilidad', { inicio: i + ' ' + (d.hini || '08:00'), fin: fi ? fi + ' ' + (d.hfin || '00:00') : '', planificada: +d.plan === 1, detuvo: !!d.detuvo, motivo: +d.motivo || 0, detalle: d.det }, 'Indisponibilidad registrada.').then(function () { U.ind = null; pintar(); }).catch(function () { d.busy = false; pintar(); });
  };
  /* firmas */
  A.otsigclr = function (d) { FIRMAS[d.v] = ''; var cv = document.querySelector('canvas[data-sig=' + d.v + ']'); if (cv) { cv.getContext('2d').clearRect(0, 0, cv.width, cv.height); var ph = cv.parentElement.querySelector('.cp-sg-ph'); if (ph) ph.hidden = false; } var b = document.querySelector('[data-a=otsigok][data-v=' + d.v + ']'); if (b) b.disabled = true; };
  function firmar(rol, resultado) {
    var fr = U.fr || (U.fr = { obs: '', err: '', busy: '' }), F = U.ficha, obs = fr['obs_' + rol] || '';
    if (!FIRMAS[rol]) { fr.err = rol; pintar(); return; }
    if (resultado === 'RECHAZADO' && !obs.trim()) { fr.err = rol; K.toastError(new Error('Indica el motivo del rechazo en la observación.')); pintar(); return; }
    fr.err = ''; fr.busy = rol; pintar();
    llamar('Firmar', { tipo: tipoId(F, rol), resultado: resultado, observacion: obs, firma: FIRMAS[rol] }, resultado === 'APROBADO' ? 'Firma de «' + ROLES[rol][0].toLowerCase() + '» registrada.' : 'Rechazo registrado.').then(function () { fr.busy = ''; FIRMAS[rol] = ''; fr['obs_' + rol] = ''; pintar(); }).catch(function () { fr.busy = ''; pintar(); });
  }
  A.otsigok = function (d) { firmar(d.v, 'APROBADO'); };
  A.otsigno = function (d) { firmar(d.v, 'RECHAZADO'); };
  /* informe y cierre */
  A.otpost = function (d) { U.formCierre.post = +d.v; pintar(); };
  A.otenviar = function () {
    var fc = U.formCierre, F = U.ficha; fc.err = false;
    if ((fc.informe || '').trim().length < 10 || (+F.ot.otr_orden_trabajo_tipo === 2 && !(fc.causa || '').trim())) { fc.err = true; pintar(); return; }
    if (!firmaDe(F, 'ej')) { U.fr = U.fr || {}; U.fr.err = 'ej'; K.toastError(new Error('Falta la firma de quien ejecutó el trabajo.')); pintar(); var b = document.getElementById('sgb-ej'); if (b) b.scrollIntoView({ block: 'center', behavior: 'smooth' }); return; }
    fc.busy = true; pintar();
    llamar('EnviarCierre', { informe: fc.informe.trim(), horas: fc.horas || '', estadoActivo: +fc.post || 0, causa: fc.causa || '' }, 'Informe enviado: la OT quedó completada y en espera de cierre.').then(function () { fc.busy = false; pintar(); }).catch(function () { fc.busy = false; pintar(); });
  };
  A.otcerrar = function () {
    var fc = U.formCierre, F = U.ficha, miss = faltan(F);
    if (F.servicios.some(function (s) { return !s.INFORME_URL; })) { K.toastError(new Error('Falta el informe del proveedor en los servicios contratados.')); A.otsvir(); return; }
    if (miss.length) { U.fr = U.fr || {}; U.fr.err = miss[0]; pintar(); var b = document.getElementById('sgb-' + miss[0]); if (b) b.scrollIntoView({ block: 'center', behavior: 'smooth' }); K.toastError(new Error(miss.length > 1 ? 'Faltan las firmas de recepción del área y de quien aprueba el cierre.' : 'Falta la firma ' + (miss[0] === 'sup' ? 'de quien aprueba el cierre.' : 'de recepción del área.'))); return; }
    fc.busy = true; pintar();
    llamar('Cerrar', { motivo: +fc.motivo || 1, resultado: F.ot.otr_resultado || '', firma: '' }, otTxt(F.ot.otr_correlativo) + ' cerrada.').then(function () { fc.busy = false; pintar(); }).catch(function () { fc.busy = false; pintar(); });
  };
  /* HU-117 · servicios contratados (cajón) */
  A.otsvnew = function () { abrirServicio(null); };
  A.otsvedit = function (d) { abrirServicio(U.ficha.servicios.filter(function (s) { return String(s.ots_id) === String(d.v); })[0]); };
  A.otsvir = function () { U.tab = 'pasos'; hashOt(U.ficha.q, 'pasos'); pintar(); var el = document.getElementById('otServicios'); if (el) el.scrollIntoView({ block: 'start', behavior: 'smooth' }); };
  A.otsvdel = function (d) {
    var F = U.ficha, s = F.servicios.filter(function (x) { return String(x.ots_id) === String(d.v); })[0]; if (!s) return;
    /* Se ve al instante; si el servidor lo rechaza, la ficha vuelve con lo que hay en la base. */
    F.servicios = F.servicios.filter(function (x) { return x !== s; }); pintar();
    llamar('QuitarServicio', { servicio: +s.ots_id }, 'Servicio quitado.').catch(nada);
  };
  A.otsvsave = function () {
    var s = U.sv; if (!s || s.busy) return;
    if (!s.prov || !s.tipo || !String(s.desc).trim() || !(numero(s.monto) > 0) || !s.mon) { s.err = true; K.Panel.paint(); return; }
    s.busy = true; K.Panel.paint();
    var arch = s.archivo;
    llamar('GuardarServicio', { servicio: s.id, proveedor: +s.prov, tipo: +s.tipo, descripcion: String(s.desc).trim(), cantidad: '1', monto: String(numero(s.monto)), moneda: +s.mon, documento: s.doc || '', fecha: s.fecha ? K.deDN(s.fecha) : '' }, s.id ? 'Servicio actualizado.' : 'Servicio registrado.')
      .then(function (r) {
        if (!arch) return;
        var f = (r.ficha || r).servicios || [], nuevo = f.reduce(function (m, x) { return +x.ots_id > m ? +x.ots_id : m; }, 0);
        return subirInforme(nuevo, arch);
      })
      .then(function () { U.sv = null; K.Panel.close(); })
      .catch(function (e) { s.busy = false; K.Panel.paint(); if (e && e.message) K.toastError(e); });
  };
  document.addEventListener('change', function (ev) {
    var t = ev.target; if (!t || t.type !== 'file') return;
    if (t.hasAttribute('data-svinf') && U.ficha) { var f = t.files && t.files[0]; if (f) subirInforme(t.getAttribute('data-svinf'), f).catch(function (e) { K.toastError(e); }); return; }
    if (t.hasAttribute('data-svnuevo') && U.sv) { U.sv.archivo = t.files && t.files[0] || null; K.Panel.paint(); }
  });
  /* hallazgo encontrado al ejecutar */
  A.othsev = function (d) { if (U.hf) { U.hf.sev = +d.v; pintar(); } };
  A.othok = function () {
    var hf = U.hf; if (!hf) return;
    if ((hf.t || '').trim().length < 5) { hf.err = true; pintar(); return; }
    hf.busy = true; pintar();
    api('HallazgoEnOt', { token: U.ficha.q, titulo: hf.t.trim(), componente: +hf.comp || 0, severidad: +hf.sev, detalle: hf.d || '' }).then(function (r) {
      U.hf = null; aplicar(r.ficha);
      K.toastA('HAL-' + r.hallazgo + ' creado en Avisos para evaluar.', 'Ver aviso', function () { location.href = CFG.base_ + 'View/Mantenimiento/Avisos/Avisos.aspx#avisos'; });
    }).catch(function (e) { hf.busy = false; pintar(); K.toastError(e); });
  };

  var PD = function (st) {
    return { t: 'Devolver a ejecución', s: otTxt(U.ficha.ot.otr_correlativo) + ' · el motivo queda en la bitácora', w: 'n',
      b: '<div class="cp-fld"><label for="dvM">Qué falta corregir <small>obligatorio</small></label><textarea id="dvM" class="cp-inp' + (st.err ? ' cp-err' : '') + '" rows="3" data-pv="dv_motivo" data-autofocus="1" placeholder="Ej.: Falta registrar la presión final">' + esc(st.motivo || '') + '</textarea>' + (st.err ? msgErr('Escribe el motivo (mínimo 5 caracteres).') : '') + '</div>',
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="otdevok">Devolver</button></span>' };
  };
  A.otdev = function () { K.Panel.open({ render: PD, st: { motivo: '', err: false, busy: false } }); };
  A.otdevok = function () {
    var st = K.Panel.state(); if (!st) return;
    if ((st.motivo || '').trim().length < 5) { st.err = true; K.Panel.paint(); return; }
    st.busy = true; K.Panel.paint();
    llamar('Devolver', { motivo: st.motivo.trim() }, 'Devuelta a ejecución.').then(function () { K.Panel.close(); U.tab = 'resumen'; pintar(); }).catch(function () { st.busy = false; K.Panel.paint(); });
  };

  /* nueva OT */
  var PN_ = function (st) {
    var c = st.cat; if (!c) return { t: 'Nueva orden de trabajo', s: 'OT manual · sin plan ni aviso de origen', b: '<div class="cp-sk" style="height:46px"></div><div class="cp-sk" style="height:46px;margin-top:12px"></div><div class="cp-sk" style="height:120px;margin-top:12px"></div>', w: 'n' };
    var activos = c.activos.map(function (a) { return { id: a.ID, n: a.CODIGO + ' · ' + a.NOMBRE, sub: a.AREA }; });
    var comps = [{ id: 0, n: 'Activo completo' }].concat(c.componentes.filter(function (x) { return +x.ACTIVO_ID === +st.act; }).map(function (x) { return { id: x.ID, n: x.NOMBRE }; }));
    var pers = [{ id: 0, n: 'Sin asignar' }].concat(c.personas.map(function (p) { return { id: p.ID, n: p.NOMBRE, sub: [p.PERFIL, p.ESPECIALIDAD].filter(Boolean).join(' · ') || 'Sin perfil', img: p.FOTO || '', ini: K.ini(p.NOMBRE) }; }));
    var e = st.err;
    return { t: 'Nueva orden de trabajo', s: 'OT manual · sin plan ni aviso de origen', w: 'n',
      b: '<div class="cp-fld"><label>Activo <small>obligatorio</small></label>' + K.combo('nAct', activos, st.act || '', { etiqueta: 'Activo', ph: 'Elige el activo', err: e && !st.act }) + '</div>' +
        (st.act ? '<div class="cp-fld"><label>Objeto mantenible</label>' + K.combo('nComp', comps, st.comp || 0, { etiqueta: 'Componente', ph: 'Activo completo' }) + '</div>' : '') +
        '<div class="cp-fld"><label for="nT">Trabajo a realizar <small>obligatorio</small></label><input id="nT" class="cp-inp' + (e && (st.t || '').trim().length < 5 ? ' cp-err' : '') + '" data-pv="n_t" value="' + esc(st.t || '') + '" placeholder="Ej.: Cambiar la correa de transmisión" autocomplete="off"></div>' +
        '<div class="cp-fld"><label>Tipo</label>' + seg(TIPOS, 'otn', 'tipo', st.tipo) + '</div>' +
        '<div class="cp-fld"><label>Prioridad</label>' + seg(PRIO, 'otn', 'prio', st.prio) + '</div>' +
        '<div class="cp-fld2"><div class="cp-fld"><label>Fecha programada</label>' + K.fecha('n_fecha', K.deDN(st.fecha || ''), { ph: 'dd-mm-aaaa' }) + '</div><div class="cp-fld"><label>Hora</label>' + K.combo('nHora', HORAS.slice(10, 46).map(function (h) { return { id: h, n: h }; }), st.hora || '08:00', { etiqueta: 'Hora', ph: '08:00' }) + '</div></div>' +
        '<div class="cp-fld2"><div class="cp-fld"><label>Responsable</label>' + K.combo('nResp', pers, st.resp || 0, { etiqueta: 'Responsable', ph: 'Sin asignar' }) + '</div><div class="cp-fld"><label for="nD">Duración (horas)</label><input id="nD" class="cp-inp" data-pv="n_dur" value="' + esc(st.dur || '') + '" inputmode="decimal" placeholder="Ej.: 2"></div></div>' +
        '<div class="cp-fld"><label for="nDe">Descripción</label><textarea id="nDe" class="cp-inp" rows="3" data-pv="n_desc" placeholder="Detalle del trabajo">' + esc(st.desc || '') + '</textarea></div>' + choquesHTML(st.choq),
      f: '<button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button><span class="cp-r"><button type="button" class="cp-btn cp-pri' + (st.busy ? ' cp-load' : '') + '" data-a="nuevaok">' + (st.choq && st.choq.length ? ic('alert', 16) + 'Crear igual' : 'Crear OT') + '</button></span>' };
  };
  A.otnueva = function () {
    var st = { cat: null, act: '', comp: 0, t: '', tipo: 2, prio: 2, fecha: '', hora: '08:00', resp: 0, dur: '', desc: '', err: false, busy: false };
    K.Panel.open({ render: PN_, st: st });
    catalogos().then(function () { st.cat = U.cat; if (K.Panel.state() === st) K.Panel.paint(); }).catch(function (e) { K.Panel.close(); K.toastError(e); });
  };
  A.otn = function (d) { var st = K.Panel.state(); st[d.k] = +d.v; K.Panel.paint(); };
  A.nuevaok = function () {
    var st = K.Panel.state(); if (!st) return;
    if (!st.act || (st.t || '').trim().length < 5) { st.err = true; K.Panel.paint(); return; }
    var f = st.fecha ? K.deDN(st.fecha) : '';
    var dur = parseFloat(String(st.dur || '').replace(',', '.')) || 0;
    if (choquesAntes(st, 0, st.act, st.comp, f ? f + ' ' + (st.hora || '08:00') : '', Math.round(dur * 60), A.nuevaok, +st.resp ? ['U:' + st.resp] : [])) return;
    st.busy = true; K.Panel.paint();
    api('Nueva', { activo: +st.act, componente: +st.comp || 0, titulo: st.t.trim(), descripcion: st.desc || '', tipo: +st.tipo, prioridad: +st.prio, fecha: f ? f + ' ' + (st.hora || '08:00') : '', duracionMin: Math.round(dur * 60), responsable: +st.resp || 0 }).then(function (r) {
      K.Panel.close(); K.toast(otTxt(r.ot) + ' creada.'); cargarLista(); abrir(r.q);
    }).catch(function (e) { st.busy = false; K.Panel.paint(); K.toastError(e); });
  };

  /* ---------------------------------------------------------------- campos y combos */
  L.on({
    pv: function (k, v) {
      var cst = K.Panel.state(); if (cst && (k === 'ed_dur' || k === 'n_dur')) { cst.choq = null; cst.choqOk = false; }
      if (k === 'otq') { U.q = v; var f = $('#otFilas'); if (f) f.innerHTML = ordenada().slice(0, 100).map(filaOt).join(''); return; }
      var fc = U.formCierre, st = K.Panel.state(), e = U.ed, fr = U.fr || (U.fr = { obs: '', err: '', busy: '' });
      if (k === 'ci_informe') { fc.informe = v; return; }
      if (k === 'ci_horas') { fc.horas = v; return; }
      if (k === 'hf_t' && U.hf) { U.hf.t = v; return; }
      if (k === 'sg_obs_rec') { fr.obs_rec = v; return; }
      if (k === 'sg_obs_sup') { fr.obs_sup = v; return; }
      if (k === 'in_detuvo' && U.ind) { U.ind.detuvo = !!v; return; }
      if (k === 'in_det' && U.ind) { U.ind.det = v; return; }
      if (e && k.indexOf('ed_') === 0) { if (k === 'ed_titulo') e.titulo = v; else if (k === 'ed_desc') e.desc = v; else if (k === 'ed_notas') e.notas = v; else if (k === 'ed_dur') e.dur = v; else if (k === 'ed_permiso') e.permiso = !!v; return; }
      if (U.sv && k.indexOf('sv_') === 0) { U.sv[{ sv_desc: 'desc', sv_monto: 'monto', sv_doc: 'doc' }[k]] = v; return; }
      if (U.asig && k === 'oa_resp') { U.asig.resp = !!v; return; }
      if (U.asig && k === 'oa_obs') { U.asig.obs = v; return; }
      if (!st) return;
      if (k === 'dv_motivo') { st.motivo = v; return; }
      if (k === 'n_t') { st.t = v; return; }
      if (k === 'n_dur') { st.dur = v; return; }
      if (k === 'n_desc') { st.desc = v; return; }
    },
    fecha: function (el) {
      var k = el.getAttribute('data-fe'), st = K.Panel.state();
      if (st && (k === 'n_fecha' || k === 'ed_fecha')) { st.choq = null; st.choqOk = false; }
      if (k === 'n_fecha' && st) st.fecha = el.value;
      if (k === 'ed_fecha' && U.ed) U.ed.fecha = el.value;
      if (k === 'sv_fecha' && U.sv) U.sv.fecha = el.value;
      if (k === 'in_ini' && U.ind) U.ind.ini = el.value;
      if (k === 'in_fin' && U.ind) U.ind.fin = el.value;
    },
    combo: function (span, v) {
      var n = span.getAttribute('data-cb'), st = K.Panel.state();
      if (st && /^(nAct|nComp|nHora|edHora|nResp)$/.test(n)) { st.choq = null; st.choqOk = false; }
      if (n === 'otOrigen') { U.o = +v || 0; pintar(); return; }
      if (n === 'otTipo') { U.t = +v || 0; pintar(); return; }
      if (n === 'ciMotivo') { U.formCierre.motivo = +v || 1; return; }
      if (n === 'ciCausa') { U.formCierre.causa = v; return; }
      if (n === 'otProc') { U.proc = v; pintar(); return; }
      if (n === 'inHIni' && U.ind) { U.ind.hini = v; return; }
      if (n === 'inHFin' && U.ind) { U.ind.hfin = v; return; }
      if (n === 'inMotivo' && U.ind) { U.ind.motivo = +v || 0; return; }
      if (n === 'hfComp' && U.hf) { U.hf.comp = +v || 0; return; }
      if (n === 'edEstr' && U.ed) { U.ed.estr = +v || 1; return; }
      if (n === 'edHora' && U.ed) { U.ed.hora = v; return; }
      if (n === 'otaQuien' && U.asig) { U.asig.quien = +v || 0; K.Panel.paint(); return; }
      if (n === 'otaGrupo' && U.asig) { U.asig.grupo = +v || 0; return; }
      if (U.sv && (n === 'svProv' || n === 'svTipo' || n === 'svMon')) { U.sv[{ svProv: 'prov', svTipo: 'tipo', svMon: 'mon' }[n]] = +v || ''; return; }
      if (!st) return;
      if (n === 'nAct') { st.act = v; st.comp = 0; K.Panel.paint(); }
      if (n === 'nComp') st.comp = +v || 0;
      if (n === 'nHora') st.hora = v;
      if (n === 'nResp') st.resp = +v || 0;
    }
  });

  /* ---------------------------------------------------------------- registro */
  L.tab('ordenes', {
    mount: function (body) {
      body.innerHTML = '<div id="otRoot"></div>';
      var pn = body.closest('.cp-panel'); if (pn) pn.classList.add('cp-bare');
      var h = leerHash();
      cargarLista().then(function () { if (h.ot) abrir(h.ot, h.t); });
    },
    hero: function () { return U.perm.crear ? '<button type="button" class="cp-btn cp-pri" data-a="otnueva">' + ic('plus', 16) + 'Nueva OT</button>' : ''; },
    planta: function () { U.ficha = null; cargarLista(); }
  });
})();
