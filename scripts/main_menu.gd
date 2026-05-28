extends Control

const LOADING_SCENE := "res://scenes/loading_screen.tscn"
const MENU_MUSIC_PATH := "res://assets/music/moonlit_keep.mp3"
const MENU_BACKGROUND_PATH := "res://assets/ui/main_menu_background.jpg"
const MUSIC_FADE_SEC := 1.4
const RESOLUTIONS := [
	["4K", Vector2i(3840, 2160)],
	["2K", Vector2i(2560, 1440)],
	["Full HD", Vector2i(1920, 1080)],
	["HD", Vector2i(1280, 720)],
]

var _main_layer: CenterContainer
var _mode_layer: CenterContainer
var _settings_layer: CenterContainer
var _main_panel: PanelContainer
var _settings_panel: PanelContainer
var _music_player: AudioStreamPlayer
var _music_slider: HSlider
var _sound_slider: HSlider
var _resolution_option: OptionButton
var _fullscreen_check: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_menu_music()
	_build_background()
	_build_main_panel()
	_build_mode_panel()
	_build_settings_panel()
	_show_main()


func _setup_menu_music() -> void:
	if not ResourceLoader.exists(MENU_MUSIC_PATH):
		push_warning("Main menu music not found: %s" % MENU_MUSIC_PATH)
		return
	var stream: AudioStream = load(MENU_MUSIC_PATH) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player = AudioStreamPlayer.new()
	_music_player.name = &"MenuMusic"
	_music_player.stream = stream
	_music_player.volume_db = -22.0
	add_child(_music_player)
	_music_player.play()


func _build_background() -> void:
	var bg := TextureRect.new()
	bg.name = &"Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 0.0
	bg.offset_top = 0.0
	bg.offset_right = 0.0
	bg.offset_bottom = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.texture = _load_background_texture()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)


func _load_background_texture() -> Texture2D:
	var image := Image.new()
	var err := image.load(MENU_BACKGROUND_PATH)
	if err != OK:
		push_warning("Main menu background failed to load: %s, error %s" % [MENU_BACKGROUND_PATH, err])
		return null
	return ImageTexture.create_from_image(image)


func _build_main_panel() -> void:
	_main_layer = CenterContainer.new()
	_main_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_main_layer)

	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(390, 330)
	_main_panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style(Color(0.045, 0.04, 0.034, 0.94), Color(0.48, 0.38, 0.25), 12, 2))
	_main_layer.add_child(_main_panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	_main_panel.add_child(col)

	var title := Label.new()
	title.text = "STRONDOLD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_COIN, 44, 8)
	col.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Defend the fortress and gather resources"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(subtitle, UiStyle.TEXT_MUTED, 14, 2)
	col.add_child(subtitle)

	col.add_child(_spacer(10))
	col.add_child(_make_button("New Game", _on_new_game_pressed))
	col.add_child(_make_button("Settings", _on_settings_pressed))
	col.add_child(_make_button("Exit", _on_exit_pressed))


func _build_mode_panel() -> void:
	_mode_layer = CenterContainer.new()
	_mode_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mode_layer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 300)
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	_mode_layer.add_child(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Choose Game Mode"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_MAIN, 28, 5)
	col.add_child(title)

	col.add_child(_spacer(8))
	col.add_child(_make_button("Mission 1", _on_mission_1_pressed))
	col.add_child(_make_button("Endless Game", _on_endless_game_pressed))
	col.add_child(_make_button("Back to Main Menu", _show_main))


func _build_settings_panel() -> void:
	_settings_layer = CenterContainer.new()
	_settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_settings_layer)

	_settings_panel = PanelContainer.new()
	_settings_panel.custom_minimum_size = Vector2(440, 430)
	_settings_panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	_settings_layer.add_child(_settings_panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	_settings_panel.add_child(col)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_MAIN, 30, 6)
	col.add_child(title)

	var music_label := Label.new()
	music_label.text = "Music"
	UiStyle.style_label(music_label, UiStyle.TEXT_MUTED, 16, 3)
	col.add_child(music_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = 1.0
	_music_slider.custom_minimum_size = Vector2(260, 28)
	_music_slider.value = _get_music_volume_percent()
	_music_slider.value_changed.connect(_on_music_slider_changed)
	col.add_child(_music_slider)

	var sound_label := Label.new()
	sound_label.text = "Sound"
	UiStyle.style_label(sound_label, UiStyle.TEXT_MUTED, 16, 3)
	col.add_child(sound_label)

	_sound_slider = HSlider.new()
	_sound_slider.min_value = 0.0
	_sound_slider.max_value = 100.0
	_sound_slider.step = 1.0
	_sound_slider.custom_minimum_size = Vector2(260, 28)
	_sound_slider.value = SoundManager.get_sfx_volume_slider_percent()
	_sound_slider.value_changed.connect(_on_sound_slider_changed)
	col.add_child(_sound_slider)

	var resolution_label := Label.new()
	resolution_label.text = "Resolution"
	UiStyle.style_label(resolution_label, UiStyle.TEXT_MUTED, 16, 3)
	col.add_child(resolution_label)

	_resolution_option = OptionButton.new()
	_resolution_option.custom_minimum_size = Vector2(260, 40)
	for i in RESOLUTIONS.size():
		var item: Array = RESOLUTIONS[i]
		var size: Vector2i = item[1]
		_resolution_option.add_item("%s (%dx%d)" % [item[0], size.x, size.y], i)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	col.add_child(_resolution_option)

	_fullscreen_check = CheckBox.new()
	_fullscreen_check.text = "Fullscreen"
	_fullscreen_check.custom_minimum_size = Vector2(260, 36)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	col.add_child(_fullscreen_check)

	col.add_child(_spacer(4))
	col.add_child(_make_button("Back", _show_main))


func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(250, 46)
	btn.focus_mode = Control.FOCUS_ALL
	UiStyle.style_button(btn, 18)
	btn.pressed.connect(callback)
	return btn


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(1.0, height)
	return c


func _show_main() -> void:
	_main_layer.visible = true
	_mode_layer.visible = false
	_settings_layer.visible = false


func _on_settings_pressed() -> void:
	_music_slider.set_value_no_signal(_get_music_volume_percent())
	_sound_slider.set_value_no_signal(SoundManager.get_sfx_volume_slider_percent())
	_refresh_video_settings()
	_main_layer.visible = false
	_mode_layer.visible = false
	_settings_layer.visible = true


func _get_music_volume_percent() -> float:
	if _music_player == null:
		return 0.0
	if _music_player.volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(_music_player.volume_db) * 100.0, 0.0, 100.0)


func _on_music_slider_changed(value: float) -> void:
	if _music_player == null:
		return
	var v := clampf(value / 100.0, 0.0, 1.0)
	_music_player.volume_db = -80.0 if v <= 0.0001 else linear_to_db(v)


func _on_sound_slider_changed(value: float) -> void:
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


func _on_new_game_pressed() -> void:
	_main_layer.visible = false
	_mode_layer.visible = true
	_settings_layer.visible = false


func _on_mission_1_pressed() -> void:
	_start_selected_game(GameState.GAME_MODE_MISSION)


func _on_endless_game_pressed() -> void:
	_start_selected_game(GameState.GAME_MODE_ENDLESS)


func _start_selected_game(mode: int) -> void:
	GameState.set_game_mode(mode)
	GameState.reset_run()
	if _music_player != null:
		var tw := create_tween()
		tw.tween_property(_music_player, "volume_db", -80.0, MUSIC_FADE_SEC)
		await tw.finished
	get_tree().change_scene_to_file(LOADING_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
