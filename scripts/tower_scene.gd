extends RefCounted

## Простая башня: коллизия на слое 1 (как земля), чтобы герой обходил.
static func create_tower(level: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "Tower"
	body.add_to_group(&"tower")
	body.set_meta(&"tower_level", clampi(level, 1, 3))
	body.set_meta(&"tower_type", 0)  # 0 = PHYS

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.3, 6.6, 3.3)
	col.shape = box
	col.position = Vector3(0.0, 3.3, 0.0)
	body.add_child(col)

	var base_m := MeshInstance3D.new()
	base_m.name = "TowerBase"
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
	mid.name = "TowerMid"
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
	top.name = "TowerTop"
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(2.85, 1.05, 2.85)
	top.mesh = top_mesh
	top.position.y = 5.175
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.42, 0.38, 0.36)
	m2.roughness = 0.7
	top.set_surface_override_material(0, m2)
	body.add_child(top)

	_add_level_visuals(body, level, false)

	body.set_script(preload("res://scripts/tower_unit.gd"))
	return body


static func add_level_visuals(body: Node3D, level: int, is_magic: bool = false) -> void:
	var old := body.get_node_or_null("TowerLevelVisuals")
	if old != null:
		body.remove_child(old)
		old.free()
	_add_level_visuals(body, level, is_magic)


static func _add_level_visuals(body: Node3D, level: int, is_magic: bool = false) -> void:
	var lvl := clampi(level, 1, 3)
	var root := Node3D.new()
	root.name = &"TowerLevelVisuals"
	body.add_child(root)

	if is_magic:
		_repaint_magic_base(body, lvl)
		_add_magic_decorations(root, lvl)
	else:
		_repaint_base(body,
			Color(0.38, 0.36, 0.34),
			Color(0.55, 0.52, 0.48),
			Color(0.42, 0.38, 0.36))
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


static func _repaint_base(body: Node3D, base_col: Color, mid_col: Color, top_col: Color) -> void:
	var pairs := [["TowerBase", base_col], ["TowerMid", mid_col], ["TowerTop", top_col]]
	for pair in pairs:
		var node := body.get_node_or_null(pair[0]) as MeshInstance3D
		if node == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = pair[1]
		mat.roughness = 0.82
		node.set_surface_override_material(0, mat)


static func _repaint_magic_base(body: Node3D, level: int) -> void:
	var base_col := Color(0.28, 0.00, 0.45)
	var mid_col  := Color(0.38, 0.00, 0.58)
	var top_col  := Color(0.32, 0.00, 0.50)
	var pairs := [["TowerBase", base_col], ["TowerMid", mid_col], ["TowerTop", top_col]]
	for pair in pairs:
		var node := body.get_node_or_null(pair[0]) as MeshInstance3D
		if node == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = pair[1]
		mat.roughness = 0.55
		if level >= 2:
			mat.emission_enabled = true
			mat.emission = Color(0.40, 0.00, 0.65)
			mat.emission_energy_multiplier = 0.5
		node.set_surface_override_material(0, mat)


static func _add_magic_decorations(root: Node3D, level: int) -> void:
	if level >= 2:
		# Glowing rune strips on each face of the mid-tower section
		_add_emissive_box(root, Vector3(1.60, 2.60, 0.10), Vector3(0.00,  2.85,  1.16))
		_add_emissive_box(root, Vector3(1.60, 2.60, 0.10), Vector3(0.00,  2.85, -1.16))
		_add_emissive_box(root, Vector3(0.10, 2.60, 1.60), Vector3(1.16,  2.85,  0.00))
		_add_emissive_box(root, Vector3(0.10, 2.60, 1.60), Vector3(-1.16, 2.85,  0.00))
	if level >= 3:
		# Floating glowing orb above the tower
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.10
		sm.radial_segments = 16
		sm.rings = 8
		orb.mesh = sm
		orb.position = Vector3(0.0, 7.50, 0.0)
		orb.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.70, 0.00, 1.00, 0.90)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.55, 0.00, 0.90)
		mat.emission_energy_multiplier = 2.2
		mat.roughness = 0.10
		orb.set_surface_override_material(0, mat)
		root.add_child(orb)


static func _add_emissive_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_i.mesh = mesh
	mesh_i.position = pos
	mesh_i.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.60, 0.00, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.50, 0.00, 0.85)
	mat.emission_energy_multiplier = 1.8
	mat.roughness = 0.20
	mesh_i.set_surface_override_material(0, mat)
	parent.add_child(mesh_i)


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
