/* SIGMA · Landing pública cinematográfica (Inicio.aspx).
   three.js + GSAP/ScrollTrigger locales. Regla de oro: todo el contenido se ve sin JS;
   cada escena va en su propio try/catch para que un fallo no rompa la página. */

const $ = (s, r) => (r || document).querySelector(s);
const $$ = (s, r) => Array.prototype.slice.call((r || document).querySelectorAll(s));
const byId = (id) => document.getElementById(id);

const reduced = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
const fine = !!(window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches);
const gs = window.gsap || null;
const ST = window.ScrollTrigger || null;
if (gs && ST) { try { gs.registerPlugin(ST); } catch (e) { /* sin ScrollTrigger */ } }

let THREE = null;
try { THREE = await import('../three/three.module.min.js'); } catch (e) { THREE = null; }

const root = byId('sg-root');
const gls = [];
let mouse = null, onMove = null;
let heroGL = null, cineGL = null, twinGL = null;
let introTl = null, safety = null, introOn = false;
let mq1 = null, mq2 = null;
let storyIdx = 0;
let spot = 'ai', soundMuted = true, userPaused = false;
let activeNav = 'inicio', navLight = false;
let ctx = null;

/* =============== nav =============== */
const navEl = byId('sg-nav');
const burger = byId('sg-burger');
const mnav = byId('sg-mnav');

function setMenu(open) {
  if (!burger || !mnav) return;
  mnav.hidden = !open;
  burger.setAttribute('aria-expanded', open ? 'true' : 'false');
  burger.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
  byId('sg-ico-close').hidden = !open;
  byId('sg-ico-open').hidden = open;
}
if (burger) burger.addEventListener('click', () => setMenu(mnav.hidden));
$$('a[href^="#"]').forEach((a) => a.addEventListener('click', () => { if (mnav && !mnav.hidden) setMenu(false); }));

function onScroll() {
  if (!root) return;
  const ids = [['inicio', 'inicio'], ['sigma-ai', 'ai'], ['sigma-twin', 'twin'], ['componentes', 'componentes'], ['planes', 'planes'], ['nosotros', 'nosotros']];
  let cur = 'inicio';
  ids.forEach((p) => { const el = byId(p[0]); if (el && el.getBoundingClientRect().top <= 160) cur = p[1]; });
  let light = false;
  const secs = $$('[data-nav]', root);
  for (let j = 0; j < secs.length; j++) {
    const r = secs[j].getBoundingClientRect();
    if (r.top <= 44 && r.bottom > 44) { light = secs[j].getAttribute('data-nav') === 'light'; break; }
  }
  const max = document.documentElement.scrollHeight - window.innerHeight;
  const bar = byId('sg-progress');
  if (bar) bar.style.transform = 'scaleX(' + (max > 0 ? Math.min(1, window.scrollY / max) : 0) + ')';
  if (cur !== activeNav || light !== navLight) {
    activeNav = cur; navLight = light;
    if (navEl) navEl.classList.toggle('is-light', light);
    const keys = ['inicio', 'ai', 'twin', 'componentes', 'planes', 'nosotros'];
    $$('.sg-nav-links a', navEl).forEach((a, i) => {
      const on = keys[i] === cur;
      a.classList.toggle('is-active', on);
      a.setAttribute('aria-current', on ? 'location' : 'false');
    });
  }
}

/* =============== three.js: utilidades =============== */
function makeGL(id, fov, maxPR) {
  const c = byId(id);
  if (!THREE || !c) return null;
  const r = new THREE.WebGLRenderer({ canvas: c, antialias: true, alpha: true, powerPreference: 'high-performance' });
  const W = Math.max(1, c.clientWidth), H = Math.max(1, c.clientHeight);
  r.setPixelRatio(Math.min(window.devicePixelRatio || 1, maxPR || 2));
  r.setSize(W, H, false);
  const g = { T: THREE, r, c, scene: new THREE.Scene(), cam: new THREE.PerspectiveCamera(fov || 42, W / H, 0.1, 200), visible: true, raf: 0, small: W < 700 };
  if (window.ResizeObserver) {
    g.ro = new ResizeObserver(() => {
      const w = c.clientWidth, h = c.clientHeight; if (!w || !h) return;
      r.setSize(w, h, false); g.cam.aspect = w / h; g.cam.updateProjectionMatrix();
      if (reduced) { if (g.tick) g.tick(0); r.render(g.scene, g.cam); }
    });
    g.ro.observe(c);
  }
  if (window.IntersectionObserver) { g.io = new IntersectionObserver((en) => { g.visible = en[0].isIntersecting; }); g.io.observe(c); }
  const t0 = performance.now();
  g.start = () => {
    if (reduced) { if (g.tick) g.tick(0); r.render(g.scene, g.cam); return; }
    (function frame() {
      g.raf = requestAnimationFrame(frame);
      if (!g.visible) return;
      if (g.tick) g.tick((performance.now() - t0) / 1000);
      r.render(g.scene, g.cam);
    })();
  };
  gls.push(g);
  if (!onMove) {
    mouse = { x: 0, y: 0, tx: 0, ty: 0 };
    onMove = (e) => { mouse.tx = (e.clientX / window.innerWidth - 0.5) * 2; mouse.ty = (e.clientY / window.innerHeight - 0.5) * 2; };
    window.addEventListener('pointermove', onMove, { passive: true });
  }
  return g;
}
function lerpMouse() { const m = mouse; m.x += (m.tx - m.x) * 0.045; m.y += (m.ty - m.y) * 0.045; return m; }

/* =============== HERO: del caos al control =============== */
function initHero(delay) {
  const g = makeGL('sg-gl', 42); if (!g) return;
  const T = g.T, small = g.small;
  g.cam.position.set(0, 0, 11);
  const N = small ? 4200 : 9500, TAU = Math.PI * 2, R = 3.3, TEETH = 20;
  const pos = new Float32Array(N * 3), tgt = new Float32Array(N * 3), flo = new Float32Array(N * 3), rnd = new Float32Array(N);
  function ss(a, b, x) { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); }
  function tooth(a) { const t = ((a * TEETH / TAU) % 1 + 1) % 1; return ss(0.1, 0.2, t) * (1 - ss(0.55, 0.65, t)); }
  const cols = 150, rowsN = Math.ceil(N / cols);
  for (let i = 0; i < N; i++) {
    rnd[i] = Math.random();
    pos[i * 3] = (Math.random() - 0.5) * 26; pos[i * 3 + 1] = (Math.random() - 0.5) * 15; pos[i * 3 + 2] = (Math.random() - 0.5) * 10 - 2;
    const k = Math.random(); let a = Math.random() * TAU, r, z = (Math.random() - 0.5) * 0.7;
    if (k < 0.58) r = R + tooth(a) * 0.55 + (Math.random() - 0.5) * 0.16;
    else if (k < 0.72) r = R - 0.45 + (Math.random() - 0.5) * 0.12;
    else if (k < 0.86) { r = 1.05 + (Math.random() - 0.5) * 0.25; z *= 1.6; }
    else { const sp = Math.floor(Math.random() * 6); a = sp / 6 * TAU + (Math.random() - 0.5) * 0.09; r = 1.2 + Math.random() * (R - 1.7); }
    tgt[i * 3] = Math.cos(a) * r; tgt[i * 3 + 1] = Math.sin(a) * r; tgt[i * 3 + 2] = z;
    const gx = i % cols, gz = Math.floor(i / cols);
    flo[i * 3] = (gx / (cols - 1) - 0.5) * 30; flo[i * 3 + 1] = -3.4; flo[i * 3 + 2] = 5 - gz / rowsN * 24;
  }
  const geo = new T.BufferGeometry();
  geo.setAttribute('position', new T.BufferAttribute(pos, 3));
  geo.setAttribute('aTarget', new T.BufferAttribute(tgt, 3));
  geo.setAttribute('aFloor', new T.BufferAttribute(flo, 3));
  geo.setAttribute('aRnd', new T.BufferAttribute(rnd, 1));
  const off = small ? new T.Vector3(0, 1.6, -3) : new T.Vector3(3.1, 0.35, 0);
  const u = { uTime: { value: 0 }, uMorph: { value: reduced ? 1 : 0 }, uFloor: { value: 0 }, uSize: { value: small ? 30 : 34 }, uPR: { value: g.r.getPixelRatio() }, uMouse: { value: new T.Vector2() }, uOff: { value: off } };
  const mat = new T.ShaderMaterial({
    uniforms: u, transparent: true, depthWrite: false, blending: T.AdditiveBlending,
    vertexShader: [
      'uniform float uTime,uMorph,uFloor,uSize,uPR; uniform vec2 uMouse; uniform vec3 uOff;',
      'attribute vec3 aTarget; attribute vec3 aFloor; attribute float aRnd;',
      'varying float vA; varying vec3 vC;',
      'mat3 rx(float a){float c=cos(a),s=sin(a);return mat3(1.,0.,0.,0.,c,s,0.,-s,c);}',
      'mat3 ry(float a){float c=cos(a),s=sin(a);return mat3(c,0.,-s,0.,1.,0.,s,0.,c);}',
      'mat3 rz(float a){float c=cos(a),s=sin(a);return mat3(c,s,0.,-s,c,0.,0.,0.,1.);}',
      'void main(){',
      '  float m = smoothstep(0.,1.,clamp(uMorph*1.5-aRnd*.5,0.,1.));',
      '  vec3 chaos = position + vec3(sin(uTime*.3+aRnd*40.)*.35, cos(uTime*.25+aRnd*30.)*.35, 0.);',
      '  vec3 g0 = rz(uTime*.12)*aTarget;',
      '  vec3 g = ry(.55+uMouse.x*.25)*rx(-.42+uMouse.y*.15)*g0 + uOff;',
      '  vec3 p = mix(chaos, g, m);',
      '  vec3 f = aFloor; f.y += sin(f.x*.45+uTime*.8)*.18 + cos(f.z*.5+uTime*.6)*.18;',
      '  float fl = smoothstep(0.,1.,clamp(uFloor*1.4-aRnd*.4,0.,1.));',
      '  p = mix(p, f, fl);',
      '  vec4 mv = modelViewMatrix*vec4(p,1.);',
      '  gl_Position = projectionMatrix*mv;',
      '  gl_PointSize = uSize*uPR*(.55+aRnd*.9)/-mv.z;',
      '  float t = clamp(g0.x/8.+.5,0.,1.);',
      '  vec3 col = mix(vec3(.45,.25,.98), vec3(.09,.78,.79), t);',
      '  col = mix(col, vec3(.03,.48,.92), fl*.6);',
      '  vC = mix(vec3(.5,.55,.7), col, max(m,fl));',
      '  vA = mix(.28,.9,max(m,fl*.8)) * (aRnd>.985?1.8:1.);',
      '}'
    ].join('\n'),
    fragmentShader: 'varying float vA; varying vec3 vC; void main(){ float d = length(gl_PointCoord-.5); float a = smoothstep(.5,0.,d); gl_FragColor = vec4(vC, a*a*vA); }'
  });
  g.scene.add(new T.Points(geo, mat));

  const rings = [];
  [[R + 1.25, 0x9A72FF, 0.9, 0.2], [R + 1.75, 0x16C6C9, -0.6, -0.35], [R + 2.4, 0x087BEA, 0.35, 0.55]].forEach((d) => {
    const m = new T.Mesh(new T.TorusGeometry(d[0], 0.012, 6, 220), new T.MeshBasicMaterial({ color: d[1], transparent: true, opacity: 0, blending: T.AdditiveBlending, depthWrite: false }));
    m.position.copy(off); m.rotation.set(1.1 + d[3], 0.5, 0); m.userData = { spd: d[2] };
    g.scene.add(m); rings.push(m);
  });
  g.u = u; g.camZ = 11;
  g.tick = (t) => {
    u.uTime.value = t;
    if (!gs && u.uMorph.value < 1) u.uMorph.value = Math.min(1, u.uMorph.value + 0.006);
    const m = lerpMouse(); u.uMouse.value.set(m.x, m.y);
    rings.forEach((rg, i) => { rg.rotation.z = t * 0.1 * rg.userData.spd; rg.rotation.x = 1.1 + Math.sin(t * 0.3 + i) * 0.08 + m.y * 0.1; rg.material.opacity = Math.max(0, u.uMorph.value - 0.55) * 0.9 * (1 - u.uFloor.value); });
    g.cam.position.x = m.x * 0.5; g.cam.position.y = -m.y * 0.3; g.cam.position.z = g.camZ; g.cam.lookAt(0, 0, 0);
  };
  heroGL = g;
  g.start();
  if (gs && !reduced) gs.to(u.uMorph, { value: 1, duration: 3.4, ease: 'expo.inOut', delay: delay });
}

/* =============== CINE: pantalla curva que se arma con el spot =============== */
const SPOTS = {
  ai: { src: 'Video/landing/sigma-ai-spot.mp4', poster: 'Imagen/landing/poster-ai.jpg', title: 'SIGMA AI', label: 'Spot de SIGMA AI: anticípate a la falla. 30 segundos, con voz.' },
  twin: { src: 'Video/landing/sigma-twin-spot.mp4', poster: 'Imagen/landing/poster-twin.jpg', title: 'SIGMA Twin', label: 'Spot de SIGMA Twin: tu bodega, en 3D. 30 segundos, con voz.' }
};
const video = byId('sg-cine-video');
const cineSec = byId('spots');

function initCine() {
  const g = makeGL('sg-cine-gl', 38); if (!g || !video) return;
  const T = g.T;
  g.cam.position.set(0, 0, 14.5);
  const vtex = new T.VideoTexture(video); vtex.colorSpace = T.SRGBColorSpace;
  const loader = new T.TextureLoader();
  const posters = {
    ai: loader.load(SPOTS.ai.poster, () => { if (!g.live) g.mat.needsUpdate = true; }),
    twin: loader.load(SPOTS.twin.poster)
  };
  posters.ai.colorSpace = T.SRGBColorSpace; posters.twin.colorSpace = T.SRGBColorSpace;
  g.mat = new T.MeshBasicMaterial({ map: posters.ai, side: T.DoubleSide, toneMapped: false });
  video.addEventListener('playing', () => { g.live = true; g.mat.map = vtex; g.mat.needsUpdate = true; });
  g.posters = posters; g.vtex = vtex;

  const cols = g.small ? 10 : 16, rows = g.small ? 6 : 9, Rr = 9, theta = 1.12;
  const chord = 2 * Rr * Math.sin(theta / 2), Hh = chord * 9 / 16, tw = (Rr * theta) / cols, th = Hh / rows;
  const tiles = [];
  for (let i = 0; i < cols; i++) for (let j = 0; j < rows; j++) {
    const geo = new T.PlaneGeometry(tw * 1.004, th * 1.004);
    const uv = geo.attributes.uv;
    for (let q = 0; q < uv.count; q++) uv.setXY(q, (i + uv.getX(q)) / cols, (j + uv.getY(q)) / rows);
    const mesh = new T.Mesh(geo, g.mat);
    const a = -theta / 2 + (i + 0.5) / cols * theta;
    const tgt = { x: Rr * Math.sin(a), y: (j + 0.5) * th - Hh / 2, z: Rr * (1 - Math.cos(a)), ry: -a };
    const dx = (i + 0.5) / cols - 0.5, dy = (j + 0.5) / rows - 0.5;
    const d = Math.min(1, Math.sqrt(dx * dx + dy * dy) * 1.5 + Math.random() * 0.15);
    const sc = { x: (Math.random() - 0.5) * 34, y: (Math.random() - 0.5) * 20, z: (Math.random() - 0.5) * 18 - 4, rx: (Math.random() - 0.5) * 6, ry: (Math.random() - 0.5) * 6, rz: (Math.random() - 0.5) * 6 };
    mesh.userData = { t: tgt, s: sc, d: d };
    g.scene.add(mesh); tiles.push(mesh);
  }
  const edgeMat = new T.LineBasicMaterial({ color: 0x16C6C9, transparent: true, opacity: 0, blending: T.AdditiveBlending });
  [-1, 1].forEach((s) => {
    const pts = [];
    for (let k = 0; k <= 60; k++) { const aa = -theta / 2 + k / 60 * theta; pts.push(new T.Vector3(Rr * Math.sin(aa), s * (Hh / 2 + 0.08), Rr * (1 - Math.cos(aa)))); }
    g.scene.add(new T.Line(new T.BufferGeometry().setFromPoints(pts), edgeMat));
  });
  const dn = 600, dp = new Float32Array(dn * 3);
  for (let n = 0; n < dn; n++) { dp[n * 3] = (Math.random() - 0.5) * 24; dp[n * 3 + 1] = (Math.random() - 0.5) * 12; dp[n * 3 + 2] = Math.random() * 10; }
  const dg = new T.BufferGeometry(); dg.setAttribute('position', new T.BufferAttribute(dp, 3));
  const dust = new T.Points(dg, new T.PointsMaterial({ color: 0x9A72FF, size: 0.04, transparent: true, opacity: 0.5, blending: T.AdditiveBlending, depthWrite: false }));
  g.scene.add(dust);

  g.p = (gs && !reduced) ? 0 : 1; g.push = 0; g.built = !(gs && !reduced);
  const ease = (x) => 1 - Math.pow(1 - x, 3);
  g.tick = (t) => {
    const m = lerpMouse();
    for (let k = 0; k < tiles.length; k++) {
      const o = tiles[k].userData, e = ease(Math.max(0, Math.min(1, g.p * 1.7 - o.d * 0.7))), f = 1 - e;
      tiles[k].position.set(o.s.x * f + o.t.x * e, o.s.y * f + o.t.y * e, o.s.z * f + o.t.z * e);
      tiles[k].rotation.set(o.s.rx * f, o.s.ry * f + o.t.ry * e, o.s.rz * f);
    }
    edgeMat.opacity = Math.max(0, (g.p - 0.85) / 0.15) * 0.8;
    dust.rotation.y = t * 0.02;
    g.cam.position.x = m.x * 0.9; g.cam.position.y = -m.y * 0.45; g.cam.position.z = 14.5 - g.push * 2.4;
    g.cam.lookAt(0, 0, 2.2);
  };
  cineGL = g;
  g.start();
  if (cineSec) cineSec.classList.add('is-gl');
}
function assembleCine() {
  const g = cineGL; if (!g || g.built) return;
  g.built = true;
  if (gs) gs.to(g, { p: 1, duration: 2.6, ease: 'power3.out' }); else g.p = 1;
}
function playVideo() { if (!video) return; const p = video.play(); if (p && p.catch) p.catch(() => {}); }

function switchSpot(k) {
  if (k === spot) return;
  const g = cineGL;
  const apply = () => {
    spot = k; userPaused = false;
    const sp = SPOTS[k];
    $$('.sg-cine-tabs button').forEach((b) => { const on = b.getAttribute('data-spot') === k; b.classList.toggle('is-on', on); b.setAttribute('aria-pressed', on ? 'true' : 'false'); });
    byId('sg-cine-title').textContent = sp.title;
    syncPlayUI();
    if (g) { g.live = false; g.mat.map = g.posters[k]; g.mat.needsUpdate = true; }
    if (video) {
      video.setAttribute('poster', sp.poster); video.setAttribute('aria-label', sp.label);
      video.src = sp.src; video.muted = soundMuted;
      try { video.load(); } catch (e) { /* sin load */ }
      playVideo();
    }
    if (g && gs && !reduced) gs.to(g, { p: 1, duration: 1.9, ease: 'power3.out' }); else if (g) g.p = 1;
  };
  if (g && gs && !reduced && g.built) gs.to(g, { p: 0, duration: 0.75, ease: 'power2.in', onComplete: apply }); else apply();
}
function syncPlayUI() {
  const b = byId('sg-cine-play');
  byId('sg-ico-pause').hidden = userPaused; byId('sg-ico-play').hidden = !userPaused;
  b.setAttribute('aria-label', userPaused ? 'Reproducir el spot' : 'Pausar el spot');
}
function syncSoundUI() {
  const b = byId('sg-cine-snd');
  byId('sg-ico-muted').hidden = !soundMuted; byId('sg-ico-sound').hidden = soundMuted;
  b.setAttribute('aria-pressed', soundMuted ? 'false' : 'true');
  b.setAttribute('aria-label', soundMuted ? 'Activar sonido del spot' : 'Silenciar el spot');
  byId('sg-cine-hint').textContent = soundMuted ? 'Activa el sonido para escuchar la voz' : 'Sonido activado';
}
function bindCine() {
  $$('.sg-cine-tabs button').forEach((b) => b.addEventListener('click', () => switchSpot(b.getAttribute('data-spot'))));
  byId('sg-cine-play').addEventListener('click', () => {
    userPaused = !userPaused;
    if (video) { if (userPaused) video.pause(); else playVideo(); }
    syncPlayUI();
  });
  byId('sg-cine-snd').addEventListener('click', () => {
    soundMuted = !soundMuted; userPaused = false;
    if (video) { video.muted = soundMuted; if (!soundMuted) playVideo(); }
    syncSoundUI(); syncPlayUI();
  });
  if (!video) return;
  video.muted = true;
  video.addEventListener('timeupdate', () => { const b = byId('sg-cine-prog'); if (b && video.duration) b.style.transform = 'scaleX(' + (video.currentTime / video.duration) + ')'; });
  const stage = byId('sg-cine-stage');
  if (window.IntersectionObserver && stage) {
    new IntersectionObserver((en) => {
      const vis = en[0].isIntersecting;
      if (vis && !userPaused) playVideo();
      if (!vis) video.pause();
      if (vis && cineGL && !cineGL.built) assembleCine();
    }, { threshold: 0.25 }).observe(stage);
  }
}

/* =============== SIGMA AI: la planta como red neuronal =============== */
function initBrain() {
  const g = makeGL('sg-ai-gl', 40, 1.75); if (!g) return;
  const T = g.T;
  g.cam.position.set(0, 0, 9);
  const grp = new T.Group(); grp.position.set(g.small ? 0 : -1.6, g.small ? 0 : 0.6, 0); g.scene.add(grp);
  const N = g.small ? 900 : 1800, R = 2.5, pos = new Float32Array(N * 3), rnd = new Float32Array(N);
  const golden = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < N; i++) {
    const y = 1 - (i / (N - 1)) * 2, rad = Math.sqrt(1 - y * y), th = golden * i, jit = 1 + (Math.random() - 0.5) * 0.06;
    pos[i * 3] = Math.cos(th) * rad * R * jit; pos[i * 3 + 1] = y * R * jit; pos[i * 3 + 2] = Math.sin(th) * rad * R * jit; rnd[i] = Math.random();
  }
  const geo = new T.BufferGeometry(); geo.setAttribute('position', new T.BufferAttribute(pos, 3)); geo.setAttribute('aRnd', new T.BufferAttribute(rnd, 1));
  const u = { uTime: { value: 0 }, uPR: { value: g.r.getPixelRatio() } };
  grp.add(new T.Points(geo, new T.ShaderMaterial({
    uniforms: u, transparent: true, depthWrite: false, blending: T.AdditiveBlending,
    vertexShader: 'uniform float uTime,uPR; attribute float aRnd; varying float vA; varying float vR; void main(){ vec4 mv = modelViewMatrix*vec4(position,1.); gl_Position = projectionMatrix*mv; float tw = .55+.45*sin(uTime*1.6+aRnd*30.); gl_PointSize = (14.+aRnd*12.)*uPR/-mv.z; vA = tw*smoothstep(-9.5,-6.,mv.z); vR = aRnd; }',
    fragmentShader: 'varying float vA; varying float vR; void main(){ float d=length(gl_PointCoord-.5); float a=smoothstep(.5,0.,d); vec3 c = mix(vec3(.6,.42,1.), vec3(.09,.78,.79), step(.72,vR)); gl_FragColor=vec4(c, a*a*vA*.9); }'
  })));
  const nodes = [], NN = 7;
  for (let n = 0; n < NN; n++) { const phi = Math.acos(1 - 2 * (n + 0.5) / NN), lam = n * 2.4; nodes.push(new T.Vector3(Math.sin(phi) * Math.cos(lam) * R, Math.cos(phi) * R, Math.sin(phi) * Math.sin(lam) * R)); }
  const arcU = { uTime: { value: 0 } };
  const arcMat = new T.ShaderMaterial({ uniforms: arcU, transparent: true, depthWrite: false, blending: T.AdditiveBlending,
    vertexShader: 'attribute float aT; varying float vT; void main(){ vT=aT; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }',
    fragmentShader: 'uniform float uTime; varying float vT; void main(){ float k = fract(vT*2. - uTime*.35); float a = smoothstep(.0,.08,k)*smoothstep(.35,.08,k); gl_FragColor = vec4(mix(vec3(.6,.42,1.),vec3(.09,.85,.85),vT), .12 + a*.9); }' });
  for (let a = 0; a < NN; a++) for (let b = a + 1; b < NN; b++) {
    if ((a + b) % 2) continue;
    const mid = nodes[a].clone().add(nodes[b]).multiplyScalar(0.5).normalize().multiplyScalar(R * 1.45);
    const curve = new T.QuadraticBezierCurve3(nodes[a], mid, nodes[b]), pts = curve.getPoints(60), tt = new Float32Array(61);
    for (let q = 0; q <= 60; q++) tt[q] = q / 60;
    const lg = new T.BufferGeometry().setFromPoints(pts); lg.setAttribute('aT', new T.BufferAttribute(tt, 1));
    grp.add(new T.Line(lg, arcMat));
  }
  nodes.forEach((p, idx) => {
    const hot = idx === 3;
    const s = new T.Mesh(new T.SphereGeometry(hot ? 0.11 : 0.07, 16, 16), new T.MeshBasicMaterial({ color: hot ? 0xFF4D7A : 0xB08CFF }));
    s.position.copy(p); grp.add(s);
    if (hot) {
      const halo = new T.Mesh(new T.RingGeometry(0.16, 0.2, 48), new T.MeshBasicMaterial({ color: 0xFF4D7A, transparent: true, side: T.DoubleSide, blending: T.AdditiveBlending, depthWrite: false }));
      halo.position.copy(p); halo.lookAt(p.clone().multiplyScalar(2)); grp.add(halo); g.halo = halo;
    }
  });
  g.tick = (t) => {
    u.uTime.value = t; arcU.uTime.value = t;
    const m = lerpMouse();
    grp.rotation.y = t * 0.12 + m.x * 0.4; grp.rotation.x = -0.15 + m.y * 0.2;
    if (g.halo) { const k = (t * 0.8) % 1; g.halo.scale.setScalar(1 + k * 3); g.halo.material.opacity = (1 - k) * 0.9; }
  };
  g.start();
}

/* =============== SIGMA TWIN: bodega 3D procedural =============== */
function initTwin() {
  const g = makeGL('sg-twin-gl', 45, 1.75); if (!g) return;
  const T = g.T, sc = g.scene;
  sc.fog = new T.Fog(0x070A14, 16, 40);
  sc.add(new T.HemisphereLight(0xbcd2ff, 0x0b0f1c, 1.1));
  const dl = new T.DirectionalLight(0xffffff, 1.4); dl.position.set(8, 14, 6); sc.add(dl);
  const floor = new T.Mesh(new T.PlaneGeometry(40, 40), new T.MeshStandardMaterial({ color: 0x141a2e, roughness: 0.9 }));
  floor.rotation.x = -Math.PI / 2; sc.add(floor);
  const grid = new T.GridHelper(40, 40, 0x2a3a66, 0x1a2342); grid.position.y = 0.005; sc.add(grid);
  const laneMat = new T.MeshBasicMaterial({ color: 0xE8B12E });
  [-3, 0, 3].forEach((x) => { [-1, 1].forEach((s) => { const ln = new T.Mesh(new T.PlaneGeometry(0.06, 14), laneMat); ln.rotation.x = -Math.PI / 2; ln.position.set(x + s * 0.7, 0.01, 0); sc.add(ln); }); });

  const rowsX = [-4.5, -1.5, 1.5, 4.5], racksZ = 5, rackL = 2.2, levels = [0.15, 0.95, 1.75, 2.55], dep = 0.9;
  const nUp = rowsX.length * racksZ * 4, nBeam = rowsX.length * racksZ * levels.length, nBox = rowsX.length * racksZ * levels.length * 3;
  const up = new T.InstancedMesh(new T.BoxGeometry(0.07, 2.8, 0.07), new T.MeshStandardMaterial({ color: 0x2257D6, roughness: 0.5, metalness: 0.3 }), nUp);
  const beam = new T.InstancedMesh(new T.BoxGeometry(rackL, 0.06, dep), new T.MeshStandardMaterial({ color: 0xE8812E, roughness: 0.6 }), nBeam);
  const box = new T.InstancedMesh(new T.BoxGeometry(0.6, 0.5, 0.72), new T.MeshStandardMaterial({ color: 0xffffff, roughness: 0.45 }), nBox);
  const M = new T.Matrix4(), col = new T.Color(), slots = [];
  let iu = 0, ib = 0, ix = 0;
  rowsX.forEach((x) => {
    for (let r = 0; r < racksZ; r++) {
      const z = -5 + r * (rackL + 0.25);
      [[-rackL / 2, -dep / 2], [rackL / 2, -dep / 2], [-rackL / 2, dep / 2], [rackL / 2, dep / 2]].forEach((c) => { M.makeTranslation(x + c[1], 1.4, z + c[0]); up.setMatrixAt(iu++, M); });
      levels.forEach((y) => {
        M.makeRotationY(Math.PI / 2); M.setPosition(x, y, z); beam.setMatrixAt(ib++, M);
        for (let b = 0; b < 3; b++) {
          const present = Math.random() > 0.18;
          const bz = z - 0.7 + b * 0.7;
          M.makeTranslation(x, present ? y + 0.29 : -50, bz); box.setMatrixAt(ix, M);
          const low = Math.random() < 0.09;
          col.set(low ? 0xFF6B4A : (Math.random() < 0.5 ? 0x6FA8F0 : 0x8EC0F6)); box.setColorAt(ix, col);
          if (present) slots.push({ x: x, y: y + 0.29, z: bz });
          ix++;
        }
      });
    }
  });
  up.instanceMatrix.needsUpdate = true; beam.instanceMatrix.needsUpdate = true; box.instanceMatrix.needsUpdate = true; if (box.instanceColor) box.instanceColor.needsUpdate = true;
  sc.add(up); sc.add(beam); sc.add(box);
  const target = slots[Math.floor(slots.length * 0.42)] || { x: 1.5, y: 1.04, z: 0 };
  const hb = new T.Mesh(new T.BoxGeometry(0.62, 0.52, 0.74), new T.MeshStandardMaterial({ color: 0x16C6C9, emissive: 0x16C6C9, emissiveIntensity: 0.8, roughness: 0.3 }));
  hb.position.set(target.x, target.y, target.z); sc.add(hb);
  const beacon = new T.Mesh(new T.CylinderGeometry(0.02, 0.02, 6, 8), new T.MeshBasicMaterial({ color: 0x16C6C9, transparent: true, opacity: 0.5, blending: T.AdditiveBlending }));
  beacon.position.set(target.x, target.y + 3, target.z); sc.add(beacon);
  const pulse = new T.Mesh(new T.RingGeometry(0.35, 0.42, 48), new T.MeshBasicMaterial({ color: 0x16C6C9, transparent: true, side: T.DoubleSide, blending: T.AdditiveBlending, depthWrite: false }));
  pulse.rotation.x = -Math.PI / 2; pulse.position.set(target.x + (target.x > 0 ? -1.4 : 1.4), 0.02, target.z); sc.add(pulse);

  const A = new T.Vector3(13, 11, 15), B = new T.Vector3(0, 1.7, 9.5), LA = new T.Vector3(0, 0, 0), LB = new T.Vector3(0, 1.5, -8);
  g.q = null;
  g.tick = (t) => {
    const m = lerpMouse();
    const q = g.q === null ? 0.5 - 0.5 * Math.cos(t * 0.16) : g.q;
    const e = q * q * (3 - 2 * q);
    const orbit = (1 - e) * (t * 0.05);
    const cam = A.clone().lerp(B, e);
    if (e < 0.99) { const ang = Math.atan2(cam.z, cam.x) + orbit * 0.6; const rr = Math.sqrt(cam.x * cam.x + cam.z * cam.z); cam.x = Math.cos(ang) * rr; cam.z = Math.sin(ang) * rr; }
    g.cam.position.set(cam.x + m.x * 0.8, cam.y - m.y * 0.4, cam.z);
    g.cam.lookAt(LA.clone().lerp(LB, e));
    const k = (Math.sin(t * 1.4) + 1) / 2;
    hb.position.x = target.x + (target.x > 0 ? -1 : 1) * k * 0.6; hb.position.y = target.y + k * 0.08; hb.rotation.y = k * 0.25;
    hb.material.emissiveIntensity = 0.5 + k * 0.8;
    const pk = (t * 0.7) % 1; pulse.scale.setScalar(1 + pk * 2.5); pulse.material.opacity = (1 - pk) * 0.9;
  };
  twinGL = g;
  g.start();
}

/* =============== GSAP: marquesina, magnéticos, tarjetas =============== */
function initAmbient() {
  const m1 = byId('sg-mq1'), m2 = byId('sg-mq2');
  if (m1 && m2) {
    mq1 = gs.to(m1, { xPercent: -50, repeat: -1, duration: 46, ease: 'none' });
    mq2 = gs.fromTo(m2, { xPercent: -50 }, { xPercent: 0, repeat: -1, duration: 52, ease: 'none' });
  }
  if (!fine) return;
  $$('#sg-root .sg-magnet').forEach((el) => {
    el.addEventListener('mousemove', (e) => { const r = el.getBoundingClientRect(); gs.to(el, { x: (e.clientX - r.left - r.width / 2) * 0.25, y: (e.clientY - r.top - r.height / 2) * 0.35, duration: 0.4, ease: 'power3.out' }); });
    el.addEventListener('mouseleave', () => { gs.to(el, { x: 0, y: 0, duration: 0.9, ease: 'elastic.out(1, .4)' }); });
  });
  $$('#sg-root .sg-plan, #sg-root .sg-prod-shot').forEach((el) => {
    const plan = el.classList.contains('sg-plan');
    el.addEventListener('mousemove', (e) => {
      const r = el.getBoundingClientRect(), x = (e.clientX - r.left) / r.width, y = (e.clientY - r.top) / r.height;
      if (plan) { el.style.setProperty('--mx', (x * 100) + '%'); el.style.setProperty('--my', (y * 100) + '%'); }
      gs.to(el, { rotationY: (x - 0.5) * (plan ? 7 : 10), rotationX: (0.5 - y) * (plan ? 6 : 8), transformPerspective: 1100, duration: 0.5, ease: 'power3.out' });
    });
    el.addEventListener('mouseleave', () => { gs.to(el, { rotationY: 0, rotationX: 0, duration: 0.8, ease: 'power3.out' }); });
  });
}

/* =============== GSAP + ScrollTrigger: la película al hacer scroll =============== */
function setStoryIdx(idx) {
  if (idx === storyIdx) return;
  storyIdx = idx;
  const lbl = byId('sg-rail-label');
  if (lbl) lbl.textContent = ['01 — Planifica', '02 — Ejecuta', '03 — Vuelve con datos'][idx];
}
function initScroll(wide) {
  ctx = gs.context(() => {
    ST.create({ trigger: '#inicio', start: 'top top', end: 'bottom top', scrub: true, onUpdate: (s) => {
      if (heroGL) { heroGL.u.uFloor.value = s.progress; heroGL.camZ = 11 - s.progress * 2.5; }
    } });
    gs.to('#sg-root .sg-hero-in', { yPercent: -18, opacity: 0.1, scale: 0.96, filter: 'blur(6px)', ease: 'none', scrollTrigger: { trigger: '#inicio', start: 'top top', end: 'bottom top', scrub: true } });

    gs.fromTo('#sg-manif .sg-mw', { opacity: 0.14 }, { opacity: 1, stagger: 0.06, ease: 'none', scrollTrigger: { trigger: '#sg-manif', start: 'top 78%', end: 'bottom 42%', scrub: true } });

    if (wide) {
      const chaps = gs.utils.toArray('#sg-story .sg-chap');
      gs.set(chaps.slice(1), { autoAlpha: 0 });
      const tl = gs.timeline({ scrollTrigger: { trigger: '#sg-story .sg-story-track', start: 'top top', end: 'bottom bottom', scrub: 0.8,
        onUpdate: (s) => setStoryIdx(Math.min(2, Math.floor(s.progress * 3))) } });
      tl.to('#sg-rail-fill', { scaleX: 1, ease: 'none', duration: 3 }, 0);
      tl.from(chaps[0].querySelector('.sg-browser'), { rotateX: 24, rotateY: -16, scale: 0.8, y: 70, ease: 'power2.out', duration: 0.7 }, 0);
      tl.from(chaps[0].querySelector('.sg-shot-card'), { x: 120, y: 60, rotate: 6, opacity: 0, duration: 0.45 }, 0.3);
      tl.to(chaps[0], { autoAlpha: 0, y: -70, filter: 'blur(8px)', duration: 0.35 }, 0.9);
      tl.fromTo(chaps[1], { autoAlpha: 0, y: 80 }, { autoAlpha: 1, y: 0, duration: 0.4 }, 1.05);
      tl.from(chaps[1].querySelector('.sg-phone'), { rotateY: 28, rotateZ: -6, y: 120, ease: 'power2.out', duration: 0.6 }, 1.05);
      tl.from(chaps[1].querySelectorAll('.sg-float'), { scale: 0.6, opacity: 0, stagger: 0.15, duration: 0.3 }, 1.35);
      tl.to(chaps[1], { autoAlpha: 0, y: -70, filter: 'blur(8px)', duration: 0.35 }, 1.9);
      tl.fromTo(chaps[2], { autoAlpha: 0, y: 80 }, { autoAlpha: 1, y: 0, duration: 0.4 }, 2.05);
      tl.from(chaps[2].querySelector('.sg-browser'), { rotateX: -18, rotateY: 14, scale: 0.84, ease: 'power2.out', duration: 0.6 }, 2.05);
      tl.from(chaps[2].querySelector('.sg-shot-card'), { x: -120, y: 60, rotate: -6, opacity: 0, duration: 0.45 }, 2.35);
    } else {
      gs.utils.toArray('#sg-story .sg-chap').forEach((c) => {
        gs.from(c, { y: 70, opacity: 0, duration: 1.1, ease: 'expo.out', scrollTrigger: { trigger: c, start: 'top 85%', once: true } });
      });
    }

    ST.create({ trigger: '#spots', start: 'top 70%', once: true, onEnter: () => assembleCine() });
    ST.create({ trigger: '#sg-cine-stage', start: 'top bottom', end: 'bottom top', scrub: true, onUpdate: (s) => { if (cineGL) cineGL.push = Math.sin(s.progress * Math.PI); } });

    ['#sigma-ai', '#sigma-twin'].forEach((id) => {
      gs.to(id + ' .sg-par', { yPercent: -10, ease: 'none', scrollTrigger: { trigger: id, start: 'top bottom', end: 'bottom top', scrub: true } });
      gs.to(id + ' .sg-par2', { yPercent: -28, ease: 'none', scrollTrigger: { trigger: id, start: 'top bottom', end: 'bottom top', scrub: true } });
      if ($(id + ' .sg-par3')) gs.to(id + ' .sg-par3', { yPercent: -40, ease: 'none', scrollTrigger: { trigger: id, start: 'top bottom', end: 'bottom top', scrub: true } });
      gs.from(id + ' .sg-prod-logo', { opacity: 0, y: 30, filter: 'blur(10px)', duration: 1.2, ease: 'expo.out', scrollTrigger: { trigger: id, start: 'top 70%', once: true } });
    });
    ST.create({ trigger: '#sigma-twin', start: 'top bottom', end: 'bottom top', scrub: true, onUpdate: (s) => { if (twinGL) twinGL.q = Math.max(0, Math.min(1, (s.progress - 0.15) / 0.6)); } });

    gs.fromTo('#componentes', { clipPath: 'inset(7% 5% 0% 5% round 48px)' }, { clipPath: 'inset(0% 0% 0% 0% round 0px)', ease: 'none', scrollTrigger: { trigger: '#componentes', start: 'top bottom', end: 'top 25%', scrub: true } });

    ST.create({ trigger: root, start: 'top top', end: 'bottom bottom', onUpdate: (s) => {
      const v = Math.min(4, 1 + Math.abs(s.getVelocity()) / 600);
      if (mq1) gs.to([mq1, mq2], { timeScale: v, duration: 0.2, overwrite: true, onComplete: () => { gs.to([mq1, mq2], { timeScale: 1, duration: 1.2 }); } });
    } });

    gs.utils.toArray('#sg-root .sg-rv').forEach((el) => {
      gs.from(el, { y: 56, opacity: 0, duration: 1.2, ease: 'expo.out', scrollTrigger: { trigger: el, start: 'top 88%', once: true } });
    });
    gs.from('#sg-root .sg-final h2', { yPercent: 40, scale: 0.86, opacity: 0, ease: 'none', scrollTrigger: { trigger: '#sg-root .sg-final', start: 'top 85%', end: 'top 30%', scrub: true } });
  }, root);
  ST.refresh();
}

/* =============== intro de película =============== */
function heroIn(tl, at) {
  tl.from('#sg-root .sg-nav-in', { y: -30, opacity: 0, duration: 1.2, ease: 'expo.out' }, at)
    .from('#sg-root .sg-h1 .sg-line > span', { yPercent: 115, rotate: 3, duration: 1.5, stagger: 0.12, ease: 'expo.out' }, at + 0.1)
    .from('#sg-root .sg-hero .sg-intro', { y: 26, opacity: 0, duration: 1.2, stagger: 0.1, ease: 'expo.out' }, at + 0.6);
}
function endIntro() {
  if (safety) { clearTimeout(safety); safety = null; }
  try { sessionStorage.setItem('sg-intro', '1'); } catch (e) { /* sin sessionStorage */ }
  if (introOn) { introOn = false; const f = byId('sg-film'); if (f) f.hidden = true; }
}
function runIntro() {
  const tl = gs.timeline({ onComplete: endIntro });
  introTl = tl;
  tl.set('#sg-film .sg-film-bar', { scaleY: 1 })
    .fromTo('#sg-film .sg-film-cc', { opacity: 0, y: 20, filter: 'blur(8px)' }, { opacity: 1, y: 0, filter: 'blur(0px)', duration: 0.9, ease: 'expo.out' }, 0.2)
    .to('#sg-film .sg-film-cc', { opacity: 0, y: -14, filter: 'blur(6px)', duration: 0.5, ease: 'power2.in' }, 1.5)
    .fromTo('#sg-film .sg-film-flash', { opacity: 0 }, { opacity: 1, duration: 0.25, yoyo: true, repeat: 1, ease: 'power2.out' }, 2.0)
    .fromTo('#sg-film .sg-film-sigma', { opacity: 0, scale: 0.82, letterSpacing: '.3em' }, { opacity: 1, scale: 1, duration: 1, ease: 'expo.out' }, 2.05)
    .to('#sg-film .sg-film-sigma', { opacity: 0, scale: 1.12, filter: 'blur(10px)', duration: 0.55, ease: 'power2.in' }, 3.1)
    .to('#sg-film .sg-film-bar', { scaleY: 0.16, duration: 0.9, ease: 'expo.inOut' }, 3.3)
    .to('#sg-film .sg-film-bar', { scaleY: 0, duration: 0.9, ease: 'expo.inOut' }, 4.5)
    .to('#sg-film .sg-film-skip', { opacity: 0, duration: 0.3 }, 4.4);
  heroIn(tl, 3.7);
}

/* =============== componentes y planes =============== */
let modIdx = 0;
function pickMod(i) {
  if (i === modIdx) return;
  modIdx = i;
  const btns = $$('.sg-idx button');
  btns.forEach((b, k) => { b.classList.toggle('is-on', k === i); b.setAttribute('aria-pressed', k === i ? 'true' : 'false'); });
  const b = btns[i], n = '0' + (i + 1);
  byId('sg-mod-n').textContent = n; byId('sg-mod-big').textContent = n;
  byId('sg-mod-name').textContent = b.getAttribute('data-name');
  byId('sg-mod-desc').textContent = b.getAttribute('data-desc');
  byId('sg-mod-val').textContent = b.getAttribute('data-val');
  byId('sg-mod-star').hidden = b.getAttribute('data-star') !== '1';
  $$('#sg-viewer-stage .sg-mini-slot').forEach((s, k) => { s.hidden = k !== i; });
  if (gs && !reduced) gs.fromTo('#sg-viewer-stage', { y: 18, opacity: 0, scale: 0.98 }, { y: 0, opacity: 1, scale: 1, duration: 0.55, ease: 'expo.out' });
}
function bindMods() {
  $$('.sg-idx button').forEach((b, i) => {
    const pick = () => pickMod(i);
    b.addEventListener('click', pick); b.addEventListener('mouseenter', pick); b.addEventListener('focus', pick);
  });
}

const PRICES = { basico: [9, 90, 25.7], medio: [22, 220, 62.7], full: [45, 450, 128.3] }; /* UF/mes, UF/año, UF/trimestre (−5 %, Anexo F) */
let billing = 'mensual';
function setBilling(b) {
  if (b === billing) return;
  billing = b;
  $$('.sg-bill button').forEach((x) => { const on = x.getAttribute('data-bill') === b; x.classList.toggle('is-on', on); x.setAttribute('aria-pressed', on ? 'true' : 'false'); });
  Object.keys(PRICES).forEach((k) => {
    const m = PRICES[k][0], a = PRICES[k][1];
    let big, per, sub;
    if (b === 'anual') { big = String(a); per = '/ año'; sub = 'Equivale a ' + (a / 12).toFixed(1).replace('.', ',') + ' UF al mes · ahorras 17%'; }
    else if (b === 'trimestral') { const q = PRICES[k][2]; big = String(q).replace('.', ','); per = '/ trimestre'; sub = 'Equivale a ' + (q / 3).toFixed(1).replace('.', ',') + ' UF al mes · ahorras 5%'; }
    else { big = String(m); per = '/ mes'; sub = 'o ' + a + ' UF al año (ahorra 17%)'; }
    $('[data-pb="' + k + '"]').textContent = big; $('[data-pp="' + k + '"]').textContent = per; $('[data-ps="' + k + '"]').textContent = sub;
  });
  if (gs && !reduced) gs.fromTo('#sg-root .sg-price b', { yPercent: 70, opacity: 0 }, { yPercent: 0, opacity: 1, duration: 0.7, ease: 'expo.out', stagger: 0.07 });
}
function bindBilling() { $$('.sg-bill button').forEach((x) => x.addEventListener('click', () => setBilling(x.getAttribute('data-bill')))); }

/* =============== formulario de asesoría (3 pasos) =============== */
const FIELDS = { nombre: 'asNombre', apellido: 'asApellido', correo: 'asCorreo', telefono: 'asTelefono', empresa: 'asEmpresa', rubro: 'asRubro', cargo: 'asCargo', pais: 'asPais', ident: 'asIdent', activos: 'asActivos', plan: 'asPlan', mensaje: 'asMensaje' };
const TITLES = { 1: '¿Cómo te contactamos?', 2: 'Cuéntanos de tu empresa', 3: '¿Qué buscas resolver?' };
const PAIS = {
  'Chile': ['RUT de tu empresa', '76.123.456-7', 'Se cotiza en UF y se cobra en pesos (CLP).'],
  'Perú': ['RUC de tu empresa', '', 'Se cotiza y se cobra en dólares (USD).'],
  'Colombia': ['NIT de tu empresa', '', 'Se cotiza y se cobra en dólares (USD).'],
  'México': ['RFC de tu empresa', '', 'Se cotiza y se cobra en dólares (USD).'],
  'Argentina': ['CUIT de tu empresa', '', 'Se cotiza y se cobra en dólares (USD).'],
  'Ecuador': ['RUC de tu empresa', '', 'Se cotiza y se cobra en dólares (USD).'],
  'Otro': ['Identificador tributario', '', 'Se cotiza y se cobra en dólares (USD).']
};
const form = { step: 1, tried: {}, sending: false };
const val = (id) => { const e = byId(id); return e ? e.value.trim() : ''; };

function getF() {
  const f = {};
  Object.keys(FIELDS).forEach((k) => { f[k] = val(FIELDS[k]); });
  f.consent = byId('asConsent').checked;
  return f;
}
function errsFor(f) {
  const e = {};
  if (!f.nombre) e.nombre = 'Escribe tu nombre.';
  if (!f.correo) e.correo = 'Necesitamos un correo para responderte.';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(f.correo)) e.correo = 'Revisa el formato: nombre@empresa.cl';
  if (!f.empresa) e.empresa = 'Indica el nombre de tu empresa.';
  if (!f.consent) e.consent = 'Necesitamos tu autorización para contactarte.';
  return e;
}
const stepOf = (k) => (k === 'nombre' || k === 'correo') ? 1 : (k === 'empresa' ? 2 : 3);
const stepHasErr = (e, n) => Object.keys(e).some((k) => stepOf(k) === n);

function renderForm() {
  const all = errsFor(getF()), shown = {};
  Object.keys(all).forEach((k) => { if (form.tried[stepOf(k)]) shown[k] = all[k]; });
  ['nombre', 'correo', 'empresa', 'consent'].forEach((k) => {
    const err = shown[k], span = byId({ nombre: 'asNombreErr', correo: 'asCorreoErr', empresa: 'asEmpresaErr', consent: 'asConsentErr' }[k]);
    const input = byId(k === 'consent' ? 'asConsent' : FIELDS[k]);
    const wrap = k === 'consent' ? byId('asConsentWrap') : $('[data-f="' + k + '"]');
    wrap.classList.toggle('is-error', !!err);
    input.setAttribute('aria-invalid', err ? 'true' : 'false');
    span.textContent = err || ''; span.hidden = !err;
  });
  const s = form.step;
  $$('#sg-form .sg-fields').forEach((p) => { p.hidden = Number(p.getAttribute('data-step')) !== s; });
  $$('.sg-stepper li').forEach((li) => {
    const n = Number(li.getAttribute('data-st'));
    li.className = s > n ? 'is-done' : (s === n ? 'is-current' : '');
    li.setAttribute('aria-current', s === n ? 'step' : 'false');
  });
  byId('sg-form-t').textContent = TITLES[s];
  byId('sg-step-n').textContent = String(s);
  byId('sg-summary').hidden = !(form.tried[s] && stepHasErr(all, s));
  byId('sg-back').hidden = s <= 1; byId('sg-back').disabled = form.sending;
  byId('sg-next').hidden = s >= 3;
  const send = byId('sg-send');
  send.hidden = s < 3; send.disabled = form.sending; send.setAttribute('aria-busy', form.sending ? 'true' : 'false');
  $('.sg-spin', send).hidden = !form.sending;
  $('.sg-arrow', send).hidden = form.sending;
  byId('sg-send-txt').textContent = form.sending ? 'Enviando…' : 'Solicitar asesoría';
}
function focusFirstError() {
  const sel = $('#sg-form .sg-fields:not([hidden]) .is-error input, #sg-form .sg-fields:not([hidden]) .is-error select, #sg-form .sg-fields:not([hidden]) input[aria-invalid="true"]');
  if (sel) sel.focus();
}
function pais() {
  const c = PAIS[byId('asPais').value] || PAIS.Otro;
  byId('asIdentLbl').textContent = c[0]; byId('asIdent').placeholder = c[1]; byId('asMoneda').textContent = c[2];
}
function nextStep() {
  form.tried[form.step] = true;
  if (stepHasErr(errsFor(getF()), form.step)) { renderForm(); focusFirstError(); return; }
  form.step += 1; renderForm();
  const first = $('#sg-form .sg-fields:not([hidden]) input, #sg-form .sg-fields:not([hidden]) select'); if (first) first.focus();
}
function submitForm() {
  const f = getF(), e = errsFor(f);
  form.tried = { 1: true, 2: true, 3: true };
  if (stepHasErr(e, 1)) { form.step = 1; renderForm(); focusFirstError(); return; }
  if (stepHasErr(e, 2)) { form.step = 2; renderForm(); focusFirstError(); return; }
  if (stepHasErr(e, 3)) { renderForm(); focusFirstError(); return; }
  const errBox = byId('asErr');
  errBox.hidden = true;
  form.sending = true; renderForm();
  /* Centro Comercial: crea el lead en SIGMA y avisa a comercial (WsComercial.CrearLeadPublico). */
  fetch('WebService/WsComercial.asmx/CrearLeadPublico', {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      nombre: f.nombre, apellido: f.apellido, empresa: f.empresa, rubro: f.rubro, cargo: f.cargo, correo: f.correo,
      telefono: f.telefono, pais: f.pais, identificador: f.ident, activos: f.activos, plan: f.plan,
      mensaje: f.mensaje, consentimiento: f.consent, web: val('asWeb')
    })
  }).then((r) => {
    if (!r.ok) throw new Error('No pudimos enviar tu solicitud. Inténtalo de nuevo en unos minutos.');
    return r.json();
  }).then((j) => {
    const x = typeof j.d === 'string' ? JSON.parse(j.d) : j.d;
    if (x && x.error) throw new Error(x.detalle || 'No pudimos enviar tu solicitud.');
    form.sending = false;
    byId('sg-done-name').textContent = (f.nombre.split(' ')[0]) || 'gracias';
    byId('sg-done-mail').textContent = f.correo;
    byId('sg-form').hidden = true; byId('sg-done').hidden = false;
    byId('sg-done').scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'center' });
  }).catch((er) => {
    form.sending = false; renderForm();
    errBox.textContent = er.message; errBox.hidden = false;
  });
}
function resetForm() {
  Object.keys(FIELDS).forEach((k) => { byId(FIELDS[k]).value = k === 'pais' ? 'Chile' : ''; });
  byId('asConsent').checked = false; byId('asWeb').value = '';
  form.step = 1; form.tried = {}; form.sending = false;
  byId('asErr').hidden = true;
  byId('sg-done').hidden = true; byId('sg-form').hidden = false;
  pais(); renderForm();
}
function bindForm() {
  const f = byId('sg-form'); if (!f) return;
  byId('sg-next').addEventListener('click', nextStep);
  byId('sg-back').addEventListener('click', () => { form.step = Math.max(1, form.step - 1); renderForm(); });
  byId('sg-send').addEventListener('click', submitForm);
  byId('sg-reset').addEventListener('click', resetForm);
  byId('asPais').addEventListener('change', pais);
  f.addEventListener('input', renderForm); f.addEventListener('change', renderForm);
  pais(); renderForm();
}

/* =============== arranque =============== */
const wide = window.innerWidth >= 1100;
const vh = window.innerHeight, docH = document.documentElement.scrollHeight;
const cinema = !!(gs && ST && !reduced && vh < 1400 && docH > vh * 1.6);
let seen = false; try { seen = sessionStorage.getItem('sg-intro') === '1'; } catch (e) { /* sin sessionStorage */ }
const wantIntro = !!(gs && !reduced && cinema && !seen);

try { bindMods(); } catch (e) { /* componentes */ }
try { bindBilling(); } catch (e) { /* planes */ }
try { bindForm(); } catch (e) { /* formulario */ }
try { bindCine(); syncPlayUI(); syncSoundUI(); } catch (e) { /* cine */ }

try { initHero(wantIntro ? 2.6 : 0.25); } catch (e) { /* hero */ }
try { initCine(); } catch (e) { /* cine 3D */ }
try { initBrain(); } catch (e) { /* SIGMA AI */ }
try { initTwin(); } catch (e) { /* SIGMA Twin */ }

window.addEventListener('scroll', onScroll, { passive: true });
onScroll();

if (gs && !reduced) { try { initAmbient(); } catch (e) { /* ambiente */ } }
if (wantIntro) {
  const film = byId('sg-film');
  if (film) {
    film.hidden = false; introOn = true;
    const skip = byId('sg-film-skip');
    if (skip) skip.addEventListener('click', () => { if (introTl) introTl.progress(1); else endIntro(); });
    try { runIntro(); } catch (e) { endIntro(); }
    safety = setTimeout(() => { if (introOn) endIntro(); }, 9000);
  }
} else if (gs && !reduced) {
  try { heroIn(gs.timeline({ delay: 0.1 }), 0); } catch (e) { /* hero in */ }
}
if (cinema) {
  const story = byId('sg-story');
  if (story && wide) story.classList.add('is-cinema');
  try { initScroll(wide); } catch (e) { /* scroll */ }
}
