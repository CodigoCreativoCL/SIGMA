<%@ page language="C#" masterpagefile="~/Master/Simple.master" autoeventwireup="true" inherits="View_Comun_Clientes_AsociarUsuario, App_Web_gmat4w2s" %>

<%@ Register Src="~/View/Comun/Controls/Cliente/Usuarios.ascx" TagPrefix="wuc" TagName="Usuarios" %>
<%@ Register Src="~/View/Comun/Controls/FiltroAvanzado.ascx" TagPrefix="wuc" TagName="Filtro" %>


<asp:Content ID="ContenHead" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript" language="javascript">       

        //Cierra el RadWindow"
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

<asp:Content ID="Content1" ContentPlaceHolderID="cphBody" runat="Server">

    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="container-fluid">
                <div class="row">
                    <div class="col-lg-2 col-md-2 col-xs-12">
                        <label>Perfiles:</label>
                    </div>
                    <div class="col-lg-2 col-md-2 col-xs-12">
                        <rad:RadComboBox2 ID="cboPerfiles" runat="server" OnLoad="LoadControls" MarkFirstMatch="true" EnableLoadOnDemand="true" Width="100%" Filter="Contains" AutoPostBack="true" />
                    </div>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>


    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <%-- Migrada al estandar sigma-modal (§5 del MD). No lleva
                 sigma-modal-grid porque no es un formulario de campos: lo
                 que se viene a hacer aqui es elegir gente de una lista. --%>
            <div class="sigma-modal">

                <%-- La pantalla sirve para dos cosas segun venga o no una
                     planta en el querystring: autorizar gente EN UNA PLANTA,
                     o afiliarla AL CLIENTE. El encabezado lo dice el
                     code-behind; un texto fijo mentiria en uno de los dos. --%>
                <div class="sigma-modal-eyebrow">
                    <i class="mdi mdi-account-multiple-plus-outline"></i>
                    <asp:Literal ID="litContexto" runat="server" />
                </div>

                <h1 class="sigma-modal-title"><asp:Literal ID="litTitulo" runat="server" /></h1>

                <div class="sigma-modal-note">
                    <asp:Literal ID="litNota" runat="server" />
                </div>

                <rad:RadGrid2 ID="Grid" runat="server">
                    <MasterTableView CommandItemDisplay="none" DataKeyNames="usu_id">
                        <CommandItemTemplate>
                            <wuc:Usuarios runat="server" ID="wucUsuarios" />
                        </CommandItemTemplate>
                    </MasterTableView>
                </rad:RadGrid2>

                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow();" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Asociar" OnClick="btnGuardar_OnClick" ValidationGroup="Identidad" />
                </div>

            </div>

        </ContentTemplate>
        <Triggers>
            <asp:PostBackTrigger ControlID="btnGuardar" />
        </Triggers>
    </asp:UpdatePanel>
</asp:Content>
