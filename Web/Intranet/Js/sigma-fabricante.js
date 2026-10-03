/* =============================================================================
   SIGMA · Fabricante y modelo del repuesto (bloque 333)
   -----------------------------------------------------------------------------
   Combo con buscador que ofrece lo que ya existe y deja escribir lo nuevo, con
   el modelo en cascada bajo su fabricante. Lo usa el formulario del mapa 3D;
   la ficha web (Repuesto.aspx) usa el RadComboBox2 de SIGMA y de aqui solo
   toma clave() para comparar igual.

     - Lista propia (no el datalist del navegador): se ve como el resto de
       SIGMA, filtra por "contiene" sin mayusculas ni acentos y se maneja con
       flechas, Enter y Esc.
     - "fleetguard", "FLEETGUARD " o "Fléetguard" se corrigen a la forma del
       catalogo ("Fleetguard") al salir: no nacen duplicados.
     - Lo que no existe aparece como "Usar «X» · nuevo" y se avisa que se
       agrega al guardar. El alta la hace el trigger de la base
       (TRG_REPUESTO_FABRICANTE): la misma regla para web, mapa, carga
       masiva y API.

   Uso:  SigmaFabricante.enlazar(inputFabricante, inputModelo, catalogo, avisoEl)
         catalogo = [{ nombre, repuestos, modelos: [..] }]
   ============================================================================= */
(function (w) {
    'use strict';

    function clave(t) {
        return String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '')
            .replace(/\s+/g, ' ').trim().toLowerCase();
    }
    function limpio(t) { return String(t || '').replace(/\s+/g, ' ').trim(); }
    function esc(t) {
        return String(t).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; });
    }
    function resaltar(texto, q) {
        if (!q) return esc(texto);
        var k = clave(texto), i = k.indexOf(q);
        if (i < 0) return esc(texto);
        return esc(texto.slice(0, i)) + '<mark>' + esc(texto.slice(i, i + q.length)) + '</mark>' + esc(texto.slice(i + q.length));
    }

    /* Un combo sobre un input: opciones() devuelve [{ valor, nota }]. */
    function combo(input, opciones, alElegir) {
        var caja = document.createElement('div');
        caja.className = 'sg-combo';
        input.parentNode.insertBefore(caja, input);
        caja.appendChild(input);
        input.classList.add('sg-combo-in');
        input.setAttribute('autocomplete', 'off');
        input.setAttribute('role', 'combobox');
        var flecha = document.createElement('i');
        flecha.className = 'mdi mdi-chevron-down sg-combo-flecha';
        caja.appendChild(flecha);
        var lista = document.createElement('div');
        lista.className = 'sg-combo-lista';
        lista.setAttribute('role', 'listbox');
        lista.hidden = true;
        caja.appendChild(lista);

        var items = [], foco = -1;

        function pintar() {
            var q = clave(input.value), todas = opciones();
            var filtradas = todas.filter(function (o) { return !q || clave(o.valor).indexOf(q) >= 0; }).slice(0, 60);
            var exacta = todas.some(function (o) { return clave(o.valor) === q; });
            items = filtradas.map(function (o) { return { valor: o.valor, nota: o.nota, nuevo: false }; });
            if (q && !exacta) items.push({ valor: limpio(input.value), nuevo: true });
            foco = items.length ? 0 : -1;
            if (!items.length) {
                lista.innerHTML = '<div class="sg-combo-vacio">' + (todas.length ? 'Sin coincidencias' : 'Escriba para agregar el primero') + '</div>';
                return;
            }
            lista.innerHTML = items.map(function (it, i) {
                return '<div class="sg-combo-op' + (it.nuevo ? ' es-nuevo' : '') + (i === foco ? ' is-foco' : '') + '" data-i="' + i + '" role="option">' +
                    (it.nuevo ? '<i class="mdi mdi-plus-circle-outline"></i><span>Usar «' + esc(it.valor) + '»</span><small>nuevo</small>'
                              : '<span>' + resaltar(it.valor, q) + '</span>' + (it.nota ? '<small>' + esc(it.nota) + '</small>' : '')) +
                    '</div>';
            }).join('');
        }
        function marcar() {
            var ops = lista.querySelectorAll('.sg-combo-op');
            for (var i = 0; i < ops.length; i++) ops[i].classList.toggle('is-foco', i === foco);
            if (ops[foco]) ops[foco].scrollIntoView({ block: 'nearest' });
        }
        function abrir() { pintar(); lista.hidden = false; caja.classList.add('is-abierto'); }
        function cerrar() { lista.hidden = true; caja.classList.remove('is-abierto'); }
        function elegir(i) {
            var it = items[i]; if (!it) return;
            input.value = it.valor;
            cerrar();
            alElegir();
        }

        input.addEventListener('focus', abrir);
        input.addEventListener('input', abrir);
        flecha.addEventListener('mousedown', function (e) { e.preventDefault(); if (lista.hidden) { input.focus(); abrir(); } else cerrar(); });
        lista.addEventListener('mousedown', function (e) {
            e.preventDefault();   // que el input no pierda el foco antes del clic
            var op = e.target.closest('.sg-combo-op');
            if (op) elegir(+op.getAttribute('data-i'));
        });
        input.addEventListener('keydown', function (e) {
            if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
                if (lista.hidden) abrir();
                else if (items.length) { foco = (foco + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length; marcar(); }
                e.preventDefault(); e.stopPropagation();
            } else if (e.key === 'Enter') {
                if (!lista.hidden && foco >= 0) { elegir(foco); e.preventDefault(); }
                e.stopPropagation();
            } else if (e.key === 'Escape') {
                if (!lista.hidden) { cerrar(); e.preventDefault(); e.stopPropagation(); }
            }
        });
        input.addEventListener('blur', function () { cerrar(); alElegir(); });
        return { refrescar: function () { if (!lista.hidden) pintar(); } };
    }

    function enlazar(fab, mod, catalogo, aviso) {
        if (!fab || !mod || fab.dataset.sgCombo) return;
        fab.dataset.sgCombo = mod.dataset.sgCombo = '1';
        catalogo = catalogo || [];
        var porClave = {};
        catalogo.forEach(function (f) { porClave[clave(f.nombre)] = f; });
        function actual() { return porClave[clave(fab.value)] || null; }

        var previo = clave(fab.value);

        function decir() {
            var f = actual(), m = limpio(mod.value), t = limpio(fab.value);
            mod.placeholder = f ? (f.modelos.length ? 'Elija o escriba · ' + f.modelos.length + ' de ' + f.nombre : 'Escriba el primer modelo de ' + f.nombre)
                                : (t ? 'Modelo nuevo de ' + t : 'Primero el fabricante');
            if (!aviso) return;
            var html = '';
            if (t && !f) html = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + esc(t) + '</b> es un fabricante nuevo: se agrega al catálogo al guardar.';
            else if (f && m && !f.modelos.some(function (x) { return clave(x) === clave(m); }))
                html = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + esc(m) + '</b> es un modelo nuevo de ' + esc(f.nombre) + ': se agrega al guardar.';
            else if (f) html = '<i class="mdi mdi-check-circle-outline"></i> ' + esc(f.nombre) + ' · ' + f.repuestos + (f.repuestos === 1 ? ' repuesto' : ' repuestos') +
                               ' · ' + f.modelos.length + (f.modelos.length === 1 ? ' modelo' : ' modelos');
            aviso.innerHTML = html;
            aviso.hidden = !html;
        }

        combo(fab, function () {
            return catalogo.map(function (f) { return { valor: f.nombre, nota: f.repuestos + (f.repuestos === 1 ? ' rep.' : ' rep.') }; });
        }, function () {
            var f = actual();
            fab.value = f ? f.nombre : limpio(fab.value);
            // otro fabricante: el modelo anterior ya no le pertenece
            if (clave(fab.value) !== previo && previo &&
                !(f && f.modelos.some(function (x) { return clave(x) === clave(mod.value); }))) mod.value = '';
            previo = clave(fab.value);
            decir();
        });
        combo(mod, function () {
            var f = actual();
            return (f ? f.modelos : []).map(function (m) { return { valor: m }; });
        }, function () {
            var f = actual(), m = limpio(mod.value);
            if (f) for (var i = 0; i < f.modelos.length; i++) if (clave(f.modelos[i]) === clave(m)) { m = f.modelos[i]; break; }
            mod.value = m;
            decir();
        });
        fab.addEventListener('input', decir);
        mod.addEventListener('input', decir);
        decir();
    }

    w.SigmaFabricante = { enlazar: enlazar, clave: clave, combo: combo };
})(window);
