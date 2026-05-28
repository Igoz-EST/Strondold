extends RefCounted

## Простая башня: коллизия на слое 1 (как земля), чтобы герой обходил.
static func create_tower(level: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "Tower"
	body.add_to_group(&"tower")
	body.set_meta(&"tower_level", clampi(level, 1, 3))

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.3, 6.6, 3.3)
	col.shape = box
	col.position = Vector3(0.0, 3.3, 0.0)
	body.add_child(col)

	var base_m := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(3.15, 1.35, 3.15)
	base_m.mesh = base_mesh
	base_m.position.y = 0.675
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = Color(0.38, 0.36, 0.34)
	m0.roughness = 0.88
	base_m.set_surface_override_material(0, m0)
	body.add_child(base_m)

	var mid := MeshInstance3D.new()
	var mid_mesh := BoxMesh.new()
	mid_mesh.size = Vector3(2.25, 3.45, 2.25)
	mid.mesh = mid_mesh
	mid.position.y = 2.85
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = Color(0.55, 0.52, 0.48)
	m1.roughness = 0.75
	mid.set_surface_override_material(0, m1)
	body.add_child(mid)

	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.85, 1.05, 2.85)
	top.mesh = top_mesh
	top.position.y = 5.175
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.42, 0.38, 0.36)
	m2.roughness = 0.7
	top.set_surface_override_material(0, m2)
	body.add_child(top)

	_add_level_visuals(body, level)

	body.set_script(preload("res://scripts/tower_unit.gd"))
	return body


static func add_level_visuals(body: Node3D, level: int) -> void:
	var old := body.get_node_or_null("TowerLevelVisuals")
	if old != null:
		body.remove_child(old)
		old.free()
	_add_level_visuals(body, level)


static func _add_level_visuals(body: Node3D, level: int) -> void:
	var lvl := clampi(level, 1, 3)
	var root := Node3D.new()
	root.name = &"TowerLevelVisuals"
	body.add_child(root)
	if lvl >= 2:
		_add_box(root, Vector3(3.35, 0.32, 0.42), Vector3(0.0, 4.7, 1.62), Color(0.62, 0.58, 0.5))
		_add_box(root, Vector3(3.35, 0.32, 0.42), Vector3(0.0, 4.7, -1.62), Color(0.62, 0.58, 0.5))
		_add_box(root, Vector3(0.42, 0.32, 3.35), Vector3(1.62, 4.7, 0.0), Color(0.62, 0.58, 0.5))
		_add_box(root, Vector3(0.42, 0.32, 3.35), Vector3(-1.62, 4.7, 0.0), Color(0.62, 0.58, 0.5))
		_add_box(root, Vector3(0.55, 0.75, 0.55), Vector3(1.28, 5.55, 1.28), Color(0.44, 0.4, 0.36))
		_add_box(root, Vector3(0.55, 0.75, 0.55), Vector3(-1.28, 5.55, 1.28), Color(0.44, 0.4, 0.36))
		_add_box(root, Vector3(0.55, 0.75, 0.55), Vector3(1.28, 5.55, -1.28), Color(0.44, 0.4, 0.36))
		_add_box(root, Vector3(0.55, 0.75, 0.55), Vector3(-1.28, 5.55, -1.28), Color(0.44, 0.4, 0.36))
	if lvl >= 3:
		_add_box(root, Vector3(1.0, 1.15, 1.0), Vector3(0.0, 6.15, 0.0), Color(0.55, 0.52, 0.46))
		_add_box(root, Vector3(0.18, 1.4, 0.18), Vector3(0.0, 7.25, 0.0), Color(0.28, 0.25, 0.22))
		_add_box(root, Vector3(0.95, 0.28, 0.08), Vector3(0.42, 7.65, 0.0), Color(0.85, 0.62, 0.18))


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_i.mesh = mesh
	mesh_i.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mesh_i.set_surface_override_material(0, mat)
	parent.add_child(mesh_i)
