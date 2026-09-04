<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Repuestos.aspx.cs" Inherits="View_Inventario_Repuestos_Repuestos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-repuesto-tipos.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirCargaMasiva() {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Repuestos/CargaMasivaRepuestos.aspx") %>',
                title: 'Carga masiva de repuestos',
                width: 1080,
                initialHeight: 680
            });
        }

        function abrirRepuesto(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Repuestos/Repuesto.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo repuesto' : 'Editar repuesto',
                width: 1040,
                initialHeight: 680
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
    Repuestos
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El catálogo de la planta, para que todos nombren la misma pieza de la misma forma.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboLote" style="margin: 0;">Controla lote:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboLote" runat="server" Width="80%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Sí" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboExistencia" style="margin: 0;">Existencia:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboExistencia" runat="server" Width="80%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Con existencia" Value="1" />
                            <rad:RadComboBoxItem Text="Sin existencia" Value="0" />
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

            <%-- LAS ACCIONES VAN EN SU PROPIA BARRA, NO EN LA GRILLA

                 Estaban en el CommandItemTemplate de RadGrid, y un control ahi
                 dentro NO es un campo de la pagina: el code-behind no puede
                 nombrarlo, asi que la descarga -que necesita su evento- no
                 compilaba.

                 Ademas las tres son la misma tarea -meter repuestos al catalogo
                 o sacarlos- y juntas se eligen de un vistazo. --%>
            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                    OnClientClick="return abrirRepuesto(0);">
                    <i class="mdi mdi-plus"></i><span>Nuevo repuesto</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkDescargar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkDescargar_Click"
                    ToolTip="Baja los repuestos que coinciden con la búsqueda">
                    <i class="mdi mdi-file-excel-outline"></i><span>Descargar a Excel</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkCargaMasiva" runat="server" CssClass="sigma-accion"
                    OnClientClick="return abrirCargaMasiva();"
                    ToolTip="Dar de alta muchos repuestos desde una planilla">
                    <i class="mdi mdi-upload-outline"></i><span>Carga masiva</span>
                </asp:LinkButton>
            </div>

            <%-- ============================================================
                 LAS PESTAÑAS POR CATEGORIA

                 Se dibujan con un Repeater sobre los tipos que definio el
                 cliente, mas dos fijas: "Todos" al principio y "Sin
                 clasificar" al final.

                 "Sin clasificar" no se esconde cuando esta vacia: es
                 justamente la pestaña que hay que vaciar, y verla en cero es
                 la señal de que el maestro quedo clasificado. Escondida, no
                 habria forma de saber que faltan repuestos por clasificar.

                 Cada pestaña trae su numero. Un filtro que al tocarlo no
                 muestra nada ya hizo perder un clic.
                 ============================================================ --%>
            <div class="sg-rep-tabs" role="tablist">
                <asp:Repeater ID="rptTabs" runat="server" OnItemCommand="rptTabs_ItemCommand"
                    OnItemDataBound="rptTabs_ItemDataBound">
                    <ItemTemplate>
                        <asp:LinkButton ID="lnkTab" runat="server" CommandName="tab"
                            CssClass="sg-rep-tab" CausesValidation="false" />
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <%-- ============================================================
                 ASIGNAR EL TIPO A VARIOS DE UNA VEZ

                 Clasificar un maestro que ya existe es el caso real: con
                 trescientos repuestos, abrirlos de a uno no lo hace nadie y
                 las pestañas nunca llegan a servir.

                 La barra aparece sola cuando hay algo marcado: permanente
                 seria una fila mas de ruido en una pantalla que casi siempre
                 se usa para buscar, no para clasificar.
                 ============================================================ --%>
            <asp:Panel ID="pnlAsignar" runat="server" Visible="false" CssClass="sg-rep-asignar">
                <i class="mdi mdi-checkbox-marked-circle-outline" aria-hidden="true"></i>
                <strong><asp:Literal ID="litMarcados" runat="server" /></strong>
                <span>Asignarles el tipo:</span>
                <rad:RadComboBox2 ID="cboTipoLote" runat="server" OnLoad="LoadControls"
                    Filter="Contains" Width="220px" />
                <asp:LinkButton ID="lnkAsignar" runat="server" CssClass="sigma-accion is-primaria"
                    OnClick="lnkAsignar_Click" CausesValidation="false">
                    <i class="mdi mdi-tag-multiple-outline"></i><span>Asignar</span>
                </asp:LinkButton>
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="rep_id" />
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                El buscador mira el <strong>código interno, el nombre, el fabricante y el modelo</strong>:
                sirve el número grabado en la pieza, que muchas veces es lo único que se tiene a mano.<br />
                <strong>Existencia</strong> es la suma de todas las bodegas, y debajo en cuántas está.
                Para ver cuánto hay en cada una y sus umbrales, entre a la ficha o al listado de
                <strong>Existencias</strong>.<br />
                <span class="grid-estado-chip is-info"><i class="mdi mdi-barcode"></i>Lote</span>
                marca los repuestos cuyo ingreso <strong>exige el número de lote</strong>: aceites,
                filtros y todo lo que vence o hay que poder rastrear.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
