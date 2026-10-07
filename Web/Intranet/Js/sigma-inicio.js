/* ============================================================================
   SIGMA · Inicio (Default.aspx) · Propuesta 1 (06-10-2026)
   Referencia: docs/rediseno-inicio/sigma-inicio-referencia.html

   Ninguna cifra se escribe aqui: todo llega de WsInicio (SP «SEL_INICIO_*», BD/377). Cada
   bloque que depende de ordenes de trabajo o de predicciones muestra su estado vacio hasta
   que haya filas. El widget de SIGMA AI consulta cada 30 s (y se detiene con la pestaña oculta).
   ========================================================================= */
(function () {
    'use strict';

    var root = document.getElementById('sgin');
    if (!root) return;
    var WS = root.getAttribute('data-ws'), IMG = root.getAttribute('data-img');

    /* ------------------------------------------------------------ utilidades */
    function $(s, r) { return (r || root).querySelector(s); }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function fmt(n, d) { return Number(n).toLocaleString('es-CL', { minimumFractionDigits: d || 0, maximumFractionDigits: d || 0 }); }
    function num(v) { return v == null || v === '' ? null : Number(v); }
    var P = {
        plus: '<path d="M12 5v14M5 12h14"/>', check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>', x: '<path d="M6 6l12 12M18 6L6 18"/>',
        arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>', chev: '<path d="M9 6l6 6-6 6"/>', pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
        clip: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M9 12l2 2 4-4"/>',
        box: '<path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/>',
        shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M8.5 12l2.5 2.5 4.5-5"/>',
        gauge: '<path d="M4 17a8 8 0 1 1 16 0"/><path d="M12 17l4-5"/>',
        bell: '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
        ai: '<path d="M12 3l1.8 4.7L18.5 9l-4.7 1.3L12 15l-1.8-4.7L5.5 9l4.7-1.3z"/><path d="M18 15l.8 2 2 .8-2 .8L18 20.6l-.8-2-2-.8 2-.8z"/>',
        send: '<path d="M4 12l16-8-6 16-3-7z"/>', cal: '<rect x="3.5" y="5" width="17" height="15" rx="2"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
        clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3 2"/>', bot: '<rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 4v4M9 13h.01M15 13h.01M9.5 16.5h5"/>'
    };
    function ic(k, n) { n = n || 18; return '<svg class="ic" style="width:' + n + 'px;height:' + n + 'px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (P[k] || P.box) + '</svg>'; }

    function post(metodo, datos) {
        return fetch(WS + '/' + metodo, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify(datos || {}) })
            .then(function (r) { if (!r.ok) throw new Error('El servidor respondió ' + r.status + '.'); return r.json(); })
            .then(function (j) { var d = JSON.parse(j.d); if (d.error) { var e = new Error(d.detalle || 'No se pudo completar.'); e.sesion = d.sesion; throw e; } return d; });
    }
    function toast(msg, enlace) {
        var box = document.querySelector('.in-toasts');
        if (!box) { box = document.createElement('div'); box.className = 'in-toasts'; box.setAttribute('aria-live', 'polite'); document.body.appendChild(box); }
        var t = document.createElement('div'); t.className = 'in-toast'; t.setAttribute('role', 'status');
        t.innerHTML = ic('check', 18) + '<span>' + esc(msg) + '</span>' + (enlace ? '<a href="' + esc(enlace.href) + '">' + esc(enlace.texto) + '</a>' : '');
        box.appendChild(t); setTimeout(function () { t.remove(); }, enlace ? 7000 : 3800);
    }
    function icono(k, dark) {
        var src = k === 'twin' ? IMG + 'sigma-twin/sigma-twin-symbol-gradient.svg' : k === 'ai' ? IMG + 'sigma-ai/sigma-ai-symbol-gradient.svg' : IMG + 'accesos/' + k + '.svg';
        return '<img src="' + esc(src) + '" alt="" aria-hidden="true">';
    }

    /* ------------------------------------------------------------ estado */
    var D = null;                  // lo ultimo que devolvio Resumen
    var S = { editing: false, pins: [] };
    var planta = 0; try { planta = +localStorage.getItem('sigmaAiPlanta') || 0; } catch (x) { }
    var AI = { pred: [], razones: {}, curvas: {}, modelo: {}, sel: null, desde: null, feed: [], fresh: {} };
    var guardarT = null, askAbierto = false;

    function modulo(k) { return ((D && D.catalogo) || []).filter(function (m) { return m.k === k; })[0]; }
    function permitidos() { return ((D && D.catalogo) || []).filter(function (m) { return m.ok; }); }

    /* ------------------------------------------------------------ acciones del encabezado */
    function acciones() {
        var host = document.querySelector('.sg-page-head'); if (!host) return;
        var a = host.querySelector('.in-acts');
        if (!a) { a = document.createElement('div'); a.className = 'in-acts'; host.appendChild(a); }
        var u = D && D.urls || {};
        a.innerHTML = u.nuevaOt ? '<a class="btn pri" href="' + esc(u.nuevaOt) + '">' + ic('plus', 16) + 'Nueva orden de trabajo</a>' : '';
    }

    /* ------------------------------------------------------------ accesos directos */
    function tiles() {
        var edit = S.editing, pins = S.pins.filter(function (k) { var m = modulo(k); return m && m.ok; });
        var h = pins.map(function (k) {
            var m = modulo(k);
            return '<a href="' + esc(m.url) + '" class="tile' + (m.dark ? ' dark' : '') + '" data-tile="' + k + '"' + (edit ? ' tabindex="-1"' : '') + '>'
                + '<span class="ti">' + icono(k, m.dark) + '</span><span><b>' + esc(m.n) + '</b><small>' + (m.dot ? '<i style="background:' + m.dot + '"></i>' : '') + esc(m.s) + '</small></span>'
                + '<span class="go">' + ic('arrow', 16) + '</span><button type="button" class="x" data-unpin="' + k + '" aria-label="Quitar ' + esc(m.n) + '">' + ic('x', 13) + '</button></a>';
        }).join('');
        var libres = permitidos().filter(function (m) { return pins.indexOf(m.k) < 0; });
        if (edit && libres.length) h += '<button type="button" class="tile add" data-addpin="1">' + ic('plus', 20) + 'Agregar acceso</button>';
        $('#tiles').classList.toggle('editing', edit);
        $('#tiles').innerHTML = h || '<p style="color:var(--muted);grid-column:1/-1">No tienes accesos directos. Usa «Personalizar» para agregar los que quieras.</p>';
        $('#editBtn').innerHTML = edit ? ic('check', 16) + 'Listo' : ic('pencil', 15) + 'Personalizar';
    }
    function guardarPins() {
        clearTimeout(guardarT);
        guardarT = setTimeout(function () { post('GuardarAccesos', { modulos: S.pins.join(',') }).catch(function (e) { toast(e.message); }); }, 350);
    }
    function pop(anchor) {
        var libres = permitidos().filter(function (m) { return S.pins.indexOf(m.k) < 0; }), r = anchor.getBoundingClientRect();
        var l = $('#layer');
        l.innerHTML = '<div class="in-pop" role="menu" style="left:' + Math.max(8, Math.min(r.left, innerWidth - 296)) + 'px;top:' + Math.max(8, Math.min(r.bottom + 8, innerHeight - 70 - libres.length * 50)) + 'px"><p>Agrega un acceso directo</p>'
            + libres.map(function (m) { return '<button type="button" role="menuitem" data-pin="' + m.k + '"><span class="ti">' + icono(m.k) + '</span>' + esc(m.n) + '</button>'; }).join('') + '</div>';
        var b = l.querySelector('button'); if (b) b.focus();
    }
    function cerrarPop() { $('#layer').innerHTML = ''; }

    /* ------------------------------------------------------------ indicadores y ordenes */
    function spark(vals) {
        vals = vals.filter(function (v) { return v != null; });
        if (vals.length < 2) return '<div class="spark" aria-hidden="true"></div>';
        var lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals);
        function X(i) { return i / (vals.length - 1) * 200; } function Y(v) { return 34 - (v - lo) / ((hi - lo) || 1) * 30; }
        var d = vals.map(function (v, i) { return (i ? 'L' : 'M') + X(i) + ' ' + Y(v); }).join('');
        return '<div class="spark"><svg viewBox="0 0 200 38" preserveAspectRatio="none" aria-hidden="true"><path d="' + d + 'L200 38L0 38Z" fill="rgba(37,99,235,.08)"/><path d="' + d + '" fill="none" stroke="#2563EB" stroke-width="2" vector-effect="non-scaling-stroke" stroke-linejoin="round"/></svg></div>';
    }
    function opsHTML() {
        var I = D.indicadores || {}, sem = D.semanas || [], u = D.urls || {};
        if (!num(I.OT_TOTAL)) {
            var act = num((D.cifras || {}).ACTIVOS) || 0, planes = num((D.cifras || {}).PLANES) || 0;
            return '<section class="card empty"><div><h3>Tus indicadores aparecen con la primera orden de trabajo</h3><p>Disponibilidad, cumplimiento del preventivo, MTTR y órdenes recientes se calculan desde las órdenes de trabajo. Con estos tres pasos el panel se llena solo.</p>'
                + '<div class="steps3"><div>' + (act > 0 ? '<span class="ok">' + ic('check', 14) + 'Listo</span>' : '<span class="nx">Paso 1</span>') + '<b>Activos registrados</b><small>' + (act > 0 ? act + (act === 1 ? ' activo' : ' activos') + ' en ' + esc(D.cliente || 'tu planta') : 'Registra los activos que mantienes') + '</small></div>'
                + '<div>' + (planes > 0 ? '<span class="ok">' + ic('check', 14) + 'Listo</span>' : '<span class="nx">Paso 2</span>') + '<b>Plan preventivo</b><small>' + (planes > 0 ? planes + (planes === 1 ? ' plan definido' : ' planes definidos') : 'Define qué se revisa y cada cuánto') + '</small></div>'
                + '<div><span class="nx">Paso 3</span><b>Primera orden de trabajo</b><small>Correctiva, preventiva o desde una predicción</small></div></div></div>'
                + '<div style="display:flex;flex-direction:column;gap:8px">' + (u.nuevaOt ? '<a class="btn pri" href="' + esc(u.nuevaOt) + '">' + ic('plus', 16) + 'Crear la primera OT</a>' : '')
                + '<a class="btn out" href="' + esc(u.planes || u.plan) + '">Armar el plan preventivo</a></div></section>';
        }
        var disp = num(I.DISPONIBILIDAD), dispA = num(I.DISPONIBILIDAD_ANT), mttr = num(I.MTTR_H), mttrA = num(I.MTTR_H_ANT), cum = num(I.CUMPLIMIENTO);
        function delta(v, a, unidad, decimales, bajarEsBueno) {
            if (v == null || a == null) return '';
            var d = v - a; if (Math.abs(d) < Math.pow(10, -(decimales + 1))) return '<span class="neu">= sin cambio</span>';
            var bien = bajarEsBueno ? d < 0 : d > 0;
            return '<span class="' + (bien ? 'up' : 'dn') + '">' + (d > 0 ? '▲ ' : '▼ ') + fmt(Math.abs(d), decimales) + ' ' + unidad + '</span>';
        }
        var disps = sem.map(function (s) { var pm = num(s.PARADA_MIN), ac = num(s.ACTIVOS); return pm == null || !ac ? null : 100 * (1 - pm / (ac * 10080)); });
        var K = [
            { k: 'OT abiertas', i: 'clip', n: fmt(num(I.OT_ABIERTAS) || 0), s: '', d: '<b>' + (num(I.OT_VENCIDAS) || 0) + (num(I.OT_VENCIDAS) === 1 ? ' vencida' : ' vencidas') + '</b> · ' + (num(I.OT_ALTA) || 0) + ' de alta prioridad', sp: sem.map(function (s) { return num(s.ABIERTAS); }) },
            { k: 'Cumplimiento del preventivo', i: 'cal', n: cum == null ? '—' : fmt(cum, 0) + ' %', s: '', d: cum == null ? 'Sin tareas preventivas en los últimos 30 días' : 'Meta 90 % · semana ' + (num(I.SEMANA_ISO) || ''), meter: cum },
            { k: 'Disponibilidad', i: 'gauge', n: disp == null ? '—' : fmt(disp, 1) + ' %', s: delta(disp, dispA, 'pts', 1, false), d: disp == null ? 'Aún no hay paradas registradas en órdenes cerradas' : 'vs. los 30 días anteriores', sp: disps },
            { k: 'MTTR', i: 'clock', n: mttr == null ? '—' : fmt(mttr, 1) + ' h', s: delta(mttr, mttrA, 'h', 1, true), d: mttr == null ? 'Aún no hay órdenes cerradas con duración' : 'Tiempo medio de reparación', sp: sem.map(function (s) { return num(s.MTTR_H); }) }
        ];
        var kpis = '<div class="kpis">' + K.map(function (x) {
            return '<section class="card kpi"><div class="k"><span>' + x.k + '</span>' + ic(x.i, 17) + '</div><div class="n"><b class="tn' + (x.n === '—' ? ' vacio' : '') + '">' + x.n + '</b>' + x.s + '</div><div class="d">' + x.d + '</div>'
                + (x.meter !== undefined ? '<div class="meter" title="Meta de 90 %"><i style="width:' + (x.meter == null ? 0 : Math.min(100, x.meter)) + '%"></i><em style="left:90%"></em></div>' : spark(x.sp)) + '</section>';
        }).join('') + '</div>';
        return kpis + ordenesHTML();
    }
    function ordenesHTML() {
        var L = D.ordenes || [], u = D.urls || {}, ab = num((D.indicadores || {}).OT_ABIERTAS) || 0;
        var colores = [['#E6F0FE', '#1675F2'], ['#EFEBFE', '#5A30F2'], ['#DFF8F8', '#007F8A'], ['#FFF4E6', '#B65C00'], ['#E7F5EE', '#16855B']];
        function est(o) {
            var f = o.PROGRAMADA ? new Date(o.PROGRAMADA) : null;
            if (num(o.ESTADO) === 4) return ['fin', 'Finalizada'];
            if (o.VENCIDA) { var d = num(o.DIAS_VENCIDA) || 0; return ['venc', d >= 1 ? 'Vencida hace ' + d + (d === 1 ? ' día' : ' días') : 'Vencida']; }
            if (num(o.ESTADO) === 2 || num(o.ESTADO) === 3) return ['curso', 'En curso'];
            return ['prog', f ? 'Programada ' + f.toLocaleString('es-CL', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'Programada'];
        }
        var PR = { CRITICA: ['c', 'Crítica'], ALTA: ['a', 'Alta'], MEDIA: ['m', 'Media'], BAJA: ['m', 'Baja'] };
        return '<section class="card ots"><div class="sec-h"><h2>Órdenes de trabajo recientes<small>' + L.length + ' de ' + ab + ' abiertas</small></h2><a class="btn plain sm" href="' + esc(u.ordenes) + '">Ver todas' + ic('arrow', 15) + '</a></div>'
            + '<div class="ot h"><span>OT</span><span>Trabajo</span><span class="c3">Responsable</span><span class="c5">Prioridad</span><span>Estado</span><span></span></div>'
            + L.map(function (o, i) {
                var e = est(o), p = PR[o.PRIORIDAD] || ['m', ''], c = colores[i % colores.length];
                var ini = String(o.RESPONSABLE || '').split(' ').filter(Boolean).slice(0, 2).map(function (x) { return x.charAt(0).toUpperCase(); }).join('') || '—';
                var sub = [o.ACTIVO, o.TIPO].filter(Boolean).join(' · ');
                return '<a class="ot" href="' + esc(o.URL || u.ordenes) + '" style="text-decoration:none;color:inherit"><code>OT ' + esc(o.CORRELATIVO) + '</code><span class="t"><b>' + esc(o.TITULO) + '</b><small>' + esc(sub) + '</small></span>'
                    + '<span class="who c3"><span class="ini" style="background:' + c[0] + ';color:' + c[1] + '">' + esc(ini) + '</span><span>' + esc(o.RESPONSABLE || 'Sin responsable') + '</span></span>'
                    + '<span class="pri-t ' + p[0] + ' c5">' + p[1] + '</span><span><span class="es ' + e[0] + '"><i></i>' + e[1] + '</span></span><span class="ib" aria-hidden="true">' + ic('chev', 16) + '</span></a>';
            }).join('') + '</section>';
    }

    /* ------------------------------------------------------------ columna derecha */
    function sideHTML() {
        var u = D.urls || {}, H = D.hoy || [];
        var ES = { done: 'Hecha', now: 'En curso', next: 'Pendiente' };
        var hoy = '<section class="card today"><div class="sec-h"><h2>Hoy<small>' + (H.length ? H.length + (H.length === 1 ? ' tarea' : ' tareas') : 'sin tareas') + '</small></h2><a class="btn plain sm" href="' + esc(u.plan) + '">Agenda' + ic('arrow', 15) + '</a></div>'
            + (H.length ? '<div class="tl">' + H.map(function (t) {
                var f = t.HORA ? new Date(t.HORA) : null;
                return '<div class="tl-i ' + t.ESTADO + '"><time class="tn">' + (f ? f.toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit', hour12: false }) : '') + '</time><span class="dot"><i></i></span><div><b>' + esc(t.TITULO) + '</b><small>' + esc(t.DETALLE) + '</small><span class="st ' + t.ESTADO + '">' + ES[t.ESTADO] + '</span></div></div>';
            }).join('') + '</div>'
              : '<div style="text-align:center;padding:14px 6px 8px;color:var(--muted);font-size:12.5px"><b style="display:block;color:var(--ink);font-size:13.5px;margin-bottom:4px">No hay tareas programadas para hoy</b>Cuando planifiques la semana, aquí verás qué toca cada día.<div style="margin-top:12px"><a class="btn ghost sm" href="' + esc(u.plan) + '">Planificar la semana</a></div></div>')
            + '</section>';
        var A = D.atencion || [];
        var TONO = { c: ['#FDECEA', '#C7352B'], a: ['#FFF4E6', '#B65C00'], '': ['#F3F5F8', '#64748B'] };
        var att = '<section class="card att"><div class="sec-h"><h2>Requieren tu atención<small>' + A.length + '</small></h2></div><div class="al">'
            + (A.length ? A.map(function (a, i) {
                var t = TONO[a.sev] || TONO[''];
                var cuerpo = '<span class="ai2" style="background:' + t[0] + ';color:' + t[1] + '">' + ic(a.icono, 17) + '</span><span style="min-width:0"><b>' + esc(a.titulo) + '</b><small>' + esc(a.detalle) + '</small></span>' + (a.sev ? '<span class="tag ' + a.sev + '">' + (a.sev === 'c' ? 'Crítica' : 'Alta') + '</span>' : '<span></span>');
                return a.grupo ? '<a href="' + esc(a.url) + '">' + cuerpo + '</a>' : '<button type="button" data-aten="' + i + '">' + cuerpo + '</button>';
            }).join('') : '<p style="color:var(--muted);font-size:12.5px;padding:8px">Estás al día: no hay nada que requiera tu atención.</p>')
            + '</div><div style="padding:8px 8px 0"><a class="btn plain sm" href="' + esc(u.notificaciones) + '" style="padding:0;color:var(--sigma-blue)">Ver todas las notificaciones' + ic('arrow', 15) + '</a></div></section>';
        return hoy + att;
    }

    /* ------------------------------------------------------------ SIGMA AI */
    var SEV = function (p) { return p >= 70 ? ['#FF5C8A', 'Crítica'] : p >= 50 ? ['#FFB547', 'Alta'] : ['#00E0C2', 'Media']; };
    var gid = 0;
    function ago(iso) {
        var s = Math.round((Date.now() - new Date(iso).getTime()) / 1000);
        return s < 50 ? 'ahora' : s < 3600 ? 'hace ' + Math.max(1, Math.round(s / 60)) + ' min' : s < 86400 ? 'hace ' + Math.round(s / 3600) + ' h' : 'hace ' + Math.round(s / 86400) + ' d';
    }
    function ordenarPred() { AI.pred.sort(function (a, b) { return num(b.PROB) - num(a.PROB); }); }
    function plantaSel() {
        var L = (D && D.plantas) || [];
        if (!L.length) return '';
        if (L.length === 1) return '<span class="plsel"><span>Planta</span><span class="plchip">' + esc(L[0].nombre) + '</span></span>';
        return '<label class="plsel"><span>Planta</span><select id="aiPlanta" aria-label="Filtrar SIGMA AI por planta"><option value="0">Todas las plantas</option>'
            + L.map(function (x) { return '<option value="' + x.id + '"' + (+planta === +x.id ? ' selected' : '') + '>' + esc(x.nombre) + '</option>'; }).join('') + '</select></label>';
    }
    function aiHead() {
        var c = D.cifras || {};
        var senales = num(c.SENALES_MIN) || 0, conectados = num(c.ACTIVOS_CON_LECTURA) || 0, activos = num(c.AI_ACTIVOS) || 0;
        return '<div class="ai-h"><span class="ai-logo"><img src="' + esc(IMG + 'sigma-ai/sigma-ai-symbol-gradient.svg') + '" alt=""></span>'
            + '<div class="ai-t"><img src="' + esc(IMG + 'sigma-ai/sigma-ai-wordmark-dark.svg') + '" alt="SIGMA AI"><small>Mantenimiento predictivo · ' + esc(D.cliente || '') + '</small></div>'
            + '<div class="live">' + plantaSel() + '<span class="sig">Analizando <b>' + conectados + '</b> de ' + activos + ' activos · <b class="tn">' + fmt(senales, 1) + '</b> señales/min</span><span class="pill-live"><i></i>EN VIVO</span></div></div>';
    }
    /* El chat se ve igual que en el mockup. La conversacion todavia no existe: cada pregunta recibe el aviso «Próximamente». */
    function aiAsk() {
        return '<div class="ask"><div id="ans"></div><div class="ask-in" id="askF"><span style="color:#7C8CFF;display:flex">' + ic('bot', 18) + '</span>'
            + '<input id="askQ" placeholder="Pregúntale a SIGMA AI: ¿qué activos reviso esta semana?" aria-label="Pregunta para SIGMA AI"><span class="soon">Próximamente</span><button type="button" class="send" data-enviar="1" aria-label="Enviar">' + ic('send', 17) + '</button></div>'
            + '<div class="sugs">' + ['¿Qué reviso primero hoy?', 'Resumen del día', 'Repuestos en riesgo'].map(function (s) { return '<button type="button" data-sug="' + esc(s) + '">' + s + '</button>'; }).join('') + '</div></div>';
    }
    var typing = null;
    function responder(q) {
        var box = $('#ans'); if (!box) return;
        var txt = 'La conversación con SIGMA AI estará disponible muy pronto. Cuando llegue podrás preguntarle esto mismo y recibir una respuesta con los datos y las fuentes de tu planta. Mientras tanto, revisa «Requieren tu atención» y las predicciones de arriba.';
        box.innerHTML = '<div class="ans"><span style="flex:none"><img src="' + esc(IMG + 'sigma-ai/sigma-ai-symbol-gradient.svg') + '" alt="" width="22" height="22"></span><div><span class="q">' + esc(q) + '</span><span class="ansT"></span><span class="caret"></span></div></div>';
        clearInterval(typing); var k = 0, t = box.querySelector('.ansT');
        typing = setInterval(function () { k += 3; t.textContent = txt.slice(0, k); if (k >= txt.length) { clearInterval(typing); var c = box.querySelector('.caret'); if (c) c.remove(); } }, 18);
    }
    function aiAprendiendo() {
        var c = D.cifras || {}, dias = Math.min(Math.max(num(c.DIAS_LECTURAS) || 0, 0), 30), r = 46, C = 2 * Math.PI * r;
        var faltan = Math.max(30 - dias, 0);
        return aiHead() + '<div class="learn"><div class="gauge"><svg width="118" height="118" viewBox="0 0 118 118" aria-hidden="true"><circle cx="59" cy="59" r="' + r + '" stroke="rgba(255,255,255,.08)" stroke-width="9" fill="none"/><circle cx="59" cy="59" r="' + r + '" stroke="#00E0C2" stroke-width="9" fill="none" stroke-linecap="round" stroke-dasharray="' + C + '" stroke-dashoffset="' + (C * (1 - dias / 30)) + '" transform="rotate(-90 59 59)" style="filter:drop-shadow(0 0 6px rgba(0,224,194,.6))"/></svg><div class="v"><b class="tn">' + dias + '</b><small>de 30 días<br>de lecturas</small></div></div>'
            + '<div><div class="lab">Aprendiendo</div><h3 style="margin-top:6px">SIGMA AI está aprendiendo cómo funciona tu planta</h3><p>Para predecir fallas con confianza necesita 30 días de lecturas y al menos una orden de trabajo cerrada por activo. Mientras tanto vigila las señales en vivo y te avisa si algo sale de rango.</p>'
            + '<div class="steps"><span><b>' + (num(c.ACTIVOS_CON_LECTURA) || 0) + '</b> activos con lecturas</span><span><b class="tn">' + fmt(num(c.SENALES_MIN) || 0, 1) + '</b> señales por minuto</span><span>' + (faltan > 0 ? 'Primeras predicciones en <b>~' + faltan + (faltan === 1 ? ' día' : ' días') + '</b>' : 'Las primeras predicciones llegan en cuanto el modelo las calcule') + '</span></div></div></div>' + aiAsk();
    }
    function gauge(p) {
        var id = 'sgg' + (++gid), r = 50, C = 2 * Math.PI * r;
        return '<div class="gauge"><svg width="118" height="118" viewBox="0 0 118 118" aria-hidden="true"><defs><linearGradient id="' + id + '" x1="0" y1="0" x2="118" y2="118" gradientUnits="userSpaceOnUse"><stop stop-color="#00E0C2"/><stop offset=".48" stop-color="#2563EB"/><stop offset=".74" stop-color="#6C5CFF"/><stop offset="1" stop-color="#FF4D9D"/></linearGradient></defs>'
            + '<circle cx="59" cy="59" r="' + r + '" stroke="rgba(255,255,255,.08)" stroke-width="10" fill="none"/><circle class="arc" cx="59" cy="59" r="' + r + '" stroke="url(#' + id + ')" stroke-width="10" fill="none" stroke-linecap="round" stroke-dasharray="' + C + '" stroke-dashoffset="' + C + '" data-to="' + (C * (1 - Math.min(100, num(p.PROB)) / 100)) + '" transform="rotate(-90 59 59)" style="transition:stroke-dashoffset 1.1s cubic-bezier(.2,.8,.2,1);filter:drop-shadow(0 0 6px rgba(108,92,255,.6))"/></svg>'
            + '<div class="v"><b class="tn">' + fmt(num(p.PROB), 0) + ' %</b><small>probabilidad<br>de falla</small></div></div>';
    }
    function plazo(p) {
        var d = num(p.DIAS), lo = num(p.DIAS_MIN), hi = num(p.DIAS_MAX);
        var txt = d == null ? 'Sin plazo estimado' : (lo != null && hi != null && lo <= d && d <= hi && hi > lo ? fmt(lo, 0) + '–' + fmt(hi, 0) + ' días' : '~' + fmt(d, 0) + (d === 1 ? ' día' : ' días'));
        var f = p.FECHA_EVENTO ? new Date(p.FECHA_EVENTO) : null;
        return { txt: txt, fecha: f ? 'antes del ' + f.toLocaleDateString('es-CL', { day: 'numeric', month: 'long' }) : '' };
    }
    function featHTML() {
        var p = AI.sel, pz = plazo(p), titulo = p.COMPONENTE || p.ACTIVO, ctx = [p.COMPONENTE ? p.ACTIVO : '', p.AREA, p.CODIGO].filter(Boolean).join(' · ');
        var ra = AI.razones[p.ID] || [];
        return '<div class="feat"><div class="lab">Predicción principal' + (num(p.CONFIANZA) != null ? ' <span class="conf">Confianza ' + fmt(num(p.CONFIANZA), 0) + ' %</span>' : '') + '</div>'
            + '<div><h3>' + esc(titulo) + '</h3><p class="ctx">' + esc(ctx) + '</p></div>'
            + '<div class="hero">' + gauge(p) + '<div class="when"><small>Falla probable en</small><b class="tn">' + esc(pz.txt) + '</b><span>' + esc(pz.fecha) + '</span></div>'
            + (ra.length ? '<div class="why">' + ra.slice(0, 3).map(function (w) { return '<div><span>' + esc(w) + '</span></div>'; }).join('') + '</div>' : '') + '</div>'
            + '<div class="chart"><div class="chart-h"><span><b class="tn" id="vNow">' + fmt(num(p.PROB), 0) + '</b>% · Probabilidad de falla del activo</span><span class="lg"><span><i></i>Corridas del modelo</span><span><i class="t"></i>Crítica 70 %</span></div>'
            + '<div class="plot" id="plot" role="img" aria-label="Probabilidad de falla de ' + esc(p.ACTIVO) + ' en los últimos 30 días; hoy ' + fmt(num(p.PROB), 0) + ' por ciento."></div></div>'
            + '<div class="ai-acts">' + otBoton(p) + '<button type="button" class="btn dk sm" data-analisis="1">Ver análisis' + ic('arrow', 15) + '</button><button type="button" class="btn dkp sm" data-descartar="' + p.ID + '">Descartar</button></div></div>';
    }
    function otBoton(p) {
        if (p.OT_ID) return '<span class="btn sm okd" style="cursor:default;background:rgba(22,133,91,.18);color:#7EE2C0">' + ic('check', 15) + 'OT creada</span>';
        if (!p.ALERTA_ID) return '<button type="button" class="btn pri sm" disabled title="Esta predicción aún no tiene alerta asociada">' + ic('plus', 15) + 'Crear OT preventiva</button>';
        return '<button type="button" class="btn pri sm" data-crearot="' + p.ID + '">' + ic('plus', 15) + 'Crear OT preventiva</button>';
    }
    function plot() {
        var el = $('#plot'); if (!el) return;
        var p = AI.sel, cv = (AI.curvas[p.ACTIVO_ID] || []).map(function (x) { return { t: new Date(x.f).getTime(), v: num(x.p) }; });
        if (cv.length < 2) { el.innerHTML = '<div class="nodata">Hay una sola corrida del modelo para este activo: la curva aparece con la siguiente.</div>'; return; }
        var ahora = Date.now(), t0 = ahora - 30 * 86400000, W = 1000, H = 300;
        function X(t) { return Math.max(0, Math.min(1, (t - t0) / (ahora - t0))) * W; } function Y(v) { return H - Math.min(100, Math.max(0, v)) / 100 * H; }
        var line = cv.map(function (c, i) { return (i ? 'L' : 'M') + X(c.t).toFixed(1) + ' ' + Y(c.v).toFixed(1); }).join('');
        var last = cv[cv.length - 1], area = line + 'L' + X(last.t).toFixed(1) + ' ' + H + 'L' + X(cv[0].t).toFixed(1) + ' ' + H + 'Z';
        var ticks = [25, 50, 75];
        el.innerHTML = '<svg viewBox="0 0 1000 300" preserveAspectRatio="none" aria-hidden="true"><defs><linearGradient id="arF" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#7C8CFF" stop-opacity=".35"/><stop offset="1" stop-color="#7C8CFF" stop-opacity="0"/></linearGradient></defs>'
            + ticks.map(function (t) { return '<line x1="0" x2="1000" y1="' + Y(t) + '" y2="' + Y(t) + '" stroke="rgba(148,163,214,.12)" stroke-width="1" vector-effect="non-scaling-stroke"/>'; }).join('')
            + '<line x1="0" x2="1000" y1="' + Y(70) + '" y2="' + Y(70) + '" stroke="#FFB547" stroke-width="1.5" stroke-dasharray="6 5" vector-effect="non-scaling-stroke"/>'
            + '<path d="' + area + '" fill="url(#arF)"/><path d="' + line + '" fill="none" stroke="#7C8CFF" stroke-width="2" stroke-linejoin="round" vector-effect="non-scaling-stroke"/></svg>'
            + ticks.concat([100]).map(function (t) { return '<span class="ylab tn" style="top:' + (100 - t) + '%">' + t + '</span>'; }).join('')
            + '<span class="thr" style="top:' + (100 - 70) + '%">Crítica 70 %</span>'
            + [[0, 'hace 30 d'], [.5, 'hace 15 d'], [1, 'hoy']].map(function (x) { return '<span class="xlab' + (x[0] === .5 ? ' xs-h' : '') + '" style="left:' + x[0] * 100 + '%' + (x[0] === 1 ? ';transform:translateX(-100%)' : x[0] === 0 ? ';transform:none' : '') + '">' + x[1] + '</span>'; }).join('')
            + '<span class="nowdot" style="left:' + (X(last.t) / W * 100) + '%;top:' + (100 - Math.min(100, last.v)) + '%"></span><span class="cross"></span><span class="tip"></span>';
        el._geo = { cv: cv, X: X, W: W, t0: t0, ahora: ahora };
    }
    function streamHTML() {
        var feed = AI.pred.filter(function (p) { return p !== AI.sel; }).sort(function (a, b) { return new Date(b.CALCULADA) - new Date(a.CALCULADA); }).slice(0, 5);
        return feed.map(function (p) {
            var s = SEV(num(p.PROB)), titulo = (p.ACTIVO + (p.COMPONENTE ? ' · ' + p.COMPONENTE : ''));
            var pz = plazo(p);
            return '<button type="button" class="pi' + (AI.fresh[p.ID] ? ' new' : '') + '" data-pred="' + p.ID + '" aria-label="' + esc(titulo) + ', ' + fmt(num(p.PROB), 0) + ' %, ' + s[1] + '">'
                + '<span class="pic"><i style="background:' + s[0] + ';box-shadow:0 0 10px ' + s[0] + '"></i></span><span style="min-width:0"><b>' + esc(titulo) + '</b><small>' + esc(pz.txt) + ' <em>· ' + ago(p.CALCULADA) + '</em></small></span>'
                + '<span class="pr"><b class="tn">' + fmt(num(p.PROB), 0) + ' %</b><span><i style="width:' + Math.min(100, num(p.PROB)) + '%;background:' + s[0] + '"></i></span></span></button>';
        }).join('');
    }
    function aiConPred() {
        var m = AI.modelo || {}, ant = num(m.ANTICIPADAS) || 0, ev = num(m.EVALUADAS) || 0, ac = num(m.ACIERTOS) || 0;
        return aiHead() + '<div class="ai-b">' + featHTML() + '<div class="stream"><div class="stream-h"><div class="lab">Flujo de predicciones</div><span><b class="tn" style="color:#fff">' + AI.pred.length + '</b> activas</span></div>'
            + '<div class="pl" id="pl">' + streamHTML() + '</div>'
            + '<div class="stats"><div><b class="tn">' + ant + '</b><small>fallas anticipadas este mes</small></div><div><b class="tn">—</b><small>horas de detención evitadas</small></div><div><b class="tn">' + (ev > 0 ? fmt(100 * ac / ev, 0) + ' %' : '—') + '</b><small>de aciertos del modelo</small></div></div></div></div>' + aiAsk();
    }
    function renderAI() {
        var el = $('#ai');
        if (!AI.pred.length) { el.innerHTML = aiAprendiendo(); return; }
        if (!AI.sel || AI.pred.indexOf(AI.sel) < 0) AI.sel = AI.pred[0];
        el.innerHTML = aiConPred();
        plot();
        requestAnimationFrame(function () { requestAnimationFrame(function () { var a = $('#ai .arc'); if (a) a.style.strokeDashoffset = a.getAttribute('data-to'); }); });
    }
    function integrar(d, nuevas) {
        var viejos = {}; AI.pred.forEach(function (p) { viejos[p.ID] = p; });
        (d.pred || []).forEach(function (p) {
            var antes = viejos[p.ID];
            if (nuevas && !antes) AI.fresh[p.ID] = true;
            if (antes) { var i = AI.pred.indexOf(antes); AI.pred[i] = p; if (AI.sel === antes) AI.sel = p; } else AI.pred.push(p);
        });
        Object.keys(d.razones || {}).forEach(function (k) { AI.razones[k] = d.razones[k]; });
        Object.keys(d.curvas || {}).forEach(function (k) { AI.curvas[k] = d.curvas[k]; });
        if (d.modelo) AI.modelo = d.modelo;
        if (d.ahora) AI.desde = d.ahora;
        ordenarPred();
    }

    /* ------------------------------------------------------------ render general */
    function render() {
        acciones(); tiles(); renderAI();
        $('#ops').innerHTML = opsHTML(); $('#sideCol').innerHTML = sideHTML();
    }
    function cargar(primera) {
        return Promise.all([post('Resumen', { planta: planta }), post('Predicciones', { desde: primera ? '' : AI.desde || '', planta: planta })]).then(function (r) {
            D = r[0];
            if (planta && !(D.plantas || []).some(function (x) { return +x.id === +planta; })) { planta = 0; return cargar(primera); }
            if (primera) { S.pins = (D.pins || []).slice(); integrar(r[1], false); render(); }
            else {
                /* sondeo: se redibujan las cifras, las predicciones nuevas entran arriba con destello */
                var antes = AI.pred.length; integrar(r[1], true);
                acciones(); if (!S.editing) tiles(); $('#ops').innerHTML = opsHTML(); $('#sideCol').innerHTML = sideHTML();
                if (antes !== AI.pred.length || r[1].pred.length) renderAI(); else { var h = $('#ai .ai-h'); if (h) h.outerHTML = aiHead(); }
            }
        });
    }

    /* ------------------------------------------------------------ eventos */
    /* No es un <form>: la pagina ya vive dentro del formulario de ASP.NET y los anidados se ignoran. */
    function enviar() { var i = $('#askQ'); if (!i) return; var q = (i.value || '').trim() || 'Tu pregunta'; i.value = ''; responder(q); }
    root.addEventListener('keydown', function (e) { if (e.key === 'Enter' && e.target.id === 'askQ') { e.preventDefault(); enviar(); } });
    root.addEventListener('click', function (e) {
        var t = e.target.closest ? e.target : null; if (!t) return;
        var c;
        if (t.closest('[data-enviar]')) { enviar(); return; }
        if ((c = t.closest('[data-sug]'))) { responder(c.getAttribute('data-sug')); return; }
        if ((c = t.closest('[data-unpin]'))) { e.preventDefault(); e.stopPropagation(); S.pins = S.pins.filter(function (k) { return k !== c.getAttribute('data-unpin'); }); guardarPins(); tiles(); return; }
        if (t.closest('.tile') && S.editing && !t.closest('[data-addpin]')) { e.preventDefault(); return; }
        if ((c = t.closest('[data-addpin]'))) { e.preventDefault(); pop(c); return; }
        if ((c = t.closest('[data-pin]'))) { S.pins.push(c.getAttribute('data-pin')); guardarPins(); cerrarPop(); tiles(); return; }
        if ((c = t.closest('#editBtn'))) { S.editing = !S.editing; cerrarPop(); tiles(); return; }
        if ((c = t.closest('[data-pred]'))) { var id = c.getAttribute('data-pred'); AI.pred.forEach(function (p) { if (String(p.ID) === id) { AI.sel = p; delete AI.fresh[p.ID]; } }); renderAI(); return; }
        if ((c = t.closest('[data-descartar]'))) {
            var pid = +c.getAttribute('data-descartar'); c.disabled = true;
            post('Descartar', { id: pid }).then(function () {
                AI.pred = AI.pred.filter(function (p) { return p.ID !== pid; }); AI.sel = null; ordenarPred();
                toast('Descartada. SIGMA AI lo tendrá en cuenta.'); renderAI();
            }).catch(function (er) { toast(er.message); c.disabled = false; });
            return;
        }
        if ((c = t.closest('[data-crearot]'))) {
            var p0 = AI.pred.filter(function (p) { return String(p.ID) === c.getAttribute('data-crearot'); })[0]; if (!p0) return;
            c.disabled = true;
            fetch(WS.replace('WsInicio.asmx', 'WsAlertas.asmx') + '/GenerarOrden', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify({ alerta: p0.ALERTA_ID }) })
                .then(function (r) { return r.json(); }).then(function (j) {
                    var d = JSON.parse(j.d);
                    if (d.error) throw new Error(d.detalle || 'No se pudo crear la orden.');
                    p0.OT_ID = d.codigo || -1; renderAI(); toast('Orden de trabajo creada', (D.urls || {}).ordenes ? { href: D.urls.ordenes, texto: 'Ver órdenes' } : null);
                    cargar(false).catch(function () { });
                }).catch(function (er) { toast(er.message); c.disabled = false; });
            return;
        }
        if ((c = t.closest('[data-analisis]'))) {
            var s = AI.sel; if (s && s.Q && window.abrirNotificacion) window.abrirNotificacion(s.URL, s.Q, s.ALERTA_ID);
            else toast('Esta predicción aún no tiene una ficha de alerta.');
            return;
        }
        if ((c = t.closest('[data-aten]'))) { var a = (D.atencion || [])[+c.getAttribute('data-aten')]; if (a && window.abrirNotificacion) window.abrirNotificacion(a.url, a.q, a.id); return; }
    });
    document.addEventListener('change', function (e) {
        if (!e.target || e.target.id !== 'aiPlanta') return;
        planta = +e.target.value || 0;
        try { localStorage.setItem('sigmaAiPlanta', String(planta)); } catch (x) { }
        AI = { pred: [], razones: {}, curvas: {}, modelo: {}, sel: null, desde: null, feed: [], fresh: {} };
        cargar(true).catch(function (er) { toast(er.message); });
    });
    document.addEventListener('click', function (e) { if (!e.target.closest('.in-pop') && !e.target.closest('[data-addpin]')) cerrarPop(); });
    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape') return;
        if ($('#layer').innerHTML) { cerrarPop(); return; }
        if (S.editing) { S.editing = false; tiles(); }
    });
    /* cruz con tooltip del grafico */
    root.addEventListener('mousemove', function (e) {
        var plotEl = e.target.closest ? e.target.closest('#plot') : null; if (!plotEl || !plotEl._geo) return;
        var g = plotEl._geo, r = plotEl.getBoundingClientRect(), x = (e.clientX - r.left) / r.width, t = g.t0 + x * (g.ahora - g.t0);
        var best = g.cv.reduce(function (m, c) { return Math.abs(c.t - t) < Math.abs(m.t - t) ? c : m; }, g.cv[0]);
        var cross = plotEl.querySelector('.cross'), tip = plotEl.querySelector('.tip'); if (!cross || !tip) return;
        var px = g.X(best.t) / g.W * 100;
        cross.style.display = 'block'; cross.style.left = px + '%';
        tip.style.display = 'block'; tip.style.left = px + '%'; tip.style.top = (100 - best.v) + '%';
        tip.innerHTML = '<b>' + fmt(best.v, 0) + ' %</b>' + new Date(best.t).toLocaleString('es-CL', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
    });
    root.addEventListener('mouseleave', function () { var c = $('.cross'), t = $('.tip'); if (c) c.style.display = 'none'; if (t) t.style.display = 'none'; }, true);

    /* ------------------------------------------------------------ tiempo real: cada 30 s, y no con la pestaña oculta */
    setInterval(function () { if (!document.hidden && D) cargar(false).catch(function () { }); }, 30000);
    document.addEventListener('visibilitychange', function () { if (!document.hidden && D) cargar(false).catch(function () { }); });

    cargar(true).catch(function (e) {
        $('#ops').innerHTML = '<section class="card" style="padding:22px"><b>No se pudo cargar el inicio.</b><p style="color:var(--muted);margin-top:4px">' + esc(e.message) + '</p></section>';
        $('#ai').innerHTML = '';
    });

    /* para pruebas visuales y soporte: SigmaInicio.pintar(datos) dibuja con datos de prueba sin tocar el servidor */
    window.SigmaInicio = {
        pintar: function (resumen, predicciones) { D = resumen; S.pins = (D.pins || []).slice(); AI = { pred: [], razones: {}, curvas: {}, modelo: {}, sel: null, desde: null, feed: [], fresh: {} }; integrar(predicciones || {}, false); render(); }
    };
})();
