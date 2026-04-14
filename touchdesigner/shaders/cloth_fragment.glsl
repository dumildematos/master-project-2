// Sentio — Cloth Fragment Shader
// Iridescent fabric effect driven by Sentio emotion parameters.
//
// Uniforms:
//   uColorHue     — float 0.0–1.0  (normalised from 0–360)
//   uBrightness   — float 0.0–1.0
//   uDistortion   — float 0.0–1.0  (adds shimmer intensity)
//   uTime         — float (seconds)

uniform float uColorHue;
uniform float uBrightness;
uniform float uDistortion;
uniform float uTime;

in vec4  vPos;
in vec3  vNormal;
out vec4 fragColor;

// HSV → RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec3  normal   = normalize(vNormal);
    vec3  viewDir  = normalize(-vPos.xyz);

    // View-angle iridescence: shift hue based on angle to camera
    float rimAngle = 1.0 - max(dot(normal, viewDir), 0.0);
    float shimmer  = rimAngle * uDistortion * 0.25;
    float hue      = fract(uColorHue + shimmer + sin(uTime * 0.3) * 0.02);

    // Fabric saturation is higher at glancing angles
    float sat = 0.55 + rimAngle * 0.35;

    vec3 baseColor = hsv2rgb(vec3(hue, sat, uBrightness));

    // Soft specular highlight
    vec3  lightDir = normalize(vec3(0.5, 1.0, 0.8));
    float spec     = pow(max(dot(reflect(-lightDir, normal), viewDir), 0.0), 32.0);
    vec3  color    = baseColor + spec * 0.35 * uBrightness;

    // Subtle dark edge (fabric occlusion feel)
    float edge = pow(1.0 - rimAngle, 3.0);
    color *= 0.6 + 0.4 * edge;

    fragColor = TDOutputSwizzle(vec4(color, 1.0));
}
