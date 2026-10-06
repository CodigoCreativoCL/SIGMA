<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="RepuestoCentro.aspx.cs" Inherits="View_Inventario_Repuestos_RepuestoCentro" %>


<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Centro de repuestos. La cáscara -hero, pestañas, tarjetas, chips- es la
         misma del centro del activo y del centro de la pauta: un repuesto se
         mira entero en una pantalla, no saltando entre seis menús.

         Qué reúne: la ficha, con qué equipos es compatible, cuánto hay y dónde,
         qué movimientos tuvo, cuánto le dura a la planta y su evidencia. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <script type="text/javascript" src="<%=ResolveUrl("~/Js/sigma-fabricante.js") %>?vrs=2"></script>
    <%-- Rediseño 06-10-2026: el listado y la ficha usan el diseño del Centro de activos. --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activos.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-repuesto-centro.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-paginador.js") %>'></script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-repuesto-centro.js") %>'></script>
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
        .rc-foto .pie { display: flex; align-items: center; justify-content: space-between; gap: 6px;
            min-height: 34px; padding: 6px 8px; font-size: 11px; color: var(--muted); }
        .rc-foto-ver { position: relative; display: block; cursor: zoom-in; }
        .rc-foto-zoom { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
            background: rgba(23, 34, 59, .35); color: #fff; font-size: 26px; opacity: 0; transition: opacity .15s; }
        .rc-foto-ver:hover .rc-foto-zoom, .rc-foto-ver:focus .rc-foto-zoom { opacity: 1; }
        .rc-chip-portada { padding: 2px 8px; border-radius: 999px; background: var(--sigma-purple-soft, #F2EFFF);
            color: var(--sigma-purple, #6732F4); font-weight: 800; }
        .rc-foto-acc { display: inline-flex; gap: 2px; }
        .rc-foto-acc a, .rc-tabla a.link { display: inline-flex; width: 28px; height: 28px; align-items: center;
            justify-content: center; border-radius: 8px; color: var(--muted); font-size: 16px; }
        .rc-foto-acc a:hover, .rc-tabla a.link:hover { background: var(--sigma-blue-soft, #EAF4FF); color: var(--sigma-blue, #087BEA); }
        .rc-foto-acc a.es-peligro:hover, .rc-tabla a.link.es-peligro:hover { background: #FDECEA; color: #C7352B; }

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
        /* Las pestañas bajan de línea en vez de desbordar la tarjeta (sin scroll horizontal). */
        /* Ocho pestañas en una fila; si la pantalla no alcanza bajan de línea, nunca scroll horizontal. */
        .sg-rc .sg-a3-nav { flex-wrap: wrap; }
        .sg-rc a.sg-a3-tab, .sg-rc a.sg-a3-tab:hover, .sg-rc a.sg-a3-tab:focus { padding: 13px 13px; }

        /* ---- Ficha: lectura y edición en el mismo lugar ---- */
        .rc-ficha-cab { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 14px; }
        .rc-ficha-cab h3 { margin: 0; }
        .rc-ficha { display: grid; grid-template-columns: 180px 1fr; gap: 22px; align-items: start; }
        .rc-ficha .rc-foto-grande { display: flex; align-items: center; justify-content: center; width: 180px; height: 180px;
            border-radius: 14px; overflow: hidden; background: var(--canvas); border: 1px solid var(--line); color: #A0A8B8; font-size: 40px; }
        .rc-ficha .rc-foto-grande img { width: 100%; height: 100%; object-fit: cover; display: block; }
        .rc-ficha-desc { margin: 0 0 16px; font-size: 13.5px; color: var(--ink); line-height: 1.55; }
        .rc-ficha-desc.es-vacia { color: var(--muted); font-style: italic; }
        .rc-grupos { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; }
        .rc-grupo { border: 1px solid var(--line); border-radius: 12px; padding: 12px 14px; }
        .rc-grupo-tit { display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 800; color: #4A556D;
            text-transform: uppercase; letter-spacing: .4px; margin-bottom: 8px; }
        .rc-grupo-tit i { color: var(--sigma-cyan-dark); font-size: 15px; }
        .rc-fila { display: flex; justify-content: space-between; gap: 10px; padding: 6px 0; font-size: 13px; border-top: 1px dashed var(--line); }
        .rc-grupo-tit + .rc-fila { border-top: 0; }
        .rc-fila .k { color: var(--muted); }
        .rc-fila .v { color: var(--ink); font-weight: 600; text-align: right; }
        .rc-fila .v.es-vacio { color: #A0A8B8; font-weight: 500; }
        .rc-chips-op { display: flex; flex-wrap: wrap; gap: 6px; }
        .rc-chip-op { display: inline-flex; align-items: center; gap: 4px; padding: 3px 10px; border-radius: 999px; font-size: 11.5px; font-weight: 800; }
        .rc-chip-op.es-si { background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); }
        .rc-chip-op.es-no { background: var(--canvas); color: var(--muted); }
        @media (max-width: 860px) { .rc-ficha { grid-template-columns: 1fr; } }

        .rc-form { display: grid; gap: 14px; }
        .rc-form-sec { border: 1px solid var(--line); border-radius: 12px; padding: 14px 16px; }
        .rc-form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px 16px; }
        .rc-form-grid .es-ancho { grid-column: 1 / -1; }
        .rc-campo label { display: block; margin: 0 0 5px; font-size: 11px; font-weight: 800; color: #4A556D; }
        .rc-campo .form-control, .rc-campo textarea { width: 100%; border: 1px solid #CFD6E3; border-radius: 9px; padding: 8px 10px; font-size: 13px; color: var(--ink); }
        .rc-campo textarea { min-height: 76px; resize: vertical; }
        .rc-campo .form-control:focus, .rc-campo textarea:focus { outline: 3px solid rgba(22,198,201,.27); border-color: var(--sigma-cyan-dark); }
        .rc-ayuda { display: block; margin-top: 4px; font-size: 11px; color: var(--muted); }
        .rc-campo .rc-fijo { padding: 8px 0; font-size: 13.5px; font-weight: 700; color: var(--ink); }
        .rc-switch { display: flex; gap: 6px; }
        .rc-switch label { margin: 0; font-weight: 400; }
        .rc-switch input { position: absolute; opacity: 0; pointer-events: none; }
        .rc-switch span { display: inline-block; padding: 6px 16px; border: 1px solid #CFD6E3; border-radius: 9px; font-size: 12.5px; font-weight: 700; color: var(--muted); cursor: pointer; }
        .rc-switch input:checked + span { background: var(--sigma-purple-soft); border-color: var(--sigma-purple); color: var(--sigma-purple); }
        .rc-form-pie { display: flex; justify-content: flex-end; gap: 10px; }
        .sg-fab-aviso { margin-top: 6px; padding: 8px 10px; border-radius: 9px; background: var(--sigma-cyan-soft); color: var(--ink); font-size: 12px; }
        .sg-fab-aviso i { color: var(--sigma-cyan-dark); }
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
        /* Eliminar o dejar de portada: confirma y lo resuelve el servidor. */
        /* Fabricante y modelo en cascada (bloque 333), igual que la ficha modal:
           el catálogo lo deja el servidor en #sgFabCatalogo. */
        function sgCatalogo() { var c = document.getElementById('sgFabCatalogo'); return c ? JSON.parse(c.textContent || '[]') : []; }
        function sgCombo(suf) { var el = document.querySelector('[id$="_' + suf + '"].RadComboBox'); return el ? $find(el.id) : null; }
        function sgTexto(c) { if (!c) return ''; var t = c.get_text(); return (c.get_emptyMessage && t === c.get_emptyMessage()) ? '' : t; }
        function sgFabricante() {
            var f = sgCombo('cboFabricante'), k = f ? SigmaFabricante.clave(sgTexto(f)) : '';
            return sgCatalogo().filter(function (x) { return SigmaFabricante.clave(x.nombre) === k; })[0] || null;
        }
        function sgFabCambio() {
            var f = sgCombo('cboFabricante'), m = sgCombo('cboModelo');
            if (!f || !m) return;
            var fab = sgFabricante(), limpio = sgTexto(f).replace(/\s+/g, ' ').trim();
            if (fab && sgTexto(f) !== fab.nombre) f.set_text(fab.nombre);
            else if (!fab && limpio && sgTexto(f) !== limpio) f.set_text(limpio);
            var antes = sgTexto(m);
            m.trackChanges(); m.get_items().clear();
            (fab ? fab.modelos : []).forEach(function (x) {
                var it = new Telerik.Web.UI.RadComboBoxItem(); it.set_text(x); it.set_value(x); m.get_items().add(it);
            });
            m.commitChanges();
            if (antes && !(fab && fab.modelos.some(function (x) { return SigmaFabricante.clave(x) === SigmaFabricante.clave(antes); }))
                && sgFabCambio.previo && sgFabCambio.previo !== SigmaFabricante.clave(sgTexto(f))) { m.clearSelection(); m.set_text(''); }
            sgFabCambio.previo = SigmaFabricante.clave(sgTexto(f));
            sgModAvisar();
        }
        function sgModCanon() {
            var m = sgCombo('cboModelo'), fab = sgFabricante();
            if (!m) return;
            var t = sgTexto(m).replace(/\s+/g, ' ').trim();
            if (t && fab) fab.modelos.forEach(function (x) { if (SigmaFabricante.clave(x) === SigmaFabricante.clave(t)) t = x; });
            if (t && sgTexto(m) !== t) m.set_text(t);
            sgModAvisar();
        }
        function sgModAvisar() {
            var a = document.getElementById('sgFabAviso'), f = sgCombo('cboFabricante'), m = sgCombo('cboModelo');
            if (!a || !f || !m) return;
            var fab = sgFabricante(), t = sgTexto(f).trim(), mt = sgTexto(m).trim(), h = '';
            if (t && !fab) h = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + t.replace(/</g, '&lt;') + '</b> es un fabricante nuevo: se agrega al catálogo al guardar.';
            else if (fab && mt && !fab.modelos.some(function (x) { return SigmaFabricante.clave(x) === SigmaFabricante.clave(mt); }))
                h = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + mt.replace(/</g, '&lt;') + '</b> es un modelo nuevo de ' + fab.nombre + ': se agrega al guardar.';
            a.innerHTML = h; a.hidden = !h;
        }
        function sgFabIniciar() { var f = sgCombo('cboFabricante'); if (!f) return; sgFabCambio.previo = SigmaFabricante.clave(sgTexto(f)); sgModAvisar(); }
        window.addEventListener('load', function () {
            setTimeout(sgFabIniciar, 0);
            if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () { setTimeout(sgFabIniciar, 0); });
        });

        function rcAccion(accion, vinculo) {
            var txt = accion === 'quitar' ? '¿Eliminar este archivo del repuesto? No se puede deshacer.'
                                          : '¿Usar esta foto como portada del repuesto?';
            if (!confirm(txt)) return false;
            document.getElementById('<%=hdnAccion.ClientID %>').value = accion;
            document.getElementById('<%=hdnVinculo.ClientID %>').value = vinculo;
            __doPostBack('<%=lnkAccionArchivo.UniqueID %>', '');
            return false;
        }
        function rcVisor(el) {
            if (window.event) window.event.stopPropagation();
            var d = (el.getAttribute('data-fotos') || '').split('|').filter(function (x) { return x; });
            if (!d.length) return false;
            rcFotos = d; rcPos = parseInt(el.getAttribute('data-pos') || '0', 10) || 0;
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
                width: 1080, initialHeight: 680, onClose: refresh
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
        function abrirTipoRepuesto(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Repuestos/RepuestoTipo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo tipo de repuesto' : 'Editar tipo de repuesto',
                width: 720, initialHeight: 470, onClose: refresh
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
    <asp:HiddenField ID="hdnAccion" runat="server" />
    <asp:HiddenField ID="hdnVinculo" runat="server" />
    <asp:LinkButton ID="lnkAccionArchivo" runat="server" OnClick="lnkAccionArchivo_Click" style="display:none" CausesValidation="false" />
    <asp:LinkButton ID="lnkRecargar" runat="server" OnClick="lnkRecargar_Click" style="display:none" CausesValidation="false" />

    <asp:UpdatePanel ID="upCentro" runat="server" UpdateMode="Always">
        <ContentTemplate>

            <%-- ===================== LISTADO (rediseño 06-10-2026) =====================
                 El mismo diseño del Centro de activos 360°: encabezado navy con
                 las acciones, indicadores, pestañas del modulo y «Ver como»
                 Lista o Tarjetas. Los datos los arma el servidor (litLista, un
                 JSON) y Js en esta pagina dibuja las dos vistas; buscar, agrupar
                 y ordenar no van al servidor. Planta, bodega, tipo y existencia
                 siguen en el filtro: resuelven por saldos en el servidor. --%>
            <asp:Panel ID="pnlLista" runat="server" CssClass="sgap rcx" ClientIDMode="Static">
            <div class="wrap">
              <header class="hero">
                <div class="hero-top">
                  <div class="hero-title">
                    <span class="hero-eyebrow">Inventario</span>
                    <h1>Centro de repuestos</h1>
                    <p>Compatibilidades, existencias, movimientos y vida útil de cada repuesto.</p>
                  </div>
                  <div class="hero-actions">
                    <div class="menu-wrap">
                      <button type="button" class="btn btn--hero" id="rcBtnIO" aria-haspopup="menu" aria-expanded="false" aria-controls="rcMenuIO"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 17V5M3 9l4-4 4 4M17 7v12M13 15l4 4 4-4"/></svg>Importar o exportar<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></button>
                      <div class="menu" id="rcMenuIO" role="menu" hidden>
                        <asp:LinkButton ID="lnkCargaMasiva" runat="server" role="menuitem" CausesValidation="false"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 15V4M7 9l5-5 5 5M4 15v5h16v-5"/></svg><span><b>Importar desde Excel</b><small>Repuestos completos, umbrales, stock y compatibilidades</small></span></asp:LinkButton>
                        <asp:LinkButton ID="lnkExportar" runat="server" role="menuitem" OnClick="lnkExportar_Click" CausesValidation="false"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M4 20h16"/></svg><span><b>Exportar a Excel</b><small>Los repuestos que estás viendo ahora</small></span></asp:LinkButton>
                        <asp:LinkButton ID="lnkClasificar" runat="server" role="menuitem" CausesValidation="false"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 6h7v7H4zM13 6h7v7h-7zM4 15h16v4H4z"/></svg><span><b>Clasificar varios</b><small>Asignar el tipo a muchos a la vez</small></span></asp:LinkButton>
                      </div>
                    </div>
                    <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="btn btn--primary btn--glow"
                        OnClientClick="return abrirRepuesto(0);" CausesValidation="false"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>Nuevo repuesto</asp:LinkButton>
                  </div>
                </div>
              </header>

              <section class="kpis" aria-label="Resumen de los repuestos"><asp:Literal ID="litKpis" runat="server" /></section>

              <section class="panel">
                <nav class="mtabs" aria-label="Secciones de Inventario">
                  <button type="button" role="tab" data-rctab="repuestos" aria-current="page" aria-selected="true"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 8l-9-5-9 5 9 5 9-5zM3 8v8l9 5 9-5V8M12 13v8"/></svg>Repuestos<b><asp:Literal ID="litNumRep" runat="server" Text="0" /></b></button>
                  <button type="button" role="tab" data-rctab="tipos" aria-selected="false"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12l9-9 9 9-9 9-9-9z"/></svg>Tipos de repuesto<b><asp:Literal ID="litNumTipos" runat="server" Text="0" /></b></button>
                  <button type="button" role="tab" data-rctab="bodegas" aria-selected="false"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 21V8l9-5 9 5v13M7 21v-8h10v8M7 17h10"/></svg>Bodegas<b><asp:Literal ID="litNumBodegas" runat="server" Text="0" /></b></button>
                </nav>

                <div class="tabpanel" data-rcpanel="repuestos">
                  <div class="viewbar">
                    <div class="viewbar-l">
                      <span class="viewbar-lbl" id="rcVerComo">Ver como</span>
                      <div class="seg seg--views" role="group" aria-labelledby="rcVerComo">
                        <button type="button" data-rcview="lista" aria-pressed="false"><svg class="icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"/></svg><span>Lista</span></button>
                        <button type="button" data-rcview="tarjetas" aria-pressed="true"><svg class="icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="4" width="7" height="7" rx="1.5"/><rect x="13" y="4" width="7" height="7" rx="1.5"/><rect x="4" y="13" width="7" height="7" rx="1.5"/><rect x="13" y="13" width="7" height="7" rx="1.5"/></svg><span>Tarjetas</span></button>
                        <button type="button" data-rcview="mapa" aria-pressed="false"><svg class="icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="4" width="11" height="8" rx="1.5"/><rect x="16" y="4" width="5" height="16" rx="1.5"/><rect x="3" y="14" width="11" height="6" rx="1.5"/></svg><span>Mapa por ubicación</span></button>
                      </div>
                      <span class="viewbar-help" id="rcViewHelp"></span>
                    </div>
                    <button type="button" class="btn" id="rcBtnFiltros" aria-expanded="false" aria-controls="rcFiltros"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5h16l-6 8v6l-4-2v-4z"/></svg>Filtrar por planta, bodega o tipo<asp:Literal ID="litNumFiltros" runat="server" /></button>
                  </div>

                  <%-- Los filtros que se resuelven por los saldos: un repuesto
                       "esta" en una bodega cuando tiene saldo ahi. --%>
                  <div class="rcx-filtros" id="rcFiltros" hidden>
                    <label><span>Planta</span><rad:RadComboBox2 ID="ddlPlanta" runat="server" Width="100%" AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Planta_Changed" /></label>
                    <label><span>Bodega</span><rad:RadComboBox2 ID="ddlBodega" runat="server" Width="100%" AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Filtro_Changed" /></label>
                    <label><span>Tipo de repuesto</span><rad:RadComboBox2 ID="ddlTipo" runat="server" Width="100%" AutoPostBack="true" Filter="Contains" OnSelectedIndexChanged="Filtro_Changed" /></label>
                    <label><span>Existencia</span><rad:RadComboBox2 ID="ddlEstado" runat="server" Width="100%" AutoPostBack="true" OnSelectedIndexChanged="Filtro_Changed">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas" Value="" />
                            <rad:RadComboBoxItem Text="Con existencia" Value="con" />
                            <rad:RadComboBoxItem Text="Sin existencia" Value="sin" />
                            <rad:RadComboBoxItem Text="Bajo el mínimo" Value="bajo" />
                            <rad:RadComboBoxItem Text="Sobre el máximo" Value="sobre" />
                        </Items>
                    </rad:RadComboBox2></label>
                    <div class="rcx-checks">
                      <asp:CheckBox ID="chkLote" runat="server" Text=" Controla lote" AutoPostBack="true" OnCheckedChanged="Filtro_Changed" />
                      <asp:CheckBox ID="chkInhabilitados" runat="server" Text=" Incluir deshabilitados" AutoPostBack="true" OnCheckedChanged="Filtro_Changed" />
                    </div>
                  </div>

                  <div id="rcLista" hidden></div>
                  <div id="rcTarjetas"></div>
                  <div id="rcMapa" hidden></div>
                </div>
                <div class="tabpanel" data-rcpanel="tipos" hidden><div class="sa-cat" id="rcCatTipos"></div></div>
                <div class="tabpanel" data-rcpanel="bodegas" hidden><div class="sa-cat" id="rcCatBodegas"></div></div>
                <asp:Literal ID="litLista" runat="server" />
              </section>
            </div>
            </asp:Panel>

            <%-- ===================== CENTRO DEL REPUESTO ===================== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sg-a3 sg-ot sg-rc sg-a3--v3 rcx-ficha">

                <%-- Volver + miga y la cabecera blanca con la portada: las mismas
                     de la ficha del activo. --%>
                <div class="sg-a3-miga">
                    <asp:LinkButton ID="lnkVolver" runat="server" CssClass="sg-a3-volver"
                        OnClientClick="return volverListado();" CausesValidation="false"><i class="mdi mdi-chevron-left"></i>Volver</asp:LinkButton>
                    <span>Inventario</span>
                    <span class="sep">/</span>
                    <a href="#" onclick="return volverListado();">Centro de repuestos</a>
                    <span class="sep">/</span><asp:Literal ID="litMiga" runat="server" />
                </div>

                <header class="sg-a3-hero es-v2">
                    <asp:Literal ID="litHeroFoto" runat="server" />
                    <div class="sg-a3-hero-txt">
                        <h1><span class="sg-a3-hero-nom"><asp:Literal ID="litHeroNombre" runat="server" /></span></h1>
                        <div class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></div>
                    </div>
                    <div class="sg-a3-hero-acc">
                        <%-- El mapa en otra pestana: quien esta en la ficha no pierde lo que miraba. --%>
                        <asp:HyperLink ID="hlMapa" runat="server" CssClass="sg-ot-btn es-contorno" Target="_blank" Visible="false">
                            <i class="mdi mdi-cube-scan"></i>Ver en el mapa 3D</asp:HyperLink>
                        <asp:LinkButton ID="lnkEditar" runat="server" CssClass="sg-ot-btn es-primario" CausesValidation="false" OnClick="lnkEditar_Click">
                            <i class="mdi mdi-pencil-outline"></i>Editar</asp:LinkButton>
                    </div>
                </header>

                <div class="sg-a3-kpis">
                    <asp:Literal ID="litKpisFicha" runat="server" />
                </div>

                <nav class="sg-a3-nav" aria-label="Secciones del repuesto">
                    <div class="sg-a3-nav-scroll">
                    <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-file-document-outline"></i>Ficha</a>
                    <a href="#" class="sg-a3-tab" data-sec="compatibilidades"><i class="mdi mdi-puzzle-outline"></i>Compatibilidades</a>
                    <a href="#" class="sg-a3-tab" data-sec="existencias"><i class="mdi mdi-warehouse"></i>Existencias</a>
                    <a href="#" class="sg-a3-tab" data-sec="posiciones"><i class="mdi mdi-map-marker-outline"></i>Posiciones</a>
                    <a href="#" class="sg-a3-tab" data-sec="reposicion"><i class="mdi mdi-cart-plus"></i>Reposición y conteos</a>
                    <a href="#" class="sg-a3-tab" data-sec="movimientos"><i class="mdi mdi-swap-horizontal"></i>Movimientos</a>
                    <a href="#" class="sg-a3-tab" data-sec="vidautil"><i class="mdi mdi-timer-sand"></i>Vida útil</a>
                    <a href="#" class="sg-a3-tab" data-sec="evidencia"><i class="mdi mdi-image-multiple-outline"></i>Evidencia y documentos</a>
                    </div>
                </nav>

                <%-- FICHA. Una sola pestaña para leer y editar el repuesto: Editar no abre
                     un modal, vuelve editables los mismos datos aquí. Los umbrales de
                     stock viven en Existencias, por eso no se repiten. --%>
                <section class="sg-a3-panel" data-panel="resumen">
                    <div class="rc-card">
                        <div class="rc-ficha-cab">
                            <h3><asp:Literal ID="litFichaTitulo" runat="server" Text="Ficha del repuesto" /></h3>
                        </div>

                        <asp:Panel ID="pnlFichaVer" runat="server" CssClass="rc-ficha">
                            <asp:Literal ID="litFotoResumen" runat="server" />
                            <div><asp:Literal ID="litResumen" runat="server" /></div>
                        </asp:Panel>

                        <asp:Panel ID="pnlFichaEditar" runat="server" Visible="false" CssClass="rc-form">
                            <div class="rc-form-sec">
                                <div class="rc-grupo-tit"><i class="mdi mdi-tag-outline"></i>Identificación</div>
                                <div class="rc-form-grid">
                                    <div class="rc-campo">
                                        <label>Código</label>
                                        <div class="rc-fijo"><asp:Literal ID="litEdCodigo" runat="server" /></div>
                                        <span class="rc-ayuda">No cambia: está impreso en su etiqueta.</span>
                                    </div>
                                    <div class="rc-campo" style="grid-column: span 2">
                                        <label for="<%=txtEdNombre.ClientID %>">Nombre (*)</label>
                                        <asp:TextBox ID="txtEdNombre" runat="server" CssClass="form-control" MaxLength="400" />
                                    </div>
                                    <div class="rc-campo">
                                        <label>Tipo de repuesto</label>
                                        <rad:RadComboBox2 ID="cboEdTipo" runat="server" Width="100%" Filter="Contains" />
                                    </div>
                                    <div class="rc-campo">
                                        <label>Unidad de medida (*)</label>
                                        <rad:RadComboBox2 ID="cboEdUnidad" runat="server" Width="100%" Filter="Contains" />
                                        <span class="rc-ayuda">No se puede cambiar si tiene existencia.</span>
                                    </div>
                                    <div class="rc-campo">
                                        <label>Habilitado</label>
                                        <div class="rc-switch">
                                            <label><asp:RadioButton ID="rdbEdHabSi" runat="server" GroupName="EdHab" /><span>Sí</span></label>
                                            <label><asp:RadioButton ID="rdbEdHabNo" runat="server" GroupName="EdHab" /><span>No</span></label>
                                        </div>
                                        <span class="rc-ayuda">No se da de baja con existencia en bodega.</span>
                                    </div>
                                    <div class="rc-campo es-ancho">
                                        <label for="<%=txtEdDescripcion.ClientID %>">Descripción</label>
                                        <asp:TextBox ID="txtEdDescripcion" runat="server" TextMode="MultiLine" MaxLength="1000" />
                                    </div>
                                </div>
                            </div>

                            <div class="rc-form-sec">
                                <div class="rc-grupo-tit"><i class="mdi mdi-factory"></i>Fabricante y costo</div>
                                <div class="rc-form-grid">
                                    <div class="rc-campo">
                                        <label>Fabricante</label>
                                        <rad:RadComboBox2 ID="cboFabricante" runat="server" Width="100%" AllowCustomText="true"
                                            Filter="Contains" MaxLength="400" EmptyMessage="Elija o escriba uno nuevo"
                                            OnClientSelectedIndexChanged="sgFabCambio" OnClientBlur="sgFabCambio" />
                                    </div>
                                    <div class="rc-campo">
                                        <label>Modelo o código del fabricante</label>
                                        <rad:RadComboBox2 ID="cboModelo" runat="server" Width="100%" AllowCustomText="true"
                                            Filter="Contains" MaxLength="400" EmptyMessage="Primero el fabricante"
                                            OnClientSelectedIndexChanged="sgModAvisar" OnClientBlur="sgModCanon" />
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdCosto.ClientID %>">Costo de referencia</label>
                                        <asp:TextBox ID="txtEdCosto" runat="server" CssClass="form-control" MaxLength="14" />
                                        <span class="rc-ayuda">Referencial: el costo real sale de cada ingreso.</span>
                                    </div>
                                    <div class="rc-campo es-ancho">
                                        <div class="sg-fab-aviso" id="sgFabAviso" hidden></div>
                                        <asp:Literal ID="litFabCatalogo" runat="server" />
                                    </div>
                                </div>
                            </div>

                            <div class="rc-form-sec">
                                <div class="rc-grupo-tit"><i class="mdi mdi-cog-outline"></i>Cómo se opera</div>
                                <div class="rc-form-grid">
                                    <div class="rc-campo">
                                        <label>Controla lote</label>
                                        <div class="rc-switch">
                                            <label><asp:RadioButton ID="rdbEdLoteSi" runat="server" GroupName="EdLote" /><span>Sí</span></label>
                                            <label><asp:RadioButton ID="rdbEdLoteNo" runat="server" GroupName="EdLote" /><span>No</span></label>
                                        </div>
                                        <span class="rc-ayuda">El lote no se escribe aquí: al <strong>registrar un ingreso</strong> (pestaña Movimientos) se pide su código y vencimiento, y luego se ve en Existencias › Lotes.</span>
                                    </div>
                                    <div class="rc-campo">
                                        <label>Consumible</label>
                                        <div class="rc-switch">
                                            <label><asp:RadioButton ID="rdbEdConsSi" runat="server" GroupName="EdCons" /><span>Sí</span></label>
                                            <label><asp:RadioButton ID="rdbEdConsNo" runat="server" GroupName="EdCons" /><span>No</span></label>
                                        </div>
                                        <span class="rc-ayuda">Se gasta y no vuelve a bodega.</span>
                                    </div>
                                    <div class="rc-campo">
                                        <label>Reparable</label>
                                        <div class="rc-switch">
                                            <label><asp:RadioButton ID="rdbEdRepSi" runat="server" GroupName="EdRep" /><span>Sí</span></label>
                                            <label><asp:RadioButton ID="rdbEdRepNo" runat="server" GroupName="EdRep" /><span>No</span></label>
                                        </div>
                                        <span class="rc-ayuda">Sale, se repara y vuelve.</span>
                                    </div>
                                </div>
                            </div>

                            <div class="rc-form-sec">
                                <div class="rc-grupo-tit"><i class="mdi mdi-timer-sand"></i>Vida útil declarada</div>
                                <div class="rc-form-grid">
                                    <div class="rc-campo">
                                        <label for="<%=txtEdVidaHora.ClientID %>">Horas</label>
                                        <asp:TextBox ID="txtEdVidaHora" runat="server" CssClass="form-control" MaxLength="12" />
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdVidaDia.ClientID %>">Días</label>
                                        <asp:TextBox ID="txtEdVidaDia" runat="server" CssClass="form-control" MaxLength="8" />
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdVidaCiclo.ClientID %>">Ciclos</label>
                                        <asp:TextBox ID="txtEdVidaCiclo" runat="server" CssClass="form-control" MaxLength="12" />
                                    </div>
                                </div>
                                <span class="rc-ayuda">Lo que ocurra primero. Vacías si no se conocen.</span>
                            </div>

                            <div class="rc-form-sec">
                                <div class="rc-grupo-tit"><i class="mdi mdi-warehouse"></i>Almacenamiento</div>
                                <div class="rc-form-grid">
                                    <div class="rc-campo">
                                        <label>Método de salida</label>
                                        <rad:RadComboBox2 ID="cboEdMetodo" runat="server" Width="100%">
                                            <Items>
                                                <rad:RadComboBoxItem Value="" Text="Según la bodega" />
                                                <rad:RadComboBoxItem Value="FEFO" Text="FEFO · vence primero" />
                                                <rad:RadComboBoxItem Value="FIFO" Text="FIFO · entró primero" />
                                                <rad:RadComboBoxItem Value="LIFO" Text="LIFO · entró último" />
                                            </Items>
                                        </rad:RadComboBox2>
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdLargo.ClientID %>">Largo (cm)</label>
                                        <asp:TextBox ID="txtEdLargo" runat="server" CssClass="form-control" MaxLength="9" />
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdAncho.ClientID %>">Ancho (cm)</label>
                                        <asp:TextBox ID="txtEdAncho" runat="server" CssClass="form-control" MaxLength="9" />
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdAlto.ClientID %>">Alto (cm)</label>
                                        <asp:TextBox ID="txtEdAlto" runat="server" CssClass="form-control" MaxLength="9" />
                                    </div>
                                    <div class="rc-campo">
                                        <label for="<%=txtEdPeso.ClientID %>">Peso (kg)</label>
                                        <asp:TextBox ID="txtEdPeso" runat="server" CssClass="form-control" MaxLength="10" />
                                    </div>
                                </div>
                            </div>

                            <asp:Literal ID="litFichaAviso" runat="server" />
                            <div class="rc-form-pie">
                                <asp:LinkButton ID="lnkCancelarFicha" runat="server" CssClass="sg-ot-btn es-plano"
                                    OnClick="lnkCancelarFicha_Click" CausesValidation="false"><i class="mdi mdi-close"></i>Cancelar</asp:LinkButton>
                                <asp:LinkButton ID="lnkGuardarFicha" runat="server" CssClass="sg-ot-btn es-primario"
                                    OnClick="lnkGuardarFicha_Click" CausesValidation="false"><i class="mdi mdi-content-save-outline"></i>Guardar</asp:LinkButton>
                            </div>
                        </asp:Panel>
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
                            <asp:LinkButton ID="lnkNuevaCompat" runat="server" CssClass="sg-ot-btn es-primario"
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

                <%-- Reposicion y conteos (bloques 326 y 329): lo que se pidio para este
                     repuesto y las veces que se conto en bodega. --%>
                <section class="sg-a3-panel" data-panel="reposicion">
                    <asp:Panel ID="pnlRepoNueva" runat="server" CssClass="rc-card">
                        <h3>Solicitar reposición</h3>
                        <p class="rc-resultado">Queda como solicitud PENDIENTE con su número; se sigue en el mapa 3D (bodega › Reposición) y se imprime desde ahí.</p>
                        <div class="rc-subir-fila">
                            <rad:RadComboBox2 ID="cboRepoBodega" runat="server" Width="240px" Filter="Contains" />
                            <asp:TextBox ID="txtRepoCant" runat="server" CssClass="form-control" placeholder="Cantidad" style="max-width:130px" />
                            <asp:TextBox ID="txtRepoObs" runat="server" CssClass="form-control" placeholder="Observación (opcional): proveedor, urgencia…" />
                            <asp:LinkButton ID="lnkSolicitar" runat="server" CssClass="sg-ot-btn es-primario"
                                OnClick="lnkSolicitar_Click" CausesValidation="false"><i class="mdi mdi-cart-plus"></i>Solicitar</asp:LinkButton>
                        </div>
                        <asp:Literal ID="litRepoAviso" runat="server" />
                    </asp:Panel>
                    <div class="rc-card">
                        <h3>Solicitudes de reposición</h3>
                        <asp:Literal ID="litReposiciones" runat="server" />
                    </div>
                    <div class="rc-card">
                        <h3>Conteos cíclicos</h3>
                        <asp:Literal ID="litConteos" runat="server" />
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
                                <asp:LinkButton ID="lnkNuevoMov" runat="server" CssClass="sg-ot-btn es-primario"
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
                            <asp:LinkButton ID="lnkSubir" runat="server" CssClass="sg-ot-btn es-primario"
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
