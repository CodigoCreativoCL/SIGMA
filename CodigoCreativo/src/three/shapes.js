// Generadores de formas: cada uno devuelve un Float32Array (n × xyz).
// El sistema de partículas interpola entre estas formas según el scroll.

const TAU = Math.PI * 2;
const GOLDEN = Math.PI * (3 - Math.sqrt(5));

export function seeded(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function make(n, fn) {
  const out = new Float32Array(n * 3);
  const v = [0, 0, 0];
  for (let i = 0; i < n; i++) {
    fn(i, v);
    out[i * 3] = v[0]; out[i * 3 + 1] = v[1]; out[i * 3 + 2] = v[2];
  }
  return out;
}

const gauss = (r) => (r() + r() + r() - 1.5) / 1.5;

function onSphere(r, v, radius) {
  const u = r() * 2 - 1, a = r() * TAU, s = Math.sqrt(1 - u * u);
  v[0] = s * Math.cos(a) * radius;
  v[1] = u * radius;
  v[2] = s * Math.sin(a) * radius;
  return v;
}

// Dibuja en un canvas 2D y reparte partículas sobre los píxeles opacos.
function sampleDrawing(n, r, { w, h, width, depth = 0.25, x = 0, y = 0 }, draw) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const ctx = c.getContext('2d', { willReadFrequently: true });
  draw(ctx, w, h);
  const data = ctx.getImageData(0, 0, w, h).data;
  const px = [];
  for (let j = 0; j < h; j += 2) {
    for (let i = 0; i < w; i += 2) if (data[(j * w + i) * 4 + 3] > 140) px.push(i, j);
  }
  if (!px.length) return make(n, (_, v) => onSphere(r, v, 2.4));
  const s = width / w;
  return make(n, (_, v) => {
    const k = Math.floor(r() * (px.length / 2)) * 2;
    v[0] = (px[k] + r() * 2 - w / 2) * s + x;
    v[1] = -(px[k + 1] + r() * 2 - h / 2) * s + y;
    v[2] = (r() - 0.5) * depth;
  });
}

// ── Isotipo: el foco con </> (lee los trazos del <symbol id="logo-mark">)
export function bulb(n, r) {
  const paths = [...document.querySelectorAll('#logo-mark path')].map((p) => ({
    d: p.getAttribute('d'),
    w: parseFloat(p.getAttribute('stroke-width') || '0'),
    fill: p.getAttribute('fill') === 'currentColor',
  }));
  return sampleDrawing(n, r, { w: 600, h: 600, width: 4.8, depth: 0.4, y: -0.2 }, (ctx, w) => {
    const k = w / 100;
    ctx.setTransform(k, 0, 0, k, 0, 0);
    ctx.strokeStyle = '#fff'; ctx.fillStyle = '#fff';
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    for (const p of paths) {
      const path = new Path2D(p.d);
      if (p.fill) ctx.fill(path);
      else { ctx.lineWidth = p.w; ctx.stroke(path); }
    }
  });
}

// ── Logotipo tipográfico
export function wordmark(n, r) {
  return sampleDrawing(n, r, { w: 1400, h: 640, width: 9.4, depth: 0.3 }, (ctx, w, h) => {
    ctx.fillStyle = '#fff';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    const font = (s) => `800 expanded ${s}px Archivo, system-ui, sans-serif`;
    ctx.font = font(300);
    if ('fontStretch' in ctx) ctx.fontStretch = 'expanded';
    const size = Math.min(300 * (w * 0.94) / ctx.measureText('CREATIVO').width, h * 0.42);
    ctx.font = font(size);
    if ('fontStretch' in ctx) ctx.fontStretch = 'expanded';
    ctx.fillText('CÓDIGO', w / 2, h * 0.29);
    ctx.fillText('CREATIVO', w / 2, h * 0.74);
  });
}

// ── Red de nodos (el logo "desarmado")
export function constellation(n, r) {
  const nodes = [];
  for (let i = 0; i < 70; i++) nodes.push([(r() - 0.5) * 15, (r() - 0.5) * 7.5, (r() - 0.5) * 6]);
  const edges = [];
  nodes.forEach((a, i) => {
    nodes
      .map((b, j) => [j, (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2])
      .filter(([j]) => j !== i)
      .sort((x, y) => x[1] - y[1])
      .slice(0, 2)
      .forEach(([j]) => edges.push([a, nodes[j]]));
  });
  return make(n, (_, v) => {
    if (r() < 0.22) {
      const a = nodes[Math.floor(r() * nodes.length)];
      v[0] = a[0] + gauss(r) * 0.12; v[1] = a[1] + gauss(r) * 0.12; v[2] = a[2] + gauss(r) * 0.12;
    } else {
      const [a, b] = edges[Math.floor(r() * edges.length)];
      const t = r();
      v[0] = a[0] + (b[0] - a[0]) * t + gauss(r) * 0.025;
      v[1] = a[1] + (b[1] - a[1]) * t + gauss(r) * 0.025;
      v[2] = a[2] + (b[2] - a[2]) * t + gauss(r) * 0.025;
    }
  });
}

// ── Esfera orgánica (experiencias)
export function blob(n, r) {
  return make(n, (i, v) => {
    const y = 1 - 2 * (i + 0.5) / n, rad = Math.sqrt(1 - y * y), th = i * GOLDEN;
    const x = Math.cos(th) * rad, z = Math.sin(th) * rad;
    const k = 2.45 + 0.3 * Math.sin(x * 3.1 + y * 2.3) * Math.cos(z * 2.7 - y * 1.4);
    const inner = r() < 0.12 ? 0.5 + r() * 0.4 : 1;
    v[0] = x * k * inner; v[1] = y * k * inner; v[2] = z * k * inner;
  });
}

// ── Nudo toroidal (sistemas)
export function knot(n, r) {
  return make(n, (_, v) => {
    const t = r() * TAU;
    const rr = Math.cos(3 * t) + 2.2;
    const cx = rr * Math.cos(2 * t) * 1.02, cy = rr * Math.sin(2 * t) * 1.02, cz = -Math.sin(3 * t) * 1.02;
    onSphere(r, v, 0.28 + r() * 0.1);
    v[0] += cx; v[1] += cy; v[2] += cz;
  });
}

// ── Galaxia espiral (futuro)
export function galaxy(n, r) {
  return make(n, (i, v) => {
    if (r() < 0.12) { onSphere(r, v, Math.pow(r(), 2) * 0.9); v[1] *= 0.6; return; }
    const radius = 0.35 + Math.pow(r(), 0.85) * 6.2;
    const ang = ((i % 3) / 3) * TAU + radius * 0.72;
    const sp = 0.25 + radius * 0.16;
    const jx = Math.pow(r(), 3) * (r() < 0.5 ? 1 : -1) * sp;
    const jz = Math.pow(r(), 3) * (r() < 0.5 ? 1 : -1) * sp;
    v[0] = Math.cos(ang) * radius + jx;
    v[1] = gauss(r) * 0.18;
    v[2] = Math.sin(ang) * radius + jz;
  });
}

// ── Ecosistema: Código Creativo (núcleo) → SIGMA y Software a la medida.
// SIGMA AI y SIGMA TWIN son módulos de inteligencia DE SIGMA: orbitan a SIGMA, no al núcleo.
// En vertical todo se gira 90° para caber.
const ECO_RADIUS = { core: 1.15, sigma: 0.72, ai: 0.34, twin: 0.34, soft: 0.5 };

const ECO_SPAN = 3.4;   // núcleo ↔ SIGMA / Software
const ECO_MOON = 2.05;  // SIGMA ↔ sus módulos

export function ecoNodes(portrait) {
  // En horizontal el racimo de SIGMA lleva etiquetas a la izquierda: se corre todo a la derecha.
  const cx = portrait ? 0 : 1.1;
  const L = {
    core: [cx, 0, 0],
    sigma: [cx - ECO_SPAN, 0, 0],
    ai: [cx - ECO_SPAN, ECO_MOON, 0],
    twin: [cx - ECO_SPAN, -ECO_MOON, 0],
    soft: [cx + ECO_SPAN, 0, 0],
  };
  if (!portrait) return L;
  const P = {};
  for (const [k, [x, y, z]] of Object.entries(L)) P[k] = [-y, x, z];
  return P;
}

// Dónde va cada etiqueta respecto de su nodo: 'below', 'above', 'left' o 'center'.
export function ecoLabelAnchors(portrait) {
  const N = ecoNodes(portrait);
  const below = (k, gap) => ({ pos: [N[k][0], N[k][1] - ECO_RADIUS[k] - gap, N[k][2]], side: 'below' });
  const left = (k, gap) => ({ pos: [N[k][0] - ECO_RADIUS[k] - gap, N[k][1], N[k][2]], side: 'left' });
  const center = (k) => ({ pos: [...N[k]], side: 'center' });
  const above = (k, gap) => ({ pos: [N[k][0], N[k][1] + ECO_RADIUS[k] + gap, N[k][2]], side: 'above' });
  if (portrait) {
    return { core: center('core'), sigma: above('sigma', 0.2), ai: below('ai', 0.2), twin: below('twin', 0.2), soft: below('soft', 0.25) };
  }
  return { core: below('core', 0.3), sigma: left('sigma', 0.75), ai: left('ai', 0.5), twin: left('twin', 0.5), soft: below('soft', 0.25) };
}

export function ecosystem(n, r, portrait) {
  const N = ecoNodes(portrait);
  const rot = (x, y) => (portrait ? [-y, x] : [x, y]);
  const ball = (k, v) => {
    onSphere(r, v, ECO_RADIUS[k] + gauss(r) * 0.03);
    v[0] += N[k][0]; v[1] += N[k][1]; v[2] += N[k][2];
  };
  const link = (a, b, v) => {
    const t = r();
    v[0] = N[a][0] + (N[b][0] - N[a][0]) * t + gauss(r) * 0.02;
    v[1] = N[a][1] + (N[b][1] - N[a][1]) * t + gauss(r) * 0.02;
    v[2] = N[a][2] + (N[b][2] - N[a][2]) * t + gauss(r) * 0.02;
  };
  const links = [['core', 'sigma'], ['core', 'soft'], ['sigma', 'ai'], ['sigma', 'twin']];
  return make(n, (_, v) => {
    const k = r();
    if (k < 0.3) ball('core', v);
    else if (k < 0.46) ball('sigma', v);
    else if (k < 0.54) ball('ai', v);
    else if (k < 0.62) ball('twin', v);
    else if (k < 0.7) ball('soft', v);
    else if (k < 0.82) link(...links[Math.floor(r() * links.length)], v);
    else if (k < 0.87) {
      // órbita de los módulos alrededor de SIGMA
      const a = r() * TAU;
      const [x, y] = rot(Math.sin(a) * 0.75, Math.cos(a) * ECO_MOON);
      v[0] = N.sigma[0] + x + gauss(r) * 0.015; v[1] = N.sigma[1] + y + gauss(r) * 0.015; v[2] = -Math.sin(a) * 0.4;
    } else if (k < 0.92) {
      // órbita del núcleo
      const a = r() * TAU;
      const [x, y] = rot(Math.cos(a) * ECO_SPAN, Math.sin(a) * 1.15);
      v[0] = N.core[0] + x + gauss(r) * 0.015; v[1] = N.core[1] + y + gauss(r) * 0.015; v[2] = Math.sin(a) * 0.5;
    } else {
      onSphere(r, v, 4.8 + r() * 3.5);
    }
  });
}

// ── Caos
export function chaos(n, r) {
  return make(n, (_, v) => { v[0] = (r() - 0.5) * 13; v[1] = (r() - 0.5) * 7; v[2] = (r() - 0.5) * 6; });
}

// ── Fábrica abstracta (SIGMA)
export const GROUND_Y = -1.3;
export const BUILDINGS = (() => {
  const R = seeded(77);
  const out = [];
  for (let gz = -1; gz <= 1; gz++) {
    for (let gx = -2; gx <= 2; gx++) {
      out.push({
        x: gx * 1.55 + (R() - 0.5) * 0.2, z: gz * 1.45,
        w: 0.75 + R() * 0.4, d: 0.7 + R() * 0.4, h: 0.45 + R() * 1.5,
      });
    }
  }
  out[8].h = 1.6; // el activo que SIGMA AI marcará
  return out;
})();
export const FACTORY_FOCUS = [BUILDINGS[8].x, GROUND_Y + BUILDINGS[8].h, BUILDINGS[8].z];

export function factory(n, r) {
  const B = BUILDINGS;
  return make(n, (_, v) => {
    const k = r();
    if (k < 0.58) {
      const b = B[Math.floor(r() * B.length)];
      const c = [0, 0, 0];
      const axis = Math.floor(r() * 3);
      for (let q = 0; q < 3; q++) c[q] = q === axis ? r() - 0.5 : (r() < 0.5 ? -0.5 : 0.5);
      v[0] = b.x + c[0] * b.w; v[1] = GROUND_Y + b.h / 2 + c[1] * b.h; v[2] = b.z + c[2] * b.d;
    } else if (k < 0.7) {
      const b = B[Math.floor(r() * B.length)];
      v[0] = b.x + (r() - 0.5) * b.w; v[1] = GROUND_Y + b.h; v[2] = b.z + (r() - 0.5) * b.d;
    } else if (k < 0.78) {
      const b = B[r() < 0.5 ? 2 : 11];
      const a = r() * TAU;
      v[0] = b.x + Math.cos(a) * 0.13; v[1] = GROUND_Y + b.h + r() * 1.3; v[2] = b.z + Math.sin(a) * 0.13;
    } else if (r() < 0.5) {
      v[0] = (r() - 0.5) * 9.5; v[1] = GROUND_Y; v[2] = (Math.floor(r() * 13) - 6) * 0.5;
    } else {
      v[0] = (Math.floor(r() * 20) - 9.5) * 0.5; v[1] = GROUND_Y; v[2] = (r() - 0.5) * 6;
    }
  });
}

// ── Indicador circular (SIGMA AI): arco al 87 % + escala
export const GAUGE_R = 2.7;
export const GAUGE_TIP = (() => {
  const a = Math.PI / 2 - 0.87 * TAU;
  return [Math.cos(a) * GAUGE_R, Math.sin(a) * GAUGE_R, 0];
})();

export function gauge(n, r) {
  return make(n, (_, v) => {
    const k = r();
    if (k < 0.56) {
      const a = Math.PI / 2 - r() * 0.87 * TAU, rad = GAUGE_R + gauss(r) * 0.07;
      v[0] = Math.cos(a) * rad; v[1] = Math.sin(a) * rad; v[2] = gauss(r) * 0.08;
    } else if (k < 0.64) {
      const a = Math.PI / 2 - (0.87 + r() * 0.13) * TAU, rad = GAUGE_R + gauss(r) * 0.03;
      v[0] = Math.cos(a) * rad; v[1] = Math.sin(a) * rad; v[2] = 0;
    } else if (k < 0.94) {
      const tick = Math.floor(r() * 72);
      const a = Math.PI / 2 - (tick / 72) * TAU;
      const rad = 3.08 + r() * (tick % 6 === 0 ? 0.34 : 0.14);
      v[0] = Math.cos(a) * rad; v[1] = Math.sin(a) * rad; v[2] = 0;
    } else {
      onSphere(r, v, 3.6 + r() * 3);
    }
  });
}

export function dust(n, r) { return make(n, (_, v) => onSphere(r, v, 7 + r() * 7)); }

export function wave(n, r) {
  return make(n, (_, v) => {
    const z = -7 + Math.floor(r() * 44) * (12 / 43);
    const x = (r() - 0.5) * 22;
    v[0] = x; v[2] = z;
    v[1] = -1.7 + Math.sin(x * 0.45 + z * 0.3) * 0.45 + Math.cos(z * 0.6) * 0.25;
  });
}

export function dot(n, r) { return make(n, (_, v) => onSphere(r, v, Math.pow(r(), 0.5) * 0.13)); }

export function sphere(n, r) {
  return make(n, (i, v) => {
    const y = 1 - 2 * (i + 0.5) / n, rad = Math.sqrt(1 - y * y), th = i * GOLDEN;
    const k = 2.6 + gauss(r) * 0.03;
    v[0] = Math.cos(th) * rad * k; v[1] = y * k; v[2] = Math.sin(th) * rad * k;
  });
}

export function burst(n, r) { return make(n, (_, v) => onSphere(r, v, 7 + r() * 13)); }

export function halo(n, r) {
  const c = Math.cos(1.2), s = Math.sin(1.2);
  return make(n, (_, v) => {
    if (r() < 0.85) {
      const a = r() * TAU, rad = 4.3 + gauss(r) * 0.22;
      const x = Math.cos(a) * rad, y = gauss(r) * 0.12, z = Math.sin(a) * rad;
      v[0] = x; v[1] = y * c - z * s; v[2] = y * s + z * c;
    } else {
      onSphere(r, v, 5 + r() * 4);
    }
  });
}
