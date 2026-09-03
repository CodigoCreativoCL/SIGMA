<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Proveedor.aspx.cs" Inherits="View_Terceros_Proveedores_Proveedor" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-ficha.css?vrs=3") %>' rel="stylesheet" />

    <script type="text/javascript">
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
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal sg-ficha-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <%-- ============================================================
         ENCABEZADO
         ============================================================ --%>
    <div class="sg-fx-cab">
        <div class="sg-fx-cab-txt">
            <span class="sg-fx-eyebrow">Ficha de proveedor</span>

            <h1 class="sg-fx-titulo">
                <asp:Literal ID="litTitulo" runat="server" />
                <asp:Literal ID="litEstadoChip" runat="server" />
            </h1>

            <div class="sg-fx-fantasia"><asp:Literal ID="litFantasia" runat="server" /></div>
            <div class="sg-fx-meta"><asp:Literal ID="litMeta" runat="server" /></div>

            <p class="sg-fx-bajada">
                Gestiona la identificación, servicios, contacto y configuración del proveedor.
            </p>
        </div>

        <div class="sg-fx-acciones">
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar"
                CssClass="sg-fx-btn" OnClientClick="closeWindow(); return false;" />

            <%-- El menú de acciones secundarias. Se abre en el navegador: es
                 mostrar y esconder un panel que ya está en el HTML. --%>
            <div class="sg-fx-mas">
                <a href="#" class="sg-fx-btn is-icono" id="sgMasBtn"
                   title="Más acciones" aria-haspopup="true" aria-expanded="false">
                    <i class="mdi mdi-dots-horizontal"></i>
                </a>

                <div class="sg-fx-menu" id="sgMasMenu" role="menu">
                    <%-- Lleva a la pestaña Comercial, que es donde vive el
                         historial de este proveedor: los lotes que entregó y
                         los servicios que prestó. No es un enlace decorativo
                         ni abre una pantalla que no existe. --%>
                    <a href="#" class="sg-fx-menu-item sg-fx-ir" data-ir="COMERCIAL" role="menuitem">
                        <i class="mdi mdi-history"></i><span>Ver historial</span>
                    </a>

                    <%-- Eliminar sale DESHABILITADO y con el motivo cuando el
                         proveedor tiene trabajo asociado. Un botón que se ve
                         disponible y falla siempre es peor que uno apagado
                         que explica por qué. --%>
                    <asp:Literal ID="litEliminar" runat="server" />
                </div>
            </div>

            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar cambios"
                CssClass="sg-fx-btn is-principal" OnClick="btnGuardar_Click" ValidationGroup="Proveedor" />
        </div>
    </div>

    <%-- ============================================================
         TARJETA PRINCIPAL
         ============================================================ --%>
    <div class="sg-fx-hero">
        <div class="sg-fx-hero-datos">
            <div class="sg-fx-avatar"><asp:Literal ID="litAvatar" runat="server" /></div>

            <div class="sg-fx-hero-txt">
                <div class="sg-fx-hero-nombre"><asp:Literal ID="litHeroNombre" runat="server" /></div>
                <div class="sg-fx-hero-fantasia"><asp:Literal ID="litHeroFantasia" runat="server" /></div>
                <div class="sg-fx-hero-campos"><asp:Literal ID="litHeroCampos" runat="server" /></div>
                <div class="sg-fx-chips"><asp:Literal ID="litRoles" runat="server" /></div>
            </div>
        </div>

        <%-- Las tres columnas de la derecha salen del propio registro: quién
             es el contacto, dónde está y con cuánto trabajo está comprometido.
             Ninguna está escrita a mano. --%>
        <div class="sg-fx-cifras"><asp:Literal ID="litCifras" runat="server" /></div>
    </div>

    <%-- ============================================================
         PESTAÑAS

         Son <a> normales, no botones de servidor: las SEIS se renderizan y el
         navegador muestra una. Cambiar de pestaña es mirar otra parte del
         mismo formulario, no una consulta nueva —y sobre todo, los campos de
         las otras cinco tienen que SEGUIR EN EL DOM para que posteen al
         guardar. Con Visible="false" se perdería lo escrito.
         ============================================================ --%>
    <div class="sg-fx-tabs" role="tablist">
        <a href="#" class="sg-fx-tab is-activa" data-tab="GENERAL" role="tab">
            <i class="mdi mdi-information-outline"></i><span>Información general</span></a>
        <a href="#" class="sg-fx-tab" data-tab="TRIBUTARIA" role="tab">
            <i class="mdi mdi-bank-outline"></i><span>Identificación tributaria</span></a>
        <a href="#" class="sg-fx-tab" data-tab="CONTACTO" role="tab">
            <i class="mdi mdi-card-account-mail-outline"></i><span>Contacto</span></a>
        <a href="#" class="sg-fx-tab" data-tab="COMERCIAL" role="tab">
            <i class="mdi mdi-briefcase-outline"></i><span>Información comercial</span></a>
        <a href="#" class="sg-fx-tab" data-tab="DOCS" role="tab">
            <i class="mdi mdi-file-document-outline"></i><span>Documentación</span></a>
        <a href="#" class="sg-fx-tab" data-tab="ESTADO" role="tab">
            <i class="mdi mdi-cog-outline"></i><span>Configuración y estado</span></a>
    </div>

    <div class="sg-fx-cuerpo">
    <div class="sg-fx-col">

        <%-- ---------------- GENERAL ---------------- --%>
        <div class="sg-fx-panel is-activo" data-panel="GENERAL">

            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num">1</span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Identificación del proveedor</div>
                    </div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-chico">
                        <label>ID</label>
                        <div class="sg-fx-solo-lectura"><asp:Literal ID="lblId" runat="server" /></div>
                    </div>

                    <div class="sigma-modal-field is-chico">
                        <label for="<%=txtRut.ClientID %>"><asp:Literal ID="litRotuloRut" runat="server" Text="RUT" /> <span class="sg-fx-req">*</span></label>
                        <WebControls:TextBox2 ID="txtRut" runat="server" MaxLength="40" UpperCase="true" />
                        <span class="sigma-modal-ayuda">Único para este cliente.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=txtRazonSocial.ClientID %>">Razón social <span class="sg-fx-req">*</span></label>
                        <WebControls:TextBox2 ID="txtRazonSocial" runat="server" MaxLength="400" />
                        <span class="sigma-modal-ayuda">Nombre legal utilizado en documentos tributarios.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=txtNombreFantasia.ClientID %>">Nombre de fantasía</label>
                        <WebControls:TextBox2 ID="txtNombreFantasia" runat="server" MaxLength="400" />
                        <span class="sigma-modal-ayuda">Nombre visible en listas y operaciones.</span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label for="<%=txtGiro.ClientID %>">Giro</label>
                        <WebControls:TextBox2 ID="txtGiro" runat="server" MaxLength="400" />
                        <span class="sigma-modal-ayuda">Actividad principal o giro comercial del proveedor.</span>
                    </div>
                </div>
            </div>

            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num">2</span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Servicios y relación comercial</div>
                        <div class="sg-fx-tarjeta-bajada">Define cómo participa este proveedor en la operación.</div>
                    </div>
                </div>

                <%-- Los dos roles son casillas, no una elección excluyente: un
                     proveedor puede prestar servicio Y vender repuestos, que
                     es justamente el caso de Eléctrica Bío Bío. --%>
                <div class="sg-fx-opciones">
                    <label class="sg-fx-opcion">
                        <asp:CheckBox ID="chkContratista" runat="server" />
                        <span class="sg-fx-opcion-ico"><i class="mdi mdi-account-hard-hat"></i></span>
                        <span class="sg-fx-opcion-txt">
                            <span class="sg-fx-opcion-t">Contratista</span>
                            <span class="sg-fx-opcion-d">Presta servicios y ejecuta trabajos en planta.</span>
                        </span>
                    </label>

                    <label class="sg-fx-opcion">
                        <asp:CheckBox ID="chkProveedorRepuesto" runat="server" />
                        <span class="sg-fx-opcion-ico"><i class="mdi mdi-package-variant-closed"></i></span>
                        <span class="sg-fx-opcion-txt">
                            <span class="sg-fx-opcion-t">Proveedor de repuestos</span>
                            <span class="sg-fx-opcion-d">Suministra materiales o componentes.</span>
                        </span>
                    </label>
                </div>

                <span class="sigma-modal-ayuda">
                    Seleccione al menos una opción. Los roles no son excluyentes.
                </span>
            </div>

            <%-- Las secciones 3 y 4 viven ACÁ, con sus controles reales.

                 Un control de servidor no puede estar en dos paneles: sería
                 dos controles con el mismo nombre. Por eso "Información
                 general" es el formulario COMPLETO —igual que en la maqueta— y
                 las pestañas de Contacto y Comercial son vistas de lo mismo
                 para revisarlo, no una segunda copia editable. --%>
            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num">3</span>
                    <div><div class="sg-fx-tarjeta-titulo">Contacto principal</div></div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label for="<%=txtContacto.ClientID %>">Nombre del contacto</label>
                        <WebControls:TextBox2 ID="txtContacto" runat="server" MaxLength="400" />
                        <span class="sigma-modal-ayuda">Persona de contacto principal.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=txtEmail.ClientID %>">Correo electrónico</label>
                        <WebControls:TextBox2 ID="txtEmail" runat="server" MaxLength="400" />
                        <span class="sigma-modal-ayuda">Correo válido para comunicaciones.</span>
                    </div>

                    <div class="sigma-modal-field is-medio">
                        <label for="<%=txtTelefono.ClientID %>">Teléfono</label>
                        <WebControls:TextBox2 ID="txtTelefono" runat="server" MaxLength="100" />
                        <span class="sigma-modal-ayuda">Incluya código de país o área.</span>
                    </div>

                    <div class="sigma-modal-field is-ancho">
                        <label for="<%=txtDireccion.ClientID %>">Dirección</label>
                        <WebControls:TextBox2 ID="txtDireccion" runat="server" MaxLength="600" />
                        <span class="sigma-modal-ayuda">Dirección comercial o de correspondencia.</span>
                    </div>
                </div>
            </div>

            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num">4</span>
                    <div><div class="sg-fx-tarjeta-titulo">Observaciones</div></div>
                </div>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-ancho">
                        <WebControls:TextArea2 ID="txtObservacion" runat="server" MaxLength="1000" />
                        <span class="sigma-modal-ayuda">Información adicional relevante sobre el proveedor.</span>
                    </div>
                </div>
            </div>
        </div>

        <%-- ---------------- TRIBUTARIA ---------------- --%>
        <div class="sg-fx-panel" data-panel="TRIBUTARIA">
            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num is-tenue"><i class="mdi mdi-bank-outline"></i></span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Identificación tributaria</div>
                        <div class="sg-fx-tarjeta-bajada">Los datos con los que el proveedor emite documentos.</div>
                    </div>
                </div>

                <asp:Literal ID="litTributaria" runat="server" />

                <div class="sigma-modal-note">
                    <i class="mdi mdi-pencil-outline"></i>
                    <div>Se editan en <strong>Información general</strong>. Acá se ven juntos
                        para revisarlos antes de recibir o emitir un documento.</div>
                </div>
            </div>
        </div>

        <%-- ---------------- CONTACTO ---------------- --%>
        <div class="sg-fx-panel" data-panel="CONTACTO">
            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num is-tenue"><i class="mdi mdi-card-account-mail-outline"></i></span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Contacto</div>
                        <div class="sg-fx-tarjeta-bajada">A quién llamar y dónde está.</div>
                    </div>
                </div>

                <asp:Literal ID="litContactoVista" runat="server" />

                <div class="sigma-modal-note">
                    <i class="mdi mdi-pencil-outline"></i>
                    <div>Se editan en <strong>Información general</strong>.</div>
                </div>
            </div>
        </div>

        <%-- ---------------- COMERCIAL ---------------- --%>
        <div class="sg-fx-panel" data-panel="COMERCIAL">
            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num is-tenue"><i class="mdi mdi-briefcase-outline"></i></span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Relación comercial</div>
                        <div class="sg-fx-tarjeta-bajada">Con cuánto trabajo está comprometido este proveedor.</div>
                    </div>
                </div>

                <asp:Literal ID="litComercial" runat="server" />
            </div>
        </div>

        <%-- ---------------- DOCUMENTACIÓN ---------------- --%>
        <div class="sg-fx-panel" data-panel="DOCS">
            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num is-tenue"><i class="mdi mdi-file-document-outline"></i></span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Documentación</div>
                    </div>
                </div>

                <%-- No existe en el modelo: `Proveedor` no guarda documentos y
                     no hay tabla que los guarde. Se dice, sin un botón de
                     subir que no tendría dónde escribir. --%>
                <div class="sg-fx-vacio">
                    <i class="mdi mdi-folder-open-outline"></i>
                    <div>
                        <strong>Sin documentación.</strong>
                        El modelo de datos todavía no guarda documentos del proveedor
                        —contratos, certificados, seguros—: no hay dónde adjuntarlos.
                    </div>
                </div>
            </div>
        </div>

        <%-- ---------------- ESTADO ---------------- --%>
        <div class="sg-fx-panel" data-panel="ESTADO">
            <div class="sg-fx-tarjeta">
                <div class="sg-fx-tarjeta-cab">
                    <span class="sg-fx-num is-tenue"><i class="mdi mdi-cog-outline"></i></span>
                    <div>
                        <div class="sg-fx-tarjeta-titulo">Configuración y estado</div>
                        <div class="sg-fx-tarjeta-bajada">Si el proveedor puede seleccionarse en la operación.</div>
                    </div>
                </div>

                <div class="sg-fx-segmentado">
                    <asp:RadioButton ID="rdbSi" runat="server" GroupName="Habilitado" Text="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" GroupName="Habilitado" Text="Deshabilitado" />
                </div>

                <asp:Literal ID="litAvisoEstado" runat="server" />
            </div>
        </div>

    </div>

    <%-- ============================================================
         LATERAL — se ve en las seis pestañas
         ============================================================ --%>
    <aside class="sg-fx-lateral">
        <asp:Literal ID="litLateral" runat="server" />
    </aside>
    </div>

    <div class="sg-fx-pie">
        <WebControls:PushButton ID="btnCancelar" runat="server" Text="Cancelar"
            CssClass="sg-fx-btn" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardarPie" runat="server" Text="Guardar cambios"
            CssClass="sg-fx-btn is-principal" OnClick="btnGuardar_Click" ValidationGroup="Proveedor" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/gsap/gsap.min.js") %>'></script>

    <script type="text/javascript">
        /* Las pestañas y el menú de acciones, en el navegador.

           Los seis paneles ya están en el HTML: cambiar de pestaña es mostrar
           otro. Y hay una razón de fondo además de la velocidad — los campos
           de las otras cinco tienen que seguir en el DOM para que posteen al
           guardar. Con Visible="false" se perdería lo escrito. */
        (function () {
            'use strict';

            function conectar() {
                var tabs = document.querySelectorAll('.sg-fx-tab');
                var paneles = document.querySelectorAll('.sg-fx-panel');

                for (var i = 0; i < tabs.length; i++) {
                    (function (t) {
                        t.onclick = function (ev) {
                            ev.preventDefault();
                            abrir(t.getAttribute('data-tab'), tabs, paneles);
                            return false;
                        };
                    })(tabs[i]);
                }

                var boton = document.getElementById('sgMasBtn');
                var menu = document.getElementById('sgMasMenu');

                if (boton && menu) {
                    boton.onclick = function (ev) {
                        ev.preventDefault();
                        ev.stopPropagation();

                        var abierto = menu.className.indexOf('is-abierto') !== -1;
                        menu.className = 'sg-fx-menu' + (abierto ? '' : ' is-abierto');
                        boton.setAttribute('aria-expanded', abierto ? 'false' : 'true');
                        return false;
                    };

                    /* Se cierra al hacer clic fuera y con Escape: un menú que
                       solo se cierra con su propio botón tapa la pantalla. */
                    document.addEventListener('click', function () {
                        menu.className = 'sg-fx-menu';
                        boton.setAttribute('aria-expanded', 'false');
                    });

                    document.addEventListener('keydown', function (e) {
                        if (e.keyCode === 27) {
                            menu.className = 'sg-fx-menu';
                            boton.setAttribute('aria-expanded', 'false');
                        }
                    });

                    menu.onclick = function (ev) { ev.stopPropagation(); };
                }

                /* Los enlaces del menú que solo cambian de pestaña. */
                var irs = document.querySelectorAll('.sg-fx-ir');

                for (var k = 0; k < irs.length; k++) {
                    (function (a) {
                        a.onclick = function (ev) {
                            ev.preventDefault();
                            abrir(a.getAttribute('data-ir'), tabs, paneles);

                            if (menu) menu.className = 'sg-fx-menu';
                            return false;
                        };
                    })(irs[k]);
                }
            }

            function abrir(codigo, tabs, paneles) {
                var i;

                for (i = 0; i < tabs.length; i++)
                    tabs[i].className = 'sg-fx-tab' +
                        (tabs[i].getAttribute('data-tab') === codigo ? ' is-activa' : '');

                for (i = 0; i < paneles.length; i++) {
                    var activo = paneles[i].getAttribute('data-panel') === codigo;
                    paneles[i].className = 'sg-fx-panel' + (activo ? ' is-activo' : '');

                    if (activo && window.gsap)
                        gsap.fromTo(paneles[i], { opacity: 0, y: 8 },
                            { opacity: 1, y: 0, duration: .25, ease: 'power2.out',
                              clearProps: 'transform,opacity' });
                }
            }

            if (document.readyState === 'loading')
                document.addEventListener('DOMContentLoaded', conectar);
            else
                conectar();

            /* Guardar sí vuelve al servidor: al volver, el HTML es nuevo y los
               manejadores se fueron con el anterior. */
            if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
                Sys.WebForms.PageRequestManager.getInstance().add_endRequest(conectar);
        })();
    </script>
</asp:Content>
