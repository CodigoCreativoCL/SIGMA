function validaFecha(obj) {
    var re = /^[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9][0-9][0-9]$/;
    if (obj.value != "") {
        if (!re.exec(obj.value)) {
            alert('Formanto No Valido (Ej. 01-01-2012)');
            obj.value = '';
        }
    }
}

function validaFecha2(text) {
    var re = /^[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9][0-9][0-9]$/;
    if (text != "") {
        if (!re.exec(text)) {
            alert('Formanto No Valido (Ej. 01-01-2012)');
            return false;
        }
    }
    return true;
}

function ValidaNumeros(obj) {
    var arreglo = /^[0-9]*(\,[0-9]+)?$/;
    if (obj.value != "") {
        if (!arreglo.exec(obj.value)) {
            obj.value = '';
            return false;
        }
    }
    return true;
}

function validaHoras(obj) {
    var arreglo = /^[0-9][0-9]$/;
    if (obj.value != "") {
        if (!arreglo.exec(obj.value)) {
            obj.value = '';
            return false;
        }
    }
    return true;
}

function validaHora(obj) {
    var arreglo = /^(0[0-9]|1\d|2[0-3]):([0-5]\d)$/;
    if (obj.value != "") {

        var txt = '';
        if (obj.value.length == 4) {
            var txtLeft = obj.value.substring(0, 2);
            var txtRigth = obj.value.substring(obj.value.length, 2);
            txt = txtLeft + ':' + txtRigth;
        }
        else {
            txt = obj.value;
        }

        if (arreglo.exec(txt)) {
            obj.value = txt;
            return true;
        }
        else {
            obj.value = '';
            obj.focus();
            return false;
        }
    }
    return true;
}

//valida Rut
function validarRut(ruti, dvi) {
    var valida = true;
    var rut = ruti + "-" + dvi;
    rut = rut.replace(/\./g, '');
    if (rut.length < 9)
        valida = false;
    //alert('Rut Incorrecto');

    i1 = rut.indexOf("-");
    dv = rut.substr(i1 + 1);
    dv = dv.toUpperCase();
    nu = rut.substr(0, i1);
    cnt = 0;
    suma = 0;
    for (i = nu.length - 1; i >= 0; i--) {
        dig = nu.substr(i, 1);
        fc = cnt + 2;
        suma += parseInt(dig) * fc;
        cnt = (cnt + 1) % 6;
    }
    dvok = 11 - (suma % 11);
    if (dvok == 11) dvokstr = "0";
    if (dvok == 10) dvokstr = "K";
    if ((dvok != 11) && (dvok != 10)) dvokstr = "" + dvok;

    if (dvokstr == dv) {
        return (true);
    }
    else {
        //alert('Dv Incorrecto');
        valida = false;
    }
}

//Formatea numero
function format(input) {
    var num = input.value.replace(/\./g, '');
    if (!isNaN(num)) {
        num = num.toString().split('').reverse().join('').replace(/(?=\d*\.?)(\d{3})/g, '$1.');
        num = num.split('').reverse().join('').replace(/^[\.]/, '');
        input.value = num;
    }
    else {
        alert('Solo se permiten numeros');
        input.value = input.value.replace(/[^\d\.]*/g, '');
    }
}

//Format Number Millones
function formatMillones(num1) {
    //var num = input.value.replace(/\./g, '');

    if (!isNaN(num1)) {
        num1 = num1.toString().split('').reverse().join('').replace(/(?=\d*\.?)(\d{3})/g, '$1.');
        num1 = num1.split('').reverse().join('').replace(/^[\.]/, '');
        return num1;
    }

    var num2 = num1.split(',');

    var num = num2[0];

    if (!isNaN(num)) {
        num = num.toString().split('').reverse().join('').replace(/(?=\d*\.?)(\d{3})/g, '$1.');
        num = num.split('').reverse().join('').replace(/^[\.]/, '');
        return num + ',' + num2[1];
    }
    else {
        alert('Solo se permiten numeros');
    }
}

// popup
function popup(url, w, h, name, winprops) {
    var winl = (screen.width - w) / 2;
    var wint = ((screen.height - h) / 2) - 30;
    winprops = winprops + ',height=' + h + ',width=' + w + ',top=' + wint + ',left=' + winl + ''
    win = window.open(url, name, winprops)
    if (parseInt(navigator.appVersion) >= 4) { win.window.focus(); }
}


//Validacion de Texbox y ComboBox
function validaControl(sender, args) {

    var ctrlTelerik = $find(sender.controltovalidate);
    if (ctrlTelerik != null) {

        //RadComboBox
        if (ctrlTelerik._dropDownElement) {
            var combobox = $find(sender.controltovalidate);
            var value = false;

            var items = ctrlTelerik.get_items()

            items.forEach(function (item) {

                if (args.Value == item.get_text()) {
                    if (item.get_value() != "")
                        value = true;
                }

            });

            if (value == true) {
                args.IsValid = true;
                combobox._element.style.border = "";
            }
            else {
                args.IsValid = false;
                combobox._element.style.border = "solid 1px red";
            }
        }

        //RadNumeric
        if (ctrlTelerik._textBoxElement) {

            if (ctrlTelerik.get_value() != "" | ctrlTelerik.get_value() == "0") {
                args.IsValid = true;
                ctrlTelerik._textBoxElement.className = "form-control";
            }
            else {
                args.IsValid = false;
                ctrlTelerik._textBoxElement.className = "ErrorControl";
            }
        }

        //RadTimePicker2
        if (ctrlTelerik._dateInput) {

            if (ctrlTelerik.get_selectedDate() != null) {
                args.IsValid = true;
                $(".RadPicker.RadTimePicker.RadPicker_Bootstrap.ErrorControl").removeClass("ErrorControl");
            }
            else {
                args.IsValid = false;
                $(".RadPicker.RadTimePicker.RadPicker_Bootstrap").addClass("ErrorControl");
            }
        }

        ////Calendar
        //if (ctrlTelerik._calendar) {

        //    if (ctrlTelerik.get_value() != "" | ctrlTelerik.get_value() == "0") {
        //        args.IsValid = true;
        //        ctrlTelerik._textBoxElement.className = "form-control";
        //    }
        //    else {
        //        args.IsValid = false;
        //        ctrlTelerik._textBoxElement.className = "ErrorControl";
        //    }
        //}

    }
    else {

        var ctrl = document.getElementById(sender.controltovalidate);

        if (ctrl.type == "text") {
            if ($(ctrl).attr('calendar') != null) {
                var fechaSplit = ctrl.value.split('-')
                var fecha = new Date(fechaSplit[1] + '/' + fechaSplit[0] + '/' + fechaSplit[2]);
                var fechaMenor = new Date('01/01/1900');
                var fechaMayor = new Date('01/01/3000');
                if (fecha < fechaMenor || fecha > fechaMayor) {
                    ctrl.value = '';
                    args.IsValid = false;
                    ctrl.className = "ErrorControl";
                }
            }
            //if (ctrl.value != "") {

            //    args.IsValid = true;
            //    ctrl.classList.remove("ErrorControl");

            //} else {

            //    args.IsValid = false;
            //    ctrl.classList.add("ErrorControl");
            //}
        }


        //Textbox
        if (ctrl.type == "text") {
            if (ctrl.value != "") {

                args.IsValid = true;
                ctrl.classList.remove("ErrorControl");
            } else {

                args.IsValid = false;
                ctrl.classList.add("ErrorControl");
            }
        }

        //TextArea
        if (ctrl.type == "textarea") {
            if (ctrl.value != "") {

                args.IsValid = true;
                ctrl.classList.remove("ErrorControl");

            } else {

                args.IsValid = false;
                ctrl.classList.add("ErrorControl");
            }
        }


        //ValidaComboBox
        if (ctrl.type == "select-one") {
            if ($(ctrl).val() == "") {
                args.IsValid = false;
                ctrl.classList.add("ErrorControl");
            }
            else {
                args.IsValid = true;
                ctrl.classList.remove("ErrorControl");
            }
        }

    }
}

//RadGrid
function RowSelecting(sender, args) {
    //get the input check box
    var id = args.get_id();
    var inputCheckBox = $get(id).getElementsByTagName("input")[0];

    if (inputCheckBox) {
        if (inputCheckBox.disabled) {
            //cancel selection
            args.set_cancel(true);
        }
    }
}

// Centrar Popup RadGrid
function PopUpShowing(sender, eventArgs) {
    var popUp;
    popUp = eventArgs.get_popUp();
    var gridWidth = sender.get_element().offsetWidth;
    var gridHeight = sender.get_element().offsetHeight;
    var popUpWidth = popUp.style.width.substr(0, popUp.style.width.indexOf("px"));
    var popUpHeight = popUp.style.height.substr(0, popUp.style.height.indexOf("px"));
    popUp.style.left = ((gridWidth - popUpWidth) / 2 + sender.get_element().offsetLeft).toString() + "px";
    popUp.style.top = ((gridHeight - popUpHeight) / 2 + sender.get_element().offsetTop).toString() + "px";
}

function onfocusTexBox(ctrl, entrada) {
    if (entrada)
        ctrl.className = "form-control";
    else
        ctrl.className = "form-control";
}

function ValidaEmail(email) {
    var regex = /[\w-\.]{3,}@([\w-]{2,}\.)*([\w-]{2,}\.)[\w-]{2,4}/;
    return regex.test(email);
}


//*** Inicio Telerik RadWindows Bloquea Scroll y Centra Modal Paginas******
var oWin = null;

function bloqueaScroll(obj) {
    if (!obj)
        $('html,body').addClass("no_scroll");
    else {
        $('html,body').removeClass("no_scroll");
        oWin = null;
    }
}

$(window).resize(function () {
    if (oWin != null)
        OnModal();
});

function Maximiza(sender, args) {
    sender.maximize();
}

function OnClientActivate(sender) {
    oWin = sender;

    //Agrego como atribito los tamaño originales
    var bounds = oWin.getWindowBounds();

    //Obtengo ancho y alto del modal
    var Wwidth = bounds.width;
    var Wheight = bounds.height;

    //Si no trae ancho y alto (trae por defecto 298) se maximiza la ventana en un 95% de la vista
    if (Wwidth == "298" && Wheight == "298") {

        //Obtengo resolucion Actual
        var width = $(window).width();
        var height = $(window).height();

        //Seteo los nuevos tamaños
        var newWidth = Math.round(((parseInt(width) / 100) * 95));
        var newHeight = Math.round(((parseInt(height) / 100) * 95));

        //Asigno el nuevo valor al modal
        oWin.setSize(newWidth, newHeight);

    }
    //Seteo la posicion en el centro
    var position = "center";
    oWin[position]();
}

function OnClientShow(sender) {
    bloqueaScroll(false);
    oWin = sender;
    OnModal();

    /* El iframe de Telerik termina de medir su contenido despues de Show.
       Un segundo centrado evita que la ventana quede corrida al completarse
       ese layout asincrono. */
    window.setTimeout(function () {
        if (oWin && (!oWin.isVisible || oWin.isVisible())) OnModal();
    }, 80);
}

function OnModal() {

    if (!oWin) return;

    //Obtengo los tamaños originales
    var winWidth = $("#" + oWin.get_id()).attr("widthOriginal");
    var winHeight = $("#" + oWin.get_id()).attr("heightOriginal");

    /* Algunas versiones del control no imprimen widthOriginal/heightOriginal.
       Se toma entonces el primer tamano declarado por la pagina y se guarda,
       para que redimensionar el navegador no convierta todos los formularios
       en ventanas al 95% sin necesidad. */
    var bounds = oWin.getWindowBounds ? oWin.getWindowBounds() : null;
    var originalWidth = parseInt(winWidth, 10);
    var originalHeight = parseInt(winHeight, 10);

    if (isNaN(originalWidth) && bounds) originalWidth = parseInt(bounds.width, 10);
    if (isNaN(originalHeight) && bounds) originalHeight = parseInt(bounds.height, 10);

    //Obtengo resolucion Actual
    var width = $(window).width();
    var height = $(window).height();

    var maxWidth = Math.max(320, Math.round(parseInt(width, 10) * 0.95));
    var maxHeight = Math.max(420, Math.round(parseInt(height, 10) * 0.95));
    var newWidth = isNaN(originalWidth) ? maxWidth : Math.min(originalWidth, maxWidth);
    var newHeight = isNaN(originalHeight) ? maxHeight : Math.min(originalHeight, maxHeight);

    oWin.setSize(newWidth, newHeight);
    oWin.center();
}

function soloLetras(e) {
    var key = e.keyCode || e.which,
        tecla = String.fromCharCode(key).toLowerCase(),
        letras = " áéíóúabcdefghijklmnñopqrstuvwxyz",
        especiales = [8, 37, 39, 46],
        tecla_especial = false;

    for (var i in especiales) {
        if (key == especiales[i]) {
            tecla_especial = true;
            break;
        }
    }

    if (letras.indexOf(tecla) == -1 && !tecla_especial) {
        return false;
    }
}
//***Fin  Telerik RadWindows Bloquea Scroll y Centra Modal Paginas******


//***Inicio SweetAlert******
function AlertSweet(titulo, mensaje, tipo) {

    $("#myAlertSweet").remove();

    var icono = '';

    switch (tipo) {
        case "error":
            icono = '<div class="sa"><div class="sa-error"><div class="sa-error-x"><div class="sa-error-left"></div><div class="sa-error-right"></div></div><div class="sa-error-placeholder"></div><div class="sa-error-fix"></div></div></div>';
            break;
        case "ok":
            icono = '<div class="sa"><div class="sa-success"><div class="sa-success-tip"></div><div class="sa-success-long"></div><div class="sa-success-placeholder"></div><div class="sa-success-fix"></div></div></div>';
            break;
        case "alerta":
            icono = '<div class="sa"><div class="sa-warning"><div class="sa-warning-body"></div><div class="sa-warning-dot"></div></div></div>';
            break;
    }

    var modal = '';

    modal += '<div class="modal fade" id="myAlertSweet" role ="dialog" data-backdrop="static" data-keyboard="false">';
    modal += '   <div class="modal-dialog">';
    modal += '       <div class="modal-content">';
    modal += '           <div class="modal-header">';
    modal += '               ' + icono + ' ';
    modal += '               <h4 class="modal-title"></h4>';
    modal += '           </div>';
    modal += '           <div class="modal-body">';
    modal += '               <div style="font-size:26px; color:black;">';
    modal += '                   <b><p>' + titulo + '</p></b>';
    modal += '               </div>';
    modal += '               <div style="font-size:12px;">';
    modal += '                   <b><p>' + mensaje + '</p></b>';
    modal += '               </div>';
    modal += '           </div>';
    modal += '           <div class="modal-footer">';
    modal += '               <button type="button" class="ButtonSweetAlert" onclick="AlertSweetCloseWindows()">Aceptar</button>';
    modal += '           </div>';
    modal += '       </div>'
    modal += '   </div>';
    modal += '</div>';

    $("body").append(modal);
    $("#myAlertSweet").modal();

}

function AlertSweetCloseWindows() {
    $('#myAlertSweet').modal('hide');
}

var objSweetAlert = { status: false, ele: null };
function ConfirSweetAlert(btn, Titulo, Mensaje) {

    if (objSweetAlert.status) {
        objSweetAlert.status = false;
        return true;
    };

    Swal.fire({
        title: Titulo,
        text: Mensaje,
        type: 'question',
        showCancelButton: true,
        cancelButtonColor: '#f8f8f8',
        cancelButtonText: 'Cancelar',
        confirmButtonColor: '#10c469',
        confirmButtonText: '&nbsp &nbsp &nbsp SI &nbsp &nbsp &nbsp'
    }).then(function (result) {
        if (result.value) {
            objSweetAlert.status = true;
            objSweetAlert.ele.click();
        }
    });

    objSweetAlert.ele = btn;
    return false;
}
//***Fin SweetAlert******

