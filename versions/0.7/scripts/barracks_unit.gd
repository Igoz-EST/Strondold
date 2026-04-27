extends StaticBody3D

const MAX_WARRIORS := 4
const RESPAWN_SEC := 10.0

const _WarriorScene := preload("res://scenes/warrior.tscn")

var _slot_warrior: Array = [null, null, null, null]
var _slot_respawn: Array[float] = [0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	for slot: int in range(MAX_WARRIORS):
		_spawn_warrior_slot(slot)


func _physics_process(delta: float) -> void:
	for i: int in range(MAX_WARRIORS):
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
		_:
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
	_slot_warrior[slot] = w


func notify_warrior_lost(slot: int) -> void:
	if slot < 0 or slot >= MAX_WARRIORS:
		return
	_slot_warrior[slot] = null
	_slot_respawn[slot] = RESPAWN_SEC
