// Catálogo de escenas: el orden ES la historia del scroll.
// p = 0 → bulb, p = 1 → constellation, … El índice fraccionario mezcla dos escenas.
import * as S from './shapes.js';

const FOV = 40;
const T = Math.tan((FOV * Math.PI / 180) / 2);

/** Distancia de cámara para que un ancho `width` quepa en pantalla. */
export const fitZ = (width, aspect) => (width / 2) / (T * aspect) * 1.08;
/** Ídem para una altura. */
export const fitH = (height) => (height / 2) / T * 1.08;
const frame = (z, width, y = 0, height = 0) => (a) => [0, y, Math.max(z, fitZ(width, a), fitH(height))];

const AMBER = '#F7A928', AMBER_SOFT = '#FFE2A6', CYAN = '#3DD6F5', WHITE = '#F2F4F8',
  STEEL = '#7D8BA8', DEEP = '#33405C';

export const FOV_DEG = FOV;

// cam(aspect) → [x, y, z]; tilt = giro en X del grupo; sway = vaivén en Y.
// pal = [color base, color acento, proporción de acento].
export const CATALOG = [
  { key: 'bulb', make: S.bulb,
    cam: (a) => (a >= 1.05
      ? [-T * 10 * a * 0.42, 0.15, 10]
      : (() => { const z = Math.max(10, fitZ(5.6, a)); return [0, -z * 0.12, z]; })()),
    tilt: 0, sway: 0.2, size: 1.0, alpha: 0.5, noise: 0.02, scatter: 0, mouse: 0.6, pal: [AMBER, AMBER_SOFT, 0.25] },
  { key: 'constellation', make: S.constellation, cam: frame(11, 12),
    tilt: 0.1, sway: 0.35, size: 1.0, alpha: 0.75, noise: 0.06, scatter: 2.5, mouse: 0.5, pal: [STEEL, AMBER, 0.12] },
  { key: 'blob', make: S.blob, cam: frame(9.5, 7),
    tilt: 0.2, sway: 0.6, size: 1.0, alpha: 0.7, noise: 0.04, scatter: 1.6, mouse: 0.35, pal: [CYAN, AMBER, 0.14] },
  { key: 'knot', make: S.knot, cam: frame(10, 8),
    tilt: 0.3, sway: 0.7, size: 1.0, alpha: 0.7, noise: 0.03, scatter: 1.6, mouse: 0.35, pal: [STEEL, CYAN, 0.35] },
  { key: 'galaxy', make: S.galaxy, cam: (a) => frame(10, a < 0.85 ? 7.5 : 12, -0.3)(a),
    tilt: 0.55, sway: 0.5, size: 1.0, alpha: 0.75, noise: 0.03, scatter: 2, mouse: 0.35, pal: [CYAN, AMBER, 0.35] },
  { key: 'ecosystem', make: S.ecosystem, cam: (a) => (a < 0.85 ? frame(10.5, 6.6, 0, 10.4) : frame(10.5, 10.8, 0, 7.6))(a),
    tilt: 0.05, sway: 0.12, size: 1.0, alpha: 0.7, noise: 0.03, scatter: 2, mouse: 0.3, pal: [STEEL, CYAN, 0.22] },
  { key: 'chaos', make: S.chaos, cam: frame(10, 10),
    tilt: 0, sway: 0.2, size: 1.25, alpha: 1.0, noise: 0.12, scatter: 0.6, mouse: 0.35, pal: ['#5A6680', AMBER, 0.08] },
  { key: 'factory', make: S.factory, cam: frame(10, 9.6, 0.4),
    tilt: 0.45, sway: 0.18, size: 0.95, alpha: 0.75, noise: 0.008, scatter: 1, mouse: 0.2, pal: [CYAN, WHITE, 0.25] },
  { key: 'gauge', make: S.gauge, cam: frame(9.5, 7.6, 0, 8.4),
    tilt: 0, sway: 0.08, size: 1.0, alpha: 0.75, noise: 0.015, scatter: 3, mouse: 0.25, pal: [CYAN, AMBER, 0.18] },
  { key: 'dust', make: S.dust, cam: frame(10, 0),
    tilt: 0, sway: 0.2, size: 0.8, alpha: 0.4, noise: 0.1, scatter: 0, mouse: 0, pal: [STEEL, CYAN, 0.1] },
  { key: 'wave', make: S.wave, cam: frame(9, 14, 0.8),
    tilt: 0.25, sway: 0.08, size: 0.9, alpha: 0.6, noise: 0.05, scatter: 0.5, mouse: 0.3, pal: [DEEP, CYAN, 0.12] },
  { key: 'dot', make: S.dot, cam: frame(9, 0),
    tilt: 0, sway: 0, size: 0.5, alpha: 0.12, noise: 0.006, scatter: 0, mouse: 0, pal: [CYAN, WHITE, 0.2] },
  { key: 'sphere', make: S.sphere, cam: frame(9, 6.6),
    tilt: 0.2, sway: 0.8, size: 0.9, alpha: 0.6, noise: 0.03, scatter: 0, mouse: 0.3, pal: [CYAN, WHITE, 0.2] },
  { key: 'burst', make: S.burst, cam: frame(9, 0),
    tilt: 0.2, sway: 0.4, size: 1.0, alpha: 0.7, noise: 0.1, scatter: 0, mouse: 0, pal: [AMBER, CYAN, 0.5] },
  { key: 'wordmark', make: S.wordmark, cam: frame(10, 10.4, -0.7),
    tilt: 0, sway: 0, size: 0.85, alpha: 0.45, noise: 0.012, scatter: 1.5, mouse: 0.5, pal: [WHITE, AMBER, 0.22] },
  { key: 'halo', make: S.halo, cam: frame(11, 10.5),
    tilt: 0, sway: 0.15, size: 1.0, alpha: 0.6, noise: 0.04, scatter: 1.5, mouse: 0.35, pal: [AMBER, CYAN, 0.2] },
];

export const INDEX = Object.fromEntries(CATALOG.map((d, i) => [d.key, i]));

export function buildShapes(count, portrait) {
  return CATALOG.map((d, i) => d.make(count, S.seeded(1000 + i * 97), portrait));
}
