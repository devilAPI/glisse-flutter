#version 460 core

// Glisse's lens, as one fragment shader.
//
// Ported from glisse (https://github.com/0kzh/glisse, MIT), whose lens is an
// SVG filter built from displacement maps drawn on a canvas. Here the maps
// are worked out per fragment instead: the pull of a rounded bezel (or of a
// shallow dome) at each point of the lens, the light caught on its rim, and
// the rim's painted light and edge line. One pass samples what is under the
// glass, bends it at the rim (red, green and blue each a little differently),
// frosts it, tints it and lights it.
//
// The same shader runs in three settings:
//  * texture mode 0: nothing is sampled; only the tint and the rim are drawn.
//  * texture mode 1: an image (a captured backdrop, or content of the glass's
//    own such as a switch's track) is sampled through an affine map.
//  * texture mode 2: Impeller's backdrop filter (ImageFilter.shader), where
//    the engine binds the live backdrop and fragment coordinates are its
//    pixels.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // The bound texture's size, in its pixels (mode 2).
uniform vec4 uRect;     // The lens as placed, in local px: x, y, width, height.
uniform vec4 uShape;    // The lens's own shape: width, height, corner radius, bezel depth.
uniform vec4 uBend;     // reach (local px), dispersion, profile (0 dome, 1 bezel), splay.
uniform vec4 uDome;     // Dome arcs: radius across, scale across, radius down, scale down.
uniform vec4 uUvX;      // u = a x + b y + c; w: 1 when outside the image is clear.
uniform vec4 uUvY;      // v = d x + e y + f.
uniform vec4 uFrost;    // blur sigma (local px), saturation, brightness, texture mode.
uniform vec4 uLightA;   // shine, cos(angle), sin(angle), glow.
uniform vec4 uLightB;   // spread, glow power, edge, edge width.
uniform vec4 uLightC;   // edge power, ink (0 none, 1 light page, 2 dark page), stand-in, local px per device px.
uniform vec4 uTint;     // A colour laid over, premultiplied.
uniform vec4 uEdge;     // The edge line's colour, premultiplied.
uniform vec4 uRim;      // rim mode (0 none, 1 glass, 2 selection, 3 bright selection), shine, opacity, unused.
uniform vec4 uFilter;   // Mode 2: local x = a fx + b fy + c from the fragment's coordinates; w: enabled.
uniform vec4 uFilterY;  // Mode 2: local y = d fx + e fy + f.

uniform sampler2D uTexture;

out vec4 fragColor;

const float SQRT2 = 1.41421356;
const float RIM_WIDTH = 1.22;
const float EDGE_WIDTH = 0.5;

float sdRound(vec2 p, vec2 h, float r) {
  vec2 q = abs(p) - h + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// The nearest edge's outward normal, turning round corners of radius r.
vec2 normalOf(vec2 p, vec2 h, float r) {
  vec2 q = abs(p) - h + r;
  if (q.x > 0.0 && q.y > 0.0) {
    return sign(p) * q / length(q);
  }
  if (q.x > q.y) {
    return vec2(sign(p.x), 0.0);
  }
  return vec2(0.0, sign(p.y));
}

float tanhApprox(float x) {
  float e = exp(2.0 * clamp(x, -10.0, 10.0));
  return (e - 1.0) / (e + 1.0);
}

// erf(x) ~ tanh(sqrt(pi) x)
float erfApprox(float x) {
  return tanhApprox(1.7724538509 * x);
}

// How far a rounded bezel bends, from 1 at its edge to 0 where it meets the
// flat of the glass: a ray straight down through a squircle's surface, bent
// by glass of index 1.5, lands further in by the tangent of how far it
// turned, times the glass under it.
float bezel(float t) {
  t = clamp(t, 0.004, 1.0);
  float inv = 1.0 - t;
  float surface = pow(1.0 - inv * inv * inv * inv, 0.25);
  float incident = atan(inv * inv * inv, surface * surface * surface);
  float refracted = asin(sin(incident) / 1.5);
  return tan(incident - refracted) * (0.6 + surface) / 0.98495116;
}

float domeSlope(float x, float radius, float scale) {
  float inside = min(x, 0.999 * radius);
  return inside / sqrt(radius * radius - inside * inside) * scale;
}

vec4 tex(vec2 p) {
  vec2 uv = vec2(dot(uUvX.xy, p) + uUvX.z, dot(uUvY.xy, p) + uUvY.z);
  if (uFrost.w > 1.5) {
    // The backdrop's own pixels, as the engine sized its texture.
    uv = uv / uSize;
  }
  if (uUvX.w > 0.5 && (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0)) {
    return vec4(0.0);
  }
#ifdef IMPELLER_TARGET_OPENGLES
  // On OpenGL, Impeller's render targets are upside down: the backdrop it
  // binds, and every image glass samples, as all of them are drawn into
  // (a copied backdrop, or a widget's recorded content).
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
}

// A frosted sample: a Gaussian of deviation uFrost.x, as three rings of taps.
vec4 frost(vec2 p) {
  float s = uFrost.x;
  if (s < 0.2) {
    return tex(p);
  }
  vec4 sum = tex(p);
  float total = 1.0;
  float r1 = 0.65 * s;
  float w1 = 0.8095;  // exp(-0.65^2 / 2)
  sum += w1 * (tex(p + vec2(r1, 0.0)) + tex(p + vec2(-r1, 0.0)) +
               tex(p + vec2(0.5 * r1, 0.866 * r1)) + tex(p + vec2(-0.5 * r1, 0.866 * r1)) +
               tex(p + vec2(0.5 * r1, -0.866 * r1)) + tex(p + vec2(-0.5 * r1, -0.866 * r1)));
  total += 6.0 * w1;
  float r2 = 1.35 * s;
  float w2 = 0.4020;  // exp(-1.35^2 / 2)
  float a2 = 0.7071 * r2;
  sum += w2 * (tex(p + vec2(r2, 0.0)) + tex(p + vec2(-r2, 0.0)) +
               tex(p + vec2(0.0, r2)) + tex(p + vec2(0.0, -r2)) +
               tex(p + vec2(a2, a2)) + tex(p + vec2(-a2, a2)) +
               tex(p + vec2(a2, -a2)) + tex(p + vec2(-a2, -a2)));
  total += 8.0 * w2;
  float r3 = 2.1 * s;
  float w3 = 0.1103;  // exp(-2.1^2 / 2)
  float c3 = 0.9239 * r3;
  float s3 = 0.3827 * r3;
  sum += w3 * (tex(p + vec2(c3, s3)) + tex(p + vec2(-c3, s3)) +
               tex(p + vec2(c3, -s3)) + tex(p + vec2(-c3, -s3)) +
               tex(p + vec2(s3, c3)) + tex(p + vec2(-s3, c3)) +
               tex(p + vec2(s3, -c3)) + tex(p + vec2(-s3, -c3)));
  total += 8.0 * w3;
  return sum / total;
}

vec3 saturateRgb(vec3 c, float s) {
  return vec3(
    (0.213 + 0.787 * s) * c.r + (0.715 - 0.715 * s) * c.g + (0.072 - 0.072 * s) * c.b,
    (0.213 - 0.213 * s) * c.r + (0.715 + 0.285 * s) * c.g + (0.072 - 0.072 * s) * c.b,
    (0.213 - 0.213 * s) * c.r + (0.715 - 0.715 * s) * c.g + (0.072 + 0.928 * s) * c.b);
}

vec4 over(vec4 top, vec4 bottom) {
  return top + bottom * (1.0 - top.a);
}

void main() {
  vec2 fc = FlutterFragCoord().xy;
  bool filtered = uFilter.w > 0.5;
  vec2 p = filtered ? vec2(dot(uFilter.xy, fc) + uFilter.z, dot(uFilterY.xy, fc) + uFilterY.z) : fc;

  // Where p falls on the lens's own shape, centred on its middle.
  vec2 mapSize = uShape.xy;
  vec2 hs = mapSize * 0.5;
  vec2 toMap = mapSize / max(uRect.zw, vec2(0.0001));
  vec2 m = (p - uRect.xy) * toMap - hs;
  float radius = clamp(uShape.z, 0.0, min(hs.x, hs.y));
  float depth = uShape.w;
  float edge = sdRound(m, hs, radius);
  // Device pixels per map px, for smoothing the edge over one pixel.
  float mapPixel = uLightC.w * max(toMap.x, toMap.y);
  float coverage = clamp(0.5 - edge / max(mapPixel, 0.0001), 0.0, 1.0);

  float mode = uFrost.w;
  vec4 original = vec4(0.0);
  if (filtered) {
    original = tex(p);
  }
  if (coverage <= 0.0) {
    fragColor = original;
    return;
  }

  // The pull: where to (outwards), and how much.
  vec2 dir = vec2(0.0);
  float amount = 0.0;
  if (edge < 0.0) {
    if (uBend.z > 0.5) {
      if (depth > 0.0 && -edge < depth) {
        float roundR = clamp(max(radius, depth), 0.0, min(hs.x, hs.y));
        dir = normalOf(m, hs, roundR);
        amount = bezel(-edge / depth);
      }
    } else {
      vec2 a = abs(m);
      float dx = uDome.x > 0.0 ? sign(m.x) * domeSlope(a.x, uDome.x, uDome.y) : clamp(m.x / hs.x, -1.0, 1.0);
      float dy = uDome.z > 0.0 ? sign(m.y) * domeSlope(a.y, uDome.z, uDome.w) : clamp(m.y / hs.y, -1.0, 1.0);
      float splay = uBend.w;
      float reachIn = 0.5 * min(hs.x, hs.y);
      if (splay < 1.0 && reachIn > 0.0) {
        float keepX = max(0.0, 1.0 - (hs.y - a.y) / reachIn) * (1.0 - splay);
        float keepY = max(0.0, 1.0 - (hs.x - a.x) / reachIn) * (1.0 - splay);
        if (keepX > 0.001 || keepY > 0.001) {
          float before = length(vec2(dx, dy));
          dx *= 1.0 - keepX;
          dy *= 1.0 - keepY;
          float after = length(vec2(dx, dy));
          if (after > 0.001) {
            dx *= before / after;
            dy *= before / after;
          }
        }
      }
      dir = vec2(dx, dy);
      vec2 inner = max(hs - depth, vec2(0.0));
      float innerRadius = clamp(radius, 0.0, min(inner.x, inner.y));
      float ramp = depth > 0.0 ? 1.0 / (depth * SQRT2) : 1e6;
      amount = 0.5 * (1.0 + erfApprox(sdRound(m, inner, innerRadius) * ramp));
    }
  }
  // Fully in once the pull reaches about a twentieth of its strength, and
  // smoothed over the last pixel at the edge.
  float bends = clamp(min(min(amount * 20.0, -edge), 1.0), 0.0, 1.0);

  vec4 base = vec4(0.0);
  if (mode > 0.5) {
    vec4 plain = frost(p);
    base = plain;
    if (bends > 0.0 && uBend.x > 0.0) {
      // Each colour's ray, pulled from further in as far as that colour bends.
      // The map stretches over the lens as placed; the pull is in local px.
      vec2 pull = dir * amount * 0.5 * uBend.x;
      float d = uBend.y;
      vec4 red = frost(p - pull * (1.0 + 0.2 * d));
      vec4 green = frost(p - pull * (1.0 + 0.1 * d));
      vec4 blue = frost(p - pull);
      vec4 bent;
      if (uLightC.y > 0.5) {
        // Ink: the alpha of whichever colour covers most, and each colour's
        // own coverage made up from the page under it.
        float most = max(red.a, max(green.a, blue.a));
        float page = uLightC.y < 1.5 ? 1.0 : 0.0;
        bent = vec4(red.r + page * (most - red.a),
                    green.g + page * (most - green.a),
                    blue.b + page * (most - blue.a),
                    most);
      } else {
        bent = vec4(red.r, green.g, blue.b, (red.a + green.a + blue.a) / 3.0);
      }

      // The light caught on the rim.
      float shine = uLightA.x;
      if (shine != 0.0) {
        float facing = abs(clamp(m.x / hs.x, -1.0, 1.0) * uLightA.y + clamp(m.y / hs.y, -1.0, 1.0) * uLightA.z);
        float spread = uLightB.x;
        float glowStart = (1.0 - spread) * SQRT2;
        float glowRange = spread * SQRT2;
        float glow = glowRange > 0.001
          ? uLightA.w * pow(clamp((facing - glowStart) / glowRange, 0.0, 1.0), uLightB.y) * amount
          : 0.0;
        float rimLight = uLightB.z * max(0.0, 1.0 + edge / uLightB.w) * pow(facing, uLightC.x);
        float caught = min(1.0, glow + rimLight) * 127.0 / 255.0;
        if (shine > 0.0) {
          bent = clamp(bent + shine * caught, 0.0, 1.0);
        } else {
          bent.rgb = bent.rgb * clamp(1.0 + shine * caught, 0.0, 1.0);
        }
      }
      base = bent * bends + plain * (1.0 - bends);
    }
    base.rgb = clamp(saturateRgb(base.rgb, uFrost.y) * uFrost.z, 0.0, base.a);
  }

  vec4 color = over(uTint, base);

  // The light painted on the rim.
  float rimMode = uRim.x;
  if (rimMode > 0.5) {
    float inside = -edge;
    vec4 rim = vec4(0.0);
    if (rimMode < 1.5) {
      // Glass's rim, as iOS 26.1 draws it: a line brightest at the very edge
      // and gone 1.2px in, over the glass's 0.5px edge line.
      float density = 1.0 / max(mapPixel, 0.0001);
      float halfPixel = 0.5 / density;
      if (inside >= -halfPixel && inside <= 2.0 * RIM_WIDTH) {
        vec2 n = normalOf(m, hs, radius);
        float facing = abs(n.x + n.y);
        float along = max(0.0, inside) / (RIM_WIDTH * sqrt(max(1.0, facing)));
        float cover = clamp((inside + halfPixel) * density, 0.0, 1.0);
        float lined = clamp((min(EDGE_WIDTH, inside + halfPixel) - max(0.0, inside - halfPixel)) * density, 0.0, 1.0);
        float light = along < 1.0 ? uRim.y * pow(min(1.0, facing), 1.5) * (1.0 - pow(along, 1.5)) * cover : 0.0;
        float line = uEdge.a * lined * (1.0 - light);
        vec3 edgeRgb = uEdge.a > 0.0 ? uEdge.rgb / uEdge.a : vec3(0.0);
        rim = vec4(vec3(light) + edgeRgb * line, light + line);
      }
    } else if (inside >= 0.0) {
      vec2 q = abs(m) - (hs - radius);
      vec2 o = max(q, 0.0);
      float len = length(o);
      vec2 n = len > 0.0 ? o / len * sign(m) : (q.x > q.y ? vec2(sign(m.x), 0.0) : vec2(0.0, sign(m.y)));
      float lightDir = -(n.x + n.y) * 0.70710678;
      float glint = pow(max(lightDir, 0.0), 3.0);
      float reflected = pow(max(-lightDir, 0.0), 3.0);
      if (rimMode < 2.5) {
        vec3 bands = exp(-pow((vec3(inside) - vec3(0.18, 0.42, 0.66)) / 0.22, vec3(2.0)));
        float peak = max(bands.x, max(bands.y, bands.z));
        float a = clamp(peak * (0.06 + 0.8 * glint + 0.35 * reflected) * 0.85, 0.0, 1.0);
        vec3 c = 0.65 + 0.35 * (peak > 0.0 ? bands / peak : vec3(0.0));
        rim = vec4(c * a, a);
      } else {
        vec3 wide = exp(-pow((vec3(inside) - vec3(0.4, 0.5, 0.6)) / 0.4, vec3(2.0)));
        float top = max(wide.x, max(wide.y, wide.z));
        float a = clamp(top * (0.55 + 0.3 * glint + 0.15 * reflected), 0.0, 1.0);
        vec3 c = 0.85 + 0.15 * (top > 0.0 ? wide / top : vec3(0.0));
        rim = vec4(c * a, a);
      }
    }
    color = over(rim * uRim.z, color);
  }

  fragColor = color * coverage + original * (1.0 - coverage);
}
