extends Node

const _TowerFactory := preload("res://scripts/tower_scene.gd")

const TOWER_COST := 10

var coins: int = 10
var commander_active: bool = false
var awaiting_tower_placement: bool = false

signal coins_changed(new_total: int)
signal commander_mode_changed(is_commander: bool)
signal pending_build_changed(is_pending: bool)


func add_coin() -> void:
	coins += 1
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func set_commander_mode(active: bool) -> void:
	commander_active = active
	if not active:
		awaiting_tower_placement = false
		pending_build_changed.emit(false)
	commander_mode_changed.emit(active)


func begin_tower_blueprint() -> void:
	if not commander_active:
		return
	if awaiting_tower_placement:
		cancel_tower_blueprint()
		return
	if coins < TOWER_COST:
		return
	awaiting_tower_placement = true
	pending_build_changed.emit(true)


func cancel_tower_blueprint() -> void:
	awaiting_tower_placement = false
	pending_build_changed.emit(false)


func try_place_tower(world_pos: Vector3) -> bool:
	if not awaiting_tower_placement or not commander_active:
		return false
	if coins < TOWER_COST:
		cancel_tower_blueprint()
		return false
	var p := world_pos
	p.y = 0.0
	if absf(p.x) < 6.5 and absf(p.z) < 6.5:
		return false
	if not spend_coins(TOWER_COST):
		cancel_tower_blueprint()
		return false
	var world := get_tree().get_first_node_in_group("main_world")
	if world == null:
		coins += TOWER_COST
		coins_changed.emit(coins)
		cancel_tower_blueprint()
		return false
	var tower := _TowerFactory.create_tower()
	world.add_child(tower)
	tower.global_position = p
	awaiting_tower_placement = false
	pending_build_changed.emit(false)
	return true
