extends "res://scripts/warrior.gd"

## Giant Warrior — forward defense interceptor.
## Spawns at base → marches to hold position → blocks all enemies.

# ─── Model ────────────────────────────────────────────────────────────────────
const _KNIGHT_PATH := "res://assets/models/knight.glb"

const _GW_ANIM_IDLE   := ["idle", "idle_combat"]
const _GW_ANIM_WALK   := ["walking", "combat_walk_forward"]
const _GW_ANIM_ATTACK := ["default_atack_full_combo", "default_atack_3", "atack_overhead"]
const _GW_ANIM_HIT    := ["pb_take_damage", "staggered_1", "poise_break"]
const _GW_ANIM_DEATH  := ["death", "death_poise_break"]

# ─── Positions ────────────────────────────────────────────────────────────────
## Enemy spawn is at (10, 0.55, 132) — Giant Warrior holds 15u in front of it.
const _ENEMY_SPAWN  := Vector3(10.0, 0.0, 132.0)
const _HOLD_POS     := Vector3(10.0, 0.0, 117.0)   # 15u before spawn
const _HOLD_RADIUS  := 2.0                           # "arrived" threshold

# ─── Stats ────────────────────────────────────────────────────────────────────
const _MELEE_RANGE   := 4.0    # short melee range (not 15u like before)
const _SPLASH_RADIUS := 4.0
const _SPLASH_PCT    := 0.20   # 20% splash damage

# ─── State machine ────────────────────────────────────────────────────────────
enum GWState { MARCH, HOLD, COMBAT }
var _gw_state: GWState = GWState.MARCH

var _gw_model: Node3D         = null
var _gw_anim:  AnimationPlayer = null


# ─── Init ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	add_to_group(&"giant_warrior")
	max_hp       = MAX_HP * 10
	hp           = max_hp
	melee_damage = MELEE_DAMAGE * 10
	scale        = Vector3.ONE * 2.0
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	_load_knight_model()


func _load_warrior_model() -> void:
	pass  # Prevent warrior.gd loading azure_sentinel


func apply_upgrade_level(_level: int) -> void:
	pass  # Stats are fixed


func _load_knight_model() -> void:
	if not ResourceLoader.exists(_KNIGHT_PATH): return
	var scene := load(_KNIGHT_PATH) as PackedScene
	if scene == null: return
	_gw_model = scene.instantiate() as Node3D
	if _gw_model == null: return
	_gw_model.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	add_child(_gw_model)
	_avatar_root.visible = false
	_gw_anim = _find_warrior_anim_player(_gw_model)
	if _gw_anim:
		_gw_play(_GW_ANIM_IDLE)


# ─── Accept duels from ALL enemies (blocks the whole group) ───────────────────
func can_accept_duel_from(_enemy: Node) -> bool:
	return true   # unlimited simultaneous engagements


# ─── Animation helper ─────────────────────────────────────────────────────────

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


# ─── Enemy search ─────────────────────────────────────────────────────────────

const GIANT_VISION := 63.0

func _pick_enemy() -> Node3D:
	# Engage ANY enemy within reach
	var vr2 := GIANT_VISION * GIANT_VISION
	var best: Node3D = null
	var best_d2 := vr2
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if not (n is Node3D) or not is_instance_valid(n): continue
		var d2 := global_position.distance_squared_to((n as Node3D).global_position)
		if d2 < best_d2: best_d2 = d2; best = n as Node3D
	return best


# ─── Splash damage ────────────────────────────────────────────────────────────

func _deal_splash_damage(primary: Node3D) -> void:
	var splash := int(float(melee_damage) * _SPLASH_PCT)
	if splash <= 0: return
	var r2 := _SPLASH_RADIUS * _SPLASH_RADIUS
	for n in get_tree().get_nodes_in_group(&"enemy"):
		if n == primary or not is_instance_valid(n) or not (n is Node3D): continue
		if global_position.distance_squared_to((n as Node3D).global_position) <= r2:
			if n.has_method(&"apply_sword_hit"):
				n.call(&"apply_sword_hit", splash, self)


# ─── State machine ────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match _gw_state:
		GWState.MARCH:  _do_march(delta)
		GWState.HOLD:   _do_hold(delta)
		GWState.COMBAT: _do_combat(delta)

	move_and_slide()


func _do_march(delta: float) -> void:
	# Transition: enemy nearby → fight
	if _pick_enemy() != null:
		_gw_state = GWState.COMBAT
		return

	# Move toward hold position
	var to := _HOLD_POS - global_position
	to.y = 0.0
	if to.length() <= _HOLD_RADIUS:
		_gw_state = GWState.HOLD
		velocity.x = 0.0; velocity.z = 0.0
		_gw_play(_GW_ANIM_IDLE)
		return

	var dir := to.normalized()
	velocity.x = dir.x * MOVE_SPEED
	velocity.z = dir.z * MOVE_SPEED
	look_at(global_position + dir, Vector3.UP)
	_gw_play(_GW_ANIM_WALK)


func _do_hold(_delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	if _pick_enemy() != null:
		_gw_state = GWState.COMBAT
		return
	_gw_play(_GW_ANIM_IDLE)


func _do_combat(delta: float) -> void:
	var tgt := _pick_enemy()
	if tgt == null:
		# Return to hold or resume march
		var to_hold := _HOLD_POS - global_position
		to_hold.y = 0.0
		_gw_state = GWState.HOLD if to_hold.length() <= _HOLD_RADIUS * 3.0 else GWState.MARCH
		return

	var to_e := tgt.global_position - global_position
	to_e.y = 0.0
	if to_e.length() > _MELEE_RANGE:
		var dir := to_e.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		look_at(global_position + dir, Vector3.UP)
		_gw_play(_GW_ANIM_WALK)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		look_at(tgt.global_position, Vector3.UP)
		_attack_cd -= delta
		if _attack_cd <= 0.0 and tgt.has_method(&"apply_sword_hit"):
			_attack_cd = ATTACK_INTERVAL
			SoundManager.play_one_shot(SoundManager.KEY_SWORD_SWING, 0.14, -4.0)
			tgt.call(&"apply_sword_hit", melee_damage, self)
			_deal_splash_damage(tgt)
			_gw_play(_GW_ANIM_ATTACK, false)


# ─── Damage reception ─────────────────────────────────────────────────────────

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
