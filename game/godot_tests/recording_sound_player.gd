class_name RecordingSoundPlayer
extends SoundPlayer

## Test double for `ui_flow_test.gd`'s sound cases: records which cues fired
## instead of touching audio, so a case can assert on `played` without a live
## AudioStreamPlayer or the wavs being present.

var played: Array[int] = []


func play(cue: int) -> void:
	if not allow_sound:
		return
	played.append(cue)
