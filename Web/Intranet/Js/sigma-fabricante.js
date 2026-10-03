/* =============================================================================
   SIGMA · Fabricante y modelo del repuesto (bloque 333)
   -----------------------------------------------------------------------------
   Un campo que sugiere lo que ya existe y deja escribir lo nuevo, con el
   modelo en cascada bajo su fabricante. Lo usan la ficha web
   (Repuesto.aspx) y la del mapa 3D: una sola implementacion.

     - Sugiere mientras se escribe (datalist del navegador).
     - "fleetguard", "FLEETGUARD " o "Fléetguard" se corrigen a la forma del
       catalogo ("Fleetguard") al salir del campo: no nacen duplicados.
     - Si no existe, avisa que se agrega al catalogo al guardar. El alta la
       hace el trigger de la base (TRG_REPUESTO_FABRICANTE), la misma regla
       para la web, el mapa, la carga masiva y la API.
     - El modelo ofrece solo los de ese fabricante.

   Uso:  SigmaFabricante.enlazar(inputFabricante, inputModelo, catalogo, avisoEl)
         catalogo = [{ nombre, repuestos, modelos: [..] }]
   ============================================================================= */
(function (w) {
    'use strict';

    var n = 0;

    function clave(t) {
        return String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '')
            .replace(/\s+/g, ' ').trim().toLowerCase();
    }
    function limpio(t) { return String(t || '').replace(/\s+/g, ' ').trim(); }
    function esc(t) {
        return String(t).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; });
    }

    function lista(input, opciones) {
        var id = input.getAttribute('list');
        var dl = id ? document.getElementById(id) : null;
        if (!dl) {
            dl = document.createElement('datalist');
            dl.id = 'sgFab' + (++n);
            input.parentNode.appendChild(dl);
            input.setAttribute('list', dl.id);
        }
        dl.innerHTML = opciones.map(function (o) {
            return '<option value="' + esc(o.valor) + '"' + (o.etiqueta ? ' label="' + esc(o.etiqueta) + '"' : '') + '></option>';
        }).join('');
    }

    function enlazar(fab, mod, catalogo, aviso) {
        if (!fab || !mod) return;
        catalogo = catalogo || [];
        var porClave = {};
        catalogo.forEach(function (f) { porClave[clave(f.nombre)] = f; });

        input(fab); input(mod);
        function input(el) { el.setAttribute('autocomplete', 'off'); }

        lista(fab, catalogo.map(function (f) {
            return { valor: f.nombre, etiqueta: f.repuestos + (f.repuestos === 1 ? ' repuesto' : ' repuestos') };
        }));

        function fabricanteActual() { return porClave[clave(fab.value)] || null; }

        function modelos() {
            var f = fabricanteActual();
            lista(mod, (f ? f.modelos : []).map(function (m) { return { valor: m }; }));
            mod.placeholder = f ? (f.modelos.length ? 'Elija o escriba · ' + f.modelos.length + ' de ' + f.nombre : 'Escriba el primer modelo de ' + f.nombre)
                                : (limpio(fab.value) ? 'Modelo nuevo de ' + limpio(fab.value) : 'Primero el fabricante');
        }

        function decir() {
            if (!aviso) return;
            var t = limpio(fab.value), f = fabricanteActual(), m = limpio(mod.value), html = '';
            if (t && !f) html = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + esc(t) + '</b> es un fabricante nuevo: se agrega al catálogo al guardar.';
            else if (f && m && !f.modelos.some(function (x) { return clave(x) === clave(m); }))
                html = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + esc(m) + '</b> es un modelo nuevo de ' + esc(f.nombre) + ': se agrega al guardar.';
            else if (f) html = '<i class="mdi mdi-check-circle-outline"></i> ' + esc(f.nombre) + ' · ' + f.repuestos + (f.repuestos === 1 ? ' repuesto' : ' repuestos') +
                               ' · ' + f.modelos.length + (f.modelos.length === 1 ? ' modelo' : ' modelos');
            aviso.innerHTML = html;
            aviso.hidden = !html;
        }

        // al salir: la forma del catalogo, para que no nazca "fleetguard"
        function canonFab() {
            var f = fabricanteActual();
            fab.value = f ? f.nombre : limpio(fab.value);
        }
        function canonMod() {
            var f = fabricanteActual(), m = limpio(mod.value);
            if (f) for (var i = 0; i < f.modelos.length; i++) if (clave(f.modelos[i]) === clave(m)) { m = f.modelos[i]; break; }
            mod.value = m;
        }

        var previo = clave(fab.value);
        fab.addEventListener('input', function () { modelos(); decir(); });
        fab.addEventListener('change', function () {
            canonFab();
            // otro fabricante: el modelo anterior ya no le pertenece
            if (clave(fab.value) !== previo && previo) {
                var f = fabricanteActual();
                if (!f || !f.modelos.some(function (x) { return clave(x) === clave(mod.value); })) mod.value = '';
            }
            previo = clave(fab.value);
            modelos(); decir();
        });
        fab.addEventListener('blur', function () { canonFab(); decir(); });
        mod.addEventListener('input', decir);
        mod.addEventListener('change', function () { canonMod(); decir(); });
        mod.addEventListener('blur', function () { canonMod(); decir(); });

        modelos(); decir();
    }

    w.SigmaFabricante = { enlazar: enlazar, clave: clave };
})(window);
