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
const _BAT_PIG_MODEL_PATH  := "res://assets/models/bat_pig.glb"
const _MODEL_SCALE         := 1.0

# Animation arrays — first match wins across all enemy kinds
# BAT PIG anims: Armature|Idle, Armature|Walk, Armature|Shoot, Armature|Desh, Pig Enemy|Desh
const _ANIM_WALK   := ["CharacterArmature|Run", "CharacterArmature|Walk",
					   "root|Walk", "root|Idle_To_Walk",
					   "agent rig|demon melee move", "Armature|Walk", "Walk", "Run"]
const _ANIM_ATTACK := ["CharacterArmature|Punch", "CharacterArmature|Run_Attack",
					   "root|Attack", "agent rig|demon melee attack",
					   "Armature|Shoot",
					   "Armature|Attack", "Armature|Attack Double", "Attack", "Punch"]
const _ANIM_DEATH  := ["CharacterArmature|Death", "root|Death",
					   "Pig Enemy|Desh", "Armature|Desh",
					   "Armature|Death", "Death"]
const _ANIM_IDLE   := ["CharacterArmature|Idle",  "root|Idle",
					   "agent rig|demon melee idle", "Armature|Idle", "Armature|idle", "Idle"]
const _ANIM_HIT    := ["CharacterArmature|HitReact", "root|Damage",
					   "Armature|Desh",
					   "HitReaction", "HitReact", "Hit"]

const _BAT_PIG_FLY_HEIGHT  := 5.5   # ~3 soldiers stacked (each ~1.8u)
const _BAT_PIG_ATTACK_RANGE := 14.0  # ~50% of tower range (28u)
const _BAT_PIG_ATTACK_INTERVAL := 1.5

enum Kind    { NORMAL, BIG, BOSS, GOLEM, DEMON, BAT_PIG }
enum AState  { IDLE, WALK, ATTACK, DEAD }
enum DamageType { PHYSICAL, MAGIC }

var kind:               int  = Kind.NORMAL
var move_speed          := 9.0
var damage_to_base      := 10
var max_hp              := 40
var hp:                 int  = 40
var physical_resistance := 0.0
var magic_resistance    := 0.0
var is_flying           := false   # BAT_PIG: skip gravity, maintain fly height
var _fly_attack_cd      := 0.0

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
	if is_flying:
		add_to_group(&"flying_enemy")
	collision_layer = LAYER_ENEMY
	collision_mask  = 1
	var bar := Node3D.new()
	bar.set_script(preload("res://scripts/enemy_hp_bar.gd"))
	bar.name = &"EnemyHpBar"
	add_child(bar)
	_hp_bar = bar
	# Adjust HP bar height for Minotaur (model is ~3.5u tall at 0.06 vis scale)
	if kind == Kind.BOSS:
		bar.position.y = 3.8
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
			move_speed = 1.8; damage_to_base = 100; max_hp = 400
			# No node scale — visual scale applied to _model only in _load_model()
			# Resize collision to match Minotaur visual body (native model is large at 0.06 vis scale)
			var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col != null:
				var cap := CapsuleShape3D.new()
				cap.radius = 1.2
				cap.height = 3.5
				col.shape    = cap
				col.position = Vector3(0.0, 1.75, 0.0)
		Kind.GOLEM:
			move_speed          = 4.5
			damage_to_base      = 10
			max_hp              = 80
			physical_resistance = 0.20
			magic_resistance    = 0.50
			scale               = Vector3(2.0, 2.0, 2.0)
		Kind.DEMON:
			move_speed          = 9.9
			damage_to_base      = 15
			max_hp              = 60
			physical_resistance = 0.80
			magic_resistance    = 0.25
		Kind.BAT_PIG:
			move_speed     = 8.0
			damage_to_base = 8
			max_hp         = 50
			is_flying      = true
	if stat_multiplier != 1.0:
		damage_to_base = maxi(1, int(round(float(damage_to_base) * stat_multiplier)))
		max_hp         = maxi(1, int(round(float(max_hp) * stat_multiplier)))
	if size_multiplier != 1.0:
		scale *= size_multiplier
	hp = max_hp


# ─── MODEL LOADING ────────────────────────────────────────────────────────────

func _get_model_path() -> String:
	match kind:
		Kind.GOLEM:   return _GOLEM_MODEL_PATH
		Kind.BOSS:    return _MINOTAUR_MODEL_PATH
		Kind.DEMON:   return _DEMON_MODEL_PATH
		Kind.BAT_PIG: return _BAT_PIG_MODEL_PATH
		_:            return _MODEL_PATH


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
	# Per-kind visual scale — does NOT affect collision/hitbox
	var vis_scale: float = _MODEL_SCALE
	match kind:
		Kind.BOSS:    vis_scale = 0.06
		Kind.BAT_PIG: vis_scale = 0.035  # Root Scale = (0.035, 0.035, 0.035)
	_model.scale            = Vector3.ONE * vis_scale
	_model.position         = Vector3.ZERO
	_model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(_model)
	var cap := get_node_or_null("MeshInstance3D")
	if cap:
		(cap as Node3D).visible = false
	_anim_player = _find_anim_player(_model)
	if _anim_player:
		if kind == Kind.BAT_PIG:
			_strip_scale_tracks(_anim_player)
			# After stripping, normalize all skeleton bones to scale (1,1,1).
			# Some GLBs bake non-uniform bone scales into the rest pose that
			# combine with animation data to produce blob/deform in certain clips.
			_normalize_skeleton_scale(_model)
		_try_play(_ANIM_IDLE)


## Remove all scale-modifying tracks from every animation.
## Pass 1: TYPE_SCALE_3D  — direct scale tracks.
## Pass 2: TYPE_VALUE     — generic value tracks targeting ":scale" property.
##         These cause blob/deform in Attack because bones get non-uniform scales.
## Reset every Skeleton3D bone's scale to (1,1,1) in the rest pose.
## Fixes blob/deform when the GLB bakes unusual bone scales into the bind pose.
func _normalize_skeleton_scale(root: Node) -> void:
	if root == null: return
	if root is Skeleton3D:
		var skel := root as Skeleton3D
		for b in range(skel.get_bone_count()):
			var pose := skel.get_bone_rest(b)
			if pose.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
				var fixed := Transform3D(pose.basis.orthonormalized(), pose.origin)
				skel.set_bone_rest(b, fixed)
				skel.set_bone_pose_scale(b, Vector3.ONE)
	for child in root.get_children():
		_normalize_skeleton_scale(child)


func _strip_scale_tracks(ap: AnimationPlayer) -> void:
	var report: Array[String] = []
	for anim_name in ap.get_animation_list():
		var anim := ap.get_animation(anim_name)
		if anim == null: continue
		var removed_s3d := 0
		var removed_val := 0
		for i in range(anim.get_track_count() - 1, -1, -1):
			var ttype := anim.track_get_type(i)
			if ttype == Animation.TYPE_SCALE_3D:
				anim.remove_track(i)
				removed_s3d += 1
			elif ttype == Animation.TYPE_VALUE:
				# Check if this value track targets a :scale property
				var path_str := str(anim.track_get_path(i))
				if path_str.ends_with(":scale") or ":scale:" in path_str:
					anim.remove_track(i)
					removed_val += 1
		var total := removed_s3d + removed_val
		if total > 0:
			report.append("%s (SCALE_3D=%d, VALUE:scale=%d)" % [anim_name, removed_s3d, removed_val])
	if report.is_empty():
		print("BAT_PIG _strip_scale_tracks: no scale tracks found — deform may be from bone weights")
	else:
		print("BAT_PIG _strip_scale_tracks removed from: ", ", ".join(report))


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
	if is_flying:
		_physics_process_flying(delta)
		return

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
		_apply_separation()
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
	_apply_separation()
	move_and_slide()


# ─── Flying physics (BAT_PIG) ─────────────────────────────────────────────────

func _physics_process_flying(delta: float) -> void:
	# Smooth height correction — always maintain fly height
	velocity.y = clampf((_BAT_PIG_FLY_HEIGHT - global_position.y) * 6.0, -10.0, 10.0)

	# Giant Warrior interception — flying enemies must engage him first
	var gw := _pick_giant_warrior()
	if gw != null:
		var to_gw := gw.global_position - global_position
		to_gw.y = 0.0
		if to_gw.length() > _BAT_PIG_ATTACK_RANGE:
			var dir := to_gw.normalized()
			velocity.x = dir.x * move_speed; velocity.z = dir.z * move_speed
			look_at(global_position + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
			_set_anim(AState.WALK)
		else:
			velocity.x = 0.0; velocity.z = 0.0
			_set_anim(AState.ATTACK)
			_fly_attack_cd -= delta
			if _fly_attack_cd <= 0.0:
				_fly_attack_cd = _BAT_PIG_ATTACK_INTERVAL
				if gw.has_method(&"apply_sword_hit"):
					gw.call(&"apply_sword_hit", damage_to_base, self)
		_apply_flying_separation()
		move_and_slide()
		return

	# Move toward base target (at fly height)
	var fly_target := Vector3(BASE_TARGET.x, _BAT_PIG_FLY_HEIGHT, BASE_TARGET.z)
	var to_target  := fly_target - global_position
	to_target.y    = 0.0
	var dist       := to_target.length()

	if dist > _BAT_PIG_ATTACK_RANGE:
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		if dir.length_squared() > 0.001:
			look_at(global_position + dir, Vector3.UP)
		_set_anim(AState.WALK)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_set_anim(AState.ATTACK)

	_fly_attack_cd -= delta
	if dist <= _BAT_PIG_ATTACK_RANGE and _fly_attack_cd <= 0.0:
		_fly_attack_cd = _BAT_PIG_ATTACK_INTERVAL
		GameState.damage_base(damage_to_base)

	_apply_flying_separation()
	move_and_slide()


# ─── Separation helpers ───────────────────────────────────────────────────────

## Ground separation — pushes away from nearby enemies AND warriors (horizontal only).
func _apply_separation() -> void:
	const RADIUS := 1.8
	const FORCE  := 4.0
	var p    := global_position
	var push := Vector3.ZERO
	for grp: StringName in [&"enemy", &"warrior"]:
		for n in get_tree().get_nodes_in_group(grp):
			if n == self or not is_instance_valid(n) or not (n is Node3D): continue
			var diff := p - (n as Node3D).global_position
			diff.y = 0.0   # horizontal only
			var d := diff.length()
			if d > 0.001 and d < RADIUS:
				push += diff.normalized() * (RADIUS - d) / RADIUS * FORCE
	velocity.x += push.x
	velocity.z += push.z


## Giant Warrior targeting for flying enemies — engage him when in range.
func _pick_giant_warrior() -> Node3D:
	const GW_RANGE := 18.0
	var r2 := GW_RANGE * GW_RANGE
	for n in get_tree().get_nodes_in_group(&"giant_warrior"):
		if not is_instance_valid(n) or not (n is Node3D): continue
		var diff := global_position - (n as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() <= r2: return n as Node3D
	return null


## Flying separation — horizontal push from other flying enemies only.
func _apply_flying_separation() -> void:
	const RADIUS := 2.2
	const FORCE  := 4.0
	var p    := global_position
	var push := Vector3.ZERO
	for n in get_tree().get_nodes_in_group(&"flying_enemy"):
		if n == self or not is_instance_valid(n) or not (n is Node3D): continue
		var diff := p - (n as Node3D).global_position
		diff.y = 0.0
		var d := diff.length()
		if d > 0.001 and d < RADIUS:
			push += diff.normalized() * (RADIUS - d) / RADIUS * FORCE
	velocity.x += push.x
	velocity.z += push.z
