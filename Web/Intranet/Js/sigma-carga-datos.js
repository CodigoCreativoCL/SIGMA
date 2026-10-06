/* =============================================================================
   SIGMA · Centro de carga de datos
   -----------------------------------------------------------------------------
   Pantalla sin postback sobre WsCargaDatos.asmx:
     - escena 3D (Three.js, Js/three): el nucleo SIGMA con un nodo por modulo;
       mientras una carga corre, los datos fluyen desde la planilla hacia su
       modulo y la velocidad sigue al avance real;
     - asistente de tres pasos: plantilla, archivo, revisar o cargar;
     - recuadro flotante de avance con tiempo transcurrido y "Alertar un
       problema"; se retoma solo si se recarga la pagina a mitad de proceso;
     - resultado por hoja con los errores (y su Excel) e historial.
   ============================================================================= */
import * as THREE from 'three';

const root = document.getElementById('cd');
const WS = root.dataset.ws;
/* Abierta desde un modulo (la carga de activos del Centro de activos) la
   pantalla queda fija en el: sin la escena ni la grilla de modulos, y el
   historial solo de ese modulo. */
const FIJO = root.dataset.modulo || '';
const $ = (id) => document.getElementById(id);
const esc = (t) => String(t == null ? '' : t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const num = (n) => Number(n || 0).toLocaleString('es-CL');
const reloj = (s) => { s = Math.max(0, Math.floor(s)); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60; return (h ? h + ':' + String(m).padStart(2, '0') : m) + ':' + String(x).padStart(2, '0'); };

const S = { modulos: [], sel: null, archivo: null, existentes: 'ACTUALIZAR', carga: null, timer: 0, tick: 0, base: 0, baseLocal: 0, ultimo: null, filtroErr: '' };
const ESTADO_FIN = ['TERMINADA', 'CON_ERRORES', 'FALLIDA'];
const HOJA_NOMBRE = { STOCK_INICIAL: 'Stock inicial', DATOS_TECNICOS: 'Datos técnicos', REPUESTOS_COMPATIBLES: 'Repuestos compatibles' };
const nombreHoja = (h) => HOJA_NOMBRE[h] || (h ? h.charAt(0) + h.slice(1).toLowerCase() : '');

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
    t.className = 'cd-toast' + (error ? ' es-error' : '');
    t.innerHTML = '<i class="mdi ' + (error ? 'mdi-alert-circle' : 'mdi-check-circle') + '"></i><span>' + esc(texto) + '</span>';
    $('cdToasts').appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .4s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 400); }, error ? 7000 : 3500);
}

function descargar(nombre, base64) {
    const bin = atob(base64), u = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    const url = URL.createObjectURL(new Blob([u], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }));
    const a = document.createElement('a'); a.href = url; a.download = nombre; document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1500);
}

async function ocupado(btn, fn) {
    if (btn.disabled) return;
    const html = btn.innerHTML; btn.disabled = true; btn.innerHTML = '<i class="mdi mdi-loading mdi-spin"></i>' + btn.textContent;
    try { await fn(); } catch (e) { aviso(e.message, true); } finally { btn.disabled = false; btn.innerHTML = html; }
}

// ============================================================================ escena 3D
const Escena = (() => {
    const cont = $('cdEscena');
    let renderer;
    try { renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false }); }
    catch (e) { cont.style.display = 'none'; return { modulos() {}, seleccionar() {}, flujo() {}, fin() {} }; }
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0x0b1120, 1);
    cont.appendChild(renderer.domElement);
    const escena = new THREE.Scene();
    escena.fog = new THREE.FogExp2(0x0b1120, 0.035);
    const cam = new THREE.PerspectiveCamera(42, 2, 0.1, 200);
    cam.position.set(0, 3.0, 13.5);

    // estrellas: datos en reposo
    const nE = 900, pos = new Float32Array(nE * 3);
    for (let i = 0; i < nE; i++) { const r = 8 + Math.random() * 28, t = Math.random() * Math.PI * 2, f = (Math.random() - 0.5) * 1.6; pos[i * 3] = Math.cos(t) * r; pos[i * 3 + 1] = f * 9; pos[i * 3 + 2] = Math.sin(t) * r - 6; }
    const gE = new THREE.BufferGeometry(); gE.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const estrellas = new THREE.Points(gE, new THREE.PointsMaterial({ color: 0x5b6b8f, size: 0.06, transparent: true, opacity: 0.75 }));
    escena.add(estrellas);

    // nucleo SIGMA
    const nucleo = new THREE.Group();
    nucleo.position.set(3.2, 0.2, 0);
    escena.add(nucleo);
    const ico = new THREE.Mesh(new THREE.IcosahedronGeometry(1.25, 1), new THREE.MeshBasicMaterial({ color: 0x6732f4, wireframe: true, transparent: true, opacity: 0.55 }));
    const brillo = new THREE.Mesh(new THREE.SphereGeometry(0.72, 32, 32), new THREE.MeshBasicMaterial({ color: 0x8b6bff, transparent: true, opacity: 0.85 }));
    const halo = new THREE.Mesh(new THREE.SphereGeometry(1.05, 32, 32), new THREE.MeshBasicMaterial({ color: 0x6732f4, transparent: true, opacity: 0.12 }));
    nucleo.add(ico, brillo, halo);
    const anillos = [];
    [[2.6, 0x16c6c9, 0.35], [3.6, 0x087bea, 0.22], [4.6, 0x6732f4, 0.16]].forEach(([r, c, o], i) => {
        const a = new THREE.Mesh(new THREE.TorusGeometry(r, 0.012, 8, 160), new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: o }));
        a.rotation.x = Math.PI / 2 + (i - 1) * 0.18; a.rotation.y = i * 0.3; nucleo.add(a); anillos.push(a);
    });

    // la planilla: de donde salen los datos
    const hoja = new THREE.Group();
    hoja.position.set(-2.4, -1.9, 2.2);
    const papel = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 1.15), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.0, side: THREE.DoubleSide }));
    const marco = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.PlaneGeometry(0.9, 1.15)), new THREE.LineBasicMaterial({ color: 0x16c6c9, transparent: true, opacity: 0.0 }));
    for (let k = 0; k < 5; k++) {
        const l = new THREE.Mesh(new THREE.PlaneGeometry(0.6 - (k % 2) * 0.18, 0.05), new THREE.MeshBasicMaterial({ color: 0x16c6c9, transparent: true, opacity: 0 }));
        l.position.set(-0.05 - (k % 2) * 0.09, 0.35 - k * 0.17, 0.01); hoja.add(l);
    }
    hoja.add(papel, marco); hoja.rotation.set(-0.15, 0.45, 0.06);
    escena.add(hoja);

    // nodos de modulo
    let nodos = [];
    function etiqueta(texto, color) {
        const c = document.createElement('canvas'); c.width = 512; c.height = 128;
        const g = c.getContext('2d');
        g.font = '800 54px "Plus Jakarta Sans", "Segoe UI", sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
        g.fillStyle = 'rgba(11,17,32,.55)'; const w = g.measureText(texto).width + 60;
        g.beginPath(); g.roundRect ? g.roundRect(256 - w / 2, 22, w, 84, 42) : g.rect(256 - w / 2, 22, w, 84); g.fill();
        g.fillStyle = color; g.fillText(texto, 256, 66);
        const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
        const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, transparent: true, depthWrite: false }));
        sp.scale.set(2.9, 0.72, 1);
        return sp;
    }
    function modulos(lista) {
        nodos.forEach((n) => nucleo.remove(n.g));
        nodos = lista.map((m, i) => {
            const ang = -Math.PI / 2 + (i / lista.length) * Math.PI * 2 + 0.6;
            const r = 3.6, g = new THREE.Group();
            g.position.set(Math.cos(ang) * r, Math.sin(ang) * 0.9, Math.sin(ang) * r * 0.55);
            const col = new THREE.Color(m.color || '#16C6C9');
            const forma = new THREE.Mesh(new THREE.OctahedronGeometry(0.52, 0), new THREE.MeshBasicMaterial({ color: col, wireframe: !m.disponible, transparent: true, opacity: m.disponible ? 0.95 : 0.55 }));
            const aura = new THREE.Mesh(new THREE.SphereGeometry(0.85, 24, 24), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.1 }));
            const lab = etiqueta(m.nombre, m.disponible ? '#FFFFFF' : '#9FAAC3'); lab.position.y = -1.15;
            g.add(forma, aura, lab);
            g.userData = { clave: m.clave, forma, aura, disponible: m.disponible, color: col, pulso: 0 };
            nucleo.add(g);
            return { g, clave: m.clave };
        });
    }
    let seleccion = null;
    function seleccionar(clave) { seleccion = clave; }

    // flujo de datos planilla -> modulo
    const MAXP = 420, pp = new Float32Array(MAXP * 3), pc = new Float32Array(MAXP * 3);
    const gP = new THREE.BufferGeometry();
    gP.setAttribute('position', new THREE.BufferAttribute(pp, 3)); gP.setAttribute('color', new THREE.BufferAttribute(pc, 3));
    const flujoPts = new THREE.Points(gP, new THREE.PointsMaterial({ size: 0.11, vertexColors: true, transparent: true, opacity: 0.95, depthWrite: false, blending: THREE.AdditiveBlending }));
    escena.add(flujoPts);
    const vivas = []; let activo = null, ritmo = 0, papelVis = 0, explosion = null;
    const cA = new THREE.Color(0x16c6c9), cB = new THREE.Color(0x8b6bff);
    function flujo(clave, avance) { activo = clave; ritmo = 0.35 + Math.min(1, avance || 0) * 0.65; }
    function fin(clave, ok) {
        activo = null;
        const n = nodos.find((x) => x.clave === clave); if (!n) return;
        n.g.userData.pulso = 1;
        explosion = { t: 0, n, color: new THREE.Color(ok ? 0x16c6c9 : 0xffb23f) };
    }

    // interaccion
    const ray = new THREE.Raycaster(), mouse = new THREE.Vector2();
    let hover = null;
    renderer.domElement.addEventListener('pointermove', (e) => {
        const r = renderer.domElement.getBoundingClientRect();
        mouse.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
        ray.setFromCamera(mouse, cam);
        const hit = ray.intersectObjects(nodos.map((n) => n.g.userData.aura), false)[0];
        hover = hit ? nodos.find((n) => n.g.userData.aura === hit.object) : null;
        renderer.domElement.style.cursor = hover && hover.g.userData.disponible ? 'pointer' : '';
    });
    renderer.domElement.addEventListener('click', () => { if (hover && hover.g.userData.disponible) elegirModulo(hover.clave, true); });

    function redimensionar() {
        const w = cont.clientWidth, h = cont.clientHeight;
        if (!w || !h) return;
        renderer.setSize(w, h, false); cam.aspect = w / h;
        // en pantallas angostas el nucleo va al centro, detras del texto
        const angosta = w < 560;
        nucleo.position.x = angosta ? 0.6 : (w < 900 ? 3.9 : 3.4); nucleo.position.y = angosta ? -0.6 : 0.2;
        cam.fov = angosta ? 58 : 40; cam.updateProjectionMatrix();
    }
    new ResizeObserver(redimensionar).observe(cont);
    redimensionar();

    const reloj3d = new THREE.Clock(), _v = new THREE.Vector3(), _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3();
    const quieto = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    function cuadro() {
        requestAnimationFrame(cuadro);
        const dt = Math.min(0.05, reloj3d.getDelta()), t = reloj3d.elapsedTime;
        const vel = quieto ? 0.15 : 1;
        estrellas.rotation.y += dt * 0.012 * vel;
        ico.rotation.x += dt * 0.18 * vel; ico.rotation.y += dt * 0.24 * vel;
        halo.scale.setScalar(1 + Math.sin(t * 2.2) * 0.05 + (activo ? 0.08 : 0));
        brillo.material.opacity = 0.7 + Math.sin(t * 3) * 0.12 + (activo ? 0.15 : 0);
        anillos.forEach((a, i) => { a.rotation.z += dt * (0.05 + i * 0.03) * (activo ? 3 : 1) * vel; });
        nucleo.rotation.y = Math.sin(t * 0.15) * 0.18;

        nodos.forEach((n) => {
            const u = n.g.userData, sel = n.clave === seleccion, hov = hover === n, act = n.clave === activo;
            u.forma.rotation.y += dt * (act ? 2.4 : 0.6) * vel;
            const s = 1 + (sel ? 0.22 : 0) + (hov ? 0.12 : 0) + Math.sin(t * 2 + n.g.position.x) * 0.03 + u.pulso * 0.6;
            n.g.scale.setScalar(THREE.MathUtils.lerp(n.g.scale.x, s, 0.12));
            u.aura.material.opacity = (sel ? 0.22 : 0.1) + (act ? 0.12 + Math.sin(t * 6) * 0.06 : 0) + u.pulso * 0.3;
            u.pulso = Math.max(0, u.pulso - dt * 0.9);
        });

        // la planilla aparece mientras hay flujo
        papelVis = THREE.MathUtils.lerp(papelVis, activo ? 1 : 0, 0.06);
        hoja.children.forEach((ch) => { if (ch.material) ch.material.opacity = papelVis * (ch === papel ? 0.08 : 0.85); });
        hoja.position.y = -1.9 + Math.sin(t * 1.4) * 0.06;

        // particulas en curva hacia el modulo activo
        const destino = activo ? nodos.find((n) => n.clave === activo) : null;
        if (destino && !quieto && vivas.length < MAXP && Math.random() < ritmo) {
            for (let k = 0; k < 2; k++) vivas.push({ t: 0, v: 0.35 + Math.random() * 0.35 * ritmo, off: new THREE.Vector3((Math.random() - 0.5) * 0.7, (Math.random() - 0.5) * 0.7, (Math.random() - 0.5) * 0.7) });
        }
        if (destino) { destino.g.getWorldPosition(_b); }
        hoja.getWorldPosition(_a);
        let n = 0;
        for (let i = vivas.length - 1; i >= 0; i--) {
            const p = vivas[i]; p.t += dt * p.v;
            if (p.t >= 1 || !destino) { if (destino && p.t >= 1) destino.g.userData.pulso = Math.min(0.35, destino.g.userData.pulso + 0.02); vivas.splice(i, 1); continue; }
            _c.copy(_a).lerp(_b, 0.5).add(_v.set(0, 2.6, 1.2)).add(p.off);
            const u = p.t, a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, c = u * u;
            pp[n * 3] = _a.x * a + _c.x * b + _b.x * c; pp[n * 3 + 1] = _a.y * a + _c.y * b + _b.y * c; pp[n * 3 + 2] = _a.z * a + _c.z * b + _b.z * c;
            const col = cA.clone().lerp(cB, u); pc[n * 3] = col.r; pc[n * 3 + 1] = col.g; pc[n * 3 + 2] = col.b;
            n++;
        }
        // estallido al terminar
        if (explosion) {
            explosion.t += dt;
            explosion.n.g.getWorldPosition(_b);
            const k = Math.min(1, explosion.t / 1.1);
            for (let j = 0; j < 90 && n < MAXP; j++, n++) {
                const ang = j * 2.399, rr = k * 1.8 * (0.6 + (j % 7) / 10);
                pp[n * 3] = _b.x + Math.cos(ang) * rr; pp[n * 3 + 1] = _b.y + Math.sin(ang * 1.3) * rr * 0.6; pp[n * 3 + 2] = _b.z + Math.sin(ang) * rr;
                pc[n * 3] = explosion.color.r * (1 - k); pc[n * 3 + 1] = explosion.color.g * (1 - k); pc[n * 3 + 2] = explosion.color.b * (1 - k);
            }
            if (k >= 1) explosion = null;
        }
        gP.setDrawRange(0, n);
        gP.attributes.position.needsUpdate = true; gP.attributes.color.needsUpdate = true;

        cam.position.x = Math.sin(t * 0.08) * 0.6; cam.lookAt(nucleo.position.x * 0.55, 0, 0);
        renderer.render(escena, cam);
    }
    cuadro();
    return { modulos, seleccionar, flujo, fin };
})();

// ============================================================================ modulos
function datoTxt(m) {
    return (m.datos || []).map((d) => '<span class="cd-dato"><b>' + num(d.cantidad) + '</b>' + esc(d.dato) + '</span>').join('');
}
function chipEstado(c) {
    if (!c) return '<span class="cd-chip es-muted">Sin cargas</span>';
    const e = c.estado, rev = c.modo === 'VALIDAR';
    if (e === 'TERMINADA') return '<span class="cd-chip es-ok"><i class="mdi mdi-check"></i>' + (rev ? 'Revisión limpia' : 'Cargada') + '</span>';
    if (e === 'CON_ERRORES') return '<span class="cd-chip es-warning"><i class="mdi mdi-alert-outline"></i>' + num(c.errores) + ' con error</span>';
    if (e === 'FALLIDA') return '<span class="cd-chip es-danger"><i class="mdi mdi-close-octagon-outline"></i>Fallida</span>';
    return '<span class="cd-chip es-cyan"><i class="mdi mdi-loading mdi-spin"></i>En curso</span>';
}

function pintarModulos() {
    $('cdModulos').innerHTML = S.modulos.map((m) => {
        const tono = m.color || '#6732F4';
        return '<button type="button" class="cd-modulo' + (m.disponible ? '' : ' es-pronto') + (S.sel && S.sel.clave === m.clave ? ' is-activo' : '') + '" data-mod="' + esc(m.clave) + '"' + (m.disponible ? '' : ' aria-disabled="true"') + '>' +
            '<div class="cd-modulo-cab"><span class="cd-modulo-ico" style="background:' + tono + '1A;color:' + tono + '"><i class="mdi ' + esc(m.icono) + '"></i></span>' +
            '<div><b>' + esc(m.nombre) + '</b>' + (m.disponible ? '<span class="cd-chip es-purple">' + m.hojas.length + ' hojas</span>' : '<span class="cd-chip es-muted">En preparación</span>') + '</div></div>' +
            '<p>' + esc(m.descripcion) + '</p>' +
            (m.datos && m.datos.length ? '<div class="cd-datos">' + datoTxt(m) + '</div>' : '') +
            '<div class="cd-modulo-pie"><span>' + (m.ultima ? 'Última: ' + esc(m.ultima.inicio) : 'Todavía no se ha cargado') + '</span>' + (m.disponible ? chipEstado(m.ultima) : '') + '</div>' +
            '</button>';
    }).join('');
    $('cdModulos').querySelectorAll('[data-mod]').forEach((b) => b.onclick = () => elegirModulo(b.dataset.mod, true));
    $('cdLeyenda').innerHTML = S.modulos.map((m) => '<span><i style="background:' + esc(m.color) + '"></i>' + esc(m.nombre) + (m.disponible ? '' : ' · pronto') + '</span>').join('');
}

function elegirModulo(clave, scroll) {
    const m = S.modulos.find((x) => x.clave === clave);
    if (!m || !m.disponible) return;
    if (S.sel && S.sel.clave !== clave) S.archivo = null;
    S.sel = m;
    Escena.seleccionar(clave);
    pintarModulos();
    pintarAsistente();
    if (scroll) $('cdAsistente').scrollIntoView({ behavior: 'smooth', block: 'start' });
}

// ============================================================================ asistente
function pintarAsistente() {
    const m = S.sel, a = $('cdAsistente');
    if (!m) { a.hidden = true; return; }
    a.hidden = false;
    const corriendo = S.carga && !ESTADO_FIN.includes((S.ultimo || {}).estado);
    a.innerHTML =
        '<div class="cd-asistente-cab"><span class="cd-modulo-ico" style="background:' + m.color + '1A;color:' + m.color + '"><i class="mdi ' + esc(m.icono) + '"></i></span>' +
        '<div><h3>Cargar ' + esc(m.nombre.toLowerCase()) + '</h3><p>' + esc(m.descripcion) + '</p></div></div>' +
        '<div class="cd-pasos">' +
        // 1 plantilla
        '<div class="cd-paso"><div class="cd-paso-tit"><b>1</b>Descarga la plantilla</div>' +
        '<p>Un libro con una hoja por paso, en el orden en que se cargan, más hojas de ayuda con los valores válidos de tu empresa.</p>' +
        '<div class="cd-hojas">' + m.hojas.map((h, i) =>
            '<details class="cd-hoja"' + (i === 0 ? ' open' : '') + '><summary><i class="mdi ' + esc(h.icono) + ' ico"></i>' + esc(h.titulo) +
            '<span class="cd-chip es-muted">' + h.columnas.length + ' col.</span></summary>' +
            '<div class="cd-hoja-cuerpo">' + esc(h.descripcion) + '<div class="cd-cols">' +
            h.columnas.map((c) => '<span class="cd-col' + (c.obligatoria ? ' es-obl' : '') + '" title="' + esc(c.ayuda) + '">' + esc(c.titulo) + '</span>').join('') +
            '</div></div></details>').join('') + '</div>' +
        '<div class="cd-acciones"><button type="button" class="cd-btn es-contorno" id="cdPlantilla"><i class="mdi mdi-file-excel-outline"></i>Descargar plantilla</button></div>' +
        '<p><span class="cd-col es-obl">MORADO</span> obligatoria · <span class="cd-col">CELESTE</span> opcional</p></div>' +
        // 2 archivo
        '<div class="cd-paso"><div class="cd-paso-tit"><b>2</b>Sube tu planilla</div>' +
        '<div class="cd-zona' + (S.archivo ? ' tiene-archivo' : '') + '" id="cdZona" tabindex="0" role="button" aria-label="Elegir archivo">' +
        (S.archivo ? '<i class="mdi mdi-file-check-outline"></i><b>' + esc(S.archivo.nombre) + '</b><span>' + (S.archivo.tam / 1024).toFixed(0) + ' KB · clic para cambiar</span>'
                   : '<i class="mdi mdi-cloud-upload-outline"></i><b>Arrastra el .xlsx aquí</b><span>o haz clic para elegirlo</span>') +
        '</div><input type="file" id="cdArchivo" accept=".xlsx" hidden />' +
        '<p><b>Si un registro ya existe</b> (mismo código):</p>' +
        '<div class="cd-seg" id="cdExist"><button type="button" data-v="ACTUALIZAR"' + (S.existentes === 'ACTUALIZAR' ? ' class="is-on"' : '') + '>Actualizar</button>' +
        '<button type="button" data-v="OMITIR"' + (S.existentes === 'OMITIR' ? ' class="is-on"' : '') + '>Dejar como está</button></div>' +
        '<p>' + (S.existentes === 'ACTUALIZAR' ? 'Las celdas con dato reemplazan; las vacías conservan lo que había.' : 'Solo se crean los nuevos.') + '</p></div>' +
        // 3 revisar / cargar
        '<div class="cd-paso"><div class="cd-paso-tit"><b>3</b>Revisa y carga</div>' +
        '<p><b>Revisar</b> lee toda la planilla y dice qué pasará con cada fila —crear, actualizar o error— <b>sin escribir nada</b>. Lo revisado se carga con un clic, sin volver a subirlo.</p>' +
        '<p>La carga corre en segundo plano: puedes seguir trabajando y ver el avance en el recuadro de abajo a la derecha.</p>' +
        '<div class="cd-acciones">' +
        '<button type="button" class="cd-btn es-secundario" id="cdRevisar"' + (!S.archivo || corriendo ? ' disabled' : '') + '><i class="mdi mdi-magnify-scan"></i>Revisar sin cargar</button>' +
        '<button type="button" class="cd-btn es-primario" id="cdCargar"' + (!S.archivo || corriendo ? ' disabled' : '') + '><i class="mdi mdi-database-import-outline"></i>Cargar</button>' +
        '</div>' + (corriendo ? '<p><i class="mdi mdi-information-outline"></i> Hay una carga en curso: espera a que termine.</p>' : '') + '</div>' +
        '</div>';

    $('cdPlantilla').onclick = (e) => ocupado(e.currentTarget, async () => {
        const r = await ws('Plantilla', { modulo: m.clave });
        descargar(r.nombre, r.base64);
        aviso('Plantilla descargada. Complétala y súbela en el paso 2.');
    });
    const zona = $('cdZona'), inp = $('cdArchivo');
    zona.onclick = () => inp.click();
    zona.onkeydown = (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); inp.click(); } };
    inp.onchange = () => { if (inp.files[0]) tomarArchivo(inp.files[0]); };
    ['dragenter', 'dragover'].forEach((ev) => zona.addEventListener(ev, (e) => { e.preventDefault(); zona.classList.add('is-encima'); }));
    ['dragleave', 'drop'].forEach((ev) => zona.addEventListener(ev, (e) => { e.preventDefault(); zona.classList.remove('is-encima'); }));
    zona.addEventListener('drop', (e) => { const f = e.dataTransfer.files[0]; if (f) tomarArchivo(f); });
    $('cdExist').querySelectorAll('button').forEach((b) => b.onclick = () => { S.existentes = b.dataset.v; pintarAsistente(); });
    $('cdRevisar').onclick = () => iniciar('VALIDAR');
    $('cdCargar').onclick = () => iniciar('CARGAR');
}

function tomarArchivo(f) {
    if (!/\.xlsx$/i.test(f.name)) { aviso('El archivo tiene que ser .xlsx (libro de Excel).', true); return; }
    if (f.size > 60 * 1024 * 1024) { aviso('El archivo pesa más de 60 MB: divídelo en partes.', true); return; }
    S.archivo = { nombre: f.name, tam: f.size, file: f };
    pintarAsistente();
}

function leerBase64(file) {
    return new Promise((ok, mal) => {
        const r = new FileReader();
        r.onload = () => ok(String(r.result).split(',')[1] || '');
        r.onerror = () => mal(new Error('No se pudo leer el archivo.'));
        r.readAsDataURL(file);
    });
}

// ============================================================================ ejecucion
async function iniciar(modo) {
    if (!S.sel || !S.archivo) return;
    if (modo === 'CARGAR' && !confirm('Se escribirán los datos de la planilla en ' + S.sel.nombre + '.\n\n¿Quieres revisarla antes? Elige Cancelar para volver y usar «Revisar sin cargar».\n\nAceptar: cargar ahora.')) return;
    S.carga = { id: 0, modulo: S.sel.clave, modo, nombre: S.sel.nombre };
    S.ultimo = { estado: 'SUBIENDO', fase: 'Subiendo la planilla', total: 0, procesadas: 0, modo, modulo: S.sel.clave };
    S.base = 0; S.baseLocal = performance.now();
    pintarAvance(); pintarAsistente(); arrancarReloj();
    Escena.flujo(S.sel.clave, 0);
    try {
        const b64 = await leerBase64(S.archivo.file);
        const r = await ws('Iniciar', { modulo: S.sel.clave, nombre: S.archivo.nombre, base64: b64, modo, existentes: S.existentes });
        S.carga.id = r.id;
        if (r.avisos && r.avisos.length) aviso(r.avisos.slice(0, 2).join(' '), false);
        sondear();
    } catch (e) {
        S.ultimo = { estado: 'FALLIDA', fase: 'No se pudo iniciar', mensaje: e.message, modo, modulo: S.sel.clave };
        pararReloj(); pintarAvance(); pintarAsistente(); Escena.fin(S.carga.modulo, false);
        aviso(e.message, true);
    }
}

async function cargarRevision(id) {
    if (!confirm('Se cargarán las filas revisadas. Las que tenían error se vuelven a informar y no se escriben.\n\n¿Cargar ahora?')) return;
    try {
        const r = await ws('CargarRevision', { id, existentes: S.existentes });
        const m = S.modulos.find((x) => x.clave === (S.ultimo || {}).modulo) || S.sel || {};
        S.carga = { id: r.id, modulo: m.clave, modo: 'CARGAR', nombre: m.nombre };
        S.ultimo = { estado: 'EN_COLA', fase: 'En cola', total: 0, procesadas: 0, modo: 'CARGAR', modulo: m.clave };
        S.base = 0; S.baseLocal = performance.now();
        $('cdResultado').hidden = true;
        pintarAvance(); arrancarReloj(); Escena.flujo(m.clave, 0); sondear();
    } catch (e) { aviso(e.message, true); }
}

function sondear() {
    clearTimeout(S.timer);
    if (!S.carga || !S.carga.id) return;
    S.timer = setTimeout(async () => {
        try {
            const r = await ws('Estado', { id: S.carga.id });
            const c = r.carga;
            S.ultimo = c; S.base = c.segundos; S.baseLocal = performance.now();
            const m = S.modulos.find((x) => x.clave === c.modulo);
            S.carga.modulo = c.modulo; S.carga.modo = c.modo; S.carga.nombre = m ? m.nombre : c.modulo;
            Escena.flujo(c.modulo, c.total ? c.procesadas / c.total : 0);
            pintarAvance();
            if (ESTADO_FIN.includes(c.estado)) {
                pararReloj();
                Escena.fin(c.modulo, c.estado === 'TERMINADA');
                await mostrarResultado(c.id, r);
                refrescar();
                return;
            }
        } catch (e) { /* un corte de red no detiene el proceso: se reintenta */ }
        sondear();
    }, 1000);
}

function arrancarReloj() {
    clearInterval(S.tick);
    S.tick = setInterval(() => { const el = $('cdReloj'); if (el) el.textContent = reloj(S.base + (performance.now() - S.baseLocal) / 1000); }, 250);
}
function pararReloj() { clearInterval(S.tick); }

// ============================================================================ avance flotante
function pintarAvance() {
    const b = $('cdAvance'), c = S.ultimo;
    if (!c || !S.carga) { b.hidden = true; return; }
    b.hidden = false;
    const fin = ESTADO_FIN.includes(c.estado), rev = (c.modo || S.carga.modo) === 'VALIDAR';
    const pct = c.total ? Math.round(100 * c.procesadas / c.total) : 0;
    const titulo = fin ? (c.estado === 'FALLIDA' ? 'La carga no pudo terminar' : rev ? 'Revisión lista' : 'Carga lista')
                       : (rev ? 'Revisando ' : 'Cargando ') + esc((S.carga.nombre || '').toLowerCase());
    const ico = !fin ? '<span class="cd-girando" aria-hidden="true"></span>'
        : c.estado === 'TERMINADA' ? '<span class="cd-avance-ico" style="background:#E9F7F0;color:#16855B"><i class="mdi mdi-check-bold"></i></span>'
        : c.estado === 'CON_ERRORES' ? '<span class="cd-avance-ico" style="background:#FFF4E5;color:#B65C00"><i class="mdi mdi-alert"></i></span>'
        : '<span class="cd-avance-ico" style="background:#FDF0EF;color:#C7352B"><i class="mdi mdi-close-thick"></i></span>';
    const abierto = b.querySelector('.cd-alerta-form textarea');
    const textoPrevio = abierto ? abierto.value : null;
    b.className = 'cd-avance' + (fin ? ' es-fin' : '');
    b.innerHTML =
        '<div class="cd-avance-cab">' + ico + '<div><b>' + titulo + '</b><small>' + esc(fin ? (c.mensaje || '') : (c.fase || '')) + '</small></div>' +
        (fin ? '<button type="button" class="cd-avance-x" id="cdAvCerrar" title="Cerrar"><i class="mdi mdi-close"></i></button>' : '') + '</div>' +
        '<div class="cd-barra' + (!fin && !c.total ? ' es-indet' : '') + '"><span style="width:' + (fin ? 100 : pct) + '%;' + (c.estado === 'CON_ERRORES' ? 'background:#FFB23F' : c.estado === 'FALLIDA' ? 'background:#C7352B' : '') + '"></span></div>' +
        '<div class="cd-avance-datos"><span>' + (c.total ? num(c.procesadas) + ' de ' + num(c.total) + ' filas' + (c.errores ? ' · ' + num(c.errores) + ' con error' : '') : esc(c.fase || '')) + '</span>' +
        '<span class="cd-reloj"><i class="mdi mdi-timer-outline"></i><span id="cdReloj">' + reloj(S.base + (fin ? 0 : (performance.now() - S.baseLocal) / 1000)) + '</span></span></div>' +
        '<div class="cd-avance-pie">' +
        (fin && S.carga.id ? '<button type="button" class="cd-btn es-contorno es-chico" id="cdAvVer"><i class="mdi mdi-eye-outline"></i>Ver resultado</button>' : '') +
        '<button type="button" class="cd-btn es-ghost es-chico" id="cdAvAlerta"><i class="mdi mdi-alert-octagram-outline"></i>Alertar un problema</button></div>' +
        (textoPrevio != null ? formAlerta(textoPrevio) : '');
    const x = $('cdAvCerrar'); if (x) x.onclick = () => { b.hidden = true; S.carga = null; pintarAsistente(); };
    const v = $('cdAvVer'); if (v) v.onclick = () => $('cdResultado').scrollIntoView({ behavior: 'smooth', block: 'start' });
    $('cdAvAlerta').onclick = () => { if (!b.querySelector('.cd-alerta-form')) { b.insertAdjacentHTML('beforeend', formAlerta('')); enlazarAlerta(); b.querySelector('textarea').focus(); } };
    if (textoPrevio != null) enlazarAlerta();
}

function formAlerta(texto) {
    return '<div class="cd-alerta-form"><textarea id="cdAlTxt" maxlength="2000" placeholder="¿Qué pasó? Por ejemplo: se quedó en 40% hace varios minutos, o un error que no entiendo.">' + esc(texto) + '</textarea>' +
        '<div class="cd-avance-pie" style="margin-top:0"><button type="button" class="cd-btn es-ghost es-chico" id="cdAlNo">Cancelar</button>' +
        '<button type="button" class="cd-btn es-primario es-chico" id="cdAlSi"><i class="mdi mdi-send"></i>Enviar</button></div>' +
        '<span class="cd-muted">Se envía con lo que muestra este recuadro: fase, avance y tiempo.</span></div>';
}
function enlazarAlerta() {
    $('cdAlNo').onclick = () => { const f = document.querySelector('.cd-alerta-form'); if (f) f.remove(); };
    $('cdAlSi').onclick = (e) => ocupado(e.currentTarget, async () => {
        const txt = $('cdAlTxt').value.trim();
        if (!txt) throw new Error('Cuéntanos qué pasó.');
        const c = S.ultimo || {};
        const contexto = JSON.stringify({ estado: c.estado, fase: c.fase, procesadas: c.procesadas, total: c.total, errores: c.errores,
            segundos: Math.round(S.base + (performance.now() - S.baseLocal) / 1000), modulo: S.carga && S.carga.modulo, modo: S.carga && S.carga.modo,
            navegador: navigator.userAgent, pantalla: innerWidth + 'x' + innerHeight, url: location.pathname });
        const r = await ws('Incidencia', { carga: (S.carga && S.carga.id) || 0, comentario: txt, contexto });
        const f = document.querySelector('.cd-alerta-form'); if (f) f.remove();
        aviso(r.detalle);
    });
}

// ============================================================================ resultado
async function mostrarResultado(id, estado) {
    const r = estado || await ws('Estado', { id });
    const c = r.carga, hojas = r.hojas || [];
    const m = S.modulos.find((x) => x.clave === c.modulo) || { nombre: c.modulo, hojas: [] };
    const rev = c.modo === 'VALIDAR';
    let errores = { total: 0, errores: [] };
    if (c.errores > 0 || c.estado === 'FALLIDA') { try { errores = await ws('Errores', { id }); } catch (e) { } }
    S.filtroErr = '';
    const box = $('cdResultado');
    box.hidden = false;
    const k = (ico, tono, v, t) => '<div class="cd-kpi"><span class="cd-kpi-ico" style="background:' + tono + '1A;color:' + tono + '"><i class="mdi ' + ico + '"></i></span><div><b>' + num(v) + '</b><span>' + t + '</span></div></div>';
    const listo = c.creadas + c.actualizadas;
    box.innerHTML =
        '<div class="cd-card-cab"><h3><i class="mdi ' + (rev ? 'mdi-magnify-scan' : 'mdi-database-check-outline') + '"></i>' + (rev ? 'Revisión' : 'Carga') + ' N° ' + c.id + ' · ' + esc(m.nombre) + '</h3>' +
        '<span class="cd-muted">' + esc(c.archivo) + ' · ' + esc(c.inicio) + ' · ' + reloj(c.segundos) + ' · ' + esc(c.usuario) + '</span></div>' +
        (c.estado === 'FALLIDA' ? '<div class="cd-nota es-error"><i class="mdi mdi-close-octagon-outline"></i><div><b>El proceso no terminó.</b> ' + esc(c.mensaje || '') + ' Lo que alcanzó a cargarse queda; puedes volver a subir la planilla: lo existente se actualiza, no se duplica.</div></div>'
            : rev ? '<div class="cd-nota' + (c.errores ? ' es-alerta' : '') + '"><i class="mdi ' + (c.errores ? 'mdi-alert-outline' : 'mdi-check-decagram-outline') + '"></i><div>' +
                    (c.errores ? '<b>' + num(c.errores) + ' filas tienen errores.</b> Corrígelas en la planilla y vuelve a revisar, o carga ahora lo que está bien: las filas con error no se escriben.'
                               : '<b>La planilla está lista.</b> Nada se escribió todavía: carga cuando quieras.') + '</div></div>'
                  : '<div class="cd-nota' + (c.errores ? ' es-alerta' : '') + '"><i class="mdi ' + (c.errores ? 'mdi-alert-outline' : 'mdi-check-decagram-outline') + '"></i><div>' + esc(c.mensaje || '') +
                    (c.errores ? ' Corrige las filas con error y vuelve a cargar la planilla: lo que ya entró se actualiza, no se duplica.' : '') + '</div></div>') +
        '<div class="cd-kpis">' +
        k('mdi-plus-circle-outline', '#16855B', c.creadas, rev ? 'se crearían' : 'creadas') +
        k('mdi-pencil-circle-outline', '#087BEA', c.actualizadas, rev ? 'se actualizarían' : 'actualizadas') +
        k('mdi-minus-circle-outline', '#68738A', c.omitidas, rev ? 'se dejarían igual' : 'omitidas') +
        k('mdi-alert-circle-outline', c.errores ? '#C7352B' : '#68738A', c.errores, 'con error') + '</div>' +
        '<div class="cd-tabla-scroll"><table class="cd-tabla"><thead><tr><th>Hoja</th><th class="num">Filas</th><th class="num">' + (rev ? 'Se crean' : 'Creadas') + '</th><th class="num">' + (rev ? 'Se actualizan' : 'Actualizadas') + '</th><th class="num">Omitidas</th><th class="num">Errores</th></tr></thead><tbody>' +
        (hojas.length ? hojas.map((h) => '<tr><td><b>' + esc(nombreHoja(h.hoja)) + '</b></td><td class="num">' + num(h.filas) + '</td><td class="num">' + num(h.creadas) + '</td><td class="num">' + num(h.actualizadas) + '</td><td class="num">' + num(h.omitidas) + '</td><td class="num">' + (h.errores ? '<span class="cd-chip es-danger">' + num(h.errores) + '</span>' : '0') + '</td></tr>').join('')
                     : '<tr><td colspan="6" class="cd-vacio">Las filas de esta carga ya no se guardan (tienen más de 30 días).</td></tr>') +
        '</tbody></table></div>' +
        '<div class="cd-acciones" style="margin-top:14px">' +
        (rev && listo > 0 && c.estado !== 'FALLIDA' ? '<button type="button" class="cd-btn es-primario" id="cdResCargar"><i class="mdi mdi-database-import-outline"></i>Cargar ' + num(listo) + ' filas ahora</button>' : '') +
        (c.errores ? '<button type="button" class="cd-btn es-contorno" id="cdResExcel"><i class="mdi mdi-file-excel-outline"></i>Descargar errores en Excel</button>' : '') +
        '</div>' +
        (errores.total ? '<h4 style="margin:18px 0 6px;font-size:13px;font-weight:800">Errores' + (errores.total > 1000 ? ' (primeros 1.000 de ' + num(errores.total) + ')' : '') + '</h4>' +
            '<div class="cd-filtros" id="cdFiltros"></div><div class="cd-tabla-scroll"><table class="cd-tabla" id="cdErrTabla"></table></div>' : '');
    const bc = $('cdResCargar'); if (bc) bc.onclick = () => cargarRevision(c.id);
    const be = $('cdResExcel'); if (be) be.onclick = (e) => ocupado(e.currentTarget, async () => { const x = await ws('ErroresExcel', { id: c.id }); descargar(x.nombre, x.base64); });
    if (errores.total) pintarErrores(errores.errores);
}

function pintarErrores(lista) {
    const hojas = [...new Set(lista.map((e) => e.hoja))];
    const f = $('cdFiltros');
    f.innerHTML = '<button type="button" class="cd-filtro' + (!S.filtroErr ? ' is-on' : '') + '" data-h="">Todas · ' + num(lista.length) + '</button>' +
        hojas.map((h) => '<button type="button" class="cd-filtro' + (S.filtroErr === h ? ' is-on' : '') + '" data-h="' + esc(h) + '">' + esc(nombreHoja(h)) + ' · ' + num(lista.filter((e) => e.hoja === h).length) + '</button>').join('');
    f.querySelectorAll('[data-h]').forEach((b) => b.onclick = () => { S.filtroErr = b.dataset.h; pintarErrores(lista); });
    const vis = lista.filter((e) => !S.filtroErr || e.hoja === S.filtroErr);
    $('cdErrTabla').innerHTML = '<thead><tr><th>Hoja</th><th class="num">Fila</th><th>Columna</th><th>Valor</th><th>Motivo</th></tr></thead><tbody>' +
        vis.map((e) => '<tr><td>' + esc(nombreHoja(e.hoja)) + '</td><td class="num"><b>' + e.fila + '</b></td><td>' + esc(e.columna) + '</td><td>' + (e.valor ? '<code>' + esc(e.valor) + '</code>' : '') + '</td><td>' + esc(e.mensaje) + '</td></tr>').join('') + '</tbody>';
}

// ============================================================================ historial
function pintarHistorial(h) {
    $('cdHistN').textContent = h.length ? h.length + (h.length === 1 ? ' carga' : ' cargas') : '';
    if (!h.length) { $('cdHistorial').innerHTML = '<tbody><tr><td class="cd-vacio">' + (FIJO ? 'Todavía no se ha cargado nada aquí. Descarga la plantilla para empezar.' : 'Todavía no se ha cargado nada. Elige un módulo arriba para empezar.') + '</td></tr></tbody>'; return; }
    $('cdHistorial').innerHTML = '<thead><tr><th>N°</th><th>Fecha</th><th>Módulo</th><th>Archivo</th><th>Tipo</th><th>Resultado</th><th class="num">Filas</th><th class="num">Duración</th><th>Quién</th></tr></thead><tbody>' +
        h.map((x) => {
            const m = S.modulos.find((y) => y.clave === x.modulo);
            return '<tr class="es-clic" data-id="' + x.id + '"><td>' + x.id + '</td><td>' + esc(x.inicio) + '</td><td>' + esc(m ? m.nombre : x.modulo) + '</td><td>' + esc(x.archivo) + '</td>' +
                '<td>' + (x.modo === 'VALIDAR' ? '<span class="cd-chip es-cyan">Revisión</span>' : '<span class="cd-chip es-purple">Carga</span>') + '</td>' +
                '<td>' + chipEstado(x) + (x.estado !== 'FALLIDA' && (x.creadas || x.actualizadas) ? ' <span class="cd-muted">' + num(x.creadas) + ' nuevas · ' + num(x.actualizadas) + ' act.</span>' : '') + '</td>' +
                '<td class="num">' + num(x.total) + '</td><td class="num">' + reloj(x.segundos) + '</td><td>' + esc(x.usuario) + '</td></tr>';
        }).join('') + '</tbody>';
    $('cdHistorial').querySelectorAll('[data-id]').forEach((tr) => tr.onclick = async () => {
        try { await mostrarResultado(+tr.dataset.id); $('cdResultado').scrollIntoView({ behavior: 'smooth', block: 'start' }); } catch (e) { aviso(e.message, true); }
    });
}

// ============================================================================ inicio
async function refrescar() {
    const d = await ws('Inicio', {});
    S.modulos = d.modulos;
    if (S.sel) S.sel = S.modulos.find((m) => m.clave === S.sel.clave) || null;
    Escena.modulos(S.modulos);
    pintarModulos();
    pintarAsistente();
    pintarHistorial((d.historial || []).filter((x) => !FIJO || x.modulo === FIJO));
    return d;
}

(async function () {
    try {
        const d = await refrescar();
        const primero = FIJO ? S.modulos.find((m) => m.clave === FIJO) : S.modulos.find((m) => m.disponible);
        if (primero) elegirModulo(primero.clave, false);
        // una carga que seguia corriendo (se recargo la pagina): se retoma su seguimiento
        if (d.enCurso) {
            S.carga = { id: d.enCurso, modulo: '', modo: '', nombre: '' };
            S.ultimo = { estado: 'PROCESANDO', fase: 'Retomando el seguimiento…', total: 0, procesadas: 0 };
            S.baseLocal = performance.now();
            pintarAvance(); arrancarReloj(); sondear();
        }
    } catch (e) {
        $('cdModulos').innerHTML = '<div class="cd-card cd-vacio" style="grid-column:1/-1"><i class="mdi mdi-alert-circle-outline" style="font-size:28px;color:#C7352B"></i><br />' + esc(e.message) + '</div>';
    }
})();
