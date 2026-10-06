/* ============================================================================
   SIGMA · COMBO CON BÚSQUEDA (compartido, 05-10-2026)

   Antes había dos: «af-combo» en el asistente (sigma-asistente.js) y
   «sa-combo» en la planta (sigma-planta.js). Este es uno solo, con el
   comportamiento del de la planta:
     - busca mientras se escribe (sin distinguir mayúsculas ni tildes) y
       marca lo que coincide;
     - ofrece «Crear "lo escrito"» solo si se permite y no existe ya;
     - cada opción puede traer foto (img) y una línea secundaria (sub);
     - teclado completo: flechas, Enter, Tab y Escape.

   DOS MODOS
     Con id (por defecto): el valor va en un input oculto con el name del
       campo: el id elegido, el texto (o.texto) o «nuevo:texto» si se crea.
     Libre (o.libre): el texto ES el valor. El input visible lleva el name y
       lo que no existe se crea al guardar. Es el del asistente: el servidor
       lee Request.Form[name] como siempre.

   USO
     SigmaCombo.html(nombre, lista, sel, o) -> el HTML del campo.
       lista: [{id, n, txt?, sub?, img?}] o ['texto', ...]
       o: { ph, req, crear, texto, libre, vacio, clave, fuente, etiqueta, clase, id }
         clave  : nombre de la definición (por defecto, el nombre del campo).
                  Varias filas con el mismo campo comparten la clave.
         fuente : función que devuelve la lista al abrir (listas que cambian).
     SigmaCombo.definir(clave, def) -> registrar opciones para un HTML fijo.
     SigmaCombo.salir(input)        -> fijar el valor de lo escrito (antes de validar).

   Va envuelto en una función: sigma-planta.js declara `esc` y `norm` como
   const globales y un segundo `const esc` rompería la página.
   ========================================================================= */
(function () {
    'use strict';

    var DEFS = {};
    var CB = { inp: null, act: -1, ops: [] };
    var FLECHA = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>';
    var MAS = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>';

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }
    function norm(s) { return String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim(); }
    function txt(v) { return v == null ? '' : String(v); }

    function items(def) {
        var l = def.fuente ? def.fuente() : def.items;
        return (l || []).map(function (x) { return typeof x === 'string' ? { id: x, n: x } : x; });
    }
    function oculto(inp) { return inp.parentNode.querySelector('input[type=hidden]'); }
    function defDe(inp) { return inp && inp.dataset ? DEFS[inp.dataset.sgcombo] : null; }

    function definir(clave, d) {
        d = d || {};
        DEFS[clave] = {
            items: d.items || null, fuente: d.fuente || null,
            libre: !!d.libre, crear: !!(d.libre || d.crear), texto: !!(d.libre || d.texto),
            vacio: d.vacio || (d.libre ? 'Escribe para crear uno nuevo.' : 'Sin coincidencias')
        };
        return DEFS[clave];
    }

    function html(nombre, lista, sel, o) {
        o = o || {};
        var clave = o.clave || nombre;
        var def = definir(clave, { items: lista, fuente: o.fuente, libre: o.libre, crear: o.crear, texto: o.texto, vacio: o.vacio });
        var its = items(def);
        var elegido = its.filter(function (x) { return String(x.id) === String(sel); })[0];
        var etiqueta = elegido ? elegido.n : (def.texto ? txt(sel) : '');
        var valor = elegido ? elegido.id : (def.texto ? txt(sel) : '');
        return '<span class="sg-combo"><input type="text" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="sgComboLista"' +
               ' autocomplete="off" spellcheck="false" data-sgcombo="' + esc(clave) + '"' +
               (def.libre ? ' name="' + esc(nombre) + '"' : '') +
               (o.id ? ' id="' + esc(o.id) + '"' : '') +
               (o.clase ? ' class="' + esc(o.clase) + '"' : '') +
               (o.etiqueta ? ' aria-label="' + esc(o.etiqueta) + '"' : '') +
               ' value="' + esc(etiqueta) + '" placeholder="' + esc(o.ph || 'Escribe para buscar') + '"' + (o.req ? ' data-req="1"' : '') + '>' +
               (def.libre ? '' : '<input type="hidden" name="' + esc(nombre) + '" value="' + esc(valor) + '">') +
               '<button type="button" class="sg-combo-btn" tabindex="-1" aria-label="Ver opciones">' + FLECHA + '</button></span>';
    }

    /* La lista va al final del <body>: dentro de un contenedor con transform,
       position:fixed se mide contra el contenedor y no contra la pantalla. */
    function lista() {
        var ul = document.getElementById('sgComboLista');
        if (!ul) {
            ul = document.createElement('ul'); ul.id = 'sgComboLista'; ul.className = 'sg-combo-lista'; ul.setAttribute('role', 'listbox'); ul.hidden = true;
            document.body.appendChild(ul);
            ul.addEventListener('mousedown', function (e) { e.preventDefault(); });
            ul.addEventListener('click', function (e) { var li = e.target.closest('[data-i]'); if (li) elegir(+li.getAttribute('data-i')); });
        }
        return ul;
    }

    function abrir(inp, todo) {
        var def = defDe(inp); if (!def) return;
        CB.inp = inp;
        var ul = lista(), its = items(def);
        var t = inp.value.trim(), q = todo ? '' : norm(t);
        CB.ops = its.filter(function (x) { return !q || norm(x.n + ' ' + (x.txt || '')).indexOf(q) !== -1; }).slice(0, 60)
                    .map(function (x) { return { x: x }; });
        if (def.crear && t && !its.some(function (x) { return norm(x.n) === norm(t); })) CB.ops.push({ crear: t });

        var marca = function (s) {
            s = txt(s); if (!q) return esc(s);
            var i = norm(s).indexOf(q);
            return i < 0 ? esc(s) : esc(s.slice(0, i)) + '<mark>' + esc(s.slice(i, i + q.length)) + '</mark>' + esc(s.slice(i + q.length));
        };
        ul.innerHTML = CB.ops.length ? CB.ops.map(function (op, i) {
            var a = '<li role="option" id="sgCbo' + i + '" data-i="' + i + '"';
            if (op.crear) return a + ' class="is-crear">' + MAS + 'Crear «' + esc(op.crear) + '»</li>';
            if (op.x.sub != null || op.x.img != null)
                return a + ' class="es-rico"><span class="cb-img">' + (op.x.img ? '<img src="' + esc(op.x.img) + '" alt="" loading="lazy">' : '<i></i>') +
                       '</span><span class="cb-t"><b>' + marca(op.x.n) + '</b>' + (op.x.sub ? '<small>' + esc(op.x.sub) + '</small>' : '') + '</span></li>';
            /* En un span: la <li> es flex con gap y, suelto, el <mark>
               quedaba separado del resto de la palabra ("Mot  or"). */
            return a + '><span>' + marca(op.x.n) + '</span></li>';
        }).join('') : '<li class="is-vacio" aria-disabled="true">' + esc(def.vacio) + '</li>';

        /* Queda marcado lo que ya estaba elegido; si no, la primera opción. */
        var hid = oculto(inp), actual = -1;
        CB.ops.forEach(function (op, i) {
            if (actual < 0 && op.x && (hid ? String(op.x.id) === hid.value : norm(op.x.n) === norm(t))) actual = i;
        });
        CB.act = actual >= 0 ? actual : (CB.ops.length ? 0 : -1);
        marcar();

        var r = inp.getBoundingClientRect(), abajo = innerHeight - r.bottom;
        ul.style.left = r.left + 'px'; ul.style.width = Math.max(r.width, 220) + 'px';
        if (abajo < 240 && r.top > abajo) { ul.style.top = ''; ul.style.bottom = (innerHeight - r.top + 4) + 'px'; }
        else { ul.style.bottom = ''; ul.style.top = (r.bottom + 4) + 'px'; }
        ul.hidden = false; inp.setAttribute('aria-expanded', 'true');
    }

    function marcar() {
        var ul = lista();
        Array.prototype.forEach.call(ul.querySelectorAll('[data-i]'), function (li) { li.classList.toggle('is-activo', +li.getAttribute('data-i') === CB.act); });
        var li = ul.querySelector('.is-activo');
        if (li && CB.inp) { li.scrollIntoView({ block: 'nearest' }); CB.inp.setAttribute('aria-activedescendant', li.id); }
    }

    function cerrar() {
        var ul = document.getElementById('sgComboLista'); if (ul) ul.hidden = true;
        if (CB.inp) { CB.inp.setAttribute('aria-expanded', 'false'); CB.inp.removeAttribute('aria-activedescendant'); }
        CB.inp = null; CB.act = -1;
    }

    function elegir(i) {
        var inp = CB.inp, op = CB.ops[i]; if (!inp || !op) return;
        var hid = oculto(inp), def = defDe(inp);
        if (op.crear) { inp.value = op.crear; if (hid) hid.value = def.texto ? op.crear : 'nuevo:' + op.crear; }
        else { inp.value = op.x.n; if (hid) hid.value = op.x.id; }
        inp.classList.toggle('is-nuevo', !!op.crear);
        cerrar();
        inp.dispatchEvent(new Event('change', { bubbles: true }));
    }

    /* Al salir: si lo escrito es una opción, queda elegida (con su forma
       escrita: «motor» pasa a «Motor» y no se crea un duplicado); si no, se
       crea (si se permite) o se vuelve a lo que estaba. */
    function salir(inp) {
        var def = defDe(inp); if (!def) return;
        var hid = oculto(inp), t = inp.value.trim(), its = items(def);
        var igual = its.filter(function (x) { return norm(x.n) === norm(t); })[0];
        if (!t) { inp.value = ''; if (hid) hid.value = ''; inp.classList.remove('is-nuevo'); return; }
        if (igual) { inp.value = igual.n; if (hid) hid.value = igual.id; inp.classList.remove('is-nuevo'); return; }
        if (def.crear) { inp.value = t; if (hid) hid.value = def.texto ? t : 'nuevo:' + t; inp.classList.add('is-nuevo'); return; }
        var prev = hid ? its.filter(function (x) { return String(x.id) === hid.value; })[0] : null;
        inp.value = prev ? prev.n : '';
    }

    function esCombo(el) { return el && el.matches && el.matches('[data-sgcombo]'); }

    document.addEventListener('focusin', function (e) { if (esCombo(e.target)) abrir(e.target, true); });
    document.addEventListener('input', function (e) { if (esCombo(e.target)) abrir(e.target); });
    document.addEventListener('focusout', function (e) {
        if (!esCombo(e.target)) return;
        salir(e.target);
        if (CB.inp === e.target) cerrar();
    });
    document.addEventListener('click', function (e) {
        var b = e.target.closest && e.target.closest('.sg-combo-btn'); if (!b) return;
        var inp = b.parentNode.querySelector('[data-sgcombo]'); if (!inp) return;
        if (CB.inp === inp) cerrar(); else { inp.focus(); abrir(inp, true); }
    });
    /* En captura: Enter y Escape no deben llegar al formulario ni al modal. */
    document.addEventListener('keydown', function (e) {
        if (!esCombo(e.target)) return;
        var ul = document.getElementById('sgComboLista'), abierta = ul && !ul.hidden && CB.inp === e.target;
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
            e.preventDefault();
            if (!abierta) { abrir(e.target, true); return; }
            if (!CB.ops.length) return;
            CB.act = (CB.act + (e.key === 'ArrowDown' ? 1 : -1) + CB.ops.length) % CB.ops.length; marcar();
        } else if (e.key === 'Enter') {
            /* Enter dentro de un combo nunca envía el <form> de la maestra. */
            e.preventDefault();
            if (abierta && CB.act >= 0) { e.stopPropagation(); elegir(CB.act); }
        } else if (e.key === 'Escape' && abierta) { e.preventDefault(); e.stopPropagation(); cerrar(); }
        else if (e.key === 'Tab' && abierta && CB.act >= 0 && e.target.value.trim()) elegir(CB.act);
    }, true);
    window.addEventListener('resize', cerrar);
    document.addEventListener('scroll', function (e) { if (CB.inp && e.target.id !== 'sgComboLista') cerrar(); }, true);

    window.SigmaCombo = { html: html, definir: definir, abrir: abrir, cerrar: cerrar, salir: salir };
})();
