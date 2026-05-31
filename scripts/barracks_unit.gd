extends StaticBody3D

const BASE_MAX_WARRIORS    := 4
const LEVEL_3_MAX_WARRIORS := 8
const RESPAWN_SEC          := 5.0

## Formation offsets relative to Rally Flag — 3.2u spacing, 2×2 / 3×3 grid.
const FORMATION_OFFSETS: Array[Vector3] = [
	Vector3(-3.2, 0.0,  3.2),   # 0 front-left
	Vector3( 3.2, 0.0,  3.2),   # 1 front-right
	Vector3(-3.2, 0.0, -3.2),   # 2 back-left
	Vector3( 3.2, 0.0, -3.2),   # 3 back-right
	Vector3(-3.2, 0.0,  0.0),   # 4 mid-left  (level 3)
	Vector3( 3.2, 0.0,  0.0),   # 5 mid-right
	Vector3( 0.0, 0.0,  3.2),   # 6 front-center
	Vector3( 0.0, 0.0, -3.2),   # 7 back-center
]

const _WarriorScene := preload("res://scenes/warrior.tscn")

var _slot_warrior: Array = []
var _slot_respawn: Array[float] = []
var upgrade_level := 1
var respawn_sec := RESPAWN_SEC
var max_warriors := BASE_MAX_WARRIORS

var _flag_pos:    Vector3          = Vector3.ZERO
var _flag_marker: Node3D           = null
var _flag_line:   MeshInstance3D   = null


func _ready() -> void:
	add_to_group(&"barracks")
	apply_upgrade_level(int(get_meta(&"barracks_level", 1)))
	for slot: int in range(max_warriors):
		_spawn_warrior_slot(slot)
	GameState.commander_mode_changed.connect(_on_commander_mode_changed)


func _exit_tree() -> void:
	if is_instance_valid(_flag_marker): _flag_marker.queue_free()
	if is_instance_valid(_flag_line):   _flag_line.queue_free()


func _on_commander_mode_changed(active: bool) -> void:
	if is_instance_valid(_flag_marker):
		_flag_marker.visible = active and _flag_pos != Vector3.ZERO
	if is_instance_valid(_flag_line):
		_flag_line.visible = active and _flag_pos != Vector3.ZERO


func _process(_delta: float) -> void:
	_update_flag_line()


func apply_upgrade_level(level: int) -> void:
	upgrade_level = clampi(level, 1, 3)
	set_meta(&"barracks_level", upgrade_level)
	respawn_sec = RESPAWN_SEC
	max_warriors = LEVEL_3_MAX_WARRIORS if upgrade_level >= 3 else BASE_MAX_WARRIORS
	_resize_slots(max_warriors)
	var factory := load("res://scripts/barracks_scene.gd")
	factory.add_level_visuals(self, upgrade_level)
	for w in _slot_warrior:
		if w != null and is_instance_valid(w) and w.has_method(&"apply_upgrade_level"):
			w.call(&"apply_upgrade_level", upgrade_level)
	if is_inside_tree():
		for slot: int in range(max_warriors):
			_spawn_warrior_slot(slot)


func _resize_slots(size: int) -> void:
	while _slot_warrior.size() < size:
		_slot_warrior.append(null)
		_slot_respawn.append(0.0)


func _physics_process(delta: float) -> void:
	for i: int in range(max_warriors):
		if _slot_respawn[i] <= 0.0:
			continue
		_slot_respawn[i] -= delta
		if _slot_respawn[i] > 0.0:
			continue
		_slot_respawn[i] = 0.0
		if _slot_warrior[i] != null and is_instance_valid(_slot_warrior[i]):
			continue
		_spawn_warrior_slot(i)


func _rally_offset(slot: int) -> Vector3:
	match slot:
		0:
			return Vector3(-1.6, 0.0, 1.6)
		1:
			return Vector3(1.6, 0.0, 1.6)
		2:
			return Vector3(-1.6, 0.0, -1.6)
		4:
			return Vector3(-3.0, 0.0, 0.0)
		5:
			return Vector3(3.0, 0.0, 0.0)
		6:
			return Vector3(0.0, 0.0, 3.0)
		_:
			if slot == 7:
				return Vector3(0.0, 0.0, -3.0)
			return Vector3(1.6, 0.0, -1.6)


func _spawn_warrior_slot(slot: int) -> void:
	if _slot_warrior[slot] != null and is_instance_valid(_slot_warrior[slot]):
		return
	var world := get_tree().get_first_node_in_group(&"main_world")
	if world == null:
		return
	var w: CharacterBody3D = _WarriorScene.instantiate() as CharacterBody3D
	if w.has_method(&"setup"):
		w.call(&"setup", self, slot, _rally_offset(slot))
	world.add_child(w)
	w.global_position = global_position + _rally_offset(slot) + Vector3(0.0, 0.55, 0.0)
	if w.has_method(&"apply_upgrade_level"):
		w.call(&"apply_upgrade_level", upgrade_level)
	_slot_warrior[slot] = w


func notify_warrior_lost(slot: int) -> void:
	if slot < 0 or slot >= max_warriors:
		return
	_slot_warrior[slot] = null
	_slot_respawn[slot] = respawn_sec


# ─── Rally flag ────────────────────────────────────────────────────────────────

func _update_flag_line() -> void:
	if _flag_pos == Vector3.ZERO or not GameState.commander_active:
		if is_instance_valid(_flag_line): _flag_line.visible = false
		return

	if _flag_line == null:
		_flag_line = _make_flag_line()
		var world := get_tree().get_first_node_in_group(&"main_world")
		if world: world.add_child(_flag_line)

	var start := global_position + Vector3(0.0, 0.5, 0.0)
	var end   := _flag_pos       + Vector3(0.0, 0.1, 0.0)
	var length := start.distance_to(end)
	if length < 0.1:
		_flag_line.visible = false
		return

	_flag_line.visible = true
	_flag_line.global_position = (start + end) * 0.5
	_flag_line.scale = Vector3(0.12, 0.12, length)
	# look_at(end) makes local -Z face end; box scaled along Z → stretches start↔end
	_flag_line.look_at(end, Vector3.UP)


func _make_flag_line() -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var bm  := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)   # scale is applied at runtime
	mi.mesh = bm
	mi.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color             = Color(0.15, 0.90, 0.30, 0.80)
	mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled         = true
	mat.emission                 = Color(0.10, 0.75, 0.22)
	mat.emission_energy_multiplier = 0.80
	mat.cull_mode                = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode          = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mi.set_surface_override_material(0, mat)
	return mi


func set_rally_flag(world_pos: Vector3) -> void:
	_flag_pos = world_pos
	if _flag_marker == null:
		_flag_marker = _make_flag_marker()
		var world := get_tree().get_first_node_in_group(&"main_world")
		if world: world.add_child(_flag_marker)
	_flag_marker.global_position = world_pos
	_flag_marker.visible = GameState.commander_active


func get_rally_pos(slot: int) -> Vector3:
	if _flag_pos != Vector3.ZERO:
		var idx := clampi(slot, 0, FORMATION_OFFSETS.size() - 1)
		return _flag_pos + FORMATION_OFFSETS[idx] + Vector3(0.0, 0.55, 0.0)
	return global_position + _rally_offset(slot) + Vector3(0.0, 0.55, 0.0)


func _make_flag_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "RallyFlag"
	# Pole
	var pole := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius = 0.06; cyl.bottom_radius = 0.06; cyl.height = 2.2
	pole.mesh = cyl
	pole.position.y = 1.1
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.50, 0.38, 0.18); pm.roughness = 0.9
	pole.set_surface_override_material(0, pm)
	root.add_child(pole)
	# Flag cloth
	var flag := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size  = Vector3(0.65, 0.42, 0.06)
	flag.mesh = bm
	flag.position = Vector3(0.38, 2.1, 0.0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color             = Color(0.15, 0.78, 0.28)
	fm.emission_enabled         = true
	fm.emission                 = Color(0.10, 0.60, 0.20)
	fm.emission_energy_multiplier = 0.55
	flag.set_surface_override_material(0, fm)
	root.add_child(flag)
	return root
