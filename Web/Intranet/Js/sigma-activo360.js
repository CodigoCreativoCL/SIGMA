/* ============================================================================
   EL CENTRO DEL ACTIVO EN EL NAVEGADOR

   Cambiar de seccion, abrir el menu "Mas" y desplegar una orden de trabajo son
   gestos de mirar: el contenido de las trece secciones ya esta en la pagina y
   pedirselo de nuevo al servidor solo agregaria un parpadeo.

   Lo que escribe -filtrar, registrar, generar- sigue yendo por el UpdatePanel.

   Se rearma despues de cada postback asincrono: el UpdatePanel reemplaza el
   HTML y con el se van los listeners.
   ============================================================================ */
(function () {
    'use strict';

    function panelActivo() {
        var h = document.getElementById('hdnSeccion');
        return h && h.value ? h.value : 'resumen';
    }

    function irA(nombre) {
        /* Salir de la ficha con cambios sin guardar pregunta primero: el
           formulario sigue vivo mientras la pestaña este abierta, pero se
           pierde en cuanto la pagina recargue. */
        if (!puedeSalirDeFicha(nombre)) return;

        var tabs = document.querySelectorAll('.sg-a3-tab[data-sec]');
        var ops = document.querySelectorAll('.sg-a3-mas-op[data-sec]');
        var paneles = document.querySelectorAll('.sg-a3-panel');
        var hay = false;

        for (var i = 0; i < paneles.length; i++)
            hay = hay || paneles[i].getAttribute('data-panel') === nombre;

        if (!hay) nombre = 'resumen';

        for (var t = 0; t < tabs.length; t++)
            tabs[t].classList.toggle('es-activa', tabs[t].getAttribute('data-sec') === nombre);

        var extra = null;
        for (var o = 0; o < ops.length; o++) {
            var esta = ops[o].getAttribute('data-sec') === nombre;
            ops[o].classList.toggle('es-activa', esta);
            if (esta) extra = ops[o].textContent.trim();
        }

        /* Si la seccion vive dentro de "Mas", su nombre se escribe al lado del
           boton: sin eso la pantalla no dice donde esta parado uno. */
        var etiqueta = document.getElementById('sgA3MasNombre');
        var boton = document.querySelector('.sg-a3-mas-btn');

        if (etiqueta) etiqueta.textContent = extra ? ' · ' + extra : '';
        if (boton) boton.classList.toggle('es-activa', !!extra);

        for (var p = 0; p < paneles.length; p++)
            paneles[p].classList.toggle('es-activo', paneles[p].getAttribute('data-panel') === nombre);

        var h = document.getElementById('hdnSeccion');
        if (h) h.value = nombre;

        cerrarMas();
    }

    function cerrarMas() {
        var mas = document.querySelector('.sg-a3-mas');
        if (mas) mas.classList.remove('es-abierto');
    }

    function navegacion() {
        var tabs = document.querySelectorAll('.sg-a3-tab[data-sec], .sg-a3-mas-op[data-sec], [data-ir-sec]');

        for (var i = 0; i < tabs.length; i++)
            tabs[i].onclick = function (ev) {
                ev.preventDefault();
                irA(this.getAttribute('data-sec') || this.getAttribute('data-ir-sec'));
            };

        var boton = document.querySelector('.sg-a3-mas-btn');
        if (boton) boton.onclick = function (ev) {
            ev.preventDefault();
            ev.stopPropagation();
            document.querySelector('.sg-a3-mas').classList.toggle('es-abierto');
        };

        /* Un menu que no se cierra al tocar fuera queda tapando la pantalla. */
        document.addEventListener('click', cerrarMas);
        document.addEventListener('keydown', function (ev) { if (ev.keyCode === 27) cerrarMas(); });

        irA(panelActivo());
    }

    /* ---- Las ordenes de trabajo se despliegan en su misma fila ---- */
    function ordenes() {
        var filas = document.querySelectorAll('.sg-a3-ot[data-ot]');

        for (var i = 0; i < filas.length; i++)
            filas[i].onclick = function (ev) {
                /* Un clic en "Abrir OT" navega; el resto de la fila despliega. */
                if (ev.target.closest && ev.target.closest('a, input, button')) return;

                var det = document.getElementById('det-' + this.getAttribute('data-ot'));
                if (!det) return;

                var abierto = det.classList.toggle('es-abierto');
                this.classList.toggle('es-abierta', abierto);
            };
    }

    /* ---- Inspecciones y tareas ----

       La fila se despliega en su lugar y los filtros -tipo, resultado y
       busqueda- son del navegador: pedirle al servidor que filtre una lista
       que ya esta en pantalla es recargarla para esconder filas. */
    function revisiones() {
        var filas = document.querySelectorAll('.sg-a3-rev');
        if (!filas.length) return;

        for (var i = 0; i < filas.length; i++) {
            filas[i].onclick = function (ev) {
                if (ev.target.closest('a, input, button, select')) return;

                var det = document.getElementById('rev-' + this.getAttribute('data-rev'));
                if (!det) return;

                var abierto = det.classList.contains('es-abierto');
                det.classList.toggle('es-abierto', !abierto);
                this.classList.toggle('es-abierta', !abierto);
            };
        }

        var chips = document.querySelectorAll('#sgA3RevTipos a[data-rev-tipo]');
        var buscar = document.getElementById('sgA3RevBuscar');
        var resultado = document.getElementById('sgA3RevResultado');

        /* El estado del filtro se lee del DOM en cada pasada y no de una
           variable: la pagina se repinta por UpdatePanel y una variable
           guardada en el cierre anterior filtra filas que ya no existen. */
        function filtrar() {
            var activa = document.querySelector('#sgA3RevTipos a.es-activa');
            var tipo = activa ? activa.getAttribute('data-rev-tipo') : 'todas';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();
            var res = resultado && resultado.value || '';
            var vivas = document.querySelectorAll('.sg-a3-rev');

            for (var i = 0; i < vivas.length; i++) {
                var f = vivas[i];
                var ok = (tipo === 'todas' || f.getAttribute('data-rev-tipo') === tipo)
                      && (res === '' || f.getAttribute('data-rev-res') === res)
                      && (texto === '' || (f.getAttribute('data-rev-txt') || '').indexOf(texto) !== -1);

                f.classList.toggle('es-oculta', !ok);
            }
        }

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;
        if (resultado) resultado.onchange = filtrar;
    }

    /* ---- Cualquier foto de la pantalla se puede agrandar ----

       La galeria de evidencias ya tenia su visor; la foto del equipo, la del
       componente y la del plan no, y son justo las que alguien acerca a la
       cara para decidir si esa es la maquina. Se reusa el mismo marco y el
       mismo Esc: dos visores distintos en la misma pagina se cierran de dos
       maneras distintas. */
    function ampliables() {
        var fotos = document.querySelectorAll('.sg-a3-foto img, .sg-plan-foto img, [data-ampliar] img, img[data-ampliar]');

        for (var i = 0; i < fotos.length; i++) {
            if (fotos[i].getAttribute('data-listo') === '1') continue;

            fotos[i].setAttribute('data-listo', '1');
            fotos[i].classList.add('sg-a3-ampliable');
            fotos[i].title = 'Ampliar';
            fotos[i].onclick = function () { ampliar(this.src, this.alt || 'Imagen'); };
        }
    }

    function ampliar(url, titulo) {
        var fondo = document.getElementById('sgOtLightbox');

        if (!fondo) {
            fondo = document.createElement('div');
            fondo.id = 'sgOtLightbox';
            fondo.className = 'sg-ot-lightbox';
            document.body.appendChild(fondo);
        }

        fondo.innerHTML =
            '<div class="sg-ot-lb-marco" role="dialog" aria-modal="true">' +
            '<header class="sg-ot-lb-cab">' +
            '<span class="sg-ot-card-ico"><i class="mdi mdi-image-outline"></i></span>' +
            '<h3></h3>' +
            '<a href="#" class="sg-ot-lb-cerrar" title="Cerrar (Esc)"><i class="mdi mdi-close"></i></a>' +
            '</header>' +
            '<div class="sg-ot-lb-foto"><img alt="" /></div>' +
            '<div class="sg-ot-lb-datos">' +
            '<a class="sg-ot-btn es-plano" target="_blank"><i class="mdi mdi-open-in-new"></i>Abrir original</a>' +
            '</div></div>';

        /* El titulo y la url se ponen por propiedad y no armando HTML: el
           nombre del archivo lo escribio una persona y puede traer comillas
           o angulos. */
        fondo.querySelector('h3').textContent = titulo;
        fondo.querySelector('.sg-ot-lb-foto img').src = url;
        fondo.querySelector('.sg-ot-lb-foto img').alt = titulo;
        fondo.querySelector('.sg-ot-lb-datos a').href = url;

        fondo.classList.add('es-abierto');

        function cerrar(ev) {
            if (ev) ev.preventDefault();
            fondo.classList.remove('es-abierto');
            fondo.innerHTML = '';
            document.removeEventListener('keydown', porEscape);
        }

        function porEscape(ev) { if (ev.keyCode === 27) cerrar(); }

        fondo.querySelector('.sg-ot-lb-cerrar').onclick = cerrar;
        fondo.onclick = function (ev) { if (ev.target === fondo) cerrar(ev); };
        document.addEventListener('keydown', porEscape);
    }

    /* ---- La ficha avisa antes de que se pierda lo escrito ----

       La pestaña Ficha es un formulario largo. Cambiar de seccion no recarga
       -las pestañas son del navegador-, pero el formulario sigue ahi con lo
       tecleado sin guardar, y al recargar la pagina se pierde. Se marca
       sucio al primer cambio y se pregunta antes de salir. */
    var fichaSucia = false;

    function ficha() {
        var panel = document.querySelector('.sg-a3-ficha');
        if (!panel || panel.getAttribute('data-listo') === '1') return;

        panel.setAttribute('data-listo', '1');

        panel.addEventListener('input', ensuciar, true);
        panel.addEventListener('change', ensuciar, true);

        /* Guardar y Cancelar hacen postback: lo que venia sin guardar deja de
           estarlo en cuanto se van al servidor. */
        var acciones = panel.querySelectorAll('.sg-a3-ficha-pie input, .sg-a3-ficha-pie button');
        for (var i = 0; i < acciones.length; i++)
            acciones[i].addEventListener('click', function () { limpiar(); });

        window.onbeforeunload = function () {
            if (fichaSucia) return 'Hay cambios sin guardar en la ficha del activo.';
        };
    }

    function ensuciar() {
        var panel = document.querySelector('.sg-a3-ficha');
        if (!panel) return;
        fichaSucia = true;
        panel.classList.add('es-sucia');
    }

    function limpiar() {
        var panel = document.querySelector('.sg-a3-ficha');
        fichaSucia = false;
        if (panel) panel.classList.remove('es-sucia');
    }

    /// Se pregunta solo al SALIR de la ficha: entrar a ella no arriesga nada.
    function puedeSalirDeFicha(destino) {
        if (!fichaSucia || destino === 'ficha') return true;

        if (confirm('La ficha tiene cambios sin guardar. ¿Descartarlos y cambiar de sección?')) {
            limpiar();
            return true;
        }

        return false;
    }

    /* ---- Componentes: el arbol, la lista y el detalle miran lo mismo ----

       Elegir una pieza en cualquiera de los tres lados marca los otros dos y
       acota el historial de reemplazos a esa pieza. Todo con lo que ya vino
       en la fila: pedirle al servidor lo que ya esta en pantalla es un viaje
       de mas y un parpadeo. */
    function componentes() {
        var filas = document.querySelectorAll('.sg-comp-fila');
        if (!filas.length) return;

        var chips = document.querySelectorAll('#sgCompTipos a[data-comp-estado]');
        var buscar = document.getElementById('sgCompBuscar');
        var detalle = document.querySelector('.sg-comp-detalle-cuerpo');
        var nodos = document.querySelectorAll('.sg-comp-nodo[data-ir-comp]');
        var reemplazos = document.querySelectorAll('.sg-comp-rep');

        function filtrar() {
            var activa = document.querySelector('#sgCompTipos a.es-activa');
            var estado = activa ? activa.getAttribute('data-comp-estado') : 'instalados';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();

            for (var i = 0; i < filas.length; i++) {
                var ok = filas[i].getAttribute('data-comp-estado') === estado
                      && (texto === '' || (filas[i].getAttribute('data-comp-txt') || '').indexOf(texto) !== -1);
                filas[i].classList.toggle('es-oculta', !ok);
            }
        }

        function elegir(id) {
            var fila = document.querySelector('.sg-comp-fila[data-comp="' + id + '"]');
            if (!fila) return;

            for (var i = 0; i < filas.length; i++) filas[i].classList.remove('es-elegida');
            fila.classList.add('es-elegida');

            for (var n = 0; n < nodos.length; n++)
                nodos[n].classList.toggle('es-elegido', nodos[n].getAttribute('data-ir-comp') === String(id));

            pintar(fila);

            /* El historial se acota a la pieza elegida: "cuantos rodamientos
               lleva este ventilador" es la pregunta, no cuantos lleva el
               equipo entero. */
            for (var r = 0; r < reemplazos.length; r++)
                reemplazos[r].classList.toggle('es-oculta', reemplazos[r].getAttribute('data-comp-rep') !== String(id));
        }

        function dato(etiqueta, valor) {
            if (!valor) return '';
            var d = document.createElement('div');
            d.className = 'sg-ot-dato';
            d.innerHTML = '<div><span class="sg-ot-dato-etq"></span><span class="sg-ot-dato-val"></span></div>';
            d.querySelector('.sg-ot-dato-etq').textContent = etiqueta;
            d.querySelector('.sg-ot-dato-val').textContent = valor;
            return d.outerHTML;
        }

        function pintar(fila) {
            if (!detalle) return;

            var d = function (n) { return fila.getAttribute('data-comp-' + n) || ''; };
            var html = '';

            /* La foto primero: es lo que identifica la pieza antes que su
               codigo. Si no tiene, no se deja un hueco gris. */
            if (d('foto')) html += '<span class="sg-comp-det-foto"><img alt="" /></span>';

            html += '<div><span class="sg-comp-det-tit"></span><span class="sg-comp-det-sub"></span></div>';
            html += '<div>' + (d('estado-txt') ? '<span class="sg-ot-chip ' +
                    (fila.getAttribute('data-comp-estado') === 'instalados' ? 'es-ok' : 'es-neutro') +
                    '">' + d('estado-txt') + '</span>' : '') + '</div>';

            html += dato('Tipo', d('tipo'));
            html += dato('Criticidad', d('criticidad'));
            html += dato('Posición', d('posicion'));
            html += dato('Componente superior', d('padre'));
            html += dato('Instalado el', d('instalacion'));
            html += dato('Descripción', d('desc'));

            if (d('motivo')) html += '<div class="sg-comp-det-motivo"></div>';

            html += '<a class="sg-ot-btn es-plano" href="javascript:void(0)" data-comp-abrir="1">' +
                    '<i class="mdi mdi-open-in-new"></i>Ver ficha del componente</a>';

            detalle.innerHTML = html;

            /* El nombre y el motivo se ponen por propiedad: los escribio una
               persona y pueden traer comillas o angulos. */
            var foto = detalle.querySelector('.sg-comp-det-foto img');
            if (foto) { foto.src = d('foto'); foto.alt = d('nombre'); }

            detalle.querySelector('.sg-comp-det-tit').textContent = d('nombre');
            detalle.querySelector('.sg-comp-det-sub').textContent = d('codigo');

            var motivo = detalle.querySelector('.sg-comp-det-motivo');
            if (motivo) motivo.textContent = d('motivo');

            var abrir = detalle.querySelector('[data-comp-abrir]');
            if (abrir) abrir.onclick = function () { abrirComponente(d('query')); };
        }

        for (var i = 0; i < filas.length; i++)
            filas[i].onclick = function (ev) {
                if (ev.target.closest('a, input, button')) return;
                elegir(this.getAttribute('data-comp'));
            };

        for (var n = 0; n < nodos.length; n++)
            nodos[n].onclick = function () { elegir(this.getAttribute('data-ir-comp')); };

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;

        filtrar();

        /* Se abre con la primera pieza elegida: un panel de detalle vacio al
           lado de una lista llena parece que no cargo. */
        var primera = document.querySelector('.sg-comp-fila:not(.es-oculta)');
        if (primera) elegir(primera.getAttribute('data-comp'));
    }

    /* ---- Condicion: la tarjeta elegida manda ----

       Elegir una variable marca su fila en la tabla, acota las ultimas
       lecturas a esa variable y llena el panel de la derecha. Todo con lo que
       ya vino en la tarjeta. */
    /* ---- Condicion y medidores ----

       Tres filtros sobre la misma grilla -que es, como esta, como se llama- y
       un detalle que se abre DEBAJO de la tarjeta elegida. Separar variables
       y contadores en dos pantallas obligaba a saber de antemano en cual
       estaba lo que se buscaba. */
    function condicion() {
        var tarjetas = document.querySelectorAll('.sg-cond-card');
        if (!tarjetas.length) return;

        var vistas = document.querySelectorAll('#sgCondVistas a[data-cond-vista]');
        var buscar = document.getElementById('sgCondBuscar');
        var estado = document.getElementById('sgCondEstado');
        var detalle = document.getElementById('sgCondDetalle');
        var nada = document.getElementById('sgCondNada');
        var secciones = document.querySelectorAll('.sg-cond-seccion');
        var aviso = document.querySelector('.sg-cond-aviso-ver');

        function vistaActiva() {
            var a = document.querySelector('#sgCondVistas a.es-activa');
            return a ? a.getAttribute('data-cond-vista') : 'todas';
        }

        function filtrar() {
            var vista = vistaActiva();
            var texto = (buscar && buscar.value || '').toLowerCase().trim();
            var cual = estado ? estado.value : '';
            var visibles = 0;

            for (var i = 0; i < tarjetas.length; i++) {
                var t = tarjetas[i];
                var tipo = t.getAttribute('data-cond');

                var ok = (vista === 'todas' || (vista === 'variables' && tipo === 'variable') || (vista === 'medidores' && tipo === 'medidor'))
                      && (texto === '' || (t.getAttribute('data-buscar') || '').indexOf(texto) !== -1)
                      && (cual === '' || t.getAttribute('data-clase') === cual);

                t.classList.toggle('es-oculta', !ok);
                if (ok) visibles++;
            }

            /* Una seccion sin tarjetas visibles se va entera: dejar el titulo
               "Contadores acumulativos 4" sobre un hueco es peor que nada. */
            for (var s = 0; s < secciones.length; s++) {
                var quedan = secciones[s].querySelectorAll('.sg-cond-card:not(.es-oculta)').length;
                var vacia = secciones[s].querySelector('.sg-ot-vacio');
                secciones[s].classList.toggle('es-oculta', quedan === 0 && !(vacia && vista !== 'medidores' && texto === '' && cual === ''));
            }

            if (nada) nada.style.display = visibles ? 'none' : 'block';
        }

        for (var v = 0; v < vistas.length; v++)
            vistas[v].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < vistas.length; k++) vistas[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;
        if (estado) estado.onchange = filtrar;

        /* "Ver pendientes" es el mismo filtro de estado, no otra pantalla. */
        if (aviso) aviso.onclick = function (ev) {
            ev.preventDefault();
            if (!estado) return;
            estado.value = document.querySelector('.sg-cond-card.es-critico') ? 'es-critico' : 'es-aviso';
            filtrar();
        };

        function dato(etiqueta, valor) {
            if (!valor) return '';
            return '<div class="sg-cond-det-dato"><span>' + etiqueta + '</span><i class="sg-cond-det-txt"></i></div>';
        }

        function cerrar() {
            for (var i = 0; i < tarjetas.length; i++) tarjetas[i].classList.remove('es-elegida');
            if (detalle) detalle.style.display = 'none';
        }

        function abrir(card) {
            if (!detalle) return;

            if (card.classList.contains('es-elegida')) { cerrar(); return; }

            for (var i = 0; i < tarjetas.length; i++) tarjetas[i].classList.remove('es-elegida');
            card.classList.add('es-elegida');

            var d = function (n) { return card.getAttribute('data-' + n) || ''; };
            var esVariable = d('cond') === 'variable';

            var etiquetas = ['Contra qué se compara', esVariable ? 'Frecuencia esperada' : 'Plan asociado', 'Dónde se mide'];
            var valores = [d('rango'), d('frecuencia'), d('sub')];

            var html = '<div class="sg-cond-det-cab">' +
                       '<div class="sg-cond-det-tit"><i class="sg-cond-det-nom"></i><span class="sg-cond-det-sub2"></span></div>' +
                       '<div class="sg-cond-det-val"></div>' +
                       '<a href="javascript:void(0)" class="sg-cond-det-cerrar" title="Cerrar"><i class="mdi mdi-close"></i></a>' +
                       '</div><div class="sg-cond-det-datos">';

            for (var e = 0; e < etiquetas.length; e++) html += dato(etiquetas[e], valores[e]);
            html += '</div>';

            detalle.innerHTML = html;
            detalle.style.display = 'block';

            /* Los textos se escriben como texto, nunca como HTML: el nombre de
               una variable lo escribe una persona. */
            var nom = detalle.querySelector('.sg-cond-det-nom');
            if (nom) nom.textContent = d('titulo');

            var sub = detalle.querySelector('.sg-cond-det-sub2');
            if (sub) sub.textContent = d('sub');

            var val = detalle.querySelector('.sg-cond-det-val');
            var numero = card.querySelector('.sg-cond-card-val');

            /* El numero y la unidad son dos nodos pegados: leer el textContent
               del contenedor los junta en "27,6A". */
            if (val && numero) {
                var n = numero.querySelector('b'), u = numero.querySelector('small');
                val.textContent = (n ? n.textContent : '') + (u ? ' ' + u.textContent : '');
            }

            var textos = detalle.querySelectorAll('.sg-cond-det-txt');
            var puestos = 0;
            for (var x = 0; x < valores.length; x++) {
                if (!valores[x]) continue;
                if (textos[puestos]) textos[puestos].textContent = valores[x];
                puestos++;
            }

            // ---- el historial de ESTA tarjeta ----
            var lecturas = document.querySelectorAll('#sgCondFuente .sg-cond-lec[data-de="' + d('id') + '"]');

            if (esVariable) {
                var lista = document.createElement('div');
                lista.innerHTML = '<p class="sg-cond-det-sub">Últimas lecturas</p>';

                if (lecturas.length) {
                    for (var l = 0; l < lecturas.length; l++) lista.appendChild(lecturas[l].cloneNode(true));
                } else {
                    var p = document.createElement('p');
                    p.className = 'sg-ot-vacio-txt';
                    p.textContent = 'Sin lecturas en los últimos 90 días.';
                    lista.appendChild(p);
                }

                detalle.appendChild(lista);
            }

            // ---- las acciones ----
            var acciones = document.createElement('div');
            acciones.className = 'sg-cond-det-acciones';

            if (d('lectura'))
                acciones.appendChild(boton('mdi-plus', 'Registrar lectura', 'es-primario', function () {
                    abrirLectura(d('lectura'));
                }));

            if (esVariable && d('serie')) {
                var a = document.createElement('a');
                a.className = 'sg-ot-btn es-accion';
                a.href = d('serie');
                a.target = '_blank';
                a.rel = 'noopener';
                a.innerHTML = '<i class="mdi mdi-chart-line"></i>';
                a.appendChild(document.createTextNode('Ver historial completo'));
                acciones.appendChild(a);
            }

            if (d('editar') === '1')
                acciones.appendChild(boton('mdi-tune-variant',
                    esVariable ? 'Configurar umbrales' : 'Editar contador', 'es-accion', function () {
                        if (esVariable) abrirVariable(d('query')); else abrirMedidor(d('query'));
                    }));

            detalle.appendChild(acciones);

            var equis = detalle.querySelector('.sg-cond-det-cerrar');
            if (equis) equis.onclick = cerrar;

            detalle.scrollIntoView({ block: 'nearest' });
        }

        function boton(icono, texto, clase, accion) {
            var b = document.createElement('a');
            b.className = 'sg-ot-btn ' + clase;
            b.href = 'javascript:void(0)';
            b.innerHTML = '<i class="mdi ' + icono + '"></i>';
            b.appendChild(document.createTextNode(texto));
            b.onclick = accion;
            return b;
        }

        for (var i = 0; i < tarjetas.length; i++)
            tarjetas[i].onclick = function () { abrir(this); };

        filtrar();
    }

    /* ---- Fallas: dos vistas y un filtro ----

       La falla es lo que le paso al equipo y la detencion es el tiempo que
       costo: se cuentan distinto, asi que se miran en dos vistas. El filtro
       de abiertas/resueltas es del navegador. */
    function fallas() {
        var vistas = document.querySelectorAll('#sgFallaVistas a[data-falla-vista]');

        for (var v = 0; v < vistas.length; v++)
            vistas[v].onclick = function (ev) {
                ev.preventDefault();
                var cual = this.getAttribute('data-falla-vista');

                for (var k = 0; k < vistas.length; k++) vistas[k].classList.remove('es-activa');
                this.classList.add('es-activa');

                var paneles = document.querySelectorAll('.sg-cond-vista[data-falla-vista]');
                for (var p = 0; p < paneles.length; p++)
                    paneles[p].classList.toggle('es-oculta', paneles[p].getAttribute('data-falla-vista') !== cual);
            };

        var filas = document.querySelectorAll('.sg-falla');
        if (!filas.length) return;

        var chips = document.querySelectorAll('#sgFallaEstados a[data-falla-estado]');
        var buscar = document.getElementById('sgFallaBuscar');

        function filtrar() {
            var activa = document.querySelector('#sgFallaEstados a.es-activa');
            var estado = activa ? activa.getAttribute('data-falla-estado') : 'todas';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();

            for (var i = 0; i < filas.length; i++) {
                var ok = (estado === 'todas' || filas[i].getAttribute('data-falla-estado') === estado)
                      && (texto === '' || (filas[i].getAttribute('data-falla-txt') || '').indexOf(texto) !== -1);
                filas[i].classList.toggle('es-oculta', !ok);
            }
        }

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;
    }

    /* ---- La lista de equipos ----

       Buscar, los chips y las paginas son del navegador: las filas ya estan
       en pantalla y pedirle al servidor que las esconda es recargar la
       pantalla entera para mostrar menos. */
    function lista() {
        var filas = document.querySelectorAll('.sg-lista-fila');
        if (!filas.length) return;

        var chips = document.querySelectorAll('#sgListaChips a[data-lista]');
        var buscar = document.getElementById('sgListaBuscar');
        var porPagina = document.getElementById('sgListaPorPagina');
        var conteo = document.getElementById('sgListaConteo');
        var paginas = document.getElementById('sgListaPaginas');
        var pagina = 1;

        function coinciden() {
            var activa = document.querySelector('#sgListaChips a.es-activa');
            var cual = activa ? activa.getAttribute('data-lista') : 'todos';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();
            var salen = [];

            for (var i = 0; i < filas.length; i++) {
                var f = filas[i];
                var ok = (cual === 'todos'
                          || (cual === 'atencion' && f.getAttribute('data-lista-atencion') === '1')
                          || (cual === 'ot' && parseInt(f.getAttribute('data-lista-ot'), 10) > 0))
                      && (texto === '' || (f.getAttribute('data-lista-txt') || '').indexOf(texto) !== -1);

                if (ok) salen.push(f);
            }

            return salen;
        }

        function pintar() {
            var salen = coinciden();
            var tam = porPagina ? parseInt(porPagina.value, 10) : 25;
            if (!tam) tam = salen.length || 1;

            var total = salen.length;
            var ultima = Math.max(1, Math.ceil(total / tam));
            if (pagina > ultima) pagina = ultima;

            var desde = (pagina - 1) * tam;
            var hasta = Math.min(desde + tam, total);

            for (var i = 0; i < filas.length; i++) filas[i].classList.add('es-oculta');
            for (var j = desde; j < hasta; j++) salen[j].classList.remove('es-oculta');

            if (conteo)
                conteo.textContent = total === 0
                    ? 'Ningún equipo coincide con la búsqueda'
                    : 'Mostrando ' + (desde + 1) + '–' + hasta + ' de ' + total + (total === 1 ? ' equipo' : ' equipos');

            if (!paginas) return;

            paginas.innerHTML = '';
            if (ultima <= 1) return;

            /* Se listan todas las paginas cuando son pocas; con muchas, las
               de los bordes y las vecinas de la actual. Una tira de treinta
               numeros no sirve para llegar a la treinta. */
            for (var p = 1; p <= ultima; p++) {
                if (ultima > 7 && p > 2 && p < ultima - 1 && Math.abs(p - pagina) > 1) {
                    if (paginas.lastChild && paginas.lastChild.tagName !== 'SPAN') {
                        var puntos = document.createElement('span');
                        puntos.textContent = '…';
                        paginas.appendChild(puntos);
                    }
                    continue;
                }

                var a = document.createElement('a');
                a.href = 'javascript:void(0)';
                a.textContent = p;
                a.className = p === pagina ? 'es-activa' : '';
                a.onclick = (function (n) { return function () { pagina = n; pintar(); }; })(p);
                paginas.appendChild(a);
            }
        }

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                pagina = 1;
                pintar();
            };

        if (buscar) buscar.oninput = function () { pagina = 1; pintar(); };
        if (porPagina) porPagina.onchange = function () { pagina = 1; pintar(); };

        /* Abrir el equipo es un postback: el centro se arma en el servidor.
           El resto de la lista no lo es. */
        for (var i = 0; i < filas.length; i++)
            filas[i].onclick = function (ev) {
                if (ev.target.closest('input, select')) return;
                abrirActivoDelCentro(this.getAttribute('data-act'));
            };

        pintar();
    }

    function abrirActivoDelCentro(id) {
        var campo = document.getElementById(window.sgCampoActivo || '');
        if (!campo) return;

        campo.value = id;
        __doPostBack('', '');
    }

    /* ---- Documentos y galeria ----

       Tres vistas por lo que SON los archivos -documento, fotografia,
       evidencia de terreno- y un panel al lado con el elegido. El visor de
       imagen sigue siendo el de sigma-orden.js: aca se escucha el clic con
       addEventListener para no pisarle el suyo. */
    function documentos() {
        var tarjetas = document.querySelectorAll('.sg-a3-docs .sg-ot-ev-card');
        if (!tarjetas.length) return;

        var chips = document.querySelectorAll('#sgDocChips a[data-doc]');
        var buscar = document.getElementById('sgDocBuscar');
        var origen = document.getElementById('sgDocOrigen');
        var detalle = document.getElementById('sgOtEvDetalle');
        var filas = document.querySelectorAll('.sg-doc-fila');

        /* El desplegable se arma con los origenes que REALMENTE hay: ofrecer
           una orden que no adjunto nada devuelve vacio y parece roto. */
        if (origen && origen.options.length <= 1) {
            var vistos = {};

            for (var i = 0; i < tarjetas.length; i++) {
                var o = tarjetas[i].getAttribute('data-paso');
                if (!o || vistos[o]) continue;
                vistos[o] = true;

                var op = document.createElement('option');
                op.value = o;
                op.textContent = o;
                origen.appendChild(op);
            }
        }

        function filtrar() {
            var activa = document.querySelector('#sgDocChips a.es-activa');
            var clase = activa ? activa.getAttribute('data-doc') : 'todos';
            var texto = (buscar && buscar.value || '').toLowerCase().trim();
            var deQuien = origen ? origen.value : '';

            function calza(el, claseAttr, textoAttr, origenAttr) {
                return (clase === 'todos' || el.getAttribute(claseAttr) === clase)
                    && (texto === '' || (el.getAttribute(textoAttr) || '').indexOf(texto) !== -1)
                    && (deQuien === '' || (el.getAttribute(origenAttr) || '') === deQuien);
            }

            for (var i = 0; i < tarjetas.length; i++)
                tarjetas[i].classList.toggle('es-oculta',
                    !calza(tarjetas[i], 'data-doc-clase', 'data-buscar', 'data-paso'));

            for (var f = 0; f < filas.length; f++)
                filas[f].classList.toggle('es-oculta',
                    !calza(filas[f], 'data-doc-clase', 'data-doc-txt', 'data-doc-origen'));
        }

        function dato(etiqueta, valor) {
            if (!valor) return '';
            var d = document.createElement('div');
            d.className = 'sg-ot-dato';
            d.innerHTML = '<div><span class="sg-ot-dato-etq"></span><span class="sg-ot-dato-val"></span></div>';
            d.querySelector('.sg-ot-dato-etq').textContent = etiqueta;
            d.querySelector('.sg-ot-dato-val').textContent = valor;
            return d.outerHTML;
        }

        function pintar(card) {
            if (!detalle) return;

            var d = function (n) { return card.getAttribute('data-' + n) || ''; };
            var esImagen = d('imagen') === '1';

            var html = '<header class="sg-ot-card-cab"><span class="sg-ot-card-ico">' +
                       '<i class="mdi ' + (esImagen ? 'mdi-image-outline' : 'mdi-file-document-outline') + '"></i></span>' +
                       '<div><h3>Archivo</h3></div></header>';

            if (esImagen) html += '<span class="sg-doc-det-foto"><img alt="" /></span>';

            html += '<div class="sg-doc-det-nom"></div>';
            html += dato('Origen', d('paso-txt'));
            html += dato('Fecha', d('fecha'));
            html += dato('Subido por', d('usuario'));
            html += dato('Descripción', d('obs'));

            html += '<a class="sg-ot-btn es-accion" href="' + d('url') + '" target="_blank" rel="noopener">' +
                    '<i class="mdi mdi-open-in-new"></i>Abrir original</a>';

            if (d('orden'))
                html += '<a class="sg-ot-btn es-accion" href="' + d('orden') + '" target="_blank" rel="noopener">' +
                        '<i class="mdi mdi-clipboard-text-outline"></i>Abrir la orden</a>';

            detalle.innerHTML = html;
            detalle.querySelector('.sg-doc-det-nom').textContent = d('titulo');

            var img = detalle.querySelector('.sg-doc-det-foto img');
            if (img) {
                img.src = d('url');
                img.alt = d('titulo');
                img.onclick = function () { ampliar(d('url'), d('titulo')); };
            }
        }

        for (var i = 0; i < tarjetas.length; i++)
            tarjetas[i].addEventListener('click', function () { pintar(this); });

        for (var c = 0; c < chips.length; c++)
            chips[c].onclick = function (ev) {
                ev.preventDefault();
                for (var k = 0; k < chips.length; k++) chips[k].classList.remove('es-activa');
                this.classList.add('es-activa');
                filtrar();
            };

        if (buscar) buscar.oninput = filtrar;
        if (origen) origen.onchange = filtrar;

        filtrar();
        pintar(tarjetas[0]);
    }

    /* ---- La agenda: un dia a la vez ----

       El calendario dice como viene el mes; tocar un dia dice que hay ESE
       dia. Los eventos ya viajan en la casilla, asi que no se pide nada. */
    function agenda() {
        var dias = document.querySelectorAll('.sg-mant-cal-dia');
        if (!dias.length) return;

        var caja = document.getElementById('sgMantDia');
        if (!caja) return;

        function mostrar(dia) {
            for (var i = 0; i < dias.length; i++) dias[i].classList.remove('es-elegido');
            dia.classList.add('es-elegido');

            var eventos = (dia.getAttribute('data-eventos') || '').split('\n').filter(function (x) { return x; });

            caja.innerHTML = '<strong></strong>' + (eventos.length
                ? '<ul></ul>'
                : '<span>Sin actividades este día.</span>');

            caja.querySelector('strong').textContent = dia.getAttribute('data-dia') || '';

            var ul = caja.querySelector('ul');
            if (!ul) return;

            for (var e = 0; e < eventos.length; e++) {
                var li = document.createElement('li');
                li.textContent = eventos[e];
                ul.appendChild(li);
            }
        }

        for (var i = 0; i < dias.length; i++)
            dias[i].onclick = function () { mostrar(this); };

        /* Se abre en el primer dia que tiene algo, o en hoy: un panel vacio
           al lado de un calendario con puntos parece que no cargo. */
        var conAlgo = document.querySelector('.sg-mant-cal-dia.es-con');
        mostrar(conAlgo || document.querySelector('.sg-mant-cal-dia.es-hoy') || dias[0]);
    }

    /* ---- Los popover de la lista ----

       El numero de OT abiertas y la fecha del proximo mantenimiento abren el
       detalle sobre la fila. El contenido ya viaja con ella: un ida y vuelta
       al servidor por cada numero que se toca se nota. */
    /* ---- El calendario del popover ----

       El servidor manda los eventos; el mes lo arma el navegador. Pintar una
       rejilla por activo en el HTML de la lista serian ochocientas celdas que
       nadie va a mirar. */
    function calendario(caja) {
        var rejilla = caja.querySelector('.sg-pop-cal');
        var detalle = caja.querySelector('.sg-pop-dia');
        var fuente = caja.querySelector('.sg-pop-ev');

        if (!rejilla || !fuente) return;
        if (rejilla.getAttribute('data-listo') === '1') return;

        rejilla.setAttribute('data-listo', '1');

        var MES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                   'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
        var DIA = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

        var eventos = fuente.querySelectorAll('.sg-pop-item[data-fecha]');
        if (!eventos.length) return;

        /* Por dia: cuantos hay y si alguno ya tiene orden. El popover se abre
           en el mes del primer evento, no en el mes de hoy: la proxima
           mantencion puede ser en marzo. */
        var porDia = {};
        var primero = null, ultimo = null;

        for (var i = 0; i < eventos.length; i++) {
            var f = eventos[i].getAttribute('data-fecha');
            if (!porDia[f]) porDia[f] = { n: 0, ot: false };
            porDia[f].n++;
            if (eventos[i].querySelector('.es-ok')) porDia[f].ot = true;

            if (!primero || f < primero) primero = f;
            if (!ultimo || f > ultimo) ultimo = f;
        }

        function partes(iso) {
            var p = iso.split('-');
            return { a: parseInt(p[0], 10), m: parseInt(p[1], 10) - 1, d: parseInt(p[2], 10) };
        }

        function clave(a, m, d) {
            return a + '-' + ('0' + (m + 1)).slice(-2) + '-' + ('0' + d).slice(-2);
        }

        var ini = partes(primero), fin = partes(ultimo);
        var hoy = new Date();
        var hoyClave = clave(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());

        var verA = ini.a, verM = ini.m;

        function mostrarDia(iso) {
            if (!detalle) return;

            detalle.innerHTML = '<strong></strong>';

            var p = partes(iso);
            detalle.querySelector('strong').textContent = p.d + ' de ' + MES[p.m];

            for (var e = 0; e < eventos.length; e++)
                if (eventos[e].getAttribute('data-fecha') === iso)
                    detalle.appendChild(eventos[e].cloneNode(true));
        }

        function pintar() {
            var html = '<div class="sg-pop-cal-cab">' +
                       '<a href="javascript:void(0)" class="sg-pop-cal-nav" data-mes="-1"><i class="mdi mdi-chevron-left"></i></a>' +
                       '<strong></strong>' +
                       '<a href="javascript:void(0)" class="sg-pop-cal-nav" data-mes="1"><i class="mdi mdi-chevron-right"></i></a>' +
                       '</div><div class="sg-pop-cal-dias">';

            for (var d = 0; d < 7; d++) html += '<span>' + DIA[d] + '</span>';
            html += '</div><div class="sg-pop-cal-grid"></div>';

            rejilla.innerHTML = html;
            rejilla.querySelector('.sg-pop-cal-cab strong').textContent = MES[verM] + ' ' + verA;

            /* Lunes primero: getDay() devuelve 0 para el domingo y la semana
               laboral chilena no empieza ahi. */
            var primeroMes = new Date(verA, verM, 1);
            var desplaza = (primeroMes.getDay() + 6) % 7;
            var largo = new Date(verA, verM + 1, 0).getDate();
            var previo = new Date(verA, verM, 0).getDate();

            var grid = rejilla.querySelector('.sg-pop-cal-grid');
            var celdas = '';

            for (var x = desplaza; x > 0; x--)
                celdas += '<span class="sg-pop-cal-dia es-fuera">' + (previo - x + 1) + '</span>';

            for (var n = 1; n <= largo; n++) {
                var iso = clave(verA, verM, n);
                var info = porDia[iso];

                var cls = 'sg-pop-cal-dia';
                if (info) cls += ' es-con' + (info.ot ? ' es-ot' : '');
                if (iso === hoyClave) cls += ' es-hoy';

                celdas += info
                    ? '<a href="javascript:void(0)" class="' + cls + '" data-dia="' + iso + '">' + n + '<i></i></a>'
                    : '<span class="' + cls + '">' + n + '</span>';
            }

            grid.innerHTML = celdas;

            // los meses fuera del rango con eventos no se ofrecen
            var atras = rejilla.querySelector('[data-mes="-1"]');
            var adelante = rejilla.querySelector('[data-mes="1"]');

            if (verA === ini.a && verM === ini.m) atras.classList.add('es-mudo');
            if (verA === fin.a && verM === fin.m) adelante.classList.add('es-mudo');

            var navs = rejilla.querySelectorAll('.sg-pop-cal-nav');
            for (var v = 0; v < navs.length; v++)
                navs[v].onclick = function () {
                    var paso = parseInt(this.getAttribute('data-mes'), 10);
                    verM += paso;
                    if (verM < 0) { verM = 11; verA--; }
                    if (verM > 11) { verM = 0; verA++; }
                    pintar();
                };

            var dias = rejilla.querySelectorAll('.sg-pop-cal-dia[data-dia]');
            for (var k = 0; k < dias.length; k++)
                dias[k].onclick = function () {
                    for (var q = 0; q < dias.length; q++) dias[q].classList.remove('es-elegido');
                    this.classList.add('es-elegido');
                    mostrarDia(this.getAttribute('data-dia'));
                };

            /* Se abre con un dia puesto: un calendario con puntos y un panel
               vacio debajo parece que no cargo. */
            var deEsteMes = rejilla.querySelector('.sg-pop-cal-dia[data-dia]');
            if (deEsteMes) deEsteMes.click();
            else if (detalle) detalle.innerHTML = '';
        }

        pintar();
    }

    function popovers() {
        /* Tras un postback parcial la lista se vuelve a pintar entera. Las
           cajas que se habian colgado del <body> ya no tienen fila: si no se
           barren, cada refresco deja otra copia y el popover abre la vieja. */
        var viejas = document.querySelectorAll('body > .sg-pop');
        for (var q = 0; q < viejas.length; q++) viejas[q].parentNode.removeChild(viejas[q]);

        var gatillos = document.querySelectorAll('.es-pop[data-pop]');
        if (!gatillos.length) return;

        var abierto = null;

        function cerrar() {
            if (!abierto) return;
            abierto.classList.remove('es-abierto');
            abierto = null;
        }

        function abrir(gatillo) {
            var cual = gatillo.getAttribute('data-pop');
            var de = gatillo.getAttribute('data-pop-de');

            var caja = document.querySelector('.sg-pop[data-pop-cont="' + cual + '"][data-pop-de="' + de + '"]');
            if (!caja) return;

            if (abierto === caja) { cerrar(); return; }
            cerrar();

            /* Se cuelga del <body> y se posiciona a mano: dentro de la fila,
               el overflow de la grilla le cortaba la mitad.

               Y se lleva la clase `sg-a3`, que es donde viven los tokens de
               color del centro: fuera de ese contenedor, `var(--sg-p)` no
               resuelve y el fondo del dia elegido quedaba transparente con el
               numero en blanco, o sea invisible. */
            if (caja.parentNode !== document.body) {
                caja.classList.add('sg-a3');
                document.body.appendChild(caja);
            }

            if (caja.classList.contains('es-cal')) calendario(caja);

            caja.classList.add('es-abierto');
            abierto = caja;

            var r = gatillo.getBoundingClientRect();
            var alto = caja.offsetHeight;
            var ancho = caja.offsetWidth;

            var arriba = window.pageYOffset + r.bottom + 6;

            // si no cabe abajo, se abre hacia arriba antes que salirse de la pantalla
            if (r.bottom + alto + 12 > window.innerHeight && r.top - alto - 6 > 0)
                arriba = window.pageYOffset + r.top - alto - 6;

            var izquierda = window.pageXOffset + Math.min(r.left, window.innerWidth - ancho - 12);

            caja.style.top = Math.round(arriba) + 'px';
            caja.style.left = Math.round(Math.max(8, izquierda)) + 'px';
        }

        for (var i = 0; i < gatillos.length; i++)
            gatillos[i].onclick = function (ev) {
                ev.preventDefault();
                ev.stopPropagation();
                abrir(this);
            };

        /* Un clic en el popover no lo cierra -se va a tocar un enlace-; uno
           afuera, si. */
        var cajas = document.querySelectorAll('.sg-pop');
        for (var c = 0; c < cajas.length; c++)
            cajas[c].onclick = function (ev) { ev.stopPropagation(); };

        /* Los oyentes del documento se ponen UNA vez: armar() corre de nuevo
           en cada postback parcial y se irian acumulando. */
        window.__sgPopCerrar = cerrar;

        if (!window.__sgPopListo) {
            window.__sgPopListo = true;
            var fuera = function () { if (window.__sgPopCerrar) window.__sgPopCerrar(); };
            document.addEventListener('click', fuera);
            document.addEventListener('keydown', function (ev) { if (ev.key === 'Escape') fuera(); });
            window.addEventListener('resize', fuera);
        }
    }

    function armar() {
        navegacion();
        ficha();
        componentes();
        condicion();
        fallas();
        lista();
        popovers();
        documentos();
        agenda();
        ordenes();
        revisiones();
        ampliables();
    }

    if (document.addEventListener) document.addEventListener('DOMContentLoaded', armar);

    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(armar);

    window.sigmaActivo360 = { irA: irA, ampliar: ampliar };
})();
