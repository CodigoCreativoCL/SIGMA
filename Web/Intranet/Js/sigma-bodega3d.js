/* ============================================================================
   SIGMA · Mapa 3D de bodegas — consulta y administracion en un solo lugar
   ----------------------------------------------------------------------------
   La bodega se construye SOLO con lo que hay en la base (WsBodegaMapa):

     bodegas de la planta  -> edificios, uno al lado del otro
     ubicaciones           -> racks. El codigo P1-A-R01 se lee como pasillo A,
                              rack 01: los racks de un pasillo se reparten a
                              los dos lados, impares a la izquierda y pares a
                              la derecha, como se numera una bodega real.
     stock por ubicacion   -> cajas en los niveles del rack, del color de la
                              familia de su tipo de repuesto.

   LAS ETIQUETAS SON LAS DEL CENTRO DE ETIQUETAS
     Mismo diseno que Comun/Impresion/Etiquetas.aspx y el MISMO QR (token
     BOD-, UBI-, REP-, correccion Q): lo que se ve pegado en el fierro del
     mapa es lo que se imprime y se pega en el fierro de verdad.

   Y se administra desde aqui mismo, sin modales ni postback: bodegas, racks,
   repuestos (con fotos y umbrales) y movimientos. Todo pasa por los mismos
   controllers que las pantallas de siempre: el mapa no tiene reglas propias.

   RECORRIDO DE PASILLO
     En primera persona, con la tablet en la mano: el bodeguero camina el
     pasillo, mira cada rack de arriba abajo y la tablet va listando lo que
     hay en cada caja, marcando lo que esta bajo minimo. Se puede pausar,
     saltar a otro rack o revisar uno en detalle: es para no tener que ir.

   Rendimiento:
     - Las piezas de los racks son InstancedMesh: todos los racks de la planta
       se dibujan en cinco llamadas.
     - Las etiquetas tienen niveles de detalle: de lejos una compartida (por
       tipo en las cajas, en baja resolucion en las vigas); de cerca la real,
       con su QR legible, que se crea al acercarse y se libera al alejarse.
   ============================================================================ */

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// ============================================================ configuracion
const root = document.getElementById('bm3d');
const WS = root.dataset.ws;

/* Medidas de un rack selectivo real, en metros. */
const RACK = {
    ancho: 2.7, prof: 1.1, alto: 3.2,
    niveles: [0.14, 0.94, 1.74, 2.54],   // cara superior de cada viga
    viga: 0.11
};
const PASILLO = 3.2, ENTRE_RACKS = 0.1, ESPALDA = 0.35, MARGEN = 3.4;
const ZONA_RECEPCION = 6.5, ENTRE_BODEGAS = 9;
const DIST_DETALLE = 6.5, TOPE_ETIQUETAS = 110;
const DIST_VIGA_HD = 7.5, TOPE_VIGAS_HD = 4;
const BLOQUE = PASILLO + 2 * RACK.prof;
const RATIO_ETQ = 70 / 37;                // etiqueta A4-24 del Centro de etiquetas
const FOV_MAPA = 40, FOV_RECORRIDO = 60, OJOS = 1.63;

/* Colores de familia: paleta SIGMA. El rojo no es categoria: es de alertas. */
const FAMILIAS = {
    MEC: { nombre: 'Mecánica', color: '#087BEA' },
    ELE: { nombre: 'Eléctrica', color: '#6732F4' },
    REF: { nombre: 'Refrigeración', color: '#16C6C9' },
    LUB: { nombre: 'Lubricación', color: '#B65C00' }
};
const COLORES_EXTRA = ['#16855B', '#4A556D', '#0565C2', '#007F8A'];
const SIN_TIPO = { nombre: 'Sin tipo', color: '#8792A8' };
const PESADO = /MOTOR|COMPRESOR|BOMBA|REDUCTOR|VARIADOR/i;
const ESTADO_TXT = { bajo: 'Bajo mínimo', sobre: 'Sobre máximo', ok: 'Dentro de umbral', sin: 'Sin umbral definido' };
const COLOR_ESTADO = { bajo: '#C7352B', sobre: '#B65C00', ok: '#16855B', sin: '#A8B1C2' };
const FUENTE = "'Segoe UI', system-ui, -apple-system, sans-serif";

// ================================================================== estado
const S = {
    datos: null, planta: 0, bodegaSel: 0, permisos: {}, qr: {},
    filtro: new Set(), modoAlertas: false, edicion: false,
    cajas: [], racks: [], pisos: [], fantasmas: [],
    porBodega: new Map(), hover: null, sel: null,
    vuelo: null, pick: null, tour: null, fovMeta: FOV_MAPA,
    etiquetasVivas: new Map(), vigasHD: new Set(), imagenes: new Map(),
    basura: [], basuraEdicion: [], cat: null, conteos: new Map(),
    posiciones: new Map(), plano: { racks: new Map(), zonas: [] }, version: null,
    modo: 'normal', consumo: null, compat: null, historial: null, moverRack: null, dibujo: null
};

// ================================================================== motor
let renderer;
try {
    renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' });
} catch (e) {
    document.getElementById('bm3dEstado').innerHTML = '<p>Este navegador no puede dibujar 3D (WebGL no está disponible).</p>';
    throw e;
}
const escenaEl = document.getElementById('bm3dEscena');
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.06;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
escenaEl.appendChild(renderer.domElement);
const ANISO = renderer.capabilities.getMaxAnisotropy();

const scene = new THREE.Scene();
scene.background = new THREE.Color('#0B1120');
scene.fog = new THREE.Fog('#0B1120', 60, 170);
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;

const camera = new THREE.PerspectiveCamera(FOV_MAPA, 1, 0.05, 500);
camera.position.set(-40, 40, 50);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.07;
controls.maxPolarAngle = Math.PI / 2 - 0.03;
controls.minDistance = 0.9;
controls.maxDistance = 180;
controls.screenSpacePanning = true;

scene.add(new THREE.HemisphereLight('#DCE6FF', '#1A2133', 0.6));
const sol = new THREE.DirectionalLight('#FFFFFF', 1.9);
sol.castShadow = true;
sol.shadow.mapSize.set(2048, 2048);
sol.shadow.bias = -0.0004;
sol.shadow.normalBias = 0.02;
scene.add(sol, sol.target);

/* Luz de mano del recorrido: sigue a la camara para que el pasillo no quede
   en la sombra de los propios racks. */
const linterna = new THREE.PointLight('#FFF4E0', 0, 9, 1.6);
scene.add(linterna);

const mundo = new THREE.Group();
const capaEdicion = new THREE.Group();
const capaRecorrido = new THREE.Group();
scene.add(mundo, capaEdicion, capaRecorrido);

// =========================================================== texturas base
function canvas(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
function tex(c, repetir) {
    const t = new THREE.CanvasTexture(c);
    t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = ANISO;
    if (repetir) t.wrapS = t.wrapT = THREE.RepeatWrapping;
    return t;
}

function texPuntal() {
    const c = canvas(64, 256), g = c.getContext('2d');
    g.fillStyle = '#1F4F9A'; g.fillRect(0, 0, 64, 256);
    const grad = g.createLinearGradient(0, 0, 64, 0);
    grad.addColorStop(0, 'rgba(255,255,255,.10)'); grad.addColorStop(.5, 'rgba(255,255,255,0)'); grad.addColorStop(1, 'rgba(0,0,0,.18)');
    g.fillStyle = grad; g.fillRect(0, 0, 64, 256);
    g.fillStyle = '#0A1B36';
    for (let y = 8; y < 256; y += 32) {
        g.beginPath(); g.moveTo(32, y); g.lineTo(38, y + 6); g.lineTo(38, y + 18); g.lineTo(26, y + 18); g.lineTo(26, y + 6); g.closePath(); g.fill();
    }
    const t = tex(c, true); t.repeat.set(1, 6); return t;
}
function texMalla() {
    const c = canvas(256, 256), g = c.getContext('2d');
    g.strokeStyle = '#C9D0DC'; g.lineWidth = 5;
    for (let i = 0; i <= 256; i += 32) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, 256); g.stroke(); }
    g.lineWidth = 3;
    for (let i = 0; i <= 256; i += 16) { g.beginPath(); g.moveTo(0, i); g.lineTo(256, i); g.stroke(); }
    const t = tex(c, true); t.repeat.set(7, 3); return t;
}
function texPiso() {
    const c = canvas(1024, 1024), g = c.getContext('2d');
    g.fillStyle = '#4C566B'; g.fillRect(0, 0, 1024, 1024);
    for (let i = 0; i < 9000; i++) {
        const v = 60 + Math.random() * 40;
        g.fillStyle = `rgba(${v},${v + 8},${v + 22},${Math.random() * .14})`;
        g.fillRect(Math.random() * 1024, Math.random() * 1024, 1 + Math.random() * 3, 1 + Math.random() * 3);
    }
    g.strokeStyle = 'rgba(20,26,40,.32)'; g.lineWidth = 2;
    for (let i = 0; i <= 1024; i += 256) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, 1024); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(1024, i); g.stroke(); }
    return tex(c, true);
}
function texCarton() {
    const c = canvas(256, 256), g = c.getContext('2d');
    g.fillStyle = '#C49A6C'; g.fillRect(0, 0, 256, 256);
    for (let i = 0; i < 2500; i++) {
        g.fillStyle = `rgba(${90 + Math.random() * 60},${60 + Math.random() * 40},30,${Math.random() * .12})`;
        g.fillRect(Math.random() * 256, Math.random() * 256, 1 + Math.random() * 2, 1 + Math.random() * 6);
    }
    g.fillStyle = 'rgba(110,80,45,.55)'; g.fillRect(0, 118, 256, 20);
    return tex(c, false);
}
function texBrillo() {
    // estela del barrido del recorrido: transparente arriba, intensa abajo
    const c = canvas(8, 128), g = c.getContext('2d');
    const gr = g.createLinearGradient(0, 0, 0, 128);
    gr.addColorStop(0, 'rgba(22,198,201,0)'); gr.addColorStop(1, 'rgba(22,198,201,.55)');
    g.fillStyle = gr; g.fillRect(0, 0, 8, 128);
    return tex(c, false);
}
const T = { puntal: texPuntal(), malla: texMalla(), piso: texPiso(), carton: texCarton(), brillo: texBrillo() };

// ================================================================ materiales
const MAT = {
    puntal: new THREE.MeshStandardMaterial({ map: T.puntal, metalness: 0.55, roughness: 0.42 }),
    riostra: new THREE.MeshStandardMaterial({ color: '#1F4F9A', metalness: 0.55, roughness: 0.45 }),
    viga: new THREE.MeshPhysicalMaterial({ color: '#E06A16', metalness: 0.35, roughness: 0.38, clearcoat: 0.6, clearcoatRoughness: 0.25 }),
    malla: new THREE.MeshStandardMaterial({ color: '#AEB7C6', metalness: 0.8, roughness: 0.35, alphaMap: T.malla, alphaTest: 0.4, side: THREE.DoubleSide }),
    placa: new THREE.MeshStandardMaterial({ color: '#111827', metalness: 0.4, roughness: 0.6 }),
    carton: new THREE.MeshStandardMaterial({ map: T.carton, roughness: 0.92, metalness: 0 }),
    piso: new THREE.MeshStandardMaterial({ map: T.piso, roughness: 0.32, metalness: 0.18 }),
    muro: new THREE.MeshStandardMaterial({ color: '#8C96A8', roughness: 0.85, metalness: 0.05 }),
    columna: new THREE.MeshStandardMaterial({ color: '#2B3448', roughness: 0.5, metalness: 0.6 }),
    amarillo: new THREE.MeshBasicMaterial({ color: '#F2C230', toneMapped: false }),
    cable: new THREE.MeshBasicMaterial({ color: '#59627A' }),
    pallet: new THREE.MeshStandardMaterial({ color: '#9C7448', roughness: 0.9 }),
    contorno: new THREE.LineBasicMaterial({ color: '#16C6C9', toneMapped: false, transparent: true, depthTest: false, depthWrite: false }),
    fantasma: new THREE.MeshBasicMaterial({ color: '#16C6C9', transparent: true, opacity: 0.1, depthWrite: false, toneMapped: false }),
    fantasmaHover: new THREE.MeshBasicMaterial({ color: '#16C6C9', transparent: true, opacity: 0.26, depthWrite: false, toneMapped: false }),
    fantasmaLinea: new THREE.LineDashedMaterial({ color: '#16C6C9', dashSize: 0.18, gapSize: 0.12, toneMapped: false, transparent: true, opacity: 0.9 }),
    marca: new THREE.LineBasicMaterial({ color: '#FF4D42', toneMapped: false, transparent: true, depthTest: false, depthWrite: false }),
    laser: new THREE.MeshBasicMaterial({ color: '#7FF7F9', toneMapped: false, transparent: true, opacity: 0.95, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }),
    estela: new THREE.MeshBasicMaterial({ map: T.brillo, toneMapped: false, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })
};

const MAT_FAM = new Map();
function matFamilia(color) {
    if (!MAT_FAM.has(color)) {
        MAT_FAM.set(color, {
            normal: new THREE.MeshPhysicalMaterial({ color, roughness: 0.42, metalness: 0, clearcoat: 0.35, clearcoatRoughness: 0.4 }),
            tenue: new THREE.MeshStandardMaterial({ color, roughness: 0.6, transparent: true, opacity: 0.1, depthWrite: false })
        });
    }
    return MAT_FAM.get(color);
}
const MAT_CARTON_TENUE = new THREE.MeshStandardMaterial({ color: '#C49A6C', transparent: true, opacity: 0.1, depthWrite: false });
const MAT_ALERTA = {
    bajo: new THREE.MeshStandardMaterial({ color: '#C7352B', emissive: '#C7352B', emissiveIntensity: 0.6, roughness: 0.4 }),
    sobre: new THREE.MeshStandardMaterial({ color: '#B65C00', emissive: '#B65C00', emissiveIntensity: 0.45, roughness: 0.4 })
};

// ============================================================ utilidades
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
const num = (v) => (v == null || v === '' ? '—' : Number(v).toLocaleString('es-CL', { maximumFractionDigits: 2 }));
const lerp = (a, b, t) => a + (b - a) * t;
const clamp01 = (t) => Math.max(0, Math.min(1, t));
const suave = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const paso = (t) => t * t * (3 - 2 * t);
const pad2 = (n) => String(n).padStart(2, '0');
const norm = (t) => String(t || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const corto = (codigo) => String(codigo || '').split('-').pop();

function familiaDe(tc) { return String(tc || '').split('-')[0].toUpperCase(); }
const coloresAsignados = new Map();
function infoFamilia(pref) {
    if (!pref) return SIN_TIPO;
    if (FAMILIAS[pref]) return FAMILIAS[pref];
    if (!coloresAsignados.has(pref)) coloresAsignados.set(pref, { nombre: pref, color: COLORES_EXTRA[coloresAsignados.size % COLORES_EXTRA.length] });
    return coloresAsignados.get(pref);
}
function estadoDe(it) {
    if (it.min == null && it.max == null) return 'sin';
    if (it.min != null && it.q < it.min) return 'bajo';
    if (it.max != null && it.q > it.max) return 'sobre';
    return 'ok';
}
function hexSuave(hex) { return '#' + new THREE.Color(hex).lerp(new THREE.Color('#FFFFFF'), 0.88).getHexString(); }

async function ws(metodo, datos) {
    const r = await fetch(WS + '/' + metodo, {
        method: 'POST', credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
        body: JSON.stringify(datos || {})
    });
    if (!r.ok) throw new Error('El servidor respondió ' + r.status + '.');
    const d = JSON.parse((await r.json()).d);
    if (d.error) throw new Error(d.detalle || 'No se pudo completar la operación.');
    return d;
}

function aviso(texto, error) {
    const t = document.createElement('div');
    t.className = 'bm3d-toast' + (error ? ' es-error' : '');
    t.innerHTML = '<i class="mdi ' + (error ? 'mdi-alert-circle' : 'mdi-check-circle') + '"></i><span>' + esc(texto) + '</span>';
    $('bm3dToasts').appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .4s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 400); }, error ? 6500 : 3200);
}

/** Interpreta P1-A-R01 como pasillo A, rack 1. Lo que no calce va a un pasillo aparte. */
function leerUbicacion(codigo, i) {
    const partes = String(codigo || '').toUpperCase().split(/[-_\s.]+/).filter(Boolean);
    const ult = partes[partes.length - 1] || '', pen = partes[partes.length - 2] || '';
    const n = parseInt(ult.replace(/\D/g, ''), 10);
    if (!isNaN(n) && /^[A-Z]{1,3}$/.test(pen)) return { pasillo: pen, rack: n };
    return { pasillo: '·', rack: 1000 + i };
}

// ===================================================================== layout
/* El mapa ocupa TODO el centro: de la barra superior hacia abajo y del menu
   lateral hacia la derecha, sin margen blanco. Si se pliega el menu, se
   reacomoda solo. */
function encajar() {
    if (document.fullscreenElement === root) return;
    const barra = document.querySelector('.navbar-custom');
    const menu = document.querySelector('.left-side-menu');
    const top = barra ? Math.max(0, barra.getBoundingClientRect().bottom) : 0;
    let left = 0;
    if (menu) {
        const r = menu.getBoundingClientRect(), cs = getComputedStyle(menu);
        if (cs.display !== 'none' && cs.visibility !== 'hidden' && r.width > 0 && r.right > 0) left = r.right;
    }
    root.style.inset = top + 'px 0 0 ' + left + 'px';
}
function redimensionar() {
    const w = escenaEl.clientWidth, h = escenaEl.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    renderer.domElement.style.width = w + 'px';
    renderer.domElement.style.height = h + 'px';
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
}

function mostrarEstado(tipo, texto) {
    const e = $('bm3dEstado');
    if (tipo === 'ok') { e.classList.add('is-oculto'); return; }
    e.classList.remove('is-oculto');
    e.innerHTML = tipo === 'cargando'
        ? '<div class="bm3d-loader"><span></span><span></span><span></span></div><p>' + esc(texto) + '</p>'
        : '<i class="mdi mdi-alert-circle-outline" style="font-size:34px;color:#16C6C9"></i><p>' + esc(texto) + '</p>' +
          '<button type="button" class="bm3d-btn es-contorno es-chico" id="bm3dReintentar"><i class="mdi mdi-refresh"></i>Reintentar</button>';
    const b = $('bm3dReintentar'); if (b) b.onclick = () => cargar(S.planta);
}

// ======================================================================== QR
/* El servidor manda cada QR como matriz "lado:hex" (EtiquetaController.
   QrMatriz): el mismo codigo que imprime el Centro de etiquetas, que aqui se
   dibuja al tamano que haga falta. */
const QR_CACHE = new Map();
function qrDe(token) {
    if (QR_CACHE.has(token)) return QR_CACHE.get(token);
    const m = S.qr && S.qr[token];
    if (!m) { if (token) pedirQr(token); return null; }
    const i = m.indexOf(':'), lado = +m.slice(0, i), hex = m.slice(i + 1);
    const bits = new Uint8Array(lado * lado);
    for (let k = 0; k < bits.length; k++) bits[k] = (parseInt(hex[k >> 2], 16) >> (3 - (k & 3))) & 1;
    const q = { lado, bits };
    QR_CACHE.set(token, q);
    return q;
}
function dibujarQr(g, token, x, y, tam) {
    g.fillStyle = '#FFFFFF'; g.fillRect(x, y, tam, tam);
    const q = qrDe(token);
    if (!q) return false;
    const k = tam / q.lado;
    g.fillStyle = '#000000';
    for (let r = 0; r < q.lado; r++) {
        const y0 = Math.floor(y + r * k), y1 = Math.floor(y + (r + 1) * k);
        for (let c = 0; c < q.lado; c++)
            if (q.bits[r * q.lado + c]) { const x0 = Math.floor(x + c * k); g.fillRect(x0, y0, Math.floor(x + (c + 1) * k) - x0, y1 - y0); }
    }
    return true;
}
/* Los QR de los repuestos no vienen en la carga (generarlos es lo caro): se
   piden en lote cuando la camara se acerca a una caja, y al llegar se
   redibujan las etiquetas que los esperaban. */
const QR_PEDIDOS = new Set();
let colaQr = new Set(), timerQr = 0;
function pedirQr(token) {
    if (QR_PEDIDOS.has(token)) return;
    QR_PEDIDOS.add(token); colaQr.add(token);
    if (!timerQr) timerQr = setTimeout(async () => {
        const lote = [...colaQr]; colaQr = new Set(); timerQr = 0;
        try {
            const r = await ws('Qr', { tokens: lote.join(',') });
            Object.assign(S.qr, r.qr || {});
            for (const [mesh, t] of S.etiquetasVivas) {
                if (!r.qr['REP-' + mesh.userData.item.id]) continue;
                dibujarEtiquetaCaja(mesh.userData.item, t.image); t.needsUpdate = true;
            }
        } catch (e) { lote.forEach((x) => QR_PEDIDOS.delete(x)); }
    }, 60);
}
/* Impostor de lejos: tres marcas de posicion y modulos sueltos. No se lee (no
   tiene que): a esa distancia el QR real no se distinguiria igual, y al
   acercarse se reemplaza por el verdadero. */
function dibujarQrLejano(g, x, y, tam) {
    g.fillStyle = '#FFFFFF'; g.fillRect(x, y, tam, tam);
    const k = tam / 25;
    g.fillStyle = '#1A1A1A';
    for (const [cx, cy] of [[2, 2], [16, 2], [2, 16]]) {
        g.fillRect(x + cx * k, y + cy * k, 7 * k, 7 * k);
        g.fillStyle = '#FFFFFF'; g.fillRect(x + (cx + 1) * k, y + (cy + 1) * k, 5 * k, 5 * k);
        g.fillStyle = '#1A1A1A'; g.fillRect(x + (cx + 2) * k, y + (cy + 2) * k, 3 * k, 3 * k);
    }
    g.globalAlpha = 0.55; g.fillRect(x + 10 * k, y + 10 * k, 13 * k, 13 * k); g.globalAlpha = 1;
}

// ======================================================= dibujo 2D comun
function envolver(g, texto, x, y, ancho, alto, lineas) {
    const palabras = String(texto || '').split(/\s+/);
    let linea = '', n = 0;
    for (let i = 0; i < palabras.length; i++) {
        const prueba = linea ? linea + ' ' + palabras[i] : palabras[i];
        if (g.measureText(prueba).width > ancho && linea) {
            if (n === lineas - 1) { g.fillText(recortar(g, linea + ' ' + palabras.slice(i).join(' '), ancho), x, y + n * alto); return n + 1; }
            g.fillText(linea, x, y + n * alto); n++; linea = palabras[i];
        } else linea = prueba;
    }
    if (linea) { g.fillText(recortar(g, linea, ancho), x, y + n * alto); n++; }
    return n;
}
function lineasDe(g, texto, ancho, lineas) {
    const palabras = String(texto || '').split(/\s+/);
    let linea = '', n = 1;
    for (const p of palabras) {
        const prueba = linea ? linea + ' ' + p : p;
        if (g.measureText(prueba).width > ancho && linea) { n++; linea = p; } else linea = prueba;
    }
    return Math.min(n, lineas);
}
function recortar(g, t, ancho) {
    t = String(t || '');
    if (g.measureText(t).width <= ancho) return t;
    while (t.length > 1 && g.measureText(t + '…').width > ancho) t = t.slice(0, -1);
    return t + '…';
}
function rrect(g, x, y, w, h, r) {
    g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}

/* ---------------------------------------------------------------------------
   UNA ETIQUETA, con el diseno de Comun/Impresion/Etiquetas.aspx
     QR a la izquierda; al lado, codigo en negrita (el tamano lo decide el
     largo, como Escala() en el code-behind: el codigo nunca se recorta, se
     parte), titulo a dos lineas, subtitulo y pie en gris, detalle en negrita.
   e = { token, codigo, titulo, subtitulo, detalle, pie, estado?, color? }
   --------------------------------------------------------------------------- */
function dibujarEtiqueta(g, x, y, w, h, e, o) {
    o = o || {};
    g.save();
    const radio = Math.max(2, h * 0.045);
    g.fillStyle = '#FFFFFF'; rrect(g, x, y, w, h, radio); g.fill();
    if (o.borde) { g.strokeStyle = 'rgba(0,0,0,.18)'; g.lineWidth = Math.max(1, h * 0.008); rrect(g, x + 0.5, y + 0.5, w - 1, h - 1, radio); g.stroke(); }
    if (e.color) { g.fillStyle = e.color; g.fillRect(x, y + h * 0.06, Math.max(2, h * 0.035), h * 0.88); }
    const pad = h * 0.075, lado = h - 2 * pad;
    // mientras llega el QR real se ve el impostor, no un cuadro en blanco
    if (o.lejos || !dibujarQr(g, e.token, x + pad * 1.2, y + pad, lado)) dibujarQrLejano(g, x + pad * 1.2, y + pad, lado);
    const tx = x + pad * 2.2 + lado, tw = w - (tx - x) - pad;
    if (tw < h * 0.25) { g.restore(); return; }

    const L = String(e.codigo || '').trim().length;
    const fc = h * (L <= 6 ? 0.25 : L <= 9 ? 0.2 : L <= 14 ? 0.155 : 0.125);
    const ft = h * 0.105, fs = h * 0.088, fd = h * 0.11;
    g.textBaseline = 'alphabetic'; g.textAlign = 'left';

    // alto del bloque para centrarlo, como align-items:center del .etq
    g.font = `800 ${fc}px ${FUENTE}`;
    const lc = Math.min(2, Math.max(1, Math.ceil(g.measureText(e.codigo || '').width / tw)));
    g.font = `600 ${ft}px ${FUENTE}`;
    const lt = e.titulo ? lineasDe(g, e.titulo, tw, (o.lejos || lc > 1) ? 1 : 2) : 0;
    const alto = lc * fc * 1.05 + lt * ft * 1.2 + (e.subtitulo ? fs * 1.25 : 0) + (e.detalle ? fd * 1.25 : 0) + (e.pie ? fs * 1.25 : 0);
    let yy = y + Math.max(pad, (h - alto) / 2);

    g.fillStyle = '#000000'; g.font = `800 ${fc}px ${FUENTE}`;
    if (lc <= 1) { yy += fc * 0.92; g.fillText(e.codigo || '', tx, yy); yy += fc * 0.13; }
    else {
        // partirlo es preferible a no poder leerlo
        const t = String(e.codigo), corte = Math.ceil(t.length / 2);
        yy += fc * 0.92; g.fillText(recortar(g, t.slice(0, corte), tw), tx, yy);
        yy += fc * 1.05; g.fillText(recortar(g, t.slice(corte), tw), tx, yy); yy += fc * 0.13;
    }
    if (lt) { g.fillStyle = '#1A1A1A'; g.font = `600 ${ft}px ${FUENTE}`; envolver(g, e.titulo, tx, yy + ft * 1.0, tw, ft * 1.2, lt); yy += lt * ft * 1.2; }
    if (e.subtitulo) { g.fillStyle = '#555555'; g.font = `500 ${fs}px ${FUENTE}`; yy += fs * 1.2; g.fillText(recortar(g, e.subtitulo, tw), tx, yy); }
    if (e.detalle) {
        g.font = `700 ${fd}px ${FUENTE}`; yy += fd * 1.22;
        const dx = e.estado ? fd * 0.85 : 0;
        if (e.estado) { g.fillStyle = COLOR_ESTADO[e.estado]; g.beginPath(); g.arc(tx + fd * 0.32, yy - fd * 0.34, fd * 0.3, 0, Math.PI * 2); g.fill(); }
        g.fillStyle = '#000000'; g.fillText(recortar(g, e.detalle, tw - dx), tx + dx, yy);
    }
    if (e.pie) { g.fillStyle = '#555555'; g.font = `500 ${fs}px ${FUENTE}`; yy += fs * 1.22; g.fillText(recortar(g, e.pie, tw), tx, yy); }
    g.restore();
}

/* Los datos de cada etiqueta, tal como los arma SEL_ETIQUETA por origen. */
function etqRepuesto(it) {
    return {
        token: 'REP-' + it.id, codigo: it.c, titulo: it.n,
        subtitulo: [it.fab, it.mod].filter(Boolean).join(' ') || it.tn,
        detalle: num(it.q) + ' ' + (it.un || ''), estado: estadoDe(it), pie: it.tn || 'Repuesto', color: it.color
    };
}
function etqUbicacion(rack, caja, nivel, pos) {
    const b = rack.bodega;
    if (caja) {
        const it = caja.userData.item;   // UBICACION_REPUESTO: el casillero con lo que guarda hoy
        return { token: 'UBI-' + rack.id, codigo: rack.codigo, titulo: it.n, subtitulo: it.c, detalle: num(it.q) + ' ' + (it.un || ''), estado: estadoDe(it), pie: b.codigo + ' · ' + nivel + '-' + pad2(pos) };
    }
    return { token: 'UBI-' + rack.id, codigo: rack.codigo, titulo: rack.nombre || 'Ubicación', subtitulo: b.codigo + ' · ' + b.nombre, detalle: '', pie: 'Posición ' + nivel + '-' + pad2(pos) + ' · libre' };
}

function placaTexto(lineas, ancho, alto, fondo, o) {
    o = o || {};
    const c = canvas(ancho, alto), g = c.getContext('2d');
    g.fillStyle = fondo; rrect(g, 0, 0, ancho, alto, o.radio || 18); g.fill();
    if (o.borde) { g.strokeStyle = o.borde; g.lineWidth = 6; rrect(g, 3, 3, ancho - 6, alto - 6, (o.radio || 18) - 3); g.stroke(); }
    g.textAlign = 'center'; g.textBaseline = 'middle';
    for (const l of lineas) { g.fillStyle = l.color; g.font = l.fuente; g.fillText(recortar(g, l.texto, ancho - 40), ancho / 2, l.y); }
    const t = tex(c); S.basura.push(t);
    return t;
}
function planoTexto(t, w, h, transparente) {
    const mat = new THREE.MeshBasicMaterial({ map: t, toneMapped: false, transparent: !!transparente, depthWrite: !transparente });
    const geo = new THREE.PlaneGeometry(w, h);
    S.basura.push(mat, geo);
    return new THREE.Mesh(geo, mat);
}
/* Etiqueta adhesiva: opaca donde hay papel, recortada donde no. alphaTest en
   vez de transparencia, para que no pelee el orden de dibujo con las cajas. */
function planoEtiqueta(t, w, h) {
    const mat = new THREE.MeshBasicMaterial({ map: t, toneMapped: false, alphaTest: 0.5, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
    const geo = new THREE.PlaneGeometry(w, h);
    S.basura.push(mat, geo);
    return new THREE.Mesh(geo, mat);
}

// ======================================================= piezas de rack
function geometriaRack() {
    const W = RACK.ancho, D = RACK.prof, H = RACK.alto;
    const partes = { puntal: [], riostra: [], viga: [], malla: [], placa: [] };
    const caja = (w, h, d, x, y, z, rx, destino) => {
        const g = new THREE.BoxGeometry(w, h, d);
        if (rx) g.rotateX(rx);
        g.translate(x, y, z);
        partes[destino].push(g);
    };
    const zf = D / 2 - 0.045, zb = -D / 2 + 0.045;
    for (const x of [-W / 2, W / 2]) {
        for (const z of [zf, zb]) {
            caja(0.085, H, 0.07, x, H / 2, z, 0, 'puntal');
            caja(0.15, 0.012, 0.14, x, 0.006, z, 0, 'placa');
        }
        const luz = zf - zb;
        caja(0.022, 0.03, luz, x, 0.22, 0, 0, 'riostra');
        caja(0.022, 0.03, luz, x, H - 0.12, 0, 0, 'riostra');
        const tramos = 4, alto = (H - 0.34) / tramos;
        for (let i = 0; i < tramos; i++) {
            const y0 = 0.22 + i * alto, y1 = y0 + alto;
            caja(0.02, 0.025, Math.hypot(luz, alto), x, (y0 + y1) / 2, 0, Math.atan2(alto, luz) * (i % 2 ? 1 : -1), 'riostra');
        }
    }
    for (const y of RACK.niveles) {
        const yc = y - RACK.viga / 2;
        caja(W, RACK.viga, 0.05, 0, yc, zf + 0.06, 0, 'viga');
        caja(W, RACK.viga, 0.05, 0, yc, zb - 0.06, 0, 'viga');
        const m = new THREE.PlaneGeometry(W - 0.04, D - 0.02);
        m.rotateX(-Math.PI / 2); m.translate(0, y + 0.004, 0);
        partes.malla.push(m);
        for (const x of [-W / 4, 0, W / 4]) caja(0.03, 0.025, D - 0.04, x, y - 0.012, 0, 0, 'riostra');
    }
    const res = {};
    for (const k in partes) res[k] = mergeGeometries(partes[k], false);
    return res;
}
const GEO_RACK = geometriaRack();
const Z_VIGA_FRENTE = RACK.prof / 2 - 0.045 + 0.06 + 0.025 + 0.003;   // cara frontal de la viga delantera

// ======================================================= etiquetas de cajas
const ETQ_LEJOS = new Map();
/* De lejos, una etiqueta compartida por tipo: el mismo papel blanco, el QR
   impostor y el tipo. Al acercarse se cambia por la del repuesto. */
function etiquetaLejos(it) {
    const k = it.tid + '|' + it.color;
    if (!ETQ_LEJOS.has(k)) {
        const c = canvas(256, Math.round(256 / RATIO_ETQ)), g = c.getContext('2d');
        dibujarEtiqueta(g, 0, 0, c.width, c.height, { codigo: it.tc ? (it.tc.split('-').slice(1).join('-') || it.tc) : 'SIN TIPO', titulo: it.tn, pie: 'Repuesto', color: it.color }, { lejos: true });
        ETQ_LEJOS.set(k, new THREE.MeshBasicMaterial({ map: tex(c), toneMapped: false }));
    }
    return ETQ_LEJOS.get(k);
}
function dibujarEtiquetaCaja(it, c) {
    const g = c.getContext('2d');
    g.clearRect(0, 0, c.width, c.height);
    dibujarEtiqueta(g, 0, 0, c.width, c.height, etqRepuesto(it));
}
function cargarImagen(url) {
    if (!url) return null;
    if (S.imagenes.has(url)) return S.imagenes.get(url);
    const img = new Image();
    img.decoding = 'async';
    img.src = url;
    S.imagenes.set(url, img);
    return img;
}

// =============================================================== construccion
function liberar() {
    marcarContorno(null);
    for (const r of S.basura) if (r && r.dispose) r.dispose();
    S.basura = [];
    for (const [, t] of S.etiquetasVivas) t.dispose();
    S.etiquetasVivas.clear();
    S.vigasHD.clear();
    while (mundo.children.length) mundo.remove(mundo.children[0]);
    limpiarEdicion();
    S.cajas = []; S.racks = []; S.pisos = []; S.porBodega.clear(); S.hover = null; S.sel = null;
}

function construir(datos) {
    liberar();
    const bodegas = datos.bodegas || [], saldos = datos.saldos || [];
    const porUbic = new Map(), sinUbic = new Map();
    for (const s of saldos) {
        s.fam = familiaDe(s.tc); s.color = infoFamilia(s.fam).color;
        s.pesado = PESADO.test(s.tc) || PESADO.test(s.tn);
        if (s.foto) cargarImagen(s.foto);
        const m = s.u ? porUbic : sinUbic, k = s.u || s.b;
        if (!m.has(k)) m.set(k, []);
        m.get(k).push(s);
    }

    const planos = bodegas.map((b) => {
        const grupos = new Map();
        (b.ubicaciones || []).forEach((u, i) => {
            const p = leerUbicacion(u.codigo, i);
            if (!grupos.has(p.pasillo)) grupos.set(p.pasillo, []);
            grupos.get(p.pasillo).push({ ...u, num: p.rack, pasillo: p.pasillo });
        });
        const pasillos = [...grupos.keys()].sort((a, c) => (a === '·') - (c === '·') || a.localeCompare(c));
        let largo = 0;
        const lista = pasillos.map((nom, i) => {
            const racks = grupos.get(nom).sort((a, c) => a.num - c.num);
            largo = Math.max(largo, Math.ceil(racks.length / 2) * (RACK.ancho + ENTRE_RACKS));
            return { nom, racks, x: i * (BLOQUE + ESPALDA) };
        });
        const anchoUtil = pasillos.length ? (pasillos.length - 1) * (BLOQUE + ESPALDA) + BLOQUE : 8;
        const hayRecepcion = sinUbic.has(b.id);
        return {
            b, lista, ancho: anchoUtil + 2 * MARGEN,
            largo: Math.max(largo, 6) + 2 * MARGEN + (hayRecepcion ? ZONA_RECEPCION : 0) + 2, hayRecepcion
        };
    });

    let x = 0;
    for (const pl of planos) { construirBodega(pl, x, porUbic, sinUbic.get(pl.b.id) || []); x += pl.ancho + ENTRE_BODEGAS; }

    const n = S.racks.length;
    S.instRack = [];
    if (n) {
        const dummy = new THREE.Object3D(), inst = {};
        for (const k of ['puntal', 'riostra', 'viga', 'malla', 'placa']) {
            const im = new THREE.InstancedMesh(GEO_RACK[k], MAT[k], n);
            im.castShadow = k !== 'malla'; im.receiveShadow = true;
            inst[k] = im; mundo.add(im); S.basura.push(im);
        }
        S.racks.forEach((r, i) => {
            dummy.position.copy(r.pos); dummy.rotation.set(0, r.rot, 0); dummy.updateMatrix();
            for (const k in inst) inst[k].setMatrixAt(i, dummy.matrix);
        });
        for (const k in inst) { inst[k].instanceMatrix.needsUpdate = true; inst[k].computeBoundingSphere(); }
        S.instRack = [inst.puntal, inst.viga, inst.riostra];
    }
    armarLeyenda();
    if (S.edicion) armarEdicion();
}

function construirBodega(pl, ox, porUbic, recepcion) {
    const b = pl.b, g = new THREE.Group();
    g.position.set(ox, 0, 0);
    mundo.add(g);
    const W = pl.ancho, L = pl.largo, cx = W / 2, cz = L / 2;

    const pisoMat = MAT.piso.clone();
    pisoMat.map = T.piso.clone(); pisoMat.map.needsUpdate = true; pisoMat.map.repeat.set(W / 8, L / 8);
    const piso = new THREE.Mesh(new THREE.PlaneGeometry(W, L), pisoMat);
    piso.rotation.x = -Math.PI / 2; piso.position.set(cx, 0, cz); piso.receiveShadow = true;
    piso.userData.bodegaId = b.id;
    g.add(piso); S.pisos.push(piso); S.basura.push(piso.geometry, pisoMat, pisoMat.map);

    const losa = new THREE.Mesh(new THREE.BoxGeometry(W + 0.6, 0.25, L + 0.6), MAT.muro);
    losa.position.set(cx, -0.126, cz); losa.receiveShadow = true; g.add(losa); S.basura.push(losa.geometry);

    const alto = 0.55, esp = 0.18;
    for (const m of [[W, alto, esp, cx, alto / 2, L], [esp, alto, L, 0, alto / 2, cz], [esp, alto, L, W, alto / 2, cz],
                     [W * 0.3, alto, esp, W * 0.15, alto / 2, 0], [W * 0.3, alto, esp, W * 0.85, alto / 2, 0]]) {
        const geo = new THREE.BoxGeometry(m[0], m[1], m[2]);
        const mesh = new THREE.Mesh(geo, MAT.muro);
        mesh.position.set(m[3], m[4], m[5]); mesh.castShadow = true; mesh.receiveShadow = true;
        g.add(mesh); S.basura.push(geo);
    }

    /* Galpon insinuado: columnas y largueros laterales. Sin cubierta ni vigas
       cruzadas, que tapan los racks desde cualquier angulo util. */
    const H = 8.2;
    const colGeo = new THREE.BoxGeometry(0.3, H, 0.3); S.basura.push(colGeo);
    const colsZ = [];
    for (let z = 0; z <= L + 0.01; z += 6) colsZ.push(Math.min(z, L));
    if (colsZ[colsZ.length - 1] < L - 0.5) colsZ.push(L);
    for (const xx of [0, W]) for (const z of colsZ) {
        const c = new THREE.Mesh(colGeo, MAT.columna); c.position.set(xx, H / 2, z); c.castShadow = true; g.add(c);
    }
    const largueroGeo = new THREE.BoxGeometry(0.16, 0.2, L); S.basura.push(largueroGeo);
    for (const xx of [0, W]) { const l = new THREE.Mesh(largueroGeo, MAT.columna); l.position.set(xx, H, cz); g.add(l); }

    // nombre pintado en el piso, legible desde la entrada
    const nombre = placaTexto([
        { texto: b.nombre.toUpperCase(), color: '#F2C230', fuente: `900 92px ${FUENTE}`, y: 70 },
        { texto: (b.descripcion || b.codigo).split('.')[0].toUpperCase(), color: 'rgba(242,194,48,.75)', fuente: `700 40px ${FUENTE}`, y: 150 }
    ], 1600, 200, 'rgba(0,0,0,0)', { radio: 1 });
    const anchoNom = Math.min(W - 1, 14);
    const nomMesh = planoTexto(nombre, anchoNom, anchoNom / 8, true);
    nomMesh.rotation.x = -Math.PI / 2; nomMesh.rotation.z = Math.PI; nomMesh.position.set(cx, 0.012, -1.6);
    g.add(nomMesh);
    lineaPiso(g, cx, -0.45, W, 0.12);
    letreroBodega(g, b, W);
    dibujarZonas(g, b.id);

    const zIni = MARGEN + (pl.hayRecepcion ? ZONA_RECEPCION : 0);
    const info = { id: b.id, bodega: b, grupo: g, ox, racks: [], cajas: [], pasillos: [], zIni, ancho: W, largo: L };

    for (const pa of pl.lista) {
        const xc = MARGEN + pa.x + BLOQUE / 2;
        const largo = Math.ceil(pa.racks.length / 2) * (RACK.ancho + ENTRE_RACKS);
        lineaPiso(g, xc - PASILLO / 2 + 0.08, zIni + largo / 2, 0.08, largo + 1.6);
        lineaPiso(g, xc + PASILLO / 2 - 0.08, zIni + largo / 2, 0.08, largo + 1.6);
        if (pa.nom !== '·') {
            const letra = placaTexto([{ texto: pa.nom, color: 'rgba(242,194,48,.9)', fuente: `900 220px ${FUENTE}`, y: 128 }], 256, 256, 'rgba(0,0,0,0)', { radio: 1 });
            const lm = planoTexto(letra, 1.5, 1.5, true);
            lm.rotation.x = -Math.PI / 2; lm.rotation.z = Math.PI; lm.position.set(xc, 0.013, zIni - 0.9);
            g.add(lm);
        }
        letreroPasillo(g, xc, zIni - 0.2, pa.nom, pa.racks.length);

        const infoPa = { nom: pa.nom, x: ox + xc, xLocal: xc, z0: zIni, z1: zIni + largo, racks: [], info };
        info.pasillos.push(infoPa);

        pa.racks.forEach((u, i) => {
            let izq = i % 2 === 0;
            const slot = Math.floor(i / 2);
            let px = ox + xc + (izq ? -1 : 1) * (PASILLO / 2 + RACK.prof / 2);
            let pz = zIni + slot * (RACK.ancho + ENTRE_RACKS) + RACK.ancho / 2;
            let rot = izq ? Math.PI / 2 : -Math.PI / 2;
            // si se movio en el plano (BD/329), manda la posicion guardada sobre la del codigo
            const pl = S.plano.racks.get(u.id);
            if (pl) { px = ox + pl.x; pz = pl.z; rot = pl.rot; izq = Math.sin(rot) > 0; }
            const nx = Math.round(Math.sin(rot) * 1e6) / 1e6, nz = Math.round(Math.cos(rot) * 1e6) / 1e6;
            const rack = {
                id: u.id, codigo: u.codigo, nombre: u.nombre, pasillo: pa.nom, num: u.num, bodega: b, info, infoPa,
                pos: new THREE.Vector3(px, 0, pz), rot,
                normal: new THREE.Vector3(nx, 0, nz), lado: izq ? 'izq' : 'der', movido: !!pl, carga: u.carga,
                items: porUbic.get(u.id) || [], cajas: [], cols: 3, indice: S.racks.length, vigas: []
            };
            S.racks.push(rack); info.racks.push(rack); infoPa.racks.push(rack);
            poblarRack(rack, info);
            marcarSobrecarga(rack);
            letreroRack(rack);
            etiquetasFierro(rack);
        });
    }

    if (recepcion.length) poblarRecepcion(g, info, recepcion, W, zIni);

    if (!pl.lista.length) {
        const av = placaTexto([{ texto: 'SIN UBICACIONES · ACTIVE EL MODO EDICIÓN PARA CREAR RACKS', color: 'rgba(255,255,255,.55)', fuente: `800 46px ${FUENTE}`, y: 64 }], 1600, 128, 'rgba(0,0,0,0)', { radio: 1 });
        const am = planoTexto(av, Math.min(W - 1, 12), Math.min(W - 1, 12) / 12.5, true);
        am.rotation.x = -Math.PI / 2; am.rotation.z = Math.PI; am.position.set(cx, 0.014, cz); g.add(am);
    }

    info.centro = new THREE.Vector3(ox + cx, 0, cz);
    info.span = Math.max(W, L);
    S.porBodega.set(b.id, info);
}

function lineaPiso(g, x, z, w, l) {
    const geo = new THREE.PlaneGeometry(w, l); S.basura.push(geo);
    const m = new THREE.Mesh(geo, MAT.amarillo);
    m.rotation.x = -Math.PI / 2; m.position.set(x, 0.011, z);
    g.add(m);
}

/* La etiqueta BOD- de la bodega, en un atril junto a la entrada. */
function letreroBodega(g, b, W) {
    const c = canvas(700, Math.round(700 / RATIO_ETQ)), ctx = c.getContext('2d');
    dibujarEtiqueta(ctx, 0, 0, c.width, c.height, { token: 'BOD-' + b.id, codigo: b.codigo, titulo: b.nombre, subtitulo: b.planta || '', pie: 'Bodega' });
    const t = tex(c); S.basura.push(t);
    const w = 0.95, h = w / RATIO_ETQ;
    const x = Math.max(0.8, W * 0.3 - 0.7);
    const m = planoEtiqueta(t, w, h);
    m.position.set(x, 1.32, -0.42); m.rotation.set(-0.12, Math.PI, 0, 'YXZ');
    g.add(m);
    const atril = new THREE.Mesh(new THREE.BoxGeometry(w + 0.06, h + 0.06, 0.03), MAT.columna);
    atril.position.set(x, 1.32, -0.39); atril.rotation.set(-0.12, Math.PI, 0, 'YXZ'); g.add(atril);
    const poste = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.1, 10), MAT.columna);
    poste.position.set(x, 0.55, -0.36); g.add(poste);
    S.basura.push(atril.geometry, poste.geometry);
}

function letreroPasillo(g, x, z, nom, racks) {
    const alto = 4.9;
    const t = placaTexto([
        { texto: nom === '·' ? 'OTRAS' : nom, color: '#FFFFFF', fuente: `900 150px ${FUENTE}`, y: 118 },
        { texto: nom === '·' ? 'UBICACIONES' : 'PASILLO ' + nom + ' · ' + racks + ' RACK' + (racks === 1 ? '' : 'S'), color: '#16C6C9', fuente: `800 38px ${FUENTE}`, y: 224 }
    ], 512, 270, '#17223B', { radio: 24, borde: '#16C6C9' });
    const m = planoTexto(t, 1.7, 0.9);
    m.material.side = THREE.DoubleSide;
    m.position.set(x, alto, z); m.rotation.y = Math.PI;
    g.add(m);
    const cGeo = new THREE.CylinderGeometry(0.008, 0.008, 8.2 - alto - 0.45, 6); S.basura.push(cGeo);
    for (const s of [-0.7, 0.7]) { const c = new THREE.Mesh(cGeo, MAT.cable); c.position.set(x + s, alto + 0.45 + (8.2 - alto - 0.45) / 2, z); g.add(c); }
}

/* Coloca un objeto en coordenadas LOCALES del rack (frente = +Z). */
function aRack(rack, obj, lx, ly, lz) {
    obj.position.copy(enRack(rack, lx, ly, lz));
    obj.rotation.y = rack.rot;
    mundo.add(obj);
    return obj;
}
function enRack(rack, lx, ly, lz) {
    return new THREE.Vector3(lx, ly, lz).applyAxisAngle(new THREE.Vector3(0, 1, 0), rack.rot).add(rack.pos);
}

/* La cabecera del rack es la etiqueta UBICACION del Centro de etiquetas, en
   grande: se lee desde el inicio del pasillo. */
function letreroRack(rack) {
    const n = rack.items.length;
    const c = canvas(760, Math.round(760 / RATIO_ETQ)), g = c.getContext('2d');
    dibujarEtiqueta(g, 0, 0, c.width, c.height, {
        token: 'UBI-' + rack.id, codigo: rack.codigo, titulo: rack.nombre || 'Ubicación',
        subtitulo: rack.bodega.codigo + ' · ' + rack.bodega.nombre,
        detalle: n ? n + ' repuesto' + (n === 1 ? '' : 's') : 'Vacío', pie: rack.bodega.planta || 'Ubicación'
    });
    const t = tex(c); S.basura.push(t);
    const w = 1.05, h = w / RATIO_ETQ;
    aRack(rack, planoEtiqueta(t, w, h), 0, RACK.alto + 0.06 + h / 2, RACK.prof / 2 - 0.05);
    const sGeo = new THREE.BoxGeometry(w + 0.05, h + 0.05, 0.03); S.basura.push(sGeo);
    aRack(rack, new THREE.Mesh(sGeo, MAT.placa), 0, RACK.alto + 0.06 + h / 2, RACK.prof / 2 - 0.068);
}

/* Las etiquetas PEGADAS EN LOS FIERROS, como en la bodega de verdad:
     - en cada viga delantera, una por casillero: la etiqueta UBICACION_REPUESTO
       (ubicacion + lo que guarda) o, si esta libre, la UBICACION con la
       posicion nivel-posicion;
     - en el puntal delantero, la del rack en vertical.
   Las de las vigas tienen dos resoluciones: de lejos baja, y alta para los
   racks que estan a pocos metros (QR legible). */
function etiquetasFierro(rack) {
    for (let n = 1; n <= RACK.niveles.length; n++) {
        const t = tex(texVigaCanvas(rack, n, false));
        const m = planoEtiqueta(t, RACK.ancho, RACK.viga);
        S.basura.push(t);
        aRack(rack, m, 0, RACK.niveles[n - 1] - RACK.viga / 2, Z_VIGA_FRENTE);
        rack.vigas.push(m);
    }
    // puntal: codigo en vertical con su QR al pie
    const c = canvas(96, 600), g = c.getContext('2d');
    g.fillStyle = '#FFFFFF'; rrect(g, 0, 0, 96, 600, 8); g.fill();
    dibujarQr(g, 'UBI-' + rack.id, 6, 600 - 90, 84);
    g.save(); g.translate(48, 255); g.rotate(-Math.PI / 2);
    g.fillStyle = '#000000'; g.font = `800 44px ${FUENTE}`; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(recortar(g, rack.codigo, 480), 0, -8);
    g.fillStyle = '#555555'; g.font = `500 22px ${FUENTE}`;
    g.fillText(recortar(g, rack.bodega.codigo, 480), 0, 26);
    g.restore();
    const t = tex(c); S.basura.push(t);
    aRack(rack, planoEtiqueta(t, 0.072, 0.45), -RACK.ancho / 2, 1.3, RACK.prof / 2 - 0.045 + 0.037);
}
function texVigaCanvas(rack, n, hd) {
    const ppm = hd ? 1400 : 360;
    const W = RACK.ancho, c = canvas(Math.round(W * ppm), Math.round(RACK.viga * ppm)), g = c.getContext('2d');
    const cols = rack.cols, anchoSlot = (W - 0.14) / cols;
    const alto = 0.092 * ppm, ancho = Math.min(anchoSlot * 0.9, 0.092 * RATIO_ETQ * 1.08) * ppm;
    for (let k = 0; k < cols; k++) {
        const caja = rack.cajas.find((x) => x.userData.nivel === n && x.userData.posicion === k + 1 && !x.userData.fila)
                  || rack.cajas.find((x) => x.userData.nivel === n && x.userData.posicion === k + 1);
        const lx = -W / 2 + 0.07 + (k + 0.5) * anchoSlot;
        const x = (lx + W / 2) * ppm - ancho / 2, y = (c.height - alto) / 2;
        dibujarEtiqueta(g, x, y, ancho, alto, etqUbicacion(rack, caja, n, k + 1), { lejos: !hd, borde: true });
    }
    return c;
}
function vigaHD(rack, si) {
    if (si === S.vigasHD.has(rack)) return;
    rack.vigas.forEach((m, i) => {
        const t = tex(texVigaCanvas(rack, i + 1, si));
        if (m.material.map) m.material.map.dispose();
        m.material.map = t; m.material.needsUpdate = true;
        S.basura.push(t);
    });
    si ? S.vigasHD.add(rack) : S.vigasHD.delete(rack);
}

const GEO_CAJA = new Map();
function geoCaja(w, h, d, carton) {
    const k = [w, h, d].map((v) => v.toFixed(3)).join('|') + carton;
    if (!GEO_CAJA.has(k)) GEO_CAJA.set(k, new RoundedBoxGeometry(w, h, d, 2, carton ? 0.012 : 0.025));
    return GEO_CAJA.get(k);
}
const GEO_ETQ = new Map();
function geoEtiqueta(w, h) {
    const k = w.toFixed(3) + '|' + h.toFixed(3);
    if (!GEO_ETQ.has(k)) GEO_ETQ.set(k, new THREE.PlaneGeometry(w, h));
    return GEO_ETQ.get(k);
}

/* Reparte el contenido en los cuatro niveles: lo pesado abajo, el resto por
   tipo para que un nivel se lea de un color. Lo que tiene posicion fija
   (planograma, BD/329) va en su casillero; el resto llena los libres. Si el
   repuesto tiene medidas, la caja es de su tamano; con peso, se suma la carga
   de cada nivel contra la admisible del rack. */
function poblarRack(rack, info) {
    const items = rack.items.slice().sort((a, c) =>
        (c.pesado - a.pesado) || String(a.tc).localeCompare(String(c.tc)) || String(a.c).localeCompare(String(c.c)));
    const niveles = RACK.niveles.length;
    const fijas = S.posiciones.get(rack.id) || new Map();
    const porNivel = Math.max(1, Math.ceil(items.length / niveles));
    let filas = porNivel > 6 ? 2 : 1;
    let cols = Math.max(3, Math.ceil(porNivel / filas));
    for (const it of items) { const a = fijas.get(it.id); if (a) { cols = Math.max(cols, a.p); if (a.f) filas = 2; } }
    rack.cols = cols; rack.filas = filas; rack.sobrecarga = [];
    if (!items.length) return;
    const anchoSlot = (RACK.ancho - 0.14) / cols;
    const altoLibre = RACK.niveles[1] - RACK.niveles[0] - RACK.viga - 0.08;

    // casilleros: primero los fijos, despues los libres repartidos parejo por nivel
    const ocupado = new Set(), lugar = new Map(), porNivelCuenta = new Array(niveles).fill(0);
    const clave = (n, c, f) => n + '|' + c + '|' + f;
    for (const it of items) {
        const a = fijas.get(it.id);
        if (!a || a.n > niveles) continue;
        const k = clave(a.n - 1, a.p - 1, a.f || 0);
        if (ocupado.has(k)) continue;
        ocupado.add(k); lugar.set(it, { nivel: a.n - 1, col: a.p - 1, fila: a.f || 0, fija: true }); porNivelCuenta[a.n - 1]++;
    }
    for (const it of items) {
        if (lugar.has(it)) continue;
        let hecho = false;
        for (let pasada = 0; pasada < 2 && !hecho; pasada++) {
            for (let n = 0; n < niveles && !hecho; n++) {
                if (pasada === 0 && porNivelCuenta[n] >= porNivel) continue;
                for (let f = 0; f < filas && !hecho; f++)
                    for (let col = 0; col < cols && !hecho; col++) {
                        const k = clave(n, col, f);
                        if (ocupado.has(k)) continue;
                        ocupado.add(k); lugar.set(it, { nivel: n, col, fila: f, fija: false }); porNivelCuenta[n]++; hecho = true;
                    }
            }
        }
        if (!hecho) { lugar.set(it, { nivel: niveles - 1, col: cols - 1, fila: 0, fija: false }); }
    }

    const kg = new Array(niveles).fill(0);
    for (const it of items) {
        const L = lugar.get(it), nivel = L.nivel, col = L.col, fila = L.fila;
        const fondoMax = filas === 1 ? RACK.prof - 0.16 : (RACK.prof - 0.18) / 2 - 0.03;
        let w = Math.min(anchoSlot - 0.05, it.pesado ? 0.9 : 0.62);
        let d = filas === 1 ? Math.min(fondoMax, it.pesado ? 0.8 : 0.58) : fondoMax;
        let h = it.pesado ? Math.min(altoLibre, 0.38 + Math.min(w, 0.9) * 0.25) : Math.min(altoLibre, 0.24 + Math.min(Math.log10(1 + it.q) * 0.05, 0.12));
        // con medidas, la caja es del tamano del repuesto (sin salirse del casillero)
        if (it.largo) w = Math.max(0.08, Math.min(anchoSlot - 0.05, it.largo / 100));
        if (it.ancho) d = Math.max(0.08, Math.min(fondoMax, it.ancho / 100));
        if (it.alto) h = Math.max(0.05, Math.min(altoLibre, it.alto / 100));
        if (it.peso) kg[nivel] += it.peso * it.q;
        const lx = -RACK.ancho / 2 + 0.07 + (col + 0.5) * anchoSlot;
        const ly = RACK.niveles[nivel] + 0.006 + h / 2;
        const frente = RACK.prof / 2 - 0.08 - d / 2;
        const lz = filas === 1 || fila === 0 ? frente : -RACK.prof / 2 + 0.08 + d / 2;

        const caja = crearCaja(it, w, h, d);
        aRack(rack, caja, lx, ly, lz);
        Object.assign(caja.userData, { base: caja.position.clone(), normal: rack.normal.clone(), rack, nivel: nivel + 1, posicion: col + 1, fila, fija: L.fija });
        rack.cajas.push(caja); info.cajas.push(caja);
    }
    const limite = rack.carga || 1000;
    kg.forEach((v, n) => { if (v > limite) rack.sobrecarga.push({ nivel: n + 1, kg: v, limite }); });
    rack.kg = kg;
}

function poblarRecepcion(g, info, items, W, zIni) {
    const ancho = Math.min(W - 2 * MARGEN, 12);
    const marco = placaTexto([{ texto: 'RECEPCIÓN · SIN UBICACIÓN', color: '#F2C230', fuente: `900 46px ${FUENTE}`, y: 40 }], 1024, 80, 'rgba(0,0,0,0)', { radio: 1 });
    const mm = planoTexto(marco, ancho * 0.7, ancho * 0.7 / 12.8, true);
    mm.rotation.x = -Math.PI / 2; mm.rotation.z = Math.PI; mm.position.set(W / 2, 0.014, zIni - 0.55); g.add(mm);
    lineaPiso(g, W / 2, zIni - 0.2, ancho, 0.1);
    lineaPiso(g, W / 2, zIni - ZONA_RECEPCION + 0.4, ancho, 0.1);

    const rack = {
        id: 0, codigo: 'RECEPCIÓN', nombre: 'Stock sin ubicación asignada', pasillo: '', num: 0, bodega: info.bodega, info,
        pos: new THREE.Vector3(info.ox + W / 2, 0, MARGEN / 2 + ZONA_RECEPCION / 2), rot: 0,
        normal: new THREE.Vector3(0, 0, -1), items, cajas: [], recepcion: true, indice: -1, vigas: []
    };
    const porPallet = 6, pallets = Math.ceil(items.length / porPallet), sep = 1.5;
    const porFila = Math.ceil(pallets / Math.ceil(pallets / Math.max(1, Math.floor(ancho / sep))));
    const palletGeo = new THREE.BoxGeometry(1.2, 0.14, 1.0); S.basura.push(palletGeo);
    items.forEach((it, i) => {
        const p = Math.floor(i / porPallet), k = i % porPallet;
        const px = info.ox + W / 2 + ((p % porFila) - (porFila - 1) / 2) * sep, pz = zIni - 1.6 - Math.floor(p / porFila) * 1.5;
        if (k === 0) { const pal = new THREE.Mesh(palletGeo, MAT.pallet); pal.position.set(px, 0.07, pz); pal.castShadow = true; pal.receiveShadow = true; mundo.add(pal); }
        const h = it.pesado ? 0.42 : 0.26;
        const caja = crearCaja(it, 0.36, h, 0.46);
        caja.position.set(px + ((k % 3) - 1) * 0.39, 0.14 + h / 2, pz + (Math.floor(k / 3) ? -0.24 : 0.24));
        caja.rotation.y = Math.PI;
        mundo.add(caja);
        Object.assign(caja.userData, { base: caja.position.clone(), normal: new THREE.Vector3(0, 0, -1), rack, nivel: 0, posicion: k + 1, fila: 0 });
        rack.cajas.push(caja); info.cajas.push(caja);
    });
    info.recepcion = rack;
}

function crearCaja(it, w, h, d) {
    const carton = !!it.pesado, fam = matFamilia(it.color);
    const mesh = new THREE.Mesh(geoCaja(w, h, d, carton), carton ? MAT.carton : fam.normal);
    mesh.castShadow = true; mesh.receiveShadow = true;
    mesh.userData = { item: it, w, h, d, carton, matNormal: carton ? MAT.carton : fam.normal, matTenue: carton ? MAT_CARTON_TENUE : fam.tenue };
    let ew = w * (carton ? 0.66 : 0.88), eh = ew / RATIO_ETQ;
    if (eh > h * 0.7) { eh = h * 0.7; ew = eh * RATIO_ETQ; }
    const etq = new THREE.Mesh(geoEtiqueta(ew, eh), etiquetaLejos(it));
    etq.position.set(0, carton ? 0 : -h * 0.06, d / 2 + 0.003);
    mesh.add(etq);
    mesh.userData.etiqueta = etq; mesh.userData.etqLejos = etq.material;
    if (!carton) {
        const lm = new THREE.MeshBasicMaterial({ color: new THREE.Color(it.color).lerp(new THREE.Color('#FFFFFF'), 0.35) });
        const labio = new THREE.Mesh(geoEtiqueta(w * 0.98, h * 0.12), lm);
        labio.position.set(0, h / 2 - h * 0.08, d / 2 + 0.002);
        mesh.add(labio); S.basura.push(lm);
    }
    S.cajas.push(mesh);
    return mesh;
}

// ================================================================ modo edicion
/* Racks "fantasma" al final de cada pasillo y un pasillo nuevo: se crea una
   ubicacion haciendo clic donde va, no llenando un codigo de memoria. */
function limpiarEdicion() {
    for (const r of S.basuraEdicion) if (r && r.dispose) r.dispose();
    S.basuraEdicion = [];
    while (capaEdicion.children.length) capaEdicion.remove(capaEdicion.children[0]);
    S.fantasmas = [];
}

function prefijoBodega(info) {
    const r = info.racks.find((x) => String(x.codigo).split('-').length >= 3);
    if (r) return r.codigo.split('-').slice(0, -2).join('-');
    return String(info.bodega.codigo || 'BOD').replace(/\s+/g, '');
}

function armarEdicion() {
    limpiarEdicion();
    if (!S.edicion || !S.permisos.bodegas) return;
    const geo = new THREE.BoxGeometry(RACK.ancho, RACK.alto, RACK.prof);
    const bordes = new THREE.EdgesGeometry(geo);
    S.basuraEdicion.push(geo, bordes);
    for (const info of S.porBodega.values()) {
        const pref = prefijoBodega(info);
        const fantasma = (x, z, rot, pasillo, num, nuevoPasillo) => {
            const m = new THREE.Mesh(geo, MAT.fantasma);
            m.position.set(x, RACK.alto / 2, z); m.rotation.y = rot;
            const l = new THREE.LineSegments(bordes, MAT.fantasmaLinea); l.computeLineDistances(); m.add(l);
            const t = placaTexto([
                { texto: '+', color: '#16C6C9', fuente: `300 180px ${FUENTE}`, y: 120 },
                { texto: nuevoPasillo ? 'NUEVO PASILLO ' + pasillo : 'NUEVO RACK', color: '#FFFFFF', fuente: `800 40px ${FUENTE}`, y: 236 }
            ], 512, 280, 'rgba(11,17,32,.75)', { radio: 28, borde: '#16C6C9' });
            S.basuraEdicion.push(t);
            const p = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 0.77), new THREE.MeshBasicMaterial({ map: t, transparent: true, toneMapped: false, depthWrite: false }));
            S.basuraEdicion.push(p.geometry, p.material);
            p.position.set(0, 0.2, RACK.prof / 2 + 0.02);
            m.add(p);
            m.userData.fantasma = { info, pasillo, codigo: pref + '-' + pasillo + '-R' + pad2(num), nombre: 'Pasillo ' + pasillo + ' · Rack ' + pad2(num), nuevoPasillo };
            capaEdicion.add(m); S.fantasmas.push(m);
        };
        const letras = info.pasillos.filter((p) => p.nom !== '·');
        for (const pa of letras) {
            const i = pa.racks.length, izq = i % 2 === 0, slot = Math.floor(i / 2);
            const n = Math.max(0, ...pa.racks.map((r) => r.num < 1000 ? r.num : 0)) + 1;
            fantasma(pa.x + (izq ? -1 : 1) * (PASILLO / 2 + RACK.prof / 2), info.zIni + slot * (RACK.ancho + ENTRE_RACKS) + RACK.ancho / 2,
                     izq ? Math.PI / 2 : -Math.PI / 2, pa.nom, n, false);
        }
        const ultima = letras.length ? letras[letras.length - 1].nom : '';
        const sig = ultima ? String.fromCharCode(ultima.charCodeAt(0) + 1) : 'A';
        const xNuevo = letras.length ? letras[letras.length - 1].x + BLOQUE + ESPALDA : info.ox + MARGEN + BLOQUE / 2;
        fantasma(xNuevo - (PASILLO / 2 + RACK.prof / 2), info.zIni + RACK.ancho / 2, Math.PI / 2, sig, 1, true);
    }
}

// ================================================================ nivel de detalle
let ultimoLod = 0;
const _v = new THREE.Vector3(), _frustum = new THREE.Frustum(), _pm = new THREE.Matrix4();
function actualizarEtiquetas(ahora) {
    if (ahora - ultimoLod < 220) return;
    ultimoLod = ahora;
    _pm.multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse);
    _frustum.setFromProjectionMatrix(_pm);

    // cajas: etiqueta del repuesto, con su QR, solo de cerca
    const cerca = [];
    for (const c of S.cajas) {
        if (c.userData.atenuada) continue;
        const dist = c.getWorldPosition(_v).distanceTo(camera.position);
        if (dist < DIST_DETALLE && _frustum.containsPoint(_v)) cerca.push([dist, c]);
    }
    cerca.sort((a, b) => a[0] - b[0]);
    const quiero = new Set(cerca.slice(0, TOPE_ETIQUETAS).map((x) => x[1]));
    if (S.sel && S.sel.isMesh) quiero.add(S.sel);   // la seleccion puede ser un rack
    for (const [mesh, t] of S.etiquetasVivas) {
        if (!quiero.has(mesh)) {
            mesh.userData.etiqueta.material.dispose(); t.dispose();
            mesh.userData.etiqueta.material = mesh.userData.etqLejos;
            S.etiquetasVivas.delete(mesh);
        }
    }
    for (const mesh of quiero) {
        if (S.etiquetasVivas.has(mesh)) continue;
        const c = canvas(512, Math.round(512 / RATIO_ETQ));
        dibujarEtiquetaCaja(mesh.userData.item, c);
        const t = tex(c);
        mesh.userData.etiqueta.material = new THREE.MeshBasicMaterial({ map: t, toneMapped: false });
        S.etiquetasVivas.set(mesh, t);
    }

    // vigas: alta resolucion para los racks mas cercanos
    const racks = S.racks.map((r) => [r.pos.distanceTo(camera.position), r]).filter((x) => x[0] < DIST_VIGA_HD)
        .sort((a, b) => a[0] - b[0]).slice(0, TOPE_VIGAS_HD).map((x) => x[1]);
    const hd = new Set(racks);
    for (const r of [...S.vigasHD]) if (!hd.has(r)) vigaHD(r, false);
    for (const r of racks) vigaHD(r, true);
}

// =================================================================== filtros
function aplicarFiltros() {
    const hay = S.filtro.size > 0;
    for (const c of S.cajas) {
        const it = c.userData.item, pasa = !hay || S.filtro.has(it.tid);
        let mat = pasa ? c.userData.matNormal : c.userData.matTenue;
        if (S.modoAlertas && pasa) { const e = estadoDe(it); mat = e === 'bajo' ? MAT_ALERTA.bajo : e === 'sobre' ? MAT_ALERTA.sobre : c.userData.matTenue; }
        else if (pasa && S.modo && S.modo !== 'normal') mat = matModo(c) || c.userData.matTenue;
        c.material = mat;
        const tenue = mat === c.userData.matTenue;
        c.userData.atenuada = tenue;
        c.castShadow = !tenue;
        c.children.forEach((h) => { if (h !== contorno) h.visible = !tenue; });
    }
    $('bm3dLeyenda').classList.toggle('hay-filtro', hay);
    const l = $('bm3dLimpiar'); if (l) l.hidden = !hay;
    document.querySelectorAll('.bm3d-chip').forEach((ch) => ch.classList.toggle('is-sel', S.filtro.has(+ch.dataset.tipo)));
    document.querySelectorAll('.bm3d-fam-nom').forEach((f) => {
        const ids = ((S.familias && S.familias.get(f.dataset.fam)) || []).map((t) => t.id);
        f.classList.toggle('is-sel', ids.length > 0 && ids.every((i) => S.filtro.has(i)));
    });
}

function armarLeyenda() {
    const tipos = new Map();
    for (const s of S.datos.saldos || []) {
        if (!tipos.has(s.tid)) tipos.set(s.tid, { id: s.tid, tc: s.tc, tn: s.tn, fam: s.fam, color: s.color, n: 0 });
        tipos.get(s.tid).n++;
    }
    const porFam = new Map();
    for (const t of tipos.values()) { if (!porFam.has(t.fam)) porFam.set(t.fam, []); porFam.get(t.fam).push(t); }
    S.familias = porFam;
    const el = $('bm3dLeyenda');
    if (!tipos.size) { el.hidden = true; return; }
    el.hidden = false;
    const abierta = el.classList.contains('is-abierta');
    let html = '<div class="bm3d-ley-cab"><b>Tipos de repuesto · ' + tipos.size + '</b><span class="bm3d-ley-acc"><button type="button" id="bm3dLimpiar" hidden>Ver todos</button>' +
               '<button type="button" id="bm3dPlegar">' + (abierta ? 'Ocultar tipos' : 'Ver tipos') + '</button></span></div>';
    const fams = [...porFam.keys()].sort((a, b) => (FAMILIAS[a] ? 0 : 1) - (FAMILIAS[b] ? 0 : 1) || a.localeCompare(b));
    for (const f of fams) {
        const inf = infoFamilia(f), lista = porFam.get(f).sort((a, b) => String(a.tn).localeCompare(String(b.tn)));
        html += '<div class="bm3d-fam"><div class="bm3d-fam-nom" data-fam="' + esc(f) + '"><i class="bm3d-punto" style="background:' + inf.color + '"></i>' + esc(inf.nombre) +
                ' <small>· ' + lista.reduce((s, t) => s + t.n, 0) + '</small></div><div class="bm3d-chips">' +
                lista.map((t) => '<button type="button" class="bm3d-chip" data-tipo="' + t.id + '" title="' + esc(t.tc) + '"><i class="bm3d-punto" style="background:' + t.color + '"></i>' + esc(t.tn) + ' <small>' + t.n + '</small></button>').join('') +
                '</div></div>';
    }
    el.innerHTML = html;
    el.querySelectorAll('.bm3d-chip').forEach((b) => b.onclick = () => { const id = +b.dataset.tipo; S.filtro.has(id) ? S.filtro.delete(id) : S.filtro.add(id); aplicarFiltros(); });
    el.querySelectorAll('.bm3d-fam-nom').forEach((b) => b.onclick = () => {
        const ids = (porFam.get(b.dataset.fam) || []).map((t) => t.id), todos = ids.every((i) => S.filtro.has(i));
        ids.forEach((i) => (todos ? S.filtro.delete(i) : S.filtro.add(i))); aplicarFiltros();
    });
    $('bm3dLimpiar').onclick = () => { S.filtro.clear(); aplicarFiltros(); };
    $('bm3dPlegar').onclick = () => { const a = el.classList.toggle('is-abierta'); $('bm3dPlegar').textContent = a ? 'Ocultar tipos' : 'Ver tipos'; };
    aplicarFiltros();
}

// =================================================================== camara
function volar(pos, objetivo, dur) {
    S.vuelo = { t0: performance.now(), dur: dur || 1100, p0: camera.position.clone(), o0: controls.target.clone(), p1: pos.clone(), o1: objetivo.clone() };
}

/* Encuadre: la bodega COMPLETA entra en pantalla, segun su tamano real y el
   del visor. Se calcula con el campo de vision de la camara, no con numeros
   fijos: una bodega de 8 racks y una de 80 quedan las dos enteras. */
function encuadre(info, planta) {
    const W = info.ancho, L = info.largo, c = info.centro.clone();
    const vfov = THREE.MathUtils.degToRad(FOV_MAPA);
    const hfov = 2 * Math.atan(Math.tan(vfov / 2) * camera.aspect);
    if (planta) {
        const d = Math.max((L / 2) / Math.tan(vfov / 2) * 1.22, (W / 2) / Math.tan(hfov / 2) * 1.1) + 3;
        return { pos: new THREE.Vector3(c.x, d, c.z + 0.01), target: new THREE.Vector3(c.x, 0, c.z - L * 0.03) };
    }
    const r = 0.5 * Math.hypot(W, L, 7);
    const d = r / Math.sin(Math.min(vfov, hfov) / 2) * 0.95;
    const el = 0.66, az = -0.5;
    const pos = new THREE.Vector3(c.x + Math.sin(az) * Math.cos(el) * d, Math.sin(el) * d, c.z - Math.cos(az) * Math.cos(el) * d);
    return { pos, target: new THREE.Vector3(c.x, 0.5, c.z) };
}
function vistaGeneral(id, dur) {
    const info = S.porBodega.get(id || S.bodegaSel);
    if (!info) return;
    const e = encuadre(info, false);
    volar(e.pos, e.target, dur);
    marcarVista('general');
}
function vistaPlanta() {
    const info = S.porBodega.get(S.bodegaSel);
    if (!info) return;
    const e = encuadre(info, true);
    volar(e.pos, e.target, 1200);
    marcarVista('planta');
}
function marcarVista(v) { document.querySelectorAll('[data-vista]').forEach((b) => b.classList.toggle('is-activo', b.dataset.vista === v)); }

function enfocarCaja(c) {
    const p = c.userData.base.clone(), u = c.userData, lado = Math.max(u.w, u.h);
    const pos = p.clone().addScaledVector(u.normal, 1.5 + lado * 2.6); pos.y += 0.3 + lado * 0.5;
    volar(pos, p, 1000); marcarVista('');
}
function enfocarRack(r) {
    const c = r.pos.clone(); c.y = 1.5;
    const pos = c.clone().addScaledVector(r.normal, r.recepcion ? 6 : 4.4); pos.y = r.recepcion ? 4.5 : 2.3;
    volar(pos, c, 1100); marcarVista('');
}

// =========================================================== seleccion y hover
const ray = new THREE.Raycaster(), puntero = new THREE.Vector2();
let contorno = null;
function marcarContorno(obj, esRack) {
    if (contorno) { if (contorno.parent) contorno.parent.remove(contorno); contorno.geometry.dispose(); contorno = null; }
    if (!obj) return;
    if (esRack) {
        contorno = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(RACK.ancho + 0.12, RACK.alto + 0.08, RACK.prof + 0.14)), MAT.contorno);
        contorno.position.copy(obj.pos); contorno.position.y = RACK.alto / 2; contorno.rotation.y = obj.rot;
        mundo.add(contorno);
    } else {
        const u = obj.userData;
        contorno = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(u.w + 0.03, u.h + 0.03, u.d + 0.03)), MAT.contorno);
        contorno.renderOrder = 10;
        obj.add(contorno);
    }
}

function intersectar(ev, soloStock) {
    const r = renderer.domElement.getBoundingClientRect();
    puntero.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
    puntero.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
    ray.setFromCamera(puntero, camera);
    if (S.edicion && S.fantasmas.length && !S.pick && !soloStock) {
        const hf = ray.intersectObjects(S.fantasmas, false)[0];
        if (hf) return { fantasma: hf.object };
    }
    const hc = S.pick ? null : ray.intersectObjects(S.cajas.filter((c) => !c.userData.atenuada), false)[0];
    const hr = S.instRack.length ? ray.intersectObjects(S.instRack, false)[0] : null;
    if (hc && (!hr || hc.distance <= hr.distance + 0.05)) return { caja: hc.object };
    if (hr) return { rack: S.racks[hr.instanceId] };
    if (S.pick || soloStock) return null;
    const hp = ray.intersectObjects(S.pisos, false)[0];
    if (hp) return { piso: hp.object.userData.bodegaId };
    return null;
}

const tip = $('bm3dTip');
function mostrarTip(ev, html) {
    const r = root.getBoundingClientRect();
    tip.innerHTML = html; tip.hidden = false;
    let x = ev.clientX - r.left, y = ev.clientY - r.top;
    if (x > r.width - 300) x -= 310;
    tip.style.left = x + 'px'; tip.style.top = y + 'px';
}
function miniatura(url, color, tamano) {
    const st = tamano ? ' style="width:' + tamano + 'px;height:' + tamano + 'px"' : '';
    return url ? '<span class="bm3d-mini"' + st + '><img src="' + esc(url) + '" alt="" loading="lazy" /></span>'
               : '<span class="bm3d-mini"' + st + '><i class="mdi mdi-package-variant" style="color:' + (color || '#A8B1C2') + '"></i></span>';
}

let ultimoMov = 0, fantasmaHover = null, arrastre = null;
renderer.domElement.addEventListener('pointermove', (ev) => {
    if (S.moverRack) { moverRackPuntero(ev); return; }
    if (S.dibujo) { dibujoPuntero(ev, 'mover'); return; }
    if (S.tour) { moverRecorrido(ev); return; }
    if (performance.now() - ultimoMov < 30) return;
    ultimoMov = performance.now();
    if (S.vuelo) return;
    const h = intersectar(ev);
    if (fantasmaHover && (!h || h.fantasma !== fantasmaHover)) { fantasmaHover.material = MAT.fantasma; fantasmaHover = null; }
    if (h && h.fantasma) {
        fantasmaHover = h.fantasma; h.fantasma.material = MAT.fantasmaHover;
        mostrarTip(ev, '<div><b>Crear ' + esc(h.fantasma.userData.fantasma.codigo) + '</b><span>' + (h.fantasma.userData.fantasma.nuevoPasillo ? 'Abre un pasillo nuevo' : 'Nuevo rack en este pasillo') + '</span></div>');
        renderer.domElement.style.cursor = 'pointer';
        return;
    }
    const obj = h ? (h.caja || h.rack) : null;
    if (obj !== S.hover) {
        if (S.hover && S.hover !== S.sel && S.hover.isMesh) S.hover.scale.set(1, 1, 1);
        S.hover = obj;
        if (!S.sel || S.pick) marcarContorno(obj, h && !!h.rack);
        if (h && h.caja && h.caja !== S.sel) h.caja.scale.set(1.04, 1.04, 1.04);
    }
    renderer.domElement.style.cursor = obj ? (S.pick ? 'crosshair' : 'pointer') : (S.pick ? 'crosshair' : 'grab');
    if (h && h.caja) {
        const it = h.caja.userData.item;
        mostrarTip(ev, (it.foto ? '<img src="' + esc(it.foto) + '" alt="" />' : '') + '<div><b>' + esc(it.c) + '</b>' + esc(it.n) + '<br><span>' + num(it.q) + ' ' + esc(it.un) + ' · ' + esc(ubicTexto(h.caja, true)) + '</span></div>');
    } else if (h && h.rack) {
        mostrarTip(ev, '<div><b>' + esc(h.rack.codigo) + '</b><span>' + (S.pick ? 'Clic para elegir este rack' : h.rack.items.length + ' repuesto(s) · clic para ver el rack') + '</span></div>');
    } else tip.hidden = true;
});
renderer.domElement.addEventListener('pointerleave', () => { tip.hidden = true; });

let abajo = null;
renderer.domElement.addEventListener('pointerdown', (ev) => {
    abajo = { x: ev.clientX, y: ev.clientY };
    if (S.dibujo) { dibujoPuntero(ev, 'inicio'); return; }
    if (S.tour) { arrastre = { x: ev.clientX, y: ev.clientY }; try { renderer.domElement.setPointerCapture(ev.pointerId); } catch (e) { /* sin captura */ } }
    $('bm3dAyuda').classList.add('is-oculta');
});
renderer.domElement.addEventListener('pointerup', (ev) => {
    arrastre = null;
    if (S.dibujo) { abajo = null; dibujoPuntero(ev, 'fin'); return; }
    if (!abajo || Math.hypot(ev.clientX - abajo.x, ev.clientY - abajo.y) > 6 || ev.button !== 0) { abajo = null; return; }
    abajo = null;
    if (S.moverRack) { guardarMoverRack(); return; }
    if (S.tour) { clicRecorrido(ev); return; }
    const h = intersectar(ev);
    if (S.pick) {
        if (h && h.rack && !h.rack.recepcion) { const cb = S.pick.cb; terminarPick(); cb(h.rack); }
        return;
    }
    if (h && h.fantasma) formRack(h.fantasma.userData.fantasma.info, h.fantasma.userData.fantasma);
    else if (h && h.caja) seleccionarCaja(h.caja, true);
    else if (h && h.rack) seleccionarRack(h.rack, true);
    else if (h && h.piso) { if (h.piso !== S.bodegaSel) elegirBodega(h.piso, true); panelBodega(S.porBodega.get(h.piso)); }
});

function soltarSeleccion() {
    if (S.sel && S.sel.isMesh) { S.sel.userData.sacar = 0; S.sel.scale.set(1, 1, 1); }
    S.sel = null;
}
function seleccionarCaja(c, volarA) {
    soltarSeleccion();
    if (c.userData.rack && c.userData.rack.bodega.id !== S.bodegaSel) elegirBodega(c.userData.rack.bodega.id, true);
    S.sel = c;
    c.userData.sacar = c.userData.fila === 1 ? 0.5 : 0.24;   // se asoma del rack, como al tomarla
    marcarContorno(c, false);
    if (volarA) enfocarCaja(c);
    panelItem(c);
}
function seleccionarRack(r, volarA) {
    soltarSeleccion();
    if (r.bodega.id !== S.bodegaSel) elegirBodega(r.bodega.id, true);
    marcarContorno(r.recepcion ? null : r, true);
    S.sel = r;
    if (volarA) enfocarRack(r);
    panelRack(r);
}

/* Elegir un rack EN EL MAPA (cambio de ubicacion): se pide el clic y se
   devuelve el rack a quien lo pidio. */
function iniciarPick(texto, cb) {
    S.pick = { cb };
    root.classList.add('es-pick');
    const p = $('bm3dPick');
    p.innerHTML = '<i class="mdi mdi-target"></i>' + esc(texto) + '<button type="button">Cancelar</button>';
    p.hidden = false;
    p.querySelector('button').onclick = terminarPick;
    marcarContorno(null);
}
function terminarPick() {
    S.pick = null; root.classList.remove('es-pick'); $('bm3dPick').hidden = true; marcarContorno(null);
}

// ===================================================================== panel
const panel = $('bm3dPanel');
let volverA = null;
function abrirPanel(cab, cuerpo, pie, volver) {
    volverA = volver || null;
    panel.innerHTML =
        '<div class="bm3d-pan-cab">' + cab + '<div class="bm3d-pan-btns">' +
        (volverA ? '<button type="button" class="bm3d-volver" aria-label="Volver"><i class="mdi mdi-arrow-left"></i></button>' : '') +
        '<button type="button" class="bm3d-cerrar" aria-label="Cerrar"><i class="mdi mdi-close"></i></button></div></div>' +
        '<div class="bm3d-pan-cuerpo">' + cuerpo + '</div>' + (pie ? '<div class="bm3d-pan-pie">' + pie + '</div>' : '');
    panel.classList.add('is-abierto');
    panel.querySelector('.bm3d-cerrar').onclick = cerrarPanel;
    const v = panel.querySelector('.bm3d-volver'); if (v) v.onclick = () => volverA();
    panel.querySelector('.bm3d-pan-cuerpo').scrollTop = 0;
}
function cab(ubic, titulo, codigo, icono) {
    return '<div class="bm3d-pan-ubic"><i class="mdi ' + (icono || 'mdi-map-marker-outline') + '"></i>' + esc(ubic) + '</div>' +
           '<h3>' + esc(titulo) + '</h3>' + (codigo ? '<div class="bm3d-pan-cod">' + esc(codigo) + '</div>' : '');
}
function cerrarPanel() { panel.classList.remove('is-abierto'); soltarSeleccion(); marcarContorno(null); terminarPick(); }

function ubicTexto(c, corto) {
    const r = c.userData.rack;
    if (r.recepcion) return corto ? 'Recepción' : r.bodega.codigo + ' · Recepción (sin ubicación)';
    const pos = c.userData.nivel + '-' + pad2(c.userData.posicion);
    return corto ? r.codigo + ' · ' + pos : r.bodega.codigo + ' · ' + r.codigo + ' · posición ' + pos;
}

/* Abre la hoja de impresion en una ventana aparte, como Bodega.aspx: el mapa
   queda detras. La ventana se abre en el mismo clic (si no, el navegador la
   bloquea) y la direccion llega despues. */
async function imprimirEtiquetas(origen, ids, bodega) {
    const w = 980, h = 760;
    const x = window.screenX + Math.max(0, (window.outerWidth - w) / 2), y = window.screenY + Math.max(0, (window.outerHeight - h) / 2);
    const vent = window.open('', 'sigmaEtiquetas', 'width=' + w + ',height=' + h + ',left=' + Math.round(x) + ',top=' + Math.round(y) + ',resizable=yes,scrollbars=yes');
    if (!vent) { aviso('El navegador bloqueó la ventana de impresión: permite las ventanas emergentes para este sitio.', true); return; }
    try {
        const r = await ws('UrlEtiquetas', { origen, ids: String(ids || ''), bodega: bodega || 0 });
        vent.location.href = r.url; vent.focus();
    } catch (e) { vent.close(); aviso(e.message, true); }
}

// -------------------------------------------------------------- panel: caja
function panelItem(c) {
    const it = c.userData.item, est = estadoDe(it), fam = infoFamilia(it.fam);
    const tope = it.max || (it.min ? it.min * 2 : Math.max(it.q, 1));
    const pct = Math.max(3, Math.min(100, (it.q / tope) * 100));
    const colorBarra = { bajo: '#C7352B', sobre: '#B65C00', ok: '#16855B', sin: '#087BEA' }[est];
    const disp = Math.max(0, it.q - (it.res || 0));
    const otras = S.cajas.filter((x) => x !== c && x.userData.item.id === it.id);
    const p = S.permisos;
    const foto = it.foto
        ? '<div class="bm3d-foto" data-zoom="1"><img src="' + esc(it.foto) + '" alt="' + esc(it.n) + '" /><span class="bm3d-lupa"><i class="mdi mdi-magnify-plus-outline"></i></span></div>'
        : '<div class="bm3d-foto es-vacia"><i class="mdi mdi-image-off-outline"></i>Sin foto' + (p.repuestos ? ' · agrégala en Editar' : '') + '</div>';
    const rapidas = [];
    if (p.entrega) rapidas.push('<button type="button" class="bm3d-rapida" data-mov="salida"><i class="mdi mdi-tray-arrow-up"></i>Entregar / sacar</button>');
    if (p.ajuste) rapidas.push('<button type="button" class="bm3d-rapida es-cyan" data-mov="reubicacion"><i class="mdi mdi-swap-horizontal"></i>Cambiar de rack</button>',
                               '<button type="button" class="bm3d-rapida es-ambar" data-mov="ajuste"><i class="mdi mdi-scale-balance"></i>Ajustar conteo</button>',
                               '<button type="button" class="bm3d-rapida" data-mov="traslado"><i class="mdi mdi-truck-fast-outline"></i>Trasladar</button>');
    if (p.ingreso) rapidas.push('<button type="button" class="bm3d-rapida es-lila" data-mov="entrada"><i class="mdi mdi-tray-arrow-down"></i>Ingresar más</button>');
    if (p.repuestos) rapidas.push('<button type="button" class="bm3d-rapida es-lila" data-accion="editar-rep"><i class="mdi mdi-pencil-outline"></i>Editar repuesto</button>');
    if (p.bodegas && !c.userData.rack.recepcion) rapidas.push('<button type="button" class="bm3d-rapida" data-accion="posicion"><i class="mdi mdi-grid"></i>Cambiar de posición</button>');
    if (p.entrega && !c.userData.rack.recepcion) rapidas.push('<button type="button" class="bm3d-rapida es-cyan" data-accion="picking-add"><i class="mdi mdi-cart-plus"></i>Agregar al picking</button>');
    rapidas.push('<button type="button" class="bm3d-rapida" data-accion="etq-rep"><i class="mdi mdi-qrcode"></i>Imprimir etiqueta</button>');

    abrirPanel(cab(ubicTexto(c), it.n, it.c),
        foto +
        '<span class="bm3d-chipt" style="background:' + hexSuave(fam.color) + ';color:' + fam.color + '"><i class="bm3d-punto" style="background:' + fam.color + '"></i>' + esc(it.tn) + (it.tc ? ' · ' + esc(it.tc) : '') + '</span>' +
        '<div class="bm3d-stock"><div><b>' + num(disp) + '</b><span>Disponible</span></div><div><b>' + num(it.res) + '</b><span>Reservado</span></div><div><b>' + it.lot + '</b><span>Lote' + (it.lot === 1 ? '' : 's') + '</span></div></div>' +
        '<div class="bm3d-barra-stock"><i style="width:' + pct + '%;background:' + colorBarra + '"></i></div>' +
        '<div class="bm3d-umbral"><span>Mín. ' + num(it.min) + '</span><span class="bm3d-estado-chip es-' + est + '">' + ESTADO_TXT[est] + '</span><span>Máx. ' + num(it.max) + '</span></div>' +
        '<div class="bm3d-rapidas">' + rapidas.join('') + '</div>' +
        '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Detalle</span></div>' +
        '<div class="bm3d-dato"><span>Existencia en esta posición</span><b>' + num(it.q) + ' ' + esc(it.un) + '</b></div>' +
        (it.pr != null ? '<div class="bm3d-dato"><span>Punto de reposición</span><b>' + num(it.pr) + '</b></div>' : '') +
        '<div class="bm3d-dato"><span>Fabricante</span><b>' + esc(it.fab || '—') + '</b></div>' +
        '<div class="bm3d-dato"><span>Modelo</span><b>' + esc(it.mod || '—') + '</b></div>' +
        (c.userData.nivel ? '<div class="bm3d-dato"><span>Posición</span><b>' + c.userData.nivel + '-' + pad2(c.userData.posicion) + (c.userData.fila ? ' · atrás' : '') + ' · ' + (c.userData.fija ? 'fija' : 'calculada') + '</b></div>' : '') +
        (it.largo || it.peso ? '<div class="bm3d-dato"><span>Medidas y peso</span><b>' + (it.largo ? num(it.largo) + ' × ' + num(it.ancho) + ' × ' + num(it.alto) + ' cm' : '—') + (it.peso ? ' · ' + num(it.peso) + ' kg' : '') + '</b></div>' : '') +
        (consumoDe(it) ? '<div class="bm3d-dato"><span>Consumo (90 días)</span><b>' + num(consumoDe(it).diario) + ' ' + esc(it.un) + '/día' + (consumoDe(it).dias != null ? ' · se agota en ~' + Math.round(consumoDe(it).dias) + ' días' : '') + '</b></div>' : '') +
        '<div class="bm3d-dato"><span>Método de salida</span><b>' + esc(it.met || 'FEFO') + ' · ' + esc(METODO_TXT[it.met || 'FEFO']) + '</b></div>' +
        (it.ing ? '<div class="bm3d-dato"><span>Ingreso a esta caja</span><b>' + fechaCorta(it.ing) + '</b></div>' : '') +
        (it.vence ? '<div class="bm3d-dato"><span>Vence (lote más próximo)</span><b>' + fechaCorta(it.vence) + '</b></div>' : '') +
        '<div class="bm3d-dato"><span>Último movimiento</span><b>' + esc(it.ult || '—') + '</b></div></div>' +
        (otras.length ? '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>También está en</span><span>' + otras.length + '</span></div>' +
            otras.map((x, i) => '<div class="bm3d-item" data-otra="' + i + '">' + miniatura(x.userData.item.foto, x.userData.item.color) + '<div><b>' + esc(ubicTexto(x)) + '</b></div><em>' + num(x.userData.item.q) + '</em></div>').join('') + '</div>' : ''),
        '<button type="button" class="bm3d-btn es-contorno" id="bm3dVerFicha"><i class="mdi mdi-card-account-details-outline"></i>Ver ficha</button>' +
        (c.userData.rack ? '<button type="button" class="bm3d-btn es-ghost" id="bm3dVerRack"><i class="mdi mdi-view-grid-outline"></i>Ver ' + (c.userData.rack.recepcion ? 'recepción' : 'rack') + '</button>' : ''));

    const z = panel.querySelector('[data-zoom]');
    if (z) z.onclick = () => abrirGaleria(it.id, it.n, it.foto);
    $('bm3dVerFicha').onclick = () => abrirFicha(it.id);
    const vr = $('bm3dVerRack'); if (vr) vr.onclick = () => seleccionarRack(c.userData.rack, true);
    panel.querySelectorAll('[data-otra]').forEach((el) => el.onclick = () => seleccionarCaja(otras[+el.dataset.otra], true));
    panel.querySelectorAll('[data-mov]').forEach((el) => el.onclick = () => formMovimiento({ caja: c, clase: el.dataset.mov }, () => panelItem(c)));
    const er = panel.querySelector('[data-accion="editar-rep"]');
    if (er) er.onclick = () => formRepuesto(it.id, { bodega: c.userData.rack.bodega.id }, () => panelItem(c));
    panel.querySelector('[data-accion="etq-rep"]').onclick = () => imprimirEtiquetas('REPUESTO', it.id);
    const pka = panel.querySelector('[data-accion="picking-add"]'); if (pka) pka.onclick = () => agregarAPicking(it);
    const pos = panel.querySelector('[data-accion="posicion"]'); if (pos) pos.onclick = () => formPosicion(c);
}

// -------------------------------------------------------------- panel: rack
function panelRack(r) {
    const p = S.permisos;
    const cap = r.recepcion ? Math.max(r.items.length, 1) : RACK.niveles.length * r.cols;
    const pct = Math.min(100, Math.round((r.items.length / cap) * 100));
    const conFoto = r.cajas.filter((c) => c.userData.item.foto);
    const bajos = r.cajas.filter((c) => estadoDe(c.userData.item) === 'bajo').length;
    let niveles = '';
    if (r.recepcion) niveles = '<div class="bm3d-nivel">' + r.cajas.map((c, i) => itemHtml(c, i)).join('') + '</div>';
    else for (let n = RACK.niveles.length; n >= 1; n--) {
        const suyas = r.cajas.map((c, i) => [c, i]).filter(([c]) => c.userData.nivel === n).sort((a, b) => a[0].userData.posicion - b[0].userData.posicion);
        niveles += '<div class="bm3d-nivel"><div class="bm3d-nivel-cab"><span>Nivel ' + n + '</span><span>' + suyas.length + '</span></div>' +
            (suyas.length ? suyas.map(([c, i]) => itemHtml(c, i)).join('') : '<div class="bm3d-vacio-txt">Vacío</div>') + '</div>';
    }
    const rapidas = [];
    if ((p.ingreso || p.ajuste || p.entrega) && !r.recepcion) rapidas.push('<button type="button" class="bm3d-rapida es-lila" id="bm3dIngresar"><i class="mdi mdi-tray-arrow-down"></i>Ingresar aquí</button>');
    if (p.repuestos && !r.recepcion) rapidas.push('<button type="button" class="bm3d-rapida" id="bm3dNuevoAqui"><i class="mdi mdi-package-variant-plus"></i>Repuesto nuevo aquí</button>');
    if (p.bodegas && !r.recepcion) rapidas.push('<button type="button" class="bm3d-rapida es-cyan" id="bm3dEditarRack"><i class="mdi mdi-pencil-outline"></i>Editar rack</button>');
    if (!r.recepcion) rapidas.push('<button type="button" class="bm3d-rapida" id="bm3dEtqRack"><i class="mdi mdi-qrcode"></i>Etiquetas del rack</button>');
    if (!r.recepcion && p.bodegas && r.items.length) rapidas.push('<button type="button" class="bm3d-rapida" id="bm3dFijarPos"><i class="mdi mdi-grid"></i>' + (r.cajas.every((c) => c.userData.fija) ? 'Posiciones fijas ✓' : 'Fijar posiciones') + '</button>');
    if (!r.recepcion && p.bodegas) rapidas.push('<button type="button" class="bm3d-rapida" id="bm3dMoverRack"><i class="mdi mdi-cursor-move"></i>Mover en el plano</button>');
    if (!r.recepcion && p.ajuste && r.items.length && r.pasillo !== '·') rapidas.push('<button type="button" class="bm3d-rapida es-cyan" id="bm3dContarRack"><i class="mdi mdi-clipboard-check-outline"></i>Contar este rack</button>');

    abrirPanel(cab(r.bodega.nombre + (r.pasillo && r.pasillo !== '·' ? ' · Pasillo ' + r.pasillo : ''), r.codigo, r.nombre || '', 'mdi-view-grid-outline'),
        (r.recepcion ? '' : '<div class="bm3d-ocup"><div class="bm3d-barra-stock"><i style="width:' + Math.max(pct, 2) + '%;background:#16C6C9"></i></div><b>' + pct + '%</b>' +
            (bajos ? '<span class="bm3d-estado-chip es-bajo">' + bajos + ' bajo mín.</span>' : '') + '</div>') +
        (conFoto.length ? '<div class="bm3d-galeria">' + conFoto.map((c) => '<span class="bm3d-mini" data-foto="' + r.cajas.indexOf(c) + '" title="' + esc(c.userData.item.n) + '"><img src="' + esc(c.userData.item.foto) + '" alt="" loading="lazy" /></span>').join('') + '</div>' : '') +
        textoUltimoConteo(r, 'panel') +
        ((r.sobrecarga || []).length ? '<div class="bm3d-nota es-alerta" style="margin-bottom:12px"><i class="mdi mdi-weight-kilogram"></i><span>' + r.sobrecarga.map((x) => 'Nivel ' + x.nivel + ': ' + num(Math.round(x.kg)) + ' kg de ' + num(x.limite)).join(' · ') + ' — supera la carga admisible.</span></div>' : '') +
        (rapidas.length ? '<div class="bm3d-rapidas">' + rapidas.join('') + '</div>' : '') +
        (r.items.length ? niveles : '<div class="bm3d-vacio-txt">Este rack no tiene stock registrado.</div>'),
        (r.pasillo && r.pasillo !== '·' && !r.recepcion ? '<button type="button" class="bm3d-btn es-primario" id="bm3dRecorrer"><i class="mdi mdi-walk"></i>Recorrer pasillo ' + esc(r.pasillo) + '</button>' +
            (p.ajuste ? '<button type="button" class="bm3d-btn es-secundario" id="bm3dContarPasillo"><i class="mdi mdi-clipboard-check-outline"></i>Contar pasillo</button>' : '') : '') +
        '<button type="button" class="bm3d-btn es-contorno" id="bm3dGeneral"><i class="mdi mdi-fit-to-screen-outline"></i>Vista general</button>');

    panel.querySelectorAll('[data-caja]').forEach((el) => el.onclick = () => seleccionarCaja(r.cajas[+el.dataset.caja], true));
    panel.querySelectorAll('[data-foto]').forEach((el) => el.onclick = () => seleccionarCaja(r.cajas[+el.dataset.foto], true));
    const vuelve = () => panelRack(r);
    const ing = $('bm3dIngresar'); if (ing) ing.onclick = () => formMovimiento({ rack: r, clase: 'entrada' }, vuelve);
    const nva = $('bm3dNuevoAqui'); if (nva) nva.onclick = () => formRepuesto(0, { rack: r, bodega: r.bodega.id }, vuelve);
    const ed = $('bm3dEditarRack'); if (ed) ed.onclick = () => formRack(r.info, { id: r.id, codigo: r.codigo, nombre: r.nombre, rack: r }, vuelve);
    const et = $('bm3dEtqRack'); if (et) et.onclick = () => imprimirEtiquetas(r.items.length ? 'UBICACION_REPUESTO' : 'UBICACION', r.id);
    const rc = $('bm3dRecorrer'); if (rc) rc.onclick = () => iniciarRecorrido(r.infoPa, r);
    const cr = $('bm3dContarRack'); if (cr) cr.onclick = () => iniciarRecorrido(r.infoPa, r, { conteo: true, revisar: true });
    const fp = $('bm3dFijarPos'); if (fp) fp.onclick = (e) => guardando(e.currentTarget, async () => { await guardarPosicionesRack(r, listaPosicionesActual(r)); aviso('Posiciones de ' + r.codigo + ' fijadas: las etiquetas de sus casilleros ya son registros.'); const r2 = S.racks.find((x) => x.id === r.id); if (r2) seleccionarRack(r2, false); });
    const mr = $('bm3dMoverRack'); if (mr) mr.onclick = () => iniciarMoverRack(r);
    const cp = $('bm3dContarPasillo'); if (cp) cp.onclick = () => iniciarRecorrido(r.infoPa, null, { conteo: true });
    $('bm3dGeneral').onclick = () => { cerrarPanel(); vistaGeneral(); };
}
function itemHtml(c, i) {
    const it = c.userData.item, est = estadoDe(it);
    return '<div class="bm3d-item' + (est === 'bajo' ? ' es-bajo' : '') + '" data-caja="' + i + '">' + miniatura(it.foto, it.color) +
        '<div><b>' + esc(it.c) + '</b><span>' + (c.userData.nivel ? c.userData.nivel + '-' + pad2(c.userData.posicion) + ' · ' : '') + esc(it.n) + '</span></div>' +
        '<em>' + num(it.q) + '<small style="color:' + COLOR_ESTADO[est] + '">' + (est === 'bajo' ? 'bajo mín.' : est === 'sobre' ? 'sobre máx.' : esc(it.un)) + '</small></em></div>';
}

// ------------------------------------------------------------ panel: bodega
function panelBodega(info) {
    if (!info) return;
    const b = info.bodega, p = S.permisos;
    const reps = new Set(info.cajas.map((c) => c.userData.item.id)).size;
    const pasillos = info.pasillos.map((pa, ip) =>
        '<div class="bm3d-pasillo"><div class="bm3d-pasillo-cab"><span>' + (pa.nom === '·' ? 'Otras ubicaciones' : 'Pasillo ' + esc(pa.nom)) + ' · ' + pa.racks.length + ' racks</span>' +
        (pa.nom !== '·' && pa.racks.length ? '<span class="bm3d-pasillo-acc"><button type="button" class="bm3d-btn es-contorno es-chico" data-recorrer="' + ip + '" style="height:28px"><i class="mdi mdi-walk"></i>Recorrer</button>' +
            (p.ajuste ? '<button type="button" class="bm3d-btn es-secundario es-chico" data-contar="' + ip + '" style="height:28px" title="Recorrer y contar"><i class="mdi mdi-clipboard-check-outline"></i>Contar</button>' : '') + '</span>' : '') + '</div>' +
        '<div class="bm3d-racks">' + pa.racks.map((r) => '<button type="button" class="bm3d-rackchip" data-rack="' + r.indice + '">' + esc(r.codigo) + '</button>').join('') +
        (p.bodegas && pa.nom !== '·' ? '<button type="button" class="bm3d-rackchip es-mas" data-nuevo-rack="' + esc(pa.nom) + '"><i class="mdi mdi-plus"></i> rack</button>' : '') + '</div></div>').join('');
    abrirPanel(cab(b.planta + ' · ' + b.codigo, b.nombre, '', 'mdi-warehouse'),
        (b.descripcion ? '<p style="color:#4A556D;margin:0 0 12px;line-height:1.45">' + esc(b.descripcion) + '</p>' : '') +
        '<div class="bm3d-metodo"><i class="mdi mdi-sort-clock-ascending-outline"></i><span><b>Salida ' + esc(b.metodo || 'FEFO') + '</b>' + esc(METODO_TXT[b.metodo || 'FEFO']) + '</span></div>' +
        '<div class="bm3d-stock"><div><b>' + info.racks.length + '</b><span>Racks</span></div><div><b>' + reps + '</b><span>Repuestos</span></div><div><b>' + info.pasillos.length + '</b><span>Pasillos</span></div></div>' +
        '<div class="bm3d-rapidas">' +
        (p.bodegas ? '<button type="button" class="bm3d-rapida es-lila" id="bm3dEditBod"><i class="mdi mdi-pencil-outline"></i>Editar bodega</button>' : '') +
        (p.bodegas ? '<button type="button" class="bm3d-rapida es-cyan" id="bm3dModoEd"><i class="mdi mdi-pencil-ruler"></i>' + (S.edicion ? 'Salir de edición' : 'Crear racks en el mapa') + '</button>' : '') +
        (p.repuestos ? '<button type="button" class="bm3d-rapida" id="bm3dNuevoRep"><i class="mdi mdi-package-variant-plus"></i>Nuevo repuesto</button>' : '') +
        '<button type="button" class="bm3d-rapida" id="bm3dEtqBod"><i class="mdi mdi-qrcode"></i>Etiquetas de racks</button>' +
        '<button type="button" class="bm3d-rapida es-ambar" id="bm3dRepo"><i class="mdi mdi-cart-plus"></i>Reposición</button>' +
        '<button type="button" class="bm3d-rapida es-lila" id="bm3dAnal"><i class="mdi mdi-chart-box-outline"></i>Análisis</button>' +
        '<button type="button" class="bm3d-rapida" id="bm3dZonas"><i class="mdi mdi-vector-square"></i>Zonas del piso</button>' +
        (info.recepcion ? '<button type="button" class="bm3d-rapida es-ambar" id="bm3dVerRec"><i class="mdi mdi-truck-delivery-outline"></i>Recepción · ' + info.recepcion.items.length + '</button>' : '') +
        '</div>' +
        '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Pasillos y racks</span>' +
        (p.bodegas ? '<button type="button" id="bm3dNuevoPas"><i class="mdi mdi-plus"></i>Nuevo pasillo</button>' : '') + '</div>' +
        (pasillos || '<div class="bm3d-vacio-txt">Aún no hay ubicaciones. Crea el primer rack.</div>') + '</div>',
        '<button type="button" class="bm3d-btn es-contorno" id="bm3dEncuadrar"><i class="mdi mdi-fit-to-screen-outline"></i>Encuadrar</button>' +
        '<button type="button" class="bm3d-btn es-ghost" id="bm3dPlanta2"><i class="mdi mdi-floor-plan"></i>Planta</button>');
    const vuelve = () => panelBodega(S.porBodega.get(b.id));
    panel.querySelectorAll('[data-rack]').forEach((el) => el.onclick = () => seleccionarRack(S.racks[+el.dataset.rack], true));
    panel.querySelectorAll('[data-recorrer]').forEach((el) => el.onclick = () => iniciarRecorrido(info.pasillos[+el.dataset.recorrer]));
    panel.querySelectorAll('[data-contar]').forEach((el) => el.onclick = () => iniciarRecorrido(info.pasillos[+el.dataset.contar], null, { conteo: true }));
    panel.querySelectorAll('[data-nuevo-rack]').forEach((el) => el.onclick = () => formRack(info, sugerirRack(info, el.dataset.nuevoRack), vuelve));
    const np = $('bm3dNuevoPas'); if (np) np.onclick = () => formRack(info, sugerirRack(info, null), vuelve);
    const eb = $('bm3dEditBod'); if (eb) eb.onclick = () => formBodega(b, vuelve);
    const me = $('bm3dModoEd'); if (me) me.onclick = () => { alternarEdicion(); panelBodega(info); };
    const nr = $('bm3dNuevoRep'); if (nr) nr.onclick = () => formRepuesto(0, { bodega: b.id }, vuelve);
    $('bm3dEtqBod').onclick = () => imprimirEtiquetas('UBICACION', '', b.id);
    $('bm3dRepo').onclick = () => formReposicion(b.id);
    $('bm3dAnal').onclick = () => panelAnalisis();
    $('bm3dZonas').onclick = () => panelZonas(info);
    const vrc = $('bm3dVerRec'); if (vrc) vrc.onclick = () => seleccionarRack(info.recepcion, true);
    $('bm3dEncuadrar').onclick = () => vistaGeneral(b.id);
    $('bm3dPlanta2').onclick = () => vistaPlanta();
}

function sugerirRack(info, pasillo) {
    const pref = prefijoBodega(info);
    const letras = info.pasillos.filter((p) => p.nom !== '·').map((p) => p.nom).sort();
    if (!pasillo) pasillo = letras.length ? String.fromCharCode(letras[letras.length - 1].charCodeAt(0) + 1) : 'A';
    const pa = info.pasillos.find((p) => p.nom === pasillo);
    const n = pa ? Math.max(0, ...pa.racks.map((r) => r.num < 1000 ? r.num : 0)) + 1 : 1;
    return { pasillo, codigo: pref + '-' + pasillo + '-R' + pad2(n), nombre: 'Pasillo ' + pasillo + ' · Rack ' + pad2(n), nuevoPasillo: !pa };
}

// ===================================================================== ficha
/* La ficha del repuesto en una ventana DENTRO del mapa: no se pierde la
   escena ni la camara. Lo que no cabe aqui (compatibilidades, documentos) se
   abre en el Centro de repuestos en otra pestana. */
const ficha = $('bm3dFicha');
async function abrirFicha(repId) {
    ficha.hidden = false;
    ficha.innerHTML = '<div class="bm3d-fic-carga"><div class="bm3d-loader"><span></span><span></span><span></span></div></div>';
    let f, cat;
    try { [f, cat] = await Promise.all([ws('FichaRepuesto', { id: repId }), catalogos()]); }
    catch (e) { aviso(e.message, true); cerrarFicha(); return; }
    if (f.qr) S.qr['REP-' + repId] = f.qr;
    const r = f.repuesto;
    const cajas = S.cajas.filter((c) => c.userData.item.id === repId);
    const it0 = cajas.length ? cajas[0].userData.item : null;
    const tipo = cat.tipos.find((t) => t.id === r.tipo);
    const uni = cat.unidades.find((u) => u.id === r.unidad);
    const fam = infoFamilia(it0 ? it0.fam : familiaDe(tipo && tipo.codigo));
    const fotos = f.fotos || [];
    const total = cajas.reduce((s, c) => s + c.userData.item.q, 0);
    const reserv = cajas.reduce((s, c) => s + (c.userData.item.res || 0), 0);
    const bajos = cajas.filter((c) => estadoDe(c.userData.item) === 'bajo').length;
    const nomBod = (id) => ((S.datos.bodegas || []).find((b) => b.id === id) || { nombre: 'Bodega ' + id }).nombre;
    const enlace = it0 ? it0.ficha : '';
    const si = (v) => (v ? '<span style="color:#16855B"><i class="mdi mdi-check-circle"></i> Sí</span>' : '<span style="color:#68738A">No</span>');
    const vida = [r.vidaHoras ? num(r.vidaHoras) + ' h' : '', r.vidaDias ? num(r.vidaDias) + ' días' : '', r.vidaCiclos ? num(r.vidaCiclos) + ' ciclos' : ''].filter(Boolean).join(' · ') || '—';

    ficha.innerHTML =
        '<div class="bm3d-fic-cab" id="bm3dFicCab">' +
            '<div class="bm3d-fic-tit"><span class="bm3d-chipt" style="background:' + hexSuave(fam.color) + ';color:' + fam.color + '"><i class="bm3d-punto" style="background:' + fam.color + '"></i>' + esc(tipo ? tipo.nombre : 'Sin tipo') + '</span>' +
            '<h3>' + esc(r.nombre) + '</h3><div class="bm3d-pan-cod">' + esc(r.codigo) + (r.habilitado ? '' : ' · deshabilitado') + '</div></div>' +
            '<div class="bm3d-fic-acc">' +
                (S.permisos.repuestos ? '<button type="button" class="bm3d-btn es-primario es-chico" id="ficEditar"><i class="mdi mdi-pencil-outline"></i>Editar</button>' : '') +
                '<button type="button" class="bm3d-btn es-contorno es-chico" id="ficEtq"><i class="mdi mdi-qrcode"></i>Imprimir etiqueta</button>' +
                (enlace ? '<a class="bm3d-ico" href="' + esc(enlace) + '" target="_blank" rel="noopener" title="Abrir en Centro de repuestos (pestaña nueva)"><i class="mdi mdi-open-in-new"></i></a>' : '') +
                '<button type="button" class="bm3d-cerrar" id="ficCerrar" aria-label="Cerrar"><i class="mdi mdi-close"></i></button>' +
            '</div>' +
        '</div>' +
        '<div class="bm3d-fic-cuerpo">' +
            '<div class="bm3d-fic-izq">' +
                (fotos.length ? '<div class="bm3d-foto es-grande" id="ficFoto" data-i="0"><img src="' + esc(fotos[0].url) + '" alt="" /><span class="bm3d-lupa"><i class="mdi mdi-magnify-plus-outline"></i></span></div>' +
                    (fotos.length > 1 ? '<div class="bm3d-fotos">' + fotos.map((x, i) => '<span class="bm3d-mini' + (i === 0 ? ' is-portada' : '') + '" data-fic-foto="' + i + '"><img src="' + esc(x.url) + '" alt="" /></span>').join('') + '</div>' : '')
                    : '<div class="bm3d-foto es-vacia es-grande"><i class="mdi mdi-image-off-outline"></i>Sin fotos' + (S.permisos.repuestos ? ' · agrégalas en Editar' : '') + '</div>') +
                '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Etiqueta del repuesto</span><span>REP-' + repId + '</span></div>' +
                '<canvas class="bm3d-fic-etq" id="ficEtqCanvas" width="700" height="370"></canvas></div>' +
            '</div>' +
            '<div class="bm3d-fic-der">' +
                '<div class="bm3d-stock"><div><b>' + num(total) + '</b><span>En la planta' + (uni ? ' · ' + esc(uni.simbolo || uni.nombre) : '') + '</span></div><div><b>' + num(Math.max(0, total - reserv)) + '</b><span>Disponible</span></div><div><b>' + cajas.length + '</b><span>Ubicaciones</span></div></div>' +
                (bajos ? '<div class="bm3d-nota es-alerta" style="margin-bottom:12px"><i class="mdi mdi-alert-outline"></i>' + bajos + (bajos === 1 ? ' ubicación' : ' ubicaciones') + ' bajo el mínimo de su bodega.</div>' : '') +
                '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Dónde está</span><span>' + cajas.length + '</span></div>' +
                (cajas.length ? cajas.map((c, i) => {
                    const x = c.userData.item, e = estadoDe(x);
                    return '<div class="bm3d-item' + (e === 'bajo' ? ' es-bajo' : '') + '" data-fic-caja="' + i + '"><span class="bm3d-mini"><i class="mdi ' + (c.userData.rack.recepcion ? 'mdi-truck-delivery-outline' : 'mdi-view-grid-outline') + '" style="color:#087BEA"></i></span>' +
                        '<div><b>' + esc(ubicTexto(c, true)) + '</b><span>' + esc(nomBod(x.b)) + (x.lot ? ' · ' + x.lot + ' lote' + (x.lot === 1 ? '' : 's') : '') + '</span></div>' +
                        '<em>' + num(x.q) + '<small style="color:' + COLOR_ESTADO[e] + '">' + (e === 'bajo' ? 'bajo mín.' : e === 'sobre' ? 'sobre máx.' : esc(x.un)) + '</small></em></div>';
                }).join('') : '<div class="bm3d-vacio-txt">Sin stock en esta planta.</div>') + '</div>' +
                ((f.umbrales || []).length ? '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Umbrales por bodega</span></div>' +
                    f.umbrales.map((u) => '<div class="bm3d-dato"><span>' + esc(nomBod(u.bodega)) + '</span><b>Mín. ' + num(u.min) + ' · Máx. ' + num(u.max) + ' · Rep. ' + num(u.pr) + '</b></div>').join('') + '</div>' : '') +
                '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Datos técnicos</span></div>' +
                '<div class="bm3d-dato"><span>Fabricante</span><b>' + esc(r.fabricante || '—') + '</b></div>' +
                '<div class="bm3d-dato"><span>Modelo</span><b>' + esc(r.modelo || '—') + '</b></div>' +
                '<div class="bm3d-dato"><span>Unidad</span><b>' + esc(uni ? uni.nombre : '—') + '</b></div>' +
                '<div class="bm3d-dato"><span>Costo de referencia</span><b>' + (r.costo != null ? '$ ' + num(r.costo) : '—') + '</b></div>' +
                '<div class="bm3d-dato"><span>Consumible</span><b>' + si(r.consumible) + '</b></div>' +
                '<div class="bm3d-dato"><span>Reparable</span><b>' + si(r.reparable) + '</b></div>' +
                '<div class="bm3d-dato"><span>Controla lote</span><b>' + si(r.lote) + '</b></div>' +
                '<div class="bm3d-dato"><span>Vida útil</span><b>' + vida + '</b></div></div>' +
                (r.descripcion ? '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Descripción</span></div><p class="bm3d-fic-desc">' + esc(r.descripcion) + '</p></div>' : '') +
            '</div>' +
        '</div>';

    // etiqueta: el mismo dibujo que el Centro de etiquetas, con su QR real
    const cv = $('ficEtqCanvas');
    dibujarEtiqueta(cv.getContext('2d'), 0, 0, cv.width, cv.height, { token: 'REP-' + repId, codigo: r.codigo, titulo: r.nombre, subtitulo: [r.fabricante, r.modelo].filter(Boolean).join(' '), detalle: uni ? uni.nombre : '', pie: 'Repuesto' }, { borde: true });

    $('ficCerrar').onclick = cerrarFicha;
    $('ficEtq').onclick = () => imprimirEtiquetas('REPUESTO', repId);
    const ed = $('ficEditar');
    if (ed) ed.onclick = () => {
        cerrarFicha();
        if (S.tour) salirRecorrido();
        formRepuesto(repId, { bodega: it0 ? it0.b : S.bodegaSel }, () => (S.sel && S.sel.isMesh ? panelItem(S.sel) : cerrarPanel()));
    };
    const fp = $('ficFoto'); if (fp) fp.onclick = () => abrirVisor(fotos.map((x) => x.url), +(fp.dataset.i || 0), r.nombre);
    ficha.querySelectorAll('[data-fic-foto]').forEach((el) => el.onclick = () => {
        const i = +el.dataset.ficFoto;
        fp.querySelector('img').src = fotos[i].url; fp.dataset.i = i;
        ficha.querySelectorAll('[data-fic-foto]').forEach((x) => x.classList.toggle('is-portada', x === el));
    });
    ficha.querySelectorAll('[data-fic-caja]').forEach((el) => el.onclick = () => {
        const c = cajas[+el.dataset.ficCaja];
        cerrarFicha();
        if (S.tour) { irACajaRecorrido(c); return; }
        if (S.filtro.size && !S.filtro.has(c.userData.item.tid)) { S.filtro.clear(); aplicarFiltros(); }
        seleccionarCaja(c, true);
    });
    arrastrable(ficha, $('bm3dFicCab'));
}
function cerrarFicha() { ficha.hidden = true; ficha.style.left = ficha.style.top = ''; ficha.style.transform = ''; }
/* La ventana se mueve tomandola de la cabecera, para ver lo que tapa. */
function arrastrable(el, asa) {
    asa.onpointerdown = (ev) => {
        if (ev.target.closest('button, a')) return;
        const r = el.getBoundingClientRect(), pr = root.getBoundingClientRect();
        const dx = ev.clientX - r.left, dy = ev.clientY - r.top;
        el.style.transform = 'none';
        el.style.left = (r.left - pr.left) + 'px'; el.style.top = (r.top - pr.top) + 'px';
        const mover = (e) => {
            el.style.left = Math.max(0, Math.min(pr.width - 120, e.clientX - pr.left - dx)) + 'px';
            el.style.top = Math.max(0, Math.min(pr.height - 60, e.clientY - pr.top - dy)) + 'px';
        };
        const soltar = () => { document.removeEventListener('pointermove', mover); document.removeEventListener('pointerup', soltar); };
        document.addEventListener('pointermove', mover); document.addEventListener('pointerup', soltar);
    };
}

// ================================================================= formularios
function campo(etq, control, o) {
    o = o || {};
    return '<div class="bm3d-campo' + (o.ancho ? ' es-ancho' : '') + '"><label>' + esc(etq) + (o.req ? ' <em>*</em>' : '') + '</label>' + control +
           (o.ayuda ? '<small>' + esc(o.ayuda) + '</small>' : '') + '</div>';
}
const inp = (id, v, o) => '<input id="' + id + '" type="' + ((o && o.tipo) || 'text') + '" value="' + esc(v == null ? '' : v) + '"' + (o && o.ph ? ' placeholder="' + esc(o.ph) + '"' : '') + (o && o.ro ? ' readonly' : '') + (o && o.paso ? ' step="any" inputmode="decimal"' : '') + ' />';
const sel = (id, opciones, v) => '<select id="' + id + '">' + opciones.map((x) => '<option value="' + esc(x[0]) + '"' + (String(x[0]) === String(v) ? ' selected' : '') + '>' + esc(x[1]) + '</option>').join('') + '</select>';
const chk = (id, etq, on) => '<label class="bm3d-check' + (on ? ' is-on' : '') + '"><input type="checkbox" id="' + id + '"' + (on ? ' checked' : '') + ' />' + esc(etq) + '</label>';
const val = (id) => { const e = $(id); return e ? (e.type === 'checkbox' ? e.checked : e.value.trim()) : ''; };
function activarChecks() { panel.querySelectorAll('.bm3d-check input').forEach((c) => c.onchange = () => c.parentElement.classList.toggle('is-on', c.checked)); }
async function guardando(btn, fn) {
    const html = btn.innerHTML; btn.disabled = true; btn.innerHTML = '<i class="mdi mdi-loading mdi-spin"></i>Guardando…';
    try { await fn(); } catch (e) { aviso(e.message, true); } finally { if (document.body.contains(btn)) { btn.disabled = false; btn.innerHTML = html; } }
}
async function catalogos(forzar) {
    if (!S.cat || forzar) S.cat = await ws('Catalogos', {});
    return S.cat;
}

// ---------------------------------------------------------------- bodega
function formBodega(b, volver) {
    const nueva = !b;
    abrirPanel(cab(nueva ? 'Nueva bodega' : 'Editar bodega', nueva ? 'Crear bodega' : b.nombre, nueva ? '' : b.codigo, 'mdi-warehouse'),
        '<div class="bm3d-form">' +
        campo('Planta', sel('fBodPlanta', (S.datos.plantas || []).map((p) => [p.id, p.nombre]), nueva ? S.planta : b.plantaId), { ancho: true, req: true }) +
        (nueva ? campo('Código', inp('fBodCod', '', { ph: 'Vacío = automático' }), { ayuda: 'No se puede cambiar después.' }) : campo('Código', inp('fBodCod', b.codigo, { ro: true }))) +
        campo('Nombre', inp('fBodNom', nueva ? '' : b.nombre, { ph: 'Ej. Bodega Piso 3' }), { req: true }) +
        campo('Descripción', '<textarea id="fBodDesc" placeholder="Para qué se usa: alta rotación, críticos…">' + esc(nueva ? '' : b.descripcion) + '</textarea>', { ancho: true }) +
        campo('Método de salida', sel('fBodMet', [['FEFO', 'FEFO · lo que vence antes sale antes'], ['FIFO', 'FIFO · lo que entró antes sale antes'], ['LIFO', 'LIFO · lo que entró último sale antes']], nueva ? 'FEFO' : (b.metodo || 'FEFO')),
              { ancho: true, ayuda: 'Decide de qué caja y de qué lote se saca primero en entregas, picking y ajustes. Un repuesto puede tener su propia excepción.' }) +
        '</div>' + (nueva ? '<div class="bm3d-nota" style="margin-top:12px"><i class="mdi mdi-lightbulb-on-outline"></i>Después de crearla, activa el modo edición para dibujar sus pasillos y racks directo en el mapa.</div>' : ''),
        '<button type="button" class="bm3d-btn es-ghost" id="fCancelar">Cancelar</button><button type="button" class="bm3d-btn es-primario" id="fGuardar"><i class="mdi mdi-content-save-outline"></i>' + (nueva ? 'Crear bodega' : 'Guardar') + '</button>',
        volver);
    $('fCancelar').onclick = () => (volver ? volver() : cerrarPanel());
    $('fGuardar').onclick = (e) => guardando(e.currentTarget, async () => {
        const r = await ws('GuardarBodega', { datos: JSON.stringify({ id: nueva ? 0 : b.id, planta: val('fBodPlanta'), codigo: nueva ? val('fBodCod') : '', nombre: val('fBodNom'), descripcion: val('fBodDesc'), metodo: val('fBodMet') }) });
        aviso(r.detalle || (nueva ? 'Bodega creada.' : 'Bodega actualizada.'));
        const planta = +val('fBodPlanta');
        await recargar(true, planta !== S.planta ? planta : 0);
        const id = r.id || (b && b.id);
        if (S.porBodega.has(id)) { elegirBodega(id); panelBodega(S.porBodega.get(id)); if (nueva && !S.edicion && S.permisos.bodegas) alternarEdicion(); }
    });
}

// ---------------------------------------------------------------- rack
function formRack(info, d, volver) {
    const nuevo = !d.id;
    abrirPanel(cab(info.bodega.nombre + (d.pasillo ? ' · Pasillo ' + d.pasillo : ''), nuevo ? 'Nuevo rack' : 'Editar rack', nuevo ? '' : d.codigo, 'mdi-view-grid-plus-outline'),
        '<div class="bm3d-form">' +
        campo('Código', inp('fRackCod', d.codigo, { ro: !nuevo }), { ancho: true, req: true, ayuda: nuevo ? 'Sigue la convención de la bodega: <prefijo>-<pasillo>-R<número>. El mapa lo lee para ubicarlo.' : 'El código no se cambia: identifica la ubicación y va en su etiqueta.' }) +
        campo('Nombre', inp('fRackNom', d.nombre), { ancho: true }) +
        (!nuevo ? campo('Estado', '<div class="bm3d-checks">' + chk('fRackHab', 'Habilitado', true) + '</div>', { ancho: true, ayuda: 'Deshabilitado deja de aparecer en el mapa y en los combos.' }) : '') +
        (!nuevo ? campo('Carga admisible por nivel (kg)', inp('fRackCarga', d.rack && d.rack.carga != null ? d.rack.carga : '', { paso: true, ph: '1000' }), { ancho: true, ayuda: 'Con el peso de cada repuesto, el mapa avisa cuando un nivel la supera. Vacío = 1.000 kg.' }) : '') +
        '</div>' +
        (!nuevo && d.rack && S.permisos.bodegas ? '<div class="bm3d-rapidas" style="margin-top:12px"><button type="button" class="bm3d-rapida es-cyan" id="fRackMover"><i class="mdi mdi-cursor-move"></i>Mover en el plano</button>' +
            (d.rack.movido ? '<button type="button" class="bm3d-rapida" id="fRackPlano0"><i class="mdi mdi-restore"></i>Volver a su posición por código</button>' : '') + '</div>' : '') +
        (d.nuevoPasillo ? '<div class="bm3d-nota" style="margin-top:12px"><i class="mdi mdi-information-outline"></i>Este rack abre el pasillo ' + esc(d.pasillo) + '.</div>' : ''),
        (!nuevo ? '<button type="button" class="bm3d-btn es-peligro es-chico" id="fEliminar"><i class="mdi mdi-delete-outline"></i></button>' : '') +
        '<button type="button" class="bm3d-btn es-ghost" id="fCancelar">Cancelar</button><button type="button" class="bm3d-btn es-primario" id="fGuardar"><i class="mdi mdi-content-save-outline"></i>' + (nuevo ? 'Crear rack' : 'Guardar') + '</button>',
        volver);
    activarChecks();
    $('fCancelar').onclick = () => (volver ? volver() : cerrarPanel());
    const codigoFinal = () => val('fRackCod').toUpperCase().replace(/\s+/g, '');
    $('fGuardar').onclick = (e) => guardando(e.currentTarget, async () => {
        const r = await ws('GuardarUbicacion', { datos: JSON.stringify({ id: d.id || 0, bodega: info.id, codigo: codigoFinal(), nombre: val('fRackNom'), habilitado: nuevo ? true : val('fRackHab') }) });
        if (!nuevo && $('fRackCarga') && val('fRackCarga') !== String(d.rack && d.rack.carga != null ? d.rack.carga : '')) await ws('GuardarCarga', { ubicacion: d.id, carga: val('fRackCarga') });
        aviso(r.detalle || 'Ubicación guardada.');
        await recargar(true);
        const nuevoRack = S.racks.find((x) => x.id === (r.id || d.id));
        if (nuevoRack) seleccionarRack(nuevoRack, true); else panelBodega(S.porBodega.get(info.id));
    });
    const fm = $('fRackMover'); if (fm) fm.onclick = () => iniciarMoverRack(d.rack);
    const f0 = $('fRackPlano0'); if (f0) f0.onclick = (e) => guardando(e.currentTarget, async () => { await ws('QuitarPlanoRack', { ubicacion: d.id }); aviso('El rack vuelve a su posición por código.'); await recargar(true); const r2 = S.racks.find((x) => x.id === d.id); if (r2) seleccionarRack(r2, true); });
    const el = $('fEliminar');
    if (el) el.onclick = (e) => {
        if (d.rack && d.rack.items.length) { aviso('El rack tiene stock: muévelo antes de eliminarlo.', true); return; }
        if (e.currentTarget.dataset.confirmar !== '1') { e.currentTarget.dataset.confirmar = '1'; e.currentTarget.innerHTML = '<i class="mdi mdi-delete-alert-outline"></i>¿Eliminar?'; return; }
        guardando(e.currentTarget, async () => {
            const r = await ws('EliminarUbicacion', { id: d.id });
            aviso(r.detalle || 'Ubicación eliminada.');
            await recargar(true);
            panelBodega(S.porBodega.get(info.id));
        });
    };
}

// ---------------------------------------------------------------- repuesto
async function formRepuesto(id, ctx, volver) {
    ctx = ctx || {};
    abrirPanel(cab('Repuestos', id ? 'Editar repuesto' : 'Nuevo repuesto', '', 'mdi-package-variant'), '<div class="bm3d-loader" style="justify-content:center;margin:30px"><span></span><span></span><span></span></div>', '', volver);
    let cat, fic = null;
    try {
        cat = await catalogos();
        if (id) fic = await ws('FichaRepuesto', { id });
    } catch (e) { aviso(e.message, true); return; }
    const r = fic ? fic.repuesto : { codigo: '', nombre: '', unidad: (cat.unidades.find((u) => u.codigo === 'UNIDAD') || {}).id, tipo: 0, consumible: false, reparable: false, lote: false, habilitado: true };
    const bodega = ctx.bodega || S.bodegaSel;
    const umb = fic ? (fic.umbrales || []).find((u) => u.bodega === bodega) : null;
    const nomBod = (S.porBodega.get(bodega) || { bodega: { nombre: '' } }).bodega.nombre;
    const fotos = fic ? fic.fotos : [];

    abrirPanel(cab(id ? r.codigo : 'Repuestos', id ? r.nombre : 'Nuevo repuesto', '', 'mdi-package-variant'),
        (id ? '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Fotos</span><span>' + fotos.length + '</span></div><div class="bm3d-fotos">' +
            fotos.map((f, i) => '<span class="bm3d-mini' + (i === 0 ? ' is-portada' : '') + '" data-ver="' + i + '"><img src="' + esc(f.url) + '" alt="" />' +
                '<span class="bm3d-foto-acc"><button type="button" data-portada="' + f.vinculo + '" title="Usar como portada"><i class="mdi mdi-star"></i></button><button type="button" data-quitar="' + f.vinculo + '" title="Quitar"><i class="mdi mdi-close"></i></button></span></span>').join('') +
            '<button type="button" class="bm3d-subir" id="fSubir" title="Agregar foto"><i class="mdi mdi-camera-plus-outline"></i></button><input type="file" id="fArchivo" accept="image/*" hidden /></div>' +
            '<small style="color:#68738A">La primera es la portada: es la que se ve en el mapa, el panel y la tablet del recorrido.</small></div>' : '') +
        '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Datos</span></div><div class="bm3d-form">' +
        campo('Código', inp('fRepCod', r.codigo, { ro: !!id, ph: 'Vacío = automático' }), { ayuda: id ? '' : 'Ej. MEC-RODAMIENTO-021' }) +
        campo('Tipo', sel('fRepTipo', [[0, 'Sin tipo']].concat(cat.tipos.map((t) => [t.id, t.nombre])), r.tipo || (ctx.tipo || 0))) +
        campo('Nombre', inp('fRepNom', r.nombre, { ph: 'Ej. Rodamiento 6205-2RS1' }), { ancho: true, req: true }) +
        campo('Unidad', sel('fRepUni', cat.unidades.map((u) => [u.id, u.nombre + (u.simbolo ? ' (' + u.simbolo + ')' : '')]), r.unidad), { req: true }) +
        campo('Costo de referencia', inp('fRepCosto', r.costo, { paso: true, ph: 'CLP' })) +
        campo('Método de salida', sel('fRepMet', [['', 'Según la bodega'], ['FEFO', 'FEFO · vence antes, sale antes'], ['FIFO', 'FIFO · entró antes, sale antes'], ['LIFO', 'LIFO · entró último, sale antes']], fic ? (fic.metodo || '') : ''),
              { ancho: true, ayuda: 'Excepción para este repuesto. «Según la bodega» sigue el método de cada bodega.' }) +
        campo('Fabricante', inp('fRepFab', r.fabricante)) +
        campo('Modelo', inp('fRepMod', r.modelo)) +
        campo('Descripción', '<textarea id="fRepDesc">' + esc(r.descripcion || '') + '</textarea>', { ancho: true }) +
        campo('Características', '<div class="bm3d-checks">' + chk('fRepCons', 'Consumible', r.consumible) + chk('fRepRepa', 'Reparable', r.reparable) + chk('fRepLote', 'Controla lote', r.lote) + (id ? chk('fRepHab', 'Habilitado', r.habilitado) : '') + '</div>', { ancho: true }) +
        '</div></div>' +
        '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Vida útil</span></div><div class="bm3d-form" style="grid-template-columns:1fr 1fr 1fr">' +
        campo('Horas', inp('fRepVH', r.vidaHoras, { paso: true })) + campo('Días', inp('fRepVD', r.vidaDias, { paso: true })) + campo('Ciclos', inp('fRepVC', r.vidaCiclos, { paso: true })) +
        '</div></div>' +
        '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Medidas y peso</span><span>para el mapa y la carga</span></div><div class="bm3d-form" style="grid-template-columns:1fr 1fr 1fr 1fr">' +
        campo('Largo cm', inp('fRepLa', fic && fic.medidas ? fic.medidas.largo : '', { paso: true })) + campo('Ancho cm', inp('fRepAn', fic && fic.medidas ? fic.medidas.ancho : '', { paso: true })) +
        campo('Alto cm', inp('fRepAl', fic && fic.medidas ? fic.medidas.alto : '', { paso: true })) + campo('Peso kg', inp('fRepPe', fic && fic.medidas ? fic.medidas.peso : '', { paso: true })) +
        '</div></div>' +
        (S.permisos.stock ? '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Umbrales en ' + esc(nomBod) + '</span></div><div class="bm3d-form" style="grid-template-columns:1fr 1fr 1fr">' +
            campo('Mínimo', inp('fUmMin', umb ? umb.min : '', { paso: true })) + campo('Máximo', inp('fUmMax', umb ? umb.max : '', { paso: true })) + campo('Reposición', inp('fUmPr', umb ? umb.pr : '', { paso: true })) +
            '</div></div>' : '') +
        (!id && ctx.rack ? '<div class="bm3d-nota"><i class="mdi mdi-information-outline"></i>Al crearlo pasas directo a ingresarlo en ' + esc(ctx.rack.codigo) + '.</div>' : ''),
        '<button type="button" class="bm3d-btn es-ghost" id="fCancelar">Cancelar</button><button type="button" class="bm3d-btn es-primario" id="fGuardar"><i class="mdi mdi-content-save-outline"></i>' + (id ? 'Guardar' : 'Crear repuesto') + '</button>',
        volver);
    activarChecks();
    $('fCancelar').onclick = () => (volver ? volver() : cerrarPanel());

    if (id) {
        $('fSubir').onclick = () => $('fArchivo').click();
        $('fArchivo').onchange = async (e) => {
            const f = e.target.files[0]; if (!f) return;
            try {
                aviso('Subiendo foto…');
                const b64 = await reducirImagen(f);
                await ws('SubirFoto', { repuesto: id, nombre: f.name.replace(/\.[^.]+$/, '') + '.jpg', mime: 'image/jpeg', base64: b64 });
                aviso('Foto agregada.');
                await refrescarStock(true);
                formRepuesto(id, ctx, volver);
            } catch (er) { aviso(er.message, true); }
        };
        panel.querySelectorAll('[data-ver]').forEach((el) => el.onclick = (e) => { if (e.target.closest('button')) return; abrirVisor(fotos.map((f) => f.url), +el.dataset.ver, r.nombre); });
        panel.querySelectorAll('[data-portada]').forEach((b) => b.onclick = async () => { try { await ws('PortadaFoto', { vinculo: +b.dataset.portada }); aviso('Portada actualizada.'); await refrescarStock(true); formRepuesto(id, ctx, volver); } catch (er) { aviso(er.message, true); } });
        panel.querySelectorAll('[data-quitar]').forEach((b) => b.onclick = async () => { try { await ws('QuitarFoto', { vinculo: +b.dataset.quitar }); aviso('Foto quitada.'); await refrescarStock(true); formRepuesto(id, ctx, volver); } catch (er) { aviso(er.message, true); } });
    }

    $('fGuardar').onclick = (e) => guardando(e.currentTarget, async () => {
        const datos = {
            id: id || 0, codigo: val('fRepCod'), nombre: val('fRepNom'), tipo: val('fRepTipo'), unidad: val('fRepUni'),
            fabricante: val('fRepFab'), modelo: val('fRepMod'), descripcion: val('fRepDesc'), costo: val('fRepCosto'),
            consumible: val('fRepCons'), reparable: val('fRepRepa'), lote: val('fRepLote'),
            vidaHoras: val('fRepVH'), vidaDias: val('fRepVD'), vidaCiclos: val('fRepVC'), metodo: val('fRepMet'),
            largo: val('fRepLa'), ancho: val('fRepAn'), alto: val('fRepAl'), peso: val('fRepPe')
        };
        if (id) datos.habilitado = val('fRepHab');
        const res = await ws('GuardarRepuesto', { datos: JSON.stringify(datos) });
        const repId = res.id || id;
        if (S.permisos.stock && (val('fUmMin') !== '' || val('fUmMax') !== '' || val('fUmPr') !== '')) {
            try { await ws('GuardarUmbral', { datos: JSON.stringify({ repuesto: repId, bodega, min: val('fUmMin'), max: val('fUmMax'), pr: val('fUmPr') }) }); }
            catch (er) { aviso('El repuesto se guardó, pero los umbrales no: ' + er.message, true); }
        }
        aviso(res.detalle || 'Repuesto guardado.');
        await catalogos(true);
        await refrescarStock(true);
        if (!id && ctx.rack) {
            const rk = S.racks.find((x) => x.id === ctx.rack.id) || ctx.rack;
            formMovimiento({ rack: rk, clase: 'entrada', repuesto: (S.cat.repuestos || []).find((x) => x.id === repId) }, () => panelRack(rk));
        } else if (!id) formRepuesto(repId, ctx, volver);
        else if (volver) reabrirSeleccion(volver);
    });
}

/* La foto se reduce ANTES de subirla: una de celular pesa 8 MB y en la ficha y
   la etiqueta no se ve mejor que una de 1600 px. */
async function reducirImagen(file) {
    const img = await new Promise((ok, mal) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => mal(new Error('El archivo no es una imagen válida.')); i.src = URL.createObjectURL(file); });
    const k = Math.min(1, 1600 / Math.max(img.naturalWidth, img.naturalHeight));
    const c = canvas(Math.round(img.naturalWidth * k), Math.round(img.naturalHeight * k));
    const g = c.getContext('2d'); g.fillStyle = '#FFFFFF'; g.fillRect(0, 0, c.width, c.height);
    g.drawImage(img, 0, 0, c.width, c.height);
    URL.revokeObjectURL(img.src);
    return c.toDataURL('image/jpeg', 0.86);
}

// ---------------------------------------------------------------- movimiento
/* Con las MISMAS reglas que Movimiento.aspx (que tambien vuelve a validar el
   servidor): la salida sale de un origen con saldo, la reubicacion pide un
   destino distinto, el lote nuevo se crea antes del movimiento. */
async function formMovimiento(ctx, volver) {
    abrirPanel(cab('Movimiento de inventario', 'Cargando…', '', 'mdi-swap-vertical'), '<div class="bm3d-loader" style="justify-content:center;margin:30px"><span></span><span></span><span></span></div>', '', volver);
    let cat;
    try { cat = await catalogos(); } catch (e) { aviso(e.message, true); return; }

    const caja = ctx.caja || null;
    const rack = ctx.rack || (caja ? caja.userData.rack : null);
    const bodegaId = rack ? rack.bodega.id : S.bodegaSel;
    const info = S.porBodega.get(bodegaId);
    let repuesto = ctx.repuesto || (caja ? (cat.repuestos.find((x) => x.id === caja.userData.item.id) || { id: caja.userData.item.id, c: caja.userData.item.c, n: caja.userData.item.n, un: caja.userData.item.un, foto: caja.userData.item.foto }) : null);

    const clasesValidas = caja ? ['salida', 'reubicacion', 'traslado', 'entrada'] : ['entrada'];
    const tipos = cat.movimientos.filter((m) => clasesValidas.includes(m.clase));
    if (!tipos.length) { aviso('No tienes permiso para registrar este tipo de movimiento.', true); if (volver) volver(); return; }
    const preferido = { salida: 2, ajuste: 5, reubicacion: 9, traslado: 6, entrada: caja ? 4 : 1 }[ctx.clase];
    let tipo = (tipos.find((t) => t.id === preferido) || tipos[0]).id;
    let destinoRack = null;

    const icono = { entrada: 'mdi-tray-arrow-down', salida: 'mdi-tray-arrow-up', reubicacion: 'mdi-swap-horizontal', traslado: 'mdi-truck-fast-outline' };
    const pintar = async () => {
        const t = tipos.find((x) => x.id === tipo), clase = t.clase;
        const otrasBodegas = (S.datos.bodegas || []).filter((b) => b.id !== bodegaId);
        abrirPanel(cab(rack ? rack.bodega.nombre + ' · ' + rack.codigo : 'Movimiento', t.nombre, repuesto ? repuesto.c : '', icono[clase]),
            '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Qué movimiento</span></div><div class="bm3d-tipos-mov">' +
            tipos.map((x) => '<button type="button" class="bm3d-tipo-mov es-' + x.clase + (x.id === tipo ? ' is-sel' : '') + '" data-tipo="' + x.id + '"><i class="mdi ' + icono[x.clase] + '"></i>' + esc(x.nombre) + '</button>').join('') + '</div></div>' +
            '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Repuesto</span></div>' +
            (repuesto ? '<div class="bm3d-repsel">' + miniatura(repuesto.foto) + '<div><b>' + esc(repuesto.c) + '</b><span>' + esc(repuesto.n) + '</span></div>' + (caja ? '' : '<button type="button" id="fCambiarRep" title="Elegir otro"><i class="mdi mdi-close-circle"></i></button>') + '</div>'
                      : '<div class="bm3d-selrep"><input id="fBuscaRep" placeholder="Busca por código o nombre…" autocomplete="off" style="width:100%;height:36px;padding:0 10px;border:1px solid #CFD6E3;border-radius:9px" /><div class="bm3d-resultados" id="fRepRes" hidden></div></div>' +
                        (S.permisos.repuestos ? '<button type="button" class="bm3d-btn es-contorno es-chico" id="fCrearRep" style="margin-top:8px"><i class="mdi mdi-plus"></i>Crear repuesto nuevo</button>' : '')) +
            '</div>' +
            '<div class="bm3d-form" id="fMovCampos"></div>',
            '<button type="button" class="bm3d-btn es-ghost" id="fCancelar">Cancelar</button><button type="button" class="bm3d-btn es-primario" id="fGuardar"' + (repuesto ? '' : ' disabled') + '><i class="mdi mdi-check"></i>Registrar</button>',
            volver);
        $('fCancelar').onclick = () => (volver ? volver() : cerrarPanel());
        panel.querySelectorAll('[data-tipo]').forEach((b) => b.onclick = () => { tipo = +b.dataset.tipo; pintar(); });
        const cr = $('fCambiarRep'); if (cr) cr.onclick = () => { repuesto = null; pintar(); };
        const crn = $('fCrearRep'); if (crn) crn.onclick = () => formRepuesto(0, { rack, bodega: bodegaId }, () => formMovimiento(ctx, volver));
        const busca = $('fBuscaRep');
        if (busca) {
            const res = $('fRepRes');
            busca.oninput = () => {
                const q = norm(busca.value);
                if (q.length < 2) { res.hidden = true; return; }
                const m = cat.repuestos.filter((x) => norm(x.c).includes(q) || norm(x.n).includes(q) || norm(x.tn).includes(q)).slice(0, 30);
                res.hidden = false;
                res.innerHTML = m.length ? m.map((x, i) => '<div class="bm3d-res" data-i="' + i + '">' + miniatura(x.foto) + '<div><b>' + esc(x.c) + '</b><span>' + esc(x.n) + '</span></div><em>' + esc(x.tn || '') + '</em></div>').join('') : '<div class="bm3d-res-vacio">Sin coincidencias.</div>';
                res.querySelectorAll('[data-i]').forEach((el) => el.onmousedown = (ev) => { ev.preventDefault(); repuesto = m[+el.dataset.i]; pintar(); });
            };
            setTimeout(() => busca.focus(), 50);
        }

        // ---- los campos dependen del tipo
        const box = $('fMovCampos');
        let html = campo('Cantidad' + (repuesto && repuesto.un ? ' (' + repuesto.un + ')' : ''), inp('fCant', '', { paso: true, ph: '0' }), { req: true });
        if (clase !== 'entrada') html += campo('Sale de', '<select id="fOrigen"><option>Cargando…</option></select>', { req: true });
        if (clase === 'entrada') {
            html += campo('Entra a', sel('fUbic', (info ? info.racks : []).map((r) => [r.id, r.codigo]), rack ? rack.id : ''), { req: true });
            if (repuesto && repuesto.lote) html += campo('Lote', '<select id="fLote"><option value="">Lote nuevo…</option></select>', { ayuda: 'El repuesto controla lote.' }) +
                campo('Código del lote nuevo', inp('fLoteNuevo', '', { ph: 'Ej. L2026-10' })) + campo('Vence', inp('fLoteVence', '', { tipo: 'date' }));
            if (tipo === 1) html += campo('Costo unitario', inp('fCosto', '', { paso: true, ph: 'CLP' }));
        }
        if (clase === 'reubicacion') {
            const racksDestino = (info ? info.racks : []).filter((r) => !caja || r.id !== caja.userData.rack.id);
            html += campo('Va a', '<div class="bm3d-elegir">' + sel('fDestUbic', [['', 'Elegir…']].concat(racksDestino.map((r) => [r.id, r.codigo])), destinoRack ? destinoRack.id : '') +
                '<button type="button" class="bm3d-btn es-secundario es-chico" id="fPick" title="Elegir el rack en el mapa"><i class="mdi mdi-target"></i>En el mapa</button></div>', { req: true, ancho: true });
        }
        if (clase === 'traslado') {
            html += campo('Bodega de destino', sel('fDestBod', [['', 'Elegir…']].concat(otrasBodegas.map((b) => [b.id, b.nombre])), ''), { req: true }) +
                    campo('Queda en', '<select id="fDestUbicT"><option value="">Elegir bodega primero</option></select>');
        }
        if (tipo === 2 || tipo === 3) html += campo('Orden de trabajo', sel('fOT', [['', 'Sin orden']].concat((cat.ordenes || []).map((o) => [o.id, o.texto])), ''), { ancho: true });
        const esAjuste = tipo === 4 || tipo === 5 || tipo === 8;
        html += campo(esAjuste ? 'Motivo' : 'Observación', '<textarea id="fObs" placeholder="' + (esAjuste ? 'Por qué se ajusta (obligatorio, al menos 5 caracteres)' : 'Opcional') + '"></textarea>', { ancho: true, req: esAjuste });
        box.innerHTML = html;

        // origen (salidas): ubicacion + lote con saldo, preseleccionando la caja
        if (clase !== 'entrada' && repuesto) {
            try {
                const o = await ws('Origenes', { repuesto: repuesto.id, bodega: bodegaId });
                const s = $('fOrigen'); if (!s) return;
                const met = (caja && caja.userData.item.met) || (info && info.bodega.metodo) || 'FEFO';
                s.innerHTML = o.origenes.length ? o.origenes.map((x, i) =>
                    '<option value="' + x.ubicacion + '|' + x.lote + '">' + esc((x.ubicacionCodigo || 'Sin ubicación') + (x.loteCodigo ? ' · lote ' + x.loteCodigo : '') + ' · hay ' + num(x.cantidad) + (i === 0 ? ' · sugerido ' + met : '')) + '</option>').join('')
                    : '<option value="">Sin existencia en esta bodega</option>';
                if (caja) { const pre = o.origenes.find((x) => x.ubicacion === caja.userData.rack.id); if (pre) s.value = pre.ubicacion + '|' + pre.lote; }
            } catch (e) { aviso(e.message, true); }
        }
        if (clase === 'entrada' && repuesto && repuesto.lote) {
            try {
                const l = await ws('Lotes', { repuesto: repuesto.id });
                const s = $('fLote'); if (s) s.innerHTML = '<option value="">Lote nuevo…</option>' + l.lotes.map((x) => '<option value="' + x.id + '">' + esc(x.codigo + (x.vence ? ' · vence ' + x.vence : '')) + '</option>').join('');
            } catch (e) { aviso(e.message, true); }
        }
        const pk = $('fPick');
        if (pk) pk.onclick = () => iniciarPick('Haz clic en el rack de destino', (r) => { destinoRack = r; pintar(); marcarContorno(r, true); });
        const db = $('fDestBod');
        if (db) db.onchange = () => {
            const b = S.porBodega.get(+db.value);
            $('fDestUbicT').innerHTML = b && b.racks.length ? b.racks.map((r) => '<option value="' + r.id + '">' + esc(r.codigo) + '</option>').join('') : '<option value="">Sin ubicaciones</option>';
        };

        $('fGuardar').onclick = (e) => guardando(e.currentTarget, async () => {
            if (!repuesto) throw new Error('Elige el repuesto.');
            const d = { tipo, repuesto: repuesto.id, bodega: bodegaId, cantidad: val('fCant'), observacion: val('fObs') };
            if (clase === 'entrada') { d.ubicacion = val('fUbic'); d.lote = val('fLote'); d.loteNuevo = val('fLoteNuevo'); d.loteVence = val('fLoteVence'); d.costo = val('fCosto'); }
            else { const o = String(val('fOrigen') || '|').split('|'); d.origenUbicacion = o[0]; d.origenLote = o[1]; }
            if (clase === 'reubicacion') d.destinoUbicacion = val('fDestUbic');
            if (clase === 'traslado') { d.destinoBodega = val('fDestBod'); d.destinoUbicacion = val('fDestUbicT'); }
            if (tipo === 2 || tipo === 3) d.orden = val('fOT');
            const r = await ws('RegistrarMovimiento', { datos: JSON.stringify(d) });
            aviso(r.detalle || 'Movimiento registrado.');
            await refrescarStock(true);
            // queda seleccionada la caja del repuesto donde quedo
            const ubicFinal = clase === 'entrada' ? +d.ubicacion : clase === 'reubicacion' ? +d.destinoUbicacion : (caja ? caja.userData.rack.id : 0);
            const c = S.cajas.find((x) => x.userData.item.id === repuesto.id && x.userData.rack.id === ubicFinal) || S.cajas.find((x) => x.userData.item.id === repuesto.id && x.userData.rack.bodega.id === bodegaId);
            if (c) seleccionarCaja(c, true);
            else if (rack) { const rk = S.racks.find((x) => x.id === rack.id); if (rk) seleccionarRack(rk, false); else cerrarPanel(); }
            else cerrarPanel();
        });
    };
    pintar();
}
function reabrirSeleccion(volver) {
    if (S.sel && S.sel.isMesh) panelItem(S.sel);
    else if (S.sel) panelRack(S.sel);
    else if (volver) volver();
}

// ===================================================================== visor
const visor = $('bm3dVisor');
let visorFotos = [], visorI = 0, visorTitulo = '';
function abrirVisor(fotos, i, titulo) {
    visorFotos = fotos; visorI = i || 0; visorTitulo = titulo || '';
    pintarVisor(); visor.hidden = false;
}
function pintarVisor() {
    visor.querySelector('img').src = visorFotos[visorI];
    visor.querySelector('.bm3d-visor-pie').textContent = visorTitulo + (visorFotos.length > 1 ? ' · ' + (visorI + 1) + ' de ' + visorFotos.length : '');
    visor.querySelectorAll('.bm3d-visor-nav').forEach((b) => b.hidden = visorFotos.length < 2);
}
async function abrirGaleria(repId, titulo, portada) {
    abrirVisor([portada], 0, titulo);
    try {
        const f = await ws('FichaRepuesto', { id: repId });
        if (f.fotos && f.fotos.length) { visorFotos = f.fotos.map((x) => x.url); visorI = Math.max(0, visorFotos.indexOf(portada)); pintarVisor(); }
    } catch (e) { /* queda la portada */ }
}
visor.querySelector('.bm3d-visor-cerrar').onclick = () => { visor.hidden = true; };
visor.querySelector('.es-ant').onclick = () => { visorI = (visorI - 1 + visorFotos.length) % visorFotos.length; pintarVisor(); };
visor.querySelector('.es-sig').onclick = () => { visorI = (visorI + 1) % visorFotos.length; pintarVisor(); };
visor.onclick = (e) => { if (e.target === visor) visor.hidden = true; };

// ============================================================================
//  RECORRIDO DE PASILLO — primera persona, con la tablet en la mano
// ----------------------------------------------------------------------------
//  El bodeguero entra al pasillo, camina despacio y en cada rack se detiene,
//  gira la cabeza y lo recorre con la vista de arriba abajo. A medida que la
//  mirada pasa por cada nivel, la tablet lista lo que hay en esas cajas (con
//  foto, cantidad y estado) y lo que esta bajo minimo queda marcado en rojo
//  sobre la caja, para verlo al mirar hacia atras.
//
//  Se puede pausar (espacio), pasar al rack siguiente o anterior (flechas),
//  tocar un rack en la tablet o en la escena para revisarlo en detalle, o
//  tocar una caja para ver su ficha. Al terminar, la tablet deja el resumen.
// ============================================================================
const cine = $('bm3dCine'), tablet = $('bm3dTablet'), callouts = $('bm3dCallouts');
const VEL = [0.5, 1, 2];

function iniciarRecorrido(pa, desdeRack, opciones) {
    if (!pa || !pa.racks.length) return;
    const previo = S.tour;
    opciones = opciones || {};
    // el conteo sigue abierto si se pasa a otro pasillo de la misma bodega
    let conteo = previo && previo.conteoId && !previo.conteoCerrado && previo.pa.info.id === pa.info.id ? { id: previo.conteoId, stats: previo.cuenta } : null;
    if (previo && previo.conteoId && !conteo) cerrarConteo(previo, true);
    if (previo) limpiarRecorrido();
    cerrarPanel(); cerrarFicha(); terminarPick(); soltarSeleccion(); marcarContorno(null);
    if (S.filtro.size) { S.filtro.clear(); aplicarFiltros(); }
    if (S.modo !== 'normal') cambiarModo('normal');
    if (pa.info.id !== S.bodegaSel) elegirBodega(pa.info.id, true);

    const paradas = pa.racks.map((r) => ({
        rack: r, lado: r.lado, z: r.pos.z,
        cara: r.pos.x + r.normal.x * (RACK.prof / 2),
        cajas: r.cajas.slice().sort((a, b) => (b.userData.nivel - a.userData.nivel) || (a.userData.posicion - b.userData.posicion) || (a.userData.fila - b.userData.fila))
    }));
    S.tour = {
        pa, paradas, vel: previo ? previo.vel : 1, idx: 0, cola: [], seg: null, reloj: 0, pausado: false, terminado: false, final: false,
        pos: new THREE.Vector3(pa.x, OJOS, pa.z0 - 2.4), mira: new THREE.Vector3(pa.x, 1.45, pa.z0 + 3),
        yaw: 0, pitch: 0, fase: 0, andando: 0,
        vistos: new Set(), revisados: new Set(), alertas: [], marcas: new Map(), destellos: [], etiquetas: [],
        camGuardada: previo ? previo.camGuardada : { pos: camera.position.clone(), target: controls.target.clone() },
        inicio: performance.now(), detalle: null, revisarIdx: -1,
        conteo: !!S.permisos.ajuste && (opciones.conteo != null ? !!opciones.conteo : !!(previo && previo.conteo)),
        conteoId: conteo ? conteo.id : 0, cuenta: conteo ? conteo.stats : { lineas: 0, coinciden: 0, ajustes: 0, cajas: {} },
        contados: new Set(), contando: null, huboAjustes: !!(previo && previo.huboAjustes)
    };
    const T = S.tour;
    controls.enabled = false;
    S.vuelo = null;
    S.fovMeta = FOV_RECORRIDO;
    linterna.intensity = 5;

    if (desdeRack) {
        const i = paradas.findIndex((p) => p.rack === desdeRack);
        if (i > 0) { T.idx = i; T.pos.z = paradas[i].z - 2.2; T.mira.z = T.pos.z + 5; }
        if (i >= 0 && opciones.revisar) T.revisarIdx = i;
    }

    root.classList.add('en-recorrido');
    armarCine(!previo);
    armarTablet();
    armarLaser();

    // entrada de pelicula: la camara baja desde donde estaba hasta los ojos del bodeguero
    const mirandoA = camera.position.clone().add(camera.getWorldDirection(new THREE.Vector3()).multiplyScalar(6));
    T.intro = { t0: performance.now(), dur: previo ? 1600 : 2800, p0: camera.position.clone(), q0: mirandoA };
}

function armarCine(titulo) {
    const T = S.tour, pa = T.pa;
    const reps = pa.racks.reduce((s, r) => s + r.items.length, 0);
    const bajos = pa.racks.reduce((s, r) => s + r.items.filter((i) => estadoDe(i) === 'bajo').length, 0);
    cine.innerHTML =
        '<div class="bm3d-cine-barra es-arriba"><span class="bm3d-cine-rec"><i></i>REC</span><span class="bm3d-cine-nom">RECORRIDO · PASILLO ' + esc(pa.nom) + ' · ' + esc(pa.info.bodega.nombre.toUpperCase()) + '</span><span class="bm3d-cine-tc" id="cineTc">00:00</span></div>' +
        '<div class="bm3d-cine-barra es-abajo"><span><kbd>Espacio</kbd> pausa</span><span><kbd>←</kbd><kbd>→</kbd> rack anterior / siguiente</span><span>Arrastra para mirar · clic en una caja para su detalle</span><span><kbd>Esc</kbd> salir</span></div>' +
        '<div class="bm3d-cine-vineta"></div>' +
        '<div class="bm3d-cine-titulo' + (titulo ? '' : ' es-sale') + '" id="cineTitulo"><small>' + esc(pa.info.bodega.nombre) + '</small><b>Pasillo ' + esc(pa.nom) + '</b>' +
            '<span>' + pa.racks.length + ' racks · ' + reps + ' repuestos' + (bajos ? ' · <em>' + bajos + ' bajo mínimo</em>' : '') + '</span></div>';
    cine.hidden = false;
    requestAnimationFrame(() => cine.classList.add('is-visible'));
}

// ------------------------------------------------------------------ tablet
function armarTablet() {
    const T = S.tour, pa = T.pa;
    tablet.innerHTML =
        // las manos van detras del equipo y los pulgares delante: asi lo "sostienen"
        '<div class="bm3d-tb-mano es-izq"><i class="manga"></i><i class="palma"></i></div>' +
        '<div class="bm3d-tb-mano es-der"><i class="manga"></i><i class="palma"></i></div>' +
        '<div class="bm3d-tb-equipo"><span class="bm3d-tb-camara"></span><div class="bm3d-tb-pantalla">' +
            '<div class="bm3d-tb-sb"><b>SIGMA</b><span id="tbHora"></span><span><i class="mdi mdi-wifi"></i><i class="mdi mdi-battery-80"></i></span></div>' +
            '<div class="bm3d-tb-app">' +
                '<div class="bm3d-tb-cab"><div><small>' + esc(pa.info.bodega.nombre) + '</small><b>Pasillo ' + esc(pa.nom) + '</b></div><span class="bm3d-tb-rec" id="tbRec"><i></i>EN VIVO</span></div>' +
                '<div class="bm3d-tb-stats" id="tbStats"></div>' +
                '<div class="bm3d-tb-racks" id="tbRacks">' + T.paradas.map((p, i) =>
                    '<button type="button" class="bm3d-tb-rack" data-tb-rack="' + i + '" title="' + esc(p.rack.codigo) + '"><span>' + esc(corto(p.rack.codigo)) + '</span><small>' + (p.lado === 'izq' ? 'IZQ' : 'DER') + '</small></button>').join('') + '</div>' +
                '<div class="bm3d-tb-actual" id="tbActual"></div>' +
                '<div class="bm3d-tb-lista" id="tbLista"></div>' +
                '<div class="bm3d-tb-alertas" id="tbAlertas" hidden></div>' +
                '<div class="bm3d-tb-ctrl">' +
                    '<button type="button" data-tb="ant" title="Rack anterior"><i class="mdi mdi-skip-previous"></i></button>' +
                    '<button type="button" data-tb="pausa" class="es-play" title="Pausa"><i class="mdi mdi-pause"></i></button>' +
                    '<button type="button" data-tb="sig" title="Rack siguiente"><i class="mdi mdi-skip-next"></i></button>' +
                    '<button type="button" data-tb="vel" class="es-vel" title="Velocidad">1×</button>' +
                    (S.permisos.ajuste ? '<button type="button" data-tb="conteo" class="es-conteo" title="Contar cada rack al pasar"><i class="mdi mdi-clipboard-check-outline"></i>Contar</button>' : '') +
                    '<button type="button" data-tb="salir" class="es-salir" title="Salir del recorrido"><i class="mdi mdi-exit-run"></i>Salir</button>' +
                '</div>' +
            '</div>' +
            '<div class="bm3d-tb-detalle" id="tbDetalle" hidden></div>' +
            '<div class="bm3d-tb-conteo" id="tbConteo" hidden></div>' +
        '</div></div>' +
        '<i class="bm3d-tb-pulgar es-izq"></i><i class="bm3d-tb-pulgar es-der"></i>';
    tablet.hidden = false;
    requestAnimationFrame(() => tablet.classList.add('is-visible'));
    tablet.querySelectorAll('[data-tb-rack]').forEach((b) => b.onclick = () => saltarA(+b.dataset.tbRack, true));
    tablet.querySelector('[data-tb="ant"]').onclick = () => saltarRelativo(-1);
    tablet.querySelector('[data-tb="sig"]').onclick = () => saltarRelativo(1);
    tablet.querySelector('[data-tb="pausa"]').onclick = () => pausar(!S.tour.pausado);
    tablet.querySelector('[data-tb="vel"]').onclick = () => { const t2 = S.tour; t2.vel = VEL[(VEL.indexOf(t2.vel) + 1) % VEL.length]; estadoTablet(); };
    tablet.querySelector('[data-tb="salir"]').onclick = salirRecorrido;
    const bc = tablet.querySelector('[data-tb="conteo"]');
    if (bc) bc.onclick = () => {
        const t2 = S.tour; t2.conteo = !t2.conteo;
        aviso(t2.conteo ? 'Modo conteo: el recorrido se detiene en cada rack para contar.' : 'Modo conteo desactivado.');
        // si ya termino de mirar el rack actual, se cuenta ahora mismo
        if (t2.conteo && t2.seg && t2.seg.tipo === 'mira' && t2.seg.hecho && !t2.contados.has(t2.seg.parada.rack)) { t2.pausado = true; mostrarConteo(t2.seg.parada); }
        estadoTablet();
    };
    $('tbActual').innerHTML = '<div class="bm3d-tb-espera"><i class="mdi mdi-walk"></i>Entrando al pasillo…</div>';
    estadoTablet();
}
function estadoTablet() {
    const T = S.tour; if (!T) return;
    if (T.modo === 'picking') { estadoPicking(); return; }
    const total = T.paradas.length;
    $('tbStats').innerHTML =
        '<div><b>' + T.vistos.size + '<small>/' + total + '</small></b><span>Racks</span></div>' +
        '<div><b>' + T.revisados.size + '</b><span>Repuestos</span></div>' +
        '<div class="' + (T.alertas.length ? 'es-alerta' : '') + '"><b>' + T.alertas.length + '</b><span>Bajo mín.</span></div>' +
        (T.conteo || T.cuenta.lineas ? '<div class="es-conteo"><b>' + (T.cuenta.lineas ? Math.round(T.cuenta.coinciden * 100 / T.cuenta.lineas) + '<small>%</small>' : '—') + '</b><span>Exactitud</span></div>' : '');
    $('tbStats').classList.toggle('es-cuatro', !!(T.conteo || T.cuenta.lineas));
    tablet.querySelectorAll('[data-tb-rack]').forEach((b, i) => {
        const p = T.paradas[i];
        b.classList.toggle('es-actual', !!(T.seg && T.seg.tipo === 'mira' && T.seg.parada === p && (!T.seg.hecho || T.pausado)));
        b.classList.toggle('es-visto', T.vistos.has(p.rack));
        b.classList.toggle('es-alerta', T.alertas.some((a) => a.userData.rack === p.rack));
        b.classList.toggle('es-contado', T.contados.has(p.rack));
    });
    const rec = $('tbRec');
    rec.className = 'bm3d-tb-rec' + (T.pausado ? ' es-pausa' : '') + (T.final ? ' es-fin' : '');
    rec.innerHTML = '<i></i>' + (T.final ? 'COMPLETO' : T.pausado ? 'EN PAUSA' : 'EN VIVO');
    const bp = tablet.querySelector('[data-tb="pausa"]');
    bp.innerHTML = '<i class="mdi ' + (T.pausado ? 'mdi-play' : 'mdi-pause') + '"></i>';
    bp.title = T.pausado ? 'Continuar' : 'Pausa';
    bp.disabled = T.final;
    tablet.querySelector('[data-tb="vel"]').textContent = (T.vel === 0.5 ? '½' : T.vel) + '×';
    tablet.classList.toggle('es-pausa', T.pausado);
    const bcn = tablet.querySelector('[data-tb="conteo"]'); if (bcn) bcn.classList.toggle('is-on', T.conteo);
    cine.classList.toggle('es-pausa', T.pausado && !T.final);
}
function tabletRack(p, revisar) {
    const r = p.rack, n = r.items.length;
    const bajos = r.items.filter((i) => estadoDe(i) === 'bajo').length;
    $('tbActual').innerHTML =
        '<div class="bm3d-tb-rackcab"><div><small>' + (revisar ? 'Revisando' : 'Mirando') + ' · lado ' + (p.lado === 'izq' ? 'izquierdo' : 'derecho') + '</small><b>' + esc(r.codigo) + '</b></div>' +
        '<span class="bm3d-tb-cuenta" id="tbCuenta">0/' + n + '</span></div>' +
        '<div class="bm3d-tb-progreso"><i id="tbProg"></i></div>' +
        textoUltimoConteo(r, 'tb') +
        (bajos && revisar ? '<div class="bm3d-tb-nota"><i class="mdi mdi-alert"></i>' + bajos + ' bajo mínimo en este rack</div>' : '');
    $('tbLista').innerHTML = n ? '' : '<div class="bm3d-tb-espera"><i class="mdi mdi-package-variant-closed-remove"></i>Rack vacío: sin stock registrado.</div>';
    estadoTablet();
}
function tabletItem(c, n, total) {
    const it = c.userData.item, e = estadoDe(it), lista = $('tbLista');
    const fila = document.createElement('div');
    fila.className = 'bm3d-tb-item es-entra' + (e === 'bajo' ? ' es-bajo' : e === 'sobre' ? ' es-sobre' : '');
    fila.innerHTML = miniatura(it.foto, it.color) +
        '<div><b>' + esc(it.c) + '</b><span>' + esc(it.n) + '</span><small>' + c.userData.nivel + '-' + pad2(c.userData.posicion) + ' · ' + esc(it.tn) + '</small></div>' +
        '<em>' + num(it.q) + '<small>' + (e === 'bajo' ? 'mín. ' + num(it.min) : esc(it.un)) + '</small></em>';
    fila.onclick = () => { pausar(true); detalleTablet(c); };
    lista.appendChild(fila);
    lista.scrollTop = lista.scrollHeight;
    const cu = $('tbCuenta'); if (cu) cu.textContent = n + '/' + total;
    const pg = $('tbProg'); if (pg) pg.style.width = (total ? (n / total) * 100 : 100) + '%';
}
function alertasTablet() {
    const T = S.tour, el = $('tbAlertas');
    el.hidden = !T.alertas.length;
    el.innerHTML = '<div class="bm3d-tb-alertas-tit"><i class="mdi mdi-alert"></i>Bajo mínimo detectado · ' + T.alertas.length + '</div>' +
        '<div class="bm3d-tb-alertas-lista">' + T.alertas.map((c, i) => '<button type="button" data-tb-alerta="' + i + '"><b>' + esc(c.userData.item.c) + '</b><span>' + esc(corto(c.userData.rack.codigo)) + ' · ' + c.userData.nivel + '-' + pad2(c.userData.posicion) + '</span><em>' + num(c.userData.item.q) + '/' + num(c.userData.item.min) + '</em></button>').join('') + '</div>';
    el.querySelectorAll('[data-tb-alerta]').forEach((b) => b.onclick = () => irACajaRecorrido(T.alertas[+b.dataset.tbAlerta]));
}
function detalleTablet(c) {
    const T = S.tour; if (!T) return;
    const it = c.userData.item, e = estadoDe(it), d = $('tbDetalle');
    if (T.detalle && T.detalle !== c) T.detalle.userData.sacar = 0;
    T.detalle = c;
    c.userData.sacar = c.userData.fila === 1 ? 0.5 : 0.22;
    const tope = it.max || (it.min ? it.min * 2 : Math.max(it.q, 1));
    d.innerHTML =
        '<button type="button" class="bm3d-tb-volver" id="tbVolver"><i class="mdi mdi-arrow-left"></i>Recorrido</button>' +
        (it.foto ? '<div class="bm3d-tb-foto"><img src="' + esc(it.foto) + '" alt="" /></div>' : '<div class="bm3d-tb-foto es-vacia"><i class="mdi mdi-image-off-outline"></i>Sin foto</div>') +
        '<div class="bm3d-tb-det-cod">' + esc(it.c) + '</div><h4>' + esc(it.n) + '</h4>' +
        '<div class="bm3d-tb-det-ubi"><i class="mdi mdi-map-marker-outline"></i>' + esc(ubicTexto(c)) + '</div>' +
        '<div class="bm3d-stock"><div><b>' + num(it.q) + '</b><span>' + esc(it.un) + '</span></div><div><b>' + num(it.min) + '</b><span>Mínimo</span></div><div><b>' + num(it.max) + '</b><span>Máximo</span></div></div>' +
        '<div class="bm3d-barra-stock"><i style="width:' + Math.max(3, Math.min(100, it.q / tope * 100)) + '%;background:' + COLOR_ESTADO[e === 'sin' ? 'ok' : e] + '"></i></div>' +
        '<div class="bm3d-umbral"><span>' + esc(it.tn) + '</span><span class="bm3d-estado-chip es-' + e + '">' + ESTADO_TXT[e] + '</span></div>' +
        '<div class="bm3d-tb-det-acc"><button type="button" class="bm3d-btn es-contorno es-chico" id="tbFicha"><i class="mdi mdi-card-account-details-outline"></i>Ver ficha</button>' +
        '<button type="button" class="bm3d-btn es-ghost es-chico" id="tbSeguir"><i class="mdi mdi-play"></i>Seguir</button></div>';
    d.hidden = false;
    $('tbVolver').onclick = cerrarDetalleTablet;
    $('tbFicha').onclick = () => abrirFicha(it.id);
    $('tbSeguir').onclick = () => { cerrarDetalleTablet(); pausar(false); };
}
function cerrarDetalleTablet() {
    const T = S.tour; if (!T) return;
    if (T.detalle) T.detalle.userData.sacar = 0;
    T.detalle = null;
    $('tbDetalle').hidden = true;
}
function resumenTablet() {
    const T = S.tour, pa = T.pa, info = pa.info;
    const otros = info.pasillos.filter((p) => p !== pa && p.nom !== '·' && p.racks.length);
    const seg = Math.round((performance.now() - T.inicio) / 1000);
    $('tbActual').innerHTML =
        '<div class="bm3d-tb-resumen"><i class="mdi mdi-check-decagram"></i><b>Recorrido completo</b>' +
        '<span>' + T.vistos.size + ' racks · ' + T.revisados.size + ' repuestos revisados en ' + Math.floor(seg / 60) + ':' + pad2(seg % 60) + '</span>' +
        (T.alertas.length ? '<em>' + T.alertas.length + ' bajo mínimo: revisa la lista y gestiona la reposición.</em>' : '<em class="es-ok">Todo el pasillo dentro de umbral.</em>') + '</div>';
    $('tbLista').innerHTML =
        '<div class="bm3d-tb-fin">' +
        '<button type="button" class="bm3d-btn es-primario es-chico" id="tbRepetir"><i class="mdi mdi-replay"></i>Repetir</button>' +
        otros.map((p) => '<button type="button" class="bm3d-btn es-contorno es-chico" data-tb-pasillo="' + info.pasillos.indexOf(p) + '"><i class="mdi mdi-walk"></i>Pasillo ' + esc(p.nom) + '</button>').join('') +
        '<button type="button" class="bm3d-btn es-ghost es-chico" id="tbSalir2"><i class="mdi mdi-exit-run"></i>Salir</button></div>';
    if (T.conteoId) resumenConteo(T);
    $('tbRepetir').onclick = () => iniciarRecorrido(pa);
    $('tbSalir2').onclick = salirRecorrido;
    tablet.querySelectorAll('[data-tb-pasillo]').forEach((b) => b.onclick = () => iniciarRecorrido(info.pasillos[+b.dataset.tbPasillo]));
}

// ----------------------------------------------------------- efectos 3D
let laser = null;
function armarLaser() {
    const g = new THREE.Group();
    const linea = new THREE.Mesh(new THREE.PlaneGeometry(RACK.ancho + 0.1, 0.014), MAT.laser);
    const estela = new THREE.Mesh(new THREE.PlaneGeometry(RACK.ancho + 0.1, 0.45), MAT.estela);
    estela.position.y = 0.225;
    g.add(linea, estela);
    g.visible = false;
    capaRecorrido.add(g);
    laser = g;
}
function ponerLaser(p, y) {
    if (!laser) return;
    laser.visible = y != null;
    if (y == null) return;
    laser.position.copy(enRack(p.rack, 0, y, RACK.prof / 2 + 0.16));
    laser.rotation.set(0, p.rack.rot, 0);
}
const GEO_UNIDAD = new THREE.BoxGeometry(1, 1, 1);
const GEO_UNIDAD_BORDES = new THREE.EdgesGeometry(GEO_UNIDAD);
function destello(c, color) {
    const m = new THREE.Mesh(GEO_UNIDAD, new THREE.MeshBasicMaterial({ color: color || '#16C6C9', transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
    const u = c.userData;
    m.scale.set(u.w + 0.03, u.h + 0.03, u.d + 0.03);
    c.add(m);
    S.tour.destellos.push({ m, t0: performance.now(), base: m.scale.clone() });
}
let texBajo = null;
function marcarBajo(c) {
    const T = S.tour;
    if (T.marcas.has(c)) return;
    if (!texBajo) {
        const cv = canvas(320, 112), g = cv.getContext('2d');
        g.fillStyle = '#C7352B'; rrect(g, 4, 4, 312, 76, 38); g.fill();
        g.beginPath(); g.moveTo(144, 78); g.lineTo(176, 78); g.lineTo(160, 104); g.closePath(); g.fill();
        g.fillStyle = '#FFFFFF'; g.font = `900 36px ${FUENTE}`; g.textAlign = 'center'; g.textBaseline = 'middle';
        g.fillText('BAJO MÍNIMO', 160, 43);
        texBajo = tex(cv);
    }
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: texBajo, depthTest: false, depthWrite: false, toneMapped: false, transparent: true }));
    sp.renderOrder = 20;
    sp.scale.set(0.46, 0.161, 1);
    sp.position.set(0, c.userData.h / 2 + 0.13, 0);
    const borde = new THREE.LineSegments(GEO_UNIDAD_BORDES, MAT.marca);
    borde.scale.set(c.userData.w + 0.05, c.userData.h + 0.05, c.userData.d + 0.05);
    borde.renderOrder = 19;
    c.add(sp, borde);
    T.marcas.set(c, [sp, borde]);
}

/* Etiquetas flotantes de las cajas del rack que se esta mirando: el codigo y
   la cantidad aparecen sobre cada caja a medida que la mirada pasa. */
function etiquetaFlotante(c) {
    const it = c.userData.item, e = estadoDe(it);
    const el = document.createElement('div');
    el.className = 'bm3d-callout' + (e === 'bajo' ? ' es-bajo' : '');
    el.innerHTML = '<b>' + esc(it.c) + '</b><span>' + num(it.q) + ' ' + esc(it.un) + (e === 'bajo' ? ' · mín. ' + num(it.min) : '') + '</span>';
    callouts.appendChild(el);
    S.tour.etiquetas.push({ el, c });
}
function limpiarFlotantes(suaveSalida) {
    const T = S.tour; if (!T) return;
    for (const x of T.etiquetas) {
        if (suaveSalida) { x.el.classList.add('es-sale'); setTimeout(() => x.el.remove(), 420); } else x.el.remove();
    }
    T.etiquetas = [];
}
const _p = new THREE.Vector3();
function moverFlotantes() {
    const T = S.tour, w = escenaEl.clientWidth, h = escenaEl.clientHeight;
    for (const x of T.etiquetas) {
        x.c.getWorldPosition(_p); _p.y += x.c.userData.h / 2 + 0.02;
        _p.project(camera);
        const visible = _p.z < 1 && Math.abs(_p.x) < 1.1 && Math.abs(_p.y) < 1.1;
        x.el.style.display = visible ? '' : 'none';
        if (visible) x.el.style.transform = 'translate(' + ((_p.x + 1) / 2 * w).toFixed(1) + 'px,' + ((1 - _p.y) / 2 * h).toFixed(1) + 'px) translate(-50%,-100%)';
    }
}

// ------------------------------------------------------- linea de tiempo
function pausar(si) {
    const T = S.tour; if (!T || T.intro) return;
    if (T.final && !si) return;
    T.pausado = si;
    if (!si) cerrarConteoTablet();
    estadoTablet();
}
function saltarRelativo(d) {
    const T = S.tour; if (!T) return;
    let actual = T.seg && T.seg.parada ? T.paradas.indexOf(T.seg.parada) : T.idx - 1;
    if (actual < 0) actual = d > 0 ? -1 : 0;
    saltarA(Math.max(0, Math.min(T.paradas.length - 1, actual + d)), T.pausado);
}
/* Ir a un rack: se camina (rapido) hasta el y se lo recorre. Con revisar, al
   terminar de mirarlo el recorrido queda en pausa frente a el. */
function saltarA(i, revisar) {
    const T = S.tour; if (!T || T.intro) return;
    cerrarDetalleTablet();
    cerrarConteoTablet();
    if (T.seg && !T.seg.hecho) cerrarSegmento(T.seg, true);
    T.seg = null; T.cola = []; T.idx = i; T.revisarIdx = revisar ? i : -1;
    T.final = false; T.terminado = false; T.pausado = false; T.prisa = true;
    estadoTablet();
}
function irACajaRecorrido(c) {
    const T = S.tour; if (!T) return;
    const i = T.paradas.findIndex((p) => p.rack === c.userData.rack);
    if (i < 0) return;
    saltarA(i, true);
    T.detallePendiente = c;
}

function planificar() {
    const T = S.tour;
    if (T.modo === 'picking') return planificarPicking();
    if (T.cola.length) return empezar(T.cola.shift());
    if (T.terminado) return null;
    if (T.idx < T.paradas.length) {
        const p = T.paradas[T.idx], i = T.idx++;
        const prisa = T.prisa; T.prisa = false;
        if (Math.abs(T.pos.z - (p.z - 0.15)) > 0.08 || Math.abs(T.pos.x - T.pa.x) > 0.05) T.cola.push({ tipo: 'camina', zb: p.z - 0.15, prisa });
        T.cola.push({ tipo: 'mira', parada: p, revisar: T.revisarIdx === i });
        return empezar(T.cola.shift());
    }
    T.terminado = true;
    T.cola.push({ tipo: 'camina', zb: T.pa.z1 + 1.2 }, { tipo: 'vuelta' });
    return empezar(T.cola.shift());
}
function empezar(s) {
    const T = S.tour;
    s.t0 = T.reloj;
    s.xa = T.pos.x; s.za = T.pos.z;
    if (s.tipo === 'camina') {
        if (s.xb == null) s.xb = T.pa.x;
        if (s.entra) T.pa = s.entra;
        if (s.dirigir) T.sentido = s.dirigir;
        s.dur = Math.max(0.6, Math.hypot(s.xb - s.xa, s.zb - s.za) / (s.prisa ? 2.6 : 0.95));
    }
    if (s.tipo === 'pick') { s.dur = 1e9; mostrarPick(s); }
    if (s.tipo === 'mira') {
        const n = s.parada.cajas.length;
        s.dur = n ? Math.min(8.5, Math.max(3.2, 2.2 + n * 0.25)) : 2.2;
        s.k = 0;
        limpiarFlotantes(true);
        tabletRack(s.parada, s.revisar);
    }
    if (s.tipo === 'vuelta') { s.dur = 3.2; limpiarFlotantes(true); }
    estadoTablet();
    return s;
}
/* Fin de un segmento. Con "corte" (se salto a otro rack) no se marca nada
   como visto: no se alcanzo a mirar. */
function cerrarSegmento(s, corte) {
    const T = S.tour;
    s.hecho = true;
    if (s.tipo === 'mira') {
        ponerLaser(null);
        if (!corte) {
            while (s.k < s.parada.cajas.length) { s.k++; revelar(s, s.parada.cajas[s.k - 1]); }
            T.vistos.add(s.parada.rack);
            if (T.conteo && s.parada.cajas.length && !T.contados.has(s.parada.rack)) {
                T.pausado = true; T.revisarIdx = -1;
                mostrarConteo(s.parada);
            } else if (s.revisar) {
                T.pausado = true; T.revisarIdx = -1;
                if (T.detallePendiente) { detalleTablet(T.detallePendiente); T.detallePendiente = null; }
            }
        }
    }
    if (s.tipo === 'pick') {
        if (!corte) T.vistos.add(s.parada.rack);
        for (const c of s.parada.cajas) c.userData.sacar = 0;
        marcarContorno(null); limpiarFlotantes(true);
    }
    if (s.tipo === 'vuelta' && !corte) { T.final = true; T.pausado = true; if (T.modo === 'picking') resumenPicking(); else resumenTablet(); }
    estadoTablet();
}
function revelar(s, c) {
    const T = S.tour;
    T.revisados.add(c);
    tabletItem(c, s.k, s.parada.cajas.length);
    etiquetaFlotante(c);
    const bajo = estadoDe(c.userData.item) === 'bajo';
    destello(c, bajo ? '#FF4D42' : '#16C6C9');
    if (bajo) {
        marcarBajo(c);
        if (!T.alertas.includes(c)) { T.alertas.push(c); alertasTablet(); }
    }
}

const _desea = new THREE.Vector3(), _dir = new THREE.Vector3(), _eje = new THREE.Vector3(0, 1, 0);
function pasoRecorrido(dt, ahora) {
    const T = S.tour, pa = T.pa;
    const hora = $('tbHora'); if (hora) hora.textContent = new Date().toLocaleTimeString('es-CL', { hour: '2-digit', minute: '2-digit' });

    // ---- entrada
    if (T.intro) {
        const t = clamp01((ahora - T.intro.t0) / T.intro.dur), e = suave(t);
        camera.position.lerpVectors(T.intro.p0, T.pos, e);
        camera.position.y += Math.sin(e * Math.PI) * 2.5;
        _desea.lerpVectors(T.intro.q0, T.mira, Math.min(1, e * 1.2));
        camera.lookAt(_desea);
        if (t > 0.72) { const ti = $('cineTitulo'); if (ti) ti.classList.add('es-sale'); }
        if (t >= 1) { T.intro = null; estadoTablet(); }
        return;
    }

    if (!T.pausado) T.reloj += dt * T.vel;
    let s = T.seg;
    if (s && !s.hecho && T.reloj - s.t0 >= s.dur) cerrarSegmento(s, false);
    if ((!s || s.hecho) && !T.pausado) s = T.seg = planificar();

    // ---- pose segun el segmento
    let andando = false;
    if (s) {
        const p = clamp01((T.reloj - s.t0) / s.dur);
        if (s.tipo === 'camina') {
            const e = paso(p);
            T.pos.x = lerp(s.xa, s.xb, e);
            T.pos.z = lerp(s.za, s.zb, e);
            andando = !s.hecho;
            // se mira hacia donde se camina: a lo largo del pasillo, o por el pasillo de cruce
            const dx = s.xb - s.xa, dz = s.zb - s.za, cruza = Math.abs(dx) > Math.abs(dz);
            const sentido = Math.sign(cruza ? dx : dz) || 1;
            if (cruza) _desea.set(T.pos.x + sentido * 4.5, 1.45, T.pos.z + Math.sin(T.fase * 0.5) * 0.12);
            else _desea.set(s.xb + Math.sin(T.fase * 0.5) * 0.12, 1.45, T.pos.z + sentido * 4.5);
        } else if (s.tipo === 'mira') {
            const pd = s.parada, lado = pd.lado === 'izq' ? 1 : -1;
            // se aparta hacia el otro lado del pasillo para ver el rack entero, y al terminar vuelve al centro
            const o = paso(Math.min(1, p / 0.16)) * (s.revisar && s.hecho ? 1 : paso(Math.min(1, (1 - p) / 0.14)));
            T.pos.x = lerp(s.xa, pd.cara + pd.rack.normal.x * (PASILLO / 2 + 0.5), o);
            T.pos.z = s.za;
            // la mirada baja del nivel 4 al 1 y la tablet lista lo que va pasando
            const pe = clamp01((p - 0.1) / 0.78), y = lerp(3.05, 0.22, suave(pe));
            _desea.set(pd.cara, s.hecho ? 1.35 : y, pd.z + Math.sin(p * Math.PI * 2) * 0.32);
            if (!s.hecho) {
                ponerLaser(pd, pe > 0 && pe < 1 ? y : null);
                while (s.k < pd.cajas.length) {
                    const c = pd.cajas[s.k], u = c.userData;
                    if (u.base.y + u.h / 2 + u.posicion * 0.02 < y) break;
                    s.k++;
                    revelar(s, c);
                }
                const pg = $('tbProg'); if (pg && !pd.cajas.length) pg.style.width = (p * 100) + '%';
            }
        } else if (s.tipo === 'pick') {
            // se arrima al otro lado del pasillo y mira la caja que hay que sacar
            const pd = s.parada, lado = pd.lado === 'izq' ? 1 : -1;
            const o = paso(clamp01((T.reloj - s.t0) / 0.9));
            T.pos.x = lerp(s.xa, pd.cara + pd.rack.normal.x * (PASILLO / 2 + 0.45), o);
            T.pos.z = s.za;
            if (s.caja) _desea.copy(s.caja.userData.base); else _desea.set(pd.cara, 1.3, pd.z);
        } else if (s.tipo === 'vuelta') {
            // al final se da vuelta y mira el pasillo recorrido: las marcas rojas quedan a la vista
            const th = Math.PI * paso(p);
            _desea.set(pa.x + Math.sin(th) * 4, lerp(1.45, 1.1, p), T.pos.z + Math.cos(th) * 4.5);
        }
    } else _desea.copy(T.mira);

    // ---- andar: balanceo de cabeza y de la tablet
    T.andando = lerp(T.andando, andando && !T.pausado ? 1 : 0, Math.min(1, dt * 5));
    if (andando && !T.pausado) T.fase += dt * T.vel * (s && s.prisa ? 10 : 7.6);
    const respira = Math.sin(ahora / 900) * 0.006;
    const bobY = Math.sin(T.fase * 2) * 0.022 * T.andando + respira;
    const bobX = Math.sin(T.fase) * 0.018 * T.andando;

    T.mira.lerp(_desea, 1 - Math.exp(-dt * 3.4));
    if (!arrastre && !T.pausado) { T.yaw *= Math.exp(-dt * 1.4); T.pitch *= Math.exp(-dt * 1.4); }
    camera.position.set(T.pos.x + bobX, OJOS + bobY, T.pos.z);
    _dir.subVectors(T.mira, camera.position).applyAxisAngle(_eje, T.yaw);
    const hl = Math.hypot(_dir.x, _dir.z);
    _dir.y += Math.tan(T.pitch) * hl;
    camera.lookAt(_desea.copy(camera.position).add(_dir));
    linterna.position.set(camera.position.x, camera.position.y + 0.4, camera.position.z);

    tablet.style.setProperty('--bob-y', (Math.sin(T.fase * 2) * 5 * T.andando + respira * 300).toFixed(2) + 'px');
    tablet.style.setProperty('--bob-r', (Math.sin(T.fase) * 0.7 * T.andando).toFixed(3) + 'deg');

    // ---- destellos que se apagan, marcas que laten
    for (let i = T.destellos.length - 1; i >= 0; i--) {
        const d = T.destellos[i], t = (ahora - d.t0) / 700;
        if (t >= 1) { if (d.m.parent) d.m.parent.remove(d.m); d.m.material.dispose(); T.destellos.splice(i, 1); continue; }
        d.m.material.opacity = 0.55 * (1 - t);
        d.m.scale.copy(d.base).multiplyScalar(1 + t * 0.12);
    }
    MAT.marca.opacity = 0.55 + 0.45 * Math.sin(ahora / 180);
    moverFlotantes();

    const tc = Math.round((performance.now() - T.inicio) / 1000), ctc = $('cineTc');
    if (ctc) ctc.textContent = pad2(Math.floor(tc / 60)) + ':' + pad2(tc % 60);
}

function moverRecorrido(ev) {
    const T = S.tour;
    if (arrastre) {
        T.yaw = Math.max(-2.6, Math.min(2.6, T.yaw - (ev.clientX - arrastre.x) * 0.0035));
        T.pitch = Math.max(-0.9, Math.min(0.8, T.pitch - (ev.clientY - arrastre.y) * 0.003));
        arrastre.x = ev.clientX; arrastre.y = ev.clientY;
        return;
    }
    if (performance.now() - ultimoMov < 60) return;
    ultimoMov = performance.now();
    const h = intersectar(ev, true);
    renderer.domElement.style.cursor = h ? 'pointer' : 'grab';
}
function clicRecorrido(ev) {
    const T = S.tour, h = intersectar(ev, true);
    if (!h || T.intro) return;
    if (h.caja) { if (T.contando && enfocarCajaConteo(h.caja)) return; pausar(true); detalleTablet(h.caja); return; }
    if (h.rack) {
        const i = T.paradas.findIndex((p) => p.rack === h.rack);
        if (i >= 0) saltarA(i, true);
        else if (T.modo !== 'picking' && h.rack.infoPa && h.rack.infoPa.racks.length) iniciarRecorrido(h.rack.infoPa, h.rack);
    }
}

function limpiarRecorrido() {
    const T = S.tour; if (!T) return;
    cerrarDetalleTablet();
    limpiarFlotantes(false);
    for (const d of T.destellos) { if (d.m.parent) d.m.parent.remove(d.m); d.m.material.dispose(); }
    for (const [c, [sp, borde]] of T.marcas) { c.remove(sp, borde); sp.material.dispose(); }
    for (const p of T.paradas) for (const c of p.cajas) c.userData.sacar = 0;
    if (laser) { capaRecorrido.remove(laser); laser.children.forEach((m) => m.geometry.dispose()); laser = null; }
    S.tour = null;
}
function salirRecorrido() {
    const T = S.tour; if (!T) return;
    const vuelta = T.camGuardada;
    if (T.conteoId && !T.conteoCerrado) cerrarConteo(T, true);
    const refrescar = T.huboAjustes || !!T.conteoId;
    limpiarRecorrido();
    cerrarFicha();
    root.classList.remove('en-recorrido');
    cine.classList.remove('is-visible', 'es-pausa'); tablet.classList.remove('is-visible');
    setTimeout(() => { if (!S.tour) { cine.hidden = true; tablet.hidden = true; } }, 500);
    S.fovMeta = FOV_MAPA;
    linterna.intensity = 0;
    controls.enabled = true;
    // se vuelve a la vista que habia antes de entrar
    controls.target.copy(camera.position).add(camera.getWorldDirection(new THREE.Vector3()).multiplyScalar(3));
    volar(vuelta.pos, vuelta.target, 1500);
    // lo que se ajusto en el conteo ya esta en la base: se trae el stock real
    if (refrescar) setTimeout(() => { if (!S.tour) refrescarStock(true); }, 1600);
}

// ============================================================================
//  CONTEO CICLICO — dentro del recorrido
// ----------------------------------------------------------------------------
//  Con "Contar" activo, al terminar de mirar cada rack el recorrido se detiene
//  y la tablet pide lo que hay en cada caja. Lo que coincide se confirma con un
//  toque; lo que no, se escribe. Al confirmar, el servidor (WsBodegaMapa.
//  ContarRack) mide contra el stock real del momento y ajusta la diferencia en
//  el acto, con el mismo SP de cualquier ajuste: el kardex queda con el motivo
//  "Conteo ciclico N°...". Al cerrar, queda la exactitud del conteo.
// ============================================================================
function leerConteos(lista) {
    S.conteos = new Map();
    for (const c of lista || []) S.conteos.set(c.u, c);
}
function haceDias(d) { return d === 0 ? 'hoy' : d === 1 ? 'ayer' : 'hace ' + d + ' días'; }
/* "Contado hace 3 dias": un rack que hace mas de 30 dias no se cuenta se
   marca, para que el bodeguero sepa por donde empezar. */
function textoUltimoConteo(r, donde) {
    if (r.recepcion) return '';
    const c = S.conteos.get(r.id);
    if (!c) return donde === 'tb'
        ? '<div class="bm3d-tb-ultimo es-nunca"><i class="mdi mdi-clipboard-alert-outline"></i>Sin conteos registrados</div>'
        : '<div class="bm3d-conteo-ult es-nunca"><i class="mdi mdi-clipboard-alert-outline"></i><span><b>Nunca se ha contado</b>Cuéntalo desde el recorrido.</span></div>';
    const ex = c.lineas ? Math.round(c.coinciden * 100 / c.lineas) : null;
    const viejo = c.dias > 30 ? ' es-viejo' : '';
    if (donde === 'tb') return '<div class="bm3d-tb-ultimo' + viejo + '"><i class="mdi mdi-clipboard-check-outline"></i>Contado ' + haceDias(c.dias) + (ex != null ? ' · ' + ex + '% exacto' : '') + '</div>';
    return '<div class="bm3d-conteo-ult' + viejo + '"><i class="mdi mdi-clipboard-check-outline"></i><span><b>Último conteo ' + haceDias(c.dias) + '</b>' +
        esc(c.fecha) + (c.usuario ? ' · ' + esc(c.usuario) : '') + '</span>' + (ex != null ? '<em>' + c.coinciden + '/' + c.lineas + ' · ' + ex + '%</em>' : '') + '</div>';
}

function leerCant(v) {
    const t = String(v == null ? '' : v).trim().replace(/\s/g, '');
    if (!t) return null;
    const n = parseFloat(t.includes(',') && !t.includes('.') ? t.replace(',', '.') : t.replace(/,/g, ''));
    return isNaN(n) || n < 0 ? null : n;
}
function resaltarCaja(c, si) {
    c.userData.sacar = si ? (c.userData.fila === 1 ? 0.5 : 0.2) : 0;
    marcarContorno(si ? c : null, false);
}

function mostrarConteo(p) {
    const T = S.tour; if (!T) return;
    cerrarDetalleTablet();
    T.contando = p;
    const el = $('tbConteo');
    el.innerHTML =
        '<div class="bm3d-tbc-cab"><div><small>Conteo · lado ' + (p.lado === 'izq' ? 'izquierdo' : 'derecho') + '</small><b>' + esc(p.rack.codigo) + '</b></div>' +
        '<button type="button" class="bm3d-btn es-contorno es-chico" id="tbcTodo" title="Marca como coincidentes las que no escribiste"><i class="mdi mdi-check-all"></i>Todo coincide</button></div>' +
        '<div class="bm3d-tbc-ayuda">Escribe lo que hay en cada caja, o toca <i class="mdi mdi-check"></i> si coincide con el sistema. Las que dejes en blanco no se cuentan.</div>' +
        '<div class="bm3d-tbc-lista" id="tbcLista">' + p.cajas.map((c, i) => filaConteo(c, i)).join('') + '</div>' +
        '<div class="bm3d-tbc-pie" id="tbcPie"><span id="tbcResumen"></span>' +
        '<button type="button" class="bm3d-btn es-ghost es-chico" id="tbcOmitir">Omitir</button>' +
        '<button type="button" class="bm3d-btn es-primario es-chico" id="tbcConfirmar"><i class="mdi mdi-check"></i>Confirmar</button></div>';
    el.hidden = false;
    el.querySelectorAll('[data-cant]').forEach((inp) => {
        const i = +inp.dataset.cant;
        inp.oninput = () => difConteo(p, i);
        inp.onfocus = () => resaltarCaja(p.cajas[i], true);
        inp.onblur = () => resaltarCaja(p.cajas[i], false);
        inp.onkeydown = (e) => {
            if (e.key === 'Enter') {
                e.preventDefault();
                const sig = el.querySelector('[data-cant="' + (i + 1) + '"]');
                if (sig) sig.focus(); else $('tbcConfirmar').focus();
            }
        };
    });
    el.querySelectorAll('[data-igual]').forEach((b) => b.onclick = () => {
        const i = +b.dataset.igual, inp = el.querySelector('[data-cant="' + i + '"]');
        inp.value = String(p.cajas[i].userData.item.q);
        difConteo(p, i);
    });
    $('tbcTodo').onclick = () => {
        p.cajas.forEach((c, i) => {
            const inp = el.querySelector('[data-cant="' + i + '"]');
            if (inp && !inp.value.trim()) { inp.value = String(c.userData.item.q); difConteo(p, i); }
        });
    };
    $('tbcOmitir').onclick = () => { cerrarConteoTablet(); pausar(false); };
    $('tbcConfirmar').onclick = (e) => confirmarConteo(p, e.currentTarget);
    resumenFilas(p);
    const primero = el.querySelector('[data-cant]'); if (primero) setTimeout(() => primero.focus({ preventScroll: true }), 80);
}
function filaConteo(c, i) {
    const it = c.userData.item;
    return '<div class="bm3d-tbc-fila" data-fila="' + i + '">' + miniatura(it.foto, it.color) +
        '<div class="bm3d-tbc-txt"><b>' + esc(it.c) + '</b><span>' + esc(it.n) + '</span><small>' + c.userData.nivel + '-' + pad2(c.userData.posicion) + ' · sistema ' + num(it.q) + ' ' + esc(it.un) + '</small></div>' +
        '<div class="bm3d-tbc-entrada"><input type="text" inputmode="decimal" autocomplete="off" data-cant="' + i + '" placeholder="' + num(it.q) + '" aria-label="Cantidad contada de ' + esc(it.c) + '" />' +
        '<button type="button" data-igual="' + i + '" title="Coincide con el sistema"><i class="mdi mdi-check"></i></button></div>' +
        '<div class="bm3d-tbc-dif" data-dif="' + i + '"></div>' +
        '<div class="bm3d-tbc-lote" data-lote="' + i + '" hidden><input type="text" data-lote-in="' + i + '" placeholder="Código del lote nuevo" /></div>' +
        '</div>';
}
function difConteo(p, i) {
    const el = $('tbConteo'), c = p.cajas[i], it = c.userData.item;
    const v = leerCant(el.querySelector('[data-cant="' + i + '"]').value);
    const chip = el.querySelector('[data-dif="' + i + '"]'), fila = el.querySelector('[data-fila="' + i + '"]');
    fila.classList.remove('es-ok', 'es-falta', 'es-sobra', 'es-error');
    if (v == null) chip.innerHTML = '';
    else {
        const d = v - it.q;
        if (Math.abs(d) < 1e-9) { chip.innerHTML = '<i class="mdi mdi-check-circle"></i>Coincide'; fila.classList.add('es-ok'); }
        else if (d < 0) { chip.innerHTML = '<i class="mdi mdi-arrow-down-bold"></i>Faltan ' + num(-d) + ' ' + esc(it.un); fila.classList.add('es-falta'); }
        else { chip.innerHTML = '<i class="mdi mdi-arrow-up-bold"></i>Sobran ' + num(d) + ' ' + esc(it.un); fila.classList.add('es-sobra'); }
    }
    resumenFilas(p);
}
function resumenFilas(p) {
    const el = $('tbConteo'), r = $('tbcResumen'); if (!r) return;
    let n = 0, dif = 0;
    p.cajas.forEach((c, i) => {
        const v = leerCant((el.querySelector('[data-cant="' + i + '"]') || {}).value);
        if (v == null) return;
        n++; if (Math.abs(v - c.userData.item.q) > 1e-9) dif++;
    });
    r.innerHTML = '<b>' + n + '/' + p.cajas.length + '</b> contadas' + (dif ? ' · <em>' + dif + ' con diferencia</em>' : '');
}
/* Un clic en una caja de la escena mientras se cuenta lleva a su fila. */
function enfocarCajaConteo(c) {
    const T = S.tour, p = T && T.contando; if (!p) return false;
    const i = p.cajas.indexOf(c); if (i < 0) return false;
    const inp = $('tbConteo').querySelector('[data-cant="' + i + '"]');
    if (inp) { inp.focus(); inp.closest('.bm3d-tbc-fila').scrollIntoView({ block: 'nearest', behavior: 'smooth' }); }
    return true;
}

async function confirmarConteo(p, btn) {
    const T = S.tour; if (!T) return;
    const el = $('tbConteo'), lineas = [];
    p.cajas.forEach((c, i) => {
        const v = leerCant(el.querySelector('[data-cant="' + i + '"]').value);
        if (v == null) return;
        const lote = el.querySelector('[data-lote-in="' + i + '"]');
        lineas.push({ i, repuesto: c.userData.item.id, contado: v, loteNuevo: lote ? lote.value.trim() : '' });
    });
    if (!lineas.length) { aviso('Escribe al menos una cantidad, o usa «Todo coincide».', true); return; }
    await guardando(btn, async () => {
        if (!T.conteoId) {
            const r0 = await ws('IniciarConteo', { bodega: T.pa.info.id, alcance: T.pa.info.bodega.nombre + ' · Pasillo ' + T.pa.nom + ' (recorrido 3D)' });
            T.conteoId = r0.id;
        }
        const r = await ws('ContarRack', { datos: JSON.stringify({ conteo: T.conteoId, bodega: T.pa.info.id, ubicacion: p.rack.id, lineas: lineas.map((l) => ({ repuesto: l.repuesto, contado: l.contado, loteNuevo: l.loteNuevo })) }) });
        if (S.tour !== T) return;
        let errores = 0;
        for (const res of r.lineas) {
            const l = lineas.find((x) => x.repuesto === res.repuesto); if (!l) continue;
            const c = p.cajas[l.i], fila = el.querySelector('[data-fila="' + l.i + '"]'), chip = el.querySelector('[data-dif="' + l.i + '"]');
            fila.classList.remove('es-ok', 'es-falta', 'es-sobra', 'es-error');
            const clave = p.rack.id + '|' + res.repuesto;
            if (!res.ok) {
                errores++;
                fila.classList.add('es-error');
                chip.innerHTML = '<i class="mdi mdi-alert-circle"></i>' + esc(res.detalle);
                if (/lote/i.test(res.detalle)) el.querySelector('[data-lote="' + l.i + '"]').hidden = false;
                continue;
            }
            if (!(clave in T.cuenta.cajas)) T.cuenta.cajas[clave] = Math.abs(res.diferencia) < 1e-9;
            if (Math.abs(res.diferencia) < 1e-9) { fila.classList.add('es-ok'); chip.innerHTML = '<i class="mdi mdi-check-circle"></i>Coincide · confirmado'; }
            else {
                fila.classList.add(res.diferencia < 0 ? 'es-falta' : 'es-sobra');
                chip.innerHTML = '<i class="mdi mdi-scale-balance"></i>Ajustado ' + (res.diferencia > 0 ? '+' : '−') + num(Math.abs(res.diferencia)) + ' · sistema ' + num(res.sistema) + ' → ' + num(res.contado);
                aplicarConteoCaja(c, res.contado);
            }
            const inp = el.querySelector('[data-cant="' + l.i + '"]'); inp.disabled = true;
            const ig = el.querySelector('[data-igual="' + l.i + '"]'); if (ig) ig.disabled = true;
        }
        const vals = Object.values(T.cuenta.cajas);
        T.cuenta.lineas = vals.length; T.cuenta.coinciden = vals.filter(Boolean).length;
        T.cuenta.ajustes += r.ajustes;
        if (r.ajustes) T.huboAjustes = true;
        T.contados.add(p.rack);
        $('tbcResumen').innerHTML = errores
            ? '<em>' + errores + ' caja' + (errores === 1 ? '' : 's') + ' sin registrar: revisa y vuelve a confirmar.</em>'
            : '<b>Rack contado</b>' + (r.ajustes ? ' · ' + r.ajustes + ' ajuste' + (r.ajustes === 1 ? '' : 's') : ' · sin diferencias');
        const pie = $('tbcPie');
        pie.querySelector('#tbcOmitir').remove();
        const conf = pie.querySelector('#tbcConfirmar');
        if (!errores) {
            conf.outerHTML = '<button type="button" class="bm3d-btn es-primario es-chico" id="tbcSeguir"><i class="mdi mdi-walk"></i>Seguir</button>';
            $('tbcSeguir').onclick = () => { cerrarConteoTablet(); pausar(false); };
            $('tbcTodo').disabled = true;
        }
        estadoTablet();
    });
}
/* Lo contado pasa a la escena sin recargar: la caja, su etiqueta, la de la
   viga y la marca de bajo minimo quedan con la cantidad real. */
function aplicarConteoCaja(c, contado) {
    const T = S.tour, it = c.userData.item;
    it.q = contado;
    if (S.etiquetasVivas.has(c)) {
        const t = S.etiquetasVivas.get(c);
        c.userData.etiqueta.material.dispose(); t.dispose();
        c.userData.etiqueta.material = c.userData.etqLejos;
        S.etiquetasVivas.delete(c);
        ultimoLod = 0;
    }
    const r = c.userData.rack;
    if (S.vigasHD.has(r)) { S.vigasHD.delete(r); vigaHD(r, true); }
    if (estadoDe(it) === 'bajo') {
        marcarBajo(c);
        if (!T.alertas.includes(c)) T.alertas.push(c);
    } else if (T.marcas.has(c)) {
        const [sp, borde] = T.marcas.get(c);
        c.remove(sp, borde); sp.material.dispose();
        T.marcas.delete(c);
        T.alertas = T.alertas.filter((x) => x !== c);
    }
    alertasTablet();
}
function cerrarConteoTablet() {
    const T = S.tour; if (!T) return;
    const el = $('tbConteo'); if (el) el.hidden = true;
    if (T.contando) for (const c of T.contando.cajas) c.userData.sacar = 0;
    T.contando = null;
    marcarContorno(null);
}
async function cerrarConteo(T, silencioso) {
    if (!T || !T.conteoId || T.conteoCerrado) return null;
    T.conteoCerrado = true;
    try { return (await ws('CerrarConteo', { id: T.conteoId })).resumen; }
    catch (e) { if (!silencioso) aviso(e.message, true); return null; }
}
async function resumenConteo(T) {
    const res = await cerrarConteo(T, false);
    if (!res || S.tour !== T) return;
    const ex = res.exactitud != null ? Math.round(res.exactitud) : null;
    const caja = document.createElement('div');
    caja.className = 'bm3d-tb-exactitud' + (ex != null && ex < 90 ? ' es-baja' : '');
    caja.innerHTML = '<b>' + (ex != null ? ex + '%' : '—') + '</b><div><span>Exactitud del conteo N° ' + res.id + '</span>' +
        '<small>' + res.coinciden + ' de ' + res.lineas + ' cajas coincidieron · ' + res.faltantes + ' con faltante · ' + res.sobrantes + ' con sobrante · ' + num(res.unidades) + ' un ajustadas</small></div>';
    $('tbActual').appendChild(caja);
}

// ============================================================================
//  PICKING — preparar lo que pide una OT (o un retiro libre)
// ----------------------------------------------------------------------------
//  Se arma la lista (lo pendiente de la OT o lo que se agregue a mano), el
//  mapa reparte cada repuesto entre sus cajas en el orden del METODO DE SALIDA
//  (FEFO, FIFO o LIFO, BD/328) y arma la ruta en "S": un pasillo hacia el
//  fondo, el siguiente hacia la entrada, como se recorre una bodega real.
//  El recorrido en primera persona va caja por caja: la caja se asoma, la
//  tablet dice cuanto sacar y de que lote, y "Retirar" registra la SALIDA POR
//  CONSUMO contra la orden (WsBodegaMapa.RetirarPicking).
// ============================================================================
const METODO_TXT = { FEFO: 'primero lo que vence antes', FIFO: 'primero lo que entró antes', LIFO: 'primero lo que entró último' };
function fechaCorta(iso) {
    if (!iso) return '';
    const d = String(iso).split(' ')[0].split('-');
    return d.length === 3 ? d[2] + '-' + d[1] + '-' + d[0] : iso;
}

/* El orden en que se toman las cajas de un repuesto: el mismo criterio que
   usa SEL_INVENTARIO_ORIGEN para los lotes dentro de cada caja. */
function compararPorMetodo(met) {
    return (a, b) => {
        const x = a.userData.item, y = b.userData.item;
        if (met === 'FEFO') {
            const vx = x.vence || '9999', vy = y.vence || '9999';
            if (vx !== vy) return vx < vy ? -1 : 1;
        }
        if (met === 'LIFO') { if ((x.ingN || '') !== (y.ingN || '')) return (x.ingN || '') > (y.ingN || '') ? -1 : 1; }
        else if ((x.ing || '') !== (y.ing || '')) return (x.ing || '9999') < (y.ing || '9999') ? -1 : 1;
        return a.userData.rack.codigo.localeCompare(b.userData.rack.codigo);
    };
}

function planPicking(bodegaId, lineas) {
    const info = S.porBodega.get(bodegaId);
    const asign = [];
    for (const l of lineas) {
        l.retirado = l.retirado || 0; l.asignada = 0; l.faltante = 0;
        const todas = info ? info.cajas.filter((c) => c.userData.item.id === l.id && c.userData.item.q > 0) : [];
        l.enRecepcion = todas.filter((c) => c.userData.rack.recepcion).reduce((s, c) => s + c.userData.item.q, 0);
        const cajas = todas.filter((c) => !c.userData.rack.recepcion);
        l.metodo = cajas.length ? (cajas[0].userData.item.met || 'FEFO') : ((info && info.bodega.metodo) || 'FEFO');
        cajas.sort(compararPorMetodo(l.metodo));
        let resta = Math.max(0, (l.pedida || 0) - l.retirado);
        for (const c of cajas) {
            if (resta <= 1e-9) break;
            const q = Math.min(resta, c.userData.item.q);
            asign.push({ linea: l, caja: c, cantidad: q, estado: 'pendiente', retirado: 0 });
            l.asignada += q; resta -= q;
        }
        l.faltante = resta > 1e-9 ? resta : 0;
    }
    const porRack = new Map();
    for (const a of asign) { const r = a.caja.userData.rack; if (!porRack.has(r)) porRack.set(r, []); porRack.get(r).push(a); }
    const pasillos = [...new Set([...porRack.keys()].map((r) => r.infoPa))].sort((a, b) => a.x - b.x);
    const dir = new Map(pasillos.map((pa, i) => [pa, i % 2 === 0 ? 1 : -1]));
    const paradas = [...porRack.entries()].map(([rack, picks]) => ({
        rack, pa: rack.infoPa, lado: rack.lado, z: rack.pos.z, dir: dir.get(rack.infoPa),
        cara: rack.pos.x + rack.normal.x * (RACK.prof / 2),
        picks: picks.sort((a, b) => (b.caja.userData.nivel - a.caja.userData.nivel) || (a.caja.userData.posicion - b.caja.userData.posicion)),
        cajas: picks.map((p) => p.caja)
    })).sort((a, b) => (pasillos.indexOf(a.pa) - pasillos.indexOf(b.pa)) || (a.z - b.z) * a.dir);
    return { info, lineas, paradas, pasillos, picks: asign };
}

function disponibilidad(l, plan) {
    const racks = [...new Set(plan.picks.filter((p) => p.linea === l).map((p) => corto(p.caja.userData.rack.codigo)))];
    if (l.asignada > 0) return 'Sale de ' + racks.join(' · ') + ' · ' + l.metodo + (l.faltante ? ' · <em>faltan ' + num(l.faltante) + '</em>' : '');
    if (l.enRecepcion > 0) return '<em>Solo en recepción (' + num(l.enRecepcion) + '): ubícalo en un rack primero</em>';
    return '<em>Sin stock en esta bodega</em>';
}

function agregarAPicking(it) {
    if (!S.picking) S.picking = { bodega: it.b, orden: 0, ordenTexto: '', lineas: [] };
    const P = S.picking;
    if (P.bodega !== it.b) { P.bodega = it.b; }
    const ya = P.lineas.find((l) => l.id === it.id);
    if (ya) ya.pedida = (ya.pedida || 0) + 1;
    else P.lineas.push({ id: it.id, c: it.c, n: it.n, un: it.un, foto: it.foto, pedida: 1 });
    aviso(it.c + ' agregado al picking (' + P.lineas.length + ' repuesto' + (P.lineas.length === 1 ? '' : 's') + ').');
    formPicking();
}

async function formPicking() {
    abrirPanel(cab('Picking', 'Preparar picking', '', 'mdi-cart-arrow-down'), '<div class="bm3d-loader" style="justify-content:center;margin:30px"><span></span><span></span><span></span></div>', '');
    let cat;
    try { cat = await catalogos(); } catch (e) { aviso(e.message, true); return; }
    if (!S.picking) S.picking = { bodega: S.bodegaSel, orden: 0, ordenTexto: '', lineas: [] };
    const P = S.picking;
    if (!S.porBodega.has(P.bodega)) P.bodega = S.bodegaSel;

    const pintar = () => {
        const info = S.porBodega.get(P.bodega);
        const plan = planPicking(P.bodega, P.lineas);
        const nombres = plan.pasillos.map((pa) => pa.nom).join(' → ');
        abrirPanel(cab(info.bodega.nombre + ' · salida ' + (info.bodega.metodo || 'FEFO'), 'Preparar picking', P.orden ? P.ordenTexto : 'Retiro libre', 'mdi-cart-arrow-down'),
            '<div class="bm3d-form">' +
            campo('Bodega', sel('fPkBod', (S.datos.bodegas || []).map((b) => [b.id, b.nombre]), P.bodega), { req: true }) +
            campo('Orden de trabajo', sel('fPkOT', [[0, 'Sin OT · retiro libre']].concat((cat.ordenes || []).map((o) => [o.id, o.texto])), P.orden)) +
            '</div>' +
            (!(cat.ordenes || []).length ? '<div class="bm3d-nota" style="margin-top:10px"><i class="mdi mdi-information-outline"></i>No hay órdenes abiertas: el retiro queda como salida por consumo sin OT.</div>' : '') +
            '<div class="bm3d-seccion" style="margin-top:14px"><div class="bm3d-seccion-tit"><span>Qué retirar</span><span>' + P.lineas.length + '</span></div>' +
            (P.lineas.length ? P.lineas.map((l, i) =>
                '<div class="bm3d-pk-linea' + (l.faltante || !l.asignada ? ' es-falta' : '') + '">' + miniatura(l.foto) +
                '<div><b>' + esc(l.c) + '</b><span>' + esc(l.n) + '</span><small>' + disponibilidad(l, plan) + '</small></div>' +
                '<input type="text" inputmode="decimal" data-pk-cant="' + i + '" value="' + esc(l.pedida) + '" aria-label="Cantidad" />' +
                '<button type="button" data-pk-quitar="' + i + '" title="Quitar"><i class="mdi mdi-close"></i></button></div>').join('')
                : '<div class="bm3d-vacio-txt">Elige una OT o agrega repuestos con el buscador.</div>') +
            '<div class="bm3d-selrep" style="margin-top:8px"><input id="fPkBusca" placeholder="Agregar repuesto: código o nombre…" autocomplete="off" style="width:100%;height:36px;padding:0 10px;border:1px solid #CFD6E3;border-radius:9px" />' +
            '<div class="bm3d-resultados" id="fPkRes" hidden></div></div></div>' +
            (plan.paradas.length ? '<div class="bm3d-nota"><i class="mdi mdi-map-marker-path"></i><span>Ruta: <b>' + plan.paradas.length + ' parada' + (plan.paradas.length === 1 ? '' : 's') + '</b> en pasillo' + (plan.pasillos.length === 1 ? ' ' : 's ') + esc(nombres) +
                '. Cada repuesto sale de sus cajas en el orden de su método de salida.</span></div>' : ''),
            '<button type="button" class="bm3d-btn es-ghost" id="fPkCancelar">Cerrar</button>' +
            '<button type="button" class="bm3d-btn es-primario" id="fPkIniciar"' + (plan.paradas.length ? '' : ' disabled') + '><i class="mdi mdi-walk"></i>Iniciar picking</button>');

        $('fPkCancelar').onclick = cerrarPanel;
        $('fPkBod').onchange = (e) => { P.bodega = +e.target.value; pintar(); };
        $('fPkOT').onchange = async (e) => {
            P.orden = +e.target.value;
            P.ordenTexto = P.orden ? e.target.options[e.target.selectedIndex].text : '';
            if (P.orden) {
                try {
                    const r = await ws('PickingOT', { orden: P.orden });
                    if (r.lineas.length) P.lineas = r.lineas.map((x) => ({ id: x.id, c: x.c, n: x.n, un: x.un, foto: (cat.repuestos.find((y) => y.id === x.id) || {}).foto, pedida: x.pendiente }));
                    else aviso('La OT no tiene repuestos pendientes: agrega lo que vas a retirar y queda cargado a la orden.');
                } catch (er) { aviso(er.message, true); }
            }
            pintar();
        };
        panel.querySelectorAll('[data-pk-cant]').forEach((inp) => inp.onchange = () => { P.lineas[+inp.dataset.pkCant].pedida = leerCant(inp.value) || 0; pintar(); });
        panel.querySelectorAll('[data-pk-quitar]').forEach((b) => b.onclick = () => { P.lineas.splice(+b.dataset.pkQuitar, 1); pintar(); });
        const busca = $('fPkBusca'), res = $('fPkRes');
        busca.oninput = () => {
            const q = norm(busca.value);
            if (q.length < 2) { res.hidden = true; return; }
            const stock = (id) => info.cajas.filter((c) => c.userData.item.id === id && !c.userData.rack.recepcion).reduce((s, c) => s + c.userData.item.q, 0);
            const m = cat.repuestos.filter((x) => norm(x.c).includes(q) || norm(x.n).includes(q) || norm(x.tn).includes(q))
                .map((x) => ({ x, hay: stock(x.id) })).sort((a, b) => (b.hay > 0) - (a.hay > 0)).slice(0, 30);
            res.hidden = false;
            res.innerHTML = m.length ? m.map((r, i) => '<div class="bm3d-res" data-i="' + i + '">' + miniatura(r.x.foto) + '<div><b>' + esc(r.x.c) + '</b><span>' + esc(r.x.n) + '</span></div><em' + (r.hay ? '' : ' style="color:#C7352B"') + '>' + (r.hay ? 'hay ' + num(r.hay) : 'sin stock') + '</em></div>').join('') : '<div class="bm3d-res-vacio">Sin coincidencias.</div>';
            res.querySelectorAll('[data-i]').forEach((el) => el.onmousedown = (ev) => {
                ev.preventDefault();
                const x = m[+el.dataset.i].x, ya = P.lineas.find((l) => l.id === x.id);
                if (ya) ya.pedida = (ya.pedida || 0) + 1; else P.lineas.push({ id: x.id, c: x.c, n: x.n, un: x.un, foto: x.foto, pedida: 1 });
                pintar();
                setTimeout(() => { const b2 = $('fPkBusca'); if (b2) b2.focus(); }, 30);
            });
        };
        $('fPkIniciar').onclick = () => {
            panel.querySelectorAll('[data-pk-cant]').forEach((inp) => { P.lineas[+inp.dataset.pkCant].pedida = leerCant(inp.value) || 0; });
            for (const l of P.lineas) l.retirado = 0;
            const plan2 = planPicking(P.bodega, P.lineas);
            if (!plan2.paradas.length) { aviso('No hay nada que retirar con stock en esta bodega.', true); return; }
            iniciarPicking(plan2, { orden: P.orden, ordenTexto: P.ordenTexto });
        };
    };
    pintar();
}

function iniciarPicking(plan, meta) {
    const previo = S.tour;
    if (previo) { if (previo.conteoId) cerrarConteo(previo, true); limpiarRecorrido(); }
    cerrarPanel(); cerrarFicha(); terminarPick(); soltarSeleccion(); marcarContorno(null);
    if (S.filtro.size) { S.filtro.clear(); aplicarFiltros(); }
    if (S.modo !== 'normal') cambiarModo('normal');
    if (plan.info.id !== S.bodegaSel) elegirBodega(plan.info.id, true);
    const pa = plan.paradas[0].pa;
    S.tour = {
        modo: 'picking', plan, meta, pa, paradas: plan.paradas, sentido: 1,
        vel: 1, idx: 0, cola: [], seg: null, reloj: 0, pausado: false, terminado: false, final: false,
        pos: new THREE.Vector3(pa.x, OJOS, pa.z0 - 2.4), mira: new THREE.Vector3(pa.x, 1.45, pa.z0 + 3),
        yaw: 0, pitch: 0, fase: 0, andando: 0,
        vistos: new Set(), revisados: new Set(), alertas: [], marcas: new Map(), destellos: [], etiquetas: [],
        camGuardada: previo ? previo.camGuardada : { pos: camera.position.clone(), target: controls.target.clone() },
        inicio: performance.now(), detalle: null, revisarIdx: -1,
        conteo: false, conteoId: 0, cuenta: { lineas: 0, coinciden: 0, ajustes: 0, cajas: {} }, contados: new Set(), contando: null,
        huboAjustes: !!(previo && previo.huboAjustes), unidades: 0
    };
    controls.enabled = false;
    S.vuelo = null;
    S.fovMeta = FOV_RECORRIDO;
    linterna.intensity = 5;
    root.classList.add('en-recorrido');
    armarCinePicking();
    armarTabletPicking();
    armarLaser();
    const mirandoA = camera.position.clone().add(camera.getWorldDirection(new THREE.Vector3()).multiplyScalar(6));
    S.tour.intro = { t0: performance.now(), dur: previo ? 1600 : 2800, p0: camera.position.clone(), q0: mirandoA };
}

function armarCinePicking() {
    const T = S.tour, info = T.plan.info;
    const titulo = T.meta.orden ? T.meta.ordenTexto : 'Retiro libre';
    cine.innerHTML =
        '<div class="bm3d-cine-barra es-arriba"><span class="bm3d-cine-rec"><i></i>REC</span><span class="bm3d-cine-nom">PICKING · ' + esc(titulo.toUpperCase()) + ' · ' + esc(info.bodega.nombre.toUpperCase()) + '</span><span class="bm3d-cine-tc" id="cineTc">00:00</span></div>' +
        '<div class="bm3d-cine-barra es-abajo"><span><kbd>Espacio</kbd> pausa</span><span><kbd>←</kbd><kbd>→</kbd> parada anterior / siguiente</span><span>Arrastra para mirar</span><span><kbd>Esc</kbd> salir</span></div>' +
        '<div class="bm3d-cine-vineta"></div>' +
        '<div class="bm3d-cine-titulo" id="cineTitulo"><small>Picking · ' + esc(info.bodega.nombre) + '</small><b>' + esc(titulo) + '</b>' +
            '<span>' + T.plan.lineas.filter((l) => l.asignada > 0).length + ' repuestos · ' + T.paradas.length + ' paradas · pasillo' + (T.plan.pasillos.length === 1 ? ' ' : 's ') + esc(T.plan.pasillos.map((p) => p.nom).join(' → ')) + '</span></div>';
    cine.hidden = false;
    requestAnimationFrame(() => cine.classList.add('is-visible'));
}

function armarTabletPicking() {
    const T = S.tour, info = T.plan.info;
    tablet.innerHTML =
        '<div class="bm3d-tb-mano es-izq"><i class="manga"></i><i class="palma"></i></div>' +
        '<div class="bm3d-tb-mano es-der"><i class="manga"></i><i class="palma"></i></div>' +
        '<div class="bm3d-tb-equipo"><span class="bm3d-tb-camara"></span><div class="bm3d-tb-pantalla">' +
            '<div class="bm3d-tb-sb"><b>SIGMA</b><span id="tbHora"></span><span><i class="mdi mdi-wifi"></i><i class="mdi mdi-battery-80"></i></span></div>' +
            '<div class="bm3d-tb-app">' +
                '<div class="bm3d-tb-cab"><div><small>Picking · ' + esc(info.bodega.nombre) + '</small><b>' + esc(T.meta.orden ? T.meta.ordenTexto : 'Retiro libre') + '</b></div><span class="bm3d-tb-rec" id="tbRec"><i></i>EN VIVO</span></div>' +
                '<div class="bm3d-tb-stats" id="tbStats"></div>' +
                '<div class="bm3d-tb-racks" id="tbRacks">' + T.paradas.map((p, i) =>
                    '<button type="button" class="bm3d-tb-rack" data-tb-rack="' + i + '" title="' + esc(p.rack.codigo) + '"><span>' + esc(corto(p.rack.codigo)) + '</span><small>' + esc(p.pa.nom) + ' · ' + p.picks.length + '</small></button>').join('') + '</div>' +
                '<div class="bm3d-tb-actual" id="tbActual"><div class="bm3d-tb-espera"><i class="mdi mdi-walk"></i>Camino a la primera caja…</div></div>' +
                '<div class="bm3d-tb-lista" id="tbLista"></div>' +
                '<div class="bm3d-tb-alertas" id="tbAlertas" hidden></div>' +
                '<div class="bm3d-tb-ctrl">' +
                    '<button type="button" data-tb="ant" title="Parada anterior"><i class="mdi mdi-skip-previous"></i></button>' +
                    '<button type="button" data-tb="pausa" class="es-play" title="Pausa"><i class="mdi mdi-pause"></i></button>' +
                    '<button type="button" data-tb="sig" title="Parada siguiente"><i class="mdi mdi-skip-next"></i></button>' +
                    '<button type="button" data-tb="vel" class="es-vel" title="Velocidad">1×</button>' +
                    '<button type="button" data-tb="salir" class="es-salir" title="Salir del picking"><i class="mdi mdi-exit-run"></i>Salir</button>' +
                '</div>' +
            '</div>' +
            '<div class="bm3d-tb-detalle" id="tbDetalle" hidden></div>' +
            '<div class="bm3d-tb-conteo" id="tbConteo" hidden></div>' +
        '</div></div>' +
        '<i class="bm3d-tb-pulgar es-izq"></i><i class="bm3d-tb-pulgar es-der"></i>';
    tablet.hidden = false;
    requestAnimationFrame(() => tablet.classList.add('is-visible'));
    tablet.querySelectorAll('[data-tb-rack]').forEach((b) => b.onclick = () => saltarA(+b.dataset.tbRack, false));
    tablet.querySelector('[data-tb="ant"]').onclick = () => saltarRelativo(-1);
    tablet.querySelector('[data-tb="sig"]').onclick = () => saltarRelativo(1);
    tablet.querySelector('[data-tb="pausa"]').onclick = () => pausar(!S.tour.pausado);
    tablet.querySelector('[data-tb="vel"]').onclick = () => { const t2 = S.tour; t2.vel = VEL[(VEL.indexOf(t2.vel) + 1) % VEL.length]; estadoTablet(); };
    tablet.querySelector('[data-tb="salir"]').onclick = salirRecorrido;
    lineasPicking();
    estadoTablet();
}

function estadoLinea(l) {
    if (l.retirado >= (l.pedida || 0) - 1e-9 && l.retirado > 0) return ['es-ok', 'Listo'];
    if (!l.asignada && !l.retirado) return ['es-falta', l.enRecepcion ? 'En recepción' : 'Sin stock'];
    if (l.retirado > 0) return ['es-parcial', num(l.retirado) + '/' + num(l.pedida)];
    if (l.faltante) return ['es-falta', 'Faltan ' + num(l.faltante)];
    return ['', 'Pendiente'];
}
function lineasPicking() {
    const T = S.tour, el = $('tbLista'); if (!T || !el) return;
    el.innerHTML = T.plan.lineas.map((l, i) => {
        const [cl, txt] = estadoLinea(l);
        return '<div class="bm3d-tb-item bm3d-tb-pkl ' + cl + '" data-pkl="' + i + '">' + miniatura(l.foto) +
            '<div><b>' + esc(l.c) + '</b><span>' + esc(l.n) + '</span><small>' + num(l.pedida) + ' ' + esc(l.un || '') + ' · ' + esc(l.metodo || '') + '</small></div>' +
            '<em>' + esc(txt) + '</em></div>';
    }).join('');
    el.querySelectorAll('[data-pkl]').forEach((f) => f.onclick = () => {
        const l = T.plan.lineas[+f.dataset.pkl];
        const i = T.paradas.findIndex((p) => p.picks.some((k) => k.linea === l && k.estado === 'pendiente'));
        if (i >= 0) saltarA(i, false);
    });
}
function estadoPicking() {
    const T = S.tour, L = T.plan.lineas.filter((l) => (l.pedida || 0) > 0);
    const listas = L.filter((l) => estadoLinea(l)[0] === 'es-ok').length;
    $('tbStats').innerHTML =
        '<div><b>' + listas + '<small>/' + L.length + '</small></b><span>Repuestos</span></div>' +
        '<div><b>' + num(T.unidades) + '</b><span>Unidades</span></div>' +
        '<div><b>' + T.vistos.size + '<small>/' + T.paradas.length + '</small></b><span>Paradas</span></div>';
    $('tbStats').classList.remove('es-cuatro');
    tablet.querySelectorAll('[data-tb-rack]').forEach((b, i) => {
        const p = T.paradas[i];
        b.classList.toggle('es-actual', !!(T.seg && T.seg.tipo === 'pick' && T.seg.parada === p && !T.seg.hecho));
        b.classList.toggle('es-visto', T.vistos.has(p.rack));
        b.classList.toggle('es-alerta', p.picks.some((k) => k.estado === 'omitido'));
    });
    const rec = $('tbRec');
    rec.className = 'bm3d-tb-rec' + (T.pausado ? ' es-pausa' : '') + (T.final ? ' es-fin' : '');
    rec.innerHTML = '<i></i>' + (T.final ? 'TERMINADO' : T.pausado ? 'EN PAUSA' : 'EN VIVO');
    const bp = tablet.querySelector('[data-tb="pausa"]');
    bp.innerHTML = '<i class="mdi ' + (T.pausado ? 'mdi-play' : 'mdi-pause') + '"></i>';
    bp.disabled = T.final;
    tablet.querySelector('[data-tb="vel"]').textContent = (T.vel === 0.5 ? '½' : T.vel) + '×';
    tablet.classList.toggle('es-pausa', T.pausado);
    cine.classList.toggle('es-pausa', T.pausado && !T.final);
}

function planificarPicking() {
    const T = S.tour;
    if (T.cola.length) return empezar(T.cola.shift());
    if (T.terminado) return null;
    if (T.idx < T.paradas.length) {
        const p = T.paradas[T.idx]; T.idx++;
        const prisa = T.prisa; T.prisa = false;
        if (p.pa !== T.pa) {
            // se sale por el extremo hacia donde se iba y se cruza al pasillo siguiente
            const zSalida = T.sentido > 0 ? T.pa.z1 + 1.3 : T.pa.z0 - 1.6;
            T.cola.push({ tipo: 'camina', xb: T.pa.x, zb: zSalida, prisa },
                        { tipo: 'camina', xb: p.pa.x, zb: zSalida, prisa, entra: p.pa });
        }
        T.cola.push({ tipo: 'camina', xb: p.pa.x, zb: p.z - 0.15 * (p.dir || 1), prisa, dirigir: p.dir || 1 });
        T.cola.push({ tipo: 'pick', parada: p });
        return empezar(T.cola.shift());
    }
    T.terminado = true;
    T.cola.push({ tipo: 'vuelta' });
    return empezar(T.cola.shift());
}

function mostrarPick(s) {
    const T = S.tour, pd = s.parada;
    for (const c of pd.cajas) c.userData.sacar = 0;
    const pick = pd.picks.find((p) => p.estado === 'pendiente');
    limpiarFlotantes(false);
    if (!pick) { s.caja = null; marcarContorno(null); s.dur = Math.max(0.01, T.reloj - s.t0); return; }
    const c = pick.caja, it = c.userData.item, l = pick.linea, u = c.userData;
    s.pick = pick; s.caja = c;
    u.sacar = u.fila === 1 ? 0.5 : 0.3;
    marcarContorno(c, false);
    destello(c, '#16C6C9');
    const fl = document.createElement('div');
    fl.className = 'bm3d-callout es-pick';
    fl.innerHTML = '<b>RETIRAR ' + num(pick.cantidad) + ' ' + esc(it.un) + '</b><span>' + esc(it.c) + '</span>';
    callouts.appendChild(fl);
    T.etiquetas.push({ el: fl, c });
    const n = T.paradas.indexOf(pd) + 1;
    $('tbActual').innerHTML =
        '<div class="bm3d-tb-pick">' +
            '<div class="bm3d-tb-pick-top">' + (it.foto ? '<span class="bm3d-mini" style="width:58px;height:58px"><img src="' + esc(it.foto) + '" alt="" /></span>' : miniatura(null, it.color, 58)) +
                '<div><small>Parada ' + n + '/' + T.paradas.length + ' · lado ' + (pd.lado === 'izq' ? 'izquierdo' : 'derecho') + '</small><b>' + esc(it.c) + '</b><span>' + esc(it.n) + '</span></div>' +
                '<div class="bm3d-tb-pick-cant"><b>' + num(pick.cantidad) + '</b><span>' + esc(it.un) + '</span></div></div>' +
            '<div class="bm3d-tb-pick-dato"><i class="mdi mdi-map-marker-outline"></i>' + esc(pd.rack.codigo) + ' · posición ' + u.nivel + '-' + pad2(u.posicion) + ' · hay ' + num(it.q) + '</div>' +
            '<div class="bm3d-tb-pick-dato"><i class="mdi mdi-sort-clock-ascending-outline"></i><b>' + esc(l.metodo) + '</b>&nbsp;' + esc(METODO_TXT[l.metodo] || '') +
                (it.vence ? ' · vence ' + fechaCorta(it.vence) : it.ing ? ' · ingreso ' + fechaCorta(it.ing) : '') + '</div>' +
            '<div class="bm3d-tb-pick-otra" id="tbpOtra" hidden><label>Cantidad a retirar</label><input type="text" inputmode="decimal" id="tbpCant" value="' + esc(pick.cantidad) + '" /></div>' +
            '<div class="bm3d-tb-pick-otra" id="tbpMotivoBox" hidden><label>Motivo</label><textarea id="tbpMotivo" placeholder="Por qué se usa en este equipo (mínimo 5 caracteres)"></textarea></div>' +
            '<div class="bm3d-tb-pick-msg" id="tbpMsg" hidden></div>' +
            '<div class="bm3d-tb-pick-acc">' +
                '<button type="button" class="bm3d-btn es-primario es-chico" id="tbpRetirar"><i class="mdi mdi-hand-back-left-outline"></i>Retirar ' + num(pick.cantidad) + ' ' + esc(it.un) + '</button>' +
                '<button type="button" class="bm3d-btn es-contorno es-chico" id="tbpOtraBtn">Otra cantidad</button>' +
                '<button type="button" class="bm3d-btn es-ghost es-chico" id="tbpNo">No está</button>' +
            '</div></div>';
    $('tbpOtraBtn').onclick = () => { $('tbpOtra').hidden = false; $('tbpCant').focus(); $('tbpCant').select(); };
    $('tbpNo').onclick = () => { pick.estado = 'omitido'; l.noEncontrado = true; lineasPicking(); estadoTablet(); mostrarPick(s); };
    $('tbpRetirar').onclick = (e) => retirarPick(s, pick, e.currentTarget);
}

async function retirarPick(s, pick, btn) {
    const T = S.tour, c = pick.caja, it = c.userData.item, l = pick.linea;
    const otra = !$('tbpOtra').hidden;
    const cantidad = otra ? leerCant($('tbpCant').value) : pick.cantidad;
    const msg = $('tbpMsg');
    if (!cantidad) { msg.hidden = false; msg.textContent = 'Indica una cantidad mayor que cero.'; return; }
    if (cantidad > it.q + 1e-9) { msg.hidden = false; msg.textContent = 'En esta caja hay ' + num(it.q) + ' ' + it.un + '.'; return; }
    const motivo = $('tbpMotivoBox').hidden ? '' : $('tbpMotivo').value.trim();
    const html = btn.innerHTML; btn.disabled = true; btn.innerHTML = '<i class="mdi mdi-loading mdi-spin"></i>Registrando…';
    try {
        const r = await ws('RetirarPicking', { datos: JSON.stringify({ repuesto: l.id, bodega: T.plan.info.id, ubicacion: s.parada.rack.id, cantidad, orden: T.meta.orden || 0, observacion: motivo }) });
        if (S.tour !== T) return;
        pick.retirado = r.retirado;
        pick.estado = r.retirado + 1e-9 < pick.cantidad ? 'parcial' : 'ok';
        l.retirado += r.retirado;
        T.unidades += r.retirado;
        T.huboAjustes = true;
        aplicarConteoCaja(c, Math.max(0, it.q - r.retirado));
        destello(c, '#16855B');
        if (r.parcial) aviso(r.detalle, true);
        else aviso('Retirado ' + num(r.retirado) + ' ' + it.un + ' de ' + it.c + (T.meta.orden ? ' · cargado a la OT' : '') + '.');
        lineasPicking(); estadoTablet();
        mostrarPick(s);
    } catch (e) {
        btn.disabled = false; btn.innerHTML = html;
        msg.hidden = false; msg.textContent = e.message;
        if (/COMPATIBLE|MOTIVO/i.test(e.message)) { $('tbpMotivoBox').hidden = false; $('tbpMotivo').focus(); }
    }
}

function resumenPicking() {
    const T = S.tour, L = T.plan.lineas.filter((l) => (l.pedida || 0) > 0);
    const listas = L.filter((l) => estadoLinea(l)[0] === 'es-ok');
    const faltan = L.filter((l) => estadoLinea(l)[0] !== 'es-ok');
    const seg = Math.round((performance.now() - T.inicio) / 1000);
    $('tbActual').innerHTML =
        '<div class="bm3d-tb-resumen"><i class="mdi mdi-cart-check"></i><b>Picking terminado</b>' +
        '<span>' + listas.length + ' de ' + L.length + ' repuestos completos · ' + num(T.unidades) + ' un retiradas en ' + Math.floor(seg / 60) + ':' + pad2(seg % 60) + '</span>' +
        (faltan.length ? '<em>Quedan pendientes: ' + faltan.map((l) => esc(l.c) + ' (' + num(Math.max(0, l.pedida - l.retirado)) + ')').join(', ') + '</em>'
                       : '<em class="es-ok">Todo listo para entregar' + (T.meta.orden ? ' a ' + esc(T.meta.ordenTexto) : '') + '.</em>') + '</div>' +
        '<div class="bm3d-tb-fin"><button type="button" class="bm3d-btn es-primario es-chico" id="tbpFin"><i class="mdi mdi-exit-run"></i>Salir</button></div>';
    $('tbpFin').onclick = salirRecorrido;
    // lo que no se alcanzo a retirar queda en la lista para otro intento
    if (S.picking) {
        S.picking.lineas = faltan.map((l) => ({ id: l.id, c: l.c, n: l.n, un: l.un, foto: l.foto, pedida: Math.max(0, l.pedida - l.retirado) }));
        if (!S.picking.lineas.length) S.picking = null;
    }
}

// ============================================================================
//  BD/329 EN EL MAPA: posiciones, medidas, analisis, reposicion, plano,
//  historial, trabajo en equipo y escaneo
// ============================================================================
const HOY_ISO = () => { const d = new Date(); return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()); };
const DIA_MS = 86400000;
function diasHasta(iso) {
    if (!iso) return null;
    const p = String(iso).split(' ')[0].split('-').map(Number);
    const f = new Date(p[0], p[1] - 1, p[2]), h = new Date(); h.setHours(0, 0, 0, 0);
    return Math.round((f - h) / DIA_MS);
}

function leerPosiciones(lista) {
    S.posiciones = new Map();
    for (const x of lista || []) {
        if (!S.posiciones.has(x.u)) S.posiciones.set(x.u, new Map());
        S.posiciones.get(x.u).set(x.rep, { n: x.n, p: x.p, f: x.f });
    }
}
function leerPlano(lista) {
    S.plano = { racks: new Map(), zonas: [] };
    for (const x of lista || []) {
        if (x.clase === 'RACK') S.plano.racks.set(x.id, { x: x.x, z: x.z, rot: x.rot });
        else S.plano.zonas.push(x);
    }
}

// ------------------------------------------------------------------ zonas
const ZONA_COLOR = { RECEPCION: '#087BEA', CUARENTENA: '#C7352B', DESPACHO: '#16855B', MUELLE: '#B65C00', PEATONAL: '#16C6C9', OTRA: '#8792A8' };
const ZONA_TXT = { RECEPCION: 'Recepción', CUARENTENA: 'Cuarentena', DESPACHO: 'Despacho', MUELLE: 'Muelle de carga', PEATONAL: 'Paso peatonal', OTRA: 'Otra' };
function dibujarZonas(g, bodegaId) {
    for (const z of S.plano.zonas.filter((x) => x.b === bodegaId)) {
        const color = ZONA_COLOR[z.tipo] || ZONA_COLOR.OTRA;
        const geo = new THREE.PlaneGeometry(z.ancho, z.largo); S.basura.push(geo);
        const mat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.16, depthWrite: false, toneMapped: false }); S.basura.push(mat);
        const m = new THREE.Mesh(geo, mat);
        m.rotation.x = -Math.PI / 2; m.position.set(z.x + z.ancho / 2, 0.009, z.z + z.largo / 2);
        g.add(m);
        const bordes = new THREE.EdgesGeometry(geo); S.basura.push(bordes);
        const lm = new THREE.LineBasicMaterial({ color, toneMapped: false }); S.basura.push(lm);
        const l = new THREE.LineSegments(bordes, lm); l.rotation.x = -Math.PI / 2; l.position.copy(m.position); l.position.y = 0.012;
        g.add(l);
        const t = placaTexto([{ texto: (z.nombre || ZONA_TXT[z.tipo]).toUpperCase(), color, fuente: `900 64px ${FUENTE}`, y: 64 }], 1024, 128, 'rgba(0,0,0,0)', { radio: 1 });
        const w = Math.min(z.ancho * 0.9, 6);
        const tm = planoTexto(t, w, w / 8, true);
        tm.rotation.x = -Math.PI / 2; tm.rotation.z = Math.PI; tm.position.set(z.x + z.ancho / 2, 0.014, z.z + z.largo / 2);
        g.add(tm);
    }
}

// ------------------------------------------------------------------ carga por nivel
function marcarSobrecarga(rack) {
    for (const s of rack.sobrecarga || []) {
        const geo = new THREE.EdgesGeometry(new THREE.BoxGeometry(RACK.ancho - 0.02, 0.06, RACK.prof - 0.02)); S.basura.push(geo);
        aRack(rack, new THREE.LineSegments(geo, MAT.marca), 0, RACK.niveles[s.nivel - 1] + 0.03, 0);
    }
}

// ================================================================== modos de analisis
const COLOR_MODO = new Map();
function matColor(hex) {
    if (!COLOR_MODO.has(hex)) COLOR_MODO.set(hex, new THREE.MeshStandardMaterial({ color: hex, emissive: hex, emissiveIntensity: 0.35, roughness: 0.45 }));
    return COLOR_MODO.get(hex);
}
const MODOS = {
    normal: { nombre: 'Vista normal', icono: 'mdi-cube-outline', txt: 'Las cajas por tipo de repuesto.' },
    alertas: { nombre: 'Alertas de stock', icono: 'mdi-alert-decagram-outline', txt: 'Bajo mínimo y sobre máximo.' },
    rotacion: { nombre: 'Rotación ABC', icono: 'mdi-fire', txt: 'Qué se retira más (últimos 90 días) y qué conviene acercar a la entrada.' },
    quiebre: { nombre: 'Quiebre proyectado', icono: 'mdi-chart-timeline-variant-shimmer', txt: 'En cuántos días se agota cada repuesto al ritmo de consumo actual.' },
    vencimiento: { nombre: 'Por vencer', icono: 'mdi-calendar-alert', txt: 'Lotes que vencen en 30, 60 y 90 días.' },
    compatibles: { nombre: '¿Qué tengo para esta máquina?', icono: 'mdi-robot-industrial', txt: 'Los repuestos compatibles con un equipo, encendidos en el mapa.' }
};

async function cargarConsumo(forzar) {
    if (S.consumo && !forzar) return S.consumo;
    const r = await ws('Rotacion', { planta: S.planta, dias: 90 });
    const porRep = new Map();
    for (const x of r.consumo) {
        const k = x.b + '|' + x.rep;
        const a = porRep.get(k) || { sal: 0, ret: 0 };
        a.sal += x.sal; a.ret += x.ret;
        porRep.set(k, a);
    }
    // ABC por bodega segun la frecuencia de retiro (lo que define donde conviene tenerlo)
    const abc = new Map(), porBod = new Map();
    for (const [k, v] of porRep) { const b = k.split('|')[0]; if (!porBod.has(b)) porBod.set(b, []); porBod.get(b).push([k, v.ret || v.sal]); }
    for (const lista of porBod.values()) {
        lista.sort((a, b) => b[1] - a[1]);
        const total = lista.reduce((s, x) => s + x[1], 0) || 1;
        let acum = 0;
        for (const [k, v] of lista) { const antes = acum / total; acum += v; abc.set(k, antes < 0.8 ? 'A' : antes < 0.95 ? 'B' : 'C'); }
    }
    S.consumo = { dias: r.dias, porRep, abc };
    return S.consumo;
}
function stockEnBodega(b, rep) { return S.cajas.filter((c) => c.userData.item.b === b && c.userData.item.id === rep).reduce((s, c) => s + c.userData.item.q, 0); }
function consumoDe(it) {
    if (!S.consumo) return null;
    const v = S.consumo.porRep.get(it.b + '|' + it.id);
    if (!v || !v.sal) return null;
    const diario = v.sal / S.consumo.dias, total = stockEnBodega(it.b, it.id);
    return { diario, total, dias: diario > 0 ? total / diario : null, alMinimo: diario > 0 && it.min != null ? Math.max(0, (total - it.min) / diario) : null, clase: S.consumo.abc.get(it.b + '|' + it.id), ret: v.ret };
}

function matModo(c) {
    const it = c.userData.item;
    switch (S.modo) {
        case 'alertas': { const e = estadoDe(it); return e === 'bajo' ? MAT_ALERTA.bajo : e === 'sobre' ? MAT_ALERTA.sobre : null; }
        case 'rotacion': { const k = consumoDe(it); return k && k.clase ? matColor({ A: '#6732F4', B: '#087BEA', C: '#8FA3C0' }[k.clase]) : null; }
        case 'quiebre': { const k = consumoDe(it); if (!k || k.dias == null) return null; return matColor(k.dias < 15 ? '#C7352B' : k.dias < 30 ? '#B65C00' : '#16855B'); }
        case 'vencimiento': { const d = diasHasta(it.vence); if (d == null || d > 90) return null; return matColor(d <= 30 ? '#C7352B' : d <= 60 ? '#B65C00' : '#087BEA'); }
        case 'compatibles': return S.compat && S.compat.set.has(it.id) ? matColor('#16C6C9') : null;
    }
    return null;
}

async function cambiarModo(m) {
    S.modo = m;
    S.modoAlertas = m === 'alertas';
    root.querySelector('[data-modo="alertas"]').classList.toggle('is-activo', m === 'alertas');
    root.querySelector('[data-accion="analisis"]').classList.toggle('is-activo', m !== 'normal' && m !== 'alertas');
    if ((m === 'rotacion' || m === 'quiebre') && !S.consumo) {
        try { await cargarConsumo(); } catch (e) { aviso(e.message, true); }
    }
    aplicarFiltros();
    if (m !== 'normal') panelAnalisis();
}

function panelAnalisis() {
    const m = S.modo, info = S.porBodega.get(S.bodegaSel);
    if (!info) return;
    const tarjetas = '<div class="bm3d-modos">' + Object.entries(MODOS).map(([k, v]) =>
        '<button type="button" class="bm3d-modo' + (k === m ? ' is-sel' : '') + '" data-modo-sel="' + k + '"><i class="mdi ' + v.icono + '"></i><b>' + esc(v.nombre) + '</b><span>' + esc(v.txt) + '</span></button>').join('') + '</div>';
    let cuerpo = '';
    const cajas = info.cajas.filter((c) => !c.userData.rack.recepcion);
    const fila = (c, der, extra) => { const it = c.userData.item; return '<div class="bm3d-item" data-an="' + S.cajas.indexOf(c) + '">' + miniatura(it.foto, it.color) + '<div><b>' + esc(it.c) + '</b><span>' + esc(ubicTexto(c, true)) + ' · ' + esc(it.n) + '</span></div><em>' + der + (extra ? '<small>' + extra + '</small>' : '') + '</em></div>'; };

    if (m === 'alertas') {
        const bajos = cajas.filter((c) => estadoDe(c.userData.item) === 'bajo');
        cuerpo = '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Bajo mínimo</span><span>' + bajos.length + '</span></div>' +
            (bajos.length ? bajos.slice(0, 40).map((c) => fila(c, num(c.userData.item.q), 'mín. ' + num(c.userData.item.min))).join('') : '<div class="bm3d-vacio-txt">Nada bajo mínimo en esta bodega.</div>') + '</div>';
    } else if (m === 'rotacion' || m === 'quiebre') {
        const conDatos = cajas.map((c) => [c, consumoDe(c.userData.item)]).filter((x) => x[1]);
        if (!conDatos.length) cuerpo = '<div class="bm3d-nota"><i class="mdi mdi-information-outline"></i><span>No hay entregas ni mermas en los últimos 90 días en esta bodega. La rotación y la proyección aparecen a medida que se registran salidas por consumo.</span></div>';
        else if (m === 'rotacion') {
            const cuenta = { A: 0, B: 0, C: 0 };
            conDatos.forEach(([, k]) => { if (k.clase) cuenta[k.clase]++; });
            const sug = sugerenciasABC(info);
            cuerpo = '<div class="bm3d-stock"><div><b>' + cuenta.A + '</b><span>Clase A · 80 %</span></div><div><b>' + cuenta.B + '</b><span>Clase B · 15 %</span></div><div><b>' + cuenta.C + '</b><span>Clase C · 5 %</span></div></div>' +
                '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Acercar a la entrada</span><span>' + sug.length + '</span></div>' +
                (sug.length ? sug.map((s, i) => '<div class="bm3d-sug"><div><b>' + esc(s.caja.userData.item.c) + '</b><span>' + esc(corto(s.caja.userData.rack.codigo)) + ' → ' + esc(s.destino.codigo) + ' · ' + s.caja.userData.item.n.slice(0, 40) + '</span></div>' +
                    (S.permisos.ajuste ? '<button type="button" class="bm3d-btn es-secundario es-chico" data-sug="' + i + '"><i class="mdi mdi-swap-horizontal"></i>Mover</button>' : '') + '</div>').join('')
                    : '<div class="bm3d-vacio-txt">Lo de alta rotación ya está cerca de la entrada.</div>') + '</div>' +
                '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Más retirados</span></div>' +
                conDatos.sort((a, b) => b[1].ret - a[1].ret).slice(0, 15).map(([c, k]) => fila(c, k.ret + ' retiros', 'clase ' + k.clase)).join('') + '</div>';
            S.sugerencias = sug;
        } else {
            const lista = conDatos.filter(([, k]) => k.dias != null).sort((a, b) => a[1].dias - b[1].dias);
            cuerpo = '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Se agota primero</span><span>' + lista.length + '</span></div>' +
                lista.slice(0, 30).map(([c, k]) => fila(c, '~' + Math.round(k.dias) + ' días', num(k.diario) + '/día · hay ' + num(k.total))).join('') + '</div>' +
                (S.permisos.stock ? '<button type="button" class="bm3d-btn es-contorno" id="bm3dAnRepo" style="width:100%"><i class="mdi mdi-cart-plus"></i>Solicitar reposición de lo crítico</button>' : '');
        }
    } else if (m === 'vencimiento') {
        const lista = cajas.filter((c) => c.userData.item.vence).map((c) => [c, diasHasta(c.userData.item.vence)]).filter((x) => x[1] <= 90).sort((a, b) => a[1] - b[1]);
        cuerpo = '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Vencen en 90 días</span><span>' + lista.length + '</span></div>' +
            (lista.length ? lista.map(([c, d]) => fila(c, d < 0 ? 'Vencido' : d + ' días', fechaCorta(c.userData.item.vence))).join('') : '<div class="bm3d-vacio-txt">Nada vence en los próximos 90 días en esta bodega.</div>') + '</div>';
    } else if (m === 'compatibles') {
        cuerpo = '<div class="bm3d-campo es-ancho"><label>Equipo</label><select id="fAnActivo"><option value="">Cargando equipos…</option></select></div><div id="bm3dAnCompat" style="margin-top:12px"></div>';
    }

    abrirPanel(cab(info.bodega.nombre, 'Análisis de la bodega', MODOS[m].nombre, 'mdi-chart-box-outline'), tarjetas + cuerpo,
        '<button type="button" class="bm3d-btn es-ghost" id="bm3dAnSalir"><i class="mdi mdi-close"></i>Volver a la vista normal</button>');
    panel.querySelectorAll('[data-modo-sel]').forEach((b) => b.onclick = () => cambiarModo(b.dataset.modoSel));
    panel.querySelectorAll('[data-an]').forEach((el) => el.onclick = () => seleccionarCaja(S.cajas[+el.dataset.an], true));
    panel.querySelectorAll('[data-sug]').forEach((b) => b.onclick = (e) => moverSugerencia(S.sugerencias[+b.dataset.sug], e.currentTarget));
    $('bm3dAnSalir').onclick = () => { cambiarModo('normal'); cerrarPanel(); };
    const ar = $('bm3dAnRepo'); if (ar) ar.onclick = () => formReposicion(info.id, 'quiebre');
    if (m === 'compatibles') cargarActivos();
}

/* Lo de clase A que esta en la mitad mas lejana de la entrada, y a donde
   llevarlo: el rack mas cercano a la entrada que tenga espacio. */
function sugerenciasABC(info) {
    const racks = info.racks.slice().sort((a, b) => a.pos.z - b.pos.z);
    if (racks.length < 2) return [];
    const corte = racks[Math.floor(racks.length / 2)].pos.z;
    const libres = new Map(racks.map((r) => [r, RACK.niveles.length * r.cols * (r.filas || 1) - r.items.length]));
    const sug = [];
    for (const c of info.cajas) {
        const r = c.userData.rack, k = consumoDe(c.userData.item);
        if (r.recepcion || !k || k.clase !== 'A' || r.pos.z < corte) continue;
        const destino = racks.find((x) => x !== r && x.pos.z < corte && libres.get(x) > 0);
        if (!destino) break;
        libres.set(destino, libres.get(destino) - 1);
        sug.push({ caja: c, destino });
        if (sug.length >= 10) break;
    }
    return sug;
}
async function moverSugerencia(s, btn) {
    if (!s) return;
    await guardando(btn, async () => {
        const it = s.caja.userData.item;
        const r = await ws('ReubicarCaja', { datos: JSON.stringify({ repuesto: it.id, bodega: it.b, origen: s.caja.userData.rack.id, destino: s.destino.id, observacion: 'Reubicación por rotación ABC (clase A más cerca de la entrada) desde el mapa 3D.' }) });
        aviso(r.parcial ? r.detalle : 'Movido ' + it.c + ' a ' + s.destino.codigo + '.', r.parcial);
        await refrescarStock(true);
        await cargarConsumo(true);
        aplicarFiltros();
        panelAnalisis();
    });
}

async function cargarActivos() {
    const s = $('fAnActivo'), box = $('bm3dAnCompat');
    try {
        const r = await ws('Activos', { planta: S.planta });
        if (!r.activos.length) { s.innerHTML = '<option value="">No hay equipos en esta planta</option>'; box.innerHTML = '<div class="bm3d-vacio-txt">Carga los equipos y sus compatibilidades (Centro de repuestos › Compatibilidades) para usar esta vista.</div>'; return; }
        s.innerHTML = '<option value="">Elige un equipo…</option>' + r.activos.map((a) => '<option value="' + a.id + '"' + (S.compat && S.compat.activo === a.id ? ' selected' : '') + '>' + esc(a.codigo + ' · ' + a.nombre + (a.modelo ? ' (' + a.modelo + ')' : '') + ' · ' + a.compatibles + ' compatibles') + '</option>').join('');
        s.onchange = () => elegirActivo(+s.value);
        if (S.compat) pintarCompatibles();
    } catch (e) { aviso(e.message, true); }
}
async function elegirActivo(id) {
    if (!id) { S.compat = null; aplicarFiltros(); $('bm3dAnCompat').innerHTML = ''; return; }
    try {
        const r = await ws('Compatibles', { activo: id });
        S.compat = { activo: id, lista: r.repuestos, set: new Set(r.repuestos.map((x) => x.rep)) };
        aplicarFiltros();
        pintarCompatibles();
    } catch (e) { aviso(e.message, true); }
}
function pintarCompatibles() {
    const box = $('bm3dAnCompat'); if (!box || !S.compat) return;
    const conStock = S.cajas.filter((c) => S.compat.set.has(c.userData.item.id));
    const sinStock = S.compat.lista.filter((x) => !conStock.some((c) => c.userData.item.id === x.rep));
    box.innerHTML = '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Con stock en la planta</span><span>' + conStock.length + '</span></div>' +
        (conStock.length ? conStock.map((c) => { const it = c.userData.item; return '<div class="bm3d-item" data-an="' + S.cajas.indexOf(c) + '">' + miniatura(it.foto, it.color) + '<div><b>' + esc(it.c) + '</b><span>' + esc(ubicTexto(c, true)) + ' · ' + esc(it.n) + '</span></div><em>' + num(it.q) + '<small>' + esc((S.compat.lista.find((x) => x.rep === it.id) || {}).regla || '') + '</small></em></div>'; }).join('')
            : '<div class="bm3d-vacio-txt">Ningún repuesto compatible tiene stock en esta planta.</div>') + '</div>' +
        (sinStock.length ? '<div class="bm3d-nota es-alerta"><i class="mdi mdi-alert-outline"></i><span>' + sinStock.length + ' repuesto(s) compatibles sin stock en esta planta.</span></div>' : '');
    box.querySelectorAll('[data-an]').forEach((el) => el.onclick = () => seleccionarCaja(S.cajas[+el.dataset.an], true));
}

// ================================================================== reposicion
function candidatosReposicion(bodegaId, criterio) {
    const porRep = new Map();
    for (const c of S.cajas) {
        const it = c.userData.item;
        if (it.b !== bodegaId) continue;
        const a = porRep.get(it.id) || { it, q: 0 };
        a.q += it.q; porRep.set(it.id, a);
    }
    const lista = [];
    for (const { it, q } of porRep.values()) {
        const k = consumoDe(it);
        const critico = (it.min != null && q < it.min) || (it.pr != null && q <= it.pr) || (criterio === 'quiebre' && k && k.dias != null && k.dias < 30);
        if (!critico) continue;
        const meta = it.max != null ? it.max : it.pr != null ? it.pr * 1.5 : it.min != null ? it.min * 2 : q + 1;
        lista.push({ it, q, sugerida: Math.max(1, Math.ceil(meta - q)), dias: k ? k.dias : null });
    }
    return lista.sort((a, b) => (a.q / (a.it.min || 1)) - (b.q / (b.it.min || 1)));
}
async function formReposicion(bodegaId, criterio) {
    const info = S.porBodega.get(bodegaId); if (!info) return;
    const lista = candidatosReposicion(bodegaId, criterio);
    let previas = [];
    try { previas = (await ws('Reposiciones', { bodega: bodegaId })).solicitudes; } catch (e) { /* sin historial */ }
    abrirPanel(cab(info.bodega.nombre, 'Solicitud de reposición', lista.length + ' repuesto(s) críticos', 'mdi-cart-plus'),
        (lista.length ? '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Qué pedir</span><span>hasta el máximo</span></div>' +
            lista.map((l, i) => '<div class="bm3d-pk-linea"><label class="bm3d-check is-on" style="padding:0;border:0;background:none"><input type="checkbox" data-rp-on="' + i + '" checked /></label>' +
                '<div><b>' + esc(l.it.c) + '</b><span>' + esc(l.it.n) + '</span><small>hay ' + num(l.q) + ' · mín. ' + num(l.it.min) + ' · máx. ' + num(l.it.max) + (l.dias != null ? ' · se agota en ~' + Math.round(l.dias) + ' d' : '') + '</small></div>' +
                '<input type="text" inputmode="decimal" data-rp-cant="' + i + '" value="' + l.sugerida + '" /><span style="font-size:11px;color:#68738A">' + esc(l.it.un) + '</span></div>').join('') +
            '<div class="bm3d-campo es-ancho" style="margin-top:8px"><label>Observación</label><textarea id="fRpObs" placeholder="Proveedor sugerido, urgencia…"></textarea></div></div>'
            : '<div class="bm3d-vacio-txt">No hay repuestos bajo mínimo ni en punto de reposición en esta bodega.</div>') +
        '<div class="bm3d-seccion"><div class="bm3d-seccion-tit"><span>Solicitudes recientes</span><span>' + previas.length + '</span></div>' +
        (previas.length ? previas.slice(0, 12).map((s) => '<div class="bm3d-sol"><div><b>N° ' + s.numero + ' · ' + esc(s.fecha) + '</b><span>' + s.lineas.length + ' repuesto(s) · ' + esc(s.usuario) + '</span></div>' +
            '<span class="bm3d-estado-chip es-' + ({ PENDIENTE: 'sin', ENVIADA: 'sobre', RECIBIDA: 'ok', ANULADA: 'bajo' }[s.estado]) + '">' + esc(s.estado.toLowerCase()) + '</span>' +
            '<div class="bm3d-sol-acc"><button type="button" title="Imprimir" data-rp-imp="' + s.id + '"><i class="mdi mdi-printer-outline"></i></button>' +
            (S.permisos.stock && s.estado === 'PENDIENTE' ? '<button type="button" title="Marcar enviada" data-rp-est="' + s.id + '|ENVIADA"><i class="mdi mdi-send-outline"></i></button>' : '') +
            (S.permisos.stock && s.estado === 'ENVIADA' ? '<button type="button" title="Marcar recibida" data-rp-est="' + s.id + '|RECIBIDA"><i class="mdi mdi-package-variant-closed-check"></i></button>' : '') +
            (S.permisos.stock && (s.estado === 'PENDIENTE' || s.estado === 'ENVIADA') ? '<button type="button" title="Anular" data-rp-est="' + s.id + '|ANULADA"><i class="mdi mdi-cancel"></i></button>' : '') +
            '</div></div>').join('') : '<div class="bm3d-vacio-txt">Todavía no hay solicitudes en esta bodega.</div>') + '</div>',
        '<button type="button" class="bm3d-btn es-ghost" id="fRpCerrar">Cerrar</button>' +
        (lista.length && S.permisos.stock ? '<button type="button" class="bm3d-btn es-primario" id="fRpCrear"><i class="mdi mdi-cart-check"></i>Crear solicitud</button>' : ''));
    $('fRpCerrar').onclick = cerrarPanel;
    panel.querySelectorAll('[data-rp-imp]').forEach((b) => b.onclick = () => imprimirReposicion(previas.find((s) => s.id === +b.dataset.rpImp)));
    panel.querySelectorAll('[data-rp-est]').forEach((b) => b.onclick = async () => {
        const [id, est] = b.dataset.rpEst.split('|');
        try { await ws('EstadoReposicion', { id: +id, estado: est }); aviso('Solicitud ' + est.toLowerCase() + '.'); formReposicion(bodegaId, criterio); } catch (e) { aviso(e.message, true); }
    });
    const cr = $('fRpCrear');
    if (cr) cr.onclick = (e) => guardando(e.currentTarget, async () => {
        const lineas = [];
        lista.forEach((l, i) => {
            if (!panel.querySelector('[data-rp-on="' + i + '"]').checked) return;
            const q = leerCant(panel.querySelector('[data-rp-cant="' + i + '"]').value);
            if (q > 0) lineas.push({ repuesto: l.it.id, cantidad: q, stock: l.q, minimo: l.it.min, maximo: l.it.max });
        });
        if (!lineas.length) throw new Error('Marca al menos un repuesto con cantidad.');
        const r = await ws('CrearReposicion', { datos: JSON.stringify({ bodega: bodegaId, observacion: val('fRpObs'), lineas }) });
        aviso(r.detalle);
        const todas = (await ws('Reposiciones', { bodega: bodegaId })).solicitudes;
        imprimirReposicion(todas.find((s) => s.id === r.id));
        formReposicion(bodegaId, criterio);
    });
}
function imprimirReposicion(s) {
    if (!s) return;
    const v = window.open('', '_blank', 'width=900,height=700');
    if (!v) { aviso('El navegador bloqueó la ventana: permite las ventanas emergentes para este sitio.', true); return; }
    const filas = s.lineas.map((l) => '<tr><td>' + esc(l.c) + '</td><td>' + esc(l.n) + '</td><td class="n">' + num(l.stock) + '</td><td class="n">' + num(l.minimo) + '</td><td class="n">' + num(l.maximo) + '</td><td class="n"><b>' + num(l.cantidad) + '</b> ' + esc(l.un) + '</td></tr>').join('');
    v.document.write('<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Solicitud de reposición N° ' + s.numero + '</title><style>' +
        'body{font-family:"Segoe UI",Arial,sans-serif;color:#17223B;margin:32px}h1{font-size:20px;margin:0 0 4px}p{margin:0 0 16px;color:#68738A}' +
        'table{width:100%;border-collapse:collapse;font-size:12px}th,td{border-bottom:1px solid #E2E7F0;padding:7px 6px;text-align:left}th{font-size:11px;text-transform:uppercase;color:#4A556D}.n{text-align:right}' +
        '.pie{margin-top:40px;display:flex;gap:60px}.pie div{border-top:1px solid #17223B;padding-top:6px;width:220px;font-size:12px}@media print{button{display:none}}</style></head><body>' +
        '<h1>Solicitud de reposición N° ' + s.numero + '</h1><p>' + esc(s.bodega) + ' · ' + esc(s.fecha) + ' · ' + esc(s.usuario) + ' · estado ' + esc(s.estado.toLowerCase()) + (s.observacion ? '<br>' + esc(s.observacion) : '') + '</p>' +
        '<table><thead><tr><th>Código</th><th>Repuesto</th><th class="n">Stock</th><th class="n">Mínimo</th><th class="n">Máximo</th><th class="n">Solicitado</th></tr></thead><tbody>' + filas + '</tbody></table>' +
        '<div class="pie"><div>Solicita</div><div>Autoriza</div></div><p style="margin-top:20px"><button onclick="window.print()">Imprimir</button></p></body></html>');
    v.document.close();
}

// ================================================================== posiciones fijas
async function guardarPosicionesRack(rack, lista) {
    await ws('GuardarPosiciones', { ubicacion: rack.id, lista: JSON.stringify(lista) });
    await recargar(true);
}
function listaPosicionesActual(rack) {
    return rack.cajas.map((c) => ({ repuesto: c.userData.item.id, nivel: c.userData.nivel, posicion: c.userData.posicion, fila: c.userData.fila || 0 }));
}
function formPosicion(c) {
    const rack = c.userData.rack, it = c.userData.item;
    const opcNivel = RACK.niveles.map((_, i) => [i + 1, 'Nivel ' + (i + 1)]).reverse();
    const opcPos = Array.from({ length: rack.cols }, (_, i) => [i + 1, 'Posición ' + pad2(i + 1)]);
    const filas = (rack.filas || 1) > 1;
    abrirPanel(cab(rack.codigo, 'Cambiar de posición', it.c, 'mdi-grid'),
        '<div class="bm3d-form">' +
        campo('Nivel', sel('fPosN', opcNivel, c.userData.nivel)) +
        campo('Posición', sel('fPosP', opcPos, c.userData.posicion)) +
        (filas ? campo('Fondo', sel('fPosF', [[0, 'Adelante'], [1, 'Atrás']], c.userData.fila || 0), { ancho: true }) : '') +
        '</div><div class="bm3d-nota" id="fPosNota" style="margin-top:12px"></div>' +
        '<div class="bm3d-nota" style="margin-top:8px"><i class="mdi mdi-information-outline"></i><span>Al guardar, <b>todo el rack</b> queda con sus posiciones fijas (planograma): la etiqueta de cada casillero pasa a ser un registro. El stock sigue siendo del rack.</span></div>',
        '<button type="button" class="bm3d-btn es-ghost" id="fPosCancelar">Cancelar</button><button type="button" class="bm3d-btn es-primario" id="fPosGuardar"><i class="mdi mdi-content-save-outline"></i>Guardar posición</button>',
        () => panelItem(c));
    const ocupante = () => rack.cajas.find((x) => x !== c && x.userData.nivel === +val('fPosN') && x.userData.posicion === +val('fPosP') && (x.userData.fila || 0) === (filas ? +val('fPosF') : 0));
    const nota = () => { const o = ocupante(); $('fPosNota').innerHTML = o ? '<i class="mdi mdi-swap-horizontal"></i><span>Intercambia con <b>' + esc(o.userData.item.c) + '</b>.</span>' : '<i class="mdi mdi-check-circle-outline"></i><span>El casillero está libre.</span>'; };
    ['fPosN', 'fPosP', 'fPosF'].forEach((id) => { const e = $(id); if (e) e.onchange = nota; });
    nota();
    $('fPosCancelar').onclick = () => panelItem(c);
    $('fPosGuardar').onclick = (e) => guardando(e.currentTarget, async () => {
        const lista = listaPosicionesActual(rack), o = ocupante();
        const yo = lista.find((x) => x.repuesto === it.id);
        if (o) { const otro = lista.find((x) => x.repuesto === o.userData.item.id); otro.nivel = yo.nivel; otro.posicion = yo.posicion; otro.fila = yo.fila; }
        yo.nivel = +val('fPosN'); yo.posicion = +val('fPosP'); yo.fila = filas ? +val('fPosF') : 0;
        await guardarPosicionesRack(rack, lista);
        aviso('Posición guardada: ' + it.c + ' en ' + yo.nivel + '-' + pad2(yo.posicion) + '.');
        const nueva = S.cajas.find((x) => x.userData.item.id === it.id && x.userData.rack.id === rack.id);
        if (nueva) seleccionarCaja(nueva, true);
    });
}

// ================================================================== plano editable
function huella(rot) { const lado = Math.abs(Math.sin(rot)) > 0.5; return lado ? { x: RACK.prof / 2, z: RACK.ancho / 2 } : { x: RACK.ancho / 2, z: RACK.prof / 2 }; }
function seCruza(rack, x, z, rot) {
    const a = huella(rot);
    for (const r of rack.info.racks) {
        if (r === rack) continue;
        const b = huella(r.rot);
        if (Math.abs(r.pos.x - x) < a.x + b.x - 0.02 && Math.abs(r.pos.z - z) < a.z + b.z - 0.02) return r;
    }
    return null;
}
function iniciarMoverRack(rack) {
    cerrarPanel();
    const geo = new THREE.BoxGeometry(RACK.ancho, RACK.alto, RACK.prof);
    const m = new THREE.Mesh(geo, MAT.fantasmaHover);
    const borde = new THREE.LineSegments(new THREE.EdgesGeometry(geo), MAT.contorno); m.add(borde);
    const frente = new THREE.Mesh(new THREE.PlaneGeometry(RACK.ancho, 0.25), MAT.laser); frente.position.set(0, -RACK.alto / 2 + 0.15, RACK.prof / 2 + 0.01); m.add(frente);
    m.position.set(rack.pos.x, RACK.alto / 2, rack.pos.z); m.rotation.y = rack.rot;
    capaEdicion.add(m);
    S.moverRack = { rack, x: rack.pos.x, z: rack.pos.z, rot: rack.rot, m, geo };
    controls.enableRotate = false;
    const p = $('bm3dPick');
    p.innerHTML = '<i class="mdi mdi-cursor-move"></i><span id="bm3dMoverTxt">Mueve el puntero para ubicar ' + esc(rack.codigo) + ' · <kbd>R</kbd> gira 90° · clic guarda · <kbd>Esc</kbd> cancela</span><button type="button">Cancelar</button>';
    p.hidden = false;
    p.querySelector('button').onclick = terminarMoverRack;
}
const _plano = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0), _pt = new THREE.Vector3();
function puntoPiso(ev) {
    const r = renderer.domElement.getBoundingClientRect();
    puntero.x = ((ev.clientX - r.left) / r.width) * 2 - 1; puntero.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
    camera.updateMatrixWorld();
    ray.setFromCamera(puntero, camera);
    return ray.ray.intersectPlane(_plano, _pt) ? _pt.clone() : null;
}
function moverRackPuntero(ev) {
    const M = S.moverRack, q = puntoPiso(ev); if (!q) return;
    M.x = Math.round(q.x * 10) / 10; M.z = Math.round(q.z * 10) / 10;
    M.m.position.set(M.x, RACK.alto / 2, M.z);
    const choca = seCruza(M.rack, M.x, M.z, M.rot);
    M.m.material = choca ? MAT_ALERTA.bajo : MAT.fantasmaHover;
    $('bm3dMoverTxt').innerHTML = choca ? 'Se cruza con <b>' + esc(choca.codigo) + '</b>: muévelo a un lugar libre' : esc(M.rack.codigo) + ' en x ' + (M.x - M.rack.info.ox).toFixed(1) + ' · z ' + M.z.toFixed(1) + ' m · <kbd>R</kbd> gira · clic guarda';
}
async function guardarMoverRack() {
    const M = S.moverRack; if (!M) return;
    if (seCruza(M.rack, M.x, M.z, M.rot)) { aviso('Ese lugar se cruza con otro rack.', true); return; }
    const rack = M.rack;
    terminarMoverRack();
    try {
        await ws('GuardarPlanoRack', { ubicacion: rack.id, x: M.x - rack.info.ox, z: M.z, rot: M.rot });
        aviso('Rack ' + rack.codigo + ' movido en el plano.');
        await recargar(true);
        const r2 = S.racks.find((x) => x.id === rack.id); if (r2) seleccionarRack(r2, true);
    } catch (e) { aviso(e.message, true); }
}
function terminarMoverRack() {
    const M = S.moverRack; if (!M) return;
    capaEdicion.remove(M.m); M.geo.dispose();
    S.moverRack = null;
    controls.enableRotate = true;
    $('bm3dPick').hidden = true;
}

/* Dibujar una zona: se arrastra un rectangulo sobre el piso. */
function iniciarDibujoZona(info, cb) {
    cerrarPanel();
    S.dibujo = { info, cb, inicio: null, m: null };
    controls.enabled = false;
    const p = $('bm3dPick');
    p.innerHTML = '<i class="mdi mdi-vector-square"></i>Arrastra sobre el piso de ' + esc(info.bodega.nombre) + ' para marcar la zona<button type="button">Cancelar</button>';
    p.hidden = false;
    p.querySelector('button').onclick = () => terminarDibujo(null);
}
function rectDibujo(a, b, info) {
    const x0 = Math.min(a.x, b.x) - info.ox, x1 = Math.max(a.x, b.x) - info.ox, z0 = Math.min(a.z, b.z), z1 = Math.max(a.z, b.z);
    const r1 = (v) => Math.round(v * 10) / 10;
    return { x: r1(x0), z: r1(z0), ancho: r1(Math.max(0.5, x1 - x0)), largo: r1(Math.max(0.5, z1 - z0)) };
}
function dibujoPuntero(ev, fase) {
    const D = S.dibujo, q = puntoPiso(ev); if (!q) return;
    if (fase === 'inicio') { D.inicio = q; return; }
    if (!D.inicio) return;
    const r = rectDibujo(D.inicio, q, D.info);
    if (!D.m) { D.m = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), MAT.fantasmaHover); D.m.rotation.x = -Math.PI / 2; capaEdicion.add(D.m); }
    D.m.scale.set(r.ancho, r.largo, 1);
    D.m.position.set(D.info.ox + r.x + r.ancho / 2, 0.02, r.z + r.largo / 2);
    if (fase === 'fin') terminarDibujo(r);
}
function terminarDibujo(rect) {
    const D = S.dibujo; if (!D) return;
    if (D.m) { capaEdicion.remove(D.m); D.m.geometry.dispose(); }
    S.dibujo = null;
    controls.enabled = true;
    $('bm3dPick').hidden = true;
    D.cb(rect);
}

function panelZonas(info) {
    const zonas = S.plano.zonas.filter((z) => z.b === info.id);
    abrirPanel(cab(info.bodega.nombre, 'Zonas del piso', zonas.length + ' zona(s)', 'mdi-vector-square'),
        (zonas.length ? zonas.map((z) => '<div class="bm3d-sol"><i class="bm3d-punto" style="background:' + (ZONA_COLOR[z.tipo] || '#8792A8') + '"></i><div><b>' + esc(z.nombre) + '</b><span>' + esc(ZONA_TXT[z.tipo] || z.tipo) + ' · ' + num(z.ancho) + ' × ' + num(z.largo) + ' m</span></div>' +
            (S.permisos.bodegas ? '<div class="bm3d-sol-acc"><button type="button" title="Editar" data-zn-ed="' + z.id + '"><i class="mdi mdi-pencil-outline"></i></button><button type="button" title="Eliminar" data-zn-del="' + z.id + '"><i class="mdi mdi-delete-outline"></i></button></div>' : '') + '</div>').join('')
            : '<div class="bm3d-vacio-txt">Marca en el piso dónde se recibe, dónde va lo en cuarentena, el despacho o el muelle.</div>'),
        '<button type="button" class="bm3d-btn es-ghost" id="fZnVolver">Volver</button>' + (S.permisos.bodegas ? '<button type="button" class="bm3d-btn es-primario" id="fZnNueva"><i class="mdi mdi-plus"></i>Nueva zona</button>' : ''),
        () => panelBodega(info));
    $('fZnVolver').onclick = () => panelBodega(info);
    const nz = $('fZnNueva'); if (nz) nz.onclick = () => formZona(info, null);
    panel.querySelectorAll('[data-zn-ed]').forEach((b) => b.onclick = () => formZona(info, zonas.find((z) => z.id === +b.dataset.znEd)));
    panel.querySelectorAll('[data-zn-del]').forEach((b) => b.onclick = async () => {
        if (b.dataset.confirmar !== '1') { b.dataset.confirmar = '1'; b.innerHTML = '<i class="mdi mdi-delete-alert-outline"></i>'; b.title = 'Clic otra vez para eliminar'; return; }
        try { await ws('QuitarZona', { id: +b.dataset.znDel }); aviso('Zona eliminada.'); await recargar(true); panelZonas(S.porBodega.get(info.id)); } catch (e) { aviso(e.message, true); }
    });
}
function formZona(info, z, rect) {
    const d = rect ? Object.assign({}, z || {}, rect) : (z || { tipo: 'RECEPCION', nombre: '', x: 1, z: 1, ancho: 4, largo: 3 });
    abrirPanel(cab(info.bodega.nombre, z ? 'Editar zona' : 'Nueva zona', '', 'mdi-vector-square'),
        '<div class="bm3d-form">' +
        campo('Tipo', sel('fZnTipo', Object.entries(ZONA_TXT), d.tipo || 'RECEPCION')) +
        campo('Nombre', inp('fZnNom', d.nombre || '', { ph: 'Ej. Recepción proveedores' })) +
        campo('Desde x (m)', inp('fZnX', d.x, { paso: true })) + campo('Desde z (m)', inp('fZnZ', d.z, { paso: true })) +
        campo('Ancho (m)', inp('fZnA', d.ancho, { paso: true })) + campo('Largo (m)', inp('fZnL', d.largo, { paso: true })) +
        '</div><button type="button" class="bm3d-btn es-secundario" id="fZnDibujar" style="width:100%;margin-top:12px"><i class="mdi mdi-gesture-tap-box"></i>Dibujar en el piso</button>',
        '<button type="button" class="bm3d-btn es-ghost" id="fZnCancelar">Cancelar</button><button type="button" class="bm3d-btn es-primario" id="fZnGuardar"><i class="mdi mdi-content-save-outline"></i>Guardar zona</button>',
        () => panelZonas(info));
    const actual = () => ({ id: z ? z.id : 0, tipo: val('fZnTipo'), nombre: val('fZnNom'), x: leerCant(val('fZnX')) || 0, z: leerCant(val('fZnZ')) || 0, ancho: leerCant(val('fZnA')), largo: leerCant(val('fZnL')) });
    $('fZnCancelar').onclick = () => panelZonas(info);
    $('fZnDibujar').onclick = () => { const a = actual(); iniciarDibujoZona(info, (r) => formZona(info, z ? Object.assign({}, z, a) : a, r)); };
    $('fZnGuardar').onclick = (e) => guardando(e.currentTarget, async () => {
        const a = actual();
        const r = await ws('GuardarZona', { datos: JSON.stringify(Object.assign({ bodega: info.id }, a)) });
        aviso(r.detalle);
        await recargar(true);
        panelZonas(S.porBodega.get(info.id));
    });
}

// ================================================================== trabajo en equipo
/* Cada 15 s se pregunta si otro usuario cambio algo. Si hay un formulario
   abierto no se interrumpe: se ofrece actualizar. */
function avisoAccion(texto, boton, cb) {
    const t = document.createElement('div');
    t.className = 'bm3d-toast es-accion';
    t.innerHTML = '<i class="mdi mdi-account-sync-outline"></i><span>' + esc(texto) + '</span><button type="button">' + esc(boton) + '</button>';
    t.querySelector('button').onclick = () => { t.remove(); cb(); };
    $('bm3dToasts').appendChild(t);
    setTimeout(() => { if (t.parentNode) { t.style.transition = 'opacity .4s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 400); } }, 20000);
}
function formularioAbierto() { return panel.classList.contains('is-abierto') && !!panel.querySelector('.bm3d-form, .bm3d-pk-linea, input[type="text"]'); }
let consultandoVersion = false, avisoPendiente = false;
async function revisarVersion() {
    if (document.hidden || S.tour || S.historial || S.moverRack || S.dibujo || !S.version || consultandoVersion || avisoPendiente) return;
    consultandoVersion = true;
    try {
        const v = (await ws('Version', { planta: S.planta })).version;
        const cambioEst = v.est !== S.version.est, cambioMov = v.mov !== S.version.mov;
        if (!cambioEst && !cambioMov) return;
        const quien = v.usuario ? ' (' + v.usuario + ', ' + v.fecha + ')' : '';
        const hacer = async () => {
            avisoPendiente = false;
            if (cambioEst) await recargar(true); else await refrescarStock(true);
            if (S.modo === 'rotacion' || S.modo === 'quiebre') { await cargarConsumo(true); aplicarFiltros(); }
        };
        if (formularioAbierto()) { avisoPendiente = true; avisoAccion((cambioEst ? 'Otro usuario cambió la bodega' : 'Hay movimientos nuevos') + quien + '.', 'Actualizar', hacer); }
        else { await hacer(); aviso((cambioEst ? 'El mapa se actualizó con cambios de otro usuario' : 'Stock actualizado: movimiento nuevo') + quien + '.'); }
    } catch (e) { /* sin red: se reintenta en la siguiente vuelta */ }
    finally { consultandoVersion = false; }
}

// ================================================================== historial
async function entrarHistorial() {
    if (S.tour) salirRecorrido();
    cerrarPanel();
    S.historial = { fecha: HOY_ISO(), saldosHoy: S.datos.saldos, reproduciendo: false };
    root.classList.add('es-historial');
    const h = $('bm3dHistoria');
    h.innerHTML =
        '<button type="button" class="bm3d-btn es-ghost es-chico" id="hsSalir"><i class="mdi mdi-close"></i>Salir</button>' +
        '<div class="bm3d-hs-fecha"><small>Stock al cierre del</small><b id="hsFecha">' + fechaCorta(S.historial.fecha) + '</b></div>' +
        '<div class="bm3d-hs-linea"><canvas id="hsActividad" height="28"></canvas><input type="range" id="hsRango" min="-89" max="0" step="1" value="0" aria-label="Día" /></div>' +
        '<button type="button" class="bm3d-btn es-contorno es-chico" id="hsHoy">Hoy</button>' +
        '<button type="button" class="bm3d-btn es-primario es-chico" id="hsPlay"><i class="mdi mdi-play"></i>Reproducir el día</button>';
    h.hidden = false;
    $('hsSalir').onclick = salirHistorial;
    $('hsHoy').onclick = () => { $('hsRango').value = 0; irAFecha(0); };
    $('hsPlay').onclick = () => (S.historial.reproduciendo ? pararReproduccion() : reproducirDia());
    let tm = 0;
    $('hsRango').oninput = (e) => {
        const d = +e.target.value;
        $('hsFecha').textContent = fechaCorta(isoDesdeHoy(d));
        clearTimeout(tm); tm = setTimeout(() => irAFecha(d), 350);
    };
    try {
        const r = await ws('Actividad', { planta: S.planta, dias: 90 });
        dibujarActividad(r.actividad);
    } catch (e) { /* sin actividad */ }
}
function isoDesdeHoy(d) { const f = new Date(Date.now() + d * DIA_MS); return f.getFullYear() + '-' + pad2(f.getMonth() + 1) + '-' + pad2(f.getDate()); }
function dibujarActividad(lista) {
    const cv = $('hsActividad'); if (!cv) return;
    cv.width = cv.clientWidth || 600;
    const g = cv.getContext('2d'), w = cv.width, h = cv.height;
    g.clearRect(0, 0, w, h);
    const mapa = new Map(lista.map((x) => [x.dia, x.n])), max = Math.max(1, ...lista.map((x) => x.n));
    for (let d = -89; d <= 0; d++) {
        const n = mapa.get(isoDesdeHoy(d)) || 0; if (!n) continue;
        const x = (d + 89) / 89 * (w - 4) + 2, alto = Math.max(3, n / max * (h - 2));
        g.fillStyle = '#6732F4'; g.fillRect(x - 1.5, h - alto, 3, alto);
    }
}
async function irAFecha(d) {
    const H = S.historial; if (!H) return;
    pararReproduccion();
    const iso = isoDesdeHoy(d);
    H.fecha = iso;
    $('hsFecha').textContent = fechaCorta(iso);
    const camP = camera.position.clone(), camT = controls.target.clone(), bod = S.bodegaSel;
    try {
        S.datos.saldos = d === 0 ? H.saldosHoy : (await ws('SaldosFecha', { planta: S.planta, fecha: iso })).saldos;
        if (S.historial !== H) return;
        construir(S.datos); pintarBodegas();
        if (S.porBodega.has(bod)) elegirBodega(bod, true);
        camera.position.copy(camP); controls.target.copy(camT);
        $('bm3dHistoria').classList.toggle('es-pasado', d !== 0);
    } catch (e) { aviso(e.message, true); }
}
async function reproducirDia() {
    const H = S.historial; if (!H) return;
    let movs;
    try { movs = (await ws('Movimientos', { planta: S.planta, desde: H.fecha, hasta: H.fecha })).movimientos; } catch (e) { aviso(e.message, true); return; }
    if (!movs.length) { aviso('No hubo movimientos el ' + fechaCorta(H.fecha) + '.'); return; }
    H.reproduciendo = true;
    $('hsPlay').innerHTML = '<i class="mdi mdi-stop"></i>Detener';
    const capt = $('bm3dHsCaption');
    const colorTipo = (t) => ([1, 3, 4, 7].includes(t) ? '#16855B' : t === 9 ? '#087BEA' : '#C7352B');
    for (let i = 0; i < movs.length && S.historial === H && H.reproduciendo; i++) {
        const m = movs[i];
        const rack = S.racks.find((r) => r.id === (m.tipo === 9 ? m.ud || m.u : m.u));
        const caja = S.cajas.find((c) => c.userData.item.id === m.rep && rack && c.userData.rack === rack);
        if (caja) { enfocarCaja(caja); destelloLibre(caja, colorTipo(m.tipo)); }
        else if (rack) enfocarRack(rack);
        const signo = [1, 3, 4, 7].includes(m.tipo) ? '+' : m.tipo === 9 ? '↔ ' : '−';
        capt.innerHTML = '<span class="bm3d-hs-n">' + (i + 1) + '/' + movs.length + '</span><b>' + esc(m.fecha.split(' ')[1]) + '</b> · ' + esc(m.tn) + ' · <b>' + esc(m.c) + '</b> ' + signo + num(m.q) + (m.usuario ? ' · ' + esc(m.usuario) : '');
        capt.hidden = false;
        await new Promise((r) => setTimeout(r, 1500));
    }
    pararReproduccion();
}
function pararReproduccion() {
    const H = S.historial; if (!H) return;
    H.reproduciendo = false;
    const b = $('hsPlay'); if (b) b.innerHTML = '<i class="mdi mdi-play"></i>Reproducir el día';
    const c = $('bm3dHsCaption'); if (c) c.hidden = true;
}
function salirHistorial() {
    const H = S.historial; if (!H) return;
    pararReproduccion();
    S.historial = null;
    root.classList.remove('es-historial');
    $('bm3dHistoria').hidden = true;
    S.datos.saldos = H.saldosHoy;
    refrescarStock(true);
}

/* Destellos fuera del recorrido (reproduccion del historial). */
const DESTELLOS_LIBRES = [];
function destelloLibre(c, color) {
    const m = new THREE.Mesh(GEO_UNIDAD, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
    const u = c.userData;
    m.scale.set(u.w + 0.04, u.h + 0.04, u.d + 0.04);
    c.add(m);
    DESTELLOS_LIBRES.push({ m, t0: performance.now(), base: m.scale.clone() });
}
function animarDestellosLibres(ahora) {
    for (let i = DESTELLOS_LIBRES.length - 1; i >= 0; i--) {
        const d = DESTELLOS_LIBRES[i], t = (ahora - d.t0) / 1200;
        if (t >= 1) { if (d.m.parent) d.m.parent.remove(d.m); d.m.material.dispose(); DESTELLOS_LIBRES.splice(i, 1); continue; }
        d.m.material.opacity = 0.6 * (1 - t);
        d.m.scale.copy(d.base).multiplyScalar(1 + t * 0.25);
    }
}

// ================================================================== escanear
let flujoCamara = null;
function abrirEscaner() {
    const e = $('bm3dScan');
    const camara = 'BarcodeDetector' in window;
    e.innerHTML = '<div class="bm3d-scan-caja"><div class="bm3d-scan-cab"><b><i class="mdi mdi-qrcode-scan"></i>Escanear o escribir</b><button type="button" class="bm3d-cerrar" id="scCerrar"><i class="mdi mdi-close"></i></button></div>' +
        '<p>Escanea la etiqueta de un rack, de un repuesto o de la bodega con el lector, o escribe el código. El mapa vuela hasta él.</p>' +
        '<div class="bm3d-scan-in"><input type="text" id="scCodigo" placeholder="UBI-17, P1-A-R03, MEC-RODAMIENTO-021…" autocomplete="off" /><button type="button" class="bm3d-btn es-primario es-chico" id="scIr"><i class="mdi mdi-arrow-right"></i>Ir</button></div>' +
        (camara ? '<button type="button" class="bm3d-btn es-contorno es-chico" id="scCam" style="width:100%"><i class="mdi mdi-camera-outline"></i>Usar la cámara</button><video id="scVideo" playsinline muted hidden></video>'
                : '<small>Este navegador no lee QR con la cámara: usa el lector USB o escribe el código.</small>') +
        '<div class="bm3d-scan-msg" id="scMsg" hidden></div></div>';
    e.hidden = false;
    const inp = $('scCodigo'); setTimeout(() => inp.focus(), 50);
    inp.onkeydown = (ev) => { if (ev.key === 'Enter') { ev.preventDefault(); irACodigo(inp.value); } if (ev.key === 'Escape') cerrarEscaner(); ev.stopPropagation(); };
    $('scIr').onclick = () => irACodigo(inp.value);
    $('scCerrar').onclick = cerrarEscaner;
    const bc = $('scCam'); if (bc) bc.onclick = usarCamara;
}
async function usarCamara() {
    const v = $('scVideo');
    try {
        flujoCamara = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
        v.srcObject = flujoCamara; v.hidden = false; await v.play();
        const det = new window.BarcodeDetector({ formats: ['qr_code'] });
        const buscar = async () => {
            if (!flujoCamara) return;
            try { const r = await det.detect(v); if (r.length) { const t = r[0].rawValue; pararCamara(); irACodigo(t); return; } } catch (e) { /* cuadro sin QR */ }
            setTimeout(buscar, 250);
        };
        buscar();
    } catch (e) { const m = $('scMsg'); m.hidden = false; m.textContent = 'No se pudo usar la cámara: ' + e.message; }
}
function pararCamara() { if (flujoCamara) { flujoCamara.getTracks().forEach((t) => t.stop()); flujoCamara = null; } }
function cerrarEscaner() { pararCamara(); $('bm3dScan').hidden = true; }
async function irACodigo(texto) {
    texto = String(texto || '').trim(); if (!texto) return;
    const msg = $('scMsg');
    // primero lo que el mapa ya conoce: el codigo de un rack o de un repuesto con stock
    const rk = S.racks.find((r) => norm(r.codigo) === norm(texto));
    if (rk) { cerrarEscaner(); seleccionarRack(rk, true); return; }
    try {
        const r = await ws('Resolver', { codigo: texto });
        if (r.tipo === 'UBI') {
            const rack = S.racks.find((x) => x.id === r.id);
            if (!rack) throw new Error('Esa ubicación no es de esta planta o está deshabilitada.');
            cerrarEscaner(); seleccionarRack(rack, true);
        } else if (r.tipo === 'REP') {
            const cajas = S.cajas.filter((c) => c.userData.item.id === r.id);
            cerrarEscaner();
            if (cajas.length === 1) seleccionarCaja(cajas[0], true); else abrirFicha(r.id);
        } else if (r.tipo === 'BOD') {
            if (!S.porBodega.has(r.id)) throw new Error('Esa bodega no es de esta planta.');
            cerrarEscaner(); elegirBodega(r.id); panelBodega(S.porBodega.get(r.id));
        } else if (r.tipo === 'ACT') {
            cerrarEscaner(); await cambiarModo('compatibles'); setTimeout(() => { const s = $('fAnActivo'); if (s) { s.value = String(r.id); elegirActivo(r.id); } }, 900);
        } else throw new Error('Esa etiqueta no es de bodega.');
    } catch (e) { if (msg) { msg.hidden = false; msg.textContent = e.message; } else aviso(e.message, true); }
}

// ==================================================================== busqueda
const buscar = $('bm3dBuscar'), resultados = $('bm3dResultados');
let foco = -1, coincidencias = [];
buscar.addEventListener('input', () => {
    const q = norm(buscar.value.trim());
    if (q.length < 2) { resultados.hidden = true; return; }
    const racks = S.racks.filter((r) => norm(r.codigo).includes(q)).slice(0, 6).map((r) => ({ rack: r }));
    const cajas = S.cajas.filter((c) => {
        const it = c.userData.item;
        return norm(it.c).includes(q) || norm(it.n).includes(q) || norm(it.tn).includes(q) || norm(it.tc).includes(q) || norm(it.mod).includes(q);
    }).slice(0, 40).map((c) => ({ caja: c }));
    coincidencias = racks.concat(cajas);
    foco = coincidencias.length ? 0 : -1;
    pintarResultados();
});
function pintarResultados() {
    resultados.hidden = false;
    if (!coincidencias.length) { resultados.innerHTML = '<div class="bm3d-res-vacio">Sin coincidencias en el stock de esta planta.</div>'; return; }
    let html = '', grupo = '';
    coincidencias.forEach((x, i) => {
        const g = x.rack ? 'Racks' : 'Repuestos en stock';
        if (g !== grupo) { html += '<div class="bm3d-res-grupo">' + g + '</div>'; grupo = g; }
        if (x.rack) html += '<div class="bm3d-res' + (i === foco ? ' is-foco' : '') + '" data-i="' + i + '"><span class="bm3d-mini"><i class="mdi mdi-view-grid-outline" style="color:#087BEA"></i></span><div><b>' + esc(x.rack.codigo) + '</b><span>' + esc(x.rack.bodega.nombre) + ' · ' + x.rack.items.length + ' repuestos</span></div><em></em></div>';
        else { const it = x.caja.userData.item; html += '<div class="bm3d-res' + (i === foco ? ' is-foco' : '') + '" data-i="' + i + '">' + miniatura(it.foto, it.color) + '<div><b>' + esc(it.c) + '</b><span>' + esc(it.n) + '</span></div><em>' + esc(ubicTexto(x.caja, true)) + '</em></div>'; }
    });
    resultados.innerHTML = html;
    resultados.querySelectorAll('[data-i]').forEach((el) => el.onmousedown = (e) => { e.preventDefault(); elegirResultado(+el.dataset.i); });
}
function elegirResultado(i) {
    const x = coincidencias[i];
    if (!x) return;
    resultados.hidden = true; buscar.blur();
    if (x.rack) { seleccionarRack(x.rack, true); return; }
    if (S.filtro.size && !S.filtro.has(x.caja.userData.item.tid)) { S.filtro.clear(); aplicarFiltros(); }
    seleccionarCaja(x.caja, true);
}
buscar.addEventListener('keydown', (e) => {
    if (resultados.hidden) return;
    if (e.key === 'ArrowDown') { foco = Math.min(coincidencias.length - 1, foco + 1); pintarResultados(); e.preventDefault(); }
    else if (e.key === 'ArrowUp') { foco = Math.max(0, foco - 1); pintarResultados(); e.preventDefault(); }
    else if (e.key === 'Enter') { elegirResultado(foco); e.preventDefault(); }
    else if (e.key === 'Escape') resultados.hidden = true;
});
buscar.addEventListener('blur', () => setTimeout(() => { resultados.hidden = true; }, 150));

// ============================================================ bodegas y KPIs
function pintarBodegas() {
    const el = $('bm3dBodegas'), bs = S.datos.bodegas || [];
    el.innerHTML = bs.map((b) => {
        const n = (S.porBodega.get(b.id) || { cajas: [] }).cajas.length;
        return '<button type="button" class="bm3d-tab' + (b.id === S.bodegaSel ? ' is-activa' : '') + '" role="tab" data-bodega="' + b.id + '" title="' + esc(b.descripcion) + '">' + esc(b.nombre) + ' <small>' + n + '</small></button>';
    }).join('') + (S.permisos.bodegas ? '<button type="button" class="bm3d-tab es-nueva" id="bm3dNuevaBod" title="Nueva bodega"><i class="mdi mdi-plus"></i>Bodega</button>' : '');
    el.querySelectorAll('[data-bodega]').forEach((b) => b.onclick = () => {
        const id = +b.dataset.bodega;
        if (id === S.bodegaSel) { panelBodega(S.porBodega.get(id)); return; }
        cerrarPanel(); elegirBodega(id);
    });
    const nb = $('bm3dNuevaBod'); if (nb) nb.onclick = () => formBodega(null);
}

function elegirBodega(id, sinVolar) {
    S.bodegaSel = id;
    document.querySelectorAll('.bm3d-tab[data-bodega]').forEach((b) => b.classList.toggle('is-activa', +b.dataset.bodega === id));
    const b = S.porBodega.get(id);
    if (b) {
        const s = b.span / 2 + 4;
        sol.position.set(b.centro.x - s * 0.6, s * 1.6 + 10, b.centro.z - s * 0.4);
        sol.target.position.copy(b.centro);
        Object.assign(sol.shadow.camera, { left: -s, right: s, top: s, bottom: -s, near: 1, far: s * 5 + 30 });
        sol.shadow.camera.updateProjectionMatrix();
    }
    pintarKpis();
    if (!sinVolar) vistaGeneral(id, 1400);
}

function pintarKpis() {
    const b = S.porBodega.get(S.bodegaSel), el = $('bm3dKpis');
    const viejo = root.querySelector('.bm3d-aviso'); if (viejo) viejo.remove();
    if (!b) { el.innerHTML = ''; return; }
    const items = b.cajas.map((c) => c.userData.item);
    const reps = new Set(items.map((i) => i.id)).size;
    const ocupadas = b.racks.filter((r) => r.items.length).length;
    const bajo = items.filter((i) => estadoDe(i) === 'bajo').length;
    const sinU = b.recepcion ? b.recepcion.items.length : 0;
    const kpi = (ico, tono, valor, txt, accion) => '<div class="bm3d-kpi' + (accion ? ' es-click' : '') + '"' + (accion ? ' data-kpi="' + accion + '"' : '') + '><span class="bm3d-kpi-ico ' + tono + '"><i class="mdi ' + ico + '"></i></span><div><b>' + valor + '</b><span>' + txt + '</span></div></div>';
    el.innerHTML = kpi('mdi-view-grid-outline', 'es-azul', ocupadas + '/' + b.racks.length, 'Racks con stock', 'bodega') +
        kpi('mdi-package-variant-closed', 'es-lila', reps, 'Repuestos en bodega') +
        kpi('mdi-alert-outline', 'es-alerta', bajo, 'Bajo mínimo', bajo ? 'alertas' : '') +
        (sinU ? kpi('mdi-truck-delivery-outline', 'es-cyan', sinU, 'Sin ubicación', 'recepcion') : '');
    el.querySelectorAll('[data-kpi]').forEach((k) => k.onclick = () => {
        if (k.dataset.kpi === 'alertas') root.querySelector('[data-modo="alertas"]').click();
        else if (k.dataset.kpi === 'recepcion') seleccionarRack(b.recepcion, true);
        else panelBodega(b);
    });
    if (!b.cajas.length) {
        const a = document.createElement('div'); a.className = 'bm3d-aviso';
        a.innerHTML = '<i class="mdi mdi-information-outline"></i>' + (b.racks.length ? 'Esta bodega no tiene stock registrado: los racks se ven vacíos hasta el primer ingreso.' : 'Esta bodega no tiene ubicaciones: activa el modo edición para crear sus racks.');
        root.appendChild(a);
    }
}

function alternarEdicion() {
    S.edicion = !S.edicion;
    root.querySelector('[data-accion="editar"]').classList.toggle('is-activo', S.edicion);
    if (S.edicion) { armarEdicion(); aviso('Modo edición: haz clic en un rack fantasma para crear una ubicación.'); }
    else limpiarEdicion();
}

// ===================================================================== carga
async function cargar(planta) {
    if (S.tour) salirRecorrido();
    mostrarEstado('cargando', 'Construyendo la bodega…');
    cerrarPanel();
    try {
        const d = await ws('Cargar', { planta: planta || 0 });
        aplicarDatos(d);
        const primera = (d.bodegas || [])[0];
        mostrarEstado('ok');
        if (primera) {
            elegirBodega(primera.id, true);
            const b = S.porBodega.get(primera.id), e = encuadre(b, false);
            camera.position.copy(e.pos).add(new THREE.Vector3(-b.span, b.span * 1.2, -b.span));
            controls.target.copy(e.target);
            vistaGeneral(primera.id, 2200);
            // ?ir=UBI-17 (desde Escanear.aspx o un enlace): vuela a esa etiqueta
            const ir = new URLSearchParams(location.search).get('ir');
            if (ir && !cargar.irHecho) { cargar.irHecho = true; setTimeout(() => irACodigo(ir), 2400); }
        } else {
            pintarKpis();
            mostrarEstado('error', 'Esta planta no tiene bodegas.' + (S.permisos.bodegas ? ' Créala con el botón «+ Bodega».' : ''));
        }
    } catch (e) { mostrarEstado('error', e.message); }
}

function aplicarDatos(d) {
    S.datos = d; S.planta = d.planta; S.permisos = d.permisos || {};
    S.qr = Object.assign(S.qr || {}, d.qr || {});
    leerConteos(d.conteos);
    leerPosiciones(d.posiciones);
    leerPlano(d.plano);
    S.version = d.version || S.version;
    S.consumo = null;
    $('bm3dPlanta').innerHTML = (d.plantas || []).map((p) => '<option value="' + p.id + '"' + (p.id === d.planta ? ' selected' : '') + '>' + esc(p.nombre) + '</option>').join('');
    root.querySelector('[data-accion="nuevo"]').hidden = !S.permisos.repuestos;
    root.querySelector('[data-accion="picking"]').hidden = !S.permisos.entrega;
    root.querySelector('[data-accion="editar"]').hidden = !S.permisos.bodegas;
    construir(d);
    pintarBodegas();
}

/* Recarga SIN mover la camara: despues de crear un rack o registrar un
   movimiento, el usuario sigue mirando donde estaba. */
async function recargar(estructura, plantaNueva) {
    if (S.tour) salirRecorrido();
    const camP = camera.position.clone(), camT = controls.target.clone(), bod = S.bodegaSel;
    const d = estructura ? await ws('Cargar', { planta: plantaNueva || S.planta }) : await ws('Saldos', { planta: S.planta });
    if (estructura) aplicarDatos(d);
    else { S.datos.saldos = d.saldos; Object.assign(S.qr, d.qr || {}); leerConteos(d.conteos); S.version = d.version || S.version; construir(S.datos); pintarBodegas(); }
    const destino = S.porBodega.has(bod) ? bod : ((S.datos.bodegas || [])[0] || {}).id;
    if (destino) elegirBodega(destino, true);
    if (!plantaNueva) { camera.position.copy(camP); controls.target.copy(camT); }
    else vistaGeneral(destino, 1200);
}
async function refrescarStock(silencioso) {
    const btn = root.querySelector('[data-accion="refrescar"] i');
    btn.classList.add('mdi-spin');
    try { await recargar(false); if (!silencioso) aviso('Stock actualizado.'); }
    catch (e) { aviso(e.message, true); }
    finally { btn.classList.remove('mdi-spin'); }
}

// ================================================================== controles
$('bm3dPlanta').onchange = (e) => cargar(+e.target.value);
root.querySelector('[data-vista="general"]').onclick = () => vistaGeneral();
root.querySelector('[data-vista="planta"]').onclick = () => vistaPlanta();
root.querySelector('[data-modo="alertas"]').onclick = () => cambiarModo(S.modo === 'alertas' ? 'normal' : 'alertas');
root.querySelector('[data-accion="analisis"]').onclick = () => panelAnalisis();
// menu "Mas": se abre con su boton y se cierra al elegir o al hacer clic afuera
const menuMas = $('bm3dMas');
root.querySelector('[data-accion="mas"]').onclick = (e) => { e.stopPropagation(); menuMas.hidden = !menuMas.hidden; };
menuMas.addEventListener('click', () => { menuMas.hidden = true; });
document.addEventListener('click', (e) => { if (!e.target.closest('.bm3d-mas')) menuMas.hidden = true; });
root.querySelector('[data-accion="historial"]').onclick = () => (S.historial ? salirHistorial() : entrarHistorial());
root.querySelector('[data-accion="escanear"]').onclick = () => abrirEscaner();
root.querySelector('[data-accion="refrescar"]').onclick = () => refrescarStock(false);
root.querySelector('[data-accion="editar"]').onclick = alternarEdicion;
root.querySelector('[data-accion="nuevo"]').onclick = () => formRepuesto(0, { bodega: S.bodegaSel });
root.querySelector('[data-accion="picking"]').onclick = () => formPicking();
root.querySelector('[data-accion="bodega"]').onclick = () => panelBodega(S.porBodega.get(S.bodegaSel));
root.querySelector('[data-accion="pantalla"]').onclick = () => { if (document.fullscreenElement) document.exitFullscreen(); else if (root.requestFullscreen) root.requestFullscreen(); };
document.addEventListener('fullscreenchange', () => {
    root.querySelector('[data-accion="pantalla"] i').className = 'mdi ' + (document.fullscreenElement ? 'mdi-fullscreen-exit' : 'mdi-fullscreen');
    encajar(); setTimeout(redimensionar, 60);
});
document.addEventListener('keydown', (e) => {
    if (S.moverRack) {
        const M = S.moverRack;
        if (e.key === 'Escape') terminarMoverRack();
        else if (e.key === 'r' || e.key === 'R') { M.rot = (M.rot + Math.PI / 2) % (Math.PI * 2); M.m.rotation.y = M.rot; }
        else if (e.key === 'Enter') guardarMoverRack();
        e.preventDefault(); return;
    }
    if (S.dibujo && e.key === 'Escape') { terminarDibujo(null); return; }
    if (!$('bm3dScan').hidden && e.key === 'Escape') { cerrarEscaner(); return; }
    const escribiendo = /INPUT|TEXTAREA|SELECT/.test((document.activeElement || {}).tagName || '');
    if (e.key === 'Escape') {
        if (!visor.hidden) visor.hidden = true;
        else if (!ficha.hidden) cerrarFicha();
        else if (S.tour && S.tour.detalle) cerrarDetalleTablet();
        else if (S.tour && S.tour.contando) cerrarConteoTablet();
        else if (S.tour) salirRecorrido();
        else if (S.pick) terminarPick();
        else if (!escribiendo) cerrarPanel();
        return;
    }
    if (escribiendo) return;
    if (S.tour) {
        if (e.key === ' ') { e.preventDefault(); pausar(!S.tour.pausado); }
        else if (e.key === 'ArrowRight') { e.preventDefault(); saltarRelativo(1); }
        else if (e.key === 'ArrowLeft') { e.preventDefault(); saltarRelativo(-1); }
        return;
    }
    if (e.key === '/') { e.preventDefault(); buscar.focus(); }
});
controls.addEventListener('start', () => { S.vuelo = null; marcarVista(''); });

// ====================================================================== bucle
const reloj = new THREE.Clock();
function bucle(ahora) {
    const dt = Math.min(reloj.getDelta(), 0.05);
    if (Math.abs(camera.fov - S.fovMeta) > 0.02) { camera.fov = lerp(camera.fov, S.fovMeta, Math.min(1, dt * 2.6)); camera.updateProjectionMatrix(); }
    if (S.tour) {
        /* Una falla en el recorrido no puede dejar al usuario encerrado en el. */
        try { pasoRecorrido(dt, ahora); }
        catch (e) { console.error('Recorrido del mapa 3D:', e); salirRecorrido(); }
    } else if (S.vuelo) {
        const v = S.vuelo, t = Math.min(1, (ahora - v.t0) / v.dur), e = suave(t);
        camera.position.lerpVectors(v.p0, v.p1, e);
        controls.target.lerpVectors(v.o0, v.o1, e);
        if (t >= 1) S.vuelo = null;
    }
    for (const c of S.cajas) {
        const u = c.userData, meta = u.sacar || 0;
        u.fuera = lerp(u.fuera || 0, meta, Math.min(1, dt * 9));
        if (u.fuera > 0.0005 || meta) c.position.copy(u.base).addScaledVector(u.normal, u.fuera);
    }
    if (S.modoAlertas) { const k = 0.35 + 0.35 * (1 + Math.sin(ahora / 260)); MAT_ALERTA.bajo.emissiveIntensity = k; MAT_ALERTA.sobre.emissiveIntensity = k * 0.7; }
    MAT.contorno.opacity = 0.65 + 0.35 * Math.sin(ahora / 220);
    if (DESTELLOS_LIBRES.length) animarDestellosLibres(ahora);
    if (S.moverRack || S.dibujo) MAT.marca.opacity = 0.55 + 0.45 * Math.sin(ahora / 180);
    if (S.edicion) MAT.fantasma.opacity = 0.08 + 0.05 * (1 + Math.sin(ahora / 400));
    if (!S.tour) controls.update();
    /* Una falla en el nivel de detalle no puede congelar la escena. */
    try { actualizarEtiquetas(ahora); }
    catch (e) { if (!bucle.avisado) { bucle.avisado = true; console.error('Etiquetas del mapa 3D:', e); } }
    renderer.render(scene, camera);
}

// ===================================================================== inicio
document.documentElement.classList.add('bm3d-pagina');
encajar(); redimensionar();
new ResizeObserver(() => { encajar(); redimensionar(); }).observe(document.body);
new ResizeObserver(() => redimensionar()).observe(escenaEl);
window.addEventListener('resize', () => { encajar(); redimensionar(); });
document.addEventListener('click', (e) => { if (e.target.closest('.button-menu-mobile')) setTimeout(() => { encajar(); redimensionar(); }, 320); });
renderer.setAnimationLoop(bucle);
cargar(0);
setInterval(revisarVersion, 15000);

/* Gancho de diagnostico (consola). No lo usa la pantalla. */
window.__bodega3d = {
    estado: S,
    seleccionar(i) { seleccionarCaja(S.cajas[i], true); },
    rack(i) { seleccionarRack(S.racks[i], true); },
    recorrer(b, p) { const info = S.porBodega.get(b || S.bodegaSel); if (info) iniciarRecorrido(info.pasillos[p || 0]); },
    ficha(id) { abrirFicha(id); },
    picking: () => formPicking(),
    modo: (m) => cambiarModo(m),
    historial: () => entrarHistorial(),
    ir: (c) => irACodigo(c),
    contar(b, p) { const info = S.porBodega.get(b || S.bodegaSel); if (info) iniciarRecorrido(info.pasillos[p || 0], null, { conteo: true }); },
    camara: () => ({ pos: camera.position.toArray(), target: controls.target.toArray() })
};
