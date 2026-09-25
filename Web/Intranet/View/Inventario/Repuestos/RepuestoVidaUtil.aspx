<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="RepuestoVidaUtil.aspx.cs" Inherits="View_Inventario_Repuestos_RepuestoVidaUtil" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-permisos-lista.css?vrs=2") %>' rel="stylesheet" />
    <style type="text/css">
        /* La comparación entre instalaciones del mismo repuesto (criterio 3):
           una tarjeta por repuesto con promedio, mínima y máxima. */
        .sg-vu-comparacion { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 14px; }
        .sg-vu-repuesto { flex: 1 1 320px; border: 1px solid #dfe5ee; border-radius: 14px; background: #fff; padding: 12px 15px; box-shadow: 0 5px 18px rgba(31, 42, 72, .04); }
        .sg-vu-repuesto .titulo { display: flex; gap: 8px; align-items: baseline; flex-wrap: wrap; margin-bottom: 8px; }
        .sg-vu-repuesto .titulo strong { color: #172034; font-size: 13px; }
        .sg-vu-repuesto .titulo small { color: #6c788e; font-size: 10.5px; }
        .sg-vu-medidas { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
        .sg-vu-medida { border: 1px solid #e5eaf2; border-radius: 10px; padding: 8px 10px; background: #f9fafc; }
        .sg-vu-medida .n { font-size: 18px; font-weight: 800; color: #141c2e; line-height: 1.1; font-variant-numeric: tabular-nums; }
        .sg-vu-medida .u { font-size: 10px; color: #6c788e; }
        .sg-vu-medida .t { display: block; margin-top: 3px; font-size: 10px; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; color: #64708a; }
        .sg-vu-esperada { margin-top: 8px; font-size: 11px; color: #4e5b72; }
        .sg-vu-celda { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
        .sg-vu-celda strong { color: #172034; font-size: 12px; }
        .sg-vu-celda small { color: #6c788e; font-size: 10px; line-height: 1.35; display: flex; gap: 5px; align-items: center; }
        .sg-vu-celda small i { color: #8592a8; }
        .sg-vu-horas { font-size: 15px; font-weight: 800; color: #141c2e; font-variant-numeric: tabular-nums; }
        .sg-vu-horas.is-sin { font-size: 11px; font-weight: 600; color: #8a6110; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirRepuesto(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Repuestos/Repuesto.aspx") %>?query=' + query,
                title: 'Repuesto',
                width: 1040,
                initialHeight: 660
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Vida útil real de los repuestos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Cuánto duró de verdad cada pieza instalada, para ajustar el plan con datos y no con supuestos.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboRepuesto" style="margin: 0;">Repuesto:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboRepuesto" runat="server" OnLoad="LoadControls"
                        Filter="Contains" Width="80%" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboSituacion" style="margin: 0;">Situación:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboSituacion" runat="server" Width="60%" AutoPostBack="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Todas las instalaciones" Value="" Selected="true" />
                            <rad:RadComboBoxItem Text="Solo retiradas (con vida útil cerrada)" Value="1" />
                            <rad:RadComboBoxItem Text="Solo instaladas (todavía en el equipo)" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- LA COMPARACION ANTES DE LA LISTA (criterio 3)

                 El planificador entra con una pregunta —"¿cuánto me dura este
                 rodamiento?"— y la respuesta es un promedio, no una fila.
                 Una tarjeta por repuesto con promedio, mínima y máxima de
                 las instalaciones CERRADAS; las que siguen puestas no tienen
                 vida útil todavía, tienen tiempo corriendo. --%>
            <div class="sg-vu-comparacion">
                <asp:Literal ID="litComparacion" runat="server" />
            </div>

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkExportar_Click" ToolTip="Baja lo que muestra la pantalla">
                    <i class="mdi mdi-file-excel-outline"></i><span>Descargar a Excel</span>
                </asp:LinkButton>

                <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <div class="sg-permit-list-shell">
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="cri_id" />
            </rad:RadGrid2>
            </div>

            <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-arbol-vacio">
                <i class="mdi mdi-timer-sand-empty"></i>
                <div class="titulo">Sin instalaciones registradas</div>
                <div class="texto"><asp:Literal ID="litVacio" runat="server" /></div>
            </asp:Panel>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Esta pantalla es de <strong>solo lectura</strong>: cada fila nace cuando un técnico
                instala o retira la pieza en una orden de trabajo.<br />
                La vida útil en <strong>horas</strong> es la diferencia entre el horómetro al instalar y
                al retirar. Si alguna de las dos lecturas no se anotó, se muestra
                <span class="grid-estado-chip is-advertencia"><i class="mdi mdi-timer-off-outline"></i>Sin horómetro</span>
                y solo se informan los <strong>días</strong>, que siempre se pueden contar.<br />
                <strong>Promedio, mínima y máxima</strong> se calculan solo con las instalaciones ya retiradas:
                una pieza que sigue puesta no tiene vida útil todavía.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
