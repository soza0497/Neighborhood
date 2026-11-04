// Bloques de la isla (Isla 1A): estilo toon de 3 tonos, pero el color sale de la
// malla (color por vértice) en vez de un parámetro. Así UNA sola malla puede llevar
// muchas casas de colores distintos y se dibuja con UNA sola llamada de dibujo.
// Los tonos y umbrales se ponen desde IslandMaterials (mismos valores que toon.gdshader).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 tones = vec3(0.62, 0.84, 1.0);
uniform vec2 thresholds = vec2(0.28, 0.7);

void fragment() {
	// COLOR llega en espacio lineal (IslandMeshKit ya lo convierte).
	ALBEDO = COLOR.rgb;
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
