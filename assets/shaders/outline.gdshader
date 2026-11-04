// Contorno por geometría invertida (Pulido 2B): la malla se dibuja otra vez,
// un poquito más grande y con las caras de adentro hacia afuera (cull_front),
// toda de un color. Barato en el teléfono (no usa pantalla completa).
//
// El grosor es en PÍXELES (no cambia con el zoom ni con la escala de la
// pieza). Para que las cajas no se "abran" en las esquinas, la dirección
// mezcla la normal (un poco) con la dirección desde el centro de la malla.
shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.17, 0.13, 0.2, 1.0);
uniform float outline_px = 2.2;

void vertex() {
	vec3 dir = normalize(NORMAL + 0.7 * normalize(VERTEX + vec3(0.0001)));
	// En espacio de vista, un poquito más lejos de la cámara (así el contorno
	// nunca "pelea" con la cara de adelante).
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz += normalize(view.xyz) * 0.04;
	vec4 clip = PROJECTION_MATRIX * view;
	vec4 clip_dir = PROJECTION_MATRIX * vec4(mat3(MODELVIEW_MATRIX) * dir, 0.0);
	vec2 offset = normalize(clip_dir.xy + vec2(0.00001)) * outline_px * 2.0 / VIEWPORT_SIZE * clip.w;
	clip.xy += offset;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
