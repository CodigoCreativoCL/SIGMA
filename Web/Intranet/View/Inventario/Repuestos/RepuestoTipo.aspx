<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="RepuestoTipo.aspx.cs" Inherits="View_Inventario_Repuestos_RepuestoTipo" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var w = getRadWindow();
            if (w.BrowserWindow.refresh) w.BrowserWindow.refresh();
            w.close();
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-shape-outline"></i>La categoría</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>ID</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label>Código</label>
                        <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                             lo escribe quien crea el registro. Van juntos en una sola
                             caja para que se lea como UN codigo y no como dos campos. --%>
                        <div class="sg-codigo">
                            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" />
                        </div>
                        <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>ROD</em>). Si lo deja vacío, se numera solo.</span>
                    </div>

                    <div class="sigma-modal-field is-mitad">
                        <label>Nombre(*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Tipo" />
                        <span class="sigma-modal-ayuda">Por ejemplo: Rodamientos.</span>
                    </div>

                    <div class="sigma-modal-field is-chico">
                        <label>Orden</label>
                        <WebControls:TextBox2 ID="txtOrden" runat="server" MaxLength="4" />
                        <span class="sigma-modal-ayuda">
                            Decide la posición de su pestaña en el listado de repuestos.
                            Menor primero. Vacío es cero.
                        </span>
                    </div>

                    <div class="sigma-modal-field is-chico">
                        <label>Habilitado(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Tipo" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Tipo" />
                        </div>
                        <span class="sigma-modal-ayuda">
                            No se puede deshabilitar mientras tenga repuestos activos.
                        </span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
                    </div>
                </div>
            </div>

            <asp:Panel ID="pnlUso" runat="server" Visible="false" CssClass="sigma-modal-note">
                <i class="mdi mdi-information-outline"></i>
                <div><asp:Literal ID="litUso" runat="server" /></div>
            </asp:Panel>

            <div class="sigma-modal-actions">
                <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Tipo" />
            </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
