/* ============================================================================
   SIGMA — Animaciones del Centro de Acción Operacional
   ----------------------------------------------------------------------------

   QUÉ ANIMA Y POR QUÉ

     Los gráficos de esta pantalla se dibujan en el servidor, ya terminados.
     Lo que agrega este archivo no es el dibujo sino el RECORRIDO: el anillo
     barre hasta su porcentaje, la curva se traza de izquierda a derecha, el
     número sube hasta su valor.

     No es adorno. Un 87% que aparece de golpe es un dato; un 87% al que se
     llega barriendo deja ver de dónde viene y cuánto falta para el borde.

   NO INVENTA NINGÚN VALOR

     Toda animación termina exactamente en lo que el servidor pintó, y lee su
     destino del propio SVG. Si GSAP no carga —o si la persona pidió menos
     movimiento— la pantalla queda con los gráficos completos y correctos:
     esto se degrada a nada, nunca a un gráfico a medio dibujar.

   VUELVE A CORRER DESPUÉS DE CADA POSTBACK

     La pantalla vive dentro de un UpdatePanel. Cada vez que se cambia de
     pestaña o se abre otra alerta, el HTML se reemplaza y los elementos
     animados son OTROS. Sin engancharse a `endRequest`, todo esto animaría
     una sola vez —la primera— y después nunca más.
   ============================================================================ */
(function () {
    'use strict';

    /* Quien pidió menos movimiento en su sistema operativo lo pidió en serio:
       para muchas personas el movimiento no es un gusto sino un mareo. */
    function movimientoReducido() {
        return !!(window.matchMedia &&
                  window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    }

    function listo() {
        return !!window.gsap && !movimientoReducido();
    }

    /* Una sola vez por elemento. Tras un refresco parcial los nodos son
       nuevos y la marca viene limpia, que es justo lo que se quiere; pero si
       el UpdatePanel repinta solo una parte, lo que ya se animó se queda
       quieto en vez de volver a saltar. */
    function nuevo(el) {
        if (!el || el.getAttribute('data-anim') === '1') return false;
        el.setAttribute('data-anim', '1');
        return true;
    }

    function todos(sel) {
        return Array.prototype.slice.call(document.querySelectorAll(sel));
    }

    /* ------------------------------------------------------------------
       Trazar una línea: se recorta con su propio largo y se va soltando.
       ------------------------------------------------------------------ */
    function trazar(el, duracion, retraso) {
        var largo;

        /* getTotalLength no existe en todos los navegadores para polyline.
           Si no está, no se anima esa línea y se deja dibujada: media línea
           permanente sería peor que ninguna animación. */
        try { largo = el.getTotalLength(); } catch (e) { return; }
        if (!largo || !isFinite(largo)) return;

        gsap.set(el, { strokeDasharray: largo, strokeDashoffset: largo });
        gsap.to(el, {
            strokeDashoffset: 0,
            duration: duracion,
            delay: retraso || 0,
            ease: 'power2.out'
        });
    }

    /* ------------------------------------------------------------------
       LOS CINCO INDICADORES
       ------------------------------------------------------------------ */
    function tarjetas() {
        var cajas = todos('.sg-kpi').filter(nuevo);
        if (!cajas.length) return;

        gsap.from(cajas, {
            y: 14,
            opacity: 0,
            duration: 0.45,
            stagger: 0.06,
            ease: 'power2.out',
            clearProps: 'transform,opacity'
        });

        /* El icono entra un pelo después que su tarjeta, no a la vez: así se
           lee como parte de ella y no como una segunda cosa que aparece. */
        cajas.forEach(function (caja, i) {
            var icono = caja.querySelector('.sg-kpi-icono');
            if (icono) {
                gsap.from(icono, {
                    scale: 0.6,
                    opacity: 0,
                    duration: 0.4,
                    delay: 0.08 + i * 0.06,
                    ease: 'back.out(2)',
                    clearProps: 'transform,opacity'
                });
            }

            var linea = caja.querySelector('.sg-spark polyline');
            if (linea) trazar(linea, 0.9, 0.15 + i * 0.06);
        });

        /* El número sube hasta el suyo. Se lee del DOM y se vuelve a escribir
           igual al terminar, así que el valor final es exactamente el que
           mandó el servidor. */
        cajas.forEach(function (caja, i) {
            var celda = caja.querySelector('.sg-kpi-valor');
            if (!celda) return;

            var destino = parseInt(celda.textContent, 10);
            if (isNaN(destino) || destino <= 0) return;

            var estado = { v: 0 };
            gsap.to(estado, {
                v: destino,
                duration: 0.7,
                delay: 0.1 + i * 0.06,
                ease: 'power2.out',
                onUpdate: function () { celda.textContent = Math.round(estado.v); },
                onComplete: function () { celda.textContent = destino; }
            });
        });
    }

    /* ------------------------------------------------------------------
       EL ANILLO DE PROBABILIDAD

       El destino sale del propio stroke-dasharray que pintó el servidor: la
       animación no decide el porcentaje, solo el camino hasta él.
       ------------------------------------------------------------------ */
    function anillo() {
        todos('.sg-anillo').filter(nuevo).forEach(function (caja) {
            var arcos = caja.querySelectorAll('.sg-anillo-svg circle');
            if (arcos.length < 2) return;

            var arco = arcos[arcos.length - 1];
            var dash = arco.getAttribute('stroke-dasharray');
            if (!dash) return;

            var partes = dash.split(/[\s,]+/);
            var pintado = parseFloat(partes[0]);
            var total = parseFloat(partes[1]);
            if (!isFinite(pintado) || !isFinite(total)) return;

            var estado = { v: 0 };
            gsap.to(estado, {
                v: pintado,
                duration: 1.1,
                ease: 'power2.inOut',
                onUpdate: function () {
                    arco.setAttribute('stroke-dasharray', estado.v + ' ' + total);
                },
                onComplete: function () {
                    arco.setAttribute('stroke-dasharray', pintado + ' ' + total);
                }
            });

            var texto = caja.querySelector('.sg-anillo-txt .n');
            if (texto) {
                var destino = parseInt(texto.textContent, 10);

                if (!isNaN(destino)) {
                    var n = { v: 0 };
                    gsap.to(n, {
                        v: destino,
                        duration: 1.1,
                        ease: 'power2.inOut',
                        onUpdate: function () { texto.textContent = Math.round(n.v) + '%'; },
                        onComplete: function () { texto.textContent = destino + '%'; }
                    });
                }
            }
        });
    }

    /* ------------------------------------------------------------------
       LA CURVA DE RIESGO

       Se traza y el área sube detrás. El orden importa: si el relleno
       apareciera primero, la línea llegaría a un dibujo ya hecho.
       ------------------------------------------------------------------ */
    function curva() {
        todos('.sg-curva-svg').filter(nuevo).forEach(function (svg) {
            var area = svg.querySelector('polygon');
            var linea = svg.querySelector('polyline');

            if (linea) trazar(linea, 1.2, 0.1);

            if (area) {
                gsap.from(area, {
                    opacity: 0,
                    duration: 0.9,
                    delay: 0.45,
                    ease: 'power1.out',
                    clearProps: 'opacity'
                });
            }
        });
    }

    /* ------------------------------------------------------------------
       EL PANEL DE SIGMA AI Y EL DETALLE

       Cuando se abre otra alerta el detalle se reemplaza entero. Sin esto el
       cambio es instantáneo y no se alcanza a notar que cambió: la persona
       cree que sigue mirando la anterior.
       ------------------------------------------------------------------ */
    function detalle() {
        todos('.sg-detalle').filter(nuevo).forEach(function (caja) {
            gsap.from(caja, {
                opacity: 0,
                y: 10,
                duration: 0.35,
                ease: 'power2.out',
                clearProps: 'transform,opacity'
            });
        });

        todos('.sg-ai-tarjeta').filter(nuevo).forEach(function (t, i) {
            gsap.from(t, {
                opacity: 0,
                y: 12,
                duration: 0.4,
                delay: i * 0.07,
                ease: 'power2.out',
                clearProps: 'transform,opacity'
            });
        });

        /* Los factores entran uno detrás de otro: son una lista ordenada por
           cuánto pesan, y verlos aparecer en ese orden lo dice sin escribirlo. */
        var factores = todos('.sg-factor').filter(nuevo);

        if (factores.length) {
            gsap.from(factores, {
                opacity: 0,
                x: -10,
                duration: 0.35,
                stagger: 0.06,
                delay: 0.15,
                ease: 'power2.out',
                clearProps: 'transform,opacity'
            });
        }

        /* La línea de tiempo se arma en orden cronológico, que es como se lee. */
        var hitos = todos('.sg-hito').filter(nuevo);

        if (hitos.length) {
            gsap.from(hitos, {
                opacity: 0,
                y: 8,
                duration: 0.3,
                stagger: 0.05,
                ease: 'power2.out',
                clearProps: 'transform,opacity'
            });
        }
    }

    /* ------------------------------------------------------------------
       LA MARCA Y EL INDICADOR DE MONITOREO
       ------------------------------------------------------------------ */
    function marca() {
        todos('.sg-ai-logo, .sg-ai-riesgo-card .sg-ai-icono').filter(nuevo)
            .forEach(function (img) {
                gsap.from(img, {
                    opacity: 0,
                    scale: 0.85,
                    duration: 0.5,
                    ease: 'back.out(1.7)',
                    clearProps: 'transform,opacity'
                });
            });

        /* El punto de "monitoreo en tiempo real" late despacio y para siempre:
           es lo único de la pantalla que afirma algo sobre AHORA, y quieto
           parece una etiqueta impresa en vez de un estado. */
        todos('.sg-cao-vivo-icono').filter(nuevo).forEach(function (icono) {
            gsap.to(icono, {
                opacity: 0.45,
                duration: 1.1,
                repeat: -1,
                yoyo: true,
                ease: 'sine.inOut'
            });
        });
    }

    /* ------------------------------------------------------------------
       LA COLA DE ALERTAS
       ------------------------------------------------------------------ */
    function cola() {
        var filas = todos('.sg-cola-lista .sg-alerta-cuerpo').filter(nuevo);
        if (!filas.length) return;

        /* Solo las primeras. Con cincuenta alertas, escalonarlas todas deja a
           la última entrando tres segundos después: eso ya no es una
           animación, es una espera. */
        gsap.from(filas.slice(0, 12), {
            opacity: 0,
            y: 8,
            duration: 0.3,
            stagger: 0.04,
            ease: 'power2.out',
            clearProps: 'transform,opacity'
        });
    }

    function animar() {
        if (!listo()) return;

        try {
            tarjetas();
            anillo();
            curva();
            detalle();
            marca();
            cola();
        } catch (e) {
            /* Una animación que falla no puede llevarse la pantalla con ella:
               los datos ya están dibujados y son lo que importa. */
            if (window.console && console.warn) console.warn('SIGMA animaciones:', e);
        }
    }

    window.sigmaAnimar = animar;

    if (document.readyState === 'loading')
        document.addEventListener('DOMContentLoaded', animar);
    else
        animar();

    /* Y de nuevo después de cada refresco parcial: cambiar de pestaña o abrir
       otra alerta reemplaza el HTML, y los elementos a animar son otros. */
    if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
        Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {
            animar();
        });
    }
})();
