extends RefCounted

## Дом: +5 к максимуму населения. Без уровней. Слой 1 (земля).


static func create_house() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = &"House"

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.6, 3.0)
	col.shape = box
	col.position = Vector3(0.0, 1.3, 0.0)
	body.add_child(col)

	var base_m := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(2.95, 0.3, 2.95)
	base_m.mesh = base_mesh
	base_m.position.y = 0.15
	var m0 := StandardMaterial3D.new()
	m0.albedo_color = Color(0.40, 0.38, 0.36)
	m0.roughness = 0.9
	base_m.set_surface_override_material(0, m0)
	body.add_child(base_m)

	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(2.8, 1.5, 2.8)
	wall.mesh = wm
	wall.position.y = 1.05
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = Color(0.78, 0.66, 0.46)
	m1.roughness = 0.85
	wall.set_surface_override_material(0, m1)
	body.add_child(wall)

	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(3.2, 1.0, 3.2)
	roof.mesh = rm
	roof.position.y = 2.3
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.55, 0.16, 0.10)
	m2.roughness = 0.8
	roof.set_surface_override_material(0, m2)
	body.add_child(roof)

	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.8, 1.15, 0.1)
	door.mesh = dm
	door.position = Vector3(0.0, 0.88, 1.42)
	var m3 := StandardMaterial3D.new()
	m3.albedo_color = Color(0.30, 0.20, 0.12)
	m3.roughness = 0.9
	door.set_surface_override_material(0, m3)
	body.add_child(door)

	body.set_script(preload("res://scripts/house_unit.gd"))
	return body
