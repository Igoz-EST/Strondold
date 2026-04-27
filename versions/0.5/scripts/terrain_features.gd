extends Node3D

## Дополнительный рельеф: бугры, гряды, низкие «гребни» — добавляется к родителю (Main), затем узел удаляется.


func _ready() -> void:
	var w := get_parent()
	if w == null:
		return

	_add_sphere_hill(w, Vector3(68, 0, -22), 5.5, -3.05, Color(0.2, 0.34, 0.15))
	_add_sphere_hill(w, Vector3(-78, 0, 12), 4.2, -2.45, Color(0.18, 0.36, 0.14))
	_add_sphere_hill(w, Vector3(22, 0, 88), 4.8, -2.9, Color(0.21, 0.35, 0.16))
	_add_sphere_hill(w, Vector3(-35, 0, -88), 3.8, -2.2, Color(0.19, 0.33, 0.15))
	_add_sphere_hill(w, Vector3(95, 0, 58), 3.5, -2.0, Color(0.2, 0.32, 0.14))

	_add_ridge(w, Vector3(-12, 0, -102), 22.0, Vector3(48, 1.1, 5.5), Color(0.17, 0.3, 0.13))
	_add_ridge(w, Vector3(88, 0, 18), -38.0, Vector3(42, 1.0, 4.8), Color(0.18, 0.31, 0.14))
	_add_ridge(w, Vector3(-92, 0, -38), 55.0, Vector3(36, 1.2, 6.0), Color(0.16, 0.29, 0.14))
	_add_ridge(w, Vector3(5, 0, 102), 8.0, Vector3(55, 0.95, 4.2), Color(0.19, 0.32, 0.15))

	_add_mesa(w, Vector3(-68, 0, 72), Vector3(14, 1.8, 12), Color(0.22, 0.37, 0.16))
	_add_mesa(w, Vector3(48, 0, -88), Vector3(11, 1.5, 10), Color(0.2, 0.34, 0.15))

	queue_free()


func _add_sphere_hill(world: Node, pos: Vector3, radius: float, center_y: float, col: Color) -> void:
	var body := StaticBody3D.new()
	body.add_to_group(&"terrain")
	body.collision_layer = 1
	body.position = pos
	world.add_child(body)

	var col_sh := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = radius
	col_sh.shape = sp
	col_sh.position = Vector3(0.0, center_y, 0.0)
	body.add_child(col_sh)

	var mesh_i := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mesh_i.mesh = sm
	mesh_i.position = col_sh.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mesh_i.set_surface_override_material(0, mat)
	body.add_child(mesh_i)


func _add_ridge(world: Node, pos: Vector3, rot_y_deg: float, box_size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.add_to_group(&"terrain")
	body.collision_layer = 1
	body.position = pos
	body.rotation_degrees.y = rot_y_deg
	world.add_child(body)

	var col_sh := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = box_size
	col_sh.shape = bx
	col_sh.position.y = box_size.y * 0.5
	body.add_child(col_sh)

	var mesh_i := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mesh_i.mesh = bm
	mesh_i.position = col_sh.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.92
	mesh_i.set_surface_override_material(0, mat)
	body.add_child(mesh_i)


func _add_mesa(world: Node, pos: Vector3, size: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.add_to_group(&"terrain")
	body.collision_layer = 1
	body.position = pos
	world.add_child(body)

	var col_sh := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	col_sh.shape = bx
	col_sh.position.y = size.y * 0.5
	body.add_child(col_sh)

	var mesh_i := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh_i.mesh = bm
	mesh_i.position = col_sh.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.88
	mesh_i.set_surface_override_material(0, mat)
	body.add_child(mesh_i)
