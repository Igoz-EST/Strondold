extends "res://scripts/warrior.gd"

const GIANT_VISION  := 63.0
const PATROL_RADIUS := 12.0

var _patrol_target := Vector3.ZERO
var _patrol_timer  := 0.0


func _ready() -> void:
	super._ready()
	add_to_group(&"giant_warrior")
	max_hp       = MAX_HP * 10
	hp           = max_hp
	melee_damage = MELEE_DAMAGE * 10
	scale        = Vector3.ONE * 10.0
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	_new_patrol()


func apply_upgrade_level(_level: int) -> void:
	pass


func _new_patrol() -> void:
	var a := randf() * TAU
	_patrol_target = Vector3(cos(a), 0.0, sin(a)) * PATROL_RADIUS
	_patrol_timer  = randf_range(4.0, 8.0)


func _pick_enemy() -> Node3D:
	var vr2 := GIANT_VISION * GIANT_VISION
	if _duel_enemy != null and is_instance_valid(_duel_enemy):
		if global_position.distance_squared_to(_duel_enemy.global_position) <= vr2 * 1.5:
			return _duel_enemy
		_duel_enemy = null
	var best: Node3D = null
	var best_d2 := vr2
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if not (n is Node3D) or not is_instance_valid(n):
			continue
		var d2 := global_position.distance_squared_to((n as Node3D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = n as Node3D
	return best


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _duel_enemy != null and not is_instance_valid(_duel_enemy):
		_duel_enemy = null

	var tgt := _pick_enemy()
	if tgt != null:
		var to_e := tgt.global_position - global_position
		to_e.y = 0.0
		var eff_range := ATTACK_RANGE * 10.0
		if to_e.length() > eff_range:
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
		_patrol_timer -= delta
		if _patrol_timer <= 0.0:
			_new_patrol()
		var to_p := _patrol_target - global_position
		to_p.y = 0.0
		if to_p.length() > 1.0:
			var d := to_p.normalized()
			velocity.x = d.x * MOVE_SPEED * 0.4
			velocity.z = d.z * MOVE_SPEED * 0.4
			look_at(global_position + d, Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()


func apply_sword_hit(damage: int = 10, _attacker: Node = null) -> void:
	hp -= damage
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if hp <= 0:
		SoundManager.play_npc_death()
		GameState.has_giant_warrior = false
		if _duel_enemy != null and is_instance_valid(_duel_enemy) and _duel_enemy.has_method(&"notify_ally_destroyed"):
			_duel_enemy.call(&"notify_ally_destroyed", self)
		queue_free()
	else:
		SoundManager.play_one_shot(SoundManager.KEY_SHIELD_HIT)
