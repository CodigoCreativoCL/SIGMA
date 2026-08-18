// =====================================================================
// Overlay de "generando informe" — compartido por las pantallas de detalle
// (Checklist, Bitácora, Tareas, Órdenes de Trabajo).
//
// Se construye por JS y con estilos en línea a propósito: así cada .ascx
// solo referencia este archivo, sin repetir el markup ni depender de un CSS
// distinto por módulo (cada detalle carga su propia hoja).
//
// Cierre: la descarga NO recarga la página (el servidor cierra la petición
// con el archivo), así que no hay evento de "terminó" al que engancharse.
// El servidor deja la cookie ckdPdfListo justo antes de enviar el binario y
// acá se consulta hasta verla. Un temporizador fijo se queda corto con
// registros pesados o deja el overlay puesto de más.
// =====================================================================
var _ckdTimerDescarga = null;

function ckdCrearOverlayDescarga() {
    var ov = document.getElementById('ckdOverlayPdf');
    if (ov) return ov;

    ov = document.createElement('div');
    ov.id = 'ckdOverlayPdf';
    ov.style.cssText = 'display:none;position:fixed;top:0;left:0;width:100%;height:100%;' +
        'background:rgba(15,23,42,.62);z-index:99999;align-items:center;justify-content:center';

    ov.innerHTML =
        '<div style="background:#fff;border-radius:12px;padding:28px 34px;max-width:400px;' +
        'text-align:center;box-shadow:0 24px 64px rgba(0,0,0,.32);font-family:Segoe UI,Arial,sans-serif">' +
        '<div id="ckdSpinnerPdf" style="width:42px;height:42px;margin:0 auto 16px;' +
        'border:4px solid #e5e7eb;border-top-color:#ba1a1a;border-radius:50%"></div>' +
        '<p style="margin:0 0 6px;font-size:15px;font-weight:700;color:#111827">' +
        'Descargando informe en PDF...</p>' +
        '<p style="margin:0;font-size:12px;color:#6b7280;line-height:1.5">' +
        'Estamos generando el documento con el detalle y los archivos adjuntos. ' +
        'Puede tardar unos segundos.</p></div>';

    document.body.appendChild(ov);

    // La animación se agrega una sola vez, no en cada apertura.
    if (!document.getElementById('ckdSpinKeyframes')) {
        var st = document.createElement('style');
        st.id = 'ckdSpinKeyframes';
        st.innerHTML = '@keyframes ckdSpin{to{transform:rotate(360deg)}}' +
                       '#ckdSpinnerPdf{animation:ckdSpin .8s linear infinite}';
        document.getElementsByTagName('head')[0].appendChild(st);
    }
    return ov;
}

function ckdMostrarDescarga() {
    document.cookie = 'ckdPdfListo=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';

    var ov = ckdCrearOverlayDescarga();
    ov.style.display = 'flex';

    var intentos = 0;
    if (_ckdTimerDescarga) clearInterval(_ckdTimerDescarga);
    _ckdTimerDescarga = setInterval(function () {
        intentos++;
        var listo = document.cookie.indexOf('ckdPdfListo=1') >= 0;
        // Tope de seguridad (~2 min): si algo falla en el servidor, el usuario
        // no queda con la pantalla bloqueada para siempre.
        if (listo || intentos > 240) {
            clearInterval(_ckdTimerDescarga);
            _ckdTimerDescarga = null;
            ov.style.display = 'none';
            document.cookie = 'ckdPdfListo=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
        }
    }, 500);
}
