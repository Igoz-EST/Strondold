extends Node

const _TowerFactory := preload("res://scripts/tower_scene.gd")
const _BarracksFactory := preload("res://scripts/barracks_scene.gd")

const TOWER_COST := 10
const BARRACKS_COST := 15

const BUILD_NONE := -1
const BUILD_TOWER := 0
const BUILD_BARRACKS := 1
const DMG_UPGRADE_COST := 5
const DMG_UPGRADE_AMOUNT := 10
const ORE_PER_COIN := 100
const WORKER_COST := 10

const BASE_MAX_HP := 1000
## Горизонтальный радиус вокруг маркера группы `player_spawn_zone`, где нельзя ставить башни/бараки.
const PLAYER_NO_BUILD_RADIUS := 10.0

var coins: int = 10
var ore: int = 0
var player_sword_damage_bonus: int = 0
var dev_console_open: bool = false
var commander_active: bool = false
## -1 нет, 0 башня, 1 бараки.
var awaiting_build_type: int = BUILD_NONE

var base_hp: int = BASE_MAX_HP
var game_over: bool = false

signal coins_changed(new_total: int)
signal ore_changed(new_total: int)
signal base_hp_changed(current: int, maximum: int)
signal commander_mode_changed(is_commander: bool)
signal pending_build_changed(is_pending: bool)
signal base_destroyed
signal pause_menu_toggle_requested


func request_pause_menu_toggle() -> void:
	pause_menu_toggle_requested.emit()


func add_coin() -> void:
	coins += 1
	coins_changed.emit(coins)


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)


func add_ore(amount: int) -> void:
	if amount <= 0:
		return
	ore += amount
	ore_changed.emit(ore)


func damage_base(amount: int) -> void:
	if amount <= 0 or base_hp <= 0 or game_over:
		return
	base_hp = maxi(0, base_hp - amount)
	base_hp_changed.emit(base_hp, BASE_MAX_HP)
	if base_hp <= 0:
		game_over = true
		base_destroyed.emit()


func reset_run() -> void:
	game_over = false
	coins = 10
	ore = 0
	player_sword_damage_bonus = 0
	dev_console_open = false
	commander_active = false
	awaiting_build_type = BUILD_NONE
	base_hp = BASE_MAX_HP
	coins_changed.emit(coins)
	ore_changed.emit(ore)
	base_hp_changed.emit(base_hp, BASE_MAX_HP)
	commander_mode_changed.emit(commander_active)
	pending_build_changed.emit(false)


func sell_ore_for_coins() -> void:
	if not commander_active:
		return
	if ore < ORE_PER_COIN:
		return
	var bundles: int = ore / ORE_PER_COIN
	ore -= bundles * ORE_PER_COIN
	coins += bundles
	coins_changed.emit(coins)
	ore_changed.emit(ore)


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func buy_dmg_upgrade() -> bool:
	if not spend_coins(DMG_UPGRADE_COST):
		return false
	player_sword_damage_bonus += DMG_UPGRADE_AMOUNT
	return true


func set_commander_mode(active: bool) -> void:
	commander_active = active
	if not active:
		awaiting_build_type = BUILD_NONE
		pending_build_changed.emit(false)
	commander_mode_changed.emit(active)


func begin_tower_blueprint() -> void:
	if not commander_active:
		return
	if awaiting_build_type == BUILD_TOWER:
		cancel_tower_blueprint()
		return
	if awaiting_build_type == BUILD_BARRACKS:
		cancel_tower_blueprint()
	if coins < TOWER_COST:
		return
	awaiting_build_type = BUILD_TOWER
	pending_build_changed.emit(true)


func begin_barracks_blueprint() -> void:
	if not commander_active:
		return
	if awaiting_build_type == BUILD_BARRACKS:
		cancel_tower_blueprint()
		return
	if awaiting_build_type == BUILD_TOWER:
		cancel_tower_blueprint()
	if coins < BARRACKS_COST:
		return
	awaiting_build_type = BUILD_BARRACKS
	pending_build_changed.emit(true)


func cancel_tower_blueprint() -> void:
	awaiting_build_type = BUILD_NONE
	pending_build_changed.emit(false)


func _get_player_spawn_horiz() -> Vector2:
	var n := get_tree().get_first_node_in_group("player_spawn_zone")
	if n is Node3D:
		var v := (n as Node3D).global_position
		return Vector2(v.x, v.z)
	return Vector2(14.0, 0.0)


func _is_in_player_no_build(p: Vector3) -> bool:
	var o := _get_player_spawn_horiz()
	var dx := p.x - o.x
	var dz := p.z - o.y
	return dx * dx + dz * dz <= PLAYER_NO_BUILD_RADIUS * PLAYER_NO_BUILD_RADIUS


func try_place_tower(world_pos: Vector3) -> bool:
	if awaiting_build_type == BUILD_NONE or not commander_active:
		return false
	var cost: int = TOWER_COST if awaiting_build_type == BUILD_TOWER else BARRACKS_COST
	if coins < cost:
		cancel_tower_blueprint()
		return false
	var p := world_pos
	if absf(p.x) < 6.5 and absf(p.z) < 6.5:
		return false
	if _is_in_player_no_build(p):
		return false
	if not spend_coins(cost):
		cancel_tower_blueprint()
		return false
	var world := get_tree().get_first_node_in_group("main_world")
	if world == null:
		coins += cost
		coins_changed.emit(coins)
		cancel_tower_blueprint()
		return false
	if awaiting_build_type == BUILD_TOWER:
		var tower := _TowerFactory.create_tower()
		world.add_child(tower)
		tower.global_position = p
	else:
		var barracks := _BarracksFactory.create_barracks()
		world.add_child(barracks)
		barracks.global_position = p
	awaiting_build_type = BUILD_NONE
	pending_build_changed.emit(false)
	return true
