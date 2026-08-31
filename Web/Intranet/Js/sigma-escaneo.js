/* ============================================================================
   SIGMA — Escaneo con la cámara del teléfono
   ----------------------------------------------------------------------------

   DOS CAMINOS, Y LOS DOS TIENEN QUE FUNCIONAR

     1. La cámara del teléfono, por fuera de SIGMA. Desde iOS 11 y Android 9
        la app de cámara lee un QR sola: se apunta a la etiqueta, aparece un
        aviso y se toca. Como el QR guarda la URL COMPLETA, eso abre esta
        misma pantalla ya resuelta. No necesita permisos, ni HTTPS, ni esta
        pantalla abierta de antemano. Es el camino que siempre funciona.

     2. La cámara DENTRO de la pantalla, que es lo que hace este archivo. Es
        más cómodo para escanear varias etiquetas seguidas —no hay que salir
        y volver—, pero depende de dos cosas que pueden faltar.

   LAS DOS COSAS QUE PUEDEN FALTAR

     getUserMedia solo existe en un contexto seguro: HTTPS, o localhost. En
     HTTP plano el navegador no entrega la cámara y no hay forma de
     convencerlo.

     BarcodeDetector decodifica el QR sin biblioteca externa, pero hoy está
     en Chrome de Android y no en Safari de iPhone.

   POR QUE NO SE AGREGA UNA BIBLIOTECA JS DE DECODIFICACION

     Resolvería lo de iPhone, pero es una dependencia nueva de varios cientos
     de kB que hay que traer, versionar y mantener, para cubrir un caso que
     el camino 1 ya cubre bien: en iPhone la cámara nativa lee el QR y abre
     esta pantalla igual.

     Cuando algo falta, se dice cuál de los dos falta y qué hacer. Un botón
     que no responde y no explica nada es peor que no tener el botón.
   ============================================================================ */

var sigmaEscaneo = (function () {

    var video = null;
    var camara = null;
    var aviso = null;
    var boton = null;
    var flujo = null;
    var detector = null;
    var buscando = false;
    var ultimo = '';

    function elementos() {
        video = document.getElementById('escVideo');
        camara = document.getElementById('escCamara');
        aviso = document.getElementById('escAviso');
        boton = document.getElementById('escBtnCamara');
    }

    function decir(texto) {
        if (!aviso) return;
        aviso.innerHTML = texto;
        aviso.style.display = texto ? 'block' : 'none';
    }

    /* Se comprueba ANTES de pedir la cámara. Pedirla y que falle deja al
       usuario con un diálogo de permiso denegado y sin entender por qué. */
    function porQueNoSePuede() {
        if (!window.isSecureContext) {
            return 'Para usar la cámara desde aquí, SIGMA tiene que abrirse con ' +
                   '<strong>https</strong>. Mientras tanto: abra la cámara de su ' +
                   'teléfono, apúntela a la etiqueta y toque el aviso que aparece ' +
                   '— lleva a esta misma pantalla.';
        }

        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            return 'Este navegador no permite usar la cámara. Abra la cámara de su ' +
                   'teléfono y apúntela a la etiqueta.';
        }

        if (typeof window.BarcodeDetector === 'undefined') {
            return 'Este navegador no sabe leer códigos QR por su cuenta ' +
                   '(le pasa al iPhone). Abra la cámara de su teléfono, apúntela a ' +
                   'la etiqueta y toque el aviso que aparece: lleva a esta misma ' +
                   'pantalla.';
        }

        return '';
    }

    function iniciar() {
        elementos();

        var problema = porQueNoSePuede();
        if (problema) { decir(problema); return; }

        decir('');

        try {
            detector = new window.BarcodeDetector({ formats: ['qr_code'] });
        } catch (e) {
            decir('Este navegador no puede leer códigos QR. Use la cámara de su teléfono.');
            return;
        }

        /* facingMode environment es la cámara trasera. Sin esto el teléfono
           abre la frontal y el bodeguero termina apuntándose a la cara. */
        navigator.mediaDevices.getUserMedia({
            video: { facingMode: { ideal: 'environment' } },
            audio: false
        }).then(function (s) {
            flujo = s;
            video.srcObject = s;
            video.play();

            camara.style.display = 'block';
            boton.style.display = 'none';
            buscando = true;

            buscar();
        }).catch(function () {
            decir('No se pudo abrir la cámara. Puede que el permiso esté denegado ' +
                  'para este sitio. Revise los permisos del navegador, o use la ' +
                  'cámara de su teléfono directamente sobre la etiqueta.');
        });
    }

    function buscar() {
        if (!buscando) return;

        detector.detect(video).then(function (codigos) {
            if (codigos && codigos.length > 0) {
                var valor = codigos[0].rawValue;

                /* El mismo código leído treinta veces por segundo dispararía
                   treinta postbacks. Se ignora hasta que cambie. */
                if (valor && valor !== ultimo) {
                    ultimo = valor;
                    entregar(valor);
                    return;
                }
            }
            seguir();
        }).catch(function () {
            seguir();
        });
    }

    /* requestAnimationFrame y no un setInterval fijo: si la pestaña pasa a
       segundo plano el navegador lo detiene solo, y no se queda un teléfono
       decodificando vídeo dentro del bolsillo hasta agotar la batería. */
    function seguir() {
        if (buscando) window.requestAnimationFrame(buscar);
    }

    function entregar(valor) {
        detener();

        if (navigator.vibrate) navigator.vibrate(60);

        var campo = document.getElementById(sigmaEscaneo.idCampo);
        var disparo = document.getElementById(sigmaEscaneo.idBoton);

        if (!campo || !disparo) return;

        campo.value = valor;
        disparo.click();
    }

    function detener() {
        buscando = false;

        if (flujo) {
            var pistas = flujo.getTracks();
            for (var i = 0; i < pistas.length; i++) pistas[i].stop();
            flujo = null;
        }

        if (video) video.srcObject = null;
        if (camara) camara.style.display = 'none';
        if (boton) boton.style.display = '';
    }

    /* Si el usuario cambia de pestaña con la cámara abierta, se apaga: dejar
       la cámara tomando sin que nadie la mire es lo que hace que la gente
       desconfíe de una aplicación. */
    document.addEventListener('visibilitychange', function () {
        if (document.hidden && buscando) detener();
    });

    return {
        iniciar: iniciar,
        detener: detener,
        idCampo: '',
        idBoton: '',
        /* Tras un escaneo el resultado cambia; que el siguiente código igual
           al anterior vuelva a consultarse es correcto, así que se olvida. */
        olvidar: function () { ultimo = ''; }
    };
})();
