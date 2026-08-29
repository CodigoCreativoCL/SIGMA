<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="MenuFuncion.aspx.cs" Inherits="View_Root_Mantenedores_MenuFuncion" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow)
                oWindow = window.radWindow;
            else if (window.frameElement.radWindow)
                oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var window = getRadWindow();
            if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
            window.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <div class="SubTitulos">Funciones de <asp:Label ID="lblMenu" runat="server" /></div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <p style="margin: 0 0 10px 0;">
                    Una función es una acción dentro de la página: ver todo, crear y editar.
                    Los controles la consultan por su <b>nombre</b>, no por un código, así que
                    el mismo control puesto en dos páginas distintas resuelve el permiso de cada una.
                </p>
            </div>

            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="mfu_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Eliminar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar las funciones seleccionadas?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>

            <div class="SubTitulos" style="margin-top: 15px;">Agregar una función</div>

            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Nombre(*)</label></div>
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <rad:RadComboBox2 ID="cboNombre" runat="server" Width="90%" AllowCustomText="true">
                        <Items>
                            <rad:RadComboBoxItem Text="Ver todo" Value="Ver todo" />
                            <rad:RadComboBoxItem Text="Ver todo paises" Value="Ver todo paises" />
                            <rad:RadComboBoxItem Text="Crear y editar" Value="Crear y editar" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-2 col-md-2 col-xs-12"><label>Permiso(*)</label></div>
                <div class="col-lg-4 col-md-4 col-xs-12">
                    <rad:RadComboBox2 ID="cboPermiso" runat="server" Width="90%" />
                </div>
            </div>

            <div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
                <WebControls:PushButton ID="btnAgregar" runat="server" Text="Agregar" OnClick="btnAgregar_Click" />
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
            </div>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
