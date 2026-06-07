extends "res://scripts/warrior.gd"

## Attack-tab Knight — cheap reinforcement (2 coins). Spawns at the base,
## marches down the enemy path, and fights the first enemy it meets.
## Uses the standard warrior model/stats — independent of any barracks.

enum AKState { MARCH, IDLE, COMBAT }

const _AK_END_PROGRESS := 6.0

var _ak_state: AKState = AKState.MARCH
var _ak_path: Path3D = null
var _ak_path_progress: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(&"attack_knight")
	_init_path()


func _init_path() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_2:
		return
	var path := get_tree().get_first_node_in_group(&"m2_enemy_path") as Path3D
	if path == null:
		return
	_ak_path = path
	_ak_path_progress = path.curve.get_baked_length()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match _ak_state:
		AKState.MARCH:  _do_march(delta)
		AKState.IDLE:   _do_idle(delta)
		AKState.COMBAT: _do_combat(delta)

	_apply_separation()
	move_and_slide()


func _do_march(delta: float) -> void:
	if _pick_enemy() != null:
		_ak_state = AKState.COMBAT
		return
	if _ak_path != null:
		_do_march_path(delta)
	else:
		_do_march_direct()


func _do_march_path(delta: float) -> void:
	if _ak_path_progress <= _AK_END_PROGRESS:
		_ak_state = AKState.IDLE
		velocity.x = 0.0; velocity.z = 0.0
		_w_play(_W_ANIM_IDLE)
		return
	_ak_path_progress = maxf(_AK_END_PROGRESS, _ak_path_progress - MOVE_SPEED * delta)
	var local_pt := _ak_path.curve.sample_baked(_ak_path_progress, true)
	_walk_toward(_ak_path.to_global(local_pt))


func _do_march_direct() -> void:
	# Outside Mission 2 — no shared enemy path; march straight toward the enemy spawn area.
	var target := Vector3(10.0, global_position.y, 132.0)
	var to := target - global_position
	to.y = 0.0
	if to.length() <= 1.0:
		_ak_state = AKState.IDLE
		velocity.x = 0.0; velocity.z = 0.0
		_w_play(_W_ANIM_IDLE)
		return
	_walk_toward(target)


func _do_idle(_delta: float) -> void:
	velocity.x = 0.0; velocity.z = 0.0
	if _pick_enemy() != null:
		_ak_state = AKState.COMBAT
		return
	_w_play(_W_ANIM_IDLE)


func _do_combat(delta: float) -> void:
	var tgt := _pick_enemy()
	if tgt == null:
		_ak_state = AKState.MARCH if (_ak_path == null or _ak_path_progress > _AK_END_PROGRESS) else AKState.IDLE
		return
	var to_e := tgt.global_position - global_position
	to_e.y = 0.0
	if to_e.length() > ATTACK_RANGE - 0.15:
		_walk_toward(tgt.global_position)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		look_at(tgt.global_position, Vector3.UP)
		_attack_cd -= delta
		if _attack_cd <= 0.0 and tgt.has_method(&"apply_sword_hit"):
			_attack_cd = ATTACK_INTERVAL
			SoundManager.play_one_shot(SoundManager.KEY_SWORD_SWING, 0.14, -4.0)
			tgt.call(&"apply_sword_hit", melee_damage, self)
			_w_play(_W_ANIM_ATTACK, false)


func _walk_toward(target: Vector3) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.3:
		var dir := to.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		look_at(global_position + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
		_w_play(_W_ANIM_WALK)
	else:
		velocity.x = 0.0; velocity.z = 0.0
