extends Node
## Autoload audio manager (a.k.a. AudioManager).
##
## World SFX are SPATIAL: played through pooled AudioStreamPlayer3D at the event's
## world position and attenuated by distance to the active Camera3D, which Godot
## uses as the audio listener automatically. The same code path works in both the
## FPS view and Commander (top-down) view — whichever camera is `current` is the
## listener, so no mode-specific volume logic is needed.
##
## UI SFX are NON-positional: pooled AudioStreamPlayer, always equal volume.
##
## Public API:
##   play_sfx(group, world_position, extra_db=0.0)  — spatial one-shot
##   play_ui(group)                                 — non-positional one-shot
##   play_build_place(world_position)               — triple "hammer"
##   play_enemy_hurt(kind, pos) / play_enemy_die(kind, pos)
##
## Variation groups: each logical name maps to one or more files; a random
## variant is chosen per play, never repeating the previous one. Combat /
## resource / build / attack / footstep groups get ±5% pitch; UI, victory,
## defeat and commander toggles do not.

# ── Buses ─────────────────────────────────────────────────────────────────────
const BUS_MASTER := &"Master"
const BUS_SFX    := &"SFX"
const BUS_UI     := &"UI"

# ── 3D attenuation (standard Godot distance falloff) ──────────────────────────
const SFX_MAX_DISTANCE := 60.0   # beyond this the source is effectively silent
const SFX_UNIT_SIZE    := 10.0   # reference radius: within ~this, near-full volume
const SFX_ATTENUATION  := AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
const STEP_MAX_DISTANCE := 25.0  # footsteps are local — short range

const _STEPS_DIR := "res://assets/audio/sfx/steps/"

# ── Volumes ───────────────────────────────────────────────────────────────────
## The pause-menu "Sound" slider drives the SFX and UI bus volumes live (see
## set_sfx_volume_slider_percent). Per-play we only apply the group mix trim, so
## the slider affects every world SFX and UI sound immediately and uniformly.
## Music is on the Master bus with its own slider and is unaffected.
## Fixed per-play trim so UI sits a touch under world SFX at the same slider %.
const UI_TRIM_DB := -4.0

# ── Variation groups: logical name → list of res:// paths ─────────────────────
const _GROUPS: Dictionary = {
	# Combat — allies
	"sword_attack": [
		"res://assets/audio/sfx/Socapex - Swordsmall_1.wav",
		"res://assets/audio/sfx/Socapex - Swordsmall_2.wav",
		"res://assets/audio/sfx/Socapex - Swordsmall_3.wav",
	],
	"impact": [
		"res://assets/audio/sfx/Socapex - new_hits_2.wav",
		"res://assets/audio/sfx/Socapex - new_hits_3.wav",
		"res://assets/audio/sfx/Socapex - new_hits_4.wav",
	],
	"knight_hurt": [
		"res://assets/audio/sfx/allies/knight/pain1.wav",
		"res://assets/audio/sfx/allies/knight/pain2.wav",
		"res://assets/audio/sfx/allies/knight/pain3.wav",
		"res://assets/audio/sfx/allies/knight/pain4.wav",
		"res://assets/audio/sfx/allies/knight/pain5.wav",
		"res://assets/audio/sfx/allies/knight/pain6.wav",
	],
	"knight_die": ["res://assets/audio/sfx/allies/knight/deathh.wav"],
	"giant_die":  ["res://assets/audio/sfx/allies/gian warrior/die2.wav"],
	# Combat — enemies (boss/golem hurt replaced with new painb/paine)
	"enemy_hurt_zombie": ["res://assets/audio/sfx/monsters/zombie/paind.wav"],
	"enemy_hurt_golem":  ["res://assets/audio/sfx/monsters/golem/paine.wav"],
	"enemy_hurt_demon":  ["res://assets/audio/sfx/monsters/demon/painr.wav"],
	"enemy_hurt_boss":   ["res://assets/audio/sfx/monsters/boss/painb.wav"],
	"enemy_die_zombie":  ["res://assets/audio/sfx/monsters/zombie/deathd.wav"],
	"enemy_die_golem":   ["res://assets/audio/sfx/monsters/golem/deathb.wav"],
	"enemy_die_demon":   ["res://assets/audio/sfx/monsters/demon/deathr.wav"],
	"enemy_die_boss":    ["res://assets/audio/sfx/monsters/boss/deathb.wav"],
	# Towers
	"tower_shoot_phys":  ["res://assets/audio/sfx/towers/default tower shoot.wav"],
	"tower_shoot_magic": ["res://assets/audio/sfx/towers/magic tower shoot.wav"],
	# Resources
	"mine_rock": ["res://assets/audio/sfx/allies/worker/Pick Hitting Rock(1).wav"],
	"chop_wood": ["res://assets/audio/sfx/allies/woodcutter/sfx100v2_wood_hit_01.ogg"],
	"tree_fall": ["res://assets/audio/sfx/allies/woodcutter/chop-tree-fall.ogg"],
	# Construction
	"build_place":   ["res://assets/audio/sfx/constructions/sfx100v2_wood_hit_02.ogg"],
	"build_upgrade": ["res://assets/audio/sfx/constructions/upgarde/Picked Coin Echo.wav"],
	"hit_chest":     ["res://assets/audio/sfx/constructions/upgarde/Picked Coin Echo.wav"],
	# UI / global (non-positional)
	"ui_click":  ["res://assets/ui/UI audio/click1.ogg"],
	"ui_switch": ["res://assets/ui/UI audio/switch2.ogg"],
	"game_over": ["res://assets/audio/sfx/game_over.wav"],
	"victory":   ["res://assets/audio/sfx/Won!.wav"],
	"commander_enter": [
		"res://assets/audio/sfx/base/qubodup-DoorOpen01.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen02.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen03.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen04.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen05.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen06.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen07.ogg",
		"res://assets/audio/sfx/base/qubodup-DoorOpen08.ogg",
	],
	"commander_exit": [
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

## Non-positional (2D) groups. Everything else is spatial.
const _UI_GROUPS: Array[StringName] = [
	&"ui_click", &"ui_switch", &"commander_enter", &"commander_exit",
]
## 2D groups that follow the SFX volume/bus instead of the UI bus.
## Construction sounds live here too: in Commander Mode they are player-action
## feedback (like button clicks), so they must always be clearly audible rather
## than spatially attenuated across the level.
const _GLOBAL_SFX_GROUPS: Array[StringName] = [
	&"game_over", &"victory", &"build_place", &"build_upgrade",
]

## Groups that do NOT get pitch randomization (UI, jingles, reward/coin).
const _NO_PITCH: Array[StringName] = [
	&"ui_click", &"ui_switch", &"commander_enter", &"commander_exit",
	&"game_over", &"victory", &"build_upgrade", &"hit_chest",
]

## Per-group mix trim (dB). Default 0.
const _VOL_DB: Dictionary = {
	&"tower_shoot_phys": -6.0,
	&"tower_shoot_magic": -6.0,
	&"impact": -4.0,
	&"mine_rock": -3.0,
	&"chop_wood": -3.0,
	&"step_dirt": -8.0, &"step_stone": -8.0, &"step_snow": -8.0,
	&"step_water": -8.0, &"step_wood": -8.0,
}

## Minimum seconds between plays of the same group (anti-spam). Default below.
const _DEFAULT_CD := 0.04

var _streams: Dictionary = {}     # group -> Array[AudioStream]
var _last_idx: Dictionary = {}    # group -> last played variant index (no repeat)
var _cd_until: Dictionary = {}    # group -> next allowed time (sec)

var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool3d_i: int = 0
var _pool2d: Array[AudioStreamPlayer] = []
var _pool2d_i: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_groups()
	_autodiscover_steps()
	for j in 24:
		var p := AudioStreamPlayer3D.new()
		p.bus = BUS_SFX
		p.attenuation_model = SFX_ATTENUATION
		p.unit_size = SFX_UNIT_SIZE
		p.max_distance = SFX_MAX_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for j in 8:
		var u := AudioStreamPlayer.new()
		u.bus = BUS_UI
		add_child(u)
		_pool2d.append(u)


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ensure_buses() -> void:
	for bus_name in [BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)


func _load_groups() -> void:
	for group in _GROUPS.keys():
		var arr: Array[AudioStream] = []
		for path in _GROUPS[group]:
			var st := _try_load(str(path))
			if st != null:
				arr.append(st)
		if not arr.is_empty():
			_streams[StringName(group)] = arr


## Auto-group footstep files by surface name (strip trailing _<n>).
func _autodiscover_steps() -> void:
	var dir := DirAccess.open(_STEPS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.ends_with(".import"):
			continue
		var fname := file.get_basename()          # "stepdirt_3.wav" → "stepdirt_3"
		# group base = name without trailing "_<digits>"  →  stepdirt_3 → stepdirt
		var base := fname
		var us := fname.rfind("_")
		if us != -1 and fname.substr(us + 1).is_valid_int():
			base = fname.substr(0, us)
		var group := StringName("step_" + base.replace("step", ""))  # stepdirt → step_dirt
		var st := _try_load(_STEPS_DIR + file)
		if st == null:
			continue
		if not _streams.has(group):
			_streams[group] = [] as Array[AudioStream]
		(_streams[group] as Array).append(st)


func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing %s" % path)
		return null
	return load(path) as AudioStream


# ── Variant selection (random, no immediate repeat) ───────────────────────────

func _pick_variant(group: StringName) -> AudioStream:
	var arr: Array = _streams.get(group, [])
	if arr.is_empty():
		return null
	if arr.size() == 1:
		return arr[0] as AudioStream
	var prev := int(_last_idx.get(group, -1))
	var idx := randi() % arr.size()
	if idx == prev:
		idx = (idx + 1) % arr.size()
	_last_idx[group] = idx
	return arr[idx] as AudioStream


func _gate(group: StringName, cooldown: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if float(_cd_until.get(group, 0.0)) > now:
		return false
	_cd_until[group] = now + cooldown
	return true


func _pitch_for(group: StringName) -> float:
	if group in _NO_PITCH:
		return 1.0
	return randf_range(0.95, 1.05)


# ── Public: spatial SFX ───────────────────────────────────────────────────────

## Play a world sound at `pos`, attenuated by distance to the active camera.
func play_sfx(group: StringName, pos: Vector3, extra_db: float = 0.0, cooldown: float = _DEFAULT_CD) -> void:
	if not _gate(group, cooldown):
		return
	var st := _pick_variant(group)
	if st == null:
		return
	var p := _pool3d[_pool3d_i]
	_pool3d_i = (_pool3d_i + 1) % _pool3d.size()
	if p.playing:
		p.stop()
	p.global_position = pos
	p.stream = st
	p.max_distance = STEP_MAX_DISTANCE if str(group).begins_with("step_") else SFX_MAX_DISTANCE
	# Master SFX level comes from the SFX bus (Sound slider); here only the mix trim.
	p.volume_db = float(_VOL_DB.get(group, 0.0)) + extra_db
	p.pitch_scale = _pitch_for(group)
	p.play()


## Building placement — triple "hammer" hits as non-positional action feedback
## (clearly audible in Commander Mode). Spaced out so it reads as hammering,
## not a machine-gun burst. `pos` is accepted for call-site compatibility but
## unused — the sound is non-spatial.
func play_build_place(_pos: Vector3 = Vector3.ZERO) -> void:
	for i in 3:
		var delay := 0.28 * float(i)
		get_tree().create_timer(delay).timeout.connect(
			func() -> void: play_ui(&"build_place"),
			CONNECT_ONE_SHOT
		)


# ── Public: enemy helpers (kind → group) ──────────────────────────────────────

const _ENEMY_HURT := {2: &"enemy_hurt_boss", 3: &"enemy_hurt_golem", 4: &"enemy_hurt_demon"}
const _ENEMY_DIE  := {2: &"enemy_die_boss",  3: &"enemy_die_golem",  4: &"enemy_die_demon"}


func play_enemy_hurt(kind: int, pos: Vector3) -> void:
	play_sfx(_ENEMY_HURT.get(kind, &"enemy_hurt_zombie"), pos, 0.0, 0.08)


func play_enemy_die(kind: int, pos: Vector3) -> void:
	play_sfx(_ENEMY_DIE.get(kind, &"enemy_die_zombie"), pos)


# ── Public: non-positional UI / global SFX ────────────────────────────────────

## Play a UI or global sound at constant volume, independent of camera position.
func play_ui(group: StringName) -> void:
	var st := _pick_variant(group)
	if st == null:
		return
	var p := _pool2d[_pool2d_i]
	_pool2d_i = (_pool2d_i + 1) % _pool2d.size()
	if p.playing:
		p.stop()
	p.stream = st
	# Bus volume (Sound slider) supplies the master level; here only per-play trim.
	if group in _GLOBAL_SFX_GROUPS:
		p.bus = BUS_SFX
		p.volume_db = float(_VOL_DB.get(group, 0.0))
	else:
		p.bus = BUS_UI
		p.volume_db = UI_TRIM_DB + float(_VOL_DB.get(group, 0.0))
	p.pitch_scale = _pitch_for(group)
	p.play()


# ── Volume API (pause menu + future settings) ─────────────────────────────────

## Pause-menu "Sound" slider: 0 = mute, 100 ≈ 0 dB. Drives the SFX and UI buses
## live, so the change is heard immediately (e.g. on UI clicks in the menu) and
## applies to every world SFX. Music is on the Master bus and is untouched.
func set_sfx_volume_slider_percent(value: float) -> void:
	set_bus_volume_percent(BUS_SFX, value)
	set_bus_volume_percent(BUS_UI, value)


func get_sfx_volume_slider_percent() -> float:
	return get_bus_volume_percent(BUS_SFX)


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
