<%@ Page Language="C#" AutoEventWireup="true" CodeFile="OrdenTrabajoImprimir.aspx.cs" Inherits="View_Mantenimiento_Ordenes_OrdenTrabajoImprimir" EnableViewState="false" %>
<!DOCTYPE html>
<%-- HU-125 · La orden en papel, en el formato de la planta: encabezado del cliente, datos,
     pasos, repuestos, mano de obra, servicios, resultado del cierre y firmas.
     Se abre en una pestaña desde la ficha de la OT y lanza la impresión sola (un clic). --%>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= Titulo %></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;600;700;800&display=swap" rel="stylesheet">
    <style>
        :root {
            --sigma-purple: #6732F4; --sigma-purple-soft: #F2EFFF; --sigma-cyan: #16C6C9; --sigma-cyan-dark: #007F8A;
            --ink: #17223B; --muted: #68738A; --line: #E2E7F0; --surface: #FFFFFF; --canvas: #F4F6FA;
            --success: #16855B; --warning: #B65C00; --danger: #C7352B;
        }
        * { box-sizing: border-box; }
        body { margin: 0; background: var(--canvas); color: var(--ink); font: 12px/1.45 Manrope, system-ui, sans-serif; }
        .bar { position: sticky; top: 0; display: flex; gap: 10px; align-items: center; justify-content: flex-end; padding: 10px 16px; background: var(--surface); border-bottom: 1px solid var(--line); }
        .bar span { margin-right: auto; color: var(--muted); font-weight: 700; }
        .btn { border: 0; border-radius: 10px; padding: 9px 16px; font: 700 13px Manrope, sans-serif; cursor: pointer; }
        .btn-pri { background: var(--sigma-purple); color: #fff; }
        .btn-ghost { background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .hoja { width: 210mm; min-height: 297mm; margin: 16px auto; padding: 14mm 14mm 12mm; background: var(--surface); border: 1px solid var(--line); border-radius: 14px; }
        .cab { display: flex; gap: 16px; align-items: center; border-bottom: 2px solid var(--ink); padding-bottom: 10px; }
        .cab img { max-height: 54px; max-width: 160px; object-fit: contain; }
        .cab .cli { flex: 1; }
        .cab .cli b { font-size: 15px; display: block; }
        .cab .cli small, .cab .ot small { color: var(--muted); }
        .cab .ot { text-align: right; }
        .cab .ot b { font-size: 20px; display: block; letter-spacing: .5px; }
        h1 { font-size: 16px; margin: 14px 0 4px; }
        h2 { font-size: 11px; text-transform: uppercase; letter-spacing: .8px; color: var(--muted); margin: 16px 0 6px; border-bottom: 1px solid var(--line); padding-bottom: 4px; }
        .grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 6px 14px; }
        .grid div span { display: block; font-size: 9.5px; font-weight: 800; color: var(--muted); text-transform: uppercase; letter-spacing: .5px; }
        .grid div b { font-weight: 700; }
        .chip { display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: 10px; font-weight: 800; background: var(--sigma-purple-soft); color: var(--sigma-purple); }
        .chip.ok { background: #E7F5EE; color: var(--success); } .chip.w { background: #FDF1E4; color: var(--warning); }
        table { width: 100%; border-collapse: collapse; }
        th { text-align: left; font-size: 9.5px; text-transform: uppercase; letter-spacing: .5px; color: var(--muted); border-bottom: 1px solid var(--line); padding: 4px 6px; }
        td { border-bottom: 1px solid var(--line); padding: 5px 6px; vertical-align: top; }
        td.n, th.n { text-align: right; white-space: nowrap; }
        .vacio { color: var(--muted); font-style: italic; padding: 6px 0; }
        .tot { display: flex; gap: 8px; justify-content: flex-end; margin-top: 6px; flex-wrap: wrap; }
        .tot b { border: 1px solid var(--line); border-radius: 8px; padding: 4px 10px; }
        .texto { white-space: pre-wrap; border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px; min-height: 36px; }
        .firmas { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; margin-top: 8px; }
        .firma { border: 1px solid var(--line); border-radius: 8px; padding: 8px; text-align: center; min-height: 110px; display: flex; flex-direction: column; justify-content: flex-end; }
        .firma img { max-height: 60px; max-width: 100%; object-fit: contain; margin: 0 auto 4px; }
        .firma i { display: block; border-top: 1px solid var(--ink); margin: 40px 6px 4px; }
        .firma b { font-size: 11px; } .firma small { color: var(--muted); display: block; }
        .pie { margin-top: 14px; color: var(--muted); font-size: 9.5px; display: flex; justify-content: space-between; }
        @media (max-width: 860px) { .hoja { width: auto; margin: 16px; padding: 16px; } .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } .firmas { grid-template-columns: 1fr; } }
        @media print {
            @page { size: A4; margin: 10mm; }
            body { background: #fff; }
            .bar { display: none; }
            .hoja { width: auto; min-height: 0; margin: 0; padding: 0; border: 0; border-radius: 0; }
            tr, .firma { page-break-inside: avoid; }
        }
    </style>
</head>
<body>
    <% if (!string.IsNullOrEmpty(Falla)) { %>
        <div class="hoja"><h1>No se pudo preparar la orden</h1><p><%= H(Falla) %></p></div>
    <% } else { %>
    <div class="bar">
        <span><%= H(Titulo) %></span>
        <button type="button" class="btn btn-ghost" onclick="window.close()">Cerrar</button>
        <button type="button" class="btn btn-pri" onclick="window.print()">Imprimir</button>
    </div>
    <article class="hoja">
        <%= Cuerpo %>
    </article>
    <script>
        /* Un clic: la ficha abre esta pestaña y el diálogo de impresión aparece solo cuando cargó el logo. */
        window.addEventListener('load', function () { if (!/[?&]sinDialogo=1/.test(location.search)) setTimeout(function () { window.print(); }, 250); });
    </script>
    <% } %>
</body>
</html>
