extends Node

## Времена волн от старта сцены (сек): 1.5 мин, 3.5 мин, 6 мин, 9 мин, 12 мин, 15 мин.
const WAVE_TIMES_SEC := [90.0, 210.0, 360.0, 540.0, 720.0, 900.0]

const _EnemyScene := preload("res://scenes/enemy.tscn")

const KIND_NORMAL  := 0
const KIND_BIG     := 1
const KIND_BOSS    := 2
const KIND_GOLEM   := 3
const KIND_DEMON   := 4
const KIND_BAT_PIG := 5

const SPAWN_RADIUS := 132.0

var _elapsed := 0.0
var _wave_spawned: Array[bool] = [false, false, false, false, false, false]
var _endless_wave := 0
var _next_endless_wave_at := 300.0

# ── Mission 3 base-assault progression (Age-of-War style) ─────────────────────
const _BATPIG_EARLIEST := 480.0   # 8 min — player can have Skywatch by now
const _DEMON_EARLIEST  := 360.0   # 6 min — player can have Magic Tower by now
const _BOSS_EARLIEST   := 600.0   # 10 min
const _BATPIG_COOLDOWN := 30.0
const _BOSS_COOLDOWN    := 45.0
const _SQUAD_CAP        := 6       # hard cap on units per spawn tick
const _STAT_MUL_CAP     := 2.0     # hard cap on enemy stat scaling
const _INTERVAL_FLOOR   := 3.5     # hard cap on spawn frequency
var _assault_cd     := 2.0         # short delay before the first squad
var _last_boss_t    := -999.0
var _last_batpig_t  := -999.0


func _ready() -> void:
	add_to_group(&"wave_manager")


func _process(delta: float) -> void:
	_elapsed += delta
	# Mission 3 — no waves; the enemy base streams units with rising pressure.
	if GameState.game_mode == GameState.GAME_MODE_MISSION_3:
		if not GameState.game_over and not GameState.enemy_base_down:
			_process_assault(delta)
		return
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


## Спавн дополнительных врагов вне расписания волн (казино ATTACK и т.п.).
## Использует обычную точку спауна и маршрут, как у волн.
func spawn_extra(normal_n: int) -> void:
	var world := get_parent()
	if world == null:
		return
	for i: int in normal_n:
		_spawn_one(world, KIND_NORMAL, i * 0.02)


# ── Mission 3 assault ─────────────────────────────────────────────────────────

func _process_assault(delta: float) -> void:
	var world := get_parent()
	if world == null:
		return
	_assault_cd -= delta
	if _assault_cd > 0.0:
		return
	_assault_cd = _assault_interval()
	var stat_mul := clampf(1.0 + (_elapsed / 60.0) * 0.07, 1.0, _STAT_MUL_CAP)
	var squad := _build_assault_squad()
	for i: int in squad.size():
		_spawn_one(world, squad[i], 0.0, stat_mul, 1.0)


## Spawn frequency rises over time, with a hard floor.
func _assault_interval() -> float:
	if _elapsed < 180.0:   return 6.0
	elif _elapsed < 360.0: return 5.0
	elif _elapsed < 600.0: return 4.5
	elif _elapsed < 840.0: return 4.0
	return _INTERVAL_FLOOR


## Composition by time tier; size, variety and rare units grow, all capped.
func _build_assault_squad() -> Array[int]:
	var t := _elapsed
	var squad: Array[int] = []
	if t < 180.0:
		# 0–3 min: Normal, rare Big
		squad.append(KIND_NORMAL)
		if randf() < 0.4: squad.append(KIND_NORMAL)
		if randf() < 0.2: squad.append(KIND_BIG)
	elif t < 360.0:
		# 3–6 min: more Big, first Golem
		squad.append(KIND_NORMAL); squad.append(KIND_NORMAL)
		if randf() < 0.6: squad.append(KIND_BIG)
		if randf() < 0.35: squad.append(KIND_GOLEM)
	elif t < 600.0:
		# 6–10 min: Golem stable, first Demon
		squad.append(KIND_NORMAL); squad.append(KIND_NORMAL)
		if randf() < 0.7: squad.append(KIND_BIG)
		squad.append(KIND_GOLEM)
		if t >= _DEMON_EARLIEST and randf() < 0.35: squad.append(KIND_DEMON)
	elif t < 840.0:
		# 10–14 min: Demon, rare Bat Pig, rare Boss
		squad.append(KIND_NORMAL); squad.append(KIND_BIG)
		if randf() < 0.8: squad.append(KIND_GOLEM)
		if randf() < 0.6: squad.append(KIND_DEMON)
		_maybe_batpig(squad, 0.35)
		_maybe_boss(squad, 0.25)
	else:
		# 14+ min: max progression, mixed groups, Boss within its cooldown
		squad.append(KIND_NORMAL); squad.append(KIND_BIG); squad.append(KIND_GOLEM)
		if randf() < 0.7: squad.append(KIND_DEMON)
		if randf() < 0.5: squad.append(KIND_BIG)
		_maybe_batpig(squad, 0.4)
		_maybe_boss(squad, 0.35)
	if squad.size() > _SQUAD_CAP:
		squad.resize(_SQUAD_CAP)
	return squad


func _maybe_batpig(squad: Array[int], chance: float) -> void:
	if _elapsed >= _BATPIG_EARLIEST and (_elapsed - _last_batpig_t) >= _BATPIG_COOLDOWN and randf() < chance:
		squad.append(KIND_BAT_PIG)
		_last_batpig_t = _elapsed


func _maybe_boss(squad: Array[int], chance: float) -> void:
	if _elapsed >= _BOSS_EARLIEST and (_elapsed - _last_boss_t) >= _BOSS_COOLDOWN and randf() < chance:
		squad.append(KIND_BOSS)
		_last_boss_t = _elapsed


func _spawn_wave_index(idx: int) -> void:
	var world := get_parent()
	if world == null:
		return
	match idx:
		0:
			_spawn_group(world, 8,  0, 0, 0, 0, 0)
			GameState.add_coins(10)
		1:
			_spawn_group(world, 12, 3, 0, 0, 0, 0)
			GameState.add_coins(10)
		2:
			_spawn_group(world, 14, 4, 0, 3, 0, 0)
			GameState.add_coins(15)
		3:
			_spawn_group(world, 18, 5, 1, 2, 0, 0)
			GameState.add_coins(15)
		4:
			_spawn_group(world, 20, 6, 0, 0, 4, 2)
			GameState.add_coins(20)
		5:
			_spawn_group(world, 25, 8, 2, 4, 4, 3)
			GameState.add_coins(25)


func _spawn_group(world: Node, normal_n: int, big_n: int, boss_n: int,
		golem_n: int = 0, demon_n: int = 0, bat_pig_n: int = 0) -> void:
	for i: int in normal_n:
		_spawn_one(world, KIND_NORMAL,  i * 0.02)
	for j: int in big_n:
		_spawn_one(world, KIND_BIG,     0.15 + j * 0.02)
	for k: int in boss_n:
		_spawn_one(world, KIND_BOSS,    0.35 + k * 0.02)
	for l: int in golem_n:
		_spawn_one(world, KIND_GOLEM,   0.55 + l * 0.02)
	for m: int in demon_n:
		_spawn_one(world, KIND_DEMON,   0.75 + m * 0.02)
	for n: int in bat_pig_n:
		_spawn_one(world, KIND_BAT_PIG, 0.95 + n * 0.02)


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
	var xoff     := randf_range(-2.0, 2.0)
	var zoff     := randf_range(-2.0, 2.0)
	var spawn_y  := base_pos.y
	if GameState.is_terrain_mission():
		# On HTerrain the surface is uneven; sample the exact spawn XZ so enemies
		# never appear inside or below the terrain.
		spawn_y = _terrain_y_at(base_pos.x + xoff, base_pos.z + zoff) + 0.55
	e.global_position = Vector3(base_pos.x + xoff, spawn_y, base_pos.z + zoff)
	# M2/M3: assign EnemyPath so enemies follow the designer-placed path
	var path := get_tree().get_first_node_in_group(&"m2_enemy_path") as Path3D
	if path != null and e.has_method(&"assign_path"):
		e.call(&"assign_path", path)


## Downward raycast returning terrain Y at a given XZ (Mission 2 only).
## Uses get_parent() as Node3D for World3D access since WaveManager is a Node.
func _terrain_y_at(x: float, z: float) -> float:
	var parent := get_parent() as Node3D
	if parent == null:
		return 0.0
	var space := parent.get_world_3d().direct_space_state
	var q     := PhysicsRayQueryParameters3D.create(
		Vector3(x, 300.0, z), Vector3(x, -50.0, z), 1)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.0


func all_waves_spawned() -> bool:
	if GameState.game_mode == GameState.GAME_MODE_ENDLESS:
		return false
	if GameState.game_mode == GameState.GAME_MODE_MISSION_3:
		return false  # no waves — victory is the enemy base falling
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
	if GameState.game_mode == GameState.GAME_MODE_MISSION_3:
		return ""  # Mission 3 has no waves; HUD shows base HP instead
	var nxt := get_next_wave_index_1based()
	if nxt == 0:
		return "Waves: all sent"
	var sec := get_seconds_until_next_wave()
	var s := maxi(0, int(ceil(sec)))
	var m: int = s / 60
	var r: int = s % 60
	return "Wave %d in %d:%02d" % [nxt, m, r]
