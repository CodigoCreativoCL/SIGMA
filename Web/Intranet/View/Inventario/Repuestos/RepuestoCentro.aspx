<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="RepuestoCentro.aspx.cs" Inherits="View_Inventario_Repuestos_RepuestoCentro" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Centro de repuestos. La cáscara -hero, pestañas, tarjetas, chips- es la
         misma del centro del activo y del centro de la pauta: un repuesto se
         mira entero en una pantalla, no saltando entre seis menús.

         Qué reúne: la ficha, con qué equipos es compatible, cuánto hay y dónde,
         qué movimientos tuvo, cuánto le dura a la planta y su evidencia. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <style type="text/css">
        /* Tokens de la paleta SIGMA (CLAUDE.md). No se repiten hex sueltos. */
        .sg-rc {
            --sigma-purple: #6732F4; --sigma-purple-dark: #4820C9; --sigma-purple-soft: #F2EFFF;
            --sigma-blue: #087BEA; --sigma-blue-dark: #0565C2; --sigma-blue-soft: #EAF4FF;
            --sigma-cyan: #16C6C9; --sigma-cyan-soft: #E8FBFB; --sigma-cyan-dark: #007F8A;
            --ink: #17223B; --muted: #68738A; --line: #E2E7F0;
            --success: #16855B; --warning: #B65C00; --danger: #C7352B;
            --surface: #FFFFFF; --canvas: #F4F6FA;
        }

        /* Chips. El estado de negocio usa los semánticos; nunca el morado de
           marca, que marca ubicación y no alerta. */
        .rc-badge { font-size: 11px; font-weight: 800; padding: 3px 10px; border-radius: 999px; display: inline-block; }
        .rc-badge.es-tipo { background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .rc-badge.es-ok   { background: #E7F4EE; color: var(--success); }
        .rc-badge.es-bajo { background: #FBE9E7; color: var(--danger); }
        .rc-badge.es-alto { background: #FBF0E3; color: var(--warning); }
        .rc-badge.es-off  { background: #EEF1F6; color: var(--muted); }
        .rc-badge.es-info { background: var(--sigma-blue-soft); color: var(--sigma-blue); }
        .rc-badge.es-lote { background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); }

        /* Tarjetas y rejilla del listado */
        .rc-card { background: var(--surface); border: 1px solid var(--line); border-radius: 14px; box-shadow: 0 1px 2px rgba(23,34,59,.05); padding: 16px 18px; margin-bottom: 14px; }
        .rc-card h3 { font-size: 13px; font-weight: 800; color: var(--ink); margin: 0 0 10px; }
        .rc-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 12px; }
        .rc-item { background: var(--surface); border: 1px solid var(--line); border-radius: 14px; padding: 14px 16px; cursor: pointer; transition: border-color .15s, box-shadow .15s; }
        .rc-item:hover { border-color: var(--sigma-blue); box-shadow: 0 4px 14px rgba(8,123,234,.12); }
        .rc-item .cod { font-size: 11px; font-weight: 800; color: var(--muted); letter-spacing: .4px; }
        .rc-item .nom { font-size: 14px; font-weight: 800; color: var(--ink); margin: 2px 0 8px; line-height: 1.3; }
        .rc-item .pie { display: flex; align-items: center; justify-content: space-between; margin-top: 10px; gap: 8px; }
        .rc-item .stock { font-size: 18px; font-weight: 800; color: var(--ink); }
        .rc-item .stock small { font-size: 11px; font-weight: 700; color: var(--muted); margin-left: 3px; }

        /* Tablas de los paneles */
        .rc-tabla { width: 100%; border-collapse: collapse; font-size: 12.5px; }
        .rc-tabla th { text-align: left; font-size: 11px; font-weight: 800; color: var(--muted); text-transform: uppercase; letter-spacing: .4px; padding: 8px 10px; border-bottom: 1px solid var(--line); }
        .rc-tabla td { padding: 9px 10px; border-bottom: 1px solid var(--line); color: var(--ink); vertical-align: middle; }
        .rc-tabla tr:last-child td { border-bottom: 0; }
        .rc-tabla td.num, .rc-tabla th.num { text-align: right; font-variant-numeric: tabular-nums; }

        /* Fichas de dato del resumen */
        .rc-datos { display: grid; grid-template-columns: repeat(auto-fill, minmax(190px, 1fr)); gap: 10px 18px; }
        .rc-dato .k { font-size: 11px; font-weight: 800; color: #4A556D; text-transform: uppercase; letter-spacing: .3px; }
        .rc-dato .v { font-size: 13.5px; color: var(--ink); font-weight: 600; margin-top: 1px; }

        /* Galería de evidencia */
        .rc-fotos { display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 10px; }
        .rc-foto { border: 1px solid var(--line); border-radius: 12px; overflow: hidden; background: var(--canvas); }
        .rc-foto img { width: 100%; height: 110px; object-fit: cover; display: block; }
        .rc-foto .pie { padding: 6px 8px; font-size: 11px; color: var(--muted); }

        /* Miniatura del repuesto en la tarjeta y en el resumen. Una foto evita
           que en bodega entreguen el que no era. */
        .rc-item-top { display: flex; gap: 10px; align-items: flex-start; }
        .rc-item-id { min-width: 0; }
        .rc-item-chips { margin-top: 6px; display: flex; gap: 5px; flex-wrap: wrap; }
        .rc-thumb { flex: 0 0 auto; width: 54px; height: 54px; border-radius: 12px; overflow: hidden;
                    background: var(--canvas); border: 1px solid var(--line);
                    display: inline-flex; align-items: center; justify-content: center; }
        .rc-thumb img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .rc-thumb.es-vacia { color: #AEB7C6; font-size: 22px; }
        .rc-thumb { position: relative; cursor: zoom-in; }
        .rc-lupa {
            position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
            background: rgba(23,34,59,.55); color: #fff; font-size: 20px;
            opacity: 0; transition: opacity .15s;
        }
        .rc-thumb:hover .rc-lupa { opacity: 1; }

        /* Visor: imagen grande y paso a las demas con flechas o teclado. */
        .rc-visor {
            position: fixed; inset: 0; z-index: 2000; display: none;
            align-items: center; justify-content: center; background: rgba(15,22,38,.86);
        }
        .rc-visor.es-abierto { display: flex; }
        .rc-visor img { max-width: 86vw; max-height: 80vh; border-radius: 12px; background: #fff; }
        .rc-visor .rc-v-cerrar, .rc-visor .rc-v-nav {
            position: absolute; background: rgba(255,255,255,.12); color: #fff; border: 0;
            width: 44px; height: 44px; border-radius: 999px; font-size: 22px; cursor: pointer;
            display: flex; align-items: center; justify-content: center;
        }
        .rc-visor .rc-v-cerrar { top: 20px; right: 24px; }
        .rc-visor .rc-v-nav.es-ant { left: 24px; }
        .rc-visor .rc-v-nav.es-sig { right: 24px; }
        .rc-visor .rc-v-nav:hover, .rc-visor .rc-v-cerrar:hover { background: rgba(255,255,255,.25); }
        .rc-visor .rc-v-pie {
            position: absolute; bottom: 22px; left: 0; right: 0; text-align: center;
            color: #fff; font-size: 13px; font-weight: 600;
        }
        .rc-resumen { display: flex; gap: 18px; align-items: flex-start; }
        .rc-resumen-datos { flex: 1 1 auto; min-width: 0; }
        .rc-resumen .rc-foto-grande { flex: 0 0 auto; width: 150px; height: 150px; border-radius: 14px;
                    overflow: hidden; background: var(--canvas); border: 1px solid var(--line);
                    display: inline-flex; align-items: center; justify-content: center; color: #AEB7C6; font-size: 40px; }
        .rc-resumen .rc-foto-grande img { width: 100%; height: 100%; object-fit: cover; display: block; }
        @media (max-width: 760px) { .rc-resumen { flex-direction: column; } }

        /* Desplegable de compatibilidades dentro de la tarjeta. <details>
           nativo: no necesita JS y es accesible por teclado. */
        .rc-compat { margin-top: 8px; font-size: 12px; }
        .rc-compat summary {
            cursor: pointer; list-style: none; color: var(--sigma-blue);
            font-weight: 700; padding: 4px 0; display: flex; align-items: center; gap: 5px;
        }
        .rc-compat summary::-webkit-details-marker { display: none; }
        .rc-compat summary::after { content: "\F0140"; font-family: "Material Design Icons"; font-size: 15px; }
        .rc-compat[open] summary::after { content: "\F0143"; }
        .rc-compat ul { list-style: none; margin: 4px 0 0; padding: 0 0 0 2px; }
        .rc-compat li { padding: 3px 0; color: var(--ink); display: flex; gap: 6px; align-items: center; }
        .rc-compat.es-vacia { color: var(--muted); display: flex; align-items: center; gap: 5px; padding: 4px 0; }

        .rc-mini { height: 34px; border: 1px solid #CFD6E3; border-radius: 9px; padding: 0 8px; font-size: 12.5px; max-width: 210px; }
        /* Zona de carga: el input de archivo del navegador es feo y no dice
           que acepta. Se oculta y el label hace de zona, mostrando el nombre
           del archivo elegido. */
        .rc-dropzone {
            flex: 1 1 260px; display: flex; align-items: center; gap: 10px;
            min-height: 54px; padding: 8px 14px; margin: 0; cursor: pointer;
            border: 1.5px dashed #CFD6E3; border-radius: 12px; background: #fff;
            transition: border-color .15s, background .15s;
        }
        .rc-dropzone:hover { border-color: var(--sigma-blue); background: var(--sigma-blue-soft); }
        .rc-dropzone > i { font-size: 24px; color: var(--sigma-cyan-dark); }
        .rc-dropzone .rc-dz-txt { font-size: 13px; font-weight: 700; color: var(--ink); }
        .rc-dropzone small { font-size: 11.5px; color: var(--muted); }
        .rc-dz-input { position: absolute; width: 1px; height: 1px; opacity: 0; overflow: hidden; }

        .rc-subir-fila { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
        .rc-subir-fila .form-control { height: 38px; border: 1px solid #CFD6E3; border-radius: 9px; padding: 0 10px; font-size: 13px; flex: 1 1 200px; }
        .rc-mov-resumen { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 10px; }

        /* El badge del movimiento dice que le hace al saldo, no solo como se
           llama: entra, sale, se ajusta, se traslada o se reubica. */
        .rc-badge.es-entra  { background: #E7F4EE; color: var(--success); }
        .rc-badge.es-sale   { background: #FBE9E7; color: var(--danger); }
        .rc-badge.es-ajuste { background: #FBF0E3; color: var(--warning); }
        .rc-badge.es-mueve  { background: var(--sigma-blue-soft); color: var(--sigma-blue); }
        .rc-badge.es-ubica  { background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); }

        /* Ingresar y dar salida, en la fila de la existencia. */
        .rc-accion {
            display: inline-flex; align-items: center; justify-content: center;
            width: 28px; height: 28px; border-radius: 8px; margin-left: 4px;
            font-size: 16px; text-decoration: none; border: 1px solid transparent;
        }
        .rc-accion.es-entra { background: #E7F4EE; color: var(--success); }
        .rc-accion.es-sale  { background: #FBE9E7; color: var(--danger); }
        .rc-accion:hover { border-color: currentColor; }

        .rc-vacio { padding: 26px; text-align: center; color: var(--muted); }
        .rc-vacio i { font-size: 34px; display: block; margin-bottom: 8px; color: var(--sigma-cyan-dark); }
        .rc-vacio p { font-weight: 700; color: var(--ink); margin: 0 0 2px; }

        /* Barra de filtros en dos filas: la busqueda manda y tiene la suya;
           los filtros que la acotan van debajo. */
        .rc-barra { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 12px; flex-wrap: wrap; }
        .rc-barra h3 { margin: 0; }
        .rc-acciones { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
        .rc-checks { display: flex; flex-direction: column; gap: 2px; justify-content: flex-end; padding-bottom: 5px; }
        .rc-checks label { font-size: 12px; font-weight: 600; color: var(--ink); text-transform: none; letter-spacing: 0; margin: 0; }
        .rc-resultado { font-size: 12px; color: var(--muted); margin: 0 0 10px; }
        .rc-cols { display: grid; grid-template-columns: 1fr 300px; gap: 16px; align-items: start; }
        @media (max-width: 1100px) { .rc-cols { grid-template-columns: 1fr; } }
    </style>

    <script type="text/javascript">
        /* Abrir el centro de un repuesto: el id viaja en un campo oculto y el
           servidor arma el centro. Mismo patrón que el centro de la pauta. */
        function abrirCentroRepuesto(id) {
            document.getElementById('<%=hdnRepuesto.ClientID %>').value = id;
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
            return false;
        }
        function volverListado() {
            document.getElementById('<%=hdnRepuesto.ClientID %>').value = '0';
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
            return false;
        }
        function refresh() { __doPostBack('<%=lnkRecargar.UniqueID %>', ''); }

        /* Visor de las imagenes del repuesto. Las URL viajan en la tarjeta, asi
           que abrirlo no pide nada al servidor. */
        var rcFotos = [], rcPos = 0;
        function rcVisor(el) {
            event.stopPropagation();
            var d = (el.getAttribute('data-fotos') || '').split('|').filter(function (x) { return x; });
            if (!d.length) return false;
            rcFotos = d; rcPos = 0;
            document.getElementById('rcVisorTitulo').textContent = el.getAttribute('data-titulo') || '';
            rcPintar();
            document.getElementById('rcVisor').classList.add('es-abierto');
            return false;
        }
        function rcPintar() {
            document.getElementById('rcVisorImg').src = rcFotos[rcPos];
            document.getElementById('rcVisorPos').textContent =
                rcFotos.length > 1 ? (rcPos + 1) + ' de ' + rcFotos.length : '';
            var uno = rcFotos.length < 2;
            document.querySelector('.rc-v-nav.es-ant').style.display = uno ? 'none' : 'flex';
            document.querySelector('.rc-v-nav.es-sig').style.display = uno ? 'none' : 'flex';
        }
        function rcPasar(d) { rcPos = (rcPos + d + rcFotos.length) % rcFotos.length; rcPintar(); return false; }
        function rcCerrar() { document.getElementById('rcVisor').classList.remove('es-abierto'); return false; }
        document.addEventListener('keydown', function (e) {
            var v = document.getElementById('rcVisor');
            if (!v || !v.classList.contains('es-abierto')) return;
            if (e.key === 'Escape') rcCerrar();
            else if (e.key === 'ArrowLeft') rcPasar(-1);
            else if (e.key === 'ArrowRight') rcPasar(1);
        });

        /* Mostrar el nombre del archivo elegido: con el input oculto, sin esto
           no hay forma de saber que se eligio algo. */
        document.addEventListener('change', function (e) {
            if (!e.target.classList || !e.target.classList.contains('rc-dz-input')) return;
            var zona = e.target.closest('.rc-dropzone');
            if (!zona) return;
            var txt = zona.querySelector('.rc-dz-txt');
            if (txt) txt.textContent = e.target.files && e.target.files.length
                ? e.target.files[0].name : 'Elegir archivo';
        });

        /* Las altas y ediciones siguen en su ficha modal de siempre: el centro
           reúne la información, no reemplaza los mantenedores. */
        function abrirRepuesto(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Repuestos/Repuesto.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo repuesto' : 'Editar repuesto',
                width: 880, initialHeight: 580, onClose: refresh
            });
        }
        function abrirCompatibilidad(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Compatibilidades/RepuestoCompatibilidad.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva compatibilidad' : 'Editar compatibilidad',
                width: 820, initialHeight: 520, onClose: refresh
            });
        }
        function abrirMovimiento(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Movimientos/Movimiento.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo movimiento' : 'Movimiento de inventario',
                width: 880, initialHeight: 600, onClose: refresh
            });
        }
        /* La ficha de la bodega, donde se crean y editan sus ubicaciones. */
        function abrirBodega(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Bodegas/Bodega.aspx") %>?query=' + query,
                title: 'Bodega y sus ubicaciones', width: 900, initialHeight: 620, onClose: refresh
            });
        }
        function abrirExistencia(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Existencias/Existencia.aspx") %>?query=' + query,
                title: 'Existencia en bodega', width: 820, initialHeight: 520, onClose: refresh
            });
        }

        /* Cambio de pestaña en el navegador: los paneles ya vienen armados, así
           que no hay postback. hdnSeccion recuerda cuál quedó abierta para que
           un postback asíncrono no devuelva al usuario a la primera. */
        (function () {
            function irA(sec) {
                if (!sec) sec = 'resumen';
                var h = document.getElementById('<%=hdnSeccion.ClientID %>'); if (h) h.value = sec;
                var tabs = document.querySelectorAll('.sg-a3-tab[data-sec]');
                for (var i = 0; i < tabs.length; i++)
                    tabs[i].classList.toggle('es-activa', tabs[i].getAttribute('data-sec') === sec);
                var pans = document.querySelectorAll('.sg-a3-panel[data-panel]');
                for (var p = 0; p < pans.length; p++)
                    pans[p].classList.toggle('es-activo', pans[p].getAttribute('data-panel') === sec);
            }
            document.addEventListener('click', function (e) {
                var t = e.target.closest ? e.target.closest('[data-sec],[data-ir-sec]') : null;
                if (!t) return;
                e.preventDefault();
                irA(t.getAttribute('data-sec') || t.getAttribute('data-ir-sec'));
            });
            function aplicar() {
                var h = document.getElementById('<%=hdnSeccion.ClientID %>');
                irA(h ? h.value : 'resumen');
            }
            /* El enganche al UpdatePanel va DENTRO del DOMContentLoaded: este
               script corre en el <head>, antes de que el ScriptManager defina
               Sys, asi que registrarlo arriba no enganchaba nada y despues de
               un postback ningun panel quedaba activo. */
            document.addEventListener('DOMContentLoaded', function () {
                aplicar();
                if (typeof Sys !== 'undefined' && Sys.WebForms)
                    Sys.WebForms.PageRequestManager.getInstance().add_endRequest(aplicar);
            });
        })();
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Inventario</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Centro de repuestos</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Compatibilidades, existencias, movimientos, vida útil y evidencia de cada repuesto, en una sola pantalla.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <%-- Visor de imagenes. Fuera del UpdatePanel: un postback no debe cerrarlo
         ni volver a pintarlo. --%>
    <div id="rcVisor" class="rc-visor" onclick="if(event.target===this) rcCerrar();">
        <button type="button" class="rc-v-cerrar" onclick="return rcCerrar();" title="Cerrar (Esc)">
            <i class="mdi mdi-close"></i></button>
        <button type="button" class="rc-v-nav es-ant" onclick="return rcPasar(-1);" title="Anterior">
            <i class="mdi mdi-chevron-left"></i></button>
        <img id="rcVisorImg" src="" alt="" />
        <button type="button" class="rc-v-nav es-sig" onclick="return rcPasar(1);" title="Siguiente">
            <i class="mdi mdi-chevron-right"></i></button>
        <div class="rc-v-pie"><span id="rcVisorTitulo"></span> <span id="rcVisorPos"></span></div>
    </div>

    <asp:HiddenField ID="hdnRepuesto" runat="server" Value="0" />
    <asp:HiddenField ID="hdnSeccion" runat="server" Value="resumen" />
    <asp:LinkButton ID="lnkRecargar" runat="server" OnClick="lnkRecargar_Click" style="display:none" CausesValidation="false" />

    <asp:UpdatePanel ID="upCentro" runat="server" UpdateMode="Always">
        <ContentTemplate>

            <%-- ===================== LISTADO =====================
                 Sin hero propio: el encabezado del sitio (Default.master) ya
                 pone modulo, titulo y subtitulo. Repetirlo aqui era el titulo
                 duplicado. Las acciones viven en la barra de la tarjeta. --%>
            <asp:Panel ID="pnlLista" runat="server" CssClass="sg-a3 sg-ot sg-rc">

            <%-- El filtro de planta y el de bodega se resuelven por los
                 saldos: un repuesto "esta" en una bodega cuando tiene
                 saldo ahi. --%>
                <wuc:Filtro runat="server" ID="wucFiltro">
                    <FiltroPersonalizado>
                        <div class="row col-lg-12 col-md-12 col-xs-12">
                            <div class="col-lg-3 col-md-3 col-xs-12">
                                <label for="ddlPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                                <rad:RadComboBox2 ID="ddlPlanta" runat="server" Width="100%"
                                    AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Planta_Changed" />
                            </div>
                            <div class="col-lg-3 col-md-3 col-xs-12">
                                <label for="ddlBodega" style="display:block; margin:0 0 4px;">Bodega:</label>
                                <rad:RadComboBox2 ID="ddlBodega" runat="server" Width="100%"
                                    AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Filtro_Changed" />
                            </div>
                            <div class="col-lg-3 col-md-3 col-xs-12">
                                <label for="ddlTipo" style="display:block; margin:0 0 4px;">Tipo de repuesto:</label>
                                <rad:RadComboBox2 ID="ddlTipo" runat="server" Width="100%"
                                    AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Filtro_Changed" />
                            </div>
                            <div class="col-lg-3 col-md-3 col-xs-12">
                                <label for="ddlEstado" style="display:block; margin:0 0 4px;">Existencia:</label>
                                <rad:RadComboBox2 ID="ddlEstado" runat="server" Width="100%"
                                    AutoPostBack="true" OnSelectedIndexChanged="Filtro_Changed">
                                    <Items>
                                        <rad:RadComboBoxItem Text="Todas" Value="" />
                                        <rad:RadComboBoxItem Text="Con existencia" Value="con" />
                                        <rad:RadComboBoxItem Text="Sin existencia" Value="sin" />
                                        <rad:RadComboBoxItem Text="Bajo el mínimo" Value="bajo" />
                                        <rad:RadComboBoxItem Text="Sobre el máximo" Value="sobre" />
                                    </Items>
                                </rad:RadComboBox2>
                            </div>
                        </div>
                        <div class="row col-lg-12 col-md-12 col-xs-12" style="margin-top:10px;">
                            <div class="col-lg-4 col-md-4 col-xs-12">
                                <asp:CheckBox ID="chkLote" runat="server" Text=" Controla lote"
                                    AutoPostBack="true" OnCheckedChanged="Filtro_Changed" />
                            </div>
                            <div class="col-lg-4 col-md-4 col-xs-12">
                                <asp:CheckBox ID="chkInhabilitados" runat="server" Text=" Incluir deshabilitados"
                                    AutoPostBack="true" OnCheckedChanged="Filtro_Changed" />
                            </div>
                        </div>
                    </FiltroPersonalizado>
                </wuc:Filtro>

                <div class="sg-a3-kpis">
                    <asp:Literal ID="litKpis" runat="server" />
                </div>

                <div class="rc-cols">
                    <div>
                        <div class="rc-card">
                            <div class="rc-barra">
                                <h3>Repuestos</h3>
                                <div class="rc-acciones">
                                    <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sg-ot-btn es-plano"
                                        OnClick="lnkExportar_Click" CausesValidation="false"
                                        ToolTip="Descargar a Excel lo que muestra el filtro">
                                        <i class="mdi mdi-file-excel-outline"></i>Exportar</asp:LinkButton>
                                    <asp:LinkButton ID="lnkCargaMasiva" runat="server" CssClass="sg-ot-btn es-contorno"
                                        CausesValidation="false"><i class="mdi mdi-file-upload-outline"></i>Carga masiva</asp:LinkButton>
                                    <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sg-ot-btn es-prim"
                                        OnClientClick="return abrirRepuesto(0);" CausesValidation="false">
                                        <i class="mdi mdi-plus"></i>Nuevo repuesto</asp:LinkButton>
                                </div>
                            </div>

                            <asp:Literal ID="litResultado" runat="server" />
                            <asp:Literal ID="litLista" runat="server" />

                            <asp:Panel ID="pnlListaVacia" runat="server" Visible="false" CssClass="rc-vacio">
                                <i class="mdi mdi-package-variant"></i>
                                <p>No hay repuestos que coincidan</p>
                                <span>Ajuste el filtro o cree un repuesto nuevo.</span>
                            </asp:Panel>
                        </div>
                    </div>

                    <aside class="rc-aside">
                        <div class="rc-card">
                            <div class="rc-aside-ico"><i class="mdi mdi-package-variant-closed"></i></div>
                            <h3>Un solo centro</h3>
                            <p>
                                El repuesto se define una vez y desde aca se ve todo lo que le pasa:
                                con que equipos calza, cuanto queda en cada bodega, quien lo movio y
                                cuanto dura antes de reemplazarse.
                            </p>
                            <asp:LinkButton ID="lnkClasificar" runat="server" CssClass="link" CausesValidation="false">
                                <i class="mdi mdi-shape-plus-outline"></i>Clasificar varios a la vez</asp:LinkButton>
                            <br />
                            <asp:HyperLink ID="hlBodegas" runat="server" CssClass="link">
                                <i class="mdi mdi-warehouse"></i>Ir a bodegas</asp:HyperLink>
                            <br />
                            <asp:HyperLink ID="hlTipos" runat="server" CssClass="link">
                                <i class="mdi mdi-shape-outline"></i>Ir a tipos de repuesto</asp:HyperLink>
                        </div>
                    </aside>
                </div>
            </asp:Panel>

            <%-- ===================== CENTRO DEL REPUESTO ===================== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sg-a3 sg-ot sg-rc">

                <div class="sg-a3-miga">
                    <span>Inventario</span>
                    <span class="sep">/</span>
                    <a href="#" onclick="return volverListado();">Centro de repuestos</a>
                    <span class="sep">/</span><asp:Literal ID="litMiga" runat="server" />
                </div>

                <header class="sg-a3-hero">
                    <div class="sg-a3-hero-txt">
                        <h1><asp:Literal ID="litHeroNombre" runat="server" /></h1>
                        <div class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></div>
                    </div>
                    <div class="sg-a3-hero-acc">
                        <asp:LinkButton ID="lnkVolver" runat="server" CssClass="sg-ot-btn es-contorno"
                            OnClientClick="return volverListado();" CausesValidation="false">
                            <i class="mdi mdi-arrow-left"></i>Volver al listado</asp:LinkButton>
                        <asp:LinkButton ID="lnkEditar" runat="server" CssClass="sg-ot-btn es-prim" CausesValidation="false">
                            <i class="mdi mdi-pencil-outline"></i>Editar</asp:LinkButton>
                    </div>
                </header>

                <div class="sg-a3-kpis">
                    <asp:Literal ID="litKpisFicha" runat="server" />
                </div>

                <nav class="sg-a3-nav">
                    <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-view-dashboard-outline"></i>Resumen</a>
                    <a href="#" class="sg-a3-tab" data-sec="compatibilidades"><i class="mdi mdi-puzzle-outline"></i>Compatibilidades</a>
                    <a href="#" class="sg-a3-tab" data-sec="existencias"><i class="mdi mdi-warehouse"></i>Existencias</a>
                    <a href="#" class="sg-a3-tab" data-sec="posiciones"><i class="mdi mdi-map-marker-outline"></i>Posiciones</a>
                    <a href="#" class="sg-a3-tab" data-sec="movimientos"><i class="mdi mdi-swap-horizontal"></i>Movimientos</a>
                    <a href="#" class="sg-a3-tab" data-sec="vidautil"><i class="mdi mdi-timer-sand"></i>Vida útil</a>
                    <a href="#" class="sg-a3-tab" data-sec="evidencia"><i class="mdi mdi-image-multiple-outline"></i>Evidencia y documentos</a>
                </nav>

                <section class="sg-a3-panel" data-panel="resumen">
                    <div class="rc-card">
                        <h3>Ficha del repuesto</h3>
                        <div class="rc-resumen">
                            <asp:Literal ID="litFotoResumen" runat="server" />
                            <div class="rc-resumen-datos"><asp:Literal ID="litResumen" runat="server" /></div>
                        </div>
                    </div>
                    <div class="rc-card">
                        <h3>Dónde está</h3>
                        <asp:Literal ID="litResumenStock" runat="server" />
                    </div>
                </section>

                <section class="sg-a3-panel" data-panel="compatibilidades">
                    <div class="rc-card">
                        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
                            <h3 style="margin:0">Con qué equipos calza</h3>
                            <asp:LinkButton ID="lnkNuevaCompat" runat="server" CssClass="sg-ot-btn es-prim"
                                CausesValidation="false"><i class="mdi mdi-plus"></i>Agregar</asp:LinkButton>
                        </div>
                        <asp:Literal ID="litCompatibilidades" runat="server" />
                    </div>
                </section>

                <section class="sg-a3-panel" data-panel="existencias">
                    <div class="rc-card">
                        <h3>Existencia por bodega</h3>
                        <asp:Literal ID="litExistencias" runat="server" />
                    </div>
                    <div class="rc-card">
                        <h3>Umbrales de stock</h3>
                        <asp:Literal ID="litUmbrales" runat="server" />
                    </div>
                    <asp:Panel ID="pnlLotes" runat="server" CssClass="rc-card" Visible="false">
                        <h3>Lotes</h3>
                        <asp:Literal ID="litLotes" runat="server" />
                    </asp:Panel>
                </section>

                <section class="sg-a3-panel" data-panel="posiciones">
                    <div class="rc-card">
                        <h3>En qué posición de cada bodega está</h3>
                        <asp:Literal ID="litPosiciones" runat="server" />
                    </div>
                </section>

                <section class="sg-a3-panel" data-panel="movimientos">
                    <div class="rc-card">
                        <div class="rc-barra">
                            <h3>Movimientos</h3>
                            <div class="rc-acciones">
                                <rad:RadComboBox2 ID="ddlMovTipo" runat="server" Width="210px"
                                    AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Mov_Changed" />
                                <rad:RadComboBox2 ID="ddlMovOrden" runat="server" Width="200px"
                                    AutoPostBack="true" OnSelectedIndexChanged="Mov_Changed">
                                    <Items>
                                        <rad:RadComboBoxItem Text="Más recientes primero" Value="fecha" />
                                        <rad:RadComboBoxItem Text="Más antiguos primero" Value="fecha_asc" />
                                        <rad:RadComboBoxItem Text="Agrupados por tipo" Value="tipo" />
                                        <rad:RadComboBoxItem Text="Mayor cantidad" Value="cantidad" />
                                    </Items>
                                </rad:RadComboBox2>
                                <asp:LinkButton ID="lnkNuevoMov" runat="server" CssClass="sg-ot-btn es-prim"
                                    CausesValidation="false"><i class="mdi mdi-plus"></i>Registrar movimiento</asp:LinkButton>
                            </div>
                        </div>
                        <asp:Literal ID="litMovResumen" runat="server" />
                        <asp:Literal ID="litMovimientos" runat="server" />
                    </div>
                </section>

                <section class="sg-a3-panel" data-panel="vidautil">
                    <div class="rc-card">
                        <h3>Cuánto le dura a la planta</h3>
                        <asp:Literal ID="litVidaUtilResumen" runat="server" />
                    </div>
                    <div class="rc-card">
                        <h3>Instalaciones registradas</h3>
                        <asp:Literal ID="litVidaUtil" runat="server" />
                    </div>
                </section>

                <section class="sg-a3-panel" data-panel="evidencia">
                    <asp:Panel ID="pnlSubir" runat="server" CssClass="rc-card rc-subir">
                        <h3>Adjuntar al repuesto</h3>
                        <p class="rc-resultado">
                            Una foto evita que en bodega entreguen el que no era; la ficha técnica y el
                            certificado del proveedor viven acá, junto al repuesto.
                        </p>
                        <div class="rc-subir-fila">
                            <label class="rc-dropzone" for="<%=fupArchivo.ClientID %>">
                                <i class="mdi mdi-cloud-upload-outline"></i>
                                <span class="rc-dz-txt">Elegir archivo</span>
                                <small>Imagen, PDF o documento</small>
                                <asp:FileUpload ID="fupArchivo" runat="server" CssClass="rc-dz-input" />
                            </label>
                            <asp:TextBox ID="txtTituloArchivo" runat="server" CssClass="form-control"
                                placeholder="Título (opcional): ficha técnica, certificado…" />
                            <asp:LinkButton ID="lnkSubir" runat="server" CssClass="sg-ot-btn es-prim"
                                OnClick="lnkSubir_Click" CausesValidation="false">
                                <i class="mdi mdi-upload"></i>Adjuntar</asp:LinkButton>
                        </div>
                        <asp:Literal ID="litSubirAviso" runat="server" />
                    </asp:Panel>
                    <div class="rc-card">
                        <h3>Fotografías</h3>
                        <asp:Literal ID="litFotos" runat="server" />
                    </div>
                    <div class="rc-card">
                        <h3>Documentos</h3>
                        <asp:Literal ID="litDocumentos" runat="server" />
                    </div>
                </section>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
