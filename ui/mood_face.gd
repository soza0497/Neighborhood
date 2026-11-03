@tool
class_name MoodFace
extends Control
## Carita que muestra una emoción (feliz, cansado, enojado...).
## Se dibuja con círculos y líneas: es arte propio del juego, no emojis del
## sistema (que además no se ven igual en todos los teléfonos).

## Color de la cara de cada emoción.
const FACE_COLORS := {
	"happy": Color("#ffd166"), "calm": Color("#ffe6a3"), "tired": Color("#c9d3ff"),
	"angry": Color("#ff8f6b"), "bored": Color("#d9d4c7"), "uncomfortable": Color("#b8e0a0"),
	"sad": Color("#9fc5ff"),
}
const INK := Color(0.2, 0.16, 0.18)

## Emoción a dibujar (ver CharacterData.EMOTIONS).
@export var emotion := "calm":
	set(value):
		emotion = value
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var c := size / 2.0
	var line := maxf(r * 0.09, 1.5)
	draw_circle(c, r, FACE_COLORS.get(emotion, FACE_COLORS["calm"]))
	draw_arc(c, r - line / 2.0, 0.0, TAU, 32, INK, line, true)

	var eye_l := c + Vector2(-r * 0.35, -r * 0.15)
	var eye_r := c + Vector2(r * 0.35, -r * 0.15)
	var mouth := c + Vector2(0, r * 0.35)

	# Ojos.
	match emotion:
		"tired":
			for eye in [eye_l, eye_r]:
				draw_line(eye - Vector2(r * 0.15, 0), eye + Vector2(r * 0.15, 0), INK, line)
		"bored":
			for eye in [eye_l, eye_r]:
				draw_line(eye - Vector2(r * 0.15, 0), eye + Vector2(r * 0.15, 0), INK, line)
				draw_circle(eye + Vector2(r * 0.06, r * 0.06), r * 0.07, INK)
		_:
			for eye in [eye_l, eye_r]:
				draw_circle(eye, r * 0.1, INK)

	# Cejas (enojado).
	if emotion == "angry":
		draw_line(eye_l + Vector2(-r * 0.18, -r * 0.25), eye_l + Vector2(r * 0.15, -r * 0.12), INK, line)
		draw_line(eye_r + Vector2(r * 0.18, -r * 0.25), eye_r + Vector2(-r * 0.15, -r * 0.12), INK, line)

	# Boca.
	match emotion:
		"happy":
			draw_arc(mouth - Vector2(0, r * 0.2), r * 0.38, 0.15 * PI, 0.85 * PI, 16, INK, line, true)
		"calm":
			draw_arc(mouth - Vector2(0, r * 0.15), r * 0.22, 0.25 * PI, 0.75 * PI, 12, INK, line, true)
		"angry", "sad":
			draw_arc(mouth + Vector2(0, r * 0.2), r * 0.28, 1.2 * PI, 1.8 * PI, 12, INK, line, true)
		"uncomfortable":
			var points := PackedVector2Array()
			for i in 7:
				points.append(mouth + Vector2((i - 3) * r * 0.1, (r * 0.06) * (1 if i % 2 == 0 else -1)))
			draw_polyline(points, INK, line, true)
		_:
			draw_line(mouth - Vector2(r * 0.2, 0), mouth + Vector2(r * 0.2, 0), INK, line)

	# Lágrima (triste) y "z" (cansado).
	if emotion == "sad":
		draw_circle(eye_r + Vector2(r * 0.05, r * 0.3), r * 0.09, Color("#3d8bff"))
	if emotion == "tired":
		var z := c + Vector2(r * 0.55, -r * 0.75)
		var s := r * 0.22
		draw_polyline(PackedVector2Array([z, z + Vector2(s, 0), z + Vector2(0, s), z + Vector2(s, s)]), INK, line * 0.8, true)
