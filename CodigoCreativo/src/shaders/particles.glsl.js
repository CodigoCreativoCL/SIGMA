// Shaders del sistema de partículas.
// Cada partícula viaja de `position` (forma A) a `aTo` (forma B) con un retraso propio,
// se dispersa a mitad de vuelo y responde al cursor y a un "foco" de luz.

export const particleVertex = /* glsl */ `
  uniform float uTime;
  uniform float uMorph;
  uniform float uScatter;
  uniform float uNoise;
  uniform float uPixelRatio;
  uniform float uSizeA, uSizeB, uAlphaA, uAlphaB, uRatioA, uRatioB;
  uniform vec3 uBaseA, uBaseB, uAccA, uAccB;
  uniform vec3 uMouse;
  uniform float uMouseForce;
  uniform vec3 uFocusPos;
  uniform float uFocusAmt;
  uniform float uFocusRadius;
  uniform vec3 uFocusColor;

  attribute vec3 aTo;
  attribute vec4 aRand;

  varying vec3 vColor;
  varying float vAlpha;

  void main() {
    float delay = aRand.x * 0.4;
    float m = clamp((uMorph - delay) / 0.6, 0.0, 1.0);
    m = m * m * (3.0 - 2.0 * m);

    vec3 p = mix(position, aTo, m);
    vec3 dir = normalize(aRand.yzw - 0.5 + 0.0001);
    p += dir * sin(m * 3.14159265) * uScatter * (0.5 + aRand.w);

    float t = uTime * 0.5 + aRand.x * 6.2831853;
    p += vec3(sin(t + p.y * 0.8), cos(t * 0.85 + p.x * 0.7), sin(t * 0.7 + p.z * 0.9))
       * uNoise * (0.35 + aRand.y * 0.65);

    float focus = uFocusAmt * (1.0 - smoothstep(0.0, uFocusRadius, distance(p, uFocusPos)));

    vec4 world = modelMatrix * vec4(p, 1.0);
    vec2 d = world.xy - uMouse.xy;
    float dl = length(d);
    world.xy += (d / max(dl, 0.001)) * uMouseForce * (1.0 - smoothstep(0.0, 1.8, dl));

    vec4 mv = viewMatrix * world;
    gl_Position = projectionMatrix * mv;

    float size = mix(uSizeA, uSizeB, m) * (0.5 + aRand.y) * (1.0 + focus * 1.6);
    gl_PointSize = size * uPixelRatio * (28.0 / -mv.z);

    float acc = step(aRand.z, mix(uRatioA, uRatioB, m));
    vec3 col = mix(mix(uBaseA, uBaseB, m), mix(uAccA, uAccB, m), acc);
    vColor = mix(col, uFocusColor, focus);
    vAlpha = mix(uAlphaA, uAlphaB, m) * (0.55 + aRand.w * 0.45) * (1.0 + focus * 1.2);
  }
`;

export const particleFragment = /* glsl */ `
  uniform float uOpacity;
  varying vec3 vColor;
  varying float vAlpha;

  void main() {
    float d = length(gl_PointCoord - 0.5);
    float a = pow(1.0 - smoothstep(0.0, 0.5, d), 1.6);
    if (a < 0.01) discard;
    gl_FragColor = vec4(vColor, a * vAlpha * uOpacity);
  }
`;

// Pasada final: grano + viñeta.
export const finishShader = {
  uniforms: { tDiffuse: { value: null }, uTime: { value: 0 }, uGrain: { value: 0.045 } },
  vertexShader: /* glsl */ `
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }
  `,
  fragmentShader: /* glsl */ `
    uniform sampler2D tDiffuse;
    uniform float uTime;
    uniform float uGrain;
    varying vec2 vUv;
    float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    void main() {
      vec4 c = texture2D(tDiffuse, vUv);
      float n = hash(floor(gl_FragCoord.xy) + fract(uTime * 7.0) * 113.0);
      c.rgb += (n - 0.5) * uGrain;
      float v = smoothstep(0.95, 0.25, distance(vUv, vec2(0.5)));
      c.rgb *= mix(0.62, 1.0, v);
      gl_FragColor = c;
    }
  `,
};
