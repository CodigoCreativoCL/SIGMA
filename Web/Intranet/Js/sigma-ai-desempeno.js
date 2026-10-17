/* =====================================================================
   SIGMA AI · DESEMPEÑO (EP-17 · HU-177 y HU-178) · BD/475
   «Por evaluar»: predicciones cuyo horizonte venció y nadie evaluó. Se registra si el evento ocurrió y cuándo; si no
   ocurrió pero hubo una intervención previa, es «acierto con intervención» y NO es falso positivo (lo decide el SP).
   «Desempeño»: por versión y mes, predicciones, evaluadas y clasificación; con la precisión contra la de referencia
   y la marca «candidata a reentrenamiento». La desviación de los datos no se mide todavía y la pantalla lo dice.
   ===================================================================== */
(function () {
  var K = window.MantKit, L = window.MantLugar;
  if (!K || !L) return;
  var CFG = K.CFG, esc = K.esc, ic = K.ic, $ = K.$, fN = K.fN;
  var api = function (m, d) { return K.llamar(CFG.ws, m, d); };
  var MES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var U = { tab: 'evaluar', pe: null, ds: null, err: '', ev: null, puede: false };
  var CLASE = { 'VERDADERO POSITIVO': ['Acierto', 'cp-g'], 'FALSO POSITIVO': ['Falsa alarma', 'cp-r'], 'ACIERTO CON INTERVENCION': ['Acierto con intervención', 'cp-p'], 'VERDADERO NEGATIVO': ['Correcto sin alerta', 'cp-g'], 'FALSO NEGATIVO': ['Falla no anticipada', 'cp-r'] };

  function vacio(t, s) { return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('check', 20) + '</span><b>' + t + '</b>' + s + '</div>'; }
  function errorHTML() { return '<div class="cp-empty" style="margin:20px"><span class="cp-ei">' + ic('alert', 20) + '</span><b>No se pudo cargar</b>' + esc(U.err) + '<button type="button" class="cp-btn cp-out cp-sm" data-a="aidrecarga">Reintentar</button></div>'; }

  /* ------------------------------------------------------------ por evaluar */
  function evaluar() {
    if (U.err) return errorHTML();
    if (!U.pe) return '<div class="cp-sk" style="height:220px;margin:12px 0"></div>';
    if (!U.pe.length) return vacio('Todas las predicciones vencidas están evaluadas', 'Cuando venza el horizonte de una predicción nueva, aparecerá aquí para que registres qué pasó.');
    var cols = 'minmax(0,1fr) 150px 90px 200px 120px';
    var filas = U.pe.map(function (p) {
      var sug = p.HUBO_INTERVENCION ? '<br><span class="cp-tg cp-p">Hubo una OT cerrada en el plazo</span>' : '';
      return '<div class="cp-rw" style="grid-template-columns:' + cols + '"><span class="cp-s"><b>' + esc(p.ACTIVO) + '</b><small>' + esc(p.ACTIVO_CODIGO) + ' · ' + esc(p.MODELO) + ' v' + p.VERSION + '</small></span>' +
        '<span class="cp-tn">' + fN((+p.PROBABILIDAD || 0) * 100, 0) + ' % de probabilidad</span><span>' + (p.DIAS != null ? p.DIAS + ' días' : '—') + '</span>' +
        '<span><small class="cp-muted2">Estimada</small> ' + (p.ESTIMADA ? K.fDN(p.ESTIMADA) : '—') + ' · vencida hace ' + Math.max(0, p.DIAS_VENCIDA) + ' d' + sug + '</span>' +
        '<span>' + (U.puede ? '<button type="button" class="cp-btn cp-pri cp-sm" data-a="aidev" data-id="' + p.ID + '">Evaluar</button>' : '<small class="cp-muted2">Sin permiso para evaluar</small>') + '</span></div>';
    }).join('');
    return '<section class="cp-card"><div class="cp-sc-h"><h3>' + U.pe.length + (U.pe.length === 1 ? ' predicción pendiente de evaluar' : ' predicciones pendientes de evaluar') + '</h3><small>Cuyo horizonte ya venció</small></div><div class="cp-rows">' + filas + '</div></section>';
  }

  function panel(st) {
    var p = st.p, e = st.e;
    var rad = function (v, t, sub) { return '<button type="button" class="cp-opt' + (e.ocurrio === v ? ' on' : '') + '" data-a="aiocu" data-v="' + v + '"><b>' + t + '</b><small>' + sub + '</small></button>'; };
    var cuerpo = '<section class="cp-card"><div class="cp-sc-h"><h3>' + esc(p.ACTIVO) + '</h3><small>' + esc(p.ACTIVO_CODIGO) + ' · ' + esc(p.MODELO) + ' v' + p.VERSION + ' · estimada ' + (p.ESTIMADA ? K.fDN(p.ESTIMADA) : '—') + '</small></div></section>' +
      '<div class="cp-fld"><label>¿El evento ocurrió?</label><div class="cp-opts">' + rad('1', 'Sí ocurrió', 'La falla se presentó') + rad('0', 'No ocurrió', 'No hubo falla en el plazo') + '</div></div>' +
      (e.ocurrio === '1' ? '<div class="cp-fld"><label>¿En qué fecha?</label>' + K.fecha('ai_fecha', e.fecha, { ph: 'dd-mm-aaaa' }) + '<small class="cp-muted2">El error respecto de la fecha estimada se calcula solo.</small></div>' : '') +
      (e.ocurrio === '0' ? '<label class="cp-chk"><input type="checkbox" data-pv="interv"' + (e.interv ? ' checked' : '') + '><span>Hubo una intervención previa (mantenimiento o reparación antes del evento)<small class="cp-muted2" style="display:block">Si la marcas, se cuenta como acierto con intervención y no como falsa alarma.</small></span></label>' : '') +
      (e.ocurrio === '0' && p.HUBO_INTERVENCION ? '<p class="cp-note">SIGMA encontró una orden de trabajo cerrada sobre este equipo dentro del plazo: probablemente corresponde marcar la intervención.</p>' : '') +
      '<div class="cp-fld"><label>Observación (opcional)</label><textarea data-pv="obs" rows="3" maxlength="500">' + esc(e.obs) + '</textarea></div>' +
      (st.err ? '<p class="cp-err-t">' + esc(st.err) + '</p>' : '');
    return { t: 'Evaluar la predicción', s: 'Resultado real', b: cuerpo, f: '<button type="button" class="cp-btn cp-pri" data-a="aiguardar"' + (st.busy || e.ocurrio === '' ? ' disabled' : '') + '>Guardar resultado</button><button type="button" class="cp-btn cp-ghost" data-a="pclose">Cancelar</button>' };
  }

  /* ------------------------------------------------------------ desempeño */
  function desempeno() {
    if (U.err) return errorHTML();
    if (!U.ds) return '<div class="cp-sk" style="height:260px;margin:12px 0"></div>';
    var m = U.ds.meses, ev = U.ds.evaluaciones;
    var aviso = '<div class="cp-note" style="margin:12px 0">' + ic('alert', 16) + ' <b>Desviación de los datos de entrada:</b> todavía no se mide (necesita guardar cómo eran los datos de entrenamiento). Mientras tanto, el desempeño se juzga solo por los resultados reales de las predicciones.</div>';
    if (!m.length) return aviso + vacio('Aún no hay predicciones para medir', 'Cuando SIGMA AI genere predicciones y se evalúen, verás aquí su desempeño por versión y mes.');
    var cols = '110px minmax(0,1fr) 62px 70px 70px 80px 70px 100px 170px';
    var cab = '<div class="cp-rw cp-h" style="grid-template-columns:' + cols + '">' + ['Mes', 'Modelo y versión', 'Predicc.', 'Evaluadas', 'Aciertos', 'Falsas alarmas', 'Con interv.', 'Precisión', 'Estado'].map(function (x) { return '<span>' + x + '</span>'; }).join('') + '</div>';
    var filas = m.map(function (o) {
      var pa = o.PRECISION_ACTUAL, pr = o.PRECISION_REFERENCIA;
      var est = o.REENTRENAR ? '<span class="cp-tg cp-r">Candidata a reentrenamiento</span>' : (o.EVALUADAS >= 5 ? '<span class="cp-tg cp-g">Dentro de lo esperado</span>' : '<span class="cp-tg">Pocas evaluadas</span>');
      return '<div class="cp-rw" style="grid-template-columns:' + cols + '"><span>' + MES[o.MES - 1] + ' ' + o.ANIO + '</span><span class="cp-s"><b>' + esc(o.MODELO) + '</b><small>versión ' + o.VERSION + '</small></span><span class="cp-tn">' + o.TOTAL + '</span><span class="cp-tn">' + o.EVALUADAS + '</span><span class="cp-tn">' + o.VP + '</span><span class="cp-tn">' + o.FP + '</span><span class="cp-tn">' + o.ACIERTO_INTERVENCION + '</span>' +
        '<span class="cp-tn">' + (pa == null ? '—' : fN(pa * 100, 0) + ' %') + (pr != null ? '<br><small class="cp-muted2">ref. ' + fN(pr * 100, 0) + ' %</small>' : '') + '</span><span>' + est + (o.OBSERVACION ? '<br><small class="cp-muted2">' + esc(o.OBSERVACION) + '</small>' : '') + '</span></div>';
    }).join('');
    var ult = ev.map(function (r) {
      var c = CLASE[r.CLASIFICACION] || [r.CLASIFICACION, ''];
      return '<div class="cp-rw" style="grid-template-columns:minmax(0,1fr) 200px 110px 100px"><span class="cp-s"><b>' + esc(r.ACTIVO) + '</b><small>' + esc(r.ACTIVO_CODIGO) + (r.OBSERVACION ? ' · ' + esc(r.OBSERVACION) : '') + '</small></span><span><span class="cp-tg ' + c[1] + '">' + c[0] + '</span></span><span>' + (r.ERROR_DIAS != null ? 'error de ' + fN(r.ERROR_DIAS, 0) + ' d' : '—') + '</span><span class="cp-muted2">' + K.fDN(r.EVALUADA) + '</span></div>';
    }).join('') || '<div class="cp-empty">Todavía no se ha evaluado ninguna predicción.</div>';
    return aviso + '<section class="cp-card"><div class="cp-sc-h"><h3>Desempeño por versión y mes</h3><small>Un acierto con intervención se cuenta aparte y no es falsa alarma</small></div><div class="cp-rows">' + cab + filas + '</div></section>' +
      '<section class="cp-card" style="margin-top:12px"><div class="cp-sc-h"><h3>Últimas evaluaciones</h3></div><div class="cp-rows">' + ult + '</div></section>';
  }

  /* ------------------------------------------------------------ carga y acciones */
  function pintar() { var b = $('#aidRoot'); if (b) b.innerHTML = U.tab === 'desempeno' ? desempeno() : evaluar(); }
  function cargar() {
    U.err = ''; if (U.tab === 'desempeno') U.ds = null; else U.pe = null;
    pintar();
    (U.tab === 'desempeno' ? api('Desempeno', {}).then(function (r) { U.ds = r; }) : api('PorEvaluar', {}).then(function (r) { U.pe = r.filas; U.puede = r.puede; L.badge('evaluar', r.filas.length); }))
      .then(pintar).catch(function (e) { U.err = e.message || 'Error'; pintar(); });
  }
  var A = L.A;
  A.aidrecarga = function () { cargar(); };
  A.aidev = function (d) {
    var p = U.pe.filter(function (x) { return String(x.ID) === d.id; })[0]; if (!p) return;
    var st = { p: p, e: { ocurrio: '', fecha: K.TODAY, interv: !!p.HUBO_INTERVENCION, obs: '' }, err: '', busy: false };
    U.ev = st; K.Panel.open({ render: function () { return panel(st); }, st: st, onclose: function () { U.ev = null; } });
  };
  A.aiocu = function (d) { if (!U.ev) return; U.ev.e.ocurrio = d.v; U.ev.err = ''; K.Panel.paint(); };
  A.aiguardar = function () {
    var st = U.ev; if (!st || st.busy) return;
    var e = st.e; if (e.ocurrio === '1' && !e.fecha) { st.err = 'Indica la fecha en que ocurrió el evento.'; K.Panel.paint(); return; }
    st.busy = true; st.err = ''; K.Panel.paint();
    api('Evaluar', { prediccion: st.p.ID, ocurrio: e.ocurrio === '1', fecha: e.ocurrio === '1' ? e.fecha : '', intervencion: e.ocurrio === '0' && !!e.interv, falla: st.p.FALLA_ID || 0, observacion: e.obs })
      .then(function (r) { K.Panel.close(); K.toast('Resultado registrado: ' + ((CLASE[r.clasificacion] || [r.clasificacion])[0]) + '.'); U.ds = null; cargar(); })
      .catch(function (x) { st.busy = false; st.err = x.message || 'No se pudo guardar.'; K.Panel.paint(); });
  };
  L.on({
    pv: function (k, v) { if (!U.ev) return; if (k === 'interv') U.ev.e.interv = !!v; if (k === 'obs') U.ev.e.obs = v; },
    fecha: function (el) { if (U.ev && el.getAttribute('data-fe') === 'ai_fecha') U.ev.e.fecha = K.deDN(el.value); }
  });
  function montar(tab) { return function (body) { U.tab = tab; body.innerHTML = '<div id="aidRoot"></div>'; cargar(); }; }
  L.tab('evaluar', { mount: montar('evaluar') });
  L.tab('desempeno', { mount: montar('desempeno') });
})();
