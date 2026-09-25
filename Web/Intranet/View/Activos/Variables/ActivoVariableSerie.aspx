<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoVariableSerie.aspx.cs" Inherits="View_Activos_Variables_ActivoVariableSerie" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <style type="text/css">
        .sg-serie-cabecera { display: flex; flex-wrap: wrap; gap: 18px 32px; align-items: flex-start; }
        .sg-serie-cabecera .dato label { display: block; font-size: 11px; letter-spacing: .4px; text-transform: uppercase; color: #6b7280; margin: 0 0 2px; }
        .sg-serie-cabecera .dato strong { font-size: 15px; }
        .sg-serie-umbrales { display: flex; gap: 8px; flex-wrap: wrap; }
        .sg-serie-resumen { display: flex; gap: 12px; flex-wrap: wrap; margin-top: 14px; }
        .sg-serie-kpi { flex: 1 1 140px; border: 1px solid #e5e7eb; border-radius: 12px; padding: 10px 14px; background: #fff; }
        .sg-serie-kpi .n { font-size: 22px; font-weight: 800; line-height: 1.1; }
        .sg-serie-kpi .t { font-size: 12px; color: #6b7280; }
        .sg-serie-kpi.is-alerta .n { color: #b02a2a; }
        .sg-serie-kpi.is-advertencia .n { color: #9a6a00; }
        #divGrafico { width: 100%; height: 380px; }
        .sg-serie-detalle { border: 1px dashed #c7c9d3; border-radius: 12px; padding: 12px 16px; margin-top: 10px; background: #fafaff; }
        .sg-serie-detalle .vacio { color: #6b7280; }
        .sg-serie-detalle dl { display: grid; grid-template-columns: 160px 1fr; gap: 4px 12px; margin: 0; }
        .sg-serie-detalle dt { color: #6b7280; font-size: 12px; text-transform: uppercase; letter-spacing: .3px; }
        .sg-serie-detalle dd { margin: 0; }
        .sg-serie-filtro { display: flex; gap: 14px; align-items: flex-end; flex-wrap: wrap; }
        .sg-serie-filtro .campo label { display: block; font-size: 12px; color: #6b7280; margin-bottom: 4px; }
        .sg-serie-filtro .campo input.form-control { width: 130px !important; min-width: 130px; display: inline-block; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* HU-045: el gráfico. Los puntos vienen del servidor ya con su nivel
           (NORMAL, ADVERTENCIA, CRITICO, FUERA_RANGO) porque el veredicto contra
           los umbrales se calcula en el SP, el mismo que usa la app al
           registrar: acá solo se pinta. */
        /* El master emite este bloque DESPUES del cuerpo, asi que los datos que
           la pagina inyecta en litDatos ya corrieron: no se pisa la variable. */
        window.sgSerie = window.sgSerie || null;

        function sgColorNivel(n) {
            if (n === 'CRITICO') return '#d64545';
            if (n === 'ADVERTENCIA') return '#e0a100';
            if (n === 'FUERA_RANGO') return '#7c3aed';
            return '#2563eb';
        }

        function sgMinEje(v, datos) {
            var m = null;
            for (var i = 0; i < datos.length; i++) if (m === null || datos[i].y < m) m = datos[i].y;
            if (v.minimo != null && (m === null || v.minimo < m)) m = v.minimo;
            return m === null ? null : m - Math.abs(m) * 0.05 - 1;
        }
        function sgMaxEje(v, datos) {
            var m = null;
            for (var i = 0; i < datos.length; i++) if (m === null || datos[i].y > m) m = datos[i].y;
            var tope = v.critico != null ? v.critico : v.maximo;
            if (tope != null && (m === null || tope > m)) m = tope;
            return m === null ? null : m + Math.abs(m) * 0.08 + 1;
        }
        function sgNum(x) { return (Math.round(x * 100) / 100).toString().replace('.', ','); }

        function sgPintarSerie() {
            var cont = document.getElementById('divGrafico');
            if (!cont || !window.sgSerie || !window.Highcharts) return;

            var v = window.sgSerie.variable, pts = window.sgSerie.puntos;
            if (!pts.length) { cont.innerHTML = '<div class="sigma-lista-vacia">No hay mediciones en el rango elegido.</div>'; return; }

            var datos = [];
            for (var i = 0; i < pts.length; i++) {
                datos.push({
                    x: pts[i].t, y: pts[i].v, indice: i,
                    marker: { radius: pts[i].n === 'NORMAL' ? 3.5 : 6, fillColor: sgColorNivel(pts[i].n), lineColor: '#fff', lineWidth: 1 }
                });
            }

            /* La banda de valores normales se sombrea: entre el mínimo y el
               umbral de advertencia (o el máximo si no hay advertencia). Las
               líneas de advertencia y crítico van punteadas encima. */
            var bandas = [], lineas = [];
            var piso = v.minimo != null ? v.minimo : null;
            var techo = v.advertencia != null ? v.advertencia : (v.maximo != null ? v.maximo : null);
            if (piso != null || techo != null)
                bandas.push({ from: piso != null ? piso : -Infinity, to: techo != null ? techo : Infinity, color: 'rgba(37,99,235,0.08)', label: { text: 'Normal', style: { color: '#2563eb', fontSize: '11px' } } });
            if (v.advertencia != null && v.critico != null)
                bandas.push({ from: v.advertencia, to: v.critico, color: 'rgba(224,161,0,0.12)', label: { text: 'Advertencia', style: { color: '#9a6a00', fontSize: '11px' } } });
            if (v.critico != null)
                bandas.push({ from: v.critico, to: Infinity, color: 'rgba(214,69,69,0.10)', label: { text: 'Crítico', style: { color: '#b02a2a', fontSize: '11px' } } });
            if (v.minimo != null) lineas.push({ value: v.minimo, color: '#2563eb', dashStyle: 'ShortDot', width: 1, label: { text: 'mín ' + v.minimo, style: { fontSize: '10px' } } });
            if (v.maximo != null) lineas.push({ value: v.maximo, color: '#7c3aed', dashStyle: 'ShortDot', width: 1, label: { text: 'máx ' + v.maximo, style: { fontSize: '10px' } } });
            if (v.advertencia != null) lineas.push({ value: v.advertencia, color: '#e0a100', dashStyle: 'Dash', width: 1.5, label: { text: 'adv ' + v.advertencia, style: { fontSize: '10px' } } });
            if (v.critico != null) lineas.push({ value: v.critico, color: '#d64545', dashStyle: 'Dash', width: 1.5, label: { text: 'crít ' + v.critico, style: { fontSize: '10px' } } });

            Highcharts.setOptions({ global: { useUTC: false }, lang: { months: ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'], shortMonths: ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'], weekdays: ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'] } });

            new Highcharts.Chart({
                chart: { renderTo: 'divGrafico', type: 'line', zoomType: 'x', backgroundColor: 'transparent', style: { fontFamily: 'inherit' } },
                title: { text: null },
                credits: { enabled: false },
                legend: { enabled: false },
                xAxis: { type: 'datetime', gridLineWidth: 0 },
                /* El eje incluye los umbrales aunque ningun punto los alcance:
                   la banda critica se tiene que ver para saber cuanto falta. */
                yAxis: { title: { text: v.unidad }, plotBands: bandas, plotLines: lineas,
                         min: sgMinEje(v, datos), max: sgMaxEje(v, datos), startOnTick: false, endOnTick: false },
                tooltip: {
                    formatter: function () {
                        var p = pts[this.point.indice];
                        return '<b>' + sgNum(p.v) + ' ' + v.unidad + '</b> · ' + p.nivelTexto + '<br/>' + p.fecha + '<br/>' + p.origen + ' · ' + p.quien + '<br/><span style="color:#6b7280">Clic para ver el origen del dato</span>';
                    }
                },
                plotOptions: {
                    series: {
                        color: '#2563eb', lineWidth: 2, marker: { enabled: true },
                        cursor: 'pointer',
                        point: { events: { click: function () { sgMostrarPunto(this.indice); } } }
                    }
                },
                series: [{ name: v.nombre, data: datos }]
            });
        }

        /* HU-045 #2: al tocar un punto se dice quién lo registró, cuándo y de
           dónde salió (checklist, orden o a mano). */
        function sgMostrarPunto(i) {
            var p = window.sgSerie.puntos[i], v = window.sgSerie.variable;
            var origen = p.origen + (p.entrada ? ' · ' + p.entrada : '');
            if (p.ot) origen += ' · Orden OT-' + p.ot;
            if (p.checklist) origen += ' · Ejecución de checklist #' + p.checklist;
            var h = '<dl>' +
                '<dt>Valor</dt><dd><strong>' + sgNum(p.v) + ' ' + v.unidad + '</strong> <span class="grid-estado-chip ' + p.chip + '">' + p.nivelTexto + '</span>' +
                (p.vo !== p.v ? ' <span style="color:#6b7280">(medido como ' + sgNum(p.vo) + ' ' + p.uo + ')</span>' : '') + '</dd>' +
                '<dt>Cuándo</dt><dd>' + p.fecha + '</dd>' +
                '<dt>Quién lo registró</dt><dd>' + p.quien + '</dd>' +
                '<dt>Origen</dt><dd>' + origen + '</dd>' +
                '<dt>Calidad</dt><dd>' + p.calidad + '</dd>' +
                (p.obs ? '<dt>Observación</dt><dd>' + p.obs + '</dd>' : '') +
                '</dl>';
            document.getElementById('divDetalle').innerHTML = h;
            var fila = document.querySelector('tr[data-punto="' + i + '"]');
            var filas = document.querySelectorAll('tr[data-punto]');
            for (var k = 0; k < filas.length; k++) filas[k].style.background = '';
            if (fila) fila.style.background = '#eef2ff';
        }

        Sys.Application.add_load(function () { sgPintarSerie(); });
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Activos · Variables de condición
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    <asp:Literal ID="litTitulo" runat="server" Text="Serie histórica" />
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cómo ha evolucionado la variable en el tiempo, contra sus umbrales.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinVariable" runat="server" Visible="false" CssClass="card-box">
        <p>No se encontró la variable. Vuelva a <a href="ActivoVariables.aspx">Variables de condición</a> y elija una.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <asp:Panel ID="pnlSerie" runat="server">

                <div class="card-box">
                    <div class="sg-serie-cabecera">
                        <div class="dato"><label>Equipo</label><strong><asp:Literal ID="litEquipo" runat="server" /></strong></div>
                        <div class="dato"><label>Variable</label><strong><asp:Literal ID="litVariable" runat="server" /></strong></div>
                        <div class="dato"><label>Unidad</label><strong><asp:Literal ID="litUnidad" runat="server" /></strong></div>
                        <div class="dato"><label>Umbrales</label><div class="sg-serie-umbrales"><asp:Literal ID="litUmbrales" runat="server" /></div></div>
                    </div>
                    <div class="sg-serie-resumen"><asp:Literal ID="litResumen" runat="server" /></div>
                </div>

                <div class="card-box">
                    <div class="sg-serie-filtro">
                        <div class="campo">
                            <label>Desde</label>
                            <WebControls:Calendar ID="calDesde" runat="server" />
                        </div>
                        <div class="campo">
                            <label>Hasta</label>
                            <WebControls:Calendar ID="calHasta" runat="server" />
                        </div>
                        <div class="campo">
                            <WebControls:PushButton ID="btnAplicar" runat="server" Text="Aplicar" OnClick="btnAplicar_Click" />
                        </div>
                        <div class="campo">
                            <a class="icono_Editar" href="ActivoVariables.aspx" style="margin-left: 8px;">Volver a variables</a>
                        </div>
                    </div>
                </div>

                <div class="card-box">
                    <div class="sigma-form-seccion">
                        <div class="titulo"><i class="mdi mdi-chart-line"></i>Tendencia</div>
                        <div class="ayuda">La banda sombreada es el rango normal; los puntos en advertencia, crítico o fuera de rango se destacan. Toque un punto para ver de dónde salió el dato.</div>
                    </div>
                    <div id="divGrafico"></div>
                    <div id="divDetalle" class="sg-serie-detalle"><span class="vacio">Toque un punto del gráfico (o una fila de la tabla) para ver quién lo registró, cuándo y desde dónde.</span></div>
                    <asp:Literal ID="litDatos" runat="server" />
                </div>

                <div class="card-box">
                    <div class="sigma-form-seccion">
                        <div class="titulo"><i class="mdi mdi-table"></i>Mediciones del rango</div>
                    </div>
                    <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                        <MasterTableView DataKeyNames="amd_id" CommandItemDisplay="None" />
                    </rad:RadGrid2>
                </div>

            </asp:Panel>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
