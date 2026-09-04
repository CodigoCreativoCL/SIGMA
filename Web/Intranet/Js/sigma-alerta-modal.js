/* ============================================================================
   SIGMA - El aviso de ClientAlert

   EL PROBLEMA

     `Tools.tools.ClientAlert(mensaje, tipo)` -359 llamadas en el sitio- arma
     el HTML del aviso y termina con:

         $("#myModal").modal();

     `.modal()` es el plugin de BOOTSTRAP. Y ninguno de los dos masters carga
     Bootstrap JS: cargan su CSS, pero el bundle de JavaScript no esta ni en
     la carpeta de Adminto -solo estan sus plugins sueltos-.

     O sea que esa linea lanzaba `TypeError: $(...).modal is not a function`,
     el script moria ahi y el aviso NUNCA aparecia. En ninguna pantalla. Por
     eso guardar algo que fallaba se sentia como que el boton no hacia nada:
     el error estaba, pero nadie lo mostraba.

   POR QUE UN SUSTITUTO Y NO CARGAR BOOTSTRAP

     Traer Bootstrap JS entero para una funcion agrega un plugin que compite
     con el modal propio de SIGMA -los dos manejan foco, scroll del body y
     tecla Escape- y arrastra su carrusel, sus tooltips y sus dropdowns, que
     nadie usa aca.

     `.modal()` en este sitio solo necesita hacer dos cosas: mostrar y
     esconder. Eso es lo que hay abajo.

   NO PISA NADA

     Solo se define si no existe. El dia que alguien cargue Bootstrap de
     verdad, este archivo se aparta solo.
   ============================================================================ */
(function (window) {
    'use strict';

    var $ = window.jQuery;

    if (!$ || !$.fn || $.fn.modal) return;

    function esconder($caja) {
        $caja.removeClass('sg-aviso-abierto');

        /* Se saca del DOM: `ClientAlert` hace `$("#myModal").remove()` antes
           de crear el siguiente, pero si dos avisos llegan seguidos el
           primero podria quedar tapando la pantalla con su fondo. */
        window.setTimeout(function () { $caja.remove(); }, 180);

        if (!$('.sg-aviso-abierto').length)
            $('body').removeClass('sg-aviso-bloqueado');
    }

    $.fn.modal = function (accion) {
        var $caja = this;

        if (accion === 'hide') {
            esconder($caja);
            return this;
        }

        $caja.addClass('sg-aviso-abierto');
        $('body').addClass('sg-aviso-bloqueado');

        /* Cerrar tocando fuera. El aviso de ClientAlert siempre trae su boton
           Aceptar, asi que esto es un atajo, no la unica salida. */
        $caja.on('click', function (e) {
            if (e.target === $caja[0]) esconder($caja);
        });

        /* Y con Escape, como cualquier dialogo. */
        $(document).on('keydown.sgAviso', function (e) {
            if (e.keyCode !== 27) return;
            $(document).off('keydown.sgAviso');
            esconder($caja);
        });

        /* El foco al boton: quien viene del teclado no tiene que buscarlo, y
           quien viene del mouse ve cual es la accion. */
        window.setTimeout(function () {
            var b = $caja.find('.modal-footer button')[0];
            if (b && b.focus) b.focus();
        }, 60);

        return this;
    };
})(window);
