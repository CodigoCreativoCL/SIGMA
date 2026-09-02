<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Grupo.aspx.cs" Inherits="View_Organizacion_Grupos_Grupo" %>

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
    <h1 class="sigma-modal-title">Grupo de trabajo</h1>

    <%-- PESTAÑAS, Y LOS BOTONES AL FINAL

         Los botones Cerrar y Guardar estaban en MEDIO de la ficha: después
         de los datos del grupo y antes del bloque de integrantes. Guardar en
         la mitad de un formulario se lee como "guardar hasta acá", y el
         bloque de abajo parecía otra cosa que no se iba a guardar.

         Con dos bloques corresponde pestañas —es lo que dice el estándar y
         lo que hace la ficha de Repuesto—: cada cosa se ve entera, la
         ventana no crece, y las acciones quedan una sola vez, al pie.

         La pestaña de integrantes se oculta ENTERA mientras el grupo no
         exista: un integrante necesita un grupo al que pertenecer, y una
         pestaña que al abrirla no deja hacer nada se lee como que la
         pantalla se rompió. --%>
    <rad:RadTabStrip2 ID="tabFicha" runat="server" MultiPageID="mpFicha" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabDatos" Text="Datos" runat="server" PageViewID="pvDatos" />
            <rad:RadTab ID="tabIntegrantes" Text="Integrantes" runat="server" PageViewID="pvIntegrantes" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpFicha" runat="server" SelectedIndex="0" Width="100%">

        <rad:RadPageView ID="pvDatos" runat="server">

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-tag-outline"></i>Identificación</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>ID</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label>Código</label>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                        <span class="sigma-modal-ayuda">Se genera solo al guardar: <strong>GRU-</strong>más el número del registro.</span>
                        <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Grupo" />
                    </div>

                    <div class="sigma-modal-field is-mitad">
                        <label>Nombre(*)</label>
                        <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                        <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Grupo" />
                        <span class="sigma-modal-ayuda">Por ejemplo: Turno noche mecánicos.</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-factory"></i>Alcance</div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mitad">
                        <label>Planta</label>
                        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">
                            Vacío indica un grupo transversal, asignable en todas las plantas del cliente.
                        </span>
                    </div>

                    <div class="sigma-modal-field is-mitad">
                        <label>Especialidad predominante</label>
                        <rad:RadComboBox2 ID="cboEspecialidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    </div>

                    <div class="sigma-modal-field is-chico">
                        <label>Habilitado(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" ValidationGroup="Grupo" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" ValidationGroup="Grupo" />
                        </div>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" />
                    </div>
                </div>
            </div>

        </rad:RadPageView>

        <rad:RadPageView ID="pvIntegrantes" runat="server">

            <asp:Panel ID="pnlIntegrantes" runat="server" Visible="false">

                <div class="sigma-form-seccion">
                    <div class="titulo"><i class="mdi mdi-account-plus-outline"></i>Agregar a alguien</div>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-mitad">
                            <label>Persona</label>
                            <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">La lista muestra el perfil de cada persona.</span>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Desde</label>
                            <div class="sigma-modal-fecha">
                                <WebControls:Calendar ID="calDesde" runat="server" />
                            </div>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Hasta</label>
                            <div class="sigma-modal-fecha">
                                <WebControls:Calendar ID="calHasta" runat="server" />
                            </div>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>Rol</label>
                            <div class="sigma-modal-opciones">
                                <asp:CheckBox ID="chkEsLider" runat="server" Text=" Es líder" />
                            </div>
                        </div>

                        <div class="sigma-modal-field is-chico">
                            <label>&nbsp;</label>
                            <WebControls:PushButton ID="btnAgregar" runat="server" Text="Agregar" OnClick="btnAgregar_Click" />
                        </div>
                    </div>
                </div>

                <rad:RadGrid2 ID="GridIntegrantes" runat="server"
                    OnItemCreated="GridIntegrantes_ItemCreated"
                    OnItemDataBound="GridIntegrantes_ItemDataBound">
                    <MasterTableView CommandItemDisplay="None" DataKeyNames="gtu_id">
                    </MasterTableView>
                </rad:RadGrid2>

            </asp:Panel>

            <asp:Panel ID="pnlSinGrupo" runat="server" Visible="false" CssClass="sigma-modal-note">
                <i class="mdi mdi-information-outline"></i>
                <div>
                    Guarde el grupo primero. Un integrante necesita un grupo al que
                    pertenecer, así que esta pestaña se habilita en cuanto el grupo exista.
                </div>
            </asp:Panel>

        </rad:RadPageView>

    </rad:RadMultiPage>

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Grupo" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
