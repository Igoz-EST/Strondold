extends StaticBody3D

## Слой 1 — земля (рабочий в режиме копки стоит на склоне), 32 — удар меча по шахте.
const LAYER_TERRAIN := 1
const LAYER_BREAKABLE := 32
## Скатывание с холма: низкое трение + лёгкий выталкивающий импульс в _physics_process.
const SLIDE_PUSH := 52.0
const SLIDE_R_MIN := 0.2
const SLIDE_R_MAX := 10.5
## Невидимая цилиндрическая стена вплотную к шахте: шахтеры и враги не проходят внутрь.
const CLIMB_BLOCKER_RADIUS := 6.05
const CLIMB_BLOCKER_HEIGHT := 8.0
const WORK_ANCHOR_Z := CLIMB_BLOCKER_RADIUS + 0.8

const ORE_PER_HIT := 10
const MINE_ORE_MAX := 5000

const BAR_WIDTH := 2.8
const BAR_HEIGHT := 0.22

var ore_remaining: int = MINE_ORE_MAX

var _bar_root: Node3D
var _fill_mesh: MeshInstance3D
var _fill_box: BoxMesh


func _ready() -> void:
	collision_layer = LAYER_TERRAIN | LAYER_BREAKABLE
	collision_mask = 0
	name = &"Mine"
	add_to_group(&"mine")
	var slip := PhysicsMaterial.new()
	slip.friction = 0.02
	slip.bounce = 0.0
	physics_material_override = slip
	set_physics_process(true)

	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 7.0
	col.shape = sp
	col.position = Vector3(0.0, -3.9, 0.0)
	add_child(col)
	_setup_climb_blocker()

	var hill := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 7.0
	sm.height = 14.0
	hill.mesh = sm
	hill.position = col.position
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.44, 0.43, 0.42)
	rock.roughness = 0.93
	hill.set_surface_override_material(0, rock)
	add_child(hill)

	var entrance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 2.0, 0.4)
	entrance.mesh = box
	entrance.position = Vector3(0.0, 0.55, 3.95)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.03)
	dark.roughness = 1.0
	dark.metallic = 0.0
	entrance.set_surface_override_material(0, dark)
	add_child(entrance)

	_setup_ore_bar()


func _setup_climb_blocker() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = CLIMB_BLOCKER_RADIUS
	shape.height = CLIMB_BLOCKER_HEIGHT

	var wall := CollisionShape3D.new()
	wall.name = &"ClimbBlocker"
	wall.shape = shape
	wall.position = Vector3(0.0, CLIMB_BLOCKER_HEIGHT * 0.5 - 0.05, 0.0)
	add_child(wall)


func _setup_ore_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = &"OreBar"
	_bar_root.position = Vector3(0.0, 5.35, 0.0)
	add_child(_bar_root)

	var bg := MeshInstance3D.new()
	var bg_box := BoxMesh.new()
	bg_box.size = Vector3(BAR_WIDTH + 0.08, BAR_HEIGHT + 0.06, 0.06)
	bg.mesh = bg_box
	bg.set_surface_override_material(0, UiStyle.bar_bg_material())
	_bar_root.add_child(bg)

	_fill_mesh = MeshInstance3D.new()
	_fill_box = BoxMesh.new()
	_fill_box.size = Vector3(BAR_WIDTH, BAR_HEIGHT, 0.04)
	_fill_mesh.mesh = _fill_box
	_fill_mesh.set_surface_override_material(0, UiStyle.bar_fill_material(UiStyle.BAR_ORE))
	_fill_mesh.position.z = 0.035
	_bar_root.add_child(_fill_mesh)

	_refresh_mine_bar()


func _physics_process(delta: float) -> void:
	var center := global_transform * Vector3(0.0, -3.9, 0.0)
	var cxz := Vector2(center.x, center.z)
	for node in get_tree().get_nodes_in_group(&"worker"):
		if not (node is CharacterBody3D):
			continue
		var b := node as CharacterBody3D
		var d := Vector2(b.global_position.x, b.global_position.z) - cxz
		var dl := d.length()
		if dl <= SLIDE_R_MIN or dl >= SLIDE_R_MAX:
			continue
		var outward := d / dl
		b.velocity.x += outward.x * SLIDE_PUSH * delta
		b.velocity.z += outward.y * SLIDE_PUSH * delta


func _process(_delta: float) -> void:
	if _bar_root == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_bar_root.look_at(cam.global_position, Vector3.UP)
	_bar_root.rotate_object_local(Vector3.UP, PI)


func get_ore_remaining() -> int:
	return ore_remaining


func _refresh_mine_bar() -> void:
	if _fill_box == null:
		return
	var ratio := clampf(float(ore_remaining) / float(MINE_ORE_MAX), 0.0, 1.0)
	var w := BAR_WIDTH * ratio
	_fill_box.size = Vector3(maxf(w, 0.04), BAR_HEIGHT, 0.04)
	_fill_mesh.position.x = -BAR_WIDTH * 0.5 + _fill_box.size.x * 0.5


func try_extract_worker_batch(max_amount: int) -> int:
	if max_amount <= 0 or ore_remaining <= 0:
		return 0
	var take: int = mini(max_amount, ore_remaining)
	ore_remaining -= take
	_refresh_mine_bar()
	FeedbackFx.show_stone_hit(get_parent(), get_work_anchor_global() + Vector3(0.0, 0.55, 0.0))
	FeedbackFx.show_ore_gain(get_parent(), get_work_anchor_global() + Vector3(0.0, 1.15, 0.0), take)
	return take


func apply_sword_hit(_damage: int = 0, _attacker: Node = null) -> void:
	if ore_remaining <= 0:
		return
	SoundManager.play_one_shot(SoundManager.KEY_HIT_STONE, 0.05, -1.0)
	var take: int = mini(ORE_PER_HIT, ore_remaining)
	ore_remaining -= take
	_refresh_mine_bar()
	if take > 0:
		FeedbackFx.show_stone_hit(get_parent(), get_work_anchor_global() + Vector3(0.0, 0.55, 0.0))
		FeedbackFx.show_ore_gain(get_parent(), get_work_anchor_global() + Vector3(0.0, 1.15, 0.0), take)
		GameState.add_ore(take)


func get_work_anchor_global() -> Vector3:
	return global_transform * Vector3(0.0, 0.55, WORK_ANCHOR_Z)
