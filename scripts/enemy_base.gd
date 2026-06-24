extends StaticBody3D

## Mission 3 enemy base. HP/regen/victory live in GameState; this node receives
## damage from the player's units (apply_sword_hit), shows a floating HP bar, and
## darkens as it takes damage. Destroying it triggers the player's victory.

const _BAR_W := 6.0
const _INTACT := Color(1.0, 1.0, 1.0)
const _RUBBLE := Color(0.35, 0.30, 0.30)

var _tint_parts: Array = []
var _base_colors: Array = []
var _label: Label3D
var _hp_fill: MeshInstance3D
var _hp_fill_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"enemy_base")
	GameState.init_enemy_base()
	GameState.enemy_base_hp_changed.connect(_on_hp_changed)

	_tint_parts = get_meta(&"tint_parts", [])
	for p in _tint_parts:
		var mat := (p as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		_base_colors.append(mat.albedo_color if mat != null else Color.WHITE)

	_build_hp_bar()
	_on_hp_changed(GameState.enemy_base_hp, GameState.enemy_base_max)


## Player units call this when they reach and strike the base.
func apply_sword_hit(damage: int = 10, _attacker: Node = null, _damage_type: int = 0) -> void:
	if GameState.enemy_base_down:
		return
	GameState.damage_enemy_base(damage)
	SoundManager.play_sfx(&"impact", global_position)


func _build_hp_bar() -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, 9.6, 0.0)
	add_child(pivot)

	_label = Label3D.new()
	_label.text = "ENEMY BASE"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0.0, 1.1, 0.0)
	UiStyle.style_label3d(_label, Color(1.0, 0.55, 0.5), 64, 10)
	pivot.add_child(_label)

	var bg := MeshInstance3D.new()
	var bgm := BoxMesh.new()
	bgm.size = Vector3(_BAR_W, 0.5, 0.1)
	bg.mesh = bgm
	bg.material_override = _flat(Color(0.05, 0.04, 0.04), true)
	pivot.add_child(bg)

	_hp_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(_BAR_W, 0.44, 0.14)
	_hp_fill.mesh = fm
	_hp_fill_mat = _flat(Color(0.85, 0.16, 0.14), true)
	_hp_fill.material_override = _hp_fill_mat
	pivot.add_child(_hp_fill)


func _flat(color: Color, unshaded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	return m


func _on_hp_changed(current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / float(max(1, maximum)), 0.0, 1.0)
	# Shrink + slide the HP fill bar
	if _hp_fill != null:
		var w := maxf(0.02, _BAR_W * ratio)
		_hp_fill.scale.x = w / _BAR_W
		_hp_fill.position.x = -(_BAR_W - w) * 0.5
		if _hp_fill_mat != null:
			_hp_fill_mat.albedo_color = Color(0.9, 0.16, 0.14).lerp(Color(0.95, 0.7, 0.1), 1.0 - ratio)
	if _label != null:
		_label.text = "ENEMY BASE  %d%%" % int(round(ratio * 100.0))
	# Darken structure toward rubble as it takes damage
	for i in _tint_parts.size():
		var mi := _tint_parts[i] as MeshInstance3D
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = (_base_colors[i] as Color) * _INTACT.lerp(_RUBBLE, 1.0 - ratio)
	if current <= 0:
		_on_destroyed()


func _on_destroyed() -> void:
	# Collapse: sink and flatten. Victory is fired by GameState.enemy_base_destroyed.
	var tw := create_tween()
	tw.tween_property(self, "scale:y", 0.25, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "position:y", position.y - 2.0, 0.6)
	if _label != null:
		_label.text = "BASE DESTROYED"
