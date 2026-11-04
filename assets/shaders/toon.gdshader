// Shader toon (Pulido 2B): sombras DURAS en 3 tonos (estilo dibujo animado).
// El color base y los tonos vienen de data/style.json (ver Style, autoload).
// Primera pasada de cada pieza; la segunda (contorno) es outline.gdshader y
// se pega como "next_pass" (ver style.gd).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
// Textura opcional (para modelos .glb con imagen); sin textura = blanco.
uniform sampler2D albedo_tex : source_color, hint_default_white;
// Cuánta luz recibe cada tono: sombra, medio, luz (de oscuro a claro).
uniform vec3 tones = vec3(0.5, 0.78, 1.0);
// Dónde cambia de tono (luz · normal, de 0 a 1).
uniform vec2 thresholds = vec2(0.28, 0.7);
// Brillo extra (lo usa la obra prevista para "brillar").
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform vec3 glow_color : source_color = vec3(0.75, 0.95, 1.0);

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_tex, UV).rgb;
	EMISSION = glow_color * glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float nl = dot(NORMAL, LIGHT) * ATTENUATION;
	float tone = tones.x;
	if (nl > thresholds.y) {
		tone = tones.z;
	} else if (nl > thresholds.x) {
		tone = tones.y;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * tone * (1.0 / PI);
}
