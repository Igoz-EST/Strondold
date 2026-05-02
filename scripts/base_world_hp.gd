extends Node3D

## Полоска HP базы в мире (над зданием).
const BAR_WIDTH := 4.2
const BAR_HEIGHT := 0.26

var _bar_root: Node3D
var _fill_mesh: MeshInstance3D
var _fill_box: BoxMesh
var _hp_label: Label3D


func _ready() -> void:
	# Вершина короба базы ~local y=3; чуть выше.
	position = Vector3(0.0, 3.85, 0.0)
	GameState.base_hp_changed.connect(_on_hp_changed)
	_build_visuals()
	_on_hp_changed(GameState.base_hp, GameState.BASE_MAX_HP)


func _build_visuals() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = &"HpBarVisual"
	add_child(_bar_root)

	var bg := MeshInstance3D.new()
	var bg_b := BoxMesh.new()
	bg_b.size = Vector3(BAR_WIDTH + 0.1, BAR_HEIGHT + 0.08, 0.06)
	bg.mesh = bg_b
	bg.set_surface_override_material(0, UiStyle.bar_bg_material())
	_bar_root.add_child(bg)

	_fill_box = BoxMesh.new()
	_fill_box.size = Vector3(BAR_WIDTH, BAR_HEIGHT, 0.04)
	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.mesh = _fill_box
	_fill_mesh.set_surface_override_material(0, UiStyle.bar_fill_material(UiStyle.BAR_HP))
	_fill_mesh.position.z = 0.035
	_bar_root.add_child(_fill_mesh)

	_hp_label = Label3D.new()
	_hp_label.name = &"HpLabel"
	UiStyle.style_label3d(_hp_label, UiStyle.TEXT_MAIN, 28, 10)
	_hp_label.position = Vector3(0.0, 0.42, 0.0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_root.add_child(_hp_label)


func _process(_delta: float) -> void:
	if _bar_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_bar_root.look_at(cam.global_position, Vector3.UP)
	_bar_root.rotate_object_local(Vector3.UP, PI)


func _on_hp_changed(cur: int, max_hp: int) -> void:
	if _hp_label:
		_hp_label.text = "%d / %d" % [cur, max_hp]
	if _fill_box == null:
		return
	var ratio := clampf(float(cur) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var w := BAR_WIDTH * ratio
	_fill_box.size = Vector3(maxf(w, 0.06), BAR_HEIGHT, 0.04)
	_fill_mesh.position.x = -BAR_WIDTH * 0.5 + _fill_box.size.x * 0.5
