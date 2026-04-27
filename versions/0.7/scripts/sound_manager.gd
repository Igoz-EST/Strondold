extends Node
## Autoload: one-shots, looped footsteps, cooldowns, pitch ±5%, optional start delay up to 20ms.

const SFX_DIR := "res://assets/audio/sfx/"

const KEY_SWORD_SWING := &"sword_swing"
const KEY_JUMP := &"jump"
const KEY_GRASS_WALK := &"grass_walk"
const KEY_PUNCH := &"punch"
const KEY_NPC_DEATH := &"npc_death"
const KEY_SHIELD_HIT := &"shield_hit"
const KEY_HIT_WOOD := &"hit_wood"
const KEY_HIT_STONE := &"hit_stone"
const KEY_HIT_CHEST := &"hit_chest"

const _FILE_NAMES: Dictionary = {
	KEY_SWORD_SWING: "sword_swing.wav",
	KEY_JUMP: "jump.wav",
	KEY_GRASS_WALK: "grass_walk.wav",
	KEY_PUNCH: "punch.wav",
	KEY_NPC_DEATH: "npc_death.wav",
	KEY_SHIELD_HIT: "shield_hit.wav",
	KEY_HIT_WOOD: "hit_wood.wav",
	KEY_HIT_STONE: "hit_stone.wav",
	KEY_HIT_CHEST: "hit_chest.wav",
}

## Extra dB per one-shot (negative = quieter vs user `sfx_volume_db`).
const _VOL_DB: Dictionary = {
	KEY_SWORD_SWING: -10.0,
	KEY_JUMP: -12.0,
	KEY_PUNCH: -11.0,
	KEY_NPC_DEATH: -8.0,
	KEY_SHIELD_HIT: -11.0,
	KEY_HIT_WOOD: -14.0,
	KEY_HIT_STONE: -13.0,
	KEY_HIT_CHEST: -13.0,
}

## Minimum seconds between same key (anti-spam).
const _COOLDOWN: Dictionary = {
	KEY_SWORD_SWING: 0.12,
	KEY_JUMP: 0.18,
	KEY_GRASS_WALK: 0.02,
	KEY_PUNCH: 0.05,
	KEY_NPC_DEATH: 0.08,
	KEY_SHIELD_HIT: 0.09,
	KEY_HIT_WOOD: 0.06,
	KEY_HIT_STONE: 0.06,
	KEY_HIT_CHEST: 0.07,
}

## Общая громкость эффектов (dB). По умолчанию тихо; меню паузы крутит это как «Sound» 0–100 %.
var sfx_volume_db: float = -36.0

const _FOOT_RELATIVE_DB := -18.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i: int = 0
var _foot: AudioStreamPlayer
var _cd_until: Dictionary = {}
var _punch_last_ms: int = 0
var _punch_last_id: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	for j in 14:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_foot = AudioStreamPlayer.new()
	_foot.name = &"FootstepLoop"
	_foot.bus = &"Master"
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


func _load_streams() -> void:
	for k in _FILE_NAMES.keys():
		var path := SFX_DIR + str(_FILE_NAMES[k])
		if not ResourceLoader.exists(path):
			push_warning("SoundManager: missing %s" % path)
			continue
		var st: AudioStream = load(path) as AudioStream
		if st != null:
			_streams[k] = st


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
func play_punch_for_target(target_id: int, extra_db: float = 0.0) -> void:
	var ms := Time.get_ticks_msec()
	if target_id >= 0 and target_id == _punch_last_id and (ms - _punch_last_ms) < 110:
		return
	_punch_last_id = target_id
	_punch_last_ms = ms
	play_one_shot(KEY_PUNCH, -1.0, extra_db)


func play_npc_death(extra_db: float = 0.0) -> void:
	play_one_shot(KEY_NPC_DEATH, 0.06, extra_db, 0.93, 1.04)
