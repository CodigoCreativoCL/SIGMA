<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Grupo.aspx.cs" Inherits="View_Organizacion_Grupos_Grupo" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-grupo.css?vrs=2") %>' rel="stylesheet" />
    <script src='<%=ResolveUrl("~/Js/sigma-grupo.js?vrs=2") %>'></script>
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
    <div class="sg-grupo-head">
        <span class="sg-grupo-head__icon"><i class="mdi mdi-account-group-outline"></i></span>
        <div>
            <span class="sg-grupo-eyebrow">Equipo operativo</span>
            <h1 class="sigma-modal-title" data-sigma-record-name><asp:Literal ID="litTituloGrupo" runat="server" /></h1>
            <p>Organiza el alcance, la composición y el liderazgo de la cuadrilla.</p>
        </div>
        <div class="sg-grupo-head__meta">
            <asp:Literal ID="litCodigoGrupo" runat="server" />
            <asp:Literal ID="litEstadoGrupo" runat="server" />
        </div>
    </div>

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
                        <%-- El prefijo lo pone el sistema y no se puede tocar; el resto
                             lo escribe quien crea el registro. Van juntos en una sola
                             caja para que se lea como UN codigo y no como dos campos. --%>
                        <div class="sg-codigo">
                            <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                        </div>
                        <span class="sigma-modal-ayuda">El prefijo lo pone el sistema; escriba usted el resto (por ejemplo <em>CALDERAS</em>). Si lo deja vacío, se numera solo.</span>
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

                    <div class="sigma-modal-field is-mitad sg-grupo-predominante">
                        <label><i class="mdi mdi-auto-fix"></i> Especialidad predominante</label>
                        <strong><asp:Literal ID="litEspecialidadPredominante" runat="server" /></strong>
                        <span class="sigma-modal-ayuda"><asp:Literal ID="litEspecialidadDetalle" runat="server" /></span>
                        <div class="sg-grupo-composicion"><asp:Literal ID="litComposicion" runat="server" /></div>
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

                <div class="sg-grupo-team-summary">
                    <div><span>Composición vigente</span><strong><asp:Literal ID="litResumenIntegrantes" runat="server" /></strong></div>
                    <div><span>Liderazgo</span><strong><asp:Literal ID="litResumenLider" runat="server" /></strong></div>
                    <div><span>Predominante</span><strong><asp:Literal ID="litResumenPredominante" runat="server" /></strong></div>
                </div>

                <%-- ==========================================================
                     AGREGAR A ALGUIEN

                     LA PERSONA PRIMERO, Y SOLA

                       Antes la persona compartia fila con dos fechas, una
                       casilla y un boton: cinco campos del mismo tamaño, y
                       elegir a quien entra al grupo -que es de lo que se
                       trata- no se veia mas importante que la fecha de
                       termino.

                     LAS FECHAS SON OPCIONALES Y AHORA LO DICEN

                       Estaban rotuladas "Desde" y "Hasta" a secas, del mismo
                       modo que un campo obligatorio. Se llenaban por las
                       dudas, y llenarlas con la fecha de hoy es justo lo que
                       hacia que el integrante quedara sin vigencia si el
                       reloj no coincidia. Vacias significan "desde ya y sin
                       termino", y eso es lo que dice el texto de ayuda.
                     ========================================================== --%>
                <div class="sigma-form-seccion sg-grupo-alta">
                    <div class="titulo"><i class="mdi mdi-account-plus-outline"></i>Agregar a alguien</div>

                    <div class="sg-grupo-alta-persona">
                        <label for="cboUsuario">¿Quién se suma al grupo?</label>
                        <rad:RadComboBox2 ID="cboUsuario" runat="server" Filter="Contains" Width="100%" />
                        <span class="sigma-modal-ayuda">Escriba para buscar. La lista muestra el perfil y las especialidades de cada persona.</span>
                    </div>

                    <div class="sg-grupo-alta-detalle">
                        <div class="sg-grupo-alta-campo">
                            <label>Desde <em>opcional</em></label>
                            <div class="sigma-modal-fecha">
                                <WebControls:Calendar ID="calDesde" runat="server" />
                            </div>
                        </div>

                        <div class="sg-grupo-alta-campo">
                            <label>Hasta <em>opcional</em></label>
                            <div class="sigma-modal-fecha">
                                <WebControls:Calendar ID="calHasta" runat="server" />
                            </div>
                        </div>

                        <%-- El liderazgo como interruptor y no como casilla:
                             es un rol, no una preferencia, y el grupo admite
                             uno solo a la vez. --%>
                        <div class="sg-grupo-alta-campo is-rol">
                            <label>Rol en el grupo</label>
                            <asp:CheckBox ID="chkEsLider" runat="server" CssClass="sg-grupo-lider-check" Text="Es el líder" />
                        </div>

                        <div class="sg-grupo-alta-campo is-accion">
                            <asp:LinkButton ID="btnAgregar" runat="server" CssClass="sigma-accion is-primaria" OnClick="btnAgregar_Click">
                                <i class="mdi mdi-account-plus"></i><span>Agregar al grupo</span>
                            </asp:LinkButton>
                        </div>
                    </div>

                    <p class="sg-grupo-alta-nota">
                        <i class="mdi mdi-information-outline"></i>
                        Sin fechas, la persona queda vigente desde hoy y sin término.
                        El grupo admite <strong>un solo líder vigente</strong>.
                    </p>
                </div>

                <div class="sg-grupo-list-head">
                    <div><strong>Personas del grupo</strong><span>Nombre, especialidades, vigencia y rol.</span></div>
                    <div class="sg-grupo-search">
                        <i class="mdi mdi-magnify"></i>
                        <asp:TextBox ID="txtBuscarIntegrante" runat="server" AutoPostBack="true"
                            OnTextChanged="txtBuscarIntegrante_TextChanged" placeholder="Buscar persona o especialidad..." />
                        <asp:LinkButton ID="lnkLimpiarIntegrantes" runat="server" OnClick="lnkLimpiarIntegrantes_Click"
                            CssClass="sg-grupo-search__clear" ToolTip="Limpiar búsqueda">
                            <i class="mdi mdi-close"></i>
                        </asp:LinkButton>
                    </div>
                </div>

                <%-- ==========================================================
                     LAS PERSONAS DEL GRUPO

                     POR QUE NO ES UNA GRILLA

                       Una RadGrid resuelve tablas de muchas filas y muchas
                       columnas: ordenar, paginar, filtrar. Un grupo de
                       trabajo tiene entre tres y quince personas, y de cada
                       una interesan cuatro cosas. La grilla traia su
                       paginador -"Registros por pagina: 25", debajo de una
                       sola fila-, su cabecera en mayusculas y su ancho fijo
                       por columna, que dejaba las especialidades cortadas.

                       Con un repeater cada persona es una tarjeta: la cara,
                       el nombre, lo que sabe hacer y hasta cuando. Se lee
                       como una lista de personas, que es lo que es.

                     LO QUE NO CAMBIO

                       El borrado sigue siendo un comando del servidor con su
                       confirmacion y su chequeo de permiso, igual que antes.
                       Lo unico que cambio es como se dibuja.
                     ========================================================== --%>
                <asp:Repeater ID="rptIntegrantes" runat="server"
                    OnItemDataBound="rptIntegrantes_ItemDataBound"
                    OnItemCommand="rptIntegrantes_ItemCommand">
                    <HeaderTemplate>
                        <ul class="sg-personas">
                    </HeaderTemplate>
                    <ItemTemplate>
                        <li class="sg-persona">
                            <asp:Literal ID="litPersona" runat="server" />
                            <asp:LinkButton ID="lnkQuitar" runat="server" CommandName="quitar"
                                CssClass="sg-persona-quitar" ToolTip="Quitar del grupo"
                                CausesValidation="false">
                                <i class="mdi mdi-account-remove-outline" aria-hidden="true"></i>
                            </asp:LinkButton>
                        </li>
                    </ItemTemplate>
                    <FooterTemplate>
                        </ul>
                    </FooterTemplate>
                </asp:Repeater>

                <asp:Panel ID="pnlSinIntegrantes" runat="server" Visible="false" CssClass="sg-personas-vacio">
                    <i class="mdi mdi-account-search-outline" aria-hidden="true"></i>
                    <strong><asp:Literal ID="litVacioTitulo" runat="server" /></strong>
                    <span><asp:Literal ID="litVacioTexto" runat="server" /></span>
                </asp:Panel>

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
