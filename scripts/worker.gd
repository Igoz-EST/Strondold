extends CharacterBody3D

const _HumanoidAvatarBuilder := preload("res://scripts/humanoid_avatar_builder.gd")

## Половина скорости героя (12 → 6).
const SPEED := 6.0
const GRAVITY := 30.0
const MINE_REACH := 6.0
const BASE_REACH := 4.2
const CARRY_CAP := 75

const MINE_HIT_INTERVAL := 0.55
const SWING_OUT := 0.22
const SWING_BACK := 0.18

const WORKER_MAX_HP := 100
const AVATAR_SCALE := 0.88
const DEFAULT_MASK := 33
const MINING_MASK := 1
## Угол пола с вертикалью (рад): выше — считаем крутым склоном шахты, идём вниз по склону, а не впрямь вверх.
const STEEP_FLOOR_ANGLE := 0.4

## Застрял: хочет идти к цели, но почти не смещается по горизонтали.
const STUCK_TIME := 0.55
const STUCK_MOVE_EPS := 0.028
const STUCK_INTENT_MIN := 2.0
const UNSTUCK_JUMP_COUNT := 4
const UNSTUCK_JUMP_COOLDOWN := 0.42
## Высота прыжка при от unstuck (выше — сильнее выпрыгивает).
const UNSTUCK_JUMP_HEIGHT := 1.12
const UNSTUCK_JUMP_VEL := sqrt(2.0 * GRAVITY * UNSTUCK_JUMP_HEIGHT)
## Во время прыжковой фазы идёт вперёд к цели (и в воздухе тоже).
const UNSTUCK_JUMP_FORWARD_SPEED := SPEED * 0.75
const UNSTUCK_SIDE_TIME := 1.05
const UNSTUCK_SIDE_SPEED_MUL := 0.85

enum { GO_MINE, MINING, GO_BASE, UNLOAD, IDLE, DEAD }
enum _Unstuck { NONE, JUMP_BURST, SIDE_STEP }

var _state: int = GO_MINE
var _carry: int = 0
var _target_mine: Node = null
var _deposit_global: Vector3 = Vector3.ZERO
## Если не null и ближе базы — несём руду на склад (та же GameState.ore).
var _unload_warehouse: Node = null

var hp: int = WORKER_MAX_HP

var _pickaxe_pivot: Node3D
var _swing_elapsed := 0.0
var _swinging := false
var _strike_applied := false
var _cooldown := 0.0

var _hp_bar_fill: MeshInstance3D
var _hp_fill_box: BoxMesh

var _stuck_accum := 0.0
var _unstuck: int = _Unstuck.NONE
var _jumps_done := 0
var _jump_cd := 0.0
var _side_time := 0.0
var _side_dir_xz := Vector2.ZERO

var _duel_enemy: CharacterBody3D = null

## Локальный поворот кирки в покое (родитель — ArmR); Z меняется при ударе.
const PICKAXE_REST_ROT_DEG := Vector3(18.0, -28.0, 55.0)
const PICKAXE_HAND_POS := Vector3(0.1, -0.4, 0.05)

@onready var _avatar_root: Node3D = $AvatarRoot
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _walk_phase := 0.0


func setup(deposit_world: Vector3) -> void:
	_deposit_global = deposit_world


func _ready() -> void:
	add_to_group(&"worker")
	collision_layer = 32
	collision_mask = DEFAULT_MASK
	# Капсула: низ в y=0 тела; меш с scale 0.88 — чуть ниже нуля, поднимаем AvatarRoot (не как у героя с коробкой −0.46).
	_HumanoidAvatarBuilder.build(
		_avatar_root,
		Color(0.92, 0.78, 0.12),
		true,
		AVATAR_SCALE,
		0.08
	)
	_cache_avatar_limbs()
	_build_pickaxe()
	_setup_hp_bar()


func _mine_outward_dir_xz(mine: Node) -> Vector2:
	if mine == null or not is_instance_valid(mine):
		return Vector2(1.0, 0.0)
	var c: Vector3 = mine.global_transform * Vector3(0.0, -3.9, 0.0)
	var d := Vector2(global_position.x - c.x, global_position.z - c.z)
	if d.length_squared() < 0.0004:
		d = Vector2(1.0, 0.0)
	return d.normalized()


func _cache_avatar_limbs() -> void:
	_leg_l = _avatar_root.get_node_or_null("LegL") as Node3D
	_leg_r = _avatar_root.get_node_or_null("LegR") as Node3D
	_arm_l = _avatar_root.get_node_or_null("ArmL") as Node3D
	_arm_r = _avatar_root.get_node_or_null("ArmR") as Node3D


func _refresh_nearest_unload() -> void:
	_unload_warehouse = null
	var p := global_position
	var best_d := p.distance_squared_to(_deposit_global)
	for n in get_tree().get_nodes_in_group(&"warehouse"):
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method(&"get_unload_anchor_global"):
			continue
		var uw: Vector3 = n.call(&"get_unload_anchor_global") as Vector3
		var d := p.distance_squared_to(uw)
		if d < best_d:
			best_d = d
			_unload_warehouse = n


func _unload_destination() -> Vector3:
	_refresh_nearest_unload()
	if _unload_warehouse != null and is_instance_valid(_unload_warehouse) and _unload_warehouse.has_method(&"get_unload_anchor_global"):
		return _unload_warehouse.call(&"get_unload_anchor_global") as Vector3
	return _deposit_global


func _nearest_unload_for_point(point: Vector3) -> Vector3:
	var best := _deposit_global
	var best_d := point.distance_squared_to(best)
	for n in get_tree().get_nodes_in_group(&"warehouse"):
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method(&"get_unload_anchor_global"):
			continue
		var uw: Vector3 = n.call(&"get_unload_anchor_global") as Vector3
		var d := point.distance_squared_to(uw)
		if d < best_d:
			best_d = d
			best = uw
	return best


func is_alive_for_combat() -> bool:
	return _state != DEAD and hp > 0


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


func _build_pickaxe() -> void:
	_pickaxe_pivot = Node3D.new()
	_pickaxe_pivot.name = &"PickaxePivot"
	if _arm_r != null:
		_arm_r.add_child(_pickaxe_pivot)
		_pickaxe_pivot.position = PICKAXE_HAND_POS
		_pickaxe_pivot.rotation_degrees = PICKAXE_REST_ROT_DEG
	else:
		_pickaxe_pivot.position = Vector3(0.38, 0.9, 0.07)
		add_child(_pickaxe_pivot)

	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.07, 0.42, 0.07)
	handle.mesh = hm
	handle.position = Vector3(0.0, -0.12, 0.0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.32, 0.22, 0.12)
	hmat.roughness = 0.88
	handle.set_surface_override_material(0, hmat)
	_pickaxe_pivot.add_child(handle)

	var head := MeshInstance3D.new()
	var wedge := BoxMesh.new()
	wedge.size = Vector3(0.2, 0.12, 0.14)
	head.mesh = wedge
	head.rotation_degrees = Vector3(15.0, 20.0, -35.0)
	head.position = Vector3(0.16, 0.2, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.55, 0.58, 0.62)
	pmat.metallic = 0.65
	pmat.roughness = 0.35
	head.set_surface_override_material(0, pmat)
	_pickaxe_pivot.add_child(head)


func _setup_hp_bar() -> void:
	var root := Node3D.new()
	root.name = &"WorkerHpBar"
	root.position = Vector3(0.0, 1.72, 0.0)
	add_child(root)

	var bg := MeshInstance3D.new()
	var bg_b := BoxMesh.new()
	bg_b.size = Vector3(0.72, 0.1, 0.03)
	bg.mesh = bg_b
	bg.set_surface_override_material(0, UiStyle.bar_bg_material())
	root.add_child(bg)

	_hp_fill_box = BoxMesh.new()
	_hp_fill_box.size = Vector3(0.68, 0.07, 0.024)
	_hp_bar_fill = MeshInstance3D.new()
	_hp_bar_fill.mesh = _hp_fill_box
	_hp_bar_fill.set_surface_override_material(0, UiStyle.bar_fill_material(UiStyle.BAR_ALLY_HP))
	_hp_bar_fill.position.z = 0.018
	root.add_child(_hp_bar_fill)
	_refresh_hp_bar_mesh()


func _refresh_hp_bar_mesh() -> void:
	if _hp_fill_box == null:
		return
	var ratio := clampf(float(hp) / float(WORKER_MAX_HP), 0.0, 1.0)
	var w := 0.68 * ratio
	_hp_fill_box.size = Vector3(maxf(w, 0.03), 0.07, 0.024)
	_hp_bar_fill.position.x = -0.34 + _hp_fill_box.size.x * 0.5


func apply_sword_hit(damage: int = 10, attacker: Node = null) -> void:
	if _state == DEAD:
		return
	hp -= damage
	_refresh_hp_bar_mesh()
	if hp <= 0:
		SoundManager.play_npc_death()
		_state = DEAD
		if _duel_enemy != null and is_instance_valid(_duel_enemy) and _duel_enemy.has_method(&"notify_ally_destroyed"):
			_duel_enemy.call(&"notify_ally_destroyed", self)
		_duel_enemy = null
		queue_free()
		return
	if attacker != null and is_instance_valid(attacker):
		if attacker.is_in_group(&"enemy"):
			SoundManager.play_punch_for_target(get_instance_id())
		else:
			SoundManager.play_punch_for_target(get_instance_id(), -3.0)


func _process(_delta: float) -> void:
	var bar := get_node_or_null("WorkerHpBar")
	if bar == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	bar.look_at(cam.global_position, Vector3.UP)
	bar.rotate_object_local(Vector3.UP, PI)


func _physics_process(delta: float) -> void:
	if _state == DEAD:
		return

	if _duel_enemy != null and not is_instance_valid(_duel_enemy):
		_duel_enemy = null

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var pos_before := global_position

	match _state:
		GO_MINE:
			collision_mask = DEFAULT_MASK
			_stop_swing_visual()
			_pick_nearest_mine()
			if _target_mine == null:
				_reset_stuck()
				velocity.x = 0.0
				velocity.z = 0.0
				_state = IDLE
			else:
				var anchor: Vector3 = _target_mine.call(&"get_work_anchor_global") as Vector3
				var to_m := anchor - global_position
				to_m.y = 0.0
				if to_m.length() < MINE_REACH:
					_reset_stuck()
					velocity.x = 0.0
					velocity.z = 0.0
					_cooldown = 0.0
					_swinging = false
					_strike_applied = false
					_swing_elapsed = 0.0
					_state = MINING
					collision_mask = MINING_MASK
					look_at(Vector3(anchor.x, global_position.y, anchor.z), Vector3.UP)
				elif _unstuck != _Unstuck.NONE:
					_apply_unstuck_movement(delta, to_m.normalized())
				else:
					var dir := to_m.normalized()
					var d_xz := Vector2(dir.x, dir.z)
					if is_on_floor() and get_floor_angle() > STEEP_FLOOR_ANGLE and _target_mine != null:
						var out_xz := _mine_outward_dir_xz(_target_mine)
						d_xz = d_xz.lerp(out_xz, 0.62).normalized()
					velocity.x = d_xz.x * SPEED
					velocity.z = d_xz.y * SPEED
					look_at(global_position + Vector3(d_xz.x, 0.0, d_xz.y), Vector3.UP)

		MINING:
			collision_mask = MINING_MASK
			var mine_ok := _target_mine != null and is_instance_valid(_target_mine)
			if not mine_ok:
				_target_mine = null
				collision_mask = DEFAULT_MASK
				_reset_stuck()
				_state = GO_BASE if _carry > 0 else GO_MINE
			elif int(_target_mine.call(&"get_ore_remaining")) <= 0:
				_target_mine = null
				collision_mask = DEFAULT_MASK
				_reset_stuck()
				_state = GO_BASE if _carry > 0 else GO_MINE
			else:
				var anchor2: Vector3 = _target_mine.call(&"get_work_anchor_global") as Vector3
				look_at(Vector3(anchor2.x, global_position.y, anchor2.z), Vector3.UP)
				velocity.x = 0.0
				velocity.z = 0.0

				if _swinging:
					_swing_elapsed += delta
					var u := clampf(_swing_elapsed / SWING_OUT, 0.0, 1.0)
					var u2 := 0.0
					if _swing_elapsed > SWING_OUT:
						u2 = clampf((_swing_elapsed - SWING_OUT) / SWING_BACK, 0.0, 1.0)
					var ang := lerpf(55.0, -48.0, u) if _swing_elapsed <= SWING_OUT else lerpf(-48.0, 55.0, u2)
					if _pickaxe_pivot:
						_pickaxe_pivot.rotation_degrees = Vector3(
							PICKAXE_REST_ROT_DEG.x,
							PICKAXE_REST_ROT_DEG.y,
							ang
						)

					if not _strike_applied and _swing_elapsed >= SWING_OUT * 0.55:
						_strike_applied = true
						_do_pickaxe_strike()

					if _swing_elapsed >= SWING_OUT + SWING_BACK:
						_swinging = false
						_strike_applied = false
						_swing_elapsed = 0.0
						_cooldown = MINE_HIT_INTERVAL
				else:
					_cooldown -= delta
					if _pickaxe_pivot:
						_pickaxe_pivot.rotation_degrees = PICKAXE_REST_ROT_DEG
					if _cooldown <= 0.0 and _carry < CARRY_CAP:
						_swinging = true
						_swing_elapsed = 0.0
						_strike_applied = false

				if _carry >= CARRY_CAP:
					collision_mask = DEFAULT_MASK
					_stop_swing_visual()
					_reset_stuck()
					_state = GO_BASE

		GO_BASE:
			collision_mask = DEFAULT_MASK
			_stop_swing_visual()
			var dest: Vector3 = _unload_destination()
			var to_b := dest - global_position
			to_b.y = 0.0
			if to_b.length() < BASE_REACH:
				_reset_stuck()
				velocity.x = 0.0
				velocity.z = 0.0
				_state = UNLOAD
			elif _unstuck != _Unstuck.NONE:
				_apply_unstuck_movement(delta, to_b.normalized())
			else:
				var d := to_b.normalized()
				velocity.x = d.x * SPEED
				velocity.z = d.z * SPEED
				look_at(global_position + d, Vector3.UP)

		UNLOAD:
			collision_mask = DEFAULT_MASK
			_stop_swing_visual()
			if _carry > 0:
				FeedbackFx.show_ore_gain(get_parent(), global_position + Vector3(0.0, 1.55, 0.0), _carry)
				GameState.add_ore(_carry)
			_carry = 0
			_unload_warehouse = null
			_state = GO_MINE

		IDLE:
			collision_mask = DEFAULT_MASK
			_stop_swing_visual()
			_reset_stuck()
			velocity.x = 0.0
			velocity.z = 0.0
			_pick_nearest_mine()
			if _target_mine != null:
				_state = GO_MINE

	var intent_xz := Vector2(velocity.x, velocity.z).length()
	move_and_slide()

	if _state == GO_MINE or _state == GO_BASE:
		_update_stuck_after_move(pos_before, intent_xz, delta)

	_update_worker_walk_anim(delta)


func _reset_stuck() -> void:
	_stuck_accum = 0.0
	_unstuck = _Unstuck.NONE
	_jumps_done = 0
	_jump_cd = 0.0
	_side_time = 0.0
	_side_dir_xz = Vector2.ZERO


func _update_stuck_after_move(pos_before: Vector3, intent_xz: float, delta: float) -> void:
	if _unstuck != _Unstuck.NONE:
		return
	var moved_h := Vector2(global_position.x - pos_before.x, global_position.z - pos_before.z).length()
	if intent_xz >= STUCK_INTENT_MIN and moved_h < STUCK_MOVE_EPS:
		_stuck_accum += delta
		if _stuck_accum >= STUCK_TIME:
			_begin_unstuck_jump_phase()
	else:
		_stuck_accum = maxf(0.0, _stuck_accum - delta * 2.0)


func _begin_unstuck_jump_phase() -> void:
	_stuck_accum = 0.0
	_unstuck = _Unstuck.JUMP_BURST
	_jumps_done = 0
	_jump_cd = 0.0


func _apply_unstuck_movement(delta: float, toward_xz: Vector3) -> void:
	toward_xz.y = 0.0
	match _unstuck:
		_Unstuck.JUMP_BURST:
			var dir_xz := Vector2(toward_xz.x, toward_xz.z)
			if dir_xz.length_squared() < 0.0001:
				dir_xz = Vector2(0.0, 1.0)
			dir_xz = dir_xz.normalized()
			velocity.x = dir_xz.x * UNSTUCK_JUMP_FORWARD_SPEED
			velocity.z = dir_xz.y * UNSTUCK_JUMP_FORWARD_SPEED
			look_at(global_position + Vector3(dir_xz.x, 0.0, dir_xz.y), Vector3.UP)
			_jump_cd -= delta
			if is_on_floor():
				if _jumps_done < UNSTUCK_JUMP_COUNT and _jump_cd <= 0.0:
					velocity.y = UNSTUCK_JUMP_VEL
					_jumps_done += 1
					_jump_cd = UNSTUCK_JUMP_COOLDOWN
				elif _jumps_done >= UNSTUCK_JUMP_COUNT and absf(velocity.y) < 0.2:
					_begin_side_step(toward_xz)
		_Unstuck.SIDE_STEP:
			_side_time -= delta
			velocity.x = _side_dir_xz.x * SPEED * UNSTUCK_SIDE_SPEED_MUL
			velocity.z = _side_dir_xz.y * SPEED * UNSTUCK_SIDE_SPEED_MUL
			if _side_dir_xz.length_squared() > 0.0001:
				var sd := Vector3(_side_dir_xz.x, 0.0, _side_dir_xz.y).normalized()
				look_at(global_position + sd, Vector3.UP)
			if _side_time <= 0.0:
				_reset_stuck()


func _begin_side_step(toward_xz: Vector3) -> void:
	var t2 := Vector2(toward_xz.x, toward_xz.z)
	if t2.length_squared() < 0.0001:
		t2 = Vector2(1.0, 0.0)
	t2 = t2.normalized()
	# Перпендикуляр к направлению на цель; случайный знак.
	var perp := Vector2(-t2.y, t2.x)
	if randf() < 0.5:
		perp = -perp
	_side_dir_xz = perp.normalized()
	_side_time = UNSTUCK_SIDE_TIME
	_unstuck = _Unstuck.SIDE_STEP


func _do_pickaxe_strike() -> void:
	if _target_mine == null or not is_instance_valid(_target_mine):
		return
	var space_left: int = CARRY_CAP - _carry
	if space_left <= 0:
		return
	var want: int = mini(10, space_left)
	var got: int = int(_target_mine.call(&"try_extract_worker_batch", want))
	_carry += got


func _stop_swing_visual() -> void:
	if _pickaxe_pivot:
		_pickaxe_pivot.rotation_degrees = PICKAXE_REST_ROT_DEG


func _update_worker_walk_anim(delta: float) -> void:
	if _leg_l == null or _leg_r == null or _arm_l == null or _arm_r == null:
		return
	if _state == DEAD:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	var on_floor := is_on_floor()
	var leg_tgt := 0.0
	var arm_tgt := 0.0
	if on_floor and hs > 0.12:
		_walk_phase += delta * clampf(hs * 9.0, 4.0, 15.0)
		var s := sin(_walk_phase)
		leg_tgt = deg_to_rad(28.0) * s
		arm_tgt = -deg_to_rad(22.0) * s
	var n := 12.0 * delta
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_tgt, n)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -leg_tgt, n)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_tgt, n)
	## Правая рука держит кирку: меньше размах, чтобы инструмент не уходил в тело.
	var arm_r_tgt := arm_tgt * 0.55
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_r_tgt, n)


func _pick_nearest_mine() -> void:
	var best: Node = null
	var best_route := INF
	for n in get_tree().get_nodes_in_group(&"mine"):
		if n == null or not is_instance_valid(n):
			continue
		if not n.has_method(&"get_ore_remaining"):
			continue
		if int(n.call(&"get_ore_remaining")) <= 0:
			continue
		var mine_node := n as Node3D
		var anchor: Vector3 = mine_node.global_position
		if n.has_method(&"get_work_anchor_global"):
			anchor = n.call(&"get_work_anchor_global") as Vector3
		var unload := _nearest_unload_for_point(anchor)
		var route := global_position.distance_to(anchor) + anchor.distance_to(unload)
		if route < best_route:
			best_route = route
			best = n
	_target_mine = best
