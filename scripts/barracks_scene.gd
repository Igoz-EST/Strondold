extends RefCounted

## Бараки: коллизия слой 1, как башня.
static func create_barracks(level: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "Barracks"
	body.add_to_group(&"barracks")
	body.set_meta(&"barracks_level", clampi(level, 1, 3))

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.2, 4.2, 4.2)
	col.shape = box
	col.position = Vector3(0.0, 2.1, 0.0)
	body.add_child(col)

	var base_m := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(4.0, 1.2, 4.0)
	base_m.mesh = base_mesh
	base_m.position.y = 0.6
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = Color(0.52, 0.32, 0.22)
	m0.roughness = 0.82
	base_m.set_surface_override_material(0, m0)
	body.add_child(base_m)

	var mid := MeshInstance3D.new()
	var mid_mesh := BoxMesh.new()
	mid_mesh.size = Vector3(3.2, 2.2, 3.2)
	mid.mesh = mid_mesh
	mid.position.y = 2.1
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = Color(0.42, 0.28, 0.2)
	m1.roughness = 0.78
	mid.set_surface_override_material(0, m1)
	body.add_child(mid)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(3.6, 0.5, 3.6)
	roof.mesh = roof_mesh
	roof.position.y = 3.45
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.35, 0.22, 0.16)
	m2.roughness = 0.85
	roof.set_surface_override_material(0, m2)
	body.add_child(roof)

	_add_level_visuals(body, level)

	body.set_script(preload("res://scripts/barracks_unit.gd"))
	return body


static func add_level_visuals(body: Node3D, level: int) -> void:
	var old := body.get_node_or_null("BarracksLevelVisuals")
	if old != null:
		body.remove_child(old)
		old.free()
	_add_level_visuals(body, level)


static func _add_level_visuals(body: Node3D, level: int) -> void:
	var lvl := clampi(level, 1, 3)
	var root := Node3D.new()
	root.name = &"BarracksLevelVisuals"
	body.add_child(root)
	if lvl >= 2:
		_add_box(root, Vector3(4.45, 0.35, 0.32), Vector3(0.0, 3.9, 1.95), Color(0.48, 0.30, 0.18))
		_add_box(root, Vector3(4.45, 0.35, 0.32), Vector3(0.0, 3.9, -1.95), Color(0.48, 0.30, 0.18))
		_add_box(root, Vector3(0.32, 0.35, 4.45), Vector3(1.95, 3.9, 0.0), Color(0.48, 0.30, 0.18))
		_add_box(root, Vector3(0.32, 0.35, 4.45), Vector3(-1.95, 3.9, 0.0), Color(0.48, 0.30, 0.18))
		_add_box(root, Vector3(0.45, 1.0, 0.45), Vector3(1.65, 4.35, 1.65), Color(0.58, 0.36, 0.22))
		_add_box(root, Vector3(0.45, 1.0, 0.45), Vector3(-1.65, 4.35, 1.65), Color(0.58, 0.36, 0.22))
	if lvl >= 3:
		_add_box(root, Vector3(3.2, 0.75, 3.2), Vector3(0.0, 4.65, 0.0), Color(0.34, 0.20, 0.14))
		_add_box(root, Vector3(0.2, 1.5, 0.2), Vector3(0.0, 5.7, 0.0), Color(0.24, 0.18, 0.14))
		_add_box(root, Vector3(1.05, 0.28, 0.08), Vector3(0.45, 6.12, 0.0), Color(0.78, 0.18, 0.12))


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_i.mesh = mesh
	mesh_i.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.84
	mesh_i.set_surface_override_material(0, mat)
	parent.add_child(mesh_i)
