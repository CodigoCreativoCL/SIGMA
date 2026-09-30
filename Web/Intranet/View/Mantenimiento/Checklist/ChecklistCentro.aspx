<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ChecklistCentro.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistCentro" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La cascara -tarjetas, chips, hero, pestañas- se reusa del centro del
         activo (Bryan, HU Control de activos). Aca solo va lo propio de la
         pauta. Mantiene topbar y sidebar del sistema (Default.master). --%>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-modal.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-orden.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-activo360.css") %>' rel="stylesheet" />
    <style type="text/css">
        /* Tokens de la paleta SIGMA (CLAUDE.md). No repetir hex sueltos. */
        .sg-pc {
            --sigma-purple: #6732F4; --sigma-purple-soft: #F2EFFF;
            --sigma-cyan-soft: #E8FBFB; --sigma-cyan-dark: #007F8A;
            --ink: #17223B; --muted: #68738A; --line: #E2E7F0;
            --success: #16855B; --warning: #B65C00;
        }
        /* Chips: fondo suave + texto del tono. Estado de negocio = semántico;
           versión = morado de marca. */
        .pc-badge { font-size: 11px; font-weight: 800; padding: 3px 10px; border-radius: 999px; display: inline-block; }
        .pc-badge.es-ver { background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .pc-badge.es-pub { background: #E7F4EE; color: var(--success); }
        .pc-badge.es-bor { background: #FBF0E3; color: var(--warning); }
        .pc-badge.es-ret { background: #EEF1F6; color: var(--muted); }
        .pc-badge.es-on  { background: #E7F4EE; color: var(--success); }
        .pc-badge.es-off { background: #EEF1F6; color: var(--muted); }
        .pc-proximo { padding: 26px; text-align: center; color: var(--muted); }
        .pc-proximo i { font-size: 34px; display: block; margin-bottom: 8px; color: var(--sigma-cyan-dark); }
        /* KPIs y tarjetas propias del Resumen (ccard blanca; color solo en icono/chip). */
        .sg-a3-kpis { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-bottom: 12px; }
        .sg-a3-kpi { display: flex; align-items: center; gap: 12px; background: #fff; border: 1px solid var(--line); border-radius: 14px; padding: 14px; }
        .sg-a3-kpi-ico { width: 40px; height: 40px; border-radius: 11px; display: flex; align-items: center; justify-content: center; background: var(--sigma-purple-soft); color: var(--sigma-purple); font-size: 20px; flex: 0 0 auto; }
        .sg-a3-kpi-ico.es-alerta { background: #FBEBEA; color: #C7352B; }
        .sg-a3-kpi-ico.es-info { background: var(--sigma-cyan-soft); color: var(--sigma-cyan-dark); }
        /* Donut de cumplimiento */
        .pc-donut { width: 46px; height: 46px; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex: 0 0 auto; }
        .pc-donut-in { width: 34px; height: 34px; border-radius: 50%; background: #fff; display: flex; align-items: center; justify-content: center; font-size: 11.5px; font-weight: 800; color: var(--ink); }
        /* Encabezado de indicadores */
        .sg-pc-ind { display: flex; align-items: baseline; justify-content: space-between; margin: 2px 0 10px; }
        .sg-pc-ind h4 { margin: 0; font-size: 14px; font-weight: 800; color: var(--ink); }
        .sg-pc-ind a { font-size: 12.5px; color: var(--sigma-blue); text-decoration: none; font-weight: 600; }
        /* Estado y ejecución */
        .sg-pc-ee { padding: 4px 4px 6px; font-size: 13px; color: var(--muted); line-height: 1.5; }
        .sg-pc-ee .l { display: flex; align-items: center; gap: 8px; padding: 6px 0; color: var(--ink); }
        .sg-pc-ee .l i { color: var(--muted); }
        .sg-a3-kpi-txt b { display: block; font-size: 20px; font-weight: 800; color: var(--ink); line-height: 1.1; }
        .sg-a3-kpi-txt span { color: var(--muted); font-size: 12.5px; }
        .sg-ot-nota { display: flex; gap: 8px; align-items: flex-start; color: var(--muted); font-size: 12px; background: var(--sigma-cyan-soft); border-radius: 10px; padding: 9px 12px; margin-bottom: 14px; }
        .sg-ot-aviso { display: flex; gap: 10px; align-items: flex-start; background: var(--sigma-purple-soft); border-radius: 12px; padding: 12px 14px; margin-bottom: 14px; color: var(--ink); font-size: 13px; }
        .sg-ot-vacio-min { padding: 14px 4px; color: var(--muted); font-size: 13px; text-align: center; }
        @media (max-width: 980px) { .sg-a3-kpis { grid-template-columns: repeat(2, 1fr); } }
        /* Estructura (secciones/ítems) */
        .sg-pc-sec { border: 1px solid var(--line); border-radius: 12px; margin-bottom: 12px; overflow: hidden; }
        .sg-pc-sec-cab { display: flex; align-items: center; gap: 8px; padding: 10px 14px; background: #FAFBFD; border-bottom: 1px solid var(--line); font-size: 13.5px; color: var(--ink); }
        .sg-pc-sec-cab i { color: var(--sigma-purple); }
        .sg-pc-sec-n { margin-left: auto; color: var(--muted); font-size: 12px; font-weight: 600; }
        .sg-pc-item { display: flex; align-items: center; gap: 10px; padding: 9px 14px; border-top: 1px solid #F1F4F9; font-size: 13px; }
        .sg-pc-item:first-of-type { border-top: none; }
        .sg-pc-item-txt { color: var(--ink); flex: 1; }
        .sg-pc-item-meta { color: var(--muted); font-size: 12px; white-space: nowrap; }
        /* Versiones */
        .sg-pc-vers-row { display: flex; align-items: center; gap: 12px; padding: 11px 6px; border-top: 1px solid #F1F4F9; font-size: 13px; }
        .sg-pc-vers-row:first-of-type { border-top: none; }
        .sg-pc-vers-num { font-weight: 800; color: var(--ink); min-width: 34px; }
        .sg-pc-vers-meta { color: var(--muted); font-size: 12.5px; flex: 1; }
        /* Filas de programaciones / ocurrencias */
        .sg-pc-linea { display: flex; align-items: center; gap: 12px; padding: 11px 6px; border-top: 1px solid #F1F4F9; font-size: 13px; }
        .sg-pc-linea:first-of-type { border-top: none; }
        .sg-pc-linea-ico { width: 34px; height: 34px; border-radius: 9px; display: flex; align-items: center; justify-content: center; background: var(--sigma-purple-soft); color: var(--sigma-purple); font-size: 17px; flex: 0 0 auto; }
        .sg-pc-linea-txt { flex: 1; min-width: 0; }
        .sg-pc-linea-txt b { color: var(--ink); font-weight: 700; display: block; }
        .sg-pc-linea-txt span { color: var(--muted); font-size: 12px; }
        .sg-pc-linea-fin { text-align: right; white-space: nowrap; color: var(--muted); font-size: 12px; }

        /* ===== Listado (layout propio, fiel al mockup 01) ===== */
        .pc-grid { display: grid; grid-template-columns: minmax(0,1fr) 320px; gap: 16px; align-items: start; }
        @media (max-width: 1100px) { .pc-grid { grid-template-columns: 1fr; } }
        .pc-card { background: var(--surface,#fff); border: 1px solid var(--line); border-radius: 14px; box-shadow: 0 1px 2px rgba(23,34,59,.04); padding: 18px; margin-bottom: 16px; }
        .pc-filtros { display: flex; gap: 14px; align-items: flex-end; flex-wrap: wrap; }
        .pc-f { display: flex; flex-direction: column; gap: 5px; }
        .pc-f > label { font-size: 11px; font-weight: 800; color: #4A556D; text-transform: uppercase; letter-spacing: .02em; }
        .pc-f.buscar { flex: 1; min-width: 220px; }
        .pc-search { display: flex; align-items: center; gap: 8px; border: 1px solid #CFD6E3; border-radius: 9px; padding: 8px 10px; background: #fff; }
        .pc-search input { border: none; outline: none; flex: 1; font-size: 13px; background: transparent; color: var(--ink); }
        .pc-search i { color: var(--muted); }
        .pc-list-cab { display: flex; align-items: center; justify-content: space-between; margin-bottom: 14px; }
        .pc-list-cab h3 { margin: 0; font-size: 15px; font-weight: 800; color: var(--ink); }
        .pc-list-cab .s { color: var(--muted); font-size: 12.5px; }
        .pc-table { width: 100%; border-collapse: collapse; }
        .pc-table th { text-align: left; font-size: 11px; font-weight: 800; color: var(--muted); text-transform: uppercase; letter-spacing: .03em; padding: 8px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
        .pc-table td { padding: 13px 10px; border-bottom: 1px solid #F1F4F9; font-size: 13px; color: var(--ink); vertical-align: middle; }
        .pc-table tr:last-child td { border-bottom: none; }
        .pc-table .cod { font-weight: 700; color: var(--ink); }
        .pc-table .nom { color: var(--ink); }
        .pc-table .acc { text-align: right; }
        /* Botones por función (CLAUDE.md): morado primario, contorno azul para navegar */
        .pc-btn { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 700; border-radius: 9px; padding: 8px 14px; cursor: pointer; text-decoration: none; border: 1px solid transparent; }
        .pc-btn.prim { background: var(--sigma-purple); color: #fff; }
        .pc-btn.prim:hover { background: var(--sigma-purple-dark); }
        .pc-btn.out { background: #fff; color: var(--sigma-blue); border-color: #CFD6E3; }
        .pc-btn.out:hover { border-color: var(--sigma-blue); background: var(--sigma-blue-soft); }
        /* Tarjeta lateral "Un solo centro" */
        .pc-aside .pc-card { text-align: left; }
        .pc-aside-ico { width: 46px; height: 46px; border-radius: 12px; background: var(--sigma-purple-soft); color: var(--sigma-purple); display: flex; align-items: center; justify-content: center; font-size: 24px; margin-bottom: 12px; }
        .pc-aside h3 { margin: 0 0 6px; font-size: 17px; font-weight: 800; color: var(--ink); }
        .pc-aside p { margin: 0 0 14px; color: var(--muted); font-size: 13px; line-height: 1.55; }
        .pc-aside a.link { display: inline-flex; align-items: center; gap: 6px; color: var(--sigma-blue); font-weight: 700; font-size: 13px; text-decoration: none; }
        .pc-vacio { padding: 30px; text-align: center; color: var(--muted); }
        .pc-vacio i { font-size: 34px; display: block; margin-bottom: 8px; color: var(--sigma-cyan-dark); }

        /* ===== Formulario de Configuración (mockup 03) ===== */
        .pc-form-sec { font-size: 15px; font-weight: 800; color: var(--ink); margin: 4px 0 14px; }
        .pc-form-sec:not(:first-child) { margin-top: 24px; padding-top: 20px; border-top: 1px solid var(--line); }
        .pc-grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        .pc-grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px; }
        @media (max-width: 760px) { .pc-grid-2, .pc-grid-3 { grid-template-columns: 1fr; } }
        .pc-fld { display: flex; flex-direction: column; gap: 6px; margin-bottom: 4px; }
        .pc-fld > label { font-size: 11px; font-weight: 800; color: #4A556D; text-transform: uppercase; letter-spacing: .02em; }
        .pc-fld > label .req { color: var(--danger,#C7352B); }
        .pc-fld .ayuda { font-size: 12px; color: var(--muted); }
        .pc-fld .ro { background: #F4F6FA; border: 1px solid var(--line); border-radius: 9px; padding: 9px 12px; font-size: 13px; color: var(--ink); }
        .pc-form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 22px; padding-top: 18px; border-top: 1px solid var(--line); }
        /* Toggle habilitada */
        .pc-toggle { display: inline-flex; align-items: center; gap: 10px; }
        .pc-toggle input { position: absolute; opacity: 0; width: 0; height: 0; }
        .pc-toggle .sw { width: 42px; height: 24px; border-radius: 999px; background: #CFD6E3; position: relative; transition: background .15s; cursor: pointer; }
        .pc-toggle .sw::after { content: ''; position: absolute; top: 2px; left: 2px; width: 20px; height: 20px; border-radius: 50%; background: #fff; transition: left .15s; box-shadow: 0 1px 2px rgba(0,0,0,.2); }
        .pc-toggle input:checked + .sw { background: var(--success); }
        .pc-toggle input:checked + .sw::after { left: 20px; }
        /* Inputs Telerik/estándar dentro del form (borde y radio consistentes) */
        .pc-form .RadComboBox, .pc-form .rcbInputCell { border-radius: 9px !important; }
        .pc-ta { width: 100%; box-sizing: border-box; border: 1px solid #CFD6E3; border-radius: 9px; padding: 9px 12px; font-size: 13px; font-family: inherit; color: var(--ink); resize: vertical; min-height: 70px; }
        .pc-ta:focus { outline: 3px solid rgba(22,198,201,.27); border-color: var(--sigma-cyan-dark); }
        .pc-info-card { background: var(--sigma-purple-soft); border: 1px solid #E4DDFF; border-radius: 14px; padding: 16px; }
        .pc-info-card .t { display: flex; gap: 8px; align-items: flex-start; font-weight: 800; color: var(--ink); font-size: 14px; margin-bottom: 8px; }
        .pc-info-card .t i { color: var(--sigma-purple); font-size: 18px; }
        .pc-info-card p { margin: 0 0 10px; color: var(--muted); font-size: 12.5px; line-height: 1.5; }

        /* ===== Estructura (mockup 04): 3 columnas ===== */
        .pc-est-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 14px; }
        .pc-est-head .t { font-size: 15px; font-weight: 800; color: var(--ink); display: flex; align-items: center; gap: 8px; }
        .pc-est-grid { display: grid; grid-template-columns: 300px minmax(0,1fr) 300px; gap: 16px; align-items: start; }
        @media (max-width: 1200px) { .pc-est-grid { grid-template-columns: 260px minmax(0,1fr); } .pc-est-side { display: none; } }
        @media (max-width: 820px) { .pc-est-grid { grid-template-columns: 1fr; } }
        .pc-tree { }
        .pc-tree-sec { margin-bottom: 6px; }
        .pc-tree-sec > .cab { display: flex; align-items: center; gap: 8px; padding: 9px 10px; border-radius: 9px; cursor: pointer; font-weight: 700; color: var(--ink); font-size: 13.5px; }
        .pc-tree-sec > .cab:hover { background: #F4F6FA; }
        .pc-tree-sec > .cab .chev { transition: transform .15s; color: var(--muted); }
        .pc-tree-sec.cerrada > .cab .chev { transform: rotate(-90deg); }
        .pc-tree-sec > .cab .n { margin-left: auto; color: var(--muted); font-weight: 600; font-size: 12px; }
        .pc-tree-items { padding-left: 8px; }
        .pc-tree-sec.cerrada .pc-tree-items { display: none; }
        .pc-tree-item { display: flex; align-items: center; gap: 10px; padding: 8px 10px 8px 14px; border-radius: 9px; cursor: pointer; font-size: 13px; color: var(--ink); }
        .pc-tree-item:hover { background: #F4F6FA; }
        .pc-tree-item.es-sel { background: var(--sigma-purple-soft); color: var(--sigma-purple); font-weight: 700; }
        .pc-tree-item .num { color: var(--muted); font-size: 12px; min-width: 14px; }
        .pc-tree-item.es-sel .num { color: var(--sigma-purple); }
        .pc-det { display: none; }
        .pc-det.es-sel { display: block; }
        .pc-det-h { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 4px; }
        .pc-det-h h2 { margin: 0; font-size: 19px; font-weight: 800; color: var(--ink); }
        .pc-det-h .sec { color: var(--muted); font-size: 13px; margin-top: 2px; }
        .pc-det-nav { display: flex; align-items: center; gap: 8px; white-space: nowrap; }
        .pc-det-nav .cnt { background: var(--sigma-purple-soft); color: var(--sigma-purple); border-radius: 999px; padding: 4px 12px; font-size: 12.5px; font-weight: 700; }
        .pc-det-attrs { display: grid; grid-template-columns: repeat(6, 1fr); gap: 12px; border: 1px solid var(--line); border-radius: 12px; padding: 14px; margin: 14px 0; }
        @media (max-width: 900px) { .pc-det-attrs { grid-template-columns: repeat(3, 1fr); } }
        .pc-attr .k { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: .03em; margin-bottom: 5px; }
        .pc-attr .v { font-size: 13px; color: var(--ink); font-weight: 600; display: flex; align-items: center; gap: 6px; }
        .pc-det-block { border: 1px solid var(--line); border-radius: 12px; padding: 14px; margin-bottom: 12px; }
        .pc-det-block h4 { margin: 0 0 6px; font-size: 13px; font-weight: 800; color: var(--ink); }
        .pc-det-block p, .pc-det-block ol { margin: 0; color: #384357; font-size: 13px; line-height: 1.55; }
        .pc-det-block ol { padding-left: 18px; }
        /* Preview móvil */
        .pc-phone { border: 8px solid #17223B; border-radius: 26px; padding: 14px 12px; background: #fff; }
        .pc-phone .ph-cab { font-size: 12px; font-weight: 700; color: var(--ink); margin-bottom: 10px; display: flex; justify-content: space-between; }
        .pc-phone .ph-sec { font-size: 11px; color: var(--sigma-purple); font-weight: 700; text-transform: uppercase; }
        .pc-phone .ph-q { font-size: 14px; font-weight: 700; color: var(--ink); margin: 4px 0 10px; }
        .pc-phone .ph-in { border: 1px solid #CFD6E3; border-radius: 8px; padding: 8px 10px; font-size: 13px; color: var(--muted); display: flex; justify-content: space-between; }
        .pc-phone .ph-hint { font-size: 11px; color: var(--muted); margin: 6px 0 10px; }
        .pc-ph-wrap { display: none; }
        .pc-ph-wrap.es-sel { display: block; }
        /* Programaciones: fila seleccionable + detalle */
        .pc-table tr.pc-prog-fila { cursor: pointer; }
        .pc-table tr.pc-prog-fila.es-sel { background: var(--sigma-purple-soft); }
        .pc-prog-det { display: none; }
        .pc-prog-det.es-sel { display: block; }
        /* Master-detalle de ocurrencias (mockup 07) */
        .pc-md-grid { display: grid; grid-template-columns: minmax(0,440px) minmax(0,1fr); gap: 16px; align-items: start; }
        @media (max-width: 1050px) { .pc-md-grid { grid-template-columns: 1fr; } }
        .pc-table tr.pc-oc-fila { cursor: pointer; }
        .pc-table tr.pc-oc-fila.es-sel { background: var(--sigma-purple-soft); }
        .pc-ej-attrs { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 12px 0 18px; }
        @media (max-width: 900px) { .pc-ej-attrs { grid-template-columns: repeat(2, 1fr); } }
        .pc-ej-attr { display: flex; gap: 10px; align-items: flex-start; }
        .pc-ej-attr .ic { width: 34px; height: 34px; border-radius: 9px; background: var(--sigma-purple-soft); color: var(--sigma-purple); display: flex; align-items: center; justify-content: center; font-size: 17px; flex: 0 0 auto; }
        .pc-ej-attr .k { font-size: 11px; color: var(--muted); }
        .pc-ej-attr .v { font-size: 13px; color: var(--ink); font-weight: 600; }
        .pc-resp-foto img { width: 52px; height: 40px; object-fit: cover; border-radius: 6px; border: 1px solid var(--line); vertical-align: middle; }
        /* Hallazgos de la pauta (mockup 08) */
        .pc-table tr.pc-hz-fila { cursor: pointer; }
        .pc-table tr.pc-hz-fila.es-sel { background: var(--sigma-purple-soft); }
        .pc-hz-det { display: none; }
        .pc-hz-det.es-sel { display: block; }
        .pc-hz-h { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; }
        .pc-hz-meta { color: var(--muted); font-size: 12.5px; display: flex; flex-direction: column; gap: 4px; margin: 8px 0 14px; }
        .pc-hz-meta span { display: flex; align-items: center; gap: 6px; }
        .pc-hz-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin-bottom: 14px; }
        .pc-hz-grid .k { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: .02em; margin-bottom: 3px; }
        .pc-hz-grid .v { font-size: 15px; font-weight: 800; color: var(--ink); }
        .pc-hz-grid .v.sm { font-size: 13px; font-weight: 600; }
        .pc-hz-acc { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 8px; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* Abrir el centro de una pauta: el id viaja en un campo oculto y el
           servidor arma el centro (mismo patrón que el centro del activo). */
        function abrirCentro(id) {
            document.getElementById('hdnPlantilla').value = id;
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
            return false;
        }

        /* Alta/edición de la pauta en el mismo modal de siempre. */
        function abrirPauta(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistPlantilla.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva pauta de inspección' : 'Editar pauta de inspección',
                width: 860, initialHeight: 560
            });
        }
        /* Alta/edición de una programación de la pauta, en modal. */
        function abrirProgramacion(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistProgramacion.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva programación de pauta' : 'Editar programación de pauta',
                width: 860, initialHeight: 560
            });
        }
        function refresh() { __doPostBack('<%=lnkRecargar.UniqueID %>', ''); }

        /* Estructura: seleccionar un ítem del árbol muestra su detalle y su
           preview móvil (sin postback: todo viene pintado y oculto). */
        function pcEstSel(id) {
            id = String(id);
            var t = document.querySelectorAll('.pc-tree-item');
            for (var i = 0; i < t.length; i++) t[i].classList.toggle('es-sel', t[i].getAttribute('data-item') === id);
            var d = document.querySelectorAll('.pc-det');
            for (var j = 0; j < d.length; j++) d[j].classList.toggle('es-sel', d[j].getAttribute('data-detail') === id);
            var p = document.querySelectorAll('.pc-ph-wrap');
            for (var k = 0; k < p.length; k++) p[k].classList.toggle('es-sel', p[k].getAttribute('data-prev') === id);
            return false;
        }
        function pcEstNav(dir) {
            var t = document.querySelectorAll('.pc-tree-item'), ids = [], cur = null;
            for (var i = 0; i < t.length; i++) { ids.push(t[i].getAttribute('data-item')); if (t[i].classList.contains('es-sel')) cur = t[i].getAttribute('data-item'); }
            var idx = ids.indexOf(cur); if (idx < 0) idx = 0;
            var n = idx + dir; if (n < 0) n = 0; if (n >= ids.length) n = ids.length - 1;
            if (ids.length) pcEstSel(ids[n]);
            return false;
        }

        /* Ocurrencias: seleccionar una ejecución carga su detalle (postback,
           porque las respuestas pueden ser cientos). */
        function pcOcSel(ejecId) {
            document.getElementById('hdnEjec').value = ejecId;
            __doPostBack('<%=lnkRecargar.UniqueID %>', '');
            return false;
        }

        /* Programaciones: seleccionar una fila muestra su detalle en el aside. */
        function pcProgSel(id) {
            id = String(id);
            var r = document.querySelectorAll('.pc-prog-fila');
            for (var i = 0; i < r.length; i++) r[i].classList.toggle('es-sel', r[i].getAttribute('data-prog') === id);
            var d = document.querySelectorAll('.pc-prog-det');
            for (var j = 0; j < d.length; j++) d[j].classList.toggle('es-sel', d[j].getAttribute('data-progdet') === id);
            return false;
        }

        /* Hallazgos de la pauta: seleccionar una fila muestra su detalle. */
        function pcHzSel(id) {
            id = String(id);
            var r = document.querySelectorAll('.pc-hz-fila');
            for (var i = 0; i < r.length; i++) r[i].classList.toggle('es-sel', r[i].getAttribute('data-hz') === id);
            var d = document.querySelectorAll('.pc-hz-det');
            for (var j = 0; j < d.length; j++) d[j].classList.toggle('es-sel', d[j].getAttribute('data-hzdet') === id);
            return false;
        }

        /* ---- Cambio de pestaña en el navegador (sin postback: los paneles ya
               vienen armados). hdnSeccion recuerda cuál quedó abierta. ---- */
        (function () {
            function irA(sec) {
                if (!sec) sec = 'resumen';
                var h = document.getElementById('hdnSeccion'); if (h) h.value = sec;
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
            window.sigmaPautaIrA = irA;
            function aplicar() {
                var h = document.getElementById('hdnSeccion');
                irA(h ? h.value : 'resumen');
            }
            document.addEventListener('DOMContentLoaded', aplicar);
            // Tras un postback asíncrono del UpdatePanel, el HTML de los paneles
            // se reemplaza y pierde la clase activa: hay que re-aplicarla.
            if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
                Sys.WebForms.PageRequestManager.getInstance().add_endRequest(aplicar);
        })();
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Pautas de inspección</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Un solo centro: diseña, publica, programa y revisa resultados.
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus pautas de inspección.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <asp:HiddenField ID="hdnPlantilla" runat="server" Value="0" ClientIDMode="Static" />
            <asp:HiddenField ID="hdnSeccion" runat="server" Value="resumen" ClientIDMode="Static" />
            <asp:HiddenField ID="hdnEjec" runat="server" Value="0" ClientIDMode="Static" />
            <asp:LinkButton ID="lnkRecargar" runat="server" style="display:none" CausesValidation="false" OnClick="lnkRecargar_Click" />

            <%-- ==================== LISTADO ==================== --%>
            <asp:Panel ID="pnlLista" runat="server" CssClass="sg-pc">
                <div class="pc-grid">
                    <div class="pc-main">
                        <div class="pc-card">
                            <div class="pc-filtros">
                                <div class="pc-f">
                                    <label>Planta</label>
                                    <rad:RadComboBox2 ID="cboPlanta" runat="server" AutoPostBack="true" Width="210px" OnLoad="LoadControls" Filter="Contains" />
                                </div>
                                <div class="pc-f">
                                    <label>Estado</label>
                                    <rad:RadComboBox2 ID="cboEstado" runat="server" AutoPostBack="true" Width="180px">
                                        <Items>
                                            <rad:RadComboBoxItem Text="Todos" Value="" />
                                            <rad:RadComboBoxItem Text="Habilitadas" Value="1" />
                                            <rad:RadComboBoxItem Text="Deshabilitadas" Value="0" />
                                        </Items>
                                    </rad:RadComboBox2>
                                </div>
                                <div class="pc-f buscar">
                                    <label>Buscar</label>
                                    <span class="pc-search"><i class="mdi mdi-magnify"></i>
                                        <input type="search" id="sgPautaBuscar" autocomplete="off" placeholder="Buscar por código, nombre o descripción..." onkeyup="sgPautaFiltrar(this.value)" />
                                    </span>
                                </div>
                            </div>
                        </div>

                        <div class="pc-card">
                            <div class="pc-list-cab">
                                <div><h3>Pautas de inspección</h3><span class="s">Toque Abrir para entrar al centro de la pauta.</span></div>
                                <asp:LinkButton ID="lnkNueva" runat="server" CssClass="pc-btn prim" OnClientClick="return abrirPauta(0);"><i class="mdi mdi-plus"></i>Nueva pauta</asp:LinkButton>
                            </div>
                            <asp:Literal ID="litLista" runat="server" />
                            <asp:Panel ID="pnlListaVacia" runat="server" Visible="false" CssClass="pc-vacio">
                                <i class="mdi mdi-clipboard-off-outline"></i>
                                <p>No hay pautas que coincidan</p>
                                <span>Ajuste el filtro o cree una nueva pauta.</span>
                            </asp:Panel>
                        </div>
                    </div>

                    <aside class="pc-aside">
                        <div class="pc-card">
                            <div class="pc-aside-ico"><i class="mdi mdi-clipboard-check-outline"></i></div>
                            <h3>Un solo centro</h3>
                            <p>Diseña, publica, programa y revisa resultados. Las pautas se crean una vez, se versionan y se ejecutan en las rondas programadas o en inspecciones puntuales.</p>
                            <asp:HyperLink ID="hlHallazgos" runat="server" CssClass="link"><i class="mdi mdi-alert-outline"></i>Ir a hallazgos de inspección</asp:HyperLink>
                        </div>
                    </aside>
                </div>
            </asp:Panel>

            <%-- ==================== CENTRO DE LA PAUTA ==================== --%>
            <asp:Panel ID="pnlFicha" runat="server" Visible="false" CssClass="sg-a3 sg-ot sg-pc">

                <div class="sg-a3-miga">
                    <span>Pautas de inspección</span>
                    <span class="sep">/</span>
                    <asp:LinkButton ID="lnkVolver" runat="server" OnClick="lnkVolver_Click" CausesValidation="false">Listado</asp:LinkButton>
                    <span class="sep">/</span><asp:Literal ID="litMiga" runat="server" />
                </div>

                <header class="sg-a3-hero">
                    <div class="sg-a3-hero-txt">
                        <h1><asp:Literal ID="litHeroNombre" runat="server" /></h1>
                        <div class="sg-a3-hero-sub"><asp:Literal ID="litHeroSub" runat="server" /></div>
                    </div>
                    <div class="sg-a3-hero-acc">
                        <asp:HyperLink ID="hlEditar" runat="server" CssClass="sg-ot-btn es-plano" NavigateUrl="javascript:void(0)"
                            ToolTip="Editar la configuración de la pauta"><i class="mdi mdi-pencil-outline"></i>Editar</asp:HyperLink>
                    </div>
                </header>

                <nav class="sg-a3-nav">
                    <a href="#" class="sg-a3-tab" data-sec="resumen"><i class="mdi mdi-view-dashboard-outline"></i>Resumen</a>
                    <a href="#" class="sg-a3-tab" data-sec="configuracion"><i class="mdi mdi-cog-outline"></i>Configuración</a>
                    <a href="#" class="sg-a3-tab" data-sec="estructura"><i class="mdi mdi-file-tree-outline"></i>Estructura</a>
                    <a href="#" class="sg-a3-tab" data-sec="versiones"><i class="mdi mdi-history"></i>Versiones</a>
                    <a href="#" class="sg-a3-tab" data-sec="programaciones"><i class="mdi mdi-calendar-clock"></i>Programaciones</a>
                    <a href="#" class="sg-a3-tab" data-sec="ocurrencias"><i class="mdi mdi-play-circle-outline"></i>Ocurrencias y ejecuciones</a>
                    <a href="#" class="sg-a3-tab" data-sec="hallazgos"><i class="mdi mdi-alert-outline"></i>Hallazgos</a>
                </nav>

                <%-- 1. RESUMEN --%>
                <section class="sg-a3-panel" data-panel="resumen">
                    <asp:Literal ID="litResumenAviso" runat="server" />
                    <asp:Literal ID="litKpis" runat="server" />
                    <div class="sg-a3-cols">
                        <div class="sg-a3-col">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico"><i class="mdi mdi-play-circle-outline"></i></span>
                                    <div><h3>Última ejecución</h3><p class="sg-ot-card-sub">La ronda más reciente de esta pauta.</p></div>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="ocurrencias">Ver ejecuciones <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litUltima" runat="server" />
                            </div>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab">
                                    <span class="sg-ot-card-ico es-alerta"><i class="mdi mdi-alert-outline"></i></span>
                                    <div><h3>Hallazgos que requieren atención</h3><p class="sg-ot-card-sub">Lo abierto sobre esta pauta.</p></div>
                                    <a href="#" class="sg-ot-card-acc sg-ot-link" data-ir-sec="hallazgos">Ver hallazgos <i class="mdi mdi-arrow-right"></i></a>
                                </header>
                                <asp:Literal ID="litHallazgos" runat="server" />
                            </div>
                        </div>
                        <aside class="sg-a3-lado">
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab"><span class="sg-ot-card-ico"><i class="mdi mdi-information-outline"></i></span><h3>Información general</h3></header>
                                <asp:Literal ID="litInfo" runat="server" />
                            </div>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab"><span class="sg-ot-card-ico"><i class="mdi mdi-cube-outline"></i></span><h3>Versión actual</h3></header>
                                <asp:Literal ID="litVersion" runat="server" />
                                <div class="sg-ot-card-pie">
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="estructura"><i class="mdi mdi-file-tree-outline"></i>Ver estructura</a>
                                    <a href="#" class="sg-ot-btn es-plano" data-ir-sec="versiones"><i class="mdi mdi-history"></i>Versiones</a>
                                </div>
                            </div>
                            <div class="sg-ot-card">
                                <header class="sg-ot-card-cab"><span class="sg-ot-card-ico"><i class="mdi mdi-power"></i></span><h3>Estado y ejecución</h3></header>
                                <asp:Literal ID="litEstadoEjec" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- 2-7: en construcción (fases siguientes) --%>
                <%-- 2. CONFIGURACIÓN (formulario editable, mockup 03) --%>
                <section class="sg-a3-panel" data-panel="configuracion">
                    <div class="pc-grid">
                        <div class="pc-card pc-form">
                            <div class="pc-form-sec">Identificación</div>
                            <div class="pc-grid-2">
                                <div class="pc-fld">
                                    <label>Código</label>
                                    <WebControls:TextBox2 ID="txtCodigoCfg" runat="server" MaxLength="50" />
                                    <span class="ayuda">Único por cliente. No se puede editar.</span>
                                </div>
                                <div class="pc-fld">
                                    <label>Nombre <span class="req">*</span></label>
                                    <WebControls:TextBox2 ID="txtNombreCfg" runat="server" MaxLength="200" />
                                </div>
                            </div>
                            <div class="pc-grid-2">
                                <div class="pc-fld">
                                    <label>Descripción</label>
                                    <asp:TextBox ID="txtDescripcionCfg" runat="server" TextMode="MultiLine" Rows="3" CssClass="pc-ta" />
                                </div>
                                <div class="pc-fld">
                                    <label>Habilitada</label>
                                    <label class="pc-toggle"><asp:CheckBox ID="chkHabilitadaCfg" runat="server" /><span class="sw"></span></label>
                                    <span class="ayuda">Si está deshabilitada, la pauta existe pero no estará disponible en las programaciones ni inspecciones.</span>
                                </div>
                            </div>

                            <div class="pc-form-sec">Alcance</div>
                            <div class="pc-grid-3">
                                <div class="pc-fld"><label>Planta</label><rad:RadComboBox2 ID="cboPlantaCfg" runat="server" Filter="Contains" Width="100%" /><span class="ayuda">Vacío: todas las plantas.</span></div>
                                <div class="pc-fld"><label>Tipo de activo</label><rad:RadComboBox2 ID="cboActivoTipoCfg" runat="server" Filter="Contains" Width="100%" /></div>
                                <div class="pc-fld"><label>Tipo de asignación</label><rad:RadComboBox2 ID="cboAsignacionCfg" runat="server" Filter="Contains" Width="100%" /></div>
                            </div>

                            <div class="pc-form-sec">Información adicional</div>
                            <div class="pc-grid-2">
                                <div class="pc-fld"><label>ID</label><div class="ro"><asp:Literal ID="litCfgId" runat="server" /></div></div>
                                <div class="pc-fld"><label>Creado el</label><div class="ro"><asp:Literal ID="litCfgCreado" runat="server" /></div></div>
                            </div>

                            <div class="pc-form-actions">
                                <asp:LinkButton ID="btnCancelarCfg" runat="server" CssClass="pc-btn out" OnClick="lnkRecargar_Click" CausesValidation="false"><i class="mdi mdi-close"></i>Cancelar</asp:LinkButton>
                                <asp:LinkButton ID="btnGuardarCfg" runat="server" CssClass="pc-btn prim" OnClick="btnGuardarCfg_Click"><i class="mdi mdi-content-save-outline"></i>Guardar cambios</asp:LinkButton>
                            </div>
                        </div>

                        <aside class="pc-aside">
                            <div class="pc-info-card">
                                <div class="t"><i class="mdi mdi-information-outline"></i>Los cambios de alcance no modifican respuestas históricas</div>
                                <p>Modificar la planta, el tipo de activo o el tipo de asignación solo afecta futuras programaciones y ejecuciones.</p>
                                <p>La publicación de una nueva versión es independiente del estado de habilitación.</p>
                            </div>
                        </aside>
                    </div>
                </section>
                <%-- 3. ESTRUCTURA (mockup 04: árbol + detalle + preview) --%>
                <section class="sg-a3-panel" data-panel="estructura">
                    <div class="pc-est-head">
                        <div class="t"><i class="mdi mdi-file-tree-outline"></i>Estructura de la pauta<asp:Literal ID="litEstVer" runat="server" /></div>
                        <div style="display:flex;gap:8px;flex-wrap:wrap;">
                            <asp:HyperLink ID="hlUmbrales" runat="server" CssClass="pc-btn out"><i class="mdi mdi-tune-variant"></i>Umbrales</asp:HyperLink>
                            <asp:HyperLink ID="hlDependencias" runat="server" CssClass="pc-btn out"><i class="mdi mdi-sitemap-outline"></i>Dependencias</asp:HyperLink>
                            <asp:HyperLink ID="hlEditarEstructura" runat="server" CssClass="pc-btn prim" NavigateUrl="javascript:void(0)"><i class="mdi mdi-file-document-edit-outline"></i>Crear/editar borrador</asp:HyperLink>
                        </div>
                    </div>
                    <div class="pc-est-grid">
                        <div class="pc-card pc-tree"><asp:Literal ID="litEstTree" runat="server" /></div>
                        <div class="pc-card"><asp:Literal ID="litEstDetail" runat="server" /></div>
                        <aside class="pc-est-side">
                            <div class="pc-card" style="margin-bottom:14px;">
                                <div style="font-size:12px;font-weight:800;color:var(--muted);text-transform:uppercase;margin-bottom:10px;">Vista previa en móvil</div>
                                <asp:Literal ID="litEstPreview" runat="server" />
                            </div>
                            <div class="pc-info-card" style="margin-bottom:12px;">
                                <div class="t"><i class="mdi mdi-information-outline"></i>Versión publicada</div>
                                <p>Esta versión está publicada y no se puede editar. Crea un borrador para realizar cambios.</p>
                            </div>
                            <div class="pc-info-card">
                                <div class="t"><i class="mdi mdi-lightbulb-outline"></i>En el borrador podrás</div>
                                <p>Agregar sección, agregar ítem, ordenar, configurar opciones, definir validaciones y dependencias.</p>
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- 4. VERSIONES (mockup 05) --%>
                <section class="sg-a3-panel" data-panel="versiones">
                    <div class="pc-grid">
                        <div class="pc-main">
                            <div class="pc-card">
                                <div class="pc-list-cab">
                                    <div><h3>Historial de versiones</h3><span class="s">Listado de versiones de la pauta y sus estados.</span></div>
                                    <asp:HyperLink ID="hlNuevaVersion" runat="server" CssClass="pc-btn prim" NavigateUrl="javascript:void(0)"><i class="mdi mdi-plus"></i>Crear nueva versión</asp:HyperLink>
                                </div>
                                <asp:Literal ID="litVersiones" runat="server" />
                            </div>
                            <asp:Panel ID="pnlComparacion" runat="server" CssClass="pc-card" Visible="false">
                                <div class="pc-list-cab" style="margin-bottom:6px;">
                                    <div><h3>Comparación de cambios</h3><span class="s">Resumen entre la versión publicada y el borrador.</span></div>
                                </div>
                                <asp:Literal ID="litComparacion" runat="server" />
                            </asp:Panel>
                        </div>
                        <aside class="pc-aside">
                            <div class="pc-card" style="margin-bottom:14px;">
                                <h3 style="margin:0 0 10px;font-size:15px;font-weight:800;color:var(--ink);">Revisión de publicación</h3>
                                <asp:Literal ID="litPublicacion" runat="server" />
                                <div style="margin-top:14px;">
                                    <asp:LinkButton ID="lnkPublicar" runat="server" CssClass="pc-btn prim" Visible="false"
                                        OnClick="lnkPublicar_Click" style="width:100%;justify-content:center;"
                                        OnClientClick="return confirm('¿Publicar la versión en borrador? La publicada anterior pasará a retirada.');"><i class="mdi mdi-publish"></i>Revisar y publicar</asp:LinkButton>
                                </div>
                            </div>
                            <div class="pc-info-card">
                                <div class="t"><i class="mdi mdi-information-outline"></i>Las ejecuciones históricas mantienen su versión original</div>
                                <p>Las ocurrencias y ejecuciones registradas conservan la versión con la que fueron generadas. No se realiza migración automática.</p>
                            </div>
                        </aside>
                    </div>
                </section>
                <%-- 5. PROGRAMACIONES (mockup 06) --%>
                <section class="sg-a3-panel" data-panel="programaciones">
                    <div class="pc-grid">
                        <div class="pc-main">
                            <div class="pc-card">
                                <div class="pc-list-cab">
                                    <div><h3>Programaciones</h3><span class="s">Define cuándo y sobre qué activos o áreas se ejecuta esta pauta.</span></div>
                                    <asp:HyperLink ID="hlNuevaProg" runat="server" CssClass="pc-btn prim" NavigateUrl="javascript:void(0)"><i class="mdi mdi-plus"></i>Nueva programación</asp:HyperLink>
                                </div>
                                <asp:Literal ID="litProgramaciones" runat="server" />
                            </div>
                        </div>
                        <aside class="pc-aside">
                            <div class="pc-card">
                                <h3 style="margin:0 0 2px;font-size:15px;font-weight:800;color:var(--ink);">Detalle de programación</h3>
                                <div style="color:var(--muted);font-size:12.5px;margin-bottom:14px;">Parámetros de la programación seleccionada.</div>
                                <asp:Literal ID="litProgDetalle" runat="server" />
                            </div>
                        </aside>
                    </div>
                </section>

                <%-- 6. OCURRENCIAS Y EJECUCIONES (mockup 07: master-detalle) --%>
                <section class="sg-a3-panel" data-panel="ocurrencias">
                    <div class="pc-md-grid">
                        <div class="pc-card">
                            <div style="margin-bottom:12px;">
                                <h3 style="margin:0;font-size:15px;font-weight:800;color:var(--ink);">Ocurrencias y ejecuciones</h3>
                                <span style="color:var(--muted);font-size:12.5px;">Historial de ejecuciones de la pauta. Toque una fila ejecutada para ver su detalle.</span>
                            </div>
                            <asp:Literal ID="litOcurrencias" runat="server" />
                        </div>
                        <div class="pc-card">
                            <asp:Literal ID="litEjecucion" runat="server" />
                        </div>
                    </div>
                </section>
                <%-- 7. HALLAZGOS DE LA PAUTA (mockup 08: master-detalle, filtro de pauta fijo) --%>
                <section class="sg-a3-panel" data-panel="hallazgos">
                    <div class="pc-md-grid" style="grid-template-columns: minmax(0,1fr) 340px;">
                        <div class="pc-main">
                            <div class="pc-card">
                                <div class="pc-list-cab">
                                    <div><h3>Hallazgos de la pauta</h3><span class="s">Lo detectado en las ejecuciones de esta pauta. El filtro de pauta es fijo.</span></div>
                                    <asp:HyperLink ID="hlBandeja" runat="server" CssClass="pc-btn out"><i class="mdi mdi-tray-full"></i>Ver bandeja global</asp:HyperLink>
                                </div>
                                <asp:Literal ID="litHallazgosPauta" runat="server" />
                            </div>
                        </div>
                        <aside class="pc-aside">
                            <div class="pc-card"><asp:Literal ID="litHallazgoDet" runat="server" /></div>
                        </aside>
                    </div>
                </section>

            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>

    <script type="text/javascript">
        /* Filtro cliente-side del listado por texto (código/nombre/descripción). */
        function sgPautaFiltrar(q) {
            q = (q || '').toLowerCase();
            var filas = document.querySelectorAll('#sgPautaLista tbody .pc-fila');
            for (var i = 0; i < filas.length; i++) {
                var t = (filas[i].getAttribute('data-buscar') || '').toLowerCase();
                filas[i].style.display = (!q || t.indexOf(q) >= 0) ? '' : 'none';
            }
        }
    </script>
</asp:Content>
