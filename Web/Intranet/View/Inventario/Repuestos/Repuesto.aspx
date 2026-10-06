<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="Repuesto.aspx.cs" Inherits="View_Inventario_Repuestos_Repuesto" %>
<%@ Register TagPrefix="wuc" TagName="Auditoria" Src="~/View/Comun/Controls/Auditoria.ascx" %>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <%-- La galeria comparte hoja con los tipos de repuesto: son del mismo
         modulo y separarlas seria un archivo mas por dos bloques. --%>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-repuesto-tipos.css?vrs=1") %>' rel="stylesheet" />
    <script type="text/javascript" src="<%=ResolveUrl("~/Js/sigma-fabricante.js") %>?vrs=2"></script>
    <style type="text/css">
        .sg-fab-aviso { margin-top: 6px; padding: 8px 10px; border-radius: 9px; background: #E8FBFB; color: #17223B; font-size: 12px; }
        .sg-fab-aviso i { color: #007F8A; }
    </style>
    <script type="text/javascript">
        /* Fabricante y modelo en cascada (bloque 333): el catalogo lo deja el
           servidor en #sgFabCatalogo. Se engancha al cargar y despues de cada
           postback parcial, porque el UpdatePanel reemplaza los campos. */
        function sgCatalogo() {
            var c = document.getElementById('sgFabCatalogo');
            return c ? JSON.parse(c.textContent || '[]') : [];
        }
        function sgCombo(sufijo) {
            var el = document.querySelector('[id$="_' + sufijo + '"].RadComboBox, [id$="' + sufijo + '"].RadComboBox');
            return el ? $find(el.id) : null;
        }
        /* El texto escrito, sin confundirlo con el mensaje de ayuda del combo. */
        function sgTexto(c) {
            if (!c) return '';
            var t = c.get_text();
            return (c.get_emptyMessage && t === c.get_emptyMessage()) ? '' : t;
        }
        function sgFabricante() {
            var f = sgCombo('cboFabricante'), k = f ? SigmaFabricante.clave(sgTexto(f)) : '';
            return sgCatalogo().filter(function (x) { return SigmaFabricante.clave(x.nombre) === k; })[0] || null;
        }

        /* Fabricante elegido o escrito: forma del catalogo y modelos en cascada. */
        function sgFabCambio() {
            var f = sgCombo('cboFabricante'), m = sgCombo('cboModelo');
            if (!f || !m) return;
            var fab = sgFabricante(), limpio = sgTexto(f).replace(/\s+/g, ' ').trim();
            if (fab && sgTexto(f) !== fab.nombre) f.set_text(fab.nombre);
            else if (!fab && limpio && sgTexto(f) !== limpio) f.set_text(limpio);
            var antes = sgTexto(m);
            m.trackChanges();
            m.get_items().clear();
            (fab ? fab.modelos : []).forEach(function (x) {
                var it = new Telerik.Web.UI.RadComboBoxItem(); it.set_text(x); it.set_value(x); m.get_items().add(it);
            });
            m.commitChanges();
            // el modelo de otro fabricante no le pertenece
            if (antes && !(fab && fab.modelos.some(function (x) { return SigmaFabricante.clave(x) === SigmaFabricante.clave(antes); }))
                && sgFabCambio.previo && sgFabCambio.previo !== SigmaFabricante.clave(sgTexto(f))) { m.clearSelection(); m.set_text(''); }
            sgFabCambio.previo = SigmaFabricante.clave(sgTexto(f));
            sgModAvisar();
        }
        function sgModCanon() {
            var m = sgCombo('cboModelo'), fab = sgFabricante();
            if (!m) return;
            var t = sgTexto(m).replace(/\s+/g, ' ').trim();
            if (!t) return sgModAvisar();
            if (fab) fab.modelos.forEach(function (x) { if (SigmaFabricante.clave(x) === SigmaFabricante.clave(t)) t = x; });
            if (sgTexto(m) !== t) m.set_text(t);
            sgModAvisar();
        }
        function sgModAvisar() {
            var a = document.getElementById('sgFabAviso'), f = sgCombo('cboFabricante'), m = sgCombo('cboModelo');
            if (!a || !f || !m) return;
            var fab = sgFabricante(), t = sgTexto(f).trim(), mt = sgTexto(m).trim(), h = '';
            if (t && !fab) h = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + t.replace(/</g, '&lt;') + '</b> es un fabricante nuevo: se agrega al catálogo al guardar.';
            else if (fab && mt && !fab.modelos.some(function (x) { return SigmaFabricante.clave(x) === SigmaFabricante.clave(mt); }))
                h = '<i class="mdi mdi-plus-circle-outline"></i> <b>' + mt.replace(/</g, '&lt;') + '</b> es un modelo nuevo de ' + fab.nombre + ': se agrega al guardar.';
            else if (fab) h = '<i class="mdi mdi-check-circle-outline"></i> ' + fab.nombre + ' · ' + fab.repuestos + ' repuestos · ' +
                              (mt ? fab.modelos.length + ' modelos' : 'elija uno de sus ' + fab.modelos.length + ' modelos o escriba uno nuevo');
            else if (t) h = '';
            a.innerHTML = h; a.hidden = !h;
        }
        /* Estado inicial al cargar y tras cada postback parcial (el
           UpdatePanel recrea los combos). */
        function sgFabIniciar() {
            var f = sgCombo('cboFabricante');
            if (!f) return;
            sgFabCambio.previo = SigmaFabricante.clave(sgTexto(f));
            sgModAvisar();
        }
        window.addEventListener('load', function () {
            setTimeout(sgFabIniciar, 0);
            if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
                Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () { setTimeout(sgFabIniciar, 0); });
        });
    </script>

    <%-- REDISEÑO 06-10-2026: la ficha del repuesto es el mismo asistente que
         la del activo (sigma-asistente.css/js): los pasos a la izquierda con
         una ayuda corta por paso, una sola barra de botones al pie y la
         validacion que dice que falta y lleva al campo. Antes eran tres
         pestañas con secciones apiladas. --%>
    <script type="text/javascript">var AF_PASOS = 6; var AF_GRUPO = 'Repuesto';</script>
    <link href='<%=ResolveUrl("~/Css/LookAndFeel/sigma-asistente.css") %>?v=<%=DateTime.UtcNow.ToString("yyyyMMddHH") %>' rel="stylesheet" />
    <script type="text/javascript" src='<%=ResolveUrl("~/Js/sigma-asistente.js") %>?v=<%=DateTime.UtcNow.ToString("yyyyMMddHH") %>'></script>
    <script type="text/javascript">
        /* Guardar: si falta algo, se dice que y se lleva al campo; si esta todo,
           el velo «Guardando…» (sin bloquear el postback). */
        function repGuardando() {
            setTimeout(function () {
                if (typeof Page_IsValid !== 'undefined' && Page_IsValid === false) { afMostrarFaltas(true); return; }
                var ov = document.getElementById('repGuardandoOv');
                if (ov) ov.style.display = 'flex';
            }, 0);
        }
        /* El paso en que estaba se conserva tras cada postback parcial
           (agregar una foto, guardar un umbral). */
        function repPaso() { if (window.fpIr && window.fpActual) fpIr(fpActual()); }
        window.addEventListener('load', function () {
            setTimeout(repPaso, 0);
            if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager)
                Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () {
                    var ov = document.getElementById('repGuardandoOv'); if (ov) ov.style.display = 'none';
                    setTimeout(repPaso, 0);
                });
        });
    </script>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>

<asp:Panel ID="pnlAf" runat="server" CssClass="af">

    <asp:HiddenField ID="hdnPaso" runat="server" Value="1" />

    <%-- ============ RIEL: pasos + ayuda del paso ============ --%>
    <aside class="af-rail">
        <nav class="af-pasos" aria-label="Pasos de la ficha">
            <button type="button" class="af-paso" data-ir="1" onclick="fpIr(1)"><span class="af-n"><span>1</span><i class="mdi mdi-check"></i></span><span><b>Identificación</b><small>Qué es el repuesto</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="2" onclick="fpIr(2)"><span class="af-n"><span>2</span><i class="mdi mdi-check"></i></span><span><b>Fabricante</b><small>Marca, modelo y costo</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="3" onclick="fpIr(3)"><span class="af-n"><span>3</span><i class="mdi mdi-check"></i></span><span><b>Cómo se opera</b><small>Lote, consumible y vida útil</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="4" onclick="fpIr(4)"><span class="af-n"><span>4</span><i class="mdi mdi-check"></i></span><span><b>Almacenamiento</b><small>Método de salida y medidas</small><span class="af-falta-dot">Falta un dato</span></span></button>
            <button type="button" class="af-paso" data-ir="5" onclick="fpIr(5)"><span class="af-n"><span>5</span><i class="mdi mdi-check"></i></span><span><b>Fotos</b><small>Para reconocerlo en bodega</small></span></button>
            <button type="button" class="af-paso" data-ir="6" onclick="fpIr(6)"><span class="af-n"><span>6</span><i class="mdi mdi-check"></i></span><span><b>Stock</b><small>Mínimos por bodega y lotes</small></span></button>
        </nav>

        <div class="af-tip" data-paso="1"><i class="mdi mdi-information-variant"></i><div><b>Completa lo principal.</b> Con el nombre y la unidad de medida ya puedes guardar. Lo demás lo agregas cuando quieras.</div></div>
        <div class="af-tip" data-paso="2"><i class="mdi mdi-information-variant"></i><div><b>El buscador también mira estos datos.</b> El técnico escribe el número grabado en la pieza y la encuentra igual.</div></div>
        <div class="af-tip" data-paso="3"><i class="mdi mdi-information-variant"></i><div><b>Cambian cómo se opera, no cómo se describe.</b> Con lote, cada ingreso pide su código y vencimiento. La vida útil es la que declara el fabricante.</div></div>
        <div class="af-tip" data-paso="4"><i class="mdi mdi-information-variant"></i><div><b>Este paso es opcional.</b> Lo normal es salir según la bodega. Con las medidas, el mapa 3D dibuja la caja y avisa si el nivel se sobrecarga.</div></div>
        <div class="af-tip" data-paso="5"><i class="mdi mdi-information-variant"></i><div><b>La primera foto es la portada</b> y es la que se ve en el listado y en el mapa.</div></div>
        <div class="af-tip" data-paso="6"><i class="mdi mdi-information-variant"></i><div><b>Los mínimos son por bodega:</b> la misma pieza puede ser crítica en una planta y no en otra. Los lotes se registran al ingresar la mercadería.</div></div>
    </aside>

    <div class="af-cuerpo">

        <div class="af-faltan" id="afFaltan" role="alert" aria-live="assertive">
            <i class="mdi mdi-alert-circle-outline"></i>
            <div><b id="afFaltanTit">Faltan datos para poder guardar</b><span>Toca cada uno para ir a completarlo.</span>
                <div class="af-faltan-lista" id="afFaltanLista"></div></div>
        </div>

        <%-- ============ PASO 1 · IDENTIFICACIÓN ============ --%>
        <section class="af-seccion" data-paso="1">
            <header class="af-cab"><i class="mdi mdi-package-variant-closed"></i><div><h3>Identificación</h3><p>Lo que identifica al repuesto en la bodega.</p></div></header>
            <span class="af-oculto"><asp:Label ID="lblId" runat="server"></asp:Label></span>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Código</label>
                    <div class="sg-codigo">
                        <span class="sg-codigo-prefijo"><asp:Literal ID="litPrefijo" runat="server" /></span>
                        <WebControls:TextBox2 ID="txtCodigo" runat="server" MaxLength="100" UpperCase="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Si lo dejas vacío, se numera solo. Único en la empresa y no se cambia después.</span>
                    <asp:CustomValidator ID="cvCodigo" runat="server" ControlToValidate="txtCodigo" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="validaControl" ValidationGroup="Repuesto" />
                </div>
                <div class="sigma-modal-field">
                    <label>Nombre <span class="req">*</span></label>
                    <WebControls:TextBox2 ID="txtNombre" runat="server" MaxLength="400" placeholder="Ej.: Rodamiento 6205-2RS1" />
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Escribe cómo le dicen al repuesto en la bodega.</span>
                    <asp:CustomValidator ID="cvNombre" runat="server" ControlToValidate="txtNombre" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Repuesto" />
                </div>
                <div class="sigma-modal-field">
                    <label>Unidad de medida <span class="req">*</span></label>
                    <rad:RadComboBox2 ID="cboUnidad" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">No se puede cambiar si el repuesto tiene existencia.</span>
                    <span class="af-msg"><i class="mdi mdi-alert-circle-outline"></i>Elige en qué se cuenta: unidad, litro, metro…</span>
                    <asp:CustomValidator ID="cvUnidad" runat="server" ControlToValidate="cboUnidad" Display="None"
                        ValidateEmptyText="true" ClientValidationFunction="afRequerido" ValidationGroup="Repuesto" />
                </div>
                <%-- Opcional a proposito: sin tipo, el repuesto cae en «Sin
                     clasificar», que es cierto y no estorba. --%>
                <div class="sigma-modal-field">
                    <label>Tipo de repuesto</label>
                    <rad:RadComboBox2 ID="cboTipo" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    <span class="sigma-modal-ayuda">Lo agrupa en su pestaña del listado. Vacío queda <em>Sin clasificar</em>.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>¿Está habilitado? <span class="req">*</span></label>
                    <div class="sigma-modal-opciones">
                        <asp:RadioButton ID="rdbSi" runat="server" Text="Sí" GroupName="Habilitado" Checked="true" />
                        <asp:RadioButton ID="rdbNo" runat="server" Text="No" GroupName="Habilitado" />
                    </div>
                    <span class="sigma-modal-ayuda">No se puede dar de baja con existencia en bodega.</span>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <label>Descripción</label>
                    <WebControls:TextArea2 ID="txtDescripcion" runat="server" MaxLength="1000" placeholder="Detalle técnico o algo que convenga saber" />
                </div>
            </div>
        </section>

        <%-- ============ PASO 2 · FABRICANTE ============ --%>
        <section class="af-seccion" data-paso="2">
            <header class="af-cab"><i class="mdi mdi-factory"></i><div><h3>Fabricante</h3><p>Quién lo fabrica y cuánto cuesta de referencia.</p></div></header>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Fabricante</label>
                    <%-- Lo que no esta en la lista se agrega al catalogo al guardar (bloque 333). --%>
                    <rad:RadComboBox2 ID="cboFabricante" runat="server" Width="100%" AllowCustomText="true"
                        Filter="Contains" MaxLength="400" EmptyMessage="Elige o escribe uno nuevo"
                        OnClientSelectedIndexChanged="sgFabCambio" OnClientBlur="sgFabCambio" />
                    <span class="sigma-modal-ayuda">«fleetguard» y «FLEETGUARD» se guardan como «Fleetguard», sin duplicar.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Modelo o código del fabricante</label>
                    <rad:RadComboBox2 ID="cboModelo" runat="server" Width="100%" AllowCustomText="true"
                        Filter="Contains" MaxLength="400" EmptyMessage="Primero el fabricante"
                        OnClientSelectedIndexChanged="sgModAvisar" OnClientBlur="sgModCanon" />
                    <span class="sigma-modal-ayuda">Muestra solo los de ese fabricante. ¿No está? Escríbelo.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Costo de referencia</label>
                    <WebControls:TextBox2 ID="txtCosto" runat="server" MaxLength="14" placeholder="En pesos" />
                    <span class="sigma-modal-ayuda">Referencial. El costo real sale de cada ingreso.</span>
                </div>
                <div class="sigma-modal-field af-ancho">
                    <div class="sg-fab-aviso" id="sgFabAviso" hidden></div>
                    <asp:Literal ID="litFabCatalogo" runat="server" />
                </div>
            </div>
        </section>

        <%-- ============ PASO 3 · CÓMO SE OPERA ============ --%>
        <section class="af-seccion" data-paso="3">
            <header class="af-cab"><i class="mdi mdi-shape-outline"></i><div><h3>Cómo se opera</h3><p>Si controla lote, si se gasta o se repara, y cuánto dura.</p></div></header>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>¿Controla lote? <span class="req">*</span></label>
                    <div class="sigma-modal-opciones">
                        <asp:RadioButton ID="rdbLoteSi" runat="server" Text="Sí" GroupName="Lote" />
                        <asp:RadioButton ID="rdbLoteNo" runat="server" Text="No" GroupName="Lote" Checked="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Cada ingreso pide el código del lote y su vencimiento; con FEFO sale primero el que vence antes. Aceites, filtros, sellos.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>¿Es consumible? <span class="req">*</span></label>
                    <div class="sigma-modal-opciones">
                        <asp:RadioButton ID="rdbConsumibleSi" runat="server" Text="Sí" GroupName="Consumible" />
                        <asp:RadioButton ID="rdbConsumibleNo" runat="server" Text="No" GroupName="Consumible" Checked="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Se gasta al usarlo y no vuelve a bodega.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>¿Es reparable? <span class="req">*</span></label>
                    <div class="sigma-modal-opciones">
                        <asp:RadioButton ID="rdbReparableSi" runat="server" Text="Sí" GroupName="Reparable" />
                        <asp:RadioButton ID="rdbReparableNo" runat="server" Text="No" GroupName="Reparable" Checked="true" />
                    </div>
                    <span class="sigma-modal-ayuda">Sale de servicio, se repara y vuelve.</span>
                </div>
            </div>
            <header class="af-cab" style="margin-top:18px"><i class="mdi mdi-timer-sand"></i><div><h3>Vida útil esperada</h3><p>La que declara el fabricante; las tres pueden convivir (lo que ocurra primero). Vacías si no se conocen.</p></div></header>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Horas</label>
                    <WebControls:TextBox2 ID="txtVidaHora" runat="server" MaxLength="12" placeholder="Ej.: 8000" />
                    <span class="sigma-modal-ayuda">Horas de marcha. Un rodamiento.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Días</label>
                    <WebControls:TextBox2 ID="txtVidaDia" runat="server" MaxLength="8" placeholder="Ej.: 365" />
                    <span class="sigma-modal-ayuda">Calendario, gire o no. Un filtro de aire.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Ciclos</label>
                    <WebControls:TextBox2 ID="txtVidaCiclo" runat="server" MaxLength="12" placeholder="Ej.: 50000" />
                    <span class="sigma-modal-ayuda">Maniobras. Un contacto de partida.</span>
                </div>
            </div>
        </section>

        <%-- ============ PASO 4 · ALMACENAMIENTO (bloques 328 y 329) ============ --%>
        <section class="af-seccion" data-paso="4">
            <header class="af-cab"><i class="mdi mdi-warehouse"></i><div><h3>Almacenamiento</h3><p>De qué caja sale al consumir y cuánto ocupa en el rack.</p></div></header>
            <div class="af-grid">
                <div class="sigma-modal-field">
                    <label>Método de salida</label>
                    <rad:RadComboBox2 ID="ddlMetodo" runat="server" Width="100%">
                        <Items>
                            <rad:RadComboBoxItem Value="" Text="Según la bodega" Selected="true" />
                            <rad:RadComboBoxItem Value="FEFO" Text="FEFO · vence primero" />
                            <rad:RadComboBoxItem Value="FIFO" Text="FIFO · entró primero" />
                            <rad:RadComboBoxItem Value="LIFO" Text="LIFO · entró último" />
                        </Items>
                    </rad:RadComboBox2>
                    <span class="sigma-modal-ayuda">Fíjalo solo si este repuesto es la excepción de su bodega.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Peso (kg)</label>
                    <WebControls:TextBox2 ID="txtPeso" runat="server" MaxLength="10" placeholder="Por unidad" />
                    <span class="sigma-modal-ayuda">El mapa avisa si el nivel se sobrecarga.</span>
                </div>
                <div class="sigma-modal-field">
                    <label>Largo (cm)</label>
                    <WebControls:TextBox2 ID="txtLargo" runat="server" MaxLength="9" />
                </div>
                <div class="sigma-modal-field">
                    <label>Ancho (cm)</label>
                    <WebControls:TextBox2 ID="txtAncho" runat="server" MaxLength="9" />
                </div>
                <div class="sigma-modal-field">
                    <label>Alto (cm)</label>
                    <WebControls:TextBox2 ID="txtAlto" runat="server" MaxLength="9" />
                </div>
            </div>
        </section>

        <%-- ============ PASO 5 · FOTOS ============
             Solo con el repuesto guardado: una foto necesita algo a lo que
             colgarse. La portada es la primera. --%>
        <section class="af-seccion" data-paso="5">
            <header class="af-cab"><i class="mdi mdi-image-multiple-outline"></i><div><h3>Fotos</h3><p>Para reconocerlo en la bodega y en el listado.</p></div></header>
            <asp:Panel ID="pnlFotosNuevo" runat="server" CssClass="af-vacio">
                <i class="mdi mdi-content-save-outline"></i>
                <div><b>Primero guarda el repuesto.</b><span>Las fotos se agregan apenas exista: guarda y vuelve a este paso.</span></div>
            </asp:Panel>
            <asp:Panel ID="pnlGaleria" runat="server" Visible="false">
                <div class="sg-galeria-alta">
                    <asp:FileUpload ID="fupFoto" runat="server" CssClass="sg-galeria-file" accept="image/*" />
                    <asp:LinkButton ID="lnkAgregarFoto" runat="server" CssClass="af-btn es-suave"
                        OnClick="lnkAgregarFoto_Click" CausesValidation="false">
                        <i class="mdi mdi-image-plus"></i><span>Agregar foto</span>
                    </asp:LinkButton>
                    <span class="sigma-modal-ayuda">Solo imágenes. La primera queda de portada.</span>
                </div>
                <asp:Repeater ID="rptFotos" runat="server"
                    OnItemDataBound="rptFotos_ItemDataBound" OnItemCommand="rptFotos_ItemCommand">
                    <HeaderTemplate><ul class="sg-galeria"></HeaderTemplate>
                    <ItemTemplate>
                        <li class="sg-galeria-item">
                            <asp:Literal ID="litFoto" runat="server" />
                            <div class="sg-galeria-acciones">
                                <asp:LinkButton ID="lnkPortada" runat="server" CommandName="portada"
                                    CssClass="sg-galeria-accion" ToolTip="Hacer portada" CausesValidation="false">
                                    <i class="mdi mdi-star-outline" aria-hidden="true"></i>
                                </asp:LinkButton>
                                <asp:LinkButton ID="lnkQuitarFoto" runat="server" CommandName="quitar"
                                    CssClass="sg-galeria-accion is-peligro" ToolTip="Quitar" CausesValidation="false">
                                    <i class="mdi mdi-trash-can-outline" aria-hidden="true"></i>
                                </asp:LinkButton>
                            </div>
                        </li>
                    </ItemTemplate>
                    <FooterTemplate></ul></FooterTemplate>
                </asp:Repeater>
                <asp:Panel ID="pnlSinFotos" runat="server" Visible="false" CssClass="sg-galeria-vacia">
                    <i class="mdi mdi-image-off-outline" aria-hidden="true"></i>
                    <span>Sin fotos. La primera que agregues será la portada.</span>
                </asp:Panel>
            </asp:Panel>
        </section>

        <%-- ============ PASO 6 · STOCK (HU-053 y HU-054) ============ --%>
        <section class="af-seccion" data-paso="6">
            <header class="af-cab"><i class="mdi mdi-gauge"></i><div><h3>Stock por bodega</h3><p>Mínimo, máximo y punto de reposición en cada bodega.</p></div></header>
            <asp:Panel ID="pnlStockNuevo" runat="server" CssClass="af-vacio">
                <i class="mdi mdi-content-save-outline"></i>
                <div><b>Primero guarda el repuesto.</b><span>Los mínimos y máximos se definen por bodega una vez que existe.</span></div>
            </asp:Panel>
            <asp:Panel ID="pnlUmbrales" runat="server" Visible="false">
                <div class="af-grid">
                    <div class="sigma-modal-field">
                        <label>Bodega</label>
                        <rad:RadComboBox2 ID="cboBodega" runat="server" OnLoad="LoadControls" Filter="Contains" Width="100%" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Mínimo</label>
                        <WebControls:TextBox2 ID="txtMinimo" runat="server" MaxLength="12" />
                    </div>
                    <div class="sigma-modal-field">
                        <label>Máximo</label>
                        <WebControls:TextBox2 ID="txtMaximo" runat="server" MaxLength="12" />
                        <span class="sigma-modal-ayuda">No puede ser menor que el mínimo.</span>
                    </div>
                    <div class="sigma-modal-field">
                        <label>Punto de reposición</label>
                        <WebControls:TextBox2 ID="txtReposicion" runat="server" MaxLength="12" />
                        <span class="sigma-modal-ayuda">Cuándo pedir: entre el mínimo y el máximo.</span>
                    </div>
                </div>
                <div style="display:flex;justify-content:flex-end;margin:10px 0 14px">
                    <WebControls:PushButton ID="btnGuardarUmbral" runat="server" Text="Guardar umbrales" CssClass="af-btn es-secundario" OnClick="btnGuardarUmbral_Click" />
                </div>
                <rad:RadGrid2 ID="GridUmbrales" runat="server">
                    <MasterTableView DataKeyNames="rbs_id" CommandItemDisplay="None" />
                </rad:RadGrid2>
            </asp:Panel>

            <%-- Lotes: solo lectura y solo si el repuesto los controla. El lote
                 se crea al recibir la mercaderia, en Movimientos. --%>
            <asp:Panel ID="pnlLotes" runat="server" Visible="false">
                <header class="af-cab" style="margin-top:20px"><i class="mdi mdi-barcode"></i><div><h3>Lotes recibidos</h3><p>Se registran al ingresar la mercadería, en Inventario › Movimientos.</p></div></header>
                <rad:RadGrid2 ID="GridLotes" runat="server" OnItemDataBound="GridLotes_ItemDataBound">
                    <MasterTableView CommandItemDisplay="None" />
                </rad:RadGrid2>
            </asp:Panel>
        </section>

        <%-- ============ LA BARRA DEL PIE (igual que la del activo) ============ --%>
        <div class="af-pie">
            <button type="button" class="af-btn es-contorno" id="fpBtnAnterior" onclick="fpIr(fpActual() - 1)"><i class="mdi mdi-arrow-left"></i>Anterior</button>
            <span class="af-pie-donde"><span id="fpDonde"></span></span>
            <div class="af-pie-der">
                <button type="button" class="af-btn es-contorno" id="fpBtnSiguiente" onclick="fpSiguiente()">Siguiente<i class="mdi mdi-arrow-right"></i></button>
                <div class="af-pie-acc">
                    <WebControls:PushButton ID="btnCerrar" runat="server" Text="Cancelar" CssClass="af-btn es-ghost af-cancelar" OnClientClick="closeWindow(); return false;" />
                    <WebControls:PushButton ID="btnGuardar" runat="server" Text="Guardar" CssClass="af-btn es-primario af-guardar" OnClick="btnGuardar_Click" ValidationGroup="Repuesto" OnClientClick="repGuardando();" />
                </div>
            </div>
        </div>

        <wuc:Auditoria runat="server" ID="wucAuditoria" />
    </div>
</asp:Panel>

<div id="repGuardandoOv" style="display:none;position:fixed;inset:0;z-index:99999;background:rgba(255,255,255,.82);align-items:center;justify-content:center;">
    <div style="display:flex;flex-direction:column;align-items:center;gap:12px;text-align:center;">
        <div style="width:44px;height:44px;border:4px solid #E2E7F0;border-top-color:#6732F4;border-radius:50%;animation:repSpin .8s linear infinite;"></div>
        <div style="font-size:15px;font-weight:700;color:#17223B;">Guardando el repuesto…</div>
    </div>
</div>
<style>@keyframes repSpin{to{transform:rotate(360deg)}}
.af-vacio{display:flex;gap:12px;align-items:flex-start;padding:16px;border-radius:14px;background:#F4F6FA;color:#3C4760;font-size:13px}
.af-vacio i{font-size:22px;color:#6732F4}.af-vacio b{display:block;color:#17223B}</style>

        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
