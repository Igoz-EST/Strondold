extends StaticBody3D

const BASE_MAX_WARRIORS := 4
const LEVEL_3_MAX_WARRIORS := 8
const RESPAWN_SEC := 5.0

const _WarriorScene := preload("res://scenes/warrior.tscn")

var _slot_warrior: Array = []
var _slot_respawn: Array[float] = []
var upgrade_level := 1
var respawn_sec := RESPAWN_SEC
var max_warriors := BASE_MAX_WARRIORS


func _ready() -> void:
	add_to_group(&"barracks")
	apply_upgrade_level(int(get_meta(&"barracks_level", 1)))
	for slot: int in range(max_warriors):
		_spawn_warrior_slot(slot)


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
