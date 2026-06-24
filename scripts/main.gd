extends Node3D

const _WorkerScene := preload("res://scenes/worker.tscn")
const _BreakableScene := preload("res://scenes/breakable.tscn")
const _MineScene := preload("res://scenes/mine.tscn")
const _WaveManagerScript := preload("res://scripts/wave_manager.gd")
const _BaseWorldHpScript := preload("res://scripts/base_world_hp.gd")
const _PauseEscListenerScript := preload("res://scripts/pause_menu_esc_listener.gd")
const _WorldBuilderScript := preload("res://scripts/world_builder.gd")
const _WarriorScene       := preload("res://scenes/warrior.tscn")
const _GiantWarriorScript := preload("res://scripts/giant_warrior.gd")
const _AttackKnightScript := preload("res://scripts/attack_knight.gd")
const _AttackBigKnightScript := preload("res://scripts/attack_big_knight.gd")
const _AttackGiantScript  := preload("res://scripts/attack_giant_warrior.gd")
const _EnemyScene         := preload("res://scenes/enemy.tscn")

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const _BG_MUSIC_PATH := "res://assets/music/krepost_strondolt.mp3"
const MUSIC_FADE_SEC := 1.4
const RESOLUTIONS := [
	["4K", Vector2i(3840, 2160)],
	["2K", Vector2i(2560, 1440)],
	["Full HD", Vector2i(1920, 1080)],
	["HD", Vector2i(1280, 720)],
]

## Отступ сундука от маркера спавна игрока (~14, 0, 0).
const PLAYER_SPAWN_CHEST_CLEAR := 5.0
const MAP_RANDOM_HALF := 112.0
const ENDLESS_MAP_SCALE := 2.0
const RANDOM_MINE_COUNT := 2
const RANDOM_TREE_COUNT := 25
const RANDOM_ROCK_COUNT := 25
const ENDLESS_BREAKABLE_MULTIPLIER := 3
const MINE_CLEAR_RADIUS := 15.0
const BREAKABLE_CLEAR_RADIUS := 4.6

const _CASINO_POOLS: Array = [
	# Tier 0 — 1 coin
	[
		{"id": "empty",        "label": "Empty",         "weight": 49.5},
		{"id": "bld_upgrade",  "label": "BUILDING\nUP!", "weight": 0.5},
		{"id": "enemy_attack", "label": "ATTACK!",       "weight": 5},
		{"id": "coin1",        "label": "+1\nCoin",      "weight": 20},
		{"id": "coin3",        "label": "+3\nCoins",     "weight": 12},
		{"id": "coin10",       "label": "+10\nCoins",    "weight": 5},
		{"id": "wood50",       "label": "50\nWood",      "weight": 7},
		{"id": "giant",        "label": "GIANT\nWARRIOR","weight": 1},
	],
	# Tier 1 — 5 coins
	[
		{"id": "empty",        "label": "Empty",         "weight": 40},
		{"id": "bld_upgrade",  "label": "BUILDING\nUP!", "weight": 2},
		{"id": "enemy_attack", "label": "ATTACK!",       "weight": 5},
		{"id": "coin3",        "label": "+3\nCoins",     "weight": 18},
		{"id": "coin8",        "label": "+8\nCoins",     "weight": 12},
		{"id": "coin20",       "label": "+20\nCoins",    "weight": 8},
		{"id": "ore100",       "label": "100\nOre",      "weight": 3},
		{"id": "coin50",       "label": "+50\nCoins",    "weight": 2},
		{"id": "wood100",      "label": "100\nWood",     "weight": 7},
		{"id": "giant",        "label": "GIANT\nWARRIOR","weight": 3},
	],
	# Tier 2 — 10 coins
	[
		{"id": "empty",        "label": "Empty",         "weight": 25},
		{"id": "bld_upgrade",  "label": "BUILDING\nUP!", "weight": 5},
		{"id": "enemy_attack", "label": "ATTACK!",       "weight": 3},
		{"id": "coin5",        "label": "+5\nCoins",     "weight": 14},
		{"id": "coin15",       "label": "+15\nCoins",    "weight": 15},
		{"id": "coin35",       "label": "+35\nCoins",    "weight": 13},
		{"id": "ore200",       "label": "200\nOre",      "weight": 8},
		{"id": "coin100",      "label": "+100\nCoins",   "weight": 1},
		{"id": "wood200",      "label": "200\nWood",     "weight": 7},
		{"id": "free_knight",  "label": "FREE\nKNIGHT",  "weight": 4},
		{"id": "giant",        "label": "GIANT\nWARRIOR","weight": 5},
	],
]
const _CASINO_TIER_COSTS: Array[int] = [1, 5, 10]
const _CASINO_BG: Dictionary = {
	"empty":        Color(0.10, 0.10, 0.10),
	"bld_upgrade":  Color(0.05, 0.25, 0.10),
	"enemy_attack": Color(0.30, 0.04, 0.04),
	"giant":        Color(0.22, 0.00, 0.38),
	"free_knight":  Color(0.04, 0.16, 0.34),
	"ore100":       Color(0.04, 0.18, 0.38),
	"ore200":       Color(0.04, 0.18, 0.38),
	"wood50":       Color(0.22, 0.10, 0.03),
	"wood100":      Color(0.22, 0.10, 0.03),
	"wood200":      Color(0.22, 0.10, 0.03),
}
const _CASINO_TXT: Dictionary = {
	"empty":        Color(0.38, 0.38, 0.38),
	"bld_upgrade":  Color(0.35, 1.00, 0.55),
	"enemy_attack": Color(1.00, 0.22, 0.18),
	"giant":        Color(0.88, 0.45, 1.00),
	"free_knight":  Color(0.40, 0.90, 1.00),
	"ore100":       Color(0.40, 0.90, 1.00),
	"ore200":       Color(0.40, 0.90, 1.00),
	"wood50":       Color(0.75, 0.48, 0.15),
	"wood100":      Color(0.75, 0.48, 0.15),
	"wood200":      Color(0.75, 0.48, 0.15),
}
const _CASINO_ITEM_W  := 86
const _CASINO_ITEM_H  := 60
const _CASINO_SEP     := 2
const _CASINO_STRIDE  := 88  # ITEM_W + SEP
const _CASINO_VIS     := 5
const _CASINO_TOTAL   := 40
const _CASINO_FIN_IDX := 32

@onready var _coin_label: Label = $CanvasLayer/CoinLabel
@onready var _ore_label: Label = $CanvasLayer/OreLabel
@onready var _base_hp_label: Label = $CanvasLayer/BaseHpLabel
@onready var _worker_spawn: Marker3D = $WorkerSpawn
@onready var _ore_deposit: Marker3D = $OreDeposit

var _build_layer: CanvasLayer
var _tower_button:    Button
var _skywatch_button: Button
var _barracks_button: Button
var _warehouse_button: Button
var _market_building_button: Button
var _house_button: Button
var _pop_label: Label
var _attack_knight_button: Button
var _attack_big_knight_button: Button
var _attack_giant_button: Button
var _dmg_upgrade_button: Button
var _market_tab_idx: int = -1
var _bld_panel_layer:      CanvasLayer
var _bld_panel_container:  PanelContainer
var _bld_selected:         Node3D = null
var _bld_title_lbl:        Label
var _bld_upgrade_btn:      Button
var _bld_flag_btn:         Button
var _bld_magic_btn:        Button
var _selection_ring:       Node3D = null
var _wood_label: Label
var _market_buttons: Array[Button] = []
var _buy_worker_button: Button
var _buy_woodcutter_button: Button
var _worker_timer_label: Label

const _SPAWN_ICONS: Dictionary = {"miner": "⛏", "woodcutter": "🌲", "knight": "⚔", "big_knight": "🗡", "giant": "🛡"}
const _SPAWN_TIMES: Dictionary = {"miner": 5.0, "woodcutter": 5.0, "knight": 1.0, "big_knight": 2.0, "giant": 20.0}

var _spawn_queue: Array = []
var _spawn_timer_left: float = 0.0
var _spawn_queue_row: HBoxContainer

var _casino_tier: int = 0
var _casino_tier_btns: Array[Button] = []
var _casino_roll_btn:   Button
var _casino_result_lbl: Label
var _casino_strip_row:  HBoxContainer
var _casino_clip:       Control
var _casino_rolling     := false

var _dev_console_layer: CanvasLayer
var _dev_line:          LineEdit
var _dev_inf_res_btn:   Button
var _dev_unbreak_btn:   Button
var _money_cmd_regex: RegEx

var _wave_countdown_label: Label
var _enemy_base_label: Label  # Mission 3 only

var _game_over_layer: CanvasLayer
var _restart_button: Button

var _win_layer: CanvasLayer
var _win_play_again_button: Button
var _win_exit_button: Button
var _victory_shown := false

var _pause_menu_layer: CanvasLayer
var _bg_music_player: AudioStreamPlayer
var _music_volume_slider: HSlider
var _sound_volume_slider: HSlider
var _resolution_option: OptionButton
var _fullscreen_check: CheckBox
var _pause_menu_open: bool = false


func _ready() -> void:
	randomize()
	add_to_group("main_world")
	_apply_map_scale()
	var wm := Node.new()
	wm.set_script(_WaveManagerScript)
	wm.name = "WaveManager"
	add_child(wm)
	_randomize_map_resources()
	set_process_input(true)
	set_process_unhandled_input(true)
	_money_cmd_regex = RegEx.new()
	_money_cmd_regex.compile("(?i)^\\s*Money\\s*:\\s*(-?\\d+)\\s*$")
	_setup_dev_console()
	_setup_game_over_ui()
	_setup_victory_ui()
	_setup_pause_menu()
	GameState.base_destroyed.connect(_on_base_destroyed)
	GameState.enemy_base_destroyed.connect(_on_enemy_base_destroyed)
	GameState.enemy_base_hp_changed.connect(_on_enemy_base_hp_changed)
	GameState.pause_menu_toggle_requested.connect(_on_pause_menu_toggle_requested)
	var hp_world := Node3D.new()
	hp_world.set_script(_BaseWorldHpScript)
	hp_world.name = "BaseHpWorld"
	$Base.add_child(hp_world)
	_setup_background_music()
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_label.focus_mode = Control.FOCUS_NONE
	_ore_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ore_label.focus_mode = Control.FOCUS_NONE
	_base_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_hp_label.focus_mode = Control.FOCUS_NONE
	_setup_hud_style()
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.ore_changed.connect(_on_ore_changed)
	GameState.wood_changed.connect(_on_wood_changed)
	GameState.population_changed.connect(_on_population_changed)
	GameState.base_hp_changed.connect(_on_base_hp_changed)
	GameState.commander_mode_changed.connect(_on_commander_mode)
	GameState.pending_build_changed.connect(_on_pending_build)
	GameState.building_levels_changed.connect(_refresh_upgrade_buttons)
	GameState.building_selected.connect(_open_building_panel)
	GameState.coins_changed.connect(_on_bld_coins_changed)
	GameState.ore_changed.connect(_on_bld_coins_changed)
	GameState.flag_placement_changed.connect(_refresh_building_panel)
	_on_coins_changed(GameState.coins)
	_refresh_ore_labels()
	_on_base_hp_changed(GameState.base_hp, GameState.BASE_MAX_HP)
	_setup_wave_timer_ui()
	if not GameState.is_terrain_mission():
		call_deferred(&"_spawn_secret_chest_random")
	if GameState.has_giant_warrior:
		call_deferred(&"_spawn_saved_giant_warrior")


func _spawn_saved_giant_warrior() -> void:
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	add_child(gw)
	if GameState.is_terrain_mission():
		_gw_place_m2(gw)
	else:
		gw.global_position = Vector3(7.0, 0.55, 22.0)


## Spawns a Giant Warrior at the Base end of Mission 2's Path3D.
## GW will then reverse-march along the path toward EnemySpawn.
func _gw_place_m2(gw: CharacterBody3D) -> void:
	var path := get_tree().get_first_node_in_group(&"m2_enemy_path") as Path3D
	if path != null:
		var curve      := path.curve
		var end_local  := curve.sample_baked(curve.get_baked_length(), true)
		var spawn_pos  := path.to_global(end_local) + Vector3(0.0, 1.0, 0.0)
		gw.global_position = spawn_pos
		print("GiantWarrior M2 spawn: ", spawn_pos)
	else:
		push_warning("GiantWarrior M2: m2_enemy_path empty — using fallback")
		gw.global_position = Vector3(248.0, 4.0, 358.0)


func _apply_map_scale() -> void:
	if GameState.game_mode != GameState.GAME_MODE_ENDLESS:
		return
	var ground := get_node_or_null("Ground")
	if ground == null:
		return
	ground.scale.x = ENDLESS_MAP_SCALE
	ground.scale.z = ENDLESS_MAP_SCALE


func _setup_background_music() -> void:
	if not ResourceLoader.exists(_BG_MUSIC_PATH):
		push_warning("Background music not found: %s" % _BG_MUSIC_PATH)
		return
	var stream: AudioStream = load(_BG_MUSIC_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var bgm := AudioStreamPlayer.new()
	bgm.name = "BackgroundMusic"
	bgm.stream = stream
	bgm.volume_db = -80.0
	bgm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm)
	bgm.play()
	_bg_music_player = bgm
	create_tween().tween_property(bgm, "volume_db", -22.0, MUSIC_FADE_SEC)


func _setup_hud_style() -> void:
	var cl: CanvasLayer = $CanvasLayer
	_wood_label = Label.new()
	_wood_label.name = &"WoodLabel"
	_wood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood_label.focus_mode = Control.FOCUS_NONE
	cl.add_child(_wood_label)

	_pop_label = Label.new()
	_pop_label.name = &"PopulationLabel"
	_pop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop_label.focus_mode = Control.FOCUS_NONE
	cl.add_child(_pop_label)

	var panel := PanelContainer.new()
	panel.name = &"TopHudPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.offset_left = 10.0
	panel.offset_top = 8.0
	panel.offset_right = 520.0
	panel.offset_bottom = 82.0
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style(UiStyle.PANEL_BG_SOFT, UiStyle.PANEL_BORDER_DIM, 9, 1))
	cl.add_child(panel)
	cl.move_child(panel, 0)

	_coin_label.offset_left = 18.0
	_coin_label.offset_top = 9.0
	_coin_label.offset_right = 170.0
	_coin_label.offset_bottom = 32.0
	_ore_label.offset_left = 190.0
	_ore_label.offset_top = 9.0
	_ore_label.offset_right = 350.0
	_ore_label.offset_bottom = 32.0
	_wood_label.offset_left = 18.0
	_wood_label.offset_top = 32.0
	_wood_label.offset_right = 220.0
	_wood_label.offset_bottom = 56.0
	_pop_label.offset_left = 240.0
	_pop_label.offset_top = 32.0
	_pop_label.offset_right = 400.0
	_pop_label.offset_bottom = 56.0
	_base_hp_label.offset_left = 18.0
	_base_hp_label.offset_top = 56.0
	_base_hp_label.offset_right = 350.0
	_base_hp_label.offset_bottom = 80.0

	UiStyle.style_label(_coin_label, UiStyle.TEXT_COIN, 16, 3)
	UiStyle.style_label(_ore_label, UiStyle.TEXT_ORE, 16, 3)
	UiStyle.style_label(_wood_label, Color(0.72, 0.42, 0.16), 16, 3)
	UiStyle.style_label(_pop_label, Color(0.55, 0.85, 0.55), 16, 3)
	_pop_label.text = "Pop: %d/%d" % [GameState.population, GameState.population_max]
	UiStyle.style_label(_base_hp_label, UiStyle.TEXT_HP, 15, 3)


func _randomize_map_resources() -> void:
	if GameState.is_terrain_mission():
		return
	_remove_scene_resource_placeholders()
	var occupied: Array = []
	_add_reserved_area(occupied, Vector3.ZERO, 20.0)
	_add_reserved_area(occupied, $ExteriorSpawn.global_position, 8.0)
	_add_reserved_area(occupied, _worker_spawn.global_position, 7.0)
	_add_reserved_area(occupied, _ore_deposit.global_position, 6.0)

	for i in range(RANDOM_MINE_COUNT):
		var pos := _pick_random_map_position(occupied, MINE_CLEAR_RADIUS)
		_add_reserved_area(occupied, pos, MINE_CLEAR_RADIUS)
		_spawn_random_mine(i, pos)

	var breakable_mul := ENDLESS_BREAKABLE_MULTIPLIER if GameState.game_mode == GameState.GAME_MODE_ENDLESS else 1
	for i in range(RANDOM_TREE_COUNT * breakable_mul):
		var tree_pos := _pick_random_map_position(occupied, BREAKABLE_CLEAR_RADIUS)
		_add_reserved_area(occupied, tree_pos, BREAKABLE_CLEAR_RADIUS)
		_spawn_random_breakable(i, tree_pos, true)

	for i in range(RANDOM_ROCK_COUNT * breakable_mul):
		var rock_pos := _pick_random_map_position(occupied, BREAKABLE_CLEAR_RADIUS)
		_add_reserved_area(occupied, rock_pos, BREAKABLE_CLEAR_RADIUS)
		_spawn_random_breakable(i, rock_pos, false)


func _remove_scene_resource_placeholders() -> void:
	for child in get_children():
		var n := String(child.name)
		if n.begins_with("Tree") or n.begins_with("Rock") or child.is_in_group(&"mine"):
			remove_child(child)
			child.free()


func _spawn_random_mine(index: int, pos: Vector3) -> void:
	var mine: Node3D = _MineScene.instantiate() as Node3D
	mine.name = "Mine%d" % (index + 1)
	mine.global_position = pos
	mine.rotation.y = randf() * TAU
	add_child(mine)


func _spawn_random_breakable(index: int, pos: Vector3, is_tree: bool) -> void:
	var obj: Node3D = _BreakableScene.instantiate() as Node3D
	obj.name = "%s%d" % ["Tree" if is_tree else "Rock", index + 1]
	obj.set(&"is_tree", is_tree)
	if is_tree:
		obj.set(&"tree_variant", index % 4)
	else:
		obj.set(&"rock_variant", index % 4)
	obj.global_position = pos
	obj.rotation.y = randf() * TAU
	add_child(obj)


func _add_reserved_area(occupied: Array, pos: Vector3, radius: float) -> void:
	occupied.append({
		"pos": Vector2(pos.x, pos.z),
		"radius": radius,
	})


func _pick_random_map_position(occupied: Array, radius: float) -> Vector3:
	for _i in range(256):
		var half := MAP_RANDOM_HALF * GameState.get_map_scale()
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		var p := Vector2(x, z)
		if _is_random_position_clear(p, radius, occupied):
			return Vector3(x, 0.0, z)
	var half := MAP_RANDOM_HALF * GameState.get_map_scale()
	return Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))


func _is_random_position_clear(p: Vector2, radius: float, occupied: Array) -> bool:
	for item in occupied:
		var other := item["pos"] as Vector2
		var min_dist := radius + float(item["radius"])
		if p.distance_squared_to(other) < min_dist * min_dist:
			return false
	return true


func _spawn_secret_chest_random() -> void:
	var chest: Node = _BreakableScene.instantiate()
	if chest == null:
		return
	chest.set(&"is_tree", false)
	chest.set(&"is_chest", true)
	chest.set(&"coin_reward", 10)
	var p := _pick_random_chest_position()
	chest.global_position = p
	chest.rotation.y = randf() * TAU
	add_child(chest)


func _pick_random_chest_position() -> Vector3:
	const half := 118.0
	const base_r := 11.0
	const spawn_cx := 14.0
	for _i in range(48):
		var x := randf_range(-half, half)
		var z := randf_range(-half, half)
		if Vector2(x, z).length() < base_r:
			continue
		if absf(x - spawn_cx) < PLAYER_SPAWN_CHEST_CLEAR and absf(z) < PLAYER_SPAWN_CHEST_CLEAR:
			continue
		return Vector3(x, 0.0, z)
	return Vector3(62.0, 0.0, -58.0)


func _process(delta: float) -> void:
	if not _spawn_queue.is_empty():
		_spawn_timer_left -= delta
		if _worker_timer_label:
			var first: Dictionary = _spawn_queue[0]
			_worker_timer_label.text = "Spawning %s: %.1f s" % [first.get("type", "?"), maxf(_spawn_timer_left, 0.0)]
		if _spawn_timer_left <= 0.0:
			var entry: Dictionary = _spawn_queue[0]
			_spawn_queue.remove_at(0)
			_do_spawn_entry(entry)
			_spawn_timer_left = float(_spawn_queue[0].get("time", 5.0)) if not _spawn_queue.is_empty() else 0.0
			_refresh_workers_ui()
			_rebuild_spawn_queue_ui()
	_update_wave_countdown_label()
	_try_show_victory()


func _setup_wave_timer_ui() -> void:
	var cl: CanvasLayer = $CanvasLayer
	_wave_countdown_label = Label.new()
	_wave_countdown_label.name = "WaveTimerLabel"
	_wave_countdown_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_countdown_label.offset_left = -440.0
	_wave_countdown_label.offset_top = 12.0
	_wave_countdown_label.offset_right = -20.0
	_wave_countdown_label.offset_bottom = 50.0
	_wave_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.style_label(_wave_countdown_label, Color(0.9, 0.68, 1.0), 22, 5)
	_wave_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_countdown_label.focus_mode = Control.FOCUS_NONE
	cl.add_child(_wave_countdown_label)

	# Mission 3 — no waves; show enemy base HP + mission timer instead.
	if GameState.is_base_assault():
		_enemy_base_label = Label.new()
		_enemy_base_label.name = "EnemyBaseLabel"
		_enemy_base_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_enemy_base_label.offset_left = -440.0
		_enemy_base_label.offset_top = 48.0
		_enemy_base_label.offset_right = -20.0
		_enemy_base_label.offset_bottom = 84.0
		_enemy_base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_enemy_base_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_enemy_base_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_base_label.focus_mode = Control.FOCUS_NONE
		UiStyle.style_label(_enemy_base_label, Color(1.0, 0.5, 0.45), 20, 5)
		cl.add_child(_enemy_base_label)
		_on_enemy_base_hp_changed(GameState.enemy_base_hp, GameState.enemy_base_max)

	_update_wave_countdown_label()


func _update_wave_countdown_label() -> void:
	if _wave_countdown_label == null:
		return
	if GameState.is_base_assault():
		# Reuse the top-right slot for a mission timer; base HP shown below it.
		var t := int(GameState.mission_time)
		_wave_countdown_label.text = "Assault — %d:%02d" % [t / 60, t % 60]
		return
	var wm: Node = get_node_or_null("WaveManager")
	if wm == null or not wm.has_method(&"get_wave_timer_hud_text"):
		return
	_wave_countdown_label.text = wm.call(&"get_wave_timer_hud_text") as String


func _on_enemy_base_hp_changed(current: int, maximum: int) -> void:
	if _enemy_base_label == null:
		return
	_enemy_base_label.text = "Enemy Base: %d / %d" % [current, maximum]


func _on_enemy_base_destroyed() -> void:
	_show_victory_screen()


func _spawn_worker(role: String = "miner") -> void:
	var inst: Node = _WorkerScene.instantiate()
	if inst.has_method(&"setup"):
		inst.call(&"setup", _ore_deposit.global_position, role)
	GameState.register_population_unit(inst)
	add_child(inst)
	inst.global_position = _worker_spawn.global_position


func _setup_commander_build_ui() -> void:
	_build_layer = CanvasLayer.new()
	_build_layer.name = "CommanderBuildUI"
	_build_layer.layer = 12
	_build_layer.visible = false
	add_child(_build_layer)

	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -132.0
	bar.offset_bottom = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.focus_mode = Control.FOCUS_NONE
	bar.add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	_build_layer.add_child(bar)

	var outer_col := VBoxContainer.new()
	outer_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_child(outer_col)

	var queue_strip := HBoxContainer.new()
	queue_strip.add_theme_constant_override("separation", 6)
	outer_col.add_child(queue_strip)

	_worker_timer_label = Label.new()
	_worker_timer_label.text = "No queue"
	UiStyle.style_label(_worker_timer_label, UiStyle.TEXT_MUTED, 14, 3)
	queue_strip.add_child(_worker_timer_label)

	_spawn_queue_row = HBoxContainer.new()
	_spawn_queue_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn_queue_row.add_theme_constant_override("separation", 4)
	queue_strip.add_child(_spawn_queue_row)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.mouse_filter = Control.MOUSE_FILTER_STOP
	tabs.focus_mode = Control.FOCUS_NONE
	tabs.tab_changed.connect(func(_idx: int) -> void: SoundManager.play_ui(&"ui_switch"))
	outer_col.add_child(tabs)

	var build_tab := MarginContainer.new()
	build_tab.name = "Defence"
	build_tab.add_theme_constant_override("margin_left", 6)
	build_tab.add_theme_constant_override("margin_top", 4)
	build_tab.add_theme_constant_override("margin_right", 6)
	build_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(build_tab)

	var row_build := HBoxContainer.new()
	row_build.alignment = BoxContainer.ALIGNMENT_BEGIN
	build_tab.add_child(row_build)

	_tower_button = Button.new()
	_tower_button.focus_mode = Control.FOCUS_NONE
	_tower_button.custom_minimum_size = Vector2(118, 96)
	_tower_button.text = "TOWER\n🏰\n%d ore\n%d wood" % [GameState.TOWER_ORE_COST, GameState.TOWER_WOOD_COST]
	_tower_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_tower_button, 15)
	_tower_button.pressed.connect(_on_tower_button_pressed)
	row_build.add_child(_tower_button)

	_barracks_button = Button.new()
	_barracks_button.focus_mode = Control.FOCUS_NONE
	_barracks_button.custom_minimum_size = Vector2(128, 96)
	_barracks_button.text = "BARRACKS\n🛖\n%d ore\n%d wood" % [GameState.BARRACKS_ORE_COST, GameState.BARRACKS_WOOD_COST]
	_barracks_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_barracks_button, 14)
	_barracks_button.tooltip_text = "Up to 4 warriors; each respawns 10 s after death."
	_barracks_button.pressed.connect(_on_barracks_button_pressed)
	row_build.add_child(_barracks_button)

	_skywatch_button = Button.new()
	_skywatch_button.focus_mode = Control.FOCUS_NONE
	_skywatch_button.custom_minimum_size = Vector2(118, 96)
	_skywatch_button.text = "SKYWATCH\n🔭\n%d ore\n%d wood" % [GameState.SKYWATCH_ORE_COST, GameState.SKYWATCH_WOOD_COST]
	_skywatch_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_skywatch_button, 13)
	_skywatch_button.tooltip_text = "Anti-air tower. Attacks flying enemies only. 20% more range than standard tower."
	_skywatch_button.pressed.connect(_on_skywatch_button_pressed)
	row_build.add_child(_skywatch_button)

	var buildings_tab := MarginContainer.new()
	buildings_tab.name = "Buildings"
	buildings_tab.add_theme_constant_override("margin_left", 6)
	buildings_tab.add_theme_constant_override("margin_top", 4)
	buildings_tab.add_theme_constant_override("margin_right", 6)
	buildings_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(buildings_tab)

	var row_buildings := HBoxContainer.new()
	row_buildings.alignment = BoxContainer.ALIGNMENT_BEGIN
	buildings_tab.add_child(row_buildings)

	_warehouse_button = Button.new()
	_warehouse_button.focus_mode = Control.FOCUS_NONE
	_warehouse_button.custom_minimum_size = Vector2(118, 96)
	_warehouse_button.text = "WAREHOUSE\n📦\n%d ore\n%d wood" % [GameState.WAREHOUSE_ORE_COST, GameState.WAREHOUSE_WOOD_COST]
	_warehouse_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_warehouse_button, 13)
	_warehouse_button.tooltip_text = "Workers unload at the nearest warehouse or base; storage is shared."
	_warehouse_button.pressed.connect(_on_warehouse_button_pressed)
	row_buildings.add_child(_warehouse_button)

	_market_building_button = Button.new()
	_market_building_button.focus_mode = Control.FOCUS_NONE
	_market_building_button.custom_minimum_size = Vector2(118, 96)
	_market_building_button.text = "MARKET\n🏪\n%d ore\n%d wood" % [GameState.MARKET_ORE_COST, GameState.MARKET_WOOD_COST]
	_market_building_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_market_building_button, 13)
	_market_building_button.tooltip_text = "Passively generates coins over time. Upgradeable to Lv3 for faster income."
	_market_building_button.pressed.connect(_on_market_building_button_pressed)
	row_buildings.add_child(_market_building_button)

	_house_button = Button.new()
	_house_button.focus_mode = Control.FOCUS_NONE
	_house_button.custom_minimum_size = Vector2(118, 96)
	_house_button.text = "HOUSE\n🏠\n%d coins\n%d wood" % [GameState.HOUSE_COIN_COST, GameState.HOUSE_WOOD_COST]
	_house_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_house_button, 13)
	_house_button.tooltip_text = "+%d max population. No upgrades. Max %d houses." % [GameState.HOUSE_POPULATION_BONUS, GameState.MAX_HOUSES]
	_house_button.pressed.connect(_on_house_button_pressed)
	row_buildings.add_child(_house_button)

	var attack_tab := MarginContainer.new()
	attack_tab.name = "Attack"
	attack_tab.add_theme_constant_override("margin_left", 6)
	attack_tab.add_theme_constant_override("margin_top", 4)
	attack_tab.add_theme_constant_override("margin_right", 6)
	attack_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(attack_tab)

	var row_attack := HBoxContainer.new()
	row_attack.alignment = BoxContainer.ALIGNMENT_BEGIN
	attack_tab.add_child(row_attack)

	_attack_knight_button = Button.new()
	_attack_knight_button.focus_mode = Control.FOCUS_NONE
	_attack_knight_button.custom_minimum_size = Vector2(118, 96)
	_attack_knight_button.text = "KNIGHT\n⚔\n%d coins" % GameState.ATTACK_KNIGHT_COIN_COST
	_attack_knight_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_attack_knight_button, 13)
	_attack_knight_button.tooltip_text = "Sends a Knight from the base to march down the path and fight the first enemy it meets."
	_attack_knight_button.pressed.connect(_on_attack_knight_button_pressed)
	row_attack.add_child(_attack_knight_button)

	_attack_big_knight_button = Button.new()
	_attack_big_knight_button.focus_mode = Control.FOCUS_NONE
	_attack_big_knight_button.custom_minimum_size = Vector2(118, 96)
	_attack_big_knight_button.text = "BIG KNIGHT\n🗡\n%d coins" % GameState.ATTACK_BIG_KNIGHT_COIN_COST
	_attack_big_knight_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_attack_big_knight_button, 13)
	_attack_big_knight_button.tooltip_text = "A larger, tougher Knight (more HP and damage). Marches down the path and crushes what it meets."
	_attack_big_knight_button.pressed.connect(_on_attack_big_knight_button_pressed)
	row_attack.add_child(_attack_big_knight_button)

	_attack_giant_button = Button.new()
	_attack_giant_button.focus_mode = Control.FOCUS_NONE
	_attack_giant_button.custom_minimum_size = Vector2(118, 96)
	_attack_giant_button.text = "GIANT WARRIOR\n🛡\n%d coins" % GameState.ATTACK_GIANT_COIN_COST
	_attack_giant_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_attack_giant_button, 13)
	_attack_giant_button.tooltip_text = "Sends a Giant Warrior from the base to march down the path and crush the enemies it meets."
	_attack_giant_button.pressed.connect(_on_attack_giant_button_pressed)
	row_attack.add_child(_attack_giant_button)

	var upgrades_tab := MarginContainer.new()
	upgrades_tab.name = "Upgrades"
	upgrades_tab.add_theme_constant_override("margin_left", 6)
	upgrades_tab.add_theme_constant_override("margin_top", 4)
	upgrades_tab.add_theme_constant_override("margin_right", 6)
	upgrades_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(upgrades_tab)

	var row_up := HBoxContainer.new()
	row_up.alignment = BoxContainer.ALIGNMENT_BEGIN
	upgrades_tab.add_child(row_up)

	_dmg_upgrade_button = Button.new()
	_dmg_upgrade_button.focus_mode = Control.FOCUS_NONE
	_dmg_upgrade_button.custom_minimum_size = Vector2(112, 96)
	_dmg_upgrade_button.text = "🗡️ 🔼\nDMG +10\n5 coins"
	_dmg_upgrade_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_dmg_upgrade_button, 14)
	_dmg_upgrade_button.tooltip_text = "Sword damage vs trees and rocks: +10 per hit. Enemy damage is unchanged."
	_dmg_upgrade_button.pressed.connect(_on_dmg_upgrade_pressed)
	row_up.add_child(_dmg_upgrade_button)

	# Tower and Barracks upgrades are now per-building (click a building in Commander Mode)

	var market_tab := MarginContainer.new()
	market_tab.name = "Market"
	market_tab.add_theme_constant_override("margin_left", 6)
	market_tab.add_theme_constant_override("margin_top", 4)
	market_tab.add_theme_constant_override("margin_right", 6)
	market_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(market_tab)
	_market_tab_idx = tabs.get_tab_count() - 1
	tabs.set_tab_disabled(_market_tab_idx, not GameState.has_market_building)
	GameState.market_building_changed.connect(func() -> void:
		tabs.set_tab_disabled(_market_tab_idx, not GameState.has_market_building)
	)

	# Сделки сгруппированы по ресурсу-результату: колонка = что получаешь
	var market_row := HBoxContainer.new()
	market_row.add_theme_constant_override("separation", 14)
	market_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_tab.add_child(market_row)

	market_row.add_child(_make_market_column("🪙 COIN", UiStyle.TEXT_COIN, [
		["10 🪵 → 1 🪙",   1, -10,    0],
		["50 🪵 → 5 🪙",   5, -50,    0],
		["100 🪨 → 1 🪙",  1,   0, -100],
		["500 🪨 → 5 🪙",  5,   0, -500],
	]))
	market_row.add_child(_make_market_column("🪵 WOOD", Color(0.72, 0.42, 0.16), [
		["1 🪙 → 5 🪵",   -1,   5,    0],
		["10 🪙 → 50 🪵", -10,  50,   0],
	]))
	market_row.add_child(_make_market_column("🪨 ORE", UiStyle.TEXT_ORE, [
		["1 🪙 → 50 🪨",   -1,  0,   50],
		["10 🪙 → 500 🪨", -10, 0,  500],
	]))

	var workers_tab := MarginContainer.new()
	workers_tab.name = "Workers"
	workers_tab.add_theme_constant_override("margin_left", 6)
	workers_tab.add_theme_constant_override("margin_top", 4)
	workers_tab.add_theme_constant_override("margin_right", 6)
	workers_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(workers_tab)

	var workers_col := VBoxContainer.new()
	workers_col.add_theme_constant_override("separation", 10)
	workers_tab.add_child(workers_col)

	var worker_buttons_row := HBoxContainer.new()
	worker_buttons_row.add_theme_constant_override("separation", 10)
	workers_col.add_child(worker_buttons_row)

	_buy_worker_button = Button.new()
	_buy_worker_button.focus_mode = Control.FOCUS_NONE
	_buy_worker_button.text = "Miner\n%d coins" % GameState.WORKER_COST
	_buy_worker_button.custom_minimum_size = Vector2(160, 88)
	_buy_worker_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_buy_worker_button, 15)
	_buy_worker_button.tooltip_text = "Mines ore and unloads it at the base or nearest warehouse."
	_buy_worker_button.pressed.connect(_on_buy_miner_pressed)
	worker_buttons_row.add_child(_buy_worker_button)

	_buy_woodcutter_button = Button.new()
	_buy_woodcutter_button.focus_mode = Control.FOCUS_NONE
	_buy_woodcutter_button.text = "Woodcutter\n%d coins" % GameState.WORKER_COST
	_buy_woodcutter_button.custom_minimum_size = Vector2(160, 88)
	_buy_woodcutter_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_buy_woodcutter_button, 15)
	_buy_woodcutter_button.tooltip_text = "Cuts the nearest tree, gains 10 wood, then unloads it at the base or warehouse."
	_buy_woodcutter_button.pressed.connect(_on_buy_woodcutter_pressed)
	worker_buttons_row.add_child(_buy_woodcutter_button)

	_build_casino_tab(tabs)

	bar.offset_top = -270.0
	_setup_building_panel()
	_on_coins_changed(GameState.coins)
	_refresh_ore_labels()
	_refresh_workers_ui()
	_refresh_upgrade_buttons()


func _on_tower_button_pressed() -> void:
	GameState.begin_tower_blueprint()


func _on_barracks_button_pressed() -> void:
	GameState.begin_barracks_blueprint()


func _on_warehouse_button_pressed() -> void:
	GameState.begin_warehouse_blueprint()


func _on_market_building_button_pressed() -> void:
	GameState.begin_market_blueprint()


func _on_house_button_pressed() -> void:
	GameState.begin_house_blueprint()


func _on_skywatch_button_pressed() -> void:
	GameState.begin_skywatch_blueprint()


func _on_attack_knight_button_pressed() -> void:
	_enqueue_spawn("knight", GameState.ATTACK_KNIGHT_COIN_COST)


func _on_attack_big_knight_button_pressed() -> void:
	_enqueue_spawn("big_knight", GameState.ATTACK_BIG_KNIGHT_COIN_COST)


func _on_attack_giant_button_pressed() -> void:
	_enqueue_spawn("giant", GameState.ATTACK_GIANT_COIN_COST)


func _on_dmg_upgrade_pressed() -> void:
	GameState.buy_dmg_upgrade()
	_refresh_upgrade_buttons()




## Колонка рынка: заголовок-ресурс + сделки, дающие этот ресурс.
## trades: Array of [text, coin_delta, wood_delta, ore_delta]
func _make_market_column(title: String, title_col: Color, trades: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hdr := Label.new()
	hdr.text = title
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(hdr, title_col, 15, 2)
	col.add_child(hdr)
	for t in trades:
		_add_market_button(col, t[0] as String, int(t[1]), int(t[2]), int(t[3]))
	return col


func _add_market_button(parent: Node, text: String, coin_delta: int, wood_delta: int, ore_delta: int) -> void:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 34)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(btn, 14)
	btn.pressed.connect(func() -> void:
		GameState.try_market_trade(coin_delta, wood_delta, ore_delta)
		_refresh_market_buttons()
	)
	parent.add_child(btn)
	btn.set_meta(&"coin_delta", coin_delta)
	btn.set_meta(&"wood_delta", wood_delta)
	btn.set_meta(&"ore_delta", ore_delta)
	_market_buttons.append(btn)


func _on_buy_miner_pressed() -> void:
	_enqueue_spawn("miner", GameState.WORKER_COST)


func _on_buy_woodcutter_pressed() -> void:
	_enqueue_spawn("woodcutter", GameState.WORKER_COST)


func _refresh_workers_ui() -> void:
	if _buy_worker_button == null or _worker_timer_label == null:
		return
	_buy_worker_button.text = "Miner\n%d coins" % GameState.WORKER_COST
	if _buy_woodcutter_button:
		_buy_woodcutter_button.text = "Woodcutter\n%d coins" % GameState.WORKER_COST
	var no_room := not GameState.has_population_room()
	_buy_worker_button.disabled = GameState.coins < GameState.WORKER_COST or no_room
	if _buy_woodcutter_button:
		_buy_woodcutter_button.disabled = GameState.coins < GameState.WORKER_COST or no_room
	if _spawn_queue.is_empty():
		_worker_timer_label.text = "No queue"
	else:
		var first: Dictionary = _spawn_queue[0]
		_worker_timer_label.text = "Spawning %s: %.1f s" % [first.get("type", "?"), maxf(_spawn_timer_left, 0.0)]


func _enqueue_spawn(type: String, cost: int) -> void:
	# Только рабочие занимают слот населения; attack-юниты больше не ограничены.
	var needs_pop := type == "miner" or type == "woodcutter"
	if needs_pop and not GameState.reserve_population():
		return
	if not GameState.spend_coins(cost):
		if needs_pop:
			GameState.release_population()
		return
	_spawn_queue.append({"type": type, "cost": cost, "time": _SPAWN_TIMES.get(type, 5.0), "icon": _SPAWN_ICONS.get(type, "?"), "pop": needs_pop})
	if _spawn_queue.size() == 1:
		_spawn_timer_left = float(_spawn_queue[0].get("time", 5.0))
	_refresh_workers_ui()
	_rebuild_spawn_queue_ui()


func _cancel_queue_entry(idx: int) -> void:
	if idx < 0 or idx >= _spawn_queue.size():
		return
	var entry: Dictionary = _spawn_queue[idx]
	GameState.add_coins(int(entry.get("cost", 0)))
	if bool(entry.get("pop", false)):
		GameState.release_population()
	_spawn_queue.remove_at(idx)
	if idx == 0:
		_spawn_timer_left = float(_spawn_queue[0].get("time", 5.0)) if not _spawn_queue.is_empty() else 0.0
	_refresh_workers_ui()
	_rebuild_spawn_queue_ui()


func _rebuild_spawn_queue_ui() -> void:
	if _spawn_queue_row == null:
		return
	for child in _spawn_queue_row.get_children():
		child.queue_free()
	for i in _spawn_queue.size():
		var entry: Dictionary = _spawn_queue[i]
		var icon := entry.get("icon", "?") as String
		var btn := Button.new()
		btn.text = icon
		btn.custom_minimum_size = Vector2(36, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = "Cancel — refunds %d coins" % entry.get("cost", 0)
		UiStyle.style_button(btn, 13)
		btn.set_meta(&"orig_icon", icon)
		btn.mouse_entered.connect(func() -> void: btn.text = "✕")
		btn.mouse_exited.connect(func() -> void: btn.text = btn.get_meta(&"orig_icon") as String)
		btn.pressed.connect(_cancel_queue_entry.bind(i))
		_spawn_queue_row.add_child(btn)


func _do_spawn_entry(entry: Dictionary) -> void:
	match entry.get("type", "") as String:
		"miner", "woodcutter":
			_spawn_worker(entry.get("type", "miner") as String)
		"knight":
			var k := _WarriorScene.instantiate() as CharacterBody3D
			k.set_script(_AttackKnightScript)
			add_child(k)
			if GameState.is_terrain_mission():
				_gw_place_m2(k)
			else:
				k.global_position = Vector3(7.0, 0.55, 22.0)
		"big_knight":
			var bk := _WarriorScene.instantiate() as CharacterBody3D
			bk.set_script(_AttackBigKnightScript)
			add_child(bk)
			if GameState.is_terrain_mission():
				_gw_place_m2(bk)
			else:
				bk.global_position = Vector3(7.0, 0.55, 22.0)
		"giant":
			var gw := _WarriorScene.instantiate() as CharacterBody3D
			gw.set_script(_AttackGiantScript)
			add_child(gw)
			if GameState.is_terrain_mission():
				_gw_place_m2(gw)
			else:
				gw.global_position = Vector3(7.0, 0.55, 22.0)


func _refresh_upgrade_buttons() -> void:
	if _dmg_upgrade_button:
		_dmg_upgrade_button.disabled = GameState.coins < GameState.DMG_UPGRADE_COST


func _refresh_market_buttons() -> void:
	for btn in _market_buttons:
		if btn == null:
			continue
		var coin_delta := int(btn.get_meta(&"coin_delta", 0))
		var wood_delta := int(btn.get_meta(&"wood_delta", 0))
		var ore_delta := int(btn.get_meta(&"ore_delta", 0))
		btn.disabled = (
			GameState.coins + coin_delta < 0
			or GameState.wood + wood_delta < 0
			or GameState.ore + ore_delta < 0
		)


func _refresh_build_buttons() -> void:
	if _tower_button:
		_tower_button.disabled    = not GameState.can_afford_build(GameState.BUILD_TOWER)
	if _barracks_button:
		_barracks_button.disabled = not GameState.can_afford_build(GameState.BUILD_BARRACKS)
	if _warehouse_button:
		_warehouse_button.disabled = not GameState.can_afford_build(GameState.BUILD_WAREHOUSE)
	if _skywatch_button:
		_skywatch_button.disabled  = not GameState.can_afford_build(GameState.BUILD_SKYWATCH)
	if _market_building_button:
		_market_building_button.disabled = not GameState.can_afford_build(GameState.BUILD_MARKET)
	if _house_button:
		_house_button.disabled = not GameState.can_build_house()
		if GameState.get_house_count() >= GameState.MAX_HOUSES:
			_house_button.text = "HOUSE\n🏠\nMAX (%d)" % GameState.MAX_HOUSES
		else:
			_house_button.text = "HOUSE\n🏠\n%d coins\n%d wood" % [GameState.HOUSE_COIN_COST, GameState.HOUSE_WOOD_COST]


func _refresh_ore_labels() -> void:
	var o: int = GameState.ore
	if _ore_label:
		_ore_label.text = "Ore: %d" % o
	if _wood_label:
		_wood_label.text = "Wood: %d" % GameState.wood
	_refresh_build_buttons()
	_refresh_market_buttons()
	_refresh_workers_ui()


func _on_ore_changed(_total: int) -> void:
	_refresh_ore_labels()
	_refresh_upgrade_buttons()


func _on_wood_changed(_total: int) -> void:
	_refresh_ore_labels()


func _on_population_changed(current: int, maximum: int) -> void:
	if _pop_label:
		_pop_label.text = "Pop: %d/%d" % [current, maximum]
	_refresh_workers_ui()
	_refresh_attack_buttons()


func _refresh_attack_buttons() -> void:
	# Attack units are not limited by population — gate on coins only.
	if _attack_knight_button:
		_attack_knight_button.disabled = GameState.coins < GameState.ATTACK_KNIGHT_COIN_COST
	if _attack_big_knight_button:
		_attack_big_knight_button.disabled = GameState.coins < GameState.ATTACK_BIG_KNIGHT_COIN_COST
	if _attack_giant_button:
		_attack_giant_button.disabled = GameState.coins < GameState.ATTACK_GIANT_COIN_COST


func _on_base_hp_changed(current: int, maximum: int) -> void:
	_base_hp_label.text = "Base: %d / %d" % [current, maximum]


func _on_coins_changed(total: int) -> void:
	_coin_label.text = "Coins: %d" % total
	if _dmg_upgrade_button:
		_dmg_upgrade_button.disabled = total < GameState.DMG_UPGRADE_COST
	_refresh_attack_buttons()
	_refresh_build_buttons()
	_refresh_upgrade_buttons()
	_refresh_workers_ui()
	_refresh_market_buttons()
	_casino_update_ui()


func _on_commander_mode(active: bool) -> void:
	if active and _build_layer == null:
		_setup_commander_build_ui()
	if _build_layer:
		_build_layer.visible = active
	if not active:
		# Clean up all Commander UI state when leaving Commander Mode
		_close_building_panel()
		GameState.cancel_flag_placement()


func _on_pending_build(pending: bool) -> void:
	var gold := Color(1.0, 0.92, 0.45)
	var white := Color.WHITE
	if not pending:
		for btn in [_tower_button, _barracks_button, _warehouse_button, _skywatch_button, _market_building_button, _house_button]:
			if btn: btn.modulate = white
		return
	var bt := GameState.awaiting_build_type
	if _tower_button:    _tower_button.modulate    = gold if bt == GameState.BUILD_TOWER    else white
	if _barracks_button: _barracks_button.modulate = gold if bt == GameState.BUILD_BARRACKS else white
	if _warehouse_button:_warehouse_button.modulate= gold if bt == GameState.BUILD_WAREHOUSE else white
	if _skywatch_button: _skywatch_button.modulate = gold if bt == GameState.BUILD_SKYWATCH  else white
	if _market_building_button: _market_building_button.modulate = gold if bt == GameState.BUILD_MARKET else white
	if _house_button: _house_button.modulate = gold if bt == GameState.BUILD_HOUSE else white


func _setup_game_over_ui() -> void:
	_game_over_layer = CanvasLayer.new()
	_game_over_layer.name = "GameOverLayer"
	_game_over_layer.layer = 80
	_game_over_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_game_over_layer.visible = false
	add_child(_game_over_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.02, 0.02, 0.05, 0.72)
	_game_over_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "Base destroyed"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_DANGER, 36, 7)
	box.add_child(title)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.custom_minimum_size = Vector2(220, 52)
	_restart_button.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(_restart_button, 22)
	_restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(_restart_button)


func _setup_victory_ui() -> void:
	_win_layer = CanvasLayer.new()
	_win_layer.name = "VictoryLayer"
	_win_layer.layer = 82
	_win_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_win_layer.visible = false
	add_child(_win_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.02, 0.06, 0.12, 0.78)
	_win_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_win_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	var title := Label.new()
	title.text = "YOU WON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_HP, 42, 8)
	box.add_child(title)

	_win_play_again_button = Button.new()
	_win_play_again_button.text = "Play again"
	_win_play_again_button.custom_minimum_size = Vector2(240, 52)
	_win_play_again_button.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(_win_play_again_button, 22)
	_win_play_again_button.pressed.connect(_on_restart_pressed)
	box.add_child(_win_play_again_button)

	_win_exit_button = Button.new()
	_win_exit_button.text = "Exit"
	_win_exit_button.custom_minimum_size = Vector2(240, 52)
	_win_exit_button.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(_win_exit_button, 22)
	_win_exit_button.pressed.connect(_on_victory_exit_pressed)
	box.add_child(_win_exit_button)


func _on_victory_exit_pressed() -> void:
	get_tree().quit()


func _on_base_destroyed() -> void:
	if _game_over_layer == null:
		return
	if _victory_shown:
		return
	close_pause_menu()
	get_tree().paused = true
	_game_over_layer.visible = true
	SoundManager.play_ui(&"game_over")
	if _restart_button:
		_restart_button.grab_focus()


func _try_show_victory() -> void:
	if _victory_shown or GameState.game_over:
		return
	# Mission 3 wins by destroying the enemy base (signal-driven), not by waves.
	if GameState.is_base_assault():
		return
	if _win_layer == null:
		return
	var wm: Node = get_node_or_null("WaveManager")
	if wm == null or not wm.has_method(&"all_waves_spawned"):
		return
	if not (wm.call(&"all_waves_spawned") as bool):
		return
	if get_tree().get_nodes_in_group(&"enemy").size() > 0:
		return
	_show_victory_screen()


## Shows the victory layer (shared by wave-survival completion and Mission 3
## enemy-base destruction).
func _show_victory_screen() -> void:
	if _victory_shown or GameState.game_over:
		return
	if _win_layer == null:
		return
	_victory_shown = true
	close_pause_menu()
	get_tree().paused = true
	_win_layer.visible = true
	SoundManager.play_ui(&"victory")
	if _win_play_again_button:
		_win_play_again_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	if _game_over_layer:
		_game_over_layer.visible = false
	if _win_layer:
		_win_layer.visible = false
	_victory_shown = false
	GameState.reset_run()
	get_tree().reload_current_scene()


func _setup_pause_menu() -> void:
	_pause_menu_layer = CanvasLayer.new()
	_pause_menu_layer.name = "PauseMenuLayer"
	_pause_menu_layer.layer = 65
	_pause_menu_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_pause_menu_layer.visible = false
	add_child(_pause_menu_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0.03, 0.04, 0.07, 0.55)
	_pause_menu_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_MAIN, 28, 5)
	col.add_child(title)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	col.add_child(vol_row)

	var vol_lbl := Label.new()
	vol_lbl.text = "Music"
	UiStyle.style_label(vol_lbl, UiStyle.TEXT_MAIN, 16, 3)
	vol_row.add_child(vol_lbl)

	_music_volume_slider = HSlider.new()
	_music_volume_slider.min_value = 0.0
	_music_volume_slider.max_value = 100.0
	_music_volume_slider.step = 1.0
	_music_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_volume_slider.custom_minimum_size = Vector2(160, 24)
	_music_volume_slider.value_changed.connect(_on_music_volume_slider_changed)
	vol_row.add_child(_music_volume_slider)

	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 10)
	col.add_child(sound_row)

	var sound_lbl := Label.new()
	sound_lbl.text = "Sound"
	UiStyle.style_label(sound_lbl, UiStyle.TEXT_MAIN, 16, 3)
	sound_row.add_child(sound_lbl)

	_sound_volume_slider = HSlider.new()
	_sound_volume_slider.min_value = 0.0
	_sound_volume_slider.max_value = 100.0
	_sound_volume_slider.step = 1.0
	_sound_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_volume_slider.custom_minimum_size = Vector2(160, 24)
	_sound_volume_slider.value_changed.connect(_on_sound_volume_slider_changed)
	sound_row.add_child(_sound_volume_slider)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	col.add_child(res_row)

	var res_lbl := Label.new()
	res_lbl.text = "Resolution"
	UiStyle.style_label(res_lbl, UiStyle.TEXT_MAIN, 16, 3)
	res_row.add_child(res_lbl)

	_resolution_option = OptionButton.new()
	_resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in RESOLUTIONS.size():
		var item: Array = RESOLUTIONS[i]
		var size: Vector2i = item[1]
		_resolution_option.add_item("%s (%dx%d)" % [item[0], size.x, size.y], i)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	res_row.add_child(_resolution_option)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	col.add_child(_fullscreen_check)

	var esc_hint := Label.new()
	esc_hint.text = "Esc - close menu"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(esc_hint, UiStyle.TEXT_MUTED, 13, 2)
	col.add_child(esc_hint)

	var main_menu_btn := Button.new()
	main_menu_btn.text = "Back to Main Menu"
	main_menu_btn.custom_minimum_size = Vector2(0, 44)
	main_menu_btn.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(main_menu_btn, 18)
	main_menu_btn.pressed.connect(_on_pause_main_menu_pressed)
	col.add_child(main_menu_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Exit"
	quit_btn.custom_minimum_size = Vector2(0, 44)
	quit_btn.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(quit_btn, 18)
	quit_btn.pressed.connect(_on_pause_quit_pressed)
	col.add_child(quit_btn)

	var esc_listener := Node.new()
	esc_listener.set_script(_PauseEscListenerScript)
	esc_listener.name = "PauseEscListener"
	_pause_menu_layer.add_child(esc_listener)
	if esc_listener.has_method(&"setup"):
		esc_listener.call(&"setup", self)


func _on_pause_menu_toggle_requested() -> void:
	if GameState.game_over or _victory_shown:
		return
	if GameState.dev_console_open:
		return
	if GameState.commander_active:
		return
	_toggle_pause_menu()


func _toggle_pause_menu() -> void:
	if _pause_menu_open:
		close_pause_menu()
	else:
		open_pause_menu()


func open_pause_menu() -> void:
	if _pause_menu_layer == null or GameState.game_over or _victory_shown:
		return
	_pause_menu_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause_menu_layer.visible = true
	SoundManager.play_ui(&"ui_switch")
	_sync_music_slider_from_player()
	_sync_sound_slider_from_manager()
	_refresh_video_settings()
	if _music_volume_slider:
		_music_volume_slider.grab_focus()


func close_pause_menu() -> void:
	if not _pause_menu_open:
		return
	_pause_menu_open = false
	get_tree().paused = false
	if _pause_menu_layer:
		_pause_menu_layer.visible = false
	SoundManager.play_ui(&"ui_switch")
	if not GameState.commander_active and not GameState.dev_console_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _sync_music_slider_from_player() -> void:
	if _music_volume_slider == null:
		return
	if _bg_music_player == null:
		_music_volume_slider.editable = false
		return
	_music_volume_slider.editable = true
	var lin := db_to_linear(_bg_music_player.volume_db)
	_music_volume_slider.set_value_no_signal(clampf(lin * 100.0, 0.0, 100.0))


func _on_music_volume_slider_changed(value: float) -> void:
	if _bg_music_player == null:
		return
	var v := clampf(value / 100.0, 0.0, 1.0)
	if v <= 0.0001:
		_bg_music_player.volume_db = -80.0
	else:
		_bg_music_player.volume_db = linear_to_db(v)


func _sync_sound_slider_from_manager() -> void:
	if _sound_volume_slider == null:
		return
	_sound_volume_slider.set_value_no_signal(SoundManager.get_sfx_volume_slider_percent())


func _on_sound_volume_slider_changed(value: float) -> void:
	SoundManager.set_sfx_volume_slider_percent(value)


func _refresh_video_settings() -> void:
	var current_size := get_window().size
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i][1] == current_size:
			_resolution_option.select(i)
			break
	_fullscreen_check.set_pressed_no_signal(_is_fullscreen())


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	var was_fullscreen := _is_fullscreen()
	var window := get_window()
	if was_fullscreen:
		window.mode = Window.MODE_WINDOWED
	var size: Vector2i = RESOLUTIONS[index][1]
	window.content_scale_size = size
	window.size = size
	_center_window()
	if was_fullscreen:
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN


func _on_fullscreen_toggled(enabled: bool) -> void:
	var window := get_window()
	if enabled:
		var index := _resolution_option.selected
		if index >= 0 and index < RESOLUTIONS.size():
			var size: Vector2i = RESOLUTIONS[index][1]
			window.content_scale_size = size
			window.size = size
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		_center_window()


func _is_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func _center_window() -> void:
	var window := get_window()
	var screen := window.current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	window.position = screen_pos + (screen_size - window.size) / 2


func _on_pause_quit_pressed() -> void:
	get_tree().quit()


func _on_pause_main_menu_pressed() -> void:
	get_tree().paused = false
	GameState.reset_run()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _setup_dev_console() -> void:
	_dev_console_layer = CanvasLayer.new()
	_dev_console_layer.name = "DevConsole"
	_dev_console_layer.layer = 100
	_dev_console_layer.visible = false
	add_child(_dev_console_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top    = -300.0
	panel.offset_bottom = -8.0
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style(UiStyle.PANEL_BG_SOFT, UiStyle.PANEL_BORDER_DIM, 8, 1))
	_dev_console_layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)

	# ── DEVELOPER TOOLS ──────────────────────────────────────────────────────
	var dev_hdr := Label.new()
	dev_hdr.text = "DEVELOPER ▼"
	UiStyle.style_label(dev_hdr, Color(0.88, 0.60, 0.20), 13, 3)
	col.add_child(dev_hdr)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	col.add_child(row1)

	var btn_enemy := Button.new()
	btn_enemy.text = "Spawn Enemy"; btn_enemy.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_enemy, 13)
	btn_enemy.pressed.connect(func() -> void: _dev_spawn_enemy(0))
	row1.add_child(btn_enemy)

	var btn_golem := Button.new()
	btn_golem.text = "Spawn Golem"; btn_golem.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_golem, 13)
	btn_golem.pressed.connect(func() -> void: _dev_spawn_enemy(3))
	row1.add_child(btn_golem)

	var btn_giant := Button.new()
	btn_giant.text = "Spawn Giant Warrior"; btn_giant.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_giant, 13)
	btn_giant.pressed.connect(_dev_spawn_giant_warrior)
	row1.add_child(btn_giant)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 5)
	col.add_child(row2)

	_dev_inf_res_btn = Button.new()
	_dev_inf_res_btn.text = "Infinite Resources: OFF"
	_dev_inf_res_btn.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(_dev_inf_res_btn, 13)
	_dev_inf_res_btn.pressed.connect(_dev_toggle_infinite_resources)
	row2.add_child(_dev_inf_res_btn)

	_dev_unbreak_btn = Button.new()
	_dev_unbreak_btn.text = "Unbreakable Base: OFF"
	_dev_unbreak_btn.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(_dev_unbreak_btn, 13)
	_dev_unbreak_btn.pressed.connect(_dev_toggle_unbreakable_base)
	row2.add_child(_dev_unbreak_btn)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 5)
	col.add_child(row3)

	var btn_demon := Button.new()
	btn_demon.text = "Spawn Demon"; btn_demon.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_demon, 13)
	btn_demon.pressed.connect(func() -> void: _dev_spawn_enemy(4))
	row3.add_child(btn_demon)

	var btn_boss := Button.new()
	btn_boss.text = "Spawn Boss Minotaur"; btn_boss.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_boss, 13)
	btn_boss.pressed.connect(func() -> void: _dev_spawn_enemy(2))
	row3.add_child(btn_boss)

	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 5)
	col.add_child(row4)

	var btn_bat := Button.new()
	btn_bat.text = "Spawn BAT Pig"; btn_bat.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_bat, 13)
	btn_bat.pressed.connect(func() -> void: _dev_spawn_enemy(5))
	row4.add_child(btn_bat)

	var btn_skip := Button.new()
	btn_skip.text = "Skip Wave"; btn_skip.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(btn_skip, 13)
	btn_skip.pressed.connect(_dev_skip_wave)
	row4.add_child(btn_skip)

	# ── CHAT / CONSOLE ───────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text = "T - open. Money:number  |  Esc - close"
	UiStyle.style_label(hint, UiStyle.TEXT_MUTED, 13, 2)
	col.add_child(hint)

	_dev_line = LineEdit.new()
	_dev_line.placeholder_text = "Money:100"
	_dev_line.focus_mode = Control.FOCUS_ALL
	_dev_line.custom_minimum_size = Vector2(0, 36)
	_dev_line.add_theme_font_size_override("font_size", 16)
	_dev_line.text_submitted.connect(_on_dev_console_submitted)
	col.add_child(_dev_line)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T or event.physical_keycode == KEY_T:
			if GameState.game_over or _victory_shown:
				return
			if _dev_console_layer != null and not _dev_console_layer.visible:
				_open_dev_console()
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _dev_console_layer != null and _dev_console_layer.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_dev_console()
			get_viewport().set_input_as_handled()


func _open_dev_console() -> void:
	if _dev_console_layer == null:
		return
	_dev_console_layer.visible = true
	GameState.dev_console_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_dev_line.grab_focus()


func _close_dev_console() -> void:
	if _dev_console_layer == null or not _dev_console_layer.visible:
		return
	_dev_console_layer.visible = false
	GameState.dev_console_open = false
	_dev_line.release_focus()
	_dev_line.clear()
	if GameState.commander_active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_dev_console_submitted(text: String) -> void:
	var s := text.strip_edges()
	if s.is_empty():
		return
	var low := s.to_lower()
	if low == "wave_skip":
		var wm: Node = get_node_or_null("WaveManager")
		if wm != null and wm.has_method(&"skip_next_pending_wave"):
			wm.call(&"skip_next_pending_wave")
		_dev_line.clear()
		return
	var m := _money_cmd_regex.search(s)
	if m != null:
		var n: int = int(m.get_string(1))
		GameState.add_coins(n)
	_dev_line.clear()


# ─── DEVELOPER TOOLS ──────────────────────────────────────────────────────────

func _dev_get_spawn_pos() -> Vector3:
	var sp := get_tree().get_first_node_in_group(&"enemy_spawn") as Node3D
	if sp != null:
		var xoff := randf_range(-2.0, 2.0)
		var zoff := randf_range(-2.0, 2.0)
		var x    := sp.global_position.x + xoff
		var z    := sp.global_position.z + zoff
		var y    := sp.global_position.y
		if GameState.is_terrain_mission():
			y = _m2_terrain_y(x, z) + 0.55
		return Vector3(x, y, z)
	return Vector3(10.0, 0.55, 50.0)


func _m2_terrain_y(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var q     := PhysicsRayQueryParameters3D.create(
		Vector3(x, 300.0, z), Vector3(x, -50.0, z), 1)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.0


func _dev_spawn_enemy(kind: int) -> void:
	var e := _EnemyScene.instantiate() as CharacterBody3D
	e.call(&"configure", kind)
	add_child(e)
	e.global_position = _dev_get_spawn_pos()


func _dev_spawn_giant_warrior() -> void:
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	add_child(gw)
	if GameState.is_terrain_mission():
		_gw_place_m2(gw)
	else:
		gw.global_position = Vector3(7.0, 0.55, 22.0)
	GameState.has_giant_warrior = true


func _dev_skip_wave() -> void:
	var wm: Node = get_node_or_null("WaveManager")
	if wm != null and wm.has_method(&"skip_next_pending_wave"):
		wm.call(&"skip_next_pending_wave")


func _dev_toggle_infinite_resources() -> void:
	GameState.infinite_resources = not GameState.infinite_resources
	var on := GameState.infinite_resources
	if _dev_inf_res_btn:
		_dev_inf_res_btn.text = "Infinite Resources: %s" % ("ON" if on else "OFF")
	# Refresh all cost buttons
	_on_coins_changed(GameState.coins)
	_refresh_upgrade_buttons()


func _dev_toggle_unbreakable_base() -> void:
	GameState.unbreakable_base = not GameState.unbreakable_base
	var on := GameState.unbreakable_base
	if _dev_unbreak_btn:
		_dev_unbreak_btn.text = "Unbreakable Base: %s" % ("ON" if on else "OFF")


# ─── CASINO ───────────────────────────────────────────────────────────────────

func _build_casino_tab(tabs: TabContainer) -> void:
	var tab := MarginContainer.new()
	tab.name = "Casino"
	tab.add_theme_constant_override("margin_left",   6)
	tab.add_theme_constant_override("margin_top",    4)
	tab.add_theme_constant_override("margin_right",  6)
	tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(tab)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	tab.add_child(col)

	# — Tier buttons row —
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	col.add_child(tier_row)

	var tier_lbl := Label.new()
	tier_lbl.text = "BET:"
	UiStyle.style_label(tier_lbl, UiStyle.TEXT_MAIN, 14, 2)
	tier_row.add_child(tier_lbl)

	_casino_tier_btns.clear()
	var tier_labels := ["1 coin", "5 coins", "10 coins"]
	for i in 3:
		var btn := Button.new()
		btn.text = tier_labels[i]
		btn.custom_minimum_size = Vector2(70, 28)
		btn.focus_mode = Control.FOCUS_NONE
		UiStyle.style_button(btn, 14)
		var idx := i
		btn.pressed.connect(func() -> void:
			_casino_tier = idx
			_casino_update_ui()
			_casino_build_strip_initial()
		)
		tier_row.add_child(btn)
		_casino_tier_btns.append(btn)

	_casino_result_lbl = Label.new()
	_casino_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_casino_result_lbl.text = " "
	UiStyle.style_label(_casino_result_lbl, UiStyle.TEXT_HP, 13, 2)
	col.add_child(_casino_result_lbl)

	# — Strip (clipped) —
	var clip := Control.new()
	clip.custom_minimum_size   = Vector2(_CASINO_STRIDE * _CASINO_VIS, _CASINO_ITEM_H + 20)
	clip.clip_contents         = true
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	col.add_child(clip)
	_casino_clip = clip

	var arrow := Label.new()
	arrow.text = "▼"
	arrow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	arrow.offset_top    = 0.0
	arrow.offset_bottom = 18.0
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(arrow, Color.WHITE, 14, 3)
	clip.add_child(arrow)

	_casino_strip_row = HBoxContainer.new()
	_casino_strip_row.add_theme_constant_override("separation", _CASINO_SEP)
	_casino_strip_row.position = Vector2(0.0, 18.0)
	clip.add_child(_casino_strip_row)

	# — Roll button —
	_casino_roll_btn = Button.new()
	_casino_roll_btn.text                = "ROLL"
	_casino_roll_btn.custom_minimum_size = Vector2(160, 40)
	_casino_roll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_casino_roll_btn.focus_mode          = Control.FOCUS_NONE
	UiStyle.style_button(_casino_roll_btn, 20)
	_casino_roll_btn.pressed.connect(_on_casino_roll_pressed)
	col.add_child(_casino_roll_btn)

	_casino_update_ui()
	_casino_build_strip_initial()


func _casino_update_ui() -> void:
	if _casino_roll_btn == null:
		return
	var bet := _CASINO_TIER_COSTS[_casino_tier]
	_casino_roll_btn.disabled = _casino_rolling or GameState.coins < bet
	for i in _casino_tier_btns.size():
		var btn: Button = _casino_tier_btns[i]
		if i == _casino_tier:
			var sbox := StyleBoxFlat.new()
			sbox.bg_color = Color(0.70, 0.55, 0.08)
			sbox.border_color = Color(1.0, 0.88, 0.30)
			sbox.set_border_width_all(2)
			sbox.set_corner_radius_all(4)
			sbox.content_margin_left = 6; sbox.content_margin_right = 6
			sbox.content_margin_top = 4;  sbox.content_margin_bottom = 4
			btn.add_theme_stylebox_override(&"normal", sbox)
			btn.add_theme_stylebox_override(&"hover",  sbox)
		else:
			btn.remove_theme_stylebox_override(&"normal")
			btn.remove_theme_stylebox_override(&"hover")


func _on_casino_roll_pressed() -> void:
	var bet := _CASINO_TIER_COSTS[_casino_tier]
	if _casino_rolling or GameState.coins < bet:
		return
	if not GameState.spend_coins(bet):
		return
	_casino_rolling = true
	_casino_roll_btn.disabled = true
	_casino_result_lbl.text = "Rolling..."
	var reward: Dictionary = _casino_pick_reward(_casino_tier)
	_casino_build_strip(reward)
	_casino_animate(reward)


func _casino_pick_reward(tier: int) -> Dictionary:
	var pool: Array = _CASINO_POOLS[tier]
	var total := 0.0
	for r in pool:
		total += float(r["weight"])
	var roll := randf() * total
	var acc  := 0.0
	for r in pool:
		acc += float(r["weight"])
		if roll < acc:
			return r
	return pool[0]


func _casino_build_strip_initial() -> void:
	if _casino_strip_row == null:
		return
	for c in _casino_strip_row.get_children():
		_casino_strip_row.remove_child(c)
		c.free()
	_casino_strip_row.position.x = 0.0
	var pool: Array = _CASINO_POOLS[_casino_tier]
	for _i in _CASINO_TOTAL:
		_casino_strip_row.add_child(_casino_make_item(pool[randi() % pool.size()]))


func _casino_build_strip(final: Dictionary) -> void:
	for c in _casino_strip_row.get_children():
		_casino_strip_row.remove_child(c)
		c.free()
	_casino_strip_row.position.x = 0.0
	var pool: Array = _CASINO_POOLS[_casino_tier]
	for i in _CASINO_TOTAL:
		if i == _CASINO_FIN_IDX:
			_casino_strip_row.add_child(_casino_make_item(final))
		else:
			_casino_strip_row.add_child(_casino_make_item(pool[randi() % pool.size()]))


func _casino_make_item(r: Dictionary) -> Control:
	var id: String = r.get("id", "")
	var bg_col:  Color = _CASINO_BG.get(id, Color(0.38, 0.30, 0.05))
	var txt_col: Color = _CASINO_TXT.get(id, Color(0.95, 0.85, 0.30))
	var brd_col := Color(0.30, 0.28, 0.25)

	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(_CASINO_ITEM_W, _CASINO_ITEM_H)
	c.add_theme_stylebox_override(&"panel",
		UiStyle.panel_style(bg_col, brd_col, 4, 1))

	var lbl := Label.new()
	lbl.text                  = r["label"]
	lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_label(lbl, txt_col, 11, 2)
	c.add_child(lbl)
	return c


func _casino_animate(reward: Dictionary) -> void:
	await get_tree().process_frame  # Wait for layout so clip.size is correct
	var center_x := _casino_clip.size.x * 0.5
	if center_x < 1.0:
		center_x = float(_CASINO_STRIDE * _CASINO_VIS) * 0.5
	var end_x := center_x - _CASINO_FIN_IDX * float(_CASINO_STRIDE) - _CASINO_ITEM_W * 0.5
	end_x += randf_range(-4.0, 4.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_casino_strip_row, "position:x", end_x, 3.5)
	tw.tween_callback(func() -> void: _casino_finish(reward))


func _casino_finish(reward: Dictionary) -> void:
	_casino_rolling = false
	_casino_grant(reward)
	match reward.get("id", ""):
		"empty":        _casino_result_lbl.text = "No Reward."
		"enemy_attack": _casino_result_lbl.text = "INCOMING ATTACK!"
		"bld_upgrade":  pass  # текст ставит _casino_grant_building_upgrade
		_:              _casino_result_lbl.text = "Won: %s!" % (reward["label"] as String).replace("\n", " ")
	_casino_update_ui()


func _casino_grant(reward: Dictionary) -> void:
	match reward.get("id", ""):
		"coin1":        GameState.add_coins(1)
		"coin3":        GameState.add_coins(3)
		"coin5":        GameState.add_coins(5)
		"coin8":        GameState.add_coins(8)
		"coin10":       GameState.add_coins(10)
		"coin15":       GameState.add_coins(15)
		"coin20":       GameState.add_coins(20)
		"coin35":       GameState.add_coins(35)
		"coin50":       GameState.add_coins(50)
		"coin100":      GameState.add_coins(100)
		"ore100":       GameState.add_ore(100)
		"ore200":       GameState.add_ore(200)
		"wood50":       GameState.add_wood(50)
		"wood100":      GameState.add_wood(100)
		"wood200":      GameState.add_wood(200)
		"free_knight":  _casino_spawn_free_knight()
		"giant":        _casino_try_spawn_giant()
		"enemy_attack": _casino_spawn_enemy_attack()
		"bld_upgrade":  _casino_grant_building_upgrade()
		# "empty": nothing


func _casino_grant_building_upgrade() -> void:
	if GameState.grant_random_building_upgrade():
		_casino_result_lbl.text = "Building upgraded!"
	else:
		GameState.add_coins(50)
		_casino_result_lbl.text = "Nothing to upgrade! +50 Coins."


func _casino_spawn_free_knight() -> void:
	var k := _WarriorScene.instantiate() as CharacterBody3D
	k.set_script(_AttackKnightScript)
	add_child(k)
	if GameState.is_terrain_mission():
		_gw_place_m2(k)
	else:
		k.global_position = Vector3(7.0, 0.55, 22.0)


func _casino_spawn_enemy_attack() -> void:
	var wm: Node = get_node_or_null("WaveManager")
	if wm != null and wm.has_method(&"spawn_extra"):
		wm.call(&"spawn_extra", 5)


func _casino_try_spawn_giant() -> void:
	if GameState.has_giant_warrior:
		GameState.add_coins(50)
		_casino_result_lbl.text = "Giant exists! +50 Coins."
		return
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	add_child(gw)
	if GameState.is_terrain_mission():
		_gw_place_m2(gw)
	else:
		gw.global_position = Vector3(7.0, 0.55, 22.0)
	GameState.has_giant_warrior = true


# ─── BUILDING UPGRADE PANEL ───────────────────────────────────────────────────

func _setup_building_panel() -> void:
	_bld_panel_layer = CanvasLayer.new()
	_bld_panel_layer.name    = "BuildingPanel"
	_bld_panel_layer.layer   = 50
	_bld_panel_layer.visible = false
	add_child(_bld_panel_layer)

	# Absolute positioning — anchors all at 0 (top-left), position set dynamically
	_bld_panel_container = PanelContainer.new()
	_bld_panel_container.anchor_left   = 0.0
	_bld_panel_container.anchor_right  = 0.0
	_bld_panel_container.anchor_top    = 0.0
	_bld_panel_container.anchor_bottom = 0.0
	_bld_panel_container.custom_minimum_size = Vector2(260, 0)
	_bld_panel_container.mouse_filter  = Control.MOUSE_FILTER_STOP
	_bld_panel_container.add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	_bld_panel_layer.add_child(_bld_panel_container)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_bld_panel_container.add_child(col)

	_bld_title_lbl = Label.new()
	_bld_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(_bld_title_lbl, UiStyle.TEXT_MAIN, 16, 3)
	col.add_child(_bld_title_lbl)

	_bld_upgrade_btn = Button.new()
	_bld_upgrade_btn.focus_mode = Control.FOCUS_NONE
	_bld_upgrade_btn.custom_minimum_size = Vector2(230, 44)
	UiStyle.style_button(_bld_upgrade_btn, 14)
	_bld_upgrade_btn.pressed.connect(_on_bld_upgrade_pressed)
	col.add_child(_bld_upgrade_btn)

	_bld_magic_btn = Button.new()
	_bld_magic_btn.focus_mode = Control.FOCUS_NONE
	_bld_magic_btn.custom_minimum_size = Vector2(230, 44)
	UiStyle.style_button(_bld_magic_btn, 14)
	_bld_magic_btn.visible = false
	_bld_magic_btn.pressed.connect(_on_bld_magic_btn_pressed)
	col.add_child(_bld_magic_btn)

	_bld_flag_btn = Button.new()
	_bld_flag_btn.text = "🚩 Set Rally Flag"
	_bld_flag_btn.focus_mode = Control.FOCUS_NONE
	_bld_flag_btn.custom_minimum_size = Vector2(230, 44)
	UiStyle.style_button(_bld_flag_btn, 14)
	_bld_flag_btn.pressed.connect(_on_bld_flag_pressed)
	col.add_child(_bld_flag_btn)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(close_btn, 13)
	close_btn.pressed.connect(_close_building_panel)
	col.add_child(close_btn)

	_create_selection_ring()


func _open_building_panel(building: Node3D) -> void:
	if not is_instance_valid(building): return
	if _bld_panel_layer == null: return
	var was_open := _bld_selected != null
	_bld_selected = building
	_bld_panel_layer.visible = true
	_refresh_building_panel()
	_position_building_panel(building)
	_show_selection_ring(building)
	if not was_open:
		SoundManager.play_ui(&"ui_switch")


func _close_building_panel() -> void:
	var was_open := _bld_panel_layer != null and _bld_panel_layer.visible
	if _bld_panel_layer != null: _bld_panel_layer.visible = false
	_bld_selected = null
	_hide_selection_ring()
	if was_open:
		SoundManager.play_ui(&"ui_switch")


func _position_building_panel(building: Node3D) -> void:
	if _bld_panel_container == null: return
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(cam): return

	# Project building position (+2u up to hit visible center) to screen coords
	var screen_pos := cam.unproject_position(building.global_position + Vector3(0.0, 2.0, 0.0))
	var vp         := get_viewport().get_visible_rect().size
	const PANEL_W  := 280.0
	const PANEL_H  := 180.0   # estimated; PanelContainer auto-grows
	const MARGIN   := 12.0
	const BOT_UI   := 250.0   # height of bottom commander build panel

	# Try right of building; fall back to left if it clips the screen edge
	var x := screen_pos.x + 50.0
	if x + PANEL_W > vp.x - MARGIN:
		x = screen_pos.x - PANEL_W - 50.0

	# Vertically centered on building, clamped above bottom UI
	var y := screen_pos.y - PANEL_H * 0.5
	y = clampf(y, MARGIN, vp.y - BOT_UI - PANEL_H - MARGIN)

	# Final horizontal clamp
	x = clampf(x, MARGIN, vp.x - PANEL_W - MARGIN)

	_bld_panel_container.position = Vector2(x, y)


func _refresh_building_panel() -> void:
	if _bld_panel_layer == null or not _bld_panel_layer.visible: return
	if not is_instance_valid(_bld_selected): _close_building_panel(); return

	var lvl: int   = int(_bld_selected.get(&"upgrade_level") if _bld_selected.get(&"upgrade_level") != null else 1)
	var is_tower   := _bld_selected.is_in_group(&"tower")
	var is_market  := _bld_selected.is_in_group(&"market_building")

	if _bld_magic_btn != null:
		_bld_magic_btn.visible = false

	if is_tower:
		var is_skywatch := _bld_selected.is_in_group(&"skywatch_tower")
		var t_type := int(_bld_selected.get(&"tower_type") if _bld_selected.get(&"tower_type") != null else 0)
		var type_str := "Magic" if t_type == 1 else "Physical"
		_bld_title_lbl.text = ("Skywatch" if is_skywatch else "Tower  L%d  (%s)" % [lvl, type_str])
		if _bld_flag_btn != null:
			_bld_flag_btn.visible = false

		if is_skywatch:
			_bld_upgrade_btn.text     = "⬆ No upgrades available"
			_bld_upgrade_btn.disabled = true
		elif t_type == 0:  # physical path
			if lvl >= 3:
				_bld_upgrade_btn.text     = "⬆ Max Level (Physical)"
				_bld_upgrade_btn.disabled = true
			else:
				var cc := GameState.TOWER_PHYS_COIN_COSTS[lvl]
				var oc := GameState.TOWER_PHYS_ORE_COSTS[lvl]
				_bld_upgrade_btn.text     = "⬆ Phys L%d → L%d  (%dc / %do)" % [lvl, lvl+1, cc, oc]
				_bld_upgrade_btn.disabled = not GameState.can_afford_tower_phys_upgrade(_bld_selected)
			if lvl == 1 and _bld_magic_btn != null:
				_bld_magic_btn.visible   = true
				_bld_magic_btn.text      = "✨ → Magic L1  (%dc / %do)" % [GameState.TOWER_CONV_COIN, GameState.TOWER_CONV_ORE]
				_bld_magic_btn.disabled  = not GameState.can_afford_tower_convert(_bld_selected)
		else:  # magic path
			if lvl >= 3:
				_bld_upgrade_btn.text     = "✨ Max Level (Magic)"
				_bld_upgrade_btn.disabled = true
			else:
				var cc := GameState.TOWER_MAGIC_COIN_COSTS[lvl]
				var oc := GameState.TOWER_MAGIC_ORE_COSTS[lvl]
				_bld_upgrade_btn.text     = "✨ Magic L%d → L%d  (%dc / %do)" % [lvl, lvl+1, cc, oc]
				_bld_upgrade_btn.disabled = not GameState.can_afford_tower_magic_upgrade(_bld_selected)
	else:
		var type_str := "Market" if is_market else "Barracks"
		_bld_title_lbl.text = "%s  (Level %d / 3)" % [type_str, lvl]
		if _bld_flag_btn != null:
			_bld_flag_btn.visible = not is_market
			if _bld_flag_btn.visible:
				var placing := GameState.flag_placement_mode and \
					GameState.flag_placement_barracks == _bld_selected
				_bld_flag_btn.text     = "🚩 Placing… (click to set)" if placing else "🚩 Set Rally Flag"
				_bld_flag_btn.disabled = placing
		if lvl >= 3:
			_bld_upgrade_btn.text     = "⬆ Max Level"
			_bld_upgrade_btn.disabled = true
		elif is_market:
			var mc := GameState.MARKET_UPGRADE_COIN_COSTS[lvl]
			var mw := GameState.MARKET_UPGRADE_WOOD_COSTS[lvl]
			var mo := GameState.MARKET_UPGRADE_ORE_COSTS[lvl]
			_bld_upgrade_btn.text     = "⬆ Lv%d → Lv%d  (%dc / %dw / %do)" % [lvl, lvl+1, mc, mw, mo]
			_bld_upgrade_btn.disabled = not GameState.can_afford_building_upgrade(_bld_selected)
		else:
			var cc := GameState.BUILDING_UPGRADE_COIN_COSTS[lvl]
			var oc := GameState.BUILDING_UPGRADE_ORE_COSTS[lvl]
			_bld_upgrade_btn.text     = "⬆ Lv%d → Lv%d  (%dc / %do)" % [lvl, lvl+1, cc, oc]
			_bld_upgrade_btn.disabled = not GameState.can_afford_building_upgrade(_bld_selected)


func _create_selection_ring() -> void:
	_selection_ring = Node3D.new()
	_selection_ring.name    = "SelectionRing"
	_selection_ring.visible = false
	add_child(_selection_ring)

	# Glowing flat disc as ground ring — outer edge visible around building base
	var mi  := MeshInstance3D.new()
	var cm  := CylinderMesh.new()
	cm.top_radius    = 5.0
	cm.bottom_radius = 5.0
	cm.height        = 0.08
	cm.radial_segments = 32
	mi.mesh  = cm
	mi.position.y = 0.05
	mi.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color             = Color(1.0, 0.88, 0.15, 0.65)
	mat.transparency             = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled         = true
	mat.emission                 = Color(1.0, 0.90, 0.25)
	mat.emission_energy_multiplier = 1.8
	mat.cull_mode                = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode          = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	mi.set_surface_override_material(0, mat)
	_selection_ring.add_child(mi)


func _show_selection_ring(building: Node3D) -> void:
	if _selection_ring == null or not is_instance_valid(building): return
	_selection_ring.global_position = building.global_position
	_selection_ring.visible         = true


func _hide_selection_ring() -> void:
	if _selection_ring != null: _selection_ring.visible = false


func _on_bld_upgrade_pressed() -> void:
	if not is_instance_valid(_bld_selected): return
	if _bld_selected.is_in_group(&"tower"):
		var t_type := int(_bld_selected.get(&"tower_type") if _bld_selected.get(&"tower_type") != null else 0)
		if t_type == 0:
			GameState.buy_tower_phys_upgrade(_bld_selected)
		else:
			GameState.buy_tower_magic_upgrade(_bld_selected)
	else:
		GameState.buy_building_upgrade(_bld_selected)
	_refresh_building_panel()


func _on_bld_magic_btn_pressed() -> void:
	if not is_instance_valid(_bld_selected): return
	GameState.buy_tower_convert_to_magic(_bld_selected)
	_refresh_building_panel()


func _on_bld_flag_pressed() -> void:
	if not is_instance_valid(_bld_selected): return
	GameState.begin_flag_placement(_bld_selected)
	# Panel stays open — _refresh_building_panel via flag_placement_changed signal


func _on_bld_coins_changed(_n: int = 0) -> void:
	_refresh_building_panel()
