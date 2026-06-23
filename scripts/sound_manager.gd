extends Node
## Autoload: one-shots, looped footsteps, cooldowns, pitch ±5%, optional start delay up to 20ms.

# ── Kept keys (repointed to сегодняшние ассеты; старые файлы удалены) ──────────
const KEY_GRASS_WALK := &"grass_walk"   # footstep loop → new flac
const KEY_HIT_WOOD := &"hit_wood"       # → woodcutter wood hit
const KEY_HIT_STONE := &"hit_stone"     # → pick-on-rock
const KEY_HIT_CHEST := &"hit_chest"     # → coin/treasure

# ── New single-file SFX (Sprint 4) ────────────────────────────────────────────
const KEY_GAME_OVER         := &"game_over"
const KEY_VICTORY           := &"victory"
const KEY_TOWER_PHYS_SHOOT  := &"tower_phys_shoot"
const KEY_TOWER_MAGIC_SHOOT := &"tower_magic_shoot"
const KEY_BUILD_PLACE       := &"build_place"      # hammer hit (played x3)
const KEY_BUILD_UPGRADE     := &"build_upgrade"
const KEY_WORKER_MINE       := &"worker_mine"
const KEY_WOOD_CHOP         := &"wood_chop"
const KEY_TREE_FALL         := &"tree_fall"
const KEY_GIANT_DEATH       := &"giant_death"
const KEY_KNIGHT_DEATH      := &"knight_death"
const KEY_ENEMY_PAIN_ZOMBIE := &"enemy_pain_zombie"
const KEY_ENEMY_PAIN_GOLEM  := &"enemy_pain_golem"
const KEY_ENEMY_PAIN_DEMON  := &"enemy_pain_demon"
const KEY_ENEMY_PAIN_BOSS   := &"enemy_pain_boss"
const KEY_ENEMY_DEATH_ZOMBIE := &"enemy_death_zombie"
const KEY_ENEMY_DEATH_GOLEM  := &"enemy_death_golem"
const KEY_ENEMY_DEATH_DEMON  := &"enemy_death_demon"
const KEY_ENEMY_DEATH_BOSS   := &"enemy_death_boss"

# ── UI sounds (separate UI bus) ───────────────────────────────────────────────
const KEY_UI_CLICK  := &"ui_click"
const KEY_UI_SWITCH := &"ui_switch"

# ── Multi-variant groups (random pick per play) ───────────────────────────────
const KEY_SWORD_ATTACK    := &"sword_attack"     # Knight / Giant melee
const KEY_PROJECTILE_HIT  := &"projectile_hit"   # tower bolt impact
const KEY_KNIGHT_PAIN     := &"knight_pain"
const KEY_COMMANDER_ENTER := &"commander_enter"  # door open
const KEY_COMMANDER_EXIT  := &"commander_exit"   # door close

## Single-file SFX as full res:// paths (subfolders / special chars).
const _NEW_FILES: Dictionary = {
	# Repointed legacy keys → сегодняшние аналоги (старые файлы удалены).
	KEY_GRASS_WALK: "res://assets/audio/sfx/sfx_step_grass_l.flac",
	KEY_HIT_WOOD:   "res://assets/audio/sfx/allies/woodcutter/sfx100v2_wood_hit_01.ogg",
	KEY_HIT_STONE:  "res://assets/audio/sfx/allies/worker/Pick Hitting Rock(1).wav",
	KEY_HIT_CHEST:  "res://assets/audio/sfx/constructions/upgarde/Picked Coin Echo.wav",
	KEY_GAME_OVER:          "res://assets/audio/sfx/game_over.wav",
	KEY_VICTORY:            "res://assets/audio/sfx/Won!.wav",
	KEY_TOWER_PHYS_SHOOT:   "res://assets/audio/sfx/towers/default tower shoot.wav",
	KEY_TOWER_MAGIC_SHOOT:  "res://assets/audio/sfx/towers/magic tower shoot.wav",
	KEY_BUILD_PLACE:        "res://assets/audio/sfx/constructions/sfx100v2_wood_hit_02.ogg",
	KEY_BUILD_UPGRADE:      "res://assets/audio/sfx/constructions/upgarde/Picked Coin Echo.wav",
	KEY_WORKER_MINE:        "res://assets/audio/sfx/allies/worker/Pick Hitting Rock(1).wav",
	KEY_WOOD_CHOP:          "res://assets/audio/sfx/allies/woodcutter/sfx100v2_wood_hit_01.ogg",
	KEY_TREE_FALL:          "res://assets/audio/sfx/allies/woodcutter/chop-tree-fall.ogg",
	KEY_GIANT_DEATH:        "res://assets/audio/sfx/allies/gian warrior/die2.wav",
	KEY_KNIGHT_DEATH:       "res://assets/audio/sfx/allies/knight/deathh.wav",
	KEY_ENEMY_PAIN_ZOMBIE:  "res://assets/audio/sfx/monsters/zombie/paind.wav",
	KEY_ENEMY_PAIN_GOLEM:   "res://assets/audio/sfx/monsters/golem/painp.wav",
	KEY_ENEMY_PAIN_DEMON:   "res://assets/audio/sfx/monsters/demon/painr.wav",
	KEY_ENEMY_PAIN_BOSS:    "res://assets/audio/sfx/monsters/boss/pains.wav",
	KEY_ENEMY_DEATH_ZOMBIE: "res://assets/audio/sfx/monsters/zombie/deathd.wav",
	KEY_ENEMY_DEATH_GOLEM:  "res://assets/audio/sfx/monsters/golem/deathb.wav",
	KEY_ENEMY_DEATH_DEMON:  "res://assets/audio/sfx/monsters/demon/deathr.wav",
	KEY_ENEMY_DEATH_BOSS:   "res://assets/audio/sfx/monsters/boss/deathb.wav",
	KEY_UI_CLICK:           "res://assets/ui/UI audio/click1.ogg",
	KEY_UI_SWITCH:          "res://assets/ui/UI audio/switch2.ogg",
}

## Multi-variant groups → list of res:// paths; one is chosen at random per play.
const _GROUP_FILES: Dictionary = {
	KEY_SWORD_ATTACK: [
		"res://assets/audio/sfx/Socapex - Swordsmall_1.wav",
		"res://assets/audio/sfx/Socapex - Swordsmall_2.wav",
		"res://assets/audio/sfx/Socapex - Swordsmall_3.wav",
	],
	KEY_PROJECTILE_HIT: [
		"res://assets/audio/sfx/Socapex - new_hits_2.wav",
		"res://assets/audio/sfx/Socapex - new_hits_3.wav",
		"res://assets/audio/sfx/Socapex - new_hits_4.wav",
	],
	KEY_KNIGHT_PAIN: [
		"res://assets/audio/sfx/allies/knight/pain1.wav",
		"res://assets/audio/sfx/allies/knight/pain2.wav",
		"res://assets/audio/sfx/allies/knight/pain3.wav",
		"res://assets/audio/sfx/allies/knight/pain4.wav",
		"res://assets/audio/sfx/allies/knight/pain5.wav",
		"res://assets/audio/sfx/allies/knight/pain6.wav",
	],
	KEY_COMMANDER_ENTER: [
		"res://assets/audio/sfx/base/qubodup-DoorOpen01.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen02.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen03.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen04.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen05.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen06.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen07.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen08.ogg",
	],
	KEY_COMMANDER_EXIT: [
		"res://assets/audio/sfx/base/qubodup-DoorClose01.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose02.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose03.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose04.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose05.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose06.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose07.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose08.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose09.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorClose10.ogg",
	],
}

## Extra dB per one-shot (negative = quieter vs user `sfx_volume_db`).
const _VOL_DB: Dictionary = {
	KEY_HIT_WOOD: -12.0,
	KEY_HIT_STONE: -12.0,
	KEY_HIT_CHEST: -13.0,
	KEY_GAME_OVER: 0.0,
	KEY_VICTORY: 0.0,
	KEY_TOWER_PHYS_SHOOT: -14.0,
	KEY_TOWER_MAGIC_SHOOT: -14.0,
	KEY_PROJECTILE_HIT: -13.0,
	KEY_BUILD_PLACE: -8.0,
	KEY_BUILD_UPGRADE: -6.0,
	KEY_WORKER_MINE: -12.0,
	KEY_WOOD_CHOP: -12.0,
	KEY_TREE_FALL: -10.0,
	KEY_SWORD_ATTACK: -10.0,
	KEY_KNIGHT_PAIN: -8.0,
	KEY_KNIGHT_DEATH: -6.0,
	KEY_GIANT_DEATH: -5.0,
	KEY_ENEMY_PAIN_ZOMBIE: -9.0,
	KEY_ENEMY_PAIN_GOLEM: -9.0,
	KEY_ENEMY_PAIN_DEMON: -9.0,
	KEY_ENEMY_PAIN_BOSS: -7.0,
	KEY_ENEMY_DEATH_ZOMBIE: -7.0,
	KEY_ENEMY_DEATH_GOLEM: -6.0,
	KEY_ENEMY_DEATH_DEMON: -6.0,
	KEY_ENEMY_DEATH_BOSS: -4.0,
	KEY_COMMANDER_ENTER: -4.0,
	KEY_COMMANDER_EXIT: -4.0,
}

## Minimum seconds between same key (anti-spam).
const _COOLDOWN: Dictionary = {
	KEY_HIT_WOOD: 0.06,
	KEY_HIT_STONE: 0.06,
	KEY_HIT_CHEST: 0.07,
}

## Общая громкость эффектов (dB). По умолчанию тихо; меню паузы крутит это как «Sound» 0–100 %.
var sfx_volume_db: float = -36.0
## UI-звуки независимы от тихого игрового слайдера — слышны по умолчанию.
var ui_volume_db: float = -10.0

const _FOOT_RELATIVE_DB := -18.0

# Audio buses: SFX и UI создаются в рантайме и направляются в Master.
const BUS_MASTER := &"Master"
const BUS_SFX    := &"SFX"
const BUS_UI     := &"UI"

var _streams: Dictionary = {}      # key -> AudioStream (single)
var _groups: Dictionary = {}       # key -> Array[AudioStream] (random variants)
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_pool_i: int = 0
var _foot: AudioStreamPlayer
var _cd_until: Dictionary = {}
var _punch_last_ms: int = 0
var _punch_last_id: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_streams()
	for j in 14:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)
	for j in 6:
		var u := AudioStreamPlayer.new()
		u.bus = BUS_UI
		add_child(u)
		_ui_pool.append(u)
	_foot = AudioStreamPlayer.new()
	_foot.name = &"FootstepLoop"
	_foot.bus = BUS_SFX
	_foot.volume_db = sfx_volume_db + _FOOT_RELATIVE_DB
	var gs_base: AudioStreamWAV = _streams.get(KEY_GRASS_WALK) as AudioStreamWAV
	if gs_base != null:
		var gs: AudioStreamWAV = gs_base.duplicate() as AudioStreamWAV
		gs.loop_mode = AudioStreamWAV.LOOP_FORWARD
		gs.loop_begin = 0
		var mr: int = int(gs.mix_rate)
		if mr <= 0:
			mr = 44100
		gs.loop_end = maxi(1, int(mr * gs.get_length()))
		_foot.stream = gs
	add_child(_foot)


## Создаёт шины SFX и UI (если их нет) и направляет их в Master.
func _ensure_buses() -> void:
	for bus_name in [BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()                 # append at end
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)


func _load_streams() -> void:
	# 1. Одиночные файлы (полные res:// пути).
	for k in _NEW_FILES.keys():
		var st2 := _try_load(str(_NEW_FILES[k]))
		if st2 != null:
			_streams[k] = st2
	# 2. Группы вариантов.
	for k in _GROUP_FILES.keys():
		var arr: Array[AudioStream] = []
		for p in _GROUP_FILES[k]:
			var st := _try_load(str(p))
			if st != null:
				arr.append(st)
		if not arr.is_empty():
			_groups[k] = arr


func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("SoundManager: missing %s" % path)
		return null
	return load(path) as AudioStream


func _process(_delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.paused:
		set_grass_walk_loop(false)


## Как слайдер музыки: 0 = mute, 100 ≈ 0 dB (на ползунке — «максимум»).
func set_sfx_volume_slider_percent(value: float) -> void:
	var v := clampf(value / 100.0, 0.0, 1.0)
	if v <= 0.0001:
		sfx_volume_db = -80.0
	else:
		sfx_volume_db = linear_to_db(v)
	if _foot and _foot.playing:
		_foot.volume_db = sfx_volume_db + _FOOT_RELATIVE_DB + randf_range(-0.6, 0.6)


func get_sfx_volume_slider_percent() -> float:
	if sfx_volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(sfx_volume_db) * 100.0, 0.0, 100.0)


## Looping grass footsteps; safe to call every frame.
func set_grass_walk_loop(active: bool) -> void:
	if _foot == null or _foot.stream == null:
		return
	if active:
		if not _foot.playing:
			_foot.volume_db = sfx_volume_db + _FOOT_RELATIVE_DB + randf_range(-0.8, 0.8)
			_foot.pitch_scale = randf_range(0.97, 1.03)
			_foot.play()
	else:
		if _foot.playing:
			_foot.stop()


func play_one_shot(
	key: StringName,
	cooldown_override: float = -1.0,
	extra_db: float = 0.0,
	pitch_min: float = 0.95,
	pitch_max: float = 1.05
) -> void:
	if not _streams.has(key):
		return
	var cd := cooldown_override
	if cd < 0.0:
		cd = float(_COOLDOWN.get(key, 0.05))
	var now := Time.get_ticks_msec() * 0.001
	if float(_cd_until.get(key, 0.0)) > now:
		return
	_cd_until[key] = now + cd
	var delay := randf_range(0.0, 0.02)
	if delay < 0.001:
		_play_one_shot_impl(key, extra_db, pitch_min, pitch_max)
	else:
		get_tree().create_timer(delay).timeout.connect(
			func(): _play_one_shot_impl(key, extra_db, pitch_min, pitch_max),
			CONNECT_ONE_SHOT
		)


func _play_one_shot_impl(key: StringName, extra_db: float, pitch_lo: float, pitch_hi: float) -> void:
	var st: AudioStream = _streams.get(key) as AudioStream
	if st == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	if p.playing:
		p.stop()
	p.stream = st
	p.volume_db = sfx_volume_db + float(_VOL_DB.get(key, 0.0)) + extra_db
	p.pitch_scale = randf_range(pitch_lo, pitch_hi)
	p.play()


## Punch with light debounce per target instance (same frame overlap).
## Удар по цели (дебаунс на инстанс). Старый punch.wav удалён — используем
## сегодняшний impact (Socapex new_hits).
func play_punch_for_target(target_id: int, extra_db: float = 0.0) -> void:
	var ms := Time.get_ticks_msec()
	if target_id >= 0 and target_id == _punch_last_id and (ms - _punch_last_ms) < 110:
		return
	_punch_last_id = target_id
	_punch_last_ms = ms
	play_random(KEY_PROJECTILE_HIT, 0.05, extra_db)


## Общий звук удара/импакта (Socapex new_hits) — замена удалённым punch/shield_hit.
func play_impact(extra_db: float = 0.0) -> void:
	play_random(KEY_PROJECTILE_HIT, 0.05, extra_db)


## Смерть NPC. Выделенного звука для рабочих в сегодняшних ассетах нет —
## проигрываем impact как финальный удар (см. отчёт, ручная проверка).
func play_npc_death(extra_db: float = 0.0) -> void:
	play_random(KEY_PROJECTILE_HIT, 0.06, extra_db)


# ═══════════════════════════════════════════════════════════════════════════════
# NEW SFX (Sprint 4)
# ═══════════════════════════════════════════════════════════════════════════════

## Воспроизводит случайный вариант из группы на SFX-пуле.
func play_random(
	key: StringName,
	cooldown: float = 0.05,
	extra_db: float = 0.0,
	pitch_min: float = 0.95,
	pitch_max: float = 1.05
) -> void:
	var arr: Array = _groups.get(key, [])
	if arr.is_empty():
		return
	var now := Time.get_ticks_msec() * 0.001
	if float(_cd_until.get(key, 0.0)) > now:
		return
	_cd_until[key] = now + cooldown
	var st: AudioStream = arr[randi() % arr.size()] as AudioStream
	_play_stream_sfx(st, sfx_volume_db + float(_VOL_DB.get(key, 0.0)) + extra_db, pitch_min, pitch_max)


func _play_stream_sfx(st: AudioStream, vol_db: float, pitch_lo: float, pitch_hi: float) -> void:
	if st == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	if p.playing:
		p.stop()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = randf_range(pitch_lo, pitch_hi)
	p.play()


# ── Enemies (per kind: enemy.gd Kind enum) ────────────────────────────────────

func _enemy_key(kind: int, pain: bool) -> StringName:
	# Kind: NORMAL=0, BIG=1, BOSS=2, GOLEM=3, DEMON=4, BAT_PIG=5
	match kind:
		2:  return KEY_ENEMY_PAIN_BOSS  if pain else KEY_ENEMY_DEATH_BOSS
		3:  return KEY_ENEMY_PAIN_GOLEM if pain else KEY_ENEMY_DEATH_GOLEM
		4:  return KEY_ENEMY_PAIN_DEMON if pain else KEY_ENEMY_DEATH_DEMON
		_:  return KEY_ENEMY_PAIN_ZOMBIE if pain else KEY_ENEMY_DEATH_ZOMBIE


func play_enemy_pain(kind: int) -> void:
	play_one_shot(_enemy_key(kind, true), 0.08, 0.0, 0.94, 1.06)


func play_enemy_death(kind: int) -> void:
	play_one_shot(_enemy_key(kind, false), 0.05, 0.0, 0.95, 1.05)


# ── Allies ────────────────────────────────────────────────────────────────────

func play_sword_attack(extra_db: float = 0.0) -> void:
	play_random(KEY_SWORD_ATTACK, 0.10, extra_db, 0.92, 1.06)


func play_knight_pain() -> void:
	play_random(KEY_KNIGHT_PAIN, 0.12, 0.0, 0.96, 1.05)


func play_knight_death() -> void:
	play_one_shot(KEY_KNIGHT_DEATH, 0.05, 0.0, 0.95, 1.05)


func play_giant_death() -> void:
	play_one_shot(KEY_GIANT_DEATH, 0.05, 0.0, 0.92, 1.0)


# ── Towers ────────────────────────────────────────────────────────────────────

func play_tower_shoot(tower_type: int) -> void:
	# tower_type: 0 = physical, 1 = magic
	var key := KEY_TOWER_MAGIC_SHOOT if tower_type == 1 else KEY_TOWER_PHYS_SHOOT
	play_one_shot(key, 0.04, 0.0, 0.96, 1.05)


func play_projectile_hit(magic: bool = false) -> void:
	play_random(KEY_PROJECTILE_HIT, 0.04, 0.0, 1.05 if magic else 0.92, 1.15 if magic else 1.02)


# ── Workers ───────────────────────────────────────────────────────────────────

func play_worker_mine() -> void:
	play_one_shot(KEY_WORKER_MINE, 0.06, 0.0, 0.95, 1.06)


func play_wood_chop() -> void:
	play_one_shot(KEY_WOOD_CHOP, 0.06, 0.0, 0.95, 1.06)


# ── Construction ──────────────────────────────────────────────────────────────

## Установка здания — тройной удар «молотком» (sfx100v2_wood_hit_02 x3).
func play_build_place() -> void:
	if not _streams.has(KEY_BUILD_PLACE):
		return
	for i in 3:
		var delay := 0.12 * float(i)
		get_tree().create_timer(delay).timeout.connect(
			func() -> void: _play_stream_sfx(
				_streams[KEY_BUILD_PLACE] as AudioStream,
				sfx_volume_db + float(_VOL_DB.get(KEY_BUILD_PLACE, 0.0)),
				0.96, 1.04),
			CONNECT_ONE_SHOT
		)


func play_build_upgrade() -> void:
	play_one_shot(KEY_BUILD_UPGRADE, 0.05, 0.0, 0.98, 1.03)


# ── Waves ─────────────────────────────────────────────────────────────────────

func play_game_over() -> void:
	play_one_shot(KEY_GAME_OVER, 0.5, 0.0, 1.0, 1.0)


func play_victory() -> void:
	play_one_shot(KEY_VICTORY, 0.5, 0.0, 1.0, 1.0)


# ═══════════════════════════════════════════════════════════════════════════════
# UI SOUNDS (UI bus, independent volume)
# ═══════════════════════════════════════════════════════════════════════════════

func _play_ui(key: StringName, extra_db: float, pitch_lo: float, pitch_hi: float) -> void:
	var st: AudioStream = _streams.get(key) as AudioStream
	if st == null:
		return
	var p := _ui_pool[_ui_pool_i]
	_ui_pool_i = (_ui_pool_i + 1) % _ui_pool.size()
	if p.playing:
		p.stop()
	p.stream = st
	p.volume_db = ui_volume_db + extra_db
	p.pitch_scale = randf_range(pitch_lo, pitch_hi)
	p.play()


func play_ui_click() -> void:
	_play_ui(KEY_UI_CLICK, 0.0, 0.99, 1.02)


func play_ui_switch() -> void:
	_play_ui(KEY_UI_SWITCH, 0.0, 0.99, 1.02)


func play_commander_enter() -> void:
	play_random(KEY_COMMANDER_ENTER, 0.1, 0.0, 0.98, 1.03)


func play_commander_exit() -> void:
	play_random(KEY_COMMANDER_EXIT, 0.1, 0.0, 0.98, 1.03)


# ═══════════════════════════════════════════════════════════════════════════════
# VOLUME GROUPS — bus-level API for future sound settings
# ═══════════════════════════════════════════════════════════════════════════════

func set_bus_volume_percent(bus_name: StringName, percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var v := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, -80.0 if v <= 0.0001 else linear_to_db(v))


func get_bus_volume_percent(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	var db := AudioServer.get_bus_volume_db(idx)
	return 0.0 if db <= -79.0 else clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func set_master_volume_percent(percent: float) -> void:
	set_bus_volume_percent(BUS_MASTER, percent)


func set_ui_volume_percent(percent: float) -> void:
	set_bus_volume_percent(BUS_UI, percent)
