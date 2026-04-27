extends RefCounted

## Простая башня: коллизия на слое 1 (как земля), чтобы герой обходил.
static func create_tower() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "Tower"

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.2, 1.1)
	col.shape = box
	col.position = Vector3(0.0, 1.1, 0.0)
	body.add_child(col)

	var base_m := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.05, 0.45, 1.05)
	base_m.mesh = base_mesh
	base_m.position.y = 0.225
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = Color(0.38, 0.36, 0.34)
	m0.roughness = 0.88
	base_m.set_surface_override_material(0, m0)
	body.add_child(base_m)

	var mid := MeshInstance3D.new()
	var mid_mesh := BoxMesh.new()
	mid_mesh.size = Vector3(0.75, 1.15, 0.75)
	mid.mesh = mid_mesh
	mid.position.y = 0.95
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = Color(0.55, 0.52, 0.48)
	m1.roughness = 0.75
	mid.set_surface_override_material(0, m1)
	body.add_child(mid)

	var top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.95, 0.35, 0.95)
	top.mesh = top_mesh
	top.position.y = 1.725
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.42, 0.38, 0.36)
	m2.roughness = 0.7
	top.set_surface_override_material(0, m2)
	body.add_child(top)

	return body
