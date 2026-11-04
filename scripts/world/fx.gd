class_name Fx
## Efectos de partículas simples (Pulido 2B): humo blanco, destellos y
## hojas. Usan CPUParticles3D (funcionan igual en todos los teléfonos) y se
## borran solos al terminar.

## Un soplido de humo blanco en `position` (coordenadas del padre).
static func puff(parent: Node3D, position: Vector3, amount := 18, color := Color(1, 1, 1, 0.85)) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = 1.1
	particles.explosiveness = 0.9
	particles.direction = Vector3.UP
	particles.spread = 70.0
	particles.initial_velocity_min = 0.6
	particles.initial_velocity_max = 1.6
	particles.gravity = Vector3(0, 0.4, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	particles.position = position
	parent.add_child(particles)
	var timer := parent.get_tree().create_timer(particles.lifetime + 0.5)
	timer.timeout.connect(particles.queue_free)
	return particles


## Hojitas que caen despacio sobre una zona (decoración del jardín).
static func falling_leaves(parent: Node3D, center: Vector3, extents: Vector3, amount := 14) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 9.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = extents
	particles.direction = Vector3.DOWN
	particles.spread = 15.0
	particles.initial_velocity_min = 0.1
	particles.initial_velocity_max = 0.3
	particles.gravity = Vector3(0.15, -0.35, 0.05)
	particles.angular_velocity_min = -60.0
	particles.angular_velocity_max = 60.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.18, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#79c75a")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	particles.mesh = mesh
	particles.position = center
	parent.add_child(particles)
	return particles
