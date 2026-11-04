class_name WorldLife
extends Node3D
## Vida en la calle (Pulido 2B): autos que pasan y gente que camina por la
## acera. Es SOLO decoración local: no usa el servidor, no se guarda y no
## cuenta para nada del juego. Cantidad y velocidades en data/world.json.
##
## Los autos y la gente son figuras simples (cajas y la figura chibi del
## personaje) con el estilo toon. Se mueven de un lado al otro y vuelven a
## empezar. Para el teléfono: pocos y muy livianos.

var config: Dictionary = {}
var road_z := 22.0
var sidewalk_z := 17.25
var road_width := 7.0
var length := 600.0

var _cars: Array = []
var _walkers: Array = []
var _time := 0.0
var _rng := RandomNumberGenerator.new()

const CAR_COLORS := ["#e8605a", "#4f8fe0", "#f2c94c", "#58b87a", "#9b6fd1", "#f08a4b"]


func _ready() -> void:
	_rng.seed = 11
	var speed: Array = config.get("car_speed", [5.0, 8.5])
	for i in int(config.get("cars", 3)):
		var car := _make_car(Color.from_string(CAR_COLORS[i % CAR_COLORS.size()], Color.RED))
		var lane := 1.0 if i % 2 == 0 else -1.0
		car.position = Vector3(_rng.randf_range(-60.0, 60.0), 0.0, road_z + lane * road_width * 0.22)
		# Los de un carril van para un lado y los del otro, para el otro.
		car.rotation.y = -PI / 2.0 if lane > 0 else PI / 2.0
		add_child(car)
		_cars.append({"node": car, "speed": _rng.randf_range(speed[0], speed[1]) * (-lane)})
	var walk: Array = config.get("walk_speed", [0.9, 1.4])
	for i in int(config.get("pedestrians", 3)):
		var look := CharacterLook.build({
			"skin": ["#f5c9a6", "#d9a67c", "#8d5a3b"][i % 3],
			"hair": ["#5a3a22", "#222222", "#c9a227"][(i + 1) % 3],
			"shirt": ["#ff8fab", "#6fd1a0", "#ffd166"][i % 3],
			"pants": "#3b4a5e"})
		look.scale = Vector3.ONE * 0.95
		look.position = Vector3(_rng.randf_range(-40.0, 40.0), 0.15, sidewalk_z + _rng.randf_range(-0.5, 0.5))
		add_child(look)
		var direction := 1.0 if i % 2 == 0 else -1.0
		look.rotation.y = PI / 2.0 if direction > 0 else -PI / 2.0
		_walkers.append({"node": look, "speed": _rng.randf_range(walk[0], walk[1]) * direction, "phase": _rng.randf() * 6.0})


func _process(delta: float) -> void:
	_time += delta
	var half := length / 2.0 - 40.0
	for car in _cars:
		var node: Node3D = car["node"]
		node.position.x += car["speed"] * delta
		if absf(node.position.x) > half:
			node.position.x = -signf(car["speed"]) * half
	for walker in _walkers:
		var node: Node3D = walker["node"]
		node.position.x += walker["speed"] * delta
		node.position.y = 0.15 + absf(sin(_time * 7.0 + walker["phase"])) * 0.05
		node.rotation.z = sin(_time * 7.0 + walker["phase"]) * 0.06
		if absf(node.position.x) > 60.0:
			node.position.x = -signf(walker["speed"]) * 60.0


## Un auto: caja de abajo, cabina arriba y cuatro ruedas. Mira hacia +Z.
func _make_car(color: Color) -> Node3D:
	var car := Node3D.new()
	var body_material := Style.toon_material(color)
	HousePieces.add_box(car, Vector3(0, 0.55, 0), Vector3(1.7, 0.6, 3.6), body_material)
	HousePieces.add_box(car, Vector3(0, 1.1, -0.15), Vector3(1.5, 0.55, 1.9), Style.toon_material(color.lightened(0.25)))
	HousePieces.add_box(car, Vector3(0, 1.1, 0.8), Vector3(1.45, 0.4, 0.05), Style.toon_material(Color("#a9d6f5")))
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.3
	wheel.bottom_radius = 0.3
	wheel.height = 0.25
	wheel.radial_segments = 10
	var wheel_material := Style.toon_material(Color("#2b2b33"))
	for x in [-0.85, 0.85]:
		for z in [-1.1, 1.1]:
			var instance := MeshInstance3D.new()
			instance.mesh = wheel
			instance.material_override = wheel_material
			instance.rotation.z = PI / 2.0
			instance.position = Vector3(x, 0.3, z)
			car.add_child(instance)
	return car
