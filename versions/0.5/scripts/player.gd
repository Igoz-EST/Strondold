extends CharacterBody3D

const SPEED := 12.0
## Same as player cube height in `main.tscn` — jump apex is one body height above feet.
const PLAYER_HEIGHT := 1.0
const GRAVITY := 30.0
const JUMP_VELOCITY := sqrt(2.0 * GRAVITY * PLAYER_HEIGHT)
const MOUSE_SENS := 0.0025
const PITCH_MIN := -50.0
const PITCH_MAX := 55.0

const COMMANDER_CAM_HEIGHT := 34.0
const COMMANDER_ORBIT_RADIUS := 22.0
const COMMANDER_PAN_SPEED := 22.0
const COMMANDER_FOCUS_CLAMP := 118.0

const _HumanoidAvatarBuilder := preload("res://scripts/humanoid_avatar_builder.gd")

const SWING_OUT := 0.15
const SWING_BACK := 0.2
## Horizontal swing (Y axis): from right side toward front, like a side slash.
const SWING_Y_REST := 92.0
const SWING_Y_STRIKE := -40.0
const ATTACK_COOLDOWN := 1.0
const SWORD_DAMAGE := 10
const LAYER_ENEMY := 256
## Ground (1) + breakables (32) + враги (256).
const DEFAULT_COLLISION_MASK := 33 | LAYER_ENEMY

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D
@onready var _avatar_root: Node3D = $AvatarRoot
@onready var _player_collision: CollisionShape3D = $CollisionShape3D
@onready var _commander_cam: Camera3D = $"../CommanderCameraRig/Camera3D"
@onready var _base_collision: CollisionShape3D = $"../Base/CollisionShape3D"
@onready var _command_zone: Area3D = $"../BaseCommandZone"
@onready var _interior_spawn: Node3D = $"../InteriorSpawn"
@onready var _exterior_spawn: Node3D = $"../ExteriorSpawn"

var _inside_base := false
var _in_command_zone := false
var _commander_focus := Vector3.ZERO
var _commander_yaw := 0.0
var _saved_collision_layer: int = 2
var _saved_collision_mask: int = DEFAULT_COLLISION_MASK

var _attack_ready_at := 0.0
var _sword_swinging := false
var _sword_swing_elapsed := 0.0

var _sword_hilt: Node3D
var _swing_pivot: Node3D
var _swing_arc: MeshInstance3D
var _sword_hit_area: Area3D
var _hit_collision: CollisionShape3D
var _hit_box: BoxShape3D
## One damage per breakable per swing (hitbox can overlap several frames).
var _hit_ids_this_swing: Dictionary = {}

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _walk_phase: float = 0.0


func _ready() -> void:
	set_process_unhandled_input(true)
	_setup_avatar_visual()
	_setup_sword_visuals()
	_setup_sword_hitbox()
	if not InputMap.has_action(&"jump"):
		InputMap.add_action(&"jump")
		var space := InputEventKey.new()
		space.physical_keycode = KEY_SPACE
		InputMap.action_add_event(&"jump", space)
	if not InputMap.has_action(&"interact"):
		InputMap.add_action(&"interact")
		var key_e := InputEventKey.new()
		key_e.physical_keycode = KEY_E
		InputMap.action_add_event(&"interact", key_e)
	_command_zone.body_entered.connect(_on_command_zone_body_entered)
	_command_zone.body_exited.connect(_on_command_zone_body_exited)
	_commander_cam.current = false
	_reset_sword_pose()
	call_deferred("_start_game_in_commander")


func _start_game_in_commander() -> void:
	get_viewport().gui_release_focus()
	_enter_commander_mode()


func _deferred_release_focus() -> void:
	if _inside_base:
		return
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_avatar_visual() -> void:
	_HumanoidAvatarBuilder.build(_avatar_root, Color(0.15, 0.52, 0.92), false, 1.0)
	_leg_l = _avatar_root.get_node_or_null("LegL") as Node3D
	_leg_r = _avatar_root.get_node_or_null("LegR") as Node3D
	_arm_l = _avatar_root.get_node_or_null("ArmL") as Node3D
	_arm_r = _avatar_root.get_node_or_null("ArmR") as Node3D


func _update_walk_animation(delta: float) -> void:
	if _inside_base or _leg_l == null:
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	var on_floor := is_on_floor()
	var leg_tgt := 0.0
	var arm_tgt := 0.0
	if on_floor and hs > 0.18:
		_walk_phase += delta * clampf(hs * 10.0, 5.0, 18.0)
		var s := sin(_walk_phase)
		leg_tgt = deg_to_rad(32.0) * s
		arm_tgt = -deg_to_rad(26.0) * s
	var n := 14.0 * delta
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_tgt, n)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -leg_tgt, n)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_tgt, n)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -arm_tgt, n)


func _setup_sword_visuals() -> void:
	# Pivot at the character's right — swing rotates around vertical (Y), slash travels side → front.
	_sword_hilt = Node3D.new()
	_sword_hilt.name = "SwordHilt"
	_sword_hilt.position = Vector3(0.46, 0.02, -0.1)
	add_child(_sword_hilt)

	_swing_pivot = Node3D.new()
	_swing_pivot.name = "SwingPivot"
	_sword_hilt.add_child(_swing_pivot)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.56, 0.09, 0.11)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.3, 0.06, 0.0)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.88, 0.9, 0.96)
	blade_mat.metallic = 0.75
	blade_mat.roughness = 0.28
	blade.set_surface_override_material(0, blade_mat)
	_swing_pivot.add_child(blade)

	_swing_arc = MeshInstance3D.new()
	_swing_arc.name = "SwingArc"
	# Сектор с небольшой высотой — сверху видна площадь, не только ребро плоскости.
	_swing_arc.mesh = _make_slash_fan_mesh(22, 38.0, 198.0, 0.05, 1.05)
	_swing_arc.position = Vector3(0.0, 0.04, 0.0)
	_swing_arc.visible = false
	var arc_mat := StandardMaterial3D.new()
	arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arc_mat.albedo_color = Color(0.96, 0.98, 1.0, 0.52)
	arc_mat.roughness = 0.35
	arc_mat.emission_enabled = true
	arc_mat.emission = Color(0.55, 0.72, 1.0)
	arc_mat.emission_energy_multiplier = 0.85
	arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_swing_arc.set_surface_override_material(0, arc_mat)
	_swing_pivot.add_child(_swing_arc)


func _setup_sword_hitbox() -> void:
	# Large box in front of the hero; damage uses physics intersect_shape (reliable with StaticBody3D).
	_sword_hit_area = Area3D.new()
	_sword_hit_area.name = "SwordHitbox"
	_sword_hit_area.collision_layer = 0
	_sword_hit_area.collision_mask = 32 | LAYER_ENEMY
	_sword_hit_area.monitoring = true
	_sword_hit_area.monitorable = false
	_hit_collision = CollisionShape3D.new()
	_hit_collision.name = "HitCollision"
	_hit_box = BoxShape3D.new()
	_hit_box.size = Vector3(2.6, 6.0, 2.4)
	_hit_collision.shape = _hit_box
	_hit_collision.position = Vector3(0.0, 3.0, -1.45)
	_sword_hit_area.add_child(_hit_collision)
	add_child(_sword_hit_area)


func _slash_push_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


func _make_slash_fan_mesh(segments: int, deg_from: float, deg_to: float, r_in: float, r_out: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rf := deg_to_rad(deg_from)
	var rt := deg_to_rad(deg_to)
	var y_lo := 0.02
	var y_hi := 0.16
	for i in range(segments):
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var a0 := lerpf(rf, rt, t0)
		var a1 := lerpf(rf, rt, t1)
		var ib0 := Vector3(sin(a0) * r_in, y_lo, cos(a0) * r_in)
		var ib1 := Vector3(sin(a1) * r_in, y_lo, cos(a1) * r_in)
		var ob0 := Vector3(sin(a0) * r_out, y_lo, cos(a0) * r_out)
		var ob1 := Vector3(sin(a1) * r_out, y_lo, cos(a1) * r_out)
		var it0 := Vector3(sin(a0) * r_in, y_hi, cos(a0) * r_in)
		var it1 := Vector3(sin(a1) * r_in, y_hi, cos(a1) * r_in)
		var ot0 := Vector3(sin(a0) * r_out, y_hi, cos(a0) * r_out)
		var ot1 := Vector3(sin(a1) * r_out, y_hi, cos(a1) * r_out)
		_slash_push_tri(st, it0, ot1, ot0)
		_slash_push_tri(st, it0, it1, ot1)
		_slash_push_tri(st, ib0, ob0, ob1)
		_slash_push_tri(st, ib0, ob1, ib1)
		_slash_push_tri(st, ob0, ot0, ot1)
		_slash_push_tri(st, ob0, ot1, ob1)
		_slash_push_tri(st, ib1, it1, it0)
		_slash_push_tri(st, ib1, it0, ib0)
	return st.commit()


func _on_command_zone_body_entered(body: Node3D) -> void:
	if body == self:
		_in_command_zone = true


func _on_command_zone_body_exited(body: Node3D) -> void:
	if body == self:
		_in_command_zone = false


func _unhandled_input(event: InputEvent) -> void:
	if GameState.dev_console_open:
		return

	if _inside_base and event is InputEventMouseButton and event.pressed:
		if GameState.awaiting_build_type != GameState.BUILD_NONE:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				GameState.cancel_tower_blueprint()
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT:
				if get_viewport().gui_get_hovered_control() != null:
					return
				var gp: Variant = _commander_ground_hit(event.position)
				if gp != null and GameState.try_place_tower(gp as Vector3):
					get_viewport().set_input_as_handled()
				return

	if _inside_base and event is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_commander_yaw -= event.relative.x * MOUSE_SENS

	if not _inside_base and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_start_swing()

	if event.is_action_pressed(&"ui_cancel"):
		if _inside_base:
			if GameState.awaiting_build_type != GameState.BUILD_NONE:
				GameState.cancel_tower_blueprint()
			else:
				_exit_commander_mode()
		else:
			GameState.request_pause_menu_toggle()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _inside_base:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_spring_arm.rotate_x(-event.relative.y * MOUSE_SENS)
		var pitch := _spring_arm.rotation_degrees.x
		_spring_arm.rotation_degrees.x = clampf(pitch, PITCH_MIN, PITCH_MAX)


func _commander_ground_hit(screen_pos: Vector2) -> Variant:
	var from := _commander_cam.project_ray_origin(screen_pos)
	var dir := _commander_cam.project_ray_normal(screen_pos)
	var to := from + dir * 900.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	if not hit.collider.is_in_group(&"terrain"):
		return null
	return hit["position"] as Vector3


func _physics_process(delta: float) -> void:
	if _inside_base:
		global_position = _interior_spawn.global_position
		velocity = Vector3.ZERO
		_update_commander_camera(delta)
		if Input.is_action_just_pressed(&"interact"):
			_exit_commander_mode()
		return

	if GameState.dev_console_open and not _inside_base:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if is_on_floor() and Input.is_action_just_pressed(&"jump"):
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed(&"interact"):
		if _in_command_zone and is_on_floor():
			_enter_commander_mode()

	var input_dir := _read_move_input()
	var cam_basis := _camera.global_transform.basis
	var forward := (-cam_basis.z).slide(Vector3.UP).normalized()
	var right := cam_basis.x.slide(Vector3.UP).normalized()
	var move := (right * input_dir.x + forward * -input_dir.y) * SPEED
	velocity.x = move.x
	velocity.z = move.z
	move_and_slide()
	_update_walk_animation(delta)
	_update_sword_swing(delta)
	_update_sword_hits()


func _read_move_input() -> Vector2:
	var x := Input.get_axis(&"ui_left", &"ui_right")
	var y := Input.get_axis(&"ui_up", &"ui_down")
	if x == 0.0 and y == 0.0:
		x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	return Vector2(x, y).limit_length(1.0)


func _try_start_swing() -> void:
	if _sword_swinging:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _attack_ready_at:
		return
	_attack_ready_at = now + ATTACK_COOLDOWN
	_hit_ids_this_swing.clear()
	_sword_swinging = true
	_sword_swing_elapsed = 0.0
	_swing_arc.visible = true


func _update_sword_swing(delta: float) -> void:
	if not _sword_swinging:
		return
	_sword_swing_elapsed += delta
	if _sword_swing_elapsed < SWING_OUT:
		var u := _smoothstep(_sword_swing_elapsed / SWING_OUT)
		_swing_pivot.rotation_degrees.y = lerpf(SWING_Y_REST, SWING_Y_STRIKE, u)
	elif _sword_swing_elapsed < SWING_OUT + SWING_BACK:
		var u2 := _smoothstep((_sword_swing_elapsed - SWING_OUT) / SWING_BACK)
		_swing_pivot.rotation_degrees.y = lerpf(SWING_Y_STRIKE, SWING_Y_REST, u2)
	else:
		_reset_sword_pose()


func _smoothstep(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _reset_sword_pose() -> void:
	_sword_swinging = false
	_sword_swing_elapsed = 0.0
	if _swing_pivot:
		_swing_pivot.rotation_degrees = Vector3(0.0, SWING_Y_REST, 0.0)
	if _swing_arc:
		_swing_arc.visible = false


func _sword_in_strike_phase() -> bool:
	if not _sword_swinging:
		return false
	return _sword_swing_elapsed >= 0.0 and _sword_swing_elapsed <= (SWING_OUT + 0.08)


func _update_sword_hits() -> void:
	if not _sword_in_strike_phase() or _hit_collision == null or _hit_box == null:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _hit_box
	q.transform = _hit_collision.global_transform
	q.collision_mask = 32 | LAYER_ENEMY
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	var hits := space.intersect_shape(q, 48)
	for h in hits:
		var col: Object = h.get("collider")
		if col == null or not col.has_method(&"apply_sword_hit"):
			continue
		var id := col.get_instance_id()
		if _hit_ids_this_swing.has(id):
			continue
		col.apply_sword_hit(SWORD_DAMAGE + GameState.player_sword_damage_bonus)
		_hit_ids_this_swing[id] = true


func _update_commander_camera(delta: float) -> void:
	var input_dir := _read_move_input()
	var cam_basis := _commander_cam.global_transform.basis
	var pan_forward := (-cam_basis.z).slide(Vector3.UP).normalized()
	var pan_right := cam_basis.x.slide(Vector3.UP).normalized()
	var pan := (pan_right * input_dir.x + pan_forward * (-input_dir.y)) * COMMANDER_PAN_SPEED * delta
	_commander_focus.x += pan.x
	_commander_focus.z += pan.z
	_commander_focus.x = clampf(_commander_focus.x, -COMMANDER_FOCUS_CLAMP, COMMANDER_FOCUS_CLAMP)
	_commander_focus.z = clampf(_commander_focus.z, -COMMANDER_FOCUS_CLAMP, COMMANDER_FOCUS_CLAMP)

	var offset := Vector3(0.0, COMMANDER_CAM_HEIGHT, COMMANDER_ORBIT_RADIUS).rotated(Vector3.UP, _commander_yaw)
	var cam_pos := _commander_focus + offset
	_commander_cam.global_position = cam_pos
	_commander_cam.look_at(Vector3(_commander_focus.x, 1.2, _commander_focus.z))


func _enter_commander_mode() -> void:
	_inside_base = true
	GameState.set_commander_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_base_collision.disabled = true
	_saved_collision_layer = collision_layer
	_saved_collision_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	_avatar_root.visible = false
	_sword_hilt.visible = false
	if _sword_hit_area:
		_sword_hit_area.monitoring = false
	_player_collision.disabled = true
	_reset_sword_pose()
	global_position = _interior_spawn.global_position
	velocity = Vector3.ZERO
	_commander_focus = Vector3.ZERO
	_commander_yaw = deg_to_rad(-38.0)
	_camera.current = false
	_commander_cam.current = true
	_update_commander_camera(0.0)


func _exit_commander_mode() -> void:
	_inside_base = false
	GameState.set_commander_mode(false)
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_collision.disabled = false
	collision_layer = _saved_collision_layer
	collision_mask = _saved_collision_mask
	_avatar_root.visible = true
	_sword_hilt.visible = true
	if _sword_hit_area:
		_sword_hit_area.monitoring = true
	_player_collision.disabled = false
	_reset_sword_pose()
	global_position = _exterior_spawn.global_position
	velocity = Vector3.ZERO
	_commander_cam.current = false
	_camera.current = true
	call_deferred("_deferred_release_focus")
