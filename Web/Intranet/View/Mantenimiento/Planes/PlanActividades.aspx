<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="PlanActividades.aspx.cs" Inherits="View_Mantenimiento_Planes_PlanActividades" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* El id del hito no viaja a la vista: va DENTRO del querystring
           cifrado que armó el servidor, igual que en el resto del módulo. */
        var queryNueva = '<%=QueryNueva %>';

        function abrirPlanActividad(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Planes/PlanActividad.aspx") %>?query=' + query,
                title: query === queryNueva ? 'Nueva actividad' : 'Editar actividad',
                width: 960,
                initialHeight: 700
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento · Planes
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Actividades del hito
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El hito dice cada cuánto; la actividad dice qué se hace. Cada una se copia como paso dentro de la orden de trabajo que el hito genere.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-4 col-md-4 col-12">
                    <label for="cboHitoFiltro" style="display:block; margin:0 0 4px;">Hito:</label>
                    <rad:RadComboBox2 ID="cboHitoFiltro" runat="server" Width="100%" Filter="Contains" AutoPostBack="true" />
                </div>
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboHabilitado" style="display:block; margin:0 0 4px;">Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" Selected="true" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-5 col-md-5 col-xs-12"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus planes de mantenimiento.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <%-- De dónde vengo y a qué hito pertenece esto. Sin esta línea,
                 una grilla de actividades filtrada por un hito que no se
                 nombra es una lista sin contexto. --%>
            <asp:Panel ID="pnlContexto" runat="server" Visible="false" CssClass="card-box" style="margin-bottom:12px;">
                <asp:Literal ID="litContexto" runat="server" />
            </asp:Panel>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="paa_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nueva" CssClass="icono_guardar" OnClientClick="return abrirPlanActividad(queryNueva);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar las actividades seleccionadas? Una actividad ya copiada en una orden de trabajo no se puede eliminar.');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
