extends CharacterBody3D

const LAYER_ENEMY          := 256
const WARRIOR_VISION_RANGE := 42.0
const GRAVITY              := 30.0
const ATTACK_INTERVAL      := 0.85
const BASE_TARGET          := Vector3(6.0, 0.55, 0.0)
const ATTACK_RANGE         := 7.5

const _MODEL_PATH          := "res://assets/models/Zombie_Arm.fbx"
const _GOLEM_MODEL_PATH    := "res://assets/models/low_poly_animated_simple_golem.glb"
const _MINOTAUR_MODEL_PATH := "res://assets/models/minataur_low_poly.glb"
const _DEMON_MODEL_PATH    := "res://assets/models/demon_melee_-_animated__game_ready.glb"
const _MODEL_SCALE         := 1.0

# Animation arrays — first match wins across all enemy kinds
const _ANIM_WALK   := ["CharacterArmature|Run", "CharacterArmature|Walk",
					   "root|Walk", "root|Idle_To_Walk",
					   "agent rig|demon melee move", "Armature|Walk", "Walk", "Run"]
const _ANIM_ATTACK := ["CharacterArmature|Punch", "CharacterArmature|Run_Attack",
					   "root|Attack", "agent rig|demon melee attack",
					   "Armature|Attack", "Armature|Attack Double", "Attack", "Punch"]
const _ANIM_DEATH  := ["CharacterArmature|Death", "root|Death", "Armature|Death", "Death"]
const _ANIM_IDLE   := ["CharacterArmature|Idle",  "root|Idle",
					   "agent rig|demon melee idle", "Armature|idle", "Idle"]
const _ANIM_HIT    := ["CharacterArmature|HitReact", "root|Damage", "HitReaction", "HitReact", "Hit"]

enum Kind    { NORMAL, BIG, BOSS, GOLEM, DEMON }
enum AState  { IDLE, WALK, ATTACK, DEAD }
enum DamageType { PHYSICAL, MAGIC }

var kind:               int  = Kind.NORMAL
var move_speed          := 9.0
var damage_to_base      := 10
var max_hp              := 40
var hp:                 int  = 40
var physical_resistance := 0.0
var magic_resistance    := 0.0

var _attack_cd    := 0.0
var _hp_bar:       Node           = null
var _ally_target:  CharacterBody3D = null
var _model:        Node3D          = null
var _anim_player:  AnimationPlayer = null
var _astate:       AState          = AState.IDLE
var _proc_tween:   Tween           = null
var _walk_phase    := 0.0


func _exit_tree() -> void:
	_release_ally_target()


func _ready() -> void:
	add_to_group(&"enemy")
	collision_layer = LAYER_ENEMY
	collision_mask  = 1
	var bar := Node3D.new()
	bar.set_script(preload("res://scripts/enemy_hp_bar.gd"))
	bar.name = &"EnemyHpBar"
	add_child(bar)
	_hp_bar = bar
	_load_model()


func configure(kind_in: int, stat_multiplier: float = 1.0, size_multiplier: float = 1.0) -> void:
	kind = kind_in
	physical_resistance = 0.0
	magic_resistance    = 0.0
	match kind:
		Kind.NORMAL:
			move_speed = 9.0;  damage_to_base = 10;  max_hp = 40
		Kind.BIG:
			move_speed = 4.5;  damage_to_base = 20;  max_hp = 80
			scale = Vector3(2.0, 2.0, 2.0)
		Kind.BOSS:
			move_speed = 1.8;  damage_to_base = 100; max_hp = 400
			# No node scale — visual scale applied to _model only in _load_model()
		Kind.GOLEM:
			move_speed          = 4.5
			damage_to_base      = 10
			max_hp              = 80
			physical_resistance = 0.20
			magic_resistance    = 0.50
			scale               = Vector3(2.0, 2.0, 2.0)
		Kind.DEMON:
			move_speed          = 9.9   # 1.1x
			damage_to_base      = 15    # 1.5x
			max_hp              = 60    # 1.5x
			physical_resistance = 0.80
			magic_resistance    = 0.25
	if stat_multiplier != 1.0:
		damage_to_base = maxi(1, int(round(float(damage_to_base) * stat_multiplier)))
		max_hp         = maxi(1, int(round(float(max_hp) * stat_multiplier)))
	if size_multiplier != 1.0:
		scale *= size_multiplier
	hp = max_hp


# ─── MODEL LOADING ────────────────────────────────────────────────────────────

func _get_model_path() -> String:
	match kind:
		Kind.GOLEM: return _GOLEM_MODEL_PATH
		Kind.BOSS:  return _MINOTAUR_MODEL_PATH
		Kind.DEMON: return _DEMON_MODEL_PATH
		_:          return _MODEL_PATH


func _load_model() -> void:
	var path := _get_model_path()
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	if _model == null:
		return
	# For BOSS: scale only the visual mesh, not the node (preserves hitbox/HP bar)
	var vis_scale := 0.06 if kind == Kind.BOSS else _MODEL_SCALE
	_model.scale            = Vector3.ONE * vis_scale
	_model.position         = Vector3.ZERO
	_model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(_model)
	var cap := get_node_or_null("MeshInstance3D")
	if cap:
		(cap as Node3D).visible = false
	_anim_player = _find_anim_player(_model)
	if _anim_player:
		_try_play(_ANIM_IDLE)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null


# ─── ANIMATION ────────────────────────────────────────────────────────────────

func _try_play(names: Array, loop: bool = true) -> bool:
	if _anim_player == null:
		return false
	for n in names:
		if _anim_player.has_animation(n):
			var stopped := not _anim_player.is_playing()
			if _anim_player.current_animation != n or stopped:
				var anim := _anim_player.get_animation(n)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
				_anim_player.play(n)
			return true
	return false


func _set_anim(new_state: AState) -> void:
	var anim_stopped := _anim_player != null and not _anim_player.is_playing()
	if _astate == new_state and not anim_stopped:
		return
	_astate = new_state
	match new_state:
		AState.IDLE:
			if not _try_play(_ANIM_IDLE):   _stop_proc_anim()
		AState.WALK:
			if not _try_play(_ANIM_WALK):   _start_walk_bob()
		AState.ATTACK:
			if not _try_play(_ANIM_ATTACK): _do_attack_pulse()
		AState.DEAD:
			if not _try_play(_ANIM_DEATH, false): _do_death_fall()


func _start_walk_bob() -> void:
	if _model == null: return
	_stop_proc_anim()
	_proc_tween = create_tween().set_loops()
	var period := 0.55 / maxf(0.5, move_speed / 9.0)
	_proc_tween.tween_property(_model, "rotation_degrees:z",  7.0, period * 0.5).set_trans(Tween.TRANS_SINE)
	_proc_tween.tween_property(_model, "rotation_degrees:z", -7.0, period * 0.5).set_trans(Tween.TRANS_SINE)


func _stop_proc_anim() -> void:
	if _proc_tween: _proc_tween.kill(); _proc_tween = null
	if _model: _model.rotation_degrees = Vector3.ZERO


func _do_attack_pulse() -> void:
	if _model == null: return
	_stop_proc_anim()
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * 1.25, 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_model, "scale", Vector3.ONE * _MODEL_SCALE, 0.2).set_trans(Tween.TRANS_BACK)


func _do_death_fall() -> void:
	if _model == null: return
	_stop_proc_anim()
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(_model, "rotation_degrees:x", 90.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "position:y", -0.4, 0.3)


# ─── COMBAT ───────────────────────────────────────────────────────────────────

func apply_sword_hit(damage: int = 10, _attacker: Node = null,
		damage_type: int = DamageType.PHYSICAL) -> void:
	var resistance := magic_resistance if damage_type == DamageType.MAGIC else physical_resistance
	var actual := int(round(float(damage) * (1.0 - resistance)))
	hp -= actual
	FeedbackFx.spawn_hit_burst(get_parent(), global_position + Vector3(0.0, 1.0, 0.0), Color(0.78, 0.08, 0.06), 7, 0.85)
	if is_instance_valid(_hp_bar) and _hp_bar.has_method(&"set_hp"):
		_hp_bar.call(&"set_hp", hp, max_hp)
	if hp <= 0:
		_set_anim(AState.DEAD)
		set_physics_process(false)
		SoundManager.play_npc_death()
		FeedbackFx.show_coin_gain(get_parent(), global_position + Vector3(0.0, 1.35, 0.0), 1)
		GameState.add_coin()
		get_tree().create_timer(0.7).timeout.connect(queue_free)
	elif actual > 0:
		SoundManager.play_punch_for_target(get_instance_id())
		_try_play(_ANIM_HIT, false)


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
	var best_d2: float        = INF
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
		if d2 > vr2: continue
		if not u.has_method(&"can_accept_duel_from"): continue
		if not (u.call(&"can_accept_duel_from", self) as bool): continue
		if d2 < best_d2:
			best_d2 = d2; best = u
	return best


# ─── PHYSICS ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

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

	var vr2 := WARRIOR_VISION_RANGE * WARRIOR_VISION_RANGE
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
			_set_anim(AState.WALK)
		else:
			velocity.x = 0.0; velocity.z = 0.0
			_set_anim(AState.ATTACK)
		_attack_cd -= delta
		if dist_w < ATTACK_RANGE and _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			if _ally_target.has_method(&"apply_sword_hit"):
				_ally_target.call(&"apply_sword_hit", damage_to_base, self)
		move_and_slide()
		return

	var to   := BASE_TARGET - global_position
	to.y     = 0.0
	var dist := to.length()
	if dist > 0.25:
		var dir := to.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		look_at(global_position + dir, Vector3.UP)
		_set_anim(AState.WALK)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		_set_anim(AState.ATTACK)
	_attack_cd -= delta
	if dist < ATTACK_RANGE and _attack_cd <= 0.0:
		_attack_cd = ATTACK_INTERVAL
		GameState.damage_base(damage_to_base)
	move_and_slide()
