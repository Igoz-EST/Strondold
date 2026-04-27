extends Node3D

@onready var _coin_label: Label = $CanvasLayer/CoinLabel

var _build_layer: CanvasLayer
var _tower_button: Button


func _ready() -> void:
	add_to_group("main_world")
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.commander_mode_changed.connect(_on_commander_mode)
	GameState.pending_build_changed.connect(_on_pending_build)
	_on_coins_changed(GameState.coins)
	_setup_commander_build_ui()


func _setup_commander_build_ui() -> void:
	_build_layer = CanvasLayer.new()
	_build_layer.name = "CommanderBuildUI"
	_build_layer.layer = 12
	_build_layer.visible = false
	add_child(_build_layer)

	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -118.0
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

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_child(row)

	_tower_button = Button.new()
	_tower_button.focus_mode = Control.FOCUS_NONE
	_tower_button.custom_minimum_size = Vector2(118, 96)
	_tower_button.text = "TOWER\n🏰\nCOST: 10"
	_tower_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tower_button.add_theme_font_size_override("font_size", 15)
	_tower_button.pressed.connect(_on_tower_button_pressed)
	row.add_child(_tower_button)


func _on_tower_button_pressed() -> void:
	GameState.begin_tower_blueprint()


func _on_coins_changed(total: int) -> void:
	_coin_label.text = "Монеты: %d" % total
	if _tower_button:
		_tower_button.disabled = total < GameState.TOWER_COST


func _on_commander_mode(active: bool) -> void:
	if _build_layer:
		_build_layer.visible = active


func _on_pending_build(pending: bool) -> void:
	if _tower_button:
		_tower_button.modulate = Color(1.0, 0.92, 0.45) if pending else Color.WHITE
