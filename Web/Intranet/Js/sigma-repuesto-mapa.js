/* ============================================================================
   Centro de repuestos · Mapa por ubicación (06-10-2026)

   Donde esta cada repuesto: planta › bodega › ubicacion (rack) › nivel.
   Se dibuja con WsBodegaMapa (el mismo servicio del mapa SIGMA Twin), asi que
   mover un repuesto aqui es mover el stock de verdad:
     - Arrastrar a OTRO rack      -> ReubicarCaja (movimiento «cambio de ubicacion»)
                                     y el nivel queda en el planograma del destino.
     - Arrastrar a otro nivel     -> GuardarPosiciones (planograma del rack).
     - Clic en un repuesto        -> drawer con su ubicacion, existencia, umbrales
                                     y los controles para moverlo sin arrastrar.
   Crear bodegas y ubicaciones es inline, en la misma pestaña (sin modal).
   Cada llamada vuelve a validar sesion y permiso en el servidor.
   ========================================================================= */
(function () {
    'use strict';

    var WSURL = (function () {
        var s = document.querySelector('script[src*="sigma-repuesto-mapa.js"]');
        return (s ? s.getAttribute('src').split('/Js/')[0] : '') + '/WebService/WsBodegaMapa.asmx';
    })();

    var M = null;            // lo ultimo que devolvio Cargar
    var planta = 0;
    var OPT = {};
    var host = null;
    var sel = null;          // {rep, b, u}: el repuesto del drawer
    var forms = { bodega: null, ubic: null, editar: null };   // formularios inline abiertos
    var drag = null;
    var cargando = false;
    var posBy = {}, saldos = [];

    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
    function num(n) { return n == null ? '—' : Number(n).toLocaleString('es-CL', { maximumFractionDigits: 2 }); }
    function svg(p, n) { return '<svg width="' + (n || 16) + '" height="' + (n || 16) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; }
    var IC = {
        caja: '<path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/>',
        mas: '<path d="M12 5v14M5 12h14"/>',
        x: '<path d="M6 6l12 12M18 6L6 18"/>',
        rack: '<rect x="4" y="3" width="16" height="18" rx="1.5"/><path d="M4 9h16M4 15h16"/>',
        lapiz: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
        qr: '<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 14h2v6h-4M14 18h2"/>',
        basura: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
        flecha: '<path d="M5 12h14M13 6l6 6-6 6"/>',
        alerta: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>'
    };

    async function ws(metodo, datos) {
        var r = await fetch(WSURL + '/' + metodo, {
            method: 'POST', credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json; charset=utf-8' },
            body: JSON.stringify(datos || {})
        });
        if (!r.ok) throw new Error('El servidor respondió ' + r.status + '.');
        var d = JSON.parse((await r.json()).d);
        if (d.error) throw new Error(d.detalle || 'No se pudo completar la operación.');
        return d;
    }

    function aviso(texto, error) {
        var t = document.createElement('div');
        t.className = 'rm-toast' + (error ? ' es-error' : '');
        t.setAttribute('role', 'status');
        t.innerHTML = svg(error ? IC.alerta : '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.5"/>', 18) + '<span>' + esc(texto) + '</span>';
        document.body.appendChild(t);
        setTimeout(function () { t.classList.add('es-fuera'); setTimeout(function () { t.remove(); }, 400); }, error ? 6500 : 3200);
    }

    /* ------------------------------------------------------------ datos */
    async function cargar(p) {
        if (cargando) return;
        cargando = true;
        try {
            var d = await ws('Cargar', { planta: p || planta || 0 });
            M = d; planta = d.planta;
            indexar();
        } finally { cargando = false; }
    }
    function indexar() {
        posBy = {};
        (M.posiciones || []).forEach(function (x) { posBy[x.u + '_' + x.rep] = x; });
        saldos = (M.saldos || []).filter(function (s) { return s.q > 0 || s.u > 0; });
    }
    function tono(s) {
        if (s.min != null && s.q < s.min) return 'bajo';
        if (s.max != null && s.max > 0 && s.q > s.max) return 'alto';
        return 'ok';
    }
    function bodegasDePlanta() { return (M.bodegas || []).filter(function (b) { return b.plantaId === planta; }); }
    function bodega(id) { return (M.bodegas || []).filter(function (b) { return b.id === id; })[0]; }
    function ubic(b, id) { return b ? (b.ubicaciones || []).filter(function (u) { return u.id === id; })[0] : null; }
    function puedeMover() { return !!(M && M.permisos && M.permisos.ajuste); }
    function puedeCrear() { return !!(M && M.permisos && M.permisos.bodegas); }
    function coincide(s) {
        if (!OPT.q) return true;
        return norm([s.c, s.n, s.fab, s.mod, s.tn].join(' ')).indexOf(norm(OPT.q)) >= 0;
    }

    /* ------------------------------------------------------------ dibujo */
    function chip(s) {
        var on = sel && sel.rep === s.id && sel.u === s.u && sel.b === s.b;
        return '<button type="button" class="rm-chip es-' + tono(s) + (coincide(s) ? '' : ' is-dim') + (on ? ' is-sel' : '') + '"'
            + (puedeMover() ? ' draggable="true"' : '') + ' data-rep="' + s.id + '" data-b="' + s.b + '" data-u="' + s.u + '" title="' + esc(s.n) + '">'
            + '<span class="rm-ph">' + (s.foto ? '<img src="' + esc(s.foto) + '" alt="" loading="lazy">' : svg(IC.caja, 13)) + '</span>'
            + '<span class="rm-n">' + esc(s.n) + '</span><b>' + num(s.q) + '<small>' + esc(s.un) + '</small></b></button>';
    }

    function rack(b, u) {
        var items = saldos.filter(function (s) { return s.b === b.id && s.u === u.id; });
        var porN = {}, maxN = 4;
        items.forEach(function (s) {
            var p = posBy[u.id + '_' + s.id], n = p ? p.n : 0;
            if (n > maxN) maxN = n;
            (porN[n] = porN[n] || []).push(s);
        });
        var h = '';
        for (var n = maxN; n >= 1; n--)
            h += '<div class="rm-niv" data-b="' + b.id + '" data-u="' + u.id + '" data-n="' + n + '"><span class="rm-niv-l">N' + n + '</span><div class="rm-niv-c">' + (porN[n] || []).map(chip).join('') + '</div></div>';
        h += '<div class="rm-niv es-sin" data-b="' + b.id + '" data-u="' + u.id + '" data-n="0"><span class="rm-niv-l">Sin<br>nivel</span><div class="rm-niv-c">' + (porN[0] || []).map(chip).join('') + '</div></div>';
        var alertas = items.filter(function (s) { return tono(s) === 'bajo'; }).length;
        return '<div class="rm-rack' + (alertas ? ' es-alerta' : '') + (items.length ? '' : ' es-vacio') + '">'
            + '<div class="rm-rack-h">' + svg(IC.rack, 15) + '<b>' + esc(u.codigo) + '</b><span title="Repuestos en esta ubicación">' + items.length + '</span>'
            + (puedeCrear() && !items.length ? '<button type="button" class="rm-ib" data-delubic="' + u.id + '" title="Eliminar la ubicación vacía">' + svg(IC.basura, 14) + '</button>' : '')
            + '</div>'
            + (u.nombre && u.nombre !== u.codigo ? '<small class="rm-rack-n">' + esc(u.nombre) + '</small>' : '')
            + h + '</div>';
    }

    function formUbic(b) {
        var n = (b.ubicaciones || []).length + 1, cod;
        do { cod = 'R' + (n < 10 ? '0' + n : n); n++; } while ((b.ubicaciones || []).some(function (u) { return u.codigo === cod; }));
        return '<div class="rm-form" data-formubic="' + b.id + '"><b>Nueva ubicación en ' + esc(b.nombre) + '</b>'
            + '<label>Código<input type="text" data-f="codigo" maxlength="30" value="' + esc(cod) + '"></label>'
            + '<label>Nombre <small>(opcional)</small><input type="text" data-f="nombre" maxlength="100" placeholder="Pasillo A · Rack 01"></label>'
            + '<span class="rm-form-acc"><button type="button" class="rm-bt es-ghost" data-cancelar="1">Cancelar</button><button type="button" class="rm-bt es-pri" data-guardarubic="' + b.id + '">Crear ubicación</button></span></div>';
    }
    function formBodega(b) {
        var nueva = !b;
        var pl = (M.plantas || []).map(function (p) { return '<option value="' + p.id + '"' + ((b ? b.plantaId : planta) === p.id ? ' selected' : '') + '>' + esc(p.nombre) + '</option>'; }).join('');
        return '<div class="rm-form rm-form-b" data-formbodega="' + (b ? b.id : 0) + '"><b>' + (nueva ? 'Nueva bodega' : 'Editar ' + esc(b.nombre)) + '</b>'
            + '<label>Nombre *<input type="text" data-f="nombre" maxlength="400" value="' + esc(b ? b.nombre : '') + '" placeholder="Ej.: Bodega central"></label>'
            + '<label>Planta *<select data-f="planta">' + pl + '</select></label>'
            + '<label>Descripción<input type="text" data-f="descripcion" maxlength="400" value="' + esc(b ? b.descripcion : '') + '" placeholder="Para qué se usa"></label>'
            + '<label>Método de salida<select data-f="metodo">' + [['', 'Según la configuración'], ['FEFO', 'FEFO · vence primero'], ['FIFO', 'FIFO · entró primero'], ['LIFO', 'LIFO · entró último']]
                .map(function (o) { return '<option value="' + o[0] + '"' + ((b ? b.metodo : '') === o[0] ? ' selected' : '') + '>' + o[1] + '</option>'; }).join('') + '</select></label>'
            + '<span class="rm-form-acc"><button type="button" class="rm-bt es-ghost" data-cancelar="1">Cancelar</button><button type="button" class="rm-bt es-pri" data-guardarbodega="' + (b ? b.id : 0) + '">' + (nueva ? 'Crear bodega' : 'Guardar cambios') + '</button></span></div>';
    }

    function tarjetaBodega(b) {
        var propios = saldos.filter(function (s) { return s.b === b.id; });
        var sinUbicar = propios.filter(function (s) { return !s.u; });
        var bajos = propios.filter(function (s) { return tono(s) === 'bajo'; }).length;
        var h = '<article class="rm-bod" data-bod="' + b.id + '"><header><div><b>' + esc(b.nombre) + '</b><small>' + esc(b.codigo) + ' · ' + (b.ubicaciones || []).length + ' ubicaciones'
            + (b.metodo ? ' · ' + esc(b.metodo) : '') + '</small></div><div class="rm-bod-acc">'
            + '<span class="rm-pill ' + (bajos ? 'es-bajo' : 'es-ok') + '"><i></i>' + propios.length + ' repuestos' + (bajos ? ' · ' + bajos + ' bajo mínimo' : '') + '</span>'
            + (puedeCrear() ? '<button type="button" class="rm-bt" data-nueva-ubic="' + b.id + '">' + svg(IC.mas, 14) + 'Ubicación</button><button type="button" class="rm-ib" data-editar-bod="' + b.id + '" title="Editar la bodega">' + svg(IC.lapiz, 15) + '</button>' : '')
            + '</div></header>';
        if (forms.editar === b.id) h += formBodega(b);
        if (forms.ubic === b.id) h += formUbic(b);
        if (sinUbicar.length)
            h += '<div class="rm-tray"><span>' + svg(IC.alerta, 14) + 'Sin ubicar · arrástralos a un rack</span><div class="rm-niv-c">' + sinUbicar.map(chip).join('') + '</div></div>';
        h += '<div class="rm-racks">' + ((b.ubicaciones || []).map(function (u) { return rack(b, u); }).join('')
            || '<div class="rm-vacio-b">' + (puedeCrear() ? 'Esta bodega aún no tiene ubicaciones. Crea la primera con «+ Ubicación».' : 'Esta bodega aún no tiene ubicaciones.') + '</div>') + '</div></article>';
        return h;
    }

    /* ------------------------------------------------------------ drawer */
    function drawer() {
        if (!sel) return '';
        var s = saldos.filter(function (x) { return x.id === sel.rep && x.b === sel.b && x.u === sel.u; })[0];
        if (!s) return '';
        var b = bodega(s.b), u = ubic(b, s.u), p = posBy[s.u + '_' + s.id];
        var otros = saldos.filter(function (x) { return x.id === s.id && !(x.b === s.b && x.u === s.u); });
        var t = tono(s), tope = Math.max(s.max || 0, s.q, s.min || 0, s.pr || 0) || 1, pc = function (v) { return Math.min(100, v / tope * 100); };
        var ubOps = (b ? b.ubicaciones : []).map(function (x) { return '<option value="' + x.id + '"' + (x.id === s.u ? ' selected' : '') + '>' + esc(x.codigo) + (x.nombre && x.nombre !== x.codigo ? ' · ' + esc(x.nombre) : '') + '</option>'; }).join('');
        var nvOps = '<option value="0">Sin nivel</option>' + [1, 2, 3, 4].map(function (n) { return '<option value="' + n + '"' + (p && p.n === n ? ' selected' : '') + '>Nivel ' + n + '</option>'; }).join('');
        var dato = function (k, v) { return '<div><span>' + k + '</span><b>' + v + '</b></div>'; };
        return '<div class="rm-scrim" data-cerrar-dr="1"></div><aside class="rm-drawer" role="dialog" aria-label="Detalle del repuesto">'
            + '<header><span class="rm-dr-foto">' + (s.foto ? '<img src="' + esc(s.foto) + '" alt="">' : svg(IC.caja, 26)) + '</span>'
            + '<div><small>' + esc(s.c) + '</small><h3>' + esc(s.n) + '</h3><span class="rm-pill es-' + t + '"><i></i>' + (t === 'bajo' ? 'Bajo el mínimo' : t === 'alto' ? 'Sobre el máximo' : 'En orden') + '</span></div>'
            + '<button type="button" class="rm-ib" data-cerrar-dr="1" aria-label="Cerrar">' + svg(IC.x, 18) + '</button></header>'
            + '<section><h4>Dónde está</h4><div class="rm-dl">'
            + dato('Planta', esc(b ? b.planta : '—')) + dato('Bodega', esc(b ? b.nombre : '—'))
            + dato('Ubicación', u ? esc(u.codigo) + (u.nombre && u.nombre !== u.codigo ? ' · ' + esc(u.nombre) : '') : '<em>Sin ubicar</em>')
            + dato('Nivel', p ? 'Nivel ' + p.n : '<em>Sin nivel asignado</em>') + dato('Posición', p ? p.p + (p.f ? ' · fila trasera' : '') : '—')
            + '</div></section>'
            + '<section><h4>Existencia</h4><div class="rm-dl">' + dato('Disponible', num(s.q) + ' ' + esc(s.un)) + dato('Reservada', num(s.res))
            + dato('Lotes', s.lot || '—') + dato('Último movimiento', esc(s.ult || '—')) + dato('Ingreso', esc(s.ing || '—')) + dato('Vence', esc(s.vence || '—')) + '</div>'
            + '<div class="rm-bar es-' + t + '"><i style="width:' + pc(s.q) + '%"></i>'
            + (s.min != null ? '<em style="left:' + pc(s.min) + '%" title="Mínimo"></em>' : '') + (s.pr != null ? '<em class="es-pr" style="left:' + pc(s.pr) + '%" title="Reposición"></em>' : '') + (s.max != null ? '<em class="es-max" style="left:' + pc(s.max) + '%" title="Máximo"></em>' : '') + '</div>'
            + '<p class="rm-umb">Mínimo <b>' + num(s.min) + '</b> · Reposición <b>' + num(s.pr) + '</b> · Máximo <b>' + num(s.max) + '</b></p></section>'
            + (s.largo || s.peso ? '<section><h4>Medidas</h4><div class="rm-dl">' + dato('Largo × ancho × alto', num(s.largo) + ' × ' + num(s.ancho) + ' × ' + num(s.alto) + ' cm') + dato('Peso', num(s.peso) + ' kg') + dato('Método de salida', esc(s.met || (b && b.metodo) || '—')) + '</div></section>' : '')
            + (puedeMover() && b && (b.ubicaciones || []).length
                ? '<section><h4>Mover dentro de la bodega</h4><div class="rm-mover"><label>Ubicación<select id="rmUb">' + ubOps + '</select></label><label>Nivel<select id="rmNv">' + nvOps + '</select></label>'
                  + '<button type="button" class="rm-bt es-pri" data-mover-dr="1">Mover' + svg(IC.flecha, 15) + '</button></div>'
                  + '<p class="rm-ayuda">Mueve el stock de verdad: queda un movimiento «cambio de ubicación». Para llevarlo a otra bodega, registra un traslado en Movimientos.</p></section>' : '')
            + (otros.length ? '<section><h4>También está en</h4><div class="rm-otros">' + otros.map(function (x) {
                var bx = bodega(x.b), ux = ubic(bx, x.u);
                return '<button type="button" data-ir-rep="' + x.id + '|' + x.b + '|' + x.u + '"><span>' + esc(bx ? bx.nombre : '') + ' · ' + (ux ? esc(ux.codigo) : 'sin ubicar') + '</span><b>' + num(x.q) + ' ' + esc(x.un) + '</b></button>';
            }).join('') + '</div></section>' : '')
            + '<footer><button type="button" class="rm-bt" data-etiqueta-dr="' + s.id + '">' + svg(IC.qr, 15) + 'Etiqueta</button>'
            + '<button type="button" class="rm-bt es-pri" data-ficha-dr="' + s.id + '">Abrir ficha' + svg(IC.flecha, 15) + '</button></footer></aside>';
    }

    function dibujar() {
        if (!host || !M) return;
        var plOps = (M.plantas || []).map(function (p) { return '<option value="' + p.id + '"' + (p.id === planta ? ' selected' : '') + '>' + esc(p.nombre) + '</option>'; }).join('');
        var bods = bodegasDePlanta();
        host.innerHTML = '<div class="rm">'
            + '<div class="rm-top"><div class="rm-top-l">' + ((M.plantas || []).length > 1 ? '<label class="rm-sel">Planta<select id="rmPlanta">' + plOps + '</select></label>' : '<span class="rm-planta">' + svg('<path d="M3 21V9l6-4v4l6-4v4l6-4v16z"/>', 17) + esc(((M.plantas || [])[0] || {}).nombre || '') + '</span>')
            + '<span class="rm-leyenda"><i class="es-ok"></i>En orden<i class="es-bajo"></i>Bajo el mínimo<i class="es-alto"></i>Sobre el máximo</span></div>'
            + (puedeCrear() ? '<button type="button" class="rm-bt es-pri" data-nueva-bod="1">' + svg(IC.mas, 15) + 'Nueva bodega</button>' : '') + '</div>'
            + (forms.bodega ? formBodega(null) : '')
            + (puedeMover() ? '<p class="rm-ayuda es-top">' + svg(IC.flecha, 14) + 'Arrastra un repuesto a otro rack o nivel para reubicarlo. Haz clic para ver su detalle.</p>' : '')
            + (bods.length ? '<div class="rm-bods">' + bods.map(tarjetaBodega).join('') + '</div>'
                : '<div class="rm-vacio">' + svg(IC.rack, 34) + '<b>No hay bodegas en esta planta</b><span>' + (puedeCrear() ? 'Crea la primera con «Nueva bodega».' : 'Pide a un administrador que cree una.') + '</span></div>')
            + '</div>' + drawer();
    }

    /* ------------------------------------------------------------ acciones */
    async function recargar(msg) {
        try { await cargar(planta); } catch (e) { aviso(e.message, true); }
        dibujar();
        if (msg) aviso(msg);
    }

    function listaPlanograma(u, sinRep) {
        return (M.posiciones || []).filter(function (x) { return x.u === u && x.rep !== sinRep; })
            .map(function (x) { return { repuesto: x.rep, nivel: x.n, posicion: x.p, fila: x.f }; });
    }
    async function planograma(rep, desde, hacia, nivel) {
        if (desde && desde !== hacia && posBy[desde + '_' + rep])
            await ws('GuardarPosiciones', { ubicacion: desde, lista: JSON.stringify(listaPlanograma(desde, rep)) });
        if (hacia) {
            var l = listaPlanograma(hacia, rep), tenia = !!posBy[hacia + '_' + rep];
            if (nivel > 0) {
                var usado = {};
                l.forEach(function (x) { if (x.nivel === nivel && !x.fila) usado[x.posicion] = 1; });
                var p = 1; while (usado[p] && p < 30) p++;
                l.push({ repuesto: rep, nivel: nivel, posicion: p, fila: 0 });
            }
            if (nivel > 0 || tenia) await ws('GuardarPosiciones', { ubicacion: hacia, lista: JSON.stringify(l) });
        }
    }
    async function mover(rep, b, desde, hacia, nivel) {
        if (!hacia) { aviso('Un repuesto ubicado no vuelve a «sin ubicar».', true); return; }
        var antes = posBy[desde + '_' + rep];
        if (desde === hacia && (antes ? antes.n : 0) === nivel) return;
        try {
            if (desde !== hacia) {
                var r = await ws('ReubicarCaja', { datos: JSON.stringify({ repuesto: rep, bodega: b, origen: desde, destino: hacia }) });
                if (r.parcial) aviso('Se movió una parte: ' + r.detalle, true);
            }
            try { await planograma(rep, desde, hacia, nivel); }
            catch (e) { aviso('El stock se movió, pero el nivel no se guardó: ' + e.message, true); }
            if (sel && sel.rep === rep) sel = { rep: rep, b: b, u: hacia };
            await recargar('Listo: el repuesto quedó en su nueva ubicación.');
        } catch (e) { aviso(e.message, true); dibujar(); }
    }

    async function guardarBodega(id) {
        var f = host.querySelector('[data-formbodega="' + id + '"]'); if (!f) return;
        var v = function (k) { return (f.querySelector('[data-f="' + k + '"]') || {}).value || ''; };
        var d = { id: id, planta: parseInt(v('planta'), 10), nombre: v('nombre').trim(), descripcion: v('descripcion').trim() };
        if (id) d.codigo = (bodega(id) || {}).codigo;
        if (v('metodo')) d.metodo = v('metodo');
        if (!d.nombre) { aviso('Escribe el nombre de la bodega.', true); return; }
        try {
            var r = await ws('GuardarBodega', { datos: JSON.stringify(d) });
            forms.bodega = null; forms.editar = null;
            if (d.planta && d.planta !== planta) planta = d.planta;
            await recargar(id ? 'Bodega actualizada.' : 'Bodega creada.');
        } catch (e) { aviso(e.message, true); }
    }
    async function guardarUbic(bId) {
        var f = host.querySelector('[data-formubic="' + bId + '"]'); if (!f) return;
        var v = function (k) { return (f.querySelector('[data-f="' + k + '"]') || {}).value || ''; };
        var codigo = v('codigo').trim(); if (!codigo) { aviso('Escribe el código de la ubicación.', true); return; }
        try {
            await ws('GuardarUbicacion', { datos: JSON.stringify({ bodega: bId, codigo: codigo, nombre: v('nombre').trim() }) });
            forms.ubic = null;
            await recargar('Ubicación creada.');
        } catch (e) { aviso(e.message, true); }
    }

    /* ------------------------------------------------------------ eventos */
    function ligar() {
        if (host.dataset.listo) return;
        host.dataset.listo = '1';
        host.addEventListener('click', async function (e) {
            var t = e.target; if (!t.closest) return;
            var c;
            if ((c = t.closest('[data-cerrar-dr]'))) { sel = null; dibujar(); return; }
            if ((c = t.closest('[data-nueva-bod]'))) { forms.bodega = true; forms.editar = null; forms.ubic = null; dibujar(); return; }
            if ((c = t.closest('[data-editar-bod]'))) { forms.editar = parseInt(c.dataset.editarBod, 10); forms.bodega = null; forms.ubic = null; dibujar(); return; }
            if ((c = t.closest('[data-nueva-ubic]'))) { forms.ubic = parseInt(c.dataset.nuevaUbic, 10); forms.bodega = null; forms.editar = null; dibujar(); return; }
            if ((c = t.closest('[data-cancelar]'))) { forms = { bodega: null, ubic: null, editar: null }; dibujar(); return; }
            if ((c = t.closest('[data-guardarbodega]'))) { guardarBodega(parseInt(c.dataset.guardarbodega, 10)); return; }
            if ((c = t.closest('[data-guardarubic]'))) { guardarUbic(parseInt(c.dataset.guardarubic, 10)); return; }
            if ((c = t.closest('[data-delubic]'))) {
                if (!confirm('¿Eliminar esta ubicación vacía?')) return;
                try { await ws('EliminarUbicacion', { id: parseInt(c.dataset.delubic, 10) }); await recargar('Ubicación eliminada.'); } catch (x) { aviso(x.message, true); }
                return;
            }
            if ((c = t.closest('[data-mover-dr]'))) {
                var u1 = parseInt(document.getElementById('rmUb').value, 10), n1 = parseInt(document.getElementById('rmNv').value, 10);
                mover(sel.rep, sel.b, sel.u, u1, n1); return;
            }
            if ((c = t.closest('[data-ir-rep]'))) { var a = c.dataset.irRep.split('|'); sel = { rep: +a[0], b: +a[1], u: +a[2] }; dibujar(); return; }
            if ((c = t.closest('[data-ficha-dr]'))) { if (OPT.abrirFicha) OPT.abrirFicha(c.dataset.fichaDr); return; }
            if ((c = t.closest('[data-etiqueta-dr]'))) {
                try { var r = await ws('UrlEtiquetas', { origen: 'REPUESTO', ids: c.dataset.etiquetaDr, bodega: 0, simbolo: '' }); window.open(r.url, 'sigmaEtiquetas', 'width=980,height=760,resizable=yes,scrollbars=yes'); }
                catch (x) { aviso(x.message, true); }
                return;
            }
            if ((c = t.closest('.rm-chip'))) { sel = { rep: +c.dataset.rep, b: +c.dataset.b, u: +c.dataset.u }; dibujar(); return; }
        });
        host.addEventListener('change', function (e) {
            if (e.target.id === 'rmPlanta') { planta = parseInt(e.target.value, 10); forms = { bodega: null, ubic: null, editar: null }; sel = null; recargar(); }
        });
        host.addEventListener('keydown', function (e) { if (e.key === 'Escape' && sel) { sel = null; dibujar(); } });

        /* Arrastrar y soltar */
        host.addEventListener('dragstart', function (e) {
            var c = e.target.closest && e.target.closest('.rm-chip'); if (!c) return;
            var s = saldos.filter(function (x) { return x.id === +c.dataset.rep && x.b === +c.dataset.b && x.u === +c.dataset.u; })[0];
            var p = s ? posBy[s.u + '_' + s.id] : null;
            drag = { rep: +c.dataset.rep, b: +c.dataset.b, u: +c.dataset.u, n: p ? p.n : 0 };
            e.dataTransfer.effectAllowed = 'move';
            try { e.dataTransfer.setData('text/plain', String(drag.rep)); } catch (x) { }
            c.classList.add('is-drag');
            host.classList.add('es-arrastrando');
        });
        host.addEventListener('dragend', function () {
            drag = null; host.classList.remove('es-arrastrando');
            [].forEach.call(host.querySelectorAll('.is-drag,.is-over'), function (x) { x.classList.remove('is-drag', 'is-over'); });
        });
        host.addEventListener('dragover', function (e) {
            var z = e.target.closest && e.target.closest('.rm-niv'); if (!z || !drag) return;
            if (+z.dataset.b !== drag.b) return;      // solo dentro de su bodega
            e.preventDefault(); e.dataTransfer.dropEffect = 'move';
            [].forEach.call(host.querySelectorAll('.is-over'), function (x) { if (x !== z) x.classList.remove('is-over'); });
            z.classList.add('is-over');
        });
        host.addEventListener('drop', function (e) {
            var z = e.target.closest && e.target.closest('.rm-niv'); if (!drag) return;
            if (!z) return;
            e.preventDefault();
            var d = drag; drag = null;
            if (+z.dataset.b !== d.b) { aviso('Cambiar de bodega es un traslado: regístralo en Movimientos.', true); return; }
            mover(d.rep, d.b, d.u, +z.dataset.u, +z.dataset.n);
        });
        document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && sel && host.isConnected) { sel = null; dibujar(); } });
    }

    window.RcMapa = {
        /* host: el contenedor; opts: {q, abrirFicha(id)}. La primera vez trae los datos; despues solo redibuja. */
        pintar: async function (el, opts) {
            host = el; OPT = opts || {};
            ligar();
            if (!M) {
                host.innerHTML = '<div class="rm-cargando"><span></span><span></span><span></span>Cargando el mapa de ubicaciones…</div>';
                try { await cargar(0); } catch (e) { host.innerHTML = '<div class="rm-vacio">' + svg(IC.alerta, 30) + '<b>No se pudo cargar el mapa</b><span>' + esc(e.message) + '</span></div>'; return; }
            }
            dibujar();
        },
        invalidar: function () { M = null; }
    };
})();
