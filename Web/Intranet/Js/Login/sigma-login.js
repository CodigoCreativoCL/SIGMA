/* SIGMA · Login (rediseño). El postback y los controles del servidor no cambian:
   esto solo agrega la escena, la validación previa y los detalles de usabilidad. */

const byId = (id) => document.getElementById(id);
const reduced = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
const gs = window.gsap || null;
const LS_KEY = 'sigma-login-correo';

let THREE = null;
try { THREE = await import('../three/three.module.min.js'); } catch (e) { THREE = null; }

/* ---------- escena: engranaje de partículas (versión liviana del hero) ---------- */
function initGL() {
  const T = THREE, c = byId('lg-gl'); if (!T || !c) return;
  const r = new T.WebGLRenderer({ canvas: c, antialias: false, alpha: true });
  const W = Math.max(1, c.clientWidth), H = Math.max(1, c.clientHeight), small = W < 700;
  r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2)); r.setSize(W, H, false);
  const scene = new T.Scene(), cam = new T.PerspectiveCamera(42, W / H, 0.1, 100); cam.position.set(0, 0, 11);
  const N = small ? 2500 : 6000, TAU = Math.PI * 2, R = 3.1, TEETH = 18;
  const pos = new Float32Array(N * 3), tgt = new Float32Array(N * 3), rnd = new Float32Array(N);
  function ss(a, b, x) { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); }
  function tooth(a) { const t = ((a * TEETH / TAU) % 1 + 1) % 1; return ss(0.1, 0.2, t) * (1 - ss(0.55, 0.65, t)); }
  for (let i = 0; i < N; i++) {
    rnd[i] = Math.random();
    pos[i * 3] = (Math.random() - 0.5) * 22; pos[i * 3 + 1] = (Math.random() - 0.5) * 14; pos[i * 3 + 2] = (Math.random() - 0.5) * 8 - 2;
    const k = Math.random(); let a = Math.random() * TAU, rr, z = (Math.random() - 0.5) * 0.7;
    if (k < 0.6) rr = R + tooth(a) * 0.5 + (Math.random() - 0.5) * 0.14;
    else if (k < 0.75) rr = R - 0.42 + (Math.random() - 0.5) * 0.1;
    else if (k < 0.88) { rr = 1 + (Math.random() - 0.5) * 0.22; z *= 1.6; }
    else { const sp = Math.floor(Math.random() * 6); a = sp / 6 * TAU + (Math.random() - 0.5) * 0.09; rr = 1.15 + Math.random() * (R - 1.6); }
    tgt[i * 3] = Math.cos(a) * rr; tgt[i * 3 + 1] = Math.sin(a) * rr; tgt[i * 3 + 2] = z;
  }
  const geo = new T.BufferGeometry();
  geo.setAttribute('position', new T.BufferAttribute(pos, 3)); geo.setAttribute('aTarget', new T.BufferAttribute(tgt, 3)); geo.setAttribute('aRnd', new T.BufferAttribute(rnd, 1));
  const u = { uTime: { value: 0 }, uMorph: { value: reduced ? 1 : 0 }, uPR: { value: r.getPixelRatio() }, uMouse: { value: new T.Vector2() }, uOff: { value: small ? new T.Vector3(2.6, 2.4, -3) : new T.Vector3(3.4, 1.4, 0) } };
  scene.add(new T.Points(geo, new T.ShaderMaterial({
    uniforms: u, transparent: true, depthWrite: false, blending: T.AdditiveBlending,
    vertexShader: [
      'uniform float uTime,uMorph,uPR; uniform vec2 uMouse; uniform vec3 uOff; attribute vec3 aTarget; attribute float aRnd; varying float vA; varying vec3 vC;',
      'mat3 rx(float a){float c=cos(a),s=sin(a);return mat3(1.,0.,0.,0.,c,s,0.,-s,c);} mat3 ry(float a){float c=cos(a),s=sin(a);return mat3(c,0.,-s,0.,1.,0.,s,0.,c);} mat3 rz(float a){float c=cos(a),s=sin(a);return mat3(c,s,0.,-s,c,0.,0.,0.,1.);}',
      'void main(){ float m = smoothstep(0.,1.,clamp(uMorph*1.5-aRnd*.5,0.,1.));',
      ' vec3 chaos = position + vec3(sin(uTime*.3+aRnd*40.)*.35, cos(uTime*.25+aRnd*30.)*.35, 0.);',
      ' vec3 g0 = rz(uTime*.1)*aTarget; vec3 g = ry(.5+uMouse.x*.25)*rx(-.4+uMouse.y*.15)*g0 + uOff;',
      ' vec4 mv = modelViewMatrix*vec4(mix(chaos,g,m),1.); gl_Position = projectionMatrix*mv; gl_PointSize = 32.*uPR*(.55+aRnd*.9)/-mv.z;',
      ' vC = mix(vec3(.5,.55,.7), mix(vec3(.45,.25,.98), vec3(.09,.78,.79), clamp(g0.x/7.+.5,0.,1.)), m); vA = mix(.25,.85,m); }'
    ].join('\n'),
    fragmentShader: 'varying float vA; varying vec3 vC; void main(){ float d=length(gl_PointCoord-.5); float a=smoothstep(.5,0.,d); gl_FragColor=vec4(vC,a*a*vA); }'
  })));
  const ms = { x: 0, y: 0, tx: 0, ty: 0 };
  window.addEventListener('pointermove', (e) => { ms.tx = (e.clientX / window.innerWidth - 0.5) * 2; ms.ty = (e.clientY / window.innerHeight - 0.5) * 2; }, { passive: true });
  let visible = true;
  if (window.ResizeObserver) { new ResizeObserver(() => { const w = c.clientWidth, h = c.clientHeight; if (!w || !h) return; r.setSize(w, h, false); cam.aspect = w / h; cam.updateProjectionMatrix(); if (reduced) r.render(scene, cam); }).observe(c); }
  if (window.IntersectionObserver) new IntersectionObserver((en) => { visible = en[0].isIntersecting; }).observe(c);
  if (reduced) { r.render(scene, cam); return; }
  const t0 = performance.now();
  (function frame() {
    requestAnimationFrame(frame);
    if (!visible) return;
    u.uTime.value = (performance.now() - t0) / 1000;
    if (!gs && u.uMorph.value < 1) u.uMorph.value = Math.min(1, u.uMorph.value + 0.008);
    ms.x += (ms.tx - ms.x) * 0.045; ms.y += (ms.ty - ms.y) * 0.045; u.uMouse.value.set(ms.x, ms.y);
    cam.position.x = ms.x * 0.4; cam.position.y = -ms.y * 0.25; cam.lookAt(0, 0, 0);
    r.render(scene, cam);
  })();
  if (gs) gs.to(u.uMorph, { value: 1, duration: 3, ease: 'expo.inOut', delay: 0.2 });
}

/* ---------- validación en el cliente antes del postback ---------- */
const correo = byId('txtCorreo'), pass = byId('txtPassword');

function setErr(field, input, spanId, msg) {
  const span = byId(spanId);
  field.classList.toggle('is-error', !!msg);
  input.setAttribute('aria-invalid', msg ? 'true' : 'false');
  span.textContent = msg || ''; span.hidden = !msg;
}
function errores() {
  const e = {}, v = correo.value.trim();
  if (!v) e.correo = 'Escribe tu correo.';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v)) e.correo = 'Revisa el formato: nombre@empresa.cl';
  if (!pass.value) e.pass = 'Escribe tu contraseña.';
  return e;
}
let tried = false;
function pintar() {
  const e = tried ? errores() : {};
  setErr(byId('lgFieldCorreo'), correo, 'lgCorreoErr', e.correo);
  setErr(byId('lgFieldPass'), pass, 'lgPassErr', e.pass);
  return e;
}
function enviando() {
  const b = byId('btnLogin');
  b.classList.add('is-busy'); b.setAttribute('aria-busy', 'true');
  byId('lgSubmitSpin').hidden = false; byId('lgSubmitArrow').hidden = true;
  byId('lgSubmitTxt').textContent = 'Verificando…';
}
/* El postback lo dispara el href del LinkButton: «Verificando…» se pone después del clic (setTimeout 0). */
window.sgLoginValidar = function () {
  tried = true;
  const e = pintar();
  if (e.correo || e.pass) { (e.correo ? correo : pass).focus(); return false; }
  try {
    if (byId('chkRecordar').checked) localStorage.setItem(LS_KEY, correo.value.trim()); else localStorage.removeItem(LS_KEY);
  } catch (er) { /* sin localStorage */ }
  setTimeout(enviando, 0);
  return true;
};

if (correo && pass) {
  correo.addEventListener('input', () => { if (tried) pintar(); });
  pass.addEventListener('input', () => { if (tried) pintar(); });

  /* mostrar / ocultar contraseña */
  byId('lgEye').addEventListener('click', () => {
    const show = pass.type === 'password';
    pass.type = show ? 'text' : 'password';
    const b = byId('lgEye');
    b.setAttribute('aria-pressed', show ? 'true' : 'false');
    b.setAttribute('aria-label', show ? 'Ocultar contraseña' : 'Mostrar contraseña');
    byId('lgEyeOff').hidden = !show; byId('lgEyeOn').hidden = show;
  });

  /* aviso de Bloq Mayús */
  const caps = (ev) => { if (ev.getModifierState) byId('lgCaps').hidden = !ev.getModifierState('CapsLock'); };
  pass.addEventListener('keyup', caps); pass.addEventListener('keydown', caps);
  pass.addEventListener('blur', () => { byId('lgCaps').hidden = true; });

  /* recordar solo el correo, nunca la contraseña */
  try {
    const guardado = localStorage.getItem(LS_KEY);
    if (guardado) { byId('chkRecordar').checked = true; if (!correo.value) correo.value = guardado; }
  } catch (er) { /* sin localStorage */ }
}

/* ---------- entrada animada y sacudida si el servidor devolvió un error ---------- */
try { initGL(); } catch (e) { /* sin escena: quedan los halos de CSS */ }
const errorServidor = !!byId('pnlError');
if (errorServidor && pass) { pass.focus(); }
if (gs && !reduced) {
  try {
    const tl = gs.timeline({ defaults: { ease: 'expo.out' } });
    tl.from('#lg-root .lg-film', { scaleX: 0, transformOrigin: '0 50%', duration: 1.2 }, 0)
      .from('#lg-root .lg-copy h1 .sg-line > span', { yPercent: 115, rotate: 3, duration: 1.4, stagger: 0.1 }, 0.15)
      .from('#lg-root .lg-in', { y: 22, opacity: 0, duration: 1.1, stagger: 0.08 }, 0.5)
      .from('#pnlLogin > *', { y: 26, opacity: 0, duration: 1, stagger: 0.05 }, 0.3);
    if (errorServidor) tl.fromTo('#pnlLogin', { x: -10 }, { x: 0, duration: 0.6, ease: 'elastic.out(1, .3)' }, 1);
  } catch (e) { /* sin animación */ }
}
