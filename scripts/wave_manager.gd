extends Node

## Времена волн от старта сцены (сек): 3 мин, 5 мин, 10 мин, 20 мин.
const WAVE_TIMES_SEC := [180.0, 300.0, 600.0, 1200.0]

const _EnemyScene := preload("res://scenes/enemy.tscn")

const KIND_NORMAL  := 0
const KIND_BIG     := 1
const KIND_BOSS    := 2
const KIND_GOLEM   := 3
const KIND_DEMON   := 4
const KIND_BAT_PIG := 5

const SPAWN_RADIUS := 132.0

var _elapsed := 0.0
var _wave_spawned: Array[bool] = [false, false, false, false]
var _endless_wave := 0
var _next_endless_wave_at := 300.0


func _ready() -> void:
	add_to_group(&"wave_manager")


func _process(delta: float) -> void:
	_elapsed += delta
	if GameState.game_mode == GameState.GAME_MODE_ENDLESS:
		if _elapsed >= _next_endless_wave_at:
			_spawn_endless_wave()
		return
	for i: int in range(WAVE_TIMES_SEC.size()):
		if _wave_spawned[i]:
			continue
		if _elapsed >= WAVE_TIMES_SEC[i]:
			_spawn_wave_index(i)
			_wave_spawned[i] = true


func skip_next_pending_wave() -> void:
	if GameState.game_mode == GameState.GAME_MODE_ENDLESS:
		_spawn_endless_wave()
		return
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			_spawn_wave_index(i)
			_wave_spawned[i] = true
			return


func _spawn_wave_index(idx: int) -> void:
	var world := get_parent()
	if world == null:
		return
	match idx:
		0:
			_spawn_group(world, 10, 0, 0)
		1:
			_spawn_group(world, 15, 0, 0)
		2:
			_spawn_group(world, 20, 2, 0)
		3:
			_spawn_group(world, 25, 5, 1)
	GameState.add_coins(10)


func _spawn_group(world: Node, normal_n: int, big_n: int, boss_n: int) -> void:
	for i: int in normal_n:
		_spawn_one(world, KIND_NORMAL, i * 0.02)
	for j: int in big_n:
		_spawn_one(world, KIND_BIG, 0.15 + j * 0.02)
	for k: int in boss_n:
		_spawn_one(world, KIND_BOSS, 0.35 + k * 0.02)


func _spawn_endless_wave() -> void:
	var world := get_parent()
	if world == null:
		return
	_endless_wave += 1
	match _endless_wave:
		1:
			_spawn_group(world, 10, 0, 0)
			_next_endless_wave_at = _elapsed + 240.0
		2:
			_spawn_group(world, 15, 5, 0)
			_next_endless_wave_at = _elapsed + 240.0
		3:
			_spawn_group(world, 25, 10, 0)
			_next_endless_wave_at = _elapsed + 240.0
		4:
			_spawn_group(world, 25, 10, 1)
			_next_endless_wave_at = _elapsed + 120.0
		_:
			var extra := _endless_wave - 4
			var boss_mul := pow(1.25, float(extra))
			_spawn_group_scaled_boss(world, 25 + extra * 3, 10 + extra * 2, boss_mul)
			_next_endless_wave_at = _elapsed + 120.0
	GameState.add_coins(10)


func _spawn_group_scaled_boss(world: Node, normal_n: int, big_n: int, boss_multiplier: float) -> void:
	for i: int in normal_n:
		_spawn_one(world, KIND_NORMAL, i * 0.02)
	for j: int in big_n:
		_spawn_one(world, KIND_BIG, 0.15 + j * 0.02)
	_spawn_one(world, KIND_BOSS, 0.35, boss_multiplier, boss_multiplier)


func _get_spawn_position() -> Vector3:
	# Спавн только из одной точки — нода EnemySpawn в сцене
	var spawn := get_tree().get_first_node_in_group(&"enemy_spawn") as Node3D
	if spawn != null:
		return spawn.global_position
	# Fallback: старый радиус если нода не найдена
	var ang := randf() * TAU
	var r   := SPAWN_RADIUS * GameState.get_map_scale()
	return Vector3(cos(ang) * r, 0.55, sin(ang) * r)


func _spawn_one(world: Node, kind: int, _angle_offset: float, stat_multiplier: float = 1.0, size_multiplier: float = 1.0) -> void:
	var e: CharacterBody3D = _EnemyScene.instantiate() as CharacterBody3D
	e.configure(kind, stat_multiplier, size_multiplier)
	world.add_child(e)
	var base_pos := _get_spawn_position()
	# Небольшой разброс чтобы враги не стакались в одну точку
	e.global_position = base_pos + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))


func all_waves_spawned() -> bool:
	if GameState.game_mode == GameState.GAME_MODE_ENDLESS:
		return false
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			return false
	return true


func get_next_wave_index_1based() -> int:
	if GameState.game_mode == GameState.GAME_MODE_ENDLESS:
		return _endless_wave + 1
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			return i + 1
	return 0


func get_seconds_until_next_wave() -> float:
	if GameState.game_mode == GameState.GAME_MODE_ENDLESS:
		return maxf(0.0, _next_endless_wave_at - _elapsed)
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			return maxf(0.0, WAVE_TIMES_SEC[i] - _elapsed)
	return -1.0


func get_wave_timer_hud_text() -> String:
	var nxt := get_next_wave_index_1based()
	if nxt == 0:
		return "Waves: all sent"
	var sec := get_seconds_until_next_wave()
	var s := maxi(0, int(ceil(sec)))
	var m: int = s / 60
	var r: int = s % 60
	return "Wave %d in %d:%02d" % [nxt, m, r]
