// Sentio — Cloth Vertex Shader
// Attach to a GLSL MAT or Phong MAT (vertex shader override).
// Deforms the cloth mesh using animated noise driven by the
// "distortion" and "flowSpeed" parameters from Sentio.
//
// Uniforms fed by a GLSL TOP or Constant CHOP → GLSL MAT:
//   uDistortion   — float 0.0–1.0
//   uFlowSpeed    — float 0.0–1.0
//   uTime         — float (seconds, connect to absTime:seconds CHOP)

uniform float uDistortion;
uniform float uFlowSpeed;
uniform float uTime;

// Simple 3-D value noise
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(mix(hash(i),           hash(i + vec3(1,0,0)), f.x),
            mix(hash(i+vec3(0,1,0)),hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i+vec3(0,0,1)),hash(i + vec3(1,0,1)), f.x),
            mix(hash(i+vec3(0,1,1)),hash(i + vec3(1,1,1)), f.x), f.y),
        f.z
    );
}

// TD built-ins
in vec4 P;      // position
in vec3 N;      // normal
out vec4 vPos;
out vec3 vNormal;

void main() {
    vec3 pos   = P.xyz;
    float speed = uFlowSpeed * 0.5;

    // Ripple displacement along the normal direction
    float n = noise(pos * 2.0 + vec3(0.0, uTime * speed, uTime * speed * 0.7));
    float displacement = (n - 0.5) * uDistortion * 0.15;
    pos += N * displacement;

    // Secondary high-frequency wrinkle layer
    float wrinkle = noise(pos * 8.0 + uTime * speed * 1.5);
    pos += N * (wrinkle - 0.5) * uDistortion * 0.04;

    vPos    = vec4(pos, 1.0);
    vNormal = N;
    gl_Position = TDWorldToProj(TDDeform(vec4(pos, 1.0)));
}
