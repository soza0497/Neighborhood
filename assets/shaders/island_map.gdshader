// Mapa estilizado de la isla (LOD 3, Isla 1A): sin luces, color plano por vértice.
// Una sola malla baja con todos los lotes coloreados = una sola llamada de dibujo.
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
}
