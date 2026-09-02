<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Programaciones.aspx.cs" Inherits="View_Mantenimiento_Programaciones_Programaciones" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirProgramacion(query) {
            var oWin = $find("<%=rwiDetalle.ClientID %>");
            oWin.setUrl('<%=ResolveUrl("~/View/Mantenimiento/Programaciones/Programacion.aspx") %>?query=' + query);
            oWin.show();
            return false;
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Programaciones
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Las reglas que definen cuándo toca cada trabajo: por fecha, por calendario, por intervalo, por medidor o por condición.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboTipo" style="margin: 0;">Tipo:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboTipo" runat="server" Width="80%" AutoPostBack="true" />
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
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <rad:RadWindow2 ID="rwiDetalle" runat="server" Width="1100" Height="700" />

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-acciones-barra">
                <asp:LinkButton ID="lnkNuevo" runat="server" CssClass="sigma-accion is-primaria"
                    OnClientClick="return abrirProgramacion(0);">
                    <i class="mdi mdi-plus"></i><span>Nueva programación</span>
                </asp:LinkButton>

                <asp:LinkButton ID="lnkEliminar" runat="server" CssClass="sigma-accion"
                    OnClick="lnkEliminar_Click"
                    OnClientClick="return ConfirSweetAlert(this, '', '¿Deshabilitar las programaciones seleccionadas?');"
                    ToolTip="Deja de generar sin perder lo ya generado">
                    <i class="mdi mdi-trash-can-outline"></i><span>Eliminar</span>
                </asp:LinkButton>
            </div>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="None" DataKeyNames="pro_id" />
            </rad:RadGrid2>

            <div class="card-box" style="margin-top: 14px; font-size: 12px; color: #555;">
                Una programación dice <strong>cuándo</strong> toca un trabajo. Todavía no crea las
                órdenes: eso lo hace el plan de mantenimiento, que las toma de acá.<br />
                <strong>Eliminar</strong> no borra: <strong>deshabilita</strong>. Deja de generar
                ocurrencias nuevas y conserva todas las que ya generó, porque son historial de
                trabajo hecho. Si algún hito de un plan la está usando, el sistema lo rechaza y
                dice cuántos.
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
