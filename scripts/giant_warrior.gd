extends "res://scripts/warrior.gd"

const GIANT_VISION  := 63.0
const PATROL_RADIUS := 12.0
const _KNIGHT_PATH  := "res://assets/models/knight.glb"

# Animation names from knight.glb (verified in import preview)
const _GW_ANIM_IDLE   := ["idle", "idle_combat"]
const _GW_ANIM_WALK   := ["walking", "combat_walk_forward"]
const _GW_ANIM_ATTACK := ["default_atack_full_combo", "default_atack_3", "atack_overhead"]
const _GW_ANIM_HIT    := ["pb_take_damage", "staggered_1", "poise_break"]
const _GW_ANIM_DEATH  := ["death", "death_poise_break"]

var _patrol_target := Vector3.ZERO
var _patrol_timer  := 0.0
var _gw_model:      Node3D          = null
var _gw_anim:       AnimationPlayer = null


func _ready() -> void:
	super._ready()
	add_to_group(&"giant_warrior")
	max_hp       = MAX_HP * 10
	hp           = max_hp
	melee_damage = MELEE_DAMAGE * 10
	scale        = Vector3.ONE * 2.0   # ~2x normal warrior (not 10x)
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	_load_knight_model()
	_new_patrol()


# Prevent warrior.gd from loading azure_sentinel on top of knight
func _load_warrior_model() -> void:
	pass


func apply_upgrade_level(_level: int) -> void:
	pass


func _load_knight_model() -> void:
	if not ResourceLoader.exists(_KNIGHT_PATH):
		return
	var scene := load(_KNIGHT_PATH) as PackedScene
	if scene == null: return
	_gw_model = scene.instantiate() as Node3D
	if _gw_model == null: return
	# GLB faces -Z by default (GLTF spec) — no rotation needed
	_gw_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	add_child(_gw_model)
	_avatar_root.visible = false
	_gw_anim = _find_warrior_anim_player(_gw_model)
	if _gw_anim:
		_gw_play(_GW_ANIM_IDLE)


func _gw_play(names: Array, loop: bool = true) -> bool:
	if _gw_anim == null: return false
	for n in names:
		if _gw_anim.has_animation(n):
			if _gw_anim.current_animation != n or not _gw_anim.is_playing():
				var anim := _gw_anim.get_animation(n)
				if anim: anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				_gw_anim.play(n)
			return true
	return false


func _gw_death_fall() -> void:
	if _gw_model == null: return
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(_gw_model, "rotation_degrees:x", 90.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_gw_model, "position:y", -0.4, 0.3)


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
		if not (n is Node3D) or not is_instance_valid(n): continue
		var d2 := global_position.distance_squared_to((n as Node3D).global_position)
		if d2 < best_d2: best_d2 = d2; best = n as Node3D
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
		var eff_range := ATTACK_RANGE * 2.0   # matches new scale
		if to_e.length() > eff_range:
			var dir := to_e.normalized()
			velocity.x = dir.x * MOVE_SPEED
			velocity.z = dir.z * MOVE_SPEED
			look_at(global_position + dir, Vector3.UP)
			_gw_play(_GW_ANIM_WALK)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			look_at(tgt.global_position, Vector3.UP)
			_attack_cd -= delta
			if _attack_cd <= 0.0 and tgt.has_method(&"apply_sword_hit"):
				_attack_cd = ATTACK_INTERVAL
				SoundManager.play_one_shot(SoundManager.KEY_SWORD_SWING, 0.14, -4.0)
				tgt.call(&"apply_sword_hit", melee_damage)
				_gw_play(_GW_ANIM_ATTACK, false)
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
			_gw_play(_GW_ANIM_WALK)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_gw_play(_GW_ANIM_IDLE)
	move_and_slide()


func apply_sword_hit(damage: int = 10, _attacker: Node = null) -> void:
	hp -= damage
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if hp <= 0:
		SoundManager.play_npc_death()
		GameState.has_giant_warrior = false
		set_physics_process(false)
		if _duel_enemy != null and is_instance_valid(_duel_enemy) and _duel_enemy.has_method(&"notify_ally_destroyed"):
			_duel_enemy.call(&"notify_ally_destroyed", self)
		if not _gw_play(_GW_ANIM_DEATH, false):
			_gw_death_fall()
		get_tree().create_timer(0.7).timeout.connect(queue_free)
	else:
		SoundManager.play_one_shot(SoundManager.KEY_SHIELD_HIT)
		_gw_play(_GW_ANIM_HIT, false)
