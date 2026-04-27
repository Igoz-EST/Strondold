extends Node3D
## Внешний вид базы: цитадель (цоколь, корпус, башни, бойницы, портик). Коллизия остаётся на родителе.

const STONE := Color(0.56, 0.57, 0.62)
const STONE_DEEP := Color(0.4, 0.42, 0.48)
const STONE_DARK := Color(0.26, 0.28, 0.32)
const TRIM := Color(0.32, 0.34, 0.38)
const BRONZE := Color(0.58, 0.42, 0.22)
const SHADOW := Color(0.08, 0.09, 0.11)

var _sign_pair: PackedFloat32Array = PackedFloat32Array([-1.0, 1.0])
var _sign_triple: PackedFloat32Array = PackedFloat32Array([-1.0, 0.0, 1.0])


func _ready() -> void:
	_build_podium()
	_build_lower_skirt()
	_build_main_keep()
	_build_corner_turrets()
	_build_vertical_buttresses()
	_build_battlements()
	_build_gate_portico()
	_build_roof_cap()
	_build_banner()


func _mat(col: Color, rough: float = 0.82, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


func _box_mi(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.set_surface_override_material(0, mat)
	add_child(mi)


func _cyl_mi(radius: float, height: float, pos: Vector3, rot_deg: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius * 1.06
	cm.height = height
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.set_surface_override_material(0, mat)
	add_child(mi)


func _build_podium() -> void:
	var m := _mat(STONE_DEEP, 0.9)
	_box_mi(Vector3(11.6, 0.95, 11.6), Vector3(0, -2.525, 0), Vector3.ZERO, m)
	var step := _mat(STONE_DARK, 0.92)
	_box_mi(Vector3(11.0, 0.22, 11.0), Vector3(0, -2.02, 0), Vector3.ZERO, step)


func _build_lower_skirt() -> void:
	var m := _mat(STONE, 0.86)
	var h := 1.35
	var y := -1.325
	var thick := 0.42
	var span := 9.85
	_box_mi(Vector3(span, h, thick), Vector3(0, y, span * 0.5 - thick * 0.5), Vector3.ZERO, m)
	_box_mi(Vector3(span, h, thick), Vector3(0, y, -span * 0.5 + thick * 0.5), Vector3.ZERO, m)
	_box_mi(Vector3(thick, h, span - thick * 2.0), Vector3(span * 0.5 - thick * 0.5, y, 0), Vector3.ZERO, m)
	_box_mi(Vector3(thick, h, span - thick * 2.0), Vector3(-span * 0.5 + thick * 0.5, y, 0), Vector3.ZERO, m)


func _build_main_keep() -> void:
	var m := _mat(STONE, 0.8)
	_box_mi(Vector3(8.2, 3.35, 8.2), Vector3(0, 0.42, 0), Vector3.ZERO, m)
	var band := _mat(BRONZE, 0.55, 0.35)
	_box_mi(Vector3(8.35, 0.14, 8.35), Vector3(0, 1.85, 0), Vector3.ZERO, band)
	var upper := _mat(STONE_DEEP, 0.78)
	_box_mi(Vector3(7.15, 1.25, 7.15), Vector3(0, 2.58, 0), Vector3.ZERO, upper)


func _build_corner_turrets() -> void:
	var m := _mat(STONE_DEEP, 0.76, 0.05)
	var cap := _mat(TRIM, 0.7, 0.12)
	var r := 0.62
	var h := 5.95
	var y := 0.05
	var o: float = 4.05
	for sx in _sign_pair:
		for sz in _sign_pair:
			var ox: float = sx * o
			var oz: float = sz * o
			_cyl_mi(r, h, Vector3(ox, y, oz), Vector3.ZERO, m)
			_cyl_mi(r * 0.72, 0.38, Vector3(ox, y + h * 0.5 + 0.2, oz), Vector3.ZERO, cap)


func _build_vertical_buttresses() -> void:
	var m := _mat(STONE_DARK, 0.88)
	var w := 0.38
	var d := 0.55
	var h := 3.1
	var y := 0.35
	var s := 3.55
	for sign_x in _sign_pair:
		for k in _sign_triple:
			_box_mi(Vector3(w, h, d), Vector3(sign_x * 4.55, y, k * s), Vector3.ZERO, m)
	for sign_z in _sign_pair:
		for k in _sign_triple:
			_box_mi(Vector3(d, h, w), Vector3(k * s, y, sign_z * 4.55), Vector3.ZERO, m)


func _build_battlements() -> void:
	var m := _mat(TRIM, 0.72, 0.08)
	var merlon_w := 0.62
	var merlon_h := 0.48
	var merlon_d := 0.52
	# Верх верхнего яруса (центр 2.58, высота 1.25) — бойницы стоят на этой плоскости, не «в воздухе».
	var deck_top: float = 2.58 + 1.25 * 0.5
	var y: float = deck_top + merlon_h * 0.5
	var upper_half: float = 7.15 * 0.5
	# Центр зубца по Z/X — внутри габарита яруса, наружная грань почти по линии стены.
	var z_edge: float = upper_half - merlon_d * 0.5
	var x_edge: float = upper_half - merlon_d * 0.5
	var span_x: float = upper_half - merlon_w * 0.5
	var n := 7
	for i in range(n):
		var t := (float(i) / float(n - 1)) * 2.0 - 1.0
		var x := t * span_x
		_box_mi(Vector3(merlon_w, merlon_h, merlon_d), Vector3(x, y, z_edge), Vector3.ZERO, m)
		_box_mi(Vector3(merlon_w, merlon_h, merlon_d), Vector3(x, y, -z_edge), Vector3.ZERO, m)
	for i in range(1, n - 1):
		var t2 := (float(i) / float(n - 1)) * 2.0 - 1.0
		var z := t2 * span_x
		_box_mi(Vector3(merlon_d, merlon_h, merlon_w), Vector3(x_edge, y, z), Vector3.ZERO, m)
		_box_mi(Vector3(merlon_d, merlon_h, merlon_w), Vector3(-x_edge, y, z), Vector3.ZERO, m)


func _build_gate_portico() -> void:
	var z := 4.72
	var stone := _mat(STONE_DEEP, 0.84)
	var dark := _mat(STONE_DARK, 0.9)
	_box_mi(Vector3(3.6, 2.35, 0.55), Vector3(0, -0.35, z), Vector3.ZERO, stone)
	_box_mi(Vector3(0.55, 2.85, 0.55), Vector3(-1.35, 0.1, z + 0.12), Vector3.ZERO, dark)
	_box_mi(Vector3(0.55, 2.85, 0.55), Vector3(1.35, 0.1, z + 0.12), Vector3.ZERO, dark)
	_box_mi(Vector3(3.2, 0.32, 0.75), Vector3(0, 1.35, z + 0.18), Vector3.ZERO, dark)
	var lintel := _mat(BRONZE, 0.5, 0.45)
	_box_mi(Vector3(3.45, 0.16, 0.62), Vector3(0, 1.52, z + 0.2), Vector3.ZERO, lintel)
	var void_m := _mat(SHADOW, 0.95)
	void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box_mi(Vector3(2.35, 2.05, 0.08), Vector3(0, -0.2, z + 0.32), Vector3.ZERO, void_m)
	var step_y := -2.62
	for i in range(3):
		var sw := 3.8 + float(i) * 0.45
		var sh := 0.18
		var sd := 0.85 + float(i) * 0.15
		var sy := step_y + float(i) * sh
		var sz := 5.35 + float(i) * 0.12
		_box_mi(Vector3(sw, sh, sd), Vector3(0, sy, sz), Vector3.ZERO, _mat(STONE_DARK, 0.92))


func _build_roof_cap() -> void:
	var m := _mat(TRIM, 0.68, 0.15)
	var deck_top: float = 2.58 + 1.25 * 0.5
	var merlon_top: float = deck_top + 0.48
	var roof_h := 0.35
	var roof_y: float = merlon_top + roof_h * 0.5
	_box_mi(Vector3(5.2, roof_h, 5.2), Vector3(0, roof_y, 0), Vector3.ZERO, m)
	var sp := _mat(STONE_DARK, 0.75)
	var spire_h := 0.55
	_box_mi(Vector3(1.1, spire_h, 1.1), Vector3(0, roof_y + roof_h * 0.5 + spire_h * 0.5, 0), Vector3.ZERO, sp)


func _build_banner() -> void:
	var pole := _mat(TRIM, 0.6, 0.2)
	_cyl_mi(0.06, 2.4, Vector3(0, 2.35, -4.25), Vector3.ZERO, pole)
	var cloth := _mat(Color(0.22, 0.38, 0.72), 0.75)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.85, 0.55, 0.04)
	mi.mesh = bm
	mi.position = Vector3(0.42, 3.95, -4.25)
	mi.rotation_degrees = Vector3(0, 0, -8)
	mi.set_surface_override_material(0, cloth)
	add_child(mi)
