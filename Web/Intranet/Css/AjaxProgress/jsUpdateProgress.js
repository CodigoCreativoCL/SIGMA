Sys.WebForms.PageRequestManager.getInstance().add_beginRequest(beginReq);
Sys.WebForms.PageRequestManager.getInstance().add_endRequest(endReq);

var intervaloModalTiempoCarga;

/* EL VELO SOLO CUANDO LA ESPERA SE NOTA

   Se mostraba al empezar CUALQUIER ida al servidor. Con las pantallas nuevas
   -elegir un paso, cambiar de filtro, abrir una evidencia- la respuesta llega
   en decimas, asi que el velo alcanzaba a dibujarse y a irse: un parpadeo de
   pantalla completa que parecia una recarga.

   Ahora se agenda para 600 ms despues y se cancela si la respuesta llego
   antes. Las operaciones largas -una carga masiva, un informe- lo siguen
   mostrando con su cronometro, que es para lo que estaba. */
var esperaModal = null;

function beginReq(sender, args) {
    clearTimeout(esperaModal);

    /* SIN VELO EN LAS PANTALLAS QUE SE SIENTEN COMO UNA APLICACION
       El modulo de activos (centro, fichas y sus pestañas) cambia de
       pestaña y de vista sin recargar: un velo de pantalla completa lo hace
       ver pegado. La pagina lo apaga con window.SIGMA_SIN_VELO = true. */
    if (window.SIGMA_SIN_VELO) return;

    esperaModal = setTimeout(function () {
        $find(ModalProgress).show();

        $('.tiempoCarga').show();

        $('#lblModalMinutos').html("0");
        $('#lblModalSegundos').html("0");

        clearInterval(intervaloModalTiempoCarga);
        intervaloModalTiempoCarga = setInterval(ModalTiempoCargaSegundos, 1000);
    }, 600);
}

function endReq(sender, args) {
    clearTimeout(esperaModal);

    $find(ModalProgress).hide();
    clearInterval(intervaloModalTiempoCarga);

    $('#lblMinutos').html($('#lblModalMinutos').html());
    $('#lblSegundos').html($('#lblModalSegundos').html());
}

// Calcula tiempo de carga cuando ejecuto ajax
function ModalTiempoCargaSegundos() {
    
    var lblModalSegundos = $('#lblModalSegundos');
    var segundos = parseInt(lblModalSegundos.html()) + 1;

    if (segundos > 59) {
        lblModalSegundos.html('0');

        ModalTiempoCargaMinutos();

    }
    else {
        lblModalSegundos.html(segundos);
    }
}

function ModalTiempoCargaMinutos() {
    var lblModalMinutos = $('#lblModalMinutos');
    var ModalMinutos = (parseInt(lblModalMinutos.html()) + 1);

    lblModalMinutos.html(ModalMinutos);
}
// Calcula tiempo de carga cuando ejecuto ajax


//Obtengo el tiempo de carga la primera vez que entro a la página.
var beforeload = (new Date()).getTime();

function getPageLoadTime() {
    //Otengo el tiempo de inicio.
    var hdfTiempoCargaInicial = $('#ctl00_hdfTiempoCargaInicial').val();
    var hdfTiempoCargaFinal = $('#ctl00_hdfTiempoCargaFinal').val();

    var tiempoInicio = new Date(hdfTiempoCargaInicial); 

    //Obtengo el tiempo de termino de carga.
    var tiempoTermino = new Date(hdfTiempoCargaFinal); 
    //Calculo la diferencia entre el tiempo de inicio y el de termino.
    var tiempoCarga = new Date((tiempoTermino - tiempoInicio));

    $('#lblMinutos').html(tiempoCarga.getMinutes());
    $('#lblSegundos').html(tiempoCarga.getSeconds());
}

window.onload = getPageLoadTime;
//Obtengo el tiempo de carga la primera vez que entro a la página.