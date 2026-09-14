<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ChecklistPlantilla.aspx.cs" Inherits="View_Mantenimiento_Checklist_ChecklistPlantilla" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
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

        // ===== Editor de campos del checklist (secciones + campos) =====
        // Opciones armadas en el servidor (tipos de campo y unidades).
        var CL_TIPO_OPTIONS = '<%= BuildTipoOptions(0) %>';
        var CL_UNIT_OPTIONS = '<option value="">— unidad —</option><%= BuildUnidadOptions(0) %>';
        var CL_SEQ = 0;

        // ¿el tipo es numérico? (Entero=3, Decimal=4) → muestra unidad y rangos.
        function clEsNumerico(v) { return v === '3' || v === '4'; }

        function clAgregarSeccion(sid, nombre) {
            var cont = document.getElementById('clSecciones');
            if (!cont) return;
            if (!sid) { CL_SEQ++; sid = 'n' + CL_SEQ; }
            var sec = document.createElement('div');
            sec.className = 'cl-sec';
            sec.setAttribute('data-sid', sid);
            sec.innerHTML =
                '<div class="cl-sec-head">' +
                    '<input type="hidden" name="sec_id" value="' + sid + '" />' +
                    '<input type="text" name="sec_nombre" class="cl-sec-nombre" placeholder="Nombre de la sección (ej. Aire comprimido Kaeser)" value="' + (nombre ? clEsc(nombre) : '') + '" />' +
                    '<a href="javascript:void(0)" class="cl-x" onclick="this.closest(\'.cl-sec\').remove()">✕ sección</a>' +
                '</div>' +
                '<div class="cl-items"></div>' +
                '<a href="javascript:void(0)" class="cl-add-item" onclick="clAgregarCampo(this.closest(\'.cl-sec\'))">+ Agregar campo</a>';
            cont.appendChild(sec);
            return sec;
        }

        function clAgregarCampo(sec, v) {
            if (!sec) return;
            var sid = sec.getAttribute('data-sid');
            var cont = sec.querySelector('.cl-items');
            v = v || {};
            var row = document.createElement('div');
            row.className = 'cl-item';
            row.innerHTML =
                '<input type="hidden" name="itm_sec" value="' + sid + '" />' +
                '<input type="text" name="itm_nombre" class="cl-itm-nombre" placeholder="Campo (ej. Presión de trabajo)" value="' + (v.nombre ? clEsc(v.nombre) : '') + '" />' +
                '<select name="itm_tipo" class="cl-itm-tipo" onchange="clTipoChange(this)">' + CL_TIPO_OPTIONS + '</select>' +
                '<select name="itm_unidad" class="cl-itm-unidad">' + CL_UNIT_OPTIONS + '</select>' +
                '<select name="itm_oblig" class="cl-itm-oblig"><option value="1">Obligatorio</option><option value="0">Opcional</option></select>' +
                '<a href="javascript:void(0)" class="cl-x" onclick="this.closest(\'.cl-item\').remove()">✕</a>';
            cont.appendChild(row);
            if (v.tipo) row.querySelector('select[name="itm_tipo"]').value = v.tipo;
            if (v.unidad) row.querySelector('select[name="itm_unidad"]').value = v.unidad;
            if (v.oblig === '0') row.querySelector('select[name="itm_oblig"]').value = '0';
            clTipoChange(row.querySelector('select[name="itm_tipo"]'));
            return row;
        }

        // Muestra u oculta la unidad según el tipo (solo aplica a los numéricos).
        function clTipoChange(sel) {
            var row = sel.closest('.cl-item');
            var num = clEsNumerico(sel.value);
            var uni = row.querySelector('.cl-itm-unidad');
            if (uni) uni.style.display = num ? '' : 'none';
        }

        function clEsc(s) { return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;'); }

        // Inicializa los selects/tipos de lo que vino renderizado del servidor.
        function clInit() {
            var rows = document.querySelectorAll('#clSecciones .cl-item');
            for (var i = 0; i < rows.length; i++) {
                var t = rows[i].querySelector('select[name="itm_tipo"]');
                if (t) clTipoChange(t);
            }
        }
        if (document.addEventListener) document.addEventListener('DOMContentLoaded', clInit);
        if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(clInit);
    </script>
    <style type="text/css">
        #clSecciones { display: flex; flex-direction: column; gap: 12px; }
        .cl-sec { border: 1px solid #e5e7eb; border-radius: 10px; padding: 10px 12px; background: #fafbfc; }
        .cl-sec-head { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
        .cl-sec-nombre { flex: 1; padding: 8px 11px; border: 1px solid #ddd6fe; border-radius: 9px; font-size: 13px; font-weight: 600; background: #fff; }
        .cl-items { display: flex; flex-direction: column; gap: 6px; }
        .cl-item { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
        .cl-item input[type="text"], .cl-item select { padding: 8px 9px; border: 1px solid #e5e7eb; border-radius: 9px; font-size: 12.5px; background: #fff; }
        .cl-itm-nombre { flex: 1 1 220px; }
        .cl-itm-tipo { width: 120px; }
        .cl-itm-unidad { width: 130px; }
        .cl-itm-rango { width: 64px; }
        .cl-itm-oblig { width: 120px; }
        .cl-add-item { display: inline-block; margin-top: 8px; color: #6C5CFF; font-weight: 600; font-size: 12.5px; text-decoration: none; }
        .cl-x { color: #b91c1c; font-weight: 700; text-decoration: none; padding: 0 4px; font-size: 12.5px; white-space: nowrap; }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Pauta de inspección (plantilla de checklist)</h1>

    <%-- ============ IDENTIFICACIÓN ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-clipboard-check-outline"></i>Identificación</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-chico">
                <label>Código(*)</label>
                <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" UpperCase="true" />
                <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Plantilla" />
                <span class="sigma-modal-ayuda">P. ej. RONDA-BLOWERS. Único por cliente; no cambia después.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Nombre(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Plantilla" />
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="4000" />
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

    <%-- ============ ALCANCE ============ --%>
    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-target"></i>Alcance</div>

        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-medio">
                <label>Planta</label>
                <rad:RadComboBox2 ID="cboPlanta" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">A qué planta aplica. Vacío = todas.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Tipo de asignación</label>
                <rad:RadComboBox2 ID="cboAsignacion" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">A quién se asigna al ejecutarla.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Tipo de activo</label>
                <rad:RadComboBox2 ID="cboActivoTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <span class="sigma-modal-ayuda">A qué familia de equipos aplica. Vacío = cualquiera.</span>
            </div>
        </div>
    </div>

    <%-- ============ CAMPOS DEL CHECKLIST (secciones + campos) ============ --%>
    <asp:Panel ID="pnlCampos" runat="server" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-format-list-checks"></i>Campos del checklist</div>
        <div id="clSecciones"><asp:Literal ID="litEstructura" runat="server" /></div>
        <a href="javascript:void(0)" onclick="clAgregarSeccion()" class="sigma-img-btn"
           style="display:inline-flex;align-items:center;gap:7px;margin-top:8px;">
            <i class="mdi mdi-plus"></i> Agregar sección
        </a>
        <span class="sigma-modal-ayuda">Agrupa por área (Silos, Blowers, Aire comprimido…) y dentro agrega los campos a chequear (nombre, tipo y unidad). El valor de cada campo se registra al ejecutar el checklist, no aquí.</span>
        <asp:Panel ID="pnlCamposAviso" runat="server" Visible="false" CssClass="sigma-modal-ayuda" style="margin-top:8px;">
            Guarde primero la pauta (código y nombre) y vuelva a abrirla para agregar sus campos.
        </asp:Panel>
    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Plantilla" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
