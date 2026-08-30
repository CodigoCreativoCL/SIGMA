Sys.WebForms.PageRequestManager.getInstance().add_beginRequest(beginReq);
Sys.WebForms.PageRequestManager.getInstance().add_endRequest(endReq);

var intervaloModalTiempoCarga;

function beginReq(sender, args) {
    // shows the Popup "ctl00_ModalProgress"
    $find(ModalProgress).show();

    $('.tiempoCarga').show();

    var lblModalMinutos = $('#lblModalMinutos');
    var lblModalSegundos = $('#lblModalSegundos');

    lblModalMinutos.html("0");
    lblModalSegundos.html("0");
    
    intervaloModalTiempoCarga = setInterval(ModalTiempoCargaSegundos, 1000);
    
}

function endReq(sender, args) {
	//  shows the Popup 
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