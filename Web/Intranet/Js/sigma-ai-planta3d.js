/* SIGMA AI · planta en vivo (Three.js r160, modulo ES). Referencia: docs/rediseno-sigma-ai/sigma-ai-centro-referencia.html.
   Las areas son plataformas, cada activo un pilar (alto = riesgo) y el nucleo de SIGMA AI flota sobre la planta y recibe los
   datos de los activos en riesgo. Se carga bajo demanda desde sigma-ai-centro.js (import dinamico): si no hay WebGL,
   mount() devuelve null y la vista usa su grilla de respaldo. */
import * as THREE from 'three';

/* SIGMA AI · planta en vivo (Three.js r160).
   Áreas como plataformas, cada activo como un pilar (alto = riesgo), y un núcleo
   de SIGMA AI flotando sobre la planta que recibe los datos de los activos en riesgo. */
function glowTex() {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d'), r = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  r.addColorStop(0, 'rgba(255,255,255,1)'); r.addColorStop(.2, 'rgba(255,255,255,.6)'); r.addColorStop(.5, 'rgba(255,255,255,.12)'); r.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = r; g.fillRect(0, 0, 128, 128); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
const sevColor = p => !p ? 0x56619F : p >= 70 ? 0xFF5C8A : p >= 50 ? 0xFFB547 : 0x00E0C2;

function mount(canvas, opt) {
  let renderer;
  try { renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' }); } catch (e) { return null; }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.75)); renderer.setClearColor(0, 0);
  const scene = new THREE.Scene(); scene.fog = new THREE.Fog(0x060A14, 16, 34);
  const camera = new THREE.PerspectiveCamera(36, 1, .1, 120);
  const gsap = window.gsap, reduced = !!opt.reduced, tex = glowTex(), D = [tex];
  const T = o => { D.push(o); return o; };
  const root = new THREE.Group(); scene.add(root);

  /* piso */
  const grid = new THREE.GridHelper(30, 60, 0x2B3570, 0x141A36); grid.material.transparent = true; grid.material.opacity = .55; grid.position.y = -.02; root.add(grid); D.push(grid.geometry, grid.material);

  /* áreas */
  const areaTop = {};
  opt.areas.forEach(a => {
    const plat = new THREE.Mesh(T(new THREE.BoxGeometry(a.w, .08, a.d)), T(new THREE.MeshBasicMaterial({ color: 0x10163A, transparent: true, opacity: .92 })));
    plat.position.set(a.cx, .04, a.cz); root.add(plat);
    const ed = new THREE.LineSegments(T(new THREE.EdgesGeometry(plat.geometry)), T(new THREE.LineBasicMaterial({ color: 0x6C5CFF, transparent: true, opacity: .55 })));
    ed.position.copy(plat.position); root.add(ed);
    const inner = new THREE.Mesh(T(new THREE.PlaneGeometry(a.w - .3, a.d - .3)), T(new THREE.MeshBasicMaterial({ color: 0x1B2356, transparent: true, opacity: .55 })));
    inner.rotation.x = -Math.PI / 2; inner.position.set(a.cx, .085, a.cz); root.add(inner);
    areaTop[a.id] = new THREE.Vector3(a.cx, .1, a.cz - a.d / 2 - .35);
  });

  /* núcleo SIGMA AI */
  const coreU = { t: { value: 0 } };
  const core = new THREE.Mesh(T(new THREE.IcosahedronGeometry(.62, 5)), T(new THREE.ShaderMaterial({
    uniforms: coreU, transparent: true, depthWrite: false,
    vertexShader: 'varying vec3 vN; varying vec3 vP; void main(){ vN=normalize(normalMatrix*normal); vP=position; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }',
    fragmentShader: `uniform float t; varying vec3 vN; varying vec3 vP;
      vec3 g(float x){ vec3 a=vec3(0.,.878,.761), b=vec3(.145,.388,.922), c=vec3(.424,.361,1.), d=vec3(1.,.302,.616);
        if(x<.48) return mix(a,b,x/.48); if(x<.74) return mix(b,c,(x-.48)/.26); return mix(c,d,(x-.74)/.26); }
      void main(){ float f=pow(1.-abs(dot(vN,vec3(0.,0.,1.))),2.); vec3 col=g(fract(vP.y*.6+vP.x*.4+t*.05));
        float band=.5+.5*sin(vP.y*16.+t*2.); gl_FragColor=vec4(col*(.3+f*1.5)+band*.05,(.2+f*.9)); }`
  })));
  const coreG = new THREE.Group(); coreG.position.set(.4, 4.3, .1); coreG.add(core); root.add(coreG);
  const wire = new THREE.LineSegments(T(new THREE.WireframeGeometry(T(new THREE.IcosahedronGeometry(.78, 1)))), T(new THREE.LineBasicMaterial({ color: 0x8C9BFF, transparent: true, opacity: .35 }))); coreG.add(wire);
  const halo = new THREE.Sprite(T(new THREE.SpriteMaterial({ map: tex, color: 0x6C5CFF, transparent: true, opacity: .65, blending: THREE.AdditiveBlending, depthWrite: false }))); halo.scale.set(4.4, 4.4, 1); coreG.add(halo);
  const ringC = new THREE.Mesh(T(new THREE.TorusGeometry(1.15, .012, 8, 120)), T(new THREE.MeshBasicMaterial({ color: 0x00E0C2, transparent: true, opacity: .5 }))); ringC.rotation.x = Math.PI / 2.3; coreG.add(ringC);
  const beamDown = new THREE.Mesh(T(new THREE.CylinderGeometry(.015, .25, 4.2, 24, 1, true)), T(new THREE.MeshBasicMaterial({ color: 0x6C5CFF, transparent: true, opacity: .07, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })));
  beamDown.position.set(.4, 2.15, .1); root.add(beamDown);

  /* activos */
  const N = [], hits = [], coreW = new THREE.Vector3(.4, 4.3, .1);
  const byArea = {}; opt.assets.forEach(a => (byArea[a.area] = byArea[a.area] || []).push(a));
  opt.areas.forEach(ar => {
    const list = (byArea[ar.id] || []).slice().sort((a, b) => b.p - a.p), n = list.length;
    const cols = Math.max(1, Math.round(Math.sqrt(n * ar.w / ar.d))), rows = Math.ceil(n / cols);
    list.forEach((a, i) => {
      const c = i % cols, r = Math.floor(i / cols);
      const x = ar.cx - ar.w / 2 + (c + .5) * (ar.w / cols), z = ar.cz - ar.d / 2 + (r + .5) * (ar.d / rows);
      const risk = a.p >= 40, h = risk ? .45 + a.p / 100 * 1.9 : .26 + ((i * 37) % 10) / 60, col = sevColor(a.p);
      const g = new THREE.Group(); g.position.set(x, .09, z); root.add(g);
      const pil = new THREE.Mesh(T(new THREE.CylinderGeometry(risk ? .13 : .1, risk ? .15 : .12, h, 20)), T(new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: risk ? .95 : .8 })));
      pil.position.y = h / 2; g.add(pil);
      const cap = new THREE.Mesh(T(new THREE.CircleGeometry(risk ? .13 : .1, 20)), T(new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: risk ? .55 : .25 }))); cap.rotation.x = -Math.PI / 2; cap.position.y = h + .001; g.add(cap);
      const glow = new THREE.Sprite(T(new THREE.SpriteMaterial({ map: tex, color: col, transparent: true, opacity: risk ? .95 : .3, blending: THREE.AdditiveBlending, depthWrite: false }))); glow.scale.setScalar(risk ? 1.1 : .45); glow.position.y = h + .05; g.add(glow);
      const hit = new THREE.Mesh(T(new THREE.BoxGeometry(.42, h + .5, .42)), T(new THREE.MeshBasicMaterial({ visible: false }))); hit.position.y = (h + .5) / 2; hit.userData.id = a.id; g.add(hit); hits.push(hit);
      const o = { a, g, pil, cap, glow, h, risk, col, ph: Math.random() * 6, rings: [], link: null, pk: [], grow: reduced || !gsap ? 1 : 0, dim: 1 };
      if (risk) {
        for (let k = 0; k < 2; k++) { const rg = new THREE.Mesh(T(new THREE.RingGeometry(.2, .26, 40)), T(new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false }))); rg.rotation.x = -Math.PI / 2; rg.position.y = .02; g.add(rg); o.rings.push({ m: rg, u: k * .5 }); }
        if (a.p >= 50) {
          const top = new THREE.Vector3(x, h + .15, z), mid = top.clone().lerp(coreW, .5); mid.y += 1.2;
          const curve = new THREE.QuadraticBezierCurve3(top, mid, coreW);
          o.curve = curve;
          o.link = new THREE.Line(T(new THREE.BufferGeometry().setFromPoints(curve.getPoints(40))), T(new THREE.LineBasicMaterial({ color: col, transparent: true, opacity: .35, blending: THREE.AdditiveBlending })));
          root.add(o.link);
          for (let k = 0; k < 3; k++) { const s = new THREE.Sprite(T(new THREE.SpriteMaterial({ map: tex, color: col, transparent: true, opacity: .9, blending: THREE.AdditiveBlending, depthWrite: false }))); s.scale.setScalar(.2); root.add(s); o.pk.push({ s, u: k / 3 }); }
        }
      }
      N.push(o);
    });
  });
  /* RED NEURONAL: cada area alimenta al cerebro. Una neurona por cada activo de la planta alrededor del nucleo, sinapsis entre las
     cercanas, y desde cada area un cable de datos con paquetes que viajan hacia el cerebro (mas rapidos y rosados si el area tiene riesgo). */
  const neuG = new THREE.Group(); coreG.add(neuG);
  const nn = Math.max(36, Math.min(110, opt.assets.length * 3 + 30)), nodes = [];
  for (let i = 0; i < nn; i++) {
    const th = Math.random() * Math.PI * 2, ph = Math.acos(2 * Math.random() - 1), rr = 1.25 + Math.random() * .75;
    nodes.push(new THREE.Vector3(rr * Math.sin(ph) * Math.cos(th), rr * Math.cos(ph) * .8, rr * Math.sin(ph) * Math.sin(th)));
  }
  const sy = []; for (let i = 0; i < nn; i++) for (let j = i + 1; j < nn; j++) if (nodes[i].distanceTo(nodes[j]) < 1.05) sy.push(nodes[i].x, nodes[i].y, nodes[i].z, nodes[j].x, nodes[j].y, nodes[j].z);
  const web = new THREE.LineSegments(T(new THREE.BufferGeometry()), T(new THREE.LineBasicMaterial({ color: 0x8C9BFF, transparent: true, opacity: .2, blending: THREE.AdditiveBlending, depthWrite: false })));
  web.geometry.setAttribute('position', new THREE.Float32BufferAttribute(sy, 3)); neuG.add(web);
  const npts = new THREE.Points(T(new THREE.BufferGeometry().setFromPoints(nodes)), T(new THREE.PointsMaterial({ map: tex, color: 0xB8C0FF, size: .2, transparent: true, opacity: .9, blending: THREE.AdditiveBlending, depthWrite: false, sizeAttenuation: true })));
  neuG.add(npts);
  const AL = [];
  opt.areas.forEach(ar => {
    const inArea = opt.assets.filter(a => a.area === ar.id), riesgo = inArea.reduce((m, a) => Math.max(m, a.p || 0), 0);
    const col = riesgo >= 70 ? 0xFF5C8A : riesgo >= 50 ? 0xFFB547 : 0x00E0C2;
    const top = new THREE.Vector3(ar.cx, .35, ar.cz), mid = top.clone().lerp(coreW, .5); mid.y += 1.6 + Math.random() * .6;
    const curve = new THREE.QuadraticBezierCurve3(top, mid, coreW);
    const line = new THREE.Line(T(new THREE.BufferGeometry().setFromPoints(curve.getPoints(48))), T(new THREE.LineBasicMaterial({ color: col, transparent: true, opacity: .22, blending: THREE.AdditiveBlending, depthWrite: false })));
    root.add(line);
    const pk = []; const nPk = 2 + Math.min(4, inArea.length);
    for (let k = 0; k < nPk; k++) { const sp = new THREE.Sprite(T(new THREE.SpriteMaterial({ map: tex, color: col, transparent: true, opacity: .9, blending: THREE.AdditiveBlending, depthWrite: false }))); sp.scale.setScalar(.16); root.add(sp); pk.push({ s: sp, u: k / nPk }); }
    AL.push({ curve, line, pk, v: .16 + (riesgo >= 50 ? .2 : 0) + Math.min(.14, inArea.length * .01), riesgo });
  });

  /* anillo de selección */
  const selRing = new THREE.Mesh(T(new THREE.RingGeometry(.34, .4, 48)), T(new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: .0, side: THREE.DoubleSide }))); selRing.rotation.x = -Math.PI / 2; root.add(selRing);

  /* cámara orbital */
  const tgt = new THREE.Vector3(.3, .6, .2), cam = { az: .78, pol: .98, r: 15.5 }, home = { x: .3, y: .6, z: .2, r: 15.5 };
  let idle = 0, drag = null, autoSpin = !reduced;
  function placeCam() { const s = Math.sin(cam.pol); camera.position.set(tgt.x + cam.r * s * Math.sin(cam.az), tgt.y + cam.r * Math.cos(cam.pol), tgt.z + cam.r * s * Math.cos(cam.az)); camera.lookAt(tgt); }
  if (!reduced && gsap) {
    cam.r = 24; cam.pol = .7; gsap.to(cam, { r: 15.5, pol: .98, duration: 2.4, ease: 'expo.out' });
    N.forEach((o, i) => gsap.to(o, { grow: 1, duration: 1.2, ease: 'expo.out', delay: .3 + i * .02 }));
    coreG.scale.setScalar(.01); gsap.to(coreG.scale, { x: 1, y: 1, z: 1, duration: 1.6, ease: 'expo.out', delay: .9 });
  }

  /* interacción */
  const host = opt.host, ray = new THREE.Raycaster(), m2 = new THREE.Vector2(); let hover = null, selId = opt.sel || null;
  function pick(e) { const r = canvas.getBoundingClientRect(); m2.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1); ray.setFromCamera(m2, camera); const it = ray.intersectObjects(hits, false)[0]; return it ? it.object.userData.id : null; }
  function onDown(e) { if (e.target !== canvas) return; drag = { x: e.clientX, y: e.clientY, az: cam.az, pol: cam.pol, moved: false }; canvas.setPointerCapture && canvas.setPointerCapture(e.pointerId); }
  function onMove(e) {
    if (drag) { const dx = e.clientX - drag.x, dy = e.clientY - drag.y; if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true; cam.az = drag.az - dx * .006; cam.pol = Math.max(.45, Math.min(1.25, drag.pol - dy * .004)); idle = 0; opt.onLeave && opt.onLeave(); return; }
    if (e.target !== canvas) { if (hover) { hover = null; opt.onLeave && opt.onLeave(); } return; }
    const id = pick(e); hover = id; canvas.style.cursor = id ? 'pointer' : '';
    if (id && opt.onHover) { const hr = host.getBoundingClientRect(); opt.onHover(id, e.clientX - hr.left, e.clientY - hr.top); } else opt.onLeave && opt.onLeave();
  }
  function onUp(e) { if (drag && !drag.moved && e.target === canvas) { const id = pick(e); if (id && opt.onSelect) opt.onSelect(id); } drag = null; }
  host.addEventListener('pointerdown', onDown); window.addEventListener('pointermove', onMove); window.addEventListener('pointerup', onUp);
  host.addEventListener('pointerleave', () => { hover = null; opt.onLeave && opt.onLeave(); });
  function zoom(f) { cam.r = Math.max(5, Math.min(30, cam.r * (f > 0 ? .82 : 1.22))); idle = -4; }
  function onWheel(e) { if (!(e.ctrlKey || e.metaKey || host.classList.contains('full'))) return; e.preventDefault(); zoom(e.deltaY < 0 ? 1 : -1); }
  host.addEventListener('wheel', onWheel, { passive: false });

  /* tamaño */
  function resize() { const w = canvas.clientWidth || 1, h = canvas.clientHeight || 1; renderer.setSize(w, h, false); camera.aspect = w / h; camera.fov = w < 700 ? 48 : 36; camera.updateProjectionMatrix(); }
  const ro = new ResizeObserver(resize); ro.observe(canvas); resize();

  /* bucle */
  const clock = new THREE.Clock(), v = new THREE.Vector3(); let t = 0, running = true, raf = 0, filt = 'all';
  const labs = opt.areas.map(a => ({ a, el: opt.labelEl ? opt.labelEl.querySelector(`[data-al="${a.id}"]`) : null })).filter(x => x.el);
  function frame() {
    raf = requestAnimationFrame(frame); if (!running) return;
    const dt = Math.min(clock.getDelta(), .05); if (!reduced) t += dt;
    idle += dt; if (autoSpin && !drag && idle > 3) cam.az += dt * .05;
    placeCam(); coreU.t.value = t;
    core.rotation.y = t * .3; wire.rotation.y = -t * .25; ringC.rotation.z = t * .4; halo.material.opacity = .55 + Math.sin(t * 1.2) * .12;
    coreG.position.y = 4.3 + Math.sin(t * .8) * .08;
    N.forEach(o => {
      const show = filt === 'all' || o.risk; o.dim += ((show ? 1 : .12) - o.dim) * .12;
      o.pil.scale.y = Math.max(.001, o.grow); o.pil.position.y = o.h * o.grow / 2; o.cap.position.y = o.h * o.grow + .001; o.glow.position.y = o.h * o.grow + .05;
      o.pil.material.opacity = (o.risk ? .95 : .8) * o.dim; o.cap.material.opacity = (o.risk ? .55 : .25) * o.dim;
      const sel = selId === o.a.id, hv = hover === o.a.id;
      o.glow.material.opacity = (o.risk ? .75 + Math.sin(t * 3 + o.ph) * .25 : .3) * o.dim * o.grow;
      o.glow.scale.setScalar((o.risk ? 1.1 : .45) * (sel || hv ? 1.5 : 1));
      o.rings.forEach(r => { r.u = (r.u + dt * .55) % 1; const s = 1 + r.u * 3.2; r.m.scale.set(s, s, s); r.m.material.opacity = (1 - r.u) * .6 * o.dim * o.grow; });
      if (o.link) { o.link.material.opacity = (.25 + Math.sin(t * 2 + o.ph) * .1 + (sel ? .4 : 0)) * o.dim * o.grow; o.pk.forEach(k => { k.u = (k.u + dt * .32) % 1; o.curve.getPoint(k.u, k.s.position); k.s.material.opacity = Math.sin(k.u * Math.PI) * o.dim * o.grow; }); }
      if (sel) { selRing.position.set(o.g.position.x, .1, o.g.position.z); selRing.material.opacity = .75 + Math.sin(t * 4) * .2; selRing.scale.setScalar(1 + Math.sin(t * 4) * .06); }
    });
    neuG.rotation.y = t * .12; neuG.rotation.x = Math.sin(t * .2) * .08; npts.material.opacity = .65 + Math.sin(t * 1.6) * .25; web.material.opacity = .16 + Math.sin(t * 1.1) * .06;
    AL.forEach(l => { l.line.material.opacity = .16 + Math.sin(t * 2) * .06 + (l.riesgo >= 50 ? .12 : 0); l.pk.forEach(k => { k.u = (k.u + dt * l.v) % 1; l.curve.getPoint(k.u, k.s.position); k.s.material.opacity = Math.sin(k.u * Math.PI); k.s.scale.setScalar(.12 + Math.sin(k.u * Math.PI) * .1); }); });
    if (!selId) selRing.material.opacity = 0;
    renderer.render(scene, camera);
    const w = canvas.clientWidth, h = canvas.clientHeight;
    labs.forEach(l => { v.copy(areaTop[l.a.id]); v.project(camera); l.el.style.transform = `translate(${(v.x * .5 + .5) * w}px,${(-v.y * .5 + .5) * h}px) translate(-50%,-50%)`; l.el.style.opacity = v.z < 1 ? 1 : 0; });
  }
  frame();
  return {
    focus(id) {
      selId = id; const o = N.find(x => x.a.id === id); if (!o) return; idle = -4;
      if (gsap && !reduced) { gsap.to(tgt, { x: o.g.position.x, y: .5, z: o.g.position.z, duration: 1.4, ease: 'expo.inOut' }); gsap.to(cam, { r: 10.5, duration: 1.4, ease: 'expo.inOut' }); }
      else { tgt.set(o.g.position.x, .5, o.g.position.z); cam.r = 10.5; }
    },
    reset() { idle = 0; if (gsap && !reduced) { gsap.to(tgt, { x: home.x, y: home.y, z: home.z, duration: 1.2, ease: 'expo.inOut' }); gsap.to(cam, { r: home.r, pol: .98, duration: 1.2, ease: 'expo.inOut' }); } else { tgt.set(home.x, home.y, home.z); cam.r = home.r; } },
    filter(f) { filt = f; },
    zoom(f) { if (gsap && !reduced) { const r2 = Math.max(5, Math.min(30, cam.r * (f > 0 ? .8 : 1.25))); gsap.to(cam, { r: r2, duration: .5, ease: 'power2.out' }); idle = -4; } else zoom(f); },
    setRunning(b) { running = b; if (b) clock.getDelta(); },
    dispose() { cancelAnimationFrame(raf); ro.disconnect(); host.removeEventListener('pointerdown', onDown); host.removeEventListener('wheel', onWheel); window.removeEventListener('pointermove', onMove); window.removeEventListener('pointerup', onUp); D.forEach(d => d.dispose && d.dispose()); renderer.dispose(); }
  };
}

window.SGPLANT = { mount };
window.dispatchEvent(new Event('sgplant-ready'));
export { mount };
