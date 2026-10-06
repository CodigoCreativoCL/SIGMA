/* ============================================================================
   Centro de repuestos · «Ver como» Lista y Tarjetas (06-10-2026)

   El mismo diseño del Centro de activos 360°: los datos los arma el servidor
   en #rcDatos (JSON) y aqui se dibujan las dos vistas. Buscar, agrupar y
   ordenar no van al servidor; la vista elegida se recuerda en el navegador.
   ========================================================================= */
(function () {
    'use strict';

    var VISTA_KEY = 'sigma.repuestos.vista';
    var ST = { vista: 'tarjetas', q: '', grupo: 'none', orden: 'atencion', pag: 1, tam: 24 };
    try { var tg = parseInt(localStorage.getItem('sigma.repuestos.tam'), 10); if (SigmaPaginador.TAMANOS.indexOf(tg) >= 0) ST.tam = tg; } catch (e) { }
    try { var v = localStorage.getItem(VISTA_KEY); if (v === 'lista' || v === 'tarjetas' || v === 'mapa') ST.vista = v; } catch (e) { }

    var AYUDA = {
        tarjetas: 'Cada repuesto con su foto, su existencia y lo que necesita atención.',
        lista: 'Todos los repuestos en filas, para comparar y encontrar rápido.',
        mapa: 'Dónde está cada repuesto: planta, bodega y estante.'
    };

    function $(s, r) { return (r || document).querySelector(s); }
    function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
    function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
    function svg(p, n, w) { return '<svg width="' + (n || 18) + '" height="' + (n || 18) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="' + (w || 1.8) + '" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + p + '</svg>'; }
    var IC = {
        buscar: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
        cam: '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
        alerta: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>',
        ok: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.5"/>',
        flecha: '<path d="M5 12h14M13 6l6 6-6 6"/>',
        lapiz: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
        lupa: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5M11 8v6M8 11h6"/>',
        chev: '<path d="M9 6l6 6-6 6"/>',
        caja: '<path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/>'
    };

    function datos() {
        var el = document.getElementById('rcDatos');
        if (!el) return null;
        try { return JSON.parse(el.textContent || '{}'); } catch (e) { return null; }
    }

    /* El estado del repuesto, de lo mas urgente a lo normal. */
    function estado(x) {
        if (!x.habilitado) return { k: 'off', t: 'Deshabilitado', r: 4 };
        if (x.umbral === 'bajo') return { k: 'bajo', t: 'Bajo el mínimo', r: 0 };
        if (x.stock <= 0) return { k: 'sin', t: 'Sin existencia', r: 1 };
        if (x.umbral === 'sobre') return { k: 'alto', t: 'Sobre el máximo', r: 2 };
        return { k: 'ok', t: 'Con existencia', r: 3 };
    }
    var DOT = { ok: 'var(--success)', bajo: 'var(--danger)', sin: 'var(--warning)', alto: 'var(--warning)', off: 'var(--muted)' };

    function filtrar(items) {
        var q = norm(ST.q);
        if (!q) return items.slice();
        return items.filter(function (x) {
            return norm([x.codigo, x.nombre, x.tipo, x.fabricante, x.modelo].concat(x.compat || []).join(' ')).indexOf(q) >= 0;
        });
    }
    function ordenar(items) {
        var f = {
            atencion: function (a, b) { return estado(a).r - estado(b).r || a.nombre.localeCompare(b.nombre, 'es'); },
            nombre: function (a, b) { return a.nombre.localeCompare(b.nombre, 'es'); },
            mas: function (a, b) { return b.stock - a.stock; },
            menos: function (a, b) { return a.stock - b.stock; }
        }[ST.orden] || function () { return 0; };
        return items.sort(f);
    }
    function agrupar(items) {
        if (ST.grupo === 'none') return [{ t: '', items: items }];
        var m = {}, orden = [];
        items.forEach(function (x) {
            var k = ST.grupo === 'tipo' ? (x.tipo || 'Sin clasificar')
                  : ST.grupo === 'fabricante' ? (x.fabricante || 'Sin fabricante')
                  : estado(x).t;
            if (!m[k]) { m[k] = []; orden.push(k); }
            m[k].push(x);
        });
        orden.sort(function (a, b) { return a.localeCompare(b, 'es'); });
        return orden.map(function (k) { return { t: k, items: m[k] }; });
    }
    function cuenta(n) { return n + ' repuesto' + (n === 1 ? '' : 's'); }

    function sel(id, label, ops, val) {
        return '<label class="rcx-sel">' + label + '<select id="' + id + '">' + ops.map(function (o) {
            return '<option value="' + o[0] + '"' + (o[0] === val ? ' selected' : '') + '>' + o[1] + '</option>';
        }).join('') + '</select></label>';
    }
    function barra() {
        return '<div class="rcx-barra">'
            + '<label class="rcx-q">' + svg(IC.buscar, 20) + '<input class="rcx-qi" aria-label="Buscar repuestos" placeholder="Busca un repuesto por código, nombre, fabricante o equipo…" value="' + esc(ST.q) + '"></label>'
            + sel('rcGrupo', 'Agrupar', [['none', 'Sin agrupar'], ['tipo', 'Tipo de repuesto'], ['estado', 'Existencia'], ['fabricante', 'Fabricante']], ST.grupo)
            + sel('rcOrden', 'Orden', [['atencion', 'Primero los que necesitan atención'], ['nombre', 'Nombre'], ['mas', 'Más existencia'], ['menos', 'Menos existencia']], ST.orden)
            + '</div>';
    }

    /* ---------------- Tarjetas ---------------- */
    function tarjeta(x, puede, D) {
        var e = estado(x);
        var chips = '<span class="rcx-chip es-izq" style="color:' + DOT[e.k] + '"><i style="background:' + DOT[e.k] + '"></i>' + e.t + '</span>'
                  + (x.tipo ? '<span class="rcx-chip es-der" title="' + esc(x.tipo) + '">' + esc(x.tipo) + '</span>' : '');
        /* El estado ya va en el chip de arriba; abajo, solo si controla lote. */
        var aviso = x.lote ? '<span class="rcx-aviso" style="background:var(--sigma-cyan-dark)">Por lote</span>' : '';
        var cover = x.foto
            ? '<div class="rcx-cover" role="img" aria-label="Foto de ' + esc(x.nombre) + '" style="background-image:url(\'' + esc(x.foto) + '\')">' + chips + aviso
              + '<button type="button" class="rcx-lupa" title="Ver las fotos" data-fotos="' + esc((x.fotos && x.fotos.length ? x.fotos : [x.foto]).join('|')) + '" data-titulo="' + esc(x.nombre) + '">' + svg(IC.lupa, 18, 2) + '</button></div>'
            : '<div class="rcx-cover es-vacia">' + svg(IC.cam, 32, 1.6) + '<span>Sin foto' + (puede ? ' · agrégala en Editar' : '') + '</span>' + chips + aviso + '</div>';
        var nota = function (t, c) { return '<em style="color:' + c + '">' + t + '</em>'; };
        var celdas = '<div class="rcx-celdas">'
            + '<div><span style="color:var(--sigma-purple-dark)">Existencia</span><strong>' + esc(x.stockTxt) + '<small>' + esc(x.unidad) + '</small></strong>'
            + (x.stock > 0 ? nota(x.lote ? 'Por lote' : 'Disponible', 'var(--success-ink)') : nota('No hay', 'var(--warning-ink)')) + '</div>'
            + '<div><span style="color:var(--sigma-blue-ink)">Bodegas</span><strong>' + x.bodegas + '</strong>' + nota(x.bodegas ? 'Con saldo' : 'Ninguna', 'var(--muted)') + '</div>'
            + '<div><span style="color:var(--sigma-cyan-dark)">Equipos</span><strong>' + (x.compat || []).length + '</strong>'
            + nota((x.compat || []).length ? esc(x.compat[0]) : 'Sin vincular', 'var(--muted)') + '</div>'
            + '</div>';
        var est = umbrales(x, D);
        var sub = [x.codigo, x.fabricante, x.modelo].filter(function (s) { return s; }).map(esc).join(' · ');
        return '<article class="rcx-card' + (e.k === 'bajo' ? ' es-alerta' : '') + '" data-rc="' + x.id + '" tabindex="0" aria-label="' + esc(x.nombre) + ', ' + e.t + '">'
            + cover
            + '<div class="rcx-cuerpo"><div class="rcx-nom"><strong>' + esc(x.nombre) + '</strong><span>' + sub + '</span></div>' + celdas + est + '</div>'
            + '<div class="rcx-pie"><button type="button" data-rcabrir="' + x.id + '">Abrir ficha' + svg(IC.flecha, 16, 2) + '</button>'
            + (puede ? '<button type="button" class="es-primario" data-rcedit="' + esc(x.q) + '">' + svg(IC.lapiz, 16, 2) + 'Editar</button>' : '')
            + '</div></article>';
    }
    function pintarTarjetas(D) {
        var cont = $('#rcTarjetas'); if (!cont) return;
        if (!$('#rcTBody', cont)) cont.innerHTML = barra() + '<div id="rcTBody"></div>';
        var P = SigmaPaginador.cortar(ordenar(filtrar(D.items)), ST.pag, ST.tam), list = P.items; ST.pag = P.pagina;
        var grid = function (its) { return '<div class="rcx-tgrid">' + its.map(function (x) { return tarjeta(x, D.puedeEditar, D); }).join('') + '</div>'; };
        $('#rcTBody', cont).innerHTML = !list.length ? '<div class="rcx-vacio">No encontramos repuestos con esa búsqueda o filtro.</div>'
            : agrupar(list).map(function (g) {
                return g.t ? '<section class="rcx-grupo"><h3>' + esc(g.t) + '<span>· ' + cuenta(g.items.length) + '</span></h3>' + grid(g.items) + '</section>'
                           : '<div style="margin-top:20px">' + grid(g.items) + '</div>';
            }).join('') + SigmaPaginador.html(P, 'rc', 'repuestos');
    }

    /* ---------------- Lista ---------------- */
    function fila(x) {
        var e = estado(x);
        return '<div class="rcx-fila" data-rc="' + x.id + '" tabindex="0">'
            + '<span class="rcx-mini"' + (x.foto ? ' style="background-image:url(\'' + esc(x.foto) + '\')"' : '') + '>' + (x.foto ? '' : svg(IC.caja, 20)) + '</span>'
            + '<span><b>' + esc(x.nombre) + '</b><small>' + esc(x.codigo) + (x.fabricante ? ' · ' + esc(x.fabricante) : '') + (x.modelo ? ' ' + esc(x.modelo) : '') + '</small></span>'
            + '<span>' + (x.tipo ? '<span class="rcx-pill es-tipo">' + esc(x.tipo) + '</span>' : '<small>Sin clasificar</small>') + '</span>'
            + '<span class="rcx-num">' + esc(x.stockTxt) + '<small>' + esc(x.unidad) + '</small></span>'
            + '<span class="rcx-num">' + x.bodegas + '</span>'
            + '<span><small>' + ((x.compat || []).length ? esc(x.compat.slice(0, 2).join(', ')) + (x.compat.length > 2 ? ' y ' + (x.compat.length - 2) + ' más' : '') : 'Sin vincular') + '</small></span>'
            + '<span><span class="rcx-pill es-' + e.k + '"><i style="background:' + DOT[e.k] + '"></i>' + e.t + '</span></span>'
            + '<span style="color:var(--muted)">' + svg(IC.chev, 18, 2) + '</span></div>';
    }
    function pintarLista(D) {
        var cont = $('#rcLista'); if (!cont) return;
        if (!$('#rcLBody', cont))
            cont.innerHTML = barra() + '<section class="rcx-tabla" aria-label="Repuestos"><div class="rcx-tabla-scroll">'
                + '<div class="rcx-fila es-cab"><span></span><span>Repuesto</span><span>Tipo</span><span>Existencia</span><span>Bodegas</span><span>Sirve en</span><span>Estado</span><span></span></div>'
                + '<div id="rcLBody"></div></div></section><div id="rcLPag"></div>';
        var P = SigmaPaginador.cortar(ordenar(filtrar(D.items)), ST.pag, ST.tam), list = P.items; ST.pag = P.pagina;
        var pie = $('#rcLPag', cont); if (pie) pie.innerHTML = SigmaPaginador.html(P, 'rc', 'repuestos');
        $('#rcLBody', cont).innerHTML = !list.length ? '<div class="rcx-fila es-gcab" style="text-align:center;color:var(--muted)">No encontramos repuestos con esa búsqueda o filtro.</div>'
            : agrupar(list).map(function (g) {
                return (g.t ? '<div class="rcx-fila es-gcab">' + esc(g.t) + ' <span>· ' + cuenta(g.items.length) + '</span></div>' : '') + g.items.map(fila).join('');
            }).join('');
    }


    /* ---------------- Umbrales por bodega (en la tarjeta) ---------------- */
    function nomBodega(D, id) {
        for (var i = 0; i < (D.bodegas || []).length; i++) if (D.bodegas[i].id === id) return D.bodegas[i].nombre;
        return 'Bodega';
    }
    function umbrales(x, D) {
        var ss = (x.saldos || []).filter(function (s) { return s.min != null || s.max != null; });
        if (!ss.length) return '<div class="rcx-umb es-vacio">Sin umbrales: define el mínimo y el máximo por bodega en Editar › Stock.</div>';
        return '<div class="rcx-umb"><span class="rcx-umb-h">Umbrales por bodega</span>' + ss.slice(0, 3).map(function (s) {
            var tope = Math.max(s.max || 0, s.cant, s.min || 0) || 1;
            var k = s.bajo ? 'bajo' : s.sobre ? 'alto' : 'ok';
            return '<div class="rcx-umb-f es-' + k + '"><div class="rcx-umb-t"><b>' + esc(nomBodega(D, s.bodega)) + '</b>'
                + '<span><strong>' + esc(s.cantTxt) + '</strong> · mín ' + (s.min != null ? s.min : '—') + ' · máx ' + (s.max != null ? s.max : '—') + '</span></div>'
                + '<div class="rcx-umb-bar"><i style="width:' + Math.min(100, s.cant / tope * 100) + '%"></i>'
                + (s.min != null ? '<em style="left:' + Math.min(100, s.min / tope * 100) + '%" title="Mínimo"></em>' : '')
                + (s.max != null ? '<em class="es-max" style="left:' + Math.min(100, s.max / tope * 100) + '%" title="Máximo"></em>' : '')
                + '</div></div>';
        }).join('') + (ss.length > 3 ? '<small>y ' + (ss.length - 3) + ' bodegas más</small>' : '') + '</div>';
    }

    /* ---------------- Mapa por ubicación ----------------
       Lo dibuja Js/sigma-repuesto-mapa.js con WsBodegaMapa (el mismo servicio
       de SIGMA Twin): arrastrar mueve el stock de verdad. Aqui solo se le da
       el contenedor y la busqueda. */
    function pintarMapa(D) {
        var cont = $('#rcMapa'); if (!cont) return;
        if (!$('#rcMBody', cont)) cont.innerHTML = '<div id="rcMBody"></div>';
        if (window.RcMapa) RcMapa.pintar($('#rcMBody', cont), { abrirFicha: abrir, planta: D.planta || 0, urlTwin: D.urlTwin || '#' });
    }

    /* ---------------- vista ---------------- */
    function pintar() {
        var D = datos(); if (!D) return;
        document.querySelectorAll('[data-rcview]').forEach(function (b) { b.setAttribute('aria-pressed', String(b.getAttribute('data-rcview') === ST.vista)); });
        var l = $('#rcLista'), t = $('#rcTarjetas'), h = $('#rcViewHelp'), m = $('#rcMapa');
        if (l) l.hidden = ST.vista !== 'lista';
        if (m) m.hidden = ST.vista !== 'mapa';
        if (t) t.hidden = ST.vista !== 'tarjetas';
        if (h) h.textContent = AYUDA[ST.vista];
        if (ST.vista === 'lista') pintarLista(D); else if (ST.vista === 'mapa') pintarMapa(D); else pintarTarjetas(D);
    }
    function abrir(id) { if (window.abrirCentroRepuesto) abrirCentroRepuesto(id); }
    function menu(abrirlo) {
        var m = $('#rcMenuIO'), b = $('#rcBtnIO'); if (!m || !b) return;
        var a = abrirlo != null ? abrirlo : m.hidden;
        m.hidden = !a; b.setAttribute('aria-expanded', String(a));
    }

    document.addEventListener('click', function (e) {
        var t = e.target;
        if (!t.closest) return;
        if (t.closest('#rcBtnIO')) { menu(); return; }
        if (!t.closest('.rcx .menu-wrap')) menu(false);
        var fb = t.closest('#rcBtnFiltros');
        if (fb) { var f = $('#rcFiltros'); f.hidden = !f.hidden; fb.setAttribute('aria-expanded', String(!f.hidden)); try { sessionStorage.setItem('sigma.repuestos.filtros', f.hidden ? '0' : '1'); } catch (x) { } return; }
        var vb = t.closest('[data-rcview]');
        if (vb) { ST.vista = vb.getAttribute('data-rcview'); try { localStorage.setItem(VISTA_KEY, ST.vista); } catch (x) { } pintar(); return; }
        var lupa = t.closest('.rcx-lupa');
        if (lupa) { e.preventDefault(); if (window.rcVisor) rcVisor(lupa); return; }
        var ed = t.closest('[data-rcedit]');
        if (ed) { e.preventDefault(); if (window.abrirRepuesto) abrirRepuesto(ed.getAttribute('data-rcedit')); return; }
        var ab = t.closest('[data-rcabrir]');
        if (ab) { abrir(ab.getAttribute('data-rcabrir')); return; }
        var card = t.closest('[data-rc]');
        if (card && !t.closest('a, input, select, label')) abrir(card.getAttribute('data-rc'));
    });
    document.addEventListener('keydown', function (e) {
        var t = e.target;
        if (e.key === 'Escape') { menu(false); return; }
        if ((e.key === 'Enter' || e.key === ' ') && t.getAttribute && t.getAttribute('data-rc') && t === document.activeElement) { e.preventDefault(); abrir(t.getAttribute('data-rc')); }
    });
    document.addEventListener('input', function (e) {
        if (e.target.classList && e.target.classList.contains('rcx-qi')) {
            ST.q = e.target.value.trim(); ST.pag = 1;
            var D = datos(); if (!D) return;
            if (ST.vista === 'lista') pintarLista(D); else if (ST.vista === 'mapa') pintarMapa(D); else pintarTarjetas(D);
        }
    });
    document.addEventListener('change', function (e) {
        if (e.target.id === 'rcGrupo') { ST.grupo = e.target.value; ST.pag = 1; pintar(); }
        else if (e.target.id === 'rcOrden') { ST.orden = e.target.value; ST.pag = 1; pintar(); }
    });

    SigmaPaginador.escuchar('rc', function (pag, tam) {
        if (tam) { ST.tam = tam; try { localStorage.setItem('sigma.repuestos.tam', tam); } catch (x) { } }
        ST.pag = pag; pintar();
        var p = $('.rcx .viewbar'); if (p && p.getBoundingClientRect().top < 0) p.scrollIntoView({ block: 'start', behavior: 'smooth' });
    });


    /* ---------------- Pestañas: Tipos y Bodegas dentro del centro ----------------
       Los mismos catalogos del Centro de activos (.sa-cat): titulo, buscador,
       «+ Nuevo» y una fila por registro. Crear y editar es EN LA MISMA FILA,
       sin modal: «+ Nuevo» abre una fila de formulario arriba y «Editar»
       convierte la fila en formulario. */
    var TAB_KEY = 'sigma.repuestos.tab';
    var TAB = 'repuestos';
    var EDIT = null;                      // {k, id}: la fila que se esta creando (id 0) o editando
    try { var tb = sessionStorage.getItem(TAB_KEY); if (tb === 'tipos' || tb === 'bodegas') TAB = tb; } catch (e) { }

    var WS_REP = (function () {
        var sc = document.querySelector('script[src*="sigma-repuesto-centro.js"]');
        return (sc ? sc.getAttribute('src').split('/Js/')[0] : '') + '/WebService/';
    })();
    async function wsPost(servicio, metodo, datos) {
        var r = await fetch(WS_REP + servicio + '.asmx/' + metodo, {
            method: 'POST', credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify(datos || {})
        });
        if (!r.ok) throw new Error('El servidor respondió ' + r.status + '.');
        var d = JSON.parse((await r.json()).d);
        if (d.error) throw new Error(d.detalle || 'No se pudo completar la operación.');
        return d;
    }
    function aviso(texto, error) {
        var t = document.createElement('div');
        t.className = 'rm-toast' + (error ? ' es-error' : '');
        t.innerHTML = '<span>' + esc(texto) + '</span>';
        document.body.appendChild(t);
        setTimeout(function () { t.classList.add('es-fuera'); setTimeout(function () { t.remove(); }, 400); }, error ? 6500 : 3200);
    }
    var campo = function (k, lbl, val, o) {
        o = o || {};
        return '<label>' + lbl + '<input type="' + (o.tipo || 'text') + '" data-f="' + k + '" value="' + esc(val == null ? '' : val) + '" maxlength="' + (o.max || 400) + '"' + (o.ph ? ' placeholder="' + esc(o.ph) + '"' : '') + (o.ro ? ' readonly' : '') + '></label>';
    };

    var CATS = {
        tipos: {
            host: '#rcCatTipos', titulo: 'Tipos de repuesto', nuevo: 'Nuevo tipo', servicio: 'WsRepuestoCentro',
            ayuda: 'Agrupan los repuestos en el listado. Un repuesto sin tipo queda «Sin clasificar».',
            buscar: 'Busca un tipo…', cols: 'minmax(220px,2fr) minmax(200px,2fr) 110px 190px',
            cab: ['Tipo', 'Descripción', 'Repuestos', ''],
            puede: function (D) { return D.puedeEditar; },
            fila: function (x) {
                return '<span class="sa-cat-dos"><b>' + esc(x.nombre) + '</b><small>' + esc(x.codigo) + '</small></span>'
                    + '<span style="color:var(--muted);font-size:13px">' + (esc(x.descripcion) || '—') + '</span>'
                    + '<span class="sa-cat-num">' + x.repuestos + '</span>';
            },
            form: function (x, D) {
                return campo('nombre', 'Nombre *', x.nombre, { ph: 'Ej.: Rodamientos' })
                    + campo('descripcion', 'Descripción', x.descripcion, { ph: 'Qué reúne este tipo' })
                    + campo('orden', 'Orden', x.orden || '', { tipo: 'number', max: 4, ph: '0' })
                    + (x.id ? campo('codigo', 'Código', x.codigo, { ro: true }) : '');
            },
            guardar: async function (x, v) {
                if (!v.nombre.trim()) throw new Error('Escribe el nombre del tipo.');
                return wsPost('WsRepuestoCentro', 'GuardarTipo', { datos: JSON.stringify({ id: x.id || 0, nombre: v.nombre, descripcion: v.descripcion, orden: v.orden }) });
            },
            quitar: function (x) { return wsPost('WsRepuestoCentro', 'EliminarTipo', { id: x.id }); }
        },
        bodegas: {
            host: '#rcCatBodegas', titulo: 'Bodegas', nuevo: 'Nueva bodega', servicio: 'WsBodegaMapa',
            ayuda: 'Dónde se guardan los repuestos. Las ubicaciones (racks) se crean y se reubican en «Mapa por ubicación».',
            buscar: 'Busca una bodega o una planta…', cols: 'minmax(220px,2fr) minmax(160px,1.4fr) 110px 130px 190px',
            cab: ['Bodega', 'Planta', 'Ubicaciones', 'Con saldo', ''],
            puede: function (D) { return D.puedeBodegas; },
            fila: function (x) {
                return '<span class="sa-cat-dos"><b>' + esc(x.nombre) + '</b><small>' + esc(x.codigo) + '</small></span>'
                    + '<span>' + (esc(x.planta) || '—') + '</span>'
                    + '<span class="sa-cat-num">' + x.ubicaciones + '</span>'
                    + '<span class="sa-cat-num">' + x.repuestos + '</span>';
            },
            form: function (x, D) {
                var pl = (D.plantas || []).map(function (p) { return '<option value="' + p.id + '"' + (p.id === (x.plantaId || (D.plantas[0] || {}).id) ? ' selected' : '') + '>' + esc(p.nombre) + '</option>'; }).join('');
                var met = [['', 'Según la configuración'], ['FEFO', 'FEFO · vence primero'], ['FIFO', 'FIFO · entró primero'], ['LIFO', 'LIFO · entró último']]
                    .map(function (o) { return '<option value="' + o[0] + '">' + o[1] + '</option>'; }).join('');
                return campo('nombre', 'Nombre *', x.nombre, { ph: 'Ej.: Bodega central' })
                    + '<label>Planta *<select data-f="planta">' + pl + '</select></label>'
                    + campo('descripcion', 'Descripción', x.descripcion, { ph: 'Para qué se usa' })
                    + '<label>Método de salida<select data-f="metodo">' + met + '</select></label>'
                    + (x.id ? '' : '<div class="rcx-inline-sep"><b>Ubicaciones iniciales</b><small>Opcional · crea los primeros racks junto con la bodega. El código sale solo (PREFIJO-PASILLO-R01) y los niveles se pueden cambiar después en el mapa.</small></div>'
                        + campo('pasillo', 'Pasillo (1 a 3 letras)', '', { ph: 'Ej.: A', max: 3 })
                        + campo('cantidad', 'Cuántos racks', 1, { tipo: 'number', max: 2, ph: '1' })
                        + campo('niveles', 'Niveles por rack', 4, { tipo: 'number', max: 2, ph: '4' })
                        + campo('ubinombre', 'Nombre del rack (si es uno solo)', '', { ph: 'Vacío: «Pasillo A · Rack 01»' }));
            },
            guardar: async function (x, v) {
                if (!v.nombre.trim()) throw new Error('Escribe el nombre de la bodega.');
                var pas = (v.pasillo || '').trim().toUpperCase();
                if (!x.id && pas && !/^[A-Z]{1,3}$/.test(pas)) throw new Error('El pasillo son de 1 a 3 letras (A, B, AB).');
                var d = { id: x.id || 0, planta: parseInt(v.planta, 10), nombre: v.nombre.trim(), descripcion: v.descripcion };
                if (v.metodo) d.metodo = v.metodo;
                if (x.id) d.codigo = x.codigo;
                var r = await wsPost('WsBodegaMapa', 'GuardarBodega', { datos: JSON.stringify(d) });
                if (!x.id && pas && r.id > 0) {
                    try {
                        await wsPost('WsBodegaMapa', 'CrearRacks', { datos: JSON.stringify({ bodega: r.id, pasillo: pas, cantidad: +v.cantidad || 1, niveles: +v.niveles || 4, nombre: (v.ubinombre || '').trim() }) });
                    } catch (e) { throw new Error('La bodega se creó, pero no sus ubicaciones: ' + e.message); }
                }
                return r;
            }
        }
    };

    function filaForm(k, x, D) {
        var c = CATS[k];
        return '<div class="sa-cat-fila is-form rcx-inline" data-rcform="' + k + '" data-id="' + (x.id || 0) + '"><div class="rcx-inline-c">' + c.form(x, D) + '</div>'
            + '<span class="rcx-inline-acc">' + (x.id && c.quitar ? '<button type="button" class="btn btn--sm btn--borrar" data-rcquitar="' + k + '|' + x.id + '">Quitar</button>' : '')
            + '<button type="button" class="btn btn--ghost" data-rccancelar="1">Cancelar</button>'
            + '<button type="button" class="btn btn--primary" data-rcguardar="' + k + '">' + (x.id ? 'Guardar cambios' : 'Crear') + '</button></span></div>';
    }
    function pintarCat(k, D) {
        var c = CATS[k], host = $(c.host); if (!host) return;
        if (!host.querySelector('.sa-cat-lista')) {
            host.innerHTML = '<div class="sa-cat-bar"><div class="sa-cat-tit"><h2>' + c.titulo + '</h2><p>' + c.ayuda + '</p></div>'
                + '<label class="sa-cat-buscar">' + svg(IC.buscar, 18) + '<input type="search" data-rccat="' + k + '" placeholder="' + c.buscar + '" aria-label="' + c.buscar + '" autocomplete="off"></label>'
                + (c.puede(D) ? '<button type="button" class="btn btn--primary" data-rccatnuevo="' + k + '">+ ' + c.nuevo + '</button>' : '')
                + '</div><div class="sa-cat-lista" style="margin-top:14px"></div>';
        }
        var q = norm((host.querySelector('input[type=search]') || {}).value || '');
        var filas = (D[k] || []).filter(function (x) { return !q || norm(JSON.stringify(x)).indexOf(q) >= 0; });
        var lista = host.querySelector('.sa-cat-lista');
        lista.style.setProperty('--cols', c.cols);
        var nuevoForm = EDIT && EDIT.k === k && EDIT.id === 0 ? filaForm(k, {}, D) : '';
        lista.innerHTML = (!filas.length && !nuevoForm)
            ? '<p class="sa-cat-vacio"><b>' + (q ? 'Nada coincide con esa búsqueda' : 'Todavía no hay registros') + '</b></p>'
            : nuevoForm + '<div class="sa-cat-cab">' + c.cab.map(function (h) { return '<span>' + h + '</span>'; }).join('') + '</div>'
              + filas.map(function (x) {
                  if (EDIT && EDIT.k === k && EDIT.id === x.id) return filaForm(k, x, D);
                  return '<div class="sa-cat-fila">' + c.fila(x) + '<span class="sa-cat-acc">'
                      + (c.puede(D) ? '<button type="button" class="btn btn--sm" data-rccatedit="' + k + '|' + x.id + '">Editar</button>' : '')
                      + '</span></div>';
              }).join('');
        var f = lista.querySelector('.rcx-inline input'); if (f && EDIT) f.focus();
    }
    function pestana(k) {
        TAB = k;
        try { sessionStorage.setItem(TAB_KEY, k); } catch (e) { }
        document.querySelectorAll('[data-rctab]').forEach(function (b) {
            var on = b.getAttribute('data-rctab') === k;
            b.setAttribute('aria-selected', String(on));
            if (on) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current');
        });
        document.querySelectorAll('[data-rcpanel]').forEach(function (p) { p.hidden = p.getAttribute('data-rcpanel') !== k; });
        var D = datos(); if (!D) return;
        if (CATS[k]) pintarCat(k, D);
        else if (k === 'repuestos' && ST.vista === 'mapa') pintar();
    }
    function buscarFila(k, id) { var D = datos(); return D ? (D[k] || []).filter(function (x) { return x.id === id; })[0] : null; }
    document.addEventListener('click', async function (e) {
        var t = e.target; if (!t.closest) return;
        var c;
        if ((c = t.closest('[data-rctab]'))) { EDIT = null; pestana(c.getAttribute('data-rctab')); return; }
        if ((c = t.closest('[data-rccatnuevo]'))) { EDIT = { k: c.getAttribute('data-rccatnuevo'), id: 0 }; pintarCat(EDIT.k, datos()); return; }
        if ((c = t.closest('[data-rccatedit]'))) { var a = c.getAttribute('data-rccatedit').split('|'); EDIT = { k: a[0], id: +a[1] }; pintarCat(a[0], datos()); return; }
        if ((c = t.closest('[data-rccancelar]'))) { var k0 = EDIT && EDIT.k; EDIT = null; if (k0) pintarCat(k0, datos()); return; }
        if ((c = t.closest('[data-rcguardar]'))) {
            var k = c.getAttribute('data-rcguardar'), f = c.closest('[data-rcform]'), D = datos();
            var v = {}; [].forEach.call(f.querySelectorAll('[data-f]'), function (i) { v[i.getAttribute('data-f')] = i.value; });
            var id = +f.getAttribute('data-id'), x = id ? buscarFila(k, id) : {};
            c.disabled = true;
            try { await CATS[k].guardar(x || {}, v); aviso(id ? 'Cambios guardados.' : 'Creado.'); EDIT = null; if (window.refresh) refresh(); }
            catch (err) { aviso(err.message, true); c.disabled = false; }
            return;
        }
        if ((c = t.closest('[data-rcquitar]'))) {
            var p = c.getAttribute('data-rcquitar').split('|'), kk = p[0], xx = buscarFila(kk, +p[1]);
            if (!xx || !confirm('¿Quitar «' + xx.nombre + '»?')) return;
            try { await CATS[kk].quitar(xx); aviso('Quitado.'); EDIT = null; if (window.refresh) refresh(); }
            catch (err) { aviso(err.message, true); }
        }
    });
    document.addEventListener('keydown', function (e) {
        if (!EDIT) return;
        if (e.key === 'Escape') { var k0 = EDIT.k; EDIT = null; pintarCat(k0, datos()); }
        else if (e.key === 'Enter' && e.target.matches && e.target.matches('.rcx-inline input')) {
            e.preventDefault(); var b = document.querySelector('[data-rcguardar]'); if (b) b.click();
        }
    });
    document.addEventListener('input', function (e) {
        var k = e.target.getAttribute && e.target.getAttribute('data-rccat');
        if (k) { var D = datos(); if (D) pintarCat(k, D); }
    });

    /* Tras cada postback parcial el UpdatePanel repinta el bloque: se vuelve a dibujar. */
    function iniciar() {
        try { if (sessionStorage.getItem('sigma.repuestos.filtros') === '1') { var f = $('#rcFiltros'); if (f) { f.hidden = false; var b = $('#rcBtnFiltros'); if (b) b.setAttribute('aria-expanded', 'true'); } } } catch (x) { }
        pintar();
        pestana(TAB);
    }
    window.addEventListener('load', function () {
        iniciar();
        if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(iniciar);
    });
})();
