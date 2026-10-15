import * as THREE from 'three';
import { particleVertex, particleFragment } from '../shaders/particles.glsl.js';

// Un solo THREE.Points para toda la página. Solo se suben a la GPU las dos
// formas activas (A → B); el resto vive en memoria y se intercambia al cruzar escenas.
export class Particles {
  constructor(shapes, catalog, count) {
    this.shapes = shapes;
    this.catalog = catalog;
    this.pair = [-1, -1];

    const g = new THREE.BufferGeometry();
    this.from = new THREE.BufferAttribute(new Float32Array(count * 3), 3).setUsage(THREE.DynamicDrawUsage);
    this.to = new THREE.BufferAttribute(new Float32Array(count * 3), 3).setUsage(THREE.DynamicDrawUsage);
    const rnd = new Float32Array(count * 4);
    for (let i = 0; i < rnd.length; i++) rnd[i] = Math.random();
    g.setAttribute('position', this.from);
    g.setAttribute('aTo', this.to);
    g.setAttribute('aRand', new THREE.BufferAttribute(rnd, 4));

    const c = () => new THREE.Color();
    this.uniforms = {
      uTime: { value: 0 }, uMorph: { value: 0 }, uScatter: { value: 0 }, uNoise: { value: 0 },
      uPixelRatio: { value: 1 }, uOpacity: { value: 1 },
      uSizeA: { value: 1 }, uSizeB: { value: 1 }, uAlphaA: { value: 1 }, uAlphaB: { value: 1 },
      uRatioA: { value: 0 }, uRatioB: { value: 0 },
      uBaseA: { value: c() }, uBaseB: { value: c() }, uAccA: { value: c() }, uAccB: { value: c() },
      uMouse: { value: new THREE.Vector3(999, 999, 0) }, uMouseForce: { value: 0 },
      uFocusPos: { value: new THREE.Vector3() }, uFocusAmt: { value: 0 }, uFocusRadius: { value: 1.4 },
      uFocusColor: { value: new THREE.Color('#F7A928') },
    };

    this.material = new THREE.ShaderMaterial({
      uniforms: this.uniforms,
      vertexShader: particleVertex,
      fragmentShader: particleFragment,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
    });
    this.points = new THREE.Points(g, this.material);
    this.points.frustumCulled = false;
  }

  replaceShapes(shapes) {
    this.shapes = shapes;
    this.pair = [-1, -1];
  }

  setPair(a, b) {
    if (this.pair[0] === a && this.pair[1] === b) return;
    this.pair = [a, b];
    this.from.array.set(this.shapes[a]); this.from.needsUpdate = true;
    this.to.array.set(this.shapes[b]); this.to.needsUpdate = true;

    const A = this.catalog[a], B = this.catalog[b], u = this.uniforms;
    u.uBaseA.value.set(A.pal[0]); u.uAccA.value.set(A.pal[1]); u.uRatioA.value = A.pal[2];
    u.uBaseB.value.set(B.pal[0]); u.uAccB.value.set(B.pal[1]); u.uRatioB.value = B.pal[2];
    u.uSizeA.value = A.size; u.uSizeB.value = B.size;
    u.uAlphaA.value = A.alpha; u.uAlphaB.value = B.alpha;
    u.uScatter.value = B.scatter;
  }
}
