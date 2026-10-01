class_name SoundPlayer
extends Node

## Plays Beermat's ten wav cues (docs/beermat-re.md, "Sounds") at the events the
## original game plays them. The wavs are copyrighted and never committed
## (`task game:sounds` copies them from gitignored `vendor/dopewars-1999/` into
## gitignored `res://assets/sound/`), so every cue is a no-op when its file is
## absent -- the game must run silently without error on a fresh checkout.
##
## Each `play()` call spawns a transient AudioStreamPlayer rather than keeping
## one player per cue, because two cues can overlap (a cop's return fire follows
## the player's own shot in the same Fight round) and a shared player would cut
## the first one off.

enum Cue {
	CASH_REG,
	LAST_DAY,
	COP_CHASE,
	COP_GUN_SHOT,
	YOU_HIT_BY_GUN,
	YOUR_GUN_SHOT,
	COP_HIT_BY_GUN,
	MUGGED,
	POLICE_DOG,
	DEAD,
}

const _PATHS := {
	Cue.CASH_REG: "res://assets/sound/cashreg.wav",
	Cue.LAST_DAY: "res://assets/sound/uhoh.wav",
	Cue.COP_CHASE: "res://assets/sound/Siren.wav",
	Cue.COP_GUN_SHOT: "res://assets/sound/gun.wav",
	Cue.YOU_HIT_BY_GUN: "res://assets/sound/youhit.wav",
	Cue.YOUR_GUN_SHOT: "res://assets/sound/gun2.wav",
	Cue.COP_HIT_BY_GUN: "res://assets/sound/cophit.wav",
	Cue.MUGGED: "res://assets/sound/hrdpunch.wav",
	Cue.POLICE_DOG: "res://assets/sound/bark.wav",
	Cue.DEAD: "res://assets/sound/wasted.wav",
}

## docs/beermat-re.md: "AllowSound default: on." -- a normal first run writes 1.
var allow_sound := true

## Cached per cue: the loaded stream, or null when the wav is absent. Caches the
## miss too, so a missing file is only probed once per cue rather than once per
## call.
var _streams := {}


func play(cue: int) -> void:
	if not allow_sound:
		return
	var stream := _load(cue)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _load(cue: int) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var path: String = _PATHS.get(cue, "")
	var stream: AudioStream = null
	if not path.is_empty() and ResourceLoader.exists(path):
		stream = ResourceLoader.load(path)
	_streams[cue] = stream
	return stream
