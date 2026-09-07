<%@ Page Language="C#" MasterPageFile="~/Master/Default.master" AutoEventWireup="true" CodeFile="ProcedimientoPasos.aspx.cs" Inherits="View_Mantenimiento_Procedimientos_ProcedimientoPasos" %>

<%@ Register TagPrefix="wuc" TagName="Filtro" Src="~/View/Comun/Controls/FiltroAvanzado.ascx" %>

<asp:Content ID="ContenHeder" ContentPlaceHolderID="cphHeder" runat="server">
</asp:Content>

<asp:Content ID="ContentScript" ContentPlaceHolderID="chpScript" runat="server">
    <script type="text/javascript">
        function abrirPaso(query) {
            return SigmaModal.open({
                url: '<%=ResolveUrl("~/View/Mantenimiento/Procedimientos/ProcedimientoPaso.aspx") %>?query=' + query,
                title: String(query) === '0' ? 'Nuevo paso' : 'Editar paso',
                width: 820,
                initialHeight: 620
            });
        }
        // Nuevo: si hay un procedimiento elegido en el filtro, se preselecciona en la ficha.
        function abrirPasoNuevo() {
            var prc = '';
            try {
                var cbo = $find('<%= ProcCombo %>');
                if (cbo) prc = cbo.get_value() || '';
            } catch (e) { }
            return abrirPaso('0' + (prc ? '&prc=' + prc : ''));
        }
        function refresh() { __doPostBack("<%=Grid.ClientID %>", '') }

        // ===== Árbol plegable: procedimiento (grupo) → sus pasos =====
        // Las filas traen data-nivel (1 grupo, 2 paso). Empieza COLAPSADO: se ven
        // solo los procedimientos y al hacer clic se despliegan sus pasos.
        function sigmaArbolPasos() {
            var rows = Array.prototype.slice.call(document.querySelectorAll('tr[data-nivel]'));
            for (var i = 0; i < rows.length; i++) {
                var nivel = parseInt(rows[i].getAttribute('data-nivel'), 10);
                var next = rows[i + 1];
                var tieneHijos = next && parseInt(next.getAttribute('data-nivel'), 10) > nivel;
                var btn = rows[i].querySelector('.sigma-tree-btn');
                rows[i].style.display = nivel > 1 ? 'none' : 'table-row';
                rows[i].setAttribute('data-abierto', '0');
                if (!btn) continue;
                if (tieneHijos) {
                    btn.classList.add('is-parent');
                    btn.classList.remove('is-open');
                    rows[i].classList.add('es-padre');
                    (function (idx, lvl, r, b) {
                        b.onclick = function (ev) { ev.stopPropagation(); sigmaTogglePaso(rows, idx, lvl, r, b); };
                        r.style.cursor = 'pointer';
                        r.onclick = function (ev) {
                            var t = ev.target;
                            if (t.closest && t.closest('a, input, .icono_Editar, .rgSelect')) return;
                            sigmaTogglePaso(rows, idx, lvl, r, b);
                        };
                    })(i, nivel, rows[i], btn);
                } else {
                    btn.classList.remove('is-parent', 'is-open');
                    rows[i].classList.remove('es-padre');
                }
            }
        }
        function sigmaTogglePaso(rows, idx, nivel, row, btn) {
            var abrir = row.getAttribute('data-abierto') !== '1';
            row.setAttribute('data-abierto', abrir ? '1' : '0');
            btn.classList.toggle('is-open', abrir);
            for (var j = idx + 1; j < rows.length; j++) {
                var n = parseInt(rows[j].getAttribute('data-nivel'), 10);
                if (n <= nivel) break;
                rows[j].style.display = abrir ? 'table-row' : 'none';
            }
        }
        if (window.Sys && Sys.WebForms && Sys.WebForms.PageRequestManager) {
            Sys.WebForms.PageRequestManager.getInstance().add_endRequest(function () { window.setTimeout(sigmaArbolPasos, 60); });
        }
        if (document.addEventListener) document.addEventListener('DOMContentLoaded', function () { window.setTimeout(sigmaArbolPasos, 120); });
        window.setTimeout(sigmaArbolPasos, 400);
    </script>
    <style type="text/css">
        /* Colapsado desde el render (evita el parpadeo): los pasos (nivel 2)
           nacen ocultos por CSS; el JS los muestra con display:table-row al abrir. */
        tr[data-nivel]:not([data-nivel="1"]) { display: none; }
        /* El árbol crece al desplegar: la grilla no debe recortar en alto. */
        .sgx-page .RadGrid { overflow-y: visible !important; height: auto !important; }
        .sgx-page .RadGrid .rgDataDiv,
        .sgx-page .RadGrid .rgMasterTable { height: auto !important; max-height: none !important; overflow: visible !important; }

        .sigma-tree-item { display: flex; align-items: center; gap: 6px; }
        .sigma-tree-elbow { width: 18px; height: 16px; flex: 0 0 auto; border-left: 2px solid #c7d2fe; border-bottom: 2px solid #c7d2fe; border-bottom-left-radius: 8px; margin: -10px 2px 0 6px; align-self: flex-start; }
        .sigma-tree-btn { width: 28px; height: 28px; flex: 0 0 auto; display: inline-flex; align-items: center; justify-content: center; border-radius: 8px; color: transparent; font-size: 14px; vertical-align: middle; margin-right: 4px; }
        .sigma-tree-btn.is-parent { cursor: pointer; color: #6C5CFF; border: 1.5px solid #ddd6fe; background: #f5f3ff; transition: background .12s ease, border-color .12s ease; }
        .sigma-tree-btn.is-parent:hover { background: #ede9fe; border-color: #c4b5fd; }
        .sigma-tree-btn.is-parent::before { content: '\25B8'; }        /* ▸ */
        .sigma-tree-btn.is-parent.is-open::before { content: '\25BE'; } /* ▾ */
        .sigma-tree-nom { font-weight: 500; color: #0f172a; }
        .sigma-grp { font-weight: 500; }
        tr.es-padre > td { background: #eee9fe !important; }
        tr[data-nivel="2"]:not(.es-padre) > td { background: #f1f5f9 !important; }
        tr.es-padre > td:first-child input[type="checkbox"] { display: none; }
    </style>
</asp:Content>

<asp:Content ID="ContentEyebrow" ContentPlaceHolderID="cphEyebrow" runat="Server">Mantenimiento</asp:Content>
<asp:Content ID="ContentTitulo" ContentPlaceHolderID="cphTitulo" runat="Server">Pasos de procedimiento</asp:Content>
<asp:Content ID="ContentSubtitulo" ContentPlaceHolderID="cphSubtitulo" runat="Server">
    El detalle paso a paso de cada procedimiento: qué hacer y en qué orden. Elija un procedimiento para ver y ordenar sus pasos.
</asp:Content>

<asp:Content ID="ContentFiltro" ContentPlaceHolderID="cphFiltro" runat="Server">
    <wuc:Filtro runat="server" ID="wucFiltro">
        <FiltroPersonalizado>
            <div class="row col-lg-12 col-md-12 col-xs-12">
                <div class="col-lg-6 col-md-6 col-xs-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboProcedimiento" style="margin: 0; white-space: nowrap;">Procedimiento:</label>
                    <rad:RadComboBox2 ID="cboProcedimiento" runat="server" Width="320px" Filter="Contains" AutoPostBack="true"
                        OnSelectedIndexChanged="cboProcedimiento_SelectedIndexChanged" />
                </div>
                <div class="col-lg-4 col-md-4 col-xs-12 d-flex align-items-center" style="gap: 12px;">
                    <label for="cboHabilitado" style="margin: 0; white-space: nowrap;">Habilitado:</label>
                    <rad:RadComboBox2 ID="cboHabilitado" runat="server" Width="150px">
                        <Items>
                            <rad:RadComboBoxItem Text="Todos" Value="" />
                            <rad:RadComboBoxItem Text="Si" Value="1" />
                            <rad:RadComboBoxItem Text="No" Value="0" />
                        </Items>
                    </rad:RadComboBox2>
                </div>
            </div>
        </FiltroPersonalizado>
    </wuc:Filtro>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="Server">
    <asp:Panel ID="pnlSinCliente" runat="server" Visible="false" CssClass="card-box">
        <p>Seleccione un cliente en el encabezado para trabajar con sus procedimientos.</p>
    </asp:Panel>

    <asp:UpdatePanel runat="server" ID="udPanel" UpdateMode="Conditional">
        <ContentTemplate>
            <rad:RadGrid2 ID="Grid" runat="server" OnItemDataBound="rgrPasos_ItemDataBound">
                <MasterTableView CommandItemDisplay="Top" DataKeyNames="ppa_id">
                    <CommandItemTemplate>
                        <div style="margin-bottom: 5px;">
                            <asp:LinkButton ID="lnkNuevo" runat="server" Text="Nuevo" CssClass="icono_guardar" OnClientClick="return abrirPasoNuevo();" />
                            <asp:LinkButton ID="lnkEliminar" runat="server" Text="Dar de baja" CssClass="icono_eliminar" OnClick="lnkEliminar_Click"
                                OnClientClick="return ConfirSweetAlert(this, '', '¿Está seguro que desea dar de baja los pasos seleccionados?');" />
                        </div>
                    </CommandItemTemplate>
                </MasterTableView>
            </rad:RadGrid2>
        </ContentTemplate>
    </asp:UpdatePanel>
</asp:Content>
