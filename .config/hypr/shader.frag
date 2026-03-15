#version 300 es
precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);

    // Wahrgenommene Helligkeit
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

    // ---------- 1) Kontrast / tiefere Schatten ----------
    // 1.0 in dunklen Bereichen, 0.0 in hellen
    float shadowMask = 1.0 - smoothstep(0.20, 0.78, luma);

    // Nichtlinear abdunkeln: Weiß bleibt Weiß, Schatten werden kräftiger
    vec3 darkened = pow(color.rgb, vec3(1.28));
    darkened = max(darkened - vec3(0.030 * shadowMask), 0.0);

    color.rgb = mix(color.rgb, darkened, shadowMask);

    // ---------- 2) Warmer Farbton, aber highlights schützen ----------
    // Mehr Wärme in dunklen/mittleren Bereichen, kaum Wärme in hellen
    float warmthMask = 1.0 - smoothstep(0.45, 0.95, luma);

    // Warme Tönung:
    // Rot leicht hoch, Blau merklich runter, Grün nur ganz leicht runter
	vec3 warmTint = vec3(1.05, 0.99, 0.84);

    // Nur anteilig anwenden, damit weiße Schrift nicht "beige" wird
    vec3 warmed = color.rgb * mix(vec3(1.0), warmTint, 0.38 * warmthMask);

    // ---------- 3) Helle Schrift bewusst schützen / minimal pushen ----------
    float highlightMask = smoothstep(0.72, 0.98, luma);

    // Helle Bereiche fast neutral halten
    vec3 neutralizedHighlights = mix(warmed, color.rgb, 0.70 * highlightMask);

    // Ganz leichtes Highlight-Boosting für knackiges Weiß
    vec3 boostedHighlights = pow(neutralizedHighlights, vec3(0.96));
    color.rgb = mix(neutralizedHighlights, boostedHighlights, 0.22 * highlightMask);

    color.rgb = clamp(color.rgb, 0.0, 1.0);
    fragColor = vec4(color.rgb, color.a);
}
