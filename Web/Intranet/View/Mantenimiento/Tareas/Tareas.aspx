<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Tareas.aspx.cs" Inherits="View_Mantenimiento_Tareas_Tareas" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* LA TAREA NO SE ABRE EN MODAL: SE ENTRA A ELLA
           Ficha, programaciones y comentarios en una pantalla con pestañas,
           como el plan de mantenimiento. */
        function abrirTarea(query) {
            location.href = '<%=ResolveUrl("~/View/Mantenimiento/Tareas/Tarea.aspx") %>' + (String(query) === '0' ? '' : '?query=' + query);
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
    Tareas recurrentes
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Trabajo breve que se repite —revisar un nivel, limpiar un filtro— y que sin registro no existe. Qué es, cada cuánto y quién.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-4 col-md-4 col-12">
                    <label for="cboPlanta" style="display:block; margin:0 0 4px;">Planta:</label>
                    <rad:RadComboBox2 ID="cboPlanta" runat="server" Width="100%" AutoPostBack="true" />
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
                <div class="col-lg-3 col-md-3 col-12">
                    <label for="cboPrioridad" style="display:block; margin:0 0 4px;">Prioridad:</label>
                    <rad:RadComboBox2 ID="cboPrioridad" runat="server" Width="100%" AutoPostBack="true" />
                </div>
                <div class="col-lg-2 col-md-2 col-xs-12"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus tareas.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="tar_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirTarea(0);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Eliminar las tareas seleccionadas? Una tarea con ocurrencias pendientes no se puede eliminar.');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
