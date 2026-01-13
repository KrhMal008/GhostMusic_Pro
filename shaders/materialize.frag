#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uProgress;
uniform float uTime;

out vec4 fragColor;

float hash12(vec2 p) {
  // A small, fast hash for 2D coords.
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;

  // Pixelated “grain” to make the reveal feel material.
  float scale = mix(260.0, 180.0, smoothstep(0.0, 1.0, uProgress));
  vec2 cell = floor(uv * scale);

  // Keep the noise stable; uTime is reserved for future variants.
  float n = hash12(cell);

  // Smooth threshold: as uProgress grows, more pixels become opaque.
  float edge = 0.06;
  float alpha = smoothstep(n - edge, n + edge, clamp(uProgress, 0.0, 1.0));

  fragColor = vec4(1.0, 1.0, 1.0, alpha);
}
