// Pulido 3C: material "invisible" que solo sirve para llevar el contorno.
// No dibuja nada propio (descarta todos los píxeles); su "next_pass" es el
// contorno toon. Así una pared hecha de varios tramos puede tener UN solo
// contorno alrededor de toda su silueta, sin líneas entre un tramo y otro.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

void fragment() {
	discard;
}
