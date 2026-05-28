extends StaticBody3D

## Physics layer 6 (value 32) — sword queries; player mask 1|32.
const LAYER_BREAKABLE := 32
const TREE_MAX_HP := 200
const ROCK_MAX_HP := 100
const TREE_WOOD_REWARD := 10

@export var is_tree: bool = true
## Дерево/камень выключены; HP как у камня, меш сундука. Награда — только coin_reward (без +1 монеты).
@export var is_chest: bool = false
## -1 = случайный вариант. 0..3 — фиксированные силуэты деревьев.
@export var tree_variant: int = -1
@export var rock_variant: int = -1
## При разрушении: >0 — GameState.add_coins(...); иначе одна монета как у дерева/камня.
@export var coin_reward: int = 0

var max_hp: int = TREE_MAX_HP
var hp: int = TREE_MAX_HP

## Ширина красной заливки = доля *остатка* HP (hp / max_hp).
const HP_BAR_FULL_WIDTH := 0.92

var _bar_root: Node3D
var _fill_mesh: MeshInstance3D
var _fill_box: BoxMesh
var _hp_label: Label3D
var _bar_shown: bool = false


func _ready() -> void:
	if is_chest:
		max_hp = ROCK_MAX_HP
	elif is_tree:
		max_hp = TREE_MAX_HP
	else:
		max_hp = ROCK_MAX_HP
	hp = max_hp
	collision_layer = LAYER_BREAKABLE
	collision_mask = 0
	add_to_group("breakable")
	if is_tree and not is_chest:
		add_to_group(&"tree")
	var col := CollisionShape3D.new()
	if is_tree:
		var cyl := CylinderShape3D.new()
		cyl.height = 5.65
		cyl.radius = 0.5
		col.shape = cyl
		col.position = Vector3(0.0, 2.825, 0.0)
		_add_tree_meshes()
	elif is_chest:
		var bx_c := BoxShape3D.new()
		bx_c.size = Vector3(0.9, 0.56, 0.68)
		col.shape = bx_c
		col.position = Vector3(0.0, 0.28, 0.0)
		_add_chest_mesh()
	else:
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.88, 0.58, 0.82)
		col.shape = bx
		col.position = Vector3(0.0, 0.29, 0.0)
		_add_rock_meshes()
	add_child(col)
	_setup_hp_bar()
	set_process(false)


func _add_tree_meshes() -> void:
	var variant := randi_range(0, 3) if tree_variant < 0 else wrapi(tree_variant, 0, 4)
	match variant:
		0:
			_add_round_oak()
		1:
			_add_pine_tree()
		2:
			_add_birch_tree()
		_:
			_add_wide_old_tree()


func _add_trunk(height: float, bottom_radius: float, top_radius: float, color: Color, pos_x: float = 0.0) -> MeshInstance3D:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_radius
	cm.top_radius = top_radius
	cm.height = height
	trunk.mesh = cm
	trunk.position = Vector3(pos_x, height * 0.5, 0.0)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = color
	tm.roughness = 0.9
	trunk.set_surface_override_material(0, tm)
	add_child(trunk)
	return trunk


func _add_leaf_sphere(pos: Vector3, radius: float, height: float, color: Color, scale_xz: Vector2 = Vector2.ONE) -> void:
	var leaves := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.height = height
	sm.radius = radius
	leaves.mesh = sm
	leaves.position = pos
	leaves.scale = Vector3(scale_xz.x, 1.0, scale_xz.y)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = color
	lm.roughness = 0.85
	leaves.set_surface_override_material(0, lm)
	add_child(leaves)


func _add_leaf_cone(pos: Vector3, bottom_radius: float, top_radius: float, height: float, color: Color) -> void:
	var leaves := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_radius
	cm.top_radius = top_radius
	cm.height = height
	leaves.mesh = cm
	leaves.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	leaves.set_surface_override_material(0, mat)
	add_child(leaves)


func _add_branch(pos: Vector3, height: float, rot_z: float) -> void:
	var branch := _add_trunk(height, 0.17, 0.08, Color(0.28, 0.16, 0.08))
	branch.position = pos
	branch.rotation_degrees.z = rot_z


func _add_round_oak() -> void:
	_add_trunk(4.1, 0.48, 0.32, Color(0.34, 0.2, 0.09))
	_add_leaf_sphere(Vector3(0.0, 4.55, 0.0), 1.25, 1.85, Color(0.13, 0.48, 0.17), Vector2(1.1, 0.95))
	_add_leaf_sphere(Vector3(-0.62, 4.25, 0.1), 0.9, 1.25, Color(0.1, 0.4, 0.14))
	_add_leaf_sphere(Vector3(0.58, 4.15, -0.2), 0.82, 1.18, Color(0.16, 0.56, 0.2))


func _add_pine_tree() -> void:
	_add_trunk(3.6, 0.34, 0.22, Color(0.29, 0.18, 0.09))
	_add_leaf_cone(Vector3(0.0, 3.0, 0.0), 1.2, 0.12, 1.65, Color(0.07, 0.32, 0.16))
	_add_leaf_cone(Vector3(0.0, 4.0, 0.0), 1.0, 0.08, 1.55, Color(0.06, 0.38, 0.18))
	_add_leaf_cone(Vector3(0.0, 4.95, 0.0), 0.72, 0.04, 1.25, Color(0.09, 0.45, 0.2))


func _add_birch_tree() -> void:
	_add_trunk(4.75, 0.32, 0.24, Color(0.83, 0.78, 0.65))
	for mark in [
		Vector3(-0.16, 1.25, 0.29),
		Vector3(0.12, 1.95, 0.295),
		Vector3(-0.08, 2.65, 0.285),
		Vector3(0.16, 3.35, 0.275),
	]:
		var spot := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, 0.055, 0.018)
		spot.mesh = bm
		spot.position = mark
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.1, 0.08)
		spot.set_surface_override_material(0, mat)
		add_child(spot)
	_add_leaf_sphere(Vector3(0.0, 4.85, 0.0), 1.05, 1.75, Color(0.48, 0.62, 0.16), Vector2(0.85, 1.1))
	_add_leaf_sphere(Vector3(0.48, 4.55, 0.18), 0.75, 1.05, Color(0.36, 0.55, 0.14))


func _add_wide_old_tree() -> void:
	var trunk := _add_trunk(3.8, 0.62, 0.42, Color(0.28, 0.16, 0.08))
	trunk.rotation_degrees.z = 4.0
	_add_branch(Vector3(-0.45, 2.85, 0.0), 1.25, -38.0)
	_add_branch(Vector3(0.44, 2.75, 0.0), 1.1, 36.0)
	_add_leaf_sphere(Vector3(-0.6, 4.0, 0.05), 1.1, 1.45, Color(0.18, 0.43, 0.13), Vector2(1.15, 0.85))
	_add_leaf_sphere(Vector3(0.42, 4.25, -0.12), 1.2, 1.55, Color(0.13, 0.5, 0.17), Vector2(1.05, 1.0))
	_add_leaf_sphere(Vector3(0.0, 4.85, 0.18), 0.92, 1.2, Color(0.22, 0.56, 0.18))


func _add_rock_meshes() -> void:
	var variant := randi_range(0, 3) if rock_variant < 0 else wrapi(rock_variant, 0, 4)
	match variant:
		0:
			_add_rock_mesh(Vector3(0.88, 0.58, 0.82), Vector3(0.0, 0.29, 0.0), Color(0.42, 0.4, 0.38))
		1:
			_add_rock_mesh(Vector3(1.05, 0.45, 0.72), Vector3(-0.08, 0.23, 0.0), Color(0.36, 0.36, 0.34), Vector3(0.0, 18.0, -7.0))
			_add_rock_mesh(Vector3(0.52, 0.38, 0.5), Vector3(0.42, 0.19, 0.1), Color(0.48, 0.46, 0.42), Vector3(0.0, -12.0, 5.0))
		2:
			_add_rock_mesh(Vector3(0.62, 0.9, 0.58), Vector3(0.0, 0.45, 0.0), Color(0.38, 0.39, 0.4), Vector3(0.0, 28.0, 8.0))
			_add_rock_mesh(Vector3(0.46, 0.35, 0.42), Vector3(-0.34, 0.18, 0.18), Color(0.5, 0.49, 0.45))
		_:
			_add_rock_mesh(Vector3(1.15, 0.32, 0.95), Vector3(0.0, 0.16, 0.0), Color(0.44, 0.43, 0.4), Vector3(0.0, -24.0, 0.0))
			_add_rock_mesh(Vector3(0.38, 0.55, 0.36), Vector3(-0.36, 0.35, -0.2), Color(0.34, 0.34, 0.33), Vector3(8.0, 0.0, 11.0))
			_add_rock_mesh(Vector3(0.42, 0.48, 0.4), Vector3(0.38, 0.31, 0.18), Color(0.52, 0.5, 0.46), Vector3(-5.0, 0.0, -9.0))


func _add_rock_mesh(size: Vector3, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var rock := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	rock.mesh = bm
	rock.position = pos
	rock.rotation_degrees = rot
	var rm := StandardMaterial3D.new()
	rm.albedo_color = color
	rm.roughness = 0.92
	rock.set_surface_override_material(0, rm)
	add_child(rock)


func _add_chest_mesh() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.38, 0.22, 0.1)
	wood.roughness = 0.9

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.84, 0.38, 0.6)
	body.mesh = bm
	body.position.y = 0.19
	body.set_surface_override_material(0, wood)
	add_child(body)

	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.86, 0.09, 0.62)
	lid.mesh = lm
	lid.position = Vector3(0.0, 0.42, -0.04)
	lid.rotation_degrees.x = -14.0
	lid.set_surface_override_material(0, wood)
	add_child(lid)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.52, 0.48)
	metal.metallic = 0.55
	metal.roughness = 0.45

	for z_sign in [-1.0, 1.0]:
		var strap := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.34, 0.62)
		strap.mesh = sm
		strap.position = Vector3(0.32 * z_sign, 0.2, 0.0)
		strap.set_surface_override_material(0, metal)
		add_child(strap)

	var lock := MeshInstance3D.new()
	var lkm := BoxMesh.new()
	lkm.size = Vector3(0.14, 0.12, 0.08)
	lock.mesh = lkm
	lock.position = Vector3(0.0, 0.22, 0.32)
	lock.set_surface_override_material(0, metal)
	add_child(lock)


func _setup_hp_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "HpBar"
	var bar_y := 6.15 if is_tree else (1.08 if is_chest else 0.92)
	_bar_root.position.y = bar_y
	_bar_root.visible = false
	add_child(_bar_root)

	var bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(0.98, 0.16, 0.045)
	bg.mesh = bg_box
	bg.set_surface_override_material(0, UiStyle.bar_bg_material())
	_bar_root.add_child(bg)

	_fill_mesh = MeshInstance3D.new()
	_fill_box = BoxMesh.new()
	_fill_box.size = Vector3(HP_BAR_FULL_WIDTH, 0.11, 0.032)
	_fill_mesh.mesh = _fill_box
	_fill_mesh.set_surface_override_material(0, UiStyle.bar_fill_material(UiStyle.BAR_HP))
	_fill_mesh.position.z = 0.018
	_bar_root.add_child(_fill_mesh)

	_hp_label = Label3D.new()
	_hp_label.name = "HpLabel"
	UiStyle.style_label3d(_hp_label, UiStyle.TEXT_MAIN, 22, 8)
	_hp_label.position = Vector3(0.0, 0.15, 0.02)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_root.add_child(_hp_label)
	_refresh_hp_fill()


func _refresh_hp_fill() -> void:
	if _fill_box == null:
		return
	# Длина красной полоски = доля оставшегося HP (индикатор «сколько ещё держится»).
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var w := HP_BAR_FULL_WIDTH * ratio
	_fill_box.size = Vector3(maxf(w, 0.02), 0.11, 0.032)
	_fill_mesh.position.x = -HP_BAR_FULL_WIDTH * 0.5 + _fill_box.size.x * 0.5
	if _hp_label:
		_hp_label.text = "HP left: %d / %d" % [hp, max_hp]


func _process(_delta: float) -> void:
	if not _bar_shown or _bar_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_bar_root.look_at(cam.global_position, Vector3.UP)
	_bar_root.rotate_object_local(Vector3.UP, PI)


func get_wood_remaining() -> int:
	return maxi(hp, 0) if is_tree and not is_chest else 0


func get_work_anchor_global() -> Vector3:
	return global_position + Vector3(0.0, 0.55, 1.2)


func try_chop_worker_hit(damage: int) -> int:
	if not is_tree or is_chest or hp <= 0:
		return 0
	var fx_pos := global_position + Vector3(0.0, 2.3, 0.0)
	SoundManager.play_one_shot(SoundManager.KEY_HIT_WOOD)
	FeedbackFx.show_wood_hit(get_parent(), fx_pos)
	hp -= damage
	if not _bar_shown:
		_bar_shown = true
		_bar_root.visible = true
		set_process(true)
	_refresh_hp_fill()
	if hp > 0:
		return 0
	queue_free()
	return TREE_WOOD_REWARD


func apply_sword_hit(damage: int = 10, _attacker: Node = null) -> void:
	if hp <= 0:
		return
	var fx_pos := global_position + Vector3(0.0, 2.3 if is_tree else 0.6, 0.0)
	if is_chest:
		SoundManager.play_one_shot(SoundManager.KEY_HIT_CHEST)
		FeedbackFx.show_stone_hit(get_parent(), fx_pos)
	elif is_tree:
		SoundManager.play_one_shot(SoundManager.KEY_HIT_WOOD)
		FeedbackFx.show_wood_hit(get_parent(), fx_pos)
	else:
		SoundManager.play_one_shot(SoundManager.KEY_HIT_STONE)
		FeedbackFx.show_stone_hit(get_parent(), fx_pos)
	hp -= damage
	if not _bar_shown:
		_bar_shown = true
		_bar_root.visible = true
		set_process(true)
	_refresh_hp_fill()
	if hp <= 0:
		var reward := coin_reward if coin_reward > 0 else 1
		FeedbackFx.show_coin_gain(get_parent(), global_position + Vector3(0.0, 1.2, 0.0), reward)
		if is_tree and not is_chest:
			FeedbackFx.show_wood_gain(get_parent(), global_position + Vector3(0.0, 1.55, 0.0), TREE_WOOD_REWARD)
			GameState.add_wood(TREE_WOOD_REWARD)
		if coin_reward > 0:
			GameState.add_coins(coin_reward)
		else:
			GameState.add_coin()
		queue_free()
