<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ChecklistDetalleItem.ascx.cs" Inherits="View_Comun_Controls_Cliente_Checklist_ChecklistDetalleItem" %>


<script type="text/javascript" language="javascript">
    $(document).ready(function () {
        // Verifica el estado del radio button rdbVSi al cargar la página
        if ($("#<%= rdbVSi.ClientID %>").prop("checked")) {
            $("#<%= DivValores.ClientID %>").fadeIn(500);
            $("#<%= DivInformativo.ClientID %>").fadeIn(500); // Muestra el div
        } else {
            $("#<%= DivValores.ClientID %>").fadeOut(500);
            $("#<%= DivInformativo.ClientID %>").fadeOut(500);// Oculta el div
        }

        // Detecta el cambio en el radio button rdbVSi
        $("#<%= rdbVSi.ClientID %>").change(function () {
            if ($(this).prop("checked")) {
                $("#<%= DivValores.ClientID %>").fadeIn(500);
                $("#<%= DivInformativo.ClientID %>").fadeIn(500);  // Muestra el div
            }
        });

        // Detecta el cambio en el radio button rdbVNo
        $("#<%= rdbVNo.ClientID %>").change(function () {
            if ($(this).prop("checked")) {
                console.log("Entré al NO");
                $("#<%= DivValores.ClientID %>").fadeOut(500);
                $("#<%= DivInformativo.ClientID %>").fadeOut(500);

                // Limpiar campos cuando se selecciona rdbVNo
                $("#<%= txtValor.ClientID %>").val('');
                $("#<%= rdbNotSi.ClientID %>").prop("checked", false);
                $("#<%= rdbNotNo.ClientID %>").prop("checked", false);
            }
        });

        // Detecta el cambio en el ComboBox cboObjeto
        $("#<%= cboObjeto.ClientID %>").change(function () {
            var cho_id = $(this).val();
            console.log(cho_id);

            // Verifica si cho_id es 1, 2 o 3
            if (cho_id == "Caja de Texto" || cho_id == "Caja de Texto Numérica" || cho_id == "Lista Desplegable") {
                $("#<%= pnlValoresConfiguracion.ClientID %>").fadeIn(500);  // Muestra el panel
            } else {
                $("#<%= pnlValoresConfiguracion.ClientID %>").fadeOut(500);
                $("#<%= DivValores.ClientID %>").fadeOut(500);
                $("#<%= txtValor.ClientID %>").val('');
                $("#<%= rdbNotSi.ClientID %>").prop("checked", false);
                $("#<%= rdbNotNo.ClientID %>").prop("checked", false);
            }
        });

        // Opcionalmente, puedes verificar el estado del ComboBox cuando la página carga
        var cho_id = $("#<%= cboObjeto.ClientID %>").val();
        if (cho_id == "Caja de Texto" || cho_id == "Caja de Texto Numérica" || cho_id == "Lista Desplegable") {
            $("#<%= pnlValoresConfiguracion.ClientID %>").fadeIn(500);  // Muestra el panel si cumple la condición
        } else {
            $("#<%= pnlValoresConfiguracion.ClientID %>").fadeOut(500);
            $("#<%= DivValores.ClientID %>").fadeOut(500);
            $("#<%= txtValor.ClientID %>").val('');
            $("#<%= rdbNotSi.ClientID %>").prop("checked", false);
            $("#<%= rdbNotNo.ClientID %>").prop("checked", false);
        }
    });



</script>


<div class="SubTitulos">Detalle</div>

<div class="row col-lg-12 col-md-12 col-xs-12 ">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Ítem(*)</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <WebControls:TextBox2 ID="txtPregunta" runat="server" />
        <asp:CustomValidator ID="CustomValidator1" runat="server"
            ControlToValidate="txtPregunta"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ValidationGroup="ChecklistDetalle" />
    </div>
</div>
<div class="row col-lg-12 col-md-12 col-xs-12 ">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Tipo de Campo(*)</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <rad:RadComboBox2 ID="cboObjeto" runat="server" OnLoad="LoadControls" Width="100%" />
        <asp:CustomValidator ID="CustomValidator2" runat="server"
            ControlToValidate="cboObjeto"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ValidationGroup="ChecklistDetalle" />
    </div>
</div>
<br />

<div class="row col-lg-12 col-md-12 col-xs-12 d-flex align-items-center">
    <div id="pnlValoresConfiguracion" runat="server" style="display: none" class="row col-lg-5 col-md-5 col-xs-12">
        <div class="col-lg-5 col-md-5 col-xs-12">
            <label>Valor Predeterminado</label>
        </div>
        <div class="col-lg-3 col-md-3 col-xs-12 d-flex align-items-center">
            <div class="form-check form-check-inline">
                <asp:RadioButton ID="rdbVSi" runat="server" Text="SI" GroupName="Valor_Predeterminado" CssClass="form-check-input" />
                <asp:RadioButton ID="rdbVNo" runat="server" Text="NO" GroupName="Valor_Predeterminado" CssClass="form-check-input" />
            </div>
        </div>
    </div>

    <!-- Panel DivValores -->
    <div id="DivValores" runat="server" class="col-lg-6 col-md- col-xs-12" style="display: none">
        <!-- Panel oculto -->
        <asp:Panel ID="pnlValores" runat="server" CssClass="col-lg-12 col-md-12 col-xs-12 d-flex align-items-left panel">
            <!-- Indique -->
            <div class="col-lg-2 col-md-2 col-xs-12">
                <label>Indique</label>
            </div>
            <div class="col-lg-3 col-md-3 col-xs-12">
                <WebControls:TextBox2 ID="txtValor" runat="server" CssClass="form-control" />
            </div>

            <!-- Requiere Notificación -->
            <div class="col-lg-3 col-md-3 col-xs-12 text-right">
                <label class="text-right">Requiere Notificación</label>
            </div>
            <div class="col-lg-2 col-md-2 col-xs-12 d-flex align-items-center">
                <div class="form-check form-check-inline">
                    <asp:RadioButton ID="rdbNotSi" runat="server" Text="SI" GroupName="Notificacion" CssClass="form-check-input" />
                    <asp:RadioButton ID="rdbNotNo" runat="server" Text="NO" GroupName="Notificacion" CssClass="form-check-input" />
                </div>
            </div>
        </asp:Panel>
    </div>
</div>


<br />
<div class="row col-lg-12 col-md-12 col-xs-12">
    <div class="col-lg-2 col-md-2 col-xs-12">
        <label>Habilitado (*)</label>
    </div>
    <div class="col-lg-10 col-md-10 col-xs-12">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
    </div>
</div>

<!-- Panel DivInformativo Informativo -->
<div id="DivInformativo" runat="server" style="display: none">
    <div class="SubTitulos"></div>

    <div class="col-lg-12 col-md-12 col-xs-12">
        <h5><strong>Informativo: Generación de correo con alerta</strong></h5>
        <ul>
            <li><strong>Caja de Texto:</strong> Si se asigna un valor predeterminado y la respuesta ingresada es diferente al valor asignado, se enviará un correo con una advertencia.</li>
            <li><strong>Caja de Texto Numérica:</strong> Si se asigna un valor predeterminado y la respuesta ingresada es menor que dicho valor, se enviará un correo con una advertencia.</li>
            <li><strong>Casilla de Verificación:</strong> Si se responde con un "No" y se agrega un detalle en la respuesta, se enviará un correo con una advertencia.</li>
            <li><strong>Lista Desplegable:</strong> Si se asigna un valor predeterminado y la respuesta es diferente al valor asignado, se enviará un correo con una advertencia.</li>
        </ul>

        <p><strong>Para que el correo sea enviado, selecciona "Requiere Notificación".</strong></p>
        <p><strong>El correo es generado una vez que el responsable de responder el checklist lo complete y se encuentren dichas diferencias.</strong></p>
    </div>
</div>
<div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
    </br>
  <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_OnClick" ValidationGroup="ChecklistDetalle" />
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow();" CssClass="ButtonCerrar" />
</div>
