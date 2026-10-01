<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistItemDependencias.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistItemDependencias" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <style type="text/css">
        .cid-cab { margin: 0 0 14px; }
        .cid-cab h2 { margin: 0; font-size: 17px; font-weight: 800; color: #17223B; }
        .cid-cab p { margin: 3px 0 0; font-size: 12.5px; color: #68738A; }
        .cid-cab .pauta { color: #6732F4; font-weight: 800; }
        /* La tabla mantiene su ancho natural; si excede el modal, scroll horizontal. */
        .cid-tabla { width: 100%; max-width: 100%; overflow-x: auto; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        var CID_NUEVO = '<%= NuevoQuery %>';
        function abrirDependencia(query, esNuevo) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Checklist/ChecklistItemDependencia.aspx") %>?query=' + query,
                title: esNuevo ? 'Nueva dependencia entre ítems' : 'Editar dependencia entre ítems',
                width: 900,
                initialHeight: 600
            });
        }
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Abra esta pantalla desde una pauta de inspección (pestaña Estructura → Dependencias).</p>
    </asp:Panel>

    <div class="cid-cab">
        <h2>Dependencias entre ítems</h2>
        <p>Qué ítem se muestra, oculta, requiere o bloquea según cómo se respondió otro, en el <b>borrador</b> de <span class="pauta"><asp:Literal ID="litPauta" runat="server" /></span>.</p>
    </div>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="cid-tabla">
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound" AllowPaging="true" PageSize="25">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="cid_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom:5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirDependencia(CID_NUEVO, true);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja las dependencias seleccionadas?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
