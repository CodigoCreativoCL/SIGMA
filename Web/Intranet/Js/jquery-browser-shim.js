/* =============================================================
   SIGMA — $.browser para jQuery UI 1.8
   =============================================================
   EL PROBLEMA
     El sitio carga jQuery 1.9.1 y jQuery UI 1.8rc3 (de 2010). jQuery
     1.9 ELIMINO $.browser, y jQuery UI 1.8 lo usa sin comprobarlo:

       Uncaught TypeError: Cannot read properties of undefined
                           (reading 'mozilla')

     Ese error se repetia decenas de veces por pagina y dejaba a jQuery
     UI a medio inicializar: lo que fallaba despues de la excepcion
     simplemente no se registraba.

   POR QUE UN SHIM Y NO ACTUALIZAR JQUERY UI
     Porque de 1.8 a 1.13 cambian nombres de opciones, marcado generado
     y clases CSS, y hay pantallas heredadas que nunca se probaron en
     navegador. Cambiar la libreria a ciegas para arreglar un error de
     consola es cambiar un problema visible por uno que aparece en
     produccion.

     Esto es exactamente lo que hace jQuery Migrate, reducido a la unica
     propiedad que hace falta. Se carga ENTRE jquery y jquery-ui.

   CUANDO SE BORRA
     El dia que se suba jQuery UI a una version que no use $.browser.
     Anotado en el MD.
   ============================================================= */

(function (jq) {
    'use strict';

    if (!jq || jq.browser) return;

    var ua = navigator.userAgent.toLowerCase();

    // El mismo reconocimiento que hacia jQuery 1.8, con el mismo orden:
    // Chrome se anuncia como Safari, asi que webkit va antes que safari,
    // y opera antes que todo porque se disfraza de los demas.
    var match =
        /(chrome)[ \/]([\w.]+)/.exec(ua) ||
        /(webkit)[ \/]([\w.]+)/.exec(ua) ||
        /(opera)(?:.*version|)[ \/]([\w.]+)/.exec(ua) ||
        /(msie) ([\w.]+)/.exec(ua) ||
        /(trident)(?:.*rv:([\w.]+))/.exec(ua) ||
        (ua.indexOf('compatible') < 0 && /(mozilla)(?:.*? rv:([\w.]+)|)/.exec(ua)) ||
        [];

    var nombre = match[1] || '';
    var version = match[2] || '0';

    // jQuery UI pregunta por .msie; Trident es IE 11, que dejo de decirlo.
    if (nombre === 'trident') nombre = 'msie';

    // Y pregunta por .webkit, que Chrome tambien es.
    var browser = {};

    browser[nombre] = true;
    browser.version = version;

    if (nombre === 'chrome') browser.webkit = true;
    if (nombre === 'webkit') browser.safari = true;

    jq.browser = browser;
})(window.jQuery);
