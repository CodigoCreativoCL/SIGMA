<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Repuestos.aspx.cs" Inherits="View_Inventario_Repuestos_Repuestos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
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
