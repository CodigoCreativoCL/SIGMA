<%@ Page Language="C#" MasterPageFile="~/Master/Simple.master" AutoEventWireup="true" CodeFile="ClasificarRepuestos.aspx.cs" Inherits="View_Inventario_Repuestos_ClasificarRepuestos" %>

<%-- Clasificar repuestos (06-10-2026).

     Un modal simple, como los de la ficha rápida del activo: marcar los
     repuestos, elegir el tipo y asignar. Antes abría el listado clásico entero
     (con el menú y el encabezado del sitio) dentro del modal. --%>

<asp:Content ID="ContentHeder" ContentPlaceHolderID="cphHeder" runat="server">
    <script type="text/javascript">
        function getRadWindow() {
            var oWindow = null;
            if (window.radWindow) oWindow = window.radWindow;
            else if (window.frameElement.radWindow) oWindow = window.frameElement.radWindow;
            return oWindow;
        }
        function closeWindow() {
            var w = getRadWindow();
            if (w.BrowserWindow.refresh) w.BrowserWindow.refresh();
            w.close();
        }
    </script>
    <style type="text/css">
        .cl { --purple: #6732F4; --purple-soft: #F2EFFF; --ink: #17223B; --muted: #68738A; --line: #E2E7F0; --canvas: #F4F6FA; --ok: #16855B; display: flex; flex-direction: column; gap: 12px; font-family: inherit; color: var(--ink) }
        .cl-barra { display: flex; flex-wrap: wrap; gap: 10px; align-items: center }
        .cl-q { flex: 1 1 240px; display: flex; align-items: center; gap: 8px; height: 42px; padding: 0 12px; border: 1px solid #CFD6E3; border-radius: 9px; background: #fff; color: var(--muted) }
        .cl-q input { flex: 1; min-width: 0; border: 0; outline: 0; font-size: 14px; color: var(--ink); background: transparent }
        .cl-q:focus-within { border-color: #007F8A; outline: 3px solid rgba(22,198,201,.27) }
        .cl-chip { height: 42px; padding: 0 14px; border: 1px solid var(--line); border-radius: 9px; background: #fff; font-size: 13px; font-weight: 700; color: var(--ink); cursor: pointer }
        .cl-chip[aria-pressed="true"] { background: var(--purple-soft); border-color: var(--purple); color: var(--purple) }
        .cl-lista { border: 1px solid var(--line); border-radius: 12px; max-height: 360px; overflow: auto; background: #fff }
        .cl-fila { display: grid; grid-template-columns: 28px minmax(0, 1fr) 150px; gap: 10px; align-items: center; padding: 8px 12px; border-top: 1px solid var(--line); font-size: 13px; cursor: pointer }
        .cl-fila:first-child { border-top: 0 }
        .cl-fila:hover { background: var(--canvas) }
        .cl-fila input { width: 16px; height: 16px; accent-color: var(--purple) }
        .cl-fila b { display: block; font-weight: 800 }
        .cl-fila small { color: var(--muted) }
        .cl-tipo { justify-self: end; font-size: 11px; font-weight: 800; padding: 3px 10px; border-radius: 999px; background: var(--purple-soft); color: var(--purple); white-space: nowrap; max-width: 150px; overflow: hidden; text-overflow: ellipsis }
        .cl-tipo.es-vacio { background: #EEF1F6; color: var(--muted) }
        .cl-pie { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; padding: 12px; border-radius: 12px; background: var(--canvas) }
        .cl-pie > span { font-size: 13px; font-weight: 700 }
        .cl-pie select { height: 42px; min-width: 220px; padding: 0 10px; border: 1px solid #CFD6E3; border-radius: 9px; background: #fff; font-size: 14px }
        .cl-pie .sp { flex: 1 }
        .cl-btn { height: 42px; padding: 0 18px; border: 0; border-radius: 9px; font-size: 13px; font-weight: 700; cursor: pointer }
        .cl-btn.es-primario { background: var(--purple); color: #fff }
        .cl-btn.es-primario:disabled { opacity: .42; cursor: not-allowed }
        .cl-btn.es-ghost { background: var(--purple-soft); color: var(--purple) }
        .cl-ok { padding: 10px 14px; border-radius: 10px; background: #E7F5EE; color: #12704C; font-size: 13px; font-weight: 700 }
        .cl-vacio { padding: 26px; text-align: center; color: var(--muted); font-size: 13px }
    </style>
</asp:Content>

<asp:Content ID="ContentBody" ContentPlaceHolderID="cphBody" runat="server">
    <div class="cl">
        <asp:Literal ID="litOk" runat="server" />
        <div class="cl-barra">
            <label class="cl-q"><i class="mdi mdi-magnify"></i><input type="text" id="clQ" placeholder="Busca por código, nombre o fabricante…" autocomplete="off" /></label>
            <button type="button" class="cl-chip" id="clSin" aria-pressed="false">Solo sin clasificar</button>
        </div>
        <div class="cl-lista" id="clLista"><asp:Literal ID="litLista" runat="server" /></div>
        <div class="cl-pie">
            <span id="clMarcados">0 marcados</span>
            <button type="button" class="cl-chip" id="clTodos">Marcar los visibles</button>
            <span class="sp"></span>
            <span>Asignarles el tipo</span>
            <select id="selTipo" runat="server" clientidmode="Static"></select>
            <asp:HiddenField ID="hdnIds" runat="server" ClientIDMode="Static" />
            <asp:Button ID="btnAsignar" runat="server" CssClass="cl-btn es-primario" Text="Asignar" OnClick="btnAsignar_Click" OnClientClick="return clAntes();" ClientIDMode="Static" />
            <button type="button" class="cl-btn es-ghost" onclick="closeWindow(); return false;">Cerrar</button>
        </div>
    </div>
    <script type="text/javascript">
        (function () {
            var filas = [].slice.call(document.querySelectorAll('.cl-fila'));
            var q = document.getElementById('clQ'), sin = document.getElementById('clSin');
            function norm(s) { return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
            function visible(f) { return f.style.display !== 'none'; }
            function contar() {
                var n = filas.filter(function (f) { return f.querySelector('input').checked; }).length;
                document.getElementById('clMarcados').textContent = n + (n === 1 ? ' marcado' : ' marcados');
                document.getElementById('btnAsignar').disabled = n === 0;
            }
            function filtrar() {
                var t = norm(q.value), solo = sin.getAttribute('aria-pressed') === 'true', v = 0;
                filas.forEach(function (f) {
                    var ok = (!t || norm(f.getAttribute('data-t')).indexOf(t) >= 0) && (!solo || f.getAttribute('data-sin') === '1');
                    f.style.display = ok ? '' : 'none'; if (ok) v++;
                });
                var vac = document.getElementById('clVacio'); if (vac) vac.style.display = v ? 'none' : '';
            }
            q.addEventListener('input', filtrar);
            sin.addEventListener('click', function () { sin.setAttribute('aria-pressed', String(sin.getAttribute('aria-pressed') !== 'true')); filtrar(); });
            document.getElementById('clTodos').addEventListener('click', function () {
                var vis = filas.filter(visible), todos = vis.every(function (f) { return f.querySelector('input').checked; });
                vis.forEach(function (f) { f.querySelector('input').checked = !todos; }); contar();
            });
            document.getElementById('clLista').addEventListener('change', contar);
            window.clAntes = function () {
                document.getElementById('hdnIds').value = filas.filter(function (f) { return f.querySelector('input').checked; })
                    .map(function (f) { return f.getAttribute('data-id'); }).join(',');
                return true;
            };
            contar();
        })();
    </script>
</asp:Content>
