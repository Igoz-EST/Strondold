extends RefCounted

## Склад: слой 1 (земля). Рабочие разгружают руду в точку `get_unload_anchor_global` если склад ближе базы.


static func create_warehouse() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = &"Warehouse"

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 2.2, 3.4)
	col.shape = box
	col.position = Vector3(0.0, 1.1, 0.0)
	body.add_child(col)

	var base_m := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(3.55, 0.35, 3.3)
	base_m.mesh = base_mesh
	base_m.position.y = 0.175
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = Color(0.38, 0.36, 0.34)
	m0.roughness = 0.88
	base_m.set_surface_override_material(0, m0)
	body.add_child(base_m)

	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(3.45, 1.55, 3.25)
	wall.mesh = wm
	wall.position.y = 1.025
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = Color(0.52, 0.42, 0.28)
	m1.roughness = 0.82
	wall.set_surface_override_material(0, m1)
	body.add_child(wall)

	var trim := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(3.5, 0.12, 3.32)
	trim.mesh = tm
	trim.position.y = 1.68
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.28, 0.3, 0.35)
	m2.roughness = 0.75
	trim.set_surface_override_material(0, m2)
	body.add_child(trim)

	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.1, 1.25, 0.12)
	door.mesh = dm
	door.position = Vector3(0.0, 0.95, 1.68)
	var m3 := StandardMaterial3D.new()
	m3.albedo_color = Color(0.22, 0.2, 0.18)
	m3.roughness = 0.9
	door.set_surface_override_material(0, m3)
	body.add_child(door)

	body.set_script(preload("res://scripts/warehouse_unit.gd"))
	return body
