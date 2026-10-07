/* ============================================================================
   SIGMA AI · Centro de monitoreo (06-10-2026)
   Referencia: docs/rediseno-sigma-ai/sigma-ai-centro-referencia.html

   Ninguna cifra se escribe aqui: todo llega de WsAiCentro (SP «SEL_AI_*», BD/379), que lee lo que ya
   guardan /sigma-ai/predecir (FAILURE 30D y RUL) y /sigma-ai/vision/clasificar. Un modelo sin version
   publicada o sin datos muestra su estado vacio. El copiloto responde solo con datos de SIGMA y cita sus fuentes.
   La planta 3D vive en sigma-ai-planta3d.js (modulo ES, carga bajo demanda); sin WebGL se usa la grilla de respaldo.
   ========================================================================= */
(function () {
    'use strict';

    var root = document.getElementById('sgai');
    if (!root) return;
    var WS = root.getAttribute('data-ws'), IMG = root.getAttribute('data-img'), JS3D = root.getAttribute('data-js3d');
    var RM = !!(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches);
    var G = function () { return window.gsap; };

    /* ------------------------------------------------------------ utilidades */
    function $(s, r) { return (r || document).querySelector(s); }
    function $$(s, r) { return [].slice.call((r || document).querySelectorAll(s)); }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
    function fmt(n, d) { return Number(n).toLocaleString('es-CL', { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 }); }
    function num(v) { return v == null || v === '' ? null : Number(v); }
    /* los **asteriscos** de la bitacora marcan lo importante */
    function rico(t) { return esc(t).replace(/\*\*(.+?)\*\*/g, '<b>$1</b>'); }
    function plano(t) { return String(t || '').replace(/\*\*/g, ''); }
    function hhmm(iso) { var d = new Date(iso); return isNaN(d) ? '' : d.toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit', hour12: false }); }
    function ago(iso) {
        if (!iso) return '—'; var m = Math.round((Date.now() - new Date(iso).getTime()) / 60000) + 0;
        return m < 1 ? 'hace un momento' : m < 60 ? 'hace ' + m + ' min' : m < 1440 ? 'hace ' + Math.round(m / 60) + ' h' : 'hace ' + Math.round(m / 1440) + ' d';
    }
    var P = {
        check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', x: '<path d="M6 6l12 12M18 6L6 18"/>', plus: '<path d="M12 5v14M5 12h14"/>', arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
        send: '<path d="M4 12l16-8-6 16-3-7z"/>', bot: '<rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 4v4M9 13h.01M15 13h.01M9.5 16.5h5"/>',
        alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>', expand: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>', compress: '<path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5"/>', pin: '<path d="M12 21s7-6.2 7-11.5A7 7 0 0 0 5 9.5C5 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
        trend: '<path d="M3 17l6-6 4 4 7-8"/><path d="M15 7h5v5"/>', gauge: '<path d="M4 17a8 8 0 1 1 16 0"/><path d="M12 17l4-5"/>', wrench: '<path d="M14.5 6.5a4 4 0 0 0 4.9 4.9L21 13l-8 8-3-3 8-8z"/><path d="M5 19l-2 2"/>',
        users: '<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c.6-3.2 2.8-5 5.5-5s4.9 1.8 5.5 5"/>', box: '<path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/>'
    };
    function ic(k, n) { n = n || 18; return '<svg class="ic" style="width:' + n + 'px;height:' + n + 'px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (P[k] || P.box) + '</svg>'; }
    function simbolo(n) { return '<img src="' + esc(IMG + 'sigma-ai/sigma-ai-symbol-gradient.svg') + '" alt="" width="' + n + '" height="' + n + '" style="display:block">'; }
    var gid = 0;
    function ringSVG(v, size, w) {
        var r = (size - w) / 2, C = 2 * Math.PI * r, id = 'rx' + (++gid);
        return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 ' + size + ' ' + size + '" aria-hidden="true"><defs><linearGradient id="' + id + '" x1="0" y1="0" x2="' + size + '" y2="' + size + '" gradientUnits="userSpaceOnUse"><stop stop-color="#00E0C2"/><stop offset=".48" stop-color="#2563EB"/><stop offset=".74" stop-color="#6C5CFF"/><stop offset="1" stop-color="#FF4D9D"/></linearGradient></defs>'
            + '<circle cx="' + size / 2 + '" cy="' + size / 2 + '" r="' + r + '" fill="none" stroke="rgba(255,255,255,.08)" stroke-width="' + w + '"/>'
            + '<circle class="rgv" cx="' + size / 2 + '" cy="' + size / 2 + '" r="' + r + '" fill="none" stroke="url(#' + id + ')" stroke-width="' + w + '" stroke-linecap="round" stroke-dasharray="' + C + '" stroke-dashoffset="' + C * (1 - Math.max(0, Math.min(100, v)) / 100) + '" transform="rotate(-90 ' + size / 2 + ' ' + size / 2 + ')" data-c="' + C + '" data-v="' + Math.max(0, Math.min(100, v)) + '"/></svg>';
    }
    function sparkSVG(vals, color, w, h, area, lo, hi) {
        w = w || 200; h = h || 40; vals = vals.filter(function (v) { return v != null; }); if (vals.length < 2) return '';
        lo = lo != null ? lo : Math.min.apply(null, vals); hi = hi != null ? hi : Math.max.apply(null, vals);
        function X(i) { return i / (vals.length - 1) * w; } function Y(v) { return h - 2 - (v - lo) / ((hi - lo) || 1) * (h - 6); }
        var d = vals.map(function (v, i) { return (i ? 'L' : 'M') + X(i).toFixed(1) + ' ' + Y(v).toFixed(1); }).join('');
        return '<svg viewBox="0 0 ' + w + ' ' + h + '" preserveAspectRatio="none" aria-hidden="true">' + (area !== false ? '<path d="' + d + 'L' + w + ' ' + h + 'L0 ' + h + 'Z" fill="' + color + '" opacity=".12"/>' : '') + '<path d="' + d + '" fill="none" stroke="' + color + '" stroke-width="2" vector-effect="non-scaling-stroke" stroke-linejoin="round" stroke-linecap="round"/></svg>';
    }
    function toast(msg) {
        var box = document.querySelector('.ai-toasts'); if (!box) { box = document.createElement('div'); box.className = 'ai-toasts'; box.setAttribute('aria-live', 'polite'); document.body.appendChild(box); }
        var t = document.createElement('div'); t.className = 'ai-toast'; t.setAttribute('role', 'status'); t.innerHTML = ic('check', 18) + '<span>' + esc(msg) + '</span>';
        box.appendChild(t); setTimeout(function () { t.remove(); }, 4200);
    }
    function ws(metodo, datos) {
        return fetch(WS + '/' + metodo, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify(datos || {}) })
            .then(function (r) { if (!r.ok) throw new Error('El servidor respondió ' + r.status + '.'); return r.json(); })
            .then(function (j) { var d = JSON.parse(j.d); if (d.error) throw new Error(d.detalle || 'No se pudo completar.'); return d; });
    }

    /* severidad: crítica ≥ 70, alta 50–69, media con predicción, saludable sin ella */
    function sev(p) { return p >= 70 ? ['crit', '#FF5C8A', 'Crítica'] : p >= 50 ? ['high', '#FFB547', 'Alta'] : p >= 25 ? ['mid', '#00E0C2', 'Media'] : ['ok', '#6F7CC8', 'Saludable']; }

    /* ------------------------------------------------------------ estado */
    var D = null;
    try { V.planta = +localStorage.getItem('sigmaAiPlanta') || 0; } catch (x) { }                                     // lo ultimo de Estado()/Pulso()
    var V = { planta: 0, sel: null, qf: 'all', pf: 'all', det: null, detId: null, ev: [], desde: null, greeted: false, rail: true, ordered: {} };
    var G3 = null, G3Cargando = false;
    try { V.rail = localStorage.getItem('sg-ai-rail') === '1'; V.full = false; } catch (e) { V.rail = false; }
    function guardarRail() { try { localStorage.setItem('sg-ai-rail', V.rail ? '1' : '0'); } catch (e) { } document.body.classList.toggle('rail-off', !V.rail); if (!V.rail) { V.full = false; } document.body.classList.toggle('rail-full', !!V.full); var fs = $('[data-railfs]'); if (fs) { fs.setAttribute('aria-label', V.full ? 'Salir de pantalla completa' : 'Pantalla completa'); fs.innerHTML = ic(V.full ? 'compress' : 'expand', 17); } }

    function cola() { return (D && D.cola) || []; }
    function predOf(id) { return cola().filter(function (p) { return String(p.ID) === String(id); })[0] || null; }
    function abiertas() { return cola().filter(function (p) { return p.ESTADO !== 'd'; }); }
    function modelo(k) { return ((D && D.modelos) || []).filter(function (m) { return norm(m.MODELO).indexOf(k) >= 0; })[0] || null; }
    function publicado(m) { return !!(m && num(m.VERSION)); }
    function tend(p) { return ((D && D.tendencias) || {})[p.ACTIVO_ID] || []; }
    function plazo(p) {
        var d = num(p.DIAS); if (d == null) return 'sin plazo estimado';
        var lo = num(p.DIAS_MIN), hi = num(p.DIAS_MAX);
        return lo != null && hi != null && hi > lo && lo <= d && d <= hi ? fmt(lo) + '–' + fmt(hi) + ' días' : '~' + fmt(d) + (d === 1 ? ' día' : ' días');
    }
    function fechaLimite(p) { return p.FECHA_EVENTO ? 'antes del ' + new Date(p.FECHA_EVENTO).toLocaleDateString('es-CL', { day: 'numeric', month: 'long' }) : ''; }
    function nombreAct(p) { return p.COMPONENTE ? p.COMPONENTE : p.ACTIVO; }

    /* ------------------------------------------------------------ encabezado */
    function plantaSel() {
        var L = D.plantas || [];
        if (!L.length) return '';
        if (L.length === 1) return '<span class="plsel"><span>Planta</span><span class="plchip">' + esc(L[0].nombre) + '</span></span>';
        return '<label class="plsel"><span>Planta</span><select id="aiPlanta" aria-label="Filtrar por planta"><option value="0">Todas las plantas</option>'
            + L.map(function (x) { return '<option value="' + x.id + '"' + (+V.planta === +x.id ? ' selected' : '') + '>' + esc(x.nombre) + '</option>'; }).join('') + '</select></label>';
    }
    function headHTML() {
        var eq = !!D.puedeModelos, res = D.resumen || {}, crit = abiertas().filter(function (p) { return num(p.PROB) >= 70; }).length, pend = num(D.pendientes) || 0, pub = num(res.PUBLICADOS) || 0;
        return '<div class="crumb2">SIGMA AI / <b>Centro de monitoreo</b></div>'
            + '<section class="xh"><span class="lg">' + simbolo(40) + '</span>'
            + '<div><h1>Centro de monitoreo <span>SIGMA AI</span></h1><p>Predice fallas, estima la vida útil de cada repuesto y revisa las fotos de terreno. Todo en vivo, con la razón de cada aviso.</p></div>'
            + '<div class="xh-r">' + plantaSel() + '<span class="pill-live"><i></i>EN VIVO</span><span class="xs"><span>Última puntuación <b id="lastScore">' + (res.ULTIMA_PUNTUACION ? ago(res.ULTIMA_PUNTUACION) : 'sin puntuaciones') + '</b></span><span><b>' + pub + '</b> ' + (pub === 1 ? 'modelo publicado' : 'modelos publicados') + '</span></span>'
            + '<button type="button" class="btn cy sm" data-score="1">' + ic('trend', 15) + 'Puntuar ahora</button></div></section>'
            + '<nav class="snav" aria-label="Secciones">' + [['mon', 'Monitoreo', ''], ['pred', 'Predicciones', crit ? '<em>' + crit + '</em>' : ''], ['rul', 'Vida útil', ''], ['vis', 'Visión', pend ? '<em class="t">' + pend + '</em>' : ''], ['mod', eq ? 'Modelos' : 'Resultados', '']]
                .map(function (x, i) { return '<a href="#' + x[0] + '" data-sec="' + x[0] + '" class="' + (i ? '' : 'on') + '">' + x[1] + x[2] + '</a>'; }).join('') + '</nav>';
    }

    /* ------------------------------------------------------------ monitoreo */
    function activos() { return (D && D.activos) || []; }
    function sevAct(a) { var p = num(a.PROB); return p != null && p >= 25 ? sev(p) : ['ok', '#6F7CC8', 'Saludable']; }
    function monHTML() {
        var res = D.resumen || {}, tot = num(res.TOTAL) || 0, areas = (D.areas || []).filter(function (a) { return a.ACTIVOS > 0; });
        var seg = [['crit', '#FF5C8A', 'Crítica', num(res.CRITICAS) || 0], ['high', '#FFB547', 'Alta', num(res.ALTAS) || 0], ['mid', '#00E0C2', 'Media', num(res.MEDIAS) || 0], ['ok', '#6F7CC8', 'Saludables', num(res.SALUDABLES) || 0]];
        var salud = num(res.SALUD), hist = (D.salud || []).map(function (x) { return x.RIESGO == null ? null : 100 - 100 * Number(x.RIESGO); });
        var ult = hist.filter(function (v) { return v != null; });
        var delta = ult.length >= 2 ? ult[ult.length - 1] - ult[ult.length - 2] : null;
        var senal = D.senales || {}, hg = D.histograma || [], mx = Math.max.apply(null, hg.map(function (h) { return Number(h.N) || 0; }).concat([1]));
        var explican = num(res.EXPLICAN);
        return '<div class="sec-t" id="mon"><div><span class="k">Monitoreo</span><h2>La planta, en este momento</h2></div></div>'
            + '<div class="xg"><section class="xc plant" id="plant" aria-label="Planta en 3D"><canvas id="pl3d" aria-hidden="true"></canvas>'
            + '<div class="pl-lab" id="plLab">' + areas.map(function (a) { var n = activos().filter(function (x) { return x.AREA_ID === a.ID; }), r = n.filter(function (x) { return num(x.PROB) >= 50; }).length; return '<span class="al" data-al="' + a.ID + '">' + esc(a.NOMBRE) + '<b>' + n.length + (n.length === 1 ? ' activo' : ' activos') + (r ? ' · ' + r + ' en riesgo' : '') + '</b></span>'; }).join('') + '</div>'
            + '<div class="pl-tip" id="plTip" role="status"></div>'
            + '<div class="xc-h"><h3>Planta ' + esc(D.cliente || '') + '</h3><small>' + areas.length + (areas.length === 1 ? ' área' : ' áreas') + ' · ' + tot + (tot === 1 ? ' activo' : ' activos') + ' · arrastra para girar</small><div class="r"><button type="button" class="chipx" data-pf="all" aria-pressed="' + (V.pf === 'all') + '">Todos</button><button type="button" class="chipx" data-pf="risk" aria-pressed="' + (V.pf === 'risk') + '"><i style="background:#FF5C8A"></i>Solo en riesgo</button></div></div>'
            + '<div class="pl-fb" id="plFb">' + areas.map(function (a) { return '<div class="fb-a"><b>' + esc(a.NOMBRE) + '</b><div>' + activos().filter(function (x) { return x.AREA_ID === a.ID; }).map(function (x) { return '<i title="' + esc(x.NOMBRE) + '" style="background:' + sevAct(x)[1] + '"' + (x.PRED_ID ? ' data-sel="' + x.PRED_ID + '"' : '') + '></i>'; }).join('') + '</div></div>'; }).join('') + '</div>'
            + '<div class="pl-foot"><div class="lgx">' + seg.map(function (s) { return '<span><i style="background:' + s[1] + '"></i>' + s[2] + '</span>'; }).join('') + '</div><div class="r"><button type="button" class="btn dk sm" data-zoom="-1" aria-label="Alejar" title="Alejar">−</button><button type="button" class="btn dk sm" data-zoom="1" aria-label="Acercar" title="Acercar">+</button><button type="button" class="btn dk sm" data-pv="1">' + ic('gauge', 15) + 'Centrar vista</button><button type="button" class="btn dk sm" data-plfs="1" aria-label="Pantalla completa">' + ic('expand', 15) + 'Pantalla completa</button></div></div></section>'
            + '<div class="stx">'
            + '<section class="xc"><div class="xc-h"><h3>Salud de la planta</h3><div class="r">' + (salud == null ? '' : '<span class="sevp ' + (salud >= 85 ? 'ok' : salud >= 65 ? 'mid' : salud >= 45 ? 'high' : 'crit') + '"><i></i>' + (salud >= 85 ? 'Riesgo bajo' : salud >= 65 ? 'Riesgo moderado' : salud >= 45 ? 'Riesgo alto' : 'Riesgo crítico') + '</span>') + '</div></div>'
            + (salud == null ? '<div class="vacio"><b>Sin activos todavía</b>La salud se calcula cuando hay activos registrados.</div>'
                : '<div class="hlth"><div class="hr">' + ringSVG(salud, 118, 10) + '<div class="v"><b class="tn" id="hv" data-v="' + salud + '">' + fmt(salud) + '</b><small>de 100</small></div></div>'
                    + '<div class="hl-t"><b>' + (delta == null ? 'Sin variación aún' : (delta >= 0 ? '▲ ' : '▼ ') + fmt(Math.abs(delta), 1) + ' puntos desde ayer') + '</b><span>' + (explican ? explican + (explican === 1 ? ' activo explica' : ' activos explican') + ' el 70 % del riesgo.' : 'No hay riesgo registrado: todos los activos operan normal.') + '</span><div class="hl-sp" title="Salud de la planta, últimos 30 días">' + sparkSVG(ult, '#7C8CFF', 200, 46) + '</div></div></div>') + '</section>'
            + '<section class="xc"><div class="xc-h"><h3>Los ' + tot + (tot === 1 ? ' activo' : ' activos') + '</h3><small>según SIGMA FAILURE 30D</small></div><div class="dist" role="img" aria-label="' + seg.map(function (s) { return s[3] + ' ' + s[2]; }).join(', ') + '">'
            + seg.map(function (s) { return s[3] ? '<i style="flex:' + s[3] + ';background:' + s[1] + '"></i>' : ''; }).join('') + '</div><div class="dl2">' + seg.map(function (s) { return '<span><i style="background:' + s[1] + '"></i>' + s[2] + '<b class="tn">' + s[3] + '</b></span>'; }).join('') + '</div></section>'
            + '<section class="xc"><div class="xc-h"><h3>Señales en vivo</h3></div>'
            + (num(senal.SENSORES) ? '<div class="sig2"><div class="n"><b class="tn" id="sigN">' + fmt(num(senal.SENALES_MIN) || 0, 1) + '</b><small>señales por minuto</small></div><div class="bars" id="bars" aria-hidden="true">' + hg.map(function (h) { return '<i style="height:' + Math.max(4, (Number(h.N) || 0) / mx * 100) + '%"></i>'; }).join('') + '</div></div>'
                + '<div class="sig-m"><span>Sensores <b>' + (num(senal.EN_LINEA) || 0) + '/' + senal.SENSORES + '</b> en línea</span><span>' + (senal.ULTIMA_LECTURA ? 'Última lectura <b>' + hhmm(senal.ULTIMA_LECTURA) + '</b>' : 'Sin lecturas aún') + '</span></div>'
                : '<div class="vacio"><b>Sin fuente de lecturas</b>Cuando los activos tengan medidores con lecturas, aquí verás las señales por minuto.</div>') + '</section>'
            + '</div>'
            + '<section class="xc log"><div class="xc-h"><h3>Bitácora en vivo</h3><small>Todo lo que SIGMA AI hace y detecta</small><div class="r"><span class="mdl f">FAILURE 30D</span><span class="mdl r">RUL</span><span class="mdl v">VISION</span><span class="mdl s">SENSOR</span><span class="mdl o">OT</span></div></div>'
            + '<div class="lg-l" id="log" role="log" aria-live="polite">' + (V.ev.length ? V.ev.map(evHTML).join('') : '<div class="vacio"><b>Sin actividad todavía</b>Cuando SIGMA AI puntúe o alguien actúe sobre una predicción, quedará aquí.</div>') + '</div></section></div>';
    }
    var EVK = { f: ['f', 'FAILURE 30D'], r: ['r', 'RUL'], v: ['v', 'VISION'], s: ['s', 'SENSOR'], o: ['o', 'OT'] };
    function evHTML(e) {
        var k = EVK[e.TIPO] || EVK.s, p = e.ACTIVO ? activos().filter(function (a) { return a.ID === e.ACTIVO && a.PRED_ID; })[0] : null;
        return '<div class="ev' + (e.fresh ? ' new' : '') + '"><time class="tn">' + hhmm(e.F) + '</time><span class="mdl ' + k[0] + '">' + k[1] + '</span><span class="m">' + rico(e.MENSAJE) + '</span>'
            + (p ? '<button type="button" class="go" data-sel="' + p.PRED_ID + '" data-jump="1">Ver →</button>' : '<span></span>') + '</div>';
    }

    /* ------------------------------------------------------------ predicciones */
    var ST = { n: ['n', 'Nueva'], r: ['r', 'En revisión'], o: ['o', 'OT creada'], d: ['d', 'Descartada'] };
    function filtrada() {
        return cola().filter(function (p) {
            return V.qf === 'all' ? true : V.qf === 'crit' ? num(p.PROB) >= 70 && p.ESTADO !== 'd' : V.qf === 'high' ? num(p.PROB) >= 50 && num(p.PROB) < 70 && p.ESTADO !== 'd' : p.ESTADO !== 'o' && p.ESTADO !== 'd';
        });
    }
    function qHTML() {
        var c = cola(), n = function (k) { return c.filter(function (p) { return k === 'crit' ? num(p.PROB) >= 70 && p.ESTADO !== 'd' : k === 'high' ? num(p.PROB) >= 50 && num(p.PROB) < 70 && p.ESTADO !== 'd' : p.ESTADO !== 'o' && p.ESTADO !== 'd'; }).length; };
        var vacio = !publicado(modelo('failure'))
            ? '<div class="aprende"><span>' + ic('alert', 18) + '</span><div><b>Aprendiendo · sin versión publicada.</b> SIGMA FAILURE 30D aún no tiene una versión publicada: cuando el equipo la publique, las predicciones aparecen aquí.</div></div>'
            : '<div class="aprende"><span>' + ic('check', 18) + '</span><div><b>Sin predicciones abiertas.</b> SIGMA FAILURE 30D no ha puntuado ningún activo todavía: usa «Puntuar ahora» o espera la próxima puntuación.</div></div>';
        var list = filtrada();
        return '<section class="xc q"><div class="xc-h"><h3>Cola priorizada</h3><small>' + abiertas().length + ' predicciones activas · ordenadas por probabilidad</small>'
            + '<div class="r">' + [['all', 'Todas', c.length], ['crit', 'Críticas', n('crit')], ['high', 'Altas', n('high')], ['sin', 'Sin OT', n('sin')]].map(function (x) { return '<button type="button" class="chipx" data-qf="' + x[0] + '" aria-pressed="' + (V.qf === x[0]) + '">' + x[1] + ' <b class="tn">' + x[2] + '</b></button>'; }).join('') + '</div></div>'
            + (c.length ? '<div class="qt" id="qt"><div class="qr h"><span>Activo · componente</span><span>Probabilidad</span><span>Horizonte</span><span>14 días</span><span>Estado</span></div>' + (list.map(qRow).join('') || '<p style="color:var(--x-mut);padding:12px">Nada en este filtro.</p>') + '</div>' : vacio) + '</section>';
    }
    function qRow(p) {
        var pr = num(p.PROB) || 0, s = sev(pr), st = ST[p.ESTADO] || ST.r;
        return '<button type="button" class="qr' + (String(V.sel) === String(p.ID) ? ' on' : '') + '" data-sel="' + p.ID + '" id="qr-' + p.ID + '"><span class="a"><b>' + esc(p.ACTIVO) + '</b><small>' + esc([p.COMPONENTE, p.AREA, p.CODIGO].filter(Boolean).join(' · ')) + '</small></span>'
            + '<span class="pb"><b class="tn">' + fmt(pr) + ' %</b><span><i style="width:' + Math.min(100, pr) + '%;background:' + s[1] + '"></i></span></span><span class="hz">' + esc(plazo(p)) + '</span>'
            + '<span class="tr2" style="height:26px">' + sparkSVG(tend(p).map(function (x) { return num(x.p); }), s[1], 86, 26, false, 0, 100) + '</span>'
            + '<span class="st3 ' + st[0] + '">' + st[1] + (p.ESTADO === 'o' && p.OT_NUM ? ' · ' + p.OT_NUM : '') + '</span></button>';
    }
    function dtHTML() {
        var p = predOf(V.sel);
        if (!p) return '<section class="xc dt" id="dt" aria-label="Detalle de la predicción"><div class="vacio"><b>Elige una predicción</b>Aquí verás por qué SIGMA AI la hizo, cómo ha evolucionado y qué hacer.</div></section>';
        var pr = num(p.PROB) || 0, s = sev(pr), det = V.det && String(V.detId) === String(p.ID) ? V.det : null, razones = det ? det.razones : null;
        var cs = (razones || []).map(function (r) {
            var c = Math.abs(Number(r.CONTRIBUCION) || 0), dir = String(r.DIRECCION || '').toUpperCase(), neg = (Number(r.CONTRIBUCION) || 0) < 0 || /BAJ|DOWN|NEG|-/.test(dir);
            return { t: r.TEXTO, v: c, neg: neg };
        }).filter(function (x) { return x.t; });
        var mx = Math.max.apply(null, cs.map(function (c) { return c.v; }).concat([0.0001]));
        return '<section class="xc dt" id="dt" aria-label="Detalle de la predicción"><div class="dh"><div style="flex:1;min-width:0"><span class="sevp ' + s[0] + '"><i></i>' + s[2] + ' · ' + fmt(pr) + ' %</span><h3 style="margin-top:8px">' + esc(nombreAct(p)) + '</h3><small>' + esc([p.COMPONENTE ? p.ACTIVO : '', p.AREA, p.CODIGO].filter(Boolean).join(' · ')) + '</small></div><span class="mdl f">FAILURE 30D · v' + (p.VERSION || '') + '</span></div>'
            + '<div class="dhero"><div class="ring2">' + ringSVG(pr, 104, 9) + '<div class="v"><b class="tn">' + fmt(pr) + ' %</b><small>probabilidad<br>de falla</small></div></div><div class="when"><small>Falla probable en</small><b class="tn">' + esc(plazo(p)) + '</b><span>' + esc(fechaLimite(p)) + (num(p.CONFIANZA) != null ? ' · confianza ' + fmt(num(p.CONFIANZA)) + ' %' : '') + '</span></div></div>'
            + '<div class="sub-h">Por qué lo dice SIGMA AI</div>'
            + (!det ? '<p class="cnote">Cargando las razones…</p>' : cs.length ? '<div class="contrib">' + cs.map(function (c) { var w = c.v / mx * 50; return '<div class="cb"><span>' + esc(c.t) + '</span><span class="tr3"><i style="' + (c.neg ? 'right:50%;width:' + w + '%;background:linear-gradient(270deg,#4FEAD3,#00B5A0)' : 'left:50%;width:' + w + '%;background:linear-gradient(90deg,#FF8FB0,#FF4D80)') + '"></i></span><b class="' + (c.neg ? 'n' : 'p') + '">' + (c.neg ? '−' : '+') + fmt(c.v, 2) + '</b></div>'; }).join('') + '</div><p class="cnote">Rosado sube el riesgo y teal lo baja. Son los pesos del modelo para la fila de hoy de este activo.</p>'
                    : '<p class="cnote">El modelo no guardó las razones de esta puntuación.</p>')
            + '<div class="sub-h" id="subSenal">' + (det && det.medidor && det.medidor.length >= 2 ? 'La señal que lo explica' : 'Cómo ha evolucionado') + '</div>'
            + '<div class="chart2"><div class="hd"><span id="chHd"></span><span class="lgd"><span><i></i>Medición</span><span><i class="t"></i>' + (det && det.medidor && det.medidor.length >= 2 ? 'Hoy' : 'Crítica 70 %') + '</span></span></div><div class="plot2" id="plot2" role="img" aria-label="Probabilidad de falla de ' + esc(p.ACTIVO) + ' en los últimos 30 días; hoy ' + fmt(pr) + ' por ciento."></div></div>'
            + '<div class="sub-h">Qué hacer</div>' + recHTML(p, det)
            + '<div class="dacts">' + (p.ESTADO === 'o' ? '<span class="btn sm ok">' + ic('check', 15) + 'OT ' + esc(p.OT_NUM || '') + ' creada</span>' : p.ESTADO === 'd' ? '<button type="button" class="btn dk sm" data-undo="' + p.ID + '">Reabrir predicción</button>'
                : (D.puedeOt && p.ALERTA_ID ? '<button type="button" class="btn pri sm" data-ot="' + p.ID + '">' + ic('plus', 15) + 'Crear OT preventiva</button>' : '<button type="button" class="btn pri sm" disabled title="' + (D.puedeOt ? 'Esta predicción aún no tiene alerta asociada' : 'No tienes permiso para generar órdenes') + '">' + ic('plus', 15) + 'Crear OT preventiva</button>'))
            + '<button type="button" class="btn dk sm" data-ask="¿Por qué ' + esc(p.ACTIVO.toLowerCase()) + '?">' + ic('bot', 15) + 'Preguntar</button>'
            + (p.ESTADO !== 'd' && p.ESTADO !== 'o' ? '<button type="button" class="btn dkp sm" data-dis="' + p.ID + '">Descartar</button>' : '') + '</div></section>';
    }
    function recHTML(p, det) {
        var rec = det && det.rec, accion = 'Revisar ' + (p.COMPONENTE ? 'el componente «' + p.COMPONENTE + '»' : 'el activo') + ' de ' + p.ACTIVO;
        var partes = [];
        if (p.FECHA_EVENTO) partes.push(fechaLimite(p));
        if (rec && num(rec.DURACION_MIN)) partes.push('~' + (num(rec.DURACION_MIN) >= 60 ? fmt(num(rec.DURACION_MIN) / 60, 1) + ' h' : fmt(num(rec.DURACION_MIN)) + ' min') + ' (lo que suele durar en este activo)');
        if (rec && rec.REPUESTO_CODIGO) partes.push(rec.REPUESTO_CODIGO + ' · ' + rec.REPUESTO_NOMBRE + ' · stock ' + fmt(num(rec.STOCK) || 0, 2) + ' (mín. ' + fmt(num(rec.MINIMO) || 0, 2) + ')');
        return '<div class="rcm">' + ic('wrench', 18) + '<div><b>' + esc(accion) + '</b><span>' + esc(partes.join(' · ') || 'SIGMA AI sugiere programar una intervención antes de la fecha estimada.') + '</span></div></div>';
    }
    function plot2() {
        var el = $('#plot2'); if (!el) return;
        var p = predOf(V.sel); if (!p) return;
        var det = V.det && String(V.detId) === String(p.ID) ? V.det : null, hd = $('#chHd');
        var medidor = det && det.medidor && det.medidor.length >= 2 ? det.medidor : null;
        var pts, lo, hi, umbral = null, unidad = '';
        if (medidor) { pts = medidor.map(function (m) { return { t: new Date(m.DIA).getTime(), v: Number(m.VALOR) }; }); var vs = pts.map(function (x) { return x.v; }); lo = Math.min.apply(null, vs); hi = Math.max.apply(null, vs); if (hi === lo) { lo -= 1; hi += 1; } }
        else { pts = (det ? det.curva : tend(p)).map(function (c) { return { t: new Date(c.FECHA || c.f).getTime(), v: Number(c.PROB != null ? c.PROB : c.p) }; }); lo = 0; hi = 100; umbral = 70; }
        if (hd) hd.innerHTML = medidor ? '<b class="tn">' + fmt(pts[pts.length - 1].v, 1) + '</b> ' + esc(medidor[0].MEDIDOR || '') : '<b class="tn">' + fmt(num(p.PROB) || 0) + '</b>% · probabilidad de falla';
        if (pts.length < 2) { el.innerHTML = '<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;text-align:center;color:var(--x-mut);font-size:12.5px;padding:0 14px">Hay una sola corrida del modelo para este activo: la curva aparece con la siguiente.</div>'; return; }
        var ahora = Date.now(), t0 = ahora - 30 * 86400000, W = 1000, H = 300;
        function X(t) { return Math.max(0, Math.min(1, (t - t0) / (ahora - t0))) * W; } function Y(v) { return H - (v - lo) / (hi - lo) * H; } function pct(v) { return (1 - (v - lo) / (hi - lo)) * 100; }
        var line = pts.map(function (c, i) { return (i ? 'L' : 'M') + X(c.t).toFixed(1) + ' ' + Y(c.v).toFixed(1); }).join(''), last = pts[pts.length - 1];
        var ticks = [1, 2, 3].map(function (k) { return lo + (hi - lo) / 4 * k; });
        el.innerHTML = '<svg viewBox="0 0 1000 300" preserveAspectRatio="none" aria-hidden="true"><defs><linearGradient id="arF2" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#7C8CFF" stop-opacity=".35"/><stop offset="1" stop-color="#7C8CFF" stop-opacity="0"/></linearGradient></defs>'
            + ticks.map(function (t) { return '<line x1="0" x2="1000" y1="' + Y(t) + '" y2="' + Y(t) + '" stroke="rgba(148,163,214,.12)" vector-effect="non-scaling-stroke"/>'; }).join('')
            + (umbral != null ? '<line x1="0" x2="1000" y1="' + Y(umbral) + '" y2="' + Y(umbral) + '" stroke="#FFB547" stroke-width="1.5" stroke-dasharray="6 5" vector-effect="non-scaling-stroke"/>' : '')
            + '<path d="' + line + 'L' + X(last.t).toFixed(1) + ' 300L' + X(pts[0].t).toFixed(1) + ' 300Z" fill="url(#arF2)"/><path d="' + line + '" fill="none" stroke="#7C8CFF" stroke-width="2" vector-effect="non-scaling-stroke"/></svg>'
            + ticks.map(function (t) { return '<span class="ylab tn" style="top:' + pct(t) + '%">' + fmt(t, medidor ? 1 : 0) + '</span>'; }).join('')
            + (umbral != null ? '<span class="thr" style="left:6px;right:auto;top:' + pct(umbral) + '%">Crítica 70 %</span>' : '')
            + [[0, 'hace 30 d'], [.5, 'hace 15 d'], [1, 'hoy']].map(function (x) { return '<span class="xlab" style="left:' + x[0] * 100 + '%' + (x[0] === 1 ? ';transform:translateX(-100%)' : x[0] === 0 ? ';transform:none' : '') + '">' + x[1] + '</span>'; }).join('')
            + '<span class="nowdot" style="left:' + X(last.t) / W * 100 + '%;top:' + pct(last.v) + '%"></span><span class="cross"></span><span class="tip"></span>';
        el._geo = { pts: pts, X: X, W: W, pct: pct, t0: t0, ahora: ahora, dec: medidor ? 1 : 0, suf: medidor ? '' : ' %' };
    }

    /* ------------------------------------------------------------ vida útil (SIGMA RUL) */
    function rulHTML() {
        var L = (D.rul || []), m = modelo('rul'), MAX = 180, X = function (d) { return Math.min(100, d / MAX * 100); }, colOf = function (d) { return d < 30 ? '#FF5C8A' : d < 60 ? '#FFB547' : '#00E0C2'; };
        var cab = '<div class="sec-t" id="rul"><div><span class="k">SIGMA RUL</span><h2>Vida útil de los repuestos instalados</h2><p>Mediana de días restantes con su intervalo del 80 %. La línea ámbar es el umbral de aviso (30 días).</p></div></div>';
        if (!L.length) return cab + '<section class="xc rul">' + (publicado(m)
            ? '<div class="aprende"><span>' + ic('check', 18) + '</span><div><b>Sin repuestos puntuados.</b> SIGMA RUL no tiene repuestos instalados con vida útil estimada: se llena con «Puntuar ahora» cuando hay repuestos instalados en componentes.</div></div>'
            : '<div class="aprende"><span>' + ic('alert', 18) + '</span><div><b>Aprendiendo · sin versión publicada.</b> SIGMA RUL aún no tiene una versión publicada.</div></div>') + '</section>';
        return cab + '<section class="xc rul"><div class="rg2"><div class="hd2">Repuesto · activo</div><div class="ax">' + [0, 30, 60, 90, 120, 150, 180].map(function (d) { return '<span style="left:' + X(d) + '%' + (d === 180 ? ';transform:translateX(-100%)' : d === 0 ? ';transform:none' : '') + '">' + (d ? d + ' d' : 'Hoy') + '</span>'; }).join('') + '</div><div class="hd2">Días</div><div class="hd2">En bodega</div>'
            + L.map(function (r) {
                var d = num(r.DIAS) || 0, lo = num(r.DIAS_MIN), hi = num(r.DIAS_MAX), c = colOf(d), stock = num(r.STOCK) || 0, min = num(r.MINIMO) || 0, low = stock < Math.max(1, min), pedido = r.PEDIDO || V.ordered[r.REPUESTO_ID];
                return '<div class="rr"><div class="p"><b>' + esc(r.REPUESTO) + '</b><small>' + esc(r.ACTIVO) + ' · <code>' + esc(r.CODIGO) + '</code></small></div>'
                    + '<div class="rt">' + [30, 60, 90, 120, 150].map(function (x) { return '<span class="g" style="left:' + X(x) + '%"></span>'; }).join('') + '<span class="thr2" style="left:' + X(30) + '%"></span>'
                    + (lo != null && hi != null ? '<span class="iv" style="left:' + X(lo) + '%;width:' + Math.max(1, X(hi) - X(lo)) + '%;background:' + c + '"></span>' : '') + '<span class="md" style="left:' + X(d) + '%;background:' + c + ';color:' + c + '" title="' + d + ' días' + (lo != null ? ' (' + lo + '–' + hi + ')' : '') + '"></span></div>'
                    + '<div class="dd"><b class="tn">' + fmt(d) + ' d</b>' + (lo != null && hi != null ? fmt(lo) + '–' + fmt(hi) : '') + '</div>'
                    + '<div class="sk"><span>Stock <b class="' + (low ? 'bad' : '') + '">' + fmt(stock, 2) + '</b> · mín. ' + fmt(min, 2) + '</span>'
                    + (low && d < 60 ? (pedido ? '<span style="color:#6EE7B7;font-weight:700">' + ic('check', 13) + ' Pedido</span>' : '<button type="button" class="btn dk sm" style="height:28px" data-pedir="' + r.REPUESTO_ID + '|' + r.ID + '">Pedir reposición</button>') : '') + '</div></div>';
            }).join('') + '</div></section>';
    }

    /* ------------------------------------------------------------ visión */
    var LAB_COL = ['#FF8A3D', '#38BDF8', '#FFB547', '#34D399', '#C084FC', '#F472B6'];
    function labCol(l) { var i = 0; for (var k = 0; k < l.length; k++) i += l.charCodeAt(k); return LAB_COL[i % LAB_COL.length]; }
    function etiquetasConocidas() { var s = {}; ((D && D.fotos) || []).forEach(function (f) { f.dets.forEach(function (d) { s[d.ETIQUETA] = 1; }); }); return Object.keys(s); }
    function visHTML() {
        var F = D.fotos || [], pend = num(D.pendientes) || 0, m = modelo('vision');
        var cab = '<div class="sec-t" id="vis"><div><span class="k">SIGMA VISION</span><h2>Fotos de terreno</h2><p>Lo que SIGMA VISION ve en las fotos que sube tu equipo. Una persona confirma cada etiqueta, y eso entrena el próximo modelo.</p></div></div>';
        if (!F.length) return cab + '<section class="xc vis">' + (publicado(m) ? '<div class="aprende"><span>' + ic('check', 18) + '</span><div><b>Sin fotos clasificadas.</b> Cuando alguien suba una foto de terreno, SIGMA VISION la clasifica y queda aquí para confirmarla.</div></div>'
            : '<div class="aprende"><span>' + ic('alert', 18) + '</span><div><b>Aprendiendo · sin versión publicada.</b> SIGMA VISION aún no tiene una versión publicada.</div></div>') + '</section>';
        return cab + '<section class="xc vis">' + (pend ? '<div class="vbn">' + ic('alert', 16) + '<span><b>' + pend + (pend === 1 ? ' foto' : ' fotos') + '</b> esperan tu confirmación. Cada confirmación mejora SIGMA VISION' + (m && m.VERSION ? ' v' + (num(m.VERSION) + 1) : '') + '.</span></div>'
            : '<div class="vbn" style="background:rgba(52,211,153,.08);box-shadow:inset 0 0 0 1px rgba(52,211,153,.3)">' + ic('check', 16) + '<span><b>Todo confirmado.</b> Gracias: estas etiquetas entran al próximo entrenamiento.</span></div>')
            + '<div class="vg">' + F.map(function (f) {
                var d = f.dets[0], conf = f.dets.length && f.dets.every(function (x) { return x.CONFIRMADO; }), c = d ? labCol(d.ETIQUETA) : '#7C8CFF', ok = conf || (f.revisado && !f.dets.length);
                return '<article class="vc" data-vc="' + f.id + '"><div class="ph">' + (f.url ? '<img src="' + esc(f.url) + '" alt="Foto de terreno: ' + esc(f.nombre) + '" loading="lazy">' : '<span class="sinfoto">Sin imagen</span>')
                    + (d && d.X != null ? '<span class="bx" style="left:' + d.X + '%;top:' + d.Y + '%;width:' + d.W + '%;height:' + d.H + '%;border-color:' + c + '"><span style="background:' + c + '">' + esc(d.ETIQUETA) + ' ' + fmt(num(d.CONFIANZA)) + ' %</span></span>' : '')
                    + '<span class="tg2' + (ok ? ' ok' : '') + '">' + (ok ? '✓ Confirmada' : 'Por confirmar') + '</span></div>'
                    + '<div class="bd"><div><b>' + esc(f.nombre || 'Foto de terreno') + '</b><small style="display:block">' + esc(f.subio || '—') + ' · ' + ago(f.fecha) + '</small></div>'
                    + '<div class="lbs">' + f.dets.slice(0, 3).map(function (x) { return '<div class="lb"><span style="background:none;height:auto;color:var(--x-ink2)">' + esc(x.ETIQUETA) + '</span><span><i style="width:' + Math.min(100, num(x.CONFIANZA) || 0) + '%;background:' + labCol(x.ETIQUETA) + '"></i></span><b class="tn">' + fmt(num(x.CONFIANZA) || 0) + ' %</b></div>'; }).join('') + '</div>'
                    + (ok || !d ? '' : '<div class="vacts"><button type="button" class="btn pri sm" data-vok="' + d.ID + '|' + esc(d.ETIQUETA) + '|' + f.id + '">' + ic('check', 15) + 'Confirmar ' + esc(d.ETIQUETA.toLowerCase()) + '</button><button type="button" class="btn dk sm" data-vfix="' + d.ID + '|' + esc(d.ETIQUETA) + '|' + f.id + '">Corregir</button></div>') + '</div></article>';
            }).join('') + '</div></section>';
    }

    /* ------------------------------------------------------------ modelos */
    function modHTML() {
        var EQ = !!D.puedeModelos, M = EQ ? (D.modelos || []) : [], mes = D.mes || {}, vers = D.versiones || [], F = D.fotos || [];
        function hist(id, campo) { return vers.filter(function (v) { return v.MODELO_ID === id && num(v[campo]) != null; }).map(function (v) { return num(v[campo]); }); }
        function f2(v, d) { return v == null || v === '' ? '—' : fmt(Number(v), d == null ? 2 : d); }
        var cards = M.map(function (m) {
            var k = norm(m.MODELO).indexOf('rul') >= 0 ? 'r' : norm(m.MODELO).indexOf('vision') >= 0 ? 'v' : 'f', pub = publicado(m);
            if (!pub) return '<article class="mc"><div class="mc-h"><span class="mdl ' + k + '" style="margin-top:2px">—</span><div style="min-width:0"><b>' + esc(m.MODELO) + '</b><small>' + esc(m.DESCRIPCION || '') + '</small></div><span class="pub" style="background:rgba(255,181,71,.14);color:#FFCB7A">Aprendiendo</span></div><div class="aprende"><span>' + ic('alert', 18) + '</span><div><b>Sin versión publicada.</b> Cuando el equipo publique una versión, verás aquí sus métricas.</div></div></article>';
            var met, hl, hv, inv = false, color = k === 'r' ? '#00E0C2' : k === 'v' ? '#FF7EB8' : '#7C8CFF';
            if (k === 'f') { met = [[f2(m.AUC), 'AUC'], [f2(m.PRECISION_), 'Precisión'], [f2(m.RECALL_), 'Recall'], [f2(m.F1), 'F1']]; hl = 'AUC por versión'; hv = hist(m.MODELO_ID, 'AUC'); }
            else if (k === 'r') { met = [[m.MAE == null ? '—' : f2(m.MAE, 1) + ' d', 'Error medio'], [m.COBERTURA == null ? '—' : fmt(Number(m.COBERTURA) * (Number(m.COBERTURA) <= 1 ? 100 : 1)) + ' %', 'Cobertura 80 %'], [String((D.rul || []).length), 'Repuestos'], [m.UMBRAL == null ? '30 d' : fmt(Number(m.UMBRAL)) + ' d', 'Umbral']]; hl = 'Error medio en días por versión'; hv = hist(m.MODELO_ID, 'MAE'); inv = true; }
            else { var conf = 0; F.forEach(function (x) { x.dets.forEach(function (d) { if (d.CONFIRMADO) conf++; }); }); met = [[String(F.length), 'Fotos'], [String(conf), 'Confirmadas'], [String(num(D.pendientes) || 0), 'Por confirmar'], [String(etiquetasConocidas().length), 'Etiquetas']]; hl = ''; hv = []; }
            var ft = [];
            if (m.VERIFICADA) ft.push(['ok', 'Hash del .onnx verificado en Azure ML · ' + new Date(m.VERIFICADA).toLocaleDateString('es-CL', { day: 'numeric', month: 'short' })]); else if (m.HASH) ft.push(['w', 'Hash registrado, aún sin verificar en Azure ML']);
            if (m.DATASET_FILAS) ft.push(['ok', 'Dataset: ' + fmt(Number(m.DATASET_FILAS)) + ' filas' + (m.ENTRENADA ? ' · entrenada el ' + new Date(m.ENTRENADA).toLocaleDateString('es-CL', { day: 'numeric', month: 'short' }) : '')]); else if (m.ENTRENADA) ft.push(['ok', 'Entrenada el ' + new Date(m.ENTRENADA).toLocaleDateString('es-CL', { day: 'numeric', month: 'short' })]);
            if (k === 'v' && (num(D.pendientes) || 0)) ft.push(['w', (num(D.pendientes)) + (num(D.pendientes) === 1 ? ' foto espera' : ' fotos esperan') + ' confirmación']);
            return '<article class="mc"><div class="mc-h"><span class="mdl ' + k + '" style="margin-top:2px">v' + m.VERSION + '</span><div style="min-width:0"><b>' + esc(m.MODELO) + '</b><small>' + esc(m.ALGORITMO || '') + '</small></div><span class="pub">Publicada</span></div>'
                + '<div class="mtx">' + met.map(function (x) { return '<div><b class="tn">' + x[0] + '</b><small>' + x[1] + '</small></div>'; }).join('') + '</div>'
                + (hv.length >= 2 ? '<div><small style="font-size:11px;color:var(--x-mut)">' + hl + (inv ? ' · más bajo es mejor' : '') + '</small><div class="spk">' + sparkSVG(hv, color, 200, 44) + '</div></div>' : '')
                + '<div class="ft">' + ft.map(function (x) { return '<span class="' + (x[0] === 'w' ? 'w' : '') + '">' + ic(x[0] === 'w' ? 'alert' : 'check', 14) + esc(x[1]) + '</span>'; }).join('') + '</div></article>';
        }).join('');
        function o(v, a, b) { return '<div><b class="tn">' + (v == null ? '—' : v) + '</b><small>' + a + '</small><span>' + b + '</span></div>'; }
        return '<div class="sec-t" id="mod"><div><span class="k">' + (EQ ? 'Modelos' : 'Resultados') + '</span><h2>' + (EQ ? 'Salud de los modelos' : 'Cómo le fue a SIGMA AI este mes') + '</h2><p>' + (EQ ? 'Los modelos publicados, con sus métricas y cómo le fue a SIGMA AI este mes.' : 'Lo que SIGMA AI anticipó este mes, comparado con las órdenes correctivas reales.') + '</p></div></div>'
            + '<section class="xc mods">' + (!EQ ? '' : M.length ? '<div class="mg">' + cards + '</div>' : '<div class="aprende"><span>' + ic('alert', 18) + '</span><div><b>Aprendiendo · sin modelos.</b> Aún no hay modelos de SIGMA AI registrados.</div></div>')
            + '<div class="out">' + o(num(mes.ANTICIPADAS), 'fallas anticipadas', 'avisó antes y hubo una correctiva') + o(num(mes.FALSAS), 'falsas alarmas', 'descartadas con ese motivo') + o(num(mes.NO_ANTICIPADAS), 'fallas no anticipadas', 'entran al próximo dataset') + o(null, 'horas de detención evitadas', 'se calcula con las órdenes cerradas') + '</div></section>';
    }

    /* ------------------------------------------------------------ copiloto */
    function railHTML() {
        var p = predOf(V.sel), n = (D.modelos || []).filter(publicado).length;
        return '<div class="rl-h"><span class="o">' + simbolo(26) + '</span><div><b>SIGMA AI Chat</b><small><i></i>Conectado a ' + n + (n === 1 ? ' modelo' : ' modelos') + '</small></div><span class="sp"><button type="button" class="ib2" data-railfs="1" aria-label="Pantalla completa" title="Pantalla completa">' + ic('expand', 17) + '</button><button type="button" class="ib2" data-railx="1" aria-label="Cerrar el chat" title="Cerrar">' + ic('x', 17) + '</button></span></div>'
            + '<div class="ctx2" id="ctx2"></div><div class="msgs" id="msgs"></div><div class="rl-f"><div class="rsug" id="rsug"></div>'
            + '<div class="rin" id="rinF"><input id="rinQ" placeholder="Pregúntale a SIGMA AI…" aria-label="Pregunta para SIGMA AI" autocomplete="off"><button type="button" class="send" data-enviar="1" aria-label="Enviar">' + ic('send', 17) + '</button></div></div>';
    }
    function sugs() {
        var p = predOf(V.sel), s = $('#rsug'), c = $('#ctx2'); if (!s) return;
        var lista = (p ? ['¿Por qué ' + p.ACTIVO.toLowerCase() + '?'] : []).concat(['¿Qué reviso primero hoy?', 'Repuestos en riesgo', 'Fotos por confirmar']);
        s.innerHTML = lista.map(function (t) { return '<button type="button" data-ask="' + esc(t) + '">' + esc(t) + '</button>'; }).join('');
        c.innerHTML = p ? ic('pin', 14) + '<span>Mirando: <b>' + esc(p.ACTIVO) + '</b>' + (p.COMPONENTE ? ' · ' + esc(p.COMPONENTE) : '') + '</span>' : ic('pin', 14) + '<span>Mirando: <b>toda la planta</b></span>';
    }
    function addMsg(html, me) {
        var m = $('#msgs'); if (!m) return null;
        var d = document.createElement('div'); d.className = 'mg2' + (me ? ' me' : '');
        d.innerHTML = me ? '<div class="bb">' + html + '</div>' : '<span class="o">' + simbolo(22) + '</span><div class="bb">' + html + '</div>';
        m.appendChild(d); m.scrollTop = m.scrollHeight; return d;
    }
    var typingT = null;
    function aiSay(texto, fuentes, acciones) {
        var d = addMsg('<span class="thinking"><i></i><i></i><i></i></span>'); if (!d) return;
        var bb = d.querySelector('.bb'), m = $('#msgs');
        setTimeout(function () {
            bb.innerHTML = '<span class="tt"></span><span class="caret"></span>';
            var tt = bb.querySelector('.tt'), k = 0; clearInterval(typingT);
            function fin() {
                var c = bb.querySelector('.caret'); if (c) c.remove(); tt.innerHTML = rico(texto);
                bb.insertAdjacentHTML('beforeend', ((fuentes || []).length ? '<div class="src">' + fuentes.map(function (s) { return '<span class="mdl ' + s.k + '">' + esc(s.t) + '</span>'; }).join('') + '</div>' : '')
                    + ((acciones || []).length ? '<div class="acts2">' + acciones.map(function (a) { return '<button type="button" class="btn ' + (a.tipo === 'ot' || a.tipo === 'pedir' ? 'pri' : 'dk') + ' sm" data-ai-' + a.tipo + '="' + esc(a.valor) + '">' + esc(a.rotulo) + '</button>'; }).join('') + '</div>' : ''));
                m.scrollTop = m.scrollHeight;
            }
            if (RM) { fin(); return; }
            var pl = plano(texto);
            typingT = setInterval(function () { k += 3; tt.textContent = pl.slice(0, k); m.scrollTop = m.scrollHeight; if (k >= pl.length) { clearInterval(typingT); fin(); } }, 16);
        }, RM ? 0 : 600);
    }
    function preguntar(q) {
        addMsg(esc(q), true);
        var p = predOf(V.sel);
        ws('Copiloto', { pregunta: q, activo: p ? p.ACTIVO_ID : 0, planta: V.planta }).then(function (r) { aiSay(r.texto, r.fuentes, r.acciones); }).catch(function (e) { aiSay('No pude responder: ' + e.message, [], []); });
    }
    function saludo() {
        if (V.greeted) return; V.greeted = true;
        var h = new Date().getHours(), ab = abiertas(), crit = ab.filter(function (p) { return num(p.PROB) >= 70; }).length, pend = num(D.pendientes) || 0;
        var t = (h < 12 ? 'Buenos días' : h < 20 ? 'Buenas tardes' : 'Buenas noches') + (D.usuario ? ', ' + D.usuario : '') + '. ' + (ab.length ? 'Hay **' + ab.length + (ab.length === 1 ? ' predicción abierta' : ' predicciones abiertas') + '**' + (crit ? ' (**' + crit + '** críticas)' : '') + '.' : 'Por ahora **no hay predicciones abiertas**.') + (pend ? ' Hay **' + pend + (pend === 1 ? ' foto' : ' fotos') + '** esperando tu confirmación.' : '');
        var acc = []; if (ab.length) acc.push({ tipo: 'sel', rotulo: 'Ver la más urgente', valor: String(ab.slice().sort(function (a, b) { return num(b.PROB) - num(a.PROB); })[0].ID) }); if (pend) acc.push({ tipo: 'goto', rotulo: 'Ver fotos', valor: 'vis' });
        aiSay(t, [{ k: 'f', t: 'FAILURE 30D' }], acc);
    }

    /* ------------------------------------------------------------ render, selección y 3D */
    function render() {
        $('#ccm').innerHTML = headHTML() + monHTML()
            + '<div class="sec-t" id="pred"><div><span class="k">SIGMA FAILURE 30D</span><h2>Predicciones de falla</h2><p>Qué podría fallar en los próximos 30 días, por qué, y qué hacer.</p></div></div><div class="xg" id="predg">' + qHTML() + dtHTML() + '</div>'
            + rulHTML() + visHTML() + modHTML();
        $('#rail').innerHTML = railHTML(); sugs();
        var s = $('#railO'); if (s) s.innerHTML = simbolo(22);
        plot2(); mount3D(); intro(); spy(); saludo();
        document.body.classList.toggle('rail-off', !V.rail);
    }
    function refreshPred() { var g = $('#predg'); if (!g) return; g.innerHTML = qHTML() + dtHTML(); plot2(); sugs(); ringIn($('#dt')); }
    function ringIn(r) { if (!r || !G() || RM) return; $$('.rgv', r).forEach(function (x) { G().fromTo(x, { attr: { 'stroke-dashoffset': x.getAttribute('data-c') } }, { attr: { 'stroke-dashoffset': x.getAttribute('data-c') * (1 - x.getAttribute('data-v') / 100) }, duration: 1.3, ease: 'power3.out' }); }); }
    function select(id, jump) {
        var p = predOf(id); if (!p) return;
        V.sel = p.ID; V.det = null; V.detId = null;
        $$('.qr[data-sel]').forEach(function (r) { r.classList.toggle('on', r.getAttribute('data-sel') === String(p.ID)); });
        var dt = $('#dt'); if (dt) { dt.outerHTML = dtHTML(); plot2(); ringIn($('#dt')); }
        if (G3) G3.focus('a' + p.ACTIVO_ID);
        sugs();
        ws('Detalle', { id: p.ID }).then(function (d) { if (String(V.sel) !== String(p.ID)) return; V.det = d; V.detId = p.ID; var dt2 = $('#dt'); if (dt2) { dt2.outerHTML = dtHTML(); plot2(); ringIn($('#dt')); } }).catch(function () { });
        if (jump) $('#pred').scrollIntoView({ behavior: RM ? 'auto' : 'smooth', block: 'start' });
    }
    /* la distribucion de las areas en la escena: cada area una plataforma, en filas de hasta 3 */
    function distribuir() {
        var areas = (D.areas || []).filter(function (a) { return a.ACTIVOS > 0; }), out = [], fila = [], filas = [];
        areas.forEach(function (a) { var n = a.ACTIVOS, w = Math.max(2.4, Math.min(5.6, 1.3 + n * .55)), d = Math.max(2, Math.min(3.4, 1.3 + Math.sqrt(n) * .6)); fila.push({ a: a, w: w, d: d }); if (fila.length === 3) { filas.push(fila); fila = []; } });
        if (fila.length) filas.push(fila);
        var z = 0, total = filas.reduce(function (s, f) { return s + Math.max.apply(null, f.map(function (x) { return x.d; })) + .9; }, 0); z = -total / 2;
        filas.forEach(function (f) {
            var h = Math.max.apply(null, f.map(function (x) { return x.d; })), ancho = f.reduce(function (s, x) { return s + x.w + .8; }, 0), x0 = -ancho / 2;
            f.forEach(function (x) { out.push({ id: x.a.ID, n: x.a.NOMBRE, cx: x0 + x.w / 2, cz: z + h / 2, w: x.w, d: x.d }); x0 += x.w + .8; }); z += h + .9;
        });
        return out;
    }
    function mount3D() {
        if (G3) { try { G3.dispose(); } catch (e) { } G3 = null; }
        var canvas = $('#pl3d'); if (!canvas || G3Cargando) return;
        var areas = distribuir(); if (!areas.length) return;
        G3Cargando = true;
        import(JS3D).then(function (mod) {
            G3Cargando = false;
            var cv = $('#pl3d'); if (!cv) return;
            var tip = $('#plTip'), host = $('#plant');
            G3 = mod.mount(cv, {
                host: host, labelEl: $('#plLab'), reduced: RM, sel: V.sel ? 'a' + (predOf(V.sel) || {}).ACTIVO_ID : null, areas: areas,
                assets: activos().map(function (a) { return { id: 'a' + a.ID, name: a.NOMBRE, area: a.AREA_ID, code: a.CODIGO, p: num(a.PROB) || 0, raw: a }; }),
                onHover: function (id, x, y) {
                    var a = activos().filter(function (z) { return 'a' + z.ID === id; })[0]; if (!a) return;
                    var pr = num(a.PROB), s = sevAct(a), ar = (D.areas || []).filter(function (z) { return z.ID === a.AREA_ID; })[0];
                    tip.innerHTML = (a.FOTO ? '<img class="tipimg" src="' + esc(a.FOTO) + '" alt="">' : '') + '<b>' + esc(a.NOMBRE) + '</b><small>' + esc((ar ? ar.NOMBRE : 'Sin área') + ' · ' + a.CODIGO) + '</small>' + (a.COMPONENTE ? '<small>' + esc(a.COMPONENTE) + '</small>' : '')
                        + '<span class="sevp ' + s[0] + '"><i></i>' + (pr != null && pr >= 25 ? fmt(pr) + ' % · falla en ' + esc(plazo(a)) : 'Saludable · salud ' + fmt(100 - (pr || 0)) + '/100') + '</span>';
                    tip.style.left = x + 'px'; tip.style.top = y + 'px'; tip.style.opacity = 1;
                },
                onLeave: function () { tip.style.opacity = 0; },
                onSelect: function (id) { var a = activos().filter(function (z) { return 'a' + z.ID === id; })[0]; if (a && a.PRED_ID && predOf(a.PRED_ID)) select(a.PRED_ID, true); else toast('Activo saludable: sin predicciones abiertas.'); }
            });
            if (G3) { host.classList.add('has3d'); G3.filter(V.pf); }
        }).catch(function (e) { G3Cargando = false; if (window.console) console.error('SIGMA AI 3D:', e && e.message); });
    }
    function intro() {
        var g = G(); if (!g || RM || V.introHecho) return; V.introHecho = true;
        g.from('.xh > *, .crumb2, .snav', { y: 16, opacity: 0, duration: .9, ease: 'expo.out', stagger: .06 });
        g.from('.plant, .stx .xc', { y: 26, opacity: 0, duration: 1, ease: 'expo.out', stagger: .08, delay: .15 });
        ringIn($('#ccm'));
        var cnt = $('#hv'); if (cnt) { var o = { v: 0 }, fin = Number(cnt.getAttribute('data-v')); g.to(o, { v: fin, duration: 1.6, ease: 'power3.out', onUpdate: function () { cnt.textContent = Math.round(o.v); } }); }
        if ('IntersectionObserver' in window) {
            var io = new IntersectionObserver(function (es) { es.forEach(function (en) { if (!en.isIntersecting) return; io.unobserve(en.target); g.from(en.target, { y: 30, opacity: 0, duration: .9, ease: 'expo.out' }); if (en.target.classList.contains('rul')) g.from(en.target.querySelectorAll('.iv'), { scaleX: 0, transformOrigin: 'left center', duration: 1, ease: 'expo.out', stagger: .05 }); }); }, { threshold: .1 });
            $$('.log, .q, .rul, .vis, .mods').forEach(function (x) { io.observe(x); });
        }
    }
    var spyCur = 'mon';
    function spy() {
        var cur = 'mon';
        ['mon', 'pred', 'rul', 'vis', 'mod'].forEach(function (id) { var el = document.getElementById(id); if (el && el.getBoundingClientRect().top < 220) cur = id; });
        if (innerHeight + scrollY >= document.documentElement.scrollHeight - 4) cur = 'mod';
        if (cur !== spyCur || !$('.snav a.on')) { spyCur = cur; $$('.snav a').forEach(function (a) { a.classList.toggle('on', a.getAttribute('data-sec') === cur); }); }
    }
    addEventListener('scroll', function () { requestAnimationFrame(spy); }, { passive: true });

    /* ------------------------------------------------------------ datos en vivo */
    function integrarEventos(lista, frescos) {
        (lista || []).slice().reverse().forEach(function (e) { e.fresh = !!frescos; V.ev.unshift(e); });
        V.ev.sort(function (a, b) { return new Date(b.F) - new Date(a.F); }); V.ev = V.ev.slice(0, 40);
    }
    function cargar() {
        return ws('Estado', { planta: V.planta }).then(function (d) { D = d; if (V.planta && !(d.plantas || []).some(function (x) { return +x.id === +V.planta; })) V.planta = 0; V.ev = []; integrarEventos(d.eventos, false); V.desde = d.ahora; V.sel = (cola().filter(function (p) { return p.ESTADO !== 'd'; })[0] || {}).ID || null; render(); if (V.sel) select(V.sel, false); });
    }
    function pulso(forzar) {
        if (document.hidden && !forzar) return Promise.resolve();
        return ws('Pulso', { desde: V.desde || '', planta: V.planta }).then(function (d) {
            V.desde = d.ahora;
            var cambioCola = JSON.stringify(cola().map(function (p) { return [p.ID, p.PROB, p.ESTADO, p.OT_ID]; })) !== JSON.stringify((d.cola || []).map(function (p) { return [p.ID, p.PROB, p.ESTADO, p.OT_ID]; }));
            D.activos = d.activos; D.resumen = d.resumen; D.salud = d.salud; D.senales = d.senales; D.histograma = d.histograma; D.cola = d.cola; D.tendencias = d.tendencias;
            if ((d.eventos || []).length) { integrarEventos(d.eventos, true); var l = $('#log'); if (l) l.innerHTML = V.ev.map(evHTML).join(''); }
            var ls = $('#lastScore'); if (ls) ls.textContent = D.resumen.ULTIMA_PUNTUACION ? ago(D.resumen.ULTIMA_PUNTUACION) : 'sin puntuaciones';
            var sn = $('#sigN'); if (sn) sn.textContent = fmt(num((D.senales || {}).SENALES_MIN) || 0, 1);
            if (cambioCola) { if (V.sel && !predOf(V.sel)) V.sel = (abiertas()[0] || {}).ID || null; refreshPred(); var f = $('.snav a[data-sec="pred"]'); if (f) { var c = abiertas().filter(function (p) { return num(p.PROB) >= 70; }).length; f.innerHTML = 'Predicciones' + (c ? '<em>' + c + '</em>' : ''); } }
        }).catch(function () { });
    }
    document.addEventListener('change', function (e) {
        if (!e.target || e.target.id !== 'aiPlanta') return;
        V.planta = +e.target.value || 0;
        try { localStorage.setItem('sigmaAiPlanta', String(V.planta)); } catch (x) { }
        cargar().catch(function (er) { toast(er.message); });
    });
    setInterval(function () { pulso(false); }, 20000);
    setInterval(function () { var ls = $('#lastScore'); if (ls && D && D.resumen && D.resumen.ULTIMA_PUNTUACION) ls.textContent = ago(D.resumen.ULTIMA_PUNTUACION); }, 30000);
    document.addEventListener('visibilitychange', function () { if (G3) G3.setRunning(!document.hidden); if (!document.hidden && D) pulso(true); });

    /* ------------------------------------------------------------ eventos */
    var MOTIVOS = [['YA_INTERVENIDO', 'Ya se intervino'], ['FALSA_ALARMA', 'Falsa alarma'], ['SENSOR_FALLA', 'El sensor tiene una falla'], ['OTRO', 'Otro motivo']];
    function popAt(el, html) { var r = el.getBoundingClientRect(); $('#layer').innerHTML = '<div class="dpop" style="left:' + Math.max(8, Math.min(r.left, innerWidth - 286)) + 'px;top:' + Math.max(8, Math.min(r.bottom + 8, innerHeight - 260)) + 'px">' + html + '</div>'; }
    function cerrarPop() { var l = $('#layer'); if (l) l.innerHTML = ''; }
    function enviarPregunta() { var i = $('#rinQ'); if (!i) return; var q = i.value.trim(); if (!q) return; i.value = ''; preguntar(q); }

    root.addEventListener('click', function (e) {
        var t = e.target.closest ? e.target.closest('button,a,[data-sel]') : null;
        if (!t) { if (!e.target.closest('.dpop')) cerrarPop(); return; }
        var d = t.dataset;
        if (!t.closest('.dpop') && !('dis' in d) && !('vfix' in d)) cerrarPop();
        if ('sec' in d) { e.preventDefault(); var s = document.getElementById(d.sec); if (s) s.scrollIntoView({ behavior: RM ? 'auto' : 'smooth', block: 'start' }); return; }
        if ('goto' in d || 'aiGoto' in d) { var g = document.getElementById(d.goto || d.aiGoto); if (g) g.scrollIntoView({ behavior: RM ? 'auto' : 'smooth', block: 'start' }); return; }
        if ('sel' in d) { select(d.sel, 'jump' in d); return; }
        if ('aiSel' in d) { select(d.aiSel, true); return; }
        if ('qf' in d) { V.qf = d.qf; refreshPred(); return; }
        if ('pf' in d) { V.pf = d.pf; $$('[data-pf]').forEach(function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-pf') === V.pf); }); if (G3) G3.filter(V.pf); return; }
        if ('pv' in d) { if (G3) G3.reset(); return; }
        if ('zoom' in d) { if (G3) G3.zoom(+d.zoom); return; }
        if ('plfs' in d) { var pl = $('#plant'); if (!pl) return; var on = !pl.classList.contains('full'); pl.classList.toggle('full', on); document.body.classList.toggle('plant-full', on); t.innerHTML = ic(on ? 'compress' : 'expand', 15) + (on ? 'Salir de pantalla completa' : 'Pantalla completa'); setTimeout(function () { window.dispatchEvent(new Event('resize')); }, 60); return; }
        if ('score' in d) {
            t.disabled = true; t.classList.add('spin1');
            ws('Puntuar').then(function (r) { toast('SIGMA AI puntuó ' + r.activos + (r.activos === 1 ? ' activo' : ' activos') + ' y ' + r.repuestos + (r.repuestos === 1 ? ' repuesto.' : ' repuestos.') + (r.aviso ? ' ' + r.aviso : '')); return cargar(); })
                .catch(function (er) { toast(er.message); }).then(function () { t.disabled = false; t.classList.remove('spin1'); });
            return;
        }
        if ('ot' in d || 'aiOt' in d) {
            var pid = d.ot || d.aiOt; t.disabled = true;
            ws('CrearOt', { prediccion: +pid }).then(function () { toast('Orden de trabajo preventiva creada.'); return pulso(true); }).catch(function (er) { toast(er.message); t.disabled = false; });
            return;
        }
        if ('dis' in d) { popAt(t, '<p>¿Por qué la descartas? SIGMA AI usa el motivo para aprender.</p>' + MOTIVOS.map(function (m) { return '<button type="button" data-disr="' + m[0] + '" data-pid="' + d.dis + '">' + m[1] + '</button>'; }).join('')); return; }
        if ('disr' in d) {
            if (d.disr === 'OTRO' && !('detalle' in d)) { var pp = d.pid; $('#layer').querySelector('.dpop').innerHTML = '<p>Cuéntale a SIGMA AI qué pasó (opcional).</p><input id="disDet" placeholder="Motivo" style="width:100%;height:36px;border-radius:9px;border:1px solid rgba(148,163,214,.3);background:#0B1020;color:#fff;padding:0 10px"><button type="button" data-disr="OTRO" data-pid="' + pp + '" data-detalle="1" style="margin-top:6px;justify-content:center;background:#6732F4;color:#fff">Descartar</button>'; var inp = $('#disDet'); if (inp) inp.focus(); return; }
            var det = d.disr === 'OTRO' ? (($('#disDet') || {}).value || '') : '';
            ws('Descartar', { id: +d.pid, motivo: d.disr, detalle: det }).then(function () { cerrarPop(); toast('Descartada. El motivo entra al próximo entrenamiento.'); return pulso(true); }).catch(function (er) { toast(er.message); });
            return;
        }
        if ('undo' in d) { ws('Reabrir', { id: +d.undo }).then(function () { toast('Predicción reabierta.'); return pulso(true); }).catch(function (er) { toast(er.message); }); return; }
        if ('pedir' in d || 'aiPedir' in d) {
            var par = String(d.pedir || d.aiPedir).split('|'); t.disabled = true;
            ws('PedirRepuesto', { repuesto: +par[0], prediccion: +par[1] || 0 }).then(function (r) { V.ordered[par[0]] = 1; toast('Solicitud de compra N.º ' + r.numero + ' creada.'); return cargar(); }).catch(function (er) { toast(er.message); t.disabled = false; });
            return;
        }
        if ('vok' in d) {
            var v = d.vok.split('|'); t.disabled = true;
            var foto = (D.fotos || []).filter(function (f) { return String(f.id) === v[2]; })[0];
            ws('ConfirmarFoto', { deteccion: +v[0], etiqueta: v[1], anterior: v[1], activo: foto ? foto.nombre : '' }).then(function () { toast('Etiqueta confirmada. Entra al dataset de SIGMA VISION.'); return cargar(); }).catch(function (er) { toast(er.message); t.disabled = false; });
            return;
        }
        if ('vfix' in d) {
            var w = d.vfix.split('|'); var otras = etiquetasConocidas().filter(function (x) { return x !== w[1]; });
            popAt(t, '<p>¿Qué muestra la foto?</p>' + otras.map(function (x) { return '<button type="button" data-vset="' + esc(x) + '" data-vid="' + d.vfix + '">' + esc(x) + '</button>'; }).join('') + '<input id="vOtra" placeholder="Otra etiqueta" maxlength="60" style="width:calc(100% - 8px);margin:6px 4px 0;height:34px;border-radius:9px;border:1px solid rgba(148,163,214,.3);background:#0B1020;color:#fff;padding:0 10px"><button type="button" data-vset="" data-vid="' + d.vfix + '" style="justify-content:center;margin-top:6px;background:#6732F4;color:#fff">Usar esa etiqueta</button>');
            return;
        }
        if ('vset' in d) {
            var q = d.vid.split('|'), et = d.vset || (($('#vOtra') || {}).value || '').trim(); if (!et) { toast('Escribe o elige una etiqueta.'); return; }
            var f2 = (D.fotos || []).filter(function (f) { return String(f.id) === q[2]; })[0];
            ws('ConfirmarFoto', { deteccion: +q[0], etiqueta: et, anterior: q[1], activo: f2 ? f2.nombre : '' }).then(function () { cerrarPop(); toast('Corregida. Las correcciones enseñan más que las confirmaciones.'); return cargar(); }).catch(function (er) { toast(er.message); });
            return;
        }
        if ('ask' in d) { if (!V.rail) { V.rail = true; guardarRail(); } preguntar(d.ask); return; }
        if ('enviar' in d) { enviarPregunta(); return; }
        if ('railfs' in d) { V.full = !V.full; guardarRail(); return; }
        if ('railx' in d) { V.rail = false; guardarRail(); return; }
        if ('rail' in d) { V.rail = true; guardarRail(); return; }
    });
    root.addEventListener('keydown', function (e) { if (e.key === 'Enter' && e.target.id === 'rinQ') { e.preventDefault(); enviarPregunta(); } });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { cerrarPop(); var pf = $('#plant.full'); if (pf) { var b = $('[data-plfs]'); if (b) b.click(); return; } if (V.full) { V.full = false; guardarRail(); } else if (V.rail) { V.rail = false; guardarRail(); } } });
    /* cruz con tooltip del grafico del detalle */
    document.addEventListener('pointermove', function (e) {
        var pl = $('#plot2'); if (!pl || !pl._geo) return;
        var cr = pl.querySelector('.cross'), tp = pl.querySelector('.tip'); if (!cr || !tp) return;
        if (!e.target.closest || !e.target.closest('#plot2')) { cr.style.display = tp.style.display = 'none'; return; }
        var g = pl._geo, r = pl.getBoundingClientRect(), t = g.t0 + (e.clientX - r.left) / r.width * (g.ahora - g.t0);
        var best = g.pts.reduce(function (m, c) { return Math.abs(c.t - t) < Math.abs(m.t - t) ? c : m; }, g.pts[0]), left = g.X(best.t) / g.W * 100;
        cr.style.display = tp.style.display = 'block'; cr.style.left = left + '%';
        tp.innerHTML = '<b>' + fmt(best.v, g.dec) + g.suf + '</b>' + new Date(best.t).toLocaleString('es-CL', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
        tp.style.left = Math.max(14, Math.min(86, left)) + '%'; tp.style.top = g.pct(best.v) + '%';
    });
    window.addEventListener('beforeunload', function () { if (G3) try { G3.dispose(); } catch (e) { } });

    /* ------------------------------------------------------------ arranque */
    cargar().catch(function (e) {
        $('#ccm').innerHTML = '<section class="xc"><div class="vacio"><b>No se pudo cargar el centro de monitoreo</b>' + esc(e.message) + '</div></section>';
    });

    /* para pruebas visuales: SigmaAICentro.pintar(estado) dibuja con datos de prueba sin tocar el servidor */
    window.SigmaAICentro = { pintar: function (estado) { D = estado; V.ev = []; integrarEventos(estado.eventos, false); V.greeted = false; V.sel = (cola()[0] || {}).ID || null; render(); } };
})();
