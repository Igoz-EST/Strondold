extends StaticBody3D

## Physics layer 6 (value 32) — sword queries; player mask 1|32.
const LAYER_BREAKABLE := 32
const TREE_MAX_HP := 200
const ROCK_MAX_HP := 100

@export var is_tree: bool = true
## Дерево/камень выключены; HP как у камня, меш сундука. Награда — только coin_reward (без +1 монеты).
@export var is_chest: bool = false
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
		_add_rock_mesh()
	add_child(col)
	_setup_hp_bar()
	set_process(false)


func _add_tree_meshes() -> void:
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = 0.48
	cm.top_radius = 0.34
	cm.height = 4.55
	trunk.mesh = cm
	trunk.position.y = 2.275
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.3, 0.19, 0.1)
	tm.roughness = 0.9
	trunk.set_surface_override_material(0, tm)
	add_child(trunk)

	var leaves := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.height = 2.15
	sm.radius = 1.28
	leaves.mesh = sm
	leaves.position.y = 4.95
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.12, 0.48, 0.16)
	lm.roughness = 0.85
	leaves.set_surface_override_material(0, lm)
	add_child(leaves)


func _add_rock_mesh() -> void:
	var rock := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.88, 0.58, 0.82)
	rock.mesh = bm
	rock.position.y = 0.29
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.42, 0.4, 0.38)
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
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.1)
	bg.set_surface_override_material(0, bg_mat)
	_bar_root.add_child(bg)

	_fill_mesh = MeshInstance3D.new()
	_fill_box = BoxMesh.new()
	_fill_box.size = Vector3(HP_BAR_FULL_WIDTH, 0.11, 0.032)
	_fill_mesh.mesh = _fill_box
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.9, 0.14, 0.1)
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(0.4, 0.04, 0.02)
	fill_mat.emission_energy_multiplier = 0.4
	fill_mat.roughness = 0.4
	_fill_mesh.set_surface_override_material(0, fill_mat)
	_fill_mesh.position.z = 0.018
	_bar_root.add_child(_fill_mesh)

	_hp_label = Label3D.new()
	_hp_label.name = "HpLabel"
	_hp_label.no_depth_test = true
	_hp_label.font_size = 22
	_hp_label.outline_size = 8
	_hp_label.modulate = Color(1.0, 0.95, 0.88)
	_hp_label.outline_modulate = Color(0.02, 0.02, 0.04)
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
		_hp_label.text = "Осталось HP: %d / %d" % [hp, max_hp]


func _process(_delta: float) -> void:
	if not _bar_shown or _bar_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_bar_root.look_at(cam.global_position, Vector3.UP)
	_bar_root.rotate_object_local(Vector3.UP, PI)


func apply_sword_hit(damage: int = 10, _attacker: Node = null) -> void:
	if hp <= 0:
		return
	if is_chest:
		SoundManager.play_one_shot(SoundManager.KEY_HIT_CHEST)
	elif is_tree:
		SoundManager.play_one_shot(SoundManager.KEY_HIT_WOOD)
	else:
		SoundManager.play_one_shot(SoundManager.KEY_HIT_STONE)
	hp -= damage
	if not _bar_shown:
		_bar_shown = true
		_bar_root.visible = true
		set_process(true)
	_refresh_hp_fill()
	if hp <= 0:
		if coin_reward > 0:
			GameState.add_coins(coin_reward)
		else:
			GameState.add_coin()
		queue_free()
