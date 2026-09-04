<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="RepuestoTipos.aspx.cs" Inherits="View_Inventario_Repuestos_RepuestoTipos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-repuesto-tipos.css?vrs=1") %>' rel="stylesheet" />
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirTipo(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Inventario/Repuestos/RepuestoTipo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo tipo de repuesto' : 'Editar tipo de repuesto',
                width: 720,
                initialHeight: 470
            });
        }

        function refresh() {
            __doPostBack('<%=udPanel.ClientID %>', '');
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Inventario
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Tipos de repuesto
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Las categorías con que se agrupan los repuestos en el listado.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Sí" Value="1" Selected="true" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-6 col-md-6 col-xs-12 d-flex align-items-center"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus tipos de repuesto.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                    OnClientClick="return abrirTipo(0);">
                    <i class="mdi mdi-shape-plus"></i><span>Nuevo tipo</span>
                </asp:LinkButton>

                <span class="sg-arbol-cuenta"><asp:Literal ID="litCuenta" runat="server" /></span>
            </div>

            <%-- ============================================================
                 REPEATER, NO GRILLA

                 Un cliente tiene entre cinco y quince categorias. Una RadGrid
                 traeria su paginador -"Registros por pagina: 25" debajo de
                 seis filas-, su cabecera en mayusculas y su ancho fijo por
                 columna. De cada tipo interesan tres cosas y cuantos
                 repuestos tiene: se lee mejor como tarjetas.

                 El ORDEN se muestra porque es lo que decide la posicion de la
                 pestaña en el listado de repuestos, y sin verlo no hay forma
                 de saber por que una categoria salio antes que otra.
                 ============================================================ --%>
            <asp:Repeater ID="rptTipos" runat="server"
                OnItemDataBound="rptTipos_ItemDataBound"
                OnItemCommand="rptTipos_ItemCommand">
                <HeaderTemplate>
                    <ul class="sg-tipos">
                </HeaderTemplate>
                <ItemTemplate>
                    <li class="sg-tipo">
                        <asp:Literal ID="litTipo" runat="server" />
                        <div class="sg-tipo-acciones">
                            <asp:LinkButton ID="lnkEditar" runat="server" CommandName="editar"
                                CssClass="sg-tipo-accion" ToolTip="Editar" CausesValidation="false">
                                <i class="mdi mdi-pencil-outline" aria-hidden="true"></i>
                            </asp:LinkButton>
                            <asp:LinkButton ID="lnkEliminar" runat="server" CommandName="eliminar"
                                CssClass="sg-tipo-accion is-peligro" ToolTip="Eliminar" CausesValidation="false">
                                <i class="mdi mdi-trash-can-outline" aria-hidden="true"></i>
                            </asp:LinkButton>
                        </div>
                    </li>
                </ItemTemplate>
                <FooterTemplate>
                    </ul>
                </FooterTemplate>
            </asp:Repeater>

            <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-tipos-vacio">
                <i class="mdi mdi-shape-outline" aria-hidden="true"></i>
                <strong><asp:Literal ID="litVacioTitulo" runat="server" /></strong>
                <span><asp:Literal ID="litVacioTexto" runat="server" /></span>
            </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
