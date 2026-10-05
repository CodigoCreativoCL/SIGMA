/* ============================================================================
   SIGMA · CENTRO DE ACTIVOS — VISTAS DE LA PLANTA (rediseño 05-10-2026)

   Lista (E1), Tarjetas (E2), Mapa por áreas y Vista 3D (E3), Navegador de
   ubicaciones y Explorador del activo (E4). El comportamiento sale de
   docs/rediseno-activos/sigma-activos-referencia.html, la unica referencia de
   estas vistas; aqui los datos son los de SIGMA.

   DE DONDE SALEN LOS DATOS
     WsActivos.asmx/Planta devuelve la planta en la misma forma que dibujaba
     la referencia (lugares en arbol, activos con su portada, subactivos,
     componentes y repuestos con stock).

   COMO SE GUARDA LO QUE SE CAMBIA
     Cada cambio se hace primero en pantalla (commit) y despues SYNC compara
     el antes con el ahora y manda al servidor lo que cambio, en orden: tipos
     de lugar nuevos, lugares quitados, nuevos o renombrados, orden entre
     hermanos, ubicacion de los activos y fotos. «Deshacer» vuelve al antes y
     SYNC manda el camino de vuelta. Si el servidor rechaza algo, se avisa y
     se recarga la planta tal como quedo en la base.

   LO QUE EN LA REFERENCIA ERA SIMULADO, EN SIGMA ES REAL
     «+ Nuevo activo» abre la ficha de 6 pasos (abrirActivo), «Abrir 360°» el
     centro del activo, «Crear OT» la nueva OT, «+ Agregar componente» la
     ficha del componente, y cambiar un estado pide el motivo (como la ficha).

   three.js se carga bajo demanda (import dinamico, con el importmap de la
   pagina); GSAP con Flip y Draggable va en Js/gsap.
   ========================================================================= */
(function(){
'use strict';
const CFG = window.SIGMA_PLANTA || {};
const WS = CFG.ws || '/WebService/WsActivos.asmx';
const KEY = 'sigma-activos-planta';
const abierto = sel => { const e = document.querySelector(sel); return !!e && !e.hidden; };
let S = null;

/* ---- servidor ---- */
async function ws(metodo, datos){
  let r;
  try {
    r = await fetch(WS + '/' + metodo, { method:'POST', credentials:'same-origin',
      headers:{'Content-Type':'application/json; charset=utf-8'}, body:JSON.stringify(datos || {}) });
  } catch(e){ throw new Error('No hay conexión con SIGMA. Revisa tu internet.'); }
  if (!r.ok) throw new Error('SIGMA no respondió (' + r.status + '). Intenta de nuevo.');
  const j = await r.json();
  const d = typeof j.d === 'string' ? JSON.parse(j.d) : j.d;
  if (d && d.sesion){ location.reload(); throw new Error('La sesión expiró.'); }
  if (d && d.error) throw new Error(d.detalle || 'No se pudo guardar el cambio.');
  return d;
}
const num = id => +String(id).replace(/^\D+/, '');
const esTemp = id => /^(ul|tl)/.test(String(id));
/* Hasta tres miniaturas superpuestas (fotos de subactivos, componentes o repuestos). */
const miniFotos = fs => { const v = (fs || []).filter(Boolean); return v.length ? `<span class="nrow-fotos">${v.slice(0, 3).map(u => `<img src="${String(u).replace(/"/g, '&quot;')}" alt="" loading="lazy">`).join('')}</span>` : ''; };
const tipoN = a => (a && a.tipoNombre) || (typeof TIPOS !== 'undefined' && TIPOS[a.tipo]) || 'Otro';

async function cargarPlanta(planta){
  const d = await ws('Planta', {planta: planta || 0});
  if (d.vacio){ S = {seq:1000, cfg:{l1:'Área', l2:'Línea'}, planta:d.plantaNombre || '', planta_id:d.planta || 0, plantas:d.plantas || [],
                     tipos:[], raiz:[], lugares:{}, tray:[], activos:{}, estados:{activo:[], comp:[]}, permisos:{}, conteos:{}}; return; }
  S = { seq:1000, cfg:{l1:'Área', l2:'Línea'},
        planta:d.plantaNombre, planta_id:d.planta, plantas:d.plantas,
        tipos:d.tipos, raiz:d.raiz, lugares:d.lugares, tray:d.tray, activos:d.activos,
        estados:d.estados, permisos:d.permisos || {}, urlOt:d.urlOt, conteos:d.conteos || {} };
  Object.values(S.activos).forEach(a => { if (!a.fotos) a.fotos = a.foto ? [a.foto] : []; });
}

/* ---- sincronizar: lo que cambio en pantalla, al servidor ---- */
const SYNC = {
  cola: Promise.resolve(),
  desde(antesTxt){
    const A = JSON.parse(antesTxt), B = JSON.parse(JSON.stringify(S));
    this.cola = this.cola.then(() => sincronizar(A, B)).catch(async err => {
      toast((err && err.message) || 'No se pudo guardar el cambio.');
      try { await SIGMA.recargar(); } catch(e){}
    });
    return this.cola;
  }
};
async function sincronizar(A, B){
  let estructura = false;
  // 1. tipos de lugar nuevos
  const mapT = {};
  for (const t of B.tipos) if (!A.tipos.some(x => x.id === t.id)){
    const r = await ws('GuardarTipoLugar', {singular:t.s, plural:t.p}); mapT[t.id] = 't' + r.id; estructura = true; }
  const realT = id => num(mapT[id] || id);
  // 2. lugares quitados
  for (const id in A.lugares) if (!B.lugares[id] && !esTemp(id)){ await ws('QuitarLugar', {id:num(id)}); estructura = true; }
  // 3. lugares nuevos (el padre antes que el hijo) o renombrados
  const mapL = {}; const orden = [];
  (function rec(ids){ ids.forEach(id => { if (!B.lugares[id]) return; orden.push(id); rec(B.lugares[id].hijos || []); }); })(B.raiz);
  for (const id of orden){
    const b = B.lugares[id], a = A.lugares[id];
    const padre = b.padre ? (mapL[b.padre] || b.padre) : null;
    if (!a || esTemp(id)){
      const r = await ws('GuardarLugar', {id:0, planta:B.planta_id, padre:padre ? num(padre) : 0, tipo:realT(b.tipo), nombre:b.nombre});
      mapL[id] = 'u' + r.id; estructura = true;
    } else if (a.nombre !== b.nombre || a.tipo !== b.tipo){
      await ws('GuardarLugar', {id:num(id), planta:B.planta_id, padre:padre ? num(padre) : 0, tipo:realT(b.tipo), nombre:b.nombre});
    }
  }
  // 4. orden entre hermanos (subir / bajar en el editor de ubicaciones)
  const pares = [[A.raiz, B.raiz]];
  for (const id in B.lugares) if (A.lugares[id]) pares.push([A.lugares[id].hijos || [], B.lugares[id].hijos || []]);
  for (const [x, y] of pares){
    let xs = x.filter(i => y.includes(i)); const ys = y.filter(i => x.includes(i));
    for (let k = 0; k < ys.length; k++){
      if (xs[k] === ys[k]) continue;
      const id = ys[k], desde = xs.indexOf(id);
      for (let s = 0; s < desde - k; s++) await ws('OrdenLugar', {id:num(id), delta:-1});
      xs.splice(desde, 1); xs.splice(k, 0, id);
    }
  }
  // 5. donde esta cada activo (y en que orden dentro de su lugar)
  const ubic = St => { const m = {}; for (const lid in St.lugares) (St.lugares[lid].activos || []).forEach((id, i) => { m[id] = {l:lid, i}; });
                       (St.tray || []).forEach((id, i) => { m[id] = {l:null, i}; }); return m; };
  const ua = ubic(A), ub = ubic(B); const cambiadas = new Set();
  for (const id in ub){ const a = ua[id], b = ub[id]; if (!a || a.l !== b.l || a.i !== b.i) cambiadas.add(b.l || 'tray'); }
  for (const lid of cambiadas){
    const lista = lid === 'tray' ? B.tray : (B.lugares[lid] ? B.lugares[lid].activos : []);
    const real = lid === 'tray' ? 0 : num(mapL[lid] || lid);
    for (let i = 0; i < lista.length; i++){
      const id = lista[i], a = ua[id];
      if (lid === 'tray' && a && a.l === null) continue;   // ya estaba por ubicar
      await ws('MoverActivo', {activo:num(id), lugar:real, posicion:lid === 'tray' ? -1 : i});
    }
  }
  // 6. fotos: nuevas, quitadas y portada
  for (const id in B.activos){
    const a = A.activos[id], b = B.activos[id]; if (!a) continue;
    const fa = a.fotos || [], fb = b.fotos || [];
    const vivo = S.activos[id]; if (!vivo) continue;
    const ids = vivo._fotoIds || (vivo._fotoIds = {});
    for (const u of fb) if (/^data:/.test(u) && !fa.includes(u)){
      const r = await ws('SubirFoto', {activo:num(id), nombre:'foto-' + Date.now() + '.jpg', mime:'image/jpeg', base64:u.split(',')[1], portada:b.foto === u});
      ids[r.url] = r.id;
      vivo.fotos = (vivo.fotos || []).map(x => x === u ? r.url : x);
      if (vivo.foto === u) vivo.foto = r.url;
    }
    for (const u of fa) if (!fb.includes(u) && ids[u]) await ws('QuitarFoto', {activo:num(id), archivo:ids[u]});
    if (b.foto && a.foto !== b.foto && !/^data:/.test(b.foto) && ids[b.foto]) await ws('Portada', {activo:num(id), archivo:ids[b.foto]});
  }
  if (estructura) await SIGMA.recargar();
}

/* ---- las pestañas de catalogo: Variables, Medidores, Tipos y Modelos ----
   Se crean, editan y borran en la misma fila (sin abrir la ficha en un modal):
   son ajustes rapidos. Las lecturas de una variable se abren debajo de su fila.
   Borrar es una baja: la fila sale de la lista y se puede volver a usar desde
   «Ver los que no se usan» (las bajas de SIGMA son logicas). */
const chipUso = a => a ? '<span class="chip chip--ok"><i></i>En uso</span>' : '<span class="chip chip--neutro"><i></i>No se usa</span>';
const dos = (a, b) => `<span class="sa-cat-dos"><b>${esc(a || '—')}</b>${b ? `<small>${esc(b)}</small>` : ''}</span>`;
const campo = (txt, html, ancho) => `<label class="sa-cf${ancho ? ' sa-cf--' + ancho : ''}"><span>${txt}</span>${html}</label>`;
const fijo = (txt, valor) => `<div class="sa-cf sa-cf--fijo"><span>${txt}</span><b>${esc(valor || '—')}</b></div>`;
const numero = (nombre, valor, ph) => `<input type="number" step="any" inputmode="decimal" name="${nombre}" value="${valor == null ? '' : valor}" placeholder="${ph || ''}">`;
const lee = (fila, n) => { const el = fila.querySelector(`[name="${n}"]`); return !el ? '' : el.type === 'checkbox' ? el.checked : el.value.trim(); };
const txtN = v => v == null ? '' : String(v);

/* ---- combo con busqueda: filtra mientras se escribe y, si se permite y no
   existe, ofrece «Crear "lo escrito"». El valor va en un input oculto con el
   name del campo: el id elegido, el texto (listas de texto) o «nuevo:texto». */
const COMBOS = {};
function combo(nombre, lista, sel, o){
  o = o || {};
  const items = (lista || []).map(x => typeof x === 'string' ? {id:x, n:x} : x);
  COMBOS[nombre] = {items, crear:!!o.crear, texto:!!o.texto, vacio:o.vacio || 'Sin coincidencias'};
  const elegido = items.find(x => String(x.id) === String(sel));
  const etiqueta = elegido ? elegido.n : (o.texto ? txtN(sel) : '');
  const valor = elegido ? elegido.id : (o.texto ? txtN(sel) : '');
  return `<span class="sa-combo"><input type="text" role="combobox" aria-autocomplete="list" aria-expanded="false" aria-controls="saComboLista" autocomplete="off" spellcheck="false"
      data-sacombo="${nombre}" value="${esc(etiqueta)}" placeholder="${esc(o.ph || 'Escribe para buscar')}"${o.req ? ' data-req="1"' : ''}>
    <input type="hidden" name="${nombre}" value="${esc(valor)}">
    <button type="button" class="sa-combo-btn" tabindex="-1" aria-label="Ver opciones"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></button></span>`;
}
const CB = { inp:null, act:-1, ops:[] };
function comboLista(){
  let ul = document.getElementById('saComboLista');
  if (!ul){
    ul = document.createElement('ul'); ul.id = 'saComboLista'; ul.className = 'sa-combo-lista'; ul.setAttribute('role', 'listbox'); ul.hidden = true;
    (document.getElementById('saPortal') || document.body).appendChild(ul);
    ul.addEventListener('mousedown', e => e.preventDefault());
    ul.addEventListener('click', e => { const li = e.target.closest('[data-i]'); if (li) comboElegir(+li.dataset.i); });
  }
  return ul;
}
function comboAbrir(inp, todo){
  const def = COMBOS[inp.dataset.sacombo]; if (!def) return;
  CB.inp = inp; const ul = comboLista();
  const txt = inp.value.trim(), q = todo ? '' : norm(txt);
  const hits = def.items.filter(x => !q || norm(x.n + ' ' + (x.txt || '')).includes(q)).slice(0, 60);
  CB.ops = hits.map(x => ({x}));
  if (def.crear && txt && !def.items.some(x => norm(x.n) === norm(txt))) CB.ops.push({crear:txt});
  const marca = s => { if (!q) return esc(s); const i = norm(s).indexOf(q); return i < 0 ? esc(s) : esc(s.slice(0, i)) + '<mark>' + esc(s.slice(i, i + q.length)) + '</mark>' + esc(s.slice(i + q.length)); };
  ul.innerHTML = CB.ops.length ? CB.ops.map((op, i) => op.crear
      ? `<li role="option" id="saCbo${i}" data-i="${i}" class="is-crear"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>Crear «${esc(op.crear)}»</li>`
      : (op.x.sub != null || op.x.img != null)
        ? `<li role="option" id="saCbo${i}" data-i="${i}" class="es-rico"><span class="cb-img">${op.x.img ? `<img src="${esc(op.x.img)}" alt="" loading="lazy">` : '<i></i>'}</span><span class="cb-t"><b>${marca(op.x.n)}</b>${op.x.sub ? `<small>${esc(op.x.sub)}</small>` : ''}</span></li>`
        : `<li role="option" id="saCbo${i}" data-i="${i}">${marca(op.x.n)}</li>`).join('')
    : `<li class="is-vacio" aria-disabled="true">${esc(def.vacio)}</li>`;
  CB.act = CB.ops.length ? 0 : -1;
  const hid = inp.parentNode.querySelector('input[type=hidden]');
  const actual = CB.ops.findIndex(op => op.x && String(op.x.id) === hid.value); if (actual >= 0) CB.act = actual;
  comboMarcar();
  const r = inp.getBoundingClientRect(), abajo = innerHeight - r.bottom;
  ul.style.left = r.left + 'px'; ul.style.width = Math.max(r.width, 220) + 'px';
  if (abajo < 240 && r.top > abajo){ ul.style.top = ''; ul.style.bottom = (innerHeight - r.top + 4) + 'px'; }
  else { ul.style.bottom = ''; ul.style.top = (r.bottom + 4) + 'px'; }
  ul.hidden = false; inp.setAttribute('aria-expanded', 'true');
}
function comboMarcar(){
  const ul = comboLista();
  ul.querySelectorAll('[data-i]').forEach(li => li.classList.toggle('is-activo', +li.dataset.i === CB.act));
  const li = ul.querySelector('.is-activo'); if (li){ li.scrollIntoView({block:'nearest'}); CB.inp.setAttribute('aria-activedescendant', li.id); }
}
function comboCerrar(){
  const ul = document.getElementById('saComboLista'); if (ul) ul.hidden = true;
  if (CB.inp){ CB.inp.setAttribute('aria-expanded', 'false'); CB.inp.removeAttribute('aria-activedescendant'); }
  CB.inp = null; CB.act = -1;
}
function comboElegir(i){
  const inp = CB.inp, op = CB.ops[i]; if (!inp || !op) return;
  const hid = inp.parentNode.querySelector('input[type=hidden]'), def = COMBOS[inp.dataset.sacombo];
  if (op.crear){ inp.value = op.crear; hid.value = def.texto ? op.crear : 'nuevo:' + op.crear; }
  else { inp.value = op.x.n; hid.value = op.x.id; }
  inp.classList.toggle('is-nuevo', !!op.crear);
  comboCerrar();
}
/* Al salir: si lo escrito es una opcion, queda elegida; si no, se crea (si se
   permite) o se vuelve a lo que estaba. */
function comboSalir(inp){
  const def = COMBOS[inp.dataset.sacombo]; if (!def) return;
  const hid = inp.parentNode.querySelector('input[type=hidden]'), txt = inp.value.trim();
  const igual = def.items.find(x => norm(x.n) === norm(txt));
  if (!txt){ hid.value = ''; inp.classList.remove('is-nuevo'); return; }
  if (igual){ inp.value = igual.n; hid.value = igual.id; inp.classList.remove('is-nuevo'); return; }
  if (def.crear){ hid.value = def.texto ? txt : 'nuevo:' + txt; inp.classList.add('is-nuevo'); return; }
  const prev = def.items.find(x => String(x.id) === hid.value); inp.value = prev ? prev.n : '';
}
document.addEventListener('focusin', e => { if (e.target.matches && e.target.matches('.sgap [data-sacombo]')) comboAbrir(e.target, true); });
document.addEventListener('input', e => { if (e.target.matches && e.target.matches('.sgap [data-sacombo]')) comboAbrir(e.target); });
document.addEventListener('focusout', e => { if (e.target.matches && e.target.matches('.sgap [data-sacombo]')){ comboSalir(e.target); if (CB.inp === e.target) comboCerrar(); } });
document.addEventListener('click', e => {
  const b = e.target.closest && e.target.closest('.sgap .sa-combo-btn'); if (!b) return;
  const inp = b.parentNode.querySelector('[data-sacombo]');
  if (CB.inp === inp) comboCerrar(); else { inp.focus(); comboAbrir(inp, true); }
});
document.addEventListener('keydown', e => {
  if (!e.target.matches || !e.target.matches('.sgap [data-sacombo]')) return;
  const ul = document.getElementById('saComboLista'), abierta = ul && !ul.hidden && CB.inp === e.target;
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp'){
    e.preventDefault(); if (!abierta) return comboAbrir(e.target, true);
    if (!CB.ops.length) return;
    CB.act = (CB.act + (e.key === 'ArrowDown' ? 1 : -1) + CB.ops.length) % CB.ops.length; comboMarcar();
  } else if (e.key === 'Enter' && abierta && CB.act >= 0){ e.preventDefault(); e.stopPropagation(); comboElegir(CB.act); }
  else if (e.key === 'Escape' && abierta){ e.preventDefault(); e.stopPropagation(); comboCerrar(); }
  else if (e.key === 'Tab' && abierta && CB.act >= 0 && e.target.value.trim()) comboElegir(CB.act);
}, true);
addEventListener('resize', comboCerrar);
document.addEventListener('scroll', e => { if (CB.inp && !(e.target.id === 'saComboLista')) comboCerrar(); }, true);

const CAT = {
  variables:{ titulo:'Variables de condición', ayuda:'Lo que se mide para saber cómo está cada activo y entre qué valores es normal.', buscar:'Busca por activo o por lo que se mide…',
    nuevo:'Nueva variable', creado:'Variable creada', vacio:'Todavía no se mide nada', vacioAyuda:'Agrega una variable desde aquí o en el paso «Variables» de la ficha del activo.',
    cab:['Activo','Qué se mide','Normal','Cada','Lecturas','Estado'], cols:'minmax(0,1.6fr) minmax(0,1.4fr) minmax(0,1fr) 72px 84px 120px 250px',
    celdas:f => dos(f.activo, [f.codigo, f.pieza].filter(Boolean).join(' · ')) + dos(f.nombre, f.unidad) + `<span>${esc(f.normal || 'Sin rango')}</span><span>${esc(f.cada || '—')}</span><span class="sa-cat-num">${f.lecturas}</span><span>${chipUso(f.activa)}</span>`,
    extra:f => `<button type="button" class="btn btn--sm" data-cat-serie="${f.id}" aria-expanded="${!!(SIGMA._serie && SIGMA._serie.id === f.id)}">Lecturas</button>`,
    nombre:f => f.nombre + ' de ' + f.activo,
    form:(f, o) => (f.id ? fijo('Activo', f.activo) + fijo('Qué se mide', f.nombre)
                         : campo('Activo', combo('activo', o.activos, 0, {ph:'Busca el activo', req:true, vacio:'Ningún activo se llama así'}), 'ancho') +
                           campo('Qué se mide', combo('que', o.vars, '', {ph:'Ej.: Temperatura', req:true, crear:true, texto:true}))) +
                   campo('Unidad', combo('unidad', o.unidades, f.unidadId || 0, {ph:'Ej.: °C', req:true, vacio:'No hay una unidad así'})) +
                   campo('Normal desde', numero('min', f.minNum, 'Sin mínimo'), 'corto') + campo('hasta', numero('max', f.maxNum, 'Sin máximo'), 'corto') +
                   campo('Medir cada (horas)', numero('horas', f.horas, 'Ej.: 8'), 'corto'),
    datos:(fila, f) => ({ id:f.id || 0, activo:+lee(fila, 'activo') || 0, que:lee(fila, 'que'), unidad:+lee(fila, 'unidad') || 0,
                          min:lee(fila, 'min'), max:lee(fila, 'max'), horas:lee(fila, 'horas'), activa:f.id ? f.activa : true }),
    desde:f => ({ id:f.id, activo:f.activoId, que:'', unidad:f.unidadId, min:txtN(f.minNum), max:txtN(f.maxNum), horas:txtN(f.horas), activa:true }),
    guardar:'GuardarVariable', borrar:'BorrarVariable', borrarTxt:'Deja de medirse. Las lecturas que ya tiene se conservan.' },
  medidores:{ titulo:'Medidores', ayuda:'Lo que cuenta cuánto ha trabajado cada activo: horas, ciclos, kilómetros.', buscar:'Busca por medidor o activo…',
    nuevo:'Nuevo medidor', creado:'Medidor creado', vacio:'Todavía no hay medidores', vacioAyuda:'Agrega uno desde aquí o en el paso «Medidores» de la ficha del activo.',
    cab:['Medidor','Activo','Lectura actual','Estado'], cols:'minmax(0,1.5fr) minmax(0,1.5fr) minmax(0,1fr) 120px 170px',
    celdas:f => dos(f.nombre, f.codigo) + dos(f.activo, f.codActivo) + `<span class="sa-cat-num">${esc(f.valor)} ${esc(f.unidad)}</span><span>${chipUso(f.activa)}</span>`,
    nombre:f => f.nombre,
    form:(f, o) => campo('Qué cuenta', `<input name="nombre" maxlength="120" value="${esc(f.nombre || '')}" placeholder="Ej.: Horómetro" required>`) +
                   campo('Activo', combo('activo', o.activos, f.activoId || 0, {ph:'Busca el activo', req:true, vacio:'Ningún activo se llama así'}), 'ancho') +
                   campo('Unidad', combo('unidad', o.unidades, f.unidadId || 0, {ph:'Ej.: horas', req:true, vacio:'No hay una unidad así'})) +
                   campo('Lectura actual', numero('valor', f.id ? f.valorNum : '', '0'), 'corto'),
    datos:(fila, f) => ({ id:f.id || 0, activo:+lee(fila, 'activo') || 0, nombre:lee(fila, 'nombre'), unidad:+lee(fila, 'unidad') || 0,
                          valor:lee(fila, 'valor'), activa:f.id ? f.activa : true }),
    desde:f => ({ id:f.id, activo:f.activoId, nombre:f.nombre, unidad:f.unidadId, valor:txtN(f.valorNum), activa:true }),
    guardar:'GuardarMedidor', borrar:'BorrarMedidor', borrarTxt:'Sale de la lista. Si tiene lecturas, se conservan.' },
  tipos:{ titulo:'Tipos de activo', ayuda:'Cómo se agrupan los activos: cámaras de frío, hornos, bombas…', buscar:'Busca un tipo…',
    nuevo:'Nuevo tipo', creado:'Tipo creado', vacio:'Todavía no hay tipos de activo', vacioAyuda:'Se crean solos al escribir un tipo nuevo en la ficha del activo.',
    cab:['Tipo','Depende de','De quién es','Estado'], cols:'minmax(0,1.6fr) minmax(0,1.2fr) minmax(0,1fr) 120px 170px',
    celdas:f => dos(f.nombre, f.codigo) + `<span>${esc(f.padre || '—')}</span><span>${esc(f.ambito)}</span><span>${chipUso(f.activa)}</span>`,
    nombre:f => f.nombre,
    form:(f, o) => campo('Nombre del tipo', `<input name="nombre" maxlength="120" value="${esc(f.nombre || '')}" placeholder="Ej.: Cámara de frío" required>`, 'ancho') +
                   campo('Depende de (opcional)', combo('padre', (o.tipos || []).filter(t => t.id !== f.id), f.padreId || 0, {ph:'No depende de otro', crear:true}), 'ancho'),
    datos:(fila, f) => ({ id:f.id || 0, nombre:lee(fila, 'nombre'), padre:+lee(fila, 'padre') || 0, activa:f.id ? f.activa : true }),
    desde:f => ({ id:f.id, nombre:f.nombre, padre:f.padreId || 0, activa:true }),
    guardar:'GuardarTipo', borrar:'BorrarTipo', borrarTxt:'No se puede si algún activo, modelo o subtipo lo usa.' },
  modelos:{ titulo:'Modelos', ayuda:'La marca y el modelo de cada tipo de activo.', buscar:'Busca por marca, modelo o tipo…',
    nuevo:'Nuevo modelo', creado:'Modelo creado', vacio:'Todavía no hay modelos', vacioAyuda:'Se crean solos al escribir un modelo nuevo en la ficha del activo.',
    cab:['Modelo','Tipo de activo','De quién es','Estado'], cols:'minmax(0,1.6fr) minmax(0,1.2fr) minmax(0,1fr) 120px 170px',
    celdas:f => dos(f.nombre, f.marca) + `<span>${esc(f.tipo || '—')}</span><span>${esc(f.ambito)}</span><span>${chipUso(f.activa)}</span>`,
    nombre:f => [f.marca, f.nombre].filter(Boolean).join(' '),
    form:(f, o) => campo('Marca', combo('marca', o.marcas, f.marca || '', {ph:'Ej.: Grundfos', crear:true, texto:true})) +
                   campo('Modelo', `<input name="nombre" maxlength="120" value="${esc(f.nombre || '')}" placeholder="Ej.: DDA 7.5-16" required>`) +
                   campo('Tipo de activo', combo('tipo', o.tipos, f.tipoId || 0, {ph:'Busca o crea el tipo', req:true, crear:true}), 'ancho'),
    datos:(fila, f) => ({ id:f.id || 0, tipo:+lee(fila, 'tipo') || 0, marca:lee(fila, 'marca'), nombre:lee(fila, 'nombre'), activa:f.id ? f.activa : true }),
    desde:f => ({ id:f.id, tipo:f.tipoId, marca:f.marca, nombre:f.nombre, activa:true }),
    guardar:'GuardarModelo', borrar:'BorrarModelo', borrarTxt:'No se puede si algún activo, plan o repuesto lo usa.' }
};

/* ---- puente con el resto de SIGMA ---- */
const SIGMA = {
  nuevoActivo(){ if (window.abrirActivo) window.abrirActivo(0); },
  abrir360(id){ const a = S.activos[id]; if (a && a.url360) location.href = a.url360; },
  nuevaOT(){ if (S.urlOt) location.href = S.urlOt; },
  /* Importar y la plantilla abren la carga masiva (ahi se descarga la plantilla); exportar baja el Excel. */
  importarExportar(que){
    if (que === 'export'){ const l = document.getElementById(CFG.exportar); if (l) l.click(); return; }
    if (window.abrirCargaMasiva) window.abrirCargaMasiva();
  },
  nuevoComponente(id){
    const a = S.activos[id]; if (!a || !window.SigmaModal) return;
    window.SigmaModal.open({ url:CFG.urlComponente + '?query=' + a.qComp, title:'Nuevo componente de ' + a.nombre, width:1040, initialHeight:620 });
  },
  /* Cambiar el estado pide decir por que, como en la ficha: queda en la historia. */
  pedirMotivo(kind, id, idx, select){
    const a = S.activos[id]; if (!a) return;
    const c = kind === 'comp' ? a.comps[idx] : null;
    const antes = kind === 'comp' ? c.e : a.estado; const nuevo = select.value;
    select.value = antes;
    const lista = (S.estados[kind === 'comp' ? 'comp' : 'activo'] || []);
    const est = lista.find(x => x.k === nuevo) || lista[0]; if (!est) return;
    const quien = kind === 'comp' ? c.n : a.nombre;
    const caja = document.createElement('div');
    caja.className = 'sa-motivo'; caja.setAttribute('role', 'dialog'); caja.setAttribute('aria-modal', 'true'); caja.setAttribute('aria-labelledby', 'saMotivoTit');
    caja.innerHTML = `<div class="sa-motivo-caja"><h3 id="saMotivoTit">¿Por qué cambia el estado?</h3>
      <p><b></b> pasará a <span class="chip chip--${EST[nuevo] ? EST[nuevo].t : 'ok'}"><i></i></span>. Queda en su historia con la fecha y quién lo cambió.</p>
      <label for="saMotivoTxt">Motivo</label><textarea id="saMotivoTxt" rows="3" maxlength="500" placeholder="Ej.: se cambió la válvula y quedó funcionando"></textarea>
      <p class="sa-motivo-err" hidden>Escribe el motivo para poder guardar.</p>
      <div class="sa-motivo-pie"><button type="button" class="btn btn--ghost" data-m="no">Cancelar</button><button type="button" class="btn btn--primary" data-m="si">Guardar el cambio</button></div></div>`;
    caja.querySelector('b').textContent = quien; caja.querySelector('.chip').append(est.n);
    (document.getElementById('saPortal') || document.body).appendChild(caja);
    const txt = caja.querySelector('textarea'); setTimeout(() => txt.focus(), 30);
    const cerrar = () => { caja.remove(); select.focus(); };
    caja.addEventListener('keydown', e => { if (e.key === 'Escape') cerrar(); });
    caja.addEventListener('click', async e => {
      const b = e.target.closest('[data-m]'); if (!b) return;
      if (b.dataset.m === 'no') return cerrar();
      const m = txt.value.trim(); if (!m){ caja.querySelector('.sa-motivo-err').hidden = false; txt.focus(); return; }
      b.disabled = true;
      try {
        if (kind === 'comp') await ws('EstadoComponente', {componente:c.id, estado:est.id, motivo:m});
        else await ws('EstadoActivo', {activo:num(id), estado:est.id, motivo:m});
        if (kind === 'comp'){ c.e = nuevo; c.en = est.n; } else { a.estado = nuevo; a.estadoNombre = est.n; }
        caja.remove(); render(); if (abierto('#xp')) renderXP(false); if (view === 'lista' || view === 'tarjetas') renderCurrent(); if (view === '3d' && three) build3D(false);
        toast(`${quien}: ${est.n.toLowerCase()}`);
      } catch(err){ b.disabled = false; caja.querySelector('.sa-motivo-err').textContent = err.message; caja.querySelector('.sa-motivo-err').hidden = false; }
    });
  },
  /* Pestañas del modulo: Activos, Componentes, Variables, Medidores, Tipos y Modelos */
  pestana(k){
    document.querySelectorAll('#mtabs [data-mtab]').forEach(b => {
      const on = b.dataset.mtab === k; b.setAttribute('aria-selected', on); if (on) b.setAttribute('aria-current', 'page'); else b.removeAttribute('aria-current'); });
    document.querySelectorAll('[data-mpanel]').forEach(p => { p.hidden = p.dataset.mpanel !== k; });
    SIGMA.tab = k;
    if (CAT[k]) SIGMA.catalogo(k);
  },
  /* Variables, Medidores, Tipos y Modelos: listas propias, sin grilla del
     servidor. Crear, editar y borrar pasan en la misma fila. */
  async catalogo(k, forzar){
    const host = document.querySelector(`[data-mpanel="${k}"] .sa-cat`); if (!host) return;
    const c = CAT[k];
    if (!host.dataset.listo){
      host.dataset.listo = '1';
      host.innerHTML = `<div class="sa-cat-bar"><div class="sa-cat-tit"><h2>${c.titulo}</h2><p>${c.ayuda}</p></div>
        <label class="sa-cat-buscar"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
        <input type="search" placeholder="${c.buscar}" aria-label="${c.buscar}" autocomplete="off"></label>
        <button type="button" class="chipbtn" data-cat="bajas" aria-pressed="false" hidden>No se usan</button>
        <button type="button" class="btn btn--primary" data-cat-nuevo hidden>+ ${c.nuevo}</button></div>
        <div class="sa-cat-lista" aria-live="polite"><p class="sa-cat-vacio">Cargando…</p></div>`;
      host.querySelector('input').addEventListener('input', () => SIGMA.pintarCatalogo(k));
      host.querySelector('[data-cat-nuevo]').addEventListener('click', () => { SIGMA._edit = {k, id:0}; SIGMA._borrar = null; SIGMA.pintarCatalogo(k); });
      host.addEventListener('click', e => SIGMA.clicCatalogo(k, e));
      host.addEventListener('keydown', e => {
        const fila = e.target.closest('.sa-cat-fila.is-form'); if (!fila) return;
        if (e.key === 'Escape'){ e.preventDefault(); SIGMA._edit = null; SIGMA.pintarCatalogo(k); }
        else if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA'){ e.preventDefault(); SIGMA.guardarCatalogo(k, fila); }
      });
      forzar = true;
    }
    if (!forzar && SIGMA['_cat_' + k]) return SIGMA.pintarCatalogo(k);
    const lista = host.querySelector('.sa-cat-lista');
    try { SIGMA['_cat_' + k] = await ws('Catalogo', {cual:k}); }
    catch(err){ lista.innerHTML = ''; const p = document.createElement('p'); p.className = 'sa-cat-vacio'; p.textContent = err.message; lista.appendChild(p); return; }
    host.querySelector('[data-cat-nuevo]').hidden = !SIGMA['_cat_' + k].editar;
    const n = SIGMA['_cat_' + k].filas.filter(f => f.activa).length, bajas = SIGMA['_cat_' + k].filas.length - n, tab = document.querySelector(`#mtabs [data-mtab="${k}"] .count`);
    if (tab) tab.textContent = n;
    const bb = host.querySelector('[data-cat="bajas"]'); bb.hidden = !bajas; bb.textContent = 'No se usan · ' + bajas;
    if (!bajas){ SIGMA['_bajas_' + k] = false; bb.setAttribute('aria-pressed', 'false'); }
    SIGMA.pintarCatalogo(k);
  },
  pintarCatalogo(k){
    const host = document.querySelector(`[data-mpanel="${k}"] .sa-cat`), d = SIGMA['_cat_' + k]; if (!host || !d) return;
    const c = CAT[k], txt = host.querySelector('input').value.trim(), q = norm(txt);
    const ed = SIGMA._edit && SIGMA._edit.k === k ? SIGMA._edit : null, bo = SIGMA._borrar && SIGMA._borrar.k === k ? SIGMA._borrar : null;
    const se = SIGMA._serie && SIGMA._serie.k === k ? SIGMA._serie : null;
    const verBajas = !!SIGMA['_bajas_' + k];
    const filas = d.filas.filter(f => (verBajas ? !f.activa : f.activa) && (!q || (ed && ed.id === f.id) || norm(Object.values(f).join(' ')).includes(q)));
    const lista = host.querySelector('.sa-cat-lista');
    lista.style.setProperty('--cols', c.cols);
    const form = f => `<div class="sa-cat-fila is-form" data-id="${f.id || 0}" role="group" aria-label="${f.id ? 'Editar ' + esc(c.nombre(f)) : esc(c.nuevo)}">
        <div class="sa-cat-form">${c.form(f, d.opciones || {})}</div>
        <p class="sa-cat-err" role="alert" hidden></p>
        <div class="sa-cat-pie"><button type="button" class="btn btn--ghost" data-cat="cancelar">Cancelar</button>
        <button type="button" class="btn btn--primary" data-cat="guardar">${f.id ? 'Guardar cambios' : 'Crear'}</button></div></div>`;
    const acciones = f => !f.activa ? (d.editar && !f.global ? `<button type="button" class="btn btn--sm btn--outline" data-cat="reactivar" data-id="${f.id}">Volver a usar</button>` : '') :
      (c.extra ? c.extra(f) : '') + (!d.editar || f.global ? (f.global ? '<span class="sa-cat-sigma">De SIGMA</span>' : '') :
        `<button type="button" class="btn btn--sm" data-cat="editar" data-id="${f.id}">Editar</button>
         <button type="button" class="btn btn--sm btn--borrar" data-cat="borrar" data-id="${f.id}" aria-label="Borrar ${esc(c.nombre(f))}">Borrar</button>`);
    const fila = f => {
      if (ed && ed.id === f.id) return form(f);
      if (bo && bo.id === f.id) return `<div class="sa-cat-fila is-borrar" data-id="${f.id}" role="alert">
          <span class="sa-cat-preg"><b>¿Borrar «${esc(c.nombre(f))}»?</b><small>${c.borrarTxt}</small></span>
          <span class="sa-cat-acc"><button type="button" class="btn btn--ghost btn--sm" data-cat="noborrar">Cancelar</button>
          <button type="button" class="btn btn--danger btn--sm" data-cat="siborrar" data-id="${f.id}">Sí, borrar</button></span></div>`;
      return `<div class="sa-cat-fila${se && se.id === f.id ? ' is-abierta' : ''}" data-id="${f.id}">${c.celdas(f)}<span class="sa-cat-acc">${acciones(f)}</span></div>` +
             (se && se.id === f.id ? `<div class="sa-cat-serie" data-serie="${f.id}">${SIGMA.pintarLecturas(se)}</div>` : '');
    };
    let html = (ed && ed.id === 0) ? form({}) : '';
    if (verBajas && !filas.length && !html){ lista.innerHTML = '<div class="sa-cat-vacio"><b>No hay nada dado de baja</b></div>'; return; }
    if (!d.filas.length && !html){ lista.innerHTML = `<div class="sa-cat-vacio"><b>${c.vacio}</b><span>${c.vacioAyuda}</span></div>`; return; }
    if (d.filas.length && !filas.length && !html){ lista.innerHTML = `<div class="sa-cat-vacio"><b>No encontramos «${esc(txt)}»</b><span>Prueba con otra palabra.</span></div>`; return; }
    html += filas.map(fila).join('');
    lista.innerHTML = (filas.length ? `<div class="sa-cat-cab">${c.cab.map(h => `<span>${h}</span>`).join('')}<span></span></div>` : '') + html;
    const abierta = lista.querySelector('.is-form');
    if (abierta){ const p = abierta.querySelector('input:not([type=checkbox]):not([type=hidden]),select'); if (p) setTimeout(() => { p.focus(); if (p.dataset.sacombo) comboCerrar(); }, 20); }
    const conf = lista.querySelector('.is-borrar [data-cat="noborrar"]'); if (conf) setTimeout(() => conf.focus(), 20);
  },
  async clicCatalogo(k, e){
    const b = e.target.closest('[data-cat],[data-cat-serie]'); if (!b) return;
    const d = SIGMA['_cat_' + k]; const id = +(b.dataset.id || b.dataset.catSerie || 0);
    if (b.dataset.catSerie){
      if (SIGMA._serie && SIGMA._serie.k === k && SIGMA._serie.id === id){ SIGMA._serie = null; return SIGMA.pintarCatalogo(k); }
      SIGMA._serie = {k, id, cargando:true, mas:false}; SIGMA.pintarCatalogo(k);
      try { const r = await ws('Lecturas', {variable:id}); if (SIGMA._serie && SIGMA._serie.id === id) Object.assign(SIGMA._serie, {cargando:false, d:r}); }
      catch(err){ if (SIGMA._serie && SIGMA._serie.id === id) Object.assign(SIGMA._serie, {cargando:false, error:err.message}); }
      return SIGMA.pintarCatalogo(k);
    }
    switch (b.dataset.cat){
      case 'editar': SIGMA._edit = {k, id}; SIGMA._borrar = null; break;
      case 'cancelar': SIGMA._edit = null; break;
      case 'borrar': SIGMA._borrar = {k, id}; SIGMA._edit = null; break;
      case 'noborrar': SIGMA._borrar = null; break;
      case 'mas': if (SIGMA._serie) SIGMA._serie.mas = true; break;
      case 'bajas': SIGMA['_bajas_' + k] = !SIGMA['_bajas_' + k]; b.setAttribute('aria-pressed', SIGMA['_bajas_' + k]); SIGMA._edit = null; SIGMA._borrar = null; break;
      case 'reactivar': {
        const f = d.filas.find(x => x.id === id); b.disabled = true;
        try { await ws(CAT[k].guardar, CAT[k].desde(f)); toast(`«${CAT[k].nombre(f)}» vuelve a usarse`); await SIGMA.catalogo(k, true); }
        catch(err){ b.disabled = false; toast(err.message); }
        return;
      }
      case 'guardar': return SIGMA.guardarCatalogo(k, b.closest('.sa-cat-fila'));
      case 'siborrar': {
        const f = d.filas.find(x => x.id === id); b.disabled = true;
        try { await ws(CAT[k].borrar, {id}); SIGMA._borrar = null; toast(`«${CAT[k].nombre(f)}» borrado`); await SIGMA.catalogo(k, true); }
        catch(err){ b.disabled = false; toast(err.message); }
        return;
      }
      default: return;
    }
    SIGMA.pintarCatalogo(k);
  },
  async guardarCatalogo(k, fila){
    const c = CAT[k], d = SIGMA['_cat_' + k], id = +fila.dataset.id;
    const f = id ? d.filas.find(x => x.id === id) : {};
    const err = fila.querySelector('.sa-cat-err'), b = fila.querySelector('[data-cat="guardar"]');
    fila.querySelectorAll('[data-sacombo]').forEach(comboSalir);
    const vacio = el => { const h = el.dataset.sacombo ? el.parentNode.querySelector('input[type=hidden]') : el; return !h.value.trim() || h.value === '0'; };
    const falta = [...fila.querySelectorAll('[required],[data-req]')].find(vacio);
    if (falta){ err.textContent = 'Completa «' + falta.closest('.sa-cf').querySelector('span').textContent + '».'; err.hidden = false; falta.focus(); return; }
    err.hidden = true; b.disabled = true;
    try {
      /* Un tipo escrito en el combo que no existia se crea primero. */
      for (const h of fila.querySelectorAll('input[type=hidden]')) if (/^nuevo:/.test(h.value)){
        const r = await ws('GuardarTipo', {id:0, nombre:h.value.slice(6), padre:0, activa:true}); h.value = r.id;
        SIGMA._cat_tipos = null;
      }
      await ws(c.guardar, c.datos(fila, f));
      SIGMA._edit = null; toast(id ? 'Cambios guardados' : c.nuevo.replace(/^Nuev[oa] /, m => m) + ' creado' + (/a$/.test(c.nuevo.split(' ')[0]) ? '' : ''));
      await SIGMA.catalogo(k, true);
    } catch(e){ b.disabled = false; err.textContent = e.message; err.hidden = false; }
  },
  /* Lecturas de una variable, debajo de su fila: resumen, curva y las ultimas. */
  pintarLecturas(se){
    if (se.cargando) return '<p class="sa-serie-msg">Cargando lecturas…</p>';
    if (se.error) return `<p class="sa-serie-msg">${esc(se.error)}</p>`;
    const d = se.d, u = d.unidad ? ' ' + esc(d.unidad) : '', fmt = v => v == null ? '—' : Number(v).toLocaleString('es-CL', {maximumFractionDigits:2});
    if (!d.lecturas.length) return '<p class="sa-serie-msg"><b>Sin lecturas en los últimos 90 días.</b> Se registran desde las OT, los checklists o la app.</p>';
    const pts = d.lecturas.slice().reverse(), vs = pts.map(p => p.v);
    let lo = Math.min(...vs, d.min != null ? d.min : Infinity), hi = Math.max(...vs, d.max != null ? d.max : -Infinity);
    if (lo === hi){ lo -= 1; hi += 1; }
    const W = 520, H = 120, P = 8, x = i => P + (pts.length === 1 ? (W - 2*P)/2 : i * (W - 2*P) / (pts.length - 1)), y = v => H - P - (v - lo) * (H - 2*P) / (hi - lo);
    const banda = (d.min != null || d.max != null) ? `<rect x="0" y="${y(d.max != null ? d.max : hi)}" width="${W}" height="${Math.max(0, y(d.min != null ? d.min : lo) - y(d.max != null ? d.max : hi))}" class="sa-serie-banda"/>` : '';
    const nivel = n => /crit|fuera/i.test(n) ? 'bad' : /adv|aviso/i.test(n) ? 'warn' : 'ok';
    const ver = se.mas ? d.lecturas : d.lecturas.slice(0, 8);
    return `<div class="sa-serie-kpis">
        <span><small>Última</small><b>${fmt(d.resumen.ultimo)}${u}</b></span>
        <span><small>Promedio</small><b>${fmt(d.resumen.promedio)}${u}</b></span>
        <span><small>Normal</small><b>${d.min == null && d.max == null ? 'Sin rango' : fmt(d.min) + ' a ' + fmt(d.max) + u}</b></span>
        <span><small>Lecturas · 90 días</small><b>${d.resumen.puntos}</b></span>
        <span${d.resumen.fuera ? ' class="is-mal"' : ''}><small>Fuera de rango</small><b>${d.resumen.fuera}</b></span></div>
      <svg class="sa-serie-svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="none" role="img" aria-label="Curva de las últimas ${pts.length} lecturas">${banda}
        <polyline points="${pts.map((p, i) => x(i) + ',' + y(p.v)).join(' ')}" class="sa-serie-linea"/>
        ${pts.map((p, i) => `<circle cx="${x(i)}" cy="${y(p.v)}" r="3" class="sa-serie-pt sa-serie-pt--${nivel(p.nivel)}"><title>${esc(p.f)}: ${fmt(p.v)}${u}</title></circle>`).join('')}</svg>
      <ol class="sa-serie-lista">${ver.map(p => `<li><span>${esc(p.f)}</span><b>${fmt(p.v)}${u}</b><span class="chip chip--${nivel(p.nivel)}"><i></i>${esc(p.nivel || 'Normal')}</span><small>${esc([p.quien, p.origen].filter(Boolean).join(' · '))}</small></li>`).join('')}</ol>
      ${!se.mas && d.lecturas.length > 8 ? `<button type="button" class="btn btn--sm" data-cat="mas">Ver las ${d.lecturas.length} últimas</button>` : ''}`;
  },
  /* ---- Repuestos compatibles desde el explorador (bloque 351) ----
     «Le sirve a» todo el activo (o subactivo) o a uno de sus componentes. */
  url(u){ return String(u || '').replace(/^~\//, (CFG.raiz || '/')); },
  async abrirRepuesto(){
    XP.addRep = true;
    if (!SIGMA._reps){
      renderXP(false);
      try { SIGMA._reps = (await ws('Repuestos', {})).filas; }
      catch(err){ XP.addRep = false; toast(err.message); }
    }
    renderXP(false);
    setTimeout(() => { const i = document.querySelector('#formRep [data-sacombo]'); if (i) i.focus(); }, 40);
  },
  formRepuesto(id){
    const a = S.activos[id];
    if (!SIGMA._reps) return '<div class="addrep"><p class="addrep-cargando">Cargando repuestos…</p></div>';
    const ya = new Set((a.reps || []).filter(r => r.vinculo).map(r => r.id + ':' + (r.paraId || 0)));
    const items = SIGMA._reps.map(r => ({ id:r.id, n:r.n, sub:[r.c, r.stock + (r.u ? ' ' + r.u : '') + ' en bodega'].filter(Boolean).join(' · '), img:r.foto || '', txt:r.c }));
    return `<div class="addrep" id="formRep" role="group" aria-label="Agregar repuesto compatible">
      <label class="sa-cf"><span>Repuesto</span>${combo('xprep', items, 0, {ph:'Busca por nombre o código', req:true, vacio:'Ningún repuesto se llama así'})}</label>
      <label class="sa-cf"><span>Le sirve a</span><select id="xpRepPara"><option value="0">Todo ${a.padre ? 'el subactivo' : 'el activo'}</option>${(a.comps || []).map(c => `<option value="${c.id}">${esc(c.n)}</option>`).join('')}</select></label>
      <p class="addrep-err" role="alert" hidden></p>
      <div class="addrep-pie"><button type="button" class="btn btn--ghost btn--sm" data-xp="addrepcancel">Cancelar</button><button type="button" class="btn btn--primary btn--sm" data-xp="addrepok">Agregar</button></div>
    </div>`;
  },
  async vincularRepuesto(b){
    const f = document.getElementById('formRep'); if (!f) return;
    const inp = f.querySelector('[data-sacombo]'); if (inp) comboSalir(inp);
    const rep = +(f.querySelector('input[name="xprep"]').value || 0), para = +f.querySelector('#xpRepPara').value;
    const err = f.querySelector('.addrep-err');
    if (!rep){ err.textContent = 'Elige el repuesto de la lista.'; err.hidden = false; if (inp) inp.focus(); return; }
    b.disabled = true;
    try {
      await ws('VincularRepuesto', {repuesto:rep, activo:para ? 0 : num(curId()), componente:para, observacion:''});
      XP.addRep = false; toast('Repuesto vinculado'); await SIGMA.recargar();
    } catch(e){ b.disabled = false; err.textContent = e.message; err.hidden = false; }
  },
  async quitarRepuesto(b){
    b.disabled = true;
    try { await ws('QuitarVinculoRepuesto', {vinculo:+b.dataset.v}); XP.sel = null; toast('Se quitó el vínculo'); await SIGMA.recargar(); }
    catch(e){ b.disabled = false; toast(e.message); }
  },
  /* La planta que se ve. Con mas de una planta (las asignadas a la persona,
     o todas si no tiene asignacion) se elige en un combo; con una, se muestra. */
  pintarPlantas(){
    const box = document.getElementById('saPlantaSel'); if (!box || !S) return;
    const ps = S.plantas || [];
    box.hidden = !ps.length;
    if (ps.length > 1){
      box.innerHTML = `<label for="saPlantaCombo">Planta</label><select id="saPlantaCombo">${ps.map(p => `<option value="${p.id}"${p.id === S.planta_id ? ' selected' : ''}>${esc(p.nombre)}</option>`).join('')}</select>`;
      box.querySelector('select').onchange = e => SIGMA.cambiarPlanta(+e.target.value);
    } else if (ps.length === 1) box.innerHTML = `<span>Planta</span><b>${esc(ps[0].nombre)}</b>`;
  },
  async cambiarPlanta(id){
    try { localStorage.setItem(KEY + '-planta', id); } catch(e){}
    const caja = document.getElementById('saPlanta');
    if (abierto('#xp')) closeXP();
    MAP.cur = null; MAP.adding = null;
    caja.classList.add('is-cargando'); const w = $('#saCargando'); if (w) w.hidden = false;
    try { await cargarPlanta(id); }
    catch(err){ toast(err.message); }
    caja.classList.remove('is-cargando'); if (w) w.hidden = true;
    caja.classList.toggle('sin-lugares', !(S.permisos && S.permisos.lugares));
    render(); $('#lv').innerHTML = ''; $('#tv').innerHTML = ''; if (view !== '3d') renderCurrent();
    if (view === '3d' && three) build3D(false);
    SIGMA.pintarPlantas();
    toast('Viendo ' + S.planta);
  },
  /* Desde Componentes la ficha cierra con un postback: se vuelve a esa pestaña. */
  recordarPestana(){ try { sessionStorage.setItem(KEY + '-volver', SIGMA.tab || 'activos'); } catch(e){} },
  async cargarThree(){
    if (window.THREE && window.THREE.OrbitControls) return true;
    try {
      const base = CFG.three || '/Js/three/';
      const m = await import(base + 'three.module.min.js');
      const c = await import(base + 'addons/controls/OrbitControls.js');
      window.THREE = Object.assign({}, m, {OrbitControls:c.OrbitControls});
      return true;
    } catch(e){ console.error('[SIGMA 3D]', e); return false; }
  },
  /* Las fotos completas del activo (la planta solo trae la portada). */
  async cargarFotos(id){
    const a = S.activos[id]; if (!a || a._fotosCargadas) return;
    const d = await ws('Fotos', {activo:num(id)});
    a._fotoIds = {}; a.fotos = d.fotos.map(f => { a._fotoIds[f.url] = f.id; return f.url; });
    const p = d.fotos.find(f => f.portada); a.foto = p ? p.url : (a.fotos[0] || null);
    a._fotosCargadas = true;
  },
  async recargar(){
    const xpId = (abierto('#xp') && XP.stack.length) ? curId() : null;
    await cargarPlanta(S ? S.planta_id : 0);
    render(); if (view === 'lista' || view === 'tarjetas'){ $('#lv').innerHTML = ''; $('#tv').innerHTML = ''; renderCurrent(); }
    if (view === '3d' && three) build3D(false);
    if (xpId && S.activos[xpId]) renderXP(false); else if (xpId) closeXP();
    if (abierto('#modalCfg')) renderUb();
  }
};
/* Lo que usa el resto de la pagina: el centro del activo usa el combo y la API en su asistente. */
window.sigmaPlanta = { recargar: () => SIGMA.recargar(), pestana: k => SIGMA.pestana(k), ws, combo, comboSalir };

const hasGsap = !!window.gsap;
if (hasGsap) { try { gsap.registerPlugin(Flip, Draggable); } catch(e){} }
const RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
const SMALL_TOUCH = () => matchMedia('(pointer: coarse) and (max-width: 640px)').matches;
const T = s => RM ? 0 : s;
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm = s => String(s).normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase();
const svg = (p, sz=18) => `<svg width="${sz}" height="${sz}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;

const ICONS = {
  camara:'<rect x="6" y="2.5" width="12" height="19" rx="2"/><path d="M6 10h12M9 5.5v2M9 13v3"/>',
  horno:'<rect x="3" y="4" width="18" height="16" rx="2"/><rect x="6" y="10" width="12" height="7" rx="1"/><path d="M7 7h.01M10 7h.01M13 7h4"/>',
  amasadora:'<path d="M4 11h16a8 8 0 0 1-16 0zM12 3v8M9 5h6"/>',
  bomba:'<circle cx="9" cy="13" r="5"/><path d="M14 13h6M20 10v6M9 8V4h5"/>',
  caldera:'<rect x="6" y="3" width="12" height="18" rx="3"/><path d="M12 9.5c0 1.5-2 2.5-2 4.5a2 2 0 0 0 4 0c0-2-2-3-2-4.5z"/>',
  compresor:'<rect x="3" y="8" width="13" height="10" rx="2"/><path d="M16 11h3v4h-3M7 8V5h5v3M6 18v2M13 18v2"/>',
  dosificador:'<path d="M7 3h10v5l-3 3v9h-4v-9L7 8V3zM7 8h10"/>',
  otro:'<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="6.5"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4"/>'
};
const I = {
  pin:'<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  grip:'<path d="M9 6h.01M9 12h.01M9 18h.01M15 6h.01M15 12h.01M15 18h.01" stroke-width="3"/>',
  alert:'<path d="M12 4L2.8 19.5h18.4L12 4zM12 10v4M12 17h.01"/>',
  check:'<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.5"/>',
  close:'<path d="M6 6l12 12M18 6L6 18"/>',
  camera:'<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
  move:'<path d="M12 3v18M3 12h18M12 3l-3 3M12 3l3 3M12 21l-3-3M12 21l3-3M3 12l3-3M3 12l3 3M21 12l-3-3M21 12l-3 3"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  back:'<path d="M15 6l-6 6 6 6"/>'
};
const TIPOS = {camara:'Cámara de frío',horno:'Horno',amasadora:'Amasadora',bomba:'Bomba',caldera:'Caldera',compresor:'Compresor',dosificador:'Dosificador',otro:'Otro'};
const EST = {operativo:{l:'Operativo',t:'ok'},observacion:{l:'Con observación',t:'warn'},mantenimiento:{l:'En mantenimiento',t:'warn'},detenido:{l:'Detenido',t:'bad'},fuera:{l:'Fuera de servicio',t:'bad'}};
const CRIT = {baja:'Baja',media:'Media',alta:'Alta',critica:'Crítica'};
const AREA_COLORS = ['#6732F4','#087BEA','#007F8A','#4820C9','#0565C2','#16C6C9'];
const comp = (n,e='operativo') => ({n,e});
const RANKT = {bad:0, warn:1, ok:2};

let view = '2d', openId = null, addingArea = false, drags = [];
const MAP = {cur:null, adding:null};

/* ---------- Ubicaciones: árbol libre (cada lugar con su tipo) ---------- */
const low = w => w ? w.charAt(0).toLowerCase() + w.slice(1) : w;
const pl = w => /[aeiouáéíóú]$/i.test(w) ? w + 's' : /z$/i.test(w) ? w.slice(0,-1) + 'ces' : w + 'es';
const cnt = (n, w) => `${n} ${n === 1 ? low(w) : low(pl(w))}`;
const areaColor = i => AREA_COLORS[i % AREA_COLORS.length];
const LG = id => S.lugares[id];
const tipoL = id => S.tipos.find(t => t.id === id) || {id, s:'Lugar', p:'Lugares'};
const cntT = (n, tid) => { const t = tipoL(tid); return `${n} ${low(n === 1 ? t.s : t.p)}`; };
function rootOf(lid){ let l = LG(lid), id = lid; while (l && l.padre){ id = l.padre; l = LG(id); } return id; }
function rootColor(lid){ return areaColor(Math.max(0, S.raiz.indexOf(rootOf(lid)))); }
function pathIds(lid){ const out = []; let id = lid; while (id && LG(id)){ out.unshift(id); id = LG(id).padre; } return out; }
function pathLabel(lid){ return pathIds(lid).map(i => LG(i).nombre).join(' › '); }
function allIn(lid){ const l = LG(lid); if (!l) return []; return [...l.activos, ...l.hijos.flatMap(allIn)]; }
function treeOrder(ids, depth, out){ (ids || S.raiz).forEach(id => { const l = LG(id); if (!l) return; out.push({id, depth}); treeOrder(l.hijos, depth + 1, out); }); return out; }
function childrenSummary(lid){
  const l = LG(lid); const by = {};
  l.hijos.forEach(h => { const t = LG(h).tipo; by[t] = (by[t] || 0) + 1; });
  return Object.entries(by).map(([t, n]) => cntT(n, t)).join(' · ');
}
function childTipo(lid){ const l = lid ? LG(lid) : null; const kids = l ? l.hijos : S.raiz; if (kids.length){ const c = {}; kids.forEach(k => { const t = LG(k).tipo; c[t] = (c[t] || 0) + 1; }); return Object.entries(c).sort((x, y) => y[1] - x[1])[0][0]; } const tn = n => { const t = S.tipos.find(x => norm(x.s) === norm(n)); return t ? t.id : (S.tipos[0] ? S.tipos[0].id : 't1'); }; const s0 = l ? norm(tipoL(l.tipo).s) : ''; return l ? (s0 === 'area' ? tn('Línea') : s0 === 'edificio' ? tn('Piso') : s0 === 'piso' ? tn('Sala') : tn('Zona')) : tn('Área'); }
function nextName(lid, tid){ const kids = lid ? LG(lid).hijos : S.raiz; const n = kids.filter(k => LG(k).tipo === tid).length + 1; return `${tipoL(tid).s} ${n}`; }

/* ---------- Lógica ---------- */
function issues(id){
  const a = S.activos[id]; if (!a) return [];
  const out = [];
  a.comps.forEach(c => { if (c.e !== 'operativo') out.push({n:c.n, e:c.e}); });
  (a.subs||[]).forEach(sid => {
    const s = S.activos[sid]; if (!s) return;
    if (s.estado !== 'operativo') out.push({n:s.nombre, e:s.estado});
    s.comps.forEach(c => { if (c.e !== 'operativo') out.push({n:c.n, e:c.e, of:s.nombre}); });
  });
  return out;
}
const repLow = a => (a.reps||[]).filter(r => r.stock <= r.min);
function stock(r){ if (r.stock === 0) return {t:'bad', l:'Sin stock'}; if (r.stock <= r.min) return {t:'warn', l:'Quedan pocos'}; return {t:'ok', l:'Hay ' + r.stock}; }
function tone(id){
  const a = S.activos[id]; const own = EST[a.estado].t;
  if (own === 'bad') return 'bad';
  const iss = issues(id);
  if (own === 'warn' || iss.length) return 'warn';
  return 'ok';
}
function toneText(id){
  const a = S.activos[id]; const n = issues(id).length;
  if (EST[a.estado].t !== 'ok') return EST[a.estado].l;
  return n ? `${n} ${n === 1 ? 'aviso' : 'avisos'}` : 'Operativo';
}
function whereIs(id){ for (const lid in S.lugares) if (S.lugares[lid].activos.includes(id)) return lid; return null; }
function detach(id){ S.tray = S.tray.filter(x => x !== id); Object.values(S.lugares).forEach(l => { l.activos = l.activos.filter(x => x !== id); }); }
function moveTo(id, target, index){
  detach(id);
  if (target.type === 'tray' || !LG(target.lugar)){ S.tray.splice(index == null ? S.tray.length : index, 0, id); return; }
  const l = LG(target.lugar); const i = index == null ? l.activos.length : Math.min(index, l.activos.length);
  l.activos.splice(i, 0, id);
}
function placeName(lid){ return LG(lid) ? pathLabel(lid) : 'el mapa'; }
function placeLabel(id){
  const a = S.activos[id];
  if (a.padre) return 'Parte de ' + S.activos[a.padre].nombre;
  const w = whereIs(id); return w ? pathLabel(w) : 'Por ubicar';
}
function placeOptions(cur, trayText){
  let o = `<option value="tray"${cur==='tray'?' selected':''}>${trayText}</option>`;
  S.raiz.forEach(rid => { const r = LG(rid); if (!r) return;
    o += `<optgroup label="${esc(r.nombre)}">`;
    treeOrder([rid], 0, []).forEach(({id, depth}) => { const v = 'L:' + id, l = LG(id);
      const txt = depth === 0 ? `Directo en ${l.nombre}` : '   '.repeat(depth) + '└ ' + l.nombre;
      o += `<option value="${v}"${cur===v?' selected':''}>${esc(txt)}</option>`; });
    o += '</optgroup>'; });
  return o;
}
const parseDonde = v => v && v.startsWith('L:') ? {type:'lugar', lugar:v.slice(2)} : {type:'tray'};

/* ---------- Render 2D ---------- */
const coverURL = id => (S.activos[id] && S.activos[id].foto) || null;
function icoHTML(id, sz){
  const a = S.activos[id]; const u = coverURL(id);
  return u ? `<img src="${u}" alt="">` : svg(ICONS[a.tipo]||ICONS.otro, sz||20);
}
function tileHTML(id, compact){
  const a = S.activos[id]; const e = EST[a.estado]; const iss = issues(id); const low_ = repLow(a);
  const subs = (a.subs||[]).map(sid => S.activos[sid]).filter(Boolean);
  const counts = [];
  if (subs.length) counts.push(`<span style="--c:var(--blue)">${cnt(subs.length,'Subactivo')}</span>`);
  if (a.comps.length) counts.push(`<span style="--c:var(--cyan)">${cnt(a.comps.length,'Componente')}</span>`);
  if ((a.reps||[]).length) counts.push(`<span style="--c:var(--rep)">${cnt(a.reps.length,'Repuesto')}</span>`);
  const subsHTML = (!compact && subs.length) ? `<div class="subs"><b>SUBACTIVOS</b>${[...subs].sort((p, q) => RANKT[EST[p.estado].t] - RANKT[EST[q.estado].t]).slice(0, 3).map(s => `<div class="sub tone-${EST[s.estado].t}"><span class="dot"></span><span style="color:var(--ink)">${esc(s.nombre)}</span><em>${EST[s.estado].l}</em></div>`).join('')}${subs.length > 3 ? `<div class="sub" style="color:var(--blue-ink)">y ${subs.length - 3} más</div>` : ''}</div>` : '';
  let foot;
  if (iss.length) foot = `<div class="tile-alert">${svg(I.alert,16)}${iss.length} ${iss.length===1?'aviso':'avisos'} en sus piezas</div>`;
  else if (low_.length) foot = `<div class="tile-alert tile-alert--rep">${svg(I.alert,16)}${cnt(low_.length,'Repuesto')} por reponer</div>`;
  else foot = `<div class="tile-ok">${svg(I.check,16)}Todo en orden</div>`;
  return `<div class="tile${compact?' tile--compact':''}${openId===id?' is-selected':''}" data-id="${id}" data-flip-id="${id}" tabindex="0" role="button" aria-label="${esc(a.nombre)}, ${e.l}. Explorar activo">
    <div class="tile-head"><span class="tile-ico">${icoHTML(id)}</span><span class="tile-title"><strong>${esc(a.nombre)}</strong><span>${esc(a.codigo)} · ${tipoN(a)}</span></span><span class="grip">${svg(I.grip,16)}</span></div>
    <div class="tile-chips"><span class="chip chip--${e.t}"><i></i>${e.l}</span><span class="crit crit--${a.crit}">${CRIT[a.crit]}</span>${a.nuevo?'<span class="chip chip--new">Nuevo</span>':''}</div>
    ${subsHTML}
    ${counts.length ? `<div class="tile-count">${counts.join('')}</div>` : `<div class="tile-count">Aún sin partes registradas</div>`}
    ${foot}
  </div>`;
}
function laneHTML(lid, label, sub, extra){
  const l = LG(lid);
  const track = l.activos.map(id => tileHTML(id)).join('') + (extra || '') || `<div class="lane-empty">Arrastra un activo aquí</div>`;
  return label != null
    ? `<div class="lane" data-drop="lane" data-lugar="${lid}"><div class="lane-label"><span>${esc(label)}</span>${sub ? `<small>${esc(sub)}</small>` : ''}</div><div class="lane-track">${track}</div></div>`
    : `<div class="lane lane--flat" data-drop="lane" data-lugar="${lid}"><div class="lane-track">${track}</div></div>`;
}
function sectionHTML(lid){
  const l = LG(lid); const ids = allIn(lid); const bad = ids.filter(id => tone(id) !== 'ok').length;
  const meta = [childrenSummary(lid), cnt(ids.length,'Activo')].filter(Boolean).join(' · ');
  let lanes = '';
  if (!l.hijos.length) lanes = laneHTML(lid, null);
  else {
    if (l.activos.length) lanes += laneHTML(lid, 'Sin dividir', `Directo en ${l.nombre}`);
    l.hijos.forEach(h => { const c = LG(h);
      const deep = c.hijos.length ? `<button type="button" class="enter-tile" data-enter="${h}"><b>${esc(childrenSummary(h))}</b><span>${cnt(allIn(h).length - c.activos.length,'Activo')} adentro</span><em>Entrar ›</em></button>` : '';
      const ts = tipoL(c.tipo).s; lanes += laneHTML(h, c.nombre, norm(c.nombre).startsWith(norm(ts)) ? '' : ts, deep); });
  }
  const ct = childTipo(lid);
  const adding = MAP.adding === lid;
  return `<section class="area" data-sec="${lid}" style="--ac:${rootColor(lid)}" aria-label="${esc(tipoL(l.tipo).s)} ${esc(l.nombre)}">
    <header class="area-head"><span class="area-ico">${svg(I.pin)}</span><div><small class="tipo-tag">${esc(tipoL(l.tipo).s)}</small><h3>${esc(l.nombre)}</h3><span>${meta}</span></div>
    <span class="pill pill--${bad?'bad':'ok'}">${bad ? bad + (bad === 1 ? ' con aviso' : ' con avisos') : 'Todo bien'}</span>${l.hijos.some(h => LG(h).hijos.length) ? `<button type="button" class="btn btn--sm" data-enter="${lid}">Entrar ›</button>` : ''}</header>
    ${lanes}
    <div class="area-foot">${adding ? addFormHTML(lid, ct) : `<button type="button" class="btn-text" data-addin="${lid}">+ Agregar ${esc(low(tipoL(ct).s))}</button>${l.hijos.length ? '' : `<span class="foot-hint">para dividir ${esc(l.nombre)}</span>`}`}</div>
  </section>`;
}
function addFormHTML(lid, ct){
  const opts = S.tipos.map(t => `<option value="${t.id}"${t.id === ct ? ' selected' : ''}>${esc(t.s)}</option>`).join('') + '<option value="__nuevo">Otro tipo…</option>';
  return `<div data-form="1" class="addlugar" data-addform="${lid || 'root'}"><label class="sr" for="nlTipo">Tipo de lugar</label><select id="nlTipo">${opts}</select><input id="nlTipoNuevo" placeholder="Nombre del tipo. Ej.: Galpón" hidden autocomplete="off"><label class="sr" for="nlNombre">Nombre</label><input id="nlNombre" value="${esc(nextName(lid, ct))}" data-auto="${esc(nextName(lid, ct))}" autocomplete="off"><button type="button" class="btn btn--primary btn--sm" data-submit="1">Agregar</button><button type="button" class="btn btn--ghost btn--sm" data-addcancel="1">Cancelar</button></div>`;
}
function mapCrumbs(){
  const ids = MAP.cur ? pathIds(MAP.cur) : [];
  const parts = [`<button type="button" data-crumbmap="" ${ids.length ? '' : 'aria-current="page"'}>${svg('<path d="M3 11l9-7 9 7M5 10v10h14V10"/>',16)}${esc(S.planta)}</button>`];
  ids.forEach((id, i) => parts.push(`<span aria-hidden="true">›</span><button type="button" data-crumbmap="${id}"${i === ids.length - 1 ? ' aria-current="page"' : ''}>${esc(LG(id).nombre)}</button>`));
  return `<nav class="mapcrumbs" aria-label="Estás viendo">${parts.join('')}<button type="button" class="ln-open" data-navopen="2d" aria-haspopup="dialog">${svg('<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',16)}Ir a un lugar o activo <kbd style="font:700 11px var(--font);color:var(--muted);background:var(--canvas);border-radius:6px;padding:2px 6px">/</kbd></button>${MAP.cur ? `<button type="button" class="btn btn--sm" data-crumbmap="${LG(MAP.cur).padre || ''}">${svg(I.back,16)}Subir un nivel</button>` : ''}</nav>`;
}
function renderMap(){
  if (MAP.cur && !LG(MAP.cur)) MAP.cur = null;
  const kids = MAP.cur ? LG(MAP.cur).hijos : S.raiz;
  let html = '';
  if (MAP.cur && LG(MAP.cur).activos.length){ const l = LG(MAP.cur); html += `<section class="area" style="--ac:${rootColor(MAP.cur)}"><header class="area-head"><span class="area-ico">${svg(I.pin)}</span><div><small class="tipo-tag">Directo aquí</small><h3>${esc(l.nombre)}</h3><span>Activos que no están en ${esc(low(tipoL(childTipo(MAP.cur)).p))}</span></div></header>${laneHTML(MAP.cur, null)}</section>`; }
  html += kids.map(sectionHTML).join('');
  const rootKey = MAP.cur || 'root'; const ct = childTipo(MAP.cur);
  html += MAP.adding === rootKey ? `<div class="area area--add">${addFormHTML(MAP.cur, ct)}</div>` : `<div class="area area--add"><button type="button" class="btn" data-addin="${rootKey}">+ Agregar ${esc(low(tipoL(ct).s))}${MAP.cur ? ' en ' + esc(LG(MAP.cur).nombre) : ''}</button></div>`;
  $('#mapCrumbs').innerHTML = mapCrumbs();
  $('#map').innerHTML = html;
}
function renderTexts(){
  const el = $('#estrLbl'); if (el) el.textContent = 'Ubicaciones';
  $('#trayText').textContent = 'Activos sin ubicación. Arrástralos a su lugar.';
  $('#hintText').innerHTML = `<strong>Cómo se usa:</strong> arrastra un activo desde «Por ubicar» hasta su lugar. Entra a un lugar con «Entrar ›» para ver lo que tiene adentro. Toca un activo para ver sus partes.`;
}
const MTABS = [
  ['activos','Activos','<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/>'],
  ['componentes','Componentes','<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9L12 3zM4 7.5l8 4.5 8-4.5M12 12v9"/>'],
  ['variables','Variables','<path d="M3 12h4l3-7 4 14 3-7h4"/>'],
  ['medidores','Medidores','<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9h10M7 13h4M15 13h2M7 16h10"/>'],
  ['tipos','Tipos de activo','<circle cx="7" cy="17" r="3"/><rect x="13" y="14" width="7" height="6" rx="1"/><path d="M12 3l4 7H8l4-7z"/>'],
  ['modelos','Modelos','<path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.5"/>']
];
function renderTabs(){
  const all = Object.values(S.activos);
  const cn = S.conteos || {}; const n = {activos:all.length, componentes:cn.componentes != null ? cn.componentes : all.reduce((k, a) => k + a.comps.length, 0), variables:cn.variables || 0, medidores:cn.medidores || 0, tipos:cn.tipos || 0, modelos:cn.modelos || 0};
  const actual = (document.querySelector('#mtabs [aria-selected="true"]') || {dataset:{mtab:'activos'}}).dataset.mtab; $('#mtabs').innerHTML = MTABS.map(([k, l, ic]) => `<button type="button" role="tab" data-mtab="${k}" aria-selected="${k === actual}"${k === actual ? ' aria-current="page"' : ''}>${svg(ic,16)}${l}<b>${n[k]}</b></button>`).join('');
}
function renderPulse(){
  renderTabs();
  const all = Object.values(S.activos); const tops = all.filter(a => !a.padre);
  const c = k => all.filter(a => a.estado === k).length;
  const k = (lbl, n, note, ico, kb, kc) => `<div class="kpi"><span class="kpi-ico" style="--kb:${kb};--kc:${kc}">${svg(ico, 22)}</span><div><span>${lbl}</span><strong>${n}</strong><small>${note}</small></div></div>`;
  $('#pulse').innerHTML =
    k('Activos', all.length, `${tops.length} principales · ${cnt(all.length - tops.length,'Subactivo')}`, '<circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/>', 'var(--sigma-purple-soft)', 'var(--sigma-purple)') +
    k('Operativos', c('operativo'), 'Funcionando sin problemas', '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.5"/>', 'var(--success-soft)', 'var(--success)') +
    k('Detenidos', c('detenido') + c('fuera'), 'Detenidos o fuera de servicio', '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5M12 16h.01"/>', 'var(--danger-soft)', 'var(--danger)') +
    k('En mantenimiento', c('mantenimiento'), c('observacion') ? `${c('observacion')} más con observación` : 'En el taller o en revisión', '<path d="M14.5 4a4.5 4.5 0 0 0-4.3 5.9L4 16.1V20h3.9l6.2-6.2A4.5 4.5 0 1 0 14.5 4z"/>', 'var(--warning-soft)', 'var(--warning-ink)');
}
function render(){
  renderMap();
  $('#tray').innerHTML = S.tray.length ? S.tray.map(id => tileHTML(id, true)).join('') : `<div class="tray-empty">${svg(I.check,22)}Todo está ubicado</div>`;
  renderTexts(); renderPulse(); bindDrag();
}

/* ---------- Cambios con animación ---------- */
function commit(mutate, msg){
  const snap = JSON.stringify(S);
  const st = hasGsap && view === '2d' ? Flip.getState('.tile') : null;
  mutate(); const ok = true; SYNC.desde(snap); render();
  if (st) Flip.from(st, {targets:'.tile', duration:T(.55), ease:'power3.inOut', absolute:true, nested:true,
    onEnter: els => gsap.fromTo(els, {opacity:0, scale:.85}, {opacity:1, scale:1, duration:T(.4), ease:'back.out(1.7)'})});
  if (msg) toast(ok ? msg : msg + ' (no se pudo guardar en este navegador)', snap);
  if (view === '3d') build3D(false);
  if (view === 'lista' || view === 'tarjetas'){ $('#lv').innerHTML = ''; $('#tv').innerHTML = ''; renderCurrent(); }
  if (abierto('#xp')) renderXP(false);
}

/* ---------- Arrastrar ---------- */
function pt(e){ const t = e && (e.changedTouches ? e.changedTouches[0] : e); return t ? {x:t.clientX, y:t.clientY} : {x:0,y:0}; }
function dropAt(x, y){
  const els = document.elementsFromPoint(x, y);
  const lane = els.find(el => el.classList && el.classList.contains('lane'));
  if (lane) return {type:'lugar', lugar:lane.dataset.lugar, el:lane};
  const tray = els.find(el => el.id === 'tray');
  if (tray) return {type:'tray', el:tray};
  return null;
}
function indexIn(container, x, y, dragId){
  const tiles = [...container.querySelectorAll('.tile')].filter(t => t.dataset.id !== dragId);
  let i = 0;
  tiles.forEach(t => { const r = t.getBoundingClientRect(); if (y > r.bottom || (y >= r.top && x > r.left + r.width/2)) i++; });
  return i;
}
let overEl = null;
function setOver(el){ if (overEl === el) return; if (overEl) overEl.classList.remove('is-over'); overEl = el; if (el) el.classList.add('is-over'); }
function bindDrag(){
  drags.forEach(d => d.kill()); drags = [];
  if (!hasGsap || view !== '2d' || SMALL_TOUCH() || !(S.permisos && S.permisos.editar)) return;
  drags = Draggable.create('.tile', {
    type:'x,y', zIndexBoost:false, minimumMovement:6,
    onDragStart(){ this.target.style.zIndex = 60; this.target.classList.add('is-dragging'); gsap.to(this.target, {scale:1.04, rotation:-1.5, duration:T(.2)}); },
    onDrag(e){ const p = pt(e); const d = dropAt(p.x, p.y); setOver(d ? d.el : null); },
    onDragEnd(e){
      const el = this.target, id = el.dataset.id; const p = pt(e); const d = dropAt(p.x, p.y); setOver(null);
      if (!d){ gsap.to(el, {x:0, y:0, scale:1, rotation:0, duration:T(.35), ease:'power2.out', onComplete:()=>{ el.classList.remove('is-dragging'); el.style.zIndex = ''; }}); return; }
      const container = d.type === 'tray' ? d.el : d.el.querySelector('.lane-track');
      const idx = indexIn(container, p.x, p.y, id);
      gsap.set(el, {scale:1, rotation:0});
      const name = S.activos[id].nombre;
      commit(() => moveTo(id, d, idx), d.type === 'tray' ? `${name} volvió a «Por ubicar»` : `${name} quedó en ${placeName(d.lugar)}`);
    },
    onClick(){ openXP(this.target.dataset.id); }
  });
}

/* ---------- Nuevo activo ---------- */
let pendingFoto = null;
function openModal(target){ SIGMA.nuevoActivo(); }
function showModal(sel){
  const m = $(sel); m.hidden = false;
  if (hasGsap){ gsap.fromTo(m, {opacity:0}, {opacity:1, duration:T(.2)}); gsap.fromTo(m.firstElementChild, {y:24, scale:.97}, {y:0, scale:1, duration:T(.35), ease:'power3.out'}); }
}
function closeModal(sel){ const m = $(sel); if (m) m.hidden = true; }
function slug(s){ return norm(s).toUpperCase().replace(/[^A-Z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,22); }
function loadPhoto(file){
  return new Promise((res, rej) => {
    const fr = new FileReader();
    fr.onload = () => { const img = new Image(); img.onload = () => {
      const k = Math.min(1, 1400 / Math.max(img.width, img.height)); const c = document.createElement('canvas');
      c.width = Math.round(img.width * k); c.height = Math.round(img.height * k); c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      res(c.toDataURL('image/jpeg', .85)); }; img.onerror = rej; img.src = fr.result; };
    fr.onerror = rej; fr.readAsDataURL(file);
  });
}

/* ---------- Estructura ---------- */
/* ---------- Aviso con deshacer ---------- */
let undoSnap = null, toastTimer = null;
function toast(msg, snap){
  undoSnap = snap || null; $('#toastMsg').textContent = msg; $('#toastUndo').hidden = !snap;
  const t = $('#toast'); t.hidden = false;
  if (hasGsap) gsap.fromTo(t, {y:20, opacity:0}, {y:0, opacity:1, duration:T(.3), ease:'power2.out'});
  clearTimeout(toastTimer); toastTimer = setTimeout(() => { t.hidden = true; }, 5200);
}

/* ================= Modelado 3D (three.js) ================= */
const ANDON = {ok:'#18D07E', warn:'#FFA51F', bad:'#FF4B3E'};
const col = h => new THREE.Color(h).convertSRGBToLinear();
const V3 = (x,y,z) => new THREE.Vector3(x,y,z);
let MAT = null, GLOW = null;
function mats(){
  if (MAT) return MAT;
  const std = (h, o) => new THREE.MeshStandardMaterial(Object.assign({color:col(h), roughness:.5, metalness:.1}, o||{}));
  MAT = {
    paint: std('#F2F4F8',{roughness:.38}), paint2: std('#D7DDE8',{roughness:.45}), panel: std('#E6EAF1',{roughness:.4}),
    steel: std('#C8CFDA',{metalness:.92, roughness:.24}), dsteel: std('#6E788D',{metalness:.75, roughness:.34}),
    rubber: std('#1F2536',{roughness:.88}), dark: std('#283044',{roughness:.42, metalness:.35}),
    accent: std('#6732F4',{roughness:.34, metalness:.12}), blue: std('#3A5A8E',{roughness:.36, metalness:.38}),
    copper: std('#C47A48',{metalness:.9, roughness:.3}), brass: std('#C9A256',{metalness:.9, roughness:.3}),
    screen: std('#05262E',{emissive:col('#19D3D6'), emissiveIntensity:1.1, roughness:.15}),
    glow: std('#331405',{emissive:col('#FF8A3D'), emissiveIntensity:1.6, roughness:.2}),
    pvc: std('#EEF3FA',{roughness:.22, transparent:true, opacity:.9}), red: std('#D6453A',{roughness:.35, metalness:.2}),
    floorDark: std('#A9B3C8',{roughness:.9})
  };
  return MAT;
}
function glowTex(){
  if (GLOW) return GLOW;
  const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d');
  const g = x.createRadialGradient(64,64,0,64,64,64); g.addColorStop(0,'rgba(255,255,255,1)'); g.addColorStop(.25,'rgba(255,255,255,.55)'); g.addColorStop(1,'rgba(255,255,255,0)');
  x.fillStyle = g; x.fillRect(0,0,128,128); GLOW = new THREE.CanvasTexture(c); return GLOW;
}
function rbox(w, h, d, r){
  r = Math.max(.002, Math.min(r, w/2 - .001, h/2 - .001, d/2 - .001));
  const s = new THREE.Shape(), e = .00001, rr = r - e;
  s.absarc(e, e, e, -Math.PI/2, -Math.PI, true);
  s.absarc(e, h - rr*2, e, Math.PI, Math.PI/2, true);
  s.absarc(w - rr*2, h - rr*2, e, Math.PI/2, 0, true);
  s.absarc(w - rr*2, e, e, 0, -Math.PI/2, true);
  const g = new THREE.ExtrudeGeometry(s, {depth: d - r*2, bevelEnabled:true, bevelSegments:4, steps:1, bevelSize:rr, bevelThickness:r, curveSegments:6});
  g.center(); return g;
}
function rrShape(w, h, r){
  const s = new THREE.Shape(), x = -w/2, y = -h/2; r = Math.min(r, w/2, h/2);
  s.moveTo(x + r, y); s.lineTo(x + w - r, y); s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r); s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h); s.quadraticCurveTo(x, y + h, x, y + h - r); s.lineTo(x, y + r); s.quadraticCurveTo(x, y, x + r, y);
  return s;
}
function slabGeo(w, d, h, r, b){
  const g = new THREE.ExtrudeGeometry(rrShape(w - 2*b, d - 2*b, Math.max(.01, r - b)), {depth: Math.max(.001, h - 2*b), bevelEnabled:true, bevelThickness:b, bevelSize:b, bevelSegments:4, curveSegments:16});
  g.rotateX(-Math.PI/2); g.translate(0, b, 0); return g;
}
function Mk(geo, mat, x, y, z, o){
  const m = new THREE.Mesh(geo, mat); m.position.set(x||0, y||0, z||0); o = o || {};
  m.castShadow = o.cast !== false; m.receiveShadow = true;
  if (o.rx) m.rotation.x = o.rx; if (o.ry) m.rotation.y = o.ry; if (o.rz) m.rotation.z = o.rz;
  return m;
}
const cyl = (r1, r2, h, s) => new THREE.CylinderGeometry(r1, r2, h, s || 32);
function tube(pts, r, mat){ const c = new THREE.CatmullRomCurve3(pts.map(p => V3(p[0],p[1],p[2]))); return Mk(new THREE.TubeGeometry(c, 48, r, 12, false), mat); }
function andon(t){
  const g = new THREE.Group(), m = mats();
  g.add(Mk(cyl(.018,.018,.3,12), m.dsteel, 0, .15, 0));
  let glow = null;
  ['ok','warn','bad'].forEach((k, i) => {
    const on = k === t;
    const mat = new THREE.MeshStandardMaterial({color: on ? col(ANDON[k]) : col('#59627A'), emissive: on ? col(ANDON[k]) : col('#000000'), emissiveIntensity: on ? 2.4 : 0, roughness:.2, metalness:0, transparent:!on, opacity: on ? 1 : .55});
    mat.userData.own = true;
    g.add(Mk(cyl(.058,.058,.078,24), mat, 0, .34 + i*.084, 0, {cast:false}));
    if (on){
      const sm = new THREE.SpriteMaterial({map:glowTex(), color:new THREE.Color(ANDON[k]), transparent:true, blending:THREE.AdditiveBlending, depthWrite:false});
      sm.userData.own = true; const sp = new THREE.Sprite(sm); sp.scale.set(.7,.7,1); sp.position.y = .34 + i*.084; g.add(sp); glow = sp;
    }
  });
  g.add(Mk(cyl(.064,.064,.03,24), m.dark, 0, .34 + 3*.084 - .03, 0));
  g.add(Mk(cyl(.07,.07,.03,24), m.dark, 0, .3, 0));
  return {g, glow};
}
function fan(g, x, y, z, r, list, axis){
  const m = mats(); const holder = new THREE.Group(); holder.position.set(x, y, z);
  if (axis === 'y') holder.rotation.x = -Math.PI/2;
  holder.add(Mk(cyl(r, r, .03, 40), m.dark, 0, 0, 0, {rx:Math.PI/2, cast:false}));
  holder.add(Mk(new THREE.TorusGeometry(r, .02, 10, 48), m.steel, 0, 0, .02));
  const bl = new THREE.Group(); bl.position.z = .03;
  for (let k = 0; k < 3; k++){ const p = Mk(new THREE.BoxGeometry(r*1.75, r*.28, .012), m.paint2, 0, 0, 0, {cast:false}); p.rotation.z = k * Math.PI/3; p.rotation.y = .25; bl.add(p); }
  bl.add(Mk(cyl(r*.18, r*.18, .05, 20), m.dsteel, 0, 0, 0, {rx:Math.PI/2}));
  holder.add(bl);
  for (let k = -2; k <= 2; k++) holder.add(Mk(new THREE.BoxGeometry(r*2, .008, .008), m.steel, 0, k * r*.36, .06, {cast:false}));
  g.add(holder); list.push(bl);
}

/* Cada modelo: base en y=0, centrado en x/z. Devuelve anclas para las flechas del explorador. */
const MODELS = {
  camara(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    const W = 2.8, H = 2.05, D = 2.2, b = .12;
    g.add(Mk(rbox(W + .04, b, D + .04, .03), m.accent, 0, b/2, 0));
    g.add(Mk(rbox(W, H, D, .07), m.paint, 0, b + H/2, 0));
    const seam = (w,h,d,x,y,z) => g.add(Mk(new THREE.BoxGeometry(w,h,d), m.paint2, x,y,z, {cast:false}));
    [-.95, 1.22].forEach(x => seam(.014, H - .12, .01, x, b + H/2, D/2 + .002));
    [-.5, .5].forEach(z => { seam(.01, H - .12, .014, W/2 + .002, b + H/2, z); seam(.01, H - .12, .014, -W/2 - .002, b + H/2, z); });
    seam(W - .1, .014, .01, 0, b + H - .02, D/2 + .002);
    const dx = .15, dw = .95, dh = 1.72, dy = b + .05 + dh/2, gz = D/2 + .014;
    g.add(Mk(rbox(dw + .12, dh + .1, .03, .015), m.rubber, dx, dy, gz, {cast:false}));
    g.add(Mk(rbox(dw, dh, .07, .03), m.steel, dx, dy, D/2 + .045));
    g.add(Mk(new THREE.BoxGeometry(dw - .1, .08, .01), m.dsteel, dx, b + .2, D/2 + .084, {cast:false}));
    g.add(Mk(cyl(.024,.024,.56,14), m.dsteel, dx - dw/2 + .14, dy, D/2 + .16));
    [-.24,.24].forEach(o => g.add(Mk(new THREE.BoxGeometry(.03,.03,.09), m.dsteel, dx - dw/2 + .14, dy + o, D/2 + .11)));
    [-.55,.55].forEach(o => g.add(Mk(rbox(.06,.18,.05,.015), m.dsteel, dx + dw/2 - .02, dy + o, D/2 + .09)));
    g.add(Mk(rbox(.36,.26,.05,.02), m.dark, -.78, b + 1.38, D/2 + .025));
    g.add(Mk(new THREE.PlaneGeometry(.27,.13), m.screen, -.78, b + 1.4, D/2 + .052, {cast:false}));
    const ux = -.3, uy = b + H + .34, uz = -.25, uw = 1.7, uh = .62, ud = 1.05;
    [-.6,.6].forEach(o => g.add(Mk(new THREE.BoxGeometry(.08,.05,ud + .1), m.dsteel, ux + o, b + H + .025, uz)));
    g.add(Mk(rbox(uw, uh, ud, .06), m.panel, ux, uy, uz));
    [-.4,.4].forEach(o => fan(g, ux + o, uy, uz + ud/2 + .004, .24, fans));
    g.add(Mk(rbox(.3,.36,.06,.02), m.paint2, ux + uw/2 - .08, uy, uz + ud/2 + .02));
    g.add(tube([[ux + uw/2 - .2, uy - .12, uz - .35],[W/2 - .25, b + H + .07, uz - .35],[W/2 + .03, b + H - .18, -.62],[W/2 + .03, b + .55, -.62]], .026, m.copper));
    g.add(tube([[ux + uw/2 - .2, uy - .2, uz - .18],[W/2 - .3, b + H + .07, uz - .18],[W/2 + .07, b + H - .28, -.45],[W/2 + .07, b + .55, -.45]], .018, m.copper));
    g.add(Mk(cyl(.05,.05,.3,18), m.copper, W/2 + .07, b + 1.15, -.45));
    const an = andon(t); an.g.position.set(W/2 - .22, b + H, D/2 - .22); g.add(an.g);
    A.ventilador = V3(ux - .4, uy, uz + ud/2 + .03); A.condensadora = V3(ux + .4, uy + .12, uz + ud/2); A.termostato = V3(-.78, b + 1.4, D/2 + .05);
    A.burlete = V3(dx + dw/2 + .05, dy + .3, gz + .01); A.puerta = V3(dx, dy, D/2 + .08); A.filtro = V3(W/2 + .07, b + 1.15, -.45); A.refrigerante = V3(W/2 - .1, b + H + .05, uz - .35);
    return {g, A, h: b + H + uh + .2, fans, glow: an.glow};
  },
  compresor(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    g.add(Mk(rbox(1.7,.07,.9,.02), m.dsteel, 0, .035, 0));
    [[-.62,-.3],[-.62,.3],[.62,-.3],[.62,.3]].forEach(([x,z]) => g.add(Mk(cyl(.06,.07,.08,16), m.rubber, x, .11, z)));
    g.add(Mk(rbox(1.45,.1,.6,.03), m.dsteel, 0, .2, 0));
    g.add(Mk(cyl(.33,.33,1.05,40), m.blue, -.12, .58, 0, {rz:Math.PI/2}));
    const cap = new THREE.SphereGeometry(.33, 32, 16); [-.645, .405].forEach((x,i) => { const s = Mk(cap, m.blue, x, .58, 0); s.scale.set(.32,1,1); g.add(s); });
    for (let k = 0; k < 7; k++) g.add(Mk(new THREE.TorusGeometry(.335,.012,8,40), m.dsteel, -.55 + k*.11, .58, 0, {ry:Math.PI/2}));
    g.add(Mk(rbox(.56,.16,.5,.03), m.dsteel, .12, .99, 0));
    for (let k = 0; k < 5; k++) g.add(Mk(new THREE.BoxGeometry(.56,.018,.54), m.steel, .12, 1.09 + k*.035, 0));
    g.add(Mk(rbox(.26,.22,.2,.03), m.dark, -.5, .98, .12));
    g.add(Mk(cyl(.035,.035,.22,14), m.brass, .38, 1.12, -.12)); g.add(Mk(cyl(.06,.06,.06,16), m.brass, .38, 1.25, -.12));
    g.add(Mk(cyl(.035,.035,.22,14), m.brass, -.12, 1.12, -.2));
    g.add(tube([[.38,1.28,-.12],[.38,1.4,-.12],[.75,1.4,-.12],[.85,1.2,-.12]], .025, m.copper));
    const an = andon(t); an.g.scale.setScalar(.8); an.g.position.set(-.72, .25, .32); g.add(an.g);
    A.valvula = V3(.38, 1.25, -.12); A.motor = V3(-.45, .58, .3); A.presostato = V3(-.5, 1.02, .22); A.aceite = V3(.1, .45, .32); A.tablero = A.presostato;
    return {g, A, h: 1.5, fans, glow: an.glow};
  },
  horno(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    [[-1.05,-.55],[-1.05,.55],[1.05,-.55],[1.05,.55]].forEach(([x,z]) => { g.add(Mk(rbox(.09,.55,.09,.02), m.steel, x, .275, z)); g.add(Mk(cyl(.07,.07,.03,16), m.rubber, x, .015, z)); });
    g.add(Mk(rbox(3.3,.06,1.0,.02), m.rubber, 0, .6, 0));
    [-1.62, 1.62].forEach(x => g.add(Mk(cyl(.06,.06,1.04,24), m.steel, x, .6, 0, {rx:Math.PI/2})));
    [-1.45, 1.45].forEach(x => g.add(Mk(new THREE.BoxGeometry(.4,.04,1.08), m.steel, x, .56, 0)));
    g.add(Mk(rbox(2.4,.88,1.3,.08), m.steel, 0, .66 + .44, 0));
    g.add(Mk(rbox(2.1,.2,1.1,.06), m.dsteel, 0, 1.64, 0));
    [-.85,-.3,.25].forEach(x => { g.add(Mk(rbox(.42,.26,.03,.02), m.dark, x, 1.08, .655)); g.add(Mk(new THREE.PlaneGeometry(.36,.2), m.glow, x, 1.08, .672, {cast:false})); });
    g.add(Mk(rbox(.42,.5,.1,.03), m.paint, .85, 1.08, .69)); g.add(Mk(new THREE.PlaneGeometry(.3,.16), m.screen, .85, 1.18, .742, {cast:false}));
    [-.06,.06].forEach(o => g.add(Mk(cyl(.03,.03,.03,16), m.red, .78 + o*2, .97, .75, {rx:Math.PI/2})));
    [-.65,.55].forEach(x => { g.add(Mk(cyl(.1,.1,.75,24), m.steel, x, 2.1, -.28)); g.add(Mk(cyl(.15,.12,.08,24), m.dsteel, x, 2.5, -.28)); });
    fan(g, 0, 1.76, .1, .2, fans, 'y');
    g.add(Mk(cyl(.015,.015,.4,10), m.brass, .4, 1.9, .35));
    g.add(Mk(rbox(.5,.32,.32,.04), m.accent, -.7, .38, -.5)); g.add(Mk(cyl(.1,.1,.18,20), m.dsteel, -.7, .38, -.75, {rx:Math.PI/2}));
    const an = andon(t); an.g.position.set(1.0, 1.74, -.4); g.add(an.g);
    A.quemador = V3(-.7, .4, -.34); A.cinta = V3(1.55, .64, .45); A.ventilador = V3(0, 1.78, .1); A.termocupla = V3(.4, 2.08, .35); A.tablero = V3(.85, 1.12, .74);
    return {g, A, h: 2.6, fans, glow: an.glow};
  },
  amasadora(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    g.add(Mk(rbox(1.5,.5,1.25,.09), m.paint, 0, .25, 0));
    g.add(Mk(rbox(1.52,.07,1.27,.03), m.accent, 0, .06, 0));
    const prof = [[.12,0],[.32,.02],[.46,.1],[.54,.24],[.57,.42],[.58,.56],[.6,.58]].map(p => new THREE.Vector2(p[0], p[1]));
    const bowl = new THREE.LatheGeometry(prof, 48); const bm = mats().steel.clone(); bm.side = THREE.DoubleSide; bm.userData.own = true;
    g.add(Mk(bowl, bm, -.2, .5, .05));
    g.add(Mk(new THREE.TorusGeometry(.6,.025,12,64), m.steel, -.2, 1.08, .05, {rx:Math.PI/2}));
    g.add(Mk(rbox(.42,1.25,.55,.07), m.paint, .52, .5 + .62, -.1));
    g.add(Mk(rbox(1.05,.34,.55,.1), m.paint, .06, 1.78, -.02));
    g.add(Mk(rbox(1.07,.06,.57,.03), m.accent, .06, 1.6, -.02));
    const helix = new THREE.Curve(); helix.getPoint = function(tt, tg){ tg = tg || new THREE.Vector3(); const a = tt * Math.PI * 5; return tg.set(-.2 + Math.cos(a)*.14, 1.6 - tt*1.0, .05 + Math.sin(a)*.14); };
    g.add(Mk(new THREE.TubeGeometry(helix, 160, .028, 10, false), m.steel));
    g.add(Mk(cyl(.035,.035,.95,16), m.steel, -.02, 1.15, .05));
    g.add(Mk(rbox(.3,.3,.04,.03), m.dark, .52, 1.25, .2)); g.add(Mk(new THREE.PlaneGeometry(.22,.14), m.screen, .52, 1.29, .225, {cast:false}));
    g.add(Mk(cyl(.035,.035,.03,16), m.red, .46, 1.15, .23, {rx:Math.PI/2})); g.add(Mk(cyl(.035,.035,.03,16), m.accent, .58, 1.15, .23, {rx:Math.PI/2}));
    const an = andon(t); an.g.position.set(.55, 1.95, -.25); g.add(an.g);
    A.motorEspiral = V3(.2, 1.85, .2); A.bowl = V3(-.2, .3, .63); A.espiral = V3(-.2, 1.0, .2); A.tablero = V3(.52, 1.27, .23); A.motor = A.bowl;
    return {g, A, h: 2.45, fans, glow: an.glow};
  },
  bomba(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    g.add(Mk(rbox(1.4,.08,.62,.02), m.dsteel, 0, .04, 0));
    [-.3,.2].forEach(x => g.add(Mk(rbox(.12,.18,.4,.02), m.dsteel, x, .17, 0)));
    g.add(Mk(cyl(.19,.19,.62,40), m.paint, -.18, .45, 0, {rz:Math.PI/2}));
    for (let k = 0; k < 9; k++) g.add(Mk(new THREE.TorusGeometry(.195,.012,8,40), m.paint2, -.44 + k*.065, .45, 0, {ry:Math.PI/2}));
    g.add(Mk(cyl(.2,.2,.1,40), m.dark, -.53, .45, 0, {rz:Math.PI/2}));
    g.add(Mk(rbox(.24,.16,.22,.03), m.dark, -.18, .7, 0)); g.add(Mk(new THREE.PlaneGeometry(.14,.07), m.screen, -.18, .72, .112, {cast:false}));
    g.add(Mk(cyl(.15,.15,.2,40), m.accent, .23, .45, 0, {rz:Math.PI/2}));
    g.add(Mk(cyl(.16,.16,.04,40), m.steel, .35, .45, 0, {rz:Math.PI/2}));
    g.add(tube([[.37,.5,0],[.5,.5,0],[.6,.62,0],[.6,.9,0]], .03, m.pvc));
    g.add(tube([[.37,.38,0],[.5,.38,.0],[.6,.28,.12],[.62,.16,.3]], .03, m.pvc));
    g.add(Mk(cyl(.045,.045,.1,16), m.dark, .6, .95, 0)); g.add(Mk(cyl(.06,.06,.04,16), m.accent, .6, 1.01, 0));
    const an = andon(t); an.g.scale.setScalar(.75); an.g.position.set(-.55, .08, .22); g.add(an.g);
    A.motor = V3(-.3, .62, .15); A.diafragma = V3(.36, .45, .1); A.valvula = V3(.6, .97, 0);
    return {g, A, h: 1.25, fans, glow: an.glow};
  },
  dosificador(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    [[-.38,-.38],[-.38,.38],[.38,-.38],[.38,.38]].forEach(([x,z]) => { g.add(Mk(cyl(.035,.035,1.05,16), m.steel, x, .525, z)); g.add(Mk(cyl(.06,.06,.03,16), m.rubber, x, .015, z)); });
    g.add(Mk(rbox(.9,.05,.9,.02), m.steel, 0, .5, 0));
    g.add(Mk(rbox(.95,.06,.95,.02), m.steel, 0, 1.05, 0));
    const hop = Mk(new THREE.CylinderGeometry(.62,.16,.85,4,1,true), m.steel, 0, 1.5, 0); hop.rotation.y = Math.PI/4; hop.material = m.steel.clone(); hop.material.side = THREE.DoubleSide; hop.material.userData.own = true; g.add(hop);
    g.add(Mk(new THREE.BoxGeometry(.9,.05,.05), m.dsteel, 0, 1.94, .44)); g.add(Mk(new THREE.BoxGeometry(.9,.05,.05), m.dsteel, 0, 1.94, -.44));
    g.add(Mk(new THREE.BoxGeometry(.05,.05,.9), m.dsteel, .44, 1.94, 0)); g.add(Mk(new THREE.BoxGeometry(.05,.05,.9), m.dsteel, -.44, 1.94, 0));
    g.add(Mk(cyl(.08,.08,.9,24), m.steel, .1, .95, 0, {rz:Math.PI/2}));
    g.add(Mk(cyl(.13,.13,.34,32), m.paint, .72, .95, 0, {rz:Math.PI/2})); g.add(Mk(rbox(.18,.2,.2,.03), m.accent, .5, .95, 0));
    g.add(Mk(cyl(.06,.04,.3,20), m.steel, -.32, .75, 0));
    const an = andon(t); an.g.position.set(-.4, 1.97, -.4); g.add(an.g);
    A.motor = V3(.75, 1.0, .12); A.tolva = V3(0, 1.6, .38);
    return {g, A, h: 2.45, fans, glow: an.glow};
  },
  caldera(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    [-.6,.6].forEach(x => g.add(Mk(rbox(.22,.4,1.0,.03), m.dsteel, x, .2, 0)));
    g.add(Mk(cyl(.62,.62,2.0,48), m.paint, 0, .95, 0, {rz:Math.PI/2}));
    const cap = new THREE.SphereGeometry(.62, 48, 24); [-1, 1].forEach(x => { const s = Mk(cap, m.paint, x, .95, 0); s.scale.set(.28,1,1); g.add(s); });
    [-.7,0,.7].forEach(x => g.add(Mk(new THREE.TorusGeometry(.625,.018,10,64), m.steel, x, .95, 0, {ry:Math.PI/2})));
    g.add(Mk(rbox(.5,.55,.55,.05), m.accent, 1.38, .95, 0)); g.add(Mk(cyl(.14,.14,.18,24), m.dsteel, 1.38, .95, .36, {rx:Math.PI/2}));
    g.add(Mk(cyl(.15,.15,1.4,32), m.steel, -.75, 2.1, -.2)); g.add(Mk(cyl(.2,.16,.1,32), m.dsteel, -.75, 2.82, -.2));
    g.add(Mk(cyl(.035,.035,.25,12), m.brass, .25, 1.65, 0)); g.add(Mk(cyl(.11,.11,.05,32), m.steel, .25, 1.8, .03, {rx:Math.PI/2}));
    g.add(Mk(new THREE.CircleGeometry(.09,32), m.paint, .25, 1.8, .057, {cast:false}));
    g.add(Mk(cyl(.04,.04,.4,12), m.brass, .7, 1.7, 0)); g.add(Mk(cyl(.08,.08,.05,20), m.red, .7, 1.92, 0));
    g.add(Mk(cyl(.12,.12,.3,24), m.blue, .3, .2, .7, {rz:Math.PI/2})); g.add(Mk(cyl(.1,.1,.12,24), m.red, .52, .2, .7, {rz:Math.PI/2}));
    g.add(tube([[.58,.2,.7],[.85,.2,.7],[.95,.4,.5],[.95,.6,.45]], .025, m.steel));
    const an = andon(t); an.g.position.set(1.38, 1.22, -.15); g.add(an.g);
    A.quemador = V3(1.38, .95, .3); A.bomba = V3(.35, .22, .82); A.valvula = V3(.7, 1.92, 0); A.motor = A.bomba;
    return {g, A, h: 2.95, fans, glow: an.glow};
  },
  otro(t){
    const m = mats(), g = new THREE.Group(), A = {}, fans = [];
    g.add(Mk(rbox(1.3,.08,.85,.02), m.accent, 0, .04, 0));
    g.add(Mk(rbox(1.25,1.5,.8,.08), m.paint, 0, .83, 0));
    g.add(Mk(rbox(.5,.32,.04,.03), m.dark, -.2, 1.25, .41)); g.add(Mk(new THREE.PlaneGeometry(.4,.22), m.screen, -.2, 1.25, .434, {cast:false}));
    for (let k = 0; k < 6; k++) g.add(Mk(new THREE.BoxGeometry(.4,.02,.01), m.paint2, .3, .5 + k*.07, .405, {cast:false}));
    fan(g, .3, 1.25, .41, .14, fans);
    const an = andon(t); an.g.position.set(.45, 1.58, -.25); g.add(an.g);
    A.motor = V3(.3, 1.25, .45); A.tablero = V3(-.2, 1.25, .45); A.panel = A.tablero;
    return {g, A, h: 2.1, fans, glow: an.glow};
  }
};
function makeModel(tipo, t){ return (MODELS[tipo] || MODELS.otro)(t); }
const KW = [
  [['motor del espiral'],'motorEspiral'],[['burlete','sello','empaque'],'burlete'],[['termostato','controlador'],'termostato'],
  [['ventilador','fan'],'ventilador'],[['compresor','condensad'],'condensadora'],[['filtro'],'filtro'],[['refrigerante','r-404','gas'],'refrigerante'],
  [['puerta'],'puerta'],[['valvula','inyeccion'],'valvula'],[['presostato'],'presostato'],[['aceite'],'aceite'],[['bowl','taza'],'bowl'],[['espiral','gancho'],'espiral'],
  [['tablero','panel','electric'],'tablero'],[['quemador','electrodo'],'quemador'],[['cinta','correa','transportad'],'cinta'],
  [['termocupla','sensor'],'termocupla'],[['diafragma','cabezal'],'diafragma'],[['tolva'],'tolva'],[['bomba'],'bomba'],[['motor','rodamiento'],'motor']
];
function anchorKey(name){ const n = norm(name); const f = KW.find(([ks]) => ks.some(k => n.includes(k))); return f ? f[1] : null; }
function disposeObj(o){
  o.traverse(c => {
    if (c.geometry) c.geometry.dispose();
    const ms = c.material ? (Array.isArray(c.material) ? c.material : [c.material]) : [];
    ms.forEach(mm => { if (mm.userData && mm.userData.own){ if (hasGsap) gsap.killTweensOf(mm); if (mm.userData.ownMap && mm.map) mm.map.dispose(); mm.dispose(); } });
  });
}
function makeEnv(renderer){
  const pm = new THREE.PMREMGenerator(renderer); const sc = new THREE.Scene();
  sc.add(new THREE.Mesh(new THREE.BoxGeometry(24,14,24), new THREE.MeshBasicMaterial({color:new THREE.Color(.55,.58,.66), side:THREE.BackSide})));
  const panel = (w,h,x,y,z,rx,ry,k) => { const p = new THREE.Mesh(new THREE.PlaneGeometry(w,h), new THREE.MeshBasicMaterial({color:new THREE.Color(k,k,k), side:THREE.DoubleSide})); p.position.set(x,y,z); p.rotation.set(rx,ry,0); sc.add(p); };
  panel(10,4, 0,6.8,0, Math.PI/2,0, 5); panel(6,5, -11.8,4,0, 0,Math.PI/2, 2.6); panel(6,5, 11.8,4,2, 0,-Math.PI/2, 1.8); panel(10,3, 0,3,-11.8, 0,0, 1.6);
  const tex = pm.fromScene(sc, .04).texture; pm.dispose(); return tex;
}

/* ---------- Imagen de portada generada (estudio) ---------- */
let studio = null; const coverCache = {};
function getStudio(){
  if (studio !== null) return studio;
  if (!window.THREE) return false;
  try {
    const r = new THREE.WebGLRenderer({antialias:true, alpha:true, preserveDrawingBuffer:true});
    r.setPixelRatio(1); r.setSize(1200, 900, false); r.setClearColor(0x000000, 0);
    r.outputColorSpace = THREE.SRGBColorSpace; r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.05;
    r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
    const sc = new THREE.Scene(); sc.environment = makeEnv(r);
    sc.add(new THREE.HemisphereLight(0xffffff, col('#B4BDD2'), .45));
    const key = new THREE.DirectionalLight(0xffffff, 1.15); key.position.set(4, 8, 6); key.castShadow = true; key.shadow.mapSize.set(2048, 2048);
    Object.assign(key.shadow.camera, {left:-4, right:4, top:4, bottom:-4, near:.5, far:30}); key.shadow.bias = -.0004; sc.add(key);
    const fill = new THREE.DirectionalLight(col('#DCE4FF'), .35); fill.position.set(-6, 3, -2); sc.add(fill);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(40, 40), new THREE.ShadowMaterial({opacity:.2})); ground.rotation.x = -Math.PI/2; ground.receiveShadow = true; sc.add(ground);
    const cam = new THREE.PerspectiveCamera(26, 4/3, .1, 100);
    studio = {r, sc, cam};
  } catch(e){ studio = false; }
  return studio;
}
function coverFor(id, onlyCached){
  const a = S.activos[id]; if (!a) return null;
  const k = a.tipo + '|' + tone(id);
  if (coverCache[k] || onlyCached) return coverCache[k] || null;
  const st = getStudio(); if (!st) return null;
  try {
    const mod = makeModel(a.tipo, tone(id)); st.sc.add(mod.g);
    const box = new THREE.Box3().setFromObject(mod.g); const ctr = box.getCenter(new THREE.Vector3()); const rad = box.getSize(new THREE.Vector3()).length() / 2;
    const dir = V3(1.05, .72, 1.7).normalize(); const dist = rad / Math.sin(THREE.MathUtils.degToRad(13)) * .92;
    st.cam.position.copy(ctr).addScaledVector(dir, dist); st.cam.lookAt(ctr); st.cam.updateMatrixWorld();
    st.r.render(st.sc, st.cam);
    const url = st.r.domElement.toDataURL('image/png');
    const pts = {}; Object.entries(mod.A).forEach(([kk, v]) => { const p = v.clone().project(st.cam); pts[kk] = {x:(p.x + 1)/2, y:(1 - p.y)/2}; });
    st.sc.remove(mod.g); disposeObj(mod.g);
    coverCache[k] = {url, pts}; return coverCache[k];
  } catch(e){ console.error('[SIGMA portada]', e); return null; }
}
function warmCovers(done){
  if (!window.THREE) return;
  const ids = Object.keys(S.activos).filter(id => !coverFor(id, true)); let i = 0;
  const step = () => { if (i >= ids.length){ done && done(); return; } coverFor(ids[i++]); setTimeout(step, 30); };
  setTimeout(step, 120);
}

/* ================= Mapa 3D ================= */
let three = null;
const FLOOR = .36;
function mixHex(a, b, t){ const A = new THREE.Color(a), B = new THREE.Color(b); return '#' + A.lerp(B, t).getHexString(); }
function init3D(){
  if (three) return true;
  if (!window.THREE){ $('#sceneFallback').hidden = false; return false; }
  try {
    const host = $('#scene');
    const renderer = new THREE.WebGLRenderer({antialias:true, alpha:true});
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2)); renderer.setClearColor(0x000000, 0);
    renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    host.appendChild(renderer.domElement);
    const scene = new THREE.Scene(); scene.environment = makeEnv(renderer);
    scene.fog = new THREE.Fog(col('#C6CEE0'), 70, 170);
    const camera = new THREE.PerspectiveCamera(30, 1, .1, 600);
    let controls = null;
    if (THREE.OrbitControls){ controls = new THREE.OrbitControls(camera, renderer.domElement); controls.enableDamping = true; controls.dampingFactor = .08; controls.maxPolarAngle = 1.32; controls.screenSpacePanning = true; controls.zoomSpeed = .9; controls.minDistance = 7; controls.maxDistance = 130; controls.autoRotateSpeed = .5; }
    scene.add(new THREE.HemisphereLight(0xffffff, col('#A9B3CA'), .55));
    const sun = new THREE.DirectionalLight(0xffffff, 1.15); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048); sun.shadow.bias = -.0004; sun.shadow.normalBias = .02;
    scene.add(sun); scene.add(sun.target);
    const fill = new THREE.DirectionalLight(col('#DCE4FF'), .3); fill.position.set(-30, 20, -20); scene.add(fill);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(600, 600), new THREE.ShadowMaterial({opacity:.16})); ground.rotation.x = -Math.PI/2; ground.receiveShadow = true; scene.add(ground);
    const grid = new THREE.GridHelper(300, 150, col('#8C98B6'), col('#A6B0C8')); grid.material.transparent = true; grid.material.opacity = .32; grid.position.y = .002; scene.add(grid);
    const group = new THREE.Group(); scene.add(group);
    three = {renderer, scene, camera, controls, sun, group, ray:new THREE.Raycaster(), mouse:new THREE.Vector2(), running:false, assets:{}, labels:[], fans:[], hover:null, first:true, home:null, tmp:new THREE.Vector3()};
    const resize = () => { const r = host.getBoundingClientRect(); if (!r.width) return; renderer.setSize(r.width, r.height, false); camera.aspect = r.width / r.height; camera.updateProjectionMatrix(); };
    new ResizeObserver(resize).observe(host); resize();
    let down = null, raf = 0;
    renderer.domElement.addEventListener('pointerdown', e => { down = {x:e.clientX, y:e.clientY}; });
    renderer.domElement.addEventListener('pointerup', e => { if (!down || Math.hypot(e.clientX - down.x, e.clientY - down.y) > 6) return; const id = pick(e); if (id) openXP(id); });
    renderer.domElement.addEventListener('pointermove', e => { if (raf) return; raf = requestAnimationFrame(() => { raf = 0; setHover(pick(e)); }); });
    renderer.domElement.addEventListener('pointerleave', () => setHover(null));
    renderer.domElement.addEventListener('dblclick', e => { const id = pick(e); if (id) focusAsset(id); });
    return true;
  } catch(e){ $('#sceneFallback').hidden = false; return false; }
}
function pick(e){
  const r = three.renderer.domElement.getBoundingClientRect();
  three.mouse.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
  three.ray.setFromCamera(three.mouse, three.camera);
  const hits = three.ray.intersectObjects(three.group.children, true);
  const h = hits.find(x => x.object.userData && x.object.userData.id);
  return h ? h.object.userData.id : null;
}
function setHover(id){
  if (!three || three.hover === id) return;
  const prev = three.assets[three.hover]; if (prev){ prev.label.classList.remove('is-hover'); if (hasGsap){ gsap.to(prev.g.position, {y:prev.baseY, duration:T(.3), ease:'power2.out'}); gsap.to(prev.card.scale, {x:1, y:1, z:1, duration:T(.3), ease:'power2.out'}); } }
  three.hover = id; const cur = three.assets[id];
  if (cur){ cur.label.classList.add('is-hover'); if (hasGsap){ gsap.to(cur.g.position, {y:cur.baseY + .14, duration:T(.3), ease:'power2.out'}); gsap.to(cur.card.scale, {x:1.08, y:1.08, z:1.08, duration:T(.3), ease:'power2.out'}); } }
  three.renderer.domElement.style.cursor = id ? 'pointer' : 'grab';
}
function floorText(lines, wU, hU, color){
  const px = 140, c = document.createElement('canvas'); c.width = Math.max(64, Math.round(wU * px)); c.height = Math.round(hU * px);
  const x = c.getContext('2d'); x.textBaseline = 'middle'; let lastEnd = 0;
  lines.forEach(L => {
    x.font = `${L.w || 800} ${L.s * px}px "Sora","Segoe UI",sans-serif`;
    if (L.ls && 'letterSpacing' in x) x.letterSpacing = (L.ls * px) + 'px';
    if (L.pill){ const tw = x.measureText(L.t).width; const ph = L.s * px * 1.9; const xx = L.after ? lastEnd + .35 * px : L.x * px, yy = L.y * px - ph/2; x.fillStyle = L.bg; x.beginPath(); const r = ph/2; x.moveTo(xx + r, yy); x.arcTo(xx + tw + ph*1.4, yy, xx + tw + ph*1.4, yy + ph, r); x.arcTo(xx + tw + ph*1.4, yy + ph, xx, yy + ph, r); x.arcTo(xx, yy + ph, xx, yy, r); x.arcTo(xx, yy, xx + tw, yy, r); x.fill(); x.fillStyle = L.c; x.beginPath(); x.arc(xx + ph*.55, yy + ph/2, ph*.17, 0, Math.PI*2); x.fill(); x.fillText(L.t, xx + ph*.9, yy + ph/2 + 1); }
    else { x.fillStyle = L.c || color; x.fillText(L.t, L.x * px, L.y * px); if (!lastEnd) lastEnd = L.x * px + x.measureText(L.t).width; }
    if ('letterSpacing' in x) x.letterSpacing = '0px';
  });
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
  const mat = new THREE.MeshBasicMaterial({map:tex, transparent:true, depthWrite:false, polygonOffset:true, polygonOffsetFactor:-2}); mat.userData.own = true; mat.userData.ownMap = true;
  const m = new THREE.Mesh(new THREE.PlaneGeometry(wU, hU), mat); m.rotation.x = -Math.PI/2; m.renderOrder = 2; return m;
}
function hatchTex(color){
  const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d');
  x.strokeStyle = color; x.lineWidth = 10; x.globalAlpha = .18; for (let i = -64; i < 128; i += 22){ x.beginPath(); x.moveTo(i, 0); x.lineTo(i + 64, 64); x.stroke(); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; return t;
}
function build3D(intro){
  try { build3DInner(intro); } catch(err){ console.error('[SIGMA 3D]', err); $('#sceneFallback').hidden = false; }
}
function build3DInner(intro){
  if (!init3D()) return;
  const {group} = three;
  disposeObj(group); while (group.children.length) group.remove(group.children[0]);
  $('#labels3d').innerHTML = ''; three.assets = {}; three.labels = []; three.fans = []; three.hover = null; three.areaNav = []; three.rowNav = {};
  const m = mats();
  const SLOT = 4.4, MAXW = 36, GAP = 2.6;
  const chunk = (ids, name) => { const rows = []; for (let i = 0; i < Math.max(1, ids.length); i += 4) rows.push({name: i ? '' : name, ids: ids.slice(i, i + 4)}); return rows; };
  const blocks = S.raiz.map((rid, ai) => {
    const r = LG(rid); let rows = [];
    if (r.activos.length || !r.hijos.length) rows.push(...chunk(r.activos, r.hijos.length ? 'Sin dividir' : ''));
    r.hijos.forEach(h => { const c = LG(h); rows.push({lid:h, name: c.nombre + (c.hijos.length ? ' · ' + childrenSummary(h) : ''), ids: allIn(h)}); });
    return {name: r.nombre, lid: rid, tipo: tipoL(r.tipo).s, color: areaColor(ai), rows, ids: allIn(rid), lanes: rows.some(x => x.name)};
  });
  if (S.tray.length){ const rows = []; for (let i = 0; i < S.tray.length; i += 4) rows.push({name:'', ids:S.tray.slice(i, i + 4)}); blocks.push({name:'Por ubicar', color:'#D9822B', rows, ids:S.tray, tray:true, lid:null}); }
  blocks.forEach(b => { b.rows.forEach(r => { r.depth = r.ids.some(id => (S.activos[id].subs||[]).length) ? 5.4 : 3.8; }); b.W = Math.max(1, ...b.rows.map(r => r.ids.length)) * SLOT + 1.4; b.D = b.rows.reduce((n, r) => n + r.depth, 0) + 2.3; });
  let x = 0, z = 0, rowD = 0, maxX = 0; const P = [];
  blocks.forEach(b => { if (x > 0 && x + b.W > MAXW){ x = 0; z += rowD + GAP; rowD = 0; } P.push({b, x, z}); x += b.W + GAP; rowD = Math.max(rowD, b.D); maxX = Math.max(maxX, x - GAP); });
  const totD = z + rowD, ox = -maxX/2, oz = -totD/2;
  const slabs = [], assetsIn = [];
  P.forEach(p => {
    const b = p.b, cx = p.x + ox + b.W/2, cz = p.z + oz + b.D/2;
    const base = new THREE.Mesh(slabGeo(b.W, b.D, .14, .6, .04), new THREE.MeshStandardMaterial({color:col(b.color), roughness:.45, metalness:.1})); base.material.userData.own = true;
    base.position.set(cx, 0, cz); base.receiveShadow = true; base.castShadow = true; group.add(base); slabs.push(base);
    const topCol = b.tray ? '#FBF7F1' : mixHex('#FFFFFF', b.color, .06);
    const top = new THREE.Mesh(slabGeo(b.W - .18, b.D - .18, .22, .52, .05), new THREE.MeshStandardMaterial({color:col(topCol), roughness:.62, metalness:0})); top.material.userData.own = true;
    top.position.set(cx, .12, cz); top.receiveShadow = true; group.add(top); slabs.push(top);
    if (b.tray){ const ht = hatchTex('#D9822B'); ht.repeat.set(b.W/1.2, b.D/1.2); const hm = new THREE.MeshBasicMaterial({map:ht, transparent:true, depthWrite:false, polygonOffset:true, polygonOffsetFactor:-1}); hm.userData.own = true; hm.userData.ownMap = true; const hp = new THREE.Mesh(new THREE.PlaneGeometry(b.W - .5, b.D - .5), hm); hp.rotation.x = -Math.PI/2; hp.position.set(cx, FLOOR - .015, cz); group.add(hp); }
    const fz = p.z + oz + b.D - 1.05;
    const bad = b.ids.filter(id => tone(id) !== 'ok').length;
    const meta = b.tray ? cnt(b.ids.length,'Activo') + ' sin ubicación' : [b.tipo, b.lid ? childrenSummary(b.lid) : '', cnt(b.ids.length,'Activo')].filter(Boolean).join(' · ');
    const ft = floorText([
      {t: b.name.toUpperCase(), s:.6, x:.15, y:.55, c: mixHex('#17223B', b.color, .25), ls:.03},
      {t: meta, s:.28, x:.18, y:1.18, c:'#5F6A80', w:700},
      b.tray ? null : {pill:true, t: bad ? `${bad} con avisos` : 'Todo bien', s:.26, after:true, y:.55, bg: bad ? '#FDECEA' : '#E7F5EE', c: bad ? '#B02C23' : '#12704C'}
    ].filter(Boolean), b.W - .5, 1.6, '#17223B');
    ft.position.set(cx, FLOOR - .01, fz); group.add(ft);
    three.areaNav.push({name:b.name, lid:b.lid, color:b.color, tray:!!b.tray, center:V3(cx, 0, cz), w:b.W, d:b.D, bad, ids:b.ids, meshes:[base, top, ft]}); three.curArea = three.areaNav.length - 1;
    let rz = p.z + oz + .35;
    b.rows.forEach(r => {
      const lz = rz + r.depth/2, rowW = b.W - .7;
      if (r.lid) three.rowNav[r.lid] = {center:V3(cx, 1, lz), w:rowW, d:r.depth, area:three.areaNav.length - 1};
      if (b.lanes){
        const lm = new THREE.MeshStandardMaterial({color:col(mixHex('#FFFFFF', b.color, .12)), roughness:.8}); lm.userData.own = true;
        const lane = new THREE.Mesh(slabGeo(rowW, r.depth - .4, .02, .25, .006), lm); lane.position.set(cx, FLOOR - .02, lz); lane.receiveShadow = true; group.add(lane);
        const lt = floorText([{t: r.name.toUpperCase(), s:.2, x:.1, y:.2, c: mixHex('#5F6A80', b.color, .35), ls:.04}], 2.4, .4); lt.position.set(cx - rowW/2 + 1.3, FLOOR + .006, lz - r.depth/2 + .45); group.add(lt);
      }
      r.ids.forEach((id, i) => {
        const a = S.activos[id]; if (!a) return;
        const ax = p.x + ox + .7 + SLOT * (i + .5), az = lz - (a.subs && a.subs.length ? .9 : 0);

        assetsIn.push(placeAsset(id, a, ax, az, 1));
        const subsAll = (a.subs||[]).filter(sid => S.activos[sid]);
        const subsShow = [...subsAll].sort((p, q) => RANKT[tone(p)] - RANKT[tone(q)]).slice(0, 3);
        if (subsAll.length > 3){ const more = floorText([{t:`+${subsAll.length - 3} subactivos`, s:.22, x:.1, y:.25, c:'#0662BC', w:800}], 2.6, .5); more.position.set(ax + 2.2, FLOOR + .006, az + 2.25); group.add(more); }
        subsShow.forEach((sid, k) => {
          const s = S.activos[sid]; if (!s) return; const n = subsShow.length; const sx = ax + (k - (n-1)/2) * 1.75, sz = az + 2.25;
          assetsIn.push(placeAsset(sid, s, sx, sz, .55));
          for (let d = 1; d < 5; d++){ const dm = new THREE.Mesh(new THREE.CircleGeometry(.05, 16), m.accent); dm.rotation.x = -Math.PI/2; dm.position.set(ax + (sx - ax) * d/5, FLOOR + .005, az + 1.15 + (sz - .45 - az - 1.15) * d/5); group.add(dm); }
        });
      });
      rz += r.depth;
    });
  });
  const R = Math.max(maxX, totD) / 2 + 4;
  three.sun.position.set(R * .8, R * 1.6 + 14, R * .9); three.sun.target.position.set(0, 0, 0);
  Object.assign(three.sun.shadow.camera, {left:-R - 4, right:R + 4, top:R + 4, bottom:-R - 4, near:1, far:R * 5 + 60}); three.sun.shadow.camera.updateProjectionMatrix();
  const aspect = Math.max(1, three.camera.aspect || 1.6), tv = Math.tan(THREE.MathUtils.degToRad(15));
  const dist = Math.max(18, Math.max((maxX/2 + 3) / (tv * aspect), (totD/2 + 3) / tv * .8) * 1.02);
  three.home = {pos: V3(0, 1, 0).add(new THREE.Vector3().setFromSpherical(new THREE.Spherical(dist, .92, .32))), target: V3(0, 1, 0)};
  three.fit = dist;
  if (three.focus != null && three.focus >= three.areaNav.length) three.focus = null;
  renderNav3D(); applyDim(); renderAreaPanel(); updateTourBtn();
  if (three.first){ three.camera.position.copy(three.home.pos); if (three.controls) three.controls.target.copy(three.home.target); }
  if (intro && hasGsap && !RM){
    slabs.forEach((s, i) => gsap.from(s.scale, {x:.92, z:.92, y:.01, duration:.7, delay:i * .03, ease:'power3.out'}));
    assetsIn.forEach((e, i) => gsap.from(e.g.position, {y:e.baseY + 3.2, duration:.9, delay:.25 + i * .06, ease:'bounce.out'}));
    if (three.first){ gsap.from(three.camera.position, {x:three.home.pos.x * .2, y:three.home.pos.y * 1.9, z:three.home.pos.z * 1.3, duration:1.8, ease:'power3.out'}); }
  }
  three.first = false;
}
/* Cada activo es un tótem con su foto de portada (o su imagen referencial), que siempre mira a la cámara */
function cardTexture(id){
  const a = S.activos[id]; const c = document.createElement('canvas'); c.width = 800; c.height = 600; const x = c.getContext('2d');
  const bg = () => { const g = x.createRadialGradient(400, 230, 40, 400, 300, 520); g.addColorStop(0, '#FFFFFF'); g.addColorStop(.55, '#EEF0F7'); g.addColorStop(1, '#D6DCE8'); x.fillStyle = g; x.fillRect(0, 0, 800, 600); };
  bg();
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
  const url = a.foto;
  const pill = (txt) => { x.font = '700 26px "Sora","Segoe UI",sans-serif'; const w = x.measureText(txt).width + 36; x.fillStyle = 'rgba(255,255,255,.92)'; x.beginPath(); x.moveTo(36, 24); x.arcTo(24 + w, 24, 24 + w, 68, 22); x.arcTo(24 + w, 68, 24, 68, 22); x.arcTo(24, 68, 24, 24, 22); x.arcTo(24, 24, 24 + w, 24, 22); x.fill(); x.fillStyle = '#5F6A80'; x.textBaseline = 'middle'; x.fillText(txt, 42, 47); };
  if (url){
    const img = new Image();
    img.onload = () => { bg(); const k = Math.max(800 / img.width, 600 / img.height); const w = img.width * k, h = img.height * k; x.drawImage(img, (800 - w)/2, (600 - h)/2, w, h); tex.needsUpdate = true; };
    img.src = url;
  } else {
    x.fillStyle = '#9AA5BE'; x.font = '800 44px "Sora","Segoe UI",sans-serif'; x.textAlign = 'center'; x.fillText(tipoN(a) || 'Activo', 400, 280); x.font = '600 28px "Sora","Segoe UI",sans-serif'; x.fillText('Sin foto de portada', 400, 330); tex.needsUpdate = true;
  }
  return tex;
}
function placeAsset(id, a, x, z, sc){
  const t = tone(id); const m = mats();
  const tc = t === 'bad' ? '#E5483C' : t === 'warn' ? '#F0A030' : '#1FB574';
  const g = new THREE.Group(); g.position.set(x, FLOOR, z); g.scale.setScalar(sc);
  const own = mat => { mat.userData.own = true; return mat; };
  const glowMat = own(new THREE.MeshBasicMaterial({color:col(tc), toneMapped:false}));
  g.add(Mk(cyl(.58, .66, .12, 48), m.dark, 0, .06, 0));
  g.add(Mk(new THREE.TorusGeometry(.56, .035, 10, 64), glowMat, 0, .125, 0, {rx:Math.PI/2, cast:false}));
  g.add(Mk(cyl(.045, .045, 1.05, 16), m.steel, 0, .65, 0));
  const card = new THREE.Group(); card.position.y = 2.2; g.add(card);
  const frameMat = own(m.paint.clone());
  card.add(Mk(rbox(2.84, 2.26, .1, .1), frameMat, 0, 0, 0));
  const photoMat = own(new THREE.MeshBasicMaterial({map:cardTexture(id), toneMapped:false})); photoMat.userData.ownMap = true;
  card.add(Mk(new THREE.PlaneGeometry(2.64, 1.98), photoMat, 0, .07, .052, {cast:false}));
  card.add(Mk(new THREE.PlaneGeometry(2.64, .07), glowMat, 0, -1.03, .052, {cast:false}));
  card.add(Mk(new THREE.PlaneGeometry(2.6, 2.1), m.panel, 0, 0, -.052, {ry:Math.PI, cast:false}));
  g.traverse(o => { if (o.isMesh) o.userData.id = id; });
  three.group.add(g);
  if (t !== 'ok'){
    const rm = own(new THREE.MeshBasicMaterial({color:col(tc), transparent:true, opacity:.55, depthWrite:false}));
    const ring = new THREE.Mesh(new THREE.RingGeometry(1.0 * sc, 1.16 * sc, 64), rm); ring.rotation.x = -Math.PI/2; ring.position.set(x, FLOOR + .008, z); three.group.add(ring);
    if (hasGsap && !RM){ gsap.to(rm, {opacity:.06, duration:1.1, repeat:-1, yoyo:true, ease:'sine.inOut'}); gsap.to(ring.scale, {x:1.25, y:1.25, duration:1.1, repeat:-1, yoyo:true, ease:'sine.inOut'}); }
  }
  const anchor = new THREE.Object3D(); anchor.position.y = 3.5; g.add(anchor);
  const el = document.createElement('button'); const sub = sc < 1;
  el.className = 'l3' + (sub ? ' l3--sub' : ''); el.style.setProperty('--t', `var(--${t === 'ok' ? 'ok' : t})`);
  el.innerHTML = `<i></i><b>${esc(a.nombre)}</b><span>${esc(toneText(id))}</span>`;
  el.setAttribute('aria-label', `${a.nombre}, ${toneText(id)}. Explorar`);
  el.addEventListener('click', () => openXP(id));
  el.addEventListener('pointerenter', () => setHover(id)); el.addEventListener('pointerleave', () => setHover(null));
  $('#labels3d').appendChild(el);
  const entry = {id, g, card, baseY:FLOOR, label:el, anchor, tone:t, sub, area:three.curArea, mats:[frameMat, photoMat, glowMat]};
  three.assets[id] = entry; three.labels.push(entry);
  return entry;
}
function updateLabels(){
  const r = three.renderer.domElement.getBoundingClientRect(); const w = r.width, h = r.height;
  const placed = [];
  const order = [...three.labels].sort((p, q) => (q.id === three.hover) - (p.id === three.hover) || (p.sub - q.sub) || (RANKT[p.tone] - RANKT[q.tone]));
  order.forEach(e => {
    e.anchor.getWorldPosition(three.tmp); three.tmp.project(three.camera);
    const vis = three.tmp.z < 1 && Math.abs(three.tmp.x) < 1.1 && Math.abs(three.tmp.y) < 1.1;
    if (!vis){ e.label.style.visibility = 'hidden'; return; }
    const x = (three.tmp.x + 1)/2 * w, y = (1 - three.tmp.y)/2 * h;
    if (!e.lw){ e.lw = e.label.offsetWidth || 160; e.lh = e.label.offsetHeight || 30; }
    const box = {l:x - e.lw/2, r:x + e.lw/2, t:y - e.lh, b:y};
    const hit = e.id !== three.hover && placed.some(q => box.l < q.r && box.r > q.l && box.t < q.b && box.b > q.t);
    e.label.classList.toggle('l3--dot', hit);
    if (!hit) placed.push(box);
    e.label.style.visibility = 'visible';
    e.label.style.zIndex = e.id === three.hover ? 5 : hit ? 1 : 2;
    e.label.style.transform = `translate(${x.toFixed(1)}px,${y.toFixed(1)}px) translate(-50%,-100%)`;
  });
}
function dimEntry(e, on){
  e.mats.forEach(mm => { mm.transparent = true; mm.opacity = on ? .16 : 1; mm.needsUpdate = true; });
  e.label.classList.toggle('is-dim', on);
}
function applyDim(){
  if (!three) return; const f = three.focus;
  three.labels.forEach(e => dimEntry(e, (three.onlyIssues && e.tone === 'ok') || (f != null && e.area !== f)));
  (three.areaNav||[]).forEach((a, i) => a.meshes.forEach(m => { const on = f != null && i !== f; m.material.transparent = true; m.material.opacity = on ? .3 : 1; m.material.needsUpdate = true; }));
}
/* ---------- Navegación ---------- */
function sph(){ const c = three.controls; return new THREE.Spherical().setFromVector3(three.camera.position.clone().sub(c ? c.target : V3(0,0,0))); }
function tweenSph(to, dur){
  const c = three.controls; const s = sph(); const st = {r:s.radius, phi:s.phi, theta:s.theta};
  let dt = (to.theta != null ? to.theta : s.theta) - s.theta; dt = Math.atan2(Math.sin(dt), Math.cos(dt));
  const end = {r: to.r != null ? to.r : s.radius, phi: to.phi != null ? to.phi : s.phi, theta: s.theta + dt};
  end.r = Math.min(Math.max(end.r, 6), 140); end.phi = Math.min(Math.max(end.phi, .04), 1.32);
  const apply = () => { three.camera.position.copy(c.target).add(new THREE.Vector3().setFromSpherical(new THREE.Spherical(st.r, st.phi, st.theta))); };
  if (hasGsap && !RM) gsap.to(st, {...end, duration:dur || .7, ease:'power3.inOut', onUpdate:apply}); else { Object.assign(st, end); apply(); }
}
function flyTo(target, r, angles){
  if (!three || !three.controls) return; const c = three.controls; const s = sph();
  const phi = angles && angles.phi != null ? angles.phi : Math.min(s.phi, 1.05); const theta = angles && angles.theta != null ? angles.theta : s.theta;
  const pos = target.clone().add(new THREE.Vector3().setFromSpherical(new THREE.Spherical(r, phi, theta)));
  if (hasGsap && !RM){ gsap.to(c.target, {x:target.x, y:target.y, z:target.z, duration:1, ease:'power3.inOut'}); gsap.to(three.camera.position, {x:pos.x, y:pos.y, z:pos.z, duration:1, ease:'power3.inOut'}); }
  else { c.target.copy(target); three.camera.position.copy(pos); }
}
function focusAsset(id){
  const e = three && three.assets[id]; if (!e) return;
  const p = e.g.getWorldPosition(new THREE.Vector3()); p.y += 1.6;
  flyTo(p, e.sub ? 8 : 11);
  setTimeout(() => { setHover(id); if (hasGsap && !RM) gsap.fromTo(e.card.scale, {x:1, y:1}, {x:1.18, y:1.18, duration:.35, yoyo:true, repeat:3, ease:'sine.inOut'}); }, 900);
}
function focusArea(i){
  const a = three.areaNav[i]; if (!a) return;
  const aspect = Math.max(1, three.camera.aspect), tv = Math.tan(THREE.MathUtils.degToRad(15));
  const r = Math.max(12, Math.max((a.w/2 + 1.5) / (tv * aspect), (a.d/2 + 1.5) / tv * .85));
  flyTo(a.center.clone().setY(1), r, {phi:.95});
  three.focus = i; applyDim(); renderNav3D(); renderAreaPanel();
}
function renderNav3D(){ if (typeof renderLocNav === 'function') renderLocNav(); }
function loop(){
  if (!three || !three.running) return; requestAnimationFrame(loop);
  try {
  three.controls && three.controls.update();
  const cp = three.camera.position; three.labels.forEach(e => { e.g.getWorldPosition(three.tmp); e.card.rotation.y = Math.atan2(cp.x - three.tmp.x, cp.z - three.tmp.z); });
  updateLabels(); three.renderer.render(three.scene, three.camera);
  } catch(err){ three.running = false; console.error('[SIGMA 3D]', err); $('#sceneFallback').hidden = false; }
}
function center3D(){
  if (!three || !three.home) return; three.focus = null; applyDim(); renderNav3D(); renderAreaPanel(); const c = three.controls, h = three.home;
  if (hasGsap){ gsap.to(three.camera.position, {x:h.pos.x, y:h.pos.y, z:h.pos.z, duration:T(1), ease:'power3.inOut'}); if (c) gsap.to(c.target, {x:h.target.x, y:h.target.y, z:h.target.z, duration:T(1), ease:'power3.inOut'}); }
  else { three.camera.position.copy(h.pos); c && c.target.set(0,0,0); }
}

/* ================= Explorador del activo =================
   Foto al centro. Tres flechas hacia tres paneles: subactivos (izquierda), componentes (derecha) y repuestos (abajo).
   Nada se superpone: los controles de la foto viven dentro de la foto y el detalle de cada pieza se abre dentro de su panel. */
const XP = {stack:[], sel:null, adding:false, repFor:null};
const KIND = {comp:{l:'Componentes', one:'componente', c:'#007F8A'}, sub:{l:'Subactivos', one:'subactivo', c:'#087BEA'}, rep:{l:'Repuestos', one:'repuesto', c:'#E08A00'}};
const RANK = {bad:0, warn:1, ok:2};
const curId = () => XP.stack[XP.stack.length - 1];

function xpModel(id){
  const a = S.activos[id];
  const subs = (a.subs||[]).map(sid => S.activos[sid] && {key:'s:' + sid, kind:'sub', id:sid, name:S.activos[sid].nombre, tone:tone(sid), label:toneText(sid), foto:S.activos[sid].foto || null}).filter(Boolean);
  const comps = a.comps.map((c, i) => ({key:'c:' + i, kind:'comp', i, name:c.n, tone:EST[c.e].t, label:EST[c.e].l, foto:c.foto || null, nota:c.e !== 'operativo' ? (c.nota || '') : ''}));
  const reps = (a.reps||[]).map((r, i) => { const s = stock(r); return {key:'r:' + i, kind:'rep', i, name:r.n, tone:s.t, label:s.l, para:r.para || '', foto:r.foto || null}; });
  const sort = list => list.map((x, o) => ({x, o})).sort((p, q) => RANK[p.x.tone] - RANK[q.x.tone] || p.o - q.o).map(p => p.x);
  return {a, sub:sort(subs), comp:sort(comps), rep:sort(reps)};
}
function itemDetail(it, M){
  const a = M.a;
  if (it.kind === 'comp'){
    const c = a.comps[it.i]; const n = M.rep.filter(r => r.para && norm(r.para) === norm(c.n)).length;
    return `<div class="co-det">
      <div class="field"><label for="dEstado">Estado de esta pieza</label><select id="dEstado" data-comp="${it.i}">${Object.entries(EST).map(([k, v]) => `<option value="${k}"${k === c.e ? ' selected' : ''}>${v.l}</option>`).join('')}</select></div>
      <span class="co-note">${n ? `${cnt(n,'Repuesto')} le ${n === 1 ? 'sirve' : 'sirven'}. Lo ves filtrado en «Repuestos».` : 'Aún no tiene repuestos vinculados.'}</span>
      <button type="button" class="btn btn--primary btn--sm" data-xp="ot">Crear OT para esta pieza</button></div>`;
  }
  if (it.kind === 'rep'){
    const r = a.reps[it.i]; const target = it.para ? M.comp.find(x => norm(x.name) === norm(it.para)) : null;
    return `<div class="co-det">
      <div class="co-stock"><span class="big tone-${it.tone}">${r.stock}</span><span>en bodega<br>mínimo recomendado ${r.min}</span></div>
      ${target ? `<button type="button" class="btn-text" style="height:32px;justify-content:flex-start;padding:0" data-co-go="${target.key}">Ver la pieza: ${esc(target.name)} ›</button>` : '<span class="co-note">Sirve para este activo en general.</span>'}
      <span class="co-acc">${r.url ? `<a class="btn btn--sm" href="${SIGMA.url(r.url)}" target="_blank" rel="noopener">Ver ficha del repuesto</a>` : ''}${r.vinculo && S.permisos && S.permisos.editar ? `<button type="button" class="btn btn--sm btn--borrar" data-xp="quitarrep" data-v="${r.vinculo}">Quitar vínculo</button>` : ''}</span></div>`;
  }
  return '';
}
function itemHTML(it, M){
  const sel = XP.sel === it.key;
  return `<div class="co-wrap${sel ? ' is-open' : ''}" data-name="${esc(norm(it.name + ' ' + (it.para||'')))}" data-tone="${it.tone}"${it.para ? ` data-para="${esc(norm(it.para))}"` : ''}>
    <button type="button" class="co co--${it.kind}${sel ? ' is-sel' : ''}${it.foto ? ' con-foto' : ''}" data-co="${it.key}" aria-expanded="${it.kind === 'sub' ? 'false' : sel}">
      ${it.foto ? `<span class="co-img"><img src="${esc(it.foto)}" alt="" loading="lazy"></span>` : ''}<span class="co-main"><strong>${esc(it.name)}</strong>${it.para ? `<small class="co-para">Para: ${esc(it.para)}</small>` : ''}${it.nota ? `<small class="co-obs">«${esc(it.nota)}»</small>` : ''}</span>
      <span class="co-side">${it.kind === 'sub' ? svg('<path d="M9 6l6 6-6 6"/>',18) : svg(sel ? '<path d="M6 15l6-6 6 6"/>' : '<path d="M6 9l6 6 6-6"/>',16)}</span>
      <span class="chip chip--${it.tone}"><i></i>${esc(it.label)}</span>
    </button>${sel ? itemDetail(it, M) : ''}</div>`;
}
function groupHTML(kind, list, side, M){
  const k = KIND[kind]; const bad = list.filter(x => x.tone !== 'ok').length;
  const big = list.length > 6;
  const items = list.length
    ? `<div class="grp-items">${list.map(it => itemHTML(it, M)).join('')}</div><div class="grp-none" hidden>Nada coincide.</div>`
    : `<div class="xp-empty">${kind === 'sub' ? 'No tiene subactivos.' : kind === 'comp' ? 'Aún no tiene componentes.' : 'Sin repuestos vinculados.'}</div>`;
  const status = bad ? `<span class="chip chip--${list.some(x => x.tone === 'bad') ? 'bad' : 'warn'}"><i></i>${bad} ${kind === 'rep' ? 'por reponer' : 'con aviso'}</span>` : list.length ? '<span class="chip chip--ok"><i></i>Todo bien</span>' : '';
  return `<section class="grp grp--${kind} grp--${side}" style="--c:${k.c}" data-grp="${kind}" aria-label="${k.l}">
    <header class="grp-head"><span class="grp-ico"></span><h3>${k.l}</h3><span class="grp-n">${list.length}</span><span class="grp-st">${status}</span>
</header>
    ${kind === 'comp' && XP.adding ? `<div data-form="1" class="addform" id="formComp"><label for="iComp" class="sr">Nombre del componente</label><input id="iComp" placeholder="Ej.: Motor" autocomplete="off"><button type="button" class="btn btn--primary btn--sm" data-submit="1">Agregar</button><button type="button" class="icon-btn" style="width:36px;height:36px" data-xp="addcancel" aria-label="Cancelar">${svg(I.close,16)}</button></div>` : ''}
    ${big ? `<div class="grp-tools"><label class="sr" for="q-${kind}">Buscar ${k.one}</label><input class="grp-q" id="q-${kind}" data-q="${kind}" placeholder="Buscar ${k.one}…" autocomplete="off">${bad ? `<button type="button" class="grp-only" data-only="${kind}" aria-pressed="false">${kind === 'rep' ? 'Por reponer' : 'Con aviso'}</button>` : ''}</div>` : ''}
    ${kind === 'rep' ? `<div class="grp-for" id="repFor" hidden></div>` : ''}
    <div class="grp-list">${items}</div>
    ${kind === 'comp' && !XP.adding ? `<button type="button" class="grp-add" data-xp="add">${svg(I.plus,16)}Agregar componente</button>` : ''}
    ${kind === 'rep' && S.permisos && S.permisos.editar ? (XP.addRep ? SIGMA.formRepuesto(curId()) : `<button type="button" class="grp-add grp-add--rep" data-xp="addrep">${svg(I.plus,16)}Agregar repuesto compatible</button>`) : ''}
  </section>`;
}
function renderXP(intro){
  const id = curId(); const a = S.activos[id]; if (!a){ closeXP(); return; }
  const M = xpModel(id); const e = EST[a.estado]; const iss = issues(id);
  const photo = a.foto;
  const crumbs = XP.stack.map((sid, i) => i < XP.stack.length - 1 ? `<button type="button" data-crumb="${i}">${esc(S.activos[sid].nombre)}</button><span aria-hidden="true">›</span>` : '').join('');
  const w = whereIs(id); const cur = w ? 'L:' + w : 'tray';
  XP.repFor = null; if (XP.sel && XP.sel.startsWith('c:')){ const c = a.comps[+XP.sel.slice(2)]; if (c) XP.repFor = c.n; }
  $('#xpCard').innerHTML = `
    <header class="xp-head">
      <span class="tile-ico">${icoHTML(id, 26)}</span>
      <div class="xp-title">
        ${XP.stack.length > 1 ? `<nav class="crumbs" aria-label="Ruta">${crumbs}<span>${esc(a.nombre)}</span></nav>` : ''}
        <h2 id="xpTitle">${esc(a.nombre)}</h2>
        <small>${esc(a.codigo)} · ${tipoN(a)} · ${esc(placeLabel(id))}</small>
        <div class="tile-chips" style="margin-top:4px"><span class="chip chip--${e.t}"><i></i>${e.l}</span><span class="crit crit--${a.crit}">Criticidad ${CRIT[a.crit].toLowerCase()}</span>${iss.length ? `<span class="chip chip--bad"><i></i>${iss.length} ${iss.length === 1 ? 'pieza con aviso' : 'piezas con aviso'}</span>` : '<span class="chip chip--ok"><i></i>Todas sus piezas bien</span>'}</div>
      </div>
      ${XP.stack.length > 1 ? `<button type="button" class="btn btn--sm" data-crumb="${XP.stack.length - 2}">${svg(I.back,16)}Volver</button>` : ''}
      <button type="button" class="icon-btn" data-xp="close" aria-label="Cerrar">${svg(I.close)}</button>
    </header>
    <div class="xp-scroll"><div class="xp-body" id="xpBody">
      <svg class="xp-lines" id="xpLines" aria-hidden="true"></svg>
      <div class="xp-stage">
        ${photo ? `<figure class="xp-photo is-real" id="xpPhoto">
          <img src="${photo}" alt="Foto de portada de ${esc(a.nombre)}">
          <figcaption class="xp-badge">${svg(I.camera,14)}${fotosOf(id).length > 1 ? 'Portada · ' + fotosOf(id).length + ' fotos' : 'Foto de portada'}</figcaption>
          <div class="ph-actions">
            <button type="button" class="ph-btn" data-xp="zoom">${svg('<path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7"/>',16)}Ampliar</button>
            <label class="ph-btn" for="xpFoto">${svg(I.camera,16)}Agregar fotos</label><input type="file" id="xpFoto" accept="image/*" multiple class="sr">
            <button type="button" class="ph-btn" data-xp="nofoto" aria-label="Quitar foto" title="Quitar foto">${svg(I.close,16)}</button>
          </div>
        </figure>` : `<figure class="xp-photo xp-photo--vacia" id="xpPhoto">
          <span class="xp-vacia-ico">${svg(I.camera,32)}</span>
          <b>Este activo todavía no tiene foto</b>
          <span>PNG o JPG. La primera que subas queda de portada.</span>
          <label class="ph-btn" for="xpFoto">${svg(I.camera,16)}Agregar foto de portada</label><input type="file" id="xpFoto" accept="image/*" multiple class="sr">
        </figure>`}
      </div>
      ${groupHTML('sub', M.sub, 'c', M)}
      ${groupHTML('comp', M.comp, 'c', M)}
      ${groupHTML('rep', M.rep, 'c', M)}
    </div></div>
    <footer class="xp-foot">
      <div class="field"><label for="xEstado">Estado del ${a.padre ? 'subactivo' : 'activo'}</label><select id="xEstado">${Object.entries(EST).map(([k, v]) => `<option value="${k}"${k === a.estado ? ' selected' : ''}>${v.l}</option>`).join('')}</select></div>
      ${a.padre ? `<div class="field"><span class="lbl">Es parte de</span><button type="button" class="btn" data-crumb-open="${a.padre}">${esc(S.activos[a.padre].nombre)}</button></div>`
                : `<div class="field"><label for="xMover">Ubicación</label><select id="xMover">${placeOptions(cur, 'Por ubicar (sin ubicación)')}</select></div>`}
      <span class="spacer"></span>
      <button type="button" class="btn" data-xp="centro">Abrir centro 360°</button>
      <button type="button" class="btn btn--primary" data-xp="ot">Crear OT</button>
    </footer>`;
  XP.model = M;
  applyRepFor();
  requestAnimationFrame(() => { sizeCols(); drawLines(intro); if (intro) animXP(); });
}
function applyRepFor(){
  const box = $('#repFor'); if (!box) return;
  const f = XP.repFor ? norm(XP.repFor) : null;
  box.hidden = !f;
  if (f){ const n = $$('[data-grp="rep"] .co-wrap').filter(el => el.dataset.para === f).length; box.innerHTML = `<span>${n ? 'Los que sirven para' : 'Ninguno vinculado a'} <b>${esc(XP.repFor)}</b></span><button type="button" class="btn-text" data-xp="repall" style="height:28px">Ver todos</button>`; }
  filterGroup('rep');
}
function filterGroup(kind){
  const g = document.querySelector(`[data-grp="${kind}"]`); if (!g) return;
  const qEl = g.querySelector('.grp-q'); const q = qEl ? norm(qEl.value.trim()) : '';
  const only = g.querySelector('.grp-only'); const onlyOn = only && only.getAttribute('aria-pressed') === 'true';
  const para = kind === 'rep' && XP.repFor ? norm(XP.repFor) : null;
  let shown = 0;
  g.querySelectorAll('.co-wrap').forEach(el => {
    const ok = (!q || el.dataset.name.includes(q)) && (!onlyOn || el.dataset.tone !== 'ok') && (!para || el.dataset.para === para);
    el.hidden = !ok; if (ok) shown++;
  });
  const none = g.querySelector('.grp-none'); if (none) none.hidden = shown > 0 || !g.querySelector('.co-wrap');
  requestAnimationFrame(() => drawLines(false));
}
function sizeCols(){ const ph = $('#xpPhoto'); if (ph) $('#xpBody').style.setProperty('--ph', Math.round(ph.getBoundingClientRect().height) + 'px'); }
/* Flechas tipo organigrama: foto → subactivos, componentes y repuestos */
function drawLines(animate){
  const body = $('#xpBody'), svgEl = $('#xpLines'), ph = $('#xpPhoto'); if (!body || !svgEl || !ph) return;
  if (getComputedStyle(svgEl).display === 'none') return;
  const br = body.getBoundingClientRect(); svgEl.setAttribute('viewBox', `0 0 ${br.width} ${br.height}`);
  const pr = ph.getBoundingClientRect();
  const x0 = pr.left + pr.width/2 - br.left, y0 = pr.bottom - br.top;
  const gs = ['sub','comp','rep'].map(k => { const g = body.querySelector(`[data-grp="${k}"]`); if (!g) return null; const r = g.getBoundingClientRect(); return {k, x:r.left + r.width/2 - br.left, top:r.top - br.top}; }).filter(Boolean);
  if (!gs.length) return;
  const top = Math.min(...gs.map(g => g.top)); const ym = y0 + (top - y0) * .45;
  const defs = Object.entries(KIND).map(([k, v]) => `<marker id="ah-${k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto"><path d="M0 0L10 5L0 10z" fill="${v.c}"/></marker>`).join('');
  const r = 10; let out = `<circle cx="${x0}" cy="${y0}" r="4" fill="#9AA5BE"/><path class="ln" d="M${x0} ${y0} V${ym}" stroke="#9AA5BE"/>`;
  gs.forEach(g => {
    const dir = g.x < x0 - 1 ? -1 : g.x > x0 + 1 ? 1 : 0;
    const d = dir ? `M${x0} ${ym} H${g.x - dir*r} Q${g.x} ${ym} ${g.x} ${ym + r} V${g.top - 3}` : `M${x0} ${ym} V${g.top - 3}`;
    out += `<path class="ln" d="${d}" stroke="${KIND[g.k].c}" marker-end="url(#ah-${g.k})"/>`;
  });
  svgEl.innerHTML = `<defs>${defs}</defs>${out}`;
  if (animate && hasGsap && !RM) $$('#xpLines .ln').forEach((p, i) => { const L = p.getTotalLength(); gsap.fromTo(p, {strokeDasharray:L, strokeDashoffset:L}, {strokeDashoffset:0, duration:.55, delay:(i ? .45 : .25), ease:'power2.out', onComplete:() => { p.style.strokeDasharray = 'none'; }}); });
}
function animXP(){
  if (!hasGsap || RM) return;
  gsap.fromTo('#xpPhoto', {scale:.97, opacity:0}, {scale:1, opacity:1, duration:.5, ease:'power3.out', clearProps:'transform,opacity'});
  gsap.fromTo('.grp', {y:16, opacity:0}, {y:0, opacity:1, duration:.45, stagger:.08, delay:.5, ease:'power2.out', clearProps:'transform,opacity'});
}
function selectItem(key){
  const M = XP.model; const it = M && [...M.sub, ...M.comp, ...M.rep].find(x => x.key === key); if (!it) return;
  if (it.kind === 'sub'){ drill(it); return; }
  const scrolls = $$('.grp-list').map(l => l.scrollTop); const xs = $('.xp-scroll') ? $('.xp-scroll').scrollTop : 0;
  XP.sel = XP.sel === key ? null : key; renderXP(false);
  $$('.grp-list').forEach((l, i) => { l.scrollTop = scrolls[i] || 0; }); if ($('.xp-scroll')) $('.xp-scroll').scrollTop = xs;
  const det = document.querySelector('.co-wrap.is-open .co-det'); if (det && hasGsap && !RM) gsap.from(det, {height:0, opacity:0, duration:.3, ease:'power2.out', clearProps:'height,opacity', onUpdate:() => drawLines(false)});
  const sel = document.querySelector(`[data-co="${key}"]`); if (sel) sel.focus({preventScroll:true});
}
function drill(it){
  const img = $('#xpPhoto > img');
  const go = () => { XP.stack.push(it.id); XP.sel = null; XP.adding = false; renderXP(true); };
  if (img && hasGsap && !RM) gsap.to(img, {scale:1.4, opacity:0, duration:.35, ease:'power2.in', onComplete:go}); else go();
}
function openXP(id){ SIGMA.cargarFotos(id).then(() => { if (abierto('#xp') && curId() === id) renderXP(false); }).catch(() => {});
  if (!S.activos[id]) return;
  XP.stack = [id]; XP.sel = null; XP.adding = false;
  openId = id; $$('.tile.is-selected').forEach(t => t.classList.remove('is-selected')); $$(`.tile[data-id="${id}"]`).forEach(t => t.classList.add('is-selected'));
  const el = $('#xp'); el.hidden = false; document.body.style.overflow = 'hidden';
  renderXP(true);
  if (hasGsap && !RM){ gsap.fromTo(el, {opacity:0}, {opacity:1, duration:.25}); gsap.fromTo('#xpCard', {y:30, scale:.97}, {y:0, scale:1, duration:.45, ease:'power3.out', clearProps:'transform'}); }
  setTimeout(() => { const c = $('[data-xp="close"]'); c && c.focus({preventScroll:true}); }, 60);
}
function closeXP(){
  const el = $('#xp'); const id = openId; openId = null;
  $$('.tile.is-selected').forEach(t => t.classList.remove('is-selected'));
  const done = () => { el.hidden = true; document.body.style.overflow = ''; const t = id && document.querySelector(`.tile[data-id="${id}"]`); t && t.focus({preventScroll:true}); };
  if (hasGsap && !RM) gsap.to(el, {opacity:0, duration:.2, onComplete:() => { done(); el.style.opacity = ''; }}); else done();
}
/* Ver la foto completa */
function openLightbox(){
  const img = $('#xpPhoto > img'); if (!img) return;
  const lb = $('#lightbox'); $('#lbImg').src = img.src; $('#lbImg').alt = img.alt; lb.hidden = false;
  if (hasGsap && !RM) gsap.fromTo(lb, {opacity:0}, {opacity:1, duration:.2});
  $('#lbClose').focus();
}
function closeLightbox(){ $('#lightbox').hidden = true; const z = $('[data-xp="zoom"]'); z && z.focus({preventScroll:true}); }
document.addEventListener('click', e => {
  if (e.target.closest('[data-xp="zoom"]')){ const id = curId(); if (fotosOf(id).length) openGal('a:' + id, fotosOf(id).indexOf(S.activos[id].foto)); else openLightbox(); }
  else if (e.target.id === 'lightbox' || e.target.closest('#lbClose')) closeLightbox();
});
document.addEventListener('keydown', e => { if (e.key === 'Escape' && abierto('#lightbox')){ e.stopImmediatePropagation(); closeLightbox(); } }, true);
if ($('#xpCard')) new ResizeObserver(() => { if (abierto('#xp')){ sizeCols(); drawLines(false); } }).observe($('#xpCard'));
document.addEventListener('input', e => { if (e.target.dataset && e.target.dataset.q) filterGroup(e.target.dataset.q); });

/* ================= Eventos ================= */
document.addEventListener('click', e => {
  const tileEl = e.target.closest('.tile');
  if (tileEl && !drags.length){ openXP(tileEl.dataset.id); return; }
  const co = e.target.closest('[data-co]'); if (co){ selectItem(co.dataset.co); return; }
  const go = e.target.closest('[data-co-go]'); if (go){ selectItem(go.dataset.coGo); return; }
  const t = e.target.closest('button, a'); if (!t) return;
  if (t.dataset.crumb != null){ XP.stack = XP.stack.slice(0, +t.dataset.crumb + 1); XP.sel = null; XP.adding = false; renderXP(true); return; }
  if (t.dataset.crumbOpen){ XP.stack = [t.dataset.crumbOpen]; XP.sel = null; renderXP(true); return; }
  if (t.dataset.only){ t.setAttribute('aria-pressed', t.getAttribute('aria-pressed') !== 'true'); filterGroup(t.dataset.only); return; }
  if (t.dataset.close){ closeModal('#' + t.dataset.close); return; }
  const x = t.dataset.xp;
  if (x === 'close') closeXP();
  else if (x === 'unsel'){ XP.sel = null; renderXP(false); }
  else if (x === 'repall'){ XP.repFor = null; applyRepFor(); }
  else if (x === 'add'){ SIGMA.nuevoComponente(curId()); }
  else if (x === 'addcancel'){ XP.adding = false; renderXP(false); }
  else if (x === 'addrep') SIGMA.abrirRepuesto();
  else if (x === 'addrepcancel'){ XP.addRep = false; renderXP(false); }
  else if (x === 'addrepok') SIGMA.vincularRepuesto(t);
  else if (x === 'quitarrep') SIGMA.quitarRepuesto(t);
  else if (x === 'nofoto'){ const a = S.activos[curId()]; commit(() => removeFoto(curId(), a.foto), 'Se quitó la foto de portada'); }
  else if (x === 'ot') SIGMA.nuevaOT(curId());
  
  else if (x === 'centro') open360(curId());
  else if (t.id === 'v2d') setView('2d');
  else if (t.id === 'v3d') setView('3d');
  else if (t.id === 'btnNuevo' || t.id === 'btnNuevo2') openModal('tray');
  else if (t.id === 'btnEstructura') openUb();
  else if (t.id === 'toastUndo' && undoSnap){ const st = hasGsap && view === '2d' ? Flip.getState('.tile') : null; const antes = JSON.stringify(S); S = JSON.parse(undoSnap); undoSnap = null; SYNC.desde(antes); render(); if (st) Flip.from(st, {targets:'.tile', duration:T(.5), ease:'power3.inOut', absolute:true}); $('#toast').hidden = true; if (view === '3d') build3D(false); if (abierto('#xp')) renderXP(false); }
  else if (t.id === 'btnCenter') center3D();
  else if (t.id === 'btnSpin'){ if (three && three.controls){ three.controls.autoRotate = !three.controls.autoRotate; t.setAttribute('aria-pressed', three.controls.autoRotate); } }
  else if (t.id === 'hintClose'){ $('#hint').hidden = true; try { localStorage.setItem(KEY + '-hint', '1'); } catch(err){} }
  
});
document.addEventListener('keydown', e => {
  if (e.key === 'Escape'){
    if (abierto('#modal')) closeModal('#modal');
    else if (abierto('#modalCfg')) closeModal('#modalCfg');
    else if (abierto('#xp')){ if (XP.sel){ XP.sel = null; renderXP(false); } else closeXP(); }
  }
  const t = e.target;
  if (t.classList && t.classList.contains('tile') && (e.key === 'Enter' || e.key === ' ')){ e.preventDefault(); openXP(t.dataset.id); }
});
document.addEventListener('change', async e => {
  const t = e.target;
  if (t.id === 'xEstado'){ SIGMA.pedirMotivo('activo', curId(), null, t); }
  else if (t.id === 'dEstado'){ SIGMA.pedirMotivo('comp', curId(), +t.dataset.comp, t); }
  else if (t.id === 'xMover'){ const id = curId(); const v = t.value; const name = S.activos[id].nombre;
    if (v === 'tray') commit(() => moveTo(id, {type:'tray'}), `${name} volvió a «Por ubicar»`);
    else { const d = parseDonde(v); commit(() => moveTo(id, d), `${name} quedó en ${placeName(d.lugar)}`); } }
  else if (t.id === 'xpFoto' && t.files[0]){
    try { const urls = await readFotos(t.files); if (!urls.length) throw 0; const id = curId(); const had = !!S.activos[id].foto; commit(() => addFotos(id, urls), had ? (urls.length === 1 ? 'Se agregó 1 foto. Toca «Ampliar» y su estrella para dejarla de portada.' : `Se agregaron ${urls.length} fotos. Elige la portada con la estrella.`) : 'Foto lista: quedó como portada'); }
    catch(err){ toast('No se pudo leer esa imagen. Prueba con una foto JPG o PNG.'); }
  }
  else if (t.id === 'fFoto' && t.files[0]){
    try { pendingFoto = await loadPhoto(t.files[0]); $('#fFotoPrev').src = pendingFoto; $('#fFotoPrev').hidden = false; $('#fFotoTxt').textContent = 'Cambiar foto'; }
    catch(err){ toast('No se pudo leer esa imagen. Prueba con una foto JPG o PNG.'); }
  }
});
document.addEventListener('submit', e => {
  const f = e.target; if (!f.matches || !f.matches('[data-form]')) return; e.preventDefault();
  if (f.id === 'formNuevo'){
    const nombre = $('#fNombre').value.trim();
    if (!nombre){ $('#fNombreErr').hidden = false; $('#fNombre').setAttribute('aria-invalid','true'); $('#fNombre').focus(); return; }
    const tipo = $('#fTipo').value, crit = $('#fCrit').value, donde = $('#fDonde').value, foto = pendingFoto;
    const id = 'n' + (++S.seq);
    closeModal('#modal');
    commit(() => {
      S.activos[id] = {nombre, codigo:'ACT-' + slug(nombre), tipo, estado:'operativo', crit, subs:[], comps:[], reps:[], nuevo:true};
      if (foto) S.activos[id].foto = foto;
      moveTo(id, parseDonde(donde));
    }, donde === 'tray' ? `${nombre} se creó y quedó en «Por ubicar»` : `${nombre} se creó en ${placeName(donde.slice(2))}`);
    warmCovers(() => render());
  }
  if (f.id === 'formComp'){
    const n = $('#iComp').value.trim(); if (!n){ $('#iComp').focus(); return; } const a = S.activos[curId()];
    XP.adding = false; commit(() => { a.comps.push(comp(n)); }, `Se agregó ${n} a ${a.nombre}`);
  }

});


/* ================= Vistas Lista (E1) y Tarjetas (E2): copia fiel del diseño, con datos vivos ================= */
const LV = {q:'', f:'all', open:new Set(), group:'area', sort:'atencion', tgroup:'none', tsort:'atencion'};
const IC = {
  chevR:'<path d="M9 6l6 6-6 6"/>', chevD:'<path d="M6 9l6 6 6-6"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
  shield:'<path d="M12 3l7 3v5c0 4.5-3 8.2-7 10-4-1.8-7-5.5-7-10V6l7-3z"/>',
  arrowR:'<path d="M5 12h14M13 6l6 6-6 6"/>',
  cam:'<path d="M4 8h3l2-3h6l2 3h3v11H4V8z"/><circle cx="12" cy="13" r="3.5"/>'
};
const sv = (p, s, w) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w || 1.8}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;
const TONE_CHIP = {ok:['var(--success-soft)','var(--success-ink)','var(--success)'], warn:['var(--warning-soft)','var(--warning-ink)','var(--warning)'], bad:['var(--danger-soft)','var(--danger)','var(--danger)']};
const PLURAL_TIPO = {camara:'Cámaras de frío', horno:'Hornos', amasadora:'Amasadoras', bomba:'Bombas', caldera:'Calderas', compresor:'Compresores', dosificador:'Dosificadores', otro:'Otros'};
function estChip(estado, big){
  const t = EST[estado].t; const [bg, fg, dot] = TONE_CHIP[t];
  return `<span style="display:inline-flex;align-items:center;gap:6px;height:${big ? 28 : 26}px;padding:0 ${big ? 10 : 9}px;border-radius:${big ? 8 : 7}px;background:${bg};color:${fg};font-size:${big ? 13 : 12}px;font-weight:700;white-space:nowrap"><span style="width:${big ? 8 : 7}px;height:${big ? 8 : 7}px;border-radius:50%;background:${dot}"></span>${EST[estado].l}</span>`;
}
function critChip(c){
  const st = c === 'critica' ? 'border:1px solid #EFB3AD;color:var(--danger)' : c === 'alta' ? 'border:1px solid #F0C796;color:var(--warning-ink)' : 'border:1px solid var(--line);color:var(--muted)';
  return `<span style="display:inline-flex;align-items:center;gap:5px;height:28px;padding:0 10px;border-radius:8px;${st};font-size:13px;font-weight:700">${CRIT[c]}</span>`;
}
function partsOf(id){
  const a = S.activos[id]; const out = [];
  (a.subs||[]).forEach(s => { const x = S.activos[s]; if (!x) return; out.push(EST[x.estado].t); x.comps.forEach(c => out.push(EST[c.e].t)); });
  a.comps.forEach(c => out.push(EST[c.e].t));
  return out;
}
function worst(ts){ return ts.includes('bad') ? 'bad' : ts.includes('warn') ? 'warn' : ts.length ? 'ok' : null; }
const DOTC = {ok:'var(--success)', warn:'var(--warning)', bad:'var(--danger)'};
function noStock(id){ return (S.activos[id].reps||[]).some(r => r.stock === 0); }
function lvItems(){
  const out = [];
  treeOrder(null, 0, []).forEach(({id:lid}) => LG(lid).activos.forEach(id => S.activos[id] && out.push({id, ar:lid})));
  S.tray.forEach(id => S.activos[id] && out.push({id, ar:null}));
  return out;
}
function lvMatch(x, f){
  const a = S.activos[x.id];
  if (f === 'issues' && tone(x.id) === 'ok') return false;
  if (f === 'nostock' && !noStock(x.id)) return false;
  if (f === 'ot') return false;
  if (!LV.q) return true;
  const hay = norm([a.nombre, a.codigo, tipoN(a), x.ar ? pathLabel(x.ar) : 'sin ubicacion por ubicar', ...(a.subs||[]).map(s => S.activos[s] ? S.activos[s].nombre : ''), ...a.comps.map(c => c.n), ...(a.reps||[]).map(r => r.n)].join(' '));
  return hay.includes(norm(LV.q));
}
function lvSort(list, mode){
  const cr = {critica:0, alta:1, media:2, baja:3};
  return [...list].sort((p, q) => {
    const A = S.activos[p.id], B = S.activos[q.id];
    if (mode === 'nombre') return A.nombre.localeCompare(B.nombre, 'es');
    if (mode === 'criticidad') return cr[A.crit] - cr[B.crit] || A.nombre.localeCompare(B.nombre, 'es');
    return RANKT[tone(p.id)] - RANKT[tone(q.id)];
  });
}
function lvGroups(list, mode){
  if (mode === 'none') return [{key:'all', title:'', items:list}];
  if (mode === 'tipo'){ const ks = [...new Set(list.map(x => tipoN(S.activos[x.id])))]; return ks.map(k => ({key:k, title:k, items:list.filter(x => tipoN(S.activos[x.id]) === k)})); }
  if (mode === 'estado'){ const ks = Object.keys(EST).filter(k => list.some(x => S.activos[x.id].estado === k)); return ks.map(k => ({key:k, title:EST[k].l, items:list.filter(x => S.activos[x.id].estado === k)})); }
  const gs = [];
  treeOrder(null, 0, []).forEach(({id:lid}) => { const its = list.filter(x => x.ar === lid); if (its.length) gs.push({key:lid, title:pathLabel(lid), meta:'', items:its}); });
  const tray = list.filter(x => !x.ar); if (tray.length) gs.push({key:'tray', title:'Sin ubicación', items:tray, tray:true});
  return gs;
}
function lvGroupHead(g){
  const subsN = g.items.reduce((n, x) => n + (S.activos[x.id].subs||[]).length, 0);
  const avisos = g.items.reduce((n, x) => n + issues(x.id).length + (EST[S.activos[x.id].estado].t !== 'ok' ? 1 : 0), 0);
  const meta = (g.meta || '') + cnt(g.items.length,'Activo') + (subsN ? ' · ' + cnt(subsN,'Subactivo') : '');
  const right = g.tray ? `<button type="button" data-view="2d" style="margin-left:6px;border:0;background:none;padding:0;font-size:13px;font-weight:700;color:var(--sigma-blue-ink);text-decoration:underline;cursor:pointer">Asignar ubicación</button>`
    : avisos ? `<span style="margin-left:6px;display:inline-flex;align-items:center;gap:5px;height:22px;padding:0 8px;border-radius:6px;background:var(--danger-soft);color:var(--danger);font-size:12px;font-weight:700">${avisos} ${avisos === 1 ? 'aviso' : 'avisos'}</span>`
    : `<span style="margin-left:6px;display:inline-flex;align-items:center;height:22px;padding:0 8px;border-radius:6px;background:var(--success-soft);color:var(--success-ink);font-size:12px;font-weight:700">Todo bien</span>`;
  return `<div style="display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:12px 20px;border-top:1px solid var(--line);background:var(--rail)">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/></svg>
    <strong style="font-size:14px">${esc(g.title)}</strong><span style="font-size:13px;color:var(--muted)">${meta}</span>${right}</div>`;
}
const GRID = 'display:grid;grid-template-columns:40px minmax(0,2.1fr) minmax(0,1.7fr) 168px 160px 96px 112px;gap:14px;align-items:center';
function depChips(id){
  const a = S.activos[id]; const out = [];
  const subs = (a.subs||[]).map(s => S.activos[s]).filter(Boolean);
  const chip = (bg, fg, txt, w, title) => `<span${title ? ` title="${title}"` : ''} style="display:inline-flex;align-items:center;gap:5px;height:26px;padding:0 8px;border-radius:7px;background:${bg};color:${fg};font-size:12px;font-weight:700">${txt}${w && w !== 'ok' ? `<span style="width:7px;height:7px;border-radius:50%;background:${DOTC[w]}"></span>` : ''}</span>`;
  if (subs.length){ const w = worst(subs.map(s => EST[s.estado].t)); out.push(chip('var(--sigma-blue-soft)','var(--sigma-blue-ink)', cnt(subs.length,'Subactivo'), w)); }
  if (a.comps.length){ const w = worst(a.comps.map(c => EST[c.e].t)); out.push(chip('var(--sigma-cyan-soft)','var(--sigma-cyan-dark)', cnt(a.comps.length,'Componente'), w)); }
  if ((a.reps||[]).length){ const w = worst(a.reps.map(r => stock(r).t)); out.push(chip('var(--rep-soft)','var(--rep-ink)', cnt(a.reps.length,'Repuesto'), w)); }
  return out.join('') || '<span style="font-size:12px;color:var(--muted)">Sin partes registradas</span>';
}
function healthHTML(id){
  const ts = partsOf(id); if (!ts.length) return '<span style="font-size:12px;color:var(--muted)">Sin partes registradas</span>';
  const n = {ok:ts.filter(t => t === 'ok').length, warn:ts.filter(t => t === 'warn').length, bad:ts.filter(t => t === 'bad').length};
  const bad = n.warn + n.bad;
  const bars = ['ok','warn','bad'].filter(k => n[k]).map(k => `<span style="flex:${n[k]};background:${DOTC[k]}"></span>`).join('');
  return `<div style="display:flex;flex-direction:column;gap:5px"><div role="img" aria-label="De ${ts.length} partes: ${n.ok} bien, ${n.warn} con aviso, ${n.bad} fuera de servicio o detenidas" style="display:flex;height:8px;gap:2px;border-radius:4px;overflow:hidden">${bars}</div>
    <span style="font-size:12px;font-weight:600;color:${bad ? (n.bad ? 'var(--danger)' : 'var(--warning-ink)') : 'var(--success-ink)'}">${bad ? `${bad} de ${ts.length} con aviso` : `${ts.length} de ${ts.length} bien`}</span></div>`;
}
function nestedHTML(id){
  const a = S.activos[id]; const rows = [];
  const row = (label, color, ink, title, sub, chip, extra, dashed, open, sel, fotos) => `<div class="nrow" data-open="${open}"${sel ? ` data-sel="${sel}"` : ''} tabindex="0" title="Ver en el explorador" style="position:relative;display:grid;grid-template-columns:116px minmax(0,1fr) 168px minmax(0,1fr);gap:12px;align-items:center;padding:10px 12px;border:1px ${dashed ? 'dashed #F0C796' : 'solid var(--line)'};border-radius:10px;background:var(--surface)">
    <span aria-hidden="true" style="position:absolute;left:-19px;top:50%;width:18px;height:2px;background:#D9DFEA"></span>
    <span style="display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:800;color:${ink}"><span style="width:10px;height:10px;border-radius:3px;background:${color}"></span>${label}</span>
    <span class="nrow-tit">${miniFotos(fotos)}<span style="display:flex;flex-direction:column;min-width:0"><strong style="font-size:14px">${title}</strong><span style="font-size:12px;color:var(--muted)">${sub}</span></span></span>
    <span>${chip}</span>${extra}</div>`;
  (a.subs||[]).forEach(sid => { const s = S.activos[sid]; if (!s) return;
    const bad = s.comps.filter(c => c.e !== 'operativo');
    const extra = bad.length ? `<span style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;font-size:12px">${bad.map(c => `<span style="display:inline-flex;align-items:center;gap:5px;height:24px;padding:0 8px;border-radius:6px;background:var(--sigma-cyan-soft);color:var(--sigma-cyan-dark);font-weight:700">↳ ${esc(c.n)}</span><span style="font-weight:700;color:${DOTC[EST[c.e].t]}">● ${EST[c.e].l}</span>`).join('')}</span>`
      : `<span style="font-size:12px;color:var(--muted)">${s.comps.length ? cnt(s.comps.length,'Componente') + ' bien' : 'Sin partes registradas'}</span>`;
    rows.push(row('SUBACTIVO','var(--sigma-blue)','var(--sigma-blue-ink)', esc(s.nombre), esc(s.codigo) + (s.estado === 'mantenimiento' ? ' · en el taller' : ''), estChip(s.estado), extra, false, sid, '', [s.foto])); });
  const repFor = n => (a.reps||[]).filter(r => r.para && norm(r.para) === norm(n));
  const badC = a.comps.filter(c => c.e !== 'operativo'), okC = a.comps.filter(c => c.e === 'operativo');
  badC.forEach(c => { const rs = repFor(c.n); const ci = a.comps.indexOf(c);
    const extra = rs.length ? `<span style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;font-size:12px"><span style="color:var(--muted)">Repuesto:</span>${rs.map(r => { const s = stock(r); return `<span style="display:inline-flex;align-items:center;gap:5px;height:24px;padding:0 8px;border-radius:6px;background:var(--rep-soft);color:var(--rep-ink);font-weight:700">${esc(r.n)}</span><span style="font-weight:700;color:${DOTC[s.t]}">● ${s.l}</span>`; }).join('')}</span>` : '<span style="font-size:12px;color:var(--muted)">Sin repuestos vinculados</span>';
    rows.push(row('COMPONENTE','var(--sigma-cyan)','var(--sigma-cyan-dark)', esc(c.n), 'Parte del activo', estChip(c.e), extra, false, id, 'c:' + ci, [c.foto])); });
  if (okC.length){ const names = okC.slice(0, 3).map(c => esc(c.n)).join(' · ') + (okC.length > 3 ? ` y ${okC.length - 3} más` : '');
    const linked = okC.some(c => repFor(c.n).length);
    rows.push(row('COMPONENTE','var(--sigma-cyan)','var(--sigma-cyan-dark)', names, cnt(okC.length,'Parte'), `<span style="display:inline-flex;align-items:center;gap:6px;height:26px;padding:0 9px;border-radius:7px;background:var(--success-soft);color:var(--success-ink);font-size:12px;font-weight:700"><span style="width:7px;height:7px;border-radius:50%;background:var(--success)"></span>${okC.length === 1 ? 'Operativa' : 'Operativas'}</span>`, `<span style="font-size:12px;color:var(--muted)">${linked ? 'Con repuestos vinculados' : 'Sin repuestos vinculados'}</span>`, false, id, okC.length === 1 ? 'c:' + a.comps.indexOf(okC[0]) : '', okC.slice(0, 3).map(c => c.foto))); }
  const gen = (a.reps||[]).filter(r => !r.para);
  if (gen.length) rows.push(row('REPUESTOS','var(--rep)','var(--rep-ink)', 'Le sirven a todo el activo', 'Se sacan de bodega', `<span style="display:flex;flex-direction:column;gap:2px;font-size:12px">${gen.map(r => { const s = stock(r); return `<span><strong>${esc(r.n)}</strong> <span style="color:${s.t === 'ok' ? 'var(--success-ink)' : s.t === 'warn' ? 'var(--warning-ink)' : 'var(--danger)'};font-weight:700">· ${s.l}</span></span>`; }).join('')}</span>`, `<button type="button" data-toast="inv" style="justify-self:start;border:0;background:none;padding:0;font-size:12px;font-weight:700;color:var(--sigma-blue-ink);text-decoration:underline;cursor:pointer">Ver en Inventario</button>`, true, id, gen.length === 1 ? 'r:' + a.reps.indexOf(gen[0]) : '', gen.slice(0, 3).map(r => r.foto)));
  if (!rows.length) rows.push(`<div style="padding:10px 12px;font-size:13px;color:var(--muted)">Todavía no tiene partes registradas. Ábrelo para agregarlas.</div>`);
  return `<div style="padding:4px 20px 18px 74px;background:#FCFBFF;display:flex;flex-direction:column"><div style="position:relative;display:flex;flex-direction:column;gap:6px;padding-left:28px"><span aria-hidden="true" style="position:absolute;left:9px;top:0;bottom:22px;width:2px;background:#D9DFEA"></span>${rows.join('')}</div></div>`;
}
function lvRow(x){
  const id = x.id, a = S.activos[id], open = LV.open.has(id);
  const loc = x.ar ? tipoN(a) : 'Por ubicar';
  return `<div class="lrow" data-card="${id}" tabindex="0" aria-label="${esc(a.nombre)}, ${EST[a.estado].l}. Ver sus partes" style="${GRID};padding:14px 20px;border-top:1px solid var(--line)${open ? ';background:#FCFBFF' : ''}">
    <button type="button" data-lvt="${id}" aria-label="${open ? 'Contraer' : 'Expandir'} ${esc(a.nombre)}" aria-expanded="${open}" style="width:32px;height:32px;border:1px solid var(--line);border-radius:8px;background:var(--surface);color:var(--ink);display:flex;align-items:center;justify-content:center;cursor:pointer">${sv(open ? IC.chevD : IC.chevR, 16, 2.2)}</button>
    <div style="display:flex;align-items:center;gap:12px;min-width:0"><span style="width:44px;height:44px;flex:none;border-radius:12px;background:var(--sigma-purple-soft);color:var(--sigma-purple);display:flex;align-items:center;justify-content:center;overflow:hidden">${a.foto ? `<img src="${a.foto}" alt="" style="width:100%;height:100%;object-fit:cover">` : sv(ICONS[a.tipo] || ICONS.otro, 22)}</span>
      <span style="display:flex;flex-direction:column;min-width:0"><strong style="font-size:15px;font-weight:800">${esc(a.nombre)}</strong><span style="font-size:12px;color:var(--muted)">${esc(a.codigo)} · ${esc(loc)}</span></span></div>
    <div style="display:flex;flex-wrap:wrap;gap:6px">${depChips(id)}</div>
    <span>${estChip(a.estado, true)}</span>
    ${healthHTML(id)}
    <span>${critChip(a.crit)}</span>
    <button type="button" data-c360="${id}" title="Abre la ficha completa del activo" style="justify-self:end;height:40px;padding:0 12px;border:1px solid var(--sigma-blue);border-radius:10px;background:var(--surface);color:var(--sigma-blue-ink);font-size:13px;font-weight:700;display:flex;align-items:center;cursor:pointer;white-space:nowrap">Abrir 360°</button>
  </div>${open ? nestedHTML(id) : ''}`;
}
function chipF(key, label, n){
  const on = LV.f === key;
  return `<button type="button" data-lf="${key}" aria-pressed="${on}" style="height:34px;padding:0 14px;border:1px solid ${on ? 'var(--sigma-purple)' : 'var(--line)'};border-radius:17px;background:${on ? 'var(--sigma-purple-soft)' : 'var(--surface)'};color:${on ? 'var(--sigma-purple-dark)' : 'var(--ink)'};font-size:13px;font-weight:${on ? 700 : 600};cursor:pointer">${label} · ${n}</button>`;
}
function selectHTML(id, label, opts, val, border){
  return `<label style="display:flex;align-items:center;gap:8px;height:44px;padding:0 12px;${border ? 'border:1px solid var(--field)' : 'background:var(--canvas)'};border-radius:${border ? 10 : 12}px;font-size:13px;color:var(--muted)">${label}<select id="${id}" style="border:0;background:transparent;font-size:14px;font-weight:700;color:var(--ink);cursor:pointer">${opts.map(([v, l]) => `<option value="${v}"${v === val ? ' selected' : ''}>${l}</option>`).join('')}</select></label>`;
}
const LEGEND = `<div style="display:flex;flex-wrap:wrap;gap:6px 14px;font-size:12px;font-weight:600;color:var(--muted)">${[['var(--sigma-purple)','Activo'],['var(--sigma-blue)','Subactivo'],['var(--sigma-cyan)','Componente'],['var(--rep)','Repuesto']].map(([c, l]) => `<span style="display:flex;align-items:center;gap:6px"><span style="width:10px;height:10px;border-radius:3px;background:${c}"></span>${l}</span>`).join('')}</div>`;
function renderLista(){
  const all = lvItems();
  if (!$('#lvBody')){
    $('#lv').innerHTML = `<section aria-label="Activos" style="background:var(--surface);border-radius:20px;box-shadow:var(--e1);display:flex;flex-direction:column;overflow:hidden">
      <div style="padding:16px 20px;display:flex;flex-direction:column;gap:12px;border-bottom:1px solid var(--line)">
        <div style="display:flex;flex-wrap:wrap;align-items:center;gap:10px">
          <label style="flex:1 1 300px;display:flex;align-items:center;gap:10px;height:44px;padding:0 14px;border:1px solid var(--field);border-radius:10px;color:var(--muted)">${sv(IC.search, 20)}<input class="lv-q" aria-label="Buscar activos, partes o repuestos" placeholder="Busca un activo, una parte o un repuesto…" value="${esc(LV.q)}" style="flex:1;min-width:0;border:0;outline:none;font-size:15px;color:var(--ink);background:transparent"></label>
          ${selectHTML('lvGroup','Agrupar por',[['area','Ubicación'],['tipo','Tipo de activo'],['estado','Estado'],['none','Sin agrupar']], LV.group, true)}
          ${selectHTML('lvSort','Ordenar',[['atencion','Primero los que necesitan atención'],['nombre','Nombre'],['criticidad','Criticidad']], LV.sort, true)}
        </div>
        <div style="display:flex;flex-wrap:wrap;align-items:center;gap:8px"><span id="lvChips" style="display:contents"></span><div style="flex:1 1 20px"></div>${LEGEND}</div>
      </div>
      <div style="overflow-x:auto"><div style="min-width:1040px">
        <div style="${GRID};padding:10px 20px;background:var(--canvas);font-size:12px;font-weight:700;color:var(--muted)"><span></span><span>Activo</span><span>Lo que depende de él</span><span>Estado del activo</span><span>Salud de sus partes</span><span>Criticidad</span><span></span></div>
        <div id="lvBody"></div>
      </div></div></section>`;
  }
  $('#lvChips').innerHTML = chipF('all','Todos', all.length) + chipF('issues','Necesitan atención', all.filter(x => tone(x.id) !== 'ok').length) + chipF('nostock','Repuestos sin stock', all.filter(x => noStock(x.id)).length) + chipF('ot','Con OT abiertas', 0);
  const list = lvSort(all.filter(x => lvMatch(x, LV.f)), LV.sort);
  const gs = lvGroups(list, LV.group);
  $('#lvBody').innerHTML = list.length ? gs.map(g => (g.title ? lvGroupHead(g) : '') + g.items.map(lvRow).join('')).join('')
    : `<div style="padding:28px 20px;border-top:1px solid var(--line);text-align:center;color:var(--muted);font-size:14px">No encontramos activos con esa búsqueda o filtro.</div>`;
}
/* ---------- Tarjetas (E2) ---------- */
function tcAttention(id){
  const a = S.activos[id]; const out = [];
  (a.subs||[]).forEach(sid => { const s = S.activos[sid]; if (!s) return;
    s.comps.forEach((c, ci) => { if (c.e !== 'operativo') out.push({t:EST[c.e].t, chip:EST[c.e].l, title:c.n, sub:'Componente del ' + s.nombre.replace(/\s+\S+$/, ''), open:sid, sel:'c:' + ci}); });
    if (s.estado !== 'operativo') out.push({t:EST[s.estado].t, chip:s.estado === 'mantenimiento' ? 'En el taller' : EST[s.estado].l, title:s.nombre, sub:'Subactivo ' + EST[s.estado].l.toLowerCase(), open:sid}); });
  a.comps.forEach((c, ci) => { if (c.e === 'operativo') return; const sinStock = (a.reps||[]).some(r => r.para && norm(r.para) === norm(c.n) && r.stock === 0);
    out.push({t:EST[c.e].t, chip:EST[c.e].l, title:c.n, sub:sinStock ? 'Su repuesto está sin stock' : 'Componente del activo', open:id, sel:'c:' + ci}); });
  return out.sort((p, q) => RANKT[p.t] - RANKT[q.t]);
}
function tcCell(label, color, n, note, noteColor, first){
  return `<div style="padding:10px 12px;${first ? '' : 'border-left:1px solid var(--line);'}display:flex;flex-direction:column;gap:2px"><span style="font-size:11px;font-weight:700;color:${n ? color : 'var(--muted)'}">${label}</span><strong style="font-size:22px;line-height:1.1${n ? '' : ';color:var(--muted)'}">${n}</strong>${note}</div>`;
}
function tcCard(x){
  const id = x.id, a = S.activos[id], e = EST[a.estado], iss = issues(id), urgent = iss.length || e.t !== 'ok';
  const [bg, fg, dot] = TONE_CHIP[e.t];
  const critCol = a.crit === 'critica' ? 'var(--danger)' : a.crit === 'alta' ? 'var(--warning-ink)' : 'var(--muted)';
  const chips = (glass) => `<span style="position:absolute;top:${glass ? 14 : 12}px;left:${glass ? 14 : 12}px;display:inline-flex;align-items:center;gap:6px;height:30px;padding:0 12px;border-radius:15px;background:var(--surface);color:${fg};font-size:12px;font-weight:800${glass ? '' : ';box-shadow:0 1px 3px rgba(23,34,59,.1)'}"><span style="width:8px;height:8px;border-radius:50%;background:${dot}"></span>${e.l}</span>
    <span style="position:absolute;top:${glass ? 14 : 12}px;right:${glass ? 14 : 12}px;display:inline-flex;align-items:center;gap:5px;height:30px;padding:0 12px;border-radius:15px;background:var(--surface);color:${critCol};font-size:12px;font-weight:800${glass ? '' : ';box-shadow:0 1px 3px rgba(23,34,59,.1)'}">${sv(IC.shield, 13, 2.2)}${CRIT[a.crit]}</span>`;
  const cover = a.foto
    ? `<div role="img" aria-label="Foto de portada de ${esc(a.nombre)}" style="position:relative;height:184px;background:#2C3448 url('${a.foto}') center/cover no-repeat">
        <span style="position:absolute;inset:0;background:linear-gradient(180deg,rgba(20,27,51,0) 40%,rgba(20,27,51,.55) 100%)"></span>${chips(true)}
        ${iss.length ? `<span style="position:absolute;bottom:14px;left:14px;display:inline-flex;align-items:center;gap:6px;height:30px;padding:0 12px;border-radius:15px;background:var(--danger);color:#fff;font-size:12px;font-weight:800">${sv(I.alert, 14, 2.4)}${iss.length} ${iss.length === 1 ? 'aviso' : 'avisos'} en sus piezas</span>` : ''}</div>`
    : `<div style="position:relative;height:184px;margin:10px 10px 0;border-radius:16px;border:2px dashed #CDD4E0;background:var(--rail);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--muted)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${IC.cam}</svg>
        <label style="height:38px;padding:0 14px;border:1px solid var(--line);border-radius:10px;background:var(--surface);color:var(--ink);font-size:13px;font-weight:700;display:flex;align-items:center;cursor:pointer">Agregar foto de portada<input type="file" accept="image/*" data-tcfoto="${id}" class="sr"></label>
        ${chips(false)}
        ${iss.length ? `<span style="position:absolute;bottom:12px;left:12px;display:inline-flex;align-items:center;gap:6px;height:28px;padding:0 10px;border-radius:14px;background:var(--danger);color:#fff;font-size:12px;font-weight:800">${sv(I.alert, 14, 2.4)}${iss.length} ${iss.length === 1 ? 'aviso' : 'avisos'}</span>` : ''}</div>`;
  const subs = (a.subs||[]).map(s => S.activos[s]).filter(Boolean);
  const taller = subs.filter(s => s.estado === 'mantenimiento').length, subBad = subs.filter(s => EST[s.estado].t !== 'ok').length;
  const compBad = a.comps.filter(c => c.e !== 'operativo').length;
  const reps = a.reps || []; const sin = reps.filter(r => r.stock === 0).length, pocos = reps.filter(r => r.stock > 0 && r.stock <= r.min).length;
  const note = (t, c) => `<span style="font-size:11px;font-weight:700;color:${c}">${t}</span>`;
  const grid = `<div style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));border-radius:14px;background:var(--canvas)">
    ${tcCell('Subactivos','var(--sigma-blue-ink)', subs.length, !subs.length ? '<span style="font-size:11px;color:var(--muted)">No tiene</span>' : taller ? note(`${taller} en taller`,'var(--warning-ink)') : subBad ? note(`${subBad} con aviso`,'var(--danger)') : note('Todos operativos','var(--success-ink)'), true)}
    ${tcCell('Componentes','var(--sigma-cyan-dark)', a.comps.length, !a.comps.length ? '<span style="font-size:11px;color:var(--muted)">No tiene</span>' : compBad ? note(`${compBad} con aviso`,'var(--warning-ink)') : note('Todos operativos','var(--success-ink)'))}
    ${tcCell('Repuestos','var(--rep-ink)', reps.length, !reps.length ? `<button type="button" data-xpopen="${id}" style="border:0;background:none;padding:0;text-align:left;font-size:11px;font-weight:700;color:var(--sigma-blue-ink);text-decoration:underline;cursor:pointer">Vincular</button>` : sin ? note(`${sin} sin stock`,'var(--danger)') : pocos ? note(`${pocos} ${pocos === 1 ? 'quedan pocos' : 'con pocos'}`,'var(--warning-ink)') : note('Con stock','var(--success-ink)'))}
  </div>`;
  const att = tcAttention(id);
  const body2 = att.length ? `<ul class="tc-att" aria-label="Lo que necesita atención"><li class="tc-att-h" style="display:block">Necesita atención · ${att.length}</li>${att.slice(0, 3).map(it => `<li data-open="${it.open}"${it.sel ? ` data-sel="${it.sel}"` : ''} title="Ver en el explorador"><i style="background:${DOTC[it.t]}"></i><span><strong>${esc(it.title)}</strong><small><b style="color:${TONE_CHIP[it.t][1]}">${esc(it.chip)}</b> · ${esc(it.sub)}</small></span></li>`).join('')}${att.length > 3 ? `<li style="display:block"><button type="button" class="tc-more" data-xpopen="${id}">Ver los ${att.length} avisos ›</button></li>` : ''}</ul>`
    : `<div style="display:flex;align-items:center;gap:10px;padding:10px 12px;border-radius:12px;background:var(--success-soft);color:var(--success-ink);font-size:13px;font-weight:700">${sv('<circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.7 2.7L16 9.5"/>', 18, 2.2)}Todo en orden</div>`;
  const where = x.ar ? esc(placeLabel(id)) : `Por ubicar · <button type="button" data-view="2d" style="border:0;background:none;padding:0;font-size:13px;font-weight:700;color:var(--sigma-blue-ink);text-decoration:underline;cursor:pointer">asignar ubicación</button>`;
  return `<article class="tcard" data-card="${id}" tabindex="0" aria-label="${esc(a.nombre)}, ${e.l}. Ver sus partes" style="background:var(--surface);border-radius:22px;box-shadow:${urgent && iss.length ? '0 0 0 1.5px rgba(199,53,43,.35),0 12px 32px rgba(199,53,43,.10)' : 'var(--e2)'};display:flex;flex-direction:column;overflow:hidden">
    ${cover}
    <div style="padding:18px 20px;display:flex;flex-direction:column;gap:14px">
      <div style="display:flex;flex-direction:column;gap:3px"><strong style="font-size:19px;font-weight:800;letter-spacing:-.01em;line-height:1.25">${esc(a.nombre)}</strong><span style="font-size:13px;color:var(--muted)">${esc(a.codigo)} · ${where}</span></div>
      ${grid}${body2}
    </div>
    <div style="margin-top:auto;display:flex;gap:10px;padding:0 20px 20px">
      <button type="button" data-c360="${id}" title="Abre la ficha completa del activo" style="flex:1;height:44px;border:0;border-radius:12px;background:var(--canvas);color:var(--ink);font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;gap:6px;cursor:pointer">Abrir 360°${sv(IC.arrowR, 16, 2)}</button>
      <button type="button" data-toast="ot" data-name="${esc(a.nombre)}" style="flex:1;height:44px;border:0;border-radius:12px;background:var(--sigma-purple);color:#fff;font-size:13px;font-weight:700;cursor:pointer">Crear OT</button>
    </div></article>`;
}
function renderTarjetas(){
  if (!$('#tvBody')){
    $('#tv').innerHTML = `<div style="display:flex;flex-direction:column;gap:20px">
      <div style="display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:12px;border-radius:18px;background:var(--surface);box-shadow:var(--e1)">
        <label style="flex:1 1 280px;display:flex;align-items:center;gap:10px;height:44px;padding:0 14px;border-radius:12px;background:var(--canvas);color:var(--muted)">${sv(IC.search, 20)}<input class="lv-q" aria-label="Buscar activos, componentes o repuestos" placeholder="Busca un activo, un componente o un repuesto…" value="${esc(LV.q)}" style="flex:1;min-width:0;border:0;outline:none;font-size:15px;color:var(--ink);background:transparent"></label>
        ${selectHTML('tvGroup','Agrupar',[['none','Sin agrupar'],['area','Ubicación'],['tipo','Tipo de activo'],['estado','Estado']], LV.tgroup)}
        ${selectHTML('tvSort','Orden',[['atencion','Primero los que necesitan atención'],['nombre','Nombre'],['criticidad','Criticidad']], LV.tsort)}
      </div>
      <div id="tvBody"></div></div>`;
  }
  const list = lvSort(lvItems().filter(x => lvMatch(x, 'all')), LV.tsort);
  const gs = lvGroups(list, LV.tgroup);
  const grid = its => `<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(min(330px,100%),1fr));gap:20px">${its.map(tcCard).join('')}</div>`;
  $('#tvBody').innerHTML = !list.length ? `<div style="padding:28px;border-radius:18px;background:var(--surface);text-align:center;color:var(--muted)">No encontramos activos con esa búsqueda.</div>`
    : gs.map(g => g.title ? `<section style="display:flex;flex-direction:column;gap:12px;margin-bottom:22px"><h3 style="margin:0;font-size:14px;font-weight:800;display:flex;align-items:center;gap:8px">${esc(g.title)}<span style="font-size:13px;color:var(--muted);font-weight:600">· ${cnt(g.items.length,'Activo')}</span></h3>${grid(g.items)}</section>` : grid(g.items)).join('');
}
function renderCurrent(){ if (view === 'lista') renderLista(); else if (view === 'tarjetas') renderTarjetas(); }
document.addEventListener('change', async e => {
  const t = e.target;
  if (t.id === 'lvGroup'){ LV.group = t.value; renderLista(); }
  else if (t.id === 'lvSort'){ LV.sort = t.value; renderLista(); }
  else if (t.id === 'tvGroup'){ LV.tgroup = t.value; renderTarjetas(); }
  else if (t.id === 'tvSort'){ LV.tsort = t.value; renderTarjetas(); }
  else if (t.dataset && t.dataset.tcfoto && t.files[0]){ try { const url = await loadPhoto(t.files[0]); const a = S.activos[t.dataset.tcfoto]; commit(() => addFotos(t.dataset.tcfoto, [url], true), 'Foto lista: quedó como portada'); } catch(err){ toast('No se pudo leer esa imagen. Prueba con una foto JPG o PNG.'); } }
});
document.addEventListener('input', e => { if (e.target.classList && e.target.classList.contains('lv-q')){ LV.q = e.target.value.trim(); if (view === 'lista') renderLista(); else renderTarjetas(); } });
function openXPsel(id, sel){ openXP(id); if (sel){ XP.sel = sel; renderXP(false); } }
function open360(id){ SIGMA.abrir360(id); }
function toggleIO(force){ const m = $('#menuIO'), b = $('#btnIO'); if (!m) return; const open = force != null ? force : m.hidden; m.hidden = !open; b.setAttribute('aria-expanded', open); if (open){ const f = m.querySelector('button'); f && f.focus(); } }
document.addEventListener('click', e => {
  const c3 = e.target.closest('[data-c360]'); if (c3){ open360(c3.dataset.c360); return; }
  if (e.target.closest('#btnIO')){ toggleIO(); return; }
  const io = e.target.closest('[data-io]'); if (io){ toggleIO(false); SIGMA.importarExportar(io.dataset.io); return; }
  if (!e.target.closest('.menu-wrap')) toggleIO(false);
  const op = e.target.closest('[data-open]');
  if (op && !e.target.closest('button, a, label, input, select')){ openXPsel(op.dataset.open, op.dataset.sel); return; }
  const card = e.target.closest('[data-card]');
  if (card && !e.target.closest('button, a, label, input, select')){ openXP(card.dataset.card); return; }
});
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && abierto('#menuIO')){ toggleIO(false); $('#btnIO').focus(); return; }
  const t = e.target; if ((e.key === 'Enter' || e.key === ' ') && t.dataset && t === document.activeElement){ if (t.dataset.card){ e.preventDefault(); openXP(t.dataset.card); } else if (t.dataset.open){ e.preventDefault(); openXPsel(t.dataset.open, t.dataset.sel); } }
});
document.addEventListener('click', e => { const mt = e.target.closest('[data-mtab]'); if (mt){ SIGMA.pestana(mt.dataset.mtab); return; } const tt = e.target.closest('[data-toast]'); if (tt) toast(tt.dataset.toast === 'ot' ? `Se abre «Nueva OT» con «${tt.dataset.name || 'este activo'}» ya elegido.` : 'En SIGMA esto abre el Inventario filtrado por este activo.'); });

function topIds(){ return lvItems(); }
/* ================= Cambio de vista ================= */
async function setView(v, first){
  if (v === view && !first) return; view = v;
  try { localStorage.setItem(KEY + '-view', v); } catch(e){}
  $$('.seg--views button').forEach(b => b.setAttribute('aria-pressed', b.dataset.view === v));
  const help = {lista:'Todos los activos en una tabla. Toca una fila para ver sus partes.', tarjetas:'Cada activo con su foto y lo que necesita atención.', '2d':'Arrastra cada activo a su lugar en la planta.', '3d':'Recorre la planta por áreas y revisa los avisos.'}; $('#viewHelp').textContent = help[v] || ''; $('#hint').style.display = v === '2d' ? '' : 'none';
  const full = v !== '2d';
  $('#work').classList.toggle('is-full', full); $('#work').classList.toggle('is-3d', v === '3d');
  $('#view2d').hidden = v !== '2d'; $('#view3d').hidden = v !== '3d'; $('#viewLista').hidden = v !== 'lista'; $('#viewTarjetas').hidden = v !== 'tarjetas';
  if (three && v !== '3d') three.running = false;
  if (v === '3d'){
    try { await document.fonts.ready; } catch(e){}
    if (await SIGMA.cargarThree() && init3D()){ build3D(true); if (!three.running){ three.running = true; loop(); } }
    bindDrag();
  } else if (v === '2d'){
    render();
    if (hasGsap && !first) gsap.fromTo('.area', {opacity:0, y:12}, {opacity:1, y:0, duration:T(.4), stagger:T(.05), clearProps:'opacity,transform'});
  } else {
    bindDrag(); renderCurrent();
    if (hasGsap && !RM && !first) gsap.fromTo(v === 'lista' ? '.lv-area' : '.tc', {opacity:0, y:10}, {opacity:1, y:0, duration:.35, stagger:.02, clearProps:'opacity,transform'});
  }
}

/* ================= 3D: panel del área y recorrido de avisos ================= */
function renderAreaPanel(){
  const box = $('#areaPanel'); if (!box || !three) return;
  const i = three.focus; const a = i != null ? three.areaNav[i] : null;
  if (!a){ box.hidden = true; return; }
  const n = three.areaNav.length;
  const row = id => { const s = S.activos[id]; if (!s) return ''; const t = tone(id); return `<button type="button" class="ap-row" data-ap="${id}"><span class="tile-ico">${icoHTML(id)}</span><div><strong>${esc(s.nombre)}</strong><span class="chip chip--${t}"><i></i>${esc(toneText(id))}</span></div><span class="ap-open" data-apx="${id}" role="button" tabindex="0" aria-label="Explorar ${esc(s.nombre)}">Abrir ›</span></button>`; };
  let list = '';
  const L = a.lid ? LG(a.lid) : null;
  if (L && L.hijos.length){
    if (L.activos.length) list += `<div class="ap-line">Sin dividir</div>` + L.activos.map(row).join('');
    L.hijos.forEach(h => { const c = LG(h); const ids = allIn(h); list += `<div class="ap-line">${esc(c.nombre)}${c.hijos.length ? ' · ' + esc(childrenSummary(h)) : ''}</div>` + (ids.length ? ids.map(row).join('') : '<div class="ap-line" style="font-weight:600;text-transform:none;letter-spacing:0">Sin activos</div>'); });
  } else list = a.ids.map(row).join('') || '<div class="ap-line">Sin activos</div>';
  box.style.setProperty('--ac', a.color);
  box.innerHTML = `<div class="ap-head"><div><small>${a.tray ? 'Zona de espera' : esc(L ? tipoL(L.tipo).s : 'Lugar')} · ${i + 1} de ${n}</small><h3><i></i>${esc(a.name)}</h3>
      <span class="pill pill--${a.bad ? 'bad' : 'ok'}" style="margin-top:6px">${a.bad ? a.bad + ' con avisos' : 'Todo bien'}</span></div>
      <div class="ap-nav"><button type="button" class="icon-btn" data-apnav="-1" aria-label="Lugar anterior">${svg('<path d="M15 6l-6 6 6 6"/>')}</button><button type="button" class="icon-btn" data-apnav="1" aria-label="Lugar siguiente">${svg('<path d="M9 6l6 6-6 6"/>')}</button><button type="button" class="icon-btn" data-apnav="close" aria-label="Ver toda la planta">${svg(I.close)}</button></div></div>
    <div class="ap-list">${list}</div>`;
  if (box.hidden){ box.hidden = false; if (hasGsap && !RM) gsap.fromTo(box, {x:30, opacity:0}, {x:0, opacity:1, duration:.4, ease:'power3.out', clearProps:'transform,opacity'}); }
}
const TOUR = {on:false, list:[], i:0};
function tourIds(){ return topIds().map(x => x.id).filter(id => tone(id) !== 'ok').sort((p, q) => RANKT[tone(p)] - RANKT[tone(q)]); }
function updateTourBtn(){ const n = tourIds().length; $('#tourLbl').textContent = n ? `Recorrer avisos (${n})` : 'Sin avisos'; $('#btnTour').disabled = !n; }
function tourShow(){
  const id = TOUR.list[TOUR.i]; const a = S.activos[id]; if (!a){ tourEnd(); return; }
  if (three){ const e = three.assets[id]; if (e && e.area != null && three.focus !== e.area){ three.focus = e.area; applyDim(); renderNav3D(); renderAreaPanel(); } }
  focusAsset(id);
  const iss = issues(id); const st = EST[a.estado];
  $('#tourCard').innerHTML = `<small>Aviso ${TOUR.i + 1} de ${TOUR.list.length}</small><h3>${esc(a.nombre)}</h3><span style="font-size:12px;color:var(--muted)">${esc(placeLabel(id))}</span>
    <ul>${st.t !== 'ok' ? `<li>El activo está ${esc(st.l.toLowerCase())}</li>` : ''}${iss.slice(0, 3).map(x => `<li>${esc(x.n)}${x.of ? ' (' + esc(x.of) + ')' : ''}: ${esc(EST[x.e].l.toLowerCase())}</li>`).join('')}${iss.length > 3 ? `<li>y ${iss.length - 3} más</li>` : ''}</ul>
    <div class="row-btns"><button type="button" class="btn btn--sm" data-tour="end">Terminar</button><button type="button" class="btn btn--sm" data-tour="prev"${TOUR.i ? '' : ' disabled'}>Anterior</button><button type="button" class="btn btn--sm" data-tour="open">Explorar</button><button type="button" class="btn btn--primary btn--sm" data-tour="next">${TOUR.i < TOUR.list.length - 1 ? 'Siguiente' : 'Terminar'}</button></div>`;
  const c = $('#tourCard'); if (c.hidden){ c.hidden = false; if (hasGsap && !RM) gsap.fromTo(c, {y:20, opacity:0}, {y:0, opacity:1, duration:.35, clearProps:'opacity'}); }
}
function tourStart(){ TOUR.list = tourIds(); if (!TOUR.list.length) return; TOUR.on = true; TOUR.i = 0; tourShow(); }
function tourEnd(){ TOUR.on = false; $('#tourCard').hidden = true; }

/* ================= Eventos de vistas y 3D ================= */
document.addEventListener('click', e => {
  const vb = e.target.closest('[data-view]'); if (vb){ setView(vb.dataset.view); return; }
  const lf = e.target.closest('[data-lf]'); if (lf){ LV.f = lf.dataset.lf; $$('[data-lf]').forEach(b => b.setAttribute('aria-pressed', b === lf)); renderCurrent(); return; }
  const lvt = e.target.closest('[data-lvt]'); if (lvt){ e.stopPropagation(); const id = lvt.dataset.lvt; LV.open.has(id) ? LV.open.delete(id) : LV.open.add(id); renderLista(); return; }
  const xo = e.target.closest('[data-xpopen]'); if (xo){ openXP(xo.dataset.xpopen); return; }
  const nav = e.target.closest('[data-nav]'); if (nav){ tourEnd(); if (nav.dataset.nav === 'all') center3D(); else focusArea(+nav.dataset.nav); return; }
  const apx = e.target.closest('[data-apx]'); if (apx){ openXP(apx.dataset.apx); return; }
  const ap = e.target.closest('[data-ap]'); if (ap){ $$('.ap-row').forEach(r => r.classList.toggle('is-on', r === ap)); focusAsset(ap.dataset.ap); return; }
  const apn = e.target.closest('[data-apnav]'); if (apn){ tourEnd(); const v = apn.dataset.apnav; if (v === 'close') center3D(); else { const n = three.areaNav.length; focusArea(((three.focus == null ? 0 : three.focus) + +v + n) % n); } return; }
  const tr = e.target.closest('[data-tour]'); if (tr){ const v = tr.dataset.tour;
    if (v === 'end') tourEnd(); else if (v === 'open') openXP(TOUR.list[TOUR.i]);
    else if (v === 'next'){ if (TOUR.i < TOUR.list.length - 1){ TOUR.i++; tourShow(); } else { tourEnd(); center3D(); } }
    else if (v === 'prev' && TOUR.i > 0){ TOUR.i--; tourShow(); } return; }
  if (e.target.closest('#btnTour')){ tourStart(); return; }
  const ob = e.target.closest('#btnOnly'); if (ob && three){ three.onlyIssues = !three.onlyIssues; ob.setAttribute('aria-pressed', three.onlyIssues); applyDim(); return; }
  const c3 = e.target.closest('[data-c3]'); if (c3 && three && three.controls){
    const s = sph(); const v = c3.dataset.c3;
    if (v === 'in') tweenSph({r:s.radius * .72}, .5); else if (v === 'out') tweenSph({r:s.radius * 1.38}, .5);
    else if (v === 'left') tweenSph({theta:s.theta - Math.PI/4}); else if (v === 'right') tweenSph({theta:s.theta + Math.PI/4});
    else if (v === 'iso') tweenSph({phi:.92, theta:.32}); else if (v === 'top') tweenSph({phi:.05, theta:0}); else if (v === 'front') tweenSph({phi:1.28, theta:0});
    else if (v === 'home'){ tourEnd(); center3D(); }
    else if (v === 'spin'){ three.controls.autoRotate = !three.controls.autoRotate; c3.setAttribute('aria-pressed', three.controls.autoRotate); }
  }
});
document.addEventListener('keydown', e => {
  const t = e.target;
  if ((e.key === 'Enter' || e.key === ' ') && t.dataset && (t.dataset.xpopen || t.dataset.apx) && t.tagName !== 'BUTTON'){ e.preventDefault(); openXP(t.dataset.xpopen || t.dataset.apx); return; }
  if (view !== '3d' || document.body.classList.contains('is-360') || !three || !three.controls || abierto('#xp') || abierto('#modal') || abierto('#modalCfg')) return;
  if (/INPUT|SELECT|TEXTAREA/.test(t.tagName)) return;
  const s = sph(); let used = true;
  if (e.key === 'ArrowLeft') tweenSph({theta:s.theta - Math.PI/8}, .35);
  else if (e.key === 'ArrowRight') tweenSph({theta:s.theta + Math.PI/8}, .35);
  else if (e.key === 'ArrowUp') tweenSph({phi:s.phi - .18}, .35);
  else if (e.key === 'ArrowDown') tweenSph({phi:s.phi + .18}, .35);
  else if (e.key === '+' || e.key === '=') tweenSph({r:s.radius * .8}, .35);
  else if (e.key === '-') tweenSph({r:s.radius * 1.25}, .35);
  else if (e.key === '0' || e.key === 'Home'){ tourEnd(); center3D(); }
  else if (e.key === 'Escape' && TOUR.on) tourEnd();
  else if (e.key === 'Escape' && three.focus != null) center3D();
  else used = false;
  if (used) e.preventDefault();
});
document.addEventListener('input', e => {
  if (e.target.id === 'qList'){ LV.q = e.target.value.trim(); renderCurrent(); }
});
document.addEventListener('change', e => {
  if (e.target.id === 'goto3d'){ const v = norm(e.target.value.trim()); const id = Object.keys(S.activos).find(k => norm(S.activos[k].nombre) === v) || Object.keys(S.activos).find(k => norm(S.activos[k].nombre).includes(v));
    if (id && three){ const ent = three.assets[id]; if (ent && ent.area != null){ three.focus = ent.area; applyDim(); renderNav3D(); renderAreaPanel(); } focusAsset(id); e.target.value = ''; e.target.blur(); }
    else if (v) toast('No encontré ese activo en la vista 3D. Si es un subactivo, búscalo desde su activo principal.'); }
});

/* ================= Ubicaciones: navegar el mapa por niveles y editar el árbol ================= */
const UB = {adding:null, confirm:null};
function openUb(){ UB.adding = null; UB.confirm = null; $('#ubPlanta').value = S.planta; renderUb(); showModal('#modalCfg'); }
function renderUb(){
  const box = $('#ubTree'); if (!box) return;
  const rows = treeOrder(null, 0, []).map(({id, depth}) => {
    const l = LG(id); const n = allIn(id).length; const sib = l.padre ? LG(l.padre).hijos : S.raiz; const k = sib.indexOf(id);
    let html = `<div class="ub-row${depth ? ' is-child' : ' is-root'}" style="--d:${depth}">
      <span class="tipo-tag">${esc(tipoL(l.tipo).s)}</span>
      <label class="sr" for="ubn-${id}">Nombre de ${esc(l.nombre)}</label><input class="ub-name" id="ubn-${id}" data-ubname="${id}" value="${esc(l.nombre)}" autocomplete="off">
      <span class="ub-n">${cnt(n,'Activo')}</span>
      <span class="ub-act">
        <button type="button" class="ub-in" data-ubadd="${id}" title="Agregar un lugar dentro de ${esc(l.nombre)}">${svg(I.plus,14)}Agregar dentro</button>
        <button type="button" data-ubmove="${id}" data-dir="-1" aria-label="Subir ${esc(l.nombre)}" ${k ? '' : 'disabled'}>${svg('<path d="M12 19V5M6 11l6-6 6 6"/>',14)}</button>
        <button type="button" data-ubmove="${id}" data-dir="1" aria-label="Bajar ${esc(l.nombre)}" ${k < sib.length - 1 ? '' : 'disabled'}>${svg('<path d="M12 5v14M6 13l6 6 6-6"/>',14)}</button>
        <button type="button" data-ubdel="${id}" aria-label="Eliminar ${esc(l.nombre)}">${svg('<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',14)}</button>
      </span></div>`;
    if (UB.confirm === id){ const sub = treeOrder(l.hijos, 0, []).length;
      html += `<div class="ub-confirm" style="--d:${depth}"><span>¿Eliminar <b>${esc(l.nombre)}</b>${sub ? ` y ${cnt(sub,'Lugar')} que tiene dentro` : ''}? ${n ? `Sus ${cnt(n,'Activo')} quedarán en «Por ubicar».` : 'No tiene activos.'}</span><button type="button" class="btn btn--sm" data-ubdelok="${id}" style="background:var(--danger);border-color:var(--danger);color:#fff">Sí, eliminar</button><button type="button" class="btn btn--ghost btn--sm" data-ubdelno="1">Cancelar</button></div>`; }
    return {id, html};
  });
  if (UB.adding && UB.adding !== 'root' && LG(UB.adding)){
    const ad = UB.adding; let at = -1; rows.forEach((r, k) => { if (pathIds(r.id).includes(ad)) at = k; });
    const d = pathIds(ad).length;
    rows.splice(at + 1, 0, {id:'_add', html:`<div class="ub-addrow" style="--d:${d}"><b>NUEVO LUGAR DENTRO DE ${esc(LG(ad).nombre.toUpperCase())}</b>${addFormHTML(ad, childTipo(ad)).replace('class="addlugar"', 'class="addlugar" data-ctx="ub"')}</div>`});
  }
  const rowsHTML = rows.map(r => r.html).join('');
  box.innerHTML = rowsHTML + `<div class="ub-rootadd">${UB.adding === 'root' ? `<div class="ub-addrow" style="--d:0"><b>NUEVO LUGAR PRINCIPAL EN ${esc(S.planta.toUpperCase())}</b>${addFormHTML(null, childTipo(null)).replace('class="addlugar"', 'class="addlugar" data-ctx="ub"')}</div>` : `<button type="button" class="btn btn--outline btn--sm" data-ubadd="root">${svg(I.plus,16)}Agregar lugar principal</button>`}</div>`;
}
function removeLugar(id){
  const l = LG(id); if (!l) return;
  l.hijos.slice().forEach(removeLugar);
  S.tray.push(...l.activos);
  if (l.padre) LG(l.padre).hijos = LG(l.padre).hijos.filter(x => x !== id); else S.raiz = S.raiz.filter(x => x !== id);
  delete S.lugares[id];
}
function afterUb(){ if (abierto('#modalCfg')) renderUb(); }
document.addEventListener('click', e => {
  const t = e.target.closest('button'); if (!t) return;
  if (t.dataset.enter){ MAP.cur = t.dataset.enter; MAP.adding = null; render(); if (hasGsap && !RM) gsap.fromTo('#map .area', {opacity:0, y:12}, {opacity:1, y:0, duration:.35, stagger:.04, clearProps:'opacity,transform'}); $('#mapCrumbs').scrollIntoView({block:'nearest', behavior:RM ? 'auto' : 'smooth'}); return; }
  if (t.dataset.crumbmap != null){ MAP.cur = t.dataset.crumbmap || null; MAP.adding = null; render(); return; }
  if (t.dataset.addin){ MAP.adding = t.dataset.addin; render(); setTimeout(() => { const n = $('#map #nlNombre'); n && (n.focus(), n.select()); }, 30); return; }
  if (t.dataset.addcancel){ if (t.closest('[data-ctx="ub"]')){ UB.adding = null; renderUb(); } else { MAP.adding = null; render(); } return; }
  if (t.dataset.ubadd){ UB.adding = t.dataset.ubadd; UB.confirm = null; renderUb(); setTimeout(() => { const n = $('#ubTree #nlNombre'); n && (n.focus(), n.select()); }, 30); return; }
  if (t.dataset.ubmove){ const id = t.dataset.ubmove, d = +t.dataset.dir; const l = LG(id); const arr = l.padre ? LG(l.padre).hijos : S.raiz; const k = arr.indexOf(id), j = k + d; if (j < 0 || j >= arr.length) return;
    commit(() => { arr.splice(k, 1); arr.splice(j, 0, id); }, `Se movió ${l.nombre}`); afterUb(); setTimeout(() => { const b = document.querySelector(`[data-ubmove="${id}"][data-dir="${d}"]`); b && !b.disabled && b.focus(); }, 30); return; }
  if (t.dataset.ubdel){ UB.confirm = t.dataset.ubdel; UB.adding = null; renderUb(); return; }
  if (t.dataset.ubdelno){ UB.confirm = null; renderUb(); return; }
  if (t.dataset.ubdelok){ const id = t.dataset.ubdelok; const name = LG(id).nombre; UB.confirm = null; if (MAP.cur && pathIds(MAP.cur).includes(id)) MAP.cur = LG(id).padre || null;
    commit(() => removeLugar(id), `Se eliminó ${name}`); afterUb(); return; }
});
document.addEventListener('change', e => {
  const t = e.target;
  if (t.id === 'nlTipo'){ const f = t.closest('[data-form]'); const nu = f.querySelector('#nlTipoNuevo'); nu.hidden = t.value !== '__nuevo';
    if (t.value === '__nuevo'){ nu.focus(); return; }
    const parent = f.dataset.addform === 'root' ? (f.dataset.ctx === 'ub' ? null : MAP.cur) : f.dataset.addform; const nm = f.querySelector('#nlNombre'); if (nm.dataset.auto === nm.value){ nm.value = nextName(parent, t.value); nm.dataset.auto = nm.value; } }
  if (t.dataset && t.dataset.ubname){ const l = LG(t.dataset.ubname); const v = t.value.trim(); if (!v || v === l.nombre){ t.value = l.nombre; return; } commit(() => { l.nombre = v; }, `Ahora se llama ${v}`); afterUb(); }
  if (t.id === 'ubPlanta'){ t.value = S.planta; toast('El nombre de la planta se cambia en Organización › Plantas.'); }
});
document.addEventListener('submit', e => {
  const f = e.target; if (!f.classList || !f.classList.contains('addlugar')) return;
  e.preventDefault();
  const inUb = f.dataset.ctx === 'ub';
  const parent = f.dataset.addform === 'root' ? (inUb ? null : MAP.cur) : f.dataset.addform;
  const nombre = f.querySelector('#nlNombre').value.trim(); if (!nombre){ f.querySelector('#nlNombre').focus(); return; }
  let tipo = f.querySelector('#nlTipo').value;
  const nuevo = f.querySelector('#nlTipoNuevo').value.trim();
  if (tipo === '__nuevo' && !nuevo){ f.querySelector('#nlTipoNuevo').focus(); return; }
  commit(() => {
    if (tipo === '__nuevo'){ const s = nuevo.charAt(0).toUpperCase() + nuevo.slice(1); const ex = S.tipos.find(x => norm(x.s) === norm(s)); if (ex) tipo = ex.id; else { do { tipo = 'tl' + (++S.seq); } while (S.tipos.some(x => x.id === tipo)); S.tipos.push({id:tipo, s, p:pl(s)}); } }
    let id; do { id = 'ul' + (++S.seq); } while (S.lugares[id]);
    S.lugares[id] = {nombre, tipo, padre:parent || undefined, hijos:[], activos:[]};
    if (!parent) delete S.lugares[id].padre;
    if (parent) LG(parent).hijos.push(id); else S.raiz.push(id);
    if (inUb) UB.adding = null; else MAP.adding = null;
  }, `Se agregó ${nombre} en ${parent ? LG(parent).nombre : S.planta}. Arrastra activos hacia ahí.`);
  afterUb();
});

/* ================= Navegador de ubicaciones =================
   Un solo botón con la ruta actual + panel con buscador (lugares y activos), filtros y teclado.
   Escala a cientos de lugares sin barras con scroll horizontal. */
const NAV = {ctx:'3d', q:'', f:'all', active:0, items:[], anchor:null};
const PIN = '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>';
function badIn(ids){ return ids.filter(id => tone(id) !== 'ok').length; }
function renderLocNav(){
  const box = $('#locnav3d'); if (!box || !three) return;
  const f = three.focus; const a = f != null ? three.areaNav[f] : null;
  const scope = a ? a.ids : Object.keys(S.activos).filter(id => !S.activos[id].padre);
  const bad = badIn(scope);
  box.innerHTML = `<button type="button" class="ln-step" data-lnstep="-1" aria-label="Lugar anterior" title="Lugar anterior">${svg('<path d="M15 6l-6 6 6 6"/>')}</button>
    <button type="button" class="ln-trigger" data-navopen="3d" aria-haspopup="dialog" title="Ir a un lugar o activo (/)"><span class="ln-pin">${svg(PIN,16)}</span>
      <span class="ln-path"><span class="${a ? 'ln-root' : ''}">${esc(S.planta)}</span>${a ? `<i>›</i><span>${esc(a.name)}</span>` : ''}</span>
      ${bad ? `<span class="ln-badge" title="${bad} con avisos">${bad}</span>` : ''}<kbd>/</kbd>${svg('<path d="M6 9l6 6 6-6"/>',16)}</button>
    <button type="button" class="ln-step" data-lnstep="1" aria-label="Lugar siguiente" title="Lugar siguiente">${svg('<path d="M9 6l6 6-6 6"/>')}</button>`;
}
function hl(text, q){
  if (!q) return esc(text);
  const n = norm(text), i = n.indexOf(q); if (i < 0) return esc(text);
  return esc(text.slice(0, i)) + '<mark>' + esc(text.slice(i, i + q.length)) + '</mark>' + esc(text.slice(i + q.length));
}
function buildNav(){
  const q = norm(NAV.q.trim()); const items = []; let html = '';
  const cur = NAV.ctx === '3d' ? (three && three.focus != null && three.areaNav[three.focus] ? three.areaNav[three.focus].lid : null) : MAP.cur;
  const meta = (n, bad) => `<span class="np-meta">${bad ? `<span class="ln-badge">${bad}</span>` : ''}${cnt(n,'Activo')}</span>`;
  if (!q && NAV.f === 'all'){ items.push({type:'all'}); }
  const lug = treeOrder(null, 0, []).map(({id, depth}) => { const ids = allIn(id); return {id, depth, l:LG(id), n:ids.length, bad:badIn(ids)}; })
    .filter(x => (NAV.f !== 'issues' || x.bad) && (NAV.f !== 'empty' || !x.n) && (!q || norm(x.l.nombre).includes(q) || norm(pathLabel(x.id)).includes(q) || norm(tipoL(x.l.tipo).s).includes(q)));
  lug.forEach(x => items.push({type:'lugar', ...x}));
  const showTray = S.tray.length && NAV.f !== 'empty' && (!q || 'por ubicar'.includes(q)) && (NAV.f !== 'issues' || badIn(S.tray));
  if (showTray) items.push({type:'tray'});
  let acts = [];
  if (q){
    acts = Object.keys(S.activos).filter(id => { const a = S.activos[id]; return norm(a.nombre).includes(q) || norm(a.codigo).includes(q); })
      .filter(id => NAV.f !== 'issues' || tone(id) !== 'ok').slice(0, 10);
    acts.forEach(id => items.push({type:'activo', id}));
  }
  NAV.items = items; if (NAV.active >= items.length) NAV.active = Math.max(0, items.length - 1);
  let k = 0; const act = i => i === NAV.active ? ' is-active' : '';
  if (!items.length){ $('#npList').innerHTML = `<div class="np-empty">No encontramos «${esc(NAV.q)}».<br>Prueba con el nombre de un área, una línea o un activo.</div>`; return; }
  if (items[0] && items[0].type === 'all'){ const tops = Object.keys(S.activos).filter(id => !S.activos[id].padre);
    html += `<button type="button" class="np-item is-root${act(k)}${cur == null ? ' is-current' : ''}" role="option" data-npi="${k++}"><span class="np-ico">${svg('<path d="M3 11l9-7 9 7M5 10v10h14V10"/>',16)}</span><span class="np-main"><strong>Toda la planta</strong><small>${esc(S.planta)} · ${cnt(S.raiz.length,'Lugar')} principales</small></span>${meta(tops.length, badIn(tops))}</button>`; }
  if (lug.length){ html += `<div class="np-sec">${q ? 'Lugares' : 'Ubicaciones'} · ${lug.length}</div>`;
    lug.forEach(x => { const t = tipoL(x.l.tipo).s;
      html += `<button type="button" class="np-item${x.depth ? '' : ' is-root'}${act(k)}${cur === x.id ? ' is-current' : ''}" role="option" data-npi="${k++}" style="--d:${q ? 0 : x.depth}"><span class="np-ico">${svg(PIN,15)}</span><span class="np-main"><strong>${hl(x.l.nombre, q)}</strong><small>${q && x.l.padre ? esc(pathLabel(x.l.padre)) + ' · ' : ''}${esc(t)}${x.l.hijos.length ? ' · ' + esc(childrenSummary(x.id)) : ''}</small></span>${meta(x.n, x.bad)}</button>`; }); }
  if (showTray){ html += `<button type="button" class="np-item${act(k)}" role="option" data-npi="${k++}"><span class="np-ico" style="background:var(--warning-soft);color:var(--warning-ink)">${svg(I.alert,15)}</span><span class="np-main"><strong>Por ubicar</strong><small>Activos sin ubicación</small></span>${meta(S.tray.length, badIn(S.tray))}</button>`; }
  if (acts.length){ html += `<div class="np-sec">Activos · ${acts.length}</div>`;
    acts.forEach(id => { const a = S.activos[id]; const t = tone(id);
      html += `<button type="button" class="np-item${act(k)}" role="option" data-npi="${k++}"><span class="np-ico">${icoHTML(id, 16)}</span><span class="np-main"><strong>${hl(a.nombre, q)}</strong><small>${esc(a.codigo)} · ${esc(placeLabel(id))}</small></span><span class="chip chip--${t}" style="height:22px;font-size:11px"><i></i>${esc(toneText(id))}</span></button>`; }); }
  $('#npList').innerHTML = html;
  const el = document.querySelector('.np-item.is-active'); el && el.scrollIntoView({block:'nearest'});
}
function placeNav(){
  const pop = $('#navpop'), a = NAV.anchor; if (!a) return;
  if (innerWidth <= 640){ pop.style.left = pop.style.top = pop.style.bottom = pop.style.maxHeight = ''; return; }
  const r = a.getBoundingClientRect(); const w = Math.min(420, innerWidth - 24);
  let left = r.left + w > innerWidth - 12 ? r.right - w : r.left; left = Math.min(Math.max(12, left), innerWidth - w - 12);
  const below = innerHeight - r.bottom - 20, above = r.top - 20;
  if (below < 340 && above > below){ const h = Math.min(600, above); pop.style.top = 'auto'; pop.style.bottom = (innerHeight - r.top + 8) + 'px'; pop.style.maxHeight = h + 'px'; }
  else { pop.style.bottom = ''; pop.style.top = (r.bottom + 8) + 'px'; pop.style.maxHeight = Math.min(600, below) + 'px'; }
  pop.style.left = left + 'px';
}
function openNav(ctx, anchor){
  NAV.ctx = ctx; NAV.anchor = anchor; NAV.q = ''; NAV.f = Object.keys(S.activos).some(id => tone(id) !== 'ok') ? 'issues' : 'all'; NAV.active = 0;
  const pop = $('#navpop'); $('#npQ').value = ''; $$('[data-npf]').forEach(b => b.setAttribute('aria-pressed', b.dataset.npf === NAV.f));
  pop.hidden = false; placeNav(); buildNav();
  const cur = document.querySelector('.np-item.is-current'); if (cur){ NAV.active = +cur.dataset.npi; buildNav(); }
  if (hasGsap && !RM) gsap.fromTo(pop, {opacity:0, y:-6, scale:.98}, {opacity:1, y:0, scale:1, duration:.18, ease:'power2.out', clearProps:'transform,opacity'});
  setTimeout(() => $('#npQ').focus(), 20);
}
function closeNav(back){ const pop = $('#navpop'); if (!pop || pop.hidden) return; pop.hidden = true; if (back && NAV.anchor && document.body.contains(NAV.anchor)) NAV.anchor.focus(); }
function flyToRow(lid){
  let id = lid; while (id && !three.rowNav[id]) id = LG(id) && LG(id).padre;
  const rn = id && three.rowNav[id]; if (!rn) return false;
  three.focus = rn.area; applyDim(); renderLocNav(); renderAreaPanel();
  const aspect = Math.max(1, three.camera.aspect), tv = Math.tan(THREE.MathUtils.degToRad(15));
  flyTo(rn.center.clone(), Math.max(10, (rn.w/2 + 1) / (tv * aspect)), {phi:.9});
  return true;
}
function chooseNav(i){
  const it = NAV.items[i]; if (!it) return; closeNav(false);
  if (NAV.ctx === '3d'){
    if (!three) return; tourEnd && tourEnd();
    if (it.type === 'all') center3D();
    else if (it.type === 'tray'){ const k = three.areaNav.findIndex(a => a.tray); k >= 0 && focusArea(k); }
    else if (it.type === 'lugar'){ const root = rootOf(it.id); const k = three.areaNav.findIndex(a => a.lid === root); if (it.id === root){ k >= 0 && focusArea(k); } else if (!flyToRow(it.id) && k >= 0) focusArea(k); }
    else if (it.type === 'activo'){ let id = it.id; if (!three.assets[id] && S.activos[id].padre) id = S.activos[id].padre; const e = three.assets[id];
      if (e){ if (e.area != null && three.focus !== e.area){ three.focus = e.area; applyDim(); renderLocNav(); renderAreaPanel(); } focusAsset(id); } else openXP(it.id); }
    return;
  }
  // Mapa 2D
  if (it.type === 'all'){ MAP.cur = null; render(); return; }
  if (it.type === 'tray'){ const t = $('.tray'); t.scrollIntoView({block:'center', behavior:RM ? 'auto' : 'smooth'}); t.classList.add('is-flash'); setTimeout(() => t.classList.remove('is-flash'), 1500); return; }
  if (it.type === 'lugar'){
    const l = LG(it.id); MAP.cur = l.hijos.length ? it.id : (l.padre || null); MAP.adding = null; render();
    const sec = document.querySelector(`[data-sec="${it.id}"]`) || document.querySelector(`.lane[data-lugar="${it.id}"]`) || $('#map');
    sec.scrollIntoView({block:'center', behavior:RM ? 'auto' : 'smooth'}); const fl = sec.closest('.area') || sec; fl.classList.add('is-flash'); setTimeout(() => fl.classList.remove('is-flash'), 1500); return;
  }
  if (it.type === 'activo'){
    let id = it.id; if (S.activos[id].padre) id = S.activos[id].padre;
    const L = whereIs(id); if (!L){ MAP.adding = null; render(); const t = document.querySelector(`.tile[data-id="${id}"]`) || $('.tray'); t && t.scrollIntoView({block:'center', behavior:RM ? 'auto' : 'smooth'}); setTimeout(() => openXP(it.id), RM ? 0 : 400); return; }
    const p = LG(L).padre; MAP.cur = p ? (LG(p).padre || null) : null; MAP.adding = null; render();
    const t = document.querySelector(`.tile[data-id="${id}"]`);
    if (t){ t.scrollIntoView({block:'center', behavior:RM ? 'auto' : 'smooth'}); if (hasGsap && !RM) gsap.fromTo(t, {boxShadow:'0 0 0 0 rgba(103,50,244,.7)'}, {boxShadow:'0 0 0 12px rgba(103,50,244,0)', duration:1, repeat:1}); }
    setTimeout(() => openXP(it.id), RM ? 0 : 500);
  }
}
document.addEventListener('click', e => {
  const o = e.target.closest('[data-navopen]'); if (o){ const pop = $('#navpop'); if (!pop.hidden && NAV.anchor === o) closeNav(false); else openNav(o.dataset.navopen, o); return; }
  const st = e.target.closest('[data-lnstep]'); if (st && three){ const n = three.areaNav.length; if (!n) return; tourEnd(); const f = three.focus == null ? (+st.dataset.lnstep > 0 ? -1 : 0) : three.focus; focusArea(((f + +st.dataset.lnstep) % n + n) % n); renderLocNav(); return; }
  const it = e.target.closest('[data-npi]'); if (it){ chooseNav(+it.dataset.npi); return; }
  const nf = e.target.closest('[data-npf]'); if (nf){ NAV.f = nf.dataset.npf; NAV.active = 0; $$('[data-npf]').forEach(b => b.setAttribute('aria-pressed', b === nf)); buildNav(); $('#npQ').focus(); return; }
  if (!e.target.closest('#navpop')) closeNav(false);
});
document.addEventListener('input', e => { if (e.target.id === 'npQ'){ NAV.q = e.target.value; NAV.active = 0; buildNav(); } });
document.addEventListener('keydown', e => {
  const pop = $('#navpop');
  if (!pop.hidden){
    if (e.key === 'Escape'){ e.preventDefault(); e.stopImmediatePropagation(); closeNav(true); return; }
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp'){ e.preventDefault(); e.stopImmediatePropagation(); NAV.active = Math.max(0, Math.min(NAV.items.length - 1, NAV.active + (e.key === 'ArrowDown' ? 1 : -1))); buildNav(); return; }
    if (e.key === 'Enter' && e.target.id === 'npQ'){ e.preventDefault(); chooseNav(NAV.active); return; }
    return;
  }
  const t = e.target;
  if (e.key === '/' && !/INPUT|SELECT|TEXTAREA/.test(t.tagName) && !t.isContentEditable && $('#xp').hidden && $('#modal').hidden && $('#modalCfg').hidden && !document.body.classList.contains('is-360') && (view === '3d' || view === '2d')){
    e.preventDefault(); const anchor = view === '3d' ? document.querySelector('#locnav3d .ln-trigger') : document.querySelector('[data-navopen="2d"]'); anchor && openNav(view, anchor);
  }
}, true);
addEventListener('resize', () => { if (abierto('#navpop')) placeNav(); });
addEventListener('scroll', () => { if (abierto('#navpop')) placeNav(); }, true);

/* ================= Fotos del activo: varias fotos y una portada (estrella) =================
   a.foto  = la portada (la que se ve en tarjetas, mapa, 3D y explorador)
   a.fotos = todas las fotos reales del activo. Cambiar la portada es tocar la estrella. */
const STAR = on => svg(on ? '<path d="M12 3.2l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17.2 6.6 20.1l1-6.1L3.2 9.7l6.1-.9z" fill="currentColor"/>' : '<path d="M12 3.2l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17.2 6.6 20.1l1-6.1L3.2 9.7l6.1-.9z"/>', 16);
function fotosOf(id){ const a = S.activos[id]; if (!a) return []; const l = (a.fotos || []).slice(); if (a.foto && !l.includes(a.foto)) l.unshift(a.foto); return l; }
function addFotos(id, urls, makeCover){ const a = S.activos[id]; a.fotos = fotosOf(id); urls.forEach(u => { if (!a.fotos.includes(u)) a.fotos.push(u); }); if (makeCover || !a.foto) a.foto = urls[0]; }
function setPortada(id, url){ const a = S.activos[id]; a.fotos = fotosOf(id); if (!a.fotos.includes(url)) a.fotos.push(url); a.foto = url; }
function removeFoto(id, url){ const a = S.activos[id]; a.fotos = fotosOf(id).filter(u => u !== url); if (a.foto === url){ if (a.fotos[0]) a.foto = a.fotos[0]; else delete a.foto; } }

/* Fuente de fotos: un activo ('a:ID') o la ficha que se está llenando ('wz') */
function fsList(key){ return key === 'wz' ? WZ.d.fotos : fotosOf(key.slice(2)); }
function fsCover(key){ return key === 'wz' ? (WZ.d.portada || WZ.d.fotos[0]) : S.activos[key.slice(2)].foto; }
function fsName(key){ return key === 'wz' ? (WZ.d.nombre || 'Nuevo activo') : S.activos[key.slice(2)].nombre; }
function fsSetCover(key, url){
  if (key === 'wz'){ WZ.d.portada = url; WZ.dirty = true; renderWZ(); return; }
  const id = key.slice(2); const n = fotosOf(id).indexOf(url) + 1;
  commit(() => setPortada(id, url), `Nueva portada de ${S.activos[id].nombre}: la foto ${n}`); afterFotos();
}
function fsAdd(key, urls){
  if (key === 'wz'){ urls.forEach(u => WZ.d.fotos.push(u)); if (!WZ.d.portada) WZ.d.portada = WZ.d.fotos[0]; WZ.dirty = true; renderWZ(); return; }
  const id = key.slice(2); const had = !!S.activos[id].foto;
  commit(() => addFotos(id, urls), urls.length === 1 ? (had ? 'Se agregó 1 foto. Toca su estrella para dejarla de portada.' : 'Foto lista: quedó como portada') : `Se agregaron ${urls.length} fotos. Toca una estrella para elegir la portada.`); afterFotos();
}
function fsDel(key, url){
  if (key === 'wz'){ WZ.d.fotos = WZ.d.fotos.filter(u => u !== url); if (WZ.d.portada === url) WZ.d.portada = WZ.d.fotos[0] || null; WZ.dirty = true; renderWZ(); return; }
  const id = key.slice(2); commit(() => removeFoto(id, url), 'Se quitó la foto'); afterFotos();
}
function afterFotos(){ if (abierto('#gal')) renderGal(); if (window.sigmaFotos360) window.sigmaFotos360(); }

function fotoStripHTML(key, opts = {}){
  const list = fsList(key), cover = fsCover(key);
  const items = list.map((u, i) => { const on = u === cover;
    return `<figure class="fs-item${on ? ' is-cover' : ''}">
      <button type="button" class="fs-img" data-gal="${key}" data-i="${i}" aria-label="Ver la foto ${i + 1} en grande"><img src="${u}" alt=""></button>
      <button type="button" class="fs-star" data-fstar="${key}" data-i="${i}" aria-pressed="${on}" aria-label="${on ? 'Es la foto de portada' : 'Usar la foto ' + (i + 1) + ' como portada'}" title="${on ? 'Es la portada' : 'Usar como portada'}">${STAR(on)}</button>
      ${opts.del ? `<button type="button" class="fs-del" data-fdel="${key}" data-i="${i}" aria-label="Quitar la foto ${i + 1}" title="Quitar">${svg(I.close,14)}</button>` : ''}
      ${on ? '<span class="fs-tag">Portada</span>' : ''}</figure>`; }).join('');
  const add = `<label class="fs-add" data-fsdrop="${key}">${svg(I.camera,20)}${list.length ? 'Agregar' : 'Subir fotos'}<input type="file" accept="image/*" multiple class="sr" data-fsadd="${key}"></label>`;
  return `<div class="fs${opts.lg ? ' fs--lg' : ''}">${items}${add}</div>
    ${list.length > 1 ? `<p class="fs-help">${STAR(true)}La foto con estrella es la portada. Toca otra estrella para cambiarla.</p>` : list.length === 1 ? `<p class="fs-help">${STAR(true)}Esta foto es la portada. Si subes más, eliges cuál con la estrella.</p>` : ''}`;
}

/* ---------- Visor ---------- */
const GAL = {key:null, i:0, back:null};
function openGal(key, i){ if (!fsList(key).length) return; GAL.key = key; GAL.i = i || 0; GAL.back = document.activeElement; $('#gal').hidden = false; renderGal(); if (hasGsap && !RM) gsap.fromTo('#gal', {opacity:0}, {opacity:1, duration:.2}); setTimeout(() => { const b = $('#galCover'); b && b.focus(); }, 30); }
function closeGal(){ $('#gal').hidden = true; if (GAL.back && document.body.contains(GAL.back)) GAL.back.focus({preventScroll:true}); }
function renderGal(){
  const list = fsList(GAL.key); if (!list.length){ closeGal(); return; }
  GAL.i = Math.max(0, Math.min(list.length - 1, GAL.i));
  const u = list[GAL.i], cover = fsCover(GAL.key), on = u === cover;
  $('#gal').innerHTML = `
    <div class="gal-top">
      <div class="t"><b>${esc(fsName(GAL.key))}</b><small>Foto ${GAL.i + 1} de ${list.length}${on ? ' · es la portada' : ''}</small></div>
      <button type="button" class="gal-btn${on ? ' is-cover' : ''}" id="galCover" data-galcover="1" aria-pressed="${on}">${STAR(on)}<span class="l">${on ? 'Es la portada' : 'Usar como portada'}</span></button>
      <button type="button" class="gal-btn gal-del" data-galdel="1">${svg('<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',16)}<span class="l">Quitar</span></button>
      <button type="button" class="gal-btn gal-btn--icon" data-galclose="1" aria-label="Cerrar">${svg(I.close)}</button>
    </div>
    <div class="gal-stage" data-galbg="1">
      ${list.length > 1 ? `<button type="button" class="gal-nav p" data-galstep="-1" aria-label="Foto anterior">${svg('<path d="M15 6l-6 6 6 6"/>',22)}</button>` : ''}
      <img src="${u}" alt="Foto ${GAL.i + 1} de ${esc(fsName(GAL.key))}">
      ${list.length > 1 ? `<button type="button" class="gal-nav n" data-galstep="1" aria-label="Foto siguiente">${svg('<path d="M9 6l6 6-6 6"/>',22)}</button>` : ''}
    </div>
    <div class="gal-thumbs">${list.map((x, i) => `<button type="button" class="gal-th${i === GAL.i ? ' is-cur' : ''}" data-galgo="${i}" aria-label="Ver foto ${i + 1}${x === cover ? ' (portada)' : ''}"><img src="${x}" alt="">${x === cover ? `<span class="st">${svg('<path d="M12 3.2l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17.2 6.6 20.1l1-6.1L3.2 9.7l6.1-.9z" fill="#fff" stroke="none"/>',11)}</span>` : ''}</button>`).join('')}</div>`;
}
document.addEventListener('click', e => {
  const t = e.target.closest('button,[data-gal],[data-galbg]'); if (!t) return;
  if (t.dataset.fstar){ e.preventDefault(); const url = fsList(t.dataset.fstar)[+t.dataset.i]; if (url && url !== fsCover(t.dataset.fstar)) fsSetCover(t.dataset.fstar, url); return; }
  if (t.dataset.fdel){ const url = fsList(t.dataset.fdel)[+t.dataset.i]; url && fsDel(t.dataset.fdel, url); return; }
  if (t.dataset.gal){ openGal(t.dataset.gal, +t.dataset.i || 0); return; }
  if ($('#gal').hidden) return;
  if (t.dataset.galclose || (t.dataset.galbg && e.target === t)){ closeGal(); return; }
  if (t.dataset.galstep){ GAL.i = (GAL.i + +t.dataset.galstep + fsList(GAL.key).length) % fsList(GAL.key).length; renderGal(); return; }
  if (t.dataset.galgo){ GAL.i = +t.dataset.galgo; renderGal(); return; }
  if (t.dataset.galcover){ const u = fsList(GAL.key)[GAL.i]; if (u !== fsCover(GAL.key)) fsSetCover(GAL.key, u); renderGal(); $('#galCover').focus(); return; }
  if (t.dataset.galdel){ const u = fsList(GAL.key)[GAL.i]; fsDel(GAL.key, u); return; }
});
document.addEventListener('keydown', e => {
  if ($('#gal').hidden) return;
  if (e.key === 'Escape'){ e.preventDefault(); e.stopImmediatePropagation(); closeGal(); }
  else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight'){ e.preventDefault(); e.stopImmediatePropagation(); const n = fsList(GAL.key).length; GAL.i = (GAL.i + (e.key === 'ArrowRight' ? 1 : -1) + n) % n; renderGal(); }
}, true);
async function readFotos(files){ const out = []; for (const f of [...files].filter(f => /^image\//.test(f.type))){ try { out.push(await loadPhoto(f)); } catch(err){} } return out; }
document.addEventListener('change', async e => {
  const t = e.target; if (!t.dataset || !t.dataset.fsadd || !t.files.length) return;
  const urls = await readFotos(t.files); t.value = '';
  if (!urls.length){ toast('No se pudo leer esa imagen. Prueba con una foto JPG o PNG.'); return; }
  fsAdd(t.dataset.fsadd, urls);
});
['dragover','dragleave','drop'].forEach(ev => document.addEventListener(ev, async e => {
  const z = e.target.closest && e.target.closest('[data-fsdrop]'); if (!z) return;
  e.preventDefault(); z.classList.toggle('is-over', ev === 'dragover');
  if (ev === 'drop' && e.dataTransfer.files.length){ const urls = await readFotos(e.dataTransfer.files); if (urls.length) fsAdd(z.dataset.fsdrop, urls); }
}));


/* Los <div data-form> envian con su boton marcado o con Enter, sin tocar el form de la pagina. */
document.addEventListener('click', e => { const b = e.target.closest && e.target.closest('[data-submit]'); if (!b) return; const f = b.closest('[data-form]'); if (f) f.dispatchEvent(new Event('submit', {bubbles:true, cancelable:true})); });
document.addEventListener('keydown', e => { if (e.key !== 'Enter' || !e.target.closest) return; const f = e.target.closest('[data-form]'); if (!f || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'BUTTON') return; e.preventDefault(); f.dispatchEvent(new Event('submit', {bubbles:true, cancelable:true})); });

/* ================= Inicio =================
   Se dibuja con la planta del servidor. three.js se pide recien al entrar a
   la Vista 3D (import dinamico). Un activo sin foto muestra el espacio para
   cargarla, no una imagen generada. */
async function iniciar(){
  const caja = document.getElementById('saPlanta'); if (!caja || caja.dataset.listo) return;
  caja.dataset.listo = '1';
  /* Las ventanas (explorador, visor, ubicaciones, navegador, avisos) van al
     final del <body>: dentro del contenido de la maestra, un contenedor con
     transform hace que position:fixed se mida contra el y no contra la
     pantalla, y el explorador quedaba corrido a la izquierda. */
  let portal = document.getElementById('saPortal');
  if (portal) portal.remove();
  portal = document.createElement('div'); portal.id = 'saPortal'; portal.className = 'sgap sgap-portal';
  document.body.appendChild(portal);
  ['#gal', '#xp', '#modalCfg', '#lightbox', '#navpop', '#toast'].forEach(sel => { const el = caja.querySelector(sel); if (el) portal.appendChild(el); });
  if (three){ three.running = false; three = null; }
  let planta = 0; try { planta = +localStorage.getItem(KEY + '-planta') || 0; } catch(e){}
  try { await cargarPlanta(planta); }
  catch(err){ const w = $('#saCargando'); if (w){ w.hidden = false; w.className = 'sa-cargando-error'; w.textContent = 'No se pudo cargar la planta: ' + err.message; } return; }
  const w = $('#saCargando'); if (w) w.hidden = true;
  caja.classList.remove('is-cargando');
  /* crear o editar areas y lineas es un permiso aparte (CREAR EDITAR AREAS) */
  caja.classList.toggle('sin-lugares', !(S.permisos && S.permisos.lugares));
  SIGMA.pintarPlantas();
  try { if (!localStorage.getItem(KEY + '-hint')) $('#hint').hidden = false; } catch(e){ $('#hint').hidden = false; }
  render();
  /* Al entrar siempre se ve la pestaña Activos en Tarjetas. Solo si se
     vuelve de cerrar una ficha abierta desde otra pestaña, se vuelve a ella. */
  setView('tarjetas', true);
  let volver = null; try { volver = sessionStorage.getItem(KEY + '-volver'); sessionStorage.removeItem(KEY + '-volver'); } catch(e){}
  if (volver && volver !== 'activos' && document.querySelector(`[data-mpanel="${volver}"]`)) SIGMA.pestana(volver);
  if (hasGsap && !RM){ gsap.from('.sgap .kpi', {y:14, opacity:0, duration:.5, stagger:.06, ease:'power2.out', clearProps:'opacity,transform'}); gsap.from('.sgap .area, .sgap .tray', {y:18, opacity:0, duration:.6, stagger:.07, delay:.1, ease:'power3.out', clearProps:'opacity,transform'}); }
  /* sin permiso de edicion no se ofrece crear ni mover */
  if (!(S.permisos && S.permisos.editar)) $$('#btnNuevo, #btnNuevo2').forEach(b => { b.hidden = true; });
  if (!(S.permisos && S.permisos.lugares)) $$('#btnEstructura').forEach(b => { b.hidden = true; });
}
iniciar();
/* El centro y la lista comparten pagina: al volver a la lista por un postback parcial, se dibuja de nuevo. */
window.addEventListener('load', () => { if (window.Sys && Sys.WebForms) Sys.WebForms.PageRequestManager.getInstance().add_endRequest(() => { view = 'tarjetas'; iniciar(); }); });

})();
