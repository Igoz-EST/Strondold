## Skywatch Tower factory — taller and thinner than standard tower.
extends RefCounted

static func create_skywatch() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	body.name = "SkywatchTower"
	body.add_to_group(&"tower")
	body.add_to_group(&"skywatch_tower")

	# Collision — thinner than standard tower (standard: 3.3 x 6.6 x 3.3)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 10.0, 2.2)
	col.shape = box
	col.position = Vector3(0.0, 5.0, 0.0)
	body.add_child(col)

	# Base platform
	_add_box(body, Vector3(2.4, 0.7, 2.4), Vector3(0.0, 0.35, 0.0), Color(0.38, 0.36, 0.34))
	# Slim shaft
	_add_box(body, Vector3(1.35, 7.8, 1.35), Vector3(0.0, 4.6, 0.0), Color(0.50, 0.48, 0.44))
	# Observation deck
	_add_box(body, Vector3(2.6, 0.45, 2.6), Vector3(0.0, 8.7, 0.0), Color(0.42, 0.40, 0.38))
	# Deck crenellations (4 corners)
	for s in [Vector3(0.85,0,0.85), Vector3(-0.85,0,0.85),
			  Vector3(0.85,0,-0.85), Vector3(-0.85,0,-0.85)]:
		_add_box(body, Vector3(0.42, 0.55, 0.42),
			Vector3(s.x, 9.2, s.z), Color(0.44, 0.42, 0.38))
	# Blue emissive accent bands
	_add_box_emissive(body, Vector3(1.42, 0.14, 1.42), Vector3(0.0, 2.6, 0.0),
		Color(0.30, 0.50, 0.90))
	_add_box_emissive(body, Vector3(1.42, 0.14, 1.42), Vector3(0.0, 6.2, 0.0),
		Color(0.30, 0.50, 0.90))
	# Antenna spire
	_add_box(body, Vector3(0.18, 1.4, 0.18), Vector3(0.0, 10.1, 0.0), Color(0.30, 0.28, 0.26))

	body.set_script(preload("res://scripts/skywatch_unit.gd"))
	return body


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.82
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)


static func _add_box_emissive(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color             = color
	mat.emission_enabled         = true
	mat.emission                 = color
	mat.emission_energy_multiplier = 0.9
	mat.roughness                = 0.35
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
