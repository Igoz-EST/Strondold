extends CharacterBody3D

## Слой 9 (бит 256) — меч и игрок.
const LAYER_ENEMY := 256

## Как у башни / воина.
const WARRIOR_VISION_RANGE := 42.0

const GRAVITY := 30.0
const ATTACK_INTERVAL := 0.85
## Точка у подножия базы (мир), куда бежит враг.
## Точка у подножия базы со стороны входа (смотрит на внешний спавн +X).
const BASE_TARGET := Vector3(6.0, 0.55, 0.0)
const ATTACK_RANGE := 7.5

enum Kind { NORMAL, BIG, BOSS }

var kind: int = Kind.NORMAL
var move_speed := 9.0
var damage_to_base := 10
var max_hp := 40
var hp: int = 40

var _attack_cd := 0.0
var _hp_bar: Node = null

## Атака базы, воина или рабочего.
var _ally_target: CharacterBody3D = null


func _exit_tree() -> void:
	_release_ally_target()


func _ready() -> void:
	add_to_group(&"enemy")
	collision_layer = LAYER_ENEMY
	collision_mask = 1
	var bar := Node3D.new()
	bar.set_script(preload("res://scripts/enemy_hp_bar.gd"))
	bar.name = &"EnemyHpBar"
	add_child(bar)
	_hp_bar = bar


func configure(kind_in: int) -> void:
	kind = kind_in
	match kind:
		Kind.NORMAL:
			move_speed = 9.0
			damage_to_base = 10
			max_hp = 40
		Kind.BIG:
			move_speed = 4.5
			damage_to_base = 20
			max_hp = 80
			scale = Vector3(2.0, 2.0, 2.0)
		Kind.BOSS:
			move_speed = 1.8
			damage_to_base = 100
			max_hp = 400
			scale = Vector3(3.5, 3.5, 3.5)
	hp = max_hp


func apply_sword_hit(damage: int = 10, _attacker: Node = null) -> void:
	hp -= damage
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if hp <= 0:
		SoundManager.play_npc_death()
		GameState.add_coin()
		queue_free()
	elif damage > 0:
		SoundManager.play_punch_for_target(get_instance_id())


func notify_ally_destroyed(unit: Node) -> void:
	if _ally_target == unit:
		_release_ally_target()


func _release_ally_target() -> void:
	if _ally_target != null and is_instance_valid(_ally_target):
		if _ally_target.has_method(&"clear_duel_from"):
			_ally_target.call(&"clear_duel_from", self)
	_ally_target = null


func _pick_ally_duel_candidate() -> CharacterBody3D:
	var vr2 := WARRIOR_VISION_RANGE * WARRIOR_VISION_RANGE
	var best: CharacterBody3D = null
	var best_d2: float = INF
	var p := global_position
	var cand: Array = get_tree().get_nodes_in_group(&"warrior")
	for n2 in get_tree().get_nodes_in_group(&"worker"):
		cand.append(n2)
	for n in cand:
		if not (n is CharacterBody3D) or not is_instance_valid(n):
			continue
		var u := n as CharacterBody3D
		if u.has_method(&"is_alive_for_combat") and not (u.call(&"is_alive_for_combat") as bool):
			continue
		var d2 := p.distance_squared_to(u.global_position)
		if d2 > vr2:
			continue
		if not u.has_method(&"can_accept_duel_from"):
			continue
		if not (u.call(&"can_accept_duel_from", self) as bool):
			continue
		if d2 < best_d2:
			best_d2 = d2
			best = u
	return best


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var vr2 := WARRIOR_VISION_RANGE * WARRIOR_VISION_RANGE

	if _ally_target != null and not is_instance_valid(_ally_target):
		_release_ally_target()

	var w_pick := _pick_ally_duel_candidate()
	if w_pick == null:
		_release_ally_target()
	else:
		if _ally_target != w_pick:
			_release_ally_target()
			if w_pick.has_method(&"offer_duel"):
				w_pick.call(&"offer_duel", self)
		_ally_target = w_pick

	if _ally_target != null and is_instance_valid(_ally_target):
		var d2w := global_position.distance_squared_to(_ally_target.global_position)
		if d2w > vr2 * 1.1:
			_release_ally_target()

	if _ally_target != null and is_instance_valid(_ally_target):
		var to_w := _ally_target.global_position - global_position
		to_w.y = 0.0
		var dist_w := to_w.length()
		if dist_w > 0.25:
			var dir_w := to_w.normalized()
			velocity.x = dir_w.x * move_speed
			velocity.z = dir_w.z * move_speed
			look_at(global_position + dir_w, Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

		if dist_w < ATTACK_RANGE:
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = ATTACK_INTERVAL
				if _ally_target.has_method(&"apply_sword_hit"):
					_ally_target.call(&"apply_sword_hit", damage_to_base, self)
		move_and_slide()
		return

	var to := BASE_TARGET - global_position
	to.y = 0.0
	var dist := to.length()

	if dist > 0.25:
		var dir := to.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if dist < ATTACK_RANGE:
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			GameState.damage_base(damage_to_base)

	move_and_slide()
