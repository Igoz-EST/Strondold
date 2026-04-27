extends Node3D

## Полоска HP над врагом (billboard к камере).
const BAR_WIDTH := 1.6
const BAR_HEIGHT := 0.12

var _bar_root: Node3D
var _fill_mesh: MeshInstance3D
var _fill_box: BoxMesh


func _ready() -> void:
	position = Vector3(0.0, 1.32, 0.0)
	_build_visuals()
	var e := get_parent()
	if e:
		set_hp(e.hp, e.max_hp)


func _build_visuals() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = &"HpBarVisual"
	add_child(_bar_root)

	var bg := MeshInstance3D.new()
	var bg_b := BoxMesh.new()
	bg_b.size = Vector3(BAR_WIDTH + 0.08, BAR_HEIGHT + 0.06, 0.05)
	bg.mesh = bg_b
	var bg_m := StandardMaterial3D.new()
	bg_m.albedo_color = Color(0.06, 0.06, 0.08)
	bg.set_surface_override_material(0, bg_m)
	_bar_root.add_child(bg)

	_fill_box = BoxMesh.new()
	_fill_box.size = Vector3(BAR_WIDTH, BAR_HEIGHT, 0.03)
	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.mesh = _fill_box
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.82, 0.35)
	fm.emission_enabled = true
	fm.emission = Color(0.08, 0.25, 0.1)
	fm.emission_energy_multiplier = 0.2
	fm.roughness = 0.5
	_fill_mesh.set_surface_override_material(0, fm)
	_fill_mesh.position.z = 0.028
	_bar_root.add_child(_fill_mesh)


func _process(_delta: float) -> void:
	if _bar_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_bar_root.look_at(cam.global_position, Vector3.UP)
	_bar_root.rotate_object_local(Vector3.UP, PI)


func set_hp(cur: int, max_hp: int) -> void:
	if _fill_box == null:
		return
	var ratio := clampf(float(cur) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var w := BAR_WIDTH * ratio
	_fill_box.size = Vector3(maxf(w, 0.05), BAR_HEIGHT, 0.03)
	_fill_mesh.position.x = -BAR_WIDTH * 0.5 + _fill_box.size.x * 0.5
