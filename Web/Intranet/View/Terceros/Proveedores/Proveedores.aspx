<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Proveedores.aspx.cs" Inherits="View_Terceros_Proveedores_Proveedores" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- Proveedores unificado (10-10-2026): el Maestro y el Historial de
         servicios, que antes eran dos pantallas sueltas bajo la carpeta
         «Proveedores», pasan a ser dos PESTAÑAS de una sola vista. El menú de
         Terceros queda con un único ítem «Proveedores». El alta y la edición
         siguen en el modal (Proveedor.aspx). --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-terceros.css?vrs=1") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-permisos-lista.css?vrs=2") %>' rel="stylesheet" />
    <style type="text/css">
        /* Totales del Historial POR MONEDA (criterio 2): una tarjeta por
           moneda, nunca una sola con la suma. 730.000 pesos y 12,5 UF no son
           730.012 de nada. */
        .sg-ph-totales { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 14px; }
        .sg-ph-total { flex: 1 1 200px; border: 1px solid #dfe5ee; border-radius: 14px; background: #fff; padding: 13px 15px; box-shadow: 0 5px 18px rgba(31, 42, 72, .04); }
        .sg-ph-total .n { display: block; font-size: 22px; font-weight: 800; color: #141c2e; line-height: 1.1; font-variant-numeric: tabular-nums; }
        .sg-ph-total .n small { font-size: 12px; font-weight: 700; color: #4e5b72; margin-left: 4px; }
        .sg-ph-total .t { display: block; margin-top: 4px; font-size: 10.5px; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; color: #64708a; }
        .sg-ph-total.is-ordenes { background: #f6f8fb; }
        .sg-ph-total.is-sin { border-style: dashed; }
        .sg-ph-celda { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
        .sg-ph-celda strong { color: #172034; font-size: 12px; }
        .sg-ph-celda small { color: #6c788e; font-size: 10px; line-height: 1.35; display: flex; gap: 5px; align-items: center; }
        .sg-ph-celda small i { color: #8592a8; }
        .sg-ph-monto { font-size: 15px; font-weight: 800; color: #141c2e; font-variant-numeric: tabular-nums; white-space: nowrap; }
        .sg-ph-monto small { font-size: 10.5px; color: #4e5b72; margin-left: 3px; }
        .sg-ph-rango { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
        .sg-ph-rango label { margin: 0; }
        .sg-ph-rango input.form-control { width: 125px !important; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirProveedor(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Terceros/Proveedores/Proveedor.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo proveedor' : 'Proveedor',
                width: 1000,
                initialHeight: 640
            });
        }

        /* El modal llama a refresh() al guardar: refresca el Maestro, que es
           la pestaña donde se da de alta y se edita. */
        function refresh() {
            __doPostBack("<%=GridMaestro.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Terceros
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Proveedores
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" />
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">

    <%-- Las pestañas van arriba del filtro: primero se elige la vista y
         después se filtra dentro de ella. La activa en morado con subrayado. --%>
    <div class="sg-ter-tabs" role="tablist" aria-label="Vistas de Proveedores">
        <asp:LinkButton ID="tabMaestro" runat="server" CssClass="sg-ter-tab" OnClick="Tab_Click"
            CommandArgument="M" role="tab">
            <i class="mdi mdi-domain"></i><span>Maestro de proveedores</span>
        </asp:LinkButton>
        <asp:LinkButton ID="tabHistorial" runat="server" CssClass="sg-ter-tab" OnClick="Tab_Click"
            CommandArgument="H" role="tab">
            <i class="mdi mdi-history"></i><span>Historial de servicios</span>
        </asp:LinkButton>
    </div>

    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <%-- Filtros del Maestro --%>
            <asp:Panel ID="pnlFiltroMaestro" runat="server">
                <div class="row col-lg-12 col-md-12 col-xs-12">
                    <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                        <label for="cboTipo" style="margin: 0;">Tipo:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                        <rad:RadComboBox2 ID="cboTipo" runat="server" Width="80%" AutoPostBack="true">
                            <Items>
                                <rad:RadComboBoxItem Text="Todos" Value="" />
                                <rad:RadComboBoxItem Text="Contratistas" Value="C" />
                                <rad:RadComboBoxItem Text="Proveedores de repuestos" Value="R" />
                            </Items>
                        </rad:RadComboBox2>
                    </div>
                    <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                        <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                        <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%" AutoPostBack="true">
                            <Items>
                                <rad:RadComboBoxItem Text="Sí" Value="1" Selected="true" />
                                <rad:RadComboBoxItem Text="No" Value="0" />
                                <rad:RadComboBoxItem Text="Todos" Value="" />
                            </Items>
                        </rad:RadComboBox2>
                    </div>
                </div>
            </asp:Panel>

            <%-- Filtros del Historial --%>
            <asp:Panel ID="pnlFiltroHistorial" runat="server">
                <div class="row col-lg-12 col-md-12 col-xs-12">
                    <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                        <label for="cboProveedor" style="margin: 0;">Proveedor:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                        <rad:RadComboBox2 ID="cboProveedor" runat="server" OnLoad="LoadControls"
                            Filter="Contains" Width="80%" AutoPostBack="true" />
                    </div>
                    <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                        <label for="cboTipoServicio" style="margin: 0;">Tipo de servicio:</label>
                    </div>
                    <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                        <rad:RadComboBox2 ID="cboTipoServicio" runat="server" OnLoad="LoadControls"
                            Filter="Contains" Width="80%" AutoPostBack="true" />
                    </div>
                </div>
            </asp:Panel>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- ===================== PESTAÑA: MAESTRO ===================== --%>
            <asp:Panel ID="pnlMaestro" runat="server">

                <div class="sigma-acciones-barra">
                    <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                        OnClientClick="return abrirProveedor(0);">
                        <i class="mdi mdi-plus"></i><span>Nuevo proveedor</span>
                    </asp:LinkButton>

                    <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="sigma-accion"
                        OnClick="lnkEliminar_Click"
                        OnClientClick="return ConfirSweetAlert(this, '', '¿Deshabilitar los proveedores seleccionados?');"
                        ToolTip="Deja de ofrecerlos sin perder su historial">
                        <i class="mdi mdi-trash-can-outline"></i><span>Eliminar</span>
                    </asp:LinkButton>
                </div>

                <rad:RadGrid2 ID="GridMaestro" runat="server" OnItemDataBound="GridMaestro_ItemDataBound">
                    <MasterTableView CommandItemDisplay="None" DataKeyNames="prv_id" />
                </rad:RadGrid2>

                <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                    El buscador mira el <strong>identificador tributario, la razón social, el nombre de
                    fantasía, el contacto y el correo</strong>.<br />
                    <strong>Eliminar</strong> no borra: <strong>deshabilita</strong>. Un proveedor con lotes
                    recibidos o servicios contratados aparece en el historial de compra y en el gasto del
                    año, así que su nombre tiene que seguir estando. Deshabilitado deja de ofrecerse en los
                    combos y conserva todo lo anterior.
                </div>
            </asp:Panel>

            <%-- ===================== PESTAÑA: HISTORIAL ===================== --%>
            <asp:Panel ID="pnlHistorial" runat="server">

                <%-- EL RANGO VA FUERA DEL FILTRO AVANZADO

                     sigma-calendario.js toma como disparador de calendario TODO
                     lo pulsable dentro de `.filtroPersonalizado` y le quita el
                     onclick: un botón «Aplicar» puesto ahí deja de hacer postback.
                     Por eso el rango vive en su propia tarjeta. --%>
                <div class="card-box" style="margin-bottom: 14px;">
                    <div class="sg-ph-rango">
                        <label><i class="mdi mdi-calendar-range"></i> Entre</label>
                        <WebControls:Calendar ID="calDesde" runat="server" />
                        <label>y</label>
                        <WebControls:Calendar ID="calHasta" runat="server" />
                        <WebControls:PushButton ID="btnAplicar" runat="server" Text="Aplicar" OnClick="btnAplicar_Click" />
                        <asp:LinkButton ID="lnkQuitarRango" runat="server" CssClass="sigma-accion" OnClick="lnkQuitarRango_Click" Visible="false">
                            <i class="mdi mdi-filter-remove-outline"></i><span>Quitar el rango</span>
                        </asp:LinkButton>
                        <asp:Literal ID="litFiltroActivo" runat="server" />
                    </div>
                </div>

                <%-- LOS TOTALES ANTES DE LA LISTA: un par de números, uno por
                     moneda, y otra tarjeta con las órdenes en que participó. --%>
                <div class="sg-ph-totales">
                    <asp:Literal ID="litTotales" runat="server" />
                </div>

                <div class="sigma-acciones-barra">
                    <asp:LinkButton ID="lnkExportar" runat="server" CssClass="sigma-accion"
                        OnClick="lnkExportar_Click" ToolTip="Baja lo que muestra la pantalla">
                        <i class="mdi mdi-file-excel-outline"></i><span>Descargar a Excel</span>
                    </asp:LinkButton>

                    <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
                </div>

                <div class="sg-permit-list-shell">
                    <rad:RadGrid2 ID="GridHistorial" runat="server" OnItemDataBound="GridHistorial_ItemDataBound">
                        <MasterTableView CommandItemDisplay="None" DataKeyNames="ots_id" />
                    </rad:RadGrid2>
                </div>

                <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-arbol-vacio">
                    <i class="mdi mdi-handshake-outline"></i>
                    <div class="titulo">Sin servicios registrados</div>
                    <div class="texto"><asp:Literal ID="litVacio" runat="server" /></div>
                </asp:Panel>

                <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                    Esta pestaña es de <strong>solo lectura</strong>: los servicios se registran en la
                    orden de trabajo en que se contrataron.<br />
                    Los <strong>totales van por moneda</strong> y no se suman entre sí: pesos con pesos,
                    UF con UF. Un servicio <strong>sin moneda declarada</strong> se cuenta aparte, con
                    borde punteado, hasta que alguien la complete en la orden.<br />
                    El <strong>rango de fechas</strong> se aplica sobre la fecha del servicio; si no la
                    tiene, sobre la del documento; y si tampoco, sobre la del registro.
                </div>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
