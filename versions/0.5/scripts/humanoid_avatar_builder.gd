extends RefCounted

## Процедурный «человечек» как у героя: рубашка `shirt_color`, опционально каска.


static func _skin_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.72, 0.58)
	m.roughness = 0.62
	return m


static func _pants_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.22, 0.48)
	m.roughness = 0.55
	return m


static func _shirt_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	return m


static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)


static func build(avatar_root: Node3D, shirt_color: Color, with_helmet: bool, uniform_scale: float = 1.0) -> void:
	avatar_root.scale = Vector3(uniform_scale, uniform_scale, uniform_scale)

	var leg_l := Node3D.new()
	leg_l.name = &"LegL"
	leg_l.position = Vector3(-0.11, 0.34, 0.0)
	avatar_root.add_child(leg_l)
	_add_box(leg_l, Vector3(0.0, -0.19, 0.0), Vector3(0.14, 0.38, 0.14), _pants_mat())

	var leg_r := Node3D.new()
	leg_r.name = &"LegR"
	leg_r.position = Vector3(0.11, 0.34, 0.0)
	avatar_root.add_child(leg_r)
	_add_box(leg_r, Vector3(0.0, -0.19, 0.0), Vector3(0.14, 0.38, 0.14), _pants_mat())

	var arm_l := Node3D.new()
	arm_l.name = &"ArmL"
	arm_l.position = Vector3(-0.26, 0.7, 0.0)
	avatar_root.add_child(arm_l)
	_add_box(arm_l, Vector3(0.0, -0.17, 0.0), Vector3(0.11, 0.34, 0.1), _skin_mat())

	var arm_r := Node3D.new()
	arm_r.name = &"ArmR"
	arm_r.position = Vector3(0.26, 0.7, 0.0)
	avatar_root.add_child(arm_r)
	_add_box(arm_r, Vector3(0.0, -0.17, 0.0), Vector3(0.11, 0.34, 0.1), _skin_mat())

	var torso := MeshInstance3D.new()
	var torso_m := BoxMesh.new()
	torso_m.size = Vector3(0.36, 0.44, 0.2)
	torso.mesh = torso_m
	torso.position = Vector3(0.0, 0.58, 0.0)
	torso.set_surface_override_material(0, _shirt_mat(shirt_color))
	avatar_root.add_child(torso)

	var head := MeshInstance3D.new()
	var head_m := SphereMesh.new()
	head_m.radius = 0.13
	head_m.height = 0.26
	head.mesh = head_m
	head.position = Vector3(0.0, 0.93, 0.0)
	head.set_surface_override_material(0, _skin_mat())
	avatar_root.add_child(head)

	if with_helmet:
		var helm := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.145
		hm.height = 0.2
		helm.mesh = hm
		helm.position = Vector3(0.0, 0.98, 0.0)
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.96, 0.82, 0.14)
		hmat.roughness = 0.4
		hmat.metallic = 0.15
		helm.set_surface_override_material(0, hmat)
		avatar_root.add_child(helm)
		var brim := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.16
		bm.bottom_radius = 0.16
		bm.height = 0.04
		brim.mesh = bm
		brim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		brim.position = Vector3(0.0, 0.88, 0.06)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.88, 0.72, 0.1)
		bmat.roughness = 0.5
		brim.set_surface_override_material(0, bmat)
		avatar_root.add_child(brim)

	avatar_root.position.y = -0.46
