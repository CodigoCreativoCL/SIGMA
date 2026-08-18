<%@ Control Language="C#" AutoEventWireup="true" CodeFile="ChecklistDetalle.ascx.cs" Inherits="View_Comun_Controls_Cliente_Checklist_ChecklistDetalle" %>


<script type="text/javascript">
        <!--Obtengo Modal-->
    function getRadWindow() {
        var oWindow = null;
        if (window.radWindow) oWindow = window.radWindow;
        else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
        return oWindow;
    }

    function closeWindow() {
        var window = getRadWindow();
        if (window.BrowserWindow.refresh) window.BrowserWindow.refresh();
        window.close();
    }

    function registraOrden(objeto, id, id_check_list) {
        var orden = $("#<%=Grid.ClientID %> input[id*='" + objeto + "']:text");

        $.ajax({
            type: "POST",
            url: '<%= ResolveUrl("~/WebService/WsOrdenChecklist.asmx/registraOrden") %>',
            data: JSON.stringify({ "orden": orden.val(), "id": id, "id_check_list": id_check_list }),
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            async: false,
            success: function (response) {
                if (response.d.error) {
                    Swal.fire({
                        type: 'error',
                        title: 'Error',
                        text: response.d.detalle
                    });
                } else {
                    Swal.fire({
                        type: 'success',
                        title: 'Orden Actualizada',
                        text: `La orden ha sido cambiada a: ${orden.val()} (ID: ${id})`,
                        confirmButtonText: 'Aceptar'
                    }).then(() => {
                        refresh();
                    });
                }
            },
            error: function (XMLHttpRequest, textStatus, errorThrown) {
                Swal.fire({
                    type: 'error',
                    title: 'Error en la petición',
                    text: `${textStatus}: ${XMLHttpRequest.responseText}`
                });
            }
        });
    }


    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }

</script>




<div class="SubTitulos">Checklist</div>
<div class="row col-lg-12 col-md-12 col-xs-12">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Cliente</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <asp:Label ID="lblCliente" runat="server"></asp:Label>
    </div>
</div>
<div class="row col-lg-12 col-md-12 col-xs-12">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Nombre (*)</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <WebControls:TextBox2 ID="txtNombre" runat="server" />
        <asp:CustomValidator ID="CustomValidator5" runat="server"
            ControlToValidate="txtNombre"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ValidationGroup="Checklist" />
    </div>
</div>
<div class="row col-lg-12 col-md-12 col-xs-12">
    <div class="form-group col-lg-2 col-md-2 col-xs-12">
        <label>Descripción</label>
    </div>
    <div class="form-group col-lg-10 col-md-10 col-xs-12">
        <WebControls:TextArea2 ID="txtDescripcion" runat="server" />
        <asp:CustomValidator ID="CustomValidator1" runat="server"
            ControlToValidate="txtDescripcion"
            ValidateEmptyText="true"
            ClientValidationFunction="validaControl"
            ValidationGroup="Checklist" />
    </div>
</div>
<div class="row col-lg-12 col-md-12 col-xs-12">
    <div class="col-lg-2 col-md-2 col-xs-12">
        <label>Habilitado (*)</label>
    </div>
    <div class="col-lg-10 col-md-10 col-xs-12">
        <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
        <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
    </div>
</div>

<asp:Panel ID="pnlCheckListDetalle" runat="server" Visible="true">
    <div class="SubTitulos col-lg-12 col-md-12 col-xs-12">
        Detalle
    </div>
    <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="Grid_ItemDataBound">
        <MasterTableView CommandItemDisplay="Top" DataKeyNames="chd_id, chd_id_checklist, chd_orden, chd_objeto, NOMBREOBJETO">
            <CommandItemTemplate>
                <div>
                    <asp:LinkButton ID="lnkAñadir" runat="server" Text="Añadir" CssClass="icono_guardar" OnClick="lnkAñadir_Click" />
                    <asp:LinkButton ID="lnkEliminar" runat="server" Text="Quitar" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                        OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea eliminar los registros seleccionados?');" />
                </div>
            </CommandItemTemplate>
        </MasterTableView>
        <ClientSettings>
            <Scrolling AllowScroll="True" ScrollHeight="320" />
        </ClientSettings>
    </rad:RadGrid2>
</asp:Panel>


<div class="col-lg-12 col-md-12 col-xs-12 form-col-center">
    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Cajas" />
    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" OnClientClick="closeWindow()" CssClass="ButtonCerrar" />
</div>
