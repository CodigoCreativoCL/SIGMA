<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Root_Mantenedores_MenuFuncion, App_Web_ilustbws" %>

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
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
    <h1 class="sigma-modal-title">Funciones de <asp:Label ID="lblMenu" runat="server" /></h1>

            <div class="sigma-modal-note">
                <p style="margin: 0;">
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

            <div class="sigma-modal-seccion">Agregar una función</div>

    <div class="sigma-modal-grid">
    <div class="sigma-modal-field">
        <label>Nombre(*)</label>
        <rad:RadComboBox2 ID="cboNombre" runat="server" Width="90%" AllowCustomText="true">
            <Items>
                <rad:RadComboBoxItem Text="Ver todo" Value="Ver todo" />
                <rad:RadComboBoxItem Text="Ver todo paises" Value="Ver todo paises" />
                <rad:RadComboBoxItem Text="Crear y editar" Value="Crear y editar" />
            </Items>
        </rad:RadComboBox2>
    </div>
    <div class="sigma-modal-field">
        <label>Permiso(*)</label>
        <rad:RadComboBox2 ID="cboPermiso" runat="server" Width="90%" />
    </div>
    </div>

<div class="sigma-modal-actions">
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
    <WebControls:PushButton ID="btnAgregar" runat="server" Text="Agregar" OnClick="btnAgregar_Click" />
</div>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
