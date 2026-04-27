extends Node

## Времена волн от старта сцены (сек): 3 мин, 5 мин, 10 мин, 20 мин.
const WAVE_TIMES_SEC := [180.0, 300.0, 600.0, 1200.0]

const _EnemyScene := preload("res://scenes/enemy.tscn")

const KIND_NORMAL := 0
const KIND_BIG := 1
const KIND_BOSS := 2

## Радиус спавна у края карты (поле 288).
const SPAWN_RADIUS := 132.0

var _elapsed := 0.0
var _wave_spawned: Array[bool] = [false, false, false, false]


func _ready() -> void:
	add_to_group(&"wave_manager")


func _process(delta: float) -> void:
	_elapsed += delta
	for i: int in range(WAVE_TIMES_SEC.size()):
		if _wave_spawned[i]:
			continue
		if _elapsed >= WAVE_TIMES_SEC[i]:
			_spawn_wave_index(i)
			_wave_spawned[i] = true


func skip_next_pending_wave() -> void:
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


func _spawn_one(world: Node, kind: int, angle_offset: float) -> void:
	var e: CharacterBody3D = _EnemyScene.instantiate() as CharacterBody3D
	e.configure(kind)
	world.add_child(e)
	var ang := randf() * TAU + angle_offset
	e.global_position = Vector3(cos(ang) * SPAWN_RADIUS, 0.55, sin(ang) * SPAWN_RADIUS)


func all_waves_spawned() -> bool:
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			return false
	return true


func get_next_wave_index_1based() -> int:
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			return i + 1
	return 0


func get_seconds_until_next_wave() -> float:
	for i: int in range(_wave_spawned.size()):
		if not _wave_spawned[i]:
			return maxf(0.0, WAVE_TIMES_SEC[i] - _elapsed)
	return -1.0


func get_wave_timer_hud_text() -> String:
	var nxt := get_next_wave_index_1based()
	if nxt == 0:
		return "Волны: все отправлены"
	var sec := get_seconds_until_next_wave()
	var s := maxi(0, int(ceil(sec)))
	var m: int = s / 60
	var r: int = s % 60
	return "Волна %d через %d:%02d" % [nxt, m, r]
