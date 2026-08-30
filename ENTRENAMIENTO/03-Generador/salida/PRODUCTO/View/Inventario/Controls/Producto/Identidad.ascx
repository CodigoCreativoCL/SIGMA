<%--
    USERCONTROL DE TAB / SUB-FORMULARIO - Identidad.ascx  (PRODUCTO)

    PATRON (ver PATRON_MVC.md seccion 6 y PATRON_CONTROLES.md secciones 5 y 6):
      - Todo el contenido va dentro de un asp:UpdatePanel UpdateMode="Conditional".
      - Layout con la grilla Bootstrap de 12 columnas.
      - Se usan SIEMPRE los controles propios del proyecto, nunca los nativos.
      - Cada campo obligatorio lleva su asp:CustomValidator con
        ClientValidationFunction="validaControl" y el MISMO ValidationGroup
        que el boton Guardar.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Identidad.ascx.cs" Inherits="View_Inventario_Controls_Producto_Identidad" %>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

        <div class="row col-lg-12 col-md-12 col-xs-12">

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Codigo</label>
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="20" UpperCase="true" />
                <asp:CustomValidator ID="cvCodigo" runat="server"
                    ControlToValidate="txtCodigo"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Producto" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Nombre</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server"
                    ControlToValidate="txtNombre"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Producto" />
            </div>

            <div class="form-group col-lg-12 col-md-12 col-xs-12">
                <label>Descripcion</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Categoria</label>
                <%-- OnLoad="LoadControls": el combo se puebla desde el Controller
                     una sola vez (dentro del !IsPostBack del code-behind). --%>
                <rad:RadComboBox2 ID="cboCategoria" runat="server"
                    OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvCategoria" runat="server"
                    ControlToValidate="cboCategoria"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Producto" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Proveedor</label>
                <%-- OnLoad="LoadControls": el combo se puebla desde el Controller
                     una sola vez (dentro del !IsPostBack del code-behind). --%>
                <rad:RadComboBox2 ID="cboProveedor" runat="server"
                    OnLoad="LoadControls" Filter="Contains" Width="100%" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Precio</label>
                <rad:RadNumericBox2 ID="txtPrecio" runat="server" Width="100%">
                    <NumberFormat DecimalDigits="2" />
                </rad:RadNumericBox2>
                <asp:CustomValidator ID="cvPrecio" runat="server"
                    ControlToValidate="txtPrecio"
                    ValidateEmptyText="true"
                    ClientValidationFunction="validaControl"
                    ValidationGroup="Producto" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Stock</label>
                <rad:RadNumericBox2 ID="txtStock" runat="server" Width="100%">
                    <NumberFormat DecimalDigits="0" />
                </rad:RadNumericBox2>
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Vencimiento</label>
                <rad:RadDatePicker ID="dtpVencimiento" runat="server" Width="100%" />
            </div>

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>Habilitado</label>
                <WebControls:CheckBox2 ID="chkHabilitado" runat="server" Checked="true" />
            </div>

        </div>

        <div class="row col-lg-12 col-md-12 col-xs-12" style="text-align: right;">
            <%-- ValidationGroup DEBE coincidir con el de todos los CustomValidator. --%>
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar"
                CssClass="Button IcoGuardar"
                OnClick="btnGuardar_Click"
                ValidationGroup="Producto" />
        </div>

    </ContentTemplate>
</asp:UpdatePanel>
