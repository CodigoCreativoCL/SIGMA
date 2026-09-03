/* ============================================================================
   SIGMA — Ficha de programación: la interacción, en el cliente
   ----------------------------------------------------------------------------

   QUÉ SE MUEVE ACÁ Y QUÉ NO

     Todo lo que es MOVER LA VISTA pasa a ser instantáneo: cambiar de paso,
     elegir la frecuencia, marcar días, elegir a quién se asigna. Nada de eso
     necesita al servidor —los seis pasos ya están en el DOM— y hacerlo con
     un viaje de ida y vuelta se sentía lento sin motivo.

     Lo que SÍ sigue yendo al servidor es lo que necesita datos que el
     navegador no tiene: al elegir otra instalación hay que traer SUS áreas,
     SUS activos y SUS cuadrillas. Eso no es un toggle, es una consulta.
     Resolverlo "sin postback" obligaría a mandar el catálogo completo de
     todas las plantas al navegador, que es más lento y además filtra datos
     de instalaciones que la persona quizá no debería ver.

   EL SERVIDOR SIGUE MANDANDO

     El resumen y los avisos de "falta completar" se recalculan acá para que
     respondan al tipear, pero NO son la validación: al guardar, el servidor
     vuelve a revisarlo todo y los SP tienen sus propias reglas. Esto es
     ayuda visual, no una autorización.

   EL ESTADO SOBREVIVE AL GUARDADO

     En qué paso está y a quién se asigna viven en campos ocultos. Cuando se
     aprieta Guardar —que sí es un postback de verdad— el servidor los lee y
     devuelve la página en el mismo paso, en vez de mandar a la persona de
     vuelta al principio.
   ============================================================================ */
(function () {
    'use strict';

    var raiz = null;

    function $(sel, ctx) { return (ctx || raiz || document).querySelector(sel); }
    function $$(sel, ctx) {
        return Array.prototype.slice.call((ctx || raiz || document).querySelectorAll(sel));
    }

    function valor(id) { var e = document.getElementById(id); return e ? e.value : ''; }
    function poner(id, v) { var e = document.getElementById(id); if (e) e.value = v; }

    /* ------------------------------------------------------------------
       PASOS
       ------------------------------------------------------------------ */
    function irAlPaso(n) {
        var paneles = $$('.sg-paso-panel');
        var botones = $$('.sg-paso');

        if (n < 1) n = 1;
        if (n > paneles.length) n = paneles.length;

        for (var i = 0; i < paneles.length; i++)
            paneles[i].className = 'sg-paso-panel' + (i === n - 1 ? ' is-activo' : '');

        poner('hfPaso', n);
        pintarStepper(n);

        var ant = $('.sg-prog-nav .sg-btn-plano');
        var sig = $('.sg-prog-nav .sg-btn-secundario');

        if (ant) ant.style.visibility = (n === 1 ? 'hidden' : 'visible');
        if (sig) sig.style.visibility = (n === botones.length ? 'hidden' : 'visible');

        /* Al cambiar de paso se sube: si el paso anterior era largo, el
           siguiente aparecía ya desplazado y parecía vacío. */
        var caja = $('.sg-prog-form');
        if (caja && caja.scrollIntoView) caja.scrollIntoView({ block: 'start' });

        if (window.gsap) {
            var activo = paneles[n - 1];
            if (activo) gsap.fromTo(activo, { opacity: 0, y: 8 },
                { opacity: 1, y: 0, duration: .25, ease: 'power2.out', clearProps: 'transform,opacity' });
        }
    }

    /* El estado de cada casilla del stepper: cuál está activa, cuál quedó
       atrás y completa, y cuál tiene algo pendiente. */
    function pintarStepper(n) {
        var botones = $$('.sg-paso');

        for (var i = 0; i < botones.length; i++) {
            var num = i + 1;
            var falta = faltaEnPaso(num);
            var visitado = num < n;

            botones[i].className = 'sg-paso' +
                (num === n ? ' is-activo' : '') +
                (visitado && !falta ? ' is-listo' : '') +
                (falta && (visitado || num === n) ? ' is-pendiente' : '');

            var bolita = botones[i].querySelector('.sg-paso-bolita');
            if (bolita) bolita.textContent = (visitado && !falta) ? '✓' : num;

            botones[i].title = falta || (botones[i].querySelector('.sg-paso-rotulo') || {}).textContent || '';
        }
    }

    /* ------------------------------------------------------------------
       QUÉ LE FALTA A CADA PASO

       Es el mismo criterio que aplica el servidor en FaltaEnPaso(). Está
       duplicado a propósito y se asume: acá es para responder al tipear,
       allá es la palabra final. Si alguna vez discrepan, manda el servidor.
       ------------------------------------------------------------------ */
    function faltaEnPaso(n) {
        if (n === 1) {
            if (!texto('.sigma-modal-field input[type="text"]')) return 'Falta el nombre.';
            return '';
        }

        if (n === 3) {
            var modo = valor('hfModo');

            if (modo === 'persona' && !comboValor('cboResponsable')) return 'Falta el responsable.';
            if (modo === 'grupo' && !comboValor('cboGrupo')) return 'Falta el grupo de trabajo.';

            return '';
        }

        if (n === 4) {
            var frec = frecuenciaActiva();

            if (frec === 'SEMANAL' && diasMarcados().length === 0)
                return 'Elija al menos un día.';

            return '';
        }

        return '';
    }

    function texto(sel) {
        var e = $(sel);
        return e ? (e.value || '').trim() : '';
    }

    /* El RadComboBox guarda su valor en un input oculto cuyo id termina en
       "_ClientState"; lo simple y estable es leer el hidden que el control
       pone con el mismo id + "_ClientState" o, si no, su input visible. */
    function comboValor(sufijo) {
        var todos = $$('input[type="hidden"]');

        for (var i = 0; i < todos.length; i++)
            if (todos[i].id.indexOf(sufijo) !== -1 && todos[i].id.indexOf('ClientState') !== -1) {
                var v = todos[i].value || '';

                /* El ClientState viene como JSON: si trae value vacío, no hay
                   nada elegido. */
                var m = /"value"\s*:\s*"([^"]*)"/.exec(v);
                if (m) return m[1];

                return '';
            }

        return '';
    }

    function diasMarcados() {
        return $$('.sg-chip.is-marcado');
    }

    function frecuenciaActiva() {
        var a = $('.sg-seg.is-activa');
        return a ? (a.textContent || '').trim().toUpperCase() : '';
    }

    /* ------------------------------------------------------------------
       CHIPS DE DÍAS

       El chip mueve la casilla real, que es la que postea. El chip es la
       cara; la casilla sigue siendo el dato.
       ------------------------------------------------------------------ */
    function conectarDias() {
        var chips = $$('.sg-chips .sg-chip');

        /* Acotado al bloque de días: `.sg-oculto-accesible` lo usan también la
           grilla oculta y el combo de frecuencia, y sin acotar los chips
           terminaban moviendo casillas de otra cosa. */
        var cajas = $$('.sg-campo-dias .sg-oculto-accesible input[type="checkbox"]');

        chips.forEach(function (chip, i) {
            chip.onclick = function (ev) {
                ev.preventDefault();

                var caja = cajas[i];
                if (!caja) return false;

                caja.checked = !caja.checked;

                chip.className = 'sg-chip' + (caja.checked ? ' is-marcado' : '');
                chip.setAttribute('aria-pressed', caja.checked ? 'true' : 'false');

                if (window.gsap)
                    gsap.fromTo(chip, { scale: .9 }, { scale: 1, duration: .22, ease: 'back.out(3)' });

                refrescar();
                return false;
            };
        });
    }

    /* ------------------------------------------------------------------
       FRECUENCIA

       Cambiar de pestaña muestra u oculta los campos que esa frecuencia
       necesita. Antes esto costaba un viaje al servidor para, literalmente,
       esconder dos divs.
       ------------------------------------------------------------------ */
    var CAMPOS_POR_FRECUENCIA = {
        'DIARIA':  { dias: false, diaMes: false, ordinal: false, mes: false },
        'SEMANAL': { dias: true,  diaMes: false, ordinal: false, mes: false },
        'MENSUAL': { dias: true,  diaMes: true,  ordinal: true,  mes: false },
        'ANUAL':   { dias: true,  diaMes: true,  ordinal: true,  mes: true }
    };

    function aplicarFrecuencia(nombre) {
        var reglas = CAMPOS_POR_FRECUENCIA[nombre.toUpperCase()];
        if (!reglas) return;

        mostrar('.sg-campo-dias', reglas.dias);
        mostrar('.sg-campo-diames', reglas.diaMes);
        mostrar('.sg-campo-ordinal', reglas.ordinal);
        mostrar('.sg-campo-mes', reglas.mes);

        var u = $('.sg-unidad-frecuencia');
        if (u) u.textContent =
            nombre.toUpperCase() === 'DIARIA' ? 'día(s)' :
            nombre.toUpperCase() === 'SEMANAL' ? 'semana(s)' :
            nombre.toUpperCase() === 'MENSUAL' ? 'mes(es)' : 'año(s)';
    }

    function mostrar(sel, si) {
        var e = $(sel);
        if (e) e.style.display = si ? '' : 'none';
    }

    function conectarFrecuencias() {
        var tabs = $$('.sg-seg');

        tabs.forEach(function (tab) {
            tab.onclick = function (ev) {
                ev.preventDefault();

                tabs.forEach(function (t) { t.className = 'sg-seg'; });
                tab.className = 'sg-seg is-activa';

                var nombre = (tab.textContent || '').trim();
                poner('hfFrecuencia', tab.getAttribute('data-id') || '');
                aplicarFrecuencia(nombre);
                refrescar();
                return false;
            };
        });
    }

    /* ------------------------------------------------------------------
       A QUIÉN SE ASIGNA
       ------------------------------------------------------------------ */
    function conectarAsignacion() {
        var opciones = $$('.sg-opciones .sg-opcion[data-modo]');

        opciones.forEach(function (op) {
            op.onclick = function (ev) {
                ev.preventDefault();

                var modo = op.getAttribute('data-modo');
                poner('hfModo', modo);

                opciones.forEach(function (o) {
                    o.className = 'sg-opcion' + (o === op ? ' is-elegida' : '');
                });

                mostrar('.sg-campo-persona', modo === 'persona');
                mostrar('.sg-campo-grupo', modo === 'grupo');

                refrescar();
                return false;
            };
        });
    }

    /* ------------------------------------------------------------------
       INTERRUPTORES

       El par de radios Sí/No renderizaba como dos puntos idénticos sin
       etiqueta: no había forma de saber cuál era cuál. Los radios siguen
       siendo el dato —son los que postean—; esto los mueve.
       ------------------------------------------------------------------ */
    function radioDe(caja, cual) {
        var sufijo = caja.getAttribute(cual);
        if (!sufijo) return null;

        var todos = $$('input[type="radio"]', caja);

        for (var i = 0; i < todos.length; i++)
            if (todos[i].id.indexOf(sufijo) !== -1) return todos[i];

        return null;
    }

    function pintarConmutador(caja) {
        var si = radioDe(caja, 'data-si');
        var encendido = !!(si && si.checked);

        caja.className = 'sg-check sg-conmutador' + (encendido ? ' is-si' : '');

        var sw = caja.querySelector('.sg-switch');
        if (sw) sw.setAttribute('aria-checked', encendido ? 'true' : 'false');
    }

    function conectarConmutadores() {
        $$('.sg-conmutador').forEach(function (caja) {
            pintarConmutador(caja);

            var sw = caja.querySelector('.sg-switch');
            if (!sw) return;

            function alternar() {
                var si = radioDe(caja, 'data-si');
                var no = radioDe(caja, 'data-no');
                if (!si || !no) return;

                /* Se mueven LOS DOS: son un grupo de radios, y dejar uno sin
                   tocar deja el par en un estado que el servidor lee mal. */
                var nuevo = !si.checked;
                si.checked = nuevo;
                no.checked = !nuevo;

                pintarConmutador(caja);
                refrescar();
            }

            sw.onclick = function (ev) { ev.preventDefault(); alternar(); return false; };

            sw.onkeydown = function (ev) {
                /* Espacio y Enter, que es lo que se espera de un role="switch". */
                if (ev.keyCode === 32 || ev.keyCode === 13) {
                    ev.preventDefault();
                    alternar();
                }
            };
        });
    }

    /* ------------------------------------------------------------------
       EL RESUMEN, AL TIPEAR
       ------------------------------------------------------------------ */
    function refrescar() {
        pintarStepper(parseInt(valor('hfPaso'), 10) || 1);

        var caja = $('.sg-resumen-estado');
        if (!caja) return;

        var faltas = [];
        var titulos = ['Información general', 'Alcance', 'Asignación',
                       'Frecuencia', 'Exclusiones'];

        for (var n = 1; n <= 5; n++) {
            var f = faltaEnPaso(n);
            if (f) faltas.push(titulos[n - 1] + ': ' + f);
        }

        if (faltas.length === 0) {
            caja.className = 'sg-resumen-estado is-ok';
            caja.innerHTML = '<i class="mdi mdi-check-circle"></i><span>Configuración válida</span>';
            return;
        }

        caja.className = 'sg-resumen-estado is-falta';

        var html = '<i class="mdi mdi-alert-circle-outline"></i><div><strong>Falta completar</strong><ul>';

        for (var i = 0; i < faltas.length; i++) {
            var li = document.createElement('li');
            li.textContent = faltas[i];
            html += li.outerHTML;
        }

        caja.innerHTML = html + '</ul></div>';
    }

    /* ==================================================================
       LA TABLA DE FECHAS

       Agregar, corregir y quitar una fecha son acciones sobre UNA fila.
       Devolver la ficha entera al servidor por cada una —y volver a pintar
       los seis pasos— es justo lo que el patrón llama una microacción.

       Todo pasa por WsProgramacion.asmx. El permiso se comprueba allá y otra
       vez en el procedimiento: esconder el botón de borrar no es seguridad,
       quien arma el POST a mano se lo salta.

       EL NAVEGADOR NO CIFRA. No puede —una clave dentro del JS es una clave
       publicada—. Cada fila llega con su token ya cifrado por el servidor y
       el cliente se limita a devolverlo.
       ================================================================== */
    var FECHAS = { url: '', prog: '', puedeEditar: false, editando: '' };

    function llamar(metodo, cuerpo, alTerminar) {
        $.ajax({
            type: 'POST',
            url: FECHAS.url + '/' + metodo,
            data: JSON.stringify(cuerpo),
            contentType: 'application/json; charset=utf-8',
            dataType: 'json',
            success: function (result) {
                var r;

                /* Si la respuesta no es el JSON esperado, se dice. Dejar que
                   reviente adentro del success deja la tabla en blanco sin
                   explicación. */
                try { r = JSON.parse(result.d); }
                catch (e) { r = { error: true, detalle: 'Respuesta inesperada del servidor.' }; }

                alTerminar(r);
            },
            error: function () {
                alTerminar({ error: true, detalle: 'No fue posible contactar al servidor.' });
            }
        });
    }

    function avisar(texto) {
        if (window.Swal) Swal.fire('', texto, 'warning');
        else alert(texto);
    }

    function cargarFechas() {
        if (!FECHAS.prog) return;

        llamar('ListarFechas', { datos: FECHAS.prog }, function (r) {
            if (r.error) { pintarFechas([], r.detalle); return; }

            FECHAS.puedeEditar = !!r.puedeEditar;
            pintarFechas(r.filas || [], '');
        });
    }

    function pintarFechas(filas, error) {
        var caja = document.getElementById('sgFechas');
        if (!caja) return;

        caja.innerHTML = '';

        if (error) {
            var av = document.createElement('div');
            av.className = 'sg-vacio';
            av.textContent = error;
            caja.appendChild(av);
            return;
        }

        if (filas.length === 0) {
            caja.innerHTML = '<div class="sg-vacio"><i class="mdi mdi-calendar-blank-outline"></i>' +
                '<div><strong>Sin fechas.</strong> Agregue al menos una: una programación por ' +
                'fecha única sin fechas no genera nada.</div></div>';
            return;
        }

        var t = document.createElement('table');
        t.className = 'sg-tabla';

        var thead = document.createElement('thead');
        thead.innerHTML = '<tr><th scope="col">Fecha</th><th scope="col">Día</th>' +
                          '<th scope="col">Hora</th>' +
                          '<th scope="col" class="sg-tabla-acciones">Acciones</th></tr>';
        t.appendChild(thead);

        var tbody = document.createElement('tbody');

        filas.forEach(function (f) {
            tbody.appendChild(FECHAS.editando === f.token ? filaEdicion(f) : filaLectura(f));
        });

        t.appendChild(tbody);
        caja.appendChild(t);

        if (window.gsap)
            gsap.from(tbody.querySelectorAll('tr'), {
                opacity: 0, y: 6, duration: .25, stagger: .03, ease: 'power2.out',
                clearProps: 'transform,opacity'
            });
    }

    /* Se arma con createElement y textContent, nunca con innerHTML: la fecha
       y el día vienen del servidor pero pasan por el navegador, y concatenar
       texto ajeno dentro de HTML es por donde se cuela lo que no es texto. */
    function celda(fila, texto, rotulo) {
        var td = document.createElement('td');
        td.setAttribute('data-rotulo', rotulo);
        td.textContent = texto;
        fila.appendChild(td);
        return td;
    }

    function filaLectura(f) {
        var tr = document.createElement('tr');
        if (f.pasada) tr.className = 'is-pasada';

        celda(tr, f.fecha, 'Fecha');
        celda(tr, f.dia, 'Día');
        celda(tr, f.hora || '—', 'Hora');

        var acc = document.createElement('td');
        acc.className = 'sg-tabla-acciones';

        if (FECHAS.puedeEditar) {
            acc.appendChild(boton('mdi-pencil-outline', 'Editar fecha', '', function () {
                FECHAS.editando = f.token;
                cargarFechas();
            }));

            acc.appendChild(boton('mdi-trash-can-outline', 'Eliminar fecha', 'is-borrar', function () {
                /* Una fecha borrada por error no avisa: se nota recién cuando
                   el trabajo de ese día no aparece. */
                if (!confirmarBorrado('¿Eliminar la fecha ' + f.fecha + '?')) return;

                llamar('EliminarFecha', { token: f.token }, function (r) {
                    if (r.error) { avisar(r.detalle); return; }
                    cargarFechas();
                });
            }));
        }

        tr.appendChild(acc);
        return tr;
    }

    function filaEdicion(f) {
        var tr = document.createElement('tr');
        tr.className = 'is-editando';

        var inF = entrada(tr, 'Fecha', f.fecha, 'dd-mm-aaaa');
        celda(tr, f.dia, 'Día');
        var inH = entrada(tr, 'Hora', f.hora || '', 'HH:MM');

        var acc = document.createElement('td');
        acc.className = 'sg-tabla-acciones';

        function guardar() {
            llamar('GuardarFecha',
                   { datos: FECHAS.prog, token: f.token, fecha: inF.value, hora: inH.value },
                   function (r) {
                       if (r.error) { avisar(r.detalle); return; }

                       FECHAS.editando = '';
                       cargarFechas();
                   });
        }

        function cancelar() {
            FECHAS.editando = '';
            cargarFechas();
        }

        acc.appendChild(boton('mdi-check', 'Guardar', 'is-ok', guardar));
        acc.appendChild(boton('mdi-close', 'Cancelar', '', cancelar));

        /* Enter guarda, Escape cancela. Tener que buscar el botón con el
           mouse para cada fila es lo que hace lenta una tabla editable. */
        [inF, inH].forEach(function (e) {
            e.onkeydown = function (ev) {
                if (ev.keyCode === 13) { ev.preventDefault(); guardar(); }
                if (ev.keyCode === 27) { ev.preventDefault(); cancelar(); }
            };
        });

        tr.appendChild(acc);
        window.setTimeout(function () { inF.focus(); inF.select(); }, 30);

        return tr;
    }

    function entrada(tr, rotulo, valor, pista) {
        var td = document.createElement('td');
        td.setAttribute('data-rotulo', rotulo);

        var input = document.createElement('input');
        input.type = 'text';
        input.className = 'sg-input-linea';
        input.value = valor;
        input.placeholder = pista;
        input.setAttribute('aria-label', rotulo);

        td.appendChild(input);
        tr.appendChild(td);

        return input;
    }

    function boton(icono, titulo, clase, alHacerClic) {
        var a = document.createElement('a');
        a.href = '#';
        a.className = 'sg-icono-btn ' + (clase || '');
        a.title = titulo;
        a.setAttribute('aria-label', titulo);
        a.innerHTML = '<i class="mdi ' + icono + '"></i>';
        a.onclick = function (ev) { ev.preventDefault(); alHacerClic(); return false; };
        return a;
    }

    function conectarFechas() {
        var caja = document.getElementById('sgFechas');
        if (!caja) return;

        FECHAS.url = caja.getAttribute('data-url') || '';
        FECHAS.prog = caja.getAttribute('data-prog') || '';
        FECHAS.editando = '';

        if (!FECHAS.prog) {
            caja.innerHTML = '<div class="sg-vacio"><i class="mdi mdi-information-outline"></i>' +
                '<div>Guarde primero la programación: las fechas se agregan sobre una que ya existe.</div></div>';
            return;
        }

        conectarAgregarFecha();
        cargarFechas();
    }

    /* El botón Agregar conserva su OnClick de servidor —si el JS no corre,
       sigue funcionando por postback— pero acá se intercepta: agregar una
       fecha es una fila, no una razón para redibujar los seis pasos. */
    function conectarAgregarFecha() {
        var boton = document.querySelector('.sg-agregar-fecha');
        if (!boton) return;

        boton.onclick = function (ev) {
            ev.preventDefault();

            var campo = document.querySelector('.sg-nueva-fecha input[type="text"]');
            var fecha = campo ? (campo.value || '').trim() : '';

            if (!fecha) { avisar('Indique la fecha que quiere agregar.'); return false; }

            llamar('GuardarFecha',
                   { datos: FECHAS.prog, token: '', fecha: fecha, hora: horaNueva() },
                   function (r) {
                       if (r.error) { avisar(r.detalle); return; }

                       /* El campo se vacía: dejarlo con la fecha recién
                          agregada invita a apretar de nuevo y recibir un
                          "esa fecha ya está". */
                       if (campo) campo.value = '';

                       cargarFechas();
                   });

            return false;
        };
    }

    function horaNueva() {
        var v = comboValor('cboNuevaHora');
        return v || '';
    }

    /* ==================================================================
       LOS RESPONSABLES, CON SU CARA

       El combo decia "2 Seleccionados". Eso no dice QUIENES, que es justo lo
       que hay que poder revisar antes de guardar —y equivocarse de tecnico
       se descubre cuando la actividad lleva un mes sin ejecutarse—.

       Cada opcion del combo trae su foto y sus iniciales como atributos, asi
       que dibujar el chip no cuesta ninguna consulta extra.
       ================================================================== */
    var COMBO_PERSONAS = null;

    /* Telerik llama a esto al cargar el combo; se guarda la referencia para
       poder redibujar sin volver a buscarlo. */
    window.sgResponsablesCargado = function (combo) {
        COMBO_PERSONAS = combo;
        pintarPersonas();
    };

    window.sgResponsablesCambio = function () {
        pintarPersonas();
        if (typeof refrescar === 'function') refrescar();
    };

    function atributo(item, nombre) {
        try {
            var a = item.get_attributes();
            return (a && a.getAttribute(nombre)) || '';
        } catch (e) { return ''; }
    }

    function pintarPersonas() {
        var caja = document.getElementById('sgResponsablesChips');
        if (!caja || !COMBO_PERSONAS) return;

        var marcados = COMBO_PERSONAS.get_checkedItems();

        caja.innerHTML = '';

        if (!marcados || marcados.length === 0) {
            var v = document.createElement('span');
            v.className = 'sg-personas-vacio';
            v.textContent = 'Nadie asignado todavía.';
            caja.appendChild(v);
            return;
        }

        for (var i = 0; i < marcados.length; i++)
            caja.appendChild(chipPersona(marcados[i]));

        if (window.gsap)
            gsap.from(caja.children, {
                opacity: 0, scale: .85, duration: .22, stagger: .03,
                ease: 'back.out(2)', clearProps: 'transform,opacity'
            });
    }

    function chipPersona(item) {
        var chip = document.createElement('span');
        chip.className = 'sg-persona';

        var foto = atributo(item, 'data-foto');
        var iniciales = atributo(item, 'data-ini');
        var nombre = atributo(item, 'data-nombre') || item.get_text();

        var avatar;

        if (foto) {
            avatar = document.createElement('img');
            avatar.className = 'sg-persona-avatar';
            avatar.src = foto;
            avatar.alt = '';
        } else {
            /* Sin foto, las iniciales. El color sale del nombre y no al azar:
               asi la misma persona se ve siempre del mismo color y se la
               reconoce sin leer. */
            avatar = document.createElement('span');
            avatar.className = 'sg-persona-avatar is-inicial';
            avatar.textContent = iniciales || nombre.substring(0, 1).toUpperCase();
            avatar.style.backgroundColor = colorDe(item.get_value());
        }

        chip.appendChild(avatar);

        var txt = document.createElement('span');
        txt.className = 'sg-persona-nombre';
        txt.textContent = nombre;
        chip.appendChild(txt);

        var quitar = document.createElement('a');
        quitar.href = '#';
        quitar.className = 'sg-persona-x';
        quitar.title = 'Quitar a ' + nombre;
        quitar.setAttribute('aria-label', 'Quitar a ' + nombre);
        quitar.innerHTML = '&times;';

        quitar.onclick = function (ev) {
            ev.preventDefault();

            /* Se desmarca la casilla del combo, que es el dato: el chip es
               su cara, no la fuente. */
            item.set_checked(false);
            pintarPersonas();
            if (typeof refrescar === 'function') refrescar();
            return false;
        };

        chip.appendChild(quitar);
        return chip;
    }

    /* EL COLOR SALE DEL ID, NO DEL NOMBRE

       Antes se sumaban los códigos de las letras del nombre. Con los siete
       usuarios reales del cliente eso daba solo CUATRO colores: Marcela,
       Paula y Ximena salían las tres del mismo naranjo, y Emilio y Rodrigo
       del mismo celeste. Sumar letras es un hash malo —los anagramas chocan
       y los nombres parecidos caen cerca—, justo lo contrario de lo que se
       busca acá.

       El id es único por construcción y correlativo, así que cualquier grupo
       de personas consecutivas sale con colores distintos garantizados.

       Doce colores en vez de ocho: con ocho, el noveno usuario ya repetía. */
    var PALETA = ['#6C5CFF', '#0EA5E9', '#10B981', '#F59E0B',
                  '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6',
                  '#F97316', '#3B82F6', '#84CC16', '#A855F7'];

    function colorDe(id) {
        var n = parseInt(id, 10);

        /* Sin id utilizable —no debería pasar— se usa el primero en vez de
           devolver algo indefinido y dejar el avatar transparente. */
        if (isNaN(n) || n < 0) return PALETA[0];

        return PALETA[n % PALETA.length];
    }

    /* ------------------------------------------------------------------
       ARRANQUE
       ------------------------------------------------------------------ */
    function conectar() {
        raiz = document.querySelector('.sg-prog-modal');
        if (!raiz) return;

        var pasoActual = parseInt(valor('hfPaso'), 10) || 1;

        $$('.sg-paso').forEach(function (b, i) {
            b.onclick = function (ev) { ev.preventDefault(); irAlPaso(i + 1); return false; };
        });

        var ant = $('.sg-prog-nav .sg-btn-plano');
        var sig = $('.sg-prog-nav .sg-btn-secundario');

        if (ant) ant.onclick = function (ev) {
            ev.preventDefault();
            irAlPaso((parseInt(valor('hfPaso'), 10) || 1) - 1);
            return false;
        };

        if (sig) sig.onclick = function (ev) {
            ev.preventDefault();
            irAlPaso((parseInt(valor('hfPaso'), 10) || 1) + 1);
            return false;
        };

        var revisar = $('.sg-resumen-acciones .sg-btn-plano');
        if (revisar) revisar.onclick = function (ev) { ev.preventDefault(); irAlPaso(6); return false; };

        conectarDias();
        conectarFrecuencias();
        conectarAsignacion();
        conectarConmutadores();
        conectarFechas();

        /* El resumen responde al tipear, no solo al cambiar de paso: escribir
           el nombre tiene que apagar el aviso de "falta el nombre" en el
           momento, no cuando alguien decida avanzar. */
        $$('input[type="text"], textarea').forEach(function (e) {
            e.addEventListener('input', refrescar);
        });

        var f = $('.sg-seg.is-activa');
        if (f) aplicarFrecuencia((f.textContent || '').trim());

        irAlPaso(pasoActual);
    }

    if (document.readyState === 'loading')
        document.addEventListener('DOMContentLoaded', conectar);
    else
        conectar();

    /* Guardar y el cambio de instalación SÍ van al servidor. Al volver hay
       que reconectar: el HTML es nuevo y los manejadores se fueron con el
       anterior. */
    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(conectar);
    }
})();
