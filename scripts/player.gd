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
const COMMANDER_PAN_SPEED := 42.0
const COMMANDER_FOCUS_CLAMP := 126.0
const COMMANDER_ZOOM_MIN := 0.55
const COMMANDER_ZOOM_MAX := 1.75
const COMMANDER_ZOOM_STEP := 0.12

const _HumanoidAvatarBuilder := preload("res://scripts/humanoid_avatar_builder.gd")
const _KING_MODEL_PATH     := "res://assets/models/King.fbx"
const _KING_SCALE          := 1.0
const _AVATAR_FEET_ALIGN_Y := -0.46
const _TowerFactory := preload("res://scripts/tower_scene.gd")
const _BarracksFactory := preload("res://scripts/barracks_scene.gd")
const _WarehouseFactory := preload("res://scripts/warehouse_scene.gd")

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
@onready var _spawn_zone_visual: Node3D = $"../ExteriorSpawn/PlayerSpawnZoneVisual"
@onready var _canvas_layer: CanvasLayer = $"../CanvasLayer"

var _enter_commander_hint: Label

var _inside_base := false
var _in_command_zone := false
var _commander_focus := Vector3.ZERO
var _commander_yaw := 0.0
var _commander_zoom := 1.0
var _commander_dragging := false
var _commander_drag_anchor: Variant = null
var _commander_rotating := false
var _build_preview: Node3D = null
var _tower_range_preview: MeshInstance3D = null
var _build_preview_type: int = GameState.BUILD_NONE
var _build_preview_valid := false
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

var _king_model:   Node3D          = null
var _king_anim:    AnimationPlayer = null
var _punch_right   := true
var _kanim_idle    := ""
var _kanim_walk    := ""
var _kanim_run     := ""
var _kanim_punch_r := ""
var _kanim_punch_l := ""

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
	_load_king_model()
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
	_setup_commander_enter_hint()
	_spawn_zone_visual.visible = false
	_commander_cam.current = false
	_reset_sword_pose()
	call_deferred("_start_game_in_commander")


func _start_game_in_commander() -> void:
	get_viewport().gui_release_focus()
	_enter_commander_mode()


func _setup_commander_enter_hint() -> void:
	var lbl := Label.new()
	lbl.name = &"CommanderEnterHint"
	lbl.text = "Press E to enter"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.visible = false
	UiStyle.style_label(lbl, UiStyle.TEXT_MAIN, 22, 5)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -96.0
	lbl.offset_bottom = -56.0
	lbl.z_index = 8
	_canvas_layer.add_child(lbl)
	_enter_commander_hint = lbl


func _set_commander_enter_hint_visible(on: bool) -> void:
	if _enter_commander_hint != null:
		_enter_commander_hint.visible = on


func _deferred_release_focus() -> void:
	if _inside_base:
		return
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_avatar_visual() -> void:
	if ResourceLoader.exists(_KING_MODEL_PATH):
		# King model will replace the avatar — just need a dummy ArmR for sword attachment
		var arm := Node3D.new()
		arm.name = &"ArmR"
		arm.position = Vector3(0.26, 0.24, 0.0)
		_avatar_root.add_child(arm)
		_arm_r = arm
		return
	_HumanoidAvatarBuilder.build(_avatar_root, Color(0.15, 0.52, 0.92), false, 1.0)
	_leg_l = _avatar_root.get_node_or_null("LegL") as Node3D
	_leg_r = _avatar_root.get_node_or_null("LegR") as Node3D
	_arm_l = _avatar_root.get_node_or_null("ArmL") as Node3D
	_arm_r = _avatar_root.get_node_or_null("ArmR") as Node3D
	_add_hero_regalia()


func _add_hero_regalia() -> void:
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.95, 0.74, 0.18)
	crown_mat.metallic = 0.35
	crown_mat.roughness = 0.32

	var crown := MeshInstance3D.new()
	crown.name = &"HeroCrown"
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.14
	crown_mesh.bottom_radius = 0.16
	crown_mesh.height = 0.08
	crown_mesh.radial_segments = 8
	crown.mesh = crown_mesh
	crown.position = Vector3(0.0, 1.095, 0.0)
	crown.set_surface_override_material(0, crown_mat)
	_avatar_root.add_child(crown)

	for i in range(4):
		var spike := MeshInstance3D.new()
		var spike_mesh := BoxMesh.new()
		spike_mesh.size = Vector3(0.035, 0.08, 0.035)
		spike.mesh = spike_mesh
		var angle := TAU * float(i) / 4.0
		spike.position = crown.position + Vector3(cos(angle) * 0.105, 0.06, sin(angle) * 0.105)
		spike.set_surface_override_material(0, crown_mat)
		_avatar_root.add_child(spike)

	var cape := MeshInstance3D.new()
	cape.name = &"HeroCape"
	var cape_mesh := BoxMesh.new()
	cape_mesh.size = Vector3(0.44, 0.7, 0.035)
	cape.mesh = cape_mesh
	cape.position = Vector3(0.0, 0.5, 0.13)
	cape.rotation_degrees.x = -8.0
	var cape_mat := StandardMaterial3D.new()
	cape_mat.albedo_color = Color(0.55, 0.05, 0.08)
	cape_mat.roughness = 0.72
	cape.set_surface_override_material(0, cape_mat)
	_avatar_root.add_child(cape)


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
	_sword_hilt = Node3D.new()
	_sword_hilt.name = "SwordHilt"
	if _arm_r != null:
		_arm_r.add_child(_sword_hilt)
		_sword_hilt.position = Vector3(0.08, -0.42, 0.04)
		_sword_hilt.rotation_degrees = Vector3(0.0, -12.0, 82.0)
	else:
		add_child(_sword_hilt)
		_sword_hilt.position = Vector3(0.46, 0.02, -0.1)

	_swing_pivot = Node3D.new()
	_swing_pivot.name = "SwingPivot"
	_sword_hilt.add_child(_swing_pivot)

	# King model replaces sword — no visual meshes needed
	if ResourceLoader.exists(_KING_MODEL_PATH):
		_swing_arc = MeshInstance3D.new()
		_swing_arc.visible = false
		_swing_pivot.add_child(_swing_arc)
		return

	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.bottom_radius = 0.055
	grip_mesh.top_radius = 0.05
	grip_mesh.height = 0.32
	grip.mesh = grip_mesh
	grip.position = Vector3(-0.12, 0.0, 0.0)
	grip.rotation_degrees.z = 90.0
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.2, 0.11, 0.055)
	grip_mat.roughness = 0.85
	grip.set_surface_override_material(0, grip_mat)
	_swing_pivot.add_child(grip)

	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.08, 0.1, 0.48)
	guard.mesh = guard_mesh
	guard.position = Vector3(0.06, 0.0, 0.0)
	var guard_mat := StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.78, 0.62, 0.22)
	guard_mat.metallic = 0.45
	guard_mat.roughness = 0.35
	guard.set_surface_override_material(0, guard_mat)
	_swing_pivot.add_child(guard)

	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.74, 0.055, 0.105)
	blade.mesh = blade_mesh
	blade.position = Vector3(0.45, 0.0, 0.0)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.88, 0.9, 0.96)
	blade_mat.metallic = 0.75
	blade_mat.roughness = 0.28
	blade.set_surface_override_material(0, blade_mat)
	_swing_pivot.add_child(blade)

	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.16, 0.05, 0.09)
	tip.mesh = tip_mesh
	tip.position = Vector3(0.9, 0.0, 0.0)
	tip.rotation_degrees.z = 45.0
	tip.set_surface_override_material(0, blade_mat)
	_swing_pivot.add_child(tip)

	var pommel := MeshInstance3D.new()
	var pommel_mesh := SphereMesh.new()
	pommel_mesh.radius = 0.075
	pommel_mesh.height = 0.12
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(-0.3, 0.0, 0.0)
	pommel.set_surface_override_material(0, guard_mat)
	_swing_pivot.add_child(pommel)

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

	if _inside_base and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_commander_zoom = clampf(_commander_zoom - COMMANDER_ZOOM_STEP, COMMANDER_ZOOM_MIN, COMMANDER_ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_commander_zoom = clampf(_commander_zoom + COMMANDER_ZOOM_STEP, COMMANDER_ZOOM_MIN, COMMANDER_ZOOM_MAX)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_commander_dragging = mb.pressed
			_commander_drag_anchor = _commander_ground_plane_hit(mb.position) if mb.pressed else null
			Input.set_default_cursor_shape(Input.CURSOR_DRAG if mb.pressed else Input.CURSOR_ARROW)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if GameState.awaiting_build_type == GameState.BUILD_NONE:
				_commander_rotating = mb.pressed
				get_viewport().set_input_as_handled()
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
				if gp != null and _build_preview_valid and GameState.try_place_tower(gp as Vector3):
					_clear_build_preview()
					get_viewport().set_input_as_handled()
				return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if get_viewport().gui_get_hovered_control() == null:
				_try_select_building_raycast(event.position)

	if _inside_base and event is InputEventMouseMotion and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		if _commander_dragging:
			_update_commander_drag(mm.position)
			get_viewport().set_input_as_handled()
			return
		if _commander_rotating:
			_commander_yaw -= mm.relative.x * MOUSE_SENS
			get_viewport().set_input_as_handled()

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


func _commander_any_build_hit(screen_pos: Vector2) -> Variant:
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
	return hit["position"] as Vector3


func _commander_ground_plane_hit(screen_pos: Vector2) -> Variant:
	var from := _commander_cam.project_ray_origin(screen_pos)
	var dir := _commander_cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return null
	var t := -from.y / dir.y
	if t < 0.0:
		return null
	return from + dir * t


func _update_commander_drag(screen_pos: Vector2) -> void:
	if _commander_drag_anchor == null:
		_commander_drag_anchor = _commander_ground_plane_hit(screen_pos)
		return
	var hit: Variant = _commander_ground_plane_hit(screen_pos)
	if hit == null:
		return
	var anchor := _commander_drag_anchor as Vector3
	var delta := anchor - (hit as Vector3)
	_commander_focus.x += delta.x
	_commander_focus.z += delta.z
	_clamp_commander_focus()
	_update_commander_camera(0.0)


func _physics_process(delta: float) -> void:
	if _inside_base:
		_set_commander_enter_hint_visible(false)
		SoundManager.set_grass_walk_loop(false)
		global_position = _interior_spawn.global_position
		velocity = Vector3.ZERO
		_update_commander_camera(delta)
		_update_build_preview()
		if Input.is_action_just_pressed(&"interact"):
			_exit_commander_mode()
		return

	if GameState.dev_console_open and not _inside_base:
		_set_commander_enter_hint_visible(false)
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
		SoundManager.play_jump()

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
	var walk_grass := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.2
	SoundManager.set_grass_walk_loop(walk_grass)
	_update_walk_animation(delta)
	_update_king_animation(delta)
	_update_sword_swing(delta)
	_update_sword_hits()
	var can_enter := (
		_in_command_zone
		and is_on_floor()
		and not GameState.dev_console_open
		and not GameState.game_over
	)
	_set_commander_enter_hint_visible(can_enter)


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
	SoundManager.play_one_shot(SoundManager.KEY_SWORD_SWING)
	_sword_swinging = true
	_sword_swing_elapsed = 0.0
	_swing_arc.visible = true
	_king_trigger_punch()


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
		var dmg: int = SWORD_DAMAGE
		if col.is_in_group(&"breakable"):
			dmg += GameState.player_sword_damage_bonus
		col.apply_sword_hit(dmg)
		_hit_ids_this_swing[id] = true


func _update_commander_camera(delta: float) -> void:
	var input_dir := _read_move_input()
	var cam_basis := _commander_cam.global_transform.basis
	var pan_forward := (-cam_basis.z).slide(Vector3.UP).normalized()
	var pan_right := cam_basis.x.slide(Vector3.UP).normalized()
	var pan := (pan_right * input_dir.x + pan_forward * (-input_dir.y)) * COMMANDER_PAN_SPEED * delta
	_commander_focus.x += pan.x
	_commander_focus.z += pan.z
	_clamp_commander_focus()

	var offset := Vector3(
		0.0,
		COMMANDER_CAM_HEIGHT * _commander_zoom,
		COMMANDER_ORBIT_RADIUS * _commander_zoom
	).rotated(Vector3.UP, _commander_yaw)
	var cam_pos := _commander_focus + offset
	_commander_cam.global_position = cam_pos
	_commander_cam.look_at(Vector3(_commander_focus.x, 1.2, _commander_focus.z))


func _clamp_commander_focus() -> void:
	var limit := COMMANDER_FOCUS_CLAMP * GameState.get_map_scale()
	_commander_focus.x = clampf(_commander_focus.x, -limit, limit)
	_commander_focus.z = clampf(_commander_focus.z, -limit, limit)


func _update_build_preview() -> void:
	var build_type := GameState.awaiting_build_type
	if build_type == GameState.BUILD_NONE:
		_clear_build_preview()
		return
	if _build_preview == null or _build_preview_type != build_type:
		_create_build_preview(build_type)

	var hit: Variant = _commander_any_build_hit(get_viewport().get_mouse_position())
	if hit == null:
		if _build_preview:
			_build_preview.visible = false
		if _tower_range_preview:
			_tower_range_preview.visible = false
		_build_preview_valid = false
		return

	var pos := hit as Vector3
	_build_preview.visible = true
	_build_preview.global_position = pos
	_build_preview_valid = GameState.can_place_build_at(pos)
	var tint := Color(0.15, 1.0, 0.22, 0.48) if _build_preview_valid else Color(1.0, 0.08, 0.04, 0.5)
	_tint_build_preview(tint)
	_update_tower_range_preview(pos, tint)


func _create_build_preview(build_type: int) -> void:
	_clear_build_preview()
	match build_type:
		GameState.BUILD_TOWER:
			_build_preview = _TowerFactory.create_tower(GameState.tower_level)
		GameState.BUILD_BARRACKS:
			_build_preview = _BarracksFactory.create_barracks(GameState.barracks_level)
		GameState.BUILD_WAREHOUSE:
			_build_preview = _WarehouseFactory.create_warehouse()
		_:
			return
	_build_preview_type = build_type
	_build_preview.name = &"BuildPreview"
	_build_preview.set_script(null)
	_build_preview.collision_layer = 0
	_build_preview.collision_mask = 0
	_disable_preview_collisions(_build_preview)
	get_parent().add_child(_build_preview)
	if build_type == GameState.BUILD_TOWER:
		_create_tower_range_preview()


func _clear_build_preview() -> void:
	if _build_preview != null and is_instance_valid(_build_preview):
		_build_preview.queue_free()
	if _tower_range_preview != null and is_instance_valid(_tower_range_preview):
		_tower_range_preview.queue_free()
	_build_preview = null
	_tower_range_preview = null
	_build_preview_type = GameState.BUILD_NONE
	_build_preview_valid = false


func _create_tower_range_preview() -> void:
	if _tower_range_preview != null and is_instance_valid(_tower_range_preview):
		return
	_tower_range_preview = MeshInstance3D.new()
	_tower_range_preview.name = &"TowerRangePreview"
	_tower_range_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	var range := 28.0
	mesh.top_radius = range
	mesh.bottom_radius = range
	mesh.height = 0.035
	mesh.radial_segments = 96
	_tower_range_preview.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 0.35, 0.16)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tower_range_preview.set_surface_override_material(0, mat)
	get_parent().add_child(_tower_range_preview)


func _update_tower_range_preview(pos: Vector3, tint: Color) -> void:
	if _build_preview_type != GameState.BUILD_TOWER:
		if _tower_range_preview != null:
			_tower_range_preview.visible = false
		return
	if _tower_range_preview == null:
		_create_tower_range_preview()
	_tower_range_preview.visible = _build_preview != null and _build_preview.visible
	_tower_range_preview.global_position = Vector3(pos.x, pos.y + 0.04, pos.z)
	var mat := _tower_range_preview.get_surface_override_material(0) as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.16)


func _disable_preview_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_disable_preview_collisions(child)


func _tint_build_preview(color: Color) -> void:
	if _build_preview == null:
		return
	_tint_preview_node(_build_preview, color)


func _tint_preview_node(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_i := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
		mat.emission_energy_multiplier = 0.25
		mat.roughness = 0.55
		mesh_i.material_override = mat
	for child in node.get_children():
		_tint_preview_node(child, color)


func _enter_commander_mode() -> void:
	_inside_base = true
	GameState.set_commander_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_spawn_zone_visual.visible = true
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
	_commander_zoom = 1.0
	_commander_dragging = false
	_commander_drag_anchor = null
	_commander_rotating = false
	_camera.current = false
	_commander_cam.current = true
	_update_commander_camera(0.0)


func _exit_commander_mode() -> void:
	_inside_base = false
	GameState.set_commander_mode(false)
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_spawn_zone_visual.visible = false
	_clear_build_preview()
	_commander_dragging = false
	_commander_drag_anchor = null
	_commander_rotating = false
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


# ─── KING MODEL ───────────────────────────────────────────────────────────────

func _load_king_model() -> void:
	if not ResourceLoader.exists(_KING_MODEL_PATH):
		return
	var scene := load(_KING_MODEL_PATH) as PackedScene
	if scene == null:
		return
	_king_model = scene.instantiate() as Node3D
	if _king_model == null:
		return
	_king_model.scale            = Vector3.ONE * _KING_SCALE
	_king_model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_king_model.position.y       = _AVATAR_FEET_ALIGN_Y
	add_child(_king_model)

	_king_anim = _king_find_anim_player(_king_model)
	_king_discover_anims()
	_king_play(_kanim_idle)


func _king_find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _king_find_anim_player(c)
		if found:
			return found
	return null


# Finds animation by keyword suffix — handles any armature prefix (e.g. "CharacterArmature|Idle" or just "Idle")
func _king_find_anim(keyword: String) -> String:
	if _king_anim == null:
		return ""
	for a in _king_anim.get_animation_list():
		if a == keyword or a.ends_with("|" + keyword):
			return a
	return ""


func _king_discover_anims() -> void:
	_kanim_idle    = _king_find_anim("Idle")
	_kanim_walk    = _king_find_anim("Walk")
	_kanim_run     = _king_find_anim("Run")
	_kanim_punch_r = _king_find_anim("Punch_Right")
	_kanim_punch_l = _king_find_anim("Punch_Left")
	# Fallback: if no directional punches, try generic Punch
	if _kanim_punch_r.is_empty(): _kanim_punch_r = _king_find_anim("Punch")
	if _kanim_punch_l.is_empty(): _kanim_punch_l = _kanim_punch_r


func _king_play(anim_name: String, loop: bool = true) -> void:
	if _king_anim == null or anim_name.is_empty():
		return
	if _king_anim.current_animation == anim_name and _king_anim.is_playing():
		return
	var anim := _king_anim.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_king_anim.play(anim_name)


func _king_trigger_punch() -> void:
	if _king_anim == null:
		return
	var name := _kanim_punch_r if _punch_right else _kanim_punch_l
	_punch_right = not _punch_right
	if name.is_empty():
		return
	var anim := _king_anim.get_animation(name)
	if anim:
		anim.loop_mode = Animation.LOOP_NONE
	_king_anim.play(name)


func _update_king_animation(_delta: float) -> void:
	if _king_model == null or _king_anim == null:
		return

	# PUNCH: triggered externally; wait for swing to end, then resume movement
	if _sword_swinging:
		return

	# AIR: no jump animation exists — let last ground animation continue
	# State returns naturally when is_on_floor() becomes true again
	if not is_on_floor():
		return

	# GROUND: pure state machine, no sticky flags
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 5.0:
		_king_play(_kanim_run)
	elif speed > 0.2:
		_king_play(_kanim_walk)
	else:
		_king_play(_kanim_idle)


## Phase-1: direct physics raycast on building collision.
## Phase-2 fallback: ground-plane hit + XZ radius search (works for clicks near ground).
func _try_select_building_raycast(screen_pos: Vector2) -> void:
	# ── Phase 1: physics ray ─────────────────────────────────────────────────
	var from := _commander_cam.project_ray_origin(screen_pos)
	var dir  := _commander_cam.project_ray_normal(screen_pos)

	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 600.0)
	query.collision_mask = 1   # buildings and ground share layer 1

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var found := _building_from_collider(result.get("collider"))
		if found != null:
			print("Selected " + ("Tower" if found.is_in_group(&"tower") else "Barracks"))
			GameState.building_selected.emit(found)
			return

	# ── Phase 2: fallback — ground plane + XZ radius ─────────────────────────
	var gp: Variant = _commander_ground_hit(screen_pos)
	if gp == null:
		return
	_try_select_building_radius(gp as Vector3)


func _building_from_collider(collider: Object) -> Node3D:
	## Walk up the scene tree from the collider until we find a building node.
	var n := collider as Node
	while n != null:
		if n is Node3D:
			var n3 := n as Node3D
			if n3.is_in_group(&"tower") or n3.is_in_group(&"barracks"):
				return n3
		n = n.get_parent()
	return null


func _try_select_building_radius(world_pos: Vector3) -> void:
	const PICK_R2 := 100.0   # 10-unit XZ radius
	var best: Node3D = null
	var best_d2 := PICK_R2
	for grp in [&"tower", &"barracks"]:
		for n in get_tree().get_nodes_in_group(grp):
			if not (n is Node3D) or not is_instance_valid(n): continue
			var np := (n as Node3D).global_position
			var dx := world_pos.x - np.x
			var dz := world_pos.z - np.z
			var d2 := dx * dx + dz * dz
			if d2 < best_d2: best_d2 = d2; best = n as Node3D
	if best != null:
		print("Selected " + ("Tower" if best.is_in_group(&"tower") else "Barracks"))
		GameState.building_selected.emit(best)
