// Guion del scroll: qué escena del catálogo se ve en cada tramo de cada sección.
//
// u = progreso dentro del tramo fijo (sticky) de la sección: 0 cuando se fija, 1 cuando se suelta.
// keys: [u, p, opacidad?]  → p = índice fraccionario del catálogo (2.5 = mitad entre escena 2 y 3).
// enter: [p, opacidad?]    → valor cuando el borde superior de la sección asoma por abajo.
export const SCROLL_MAP = [
  { id: 'inicio', keys: [[0, 0, 1], [0.15, 0], [0.9, 1], [1, 1]] },
  { id: 'filosofia', enter: [1], keys: [[0, 1], [0.1, 1], [0.28, 2], [0.4, 2], [0.58, 3], [0.7, 3], [0.88, 4], [1, 4]] },
  { id: 'ecosistema', enter: [4], keys: [[0, 5], [1, 5]] },
  { id: 'sigma', enter: [5], keys: [[0, 6], [0.12, 6], [0.42, 7], [1, 7]] },
  { id: 'sigma-ai', enter: [7], keys: [[0, 7.45], [0.3, 7.55], [0.5, 8], [1, 8]] },
  { id: 'laboratorio', enter: [8, 1], keys: [[0, 9, 0], [1, 9, 0]] },
  { id: 'proyectos', enter: [9, 0], keys: [[0, 10, 0.6], [1, 10, 0.6]] },
  { id: 'transicion', enter: [10, 0.6], keys: [[0, 11, 1], [0.12, 11], [0.38, 12], [0.5, 12], [0.66, 13], [0.86, 14], [1, 14]] },
  { id: 'contacto', enter: [14, 1], keys: [[0, 15, 0.85]] },
];

// Hitos internos (u) que comparten las animaciones del DOM y los efectos 3D.
export const ECO_SEQ = [[0, 'core'], [0.16, 'sigma'], [0.4, 'ai'], [0.64, 'twin'], [0.88, 'all']];
export const SIGMA_PHASES = [0, 0.15, 0.45, 0.7];
export const AI_STEPS = [0, 0.18, 0.36, 0.66];

export function stepAt(u, stops) {
  let k = 0;
  for (let i = 0; i < stops.length; i++) if (u >= stops[i]) k = i;
  return k;
}
