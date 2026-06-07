extends Node3D

const _BREAKABLE = preload("res://scenes/breakable.tscn")
const _MINE      = preload("res://scenes/mine.tscn")

const _BASE_XZ    := Vector2(250.95, 369.29)
const _ENEMY_XZ   := Vector2(255.31, 88.43)
const BASE_CLEAR  := 50.0
const ENEMY_CLEAR := 25.0
const PATH_CLEAR  := 18.0
const PATH_CLEAR_SQ := PATH_CLEAR * PATH_CLEAR

const _WAYPOINTS: Array = [
	Vector2(254.89,  86.26), Vector2(258.70, 121.71), Vector2(271.66, 136.19),
	Vector2(293.66, 140.41), Vector2(321.92, 137.72), Vector2(336.48, 155.34),
	Vector2(335.40, 176.57), Vector2(316.75, 190.08), Vector2(281.74, 193.79),
	Vector2(239.84, 196.07), Vector2(231.87, 218.60), Vector2(250.76, 248.42),
	Vector2(267.58, 257.30), Vector2(309.82, 261.85), Vector2(351.53, 272.64),
	Vector2(341.36, 294.19), Vector2(315.45, 313.08), Vector2(275.11, 313.14),
	Vector2(248.73, 316.28), Vector2(247.62, 357.93),
]

var _path_segs: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if GameState.game_mode != GameState.GAME_MODE_MISSION_2:
		return
	_build_segs()
	call_deferred(&"_spawn_resources")


func _build_segs() -> void:
	for i in range(_WAYPOINTS.size() - 1):
		_path_segs.append([_WAYPOINTS[i], _WAYPOINTS[i + 1]])


func _spawn_resources() -> void:
	_rng.seed = 99271

	for i in 18:
		var xz := _sample_valid()
		if xz == Vector2.INF:
			continue
		var inst: Node3D = _BREAKABLE.instantiate()
		inst.set("is_tree", true)
		_place(inst, xz)

	for i in 14:
		var xz := _sample_valid()
		if xz == Vector2.INF:
			continue
		var inst: Node3D = _BREAKABLE.instantiate()
		inst.set("is_tree", false)
		_place(inst, xz)

	for i in 3:
		var xz := _sample_valid()
		if xz == Vector2.INF:
			continue
		var inst: Node3D = _MINE.instantiate()
		_place(inst, xz)


func _place(inst: Node3D, xz: Vector2) -> void:
	var root := get_parent()
	root.add_child(inst)
	var ty := _terrain_y(Vector3(xz.x, 0.0, xz.y))
	inst.global_position = Vector3(xz.x, ty, xz.y)
	inst.rotation_degrees.y = _rng.randf_range(0.0, 360.0)


func _sample_valid() -> Vector2:
	for _attempt in 64:
		var p := Vector2(
			_rng.randf_range(90.0, 410.0),
			_rng.randf_range(90.0, 410.0)
		)
		if _is_valid(p):
			return p
	return Vector2.INF


func _is_valid(p: Vector2) -> bool:
	if p.distance_to(_BASE_XZ) < BASE_CLEAR:
		return false
	if p.distance_to(_ENEMY_XZ) < ENEMY_CLEAR:
		return false
	for seg in _path_segs:
		if _seg_dist_sq(p, seg[0], seg[1]) < PATH_CLEAR_SQ:
			return false
	return true


func _seg_dist_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.dot(ab)
	var t := clampf(ab.dot(p - a) / len_sq, 0.0, 1.0) if len_sq > 0.0 else 0.0
	return (p - (a + ab * t)).length_squared()


func _terrain_y(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, 500.0, at.z),
		Vector3(at.x, -50.0, at.z),
		1
	)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	return hit.position.y if hit else 0.0
