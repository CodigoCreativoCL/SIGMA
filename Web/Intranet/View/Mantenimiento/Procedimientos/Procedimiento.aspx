<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Procedimiento.aspx.cs" Inherits="View_Mantenimiento_Procedimientos_Procedimiento" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">

    <%-- Esta hoja es de esta ficha y de ninguna otra: se enlaza SOLO acá, no
         en el Master, para no descargarla dos veces. Mismo lenguaje visual que
         la ficha de programación. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-procedimiento.css?vrs=1") %>' rel="stylesheet" />

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
<div class="sigma-modal sg-proc-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <%-- ---------------------------------------------------------------
         ENCABEZADO
         --------------------------------------------------------------- --%>
    <div class="sg-proc-cab">
        <div>
            <span class="sg-proc-eyebrow"><asp:Literal ID="litModo" runat="server" Text="Nuevo procedimiento" /></span>
            <h1 class="sg-proc-titulo">
                <asp:Literal ID="litTitulo" runat="server" Text="Procedimiento" />
                <span class="sg-proc-id">ID <asp:Label ID="lblId" runat="server" /></span>
                <asp:Literal ID="litEstado" runat="server" />
            </h1>
            <p class="sg-proc-bajada">
                La receta de un trabajo: se escribe una vez y se reutiliza en cada plan y cada orden que la necesite.
            </p>
        </div>
        <div class="sg-proc-cab-acciones">
            <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
            <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar procedimiento" OnClick="btnGuardar_Click" ValidationGroup="Proc" />
        </div>
    </div>

    <asp:Panel ID="pnlGlobal" runat="server" Visible="false" CssClass="sg-proc-aviso">
        <i class="mdi mdi-information-outline"></i>
        <span>Este es un procedimiento <strong>global del sistema</strong>: se puede usar pero no se edita desde aquí. Cópielo para adaptarlo a su empresa.</span>
    </asp:Panel>

    <%-- ---------------------------------------------------------------
         CUERPO: formulario a la izquierda, resumen a la derecha
         --------------------------------------------------------------- --%>
    <div class="sg-proc">
        <div class="sg-proc-form">

            <%-- ====== TARJETA A — IDENTIFICACION ====== --%>
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

            <%-- ====== TARJETA B — PERMISO DE TRABAJO ====== --%>
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

        <%-- ====== RESUMEN LATERAL ====== --%>
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

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
