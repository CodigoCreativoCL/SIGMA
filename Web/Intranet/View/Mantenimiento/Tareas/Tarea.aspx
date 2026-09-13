<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Tarea.aspx.cs" Inherits="View_Mantenimiento_Tareas_Tarea" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <style>
        .sigma-centro-tarea .sigma-modal { padding: 0; }
        .sigma-centro-tarea .RadMultiPage { padding-top: 14px; }

        /* El hilo de comentarios: una tarjeta por ocurrencia, adentro los
           comentarios con sangria para las respuestas. */
        .sg-hilo { border: 1px solid var(--sg-borde, #e5e7eb); border-radius: 10px; padding: 12px 14px; margin-bottom: 12px; background: #fff; }
        .sg-hilo-cab { display: flex; gap: 10px; align-items: center; margin-bottom: 8px; font-weight: 600; }
        .sg-com { padding: 8px 10px; border-left: 3px solid #e5e7eb; margin: 6px 0; }
        .sg-com.is-respuesta { margin-left: 28px; border-left-color: #c7d2fe; }
        .sg-com-meta { font-size: 12px; color: #6b7280; margin-bottom: 2px; }
        .sg-com-texto { white-space: pre-wrap; }
        .sg-com-acciones a { font-size: 12px; margin-right: 10px; cursor: pointer; }
    </style>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        var queryNuevaProgramacion = '<%=QueryNuevaProgramacion %>';

        function abrirTareaProgramacion(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Tareas/TareaProgramacion.aspx") %>?query=' + query,
                title: query === queryNuevaProgramacion ? 'Programar tarea' : 'Programación de la tarea',
                width: 860,
                initialHeight: 520
            });
        }

        function refresh() {
            __doPostBack("<%=GridProgramaciones.ClientID %>", '');
        }

        /* Responder: se anota a quien y se lleva el foco al cuadro. */
        function responder(ocurrencia, padre, nombre) {
            document.getElementById('<%=hidOcurrencia.ClientID %>').value = ocurrencia;
            document.getElementById('<%=hidPadre.ClientID %>').value = padre;
            document.getElementById('<%=litRespondiendo.ClientID %>').innerText = padre ? 'Respondiendo a ' + nombre : 'Comentario nuevo en la ocurrencia ' + ocurrencia;
            var t = document.getElementById('<%=txtComentario.ClientID %>');
            t.focus();
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Mantenimiento · Tareas recurrentes
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    <asp:Literal ID="litTitulo" runat="server">Tarea</asp:Literal>
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <asp:Literal ID="litSubtitulo" runat="server" />
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
<div class="sigma-centro-tarea"><div class="sigma-modal" style="max-width:none;">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <rad:RadTabStrip2 ID="tabTarea" runat="server" MultiPageID="mpTarea" SelectedIndex="0">
        <Tabs>
            <rad:RadTab ID="tabFicha" Text="Ficha" runat="server" PageViewID="pvFicha" />
            <rad:RadTab ID="tabProgramaciones" Text="Programaciones" runat="server" PageViewID="pvProgramaciones" />
            <rad:RadTab ID="tabComentarios" Text="Comentarios" runat="server" PageViewID="pvComentarios" />
        </Tabs>
    </rad:RadTabStrip2>

    <rad:RadMultiPage ID="mpTarea" runat="server" SelectedIndex="0" Width="100%">

        <%-- ================================ FICHA ================================ --%>
        <rad:RadPageView ID="pvFicha" runat="server">
            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-checkbox-marked-circle-outline"></i>Qué es</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-mini">
                        <label>ID</label>
                        <asp:Label ID="lblId" runat="server"></asp:Label>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Código</label>
                        <div class="sg-codigo">
                            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="90" UpperCase="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Vacío: se numera solo. Único dentro del cliente.</span>
                    </div>
                    <div class="sigma-modal-field is-grande">
                        <label>Título(*)</label>
                        <WebControls:TextBox2 ID="txtTitulo" runat="server" MaxLength="400" />
                        <asp:CustomValidator ID="cvTitulo" runat="server" ControlToValidate="txtTitulo"
                            ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Tarea" />
                        <span class="sigma-modal-ayuda">Lo que se hace, en imperativo: «Revisar nivel de aceite del reductor».</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Prioridad(*)</label>
                        <rad:RadComboBox2 ID="cboPrioridad" runat="server" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Duración estimada (min)</label>
                        <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="6" />
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Requiere evidencia</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbEvidenciaSi" runat="server" Text="SI" GroupName="Evidencia" />
                            <asp:RadioButton ID="rdbEvidenciaNo" runat="server" Text="NO" GroupName="Evidencia" Checked="true" />
                        </div>
                        <span class="sigma-modal-ayuda">Con SI, el técnico tiene que adjuntar foto al ejecutarla.</span>
                    </div>
                    <div class="sigma-modal-field is-ancho">
                        <label>Descripción</label>
                        <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="2000" />
                        <span class="sigma-modal-ayuda">Cómo se hace y qué mirar. Es lo que lee el técnico en el teléfono.</span>
                    </div>
                </div>
            </div>

            <div class="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-map-marker-outline"></i>Dónde</div>
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Planta</label>
                        <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                            OnSelectedIndexChanged="cboPlanta_SelectedIndexChanged" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Acota el área y el equipo. Vacío: cualquier planta.</span>
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Área</label>
                        <rad:RadComboBox2 ID="cboArea" runat="server" Filter="Contains" Width="100%" />
                    </div>
                    <div class="sigma-modal-field is-medio">
                        <label>Equipo</label>
                        <rad:RadComboBox2 ID="cboActivo" runat="server" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Opcional: la tarea puede ser de un lugar y no de una máquina.</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Habilitado(*)</label>
                        <div class="sigma-modal-opciones">
                            <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                            <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                        </div>
                    </div>
                </div>
            </div>

            <wuc:Auditoria runat="server" ID="wucAuditoria" />

            <div class="sigma-modal-actions">
                <WebControls:PushButton ID="btnVolver" runat="server" Text="Volver al listado" CssClass="ButtonCerrar" OnClick="btnVolver_Click" CausesValidation="false" />
                <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Tarea" />
            </div>
        </rad:RadPageView>

        <%-- ============================ PROGRAMACIONES ============================ --%>
        <rad:RadPageView ID="pvProgramaciones" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-information-outline"></i>
                <div>
                    <strong>Cada cuánto y quién.</strong> Una tarea puede tener varias programaciones
                    —diaria en el turno de mañana con un responsable, semanal con un grupo—. Las
                    ocurrencias las genera el sistema desde la programación.
                </div>
            </div>
            <rad:RadGrid2 ID="GridProgramaciones" runat="server" OnItemDataBound="GridProgramaciones_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="tpr_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevaProgramacion" runat="server" Text="Programar" CssClass="icono_guardar" OnClientClick="return abrirTareaProgramacion(queryNuevaProgramacion);" />
                            <asp:LinkButton ID="lnkGenerarOcurrencias" runat="server" Text="Generar ocurrencias (90 días)" CssClass="icono_excel" OnClick="lnkGenerarOcurrencias_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Generar las ocurrencias que faltan de esta tarea para los próximos 90 días? Las que ya existen no se duplican.');" />
                            <asp:LinkButton ID="lnkQuitarProgramacion" runat="server" Text="Quitar" CssClass="icono_eliminar" OnClick="lnkQuitarProgramacion_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Quitar las programaciones seleccionadas? La tarea deja de generar por ellas.');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </rad:RadPageView>

        <%-- ============================== COMENTARIOS ============================== --%>
        <rad:RadPageView ID="pvComentarios" runat="server">
            <div class="sigma-modal-note" style="margin:10px 0 12px;">
                <i class="mdi mdi-comment-text-multiple-outline"></i>
                <div>
                    <strong>Lo que se dijo en cada ejecución.</strong> El técnico comenta desde el teléfono;
                    desde aquí se responde. Un comentario no se edita ni se borra: se responde.
                </div>
            </div>

            <asp:Literal ID="litSinComentarios" runat="server" Visible="false"><span class="sigma-inv-vacio">Esta tarea aún no tiene comentarios.</span></asp:Literal>
            <asp:Literal ID="litHilos" runat="server" />

            <asp:Panel ID="pnlResponder" runat="server" CssClass="sigma-form-seccion">
                <div class="titulo"><i class="mdi mdi-reply-outline"></i>Responder</div>
                <asp:HiddenField ID="hidOcurrencia" runat="server" />
                <asp:HiddenField ID="hidPadre" runat="server" />
                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-ancho">
                        <label><asp:Label ID="litRespondiendo" runat="server" Text="Elija «Responder» en un comentario, o «Comentar» en una ocurrencia." /></label>
                        <WebControls:TextArea2 ID="txtComentario" runat="server" MaxLength="4000" />
                    </div>
                </div>
                <div class="sigma-modal-actions">
                    <WebControls:PushButton ID="btnComentar" runat="server" Text="Publicar" OnClick="btnComentar_Click" CausesValidation="false" />
                </div>
            </asp:Panel>
        </rad:RadPageView>

    </rad:RadMultiPage>

        </ContentTemplate>
    </asp:UpdatePanel>
</div></div>
</asp:Content>
