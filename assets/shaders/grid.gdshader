// Cuadrícula de construcción: dibuja líneas finas cada 1 metro sobre el lote.
// Se aplica a un plano del tamaño del lote; el resto es transparente.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform vec4 border_color : source_color = vec4(1.0, 0.85, 0.3, 0.9);
// Tamaño del lote en celdas (lo pone el código).
uniform vec2 lot_size = vec2(12.0, 12.0);

varying vec2 cell_pos;

void vertex() {
	// El plano está centrado: se pasa a "metros desde la esquina del lote".
	cell_pos = VERTEX.xz + lot_size * 0.5;
}

void fragment() {
	// Distancia (en píxeles) a la línea más cercana: líneas siempre finas.
	vec2 width = fwidth(cell_pos);
	vec2 dist = abs(fract(cell_pos - 0.5) - 0.5) / width;
	float line = 1.0 - clamp(min(dist.x, dist.y), 0.0, 1.0);

	// Borde del lote más marcado.
	vec2 edge = min(cell_pos, lot_size - cell_pos) / width;
	float border = 1.0 - clamp(min(edge.x, edge.y) - 1.0, 0.0, 1.0);

	vec4 color = mix(line_color, border_color, border);
	ALBEDO = color.rgb;
	ALPHA = color.a * max(line, border);
}
