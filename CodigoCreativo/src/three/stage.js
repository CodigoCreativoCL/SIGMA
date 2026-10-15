import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { finishShader } from '../shaders/particles.glsl.js';
import { FOV_DEG } from './catalog.js';

// Renderer + cámara + postproceso (bloom, grano y viñeta).
export function createStage(canvas, { mobile }) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: false, powerPreference: 'high-performance' });
  renderer.setClearColor(0x05070d, 1);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(FOV_DEG, 1, 0.1, 200);
  camera.position.set(0, 0, 10);

  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), mobile ? 0.7 : 0.85, 0.55, 0.1);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());
  const finish = new ShaderPass(finishShader);
  composer.addPass(finish);

  const size = { w: 0, h: 0, dpr: 1 };
  function resize() {
    const w = canvas.clientWidth || innerWidth;
    const h = canvas.clientHeight || innerHeight;
    if (w === size.w && h === size.h) return false;
    size.w = w; size.h = h;
    size.dpr = Math.min(devicePixelRatio || 1, mobile ? 1.5 : 1.75);
    renderer.setPixelRatio(size.dpr);
    renderer.setSize(w, h, false);
    composer.setPixelRatio(size.dpr);
    composer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    return true;
  }
  resize();

  return { renderer, scene, camera, composer, bloom, finish, size, resize };
}
