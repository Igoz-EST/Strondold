extends RefCounted

## Бараки: коллизия слой 1, как башня.
static func create_barracks() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "Barracks"

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

	body.set_script(preload("res://scripts/barracks_unit.gd"))
	return body
