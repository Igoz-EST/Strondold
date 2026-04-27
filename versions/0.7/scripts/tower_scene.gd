extends RefCounted

## Простая башня: коллизия на слое 1 (как земля), чтобы герой обходил.
static func create_tower() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "Tower"

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

	body.set_script(preload("res://scripts/tower_unit.gd"))
	return body
