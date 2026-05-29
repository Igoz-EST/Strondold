extends MarginContainer

const _WarriorScene      := preload("res://scenes/warrior.tscn")
const _GiantWarriorScript := preload("res://scripts/giant_warrior.gd")

const REWARDS := [
	{"id": "coin1",   "label": "1\nCoin",      "weight": 55.0,  "rarity": 0, "scaled": false},
	{"id": "coin5",   "label": "5\nCoins",     "weight": 25.0,  "rarity": 0, "scaled": false},
	{"id": "coin10",  "label": "10\nCoins",    "weight": 10.0,  "rarity": 0, "scaled": false},
	{"id": "coin20",  "label": "20\nCoins",    "weight": 5.0,   "rarity": 1, "scaled": true},
	{"id": "ore200",  "label": "200\nOre",     "weight": 2.0,   "rarity": 2, "scaled": true},
	{"id": "wood200", "label": "200\nWood",    "weight": 2.0,   "rarity": 2, "scaled": true},
	{"id": "coin100", "label": "100\nCoins",   "weight": 0.8,   "rarity": 3, "scaled": true},
	{"id": "giant",   "label": "GIANT\nWARRIOR","weight": 0.15, "rarity": 4, "scaled": true},
]

const BG_COLORS := [
	Color(0.35, 0.30, 0.08),
	Color(0.40, 0.34, 0.09),
	Color(0.45, 0.38, 0.10),
	Color(0.55, 0.46, 0.0),
	Color(0.04, 0.22, 0.38),
	Color(0.25, 0.12, 0.02),
	Color(0.45, 0.20, 0.0),
	Color(0.22, 0.0,  0.38),
]

const TXT_COLORS := [
	Color(0.95, 0.85, 0.30),
	Color(0.95, 0.85, 0.30),
	Color(0.95, 0.85, 0.30),
	Color(1.0,  0.95, 0.30),
	Color(0.40, 0.90, 1.0),
	Color(0.75, 0.48, 0.15),
	Color(1.0,  0.58, 0.10),
	Color(0.88, 0.45, 1.0),
]

const RARITY_BORDER := [
	Color(0.45, 0.45, 0.45),
	Color(0.18, 0.60, 0.18),
	Color(0.12, 0.38, 0.90),
	Color(0.90, 0.45, 0.0),
	Color(0.70, 0.10, 1.0),
]

const ITEM_W  := 86
const ITEM_H  := 62
const ITEM_SEP := 2
const STRIDE  := ITEM_W + ITEM_SEP
const VIS     := 5
const TOTAL   := 40
const FIN_IDX := 32

var _bet_slider: HSlider
var _bet_label:  Label
var _mult_label: Label
var _roll_btn:   Button
var _result_lbl: Label
var _strip_row:  HBoxContainer
var _rolling     := false


func _ready() -> void:
	name = "Casino"
	add_theme_constant_override("margin_left",   6)
	add_theme_constant_override("margin_top",    4)
	add_theme_constant_override("margin_right",  6)
	add_theme_constant_override("margin_bottom", 6)
	_build_ui()
	GameState.coins_changed.connect(_on_coins_changed)


func _build_ui() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	add_child(col)

	# — Bet row —
	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 6)
	col.add_child(bet_row)

	var lbl := Label.new()
	lbl.text = "BET:"
	UiStyle.style_label(lbl, UiStyle.TEXT_MAIN, 14, 2)
	bet_row.add_child(lbl)

	_bet_slider = HSlider.new()
	_bet_slider.min_value             = 1.0
	_bet_slider.max_value             = float(maxi(1, GameState.coins))
	_bet_slider.step                  = 1.0
	_bet_slider.value                 = 1.0
	_bet_slider.custom_minimum_size   = Vector2(130, 20)
	_bet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bet_slider.focus_mode            = Control.FOCUS_NONE
	_bet_slider.value_changed.connect(_on_bet_changed)
	bet_row.add_child(_bet_slider)

	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(34, 0)
	UiStyle.style_label(_bet_label, UiStyle.TEXT_COIN, 14, 2)
	bet_row.add_child(_bet_label)

	# — Multiplier info —
	_mult_label = Label.new()
	UiStyle.style_label(_mult_label, Color(0.80, 0.50, 1.0), 13, 2)
	col.add_child(_mult_label)

	# — Result —
	_result_lbl = Label.new()
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.text = " "
	UiStyle.style_label(_result_lbl, UiStyle.TEXT_HP, 13, 2)
	col.add_child(_result_lbl)

	# — Strip container (clipped) —
	var clip := Control.new()
	clip.custom_minimum_size  = Vector2(STRIDE * VIS, ITEM_H + 20)
	clip.clip_contents        = true
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(clip)

	var arrow := Label.new()
	arrow.text = "▼"
	arrow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	arrow.offset_top    = 0.0
	arrow.offset_bottom = 18.0
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(arrow, Color.WHITE, 14, 3)
	clip.add_child(arrow)

	_strip_row = HBoxContainer.new()
	_strip_row.add_theme_constant_override("separation", ITEM_SEP)
	_strip_row.position = Vector2(0.0, 18.0)
	clip.add_child(_strip_row)

	# — Roll button —
	_roll_btn = Button.new()
	_roll_btn.text                = "ROLL"
	_roll_btn.custom_minimum_size = Vector2(100, 38)
	_roll_btn.focus_mode          = Control.FOCUS_NONE
	UiStyle.style_button(_roll_btn, 18)
	_roll_btn.pressed.connect(_on_roll_pressed)
	col.add_child(_roll_btn)

	_update_ui()


func _on_coins_changed(_n: int) -> void:
	if _bet_slider == null:
		return
	_bet_slider.max_value = float(maxi(1, GameState.coins))
	_bet_slider.value = clampf(_bet_slider.value, 1.0, float(maxi(1, GameState.coins)))
	_update_ui()


func _on_bet_changed(_v: float) -> void:
	_update_ui()


func _update_ui() -> void:
	var bet := int(_bet_slider.value) if _bet_slider else 1
	if _bet_label:
		_bet_label.text = str(bet)
	if _mult_label:
		_mult_label.text = "Rare chance x%.2f" % (1.0 + bet * 0.015)
	if _roll_btn:
		_roll_btn.disabled = _rolling or GameState.coins < bet


func _on_roll_pressed() -> void:
	var bet := int(_bet_slider.value)
	if _rolling or GameState.coins < bet:
		return
	if not GameState.spend_coins(bet):
		return
	_rolling = true
	_roll_btn.disabled = true
	_result_lbl.text = "Rolling..."
	var reward := _pick_reward(bet)
	_build_strip(reward)
	_animate(reward)


func _pick_reward(bet: int) -> Dictionary:
	var mult  := 1.0 + bet * 0.015
	var pool: Array[float] = []
	var total := 0.0
	for r: Dictionary in REWARDS:
		var w: float = r["weight"]
		if r["scaled"]:
			w *= mult
		pool.append(w)
		total += w
	var roll := randf() * total
	var acc  := 0.0
	for i in pool.size():
		acc += pool[i]
		if roll < acc:
			return REWARDS[i]
	return REWARDS[0]


func _build_strip(final: Dictionary) -> void:
	for c in _strip_row.get_children():
		_strip_row.remove_child(c)
		c.free()
	_strip_row.position.x = 0.0
	var fin_r_idx := REWARDS.find(final)
	for i in TOTAL:
		if i == FIN_IDX:
			_strip_row.add_child(_make_item(final, fin_r_idx, true))
		else:
			var ri := randi() % REWARDS.size()
			_strip_row.add_child(_make_item(REWARDS[ri], ri, false))


func _make_item(r: Dictionary, r_idx: int, highlight: bool) -> Control:
	var bg_col  := BG_COLORS[r_idx]       if r_idx >= 0 else Color(0.2, 0.2, 0.2)
	var txt_col := TXT_COLORS[r_idx]      if r_idx >= 0 else Color.WHITE
	var brd_col := RARITY_BORDER[r["rarity"]] if highlight else Color(0.28, 0.28, 0.28)
	var brd_w   := 3                       if highlight else 1

	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(ITEM_W, ITEM_H)
	c.add_theme_stylebox_override(&"panel",
		UiStyle.panel_style(bg_col, brd_col, 4, brd_w))

	var lbl := Label.new()
	lbl.text                    = r["label"]
	lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical     = Control.SIZE_EXPAND_FILL
	lbl.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	UiStyle.style_label(lbl, txt_col, 11, 2)
	c.add_child(lbl)
	return c


func _animate(reward: Dictionary) -> void:
	var center_x := float(STRIDE * VIS) * 0.5
	var end_x    := center_x - FIN_IDX * STRIDE - ITEM_W * 0.5
	end_x += randf_range(-6.0, 6.0)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_strip_row, "position:x", end_x, 3.5)
	tw.tween_callback(func() -> void: _finish(reward))


func _finish(reward: Dictionary) -> void:
	_rolling = false
	_grant(reward)
	var rname: String = (reward["label"] as String).replace("\n", " ")
	_result_lbl.text = "Won: %s!" % rname
	_update_ui()


func _grant(reward: Dictionary) -> void:
	match reward["id"]:
		"coin1":   GameState.add_coins(1)
		"coin5":   GameState.add_coins(5)
		"coin10":  GameState.add_coins(10)
		"coin20":  GameState.add_coins(20)
		"ore200":  GameState.add_ore(200)
		"wood200": GameState.add_wood(200)
		"coin100": GameState.add_coins(100)
		"giant":   _try_spawn_giant()


func _try_spawn_giant() -> void:
	if GameState.has_giant_warrior:
		GameState.add_coins(50)
		_result_lbl.text = "Giant exists! +50 Coins."
		return
	var world := get_tree().get_first_node_in_group(&"main_world")
	if world == null:
		return
	var gw := _WarriorScene.instantiate() as CharacterBody3D
	gw.set_script(_GiantWarriorScript)
	world.add_child(gw)
	gw.global_position = Vector3(8.0, 0.0, 3.0)
	GameState.has_giant_warrior = true
