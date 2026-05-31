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

const _CASINO_REWARDS := [
	{"id": "coin1",        "label": "1\nCoin",    "weight": 35.0},
	{"id": "coin5",        "label": "5\nCoins",   "weight": 25.0},
	{"id": "coin10",       "label": "10\nCoins",  "weight": 15.0},
	{"id": "coin20",       "label": "20\nCoins",  "weight": 7.0},
	{"id": "ore200",       "label": "200\nOre",   "weight": 5.0},
	{"id": "wood200",      "label": "200\nWood",  "weight": 5.0},
	{"id": "coin100",      "label": "100\nCoins", "weight": 2.0},
	{"id": "empty",        "label": "Empty",      "weight": 25.0},
	{"id": "enemy_attack", "label": "ATTACK!",    "weight": 3.0},
]
# Giant jackpot — separate from loot table, index = _CASINO_REWARDS.size() = 9
const _CASINO_GIANT := {"id": "giant", "label": "GIANT\nWARRIOR"}
# Jackpot curve: [bet, chance] — linear interpolation between points, capped at last
const _CASINO_JP_CURVE := [
	[1,   0.0001], [5,   0.0003], [10,  0.0008],
	[25,  0.002],  [50,  0.01],   [100, 0.03], [250, 0.05],
]
# BG colors: indices 0-8 = REWARDS, index 9 = giant
const _CASINO_BG := [
	Color(0.35, 0.30, 0.08), Color(0.40, 0.34, 0.09), Color(0.45, 0.38, 0.10),
	Color(0.55, 0.46, 0.00), Color(0.04, 0.22, 0.38), Color(0.25, 0.12, 0.02),
	Color(0.45, 0.20, 0.00), Color(0.10, 0.10, 0.10), Color(0.30, 0.04, 0.04),
	Color(0.22, 0.00, 0.38),
]
const _CASINO_TXT := [
	Color(0.95, 0.85, 0.30), Color(0.95, 0.85, 0.30), Color(0.95, 0.85, 0.30),
	Color(1.00, 0.95, 0.30), Color(0.40, 0.90, 1.00), Color(0.75, 0.48, 0.15),
	Color(1.00, 0.58, 0.10), Color(0.38, 0.38, 0.38), Color(1.00, 0.22, 0.18),
	Color(0.88, 0.45, 1.00),
]
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
var _tower_button: Button
var _barracks_button: Button
var _warehouse_button: Button
var _dmg_upgrade_button: Button
var _bld_panel_layer:      CanvasLayer
var _bld_panel_container:  PanelContainer
var _bld_selected:         Node3D = null
var _bld_title_lbl:        Label
var _bld_upgrade_btn:      Button
var _selection_ring:       Node3D = null
var _wood_label: Label
var _market_buttons: Array[Button] = []
var _buy_worker_button: Button
var _buy_woodcutter_button: Button
var _worker_timer_label: Label

var _worker_spawn_pending := false
var _worker_spawn_time_left := 0.0
var _pending_worker_role := "miner"

var _casino_bet_slider: HSlider
var _casino_bet_label:  Label
var _casino_mult_label: Label
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
	GameState.base_hp_changed.connect(_on_base_hp_changed)
	GameState.commander_mode_changed.connect(_on_commander_mode)
	GameState.pending_build_changed.connect(_on_pending_build)
	GameState.building_levels_changed.connect(_refresh_upgrade_buttons)
	GameState.building_selected.connect(_open_building_panel)
	GameState.coins_changed.connect(_on_bld_coins_changed)
	GameState.ore_changed.connect(_on_bld_coins_changed)
	_on_coins_changed(GameState.coins)
	_refresh_ore_labels()
	_on_base_hp_changed(GameState.base_hp, GameState.BASE_MAX_HP)
	_setup_wave_timer_ui()
	call_deferred(&"_spawn_secret_chest_random")
	if GameState.has_giant_warrior:
		call_deferred(&"_spawn_saved_giant_warrior")


func _spawn_saved_giant_warrior() -> void:
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	add_child(gw)
	gw.global_position = Vector3(8.0, 0.0, 3.0)


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
	_base_hp_label.offset_left = 18.0
	_base_hp_label.offset_top = 56.0
	_base_hp_label.offset_right = 350.0
	_base_hp_label.offset_bottom = 80.0

	UiStyle.style_label(_coin_label, UiStyle.TEXT_COIN, 16, 3)
	UiStyle.style_label(_ore_label, UiStyle.TEXT_ORE, 16, 3)
	UiStyle.style_label(_wood_label, Color(0.72, 0.42, 0.16), 16, 3)
	UiStyle.style_label(_base_hp_label, UiStyle.TEXT_HP, 15, 3)


func _randomize_map_resources() -> void:
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
	if _worker_spawn_pending:
		_worker_spawn_time_left -= delta
		_refresh_workers_ui()
		if _worker_spawn_time_left <= 0.0:
			_worker_spawn_pending = false
			_spawn_worker(_pending_worker_role)
			_refresh_workers_ui()
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

	_update_wave_countdown_label()


func _update_wave_countdown_label() -> void:
	if _wave_countdown_label == null:
		return
	var wm: Node = get_node_or_null("WaveManager")
	if wm == null or not wm.has_method(&"get_wave_timer_hud_text"):
		return
	_wave_countdown_label.text = wm.call(&"get_wave_timer_hud_text") as String


func _spawn_worker(role: String = "miner") -> void:
	var inst: Node = _WorkerScene.instantiate()
	if inst.has_method(&"setup"):
		inst.call(&"setup", _ore_deposit.global_position, role)
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

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.mouse_filter = Control.MOUSE_FILTER_STOP
	tabs.focus_mode = Control.FOCUS_NONE
	bar.add_child(tabs)

	var build_tab := MarginContainer.new()
	build_tab.name = "Build"
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

	_warehouse_button = Button.new()
	_warehouse_button.focus_mode = Control.FOCUS_NONE
	_warehouse_button.custom_minimum_size = Vector2(118, 96)
	_warehouse_button.text = "WAREHOUSE\n📦\n%d ore\n%d wood" % [GameState.WAREHOUSE_ORE_COST, GameState.WAREHOUSE_WOOD_COST]
	_warehouse_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_button(_warehouse_button, 13)
	_warehouse_button.tooltip_text = "Workers unload at the nearest warehouse or base; storage is shared."
	_warehouse_button.pressed.connect(_on_warehouse_button_pressed)
	row_build.add_child(_warehouse_button)

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

	var market_scroll := ScrollContainer.new()
	market_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	market_tab.add_child(market_scroll)

	var market_col := VBoxContainer.new()
	market_col.add_theme_constant_override("separation", 8)
	market_scroll.add_child(market_col)
	_add_market_button(market_col, "1 coin -> 5 wood", -1, 5, 0)
	_add_market_button(market_col, "10 coins -> 50 wood", -10, 50, 0)
	_add_market_button(market_col, "10 wood -> 1 coin", 1, -10, 0)
	_add_market_button(market_col, "50 wood -> 5 coins", 5, -50, 0)
	_add_market_button(market_col, "1 coin -> 50 ore", -1, 0, 50)
	_add_market_button(market_col, "10 coins -> 500 ore", -10, 0, 500)
	_add_market_button(market_col, "100 ore -> 1 coin", 1, 0, -100)
	_add_market_button(market_col, "500 ore -> 5 coins", 5, 0, -500)

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

	_worker_timer_label = Label.new()
	_worker_timer_label.text = "No worker order"
	UiStyle.style_label(_worker_timer_label, UiStyle.TEXT_MUTED, 16, 3)
	workers_col.add_child(_worker_timer_label)

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

	bar.offset_top = -240.0
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


func _on_dmg_upgrade_pressed() -> void:
	GameState.buy_dmg_upgrade()
	_refresh_upgrade_buttons()




func _add_market_button(parent: Node, text: String, coin_delta: int, wood_delta: int, ore_delta: int) -> void:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 38)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiStyle.style_button(btn, 16)
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
	_start_worker_order("miner")


func _on_buy_woodcutter_pressed() -> void:
	_start_worker_order("woodcutter")


func _start_worker_order(role: String) -> void:
	if _worker_spawn_pending:
		return
	if GameState.coins < GameState.WORKER_COST:
		return
	if not GameState.spend_coins(GameState.WORKER_COST):
		return
	_pending_worker_role = role
	_worker_spawn_pending = true
	_worker_spawn_time_left = 5.0
	_refresh_workers_ui()


func _refresh_workers_ui() -> void:
	if _buy_worker_button == null or _worker_timer_label == null:
		return
	_buy_worker_button.text = "Miner\n%d coins" % GameState.WORKER_COST
	if _buy_woodcutter_button:
		_buy_woodcutter_button.text = "Woodcutter\n%d coins" % GameState.WORKER_COST
	if _worker_spawn_pending:
		_worker_timer_label.text = "Spawning %s: %.1f s" % [_pending_worker_role, maxf(_worker_spawn_time_left, 0.0)]
		_buy_worker_button.disabled = true
		if _buy_woodcutter_button:
			_buy_woodcutter_button.disabled = true
	else:
		_worker_timer_label.text = "No worker order"
		_buy_worker_button.disabled = GameState.coins < GameState.WORKER_COST
		if _buy_woodcutter_button:
			_buy_woodcutter_button.disabled = GameState.coins < GameState.WORKER_COST


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
		_tower_button.disabled = not GameState.can_afford_build(GameState.BUILD_TOWER)
	if _barracks_button:
		_barracks_button.disabled = not GameState.can_afford_build(GameState.BUILD_BARRACKS)
	if _warehouse_button:
		_warehouse_button.disabled = not GameState.can_afford_build(GameState.BUILD_WAREHOUSE)


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


func _on_base_hp_changed(current: int, maximum: int) -> void:
	_base_hp_label.text = "Base: %d / %d" % [current, maximum]


func _on_coins_changed(total: int) -> void:
	_coin_label.text = "Coins: %d" % total
	if _dmg_upgrade_button:
		_dmg_upgrade_button.disabled = total < GameState.DMG_UPGRADE_COST
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


func _on_pending_build(pending: bool) -> void:
	var gold := Color(1.0, 0.92, 0.45)
	var white := Color.WHITE
	if not pending:
		if _tower_button:
			_tower_button.modulate = white
		if _barracks_button:
			_barracks_button.modulate = white
		if _warehouse_button:
			_warehouse_button.modulate = white
		return
	if _tower_button:
		_tower_button.modulate = gold if GameState.awaiting_build_type == GameState.BUILD_TOWER else white
	if _barracks_button:
		_barracks_button.modulate = gold if GameState.awaiting_build_type == GameState.BUILD_BARRACKS else white
	if _warehouse_button:
		_warehouse_button.modulate = gold if GameState.awaiting_build_type == GameState.BUILD_WAREHOUSE else white


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
	if _restart_button:
		_restart_button.grab_focus()


func _try_show_victory() -> void:
	if _victory_shown or GameState.game_over:
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
	_victory_shown = true
	close_pause_menu()
	get_tree().paused = true
	_win_layer.visible = true
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
	panel.offset_top    = -260.0
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

	# ── CHAT / CONSOLE ───────────────────────────────────────────────────────
	var hint := Label.new()
	hint.text = "T - open. Money:number  |  wave_skip - next wave  |  Esc - close"
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
		return sp.global_position + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	return Vector3(10.0, 0.55, 50.0)


func _dev_spawn_enemy(kind: int) -> void:
	var e := _EnemyScene.instantiate() as CharacterBody3D
	e.call(&"configure", kind)
	add_child(e)
	e.global_position = _dev_get_spawn_pos()


func _dev_spawn_giant_warrior() -> void:
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	add_child(gw)
	gw.global_position = _dev_get_spawn_pos()
	GameState.has_giant_warrior = true


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

	# — Bet row —
	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 6)
	col.add_child(bet_row)

	var bet_lbl := Label.new()
	bet_lbl.text = "BET:"
	UiStyle.style_label(bet_lbl, UiStyle.TEXT_MAIN, 14, 2)
	bet_row.add_child(bet_lbl)

	_casino_bet_slider = HSlider.new()
	_casino_bet_slider.min_value             = 1.0
	_casino_bet_slider.max_value             = float(maxi(1, GameState.coins))
	_casino_bet_slider.step                  = 1.0
	_casino_bet_slider.value                 = 1.0
	_casino_bet_slider.custom_minimum_size   = Vector2(140, 24)
	_casino_bet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_casino_bet_slider.focus_mode            = Control.FOCUS_NONE
	_casino_bet_slider.value_changed.connect(_on_casino_bet_changed)
	# Visible track styling
	var sl_bg := StyleBoxFlat.new()
	sl_bg.bg_color = Color(0.18, 0.16, 0.12)
	sl_bg.set_corner_radius_all(3)
	sl_bg.content_margin_top    = 8.0
	sl_bg.content_margin_bottom = 8.0
	_casino_bet_slider.add_theme_stylebox_override(&"slider", sl_bg)
	var sl_fill := StyleBoxFlat.new()
	sl_fill.bg_color = Color(0.75, 0.60, 0.10)
	sl_fill.set_corner_radius_all(3)
	sl_fill.content_margin_top    = 8.0
	sl_fill.content_margin_bottom = 8.0
	_casino_bet_slider.add_theme_stylebox_override(&"grabber_area", sl_fill)
	_casino_bet_slider.add_theme_constant_override(&"grabber_offset", 0)
	bet_row.add_child(_casino_bet_slider)

	_casino_bet_label = Label.new()
	_casino_bet_label.custom_minimum_size = Vector2(80, 0)
	UiStyle.style_label(_casino_bet_label, UiStyle.TEXT_COIN, 14, 2)
	bet_row.add_child(_casino_bet_label)

	_casino_mult_label = Label.new()
	UiStyle.style_label(_casino_mult_label, Color(0.80, 0.50, 1.0), 13, 2)
	col.add_child(_casino_mult_label)

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


func _on_casino_bet_changed(_v: float) -> void:
	_casino_update_ui()


func _casino_update_ui() -> void:
	if _casino_bet_slider == null:
		return
	_casino_bet_slider.max_value = float(maxi(1, GameState.coins))
	_casino_bet_slider.value = clampf(_casino_bet_slider.value, 1.0, float(maxi(1, GameState.coins)))
	var bet := int(_casino_bet_slider.value)
	if _casino_bet_label:
		_casino_bet_label.text = "%d / %d coins" % [bet, GameState.coins]
	if _casino_mult_label:
		_casino_mult_label.text = "Giant: %.2f%%" % (_casino_jackpot_chance(bet) * 100.0)
	if _casino_roll_btn:
		_casino_roll_btn.disabled = _casino_rolling or GameState.coins < bet


func _on_casino_roll_pressed() -> void:
	var bet := int(_casino_bet_slider.value)
	if _casino_rolling or GameState.coins < bet:
		return
	if not GameState.spend_coins(bet):
		return
	_casino_rolling = true
	_casino_roll_btn.disabled = true
	_casino_result_lbl.text = "Rolling..."
	var reward: Dictionary = _casino_pick_reward(bet)
	_casino_build_strip(reward)
	_casino_animate(reward)


func _casino_jackpot_chance(bet: int) -> float:
	var b := float(bet)
	if b <= _CASINO_JP_CURVE[0][0]:
		return _CASINO_JP_CURVE[0][1]
	if b >= _CASINO_JP_CURVE[-1][0]:
		return _CASINO_JP_CURVE[-1][1]
	for i in range(_CASINO_JP_CURVE.size() - 1):
		var lo: Array = _CASINO_JP_CURVE[i]
		var hi: Array = _CASINO_JP_CURVE[i + 1]
		if b >= float(lo[0]) and b < float(hi[0]):
			var t := (b - float(lo[0])) / (float(hi[0]) - float(lo[0]))
			return lerpf(float(lo[1]), float(hi[1]), t)
	return _CASINO_JP_CURVE[-1][1]


func _casino_pick_reward(bet: int) -> Dictionary:
	# Giant jackpot roll first
	var jp := _casino_jackpot_chance(bet)
	if jp > 0.0 and randf() < jp:
		return _CASINO_GIANT
	# Static weighted roll
	var total := 0.0
	for r in _CASINO_REWARDS:
		total += float(r["weight"])
	var roll := randf() * total
	var acc  := 0.0
	for r in _CASINO_REWARDS:
		acc += float(r["weight"])
		if roll < acc:
			return r
	return _CASINO_REWARDS[0]


func _casino_build_strip(final: Dictionary) -> void:
	for c in _casino_strip_row.get_children():
		_casino_strip_row.remove_child(c)
		c.free()
	_casino_strip_row.position.x = 0.0
	var fin_idx := _CASINO_REWARDS.size() if final.get("id","") == "giant" else _CASINO_REWARDS.find(final)
	for i in _CASINO_TOTAL:
		if i == _CASINO_FIN_IDX:
			_casino_strip_row.add_child(_casino_make_item(final, fin_idx))
		else:
			var ri := randi() % _CASINO_REWARDS.size()
			_casino_strip_row.add_child(_casino_make_item(_CASINO_REWARDS[ri], ri))


func _casino_make_item(r: Dictionary, r_idx: int) -> Control:
	var bg_col:  Color = _CASINO_BG[r_idx]  if r_idx >= 0 else Color(0.2, 0.2, 0.2)
	var txt_col: Color = _CASINO_TXT[r_idx] if r_idx >= 0 else Color.WHITE
	var brd_col := Color(0.30, 0.28, 0.25)
	var brd_w   := 1

	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(_CASINO_ITEM_W, _CASINO_ITEM_H)
	c.add_theme_stylebox_override(&"panel",
		UiStyle.panel_style(bg_col, brd_col, 4, brd_w))

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
		_:              _casino_result_lbl.text = "Won: %s!" % (reward["label"] as String).replace("\n", " ")
	_casino_update_ui()


func _casino_grant(reward: Dictionary) -> void:
	match reward.get("id", ""):
		"coin1":        GameState.add_coins(1)
		"coin5":        GameState.add_coins(5)
		"coin10":       GameState.add_coins(10)
		"coin20":       GameState.add_coins(20)
		"ore200":       GameState.add_ore(200)
		"wood200":      GameState.add_wood(200)
		"coin100":      GameState.add_coins(100)
		"giant":        _casino_try_spawn_giant()
		"enemy_attack": _casino_spawn_enemy_attack()
		# "empty": nothing


func _casino_spawn_enemy_attack() -> void:
	var spawn_node := get_node_or_null("ExteriorSpawn") as Node3D
	var origin := spawn_node.global_position if spawn_node != null else Vector3(80.0, 0.0, 0.0)
	for i in 5:
		var e := _EnemyScene.instantiate()
		add_child(e)
		var angle := float(i) / 5.0 * TAU
		e.global_position = origin + Vector3(cos(angle) * 4.0, 0.0, sin(angle) * 4.0)


func _casino_try_spawn_giant() -> void:
	if GameState.has_giant_warrior:
		GameState.add_coins(50)
		_casino_result_lbl.text = "Giant exists! +50 Coins."
		return
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	add_child(gw)
	gw.global_position = Vector3(8.0, 0.0, 3.0)
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
	_bld_selected = building
	_bld_panel_layer.visible = true
	_refresh_building_panel()
	_position_building_panel(building)
	_show_selection_ring(building)


func _close_building_panel() -> void:
	if _bld_panel_layer != null: _bld_panel_layer.visible = false
	_bld_selected = null
	_hide_selection_ring()


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

	var lvl: int = int(_bld_selected.get(&"upgrade_level") if _bld_selected.get(&"upgrade_level") != null else 1)
	var is_tower   := _bld_selected.is_in_group(&"tower")
	var type_str   := "Tower" if is_tower else "Barracks"
	_bld_title_lbl.text = "%s  (Level %d / 3)" % [type_str, lvl]

	if lvl >= 3:
		_bld_upgrade_btn.text     = "⬆ Max Level"
		_bld_upgrade_btn.disabled = true
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
	GameState.buy_building_upgrade(_bld_selected)
	_refresh_building_panel()


func _on_bld_coins_changed(_n: int = 0) -> void:
	_refresh_building_panel()
