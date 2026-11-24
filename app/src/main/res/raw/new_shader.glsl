#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform vec2 resolution;
uniform float time;

void main() {
    vec2 uv = gl_FragCoord.xy / max(resolution, vec2(1.0));
    float bend = sin(uv.x * 5.2 + time * 0.35) * 0.13;
    float layers = fract((uv.y + bend + uv.x * 0.32) * 5.0);
    vec3 violet = vec3(0.24, 0.12, 0.42);
    vec3 iris = vec3(0.78, 0.47, 0.91);
    vec3 coral = vec3(0.99, 0.70, 0.59);
    vec3 tone = mix(violet, iris, smoothstep(0.06, 0.86, layers));
    tone = mix(tone, coral, smoothstep(0.87, 1.0, layers));
    gl_FragColor = vec4(tone, 1.0);
}
