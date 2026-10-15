// Mini‑visuales de las tarjetas de proyectos (sin imágenes: todo vectorial).
import { BUILDINGS } from '../three/shapes.js';

export function buildVisuals() {
  // SIGMA: rejilla de 40 activos con su estado
  const grid = document.querySelector('[data-grid]');
  if (grid && !grid.children.length) {
    const warn = new Set([5, 13, 30, 36]);
    for (let i = 0; i < 40; i++) {
      const cell = document.createElement('i');
      if (i === 22) cell.className = 'crit';
      else if (warn.has(i)) cell.className = 'warn';
      grid.appendChild(cell);
    }
  }

  // SIGMA TWIN: la misma fábrica del 3D, en isométrico
  const svg = document.querySelector('[data-iso]');
  if (svg && !svg.children.length) {
    const s = 26, ox = 200, oy = 132;
    const P = (x, y, z) => [ox + (x - z) * 0.866 * s, oy + (x + z) * 0.5 * s - y * s];
    const poly = (pts, fill) => `<polygon points="${pts.map((p) => p.join(',')).join(' ')}" fill="${fill}"/>`;
    let out = '';
    for (let k = -4; k <= 4; k++) {
      const a = P(k, 0, -3.4), b = P(k, 0, 3.4), c = P(-4.4, 0, k * 0.8), d = P(4.4, 0, k * 0.8);
      out += `<path class="floor" d="M${a}L${b}M${c}L${d}"/>`;
    }
    const sorted = BUILDINGS.map((b, i) => ({ ...b, i })).sort((a, b) => (a.x + a.z) - (b.x + b.z));
    for (const b of sorted) {
      const x0 = b.x - b.w / 2, x1 = b.x + b.w / 2, z0 = b.z - b.d / 2, z1 = b.z + b.d / 2, h = b.h;
      const top = [P(x0, h, z0), P(x1, h, z0), P(x1, h, z1), P(x0, h, z1)];
      const left = [P(x0, 0, z1), P(x1, 0, z1), P(x1, h, z1), P(x0, h, z1)];
      const right = [P(x1, 0, z0), P(x1, 0, z1), P(x1, h, z1), P(x1, h, z0)];
      const hot = b.i === 8;
      out += `<g class="${hot ? 'hot' : ''}">` +
        poly(left, hot ? 'rgba(247,169,40,.16)' : 'rgba(61,214,245,.07)') +
        poly(right, hot ? 'rgba(247,169,40,.1)' : 'rgba(61,214,245,.03)') +
        poly(top, hot ? 'rgba(247,169,40,.28)' : 'rgba(61,214,245,.12)') + '</g>';
    }
    svg.innerHTML = out;
  }
}
