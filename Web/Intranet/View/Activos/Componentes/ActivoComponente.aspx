<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ActivoComponente.aspx.cs" Inherits="View_Activos_Componentes_ActivoComponente" %>

<%-- LA FICHA DEL COMPONENTE (HU-036), CON LA PIEL DEL ASISTENTE

     Rediseño 04-10-2026: el mismo asistente de la ficha del activo
     (sigma-asistente.css/js): pasos a la izquierda con su ayuda, combos que
     crean lo que no existe, validacion que dice que falta y una sola barra al
     pie. Sirve para crear y para editar, desde el centro y desde «Crear». --%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- El modulo de activos no muestra el velo de carga: se ve pegado. --%>
    <script type="text/javascript">window.SIGMA_SIN_VELO = true;</script>
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-asistente.css") %>' rel="stylesheet" />
    <link href='<%=Asset("~/Css/LookAndFeel/sigma-combo.css") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-combo.js") %>'></script>
    <script type="text/javascript">var AF_PASOS = 3;</script>
    <script type="text/javascript" src='<%=Asset("~/Js/sigma-asistente.js") %>'></script>
    <style type="text/css">
        .ac-historial { width: 100%; border-collapse: collapse; font-size: 13px; }
        .ac-historial th { padding: 8px 10px; text-align: left; font-size: 11.5px; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; color: #68738A; border-bottom: 1px solid #E2E7F0; }
        .ac-historial td { padding: 9px 10px; border-bottom: 1px solid #EEF1F6; color: #17223B; vertical-align: top; }
        .ac-motivo[hidden] { display: none; }
    </style>
    <script type="text/javascript">
        /* Guardar: el velo aparece solo si la validacion paso; si no, se dice
           que falta y se lleva al campo. No retorna valor (el PushButton no
           reenvia si el OnClientClick retorna). */
        function sigmaGuardando() {
            setTimeout(function () {
                if (typeof Page_IsValid !== 'undefined' && Page_IsValid === false) { afMostrarFaltas(true); return; }
                var ov = document.getElementById('sigmaGuardandoOv');
                if (ov) ov.style.display = 'flex';
            }, 0);
        }
        function acFotoVer(input) {
            var ico = document.getElementById('acFotoIco'), nom = document.getElementById('acFotoNom'), caja = document.querySelector('.af-foto');
            if (input.files && input.files[0] && window.FileReader) {
                var r = new FileReader();
                r.onload = function (e) {
                    var prev = document.getElementById('acFotoPrev');
                    prev.src = e.target.result; prev.style.display = 'block';
                    if (caja) caja.classList.add('con-prev');
                };
                r.readAsDataURL(input.files[0]);
                nom.textContent = input.files[0].name;
            } else {
                var p = document.getElementById('acFotoPrev'); p.src = ''; p.style.display = 'none';
                if (caja) caja.classList.remove('con-prev');
                nom.textContent = '';
            }
        }
        /* Cambiar el estado pide decir por que: el campo aparece al cambiarlo. */
        function acEstadoCambio() {
            var m = document.getElementById('acMotivo'); if (!m) return;
            var c = window.$find ? $find('<%=cboEstado.ClientID %>') : null;
            var orig = m.getAttribute('data-original');
            m.hidden = !(c && orig && c.get_value() !== orig);
        }
        function acIniciar() {
            if (!document.querySelector('.af-seccion')) return;
            fpIr(fpActual());
            afSoltar(document.querySelector('.af-foto'), 'fuImagenComp', acFotoVer);
            acEstadoCambio();
        }
        if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', acIniciar); else setTimeout(acIniciar, 0);
        window.addEventListener('load', function () {
            acEstadoCambio();
            if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(acIniciar);
        });
        var AF_OPC = { tipos: [], lados: [], vars: [], meds: [] };
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
<div class="sigma-modal">
    <h1 class="sigma-modal-title">Componente</h1>
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

<asp:Panel ID="pnlForm" runat="server" CssClass="af af-modal">
    <asp:HiddenField ID="hdnPaso" runat="server" Value="1" />

    <aside class="af-rail">
        <nav class="af-pasos" aria-label="Pasos de la ficha del componente">
            <button type="button" class="af-paso" data-ir="1" onclick="fpIr(1)"><span class="af-n"><span>1</span><i class="mdi mdi-check"></i></span><span><b>Qué es</b><small>Nombre y de qué activo es</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="2" onclick="fpIr(2)"><span class="af-n"><span>2</span><i class="mdi mdi-check"></i></span><span><b>Estado</b><small>Cómo está y desde cuándo</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="3" onclick="fpIr(3)"><span class="af-n"><span>3</span><i class="mdi mdi-check"></i></span><span><b>Placa y foto</b><small>Serie, marca y una foto</small></span></button>
        </nav>
        <div class="af-tip" data-paso="1"><i class="mdi mdi-information-variant"></i><div><b>Un componente es una parte de un activo</b> que quieres seguir por separado: el motor, un rodamiento, una válvula. No existe fuera de él.</div></div>
        <div class="af-tip" data-paso="2"><i class="mdi mdi-information-variant"></i><div><b>Si cambias el estado, di por qué.</b> Queda en su historia con fecha y responsable: así se sabe cuánto duró cada pieza.</div></div>
        <div class="af-tip" data-paso="3"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Con la serie, la marca y el modelo se pide el repuesto sin abrir la máquina. La foto evita confundir dos piezas parecidas.</div></div>
        <asp:Panel ID="pnlSobre" runat="server" Visible="false" CssClass="af-sobre">
            <h4>Sobre esta ficha</h4>
            <asp:Literal ID="litSobre" runat="server" />
        </asp:Panel>
    </aside>

    <div class="af-cuerpo">
        <div class="af-faltan" id="afFaltan" role="alert" aria-live="assertive">
            <i class="mdi mdi-alert-circle-outline"></i>
            <div><b id="afFaltanTit">Faltan datos para poder guardar</b><span>Toca cada uno para ir a completarlo.</span>
                <div class="af-faltan-lista" id="afFaltanLista"></div></div>
        </div>

        <%-- ============ PASO 1 · QUÉ ES ============ --%>
        <section class="af-seccion" data-paso="1">
            <header class="af-cab"><i class="mdi mdi-puzzle-outline"></i><div><h3>Qué es</h3><p>El nombre de la pieza y el activo del que es parte.</p></div></header>
            <span class="af-oculto"><asp:Label ID="lblId" runat="server"></asp:Label></span>
            <div class="af-grid">
                <div class="sigma-modal-field af-ancho">
                    <label>Es parte del activo <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboActivo" runat="server" OnLoad="LoadControls" AutoPostBack="true"
                        OnSelectedIndexChanged="cboActivo_SelectedIndexChanged" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">Puede ser un activo o un subactivo (el compresor de una cámara también tiene sus componentes). No se cambia después.</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige el activo o subactivo del que es parte.</span>
                    <asp:CustomValidator ID="cvActivo" runat="server" ControlToValidate="cboActivo" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Nombre <span class="req">*</span></label>
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="200" placeholder="Ej.: Burlete de la puerta" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Escribe cómo le dicen a esta pieza.</span>
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Código</label>
                    <div class="sg-codigo">
                        <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="50" ReadOnly="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Si lo dejas vacío, se numera solo.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Qué es <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                        AllowCustomText="true" EmptyMessage="Elige o escribe uno nuevo" />
                    <span class="sigma-modal-ayuda">Ej.: Motor, Sello, Sensor. ¿No está? Escríbelo y se crea al guardar.</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige o escribe qué es esta pieza.</span>
                    <asp:CustomValidator ID="cvTipo" runat="server" ControlToValidate="cboTipo" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequeridoLibre" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Dónde va</label>
                    <rad:RadComboBox2 ID="cboPosicion" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%"
                        AllowCustomText="true" EmptyMessage="Elige o escribe uno nuevo" />
                    <span class="sigma-modal-ayuda">Ej.: Delantero, Lado motor. ¿No está? Escríbelo y se crea.</span>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Va dentro de otra parte</label>
                    <rad:RadComboBox2 ID="cboPadre" runat="server" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">Solo si va dentro de otro componente del mismo activo, como el rodamiento DEL motor.</span>
                </div>
            </div>
        </section>

        <%-- ============ PASO 2 · ESTADO ============ --%>
        <section class="af-seccion" data-paso="2">
            <header class="af-cab"><i class="mdi mdi-heart-pulse"></i><div><h3>Estado</h3><p>Cómo está la pieza hoy y desde cuándo está puesta.</p></div></header>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Estado <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboEstado" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" OnClientSelectedIndexChanged="acEstadoCambio" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige cómo está la pieza hoy.</span>
                    <asp:CustomValidator ID="cvEstado" runat="server" ControlToValidate="cboEstado" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <div class="sigma-modal-field">
                    <label>Criticidad <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboCriticidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">¿Qué tan grave es si falla?</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige qué tan grave es si falla.</span>
                    <asp:CustomValidator ID="cvCriticidad" runat="server" ControlToValidate="cboCriticidad" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Activo" />
                </div>
                <asp:Panel ID="pnlMotivoEstado" runat="server" Visible="false" CssClass="sigma-modal-field af-ancho">
                    <div class="ac-motivo" id="acMotivo" hidden data-original='<%= EstadoOriginal %>'>
                        <label>¿Por qué cambia el estado? <span class="req">*</span></label>
                        <WebControls:TextArea2 ID="txtMotivoEstado" runat="server" MaxLength="500" placeholder="Ej.: se gastó y deja escapar el frío" />
                        <span class="sigma-modal-ayuda">Queda en su historia con la fecha y quién lo cambió.</span>
                    </div>
                </asp:Panel>
                <div class="sigma-modal-field">
                    <label>Se instaló el</label>
                    <div class="sigma-modal-fecha"><WebControls:Calendar ID="calInstalacion" runat="server" /></div>
                    <span class="sigma-modal-ayuda">Sirve para saber cuánto dura cada pieza.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>¿Está en uso? <span class="req">*</span></label>
                    <div class="af-pills">
                        <asp:RadioButton ID="rdbSi" runat="server" Text="Sí" GroupName="Habilitado" Checked="true" />
                        <asp:RadioButton ID="rdbNo" runat="server" Text="No" GroupName="Habilitado" />
                    </div>
                    <span class="sigma-modal-ayuda">«No» la deja como retirada, sin borrar su historia.</span>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Descripción u observación</label>
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="500" placeholder="Ej.: sella la puerta; revisar cada 6 meses" />
                </div>
            </div>

            <asp:Panel ID="pnlHistorialEstado" runat="server" Visible="false">
                <p class="af-sub">Cambios de estado<small>Lo que le ha pasado a esta pieza.</small></p>
                <table class="ac-historial">
                    <thead><tr><th>Fecha</th><th>De</th><th>A</th><th>Por qué</th><th>Quién</th></tr></thead>
                    <tbody>
                        <asp:Repeater ID="rptHistorialEstado" runat="server">
                            <ItemTemplate>
                                <tr>
                                    <td><%# Eval("ceh_fecha_creacion", "{0:dd MMM yyyy HH:mm}") %></td>
                                    <td><%# Server.HtmlEncode(Convert.ToString(Eval("estado_anterior"))) %></td>
                                    <td><%# Server.HtmlEncode(Convert.ToString(Eval("estado_nuevo"))) %></td>
                                    <td><%# Server.HtmlEncode(Convert.ToString(Eval("ceh_motivo"))) %></td>
                                    <td><%# Server.HtmlEncode(Convert.ToString(Eval("responsable"))) %></td>
                                </tr>
                            </ItemTemplate>
                        </asp:Repeater>
                    </tbody>
                </table>
                <asp:Label ID="lblSinHistorial" runat="server" CssClass="sigma-modal-ayuda" Text="Todavía no cambia de estado." Visible="false" />
            </asp:Panel>
        </section>

        <%-- ============ PASO 3 · PLACA Y FOTO ============ --%>
        <section class="af-seccion" data-paso="3">
            <header class="af-cab"><i class="mdi mdi-tag-text-outline"></i><div><h3>Placa y foto</h3><p>Lo que dice la placa de la pieza y una foto para reconocerla.</p></div></header>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>N° de serie</label>
                    <WebControls:TextBox2 ID="txtNumeroSerie" runat="server" MaxLength="100" placeholder="El de la placa de la pieza" />
                </div>
                <div class="sigma-modal-field">
                    <label>Marca</label>
                    <rad:RadComboBox2 ID="cboFabricante" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" MaxLength="150"
                        AllowCustomText="true" EmptyMessage="Elige o escribe una nueva" />
                    <span class="sigma-modal-ayuda">El mismo catálogo de marcas de activos y repuestos.</span>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Modelo</label>
                    <WebControls:TextBox2 ID="txtModelo" runat="server" MaxLength="150" placeholder="Ej.: 6205-2RS" />
                    <span class="sigma-modal-ayuda">Con la marca y el modelo se pide el repuesto sin abrir la máquina.</span>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Foto del componente</label>
                    <div class="af-drop af-foto">
                        <span class="af-drop-ico" id="acFotoIco">
                            <asp:Panel ID="pnlSinImagen" runat="server" CssClass="af-foto-vacia"><i class="mdi mdi-image-outline"></i></asp:Panel>
                            <asp:Panel ID="pnlImagenActual" runat="server" Visible="false" CssClass="af-foto-actual">
                                <img id="imgActual" runat="server" alt="Foto actual del componente" />
                            </asp:Panel>
                            <img id="acFotoPrev" alt="Vista previa" style="display:none" />
                        </span>
                        <span class="af-drop-txt">
                            <b>Arrastra una foto aquí</b>
                            <span>PNG o JPG. Evita confundir dos piezas parecidas.</span>
                            <span id="acFotoNom" class="sigma-img-name"></span>
                            <asp:Panel ID="pnlQuitarImagen" runat="server" Visible="false" CssClass="af-quitar-foto">
                                <asp:CheckBox ID="chkQuitarImagen" runat="server" Text="Quitar la foto actual al guardar" />
                            </asp:Panel>
                        </span>
                        <span class="af-drop-acc">
                            <label for="fuImagenComp" class="af-btn es-suave"><i class="mdi mdi-camera-outline"></i>Elegir foto</label>
                        </span>
                        <asp:FileUpload ID="fuImagenComp" runat="server" accept="image/*" ClientIDMode="Static" onchange="acFotoVer(this)" style="display:none;" />
                    </div>
                </div>
            </div>
        </section>

        <div class="af-pie">
            <button type="button" class="af-btn es-contorno" id="fpBtnAnterior" onclick="fpIr(fpActual() - 1)"><i class="mdi mdi-arrow-left"></i>Anterior</button>
            <span class="af-pie-donde"><span id="fpDonde"></span></span>
            <div class="af-pie-der">
                <button type="button" class="af-btn es-contorno" id="fpBtnSiguiente" onclick="fpSiguiente()">Siguiente<i class="mdi mdi-arrow-right"></i></button>
                <div class="af-pie-acc">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cancelar" CssClass="af-btn es-ghost af-cancelar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" CssClass="af-btn es-primario af-guardar" OnClick="btnGuardar_Click" ValidationGroup="Activo" OnClientClick="sigmaGuardando();" />
                </div>
            </div>
        </div>
    </div>
</asp:Panel>

<div id="sigmaGuardandoOv" style="display:none;position:fixed;inset:0;z-index:99999;background:rgba(255,255,255,.82);align-items:center;justify-content:center;">
    <div style="display:flex;flex-direction:column;align-items:center;gap:12px;text-align:center;">
        <div style="width:44px;height:44px;border:4px solid #E2E7F0;border-top-color:#6732F4;border-radius:50%;animation:sigmaSpin .8s linear infinite;"></div>
        <div style="font-size:15px;font-weight:700;color:#17223B;">Guardando el componente…</div>
    </div>
</div>
<style>@keyframes sigmaSpin{to{transform:rotate(360deg)}}</style>

        </ContentTemplate>
    </asp:UpdatePanel>
</div>
</asp:Content>
