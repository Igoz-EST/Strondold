extends Node

const _TowerFactory := preload("res://scripts/tower_scene.gd")
const _BarracksFactory := preload("res://scripts/barracks_scene.gd")
const _WarehouseFactory := preload("res://scripts/warehouse_scene.gd")

const TOWER_ORE_COST := 200
const TOWER_WOOD_COST := 20
const BARRACKS_ORE_COST := 350
const BARRACKS_WOOD_COST := 40
const WAREHOUSE_ORE_COST := 100
const WAREHOUSE_WOOD_COST := 60

const BUILD_NONE := -1
const BUILD_TOWER := 0
const BUILD_BARRACKS := 1
const BUILD_WAREHOUSE := 2
const DMG_UPGRADE_COST := 5
const DMG_UPGRADE_AMOUNT := 10
const ORE_PER_COIN := 100
const WORKER_COST := 5
const BUILDING_UPGRADE_COIN_COSTS: Array[int] = [0, 20, 30]
const BUILDING_UPGRADE_ORE_COSTS: Array[int] = [0, 500, 1000]
const GAME_MODE_MISSION := 0
const GAME_MODE_ENDLESS := 1

const BASE_MAX_HP := 1000
## Горизонтальный радиус вокруг маркера группы `player_spawn_zone`, где нельзя ставить башни/бараки.
const PLAYER_NO_BUILD_RADIUS := 2.5
const BUILD_BASE_CLEAR := 6.5
const BUILD_MAX_GROUND_Y := 0.22
const BUILD_MINE_CLEAR_RADIUS := 12.0

var coins: int = 10
var ore: int = 250
var wood: int = 50
## Добавка к урону меча только по деревьям/камням (группа breakable). По врагам — фиксированный урон в player.gd.
var player_sword_damage_bonus: int = 0
var tower_level: int = 1
var barracks_level: int = 1
var dev_console_open: bool = false
var commander_active: bool = false
## -1 нет, 0 башня, 1 бараки, 2 склад.
var awaiting_build_type: int = BUILD_NONE

var base_hp: int = BASE_MAX_HP
var game_over: bool = false
var game_mode: int = GAME_MODE_MISSION
var has_giant_warrior: bool = false

signal coins_changed(new_total: int)
signal ore_changed(new_total: int)
signal wood_changed(new_total: int)
signal base_hp_changed(current: int, maximum: int)
signal commander_mode_changed(is_commander: bool)
signal pending_build_changed(is_pending: bool)
signal building_levels_changed
signal base_destroyed
signal pause_menu_toggle_requested


func request_pause_menu_toggle() -> void:
	pause_menu_toggle_requested.emit()


func set_game_mode(mode: int) -> void:
	game_mode = mode


func get_map_scale() -> float:
	return 2.0 if game_mode == GAME_MODE_ENDLESS else 1.0


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


func add_wood(amount: int) -> void:
	if amount <= 0:
		return
	wood += amount
	wood_changed.emit(wood)


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
	ore = 250
	wood = 50
	player_sword_damage_bonus = 0
	tower_level = 1
	barracks_level = 1
	dev_console_open = false
	commander_active = false
	awaiting_build_type = BUILD_NONE
	base_hp = BASE_MAX_HP
	has_giant_warrior = false
	coins_changed.emit(coins)
	ore_changed.emit(ore)
	wood_changed.emit(wood)
	base_hp_changed.emit(base_hp, BASE_MAX_HP)
	commander_mode_changed.emit(commander_active)
	pending_build_changed.emit(false)
	building_levels_changed.emit()


func sell_ore_for_coins() -> void:
	if not commander_active:
		return
	if ore < ORE_PER_COIN:
		return
	ore -= ORE_PER_COIN
	coins += 1
	coins_changed.emit(coins)
	ore_changed.emit(ore)


func try_market_trade(coin_delta: int, wood_delta: int, ore_delta: int) -> bool:
	if not commander_active:
		return false
	if coins + coin_delta < 0 or wood + wood_delta < 0 or ore + ore_delta < 0:
		return false
	coins += coin_delta
	wood += wood_delta
	ore += ore_delta
	coins_changed.emit(coins)
	wood_changed.emit(wood)
	ore_changed.emit(ore)
	return true


func can_afford_build(build_type: int) -> bool:
	return ore >= get_build_ore_cost(build_type) and wood >= get_build_wood_cost(build_type)


func get_build_ore_cost(build_type: int) -> int:
	match build_type:
		BUILD_TOWER:
			return TOWER_ORE_COST
		BUILD_BARRACKS:
			return BARRACKS_ORE_COST
		BUILD_WAREHOUSE:
			return WAREHOUSE_ORE_COST
	return 0


func get_build_wood_cost(build_type: int) -> int:
	match build_type:
		BUILD_TOWER:
			return TOWER_WOOD_COST
		BUILD_BARRACKS:
			return BARRACKS_WOOD_COST
		BUILD_WAREHOUSE:
			return WAREHOUSE_WOOD_COST
	return 0


func spend_build_resources(build_type: int) -> bool:
	if not can_afford_build(build_type):
		return false
	ore -= get_build_ore_cost(build_type)
	wood -= get_build_wood_cost(build_type)
	ore_changed.emit(ore)
	wood_changed.emit(wood)
	return true


func refund_build_resources(build_type: int) -> void:
	ore += get_build_ore_cost(build_type)
	wood += get_build_wood_cost(build_type)
	ore_changed.emit(ore)
	wood_changed.emit(wood)


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


func get_tower_upgrade_cost() -> int:
	if tower_level >= 3:
		return 0
	return BUILDING_UPGRADE_COIN_COSTS[tower_level]


func get_tower_upgrade_ore_cost() -> int:
	if tower_level >= 3:
		return 0
	return BUILDING_UPGRADE_ORE_COSTS[tower_level]


func get_barracks_upgrade_cost() -> int:
	if barracks_level >= 3:
		return 0
	return BUILDING_UPGRADE_COIN_COSTS[barracks_level]


func get_barracks_upgrade_ore_cost() -> int:
	if barracks_level >= 3:
		return 0
	return BUILDING_UPGRADE_ORE_COSTS[barracks_level]


func buy_tower_upgrade() -> bool:
	if tower_level >= 3:
		return false
	var cost := get_tower_upgrade_cost()
	var ore_cost := get_tower_upgrade_ore_cost()
	if ore < ore_cost:
		return false
	if not spend_coins(cost):
		return false
	ore -= ore_cost
	ore_changed.emit(ore)
	tower_level += 1
	_apply_level_to_group(&"tower", tower_level)
	building_levels_changed.emit()
	return true


func buy_barracks_upgrade() -> bool:
	if barracks_level >= 3:
		return false
	var cost := get_barracks_upgrade_cost()
	var ore_cost := get_barracks_upgrade_ore_cost()
	if ore < ore_cost:
		return false
	if not spend_coins(cost):
		return false
	ore -= ore_cost
	ore_changed.emit(ore)
	barracks_level += 1
	_apply_level_to_group(&"barracks", barracks_level)
	building_levels_changed.emit()
	return true


func _apply_level_to_group(group_name: StringName, level: int) -> void:
	for n in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(n) and n.has_method(&"apply_upgrade_level"):
			n.call(&"apply_upgrade_level", level)


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
	if awaiting_build_type == BUILD_BARRACKS or awaiting_build_type == BUILD_WAREHOUSE:
		cancel_tower_blueprint()
	if not can_afford_build(BUILD_TOWER):
		return
	awaiting_build_type = BUILD_TOWER
	pending_build_changed.emit(true)


func begin_barracks_blueprint() -> void:
	if not commander_active:
		return
	if awaiting_build_type == BUILD_BARRACKS:
		cancel_tower_blueprint()
		return
	if awaiting_build_type == BUILD_TOWER or awaiting_build_type == BUILD_WAREHOUSE:
		cancel_tower_blueprint()
	if not can_afford_build(BUILD_BARRACKS):
		return
	awaiting_build_type = BUILD_BARRACKS
	pending_build_changed.emit(true)


func begin_warehouse_blueprint() -> void:
	if not commander_active:
		return
	if awaiting_build_type == BUILD_WAREHOUSE:
		cancel_tower_blueprint()
		return
	if awaiting_build_type == BUILD_TOWER or awaiting_build_type == BUILD_BARRACKS:
		cancel_tower_blueprint()
	if not can_afford_build(BUILD_WAREHOUSE):
		return
	awaiting_build_type = BUILD_WAREHOUSE
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


func can_place_build_at(world_pos: Vector3) -> bool:
	if absf(world_pos.x) < BUILD_BASE_CLEAR and absf(world_pos.z) < BUILD_BASE_CLEAR:
		return false
	if world_pos.y > BUILD_MAX_GROUND_Y:
		return false
	if _is_in_player_no_build(world_pos):
		return false
	for mine in get_tree().get_nodes_in_group(&"mine"):
		if not (mine is Node3D) or not is_instance_valid(mine):
			continue
		var m := mine as Node3D
		var dx := world_pos.x - m.global_position.x
		var dz := world_pos.z - m.global_position.z
		if dx * dx + dz * dz <= BUILD_MINE_CLEAR_RADIUS * BUILD_MINE_CLEAR_RADIUS:
			return false
	return true


func try_place_tower(world_pos: Vector3) -> bool:
	if awaiting_build_type == BUILD_NONE or not commander_active:
		return false
	var build_type := awaiting_build_type
	if not can_afford_build(build_type):
		cancel_tower_blueprint()
		return false
	var p := world_pos
	if not can_place_build_at(p):
		return false
	if not spend_build_resources(build_type):
		cancel_tower_blueprint()
		return false
	var world := get_tree().get_first_node_in_group("main_world")
	if world == null:
		refund_build_resources(build_type)
		cancel_tower_blueprint()
		return false
	if build_type == BUILD_TOWER:
		var tower := _TowerFactory.create_tower(tower_level)
		world.add_child(tower)
		tower.global_position = p
	elif build_type == BUILD_BARRACKS:
		var barracks := _BarracksFactory.create_barracks(barracks_level)
		world.add_child(barracks)
		barracks.global_position = p
	else:
		var warehouse := _WarehouseFactory.create_warehouse()
		world.add_child(warehouse)
		warehouse.global_position = p
	awaiting_build_type = BUILD_NONE
	pending_build_changed.emit(false)
	return true
