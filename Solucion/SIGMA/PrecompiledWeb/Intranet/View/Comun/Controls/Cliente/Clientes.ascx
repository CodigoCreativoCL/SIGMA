<%@ control language="C#" autoeventwireup="true" inherits="View_Comun_Controls_Cliente_Clientes, App_Web_hqhu5dfg" %>


<script type="text/javascript">
    function abrirClientes(query) {
        window.location = ('<%=ResolveUrl(URLNuevoCliente) %>?query=' + query);
    }

    function refresh() {
        __doPostBack("<%=Grid.ClientID %>", '')
    }
</script>

<div class="col-lg-12 col-md-12 col-xs-12"> 
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrCliente_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="cli_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="abrirClientes(0)" />
                            <%-- "Dar de baja" y no "Eliminar": desde el bloque 52 el
                                 cliente se deshabilita y no se borra nada. El rotulo
                                 tiene que decir lo que pasa, o alguien confirma
                                 creyendo que destruye y despues no entiende por que
                                 el cliente sigue en los informes. --%>
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Dar de baja los clientes seleccionados? Dejarán de operar, pero su información se conserva.');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</div>
