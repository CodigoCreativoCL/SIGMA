<%--
    USERCONTROL DE TAB / SUB-FORMULARIO - Identidad.ascx  (CLIENTE)

    PATRON (ver PATRON_MVC.md seccion 6 y PATRON_CONTROLES.md secciones 5 y 6):
      - Todo el contenido va dentro de un asp:UpdatePanel UpdateMode="Conditional".
      - Layout con la grilla Bootstrap de 12 columnas.
      - Se usan SIEMPRE los controles propios del proyecto, nunca los nativos.
      - Cada campo obligatorio lleva su asp:CustomValidator con
        ClientValidationFunction="validaControl" y el MISMO ValidationGroup
        que el boton Guardar.

    ARCHIVO GENERADO por 03-Generador.
--%>
<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Identidad.ascx.cs" Inherits="View_Comun_Controls_Cliente_Identidad" %>

<asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
    <ContentTemplate>

        <div class="row col-lg-12 col-md-12 col-xs-12">

            <div class="form-group col-lg-4 col-md-6 col-xs-12">
                <label>NOMBRE</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
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
                ValidationGroup="Cliente" />
        </div>

    </ContentTemplate>
</asp:UpdatePanel>
