<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistItemValidacions.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistItemValidacions" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <style type="text/css">
        .civ-cab { margin: 0 0 14px; }
        .civ-cab h2 { margin: 0; font-size: 17px; font-weight: 800; color: #17223B; }
        .civ-cab p { margin: 3px 0 0; font-size: 12.5px; color: #68738A; }
        .civ-cab .pauta { color: #6732F4; font-weight: 800; }
        /* La tabla mantiene su ancho natural; si excede el modal, scroll horizontal. */
        .civ-tabla { width: 100%; max-width: 100%; overflow-x: auto; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        var CIV_NUEVO = '<%= NuevoQuery %>';
        function abrirValidacion(query, esNuevo) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistItemValidacion.aspx") %>?query=' + query,
                title: esNuevo ? 'Nueva validación de ítem' : 'Editar validación de ítem',
                width: 900,
                initialHeight: 640
            });
        }
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Abra esta pantalla desde una pauta de inspección (pestaña Estructura → Umbrales).</p>
    </asp:Panel>

    <div class="civ-cab">
        <h2>Umbrales y acciones</h2>
        <p>Qué valores son normales para cada ítem y qué ocurre fuera de rango, en el <b>borrador</b> de <span class="pauta"><asp:Literal ID="litPauta" runat="server" /></span>.</p>
    </div>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="civ-tabla">
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" AllowPaging="true" PageSize="25">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="civ_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom:5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirValidacion(CIV_NUEVO, true);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja las validaciones seleccionadas?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
