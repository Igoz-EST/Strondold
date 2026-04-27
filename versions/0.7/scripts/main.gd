extends Node3D

const _WorkerScene := preload("res://scenes/worker.tscn")
const _BreakableScene := preload("res://scenes/breakable.tscn")
const _WaveManagerScript := preload("res://scripts/wave_manager.gd")
const _BaseWorldHpScript := preload("res://scripts/base_world_hp.gd")
const _PauseEscListenerScript := preload("res://scripts/pause_menu_esc_listener.gd")

## «Крепость Строндолт» (Suno), трек из шаринга пользователя.
const _BG_MUSIC_PATH := "res://assets/music/krepost_strondolt.mp3"
## Отступ сундука от маркера спавна игрока (~14, 0, 0).
const PLAYER_SPAWN_CHEST_CLEAR := 5.0

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
var _storage_ore_label: Label
var _sell_button: Button
var _buy_worker_button: Button
var _worker_timer_label: Label

var _worker_spawn_pending := false
var _worker_spawn_time_left := 0.0

var _dev_console_layer: CanvasLayer
var _dev_line: LineEdit
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
var _pause_menu_open: bool = false


func _ready() -> void:
	add_to_group("main_world")
	var wm := Node.new()
	wm.set_script(_WaveManagerScript)
	wm.name = "WaveManager"
	add_child(wm)
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
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.ore_changed.connect(_on_ore_changed)
	GameState.base_hp_changed.connect(_on_base_hp_changed)
	GameState.commander_mode_changed.connect(_on_commander_mode)
	GameState.pending_build_changed.connect(_on_pending_build)
	_on_coins_changed(GameState.coins)
	_refresh_ore_labels()
	_on_base_hp_changed(GameState.base_hp, GameState.BASE_MAX_HP)
	_setup_wave_timer_ui()
	call_deferred(&"_spawn_secret_chest_random")


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


func _setup_background_music() -> void:
	if not ResourceLoader.exists(_BG_MUSIC_PATH):
		push_warning("Фоновая музыка не найдена: %s" % _BG_MUSIC_PATH)
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
	bgm.volume_db = -22.0
	bgm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bgm)
	bgm.play()
	_bg_music_player = bgm


func _process(delta: float) -> void:
	if _worker_spawn_pending:
		_worker_spawn_time_left -= delta
		_refresh_workers_ui()
		if _worker_spawn_time_left <= 0.0:
			_worker_spawn_pending = false
			_spawn_worker()
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
	_wave_countdown_label.add_theme_font_size_override("font_size", 22)
	_wave_countdown_label.add_theme_color_override("font_color", Color(0.88, 0.55, 0.95))
	_wave_countdown_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	_wave_countdown_label.add_theme_constant_override("outline_size", 4)
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


func _spawn_worker() -> void:
	var inst: Node = _WorkerScene.instantiate()
	if inst.has_method(&"setup"):
		inst.call(&"setup", _ore_deposit.global_position)
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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.12, 0.94)
	sb.border_color = Color(0.92, 0.92, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", sb)
	_build_layer.add_child(bar)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.mouse_filter = Control.MOUSE_FILTER_STOP
	tabs.focus_mode = Control.FOCUS_NONE
	bar.add_child(tabs)

	var build_tab := MarginContainer.new()
	build_tab.name = "Постройки"
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
	_tower_button.text = "TOWER\n🏰\nCOST: 10"
	_tower_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tower_button.add_theme_font_size_override("font_size", 15)
	_tower_button.pressed.connect(_on_tower_button_pressed)
	row_build.add_child(_tower_button)

	_barracks_button = Button.new()
	_barracks_button.focus_mode = Control.FOCUS_NONE
	_barracks_button.custom_minimum_size = Vector2(128, 96)
	_barracks_button.text = "BARRACKS\n🛖\n%d монет" % GameState.BARRACKS_COST
	_barracks_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_barracks_button.add_theme_font_size_override("font_size", 14)
	_barracks_button.tooltip_text = "До 4 воинов; после гибели новый через 10 с."
	_barracks_button.pressed.connect(_on_barracks_button_pressed)
	row_build.add_child(_barracks_button)

	_warehouse_button = Button.new()
	_warehouse_button.focus_mode = Control.FOCUS_NONE
	_warehouse_button.custom_minimum_size = Vector2(118, 96)
	_warehouse_button.text = "WAREHOUSE\n📦\n%d монет" % GameState.WAREHOUSE_COST
	_warehouse_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warehouse_button.add_theme_font_size_override("font_size", 13)
	_warehouse_button.tooltip_text = "Если склад ближе базы, рабочий несёт руду сюда; счёт руды общий."
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
	_dmg_upgrade_button.text = "DMG\n+10\n5 монет"
	_dmg_upgrade_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dmg_upgrade_button.add_theme_font_size_override("font_size", 14)
	_dmg_upgrade_button.tooltip_text = "Урон меча по деревьям и камням: +10 за удар. По врагам урон без улучшений."
	_dmg_upgrade_button.pressed.connect(_on_dmg_upgrade_pressed)
	row_up.add_child(_dmg_upgrade_button)

	var storage_tab := MarginContainer.new()
	storage_tab.name = "Storage"
	storage_tab.add_theme_constant_override("margin_left", 6)
	storage_tab.add_theme_constant_override("margin_top", 4)
	storage_tab.add_theme_constant_override("margin_right", 6)
	storage_tab.add_theme_constant_override("margin_bottom", 6)
	tabs.add_child(storage_tab)

	var storage_col := VBoxContainer.new()
	storage_col.add_theme_constant_override("separation", 10)
	storage_tab.add_child(storage_col)

	_storage_ore_label = Label.new()
	_storage_ore_label.text = "Руда: 0"
	_storage_ore_label.add_theme_font_size_override("font_size", 18)
	storage_col.add_child(_storage_ore_label)

	_sell_button = Button.new()
	_sell_button.focus_mode = Control.FOCUS_NONE
	_sell_button.text = "Продать"
	_sell_button.custom_minimum_size = Vector2(200, 44)
	_sell_button.tooltip_text = "100 руды = 1 монета. Доступно только на базе."
	_sell_button.pressed.connect(_on_sell_ore_pressed)
	storage_col.add_child(_sell_button)

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
	_worker_timer_label.text = "Нет заказа на рабочего"
	_worker_timer_label.add_theme_font_size_override("font_size", 16)
	workers_col.add_child(_worker_timer_label)

	_buy_worker_button = Button.new()
	_buy_worker_button.focus_mode = Control.FOCUS_NONE
	_buy_worker_button.text = "Рабочий\n%d монет" % GameState.WORKER_COST
	_buy_worker_button.custom_minimum_size = Vector2(160, 88)
	_buy_worker_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_worker_button.add_theme_font_size_override("font_size", 15)
	_buy_worker_button.tooltip_text = "Появится через 5 с у базы. Пока не появится — второго заказать нельзя."
	_buy_worker_button.pressed.connect(_on_buy_worker_pressed)
	workers_col.add_child(_buy_worker_button)

	bar.offset_top = -166.0
	_on_coins_changed(GameState.coins)
	_refresh_ore_labels()
	_refresh_workers_ui()


func _on_tower_button_pressed() -> void:
	GameState.begin_tower_blueprint()


func _on_barracks_button_pressed() -> void:
	GameState.begin_barracks_blueprint()


func _on_warehouse_button_pressed() -> void:
	GameState.begin_warehouse_blueprint()


func _on_dmg_upgrade_pressed() -> void:
	GameState.buy_dmg_upgrade()


func _on_sell_ore_pressed() -> void:
	GameState.sell_ore_for_coins()


func _on_buy_worker_pressed() -> void:
	if _worker_spawn_pending:
		return
	if GameState.coins < GameState.WORKER_COST:
		return
	if not GameState.spend_coins(GameState.WORKER_COST):
		return
	_worker_spawn_pending = true
	_worker_spawn_time_left = 5.0
	_refresh_workers_ui()


func _refresh_workers_ui() -> void:
	if _buy_worker_button == null or _worker_timer_label == null:
		return
	_buy_worker_button.text = "Рабочий\n%d монет" % GameState.WORKER_COST
	if _worker_spawn_pending:
		_worker_timer_label.text = "Появление рабочего: %.1f с" % maxf(_worker_spawn_time_left, 0.0)
		_buy_worker_button.disabled = true
	else:
		_worker_timer_label.text = "Нет заказа на рабочего"
		_buy_worker_button.disabled = GameState.coins < GameState.WORKER_COST


func _refresh_ore_labels() -> void:
	var o: int = GameState.ore
	if _ore_label:
		_ore_label.text = "Руда: %d" % o
	if _storage_ore_label:
		_storage_ore_label.text = "Руда: %d  (100 ед. = 1 монета)" % o
	if _sell_button:
		_sell_button.disabled = GameState.ore < GameState.ORE_PER_COIN


func _on_ore_changed(_total: int) -> void:
	_refresh_ore_labels()


func _on_base_hp_changed(current: int, maximum: int) -> void:
	_base_hp_label.text = "База: %d / %d" % [current, maximum]


func _on_coins_changed(total: int) -> void:
	_coin_label.text = "Монеты: %d" % total
	if _tower_button:
		_tower_button.disabled = total < GameState.TOWER_COST
	if _barracks_button:
		_barracks_button.disabled = total < GameState.BARRACKS_COST
	if _warehouse_button:
		_warehouse_button.disabled = total < GameState.WAREHOUSE_COST
	if _dmg_upgrade_button:
		_dmg_upgrade_button.disabled = total < GameState.DMG_UPGRADE_COST
	_refresh_workers_ui()


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
	title.text = "База уничтожена"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.32))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.custom_minimum_size = Vector2(220, 52)
	_restart_button.focus_mode = Control.FOCUS_ALL
	_restart_button.add_theme_font_size_override("font_size", 22)
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
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.35, 0.92, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.1))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)

	_win_play_again_button = Button.new()
	_win_play_again_button.text = "Play again"
	_win_play_again_button.custom_minimum_size = Vector2(240, 52)
	_win_play_again_button.focus_mode = Control.FOCUS_ALL
	_win_play_again_button.add_theme_font_size_override("font_size", 22)
	_win_play_again_button.pressed.connect(_on_restart_pressed)
	box.add_child(_win_play_again_button)

	_win_exit_button = Button.new()
	_win_exit_button.text = "Exit"
	_win_exit_button.custom_minimum_size = Vector2(240, 52)
	_win_exit_button.focus_mode = Control.FOCUS_ALL
	_win_exit_button.add_theme_font_size_override("font_size", 22)
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
	panel.custom_minimum_size = Vector2(360, 0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.11, 0.14, 0.96)
	psb.border_color = Color(0.45, 0.55, 0.72)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(10)
	psb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", psb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	col.add_child(title)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	col.add_child(vol_row)

	var vol_lbl := Label.new()
	vol_lbl.text = "Музыка"
	vol_lbl.add_theme_font_size_override("font_size", 16)
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
	sound_lbl.add_theme_font_size_override("font_size", 16)
	sound_row.add_child(sound_lbl)

	_sound_volume_slider = HSlider.new()
	_sound_volume_slider.min_value = 0.0
	_sound_volume_slider.max_value = 100.0
	_sound_volume_slider.step = 1.0
	_sound_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sound_volume_slider.custom_minimum_size = Vector2(160, 24)
	_sound_volume_slider.value_changed.connect(_on_sound_volume_slider_changed)
	sound_row.add_child(_sound_volume_slider)

	var esc_hint := Label.new()
	esc_hint.text = "Esc — закрыть меню"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_hint.add_theme_font_size_override("font_size", 13)
	esc_hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	col.add_child(esc_hint)

	var quit_btn := Button.new()
	quit_btn.text = "Выйти"
	quit_btn.custom_minimum_size = Vector2(0, 44)
	quit_btn.focus_mode = Control.FOCUS_ALL
	quit_btn.add_theme_font_size_override("font_size", 18)
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


func _on_pause_quit_pressed() -> void:
	get_tree().quit()


func _setup_dev_console() -> void:
	_dev_console_layer = CanvasLayer.new()
	_dev_console_layer.name = "DevConsole"
	_dev_console_layer.layer = 100
	_dev_console_layer.visible = false
	add_child(_dev_console_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -132.0
	panel.offset_bottom = -8.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	psb.border_color = Color(0.35, 0.55, 0.85)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(6)
	psb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", psb)
	_dev_console_layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var hint := Label.new()
	hint.text = "T — открыть. Money:число  |  wave_skip — следующая волна  |  Esc — закрыть"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
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
