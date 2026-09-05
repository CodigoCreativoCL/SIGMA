<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ActivoTipos.aspx.cs" Inherits="View_Activos_Tipos_ActivoTipos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirActivoTipo(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Activos/Tipos/ActivoTipo.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo tipo de activo' : 'Editar tipo de activo',
                width: 860,
                initialHeight: 520
            });
        }

        function refresh() {
            __doPostBack("<%=Grid.ClientID %>", '')
        }

        // ===== Árbol plegable de tipos de activo =====
        // Las filas vienen ordenadas jerárquicamente (padre y luego sus hijos)
        // y cada una trae data-nivel. Un tipo "tiene hijos" si la fila siguiente
        // es de un nivel mayor; a esos se les muestra el caret y se pueden plegar.
        function sigmaArbolTipos() {
            var rows = Array.prototype.slice.call(document.querySelectorAll('tr[data-nivel]'));
            for (var i = 0; i < rows.length; i++) {
                var nivel = parseInt(rows[i].getAttribute('data-nivel'), 10);
                var next = rows[i + 1];
                var tieneHijos = next && parseInt(next.getAttribute('data-nivel'), 10) > nivel;
                var btn = rows[i].querySelector('.sigma-tree-btn');
                rows[i].style.display = '';
                if (!btn) continue;
                if (tieneHijos) {
                    btn.classList.add('is-parent', 'is-open');
                    rows[i].classList.add('es-padre');
                    rows[i].setAttribute('data-abierto', '1');
                    (function (idx, lvl, r, b) {
                        b.onclick = function (ev) { ev.stopPropagation(); sigmaToggleTipo(rows, idx, lvl, r, b); };
                        r.style.cursor = 'pointer';
                        r.onclick = function (ev) {
                            var t = ev.target;
                            if (t.closest && t.closest('a, input, .icono_Editar, .rgSelect')) return;
                            sigmaToggleTipo(rows, idx, lvl, r, b);
                        };
                    })(i, nivel, rows[i], btn);
                } else {
                    btn.classList.remove('is-parent', 'is-open');
                    rows[i].classList.remove('es-padre');
                }
            }
        }
        function sigmaToggleTipo(rows, idx, nivel, row, btn) {
            var abrir = row.getAttribute('data-abierto') !== '1';
            row.setAttribute('data-abierto', abrir ? '1' : '0');
            btn.classList.toggle('is-open', abrir);
            for (var j = idx + 1; j < rows.length; j++) {
                var n = parseInt(rows[j].getAttribute('data-nivel'), 10);
                if (n <= nivel) break;
                rows[j].style.display = abrir ? '' : 'none';
                if (abrir) {
                    rows[j].setAttribute('data-abierto', '1');
                    var b2 = rows[j].querySelector('.sigma-tree-btn');
                    if (b2) b2.classList.add('is-open');
                }
            }
        }
        if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () { window.setTimeout(sigmaArbolTipos, 60); });
        }
        if (document.addEventListener) document.addEventListener('DOMContentLoaded', function () { window.setTimeout(sigmaArbolTipos, 120); });
        window.setTimeout(sigmaArbolTipos, 400);
    </script>
    <style type="text/css">
        .sigma-tree-item { display: flex; align-items: center; gap: 6px; }
        /* Conector de rama (└) para los hijos. */
        .sigma-tree-elbow { width: 18px; height: 16px; flex: 0 0 auto; border-left: 2px solid #c7d2fe; border-bottom: 2px solid #c7d2fe; border-bottom-left-radius: 8px; margin: -10px 2px 0 6px; align-self: flex-start; }
        /* Chevron ▸ / ▾ — vive en la columna del ID, junto a la lupa. Ocupa un
           lugar fijo en todas las filas (para que las lupas queden alineadas);
           solo se dibuja en los que tienen hijos. */
        .sigma-tree-btn { width: 28px; height: 28px; flex: 0 0 auto; display: inline-flex; align-items: center; justify-content: center; border-radius: 8px; color: transparent; font-size: 14px; vertical-align: middle; margin-right: 4px; }
        .sigma-tree-btn.is-parent { cursor: pointer; color: #6C5CFF; border: 1.5px solid #ddd6fe; background: #f5f3ff; transition: background .12s ease, border-color .12s ease; }
        .sigma-tree-btn.is-parent:hover { background: #ede9fe; border-color: #c4b5fd; }
        .sigma-tree-btn.is-parent::before { content: '\25B8'; }        /* ▸ */
        .sigma-tree-btn.is-parent.is-open::before { content: '\25BE'; } /* ▾ */
        .sigma-tree-nom { font-weight: 500; color: #0f172a; }
        /* Celda del ID: lupa a la izquierda + chevron a la derecha, lado a lado. */
        .sigma-idcell { display: flex; align-items: center; gap: 10px; white-space: nowrap; }
        .sigma-idcell .icono_Editar { flex: 0 0 auto; }

        /* Tono del RECUADRO (la fila) distinto según el rol, sin tocar las
           letras. Padre = violeta claro; hijos = gris (más marcado por nivel);
           los de primer nivel sin hijos quedan en blanco. */
        tr.es-padre > td { background: #eee9fe !important; }
        tr[data-nivel="2"]:not(.es-padre) > td { background: #f1f5f9 !important; }
        tr[data-nivel="3"]:not(.es-padre) > td { background: #e8edf3 !important; }
        tr[data-nivel="4"]:not(.es-padre) > td { background: #dfe6ee !important; }
    </style>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">
    Activos
</asp:Content>

<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">
    Tipos de activo
</asp:Content>

<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    Las clases o categorías con que agrupas tus equipos (motor, caldera, ascensor, cámara de frío…). Se organizan en árbol; cada clase puede tener sus modelos y sus datos técnicos.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-2 col-md-2 col-12 d-flex align-items-center" style="gap: 32px;">
                    <label for="cboHabilitado" style="margin: 0;">Habilitado:</label>
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 32px;">
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="60%">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
                <div class="col-lg-6 col-md-6 col-xs-12 d-flex align-items-center"></div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus tipos de activo.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrTipos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="ati_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirActivoTipo(0);" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja los tipos seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
