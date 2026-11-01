extends MainLoop
## Writes every strike's sounds to WAV files so they can be heard outside the game (D190, docs/06 §6.8).
## The sounds themselves are made in code by game/strike_sounds.gd; this only saves them.
##
## Usage:
##   godot --headless --script res://tools/strike_sounds.gd [-- --only=jab,leg_kick]
##
## Writes build/strike_sounds/<strike>.wav (connected, missed, blocked with a pause between, at the loudness
## the fight plays them: connected as a hard hit) and build/strike_sounds/all_strikes.wav (every strike in turn),
## and build/strike_sounds/fence_rattle.wav (D287: each version of the fence's rattle, hardest slam first) and
## build/strike_sounds/takedown_thud.wav (D288: each version of a takedown's landing).

const OUT_DIR := "res://build/strike_sounds/"
const GAP_SECONDS: float = 0.35
## The damage a connected shot is played at in the files (StrikeSounds.HEAVY_DAMAGE sounds biggest).
const REEL_DAMAGE: int = 10


func _initialize() -> void:
	var only: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for id in arg.get_slice("=", 1).split(","):
				only.append(id.strip_edges())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var started: int = Time.get_ticks_msec()
	var reel := PackedFloat32Array()
	var gap := PackedFloat32Array()
	gap.resize(int(StrikeSounds.RATE * GAP_SECONDS))
	for id: String in StrikeSounds.RECIPES:
		if not only.is_empty() and not only.has(id):
			continue
		var strike := PackedFloat32Array()
		for outcome in StrikeSounds.OUTCOMES:
			var samples: PackedFloat32Array = StrikeSounds.render(StrikeSounds.RECIPES[id], outcome, id.hash())
			var how: Dictionary = StrikeSounds.play_settings(id, outcome, REEL_DAMAGE if outcome == StrikeSounds.CONNECTED else -1)
			var gain: float = db_to_linear(how.db - StrikeSounds.BASE_DB)
			for n in samples.size():
				samples[n] *= gain * 0.8
			strike.append_array(samples)
			strike.append_array(gap)
		StrikeSounds.to_wav(strike).save_to_wav(OUT_DIR + id + ".wav")
		reel.append_array(strike)
		reel.append_array(gap)
		print("%-15s connected · missed · blocked" % id)
	StrikeSounds.to_wav(reel).save_to_wav(OUT_DIR + "all_strikes.wav")
	var rattle := PackedFloat32Array()
	for k in StrikeSounds.RATTLE_KINDS:
		rattle.append_array(StrikeSounds.render_rattle(k + 1))
		rattle.append_array(gap)
	StrikeSounds.to_wav(rattle).save_to_wav(OUT_DIR + "fence_rattle.wav")
	print("fence rattle    %d versions" % StrikeSounds.RATTLE_KINDS)
	var thud := PackedFloat32Array()
	for k in StrikeSounds.THUD_KINDS:
		thud.append_array(StrikeSounds.render_thud(k + 1))
		thud.append_array(gap)
	StrikeSounds.to_wav(thud).save_to_wav(OUT_DIR + "takedown_thud.wav")
	print("takedown thud   %d versions" % StrikeSounds.THUD_KINDS)
	print("Wrote %s in %d ms" % [ProjectSettings.globalize_path(OUT_DIR), Time.get_ticks_msec() - started])


func _process(_delta: float) -> bool:
	return true
