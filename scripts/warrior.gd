extends CharacterBody3D

const _HumanoidAvatarBuilder := preload("res://scripts/humanoid_avatar_builder.gd")

## Слой 10 (512) — не меч игрока (256) и не враг.
const LAYER_WARRIOR := 512

const GRAVITY := 30.0
## Как у башни (`tower_unit.FIRE_RANGE`).
const VISION_RANGE := 42.0
const ATTACK_RANGE := 7.5
const ATTACK_INTERVAL := 0.85
## Урон как у обычного врага по базе.
const MELEE_DAMAGE := 10

const MOVE_SPEED := 9.0
const MAX_HP := 40
const WARRIOR_SHIRT := Color(0.1, 0.38, 0.88)
const WARRIOR_HELM := Color(0.22, 0.52, 0.92)
const AVATAR_SCALE := 0.92

var hp: int = MAX_HP
var max_hp: int = MAX_HP
var upgrade_level := 1
var melee_damage := MELEE_DAMAGE

var _barracks: Node3D = null
var _slot_index: int = -1
var _rally_offset: Vector3 = Vector3.ZERO

## Противник, с которым нас «залочили» в дуэль (только один).
var _duel_enemy: CharacterBody3D = null

var _attack_cd := 0.0
var _hp_bar: Node = null

@onready var _avatar_root: Node3D = $AvatarRoot


func setup(barracks_root: Node3D, slot: int, rally_offset: Vector3) -> void:
	_barracks = barracks_root
	_slot_index = slot
	_rally_offset = rally_offset


func can_accept_duel_from(enemy: Node) -> bool:
	if not (enemy is CharacterBody3D):
		return false
	var e := enemy as CharacterBody3D
	if _duel_enemy != null and is_instance_valid(_duel_enemy) and _duel_enemy != e:
		return false
	return true


func offer_duel(enemy: Node) -> bool:
	if not can_accept_duel_from(enemy):
		return false
	_duel_enemy = enemy as CharacterBody3D
	return true


func clear_duel_from(enemy: Node) -> void:
	if _duel_enemy == enemy:
		_duel_enemy = null


func is_alive_for_combat() -> bool:
	return is_inside_tree() and hp > 0


func _ready() -> void:
	add_to_group(&"warrior")
	collision_layer = LAYER_WARRIOR
	collision_mask = 1
	_HumanoidAvatarBuilder.build(
		_avatar_root,
		WARRIOR_SHIRT,
		true,
		AVATAR_SCALE,
		0.08,
		WARRIOR_HELM
	)
	var arm_l := _avatar_root.get_node_or_null("ArmL") as Node3D
	if arm_l != null:
		_build_shield(arm_l)

	var bar := Node3D.new()
	bar.set_script(preload("res://scripts/enemy_hp_bar.gd"))
	bar.name = &"WarriorHpBar"
	add_child(bar)
	_hp_bar = bar
	if _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if is_instance_valid(_barracks) and _barracks.has_method(&"apply_upgrade_level"):
		var lvl := GameState.barracks_level
		if _barracks.has_meta(&"barracks_level"):
			lvl = int(_barracks.get_meta(&"barracks_level"))
		apply_upgrade_level(lvl)


func apply_upgrade_level(level: int) -> void:
	upgrade_level = clampi(level, 1, 3)
	var old_max := max_hp
	var stat_mult := 2 if upgrade_level >= 2 else 1
	max_hp = MAX_HP * stat_mult
	melee_damage = MELEE_DAMAGE * stat_mult
	if hp == old_max:
		hp = max_hp
	else:
		hp = mini(max_hp, hp + max_hp - old_max)
	scale = Vector3.ONE * (1.08 if upgrade_level >= 2 else 1.0)
	_apply_level_visuals()
	if _hp_bar != null and is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)


func _apply_level_visuals() -> void:
	var old := _avatar_root.get_node_or_null("WarriorLevelVisuals")
	if old != null:
		_avatar_root.remove_child(old)
		old.free()
	if upgrade_level < 2:
		return
	var root := Node3D.new()
	root.name = &"WarriorLevelVisuals"
	_avatar_root.add_child(root)
	_add_level_box(root, Vector3(-0.24, 0.76, 0.0), Vector3(0.16, 0.1, 0.18), Color(0.72, 0.64, 0.34))
	_add_level_box(root, Vector3(0.24, 0.76, 0.0), Vector3(0.16, 0.1, 0.18), Color(0.72, 0.64, 0.34))
	_add_level_box(root, Vector3(0.0, 1.09, 0.0), Vector3(0.22, 0.08, 0.22), Color(0.78, 0.68, 0.22))
	_add_level_box(root, Vector3(0.0, 0.58, 0.115), Vector3(0.22, 0.34, 0.035), Color(0.62, 0.12, 0.09))


func _add_level_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_i := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_i.mesh = mesh
	mesh_i.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.58
	mesh_i.set_surface_override_material(0, mat)
	parent.add_child(mesh_i)


func _build_shield(arm: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name = &"ShieldPivot"
	pivot.position = Vector3(0.04, -0.24, 0.05)
	arm.add_child(pivot)

	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.5, 0.38)
	board.mesh = bm
	board.position = Vector3(-0.15, 0.0, 0.16)
	board.rotation_degrees = Vector3(6.0, 92.0, 0.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.48, 0.52, 0.58)
	sm.metallic = 0.45
	sm.roughness = 0.42
	board.set_surface_override_material(0, sm)
	pivot.add_child(board)

	var boss := MeshInstance3D.new()
	var rim := BoxMesh.new()
	rim.size = Vector3(0.07, 0.52, 0.42)
	boss.mesh = rim
	boss.position = Vector3(-0.18, 0.0, 0.16)
	boss.rotation_degrees = Vector3(6.0, 92.0, 0.0)
	var rim_m := StandardMaterial3D.new()
	rim_m.albedo_color = Color(0.28, 0.3, 0.34)
	rim_m.metallic = 0.65
	rim_m.roughness = 0.35
	boss.set_surface_override_material(0, rim_m)
	pivot.add_child(boss)


func apply_sword_hit(damage: int = 10, attacker: Node = null) -> void:
	var from_enemy := attacker != null and is_instance_valid(attacker) and attacker.is_in_group(&"enemy")
	var from_other := attacker != null and is_instance_valid(attacker) and not from_enemy
	hp -= damage
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if hp <= 0:
		SoundManager.play_npc_death()
		if _duel_enemy != null and is_instance_valid(_duel_enemy) and _duel_enemy.has_method(&"notify_ally_destroyed"):
			_duel_enemy.call(&"notify_ally_destroyed", self)
		_duel_enemy = null
		if is_instance_valid(_barracks) and _barracks.has_method(&"notify_warrior_lost"):
			_barracks.call(&"notify_warrior_lost", _slot_index)
		queue_free()
		return
	if from_enemy:
		SoundManager.play_one_shot(SoundManager.KEY_SHIELD_HIT)
	elif from_other:
		SoundManager.play_punch_for_target(get_instance_id(), -2.0)


func _pick_enemy() -> Node3D:
	var vr2 := VISION_RANGE * VISION_RANGE
	if _duel_enemy != null and is_instance_valid(_duel_enemy):
		var d2d := global_position.distance_squared_to(_duel_enemy.global_position)
		if d2d <= vr2 * 1.5:
			return _duel_enemy
		_duel_enemy = null

	var best: Node3D = null
	var best_d2 := vr2
	var p := global_position
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if not (n is Node3D) or not is_instance_valid(n):
			continue
		var nd := n as Node3D
		var d2 := p.distance_squared_to(nd.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = nd
	return best


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _duel_enemy != null and not is_instance_valid(_duel_enemy):
		_duel_enemy = null

	var rally := global_position
	if is_instance_valid(_barracks):
		rally = _barracks.global_position + _rally_offset + Vector3(0.0, 0.55, 0.0)

	var tgt := _pick_enemy()
	if tgt != null:
		var to_e := tgt.global_position - global_position
		to_e.y = 0.0
		var dist := to_e.length()
		if dist > ATTACK_RANGE - 0.15:
			var dir := to_e.normalized()
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
			look_at(global_position + dir, Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			look_at(tgt.global_position, Vector3.UP)
			_attack_cd -= delta
			if _attack_cd <= 0.0 and tgt.has_method(&"apply_sword_hit"):
				_attack_cd = ATTACK_INTERVAL
				SoundManager.play_one_shot(SoundManager.KEY_SWORD_SWING, 0.14, -4.0)
				tgt.call(&"apply_sword_hit", melee_damage)
	else:
		var to_r := rally - global_position
		to_r.y = 0.0
		var rd := to_r.length()
		if rd > 0.4:
			var rdir := to_r.normalized()
			velocity.x = rdir.x * MOVE_SPEED
			velocity.z = rdir.z * MOVE_SPEED
			look_at(global_position + rdir, Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()
