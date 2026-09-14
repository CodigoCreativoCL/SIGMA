<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ChecklistPlantillas.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistPlantillas" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirChecklistPlantilla(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistPlantilla.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nueva pauta de inspección' : 'Editar pauta de inspección',
                width: 860,
                initialHeight: 560
            });
        }
        // Previsualización de solo lectura (clic en la fila, sin entrar a editar).
        function verChecklist(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistPlantillaVista.aspx") %>?query=' + query,
                title: 'Vista de la pauta',
                width: 820,
                initialHeight: 600
            });
        }
        // Clic en la fila abre la vista; los clic en la lupa/checkbox no.
        function clFilaVer(row, ev, query) {
            var t = ev.target;
            if (t.closest && t.closest('a, input, .icono_Editar, .rgSelect')) return;
            verChecklist(query);
        }
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Pautas de inspección</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Las plantillas de checklist reutilizables: se diseñan una vez y se ejecutan en las rondas e inspecciones.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-5 col-md-6 col-xs-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboHabilitado" style="margin: 0; white-space: nowrap;">Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="200px">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus pautas de inspección.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrPlantillas_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="cpl_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirChecklistPlantilla(0);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja las pautas seleccionadas?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
