// Cuadrícula de construcción: dibuja líneas finas cada 1 metro sobre el lote.
// Se aplica a un plano del tamaño del lote; el resto es transparente.
// Pulido 6A (5): solo se dibuja DENTRO de la valla (la parcela usable). Una
// textura chica (1 píxel = 1 celda del lote, blanco = usable) dice dónde; fuera
// no hay líneas, y el borde amarillo marca el contorno de la parte usable.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.55);
uniform vec4 border_color : source_color = vec4(1.0, 0.85, 0.3, 0.9);
// Tamaño del lote en celdas (lo pone el código).
uniform vec2 lot_size = vec2(12.0, 12.0);
// Máscara de la parcela usable (la arma el código a partir de las zonas abiertas).
uniform sampler2D zone_mask : filter_nearest, repeat_disable;
// 0.0 = sin máscara (se dibuja todo el lote, como antes).
uniform float use_mask = 0.0;

float usable(vec2 p) {
	if (use_mask < 0.5) {
		return (p.x >= 0.0 && p.y >= 0.0 && p.x <= lot_size.x && p.y <= lot_size.y) ? 1.0 : 0.0;
	}
	if (p.x < 0.0 || p.y < 0.0 || p.x >= lot_size.x || p.y >= lot_size.y) {
		return 0.0;
	}
	return texture(zone_mask, p / lot_size).r > 0.5 ? 1.0 : 0.0;
}

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

	// Borde de la parte usable más marcado: donde un vecino cercano ya no es usable.
	float inside = usable(cell_pos);
	vec2 reach = width * 1.5;
	float around = usable(cell_pos + vec2(reach.x, 0.0)) * usable(cell_pos - vec2(reach.x, 0.0))
		* usable(cell_pos + vec2(0.0, reach.y)) * usable(cell_pos - vec2(0.0, reach.y));
	float border = inside * (1.0 - around);

	vec4 color = mix(line_color, border_color, border);
	ALBEDO = color.rgb;
	ALPHA = color.a * max(line * inside, border);
}
