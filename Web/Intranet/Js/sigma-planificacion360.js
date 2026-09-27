/*
 * Planificación 360 — las siete pestañas del Centro de Mantenimiento.
 *
 * Todo corre en el navegador: cambiar de pestaña NO hace postback. Cada
 * pestaña pide sus datos a WsPlanificacion360.asmx la primera vez que se
 * abre y los guarda; planta y período marcan como vencidas las que dependen
 * de ellos. La pestaña, planta y período viven en la URL (#tab=...), así que
 * volver desde un editor deja la vista como estaba.
 *
 * Los registros (OT, plan, activo) se abren en otra pestaña del navegador;
 * el wizard de Programación, Reprogramar y la carga masiva, en modal.
 */
(function () {
    'use strict';

    var MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    var DIAS = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    var TIPOS = [['', 'Todos'], ['FECHA UNICA', 'Fecha única'], ['CALENDARIO', 'Calendario'], ['INTERVALO TIEMPO', 'Intervalo'], ['MEDIDOR', 'Medidor'], ['CONDICION', 'Condición'], ['ABIERTA', 'Abierta']];
    var cfg, raiz, datos = {}, vencidas = {}, VISTAS = {};
    var st = {
        tab: 'resumen',
        bandeja: { situacion: '', plan: 0, filtro: '', parada: false, pagina: 1, sel: {}, abiertas: {}, resultado: '' },
        cal: { vista: 'mes', plan: 0, equipo: 0, parada: false, dia: '', equipos: [] },
        planes: { filtro: '', estado: '', abiertas: {} },
        prog: { filtro: '', tipo: '', abiertas: {} },
        cob: { vista: 'sin', tipo: 0, area: 0, crit: 0, pagina: 1, foco: -1 }
    };

    // ------------------------------------------------------------ utilidades
    function e(v) { return v == null ? '' : String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
    function $id(id) { return document.getElementById(id); }
    function planta() { return parseInt($id('p360Planta').value, 10) || 0; }
    function periodo() { return $id('p360Periodo').value; }
    function iso(d) { return d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDate()).slice(-2); }
    function fecha(s) { return new Date(s + 'T12:00:00'); }
    function sumar(d, n) { var x = new Date(d.getTime()); x.setDate(x.getDate() + n); return x; }
    function lunes(d) { return sumar(d, -((d.getDay() + 6) % 7)); }
    function hoy() { return fecha(cfg.hoy); }
    function mesDe(p) { var a = p.split('-'); return new Date(+a[0], +a[1] - 1, 1, 12); }
    function rangoPeriodo() { var m = mesDe(periodo()); return { desde: iso(m), hasta: iso(new Date(m.getFullYear(), m.getMonth() + 1, 0, 12)) }; }
    function rangoGrilla() { var ini = lunes(mesDe(periodo())); return { desde: iso(ini), hasta: iso(sumar(ini, 41)) }; }
    function nombreMes(p) { var m = mesDe(p), t = MESES[m.getMonth()]; return t.charAt(0).toUpperCase() + t.slice(1) + ' ' + m.getFullYear(); }
    function plural(n, uno, varios) { return n + ' ' + (n === 1 ? uno : varios); }

    function sit(x) {
        var s = ((x.situacion || '') + ' ' + (x.estado || '')).toLowerCase();
        if (s.indexOf('venc') >= 0) return 'vencida';
        if (s.indexOf('atras') >= 0) return 'atrasada';
        if (s.indexOf('complet') >= 0 || s.indexOf('cerr') >= 0) return 'completada';
        if (s.indexOf('omit') >= 0) return 'omitida';
        if (s.indexOf('dispon') >= 0) return 'disponible';
        return 'futura';
    }
    var SIT = {
        vencida: ['Vencida', 'mdi-alert-circle-outline', 'es-rojo'],
        atrasada: ['Atrasada', 'mdi-clock-outline', 'es-ambar'],
        disponible: ['Disponible', 'mdi-play-circle-outline', 'es-verde'],
        futura: ['Programada', 'mdi-calendar-clock-outline', 'es-azul'],
        completada: ['Completada', 'mdi-check-circle-outline', 'es-verde'],
        omitida: ['Omitida', 'mdi-cancel', 'es-gris']
    };
    function chipSit(x, conIcono) { var k = sit(x), d = SIT[k]; return '<span class="p3-chip s-' + k + (conIcono ? ' sin-punto' : '') + '">' + (conIcono ? '<i class="mdi ' + d[1] + '"></i>' : '') + d[0] + '</span>'; }
    function chipParada() { return '<span class="p3-chip s-parada sin-punto"><i class="mdi mdi-power-plug-off-outline"></i>Parada</span>'; }
    function vacio(icono, texto) { return '<div class="p3-vacio"><i class="mdi ' + icono + '"></i>' + e(texto) + '</div>'; }
    function nuevaPestana(url, texto, clase) { return '<a href="' + e(url) + '" target="_blank" rel="noopener"' + (clase ? ' class="' + clase + '"' : '') + '>' + texto + '</a>'; }
    function opciones(lista, sel, todos) {
        var h = todos ? '<option value="0">' + e(todos) + '</option>' : '';
        for (var i = 0; i < lista.length; i++) h += '<option value="' + e(lista[i].id) + '"' + (String(lista[i].id) === String(sel) ? ' selected' : '') + '>' + e(lista[i].texto) + '</option>';
        return h;
    }
    function panel(sec) { return raiz.querySelector('[data-panel="' + sec + '"]'); }
    function sw(id, marcado, texto) { return '<label class="p3-switch"><input type="checkbox" id="' + id + '"' + (marcado ? ' checked' : '') + '><span></span>' + texto + '</label>'; }
    function pct(v) { return v == null ? '—' : v + '%'; }
    function nivel(v) { return v == null ? '' : v >= 85 ? 'alto' : v >= 70 ? 'medio' : 'bajo'; }
    function colorNivel(v) { return v >= 85 ? '#1f9d63' : v >= 70 ? '#f0b429' : '#e5484d'; }

    // --------------------------------------------------------------- servidor
    function pedir(metodo, cuerpo) {
        return $.ajax({ type: 'POST', url: cfg.url + metodo, data: JSON.stringify(cuerpo), contentType: 'application/json; charset=utf-8', dataType: 'json' })
            .then(function (r) { return typeof r.d === 'string' ? JSON.parse(r.d) : r.d; });
    }
    function parametros(sec) {
        var r = sec === 'calendario' ? rangoGrilla() : rangoPeriodo(), b = st.bandeja, c = st.cal, p = st.planes, g = st.prog, o = st.cob;
        return {
            seccion: sec, planta: planta(), desde: r.desde, hasta: r.hasta,
            pagina: sec === 'bandeja' ? b.pagina : sec === 'cobertura' ? o.pagina : 1,
            filtro: sec === 'bandeja' ? b.filtro : sec === 'planes' ? p.filtro : sec === 'programaciones' ? g.filtro : '',
            soloParada: sec === 'bandeja' ? b.parada : sec === 'calendario' ? c.parada : false,
            situacion: sec === 'bandeja' ? b.situacion : '',
            plan: sec === 'bandeja' ? b.plan : sec === 'calendario' ? c.plan : 0,
            equipo: sec === 'calendario' ? c.equipo : 0,
            tipo: o.tipo, area: o.area, criticidad: o.crit,
            vista: sec === 'planes' ? p.estado : sec === 'programaciones' ? g.tipo : sec === 'cobertura' ? o.vista : ''
        };
    }
    var turno = {};
    function cargar(sec) {
        var caja = panel(sec), mio = (turno[sec] = (turno[sec] || 0) + 1);
        if (!datos[sec]) caja.innerHTML = '<div class="p3-estado" role="status"><i class="mdi mdi-loading mdi-spin"></i>Cargando…</div>';
        else caja.setAttribute('aria-busy', 'true');
        pedir('Cargar', parametros(sec)).then(function (x) {
            if (mio !== turno[sec]) return; // llegó una respuesta más nueva
            caja.removeAttribute('aria-busy');
            if (x.error) { error(caja, x.detalle, !x.sinPermiso); return; }
            datos[sec] = x.datos; vencidas[sec] = false; pintar(sec);
        }, function () { if (mio !== turno[sec]) return; caja.removeAttribute('aria-busy'); error(caja, 'No fue posible conectar con el servidor.', true); });
    }
    function error(caja, texto, reintentar) {
        caja.innerHTML = '<div class="p3-estado es-error" role="alert"><i class="mdi ' + (reintentar ? 'mdi-alert-circle-outline' : 'mdi-lock-outline') + '"></i>' + e(texto) +
            (reintentar ? ' <button type="button" class="p3-btn" data-acc="reintentar">Reintentar</button>' : '') + '</div>';
    }
    function kpis() {
        pedir('Cargar', { seccion: 'kpis', planta: planta(), desde: cfg.hoy, hasta: cfg.hoy, pagina: 1, filtro: '', soloParada: false, situacion: '', plan: 0, equipo: 0, tipo: 0, area: 0, criticidad: 0, vista: '' })
            .then(function (x) {
                if (x.error) return;
                var k = x.datos, m = {
                    urgente: k.urgente, urgentePie: plural(k.vencidas, 'vencida', 'vencidas') + ' · ' + plural(k.atrasadas, 'atrasada', 'atrasadas'),
                    disponibles: k.disponibles, cumplimiento: pct(k.cumplimiento), cumplimientoPie: k.cumplimientoPie,
                    carga: k.carga + ' h', cargaPie: k.cargaPie
                };
                for (var n in m) { var el = raiz.querySelector('[data-kpi="' + n + '"]'); if (el) el.textContent = m[n]; }
            });
    }
    function pintar(sec) {
        // El buscador que tenía el foco lo conserva al repintar.
        var act = document.activeElement, foco = act && act.id && panel(sec).contains(act) && act.tagName === 'INPUT' && act.type !== 'checkbox' ? act.id : null;
        var pos = foco ? act.selectionStart : 0;
        panel(sec).innerHTML = VISTAS[sec](datos[sec]);
        var bs = panel(sec).querySelectorAll('button:not([type])');
        for (var i = 0; i < bs.length; i++) bs[i].setAttribute('type', 'button');
        if (foco) { var c = $id(foco); if (c) { c.focus(); try { c.setSelectionRange(pos, pos); } catch (x) { } } }
    }

    // -------------------------------------------------------------- pestañas
    function ir(sec, foco) {
        st.tab = sec;
        var tabs = raiz.querySelectorAll('.p3-tabs [role=tab]');
        for (var i = 0; i < tabs.length; i++) {
            var si = tabs[i].getAttribute('data-sec') === sec;
            tabs[i].setAttribute('aria-selected', si ? 'true' : 'false');
            tabs[i].tabIndex = si ? 0 : -1;
            if (si && foco) tabs[i].focus();
        }
        var ps = raiz.querySelectorAll('[data-panel]');
        for (var j = 0; j < ps.length; j++) ps[j].hidden = ps[j].getAttribute('data-panel') !== sec;
        guardarUrl();
        if (!datos[sec] || vencidas[sec]) cargar(sec);
    }
    function vencerTodo() { for (var k in VISTAS) vencidas[k] = true; }
    function guardarUrl() {
        var h = '#tab=' + st.tab + '&planta=' + planta() + '&periodo=' + periodo();
        try { history.replaceState(null, '', location.pathname + location.search + h); } catch (x) { location.hash = h; }
    }
    function leerUrl() {
        var m = {}, partes = (location.hash || '').replace(/^#/, '').split('&');
        for (var i = 0; i < partes.length; i++) { var kv = partes[i].split('='); if (kv[0]) m[kv[0]] = decodeURIComponent(kv[1] || ''); }
        if (m.planta && $id('p360Planta').querySelector('option[value="' + m.planta + '"]')) $id('p360Planta').value = m.planta;
        if (m.periodo && $id('p360Periodo').querySelector('option[value="' + m.periodo + '"]')) $id('p360Periodo').value = m.periodo;
        if (m.tab && raiz.querySelector('.p3-tabs [role=tab][data-sec="' + m.tab + '"]')) st.tab = m.tab;
    }
    function tituloPlanta() { var s = $id('p360Planta'); $id('p3TituloPlanta').textContent = planta() ? s.options[s.selectedIndex].text : ''; }
    function cambiarPeriodo(p) {
        var s = $id('p360Periodo');
        if (!s.querySelector('option[value="' + p + '"]')) { var o = document.createElement('option'); o.value = p; o.textContent = nombreMes(p); s.appendChild(o); }
        s.value = p; textoPeriodo(); vencerTodo(); guardarUrl(); cargar(st.tab);
    }

    // ------------------------------------------------------------- Resumen
    function tarjeta(clase, icono, titulo, bajada, cuerpo, extra) {
        return '<article class="p3-tarjeta"><header class="p3-tarjeta-cab"><span class="p3-ico ' + clase + '"><i class="mdi ' + icono + '"></i></span><div><h3>' + e(titulo) + '</h3><p>' + e(bajada) + '</p></div>' + (extra || '') + '</header>' + cuerpo + '</article>';
    }
    function accionesOcurrencia(x, puede) {
        if (x.ordenUrl) return nuevaPestana(x.ordenUrl, 'Abrir OT', 'p3-btn');
        var h = '';
        if (puede) h += '<button class="p3-btn es-primario" data-acc="generar" data-token="' + e(x.token) + '">Generar OT</button> ';
        if (x.reprogramable) h += '<button class="p3-btn es-secundario" data-acc="modal" data-tipo="reprogramar" data-url="' + e(x.reprogramarUrl) + '">Reprogramar</button>';
        return h || '<span class="p3-sub">—</span>';
    }
    VISTAS.resumen = function (d) {
        var u = d.urgencias || [], h, i, x;
        if (!u.length) h = vacio('mdi-check-circle-outline', 'Nada vencido ni atrasado: todo está al día.');
        else {
            h = '<div class="p3-tabla-scroll"><table class="p3-tabla es-simple"><thead><tr><th>Estado</th><th>Equipo / Ubicación</th><th>Hito / Actividad</th><th>Fecha límite</th><th>Días</th><th>OT / Acción</th></tr></thead><tbody>';
            for (i = 0; i < u.length; i++) {
                x = u[i];
                h += '<tr><td>' + chipSit(x) + '</td><td><span class="p3-dos">' + e(x.equipo) + '</span><small>' + e(x.activoCodigo) + ' · ' + e(x.planta) + '</small></td>' +
                    '<td><span class="p3-dos" style="font-weight:500">' + e(x.hito) + '</span><small>' + e(x.planCodigo) + '</small></td>' +
                    '<td>' + (x.limiteSuperado ? '<span class="p3-dos p3-rojo-txt">' + e(x.limite) + '</span><small class="p3-rojo-txt" style="font-weight:400">Límite superado</small>' : '<span class="p3-dos" style="font-weight:500">' + e(x.limite || x.fechaTexto) + '</span>') + '</td>' +
                    '<td><span class="p3-dias ' + (sit(x) === 'vencida' ? 'es-rojo' : 'es-ambar') + '">+' + x.atraso + '</span></td>' +
                    '<td style="white-space:nowrap">' + (x.ordenUrl ? nuevaPestana(x.ordenUrl, 'OT-' + e(x.orden)) + ' &nbsp; ' : '') + accionesOcurrencia(x, d.puedeGenerar) + '</td></tr>';
            }
            h += '</tbody></table></div>';
        }
        var izq = tarjeta('es-rojo', 'mdi-alert-circle-outline', 'Requieren atención', 'Mantenimientos vencidos o atrasados que requieren acción.', h,
            '<button class="p3-mas" data-acc="ir" data-sec="bandeja">Ver bandeja <i class="mdi mdi-arrow-right"></i></button>');

        var b = d.borradores || [];
        if (!b.length) h = vacio('mdi-file-check-outline', 'No hay planes con cambios sin publicar.');
        else {
            h = '<div class="p3-tabla-scroll"><table class="p3-tabla es-simple"><thead><tr><th>Plan</th><th>Familia / Área</th><th>Cambios</th><th>Última edición</th><th>Responsable</th><th>Estado</th><th>Acción</th></tr></thead><tbody>';
            for (i = 0; i < b.length; i++) {
                x = b[i];
                h += '<tr><td><span class="p3-dos">' + e(x.codigo) + '</span><small>' + e(x.nombre) + '</small></td><td>' + e(x.familia || '—') + '</td><td>' + x.cambios + '</td>' +
                    '<td><span class="p3-dos" style="font-weight:500">' + e(x.fecha) + '</span><small>' + e(x.hace) + '</small></td><td>' + e(x.responsable || '—') + '</td>' +
                    '<td><span class="p3-chip s-borrador">Borrador v' + x.version + '</span></td><td>' + nuevaPestana(x.url, 'Abrir plan', 'p3-btn') + '</td></tr>';
            }
            h += '</tbody></table></div>';
        }
        izq += tarjeta('es-lila', 'mdi-file-document-edit-outline', 'Planes con cambios sin publicar', 'Planes de mantenimiento con modificaciones en borrador.', h);

        var p = d.paradas || [];
        if (!p.length) h = vacio('mdi-calendar-check-outline', 'Ninguna parada programada en los próximos 30 días.');
        else {
            h = '<div class="p3-tabla-scroll"><table class="p3-tabla es-simple"><thead><tr><th>Equipo / Ubicación</th><th>Fecha</th><th>Duración</th></tr></thead><tbody>';
            for (i = 0; i < p.length; i++) {
                x = p[i];
                h += '<tr><td>' + nuevaPestana(x.registroUrl, '<span class="p3-dos">' + e(x.equipo) + '</span>') + '<small class="p3-sub">' + e(x.activoCodigo) + ' · ' + e(x.planta) + '</small></td><td style="white-space:nowrap">' + e(x.fechaTexto) + (x.hora ? '<small class="p3-sub">' + e(x.hora) + '</small>' : '') + '</td><td>' + e(x.duracionTexto || '—') + '</td></tr>';
            }
            h += '</tbody></table></div>';
        }
        var der = tarjeta('es-lila', 'mdi-calendar-alert', 'Próximas paradas (30 días)', 'Mantenimientos programados que implican parada del equipo.', h);

        var a = d.actividad || [];
        if (!a.length) h = vacio('mdi-history', 'No se generaron órdenes desde la planificación en la última semana.');
        else {
            h = '<div class="p3-tabla-scroll"><table class="p3-tabla es-simple"><thead><tr><th>OT</th><th>Equipo</th><th>Actividad / Hito</th><th>Fecha</th><th>Estado</th></tr></thead><tbody>';
            for (i = 0; i < a.length; i++) {
                x = a[i];
                var c = (x.estadoCodigo || '').indexOf('CERRADA') >= 0 ? 's-cerrada' : (x.estadoCodigo || '').indexOf('ABIERTA') >= 0 ? 's-abierta' : 's-ejecucion';
                h += '<tr><td>' + nuevaPestana(x.url, 'OT-' + e(x.orden)) + '</td><td>' + e(x.equipo) + '</td><td>' + e(x.hito) + '</td><td style="white-space:nowrap">' + e(x.fecha) + '</td><td><span class="p3-chip ' + c + '">' + e(x.estado) + '</span></td></tr>';
            }
            h += '</tbody></table></div>';
        }
        der += tarjeta('es-lila', 'mdi-pulse', 'Actividad reciente', 'Órdenes generadas desde la planificación.', h);
        return '<div class="p3-resumen"><div>' + izq + '</div><div>' + der + '</div></div>';
    };

    // ------------------------------------------------------------- Bandeja
    function requerimientos(x) {
        var l1 = (x.parada ? 'Parada' : 'Sin parada') + (x.duracionTexto ? ' · ' + x.duracionTexto : ''), l2 = [];
        if (x.repuesto) l2.push(x.repuestos > 1 ? x.repuesto + ' +' + (x.repuestos - 1) : x.repuesto);
        else if (x.repuestos) l2.push(plural(x.repuestos, 'repuesto', 'repuestos'));
        if (x.personas) l2.push(plural(x.personas, 'técnico', 'técnicos'));
        if (x.permiso) l2.push('Permiso de trabajo');
        if (x.overhaul) l2.push('Overhaul');
        if (!l2.length && x.actividades) l2.push(plural(x.actividades, 'actividad', 'actividades'));
        return '<span class="p3-dos" style="font-weight:400">' + e(l1) + '</span>' + (l2.length ? '<small>' + e(l2.join(' · ')) + '</small>' : '');
    }
    function pie(total, pagina, paginas, tam, sec, nota) {
        var ini = total ? (pagina - 1) * tam + 1 : 0, fin = Math.min(total, pagina * tam);
        return '<div class="p3-pie"><span>' + (nota || '') + '</span><span class="p3-pag">Mostrando ' + ini + '–' + fin + ' de ' + total +
            (paginas > 1 ? ' <button data-acc="pagina" data-sec="' + sec + '" data-valor="' + (pagina - 1) + '"' + (pagina <= 1 ? ' disabled' : '') + ' aria-label="Página anterior"><i class="mdi mdi-chevron-left"></i></button>' +
                '<button data-acc="pagina" data-sec="' + sec + '" data-valor="' + (pagina + 1) + '"' + (pagina >= paginas ? ' disabled' : '') + ' aria-label="Página siguiente"><i class="mdi mdi-chevron-right"></i></button>' : '') + '</span></div>';
    }
    VISTAS.bandeja = function (d) {
        var b = st.bandeja, r = d.resumen, i, x, h = '';
        var conts = [['', 'Todas', r.todas, 'c-todas'], ['VENCIDA', 'Vencidas', r.vencidas, 'c-vencida'], ['ATRASADA', 'Atrasadas', r.atrasadas, 'c-atrasada'], ['DISPONIBLE', 'Disponibles', r.disponibles, 'c-disponible'], ['FUTURA', 'Futuras', r.futuras, 'c-futura']];
        h += '<div class="p3-barra"><div class="p3-contadores" role="group" aria-label="Filtrar por situación">';
        for (i = 0; i < conts.length; i++) h += '<button class="p3-cont ' + conts[i][3] + '" data-acc="situacion" data-valor="' + conts[i][0] + '" aria-pressed="' + (b.situacion === conts[i][0]) + '">' + conts[i][1] + ' <b>' + conts[i][2] + '</b></button>';
        h += '</div><span class="p3-sep"></span>' +
            '<label class="p3-campo-apilado">Plan<select class="p3-sel-mini" id="p3bPlan" style="min-width:170px;max-width:220px">' + opciones(d.planes || [], b.plan, 'Todos los planes') + '</select></label>' +
            '<label class="p3-campo-apilado">Equipo<span class="p3-busca"><i class="mdi mdi-magnify"></i><input id="p3bFiltro" value="' + e(b.filtro) + '" placeholder="Buscar equipo…" style="width:190px"></span></label>' +
            '<span class="p3-der">' + sw('p3bParada', b.parada, 'Solo con parada') + '</span></div>';
        h += '<div class="p3-nota"><i class="mdi mdi-information-outline"></i><span>Vencida: pasó el límite · Atrasada: pasó la fecha, aún dentro del límite · Disponible: ya se puede adelantar · Futura: todavía fuera de su ventana.</span></div>';

        var f = d.filas || [], elegibles = f.filter(function (q) { return !q.ordenUrl && d.puedeGenerar; }), nSel = 0;
        for (var k in b.sel) if (b.sel[k]) nSel++;
        h += '<div class="p3-masivo"><input type="checkbox" class="p3-check" data-acc="todos" aria-label="Seleccionar todas las elegibles"' + (elegibles.length && nSel === elegibles.length ? ' checked' : '') + (elegibles.length ? '' : ' disabled') + '>' +
            '<span>' + plural(nSel, 'seleccionada', 'seleccionadas') + '</span>' +
            (d.puedeGenerar ? '<button class="p3-btn es-primario" data-acc="generarSel"' + (nSel ? '' : ' disabled') + '><i class="mdi mdi-flash-outline"></i>Generar OT (' + nSel + ')</button>' : '') +
            nuevaPestana(d.exportarUrl, '<i class="mdi mdi-download-outline"></i>Exportar', 'p3-btn') + '</div>';
        if (b.resultado) h += b.resultado;

        if (!f.length) return h + vacio('mdi-inbox-outline', b.situacion || b.filtro || b.plan || b.parada ? 'No hay ocurrencias con estos filtros.' : 'No hay ocurrencias abiertas hasta el fin del período.');
        h += '<div class="p3-tabla-marco p3-tabla-scroll"><table class="p3-tabla p3-bandeja"><thead><tr><th class="p3-sel"></th><th>Situación</th><th>Fecha</th><th>Activo / Equipo</th><th>Hito</th><th>Requerimientos</th><th>Orden de trabajo</th><th>Acciones</th><th></th></tr></thead><tbody>';
        for (i = 0; i < f.length; i++) {
            x = f[i];
            var ab = !!b.abiertas[x.token], s = sit(x), eleg = !x.ordenUrl && d.puedeGenerar;
            h += '<tr class="' + (ab ? 'es-abierta' : '') + '"><td class="p3-sel"><input type="checkbox" class="p3-check" data-acc="sel" data-token="' + e(x.token) + '"' + (b.sel[x.token] ? ' checked' : '') + (eleg ? '' : ' disabled') + ' aria-label="Seleccionar ' + e(x.equipo) + '"></td>' +
                '<td>' + chipSit(x, true) + '</td>' +
                '<td style="white-space:nowrap"><span class="p3-dos' + (s === 'vencida' ? ' p3-rojo-txt' : '') + '">' + e(x.fechaTexto) + '</span><small' + (s === 'vencida' ? ' class="p3-rojo-txt" style="font-weight:400"' : '') + '>' + e(x.relativo) + '</small></td>' +
                '<td><span class="p3-dos">' + e(x.equipo) + '</span><small>' + e(x.activoCodigo) + ' · ' + e(x.planta) + '</small></td>' +
                '<td>' + e(x.hito) + '</td><td>' + requerimientos(x) + '</td>' +
                '<td>' + (x.ordenUrl ? nuevaPestana(x.ordenUrl, 'OT-' + e(x.orden) + ' <i class="mdi mdi-open-in-new"></i>', 'p3-ot') : '<span class="p3-sub">—</span>') + '</td>' +
                '<td>' + (x.ordenUrl ? nuevaPestana(x.ordenUrl, 'Abrir OT', 'p3-btn') : x.reprogramable ? '<button class="p3-btn es-secundario" data-acc="modal" data-tipo="reprogramar" data-url="' + e(x.reprogramarUrl) + '">Reprogramar</button>' : '<span class="p3-sub">—</span>') + '</td>' +
                '<td><button class="p3-chev" data-acc="expandir" data-token="' + e(x.token) + '" aria-expanded="' + ab + '" aria-label="Ver fechas y plan"><i class="mdi mdi-chevron-' + (ab ? 'up' : 'down') + '"></i></button></td></tr>';
            if (ab) h += '<tr class="p3-fila-det"><td colspan="9"><div class="p3-det">' +
                '<div><i class="mdi mdi-calendar-outline"></i><span><small>Fecha original</small><strong>' + e(x.original) + '</strong></span></div>' +
                '<div><i class="mdi mdi-calendar-edit"></i><span><small>Fecha vigente</small><strong>' + e(x.vigente) + '</strong></span></div>' +
                '<div><i class="mdi mdi-alert-outline"' + (x.limiteSuperado ? ' style="color:#e5484d"' : '') + '></i><span><small>Fecha límite</small><strong' + (x.limiteSuperado ? ' class="p3-rojo-txt"' : '') + '>' + e(x.limite || '—') + '</strong></span></div>' +
                '<div><i class="mdi mdi-file-document-outline"></i><span><small>Plan asociado</small>' + nuevaPestana(x.planUrl, e(x.planCodigo) + ' · ' + e(x.planNombre) + ' <i class="mdi mdi-open-in-new" style="font-size:14px"></i>') + '</span></div>' +
                '</div></td></tr>';
        }
        return h + '</tbody></table></div>' + pie(d.total, d.pagina, d.paginas, 25, 'bandeja');
    };
    function generarSeleccion() {
        var b = st.bandeja, tokens = [];
        for (var k in b.sel) if (b.sel[k]) tokens.push(k);
        if (!tokens.length || !confirm('¿Generar ' + plural(tokens.length, 'orden de trabajo', 'órdenes de trabajo') + '?')) return;
        var filas = {}; (datos.bandeja.filas || []).forEach(function (f) { filas[f.token] = f; });
        var boton = raiz.querySelector('[data-acc="generarSel"]'); if (boton) { boton.disabled = true; boton.textContent = 'Generando…'; }
        var salida = [], i = 0;
        (function siguiente() {
            if (i >= tokens.length) {
                b.sel = {};
                b.resultado = '<div class="p3-resultado" role="status"><strong>Resultado</strong><ul>' + salida.join('') + '</ul></div>';
                vencerTodo(); kpis(); cargar('bandeja');
                return;
            }
            var t = tokens[i++], f = filas[t] || {};
            pedir('GenerarOrden', { token: t }).then(function (x) {
                salida.push('<li class="' + (x.error ? 'mal' : 'ok') + '">' + e(f.equipo || '') + ' · ' + e(f.hito || '') + ': ' + e(x.detalle) + '</li>'); siguiente();
            }, function () { salida.push('<li class="mal">' + e(f.equipo || '') + ': no fue posible conectar.</li>'); siguiente(); });
        })();
    }

    // ---------------------------------------------------------- Calendario
    function evento(x) {
        var s = sit(x), d = SIT[s];
        var tip = x.equipo + ' · ' + x.hito + '\n' + x.planCodigo + ' · ' + d[0] + (x.parada ? ' · requiere parada' : '') + '\nClic: abrir ' + (x.ordenUrl ? x.registroTexto : 'en el Centro del plan') + ' (pestaña nueva)';
        return '<a class="p3-ev s-' + s + '" href="' + e(x.registroUrl) + '" target="_blank" rel="noopener" title="' + e(tip) + '"><i class="mdi ' + d[1] + '"></i><span><b>' + (x.hora ? e(x.hora) + ' · ' : '') + e(x.activoCodigo) + '</b><small>' + e(x.hito) + '</small></span>' +
            (x.parada ? '<i class="mdi mdi-power-plug-off-outline p3-ev-parada" aria-label="Requiere parada"></i>' : '') + '</a>';
    }
    function porDia(filas) { var m = {}; for (var i = 0; i < filas.length; i++) (m[filas[i].fecha] = m[filas[i].fecha] || []).push(filas[i]); return m; }
    function diaElegido(m) {
        var c = st.cal, mes = mesDe(periodo()), h = hoy();
        if (c.dia && fecha(c.dia).getMonth() === mes.getMonth() && fecha(c.dia).getFullYear() === mes.getFullYear()) return c.dia;
        if (h.getMonth() === mes.getMonth() && h.getFullYear() === mes.getFullYear()) return iso(h);
        var dias = Object.keys(m).sort();
        for (var i = 0; i < dias.length; i++) if (fecha(dias[i]).getMonth() === mes.getMonth()) return dias[i];
        return iso(mes);
    }
    function grillaMes(filas, sel) {
        var m = porDia(filas), mes = mesDe(periodo()), ini = lunes(mes), h = iso(hoy());
        var s = '<div class="p3-mes" role="grid" aria-label="' + e(nombreMes(periodo())) + '"><div class="p3-mes-cab" role="row">';
        for (var i = 0; i < 7; i++) s += '<div role="columnheader">' + DIAS[i] + '</div>';
        s += '</div>';
        for (var w = 0; w < 6; w++) {
            if (w > 3 && sumar(ini, w * 7).getMonth() !== mes.getMonth()) break;
            s += '<div class="p3-mes-fila" role="row">';
            for (var d = 0; d < 7; d++) {
                var f = sumar(ini, w * 7 + d), k = iso(f), ev = m[k] || [];
                s += '<div class="p3-dia' + (f.getMonth() !== mes.getMonth() ? ' es-otro' : '') + (k === h ? ' es-hoy' : '') + (k === sel ? ' es-sel' : '') + '" role="gridcell" tabindex="0" data-acc="dia" data-dia="' + k + '" aria-label="' + f.getDate() + ' de ' + MESES[f.getMonth()] + ', ' + plural(ev.length, 'mantención', 'mantenciones') + '"><span class="p3-num">' + f.getDate() + '</span>';
                for (var j = 0; j < Math.min(ev.length, 2); j++) s += evento(ev[j]);
                if (ev.length > 2) s += '<button class="p3-mas-ev" data-acc="dia" data-dia="' + k + '">+' + (ev.length - 2) + ' más</button>';
                s += '</div>';
            }
            s += '</div>';
        }
        return s + '</div>';
    }
    function cargaSemanal(filas) {
        var mes = mesDe(periodo()), ini = lunes(mes), sem = [], max = 1;
        for (var w = 0; w < 6; w++) {
            var a = sumar(ini, w * 7), b = sumar(a, 6);
            if (w > 3 && a.getMonth() !== mes.getMonth()) break;
            var ka = iso(a), kb = iso(b), min = 0, n = 0, par = 0;
            for (var i = 0; i < filas.length; i++) if (filas[i].fecha >= ka && filas[i].fecha <= kb) { min += filas[i].duracion || 0; n++; if (filas[i].parada) par++; }
            sem.push({ a: a, b: b, min: min, n: n, par: par }); if (min > max) max = min;
        }
        var s = '<div class="p3-semanas">';
        for (var j = 0; j < sem.length; j++) {
            var x = sem[j], hrs = Math.round(x.min / 6) / 10;
            s += '<div class="p3-semana"><span><strong>' + x.a.getDate() + ' ' + MESES[x.a.getMonth()].slice(0, 3) + ' – ' + x.b.getDate() + ' ' + MESES[x.b.getMonth()].slice(0, 3) + '</strong><small>' + plural(x.n, 'mantención', 'mantenciones') + (x.par ? ' · ' + x.par + ' con parada' : '') + '</small></span>' +
                '<span class="barra"><i style="width:' + (x.min ? Math.max(3, Math.round(100 * x.min / max)) : 0) + '%"></i></span><b>' + String(hrs).replace('.', ',') + ' h</b></div>';
        }
        return s + '</div>';
    }
    function agenda(filas, sel) {
        var ev = porDia(filas)[sel] || [], f = fecha(sel);
        var s = '<aside class="p3-agenda" aria-live="polite"><div class="p3-agenda-cab"><h3>' + f.getDate() + ' de ' + MESES[f.getMonth()] + '</h3><span>' + plural(ev.length, 'ocurrencia generada', 'ocurrencias generadas') + '</span></div>';
        if (!ev.length) return s + vacio('mdi-calendar-blank-outline', 'Sin mantenciones este día.') + '</aside>';
        for (var i = 0; i < ev.length; i++) {
            var x = ev[i], k = sit(x), d = SIT[k];
            s += '<div class="p3-agenda-it s-' + k + '"><span class="p3-ico ' + d[2] + '"><i class="mdi ' + d[1] + '"></i></span><div class="cuerpo">' +
                '<span class="hora">' + (x.hora ? e(x.hora) + (x.horaFin ? ' – ' + e(x.horaFin) : '') : 'Todo el día') + (x.duracionTexto ? '<em>' + e(x.duracionTexto) + '</em>' : '') + '</span>' +
                '<strong>' + e(x.activoCodigo) + ' · ' + e(x.equipo) + '</strong><span class="p3-sub">' + e(x.hito) + ' · ' + e(x.planCodigo) + '</span>' +
                '<div class="pie"><span>' + chipSit(x, true) + (x.parada ? chipParada() : '') + (x.orden ? '<span class="p3-ot">OT-' + e(x.orden) + '</span>' : '') + '</span>' +
                nuevaPestana(x.registroUrl, (x.ordenUrl ? 'Abrir OT' : 'Abrir ocurrencia') + ' <i class="mdi mdi-open-in-new"></i>', 'p3-btn') + '</div></div></div>';
        }
        return s + '</aside>';
    }
    VISTAS.calendario = function (d) {
        var c = st.cal, filas = d.filas || [];
        if (!c.equipo) c.equipos = d.equipos || [];
        var sel = diaElegido(porDia(filas)); c.dia = sel;
        var h = '<div class="p3-cal-barra"><span class="p3-cal-nav"><button data-acc="mes" data-valor="-1" aria-label="Mes anterior"><i class="mdi mdi-chevron-left"></i></button><button data-acc="mes" data-valor="1" aria-label="Mes siguiente"><i class="mdi mdi-chevron-right"></i></button></span>' +
            '<h2>' + e(nombreMes(periodo())) + '</h2><button class="p3-btn es-ghost" data-acc="mes" data-valor="0">Hoy</button>' +
            '<span class="p3-der"><span class="p3-seg" role="group" aria-label="Vista"><button data-acc="vista" data-valor="mes" aria-pressed="' + (c.vista === 'mes') + '">Mes</button><button data-acc="vista" data-valor="semana" aria-pressed="' + (c.vista === 'semana') + '">Carga semanal</button></span>' +
            '<select class="p3-sel-mini" id="p3cPlan" aria-label="Plan" style="max-width:220px">' + opciones(d.planes || [], c.plan, 'Todos los planes') + '</select>' +
            '<select class="p3-sel-mini" id="p3cEquipo" aria-label="Equipo" style="max-width:220px">' + opciones(c.equipos, c.equipo, 'Todos los equipos') + '</select>' +
            sw('p3cParada', c.parada, 'Solo con parada') + '</span></div>';
        if (d.truncado) h += '<div class="p3-nota"><i class="mdi mdi-information-outline"></i>Se muestran las primeras ' + filas.length + ' de ' + d.total + ' ocurrencias. Filtra por plan o equipo para ver el resto.</div>';
        return h + '<div class="p3-cal"><div>' + (c.vista === 'semana' ? cargaSemanal(filas) : grillaMes(filas, sel)) +
            '<div class="p3-leyenda"><span><i class="pt s-vencida"></i>Vencida</span><span><i class="pt s-atrasada"></i>Atrasada</span><span><i class="pt s-disponible"></i>Disponible</span><span><i class="pt s-futura"></i>Futura</span><span><i class="pt s-completada"></i>Completada</span>' +
            '<span><i class="mdi mdi-power-plug-off-outline" style="color:#8a5a00"></i>Requiere parada</span><span class="p3-der"><i class="mdi mdi-open-in-new"></i> Clic en una mantención: abre su registro en otra pestaña</span></div></div>' +
            agenda(filas, sel) + '</div>';
    };

    // --------------------------------------------------------------- Planes
    VISTAS.planes = function (d) {
        var p = st.planes, l = d.planes || [], h, i, x;
        h = '<div class="p3-barra" style="margin-bottom:14px"><span class="p3-busca" style="flex:0 1 360px"><i class="mdi mdi-magnify"></i><input id="p3pFiltro" value="' + e(p.filtro) + '" placeholder="Buscar plan…"></span>' +
            '<label class="p3-etq-campo">Estado <select class="p3-sel-mini" id="p3pEstado" style="min-width:190px"><option value="">Todos</option><option value="PUBLICADO"' + (p.estado === 'PUBLICADO' ? ' selected' : '') + '>Con versión publicada</option><option value="BORRADOR"' + (p.estado === 'BORRADOR' ? ' selected' : '') + '>Con borrador abierto</option></select></label>' +
            '<span class="p3-der" style="display:flex;gap:10px">' + (d.puedeCrear ? nuevaPestana(d.nuevoUrl, '<i class="mdi mdi-plus"></i>Nuevo plan', 'p3-btn es-primario es-grande') + '<button class="p3-btn es-secundario es-grande" data-acc="modal" data-tipo="carga" data-url="' + e(d.cargaUrl) + '"><i class="mdi mdi-upload-outline"></i>Carga masiva</button>' : '') + '</span></div>';
        if (!l.length) return h + vacio('mdi-clipboard-text-outline', p.filtro || p.estado ? 'Ningún plan coincide con la búsqueda.' : 'Todavía no hay planes de mantenimiento.');
        h += '<div class="p3-tabla-marco p3-tabla-scroll"><table class="p3-tabla p3-planes"><thead><tr><th style="width:40px"></th><th>Código / Nombre del plan</th><th>Versión</th><th>Estado</th><th class="num">Hitos</th><th class="num">Equipos</th><th>Cumplimiento</th><th>Próxima ocurrencia</th><th>Acciones</th></tr></thead><tbody>';
        for (i = 0; i < l.length; i++) {
            x = l[i];
            var ab = !!p.abiertas[x.codigo], est = '';
            if (x.publicada) est += '<span class="p3-chip s-publicado sin-punto">Publicada</span> ';
            if (x.borrador) est += x.publicada ? '<span class="p3-chip s-borrador-v sin-punto">v' + x.borrador.numero + ' Borrador</span>' : '<span class="p3-chip s-borrador sin-punto">Borrador</span> <small class="p3-sub" style="display:inline">Sin versión publicada</small>';
            h += '<tr' + (ab ? ' class="es-abierta"' : '') + '><td><button class="p3-chev" data-acc="expPlan" data-valor="' + e(x.codigo) + '" aria-expanded="' + ab + '" aria-label="Ver versiones"><i class="mdi mdi-chevron-' + (ab ? 'down' : 'right') + '"></i></button></td>' +
                '<td><div style="display:flex;gap:12px;align-items:center"><span class="p3-plan-ico"><i class="mdi mdi-clipboard-text-outline"></i></span><span><span class="p3-dos">' + e(x.codigo) + '</span><small>' + e(x.nombre) + (x.familia ? ' · ' + e(x.familia) : '') + '</small></span></div></td>' +
                '<td><b>' + e(x.version) + '</b></td><td style="white-space:nowrap">' + est + '</td><td class="num">' + x.hitos + '</td><td class="num">' + x.equipos + '</td>' +
                '<td><span class="p3-pct ' + nivel(x.cumplimiento) + '">' + pct(x.cumplimiento) + '</span></td><td>' + e(x.proxima || '—') + '</td>' +
                '<td>' + nuevaPestana(x.url, 'Abrir plan', 'p3-btn') + '</td></tr>';
            if (ab) {
                h += '<tr class="p3-fila-det"><td colspan="9"><div class="p3-versiones">' +
                    (x.publicada ? '<div class="p3-version"><i class="pt" style="background:#1f9d63"></i><span><b>v' + x.publicada.numero + '</b> Publicada<small>Publicada el ' + e(x.publicada.fecha) + '</small><small>Por ' + e(x.publicada.por || '—') + '</small></span></div>' : '<div class="p3-version"><span class="p3-sub">Sin versión publicada: el plan todavía no genera ocurrencias.</span></div>') +
                    (x.borrador ? '<div class="p3-version"><i class="pt" style="background:#6a4cf5"></i><span><b>v' + x.borrador.numero + '</b> Borrador<small>Abierto el ' + e(x.borrador.fecha) + '</small><small>Por ' + e(x.borrador.por || '—') + '</small></span></div>' : '<div class="p3-version"><span class="p3-sub">Sin borrador abierto.</span></div>') +
                    (x.borrador ? nuevaPestana(x.editarUrl, '<i class="mdi mdi-pencil-outline"></i>Continuar edición', 'p3-btn') : '<span></span>') + '</div></td></tr>';
            }
        }
        return h + '</tbody></table></div>';
    };

    // ------------------------------------------------------- Programaciones
    var ICONO_TIPO = { 'FECHA UNICA': ['mdi-calendar-star', 'es-lila'], 'CALENDARIO': ['mdi-calendar-month-outline', 'es-lila'], 'INTERVALO TIEMPO': ['mdi-calendar-refresh-outline', 'es-lila'], 'MEDIDOR': ['mdi-gauge', 'es-ambar'], 'CONDICION': ['mdi-flask-outline', 'es-rojo'], 'ABIERTA': ['mdi-calendar-blank-outline', 'es-gris'] };
    var ICONO_USO = { Plan: 'mdi-file-document-outline', Tarea: 'mdi-wrench-outline', Pauta: 'mdi-format-list-checks' };
    VISTAS.programaciones = function (d) {
        var g = st.prog, l = d.reglas || [], h, i, x, t = '';
        for (i = 0; i < TIPOS.length; i++) t += '<option value="' + TIPOS[i][0] + '"' + (g.tipo === TIPOS[i][0] ? ' selected' : '') + '>' + TIPOS[i][1] + '</option>';
        h = '<div class="p3-titulo"><div><h2>Reglas de programación</h2><p>Una regla puede usarse en planes, tareas y pautas.</p></div><div class="p3-titulo-acc">' +
            '<span class="p3-busca"><i class="mdi mdi-magnify"></i><input id="p3gFiltro" value="' + e(g.filtro) + '" placeholder="Buscar…" style="width:220px"></span>' +
            '<label class="p3-etq-campo">Tipo <select class="p3-sel-mini" id="p3gTipo">' + t + '</select></label>' +
            (d.puedeEditar ? '<button class="p3-btn es-primario es-grande" data-acc="modal" data-tipo="programacion" data-titulo="Nueva programación" data-url="' + e(d.nuevaUrl) + '"><i class="mdi mdi-plus"></i>Nueva programación</button>' : '') + '</div></div>';
        if (!l.length) return h + vacio('mdi-calendar-sync-outline', g.filtro || g.tipo ? 'Ninguna regla coincide con la búsqueda.' : 'Todavía no hay programaciones.');
        h += '<div class="p3-tabla-marco p3-tabla-scroll"><table class="p3-tabla"><thead><tr><th style="width:40px"></th><th>Regla</th><th>Tipo</th><th>Próximas ejecuciones</th><th>Dónde se usa</th><th>Estado</th><th>Acción</th></tr></thead><tbody>';
        for (i = 0; i < l.length; i++) {
            x = l[i];
            var ab = !!g.abiertas[i], ic = ICONO_TIPO[x.tipoCodigo] || ICONO_TIPO.ABIERTA, prox, usos = '';
            if (x.fechas && x.fechas.length) {
                prox = '<small class="p3-sub">' + (x.fechas.length === 1 ? 'Fecha proyectada' : 'Fechas proyectadas') + '</small><div class="p3-fechas">';
                for (var f = 0; f < x.fechas.length; f++) prox += '<span>' + e(x.fechas[f]) + '</span>';
                prox += '</div>';
            } else prox = '<span class="p3-dos" style="font-weight:500">' + e(x.disparador || 'Sin fechas proyectadas') + '</span><small>' + e(x.detalle || '') + '</small>';
            var lista = x.usos || [], max = ab ? lista.length : Math.min(3, lista.length);
            for (var u = 0; u < max; u++) {
                var us = lista[u];
                usos += '<li><i class="mdi ' + (ICONO_USO[us.origen] || 'mdi-link') + '"></i><em>' + e(us.origen) + '</em>' +
                    (us.modal ? '<button data-acc="modal" data-tipo="pauta" data-url="' + e(us.url) + '">' + e(us.nombre) + '</button>' : nuevaPestana(us.url, e(us.nombre))) + '</li>';
            }
            if (lista.length > max) usos += '<li><button data-acc="expProg" data-valor="' + i + '">+' + (lista.length - max) + ' más</button></li>';
            h += '<tr' + (ab ? ' class="es-abierta"' : '') + '><td><button class="p3-chev" data-acc="expProg" data-valor="' + i + '" aria-expanded="' + ab + '" aria-label="Ver detalle"><i class="mdi mdi-chevron-' + (ab ? 'down' : 'right') + '"></i></button></td>' +
                '<td><div style="display:flex;gap:12px;align-items:center"><span class="p3-regla-ico ' + ic[1] + '"><i class="mdi ' + ic[0] + '"></i></span><span><span class="p3-dos">' + e(x.nombre) + '</span><small>' + e(x.alcance || 'Sin alcance definido') + '</small></span></div></td>' +
                '<td><span class="p3-dos" style="font-weight:500">' + e(x.tipo) + '</span><small>' + e(x.fechas && x.fechas.length ? x.detalle : '') + '</small></td>' +
                '<td>' + prox + '</td><td>' + (lista.length ? '<ul class="p3-usos">' + usos + '</ul>' : '<span class="p3-sub">Sin uso</span>') + '</td>' +
                '<td>' + (x.vigente ? '<span class="p3-chip s-activa sin-punto"><i class="mdi mdi-play-circle-outline"></i>Activa</span>' : '<span class="p3-chip s-gris sin-punto"><i class="mdi mdi-pause"></i>No vigente</span>') + '</td>' +
                '<td><button class="p3-btn" data-acc="modal" data-tipo="programacion" data-titulo="' + (d.puedeEditar ? 'Editar programación' : 'Programación') + '" data-url="' + e(x.url) + '">' + (d.puedeEditar ? 'Editar' : 'Ver') + '</button></td></tr>';
            if (ab) h += '<tr class="p3-fila-det"><td colspan="7"><div class="p3-det" style="grid-template-columns:1fr 1fr 1fr"><div><i class="mdi ' + ic[0] + '"></i><span><small>Regla</small><strong>' + e(x.detalle || x.tipo) + '</strong></span></div>' +
                '<div><i class="mdi mdi-map-marker-outline"></i><span><small>Alcance</small><strong>' + e(x.alcance || 'Sin alcance') + '</strong></span></div>' +
                '<div><i class="mdi mdi-link-variant"></i><span><small>Se usa en</small><strong>' + plural(lista.length, 'lugar', 'lugares') + '</strong></span></div></div></td></tr>';
        }
        return h + '</tbody></table></div><div class="p3-nota"><i class="mdi mdi-information-outline"></i>Las fechas proyectadas pueden cambiar al editar la regla. No son ocurrencias generadas.</div>';
    };

    // --------------------------------------------------------- Cumplimiento
    VISTAS.cumplimiento = function (d) {
        var h = '<div class="p3-titulo"><div><h2>Cumplimiento · ' + e(nombreMes(periodo())) + '</h2><p>Cohorte según fecha original del período: completadas a tiempo sobre programadas.</p></div><div class="p3-titulo-acc">' +
            '<button class="p3-btn es-grande" data-acc="exportarCumplimiento"' + (d.equipos && d.equipos.length ? '' : ' disabled') + '><i class="mdi mdi-download-outline"></i>Exportar</button></div></div>';
        if (!d.programadas) return h + vacio('mdi-chart-bar', 'No hay ocurrencias programadas en ' + nombreMes(periodo()).toLowerCase() + '.');
        var dif = d.vigente != null && d.original != null ? d.vigente - d.original : null;
        h += '<div class="p3-grandes"><div class="p3-grande"><span class="p3-ico es-azul"><i class="mdi mdi-calendar-check-outline"></i></span><div><strong>' + pct(d.original) + '</strong><b>Según fecha original</b><span>' + d.aTiempo + '/' + d.programadas + ' completadas a tiempo</span></div></div>' +
            '<div class="p3-grande"><span class="p3-ico es-verde"><i class="mdi mdi-chart-bar"></i></span><div><strong>' + pct(d.vigente) + '</strong><b>Según fecha reprogramada</b><span>' + d.aTiempoVigente + '/' + d.programadas + (dif != null ? ' · Comparación ' + (dif >= 0 ? '+' : '') + dif + ' puntos porcentuales' : '') + '</span></div></div></div>';
        var ch = [['es-verde', 'mdi-check-circle-outline', 'Completadas', d.completadas, 'Según fecha original'], ['es-ambar', 'mdi-clock-outline', 'Atrasadas', d.atrasadas, 'Según fecha original'],
            ['es-rojo', 'mdi-alert-outline', 'Vencidas', d.vencidas, 'Según fecha original'], ['es-gris', 'mdi-close-circle-outline', 'Omitidas', d.omitidas, 'Según fecha original'],
            ['es-lila', 'mdi-sync', 'Reprogramadas', d.reprogramadas, 'Incluidas en los estados anteriores; no se suman al total.']];
        h += '<div class="p3-chicas">';
        for (var i = 0; i < ch.length; i++) h += '<div class="p3-chica"><span class="p3-ico ' + ch[i][0] + '"><i class="mdi ' + ch[i][1] + '"></i></span><div><span>' + ch[i][2] + '</span><strong>' + ch[i][3] + '</strong><small>' + ch[i][4] + '</small></div></div>';
        h += '</div><h3 class="p3-sec">Por equipo</h3><div class="p3-tabla-marco p3-tabla-scroll"><table class="p3-tabla"><thead><tr><th>Equipo</th><th class="num">Programadas</th><th class="num">Completadas</th><th class="num">A tiempo</th><th>Cumplimiento <i class="mdi mdi-information-outline" title="Completadas a tiempo contra la fecha original, sobre programadas. Ordenado de menor a mayor."></i></th><th>Acciones</th></tr></thead><tbody>';
        for (var j = 0; j < d.equipos.length; j++) {
            var x = d.equipos[j], v = Math.round(x.cumplimiento);
            h += '<tr><td><span class="p3-dos">' + e(x.nombre) + '</span><small>' + e(x.codigo) + '</small></td><td class="num">' + x.programadas + '</td><td class="num">' + x.completadas + '</td><td class="num">' + x.aTiempo + '</td>' +
                '<td><span class="p3-barra-pct"><b>' + v + '%</b><span><i style="width:' + v + '%;background:' + colorNivel(v) + '"></i></span></span></td>' +
                '<td><button class="p3-mas" data-acc="verEquipo" data-valor="' + x.id + '" data-texto="' + e(x.codigo + ' · ' + x.nombre) + '">Ver ocurrencias <i class="mdi mdi-arrow-right"></i></button></td></tr>';
        }
        return h + '</tbody></table></div>';
    };
    function exportarCumplimiento() {
        var d = datos.cumplimiento; if (!d) return;
        var filas = [['Equipo', 'Código', 'Programadas', 'Completadas', 'A tiempo', 'Cumplimiento %']];
        d.equipos.forEach(function (x) { filas.push([x.nombre, x.codigo, x.programadas, x.completadas, x.aTiempo, String(x.cumplimiento).replace('.', ',')]); });
        var csv = '﻿' + filas.map(function (f) { return f.map(function (c) { return '"' + String(c == null ? '' : c).replace(/"/g, '""') + '"'; }).join(';'); }).join('\r\n');
        var a = document.createElement('a');
        a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
        a.download = 'cumplimiento-' + periodo() + '.csv'; document.body.appendChild(a); a.click(); a.remove();
    }

    // ------------------------------------------------------------ Cobertura
    function critClase(c) { c = (c || '').toUpperCase(); return c === 'CRITICA' ? 'c-critica' : c === 'ALTA' ? 'c-alta' : c === 'MEDIA' ? 'c-media' : c === 'BAJA' ? 'c-baja' : 'c-sin'; }
    VISTAS.cobertura = function (d) {
        var o = st.cob, r = d.resumen, varios = o.vista === 'varios', h, i, x;
        h = '<div class="p3-titulo"><div><h2>Cobertura de mantenimiento preventivo</h2><p>Detecta equipos sin mantenimiento preventivo vigente.</p></div></div>';
        h += '<div class="p3-cob-kpis">' +
            '<div class="p3-kpi es-pasiva"><span class="p3-kpi-ico es-azul"><i class="mdi mdi-cog-outline"></i></span><span class="p3-kpi-txt"><span class="p3-kpi-etq">Activos habilitados</span><strong>' + r.habilitados + '</strong></span></div>' +
            '<div class="p3-kpi es-pasiva"><span class="p3-kpi-ico es-verde"><i class="mdi mdi-check-circle-outline"></i></span><span class="p3-kpi-txt"><span class="p3-kpi-etq">Con plan vigente</span><strong>' + r.cubiertos + '</strong></span></div>' +
            '<button class="p3-kpi" data-acc="cobVista" data-valor="sin"><span class="p3-kpi-ico es-rojo"><i class="mdi mdi-minus-circle-outline"></i></span><span class="p3-kpi-txt"><span class="p3-kpi-etq">Sin plan vigente</span><strong>' + r.sin_plan + '</strong></span><i class="mdi mdi-chevron-right p3-kpi-ir"></i></button>' +
            '<button class="p3-kpi" data-acc="cobVista" data-valor="varios"><span class="p3-kpi-ico es-lila"><i class="mdi mdi-link-variant"></i></span><span class="p3-kpi-txt"><span class="p3-kpi-etq">En varios planes</span><strong>' + r.varios + '</strong><span class="p3-kpi-pie">Incluidos en los ' + r.cubiertos + ' cubiertos</span></span><i class="mdi mdi-chevron-right p3-kpi-ir"></i></button></div>';

        h += '<div class="p3-cob"><div><div class="p3-subtabs"><button data-acc="cobVista" data-valor="sin" aria-selected="' + !varios + '">Sin plan <b>' + r.sin_plan + '</b></button><button data-acc="cobVista" data-valor="varios" aria-selected="' + varios + '">Varios planes <b>' + r.varios + '</b></button></div>' +
            '<div class="p3-barra" style="margin-bottom:12px"><label class="p3-campo-apilado">Tipo<select class="p3-sel-mini" id="p3oTipo" style="min-width:190px">' + opciones(d.tipos, o.tipo, 'Todos') + '</select></label>' +
            '<label class="p3-campo-apilado">Área<select class="p3-sel-mini" id="p3oArea" style="min-width:190px">' + opciones(d.areas, o.area, 'Todas') + '</select></label>' +
            '<label class="p3-campo-apilado">Criticidad<select class="p3-sel-mini" id="p3oCrit" style="min-width:190px">' + opciones(d.criticidades, o.crit, 'Todas') + '</select></label></div>';
        var f = d.filas || [];
        if (!f.length) h += vacio(varios ? 'mdi-link-variant-off' : 'mdi-shield-check-outline', varios ? 'Ningún equipo está en más de un plan con estos filtros.' : 'Todos los equipos con estos filtros tienen un plan vigente.');
        else {
            h += '<div class="p3-tabla-marco p3-tabla-scroll"><table class="p3-tabla"><thead><tr><th>Equipo</th><th>Código</th><th>Ubicación</th><th>Área</th><th>Criticidad</th>' + (varios ? '<th>Planes</th>' : '') + '<th>Acción</th></tr></thead><tbody>';
            for (i = 0; i < f.length; i++) {
                x = f[i];
                h += '<tr><td>' + nuevaPestana(x.url, '<b style="font-weight:600">' + e(x.nombre) + '</b>') + '<small class="p3-sub">' + e(x.tipo || '') + '</small></td><td>' + e(x.codigo) + '</td><td>' + e(x.planta || '—') + '</td><td>' + e(x.area || '—') + '</td>' +
                    '<td><span class="p3-crit ' + critClase(x.criticidadCodigo) + '">' + (x.criticidad ? '<i class="mdi mdi-alert-circle"></i>' + e(x.criticidad) : 'Sin definir') + '</span></td>' +
                    (varios ? '<td><small>' + e(x.planesNombres.join(' · ')) + '</small></td><td><button class="p3-btn" data-acc="coinc" data-valor="' + i + '">Revisar</button></td>' : '<td><button class="p3-btn" data-acc="ir" data-sec="planes">Asociar a plan</button></td>') + '</tr>';
            }
            h += '</tbody></table></div>';
        }
        h += pie(d.total, d.pagina, d.paginas, 10, 'cobertura', '<i class="mdi mdi-information-outline"></i> Se considera la versión publicada de cada plan.') + '</div>';

        var c = varios && o.foco >= 0 && f[o.foco] ? f[o.foco] : (d.coincidencias || [])[0];
        h += '<aside class="p3-coinc"><div class="p3-tarjeta-cab" style="margin-bottom:0"><span class="p3-ico es-lila"><i class="mdi mdi-link-variant"></i></span><div><h3>Revisar coincidencias</h3><p>' + (c ? 'Este equipo está incluido en más de un plan de mantenimiento.' : 'Ningún equipo está en más de un plan.') + '</p></div></div>';
        if (c) {
            h += '<div class="p3-coinc-eq"><div style="display:flex;gap:12px"><span class="p3-plan-ico"><i class="mdi mdi-cog-outline"></i></span><div><strong>' + e(c.nombre) + '</strong><small class="p3-sub">' + e(c.codigo) + ' · ' + e(c.planta || '') + (c.area ? ' · ' + e(c.area) : '') + '</small>' +
                '<div style="margin-top:8px"><span class="p3-chip s-borrador-v sin-punto">Incluido en ' + c.planes + ' planes</span></div></div></div><ul>';
            for (i = 0; i < c.planesNombres.length; i++) h += '<li>' + e(c.planesNombres[i]) + '</li>';
            h += '</ul></div>' + (varios ? '' : '<button class="p3-btn" style="width:100%;height:42px" data-acc="cobVista" data-valor="varios">Comparar cobertura</button>');
        }
        return h + '<div class="p3-nota" style="margin-bottom:0"><i class="mdi mdi-information-outline"></i>Varios planes pueden cubrir trabajos distintos; revisa antes de cambiar.</div></aside></div>';
    };

    // ------------------------------------------------------------- acciones
    function modal(tipo, url, titulo) {
        var t = { reprogramar: 'Reprogramar ocurrencia', programacion: titulo || 'Programación', carga: 'Carga masiva de planes', pauta: 'Programación de pauta' }[tipo] || titulo;
        SigmaModal.open({ url: url, title: t, width: tipo === 'programacion' ? 1240 : tipo === 'carga' ? 860 : 900, initialHeight: tipo === 'programacion' ? 760 : 620, minHeight: 480 });
    }
    function generarUna(btn) {
        if (!confirm('¿Generar la orden de trabajo para esta ocurrencia?')) return;
        btn.disabled = true; btn.textContent = 'Generando…';
        pedir('GenerarOrden', { token: btn.getAttribute('data-token') }).then(function (x) {
            if (x.error) { alert(x.detalle); btn.disabled = false; btn.textContent = 'Generar OT'; return; }
            vencerTodo(); kpis(); cargar(st.tab);
        }, function () { alert('No fue posible generar la orden.'); btn.disabled = false; btn.textContent = 'Generar OT'; });
    }
    function clic(ev) {
        var el = ev.target.closest ? ev.target.closest('a,[data-acc],[data-ir],.p3-tabs [role=tab]') : null;
        if (!el || !raiz.contains(el) || el.tagName === 'A') return;
        if (el.getAttribute('role') === 'tab' && el.parentNode.classList.contains('p3-tabs')) { ev.preventDefault(); ir(el.getAttribute('data-sec')); return; }
        if (el.hasAttribute('data-ir')) {
            ev.preventDefault();
            var s = el.getAttribute('data-kpi-situacion');
            if (s) { st.bandeja.situacion = s === 'URGENTE' ? '' : s; st.bandeja.pagina = 1; vencidas.bandeja = true; }
            if (el.getAttribute('data-kpi-vista')) { st.cal.vista = el.getAttribute('data-kpi-vista'); if (datos.calendario) vencidas.calendario = true; }
            ir(el.getAttribute('data-ir'));
            return;
        }
        var acc = el.getAttribute('data-acc'), v = el.getAttribute('data-valor'), b = st.bandeja;
        switch (acc) {
            case 'reintentar': cargar(st.tab); break;
            case 'ir': ir(el.getAttribute('data-sec')); break;
            case 'modal': modal(el.getAttribute('data-tipo'), el.getAttribute('data-url'), el.getAttribute('data-titulo')); break;
            case 'generar': generarUna(el); break;
            case 'situacion': b.situacion = v; b.pagina = 1; b.sel = {}; b.resultado = ''; cargar('bandeja'); break;
            case 'pagina': if (el.getAttribute('data-sec') === 'bandeja') { b.pagina = +v; b.sel = {}; cargar('bandeja'); } else { st.cob.pagina = +v; cargar('cobertura'); } break;
            case 'sel': b.sel[el.getAttribute('data-token')] = el.checked; pintar('bandeja'); break;
            case 'todos': (datos.bandeja.filas || []).forEach(function (f) { if (!f.ordenUrl && datos.bandeja.puedeGenerar) b.sel[f.token] = el.checked; }); pintar('bandeja'); break;
            case 'generarSel': generarSeleccion(); break;
            case 'expandir': var t = el.getAttribute('data-token'); b.abiertas[t] = !b.abiertas[t]; pintar('bandeja'); break;
            case 'mes':
                var n = parseInt(v, 10), m = mesDe(periodo()), h = hoy();
                var dest = n === 0 ? new Date(h.getFullYear(), h.getMonth(), 1, 12) : new Date(m.getFullYear(), m.getMonth() + n, 1, 12);
                st.cal.dia = n === 0 ? cfg.hoy : '';
                cambiarPeriodo(dest.getFullYear() + '-' + ('0' + (dest.getMonth() + 1)).slice(-2)); break;
            case 'vista': st.cal.vista = v; pintar('calendario'); break;
            case 'dia': st.cal.dia = el.getAttribute('data-dia'); pintar('calendario'); break;
            case 'expPlan': st.planes.abiertas[v] = !st.planes.abiertas[v]; pintar('planes'); break;
            case 'expProg': st.prog.abiertas[v] = !st.prog.abiertas[v]; pintar('programaciones'); break;
            case 'exportarCumplimiento': exportarCumplimiento(); break;
            case 'verEquipo':
                st.cal.equipo = +v; st.cal.plan = 0; st.cal.vista = 'mes';
                if (!st.cal.equipos.some(function (q) { return String(q.id) === v; })) st.cal.equipos.push({ id: +v, texto: el.getAttribute('data-texto') });
                vencidas.calendario = true; ir('calendario'); break;
            case 'cobVista': st.cob.vista = v; st.cob.pagina = 1; st.cob.foco = -1; cargar('cobertura'); break;
            case 'coinc': st.cob.foco = +v; pintar('cobertura'); break;
        }
    }
    function cambio(ev) {
        var id = ev.target.id, v = ev.target.value, b = st.bandeja, c = st.cal;
        if (id === 'p360Planta' || id === 'p360Periodo') {
            if (id === 'p360Planta') { tituloPlanta(); kpis(); b.plan = 0; c.plan = 0; c.equipo = 0; } else textoPeriodo();
            c.dia = ''; b.pagina = 1; b.sel = {}; st.cob.pagina = 1; vencerTodo(); guardarUrl(); cargar(st.tab); return;
        }
        switch (id) {
            case 'p3bPlan': b.plan = +v; b.pagina = 1; b.sel = {}; cargar('bandeja'); break;
            case 'p3bParada': b.parada = ev.target.checked; b.pagina = 1; b.sel = {}; cargar('bandeja'); break;
            case 'p3cPlan': c.plan = +v; c.equipo = 0; cargar('calendario'); break;
            case 'p3cEquipo': c.equipo = +v; cargar('calendario'); break;
            case 'p3cParada': c.parada = ev.target.checked; cargar('calendario'); break;
            case 'p3pEstado': st.planes.estado = v; cargar('planes'); break;
            case 'p3gTipo': st.prog.tipo = v; cargar('programaciones'); break;
            case 'p3oTipo': st.cob.tipo = +v; st.cob.pagina = 1; cargar('cobertura'); break;
            case 'p3oArea': st.cob.area = +v; st.cob.pagina = 1; cargar('cobertura'); break;
            case 'p3oCrit': st.cob.crit = +v; st.cob.pagina = 1; cargar('cobertura'); break;
        }
    }
    var espera;
    function tecla(ev) {
        var t = ev.target, id = t.id;
        // Tablist: flechas, Inicio y Fin (patrón ARIA).
        if (ev.type === 'keydown' && t.getAttribute('role') === 'tab' && t.parentNode.classList.contains('p3-tabs')) {
            var tabs = [].slice.call(raiz.querySelectorAll('.p3-tabs [role=tab]')), i = tabs.indexOf(t), n = -1;
            if (ev.key === 'ArrowRight') n = (i + 1) % tabs.length; else if (ev.key === 'ArrowLeft') n = (i + tabs.length - 1) % tabs.length;
            else if (ev.key === 'Home') n = 0; else if (ev.key === 'End') n = tabs.length - 1;
            if (n >= 0) { ev.preventDefault(); ir(tabs[n].getAttribute('data-sec'), true); }
            return;
        }
        if (ev.type === 'keydown' && (ev.key === 'Enter' || ev.key === ' ') && t.classList && t.classList.contains('p3-dia')) { ev.preventDefault(); st.cal.dia = t.getAttribute('data-dia'); pintar('calendario'); return; }
        if (id === 'p3bFiltro' || id === 'p3pFiltro' || id === 'p3gFiltro') {
            // Enter NUNCA envía el form del master: filtra.
            if (ev.key === 'Enter') ev.preventDefault();
            if (ev.type === 'keydown' && ev.key !== 'Enter') return;
            clearTimeout(espera);
            espera = setTimeout(function () {
                var v = t.value.trim();
                if (id === 'p3bFiltro' && v !== st.bandeja.filtro) { st.bandeja.filtro = v; st.bandeja.pagina = 1; st.bandeja.sel = {}; cargar('bandeja'); }
                if (id === 'p3pFiltro' && v !== st.planes.filtro) { st.planes.filtro = v; cargar('planes'); }
                if (id === 'p3gFiltro' && v !== st.prog.filtro) { st.prog.filtro = v; cargar('programaciones'); }
            }, ev.key === 'Enter' ? 0 : 450);
        } else if (ev.type === 'keydown' && ev.key === 'Enter' && t.tagName === 'INPUT') ev.preventDefault();
    }

    // ------------------------------------------------------ selector período
    // Calendario propio de SIGMA con solo meses y años: año arriba (‹ 2026 ›)
    // y los doce meses en grilla. Escribe en el <select> oculto y dispara su
    // change, así el resto del código no sabe que existe.
    var MES_CORTO = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    var pop = { anio: 0 };
    function textoPeriodo() { $id('p3PeriodoTxt').textContent = nombreMes(periodo()); }
    function pintarPop(foco) {
        var sel = periodo(), h = hoy(), actual = h.getFullYear() + '-' + ('0' + (h.getMonth() + 1)).slice(-2), y = pop.anio;
        var objetivo = foco || (sel.slice(0, 4) === String(y) ? sel : y + '-01');
        var s = '<div class="p3-pop-cab"><button type="button" class="p3-pop-nav" data-pop="-1" aria-label="Año anterior"><i class="mdi mdi-chevron-left"></i></button>' +
            '<strong aria-live="polite">' + y + '</strong><button type="button" class="p3-pop-nav" data-pop="1" aria-label="Año siguiente"><i class="mdi mdi-chevron-right"></i></button></div><div class="p3-pop-meses" role="grid">';
        for (var m = 0; m < 12; m++) {
            var v = y + '-' + ('0' + (m + 1)).slice(-2);
            s += '<button type="button" role="gridcell" data-mes="' + v + '" class="' + (v === sel ? 'es-sel' : '') + (v === actual ? ' es-hoy' : '') + '" aria-selected="' + (v === sel) + '" aria-label="' + MESES[m] + ' ' + y + '" tabindex="' + (v === objetivo ? 0 : -1) + '">' + MES_CORTO[m] + '</button>';
        }
        s += '</div><div class="p3-pop-pie"><button type="button" data-mes="' + actual + '">Mes actual</button><button type="button" data-cerrar-pop>Cerrar</button></div>';
        var caja = $id('p3PeriodoPop');
        caja.innerHTML = s;
        var f = caja.querySelector('[role=gridcell][tabindex="0"]');
        if (f) f.focus();
    }
    function abrirPop() {
        pop.anio = +periodo().slice(0, 4);
        $id('p3PeriodoPop').hidden = false; $id('p3PeriodoBtn').setAttribute('aria-expanded', 'true');
        pintarPop();
    }
    function cerrarPop(devolverFoco) {
        if ($id('p3PeriodoPop').hidden) return;
        $id('p3PeriodoPop').hidden = true; $id('p3PeriodoBtn').setAttribute('aria-expanded', 'false');
        if (devolverFoco) $id('p3PeriodoBtn').focus();
    }
    function elegirMes(v) {
        var s = $id('p360Periodo');
        if (!s.querySelector('option[value="' + v + '"]')) { var o = document.createElement('option'); o.value = v; o.textContent = nombreMes(v); s.appendChild(o); }
        cerrarPop(true);
        if (s.value === v) return;
        s.value = v;
        var ev = document.createEvent('Event'); ev.initEvent('change', true, true); s.dispatchEvent(ev);
    }
    function iniciarPop() {
        var btn = $id('p3PeriodoBtn'), caja = $id('p3PeriodoPop');
        btn.addEventListener('click', function () { if (caja.hidden) abrirPop(); else cerrarPop(true); });
        btn.addEventListener('keydown', function (ev) { if (ev.key === 'ArrowDown') { ev.preventDefault(); abrirPop(); } });
        caja.addEventListener('click', function (ev) {
            var b = ev.target.closest('button'); if (!b) return;
            if (b.hasAttribute('data-pop')) { pop.anio += +b.getAttribute('data-pop'); pintarPop(); }
            else if (b.hasAttribute('data-mes')) elegirMes(b.getAttribute('data-mes'));
            else if (b.hasAttribute('data-cerrar-pop')) cerrarPop(true);
        });
        caja.addEventListener('keydown', function (ev) {
            if (ev.key === 'Escape') { ev.preventDefault(); cerrarPop(true); return; }
            var c = ev.target.getAttribute && ev.target.getAttribute('data-mes');
            if (!c || ev.target.getAttribute('role') !== 'gridcell') return;
            if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); elegirMes(c); return; }
            var paso = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -3, ArrowDown: 3 }[ev.key];
            if (!paso) return;
            ev.preventDefault();
            var y = +c.slice(0, 4), m = +c.slice(5) - 1 + paso;
            if (m < 0) { y--; m += 12; } else if (m > 11) { y++; m -= 12; }
            pop.anio = y; pintarPop(y + '-' + ('0' + (m + 1)).slice(-2));
        });
        document.addEventListener('mousedown', function (ev) { if (!caja.hidden && !caja.contains(ev.target) && !btn.contains(ev.target)) cerrarPop(false); });
        textoPeriodo();
    }

    function iniciar() {
        cfg = window.Planificacion360Config; raiz = $id('sgP360');
        if (!cfg || !raiz) return;
        raiz.addEventListener('click', clic);
        raiz.addEventListener('change', cambio);
        raiz.addEventListener('keydown', tecla);
        raiz.addEventListener('keyup', tecla);
        // Volver de un modal (reprogramar, wizard, carga masiva): refrescar
        // lo que pudo cambiar.
        document.addEventListener('sigma:modalclosed', function () { vencerTodo(); kpis(); cargar(st.tab); });
        leerUrl(); iniciarPop(); tituloPlanta(); kpis(); ir(st.tab);
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', iniciar); else iniciar();
})();
