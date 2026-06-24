extends RefCounted

## Factory for the Mission 3 enemy base: a dark keep with a collider and a
## damage-receiving body. Visual + collider only; HP logic lives in enemy_base.gd.

const _DARK_STONE := Color(0.20, 0.19, 0.22)
const _DARK_WALL  := Color(0.26, 0.22, 0.24)
const _ROOF       := Color(0.30, 0.05, 0.06)
const _BANNER     := Color(0.65, 0.08, 0.09)


static func create_enemy_base() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = &"EnemyBase"

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 7.0, 9.0)
	col.shape = box
	col.position = Vector3(0.0, 3.5, 0.0)
	body.add_child(col)

	# Tintable parts are collected so the script can darken them as HP drops.
	var tint_parts: Array[MeshInstance3D] = []

	var base_m := _box(Vector3(9.0, 1.2, 9.0), Vector3(0.0, 0.6, 0.0), _DARK_STONE)
	body.add_child(base_m); tint_parts.append(base_m)

	var keep := _box(Vector3(6.0, 5.0, 6.0), Vector3(0.0, 3.5, 0.0), _DARK_WALL)
	body.add_child(keep); tint_parts.append(keep)

	# Four corner turrets
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var t := _box(Vector3(1.8, 6.5, 1.8), Vector3(sx * 3.6, 3.25, sz * 3.6), _DARK_STONE)
			body.add_child(t); tint_parts.append(t)

	# Red roof prism
	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(6.6, 2.2, 6.6)
	roof.mesh = rm
	roof.position = Vector3(0.0, 7.1, 0.0)
	roof.set_surface_override_material(0, _mat(_ROOF))
	body.add_child(roof); tint_parts.append(roof)

	# Banner (kept bright red — clear "enemy" read)
	var banner := _box(Vector3(0.15, 2.6, 1.4), Vector3(3.08, 4.2, 0.0), _BANNER)
	body.add_child(banner)

	body.set_script(load("res://scripts/enemy_base.gd"))
	body.set_meta(&"tint_parts", tint_parts)
	return body


static func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.set_surface_override_material(0, _mat(color))
	return mi


static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
