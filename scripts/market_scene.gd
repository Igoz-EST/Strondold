## Market — passive coin-income building. Stall with awning and coin-stack accent.
extends RefCounted

static func create_market(level: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	body.name = "Market"

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.4, 3.2)
	col.shape = box
	col.position = Vector3(0.0, 1.2, 0.0)
	body.add_child(col)

	# Base platform
	_add_box(body, Vector3(3.1, 0.3, 3.1), Vector3(0.0, 0.15, 0.0), Color(0.42, 0.40, 0.36))
	# Counter
	_add_box(body, Vector3(2.6, 0.9, 2.4), Vector3(0.0, 0.75, 0.0), Color(0.46, 0.34, 0.20))
	# Posts
	for s in [Vector3(1.15, 0, 1.05), Vector3(-1.15, 0, 1.05),
			  Vector3(1.15, 0, -1.05), Vector3(-1.15, 0, -1.05)]:
		_add_box(body, Vector3(0.16, 2.6, 0.16), Vector3(s.x, 1.5, s.z), Color(0.36, 0.26, 0.16))
	# Awning
	_add_box(body, Vector3(3.0, 0.16, 2.9), Vector3(0.0, 2.85, 0.0), Color(0.72, 0.22, 0.20))
	# Coin-stack accent (emissive gold)
	_add_box_emissive(body, Vector3(0.5, 0.36, 0.5), Vector3(0.0, 1.4, 0.0), Color(1.0, 0.82, 0.2))

	_add_level_visuals(body, level)

	body.set_script(preload("res://scripts/market_unit.gd"))
	body.set_meta(&"market_level", level)
	return body


## Rebuilds the level-dependent decorations on an existing Market body (used on upgrade).
static func add_level_visuals(body: Node3D, level: int) -> void:
	var old := body.get_node_or_null("MarketLevelVisuals")
	if old != null:
		body.remove_child(old)
		old.free()
	_add_level_visuals(body, level)


static func _add_level_visuals(body: Node3D, level: int) -> void:
	var lvl := clampi(level, 1, 3)
	var root := Node3D.new()
	root.name = &"MarketLevelVisuals"
	body.add_child(root)

	if lvl >= 2:
		# Goods crates flanking the counter — the stall is doing more business
		_add_box(root, Vector3(0.6, 0.6, 0.6), Vector3(1.55, 0.3, 0.6), Color(0.50, 0.38, 0.22))
		_add_box(root, Vector3(0.5, 0.5, 0.5), Vector3(1.55, 0.85, 0.6), Color(0.56, 0.43, 0.25))
		_add_box(root, Vector3(0.6, 0.6, 0.6), Vector3(-1.55, 0.3, -0.5), Color(0.44, 0.34, 0.20))
		# Banner pole + cloth flag on the back-left post
		_add_box(root, Vector3(0.1, 1.2, 0.1), Vector3(-1.15, 3.55, -1.05), Color(0.30, 0.22, 0.14))
		_add_box_emissive(root, Vector3(0.55, 0.4, 0.05), Vector3(-0.85, 3.95, -1.05), Color(0.85, 0.20, 0.18))
		# Second coin stack on the counter (offset from the Lv1 stack)
		_add_box_emissive(root, Vector3(0.34, 0.24, 0.34), Vector3(0.85, 1.32, 0.55), Color(1.0, 0.82, 0.2))

	if lvl >= 3:
		# Raised second-tier canopy with golden trim — taller, grander silhouette
		_add_box(root, Vector3(2.2, 0.14, 2.1), Vector3(0.0, 3.55, 0.0), Color(0.80, 0.66, 0.22))
		_add_box(root, Vector3(0.14, 0.85, 0.14), Vector3(0.0, 3.95, 0.0), Color(0.30, 0.22, 0.14))
		# Glowing golden roof finial
		_add_box_emissive(root, Vector3(0.32, 0.32, 0.32), Vector3(0.0, 4.5, 0.0), Color(1.0, 0.85, 0.25))
		# Lantern glows at each post
		for s in [Vector3(1.15, 0, 1.05), Vector3(-1.15, 0, 1.05),
				  Vector3(1.15, 0, -1.05), Vector3(-1.15, 0, -1.05)]:
			_add_box_emissive(root, Vector3(0.18, 0.2, 0.18), Vector3(s.x, 2.85, s.z), Color(1.0, 0.72, 0.36))
		# Third coin stack — the market is now overflowing with profit
		_add_box_emissive(root, Vector3(0.4, 0.3, 0.4), Vector3(-0.85, 1.35, -0.55), Color(1.0, 0.85, 0.25))


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.85
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)


static func _add_box_emissive(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color               = color
	mat.emission_enabled           = true
	mat.emission                   = color
	mat.emission_energy_multiplier = 0.9
	mat.roughness                  = 0.35
	mi.set_surface_override_material(0, mat)
	mi.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
