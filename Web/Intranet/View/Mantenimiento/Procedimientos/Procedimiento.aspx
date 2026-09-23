<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="Procedimiento.aspx.cs" Inherits="View_Mantenimiento_Procedimientos_Procedimiento" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">

    <%-- La ficha habla el mismo idioma visual que los modales -secciones,
         grilla de campos, ayudas- y Default.master no trae esa hoja. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-modal.css?vrs=8") %>' rel="stylesheet" />
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-procedimiento.css?vrs=4") %>' rel="stylesheet" />

    <style type="text/css">
        /* En pantalla completa el marco lo pone el master: la ficha no lleva
           el relleno ni el ancho maximo que usaba dentro del modal. */
        .sg-pr.sigma-modal { padding: 0; max-width: none; }

        /* NO se tocan los overflow de #wrapper, .content-page ni
           .table-responsive para pegar el pie con position: sticky. Se probo y
           rompe el layout del master: el menu lateral y la cabecera dejan de
           quedarse quietos, aparece una segunda barra de desplazamiento y el
           titulo de la pagina queda cortado arriba. El pie va donde va en toda
           ficha de pantalla completa -al final- y lo que se acorta es la
           altura de las dos columnas, que desplazan por dentro. */

        /* El boton principal de esta ficha sale como <input type="button">
           -PushButton con grupo de validacion-, y la regla de la hoja solo
           pintaba los type="submit": quedaba gris al lado de "Volver". */
        .sg-pr-pie .sg-proc-cab-acciones input[type="button"]:not(.ButtonCerrar) {
            background: #6C5CFF;
            color: #fff;
            border-color: #6C5CFF;
        }
        .sg-pr-pie .sg-proc-cab-acciones input[type="button"]:not(.ButtonCerrar):hover { filter: brightness(1.07); }
    </style>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento · Procedimientos</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    <asp:Literal ID="litTitulo" runat="server" Text="Procedimiento" />
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    <span class="sg-pr-sub">
        <asp:Literal ID="litModo" runat="server" Text="Nuevo procedimiento" />
        <span class="sg-proc-id">ID <asp:Label ID="lblId" runat="server" /></span>
        <asp:Literal ID="litEstado" runat="server" />
    </span>
    La receta de un trabajo y sus pasos: se escribe una vez y se reutiliza en cada plan y cada orden que la necesite.
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        /* El aviso de "cambios sin guardar".

           El servidor lo enciende cuando algo cambio por un postback -agregar
           un paso, moverlo, importar-, pero escribir en una caja no es un
           postback: sin esto, alguien escribe la instruccion entera, se va y se
           lleva la impresion de que estaba guardada. */
        function sgProcSucio() {
            var pie = document.querySelector('.sg-pr-pie');
            if (pie) pie.classList.add('es-sucio');
        }
        function sgProcVigilar() {
            document.addEventListener('input', function (ev) {
                if (ev.target.closest && ev.target.closest('.sg-pr-cols, .sg-pr-datos')) sgProcSucio();
            }, true);
        }
        if (document.addEventListener) document.addEventListener('DOMContentLoaded', sgProcVigilar);
        if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(sgProcVigilar);
        }

        /* Volver al listado. Si hay algo sin guardar se pregunta: la pantalla
           guarda TODO junto al final, asi que irse a medio camino no deja nada
           escrito. */
        function sgProcVolver(url) {
            var pie = document.querySelector('.sg-pr-pie');
            if (pie && pie.classList.contains('es-sucio') &&
                !confirm('Hay cambios sin guardar. ¿Salir igual y perderlos?')) return false;
            location.href = url;
            return false;
        }
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal sg-proc-modal sg-pr">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <asp:Panel ID="pnlGlobal" runat="server" Visible="false" CssClass="sg-proc-aviso">
        <i class="mdi mdi-information-outline"></i>
        <span>Este es un procedimiento <strong>global del sistema</strong>: se puede usar pero no se edita desde aquí. Cópielo para adaptarlo a su empresa.</span>
    </asp:Panel>

    <%-- ---------------------------------------------------------------
         RESUMEN DE LA RECETA

         Lo que se consulta seguido -a qué aplica, cuánto dura, si exige
         permiso, si está habilitada- a la vista y en una línea. El
         formulario completo se abre con "Editar datos": mientras se
         escriben los pasos, los datos de la cabecera no se tocan, y
         tenerlos desplegados dejaba los pasos abajo del pliegue.
         --------------------------------------------------------------- --%>
    <div class="sg-pr-resumen">
        <div class="sg-pr-res-txt">
            <div class="sg-pr-res-cod"><asp:Literal ID="litCodigo" runat="server" /></div>
            <div class="sg-pr-chips">
                <span class="sg-pr-chip"><i class="mdi mdi-shape-outline"></i><asp:Literal ID="litChipTipo" runat="server" /></span>
                <span class="sg-pr-chip"><i class="mdi mdi-timer-outline"></i><asp:Literal ID="litChipEstimacion" runat="server" /></span>
                <span class="sg-pr-chip"><i class="mdi mdi-shield-check-outline"></i><asp:Literal ID="litChipPermiso" runat="server" /></span>
                <asp:Literal ID="litChipEstado" runat="server" />
            </div>
        </div>
        <asp:LinkButton ID="lnkEditarDatos" runat="server" CssClass="sg-pr-btn-secundario" OnClick="lnkEditarDatos_Click">
            <i class="mdi mdi-pencil-outline"></i><asp:Literal ID="litEditarDatos" runat="server" Text="Editar datos" />
        </asp:LinkButton>
    </div>

    <%-- ---------------------------------------------------------------
         DATOS DEL PROCEDIMIENTO (plegable)
         --------------------------------------------------------------- --%>
    <asp:Panel ID="pnlDatos" runat="server" CssClass="sg-pr-datos">
        <div class="sg-proc">
            <div class="sg-proc-form">

                <div class="sg-proc-card">
                    <div class="sg-proc-card-cab">
                        <span class="sg-proc-letra">A</span>
                        <div>
                            <div class="sg-proc-card-titulo">Identificación</div>
                            <div class="sg-proc-card-bajada">Cómo se llama la receta y a qué aplica.</div>
                        </div>
                    </div>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-chico">
                            <label>Código(*)</label>
                            <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" />
                            <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Proc" />
                            <span class="sigma-modal-ayuda">P. ej. CAMBIO-RODAMIENTOS. No cambia después.</span>
                        </div>
                        <div class="sigma-modal-field is-mini">
                            <label>Versión(*)</label>
                            <WebControls:TextBox2 ID="txtVersion" runat="server" MaxLength="4" />
                            <span class="sigma-modal-ayuda">Empieza en 1.</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Nombre(*)</label>
                            <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" />
                            <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                                ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Proc" />
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Tipo de activo</label>
                            <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">A qué familia de equipos aplica. Vacío = cualquiera.</span>
                        </div>
                        <div class="sigma-modal-field is-chico">
                            <label>Duración estimada (min)</label>
                            <WebControls:TextBox2 ID="txtDuracion" runat="server" MaxLength="5" />
                            <span class="sigma-modal-ayuda">Cuánto suele tomar. Opcional.</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Habilitado(*)</label>
                            <div class="sigma-modal-opciones">
                                <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                                <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                            </div>
                        </div>
                    </div>
                </div>

                <div class="sg-proc-card">
                    <div class="sg-proc-card-cab">
                        <span class="sg-proc-letra">B</span>
                        <div>
                            <div class="sg-proc-card-titulo">Permiso de trabajo y detalle</div>
                            <div class="sg-proc-card-bajada">Si el trabajo exige un permiso especial y cualquier nota útil.</div>
                        </div>
                    </div>

                    <div class="sigma-modal-grid">
                        <div class="sigma-modal-field is-medio">
                            <label>¿Requiere permiso de trabajo?(*)</label>
                            <div class="sigma-modal-opciones">
                                <asp:RadioButton ID="rdbPermisoSi" runat="server" Text="SI" GroupName="Permiso" AutoPostBack="true" OnCheckedChanged="rdbPermiso_CheckedChanged" />
                                <asp:RadioButton ID="rdbPermisoNo" runat="server" Text="NO" GroupName="Permiso" Checked="true" AutoPostBack="true" OnCheckedChanged="rdbPermiso_CheckedChanged" />
                            </div>
                            <span class="sigma-modal-ayuda">Altura, espacio confinado, trabajo caliente…</span>
                        </div>
                        <div class="sigma-modal-field is-medio">
                            <label>Tipo de permiso</label>
                            <rad:RadComboBox2 ID="cboPermisoTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                            <span class="sigma-modal-ayuda">Obligatorio si el procedimiento exige permiso.</span>
                        </div>
                        <div class="sigma-modal-field is-grande">
                            <label>Descripción</label>
                            <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="4000" />
                        </div>
                    </div>
                </div>

                <wuc:Auditoria runat="server" ID="wucAuditoria" />
            </div>

            <aside class="sg-proc-resumen">
                <h3><i class="mdi mdi-lightbulb-on-outline"></i>Cómo funciona</h3>
                <p>Un procedimiento es una receta reutilizable. Al mejorarla, mejora en todos los planes y órdenes que la usan.</p>
                <ul class="sg-proc-tips">
                    <li><i class="mdi mdi-key-variant"></i><span><strong>Código y versión</strong> son la llave: no se cambian al editar. Para mejorar la receta se crea una <strong>versión nueva</strong> con el mismo código.</span></li>
                    <li><i class="mdi mdi-shield-check-outline"></i><span>Si marca <strong>requiere permiso</strong>, elija el tipo: así el técnico sabe qué pedir antes de empezar.</span></li>
                    <li><i class="mdi mdi-earth"></i><span>Los procedimientos <strong>globales</strong> son del sistema: se usan pero no se editan desde aquí.</span></li>
                </ul>
            </aside>
        </div>
    </asp:Panel>

    <%-- ---------------------------------------------------------------
         LOS PASOS: lista a la izquierda, editor a la derecha
         --------------------------------------------------------------- --%>
    <asp:Panel ID="pnlPasos" runat="server" CssClass="sg-pr-cols">

        <%-- ====== LISTA ====== --%>
        <section class="sg-pr-lista">
            <header class="sg-pr-lista-cab">
                <div>
                    <span class="sg-pr-lista-tit">Pasos · <asp:Literal ID="litPasosN" runat="server" Text="0" /></span>
                    <span class="sg-pr-lista-sub"><asp:Literal ID="litPasosMin" runat="server" /></span>
                </div>
                <asp:LinkButton ID="lnkCargaMasiva" runat="server" CssClass="sg-pr-btn-plano" OnClick="lnkCargaMasiva_Click"
                    ToolTip="Importar los pasos desde una planilla">
                    <i class="mdi mdi-file-upload-outline"></i>Carga masiva
                </asp:LinkButton>
            </header>

            <%-- Aviso de estimación: la suma de los pasos contra lo que dice la
                 cabecera. No es un error -la estimación puede incluir traslado
                 y preparación- pero una diferencia grande casi siempre es un
                 número que quedó viejo. --%>
            <asp:Panel ID="pnlAvisoMinutos" runat="server" Visible="false" CssClass="sg-pr-aviso-min">
                <i class="mdi mdi-alert-outline"></i>
                <span><asp:Literal ID="litAvisoMinutos" runat="server" /></span>
            </asp:Panel>

            <div class="sg-pr-pasos">
                <asp:Repeater ID="rptPasos" runat="server" OnItemCommand="rptPasos_ItemCommand">
                    <ItemTemplate>
                        <div class='<%# "sg-pr-paso" + ((bool)Eval("elegido") ? " es-elegido" : "") + ((bool)Eval("habilitado") ? "" : " es-baja") %>'>
                            <asp:LinkButton ID="lnkPaso" runat="server" CssClass="sg-pr-paso-cuerpo" CommandName="sel" CommandArgument='<%# Eval("indice") %>'>
                                <span class="sg-pr-paso-num"><%# Eval("numero") %></span>
                                <span class="sg-pr-paso-txt">
                                    <span class="sg-pr-paso-nom"><%# Server.HtmlEncode(Convert.ToString(Eval("nombre"))) %></span>
                                    <span class="sg-pr-paso-meta"><%# Eval("meta") %></span>
                                </span>
                            </asp:LinkButton>
                            <span class="sg-pr-paso-acc">
                                <asp:LinkButton ID="lnkSubir" runat="server" CssClass="sg-pr-icono" CommandName="sube" CommandArgument='<%# Eval("indice") %>'
                                    ToolTip="Subir" Enabled='<%# !(bool)Eval("primero") %>'><i class="mdi mdi-chevron-up"></i></asp:LinkButton>
                                <asp:LinkButton ID="lnkBajar" runat="server" CssClass="sg-pr-icono" CommandName="baja" CommandArgument='<%# Eval("indice") %>'
                                    ToolTip="Bajar" Enabled='<%# !(bool)Eval("ultimo") %>'><i class="mdi mdi-chevron-down"></i></asp:LinkButton>
                                <asp:LinkButton ID="lnkQuitar" runat="server" CssClass="sg-pr-icono es-quita" CommandName="quita" CommandArgument='<%# Eval("indice") %>'
                                    ToolTip="Quitar el paso"><i class="mdi mdi-trash-can-outline"></i></asp:LinkButton>
                            </span>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>

                <asp:Panel ID="pnlSinPasos" runat="server" Visible="false" CssClass="sg-pr-vacio">
                    <i class="mdi mdi-format-list-numbered"></i>
                    <p>La receta todavía no tiene pasos.</p>
                    <span>Agregue el primero, o impórtelos desde una planilla.</span>
                </asp:Panel>
            </div>

            <footer class="sg-pr-lista-pie">
                <asp:LinkButton ID="lnkAgregarPaso" runat="server" CssClass="sg-pr-btn-agregar" OnClick="lnkAgregarPaso_Click">
                    <i class="mdi mdi-plus"></i>Agregar paso
                </asp:LinkButton>
            </footer>
        </section>

        <%-- ====== EDITOR DEL PASO ELEGIDO ====== --%>
        <section class="sg-pr-editor">
            <asp:Panel ID="pnlSinSeleccion" runat="server" Visible="false" CssClass="sg-pr-vacio es-editor">
                <i class="mdi mdi-gesture-tap-button"></i>
                <p>Elija un paso de la lista</p>
                <span>Se edita acá mismo, sin abrir otra ventana.</span>
            </asp:Panel>

            <asp:Panel ID="pnlEditor" runat="server" Visible="false">
                <header class="sg-pr-editor-cab">
                    <span class="sg-pr-paso-num es-grande"><asp:Literal ID="litPasoNum" runat="server" /></span>
                    <div>
                        <div class="sg-pr-editor-tit">Paso <asp:Literal ID="litPasoDe" runat="server" /></div>
                        <div class="sg-pr-editor-sub">Lo que el técnico tiene que hacer, y qué se le exige al cerrarlo.</div>
                    </div>
                </header>

                <div class="sigma-modal-grid">
                    <div class="sigma-modal-field is-medio">
                        <label>Nombre del paso(*)</label>
                        <WebControls:TextBox2 ID="txtPasoNombre" runat="server" MaxLength="200" />
                        <span class="sigma-modal-ayuda">Corto y en infinitivo: "Purgar el circuito".</span>
                    </div>
                    <div class="sigma-modal-field is-chico">
                        <label>Duración (min)</label>
                        <WebControls:TextBox2 ID="txtPasoDuracion" runat="server" MaxLength="5" />
                        <span class="sigma-modal-ayuda">Opcional.</span>
                    </div>
                    <div class="sigma-modal-field is-grande">
                        <label>Instrucciones</label>
                        <WebControls:TextArea2 ID="txtPasoInstruccion" runat="server" MaxLength="4000" />
                        <span class="sigma-modal-ayuda">El detalle que el técnico lee en su teléfono mientras lo ejecuta.</span>
                    </div>
                </div>

                <div class="sg-pr-toggles">
                    <label class="sg-pr-toggle">
                        <asp:CheckBox ID="chkPuntoControl" runat="server" />
                        <span class="sg-pr-toggle-txt">
                            <strong>Punto de control</strong>
                            <em>No se avanza al paso siguiente hasta resolverlo.</em>
                        </span>
                    </label>
                    <label class="sg-pr-toggle">
                        <asp:CheckBox ID="chkEvidencia" runat="server" />
                        <span class="sg-pr-toggle-txt">
                            <strong>Evidencia obligatoria</strong>
                            <em>Al cerrar el paso hay que adjuntar respaldo.</em>
                        </span>
                    </label>
                    <label class="sg-pr-toggle">
                        <asp:CheckBox ID="chkMedicion" runat="server" AutoPostBack="true" OnCheckedChanged="chkMedicion_CheckedChanged" />
                        <span class="sg-pr-toggle-txt">
                            <strong>Requiere medición</strong>
                            <em>Pide un valor que queda en la serie histórica del activo.</em>
                        </span>
                    </label>
                    <asp:Panel ID="pnlVariable" runat="server" CssClass="sg-pr-variable">
                        <label>Variable a medir(*)</label>
                        <rad:RadComboBox2 ID="cboVariable" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    </asp:Panel>
                    <label class="sg-pr-toggle">
                        <asp:CheckBox ID="chkPasoHabilitado" runat="server" Checked="true" />
                        <span class="sg-pr-toggle-txt">
                            <strong>Habilitado</strong>
                            <em>Un paso deshabilitado queda en la receta pero no se ejecuta.</em>
                        </span>
                    </label>
                </div>
            </asp:Panel>
        </section>
    </asp:Panel>

    <%-- ---------------------------------------------------------------
         CARGA MASIVA DE PASOS (asistente, en esta misma pantalla)

         Importar NO escribe en la base: deja los pasos en la lista de
         arriba para revisarlos y guardarlos con el resto. Asi una planilla
         mal armada no deja media receta cargada.
         --------------------------------------------------------------- --%>
    <asp:Panel ID="pnlCarga" runat="server" Visible="false" CssClass="sg-pr-carga">

        <header class="sg-pr-carga-cab">
            <div>
                <span class="sg-proc-eyebrow">Carga masiva</span>
                <h2 class="sg-pr-carga-tit">Importar pasos desde una planilla</h2>
            </div>
            <asp:LinkButton ID="lnkCargaCerrar" runat="server" CssClass="sg-pr-icono" OnClick="lnkCargaCerrar_Click" ToolTip="Volver a los pasos">
                <i class="mdi mdi-close"></i>
            </asp:LinkButton>
        </header>

        <ol class="sg-pr-stepper">
            <li runat="server" id="liPaso1"><span>1</span>Archivo</li>
            <li runat="server" id="liPaso2"><span>2</span>Revisar</li>
            <li runat="server" id="liPaso3"><span>3</span>Importar</li>
        </ol>

        <%-- ---- 1. el archivo ---- --%>
        <asp:Panel ID="pnlCarga1" runat="server" CssClass="sg-pr-carga-cuerpo">
            <p class="sg-pr-carga-ayuda">
                Una hoja llamada <strong>PASOS</strong> con una fila por paso, en el orden en que se ejecutan:
                <strong>NOMBRE</strong>, <strong>INSTRUCCION</strong>, <strong>MINUTOS</strong>,
                <strong>PUNTO CONTROL</strong>, <strong>EVIDENCIA</strong>, <strong>MEDICION</strong> y
                <strong>VARIABLE</strong>. La plantilla trae la lista de variables tal como hay que escribirlas.
            </p>

            <div class="sigma-modal-grid">
                <div class="sigma-modal-field is-medio">
                    <label>Archivo (.xlsx)</label>
                    <asp:FileUpload ID="fldArchivo" runat="server" CssClass="sg-pr-file" />
                </div>
                <div class="sigma-modal-field is-medio">
                    <label>Qué hacer con los pasos que ya están</label>
                    <div class="sigma-modal-opciones sg-pr-modo">
                        <asp:RadioButton ID="rdbModoAgregar" runat="server" GroupName="Modo" Checked="true" Text="Agregar al final" />
                        <asp:RadioButton ID="rdbModoReemplazar" runat="server" GroupName="Modo" Text="Reemplazar todos" />
                    </div>
                    <span class="sigma-modal-ayuda">"Reemplazar" quita los pasos actuales de la lista; nada se escribe hasta guardar.</span>
                </div>
            </div>

            <div class="sg-pr-carga-pie">
                <WebControls:PushButton ID="btnPlantilla" runat="server" Text="Descargar plantilla" CssClass="ButtonCerrar" OnClick="btnPlantilla_Click" />
                <WebControls:PushButton ID="btnRevisar" runat="server" Text="Revisar archivo" OnClick="btnRevisar_Click" />
            </div>
        </asp:Panel>

        <%-- ---- 2. revisar ---- --%>
        <asp:Panel ID="pnlCarga2" runat="server" Visible="false" CssClass="sg-pr-carga-cuerpo">
            <div class="sg-pr-carga-conteo">
                <span class="sg-pr-conteo es-ok"><asp:Literal ID="litCargaOk" runat="server" /> listos</span>
                <span class="sg-pr-conteo es-mal"><asp:Literal ID="litCargaMal" runat="server" /> con problema</span>
                <span class="sg-pr-conteo"><asp:Literal ID="litCargaArchivo" runat="server" /></span>
            </div>

            <div class="sg-pr-tabla">
                <div class="sg-pr-tabla-cab">
                    <span class="c-fila">Fila</span>
                    <span class="c-nom">Paso</span>
                    <span class="c-min">Min</span>
                    <span class="c-mar">Marcas</span>
                    <span class="c-est">Estado</span>
                </div>
                <asp:Repeater ID="rptCarga" runat="server">
                    <ItemTemplate>
                        <div class='<%# "sg-pr-tabla-fila" + ((bool)Eval("ok") ? "" : " es-mal") %>'>
                            <span class="c-fila"><%# Eval("fila") %></span>
                            <span class="c-nom"><%# Server.HtmlEncode(Convert.ToString(Eval("nombre"))) %></span>
                            <span class="c-min"><%# Eval("minutos") %></span>
                            <span class="c-mar"><%# Eval("marcas") %></span>
                            <span class="c-est">
                                <%# (bool)Eval("ok")
                                    ? "<span class=\"sg-pr-ok\"><i class=\"mdi mdi-check\"></i>Listo</span>"
                                    : "<span class=\"sg-pr-mal\"><i class=\"mdi mdi-alert-circle-outline\"></i>" + Server.HtmlEncode(Convert.ToString(Eval("motivo"))) + "</span>" %>
                            </span>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>
            </div>

            <div class="sg-pr-carga-pie">
                <WebControls:PushButton ID="btnCargaCancelar" runat="server" Text="Cancelar" CssClass="ButtonCerrar" OnClick="lnkCargaCerrar_Click" />
                <WebControls:PushButton ID="btnCargaErrores" runat="server" Text="Descargar errores" CssClass="ButtonCerrar" OnClick="btnCargaErrores_Click" />
                <WebControls:PushButton ID="btnImportar" runat="server" Text="Importar pasos" OnClick="btnImportar_Click" />
            </div>
        </asp:Panel>
    </asp:Panel>

    <%-- ---------------------------------------------------------------
         PIE: el aviso de cambios y el guardado de TODO junto
         --------------------------------------------------------------- --%>
    <asp:Panel ID="pnlPie" runat="server" CssClass="sg-pr-pie sg-proc-footer">
        <span class="sg-pr-sucio"><i class="mdi mdi-circle-medium"></i>Cambios sin guardar</span>
        <div class="sg-proc-cab-acciones">
            <%-- El OnClientClick lo arma el codigo: una etiqueta de servidor no
                 admite <%= %> adentro, y la URL tiene que pasar por ResolveUrl
                 porque la aplicacion no cuelga de la raiz del sitio. --%>
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Volver al listado" CssClass="ButtonCerrar" />
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar procedimiento y pasos" OnClick="btnGuardar_Click" ValidationGroup="Proc" />
        </div>
    </asp:Panel>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
