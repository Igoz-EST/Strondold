extends Control

const MAIN_SCENE := "res://scenes/main.tscn"

var _bar: ProgressBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	ResourceLoader.load_threaded_request(MAIN_SCENE)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.028, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 180)
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_style())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 16)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Loading..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(title, UiStyle.TEXT_MAIN, 30, 6)
	col.add_child(title)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.custom_minimum_size = Vector2(360, 28)
	col.add_child(_bar)

func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
	var ratio := 0.0
	if progress.size() > 0:
		ratio = float(progress[0])
	_bar.value = ratio * 100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
		if packed != null:
			get_tree().change_scene_to_packed(packed)
