<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoModelo.aspx.cs" Inherits="View_Activos_Modelos_ActivoModelo" %>
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
        // Muestra los nombres de los archivos elegidos (aún sin subir).
        function modeloArchNombres(input) {
            var d = document.getElementById('modeloArchLista');
            if (!d) return;
            if (input.files && input.files.length) {
                var n = [];
                for (var i = 0; i < input.files.length; i++) n.push(input.files[i].name);
                d.textContent = '▸ ' + n.join('  ·  ');
            } else { d.textContent = ''; }
        }
    </script>
    <style type="text/css">
        .sigma-modelo-archivos { display: grid; gap: 8px; margin-bottom: 10px; }
        .sigma-modelo-arch { display: flex; align-items: center; gap: 10px; padding: 9px 12px; border: 1px solid #e5e7eb; border-radius: 10px; font-size: 13px; color: #334155; }
        .sigma-modelo-arch > i { font-size: 18px; color: #6C5CFF; }
        .sigma-modelo-arch .nom { flex: 1 1 auto; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .sigma-modelo-arch .ver { color: #6C5CFF !important; font-weight: 600; text-decoration: none; }
        .sigma-modelo-arch .quitar { color: #b91c1c !important; font-weight: 600; text-decoration: none; }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

    <h1 class="sigma-modal-title">Modelo de activo</h1>

    <div class="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-shape-outline"></i>Identificación</div>
        <div class="sigma-modal-grid">
            <div class="sigma-modal-field is-mini">
                <label>ID</label>
                <asp:Label ID="lblId" runat="server"></asp:Label>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Tipo de activo(*)</label>
                <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Mod" />
                <span class="sigma-modal-ayuda">La familia de equipos a la que aplica este modelo.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Fabricante</label>
                <WebControls:TextBox2 ID="txtFabricante" runat="server" MaxLength="200" />
                <span class="sigma-modal-ayuda">Quién lo fabrica (WEG, Grundfos…). Opcional.</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Modelo(*)</label>
                <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" />
                <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre"
                    ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Mod" />
                <span class="sigma-modal-ayuda">La designación del fabricante (W22 132S, NB 65-200…).</span>
            </div>
            <div class="sigma-modal-field is-medio">
                <label>Habilitado(*)</label>
                <div class="sigma-modal-opciones">
                    <asp:RadioButton ID="rdbSi" runat="server" Text="SI" GroupName="Habilitado" Checked="true" />
                    <asp:RadioButton ID="rdbNo" runat="server" Text="NO" GroupName="Habilitado" />
                </div>
            </div>
            <div class="sigma-modal-field is-grande">
                <label>Descripción</label>
                <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" />
                <span class="sigma-modal-ayuda">Ficha técnica breve: potencia, caudal, etc. Opcional.</span>
            </div>
        </div>
    </div>

    <%-- ============ DOCUMENTOS Y FOTOS (opcional) ============ --%>
    <asp:Panel ID="pnlArchivos" runat="server" CssClass="sigma-form-seccion">
        <div class="titulo"><i class="mdi mdi-paperclip"></i>Documentos y fotos</div>

        <%-- Archivos ya cargados (edición): ver / quitar. --%>
        <asp:Repeater ID="rptArchivos" runat="server" OnItemCommand="rptArchivos_ItemCommand" OnItemDataBound="rptArchivos_ItemDataBound">
            <HeaderTemplate><div class="sigma-modelo-archivos"></HeaderTemplate>
            <ItemTemplate>
                <div class="sigma-modelo-arch">
                    <i class='mdi <%# (bool)Eval("es_imagen") ? "mdi-image-outline" : "mdi-file-document-outline" %>'></i>
                    <span class="nom"><%# Server.HtmlEncode(Convert.ToString(Eval("arc_nombre"))) %></span>
                    <asp:HyperLink runat="server" Target="_blank" CssClass="ver"
                        NavigateUrl='<%# VerUrl((int)Eval("arc_id")) %>'><i class="mdi mdi-open-in-new"></i> Ver</asp:HyperLink>
                    <asp:LinkButton runat="server" CssClass="quitar" CommandName="quitar" CommandArgument='<%# Eval("arc_id") %>'
                        OnClientClick="return confirm('¿Quitar este archivo del modelo?');"><i class="mdi mdi-close-circle-outline"></i> Quitar</asp:LinkButton>
                </div>
            </ItemTemplate>
            <FooterTemplate></div></FooterTemplate>
        </asp:Repeater>

        <asp:Panel ID="pnlSubir" runat="server">
            <label for="fuModelo" class="sigma-img-btn" style="display:inline-flex;align-items:center;gap:7px;background:#6C5CFF;color:#fff;border-radius:9px;padding:9px 16px;font-size:13px;font-weight:600;cursor:pointer;margin-top:6px;">
                <i class="mdi mdi-upload"></i> Agregar archivos
            </label>
            <asp:FileUpload ID="fuModelo" runat="server" AllowMultiple="true" ClientIDMode="Static"
                accept=".pdf,image/*" onchange="modeloArchNombres(this)" style="display:none;" />
            <span id="modeloArchLista" style="display:block;margin-top:6px;font-size:12px;color:#475569;"></span>
            <span class="sigma-modal-ayuda">Opcional. Catálogo (PDF), foto de la placa característica, manual… puede subir varios a la vez.</span>
        </asp:Panel>
    </asp:Panel>

    <asp:Panel ID="pnlGlobal" runat="server" Visible="false" CssClass="card-box">
        <p><i class="mdi mdi-information-outline"></i> Este es un modelo <strong>global de la plataforma</strong>: se puede usar pero no se edita desde aquí.</p>
    </asp:Panel>

    <wuc:Auditoria runat="server" ID="wucAuditoria" />

    <div class="sigma-modal-actions">
        <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cerrar" CssClass="ButtonCerrar" OnClientClick="closeWindow(); return false;" />
        <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" OnClick="btnGuardar_Click" ValidationGroup="Mod" />
    </div>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
