<%@ Control Language="C#" AutoEventWireup="true" CodeFile="Contactos.ascx.cs" Inherits="View_Comun_Controls_Cliente_Contactos" %>

<asp:UpdatePanel ID="udPanel" runat="server" UpdateMode="Conditional">
    <ContentTemplate>

<div class="sg-ct">

    <div class="sg-ct-cab">
        <div>
            <div class="sg-ct-titulo">Contactos del cliente</div>
            <div class="sg-ct-bajada">
                A quién llamar. El principal es el que se usa para las comunicaciones
                operacionales.
            </div>
        </div>

        <WebControls:PushButton ID="btnNuevo" runat="server" Text="Nuevo contacto"
            CssClass="sg-ct-btn is-principal" OnClick="btnNuevo_Click" CausesValidation="false" />
    </div>

    <%-- ============================================================
         EL FORMULARIO

         Se abre al agregar o al editar como una ventana hija (modal)
         centrada, con la página ensombrecida detrás, al estilo de las
         demás fichas del sistema.
         ============================================================ --%>
    <asp:Panel ID="pnlForm" runat="server" Visible="false" CssClass="sg-ct-overlay">
      <div class="sg-ct-modal">
        <div class="sg-ct-modal-head">
            <span class="sg-ct-modal-title"><asp:Literal ID="litFormTitulo" runat="server" /></span>
            <WebControls:PushButton ID="btnCerrarX" runat="server" Text="✕"
                CssClass="sg-ct-modal-x" OnClick="btnCancelar_Click" CausesValidation="false" ToolTip="Cerrar" />
        </div>
        <div class="sg-ct-modal-body">

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label for="<%=txtNombre.ClientID %>">Nombre del contacto <span class="sg-ct-req">*</span></label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
            </div>

            <div class="sigma-modal-field is-medio">
                <label for="<%=txtEmpresa.ClientID %>">Empresa</label>
                <WebControls:TextBox2 ID="txtEmpresa" runat="server" MaxLength="200" />
            </div>

            <div class="sigma-modal-field is-medio">
                <label for="<%=txtRubro.ClientID %>">Rubro</label>
                <WebControls:TextBox2 ID="txtRubro" runat="server" MaxLength="150" />
                <span class="sigma-modal-ayuda">Por ejemplo: Minería, Alimentos, Logística.</span>
            </div>

            <div class="sigma-modal-field is-medio">
                <label for="<%=txtCargo.ClientID %>">Función</label>
                <WebControls:TextBox2 ID="txtCargo" runat="server" MaxLength="200" />
                <span class="sigma-modal-ayuda">Por ejemplo: Jefa de Operaciones.</span>
            </div>

            <div class="sigma-modal-field is-medio">
                <label for="<%=txtTelefono.ClientID %>">Número telefónico</label>
                <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="50" />
            </div>

            <div class="sigma-modal-field is-medio">
                <label for="<%=txtEmail.ClientID %>">Correo</label>
                <WebControls:TextBox2 ID="txtEmail" runat="server" MaxLength="200" />
            </div>

            <div class="sigma-modal-field is-ancho">
                <label for="<%=txtDireccion.ClientID %>">Dirección</label>
                <WebControls:TextBox2 ID="txtDireccion" runat="server" MaxLength="300" />
            </div>

            <div class="sigma-modal-field is-ancho">
                <label for="<%=txtNotas.ClientID %>">Notas</label>
                <WebControls:TextBox2 ID="txtNotas" runat="server" TextMode="MultiLine" Rows="3" MaxLength="1000" />
            </div>

            <div class="sigma-modal-field is-ancho">
                <%-- La regla la impone la base: un nombre suelto no alcanza
                     para contactar a nadie. Se dice acá para que no se
                     descubra al guardar. --%>
                <span class="sigma-modal-ayuda">
                    Indique al menos un correo o un teléfono.
                </span>
            </div>

            <div class="sigma-modal-field is-ancho">
                <label class="sg-ct-check">
                    <asp:CheckBox ID="chkPrincipal" runat="server" />
                    <span class="sg-ct-check-txt">
                        <span class="sg-ct-check-t">Marcar como contacto principal</span>
                        <span class="sg-ct-check-d">
                            Hay uno solo por cliente: al marcar este, el anterior deja de serlo.
                        </span>
                    </span>
                </label>
            </div>
        </div>

        </div><%-- /sg-ct-modal-body --%>

        <div class="sg-ct-modal-pie">
            <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cancelar"
                CssClass="sg-ct-btn" OnClick="btnCancelar_Click" CausesValidation="false" />
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar contacto"
                CssClass="sg-ct-btn is-principal" OnClick="btnGuardar_Click" CausesValidation="false" />
        </div>
      </div><%-- /sg-ct-modal --%>
    </asp:Panel>

    <%-- ============================================================
         LA LISTA
         ============================================================ --%>
    <asp:Repeater ID="rptContactos" runat="server"
        OnItemCommand="rptContactos_ItemCommand" OnItemDataBound="rptContactos_ItemDataBound">
        <HeaderTemplate><div class="sg-ct-lista"></HeaderTemplate>

        <ItemTemplate>
            <div class='sg-ct-item <%# Eval("Clase") %>'>
                <span class="sg-ct-avatar" style='background-color: <%# Eval("Color") %>;'>
                    <%# Eval("Iniciales") %></span>

                <span class="sg-ct-txt">
                    <span class="sg-ct-nombre">
                        <span class="sg-ct-num">N.º <%# Eval("Numero") %></span>
                        <%# Eval("Nombre") %>
                        <%# Eval("ChipPrincipal") %>
                    </span>
                    <span class="sg-ct-cargo"><%# Eval("Cargo") %></span>
                    <span class="sg-ct-vias"><%# Eval("Vias") %></span>
                    <span class="sg-ct-meta"><%# Eval("Meta") %></span>
                </span>

                <span class="sg-ct-acciones">
                    <asp:LinkButton ID="btnEditar" runat="server" CssClass="sg-ct-icono"
                        CommandName="Editar" CommandArgument='<%# Eval("Id") %>'
                        CausesValidation="false" ToolTip="Editar contacto">
                        <i class="mdi mdi-pencil-outline"></i>
                    </asp:LinkButton>

                    <asp:LinkButton ID="btnEliminar" runat="server" CssClass="sg-ct-icono is-borrar"
                        CommandName="Eliminar" CommandArgument='<%# Eval("Id") %>'
                        CausesValidation="false" ToolTip="Eliminar contacto">
                        <i class="mdi mdi-trash-can-outline"></i>
                    </asp:LinkButton>
                </span>
            </div>
        </ItemTemplate>

        <FooterTemplate></div></FooterTemplate>
    </asp:Repeater>

    <asp:Panel ID="pnlVacio" runat="server" Visible="false" CssClass="sg-ct-vacio">
        <i class="mdi mdi-account-box-outline"></i>
        <div>
            <strong>Sin contactos.</strong>
            Agregue uno para centralizar las comunicaciones operacionales con este cliente.
        </div>
    </asp:Panel>

    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="sg-ct-vacio">
        <i class="mdi mdi-information-outline"></i>
        <div>Guarde primero el cliente: los contactos se agregan sobre uno que ya existe.</div>
    </asp:Panel>

</div>

    </ContentTemplate>
</asp:UpdatePanel>
