extends Node2D

# ==============================================================================
# BOUNCE BACK - Complete Godot 4 Game Script
# Creators: Mounib Reda, Chingiz Shikhgayibov, Nurazkhan Nygmet
# Enhanced Bosses (Wave 5, Wave 7 Purple Square, Wave 10 Golden Sovereign)
# Crazy Shake & Ground Effects, Clean Non-Robotic Character Select
# ==============================================================================

enum State { MENU, TRANSITION, PLAYING, GAME_OVER, VICTORY }
var state: State = State.MENU

enum Character { BANDIT, SCIENTIST, NURSE }
var selected_character: Character = Character.BANDIT

const VIEW_W := 1280.0
const VIEW_H := 720.0
const GROUND_Y := 630.0

# --- Wave & Transition State ---
var current_wave: int = 1
var transition_alpha: float = 0.0
var transition_phase: int = 0 # 0: delay before fade, 1: fade to black, 2: hold "wave X", 3: fade in
var transition_timer: float = 0.0
var transition_text: String = "wave 1"
var wave_clear_pending: bool = false

# --- Player State (Mini Terraria-style Guy) ---
var player := {
	"pos": Vector2(640.0, 630.0),
	"vel": Vector2.ZERO,
	"w": 22.0,
	"h": 36.0,
	"on_ground": false,
	"hearts": 5,
	"max_hearts": 5,
	"facing": 1,
	"walk_anim": 0.0,
	"parry_active_timer": 0.0,   # Tight parry window (~0.135s)
	"parry_cooldown_timer": 0.0, # Penalty if pressed too early (~0.44s)
	"invuln_timer": 0.0,
	"parry_flash": 0.0,
	"parry_fail_flash": 0.0
}

const GRAVITY := 1350.0
const MOVE_SPEED := 330.0
const JUMP_FORCE := -610.0
const PARRY_WINDOW := 0.135     # Tight, rewarding perfect-parry tolerance!
const PARRY_COOLDOWN := 0.44    # Pressing F too early locks you out so the laser hits you
const PARRY_RADIUS := 72.0      # Deflection reach around player center

# --- Character Abilities State ---
# Bandit: Dash to dodge (Shift), covers big distance, hitbox negation, 5s cooldown
const BANDIT_DASH_CD := 5.0
const BANDIT_DASH_DUR := 0.20
const BANDIT_DASH_SPEED := 980.0
var bandit_dash_cooldown: float = 0.0
var bandit_dashing: bool = false
var bandit_dash_timer: float = 0.0
var bandit_dash_dir: float = 1.0
var dash_ghosts: Array = []
var wind_particles: Array = []

# Scientist: Freeze time for 1s (Shift), freezes enemies & lasers, 10s cooldown
const SCIENTIST_FREEZE_CD := 10.0
const SCIENTIST_FREEZE_DUR := 1.0
var scientist_freeze_cooldown: float = 0.0
var time_freeze_timer: float = 0.0

# Nurse: Regenerates 1 heart every 8s automatically (passive)
const NURSE_REGEN_INTERVAL := 8.0
var nurse_regen_timer: float = 8.0

# --- Map Platforms (One-way jump-through from underneath, leave only via sides) ---
var platforms: Array[Rect2] = [
	Rect2(170, 495, 250, 18),
	Rect2(860, 495, 250, 18),
	Rect2(470, 385, 340, 18),
	Rect2(210, 270, 210, 18),
	Rect2(860, 270, 210, 18)
]

# --- Dynamic Scenery (Geometry Dash Grief Atmosphere + Terraria Underworld/Crimson) ---
var trees: Array = []
var clouds: Array = []
var grass_tufts: Array = []
var fireflies: Array = []
var grief_embers: Array = []
var grief_laser_columns: Array = []
var grief_chains: Array = []
var grief_eyes: Array = []
var grief_pulse_flash: float = 0.0

# --- Entities & Insane Visual Effects ---
var mobs: Array = []
var lasers: Array = []
var particles: Array = []
var floating_texts: Array = []

# Crazy Screen Shake (Intensity + Tilt)
var screen_shake: float = 0.0
var screen_shake_rot: float = 0.0

# Crazy Ground Effects (Shockwaves, Fissures, Flying Rock/Dirt Debris)
var ground_shocks: Array = []
var ground_fissures: Array = []
var ground_debris: Array = []

var mobs_to_spawn: int = 0
var spawn_timer: float = 0.0

# --- Menu & UI State (Clean & Simplified, Non-Robotic) ---
var credits_open: bool = false
var characters_open: bool = false
var boss_warning_timer: float = 0.0
var boss_warning_title: String = ""
var boss_warning_sub: String = ""
var boss_warning_color: Color = Color("ff2a4b")

# --- Developer Console (F1 Key Warp) ---
var console_open: bool = false
var console_input: String = ""
var console_msg: String = "Type wave number (1-10) and press ENTER to warp"

# --- Wave 10 Phase 2 & Boss Transformation State ---
var reached_wave10_phase2: bool = false
var wave10_phase: int = 1
var boss_trans_active: bool = false
var boss_trans_timer: float = 0.0
var boss_trans_flash: float = 0.0
var cinematic_bars_height: float = 0.0
var teleport_ghosts: Array = []
var sci_fi_teleports: Array = []

# Main Menu Buttons
var start_btn_rect := Rect2(470, 310, 340, 66)
var characters_btn_rect := Rect2(470, 395, 340, 66)
var credits_btn_rect := Rect2(470, 480, 340, 66)

# Victory Buttons
var victory_restart_rect := Rect2(360, 440, 260, 60)
var victory_menu_rect := Rect2(660, 440, 260, 60)

# Credits Box
var credits_box_rect := Rect2(350, 180, 580, 370)
var close_credits_center := Vector2(895, 215)
const CLOSE_BTN_RADIUS := 20.0

# Clean Side-by-Side Character Cards
var char_card_rects: Array[Rect2] = [
	Rect2(70, 130, 350, 520),
	Rect2(465, 130, 350, 520),
	Rect2(860, 130, 350, 520)
]
var char_back_center := Vector2(65, 65)
const CHAR_BACK_RADIUS := 24.0

var btn_scales := {
	"start": 1.0,
	"characters": 1.0,
	"credits": 1.0,
	"close": 1.0,
	"char_back": 1.0,
	"card_0": 1.0,
	"card_1": 1.0,
	"card_2": 1.0,
	"vic_restart": 1.0,
	"vic_menu": 1.0
}
var btn_vel := {
	"start": 0.0,
	"characters": 0.0,
	"credits": 0.0,
	"close": 0.0,
	"char_back": 0.0,
	"card_0": 0.0,
	"card_1": 0.0,
	"card_2": 0.0,
	"vic_restart": 0.0,
	"vic_menu": 0.0
}
var btn_hovered := {
	"start": false,
	"characters": false,
	"credits": false,
	"close": false,
	"char_back": false,
	"card_0": false,
	"card_1": false,
	"card_2": false,
	"vic_restart": false,
	"vic_menu": false
}

# --- Procedural Audio (Chiptune Synth + SFX) ---
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var sfx_player: AudioStreamPlayer
var sfx_playback: AudioStreamGeneratorPlayback
var music_phase: float = 0.0
var bass_phase: float = 0.0
var arp_time: float = 0.0
var arp_step: int = 0
var sfx_queue: Array = []

const ARP_NOTES := [
	261.63, 311.13, 392.00, 523.25, 392.00, 311.13, 466.16, 392.00,
	277.18, 349.23, 415.30, 554.37, 415.30, 349.23, 523.25, 415.30
]
const BASS_NOTES := [130.81, 130.81, 155.56, 130.81, 138.59, 138.59, 123.47, 146.83]

# Wave 7 Synthwave Arp (Purple Square Theme)
const ARP_PURPLE := [
	293.66, 349.23, 440.00, 587.33, 440.00, 349.23, 523.25, 440.00,
	329.63, 392.00, 493.88, 659.25, 493.88, 392.00, 587.33, 493.88
]

# Wave 10 Golden Hymn Arp (Soleil Doré Theme)
const ARP_GOLD := [
	329.63, 415.30, 493.88, 659.25, 830.61, 659.25, 493.88, 415.30,
	369.99, 440.00, 554.37, 739.99, 880.00, 739.99, 554.37, 440.00
]

func _ready() -> void:
	randomize()
	_generate_scenery()
	_setup_audio()

func _generate_scenery() -> void:
	trees.clear()
	var tree_positions := [75.0, 210.0, 365.0, 540.0, 745.0, 915.0, 1075.0, 1205.0]
	for tx in tree_positions:
		trees.append({
			"x": tx + randf_range(-18.0, 18.0),
			"h": randf_range(190.0, 320.0),
			"w": randf_range(24.0, 36.0),
			"canopy": randf_range(65.0, 98.0),
			"tint": randf_range(-0.06, 0.06)
		})
	clouds.clear()
	for i in range(9):
		clouds.append({
			"pos": Vector2(randf_range(0, VIEW_W), randf_range(35, 220)),
			"speed": randf_range(10.0, 26.0),
			"scale": randf_range(0.75, 1.45)
		})
	grass_tufts.clear()
	for x in range(12, int(VIEW_W) - 12, 14):
		grass_tufts.append({
			"x": float(x),
			"h": randf_range(6.0, 15.0),
			"lean": randf_range(-4.0, 4.0)
		})
	fireflies.clear()
	for i in range(24):
		fireflies.append({
			"pos": Vector2(randf_range(40, VIEW_W - 40), randf_range(120, GROUND_Y - 20)),
			"phase": randf_range(0, TAU),
			"speed": randf_range(18.0, 40.0)
		})

	grief_embers.clear()
	for i in range(48):
		grief_embers.append({
			"pos": Vector2(randf_range(0, VIEW_W), randf_range(50, VIEW_H)),
			"vel": Vector2(randf_range(-25, 25), randf_range(-65, -130)),
			"size": randf_range(2.0, 5.0),
			"alpha": randf_range(0.3, 0.85),
			"hue": randf_range(0.0, 1.0)
		})

	grief_laser_columns.clear()
	var pillar_xs := [140.0, 320.0, 510.0, 770.0, 960.0, 1140.0]
	for px in pillar_xs:
		grief_laser_columns.append({
			"x": px,
			"width": randf_range(12.0, 28.0),
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(1.8, 3.4),
			"intensity": randf_range(0.12, 0.32)
		})

	grief_chains.clear()
	var chain_xs := [90.0, 270.0, 440.0, 640.0, 840.0, 1030.0, 1210.0]
	for cx in chain_xs:
		grief_chains.append({
			"x": cx,
			"len": randf_range(60.0, 140.0),
			"sway_phase": randf_range(0.0, TAU),
			"crystal_size": randf_range(12.0, 22.0)
		})

	grief_eyes.clear()
	for i in range(8):
		grief_eyes.append({
			"pos": Vector2(randf_range(80, VIEW_W - 80), randf_range(240, 440)),
			"blink_timer": randf_range(1.0, 4.0),
			"is_open": false,
			"open_amount": 0.0
		})

func _setup_audio() -> void:
	music_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.12
	music_player.stream = gen
	music_player.volume_db = -10.0
	add_child(music_player)
	music_player.play()
	music_playback = music_player.get_stream_playback()

	sfx_player = AudioStreamPlayer.new()
	var sfx_gen := AudioStreamGenerator.new()
	sfx_gen.mix_rate = 22050.0
	sfx_gen.buffer_length = 0.1
	sfx_player.stream = sfx_gen
	sfx_player.volume_db = -5.0
	add_child(sfx_player)
	sfx_player.play()
	sfx_playback = sfx_player.get_stream_playback()

func _play_sfx(freq_start: float, freq_end: float, duration: float, wave_type: int = 0) -> void:
	sfx_queue.append({
		"f0": freq_start,
		"f1": freq_end,
		"dur": duration,
		"t": 0.0,
		"phase": 0.0,
		"type": wave_type
	})

func _play_woosh_sfx() -> void:
	_play_sfx(600.0, 180.0, 0.22, 2)

func _play_freeze_sfx() -> void:
	_play_sfx(160.0, 60.0, 0.38, 3)
	_play_sfx(1200.0, 400.0, 0.28, 3)

func _play_heal_sfx() -> void:
	_play_sfx(440.0, 880.0, 0.32, 3)

func _fill_audio_buffers() -> void:
	var mix_rate := 22050.0
	if music_playback:
		var frames := music_playback.get_frames_available()
		var step_dur := 0.115 if state != State.PLAYING else maxf(0.060, 0.115 - current_wave * 0.004)
		if (current_wave in [5, 7, 10]) and state == State.PLAYING:
			step_dur = 0.068

		for i in range(frames):
			arp_time += 1.0 / mix_rate
			if arp_time >= step_dur:
				arp_time -= step_dur
				arp_step = (arp_step + 1) % 16
				if arp_step % 2 == 0:
					grief_pulse_flash = 0.18

			var freq: float = ARP_NOTES[arp_step]
			if current_wave == 7:
				freq = ARP_PURPLE[arp_step]
			elif current_wave == 10:
				freq = ARP_GOLD[arp_step]

			var bass_freq: float = BASS_NOTES[(arp_step / 2) % BASS_NOTES.size()]
			if current_wave in [5, 7] and state == State.PLAYING:
				freq *= 0.8
				bass_freq *= 0.8
			elif current_wave == 10 and state == State.PLAYING:
				freq *= 1.15
				bass_freq *= 0.9

			var env: float = maxf(0.0, 1.0 - (arp_time / step_dur) * 0.75)
			music_phase = fmod(music_phase + freq / mix_rate, 1.0)
			bass_phase = fmod(bass_phase + bass_freq / mix_rate, 1.0)

			var lead: float = (1.0 if music_phase < 0.25 else -1.0) * 0.16 * env
			var bass: float = (absf(bass_phase * 4.0 - 2.0) - 1.0) * 0.20
			var tick: float = (randf() * 2.0 - 1.0) * 0.045 if (arp_step % 2 == 0 and arp_time < 0.012) else 0.0
			var sample: float = clampf(lead + bass + tick, -0.9, 0.9)
			music_playback.push_frame(Vector2(sample, sample))

	if sfx_playback:
		var frames := sfx_playback.get_frames_available()
		for i in range(frames):
			var sample := 0.0
			for j in range(sfx_queue.size() - 1, -1, -1):
				var s = sfx_queue[j]
				s["t"] += 1.0 / mix_rate
				if s["t"] >= s["dur"]:
					sfx_queue.remove_at(j)
					continue
				var prog: float = s["t"] / s["dur"]
				var cur_f: float = lerpf(s["f0"], s["f1"], prog)
				s["phase"] = fmod(s["phase"] + cur_f / mix_rate, 1.0)
				var env: float = 1.0 - prog
				if s["type"] == 0: # Square / Laser / Parry
					sample += (1.0 if s["phase"] < 0.5 else -1.0) * 0.32 * env
				elif s["type"] == 1: # Noise + tone (Hit / Explosion / Slam)
					sample += ((randf() * 2.0 - 1.0) * 0.5 + sin(s["phase"] * TAU) * 0.5) * 0.38 * env
				elif s["type"] == 2: # Wind / Woosh (Bandit Dash)
					var noise := (randf() * 2.0 - 1.0) * 0.44 * sin(prog * PI)
					sample += noise
				elif s["type"] == 3: # Harmonic Sine Chime (Scientist Time / Nurse Heal)
					sample += sin(s["phase"] * TAU) * 0.36 * env
			sample = clampf(sample, -0.95, 0.95)
			sfx_playback.push_frame(Vector2(sample, sample))


# ==============================================================================
# INPUT & MENU LOGIC (CLEAN & NON-ROBOTIC + F1 DEVELOPER CONSOLE)
# ==============================================================================
func _is_boss_wave() -> bool:
	return (current_wave in [5, 7, 10]) or _has_active_boss()

func _has_active_boss() -> bool:
	for m in mobs:
		if m.get("is_boss", false):
			return true
	return false

func _input(event: InputEvent) -> void:
	# F1 DEVELOPER CONSOLE TOGGLE & INPUT HANDLING
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			console_open = not console_open
			if console_open:
				console_input = ""
				console_msg = "Type wave number (1-10) and press ENTER to warp"
			_play_sfx(600.0, 920.0, 0.08, 0)
			return

		if console_open:
			if event.keycode == KEY_ESCAPE:
				console_open = false
				_play_sfx(520.0, 260.0, 0.08, 0)
				return
			elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_execute_console_command(console_input)
				return
			elif event.keycode == KEY_BACKSPACE:
				if console_input.length() > 0:
					console_input = console_input.substr(0, console_input.length() - 1)
					_play_sfx(400.0, 300.0, 0.03, 0)
				return
			else:
				if event.unicode >= 32 and event.unicode <= 126:
					console_input += char(event.unicode)
					_play_sfx(600.0, 750.0, 0.02, 0)
				return

	if console_open:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mpos: Vector2 = get_global_mouse_position()
		if state == State.MENU:
			if credits_open:
				if mpos.distance_to(close_credits_center) <= CLOSE_BTN_RADIUS + 6.0:
					credits_open = false
					_play_sfx(520.0, 260.0, 0.1, 0)
			elif characters_open:
				# Clean Back Button (top-left circle with back arrow)
				if mpos.distance_to(char_back_center) <= CHAR_BACK_RADIUS + 8.0:
					characters_open = false
					_play_sfx(520.0, 260.0, 0.1, 0)
				else:
					# 3 Clean Character Cards Click
					for idx in range(3):
						if char_card_rects[idx].has_point(mpos):
							selected_character = idx as Character
							btn_vel["card_%d" % idx] = 5.5
							_play_sfx(540.0, 960.0, 0.16, 0)
							var card_center: Vector2 = char_card_rects[idx].get_center()
							var burst_col := Color("ff9e2c") if idx == 0 else (Color("41f3ff") if idx == 1 else Color("55ff99"))
							_spawn_burst(card_center, burst_col, 20, 220.0)
							break
			else:
				if start_btn_rect.has_point(mpos):
					_play_sfx(440.0, 880.0, 0.18, 0)
					_begin_game_from_wave_1()
				elif characters_btn_rect.has_point(mpos):
					characters_open = true
					btn_vel["characters"] = 6.5
					_play_sfx(440.0, 720.0, 0.14, 0)
				elif credits_btn_rect.has_point(mpos):
					credits_open = true
					btn_vel["credits"] = 6.5
					_play_sfx(380.0, 620.0, 0.14, 0)

		elif state == State.GAME_OVER:
			if start_btn_rect.has_point(mpos):
				_play_sfx(440.0, 880.0, 0.18, 0)
				if reached_wave10_phase2 or current_wave == 10:
					_jump_to_wave(10, 2 if reached_wave10_phase2 else 1)
				else:
					_begin_game_from_wave_1()
			elif credits_btn_rect.has_point(mpos):
				state = State.MENU
				credits_open = false
				characters_open = false
				_play_sfx(520.0, 320.0, 0.14, 0)

		elif state == State.VICTORY:
			if victory_restart_rect.has_point(mpos):
				_play_sfx(440.0, 880.0, 0.18, 0)
				_begin_game_from_wave_1()
			elif victory_menu_rect.has_point(mpos):
				state = State.MENU
				credits_open = false
				characters_open = false
				_play_sfx(520.0, 320.0, 0.14, 0)

	if event is InputEventKey and event.pressed and not event.echo:
		if state == State.GAME_OVER:
			if event.keycode in [KEY_SPACE, KEY_ENTER]:
				_play_sfx(440.0, 880.0, 0.18, 0)
				if reached_wave10_phase2 or current_wave == 10:
					_jump_to_wave(10, 2 if reached_wave10_phase2 else 1)
				else:
					_begin_game_from_wave_1()
				return
		elif state == State.MENU and characters_open:
			if event.keycode in [KEY_LEFT, KEY_A]:
				selected_character = ((int(selected_character) + 2) % 3) as Character
				_play_sfx(540.0, 780.0, 0.1, 0)
			elif event.keycode in [KEY_RIGHT, KEY_D]:
				selected_character = ((int(selected_character) + 1) % 3) as Character
				_play_sfx(540.0, 780.0, 0.1, 0)
			elif event.keycode in [KEY_ENTER, KEY_SPACE]:
				_play_sfx(540.0, 960.0, 0.18, 0)
			elif event.keycode == KEY_ESCAPE:
				characters_open = false
				_play_sfx(520.0, 260.0, 0.1, 0)
		elif state == State.PLAYING:
			if event.keycode == KEY_F:
				_attempt_parry()
			elif event.keycode in [KEY_SPACE, KEY_W, KEY_UP]:
				_attempt_jump()
			elif event.keycode == KEY_SHIFT:
				_trigger_character_ability()

func _trigger_character_ability() -> void:
	match selected_character:
		Character.BANDIT:
			if bandit_dash_cooldown <= 0.0 and not bandit_dashing:
				bandit_dash_cooldown = BANDIT_DASH_CD
				bandit_dashing = true
				bandit_dash_timer = BANDIT_DASH_DUR
				var h_dir := 0.0
				if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
					h_dir -= 1.0
				if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
					h_dir += 1.0
				bandit_dash_dir = h_dir if h_dir != 0.0 else float(player["facing"])
				player["facing"] = int(sign(bandit_dash_dir)) if bandit_dash_dir != 0.0 else player["facing"]
				player["invuln_timer"] = maxf(player["invuln_timer"], BANDIT_DASH_DUR + 0.08)
				_play_woosh_sfx()
				screen_shake = 4.0
				_add_floating_text("SHADOW DASH!", player["pos"] - Vector2(0, 48), Color("38ffff"))
				for i in range(12):
					wind_particles.append({
						"pos": player["pos"] - Vector2(0, player["h"] * 0.5),
						"vel": Vector2(-bandit_dash_dir * randf_range(160, 420), randf_range(-60, 60)),
						"life": randf_range(0.2, 0.38),
						"max_life": 0.38,
						"size": randf_range(3.0, 7.0)
					})
		Character.SCIENTIST:
			if scientist_freeze_cooldown <= 0.0 and time_freeze_timer <= 0.0:
				scientist_freeze_cooldown = SCIENTIST_FREEZE_CD
				time_freeze_timer = SCIENTIST_FREEZE_DUR
				_play_freeze_sfx()
				screen_shake = 6.0
				_spawn_burst(player["pos"] - Vector2(0, player["h"] * 0.5), Color("41f3ff"), 24, 280.0)
				_add_floating_text("TIME FROZEN!", player["pos"] - Vector2(0, 48), Color("41f3ff"))
		Character.NURSE:
			_add_floating_text("PASSIVE REGEN ACTIVE!", player["pos"] - Vector2(0, 48), Color("64ff88"))

# --- CONSOLE EXECUTION & WAVE JUMP ---
func _execute_console_command(cmd: String) -> void:
	var clean := cmd.strip_edges().to_lower()
	if clean in ["10-2", "10 p2", "10 phase 2", "phase 2", "p2", "beast"]:
		console_msg = "WARPING TO WAVE 10 (PHASE 2 BEAST MODE)..."
		_jump_to_wave(10, 2)
		return
	clean = clean.replace("wave", "").replace("level", "").replace("w", "").strip_edges()
	if clean.is_valid_int():
		var w: int = clampi(clean.to_int(), 1, 10)
		console_msg = "WARPING TO WAVE %d..." % w
		_jump_to_wave(w, 1)
	else:
		console_msg = "Invalid wave! Enter 1-10 or '10-2' for Phase 2"
		_play_sfx(200.0, 100.0, 0.15, 0)

func _jump_to_wave(w: int, phase: int = 1) -> void:
	current_wave = clampi(w, 1, 10)
	wave10_phase = phase
	if w == 10 and phase == 2:
		reached_wave10_phase2 = true
	elif w < 10:
		reached_wave10_phase2 = false
	boss_trans_active = false
	boss_trans_timer = 0.0
	boss_trans_flash = 0.0
	cinematic_bars_height = 0.0
	teleport_ghosts.clear()
	sci_fi_teleports.clear()
	player["hearts"] = player["max_hearts"]
	player["pos"] = Vector2(VIEW_W * 0.5, GROUND_Y)
	player["vel"] = Vector2.ZERO
	player["parry_active_timer"] = 0.0
	player["parry_cooldown_timer"] = 0.0
	player["invuln_timer"] = 0.0
	bandit_dash_cooldown = 0.0
	bandit_dashing = false
	scientist_freeze_cooldown = 0.0
	time_freeze_timer = 0.0
	nurse_regen_timer = NURSE_REGEN_INTERVAL
	dash_ghosts.clear()
	wind_particles.clear()
	mobs.clear()
	lasers.clear()
	particles.clear()
	ground_shocks.clear()
	ground_fissures.clear()
	ground_debris.clear()
	floating_texts.clear()
	console_open = false
	screen_shake = 0.0
	_play_sfx(540.0, 1080.0, 0.22, 0)
	_start_wave_transition(current_wave, 0.1)

func _begin_game_from_wave_1() -> void:
	current_wave = 1
	wave10_phase = 1
	reached_wave10_phase2 = false
	boss_trans_active = false
	boss_trans_timer = 0.0
	boss_trans_flash = 0.0
	cinematic_bars_height = 0.0
	teleport_ghosts.clear()
	sci_fi_teleports.clear()
	player["hearts"] = player["max_hearts"]
	player["pos"] = Vector2(VIEW_W * 0.5, GROUND_Y)
	player["vel"] = Vector2.ZERO
	player["parry_active_timer"] = 0.0
	player["parry_cooldown_timer"] = 0.0
	player["invuln_timer"] = 0.0
	bandit_dash_cooldown = 0.0
	bandit_dashing = false
	scientist_freeze_cooldown = 0.0
	time_freeze_timer = 0.0
	nurse_regen_timer = NURSE_REGEN_INTERVAL
	dash_ghosts.clear()
	wind_particles.clear()
	mobs.clear()
	lasers.clear()
	particles.clear()
	ground_shocks.clear()
	ground_fissures.clear()
	ground_debris.clear()
	floating_texts.clear()
	_start_wave_transition(1, 0.0)

func _start_wave_transition(wave_num: int, initial_pause: float) -> void:
	state = State.TRANSITION
	transition_text = "wave %d" % wave_num
	if initial_pause > 0.0:
		transition_phase = 0
		transition_timer = initial_pause
		transition_alpha = 0.0
	else:
		transition_phase = 1
		transition_alpha = 0.0

func _setup_wave_entities(wave_num: int) -> void:
	mobs.clear()
	lasers.clear()

	# WAVE 5: FIRST BOSS - THE APEX ANOMALY (Terraria / Grief Eye)
	if wave_num == 5:
		mobs_to_spawn = 0
		var boss := {
			"is_boss": true,
			"name": "THE APEX ANOMALY",
			"type": 99,
			"pos": Vector2(VIEW_W * 0.5, 175.0),
			"vel": Vector2.ZERO,
			"target_pos": Vector2(VIEW_W * 0.5, 175.0),
			"retarget_timer": 1.2,
			"shoot_timer": 0.8,
			"shoot_cd": 0.72,
			"radius": 52.0,
			"hp": 20,
			"max_hp": 20,
			"hit_flash": 0.0,
			"anim": 0.0,
			"charge_glow": 0.0,
			"attack_pattern": 0,
			"enraged": false,
			"laser_speed": 660.0
		}
		mobs.append(boss)
		screen_shake = 24.0
		boss_warning_timer = 3.6
		boss_warning_title = "! WARNING: BOSS APPROACHING !"
		boss_warning_sub = "THE APEX ANOMALY * 20 LASER DEFLECTIONS REQUIRED"
		boss_warning_color = Color("ff2a4b")
		_play_sfx(140.0, 60.0, 0.85, 1)

	# WAVE 7: PURPLE SQUARE BOSS - NEO-TESSERACT (The Void Hypercube)
	elif wave_num == 7:
		mobs_to_spawn = 0
		var boss := {
			"is_boss": true,
			"name": "NEO-TESSERACT",
			"type": 101, # Level 7 Purple Square Boss
			"pos": Vector2(VIEW_W * 0.5, 185.0),
			"vel": Vector2.ZERO,
			"target_pos": Vector2(VIEW_W * 0.5, 185.0),
			"retarget_timer": 1.0,
			"shoot_timer": 1.0,
			"shoot_cd": 0.90,
			"radius": 50.0, # collision radius
			"size": 94.0,   # square dimension
			"rotation_angle": 0.0,
			"rotation_speed": 2.2,
			"hp": 26,
			"max_hp": 26,
			"hit_flash": 0.0,
			"anim": 0.0,
			"charge_glow": 0.0,
			"attack_pattern": 0,
			"enraged": false,
			"laser_speed": 690.0,
			# Slam attack state
			"slam_state": 0, # 0: none, 1: telegraph charge, 2: diving down, 3: recoil
			"slam_timer": 0.0,
			"slam_target_x": VIEW_W * 0.5,
			"slam_speed": 1300.0,
			"color": Color("9b5de5")
		}
		mobs.append(boss)
		screen_shake = 30.0
		boss_warning_timer = 3.8
		boss_warning_title = "! LEVEL 7 BOSS: NEO-TESSERACT !"
		boss_warning_sub = "THE VOID HYPERCUBE * ROTARY CROSS & QUANTUM SLAM"
		boss_warning_color = Color("b5179e")
		_play_sfx(160.0, 50.0, 0.95, 1)

	# WAVE 10: FINAL BOSS - SOLARIS (PHASE 1: GOLDEN SOVEREIGN / PHASE 2: ECLIPSE BEAST)
	elif wave_num == 10:
		mobs_to_spawn = 0
		var is_p2: bool = (wave10_phase == 2)
		var b_name: String = "SOLARIS - LE COLOSSE DORE" if not is_p2 else "ECLIPSE SOLARIS - BEAST OF THE VOID"
		var b_hp: int = 30 if not is_p2 else 40
		var b_col: Color = Color("ffd700") if not is_p2 else Color("0a0a12")
		var boss := {
			"is_boss": true,
			"name": b_name,
			"type": 102, # Level 10 Boss
			"phase": (2 if is_p2 else 1),
			"pos": Vector2(VIEW_W * 0.5, 160.0),
			"vel": Vector2.ZERO,
			"target_pos": Vector2(VIEW_W * 0.5, 160.0),
			"retarget_timer": 0.9,
			"shoot_timer": 0.8,
			"shoot_cd": (0.65 if not is_p2 else 0.40),
			"radius": 58.0,
			"hp": b_hp,
			"max_hp": b_hp,
			"hit_flash": 0.0,
			"anim": 0.0,
			"charge_glow": 0.0,
			"attack_pattern": 0,
			"enraged": is_p2,
			"laser_speed": (750.0 if not is_p2 else 820.0),
			"halo_angle": 0.0,
			"wing_anim": 0.0,
			"color": b_col,
			"accent_color": (Color("ffe550") if not is_p2 else Color("ff0055")),
			"teleport_timer": (2.4 if not is_p2 else 1.3),
			"teleport_cd": (2.8 if not is_p2 else 1.8),
			"is_beast": is_p2
		}
		mobs.append(boss)
		screen_shake = 35.0
		boss_warning_timer = 4.2
		if not is_p2:
			boss_warning_title = "! FINAL BOSS: SOLARIS (LE COLOSSE DORE) !"
			boss_warning_sub = "THE GOLDEN SOVEREIGN * HARDEST CHALLENGE * 30 HITS"
			boss_warning_color = Color("ffe550")
		else:
			boss_warning_title = "! WARNING: ECLIPSE BEAST MODE ACTIVE !"
			boss_warning_sub = "APOCALYPTIC VOID PHASE * IMPOSSIBLE CHALLENGE * 40 HITS"
			boss_warning_color = Color("ff0055")
		_play_sfx(120.0, 45.0, 1.1, 1)

	# REGULAR WAVES
	else:
		mobs_to_spawn = 4 + wave_num * 2
		if wave_num >= 6:
			mobs_to_spawn += 3
		if wave_num >= 8:
			mobs_to_spawn += 5
		spawn_timer = 0.40


# ==============================================================================
# MAIN LOOP (60 FPS FLUID PHYSICS & UPDATES)
# ==============================================================================
func _physics_process(delta: float) -> void:
	_fill_audio_buffers()
	_update_dynamic_scenery(delta)
	_update_menu_buttons(delta)
	_update_ground_effects(delta)

	# Crazy Screen Shake with Rotational Tilt (Noticeable tilt only on intense boss shakes)
	screen_shake = maxf(0.0, screen_shake - delta * 26.0)
	screen_shake_rot = (randf_range(-0.018, 0.018) * clampf(screen_shake / 22.0, 0.0, 1.4)) if screen_shake > 3.0 else 0.0
	grief_pulse_flash = maxf(0.0, grief_pulse_flash - delta * 1.8)

	if boss_warning_timer > 0.0:
		boss_warning_timer = maxf(0.0, boss_warning_timer - delta)
		if fmod(boss_warning_timer, 0.65) < delta and boss_warning_timer > 0.4:
			_play_sfx(440.0, 180.0, 0.22, 1)
			screen_shake = maxf(screen_shake, 14.0)
			_spawn_burst(Vector2(randf_range(200.0, VIEW_W - 200.0), 38.0), boss_warning_color, 10, 220.0)
			_spawn_burst(Vector2(randf_range(200.0, VIEW_W - 200.0), VIEW_H - 38.0), boss_warning_color, 10, 220.0)

	match state:
		State.MENU:
			pass
		State.TRANSITION:
			_update_transition(delta)
		State.PLAYING:
			_update_playing_state(delta)
		State.GAME_OVER, State.VICTORY:
			_update_particles_and_text(delta)

	queue_redraw()

func _update_playing_state(delta: float) -> void:
	bandit_dash_cooldown = maxf(0.0, bandit_dash_cooldown - delta)
	scientist_freeze_cooldown = maxf(0.0, scientist_freeze_cooldown - delta)

	# Letterbox cinematic bars tween during transformation
	var target_bars: float = 70.0 if boss_trans_active else 0.0
	cinematic_bars_height = move_toward(cinematic_bars_height, target_bars, delta * 240.0)

	# Fading teleport afterimage ghosts
	for i in range(teleport_ghosts.size() - 1, -1, -1):
		teleport_ghosts[i]["alpha"] -= delta * 2.8
		if teleport_ghosts[i]["alpha"] <= 0.0:
			teleport_ghosts.remove_at(i)

	# Active Sci-Fi Teleport holographic beams and shockwaves
	for i in range(sci_fi_teleports.size() - 1, -1, -1):
		sci_fi_teleports[i]["timer"] -= delta
		if sci_fi_teleports[i]["timer"] <= 0.0:
			sci_fi_teleports.remove_at(i)

	# Wave 10 Boss Transformation Cutscene (Phase 1 -> Phase 2 Beast Mode)
	if boss_trans_active:
		_update_boss_transformation(delta)
		_update_player(delta)
		_update_particles_and_text(delta)
		return

	if time_freeze_timer > 0.0:
		time_freeze_timer = maxf(0.0, time_freeze_timer - delta)
		_update_player(delta)
		_update_particles_and_text(delta)
		return

	_update_player(delta)
	_update_wave_spawner(delta)
	_update_mobs(delta)
	_update_lasers(delta)
	_update_particles_and_text(delta)

# --- Wave 10 Phase 1 -> Phase 2 Beast Transformation Cutscene ---
func _update_boss_transformation(delta: float) -> void:
	boss_trans_timer -= delta
	boss_trans_flash = maxf(0.0, boss_trans_flash - delta * 1.5)

	var b = null
	for m in mobs:
		if m.get("is_boss", false) and m.get("type", 0) == 102:
			b = m
			break
	if b == null:
		boss_trans_active = false
		return

	player["invuln_timer"] = maxf(player["invuln_timer"], 1.5)
	b["pos"] = b["pos"].lerp(Vector2(VIEW_W * 0.5, 200.0), 6.0 * delta)

	# Stage 1: Core Destabilization & Armor Fracture (5.8s -> 3.6s)
	if boss_trans_timer > 3.6:
		b["hit_flash"] = 0.22
		screen_shake = maxf(screen_shake, 14.0 + (5.8 - boss_trans_timer) * 4.5)
		if fmod(boss_trans_timer, 0.14) < delta:
			var rand_pt: Vector2 = b["pos"] + Vector2(randf_range(-45, 45), randf_range(-45, 45))
			_spawn_burst(rand_pt, Color("ffe550"), 12, 220.0)
			_spawn_burst(rand_pt, Color.WHITE, 8, 280.0)
			_play_sfx(360.0, 80.0, 0.16, 1)

	# Stage 2: Blinding Whiteout Flash & Gravitational Singularity (3.6s -> 2.2s)
	elif boss_trans_timer > 2.2:
		if boss_trans_flash < 0.25:
			boss_trans_flash = 1.0
			_play_sfx(70.0, 20.0, 1.1, 1)
			screen_shake = 40.0
			_spawn_burst(b["pos"], Color("0a0a14"), 70, 480.0)
			_spawn_burst(b["pos"], Color("ff0055"), 60, 420.0)

		# Singularity matter suction
		for k in range(4):
			var in_ang: float = randf_range(0, TAU)
			var in_dist: float = randf_range(140.0, 360.0)
			var in_pos: Vector2 = b["pos"] + Vector2(cos(in_ang), sin(in_ang)) * in_dist
			var in_vel: Vector2 = (b["pos"] - in_pos).normalized() * 560.0
			particles.append({
				"pos": in_pos,
				"vel": in_vel,
				"color": Color("ff0055") if randf() < 0.5 else Color("a800ff"),
				"life": 0.38,
				"max_life": 0.38,
				"size": randf_range(4.0, 9.0)
			})

	# Stage 3: Obsidian Beast Rebirth & Health Bar Refill (2.2s -> 0.0s)
	else:
		b["phase"] = 2
		b["is_beast"] = true
		b["color"] = Color("0a0a12")
		b["accent_color"] = Color("ff0055")
		b["name"] = "ECLIPSE SOLARIS - BEAST OF THE VOID"
		b["max_hp"] = 40

		var fill_prog: float = clampf((2.2 - boss_trans_timer) / 2.0, 0.0, 1.0)
		b["hp"] = mini(40, int(fill_prog * 40.0) + 1)
		b["enraged"] = true

		if fmod(boss_trans_timer, 0.11) < delta:
			_spawn_burst(b["pos"], Color("ff0055"), 8, 180.0)
			_play_sfx(180.0 + fill_prog * 650.0, 380.0 + fill_prog * 650.0, 0.08, 0)

	if boss_trans_timer <= 0.0:
		boss_trans_active = false
		b["hp"] = 40
		b["shoot_timer"] = 0.60
		b["teleport_timer"] = 1.0
		screen_shake = 42.0
		_play_sfx(90.0, 25.0, 1.4, 1)
		_spawn_burst(b["pos"], Color("ff0055"), 80, 500.0)
		_spawn_burst(b["pos"], Color.BLACK, 40, 420.0)
		_add_floating_text("ECLIPSE BEAST AWAKENED!", Vector2(VIEW_W * 0.5, 130), Color("ff0055"))

func _update_dynamic_scenery(delta: float) -> void:
	for c in clouds:
		c["pos"].x += c["speed"] * delta
		if c["pos"].x > VIEW_W + 140.0:
			c["pos"].x = -140.0

	for f in fireflies:
		f["phase"] += delta * 2.5
		f["pos"].x += cos(f["phase"]) * f["speed"] * delta
		f["pos"].y += sin(f["phase"] * 1.3) * (f["speed"] * 0.6) * delta

	for em in grief_embers:
		em["pos"] += em["vel"] * delta
		em["pos"].x += sin(em["pos"].y * 0.02) * 18.0 * delta
		if em["pos"].y < -20.0 or em["pos"].x < -20.0 or em["pos"].x > VIEW_W + 20.0:
			em["pos"].y = GROUND_Y + randf_range(0.0, 40.0)
			em["pos"].x = randf_range(0.0, VIEW_W)
			em["vel"] = Vector2(randf_range(-25, 25), randf_range(-65, -130))

	for col in grief_laser_columns:
		col["phase"] += col["speed"] * delta

	for eye in grief_eyes:
		eye["blink_timer"] -= delta
		if eye["blink_timer"] <= 0.0:
			eye["is_open"] = not eye["is_open"]
			eye["blink_timer"] = randf_range(0.35, 0.75) if eye["is_open"] else randf_range(2.0, 5.5)
		var target_open: float = 1.0 if eye["is_open"] else 0.0
		eye["open_amount"] = lerpf(eye["open_amount"], target_open, 12.0 * delta)

func _update_menu_buttons(delta: float) -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var mpos: Vector2 = get_global_mouse_position()

	if state == State.MENU:
		if characters_open:
			var hover_back := (mpos.distance_to(char_back_center) <= CHAR_BACK_RADIUS + 6.0)
			_apply_spring_button("char_back", hover_back, delta)
			for i in range(3):
				var hover_card: bool = char_card_rects[i].has_point(mpos)
				_apply_spring_card("card_%d" % i, hover_card, (1.04 if hover_card else 1.0), delta)
		elif credits_open:
			var hover_close := (mpos.distance_to(close_credits_center) <= CLOSE_BTN_RADIUS + 4.0)
			_apply_spring_button("close", hover_close, delta)
		else:
			var hover_start := start_btn_rect.has_point(mpos)
			var hover_chars := characters_btn_rect.has_point(mpos)
			var hover_credits := credits_btn_rect.has_point(mpos)
			_apply_spring_button("start", hover_start, delta)
			_apply_spring_button("characters", hover_chars, delta)
			_apply_spring_button("credits", hover_credits, delta)
	elif state == State.GAME_OVER:
		var hover_start := start_btn_rect.has_point(mpos)
		var hover_credits := credits_btn_rect.has_point(mpos)
		_apply_spring_button("start", hover_start, delta)
		_apply_spring_button("credits", hover_credits, delta)
	elif state == State.VICTORY:
		var hover_restart := victory_restart_rect.has_point(mpos)
		var hover_menu := victory_menu_rect.has_point(mpos)
		_apply_spring_button("vic_restart", hover_restart, delta)
		_apply_spring_button("vic_menu", hover_menu, delta)

func _apply_spring_button(key: String, is_hovered: bool, delta: float) -> void:
	if is_hovered and not btn_hovered[key]:
		btn_vel[key] = 4.2
		_play_sfx(660.0, 780.0, 0.05, 0)
	btn_hovered[key] = is_hovered
	var target: float = 1.08 if is_hovered else 1.0
	var force: float = (target - btn_scales[key]) * 180.0
	btn_vel[key] = (btn_vel[key] + force * delta) * exp(-9.5 * delta)
	btn_scales[key] += btn_vel[key] * delta

func _apply_spring_card(key: String, is_hovered: bool, target: float, delta: float) -> void:
	if is_hovered and not btn_hovered[key]:
		btn_vel[key] = 2.4
		_play_sfx(720.0, 840.0, 0.04, 0)
	btn_hovered[key] = is_hovered
	var force: float = (target - btn_scales[key]) * 160.0
	btn_vel[key] = (btn_vel[key] + force * delta) * exp(-8.5 * delta)
	btn_scales[key] += btn_vel[key] * delta

func _update_transition(delta: float) -> void:
	_update_particles_and_text(delta)
	if transition_phase == 0:
		_update_player(delta)
		transition_timer -= delta
		if transition_timer <= 0.0:
			transition_phase = 1
	elif transition_phase == 1:
		transition_alpha += delta * 1.55
		if transition_alpha >= 1.0:
			transition_alpha = 1.0
			transition_phase = 2
			transition_timer = 1.15
			_setup_wave_entities(current_wave)
	elif transition_phase == 2:
		transition_timer -= delta
		if transition_timer <= 0.0:
			transition_phase = 3
	elif transition_phase == 3:
		transition_alpha -= delta * 1.75
		if transition_alpha <= 0.0:
			transition_alpha = 0.0
			state = State.PLAYING

# ==============================================================================
# PLAYER MOVEMENT, ABILITIES & PERFECT PARRY
# ==============================================================================
func _attempt_jump() -> void:
	if player["on_ground"]:
		player["vel"].y = JUMP_FORCE
		player["on_ground"] = false
		_play_sfx(260.0, 520.0, 0.11, 0)
		_spawn_burst(player["pos"], Color("a7f070"), 7, 110.0)

func _attempt_parry() -> void:
	if player["parry_cooldown_timer"] > 0.0:
		player["parry_fail_flash"] = 0.18
		_play_sfx(150.0, 110.0, 0.08, 0)
		return

	player["parry_active_timer"] = PARRY_WINDOW
	player["parry_cooldown_timer"] = PARRY_COOLDOWN
	player["parry_flash"] = 0.18
	_play_sfx(520.0, 960.0, 0.08, 0)
	_check_parry_deflection()

func _check_parry_deflection() -> void:
	if player["parry_active_timer"] <= 0.0:
		return
	var p_center: Vector2 = player["pos"] - Vector2(0, player["h"] * 0.5)

	for l in lasers:
		if not l["bounced"]:
			var dist: float = l["pos"].distance_to(p_center)
			if dist <= PARRY_RADIUS:
				l["bounced"] = true
				var target_mob = l["owner"]
				if target_mob == null or not mobs.has(target_mob):
					target_mob = _get_nearest_mob(l["pos"])
				l["homing_target"] = target_mob
				l["speed"] = maxf(l["vel"].length() * 1.6, 820.0)

				var aim_dir: Vector2 = -l["vel"].normalized()
				if target_mob != null:
					aim_dir = (target_mob["pos"] - l["pos"]).normalized()
				l["vel"] = aim_dir * l["speed"]
				l["color"] = Color("38ffff")

				player["parry_cooldown_timer"] = 0.05
				screen_shake = 8.5 if _is_boss_wave() else 2.2
				_play_sfx(680.0, 1480.0, 0.16, 0)
				_spawn_burst(l["pos"], Color("73eff7"), 20, 270.0)
				_add_floating_text("PERFECT PARRY!", p_center + Vector2(0, -34), Color("73eff7"))

func _update_player(delta: float) -> void:
	player["parry_active_timer"] = maxf(0.0, player["parry_active_timer"] - delta)
	player["parry_cooldown_timer"] = maxf(0.0, player["parry_cooldown_timer"] - delta)
	player["invuln_timer"] = maxf(0.0, player["invuln_timer"] - delta)
	player["parry_flash"] = maxf(0.0, player["parry_flash"] - delta)
	player["parry_fail_flash"] = maxf(0.0, player["parry_fail_flash"] - delta)

	if selected_character == Character.NURSE and player["hearts"] < player["max_hearts"]:
		nurse_regen_timer -= delta
		if nurse_regen_timer <= 0.0:
			nurse_regen_timer = NURSE_REGEN_INTERVAL
			player["hearts"] = mini(player["max_hearts"], player["hearts"] + 1)
			_play_heal_sfx()
			_spawn_burst(player["pos"] - Vector2(0, 18), Color("55ff99"), 14, 110.0)
			_add_floating_text("+1 HEART REGEN!", player["pos"] - Vector2(0, 48), Color("55ff99"))
	elif selected_character == Character.NURSE and player["hearts"] >= player["max_hearts"]:
		nurse_regen_timer = NURSE_REGEN_INTERVAL

	if bandit_dashing:
		bandit_dash_timer -= delta
		player["vel"].y = 0.0
		player["pos"].x += bandit_dash_dir * BANDIT_DASH_SPEED * delta
		player["invuln_timer"] = maxf(player["invuln_timer"], 0.10)

		dash_ghosts.append({
			"pos": player["pos"],
			"facing": player["facing"],
			"char": selected_character,
			"alpha": 0.55
		})
		for i in range(2):
			wind_particles.append({
				"pos": player["pos"] - Vector2(bandit_dash_dir * 12.0, randf_range(8.0, 32.0)),
				"vel": Vector2(-bandit_dash_dir * randf_range(160, 320), randf_range(-30, 30)),
				"life": randf_range(0.18, 0.32),
				"max_life": 0.32,
				"size": randf_range(3.0, 6.0)
			})
		if bandit_dash_timer <= 0.0:
			bandit_dashing = false
	else:
		var dir := 0.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir += 1.0

		if dir != 0.0:
			player["facing"] = int(sign(dir))
			player["walk_anim"] += delta * 14.0
		else:
			player["walk_anim"] = 0.0

		player["vel"].x = lerpf(player["vel"].x, dir * MOVE_SPEED, 16.0 * delta)
		var prev_y: float = player["pos"].y
		player["vel"].y += GRAVITY * delta
		player["pos"] += player["vel"] * delta
		player["on_ground"] = false

		if player["vel"].y >= 0.0:
			for plat in platforms:
				var within_x: bool = (player["pos"].x + player["w"] * 0.45 >= plat.position.x) and (player["pos"].x - player["w"] * 0.45 <= plat.position.x + plat.size.x)
				if within_x and prev_y <= plat.position.y + 4.0 and player["pos"].y >= plat.position.y:
					player["pos"].y = plat.position.y
					player["vel"].y = 0.0
					player["on_ground"] = true
					break

		if player["pos"].y >= GROUND_Y:
			player["pos"].y = GROUND_Y
			player["vel"].y = 0.0
			player["on_ground"] = true

	player["pos"].x = clampf(player["pos"].x, 28.0, VIEW_W - 28.0)

	for i in range(dash_ghosts.size() - 1, -1, -1):
		dash_ghosts[i]["alpha"] -= delta * 3.5
		if dash_ghosts[i]["alpha"] <= 0.0:
			dash_ghosts.remove_at(i)

	if player["parry_active_timer"] > 0.0:
		_check_parry_deflection()

# ==============================================================================
# GROUND EFFECTS SYSTEM (SHOCKS, FISSURES & DEBRIS)
# ==============================================================================
func _add_ground_shock(x: float, max_radius: float, col: Color, spd: float = 380.0) -> void:
	ground_shocks.append({
		"x": x,
		"r": 8.0,
		"max_r": max_radius,
		"spd": spd,
		"col": col,
		"life": 0.42,
		"max_life": 0.42
	})

func _add_ground_fissure(x1: float, x2: float, col: Color) -> void:
	ground_fissures.append({
		"x1": minf(x1, x2),
		"x2": maxf(x1, x2),
		"col": col,
		"life": 1.4,
		"max_life": 1.4
	})

func _spawn_ground_debris(x: float, count: int, col: Color) -> void:
	for i in range(count):
		ground_debris.append({
			"pos": Vector2(x + randf_range(-14, 14), GROUND_Y - randf_range(2, 6)),
			"vel": Vector2(randf_range(-180, 180), randf_range(-240, -480)),
			"col": col,
			"size": randf_range(3.0, 7.0),
			"life": randf_range(0.4, 0.7),
			"max_life": 0.7
		})

func _update_ground_effects(delta: float) -> void:
	for i in range(ground_shocks.size() - 1, -1, -1):
		var gs = ground_shocks[i]
		gs["life"] -= delta
		gs["r"] = minf(gs["max_r"], gs["r"] + gs["spd"] * delta)
		if gs["life"] <= 0.0:
			ground_shocks.remove_at(i)

	for i in range(ground_fissures.size() - 1, -1, -1):
		var gf = ground_fissures[i]
		gf["life"] -= delta
		if gf["life"] <= 0.0:
			ground_fissures.remove_at(i)

	for i in range(ground_debris.size() - 1, -1, -1):
		var gd = ground_debris[i]
		gd["life"] -= delta
		gd["vel"].y += GRAVITY * delta * 0.8
		gd["pos"] += gd["vel"] * delta
		if gd["pos"].y >= GROUND_Y:
			gd["pos"].y = GROUND_Y
			gd["vel"].y = -gd["vel"].y * 0.4
			gd["vel"].x *= 0.7
		if gd["life"] <= 0.0:
			ground_debris.remove_at(i)


# ==============================================================================
# MOBS, DODGING AI & BOSS LOGIC (WAVE 5, WAVE 7 PURPLE, WAVE 10 GOLDEN)
# ==============================================================================
func _update_wave_spawner(delta: float) -> void:
	if mobs_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_mob()
			mobs_to_spawn -= 1
			spawn_timer = maxf(0.28, 1.10 - current_wave * 0.06)
	elif mobs.is_empty() and state == State.PLAYING:
		# WAVE CLEARED!
		if current_wave == 10:
			# VICTORY!
			state = State.VICTORY
			screen_shake = 38.0
			_play_sfx(520.0, 1040.0, 0.75, 0)
			_spawn_burst(Vector2(VIEW_W * 0.5, 300.0), Color("ffd700"), 90, 420.0)
			_spawn_burst(Vector2(VIEW_W * 0.5, 300.0), Color("ff41f3"), 70, 360.0)
			_spawn_burst(Vector2(VIEW_W * 0.5, 300.0), Color("41f3ff"), 70, 360.0)
			_add_floating_text("CONGRATULATIONS! ALL 10 WAVES CLEARED!", Vector2(VIEW_W * 0.5, 240.0), Color("ffe762"))
		else:
			current_wave += 1
			_play_sfx(392.0, 784.0, 0.35, 0)
			_add_floating_text("WAVE CLEARED!", player["pos"] - Vector2(0, 60), Color("ffe762"))
			_start_wave_transition(current_wave, 0.95)

func _spawn_mob() -> void:
	var max_archetype: int = mini(3, (current_wave - 1) / 2)
	var mob_type: int = randi_range(0, max_archetype)

	var spawn_x: float = randf_range(80.0, VIEW_W - 80.0)
	var spawn_y: float = -40.0
	if randf() < 0.4:
		spawn_x = -40.0 if randf() < 0.5 else VIEW_W + 40.0
		spawn_y = randf_range(70.0, 260.0)

	var base_fire_cd: float = maxf(0.80, 2.50 - current_wave * 0.13)
	var laser_spd: float = minf(780.0, 360.0 + current_wave * 28.0)
	var dodge_chance: float = clampf((current_wave - 1) * 0.16, 0.0, 0.85)
	var dodge_strength: float = 210.0 + current_wave * 28.0

	mobs.append({
		"is_boss": false,
		"type": mob_type,
		"pos": Vector2(spawn_x, spawn_y),
		"vel": Vector2.ZERO,
		"target_pos": Vector2(randf_range(120.0, VIEW_W - 120.0), randf_range(75.0, 290.0)),
		"retarget_timer": randf_range(1.2, 2.6),
		"shoot_timer": randf_range(0.8, base_fire_cd),
		"shoot_cd": base_fire_cd * randf_range(0.88, 1.12),
		"laser_speed": laser_spd,
		"radius": 22.0,
		"anim": randf_range(0.0, TAU),
		"dodge_chance": dodge_chance,
		"dodge_strength": dodge_strength,
		"dodge_cooldown": 0.0,
		"charge_glow": 0.0
	})

func _update_mobs(delta: float) -> void:
	var p_center: Vector2 = player["pos"] - Vector2(0, player["h"] * 0.5)

	for m in mobs:
		m["anim"] += delta * 8.0

		if m.get("is_boss", false):
			_update_boss_ai(m, p_center, delta)
			continue

		m["dodge_cooldown"] = maxf(0.0, m["dodge_cooldown"] - delta)
		m["retarget_timer"] -= delta

		# Regular mob AI
		if m["retarget_timer"] <= 0.0 or m["pos"].distance_to(m["target_pos"]) < 36.0:
			m["target_pos"] = Vector2(randf_range(100.0, VIEW_W - 100.0), randf_range(65.0, 310.0))
			m["retarget_timer"] = randf_range(1.4, 2.8)

		var desired_vel: Vector2 = (m["target_pos"] - m["pos"]).normalized() * (120.0 + current_wave * 8.0)
		desired_vel.y += sin(m["anim"]) * 35.0

		if current_wave >= 2 and m["dodge_cooldown"] <= 0.0:
			for l in lasers:
				if l["bounced"]:
					var to_mob: Vector2 = m["pos"] - l["pos"]
					var dist: float = to_mob.length()
					if dist < 240.0 and dist > 10.0:
						var l_dir: Vector2 = l["vel"].normalized()
						if l_dir.dot(to_mob.normalized()) > 0.84:
							if randf() < m["dodge_chance"]:
								var perp := Vector2(-l_dir.y, l_dir.x)
								if perp.dot(m["pos"] - Vector2(VIEW_W * 0.5, 180.0)) > 0.0:
									perp = -perp
								m["vel"] = perp * m["dodge_strength"]
								m["dodge_cooldown"] = maxf(0.45, 1.10 - current_wave * 0.06)
								_spawn_burst(m["pos"], Color("ffee83"), 6, 95.0)
								_add_floating_text("DODGE!", m["pos"] + Vector2(0, -26), Color("ffee83"))
							else:
								m["dodge_cooldown"] = 0.32
							break

		m["vel"] = m["vel"].lerp(desired_vel, 4.5 * delta)
		m["pos"] += m["vel"] * delta
		m["pos"].x = clampf(m["pos"].x, 55.0, VIEW_W - 55.0)
		m["pos"].y = clampf(m["pos"].y, 50.0, 360.0)

		# Shooting & Charging Jitter
		m["shoot_timer"] -= delta
		m["charge_glow"] = clampf(1.0 - (m["shoot_timer"] / 0.45), 0.0, 1.0) if m["shoot_timer"] < 0.45 else 0.0

		if m["shoot_timer"] <= 0.0:
			m["shoot_timer"] = m["shoot_cd"]
			var aim_dir: Vector2 = (p_center - m["pos"]).normalized()
			var col := Color("ff3b5b")
			if m["type"] == 1:
				col = Color("a6ff2e")
			elif m["type"] == 2:
				col = Color("ff77e9")
			elif m["type"] == 3:
				col = Color("ff9e2c")

			lasers.append({
				"pos": m["pos"] + aim_dir * 18.0,
				"vel": aim_dir * m["laser_speed"],
				"speed": m["laser_speed"],
				"bounced": false,
				"owner": m,
				"homing_target": null,
				"color": col,
				"trail": []
			})
			if _is_boss_wave():
				screen_shake = maxf(screen_shake, 2.0)
			_play_sfx(780.0, 310.0, 0.11, 0)

# ==============================================================================
# BOSS AI LOGIC (DISPATCH BY BOSS TYPE)
# ==============================================================================
func _update_boss_ai(boss: Dictionary, p_center: Vector2, delta: float) -> void:
	boss["hit_flash"] = maxf(0.0, boss["hit_flash"] - delta)
	var b_type: int = boss["type"]

	match b_type:
		99:
			_update_wave5_apex_boss(boss, p_center, delta)
		101:
			_update_wave7_purple_square_boss(boss, p_center, delta)
		102:
			_update_wave10_golden_boss(boss, p_center, delta)

# --- WAVE 5: APEX ANOMALY ---
func _update_wave5_apex_boss(boss: Dictionary, p_center: Vector2, delta: float) -> void:
	boss["enraged"] = (boss["hp"] <= 10)
	var move_spd: float = 240.0 if not boss["enraged"] else 350.0

	if boss["retarget_timer"] <= 0.0 or boss["pos"].distance_to(boss["target_pos"]) < 45.0:
		var max_y: float = 290.0 if not boss["enraged"] else 380.0
		boss["target_pos"] = Vector2(randf_range(160.0, VIEW_W - 160.0), randf_range(80.0, max_y))
		boss["retarget_timer"] = randf_range(1.0, 2.2) if not boss["enraged"] else randf_range(0.6, 1.4)

	var desired_vel: Vector2 = (boss["target_pos"] - boss["pos"]).normalized() * move_spd
	desired_vel.y += sin(boss["anim"] * 1.5) * 45.0
	boss["vel"] = boss["vel"].lerp(desired_vel, 6.0 * delta)
	boss["pos"] += boss["vel"] * delta
	boss["pos"].x = clampf(boss["pos"].x, 80.0, VIEW_W - 80.0)
	boss["pos"].y = clampf(boss["pos"].y, 65.0, 420.0)

	boss["shoot_timer"] -= delta
	var charge_window: float = 0.35 if not boss["enraged"] else 0.22
	boss["charge_glow"] = clampf(1.0 - (boss["shoot_timer"] / charge_window), 0.0, 1.0) if boss["shoot_timer"] < charge_window else 0.0

	if boss["shoot_timer"] <= 0.0:
		var cd: float = 0.75 if not boss["enraged"] else 0.46
		boss["shoot_timer"] = cd
		boss["attack_pattern"] = (boss["attack_pattern"] + 1) % 3

		var base_aim: Vector2 = (p_center - boss["pos"]).normalized()
		var spd: float = boss["laser_speed"] if not boss["enraged"] else (boss["laser_speed"] + 60.0)

		if boss["attack_pattern"] == 0:
			var perp := Vector2(-base_aim.y, base_aim.x) * 22.0
			_spawn_boss_laser(boss, boss["pos"] + perp, base_aim, spd, Color("ff2a55"))
			_spawn_boss_laser(boss, boss["pos"] - perp, base_aim, spd, Color("ff2a55"))
			_play_sfx(620.0, 240.0, 0.16, 0)
			screen_shake = maxf(screen_shake, 4.0)
		elif boss["attack_pattern"] == 1:
			for ang in [-0.26, 0.0, 0.26]:
				var dir := base_aim.rotated(ang)
				_spawn_boss_laser(boss, boss["pos"], dir, spd * 0.95, Color("ff7e2a"))
			_play_sfx(720.0, 260.0, 0.18, 0)
			screen_shake = maxf(screen_shake, 5.0)
		else:
			if boss["enraged"]:
				for ang in [-0.38, -0.12, 0.12, 0.38]:
					var dir := base_aim.rotated(ang)
					_spawn_boss_laser(boss, boss["pos"], dir, spd * 1.08, Color("ff22ff"))
				screen_shake = maxf(screen_shake, 7.0)
			else:
				_spawn_boss_laser(boss, boss["pos"], base_aim, spd * 1.15, Color("ff2a55"))
				screen_shake = maxf(screen_shake, 4.0)
			_play_sfx(880.0, 210.0, 0.15, 0)

# --- WAVE 7: PURPLE SQUARE BOSS (NEO-TESSERACT) ---
# Creative & Distinctive:
# 1. Tetragonal Cross-Beams: 4 spinning lasers that sweep through the arena
# 2. Prism Satellite Salvo: 4 satellite cubes fire staggered violet lasers
# 3. Quantum Hyper-Slam: Telegraphed charging with violent screen shake, drops down into ground,
#    sending massive purple ground shocks, fissures, and 8 parriable sparks upward!
func _update_wave7_purple_square_boss(boss: Dictionary, p_center: Vector2, delta: float) -> void:
	boss["enraged"] = (boss["hp"] <= 12)
	boss["rotation_speed"] = 2.4 if not boss["enraged"] else 4.2
	boss["rotation_angle"] += boss["rotation_speed"] * delta

	# Quantum Slam State Machine
	if boss["slam_state"] == 1:
		# Phase 1: Telegraph charging above the target
		boss["slam_timer"] -= delta
		screen_shake = maxf(screen_shake, 12.0)
		boss["charge_glow"] = 1.0
		# Jitter above ground
		boss["pos"].x = lerpf(boss["pos"].x, boss["slam_target_x"], 8.0 * delta)
		if boss["slam_timer"] <= 0.0:
			boss["slam_state"] = 2
			_play_sfx(220.0, 70.0, 0.28, 0)
		return
	elif boss["slam_state"] == 2:
		# Phase 2: Diving downward at extreme speed
		boss["pos"].y += boss["slam_speed"] * delta
		screen_shake = maxf(screen_shake, 16.0)
		if boss["pos"].y >= GROUND_Y - boss["radius"]:
			boss["pos"].y = GROUND_Y - boss["radius"]
			boss["slam_state"] = 3
			boss["slam_timer"] = 0.55

			# CRAZY GROUND SHOCK & DEBRIS ON SLAM
			screen_shake = 32.0
			_play_sfx(110.0, 35.0, 0.85, 1)
			_add_ground_shock(boss["pos"].x, 340.0, Color("9b5de5"), 550.0)
			_add_ground_fissure(boss["pos"].x - 220.0, boss["pos"].x + 220.0, Color("c77dff"))
			_spawn_ground_debris(boss["pos"].x, 38, Color("9b5de5"))
			_add_floating_text("QUANTUM GROUND SLAM!", Vector2(boss["pos"].x, GROUND_Y - 80), Color("c77dff"))

			# Erupt 8 deflectable purple sparks in an upward arc!
			for ang_deg in [-75, -55, -35, -15, 15, 35, 55, 75]:
				var rad: float = deg_to_rad(ang_deg - 90)
				var dir := Vector2(cos(rad), sin(rad))
				_spawn_boss_laser(boss, boss["pos"], dir, 520.0, Color("c77dff"))
		return
	elif boss["slam_state"] == 3:
		# Phase 3: Recoiling back to sky
		boss["slam_timer"] -= delta
		boss["pos"].y = lerpf(boss["pos"].y, 185.0, 7.0 * delta)
		if boss["slam_timer"] <= 0.0:
			boss["slam_state"] = 0
			boss["charge_glow"] = 0.0
			boss["shoot_timer"] = 0.70
		return

	# Regular Hover & Movement
	var move_spd: float = 230.0 if not boss["enraged"] else 340.0
	if boss["retarget_timer"] <= 0.0 or boss["pos"].distance_to(boss["target_pos"]) < 40.0:
		boss["target_pos"] = Vector2(randf_range(180.0, VIEW_W - 180.0), randf_range(90.0, 260.0))
		boss["retarget_timer"] = randf_range(1.1, 2.2)

	var desired_vel: Vector2 = (boss["target_pos"] - boss["pos"]).normalized() * move_spd
	desired_vel.y += sin(boss["anim"] * 1.8) * 40.0
	boss["vel"] = boss["vel"].lerp(desired_vel, 6.0 * delta)
	boss["pos"] += boss["vel"] * delta
	boss["pos"].x = clampf(boss["pos"].x, 90.0, VIEW_W - 90.0)
	boss["pos"].y = clampf(boss["pos"].y, 75.0, 320.0)

	# Firing Attacks
	boss["shoot_timer"] -= delta
	var charge_window: float = 0.40 if not boss["enraged"] else 0.25
	boss["charge_glow"] = clampf(1.0 - (boss["shoot_timer"] / charge_window), 0.0, 1.0) if boss["shoot_timer"] < charge_window else 0.0

	if boss["shoot_timer"] <= 0.0:
		var cd: float = 0.90 if not boss["enraged"] else 0.58
		boss["shoot_timer"] = cd
		boss["attack_pattern"] = (boss["attack_pattern"] + 1) % 4

		var base_aim: Vector2 = (p_center - boss["pos"]).normalized()
		var spd: float = boss["laser_speed"] if not boss["enraged"] else (boss["laser_speed"] + 50.0)

		# Pattern 0: Tetragonal Cross-Beams (4 lasers at 90° rotating)
		if boss["attack_pattern"] == 0:
			for k in range(4):
				var ang: float = boss["rotation_angle"] + k * (PI * 0.5)
				var dir := Vector2(cos(ang), sin(ang))
				_spawn_boss_laser(boss, boss["pos"], dir, spd * 0.9, Color("9b5de5"))
			screen_shake = maxf(screen_shake, 7.0)
			_play_sfx(580.0, 220.0, 0.16, 0)
			_add_floating_text("ROTARY CROSS!", boss["pos"] + Vector2(0, -50), Color("9b5de5"))

		# Pattern 1: Prism Satellite Salvo (staggered downward violet bolts)
		elif boss["attack_pattern"] == 1:
			for i in range(4):
				var offset_x: float = (i - 1.5) * 80.0
				var origin: Vector2 = boss["pos"] + Vector2(offset_x, -20.0)
				var dir: Vector2 = (p_center - origin).normalized()
				_spawn_boss_laser(boss, origin, dir, spd, Color("c77dff"))
			screen_shake = maxf(screen_shake, 8.0)
			_play_sfx(740.0, 280.0, 0.18, 0)
			_add_floating_text("PRISM SALVO!", boss["pos"] + Vector2(0, -50), Color("c77dff"))

		# Pattern 2: Quantum Hyper-Slam Trigger!
		elif boss["attack_pattern"] == 2:
			boss["slam_state"] = 1 # Enter telegraph
			boss["slam_timer"] = 0.65
			boss["slam_target_x"] = clampf(player["pos"].x, 150.0, VIEW_W - 150.0)
			boss["pos"].y = 120.0
			screen_shake = maxf(screen_shake, 14.0)
			_play_sfx(340.0, 880.0, 0.35, 0)
			_add_floating_text("QUANTUM SLAM INCOMING!", boss["pos"] + Vector2(0, -50), Color("f72585"))

		# Pattern 3 (or Enraged Octagon Burst)
		else:
			var count: int = 8 if boss["enraged"] else 4
			for k in range(count):
				var ang: float = boss["rotation_angle"] + k * (TAU / float(count))
				var dir := Vector2(cos(ang), sin(ang))
				_spawn_boss_laser(boss, boss["pos"], dir, spd * 1.05, Color("f72585"))
			screen_shake = maxf(screen_shake, 9.0)
			_play_sfx(880.0, 320.0, 0.18, 0)

# --- BOSS TELEPORTATION HELPER (SCI-FI QUANTUM PHASE SHIFT) ---
func _teleport_boss(boss: Dictionary, target_pos: Vector2, is_beast: bool = false) -> void:
	var old_pos: Vector2 = boss["pos"]

	# Record Sci-Fi Teleport event for drawing quantum hyper-beams, holographic lock reticles & hex shields
	sci_fi_teleports.append({
		"from_pos": old_pos,
		"to_pos": target_pos,
		"timer": 0.38,
		"max_timer": 0.38,
		"is_beast": is_beast,
		"color": Color("ff0055") if is_beast else Color("00f5ff"),
		"seed": randf() * 100.0
	})

	# Fading chromatic afterimage ghost
	teleport_ghosts.append({
		"pos": old_pos,
		"alpha": 0.95,
		"color": boss.get("color", Color("ffd700")),
		"radius": boss.get("radius", 46.0),
		"wings": boss.get("wing_anim", 0.0),
		"halo": boss.get("halo_angle", 0.0),
		"phase": boss.get("phase", 1)
	})

	# Departure quantum implosion particles
	var dep_col: Color = Color("ff0055") if is_beast else Color("00f5ff")
	for k in range(16):
		var ang: float = randf_range(0.0, TAU)
		var dist: float = randf_range(30.0, 90.0)
		var p_start: Vector2 = old_pos + Vector2(cos(ang), sin(ang)) * dist
		var p_vel: Vector2 = (old_pos - p_start).normalized() * 340.0
		particles.append({
			"pos": p_start,
			"vel": p_vel,
			"color": dep_col if k % 2 == 0 else Color.WHITE,
			"life": 0.22,
			"max_life": 0.22,
			"size": randf_range(3.0, 6.0)
		})

	# Relocate boss
	boss["pos"] = target_pos
	boss["vel"] = Vector2.ZERO
	boss["target_pos"] = target_pos

	# Arrival holographic ghost & digital pixel burst
	teleport_ghosts.append({
		"pos": target_pos,
		"alpha": 0.75,
		"color": Color.WHITE if not is_beast else Color("ff0055"),
		"radius": boss.get("radius", 46.0) * 1.3,
		"wings": boss.get("wing_anim", 0.0),
		"halo": boss.get("halo_angle", 0.0),
		"phase": boss.get("phase", 1)
	})
	_spawn_burst(target_pos, Color("00f5ff") if not is_beast else Color("ff0055"), 28, 300.0)
	_spawn_burst(target_pos, Color.WHITE, 16, 360.0)

	# Sci-Fi digital audio & screen glitch
	if is_beast:
		_play_sfx(140.0, 880.0, 0.20, 0)
		_play_sfx(90.0, 30.0, 0.25, 2)
		screen_shake = maxf(screen_shake, 24.0)
		_add_floating_text("[VOID PHASE WARP]", target_pos + Vector2(0, -52), Color("ff0055"))
	else:
		_play_sfx(1050.0, 220.0, 0.18, 0)
		_play_sfx(440.0, 880.0, 0.12, 3)
		screen_shake = maxf(screen_shake, 14.0)
		_add_floating_text("[QUANTUM BLINK]", target_pos + Vector2(0, -48), Color("00f5ff"))

# --- WAVE 10: GOLDEN BOSS & PHASE 2 ECLIPSE BEAST MODE ---
# Phase 1: Solaris - Le Colosse Doré
# - Teleports periodically to flank and evade
# - Holy Sun Spears, Pillars of Heaven, Aureate Supernova, Celestial Warp Convergence
# Phase 2: Eclipse Beast (Void Solaris) - Beast Mode (Insane & Impossible)
# - Pitch black obsidian beast with glowing crimson veins and 6 demonic dragon wings
# - Rapid void blinks, Abyssal Singularity, Cataclysmic Beast Slam, Dimensional Void Slicers
func _update_wave10_golden_boss(boss: Dictionary, p_center: Vector2, delta: float) -> void:
	var is_p2: bool = (boss.get("phase", 1) == 2)
	boss["enraged"] = true if is_p2 else (boss["hp"] <= 16)
	boss["wing_anim"] += delta * (12.0 if is_p2 else (8.5 if boss["enraged"] else 5.5))
	boss["halo_angle"] += delta * (5.0 if is_p2 else 2.5)

	# --- Teleportation Timer & Logic ---
	boss["teleport_timer"] = boss.get("teleport_timer", 3.0) - delta
	if boss["teleport_timer"] <= 0.0:
		var warp_pos := Vector2.ZERO
		if not is_p2:
			# Phase 1 tactical warps: left flank, right flank, or above player
			var warp_type: int = randi() % 3
			if warp_type == 0:
				warp_pos = Vector2(randf_range(160.0, 320.0), randf_range(90.0, 220.0))
			elif warp_type == 1:
				warp_pos = Vector2(randf_range(VIEW_W - 320.0, VIEW_W - 160.0), randf_range(90.0, 220.0))
			else:
				warp_pos = Vector2(clampf(player["pos"].x + randf_range(-140.0, 140.0), 140.0, VIEW_W - 140.0), randf_range(80.0, 160.0))
			_teleport_boss(boss, warp_pos, false)
			boss["teleport_timer"] = randf_range(2.6, 4.0) if not boss["enraged"] else randf_range(1.6, 2.6)
		else:
			# Phase 2 Beast Mode aggressive warps: rapid blinks near player, apex sky, or behind
			var b_warp_type: int = randi() % 4
			if b_warp_type == 0:
				warp_pos = Vector2(clampf(player["pos"].x + randf_range(-60.0, 60.0), 140.0, VIEW_W - 140.0), 110.0)
			elif b_warp_type == 1:
				var flank_x: float = player["pos"].x - player["facing"] * 240.0
				warp_pos = Vector2(clampf(flank_x, 140.0, VIEW_W - 140.0), randf_range(140.0, 240.0))
			elif b_warp_type == 2:
				warp_pos = Vector2(VIEW_W * 0.5 + randf_range(-180.0, 180.0), 90.0)
			else:
				warp_pos = Vector2(clampf(player["pos"].x + (220.0 if randf() > 0.5 else -220.0), 120.0, VIEW_W - 120.0), GROUND_Y - 90.0)
			_teleport_boss(boss, warp_pos, true)
			boss["teleport_timer"] = randf_range(1.1, 1.9)

	# --- Smooth Floating Movement between Teleports ---
	var move_spd: float = 460.0 if is_p2 else (390.0 if boss["enraged"] else 270.0)
	if boss["retarget_timer"] <= 0.0 or boss["pos"].distance_to(boss["target_pos"]) < 45.0:
		boss["target_pos"] = Vector2(randf_range(160.0, VIEW_W - 160.0), randf_range(80.0, 240.0))
		boss["retarget_timer"] = randf_range(0.6, 1.2) if is_p2 else (randf_range(0.9, 1.8) if not boss["enraged"] else randf_range(0.5, 1.1))

	var desired_vel: Vector2 = (boss["target_pos"] - boss["pos"]).normalized() * move_spd
	desired_vel.y += sin(boss["anim"] * (3.5 if is_p2 else 2.2)) * (65.0 if is_p2 else 45.0)
	boss["vel"] = boss["vel"].lerp(desired_vel, (9.0 if is_p2 else 7.0) * delta)
	boss["pos"] += boss["vel"] * delta
	boss["pos"].x = clampf(boss["pos"].x, 90.0, VIEW_W - 90.0)
	boss["pos"].y = clampf(boss["pos"].y, 65.0, 320.0)

	# --- Attack Timers and Patterns ---
	boss["shoot_timer"] -= delta
	var charge_window: float = 0.18 if is_p2 else (0.20 if boss["enraged"] else 0.35)
	boss["charge_glow"] = clampf(1.0 - (boss["shoot_timer"] / charge_window), 0.0, 1.0) if boss["shoot_timer"] < charge_window else 0.0

	if boss["shoot_timer"] <= 0.0:
		var cd: float = (randf_range(0.38, 0.58) if is_p2 else (0.42 if boss["enraged"] else 0.70))
		boss["shoot_timer"] = cd
		boss["attack_pattern"] = (boss["attack_pattern"] + 1) % 4

		var base_aim: Vector2 = (p_center - boss["pos"]).normalized()
		var spd: float = boss["laser_speed"] if not boss["enraged"] else (boss["laser_speed"] + 70.0)
		if is_p2:
			spd = 520.0

		if not is_p2:
			# ================= PHASE 1 PATTERNS =================
			# Pattern 0: Holy Sun Spears (3 fast golden lasers)
			if boss["attack_pattern"] == 0:
				for i in range(3):
					var ang_offset: float = (i - 1) * 0.18
					var dir: Vector2 = base_aim.rotated(ang_offset)
					_spawn_boss_laser(boss, boss["pos"] + dir * 20.0, dir, spd, Color("ffd700"))
				screen_shake = maxf(screen_shake, 8.0)
				_play_sfx(880.0, 360.0, 0.16, 0)
				_add_floating_text("HOLY SUN SPEARS!", boss["pos"] + Vector2(0, -55), Color("ffd700"))

			# Pattern 1: Pillars of Heaven (Divine ground strikes!)
			elif boss["attack_pattern"] == 1:
				var pillar_xs: Array = [player["pos"].x - 180.0, player["pos"].x, player["pos"].x + 180.0]
				for px in pillar_xs:
					var cx: float = clampf(px, 120.0, VIEW_W - 120.0)
					_add_ground_shock(cx, 160.0, Color("ffd700"), 420.0)
					_add_ground_fissure(cx - 70.0, cx + 70.0, Color("ffe066"))
					_spawn_ground_debris(cx, 16, Color("ffd700"))
					_spawn_boss_laser(boss, Vector2(cx, GROUND_Y - 10), Vector2(0, -1).rotated(randf_range(-0.25, 0.25)), 460.0, Color("fffbe6"))
				screen_shake = maxf(screen_shake, 24.0)
				_play_sfx(160.0, 40.0, 0.55, 1)
				_add_floating_text("PILLARS OF HEAVEN!", boss["pos"] + Vector2(0, -55), Color("ffe550"))

			# Pattern 2: Aureate Supernova (12-16 parriable solar discs)
			elif boss["attack_pattern"] == 2:
				var disc_count: int = 12 if not boss["enraged"] else 16
				for k in range(disc_count):
					var ang: float = k * (TAU / float(disc_count)) + boss["anim"] * 0.5
					var dir := Vector2(cos(ang), sin(ang))
					_spawn_boss_laser(boss, boss["pos"], dir, spd * 0.88, Color("ffe066"))
				screen_shake = maxf(screen_shake, 18.0)
				_play_sfx(1040.0, 240.0, 0.28, 0)
				_add_floating_text("AUREATE SUPERNOVA!", boss["pos"] + Vector2(0, -55), Color("ffe550"))

			# Pattern 3: Celestial Warp Convergence
			else:
				for ang in [-0.35, -0.15, 0.0, 0.15, 0.35]:
					var dir: Vector2 = base_aim.rotated(ang)
					_spawn_boss_laser(boss, boss["pos"], dir, spd * 1.05, Color.WHITE)
				screen_shake = maxf(screen_shake, 14.0)
				_play_sfx(960.0, 310.0, 0.20, 0)
				_add_floating_text("WARP CONVERGENCE!", boss["pos"] + Vector2(0, -55), Color.WHITE)
		else:
			# ================= PHASE 2 BEAST MODE (IMPOSSIBLE) =================
			# Pattern 0: Shadow Blink Blitz (Fires crimson void spears & blinks)
			if boss["attack_pattern"] == 0:
				for ang in [-0.22, 0.0, 0.22]:
					var dir: Vector2 = base_aim.rotated(ang)
					_spawn_boss_laser(boss, boss["pos"] + dir * 26.0, dir, spd * 1.15, Color("ff0055"))
				screen_shake = maxf(screen_shake, 16.0)
				_play_sfx(920.0, 180.0, 0.22, 0)
				_add_floating_text("SHADOW BLINK ASSAULT!", boss["pos"] + Vector2(0, -55), Color("ff0055"))

			# Pattern 1: Abyssal Singularity (16 spiraling parriable void scythes)
			elif boss["attack_pattern"] == 1:
				var void_count := 16
				for k in range(void_count):
					var ang: float = k * (TAU / float(void_count)) + boss["anim"] * 0.8
					var dir := Vector2(cos(ang), sin(ang))
					_spawn_boss_laser(boss, boss["pos"], dir, spd * 0.85, Color("a800ff") if k % 2 == 0 else Color("ff0055"))
				screen_shake = maxf(screen_shake, 26.0)
				_play_sfx(1120.0, 160.0, 0.35, 0)
				_add_floating_text("ABYSSAL SINGULARITY!", boss["pos"] + Vector2(0, -55), Color("a800ff"))

			# Pattern 2: Cataclysmic Beast Slam (Erupts ground fissures across arena)
			elif boss["attack_pattern"] == 2:
				var slam_xs: Array = [player["pos"].x - 220.0, player["pos"].x, player["pos"].x + 220.0]
				for sx in slam_xs:
					var cx: float = clampf(sx, 100.0, VIEW_W - 100.0)
					_add_ground_shock(cx, 180.0, Color("ff0055"), 480.0)
					_add_ground_fissure(cx - 90.0, cx + 90.0, Color("ff2a55"))
					_spawn_ground_debris(cx, 20, Color("ff0055"))
					_spawn_boss_laser(boss, Vector2(cx, GROUND_Y - 12), Vector2(0, -1).rotated(randf_range(-0.35, 0.35)), 520.0, Color("ff0055"))
				screen_shake = maxf(screen_shake, 38.0)
				_play_sfx(110.0, 25.0, 0.75, 1)
				_add_floating_text("CATACLYSMIC BEAST SLAM!", boss["pos"] + Vector2(0, -55), Color("ff0055"))

			# Pattern 3: Dimensional Void Slicers (8-way intersecting hyper-lasers)
			else:
				var slice_angles: Array = [-0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6]
				for s_ang in slice_angles:
					var dir: Vector2 = base_aim.rotated(s_ang)
					_spawn_boss_laser(boss, boss["pos"], dir, spd * 1.25, Color.WHITE if s_ang == 0.0 else Color("ff0055"))
				screen_shake = maxf(screen_shake, 22.0)
				_play_sfx(1050.0, 280.0, 0.28, 0)
				_add_floating_text("DIMENSIONAL VOID SLICERS!", boss["pos"] + Vector2(0, -55), Color("ff0055"))

func _spawn_boss_laser(boss: Dictionary, origin: Vector2, dir: Vector2, spd: float, col: Color) -> void:
	lasers.append({
		"pos": origin + dir * 26.0,
		"vel": dir * spd,
		"speed": spd,
		"bounced": false,
		"owner": boss,
		"homing_target": null,
		"color": col,
		"trail": []
	})

func _damage_boss(boss: Dictionary, laser_idx: int = -1) -> void:
	boss["hp"] -= 1
	boss["hit_flash"] = 0.22
	screen_shake = maxf(screen_shake, 16.0)
	_play_sfx(220.0, 60.0, 0.32, 1)

	var hit_col: Color = boss.get("color", Color("ff2a55"))
	_spawn_burst(boss["pos"], hit_col, 28, 280.0)
	_spawn_burst(boss["pos"], Color("41f3ff"), 18, 220.0)
	_add_floating_text("BOSS HIT! [%d/%d]" % [boss["hp"], boss["max_hp"]], boss["pos"] + Vector2(0, -60), hit_col)

	if laser_idx >= 0 and laser_idx < lasers.size():
		lasers.remove_at(laser_idx)

	# --- Wave 10 Phase 1 -> Phase 2 Beast Mode Transition Check ---
	if boss.get("type", 0) == 102 and boss.get("phase", 1) == 1 and boss["hp"] <= 0:
		boss["hp"] = 0
		boss_trans_active = true
		boss_trans_timer = 5.8
		boss_trans_flash = 1.0
		reached_wave10_phase2 = true
		wave10_phase = 2
		player["invuln_timer"] = 7.0
		screen_shake = 35.0
		_play_sfx(140.0, 35.0, 1.0, 1)
		_spawn_burst(boss["pos"], Color("ffd700"), 60, 380.0)
		_add_floating_text("SOLAR CORE CRITICAL OVERLOAD!", boss["pos"] + Vector2(0, -60), Color("ffd700"))
		return

	# --- Boss Defeat (Normal Bosses or Wave 10 Phase 2 Defeated) ---
	if boss["hp"] <= 0:
		screen_shake = 45.0 if boss.get("phase", 1) == 2 else 36.0
		_play_sfx(100.0 if boss.get("phase", 1) == 2 else 140.0, 30.0, 1.3, 1)
		_spawn_burst(boss["pos"], hit_col, 80, 450.0)
		_spawn_burst(boss["pos"], Color("ff0055") if boss.get("phase", 1) == 2 else Color("ffe762"), 60, 400.0)
		_spawn_burst(boss["pos"], Color("41f3ff"), 60, 360.0)
		_add_floating_text("%s DEFEATED!" % boss["name"], Vector2(VIEW_W * 0.5, 200), Color("ffe762") if boss.get("phase", 1) != 2 else Color("ff0055"))
		if boss.get("phase", 1) == 2:
			reached_wave10_phase2 = false
			wave10_phase = 1
		mobs.erase(boss)

func _get_nearest_mob(from_pos: Vector2):
	var best = null
	var best_d := 999999.0
	for m in mobs:
		var d: float = from_pos.distance_to(m["pos"])
		if d < best_d:
			best_d = d
			best = m
	return best

# ==============================================================================
# LASERS & AIMBOT TRACKING COLLISIONS WITH GROUND EFFECTS
# ==============================================================================
func _update_lasers(delta: float) -> void:
	if boss_trans_active:
		lasers.clear()
		return

	var p_center: Vector2 = player["pos"] - Vector2(0, player["h"] * 0.5)

	for i in range(lasers.size() - 1, -1, -1):
		if boss_trans_active:
			lasers.clear()
			return
		if i >= lasers.size():
			continue
		var l = lasers[i]
		l["trail"].append(l["pos"])
		if l["trail"].size() > 8:
			l["trail"].pop_front()

		# AIMBOT HOMING LOGIC
		if l["bounced"] and l["homing_target"] != null and mobs.has(l["homing_target"]):
			var target_mob = l["homing_target"]
			var to_target: Vector2 = target_mob["pos"] - l["pos"]
			if to_target.length_squared() > 16.0:
				var desired_dir: Vector2 = to_target.normalized()
				var cur_speed: float = l["speed"]
				var cur_dir: Vector2 = l["vel"].normalized()
				var new_dir: Vector2 = cur_dir.lerp(desired_dir, 16.0 * delta).normalized()
				l["vel"] = new_dir * cur_speed

		l["pos"] += l["vel"] * delta

		if l["pos"].x < -90.0 or l["pos"].x > VIEW_W + 90.0 or l["pos"].y < -90.0 or l["pos"].y > VIEW_H + 90.0:
			lasers.remove_at(i)
			continue

		if not l["bounced"]:
			if player["parry_active_timer"] > 0.0 and l["pos"].distance_to(p_center) <= PARRY_RADIUS:
				_check_parry_deflection()
				continue

			var p_rect: Rect2 = Rect2(player["pos"].x - player["w"] * 0.45, player["pos"].y - player["h"], player["w"] * 0.9, player["h"])
			if p_rect.grow(3.0).has_point(l["pos"]):
				if bandit_dashing or player["invuln_timer"] > 0.0:
					_spawn_burst(l["pos"], Color("38ffff"), 4, 80.0)
					continue
				lasers.remove_at(i)
				_damage_player()
				continue

			# Laser hits ground -> CRAZY GROUND EFFECTS!
			if l["pos"].y >= GROUND_Y:
				_add_ground_shock(l["pos"].x, 70.0, l["color"], 320.0)
				_spawn_ground_debris(l["pos"].x, 6, l["color"])
				screen_shake = maxf(screen_shake, (3.5 if _is_boss_wave() else 0.5))
				_spawn_burst(l["pos"], l["color"], 7, 90.0)
				lasers.remove_at(i)
				continue
		else:
			# Bounced / Aimbot laser: hits mobs or bosses
			var hit_any := false
			for j in range(mobs.size() - 1, -1, -1):
				var m = mobs[j]
				if l["pos"].distance_to(m["pos"]) <= m["radius"] + 14.0:
					hit_any = true
					if m.get("is_boss", false):
						_damage_boss(m, i)
						if boss_trans_active:
							lasers.clear()
							return
					else:
						_spawn_burst(m["pos"], Color("ff5555"), 24, 240.0)
						_spawn_burst(m["pos"], Color("73eff7"), 14, 180.0)
						_add_floating_text("ELIMINATED!", m["pos"], Color("ffdd55"))
						_play_sfx(240.0, 75.0, 0.22, 1)
						screen_shake = maxf(screen_shake, (8.5 if _is_boss_wave() else 2.0))
						mobs.remove_at(j)
						lasers.remove_at(i)
					break
			if hit_any:
				continue

func _damage_player() -> void:
	if player["invuln_timer"] > 0.0:
		return
	player["hearts"] -= 1
	player["invuln_timer"] = 0.65
	screen_shake = maxf(screen_shake, (14.0 if _is_boss_wave() else 4.0))
	_play_sfx(180.0, 65.0, 0.26, 1)
	_spawn_burst(player["pos"] - Vector2(0, 18), Color("ff2a4b"), 22, 220.0)
	_add_floating_text("-1 HEART!", player["pos"] - Vector2(0, 46), Color("ff4b6b"))

	if player["hearts"] <= 0:
		state = State.GAME_OVER
		_play_sfx(140.0, 50.0, 0.55, 1)

# ==============================================================================
# PARTICLES & FLOATING TEXT
# ==============================================================================
func _spawn_burst(pos: Vector2, col: Color, count: int, max_spd: float) -> void:
	for i in range(count):
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(35.0, max_spd)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"color": col,
			"life": randf_range(0.22, 0.52),
			"max_life": 0.52,
			"size": randf_range(3.0, 6.5)
		})

func _add_floating_text(txt: String, pos: Vector2, col: Color) -> void:
	floating_texts.append({
		"text": txt,
		"pos": pos,
		"color": col,
		"life": 0.85
	})

func _update_particles_and_text(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			particles.remove_at(i)
			continue
		p["pos"] += p["vel"] * delta
		p["vel"] *= exp(-4.0 * delta)

	for i in range(wind_particles.size() - 1, -1, -1):
		var wp = wind_particles[i]
		wp["life"] -= delta
		if wp["life"] <= 0.0:
			wind_particles.remove_at(i)
			continue
		wp["pos"] += wp["vel"] * delta
		wp["vel"] *= exp(-3.0 * delta)

	for i in range(floating_texts.size() - 1, -1, -1):
		var ft = floating_texts[i]
		ft["life"] -= delta
		ft["pos"].y -= 38.0 * delta
		if ft["life"] <= 0.0:
			floating_texts.remove_at(i)


# ==============================================================================
# CUSTOM RENDERING (DYNAMIC BACKGROUND, PARTICLES, MOBS, BOSSES & UI)
# ==============================================================================
func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake))

	draw_set_transform(shake_offset, screen_shake_rot, Vector2.ONE)

	_draw_dynamic_grief_background()
	_draw_platforms_and_ground()
	_draw_ground_effects()

	if state in [State.PLAYING, State.TRANSITION, State.GAME_OVER, State.VICTORY]:
		_draw_dash_ghosts()
		_draw_teleport_ghosts()
		_draw_sci_fi_teleports()
		_draw_player()
		_draw_mobs()
		_draw_lasers()
		_draw_particles_and_texts()
		_draw_hud()

	# Transformation Singularity Vortex during Phase 1 -> Phase 2 Cutscene
	if boss_trans_active and boss_trans_timer > 2.2 and boss_trans_timer <= 3.6:
		var c_pos := Vector2(VIEW_W * 0.5, 200.0)
		var sing_prog: float = (3.6 - boss_trans_timer) / 1.4
		var sing_r: float = 85.0 + sin(sing_prog * TAU * 3.0) * 18.0
		draw_circle(c_pos, sing_r, Color(0.04, 0.02, 0.08, 0.90))
		draw_arc(c_pos, sing_r * 1.15, 0.0, TAU, 32, Color("ff0055", 0.85), 3.5)
		draw_arc(c_pos, sing_r * 1.35, 0.0, TAU, 32, Color("00f5ff", 0.65), 2.5)

	# Cinematic Letterbox Black Bars during Metamorphosis Cutscene
	if cinematic_bars_height > 0.01:
		_draw_cinematic_bars()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Full-screen Whiteout Flash for Phase 2 Metamorphosis
	if boss_trans_flash > 0.001:
		draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(1.0, 1.0, 1.0, clampf(boss_trans_flash, 0.0, 1.0)))

	if state == State.MENU:
		_draw_main_menu()
	elif state == State.GAME_OVER:
		_draw_game_over_overlay()
	elif state == State.VICTORY:
		_draw_victory_overlay()

	if state == State.TRANSITION or transition_alpha > 0.001:
		_draw_wave_transition_overlay()

	if boss_warning_timer > 0.0:
		_draw_boss_warning(boss_warning_timer)

	if console_open:
		_draw_console()

# --- Dynamic Background (Transitions by Wave: Normal, Wave 5 Blood, Wave 7 Purple Void, Wave 10 Golden Twilight & Phase 2 Cyber-Void) ---
func _draw_dynamic_grief_background() -> void:
	# Wave 10 Phase 2: HYPER-TRYHARD EPILEPTIC CYBER-VOID (BEAST MODE)
	if current_wave == 10 and (wave10_phase == 2 or reached_wave10_phase2) and state in [State.PLAYING, State.TRANSITION, State.GAME_OVER]:
		_draw_tryhard_phase2_background()
		return

	var pulse_r: float = grief_pulse_flash * 0.45
	var sky_top := Color(0.04 + pulse_r, 0.02, 0.06)
	var sky_mid := Color(0.12 + pulse_r * 1.2, 0.03, 0.07)
	var sky_bot := Color(0.20 + pulse_r * 1.5, 0.05, 0.10)
	var beam_base_col := Color(1.0, 0.15, 0.25)

	# Wave 5: Apocalyptic Blood Red
	if current_wave == 5 and state == State.PLAYING:
		sky_top = Color(0.15 + pulse_r, 0.01, 0.03)
		sky_mid = Color(0.28 + pulse_r * 1.5, 0.03, 0.06)
		sky_bot = Color(0.42 + pulse_r * 2.0, 0.06, 0.10)
		beam_base_col = Color(1.0, 0.10, 0.18)

	# Wave 7: Electric Purple Void Abyss
	elif current_wave == 7 and state == State.PLAYING:
		sky_top = Color(0.06, 0.01 + pulse_r * 0.4, 0.14 + pulse_r)
		sky_mid = Color(0.13, 0.02 + pulse_r * 0.8, 0.26 + pulse_r * 1.4)
		sky_bot = Color(0.22, 0.04 + pulse_r * 1.1, 0.38 + pulse_r * 1.8)
		beam_base_col = Color(0.65, 0.20, 1.0)

	# Wave 10: Celestial Twilight with Golden Radiance
	elif current_wave == 10 and state == State.PLAYING:
		sky_top = Color(0.12 + pulse_r * 0.8, 0.08 + pulse_r * 0.6, 0.02)
		sky_mid = Color(0.25 + pulse_r * 1.2, 0.18 + pulse_r * 1.0, 0.04)
		sky_bot = Color(0.38 + pulse_r * 1.6, 0.28 + pulse_r * 1.3, 0.08)
		beam_base_col = Color(1.0, 0.84, 0.20)

	draw_rect(Rect2(0, 0, VIEW_W, 240), sky_top)
	draw_rect(Rect2(0, 240, VIEW_W, 200), sky_mid)
	draw_rect(Rect2(0, 440, VIEW_W, VIEW_H - 440), sky_bot)

	# Background Laser Beams / Light Pillars
	for col in grief_laser_columns:
		var col_x: float = col["x"]
		var w: float = col["width"] * (1.0 + 0.3 * sin(col["phase"]))
		var a: float = col["intensity"] + grief_pulse_flash * 0.35
		draw_rect(Rect2(col_x - w * 0.5, 0, w, GROUND_Y), Color(beam_base_col.r, beam_base_col.g, beam_base_col.b, clampf(a, 0.05, 0.65)))
		draw_rect(Rect2(col_x - w * 0.15, 0, w * 0.3, GROUND_Y), Color(1.0, 0.95, 0.95, clampf(a * 1.4, 0.08, 0.85)))

	# Golden Sun Rays in Wave 10
	if current_wave == 10 and state == State.PLAYING:
		for r_idx in range(7):
			var ray_x: float = 80.0 + r_idx * 190.0 + sin(Time.get_ticks_msec() * 0.001 + r_idx) * 35.0
			var ray_alpha: float = 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.002 + r_idx * 1.5)
			draw_line(Vector2(ray_x, 0), Vector2(ray_x + 60.0, GROUND_Y), Color(1.0, 0.90, 0.40, ray_alpha), 16.0)

	# Obsidian Mountain Polygons
	var m_col1 := Color("140912") if current_wave != 7 else Color("12081c")
	var m_col2 := Color("200d18") if current_wave != 7 else Color("1c0d28")
	if current_wave == 10:
		m_col1 = Color("1e1408")
		m_col2 = Color("2d2010")

	var m1 := PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(0, 390), Vector2(180, 260), Vector2(390, 410),
		Vector2(620, 230), Vector2(880, 400), Vector2(1090, 275), Vector2(VIEW_W, 370), Vector2(VIEW_W, GROUND_Y)
	])
	draw_colored_polygon(m1, m_col1)

	var m2 := PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(0, 470), Vector2(240, 420), Vector2(510, 485),
		Vector2(790, 415), Vector2(1040, 470), Vector2(VIEW_W, 435), Vector2(VIEW_W, GROUND_Y)
	])
	draw_colored_polygon(m2, m_col2)

	# Hanging Chains
	for ch in grief_chains:
		var cx: float = ch["x"]
		var l: float = ch["len"]
		for k in range(0, int(l), 10):
			draw_rect(Rect2(cx - 3, k, 6, 8), Color("2e1c25"))
			draw_rect(Rect2(cx - 1.5, k + 2, 3, 4), Color("4d313e"))
		var cs: float = ch["crystal_size"]
		var tip := Vector2(cx, l + cs * 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - cs * 0.6, l),
			Vector2(cx + cs * 0.6, l),
			tip
		]), Color("180a14"))
		var crystal_core_col: Color = beam_base_col
		draw_line(Vector2(cx, l + 2), tip - Vector2(0, 3), Color(crystal_core_col.r, crystal_core_col.g, crystal_core_col.b, 0.75), 2.0)

	# Demon Eyes
	for eye in grief_eyes:
		if eye["open_amount"] > 0.05:
			var ep: Vector2 = eye["pos"]
			var oa: float = eye["open_amount"]
			draw_line(ep - Vector2(12, 0), ep + Vector2(12, 0), Color("4a0e1c", oa), 3.0)
			draw_circle(ep, 6.0 * oa, Color(beam_base_col.r, beam_base_col.g, beam_base_col.b, oa))
			draw_circle(ep, 2.5 * oa, Color("ffffff", oa))

	# Twisted Underworld Trees
	for t in trees:
		var tx: float = t["x"]
		var th: float = t["h"]
		var tw: float = t["w"]
		var cr: float = t["canopy"]
		draw_rect(Rect2(tx - tw * 0.5, GROUND_Y - th, tw, th), Color("2c171e"))
		draw_rect(Rect2(tx - tw * 0.3, GROUND_Y - th, tw * 0.35, th), Color("3d212a"))
		draw_rect(Rect2(tx - tw * 0.8, GROUND_Y - 14, tw * 1.6, 14), Color("2c171e"))

		var top_y: float = GROUND_Y - th
		var leaf_dark := Color(0.28, 0.08, 0.14)
		var leaf_mid := Color(0.42, 0.12, 0.20)
		var leaf_bright := Color(0.60, 0.18, 0.26)
		if current_wave == 7:
			leaf_dark = Color(0.18, 0.06, 0.28)
			leaf_mid = Color(0.28, 0.10, 0.42)
			leaf_bright = Color(0.44, 0.16, 0.62)
		elif current_wave == 10:
			leaf_dark = Color(0.28, 0.20, 0.06)
			leaf_mid = Color(0.42, 0.30, 0.10)
			leaf_bright = Color(0.65, 0.50, 0.16)

		draw_circle(Vector2(tx - cr * 0.45, top_y + 12), cr * 0.62, leaf_dark)
		draw_circle(Vector2(tx + cr * 0.45, top_y + 12), cr * 0.62, leaf_dark)
		draw_circle(Vector2(tx, top_y - cr * 0.25), cr * 0.78, leaf_mid)
		draw_circle(Vector2(tx - cr * 0.22, top_y - cr * 0.38), cr * 0.48, leaf_bright)

	# Floating Embers (Color changes by wave)
	for em in grief_embers:
		var ep: Vector2 = em["pos"]
		var col: Color = Color("ff3b3b") if em["hue"] < 0.65 else Color("ff9e2c")
		if current_wave == 7:
			col = Color("9b5de5") if em["hue"] < 0.65 else Color("c77dff")
		elif current_wave == 10:
			col = Color("ffd700") if em["hue"] < 0.65 else Color("fff3b0")
		col.a = em["alpha"]
		draw_rect(Rect2(ep.x, ep.y, em["size"], em["size"]), col)

	for f in fireflies:
		var alpha: float = 0.35 + 0.45 * sin(f["phase"])
		draw_rect(Rect2(f["pos"].x, f["pos"].y, 4, 4), Color(1.0, 0.65, 0.85, alpha))

# --- HYPER-TRYHARD EPILEPTIC CYBER-VOID BACKGROUND (WAVE 10 PHASE 2 BEAST MODE) ---
func _draw_tryhard_phase2_background() -> void:
	var t_msec: float = Time.get_ticks_msec()
	var beat: float = sin(t_msec * 0.018)
	var beat_fast: float = sin(t_msec * 0.045)

	# 1. Dynamic Chromatic Strobe Void Background
	var bg_r: float = 0.07 + (0.16 if beat > 0.35 else 0.0) + (0.24 if beat_fast > 0.88 else 0.0)
	var bg_g: float = 0.01 + (0.04 if beat_fast > 0.88 else 0.0)
	var bg_b: float = 0.08 + (0.14 if beat < -0.3 else 0.0)
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(bg_r, bg_g, bg_b))

	var vp := Vector2(VIEW_W * 0.5, 335.0)

	# 2. Hyper-Speed 3D Synthwave Perspective Floor Grid
	for ang_i in range(-14, 15):
		var bot_x: float = vp.x + ang_i * 82.0
		var line_col := Color("ff0055", 0.60 if abs(ang_i) % 2 == 0 else 0.28)
		draw_line(vp, Vector2(bot_x, VIEW_H), line_col, 2.0)

	var scroll_floor: float = fmod(t_msec * 0.0016, 1.0)
	for d_i in range(14):
		var prog: float = fmod(scroll_floor + float(d_i) / 14.0, 1.0)
		var y_depth: float = vp.y + pow(prog, 2.3) * (VIEW_H - vp.y)
		var half_w: float = pow(prog, 1.5) * VIEW_W * 0.88
		var line_a: float = prog * 0.80
		draw_line(Vector2(vp.x - half_w, y_depth), Vector2(vp.x + half_w, y_depth), Color(1.0, 0.0, 0.35, line_a), 2.2)

	# 3. Hyper-Speed Ceiling Perspective Grid
	for ang_i in range(-12, 13):
		var top_x: float = vp.x + ang_i * 92.0
		draw_line(vp, Vector2(top_x, 0), Color("a800ff", 0.38 if abs(ang_i) % 2 == 0 else 0.18), 1.5)

	# 4. Giant 3D Rotating Wireframe Geometric Hypercubes in Background
	for side_x in [VIEW_W * 0.20, VIEW_W * 0.80]:
		var rot_cube: float = t_msec * 0.0024 * (1.0 if side_x > VIEW_W * 0.5 else -1.0)
		var cube_center := Vector2(side_x, 185.0)
		var cube_r: float = 75.0 + sin(t_msec * 0.006) * 14.0
		var poly_pts := PackedVector2Array()
		for pt_i in range(8):
			var p_ang: float = pt_i * (TAU / 8.0) + rot_cube
			var p_pt: Vector2 = cube_center + Vector2(cos(p_ang), sin(p_ang) * 0.52) * cube_r
			poly_pts.append(p_pt)
		poly_pts.append(poly_pts[0])
		draw_polyline(poly_pts, Color("ff0055", 0.70), 2.5)

		var inner_pts := PackedVector2Array()
		for ip_i in range(4):
			var ip_ang: float = ip_i * (TAU / 4.0) - rot_cube * 1.6
			inner_pts.append(cube_center + Vector2(cos(ip_ang), sin(ip_ang)) * (cube_r * 0.55))
		inner_pts.append(inner_pts[0])
		draw_polyline(inner_pts, Color("00f5ff", 0.80), 2.0)

	# 5. Hyper-Speed Vertical Data Streams / Matrix Speedlines
	for s_idx in range(24):
		var stream_x: float = fmod(s_idx * 55.0 + t_msec * 0.08, VIEW_W)
		var stream_y: float = fmod(t_msec * (0.8 + (s_idx % 5) * 0.25) + s_idx * 70.0, VIEW_H)
		var stream_len: float = 65.0 + (s_idx % 4) * 35.0
		draw_line(Vector2(stream_x, stream_y), Vector2(stream_x, stream_y + stream_len), Color("ff0055", 0.50), 2.0)
		draw_circle(Vector2(stream_x, stream_y + stream_len), 2.5, Color.WHITE)

	# 6. Tryhard HUD Telemetry & Combat Watermarks in Background
	var font := ThemeDB.fallback_font
	var watermark_text := "// APEX PROTOCOL: ECLIPSE BEAST [OVERCLOCK 100%] // THREAT LEVEL: MAXIMUM //"
	var wm_x: float = fmod(-t_msec * 0.24, 600.0)
	draw_string(font, Vector2(wm_x, 48), watermark_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff0055", 0.40))
	draw_string(font, Vector2(wm_x + 600, 48), watermark_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff0055", 0.40))

	# Audio-reactive frequency visualizer bars leaping on horizon
	for eq_i in range(32):
		var eq_x: float = 40.0 + eq_i * (VIEW_W - 80.0) / 32.0
		var eq_h: float = abs(sin(t_msec * 0.012 + eq_i * 0.42)) * 60.0 + 10.0
		var eq_col: Color = Color("ff0055", 0.65) if eq_i % 2 == 0 else Color("00f5ff", 0.65)
		draw_rect(Rect2(eq_x, vp.y - eq_h, 8.0, eq_h), eq_col)

	# 7. Random 1-frame Horizontal Glitch Tearing Slices
	if int(t_msec * 0.06) % 8 == 0:
		var g_y: float = randf_range(60.0, VIEW_H - 60.0)
		var g_h: float = randf_range(8.0, 38.0)
		draw_rect(Rect2(0, g_y, VIEW_W, g_h), Color(1.0, 0.0, 0.35, 0.32))

func _draw_platforms_and_ground() -> void:
	var trim_col := Color("ff2a55")
	if current_wave == 7:
		trim_col = Color("9b5de5")
	elif current_wave == 10:
		trim_col = Color("ffd700")

	for plat in platforms:
		draw_rect(Rect2(plat.position.x + 6, plat.position.y + 6, plat.size.x - 12, plat.size.y), Color(0, 0, 0, 0.55))
		draw_rect(plat, Color("2d1a24"))
		draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 4), trim_col)
		draw_rect(Rect2(plat.position.x, plat.position.y + 4, plat.size.x, 3), Color("4a1220"))

		var num_joints := int(plat.size.x / 36.0)
		for k in range(1, num_joints):
			var jx: float = plat.position.x + k * 36.0
			draw_line(Vector2(jx, plat.position.y + 5), Vector2(jx, plat.position.y + plat.size.y), Color("1a0e15"), 2.0)
		draw_rect(plat, Color("140910"), false, 2.0)

	draw_rect(Rect2(0, GROUND_Y, VIEW_W, VIEW_H - GROUND_Y), Color("2b161f"))
	for gx in range(0, int(VIEW_W), 32):
		for gy in range(int(GROUND_Y) + 16, int(VIEW_H), 28):
			draw_rect(Rect2(gx + 4, gy + 4, 24, 20), Color("200f16"))
			if (gx + gy) % 64 == 0:
				draw_rect(Rect2(gx + 10, gy + 8, 8, 8), Color(trim_col.r, trim_col.g, trim_col.b, 0.75))

	draw_rect(Rect2(0, GROUND_Y, VIEW_W, 10), trim_col)
	draw_rect(Rect2(0, GROUND_Y + 10, VIEW_W, 5), Color("7a162b"))
	for g in grass_tufts:
		draw_line(Vector2(g["x"], GROUND_Y), Vector2(g["x"] + g["lean"], GROUND_Y - g["h"]), Color(trim_col.r, trim_col.g, trim_col.b, 0.8), 2.5)

# --- Crazy Ground Effects Rendering ---
func _draw_ground_effects() -> void:
	# 1. Glowing ground fissures
	for gf in ground_fissures:
		var alpha: float = clampf(gf["life"] / gf["max_life"], 0.0, 1.0)
		var c: Color = gf["col"]
		c.a = alpha
		var width := 3.5 * alpha
		draw_line(Vector2(gf["x1"], GROUND_Y), Vector2(gf["x2"], GROUND_Y), c, width)
		# Molten glow line
		draw_line(Vector2(gf["x1"] + 10, GROUND_Y + 2), Vector2(gf["x2"] - 10, GROUND_Y + 2), Color(1, 1, 1, alpha * 0.8), 1.5)

	# 2. Expanding ground shockwaves
	for gs in ground_shocks:
		var alpha: float = clampf(gs["life"] / gs["max_life"], 0.0, 1.0)
		var c: Color = gs["col"]
		c.a = alpha * 0.85
		var r: float = gs["r"]
		# Draw shockwave arc on the ground
		draw_arc(Vector2(gs["x"], GROUND_Y), r, -PI, 0.0, 32, c, 3.5 * alpha)
		# Horizontal ground expansion line
		draw_line(Vector2(gs["x"] - r, GROUND_Y), Vector2(gs["x"] + r, GROUND_Y), Color(c.r, c.g, c.b, alpha * 0.6), 4.0 * alpha)

	# 3. Flying ground debris
	for gd in ground_debris:
		var alpha: float = clampf(gd["life"] / gd["max_life"], 0.0, 1.0)
		var c: Color = gd["col"]
		c.a = alpha
		var sz: float = gd["size"] * alpha
		draw_rect(Rect2(gd["pos"].x - sz * 0.5, gd["pos"].y - sz * 0.5, sz, sz), c)

# --- Player Drawing ---
func _draw_dash_ghosts() -> void:
	for g in dash_ghosts:
		var gp: Vector2 = g["pos"]
		var ga: float = g["alpha"]
		draw_rect(Rect2(gp.x - 7, gp.y - 36, 14, 34), Color(0.22, 0.95, 1.0, ga * 0.5))

func _draw_teleport_ghosts() -> void:
	for g in teleport_ghosts:
		var col: Color = g.get("color", Color("ffd700"))
		var a: float = g.get("alpha", 0.5)
		var r: float = g.get("radius", 46.0)
		var p: Vector2 = g.get("pos", Vector2.ZERO)
		var is_p2: bool = (g.get("phase", 1) == 2)
		if not is_p2:
			draw_circle(p, r, Color(col.r, col.g, col.b, a * 0.35))
			draw_arc(p, r * 1.25, 0.0, TAU, 24, Color(1, 1, 1, a * 0.5), 2.0)
		else:
			draw_circle(p, r, Color(0.04, 0.04, 0.08, a * 0.55))
			draw_arc(p, r * 1.3, 0.0, TAU, 24, Color(1, 0, 0.33, a * 0.6), 2.5)

# --- SCI-FI QUANTUM TELEPORTATION RENDERING ---
func _draw_sci_fi_teleports() -> void:
	var font := ThemeDB.fallback_font
	for tp in sci_fi_teleports:
		var from_p: Vector2 = tp["from_pos"]
		var to_p: Vector2 = tp["to_pos"]
		var prog: float = clampf(tp["timer"] / tp["max_timer"], 0.0, 1.0)
		var col: Color = tp["color"]
		var is_b: bool = tp["is_beast"]

		# 1. Hyper-Space Quantum Beam connecting departure to arrival
		var beam_alpha: float = clampf(prog * 1.8, 0.0, 1.0)
		draw_line(from_p, to_p, Color(col.r, col.g, col.b, beam_alpha * 0.75), 10.0)
		draw_line(from_p, to_p, Color(1, 1, 1, beam_alpha * 0.95), 3.5)

		# Procedural dimensional lightning arcs branching off the beam
		var mid_p := (from_p + to_p) * 0.5
		var norm_dir := (to_p - from_p).normalized().orthogonal()
		var arc_offset := norm_dir * sin(prog * TAU * 3.0 + tp["seed"]) * 35.0
		draw_line(from_p, mid_p + arc_offset, Color(1, 1, 1, beam_alpha * 0.8), 2.0)
		draw_line(mid_p + arc_offset, to_p, Color(col.r, col.g, col.b, beam_alpha * 0.8), 2.0)

		# 2. Departure Implosion Rings (collapsing into zero)
		var dep_r: float = 65.0 * prog
		draw_arc(from_p, dep_r, 0.0, TAU, 24, Color(col.r, col.g, col.b, prog * 0.85), 2.5)
		draw_arc(from_p, dep_r * 0.6, 0.0, TAU, 16, Color(1, 1, 1, prog * 0.9), 2.0)
		for t_i in range(4):
			var t_ang: float = t_i * (TAU / 4.0) + prog * 4.0
			var t_vec := Vector2(cos(t_ang), sin(t_ang)) * dep_r
			draw_line(from_p + t_vec, from_p + t_vec * 1.35, Color.WHITE, 2.0)

		# 3. Arrival Expanding Hex Barrier Pulse
		var arr_r: float = 20.0 + (1.0 - prog) * 75.0
		var arr_alpha: float = clampf(prog * 1.5, 0.0, 1.0)
		var hex_pts := PackedVector2Array()
		for h_i in range(6):
			var h_ang: float = h_i * (TAU / 6.0) + (1.0 - prog) * 2.0
			hex_pts.append(to_p + Vector2(cos(h_ang), sin(h_ang)) * arr_r)
		hex_pts.append(hex_pts[0])
		draw_polyline(hex_pts, Color(col.r, col.g, col.b, arr_alpha * 0.85), 3.0)

		# 4. Rotating Holographic Target Lock Reticle at arrival: [ + ]
		var ret_r := 38.0
		var ret_rot: float = (1.0 - prog) * PI
		for b_i in range(4):
			var b_ang: float = b_i * (TAU / 4.0) + ret_rot
			var b_dir := Vector2(cos(b_ang), sin(b_ang))
			var corner := to_p + b_dir * ret_r
			var arm1 := corner - b_dir.orthogonal() * 12.0
			var arm2 := corner - b_dir * 12.0
			draw_line(arm1, corner, Color.WHITE, 2.5)
			draw_line(arm2, corner, Color.WHITE, 2.5)
		draw_line(to_p - Vector2(10, 0), to_p + Vector2(10, 0), Color.WHITE, 2.0)
		draw_line(to_p - Vector2(0, 10), to_p + Vector2(0, 10), Color.WHITE, 2.0)

		# 5. 8-way Holographic Laser Cross Spikes
		for k in range(8):
			var sp_ang: float = k * (TAU / 8.0)
			var sp_dir := Vector2(cos(sp_ang), sin(sp_ang))
			var sp_len: float = (1.0 - prog) * 60.0 + 15.0
			draw_line(to_p + sp_dir * 15.0, to_p + sp_dir * sp_len, Color(col.r, col.g, col.b, arr_alpha * 0.7), 2.0)

		# Sci-Fi Tactical Lock HUD Text
		var lock_txt: String = ">> [VOID WARP LOCKED] <<" if is_b else ">> [QUANTUM PHASE SHIFT] <<"
		draw_string(font, to_p + Vector2(-90, 52), lock_txt, HORIZONTAL_ALIGNMENT_CENTER, 180, 11, Color(col.r, col.g, col.b, arr_alpha))

# --- CINEMATIC BLACK LETTERBOX BARS ---
func _draw_cinematic_bars() -> void:
	var font := ThemeDB.fallback_font
	var h: float = cinematic_bars_height
	var bar_col := Color("ff0055" if reached_wave10_phase2 else "ffd700")

	draw_rect(Rect2(0, 0, VIEW_W, h), Color("06060c"))
	draw_line(Vector2(0, h), Vector2(VIEW_W, h), bar_col, 2.5)

	draw_rect(Rect2(0, VIEW_H - h, VIEW_W, h), Color("06060c"))
	draw_line(Vector2(0, VIEW_H - h), Vector2(VIEW_W, VIEW_H - h), bar_col, 2.5)

	if h > 35.0:
		var bar_txt := "// TITAN METAMORPHOSIS: REALLOCATING QUANTUM REALITY //"
		draw_string(font, Vector2(0, h - 14), bar_txt, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 13, Color("ffe550" if not reached_wave10_phase2 else "ff0055"))
		var b_sub := "// SYSTEM OVERRIDE: APEX ECLIPSE PROTOCOL ACTIVE //"
		draw_string(font, Vector2(0, VIEW_H - 14), b_sub, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 13, Color("00f5ff"))

func _draw_player() -> void:
	var p: Vector2 = player["pos"]
	var facing: int = player["facing"]
	var flash: bool = (player["invuln_timer"] > 0.0 and int(player["invuln_timer"] * 22.0) % 2 == 0)

	for wp in wind_particles:
		var wa: float = wp["life"] / wp["max_life"]
		draw_rect(Rect2(wp["pos"].x, wp["pos"].y, wp["size"], wp["size"] * 0.6), Color(0.85, 0.98, 1.0, wa * 0.75))

	var p_center: Vector2 = p - Vector2(0, player["h"] * 0.5)
	if player["parry_active_timer"] > 0.0 or player["parry_flash"] > 0.0:
		var a: float = clampf(player["parry_flash"] * 5.0, 0.15, 0.9)
		draw_arc(p_center, PARRY_RADIUS * 0.75, 0.0, TAU, 36, Color(0.25, 0.95, 1.0, a), 4.0)
		draw_circle(p_center, PARRY_RADIUS * 0.65, Color(0.25, 0.95, 1.0, a * 0.25))
	elif player["parry_fail_flash"] > 0.0:
		draw_arc(p_center, 26.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.3, 0.8), 2.5)

	if time_freeze_timer > 0.0:
		draw_circle(p_center, 90.0 * (1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.1), Color(0.25, 0.85, 1.0, 0.14))
		draw_arc(p_center, 78.0, 0.0, TAU, 32, Color(0.4, 0.95, 1.0, 0.6), 2.5)

	if flash:
		return

	var leg_swing: float = sin(player["walk_anim"]) * 5.0 if player["on_ground"] else 4.0

	match selected_character:
		Character.BANDIT:
			_draw_bandit_sprite(p, facing, leg_swing)
		Character.SCIENTIST:
			_draw_scientist_sprite(p, facing, leg_swing)
		Character.NURSE:
			_draw_nurse_sprite(p, facing, leg_swing)

func _draw_bandit_sprite(p: Vector2, facing: int, leg_swing: float) -> void:
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("1a1a24"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("12121c"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("2c2c3e"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("2c2c3e"))

	draw_rect(Rect2(p.x - 9, p.y - 26, 18, 15), Color("232332"))
	draw_line(Vector2(p.x - 8, p.y - 25), Vector2(p.x + 8, p.y - 15), Color("5c3822"), 2.2)
	draw_circle(Vector2(p.x - 2, p.y - 20), 1.4, Color("e2b544"))
	draw_circle(Vector2(p.x + 3, p.y - 17), 1.4, Color("e2b544"))

	draw_rect(Rect2(p.x - 9, p.y - 15, 18, 3), Color("4a2d1e"))
	draw_rect(Rect2(p.x - 2, p.y - 15, 4, 3), Color("c8a855"))
	draw_rect(Rect2(p.x - (8 if facing > 0 else -4), p.y - 14, 4, 5), Color("7b4f2c"))
	draw_circle(Vector2(p.x - (6 if facing > 0 else -6), p.y - 12), 1.0, Color("ffe762"))

	draw_rect(Rect2(p.x - (11 if facing > 0 else -7), p.y - 24, 4, 16), Color("161622"))

	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	draw_rect(Rect2(p.x - 7, p.y - 32, 14, 7), Color("b1203d"))
	var eye_x: float = p.x + (3.0 if facing > 0 else -5.0)
	draw_rect(Rect2(eye_x, p.y - 35, 3.0, 2.5), Color("ffffff"))

	draw_rect(Rect2(p.x - 8, p.y - 41, 16, 6), Color("1a1a26"))
	draw_rect(Rect2(p.x - (9 if facing > 0 else 5), p.y - 38, 5, 8), Color("1a1a26"))
	draw_rect(Rect2(p.x - 10, p.y - 39, 20, 2), Color("12121c"))

	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("232332"))
	var blade_col: Color = Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("5b6270")
	draw_rect(Rect2(p.x + facing * 11.0 - 2.0, p.y - 28, 4, 16), blade_col)
	draw_rect(Rect2(p.x + facing * 11.0 - 4.0, p.y - 20, 8, 3), Color("c8a855"))

func _draw_scientist_sprite(p: Vector2, facing: int, leg_swing: float) -> void:
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("28323e"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("1c242e"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("11161d"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("11161d"))

	draw_rect(Rect2(p.x - 9, p.y - 26, 18, 16), Color("e4e8ec"))
	draw_rect(Rect2(p.x - 2, p.y - 26, 4, 16), Color("4171a6"))
	draw_rect(Rect2(p.x + (2 if facing > 0 else -6), p.y - 24, 4, 5), Color("cbd5e0"))
	draw_rect(Rect2(p.x + (3 if facing > 0 else -5), p.y - 26, 1, 3), Color("e63946"))
	draw_rect(Rect2(p.x + (4 if facing > 0 else -4), p.y - 26, 1, 3), Color("2b6cb0"))

	draw_rect(Rect2(p.x - 9, p.y - 14, 18, 3), Color("2d3748"))
	draw_rect(Rect2(p.x - 7, p.y - 13, 3, 5), Color("38ffff"))
	draw_rect(Rect2(p.x + 4, p.y - 13, 3, 5), Color("48bb78"))

	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	draw_rect(Rect2(p.x - 8, p.y - 34, 16, 4), Color("1a202c"))
	var goggle_x: float = p.x + (2.0 if facing > 0 else -6.0)
	draw_rect(Rect2(goggle_x, p.y - 35, 5.0, 5.0), Color("38ffff"))
	draw_rect(Rect2(goggle_x + 1, p.y - 34, 2.0, 2.0), Color("ffffff"))

	draw_rect(Rect2(p.x - 8, p.y - 42, 16, 6), Color("a0aec0"))
	draw_rect(Rect2(p.x - 9, p.y - 40, 4, 6), Color("a0aec0"))
	draw_rect(Rect2(p.x + 5, p.y - 40, 4, 6), Color("a0aec0"))

	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("e4e8ec"))
	var emitter_col: Color = Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("5b6270")
	draw_circle(Vector2(p.x + facing * 10.0, p.y - 19), 6.5, emitter_col)
	draw_circle(Vector2(p.x + facing * 10.0, p.y - 19), 3.0, Color.WHITE)

func _draw_nurse_sprite(p: Vector2, facing: int, leg_swing: float) -> void:
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("d8e2dc"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("c2cec7"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("ffffff"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("ffffff"))

	draw_rect(Rect2(p.x - 8, p.y - 26, 16, 15), Color("ffffff"))
	draw_rect(Rect2(p.x - 8, p.y - 15, 16, 3), Color("ff4d6d"))
	draw_rect(Rect2(p.x - 1.5, p.y - 23, 3, 7), Color("e63946"))
	draw_rect(Rect2(p.x - 3.5, p.y - 21, 7, 3), Color("e63946"))

	draw_arc(Vector2(p.x, p.y - 26), 4.5, 0.0, PI, 12, Color("4a5568"), 1.8)
	draw_circle(Vector2(p.x + (1 if facing > 0 else -1), p.y - 21), 1.5, Color("cbd5e0"))

	draw_rect(Rect2(p.x - (9 if facing > 0 else -5), p.y - 16, 5, 6), Color("ffffff"))
	draw_line(Vector2(p.x - (7 if facing > 0 else -7), p.y - 15), Vector2(p.x - (7 if facing > 0 else -7), p.y - 11), Color("e63946"), 1.2)
	draw_line(Vector2(p.x - (9 if facing > 0 else -5), p.y - 13), Vector2(p.x - (5 if facing > 0 else -9), p.y - 13), Color("e63946"), 1.2)

	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	var eye_x: float = p.x + (3.0 if facing > 0 else -5.0)
	draw_rect(Rect2(eye_x, p.y - 33, 2.5, 3.5), Color("1a1c2c"))

	draw_rect(Rect2(p.x - 8, p.y - 40, 16, 5), Color("7a432e"))
	draw_rect(Rect2(p.x - 6, p.y - 44, 12, 5), Color("ffffff"))
	draw_rect(Rect2(p.x - 1, p.y - 43, 2, 4), Color("e63946"))
	draw_rect(Rect2(p.x - 2, p.y - 42, 4, 2), Color("e63946"))

	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("ffffff"))
	var defl_col: Color = Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("5b6270")
	draw_rect(Rect2(p.x + facing * 10.0 - 2.0, p.y - 26, 4, 14), defl_col)

# --- Mobs & Bosses Drawing (With Crazy Charging Jitter & Electrical Arcs) ---
func _draw_mobs() -> void:
	for m in mobs:
		var pos: Vector2 = m["pos"]

		# Crazy Bot Shake Effect when charging up!
		if m["charge_glow"] > 0.0:
			var shake_amp: float = (8.0 if not m.get("is_boss", false) else 15.0) * m["charge_glow"]
			var jitter := Vector2(randf_range(-shake_amp, shake_amp), randf_range(-shake_amp, shake_amp))
			pos += jitter

			# Electrical arcing lightning sparks around charging bot!
			var arc_count: int = 4 if not m.get("is_boss", false) else 8
			for k in range(arc_count):
				var ang1 := randf_range(0, TAU)
				var ang2 := ang1 + randf_range(-0.6, 0.6)
				var r_inner: float = m["radius"] * 0.8
				var r_outer: float = m["radius"] * (1.2 + m["charge_glow"] * 0.6)
				var p1 := pos + Vector2(cos(ang1), sin(ang1)) * r_inner
				var p2 := pos + Vector2(cos(ang2), sin(ang2)) * r_outer
				var mid := (p1 + p2) * 0.5 + Vector2(randf_range(-8, 8), randf_range(-8, 8))
				var arc_col: Color = Color("41f3ff") if not m.get("is_boss", false) else Color(1, 0.4, 0.8)
				draw_line(p1, mid, arc_col, 2.0)
				draw_line(mid, p2, arc_col, 2.0)

		if m.get("is_boss", false):
			var b_type: int = m["type"]
			if b_type == 99:
				_draw_extreme_boss(m, pos)
			elif b_type == 101:
				_draw_purple_square_boss(m, pos)
			elif b_type == 102:
				_draw_golden_boss(m, pos)
			continue

		# Regular Mobs
		var t: int = m["type"]
		var flap: float = sin(m["anim"] * 2.2) * 8.0

		if m["charge_glow"] > 0.0:
			draw_circle(pos, 26.0 + m["charge_glow"] * 8.0, Color(1.0, 0.25, 0.35, m["charge_glow"] * 0.35))

		if t == 0:
			var p_dir: Vector2 = (player["pos"] - pos).normalized()
			for k in range(3):
				var tail_start := pos - p_dir * 14.0 + Vector2(0, (k - 1) * 6.0)
				var tail_end: Vector2 = tail_start - p_dir * 16.0 + Vector2(sin(m["anim"] + k) * 5.0, cos(m["anim"] + k) * 5.0)
				draw_line(tail_start, tail_end, Color("b1203d"), 3.0)
			draw_circle(pos, 18.0, Color("b1203d"))
			draw_circle(pos, 15.5, Color("f4f4f8"))
			draw_circle(pos + p_dir * 5.0, 7.5, Color("d92648"))
			draw_circle(pos + p_dir * 6.5, 3.5, Color("141018"))
		elif t == 1:
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(-6, -6), pos + Vector2(-24, -18 + flap), pos + Vector2(-18, 2)
			]), Color(0.75, 0.95, 1.0, 0.55))
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(6, -6), pos + Vector2(24, -18 + flap), pos + Vector2(18, 2)
			]), Color(0.75, 0.95, 1.0, 0.55))
			draw_circle(pos, 17.0, Color("3b7d3b"))
			draw_circle(pos + Vector2(0, -3), 12.0, Color("66b032"))
			draw_circle(pos + Vector2(-6, 4), 4.0, Color("a6ff2e"))
			draw_circle(pos + Vector2(6, 4), 4.0, Color("a6ff2e"))
		elif t == 2:
			draw_circle(pos + Vector2(-16, flap * 0.7), 10.0, Color(0.95, 0.65, 1.0, 0.45))
			draw_circle(pos + Vector2(16, flap * 0.7), 10.0, Color(0.95, 0.65, 1.0, 0.45))
			draw_circle(pos, 18.0, Color(1.0, 0.45, 0.88, 0.38))
			draw_circle(pos, 12.0, Color("ff9be8"))
			draw_circle(pos, 6.5, Color("ffffff"))
		else:
			draw_colored_polygon(PackedVector2Array([
				pos, pos + Vector2(-28, -14 + flap), pos + Vector2(-20, 10 + flap * 0.4)
			]), Color("591f36"))
			draw_colored_polygon(PackedVector2Array([
				pos, pos + Vector2(28, -14 + flap), pos + Vector2(20, 10 + flap * 0.4)
			]), Color("591f36"))
			draw_circle(pos, 15.0, Color("381426"))
			draw_circle(pos + Vector2(-5, -2), 3.5, Color("ff9e2c"))
			draw_circle(pos + Vector2(5, -2), 3.5, Color("ff9e2c"))

# --- WAVE 5 BOSS: APEX ANOMALY (EYEBALL) ---
func _draw_extreme_boss(boss: Dictionary, pos: Vector2) -> void:
	var r: float = boss["radius"]
	var p_dir: Vector2 = (player["pos"] - pos).normalized()
	var flash: bool = (boss["hit_flash"] > 0.0)

	for k in range(5):
		var ang: float = PI + (k - 2) * 0.38 + sin(boss["anim"] * 2.0 + k) * 0.15
		var t_dir := Vector2(cos(ang), sin(ang))
		var t_start := pos + t_dir * (r * 0.85)
		var t_end := t_start + t_dir * (r * 0.75)
		draw_line(t_start, t_end, Color("8b1429"), 6.0)
		draw_line(t_start + t_dir * 4.0, t_end, Color("ff2a4b"), 3.0)

	if boss["charge_glow"] > 0.0:
		draw_circle(pos, r + 18.0 * boss["charge_glow"], Color(1.0, 0.1, 0.2, boss["charge_glow"] * 0.45))

	for k in range(4):
		var orb_ang: float = boss["anim"] * 1.8 + k * (TAU / 4.0)
		var orb_pos := pos + Vector2(cos(orb_ang), sin(orb_ang)) * (r + 18.0)
		draw_circle(orb_pos, 7.5, Color("ff2a55"))
		draw_circle(orb_pos, 4.0, Color.WHITE)
		draw_line(pos, orb_pos, Color("ff2a55", 0.45), 2.0)

	var body_col := Color.WHITE if flash else Color("801124")
	draw_circle(pos, r, body_col)
	draw_circle(pos, r * 0.88, Color("f4f4f8") if not flash else Color("ffd5dd"))

	for i in range(8):
		var v_ang: float = i * (TAU / 8.0) + boss["anim"] * 0.2
		var v_vec := Vector2(cos(v_ang), sin(v_ang))
		draw_line(pos + v_vec * (r * 0.4), pos + v_vec * (r * 0.82), Color("b1203d", 0.65), 2.0)

	var iris_pos := pos + p_dir * (r * 0.28)
	draw_circle(iris_pos, r * 0.48, Color("b81432"))
	draw_circle(iris_pos, r * 0.38, Color("ff2a55") if not boss["enraged"] else Color("ff7e2a"))
	draw_circle(iris_pos + p_dir * (r * 0.06), r * 0.22, Color("140910"))
	draw_circle(iris_pos + p_dir * (r * 0.06), r * 0.10, Color.WHITE)

# --- WAVE 7 BOSS: NEO-TESSERACT (PURPLE SQUARE BOSS) ---
# A truly unique, rotating geometric purple hypercube with:
# - Concentric rotating squares at differing angular speeds
# - 4 Corner floating orbital satellite prism cubes
# - Central void matrix eye
# - Ground slam targeting laser line connecting boss to floor
func _draw_purple_square_boss(boss: Dictionary, pos: Vector2) -> void:
	var sz: float = boss.get("size", 94.0)
	var rot: float = boss.get("rotation_angle", 0.0)
	var flash: bool = (boss["hit_flash"] > 0.0)
	var p_col: Color = Color("9b5de5") if not boss["enraged"] else Color("f72585")

	# Telegraph laser beam to ground during quantum slam!
	if boss["slam_state"] in [1, 2]:
		var target_x: float = boss["slam_target_x"] if boss["slam_state"] == 1 else pos.x
		# Warning vertical laser beam
		draw_line(Vector2(pos.x, pos.y), Vector2(target_x, GROUND_Y), Color(0.9, 0.2, 1.0, 0.75), 8.0)
		draw_line(Vector2(pos.x, pos.y), Vector2(target_x, GROUND_Y), Color.WHITE, 3.0)
		# Reticle on the ground
		draw_arc(Vector2(target_x, GROUND_Y), 45.0, 0.0, TAU, 28, Color("f72585"), 3.5)
		draw_line(Vector2(target_x - 55, GROUND_Y), Vector2(target_x + 55, GROUND_Y), Color("f72585"), 3.0)

	# 1. 4 Corner Orbital Satellite Prism Cubes
	for i in range(4):
		var orb_ang: float = rot * 1.5 + i * (PI * 0.5)
		var sat_pos := pos + Vector2(cos(orb_ang), sin(orb_ang)) * (sz * 0.78)
		# Draw connecting holographic line
		draw_line(pos, sat_pos, Color(p_col.r, p_col.g, p_col.b, 0.4), 2.0)
		# Draw small rotating satellite cube
		_draw_rotated_rect(sat_pos, Vector2(18, 18), -rot * 2.0, Color("1f0633"), p_col, 2.0)
		draw_circle(sat_pos, 3.5, Color.WHITE)

	# 2. Outer Rotating Geometric Energy Shield
	_draw_rotated_rect(pos, Vector2(sz * 1.25, sz * 1.25), rot * 0.5, Color.TRANSPARENT, Color(p_col.r, p_col.g, p_col.b, 0.45), 2.5)

	# 3. Main Outer Purple Square Body
	var body_fill := Color.WHITE if flash else Color("1a042e")
	var body_border := Color.WHITE if flash else p_col
	_draw_rotated_rect(pos, Vector2(sz, sz), rot, body_fill, body_border, 4.5)

	# 4. Concentric Inner Spinning Diamond (Rotated 45 degrees offset)
	var mid_sz: float = sz * 0.65
	var diamond_col := Color("c77dff") if not flash else Color.WHITE
	_draw_rotated_rect(pos, Vector2(mid_sz, mid_sz), rot + PI * 0.25, Color("2d0a4e", 0.85), diamond_col, 3.0)

	# 5. Central Pulsating Violet Void Core
	var core_sz: float = (sz * 0.32) * (1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.12)
	_draw_rotated_rect(pos, Vector2(core_sz, core_sz), -rot * 1.8, Color("f72585"), Color.WHITE, 2.0)
	draw_circle(pos, 5.0, Color.WHITE)

	# Horizontal holographic scanlines
	for s_idx in range(-2, 3):
		var y_off: float = s_idx * 16.0
		var line_start := pos + Vector2(-sz * 0.35, y_off).rotated(rot)
		var line_end := pos + Vector2(sz * 0.35, y_off).rotated(rot)
		draw_line(line_start, line_end, Color(1, 1, 1, 0.3), 1.5)

# --- WAVE 10 BOSS DRAWING: PHASE 1 GOLDEN SOVEREIGN & PHASE 2 ECLIPSE BEAST ---
func _draw_golden_boss(boss: Dictionary, pos: Vector2) -> void:
	var r: float = boss["radius"]
	var flash: bool = (boss["hit_flash"] > 0.0)
	var wing_t: float = boss.get("wing_anim", 0.0)
	var halo_a: float = boss.get("halo_angle", 0.0)
	var is_p2: bool = (boss.get("phase", 1) == 2)

	if not is_p2:
		# =========================================================================
		# PHASE 1: SOLARIS (LE COLOSSE DORÉ) - PURE DIVINE GOLD
		# =========================================================================
		# 1. 6 Flapping Golden Sun Wings
		for side in [-1.0, 1.0]:
			for w in range(3):
				var wing_phase: float = wing_t + w * 0.6
				var flap: float = sin(wing_phase) * 18.0
				var len_scale: float = 1.0 - w * 0.18
				var w_tip := pos + Vector2(side * (r * 1.4 + 40.0 * len_scale), -15.0 + w * 22.0 + flap)
				var w_top := pos + Vector2(side * (r * 0.6), -25.0 + w * 14.0)
				var w_bot := pos + Vector2(side * (r * 0.6), 10.0 + w * 18.0)

				var wing_pts := PackedVector2Array([w_top, w_tip, w_bot])
				var wing_col := Color("ffe550", 0.55) if not flash else Color(1, 1, 1, 0.8)
				draw_colored_polygon(wing_pts, wing_col)
				draw_polyline(wing_pts, Color("ffd700"), 2.5)

		# 2. Dual Spinning Golden Halo Rings (3D Perspective)
		for h_idx in range(2):
			var sign_h: float = 1.0 if h_idx == 0 else -1.0
			var ring_r: float = r * 1.35 + h_idx * 14.0
			var ang_off: float = halo_a * sign_h
			var ring_pts := PackedVector2Array()
			for step in range(32):
				var a: float = step * (TAU / 32.0)
				var rx: float = cos(a + ang_off) * ring_r
				var ry: float = sin(a + ang_off) * (ring_r * 0.35)
				ring_pts.append(pos + Vector2(rx, ry))
			ring_pts.append(ring_pts[0])
			draw_polyline(ring_pts, Color("ffd700", 0.75), 2.5)

		# 3. Outer Radiating Sunburst Corona
		for k in range(12):
			var ray_ang: float = k * (TAU / 12.0) + Time.get_ticks_msec() * 0.0015
			var ray_dir := Vector2(cos(ray_ang), sin(ray_ang))
			var r1 := pos + ray_dir * (r * 0.95)
			var r2 := pos + ray_dir * (r * 1.35)
			draw_line(r1, r2, Color("ffe066", 0.6), 3.0)

		# 4. Main Golden Sovereign Body
		var body_col := Color.WHITE if flash else Color("d4af37")
		draw_circle(pos, r, body_col)
		draw_circle(pos, r * 0.88, Color("ffd700") if not flash else Color.WHITE)
		draw_circle(pos, r * 0.68, Color("ffe550") if not flash else Color("fffbe6"))

		# 5. Inner Divine White-Gold Star Core
		var core_pts := PackedVector2Array()
		var star_points := 8
		for sp in range(star_points * 2):
			var st_ang: float = sp * (PI / float(star_points)) + Time.get_ticks_msec() * 0.002
			var rad: float = (r * 0.45) if (sp % 2 == 0) else (r * 0.20)
			core_pts.append(pos + Vector2(cos(st_ang), sin(st_ang)) * rad)
		draw_colored_polygon(core_pts, Color.WHITE)

	else:
		# =========================================================================
		# PHASE 2: ECLIPSE BEAST (VOID SOLARIS) - BEAST MODE (OBSIDIAN & CRIMSON)
		# =========================================================================
		# 1. 6 Demonic Shadow / Dragon Wings with Razor Crimson Claws
		for side in [-1.0, 1.0]:
			for w in range(3):
				var wing_phase: float = wing_t + w * 0.7
				var flap: float = sin(wing_phase) * 26.0
				var len_scale: float = 1.25 - w * 0.22
				var w_tip := pos + Vector2(side * (r * 1.7 + 55.0 * len_scale), -22.0 + w * 26.0 + flap)
				var w_elbow := pos + Vector2(side * (r * 1.2 + 20.0 * len_scale), -40.0 + w * 22.0 + flap * 0.6)
				var w_top := pos + Vector2(side * (r * 0.5), -28.0 + w * 16.0)
				var w_bot := pos + Vector2(side * (r * 0.5), 14.0 + w * 20.0)

				var wing_poly := PackedVector2Array([w_top, w_elbow, w_tip, w_bot])
				var w_col := Color("0a0a14", 0.90) if not flash else Color(1, 0.2, 0.4, 0.85)
				draw_colored_polygon(wing_poly, w_col)
				draw_polyline(wing_poly, Color("ff0055", 0.85), 3.0)
				# Crimson wing rib bone
				draw_line(w_top, w_tip, Color("ff3377"), 2.0)
				# Razor claw at tip
				draw_circle(w_tip, 4.0, Color("ff0055"))

		# 2. Dual Spiked Void Halos with Orbiting Blade Orbs
		for h_idx in range(2):
			var sign_h: float = 1.0 if h_idx == 0 else -1.0
			var ring_r: float = r * 1.45 + h_idx * 16.0
			var ang_off: float = halo_a * sign_h
			var ring_pts := PackedVector2Array()
			for step in range(32):
				var a: float = step * (TAU / 32.0)
				var rx: float = cos(a + ang_off) * ring_r
				var ry: float = sin(a + ang_off) * (ring_r * 0.38)
				ring_pts.append(pos + Vector2(rx, ry))
			ring_pts.append(ring_pts[0])
			draw_polyline(ring_pts, Color("ff0055", 0.80), 2.5)

			# 4 Orbiting Spiked Void Orbs per ring
			for orb_i in range(4):
				var o_ang: float = ang_off + orb_i * (TAU / 4.0)
				var orb_pos := pos + Vector2(cos(o_ang) * ring_r, sin(o_ang) * (ring_r * 0.38))
				draw_circle(orb_pos, 5.0, Color("ff0055"))
				draw_circle(orb_pos, 2.5, Color.WHITE)

		# 3. Jagged Abyssal Void Corona Spikes
		for k in range(16):
			var ray_ang: float = k * (TAU / 16.0) + Time.get_ticks_msec() * 0.003
			var ray_dir := Vector2(cos(ray_ang), sin(ray_ang))
			var r1 := pos + ray_dir * (r * 0.95)
			var r2 := pos + ray_dir * (r * (1.30 + (0.25 if k % 2 == 0 else 0.08)))
			draw_line(r1, r2, Color("ff0055", 0.75), 3.5)

		# 4. Main Obsidian Beast Body
		var obs_col := Color("05050a") if not flash else Color(1, 0.3, 0.5)
		draw_circle(pos, r * 1.08, Color("ff0055", 0.65))
		draw_circle(pos, r, obs_col)
		draw_circle(pos, r * 0.82, Color("0f0a18"))

		# 5. Glowing Runic Veins across Body
		var runic_pts := PackedVector2Array()
		for rp in range(8):
			var ang: float = rp * (TAU / 8.0) + Time.get_ticks_msec() * 0.001
			runic_pts.append(pos + Vector2(cos(ang) * (r * 0.65), sin(ang) * (r * 0.65)))
		draw_polyline(runic_pts, Color("a800ff", 0.7), 2.0)

		# 6. Menacing 4-Eyed Demonic Beast Visage (Glowing Crimson & White Slits)
		var eye_y := -8.0
		var eyes: Array = [
			Vector2(-18, eye_y - 4),
			Vector2(-7, eye_y + 3),
			Vector2(7, eye_y + 3),
			Vector2(18, eye_y - 4)
		]
		for e_pos in eyes:
			var ep: Vector2 = pos + e_pos
			var eye_pts := PackedVector2Array([
				ep + Vector2(-6, 0),
				ep + Vector2(0, -3),
				ep + Vector2(6, 0),
				ep + Vector2(0, 3)
			])
			draw_colored_polygon(eye_pts, Color("ff0055"))
			draw_circle(ep, 1.8, Color.WHITE)

		# 7. Central Abyssal Singularity Core
		var core_r: float = r * 0.28 + sin(Time.get_ticks_msec() * 0.008) * 4.0
		draw_circle(pos + Vector2(0, 10), core_r, Color.BLACK)
		draw_arc(pos + Vector2(0, 10), core_r, 0.0, TAU, 16, Color("ff0055"), 2.0)

func _draw_rotated_rect(center: Vector2, size: Vector2, angle: float, fill_col: Color, border_col: Color, border_w: float) -> void:
	var half := size * 0.5
	var corners := [
		center + Vector2(-half.x, -half.y).rotated(angle),
		center + Vector2(half.x, -half.y).rotated(angle),
		center + Vector2(half.x, half.y).rotated(angle),
		center + Vector2(-half.x, half.y).rotated(angle)
	]
	var pts := PackedVector2Array(corners)
	if fill_col.a > 0.0:
		draw_colored_polygon(pts, fill_col)
	if border_w > 0.0 and border_col.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, border_col, border_w)

func _draw_lasers() -> void:
	for l in lasers:
		var pos: Vector2 = l["pos"]
		var dir: Vector2 = l["vel"].normalized()
		var col: Color = l["color"]

		for k in range(l["trail"].size()):
			var tp: Vector2 = l["trail"][k]
			var ratio: float = float(k + 1) / float(l["trail"].size() + 1)
			draw_circle(tp, 4.5 * ratio, Color(col.r, col.g, col.b, 0.45 * ratio))

		var tail_pos := pos - dir * 24.0
		draw_line(tail_pos, pos + dir * 6.0, Color(col.r, col.g, col.b, 0.85), 8.0)
		draw_line(tail_pos + dir * 4.0, pos + dir * 6.0, Color.WHITE, 3.5)

func _draw_particles_and_texts() -> void:
	for p in particles:
		var alpha: float = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var c: Color = p["color"]
		c.a = alpha
		var sz: float = p["size"] * alpha
		draw_rect(Rect2(p["pos"].x - sz * 0.5, p["pos"].y - sz * 0.5, sz, sz), c)

	var font := ThemeDB.fallback_font
	for ft in floating_texts:
		var c: Color = ft["color"]
		c.a = clampf(ft["life"] * 1.4, 0.0, 1.0)
		draw_string_outline(font, ft["pos"] - Vector2(140, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 280, 16, 4, Color(0, 0, 0, c.a))
		draw_string(font, ft["pos"] - Vector2(140, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 280, 16, c)

# ==============================================================================
# HUD & DYNAMIC BOSS HEALTH BAR (FOR WAVES 5, 7, 10)
# ==============================================================================
func _draw_hud() -> void:
	for i in range(player["max_hearts"]):
		var hx: float = 38.0 + i * 38.0
		var hy: float = 36.0
		var filled: bool = (i < player["hearts"])
		_draw_heart_icon(Vector2(hx, hy), 14.0, filled)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(VIEW_W - 150, 36), "[F1] CONSOLE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, 3, Color.BLACK)
	draw_string(font, Vector2(VIEW_W - 150, 36), "[F1] CONSOLE", HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, Color("41f3ff"))

	draw_string_outline(font, Vector2(28, 76), "WAVE %d / 10   |   MOBS LEFT: %d" % [current_wave, mobs.size() + mobs_to_spawn], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color.BLACK)
	draw_string(font, Vector2(28, 76), "WAVE %d / 10   |   MOBS LEFT: %d" % [current_wave, mobs.size() + mobs_to_spawn], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe762"))

	var parry_status: String = "PARRY [F]: READY" if player["parry_cooldown_timer"] <= 0.0 else "PARRY [F]: RECHARGING"
	var parry_col: Color = Color("73eff7") if player["parry_cooldown_timer"] <= 0.0 else Color("ff6b6b")

	var ability_status := ""
	var ability_col := Color.WHITE
	match selected_character:
		Character.BANDIT:
			if bandit_dash_cooldown <= 0.0:
				ability_status = "[SHIFT] DASH: READY"
				ability_col = Color("38ffff")
			else:
				ability_status = "[SHIFT] DASH: %.1fs" % bandit_dash_cooldown
				ability_col = Color("ff6b6b")
		Character.SCIENTIST:
			if scientist_freeze_cooldown <= 0.0:
				ability_status = "[SHIFT] TIME FREEZE: READY"
				ability_col = Color("41f3ff")
			else:
				ability_status = "[SHIFT] FREEZE: %.1fs" % scientist_freeze_cooldown
				ability_col = Color("ff6b6b")
		Character.NURSE:
			if player["hearts"] < player["max_hearts"]:
				ability_status = "PASSIVE REGEN: %.1fs" % nurse_regen_timer
				ability_col = Color("55ff99")
			else:
				ability_status = "PASSIVE REGEN: FULL HP"
				ability_col = Color("55ff99")

	draw_string_outline(font, Vector2(28, 102), parry_status + "   |   " + ability_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	draw_string(font, Vector2(28, 102), parry_status + "   |   " + ability_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ability_col)

	# DYNAMIC BOSS HEALTH BAR (APPEARS ON ANY ACTIVE BOSS)
	for m in mobs:
		if m.get("is_boss", false):
			_draw_boss_health_bar(m)
			break

func _draw_boss_health_bar(boss: Dictionary) -> void:
	var bar_w := 560.0
	var bar_h := 22.0
	var bar_x: float = VIEW_W * 0.5 - bar_w * 0.5
	var bar_y := 28.0

	var b_type: int = boss["type"]
	var bar_theme_col := Color("ff2a4b")
	var boss_title: String = "BOSS: " + boss["name"]
	if b_type == 101:
		bar_theme_col = Color("9b5de5")
		boss_title = "LEVEL 7 BOSS: NEO-TESSERACT (THE VOID HYPERCUBE)"
	elif b_type == 102:
		if boss.get("phase", 1) == 2:
			bar_theme_col = Color("ff0055")
			boss_title = "PHASE 2 - BEAST MODE: ECLIPSE BEAST (VOID SOLARIS)"
		else:
			bar_theme_col = Color("ffd700")
			boss_title = "FINAL BOSS: SOLARIS (LE COLOSSE DORÉ)"
		if boss_trans_active:
			boss_title = "CRITICAL METAMORPHOSIS - BEAST AWAKENING..."
			bar_theme_col = Color("ff0055").lerp(Color("ffd700"), clampf(boss_trans_timer / 5.8, 0.0, 1.0))

	_draw_rounded_box(Rect2(bar_x - 14, bar_y - 10, bar_w + 28, bar_h + 38), 12.0, Color("140912", 0.92), bar_theme_col, 3.0)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(bar_x, bar_y + 8), boss_title, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 15, 4, Color.BLACK)
	draw_string(font, Vector2(bar_x, bar_y + 8), boss_title, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 15, Color("ffe762") if b_type != 102 else Color.WHITE)

	draw_rect(Rect2(bar_x, bar_y + 16, bar_w, bar_h), Color("240d16"))
	var fill_ratio: float = clampf(float(boss["hp"]) / float(boss["max_hp"]), 0.0, 1.0)
	var fill_w: float = bar_w * fill_ratio
	var bar_col: Color = bar_theme_col
	if boss["hit_flash"] > 0.0:
		bar_col = Color.WHITE
	draw_rect(Rect2(bar_x, bar_y + 16, fill_w, bar_h), bar_col)
	draw_rect(Rect2(bar_x, bar_y + 16, bar_w, bar_h), bar_theme_col, false, 2.0)

	var hp_text: String = "%d / %d HP" % [boss["hp"], boss["max_hp"]]
	draw_string_outline(font, Vector2(bar_x, bar_y + 32), hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 15, 3, Color.BLACK)
	draw_string(font, Vector2(bar_x, bar_y + 32), hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 15, Color.WHITE)

func _draw_heart_icon(center: Vector2, size: float, filled: bool) -> void:
	var c := Color("ff2a55") if filled else Color(0.2, 0.2, 0.26, 0.75)
	var border := Color("4a0e1c") if filled else Color("12131a")
	draw_circle(center + Vector2(-size * 0.36, -size * 0.22), size * 0.48, border)
	draw_circle(center + Vector2(size * 0.36, -size * 0.22), size * 0.48, border)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.82, -size * 0.05),
		center + Vector2(size * 0.82, -size * 0.05),
		center + Vector2(0, size * 0.88)
	]), border)

	draw_circle(center + Vector2(-size * 0.34, -size * 0.22), size * 0.38, c)
	draw_circle(center + Vector2(size * 0.34, -size * 0.22), size * 0.38, c)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 0.70, -size * 0.05),
		center + Vector2(size * 0.70, -size * 0.05),
		center + Vector2(0, size * 0.74)
	]), c)
	if filled:
		draw_circle(center + Vector2(-size * 0.42, -size * 0.32), size * 0.14, Color(1, 0.8, 0.85, 0.85))

# ==============================================================================
# MAIN MENU (CLEAN MODERN ARCADE BANNER, NOT ROBOTIC)
# ==============================================================================
func _draw_main_menu() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.05, 0.07, 0.13, 0.52))

	var bob: float = sin(Time.get_ticks_msec() * 0.003) * 6.0
	var font := ThemeDB.fallback_font

	# Clean bold title banner (Sleek, modern arcade, zero robot glyph blockiness)
	var title_plate := Rect2(VIEW_W * 0.5 - 340, 105.0 + bob, 680, 80)
	_draw_rounded_box(title_plate, 20.0, Color("101626", 0.90), Color("41f3ff"), 3.5)
	draw_string_outline(font, Vector2(0, 160.0 + bob), "BOUNCE BACK", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 52, 8, Color("0b0e17"))
	draw_string(font, Vector2(0, 160.0 + bob), "BOUNCE BACK", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 52, Color("41f3ff"))

	draw_string_outline(font, Vector2(0, 240), "PERFECT PARRY [F] | SHIFT FOR CHARACTER ABILITIES", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 19, 4, Color.BLACK)
	draw_string(font, Vector2(0, 240), "PERFECT PARRY [F] | SHIFT FOR CHARACTER ABILITIES", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 19, Color("ffe762"))

	# 3 Main Buttons
	_draw_bouncy_button(start_btn_rect, btn_scales["start"], Color("ff5e7e"), Color("ff9e2c"), "START", 30)
	_draw_bouncy_button(characters_btn_rect, btn_scales["characters"], Color("3b6cd9"), Color("41f3ff"), "CHARACTERS", 28)
	_draw_bouncy_button(credits_btn_rect, btn_scales["credits"], Color("38b764"), Color("41f3ff"), "CREDITS", 28)

	if characters_open:
		_draw_characters_modal()
	elif credits_open:
		_draw_credits_modal()

# ==============================================================================
# CHARACTER SELECTION (SIMPLER & LESS ROBOTIC / AI-ISH LOOK)
# ==============================================================================
# Features:
# 1. Sleek top-left Back Button (matches user uploaded icon: green ring + peach left arrow)
# 2. Clean modern title "CHOOSE YOUR FIGHTER"
# 3. 3 Side-by-Side Character Cards (Bandit, Scientist, Nurse) with:
#    - Floating animated character sprite on glowing pedestal
#    - Clean 2-bullet ability explanation (no walls of AI lore)
#    - Clear "SELECT" / "✓ EQUIPPED" button
#    - Click anywhere on card or button to select!
func _draw_characters_modal() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.04, 0.06, 0.12, 0.92))

	var font := ThemeDB.fallback_font

	# 1. Back Button on top-left (Matches uploaded icon style)
	var r: float = CHAR_BACK_RADIUS * btn_scales["char_back"]
	_draw_rounded_box(Rect2(char_back_center - Vector2(r + 4, r + 4), Vector2((r + 4) * 2, (r + 4) * 2)), 14.0, Color("141c2c"), Color.TRANSPARENT, 0.0)
	draw_circle(char_back_center, r, Color("1b2438"))
	draw_arc(char_back_center, r, 0.0, TAU, 32, Color("2dc653"), 3.5)
	# Peach / orange arrow pointing left
	var arrow_col := Color("ff7849")
	draw_line(char_back_center + Vector2(10, 0), char_back_center + Vector2(-8, 0), arrow_col, 4.0)
	draw_line(char_back_center + Vector2(-8, 0), char_back_center + Vector2(0, -8), arrow_col, 4.0)
	draw_line(char_back_center + Vector2(-8, 0), char_back_center + Vector2(0, 8), arrow_col, 4.0)

	# 2. Title & Subtitle
	draw_string_outline(font, Vector2(0, 60), "CHOOSE YOUR FIGHTER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 32, 5, Color.BLACK)
	draw_string(font, Vector2(0, 60), "CHOOSE YOUR FIGHTER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 32, Color("ffe762"))

	draw_string(font, Vector2(0, 86), "Click any character card to equip them for the arena", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color("94a3b8"))

	# 3 Character Card Data (Clean, punchy, human language)
	var cards_data := [
		{
			"name": "BANDIT",
			"tag": "The Shadow Rogue",
			"theme_col": Color("ff9e2c"),
			"border_col": Color("ff5e7e"),
			"ab_name": "SHADOW DASH",
			"ab_badge": "[SHIFT] • 5s COOLDOWN",
			"point1": "• Invulnerable dash that glides through lasers",
			"point2": "• Great for high mobility & aggressive escapes"
		},
		{
			"name": "SCIENTIST",
			"tag": "The Time Physicist",
			"theme_col": Color("38ffff"),
			"border_col": Color("3b6cd9"),
			"ab_name": "TIME FREEZE",
			"ab_badge": "[SHIFT] • 10s COOLDOWN",
			"point1": "• Freezes all enemies & lasers in place for 1.0s",
			"point2": "• Creates safe openings to line up perfect parries"
		},
		{
			"name": "NURSE",
			"tag": "The Field Medic",
			"theme_col": Color("55ff99"),
			"border_col": Color("ff5e7e"),
			"ab_name": "VITAL RECOVERY",
			"ab_badge": "[PASSIVE] • HEALS EVERY 8s",
			"point1": "• Automatically heals 1 heart every 8 seconds",
			"point2": "• Extreme survivability for outlasting boss waves"
		}
	]

	# Render 3 Side-by-Side Cards
	for idx in range(3):
		var cd = cards_data[idx]
		var is_selected: bool = (int(selected_character) == idx)
		var c_rect: Rect2 = char_card_rects[idx]
		var c_scale: float = btn_scales["card_%d" % idx]
		var s_rect := Rect2(c_rect.get_center() - c_rect.size * c_scale * 0.5, c_rect.size * c_scale)

		# Drop shadow
		_draw_rounded_box(Rect2(s_rect.position + Vector2(0, 8), s_rect.size), 18.0, Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0.0)

		# Card body
		var card_fill := Color("0e1626", 0.95) if not is_selected else Color("141e33", 0.98)
		var card_brd: Color = cd["theme_col"] if is_selected else Color("2a3a52")
		var card_brd_w: float = 3.5 if is_selected else 1.8
		_draw_rounded_box(s_rect, 18.0, card_fill, card_brd, card_brd_w)

		# Equipped Banner if active
		if is_selected:
			var act_badge := Rect2(s_rect.position.x + 14, s_rect.position.y + 12, s_rect.size.x - 28, 26)
			_draw_rounded_box(act_badge, 8.0, Color("ffe762", 0.25), Color("ffe762"), 1.5)
			draw_string(font, Vector2(act_badge.position.x, act_badge.position.y + 18), "CURRENTLY EQUIPPED", HORIZONTAL_ALIGNMENT_CENTER, act_badge.size.x, 12, Color("ffe762"))

		# Character Name & Tagline
		var name_y: float = s_rect.position.y + (64 if is_selected else 48)
		draw_string_outline(font, Vector2(s_rect.position.x, name_y), cd["name"], HORIZONTAL_ALIGNMENT_CENTER, s_rect.size.x, 26, 4, Color.BLACK)
		draw_string(font, Vector2(s_rect.position.x, name_y), cd["name"], HORIZONTAL_ALIGNMENT_CENTER, s_rect.size.x, 26, cd["theme_col"])

		draw_string(font, Vector2(s_rect.position.x, name_y + 20), cd["tag"], HORIZONTAL_ALIGNMENT_CENTER, s_rect.size.x, 12, Color("94a3b8"))

		# Circular Avatar Pedestal & Animated Sprite
		var ped_center := Vector2(s_rect.get_center().x, s_rect.position.y + 195.0)
		var bob: float = sin(Time.get_ticks_msec() * 0.003 + idx * 1.5) * 4.0

		draw_circle(ped_center + Vector2(0, 16), 48.0, Color(0, 0, 0, 0.4))
		draw_circle(ped_center + Vector2(0, 12), 44.0, Color(cd["theme_col"].r, cd["theme_col"].g, cd["theme_col"].b, 0.22))
		draw_arc(ped_center + Vector2(0, 12), 44.0, 0.0, TAU, 32, cd["theme_col"], 2.2)

		var sprite_pos := ped_center + Vector2(0, 4 + bob)
		draw_set_transform(sprite_pos, 0.0, Vector2(2.6, 2.6))
		if idx == 0:
			_draw_bandit_sprite(Vector2.ZERO, 1, 0.0)
		elif idx == 1:
			_draw_scientist_sprite(Vector2.ZERO, 1, 0.0)
		else:
			_draw_nurse_sprite(Vector2.ZERO, 1, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Clean Ability Box
		var ab_box := Rect2(s_rect.position.x + 16, s_rect.position.y + 270, s_rect.size.x - 32, 160)
		_draw_rounded_box(ab_box, 12.0, Color("101626"), Color("24334a"), 1.2)

		draw_string(font, Vector2(ab_box.position.x + 12, ab_box.position.y + 24), cd["ab_name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe762"))

		# Ability Badge Pill
		var pill_rect := Rect2(ab_box.end.x - 170, ab_box.position.y + 10, 160, 22)
		_draw_rounded_box(pill_rect, 6.0, Color(cd["theme_col"].r, cd["theme_col"].g, cd["theme_col"].b, 0.2), cd["theme_col"], 1.0)
		draw_string(font, Vector2(pill_rect.position.x, pill_rect.position.y + 15), cd["ab_badge"], HORIZONTAL_ALIGNMENT_CENTER, pill_rect.size.x, 10, Color.WHITE)

		# Clean Bullet Points
		draw_string(font, Vector2(ab_box.position.x + 12, ab_box.position.y + 60), cd["point1"], HORIZONTAL_ALIGNMENT_LEFT, ab_box.size.x - 24, 11, Color("e2e8f0"))
		draw_string(font, Vector2(ab_box.position.x + 12, ab_box.position.y + 105), cd["point2"], HORIZONTAL_ALIGNMENT_LEFT, ab_box.size.x - 24, 11, Color("cbd5e1"))

		# Select / Equipped Button
		var btn_box := Rect2(s_rect.position.x + 18, s_rect.position.y + 448, s_rect.size.x - 36, 44)
		if is_selected:
			_draw_rounded_box(btn_box, 10.0, Color(0.12, 0.45, 0.24, 0.95), Color("ffe762"), 2.0)
			draw_string(font, Vector2(btn_box.position.x, btn_box.position.y + 28), "✓ EQUIPPED", HORIZONTAL_ALIGNMENT_CENTER, btn_box.size.x, 15, Color.WHITE)
		else:
			var btn_hover: bool = btn_hovered["card_%d" % idx]
			var btn_c := Color("223048") if btn_hover else Color("162032")
			var brd_c := Color("41f3ff") if btn_hover else Color("2c3e56")
			_draw_rounded_box(btn_box, 10.0, btn_c, brd_c, 1.5)
			draw_string(font, Vector2(btn_box.position.x, btn_box.position.y + 28), "CHOOSE", HORIZONTAL_ALIGNMENT_CENTER, btn_box.size.x, 15, Color("41f3ff") if btn_hover else Color("cbd5e1"))

func _draw_boss_warning(timer: float) -> void:
	var font := ThemeDB.fallback_font
	var pulse: float = sin((4.0 - timer) * 11.0) * 0.5 + 0.5
	var alpha: float = clampf(timer / 0.5, 0.0, 1.0)

	var tint_col: Color = boss_warning_color
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(tint_col.r, tint_col.g, tint_col.b, (0.16 + pulse * 0.18) * alpha))

	var bar_h: float = 38.0
	draw_rect(Rect2(0, 0, VIEW_W, bar_h), Color(0.10, 0.01, 0.04, 0.92 * alpha))
	draw_rect(Rect2(0, VIEW_H - bar_h, VIEW_W, bar_h), Color(0.10, 0.01, 0.04, 0.92 * alpha))
	draw_line(Vector2(0, bar_h), Vector2(VIEW_W, bar_h), Color(tint_col.r, tint_col.g, tint_col.b, alpha), 2.5)
	draw_line(Vector2(0, VIEW_H - bar_h), Vector2(VIEW_W, VIEW_H - bar_h), Color(tint_col.r, tint_col.g, tint_col.b, alpha), 2.5)

	var ticker_text := "! WARNING // DANGER // MAJOR BOSS DETECTED // ! WARNING // DANGER // MAJOR BOSS DETECTED // !"
	var ticker_x: float = fmod(-Time.get_ticks_msec() * 0.12, 400.0)
	draw_string(font, Vector2(ticker_x, 24), ticker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tint_col.r, tint_col.g, tint_col.b, alpha))
	draw_string(font, Vector2(ticker_x, VIEW_H - 14), ticker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(tint_col.r, tint_col.g, tint_col.b, alpha))

	var banner_w: float = 880.0
	var banner_h: float = 126.0
	var banner_rect := Rect2((VIEW_W - banner_w) * 0.5, 175.0, banner_w, banner_h)

	_draw_rounded_box(Rect2(banner_rect.position + Vector2(0, 8), banner_rect.size), 18.0, Color(0, 0, 0, 0.6 * alpha), Color.TRANSPARENT, 0.0)
	var box_fill := Color(0.14, 0.02, 0.06, 0.94 * alpha)
	var box_brd := Color(tint_col.r, tint_col.g, tint_col.b, alpha)
	_draw_rounded_box(banner_rect, 18.0, box_fill, box_brd, 3.5)

	draw_string_outline(font, Vector2(banner_rect.position.x, banner_rect.position.y + 50), boss_warning_title, HORIZONTAL_ALIGNMENT_CENTER, banner_w, 32, 6, Color.BLACK)
	draw_string(font, Vector2(banner_rect.position.x, banner_rect.position.y + 50), boss_warning_title, HORIZONTAL_ALIGNMENT_CENTER, banner_w, 32, Color(tint_col.r, tint_col.g, tint_col.b, alpha))

	draw_string_outline(font, Vector2(banner_rect.position.x, banner_rect.position.y + 88), boss_warning_sub, HORIZONTAL_ALIGNMENT_CENTER, banner_w, 16, 4, Color.BLACK)
	draw_string(font, Vector2(banner_rect.position.x, banner_rect.position.y + 88), boss_warning_sub, HORIZONTAL_ALIGNMENT_CENTER, banner_w, 16, Color(1.0, 0.88, 0.35, alpha))

func _draw_game_over_overlay() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.06, 0.02, 0.05, 0.74))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, 180), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 64, 8, Color.BLACK)
	draw_string(font, Vector2(0, 180), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 64, Color("ff3b5b"))

	if reached_wave10_phase2 or (current_wave == 10 and wave10_phase == 2):
		draw_string_outline(font, Vector2(0, 245), "[WAVE 10 PHASE 2 CHECKPOINT ACTIVE]", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 26, 5, Color.BLACK)
		draw_string(font, Vector2(0, 245), "[WAVE 10 PHASE 2 CHECKPOINT ACTIVE]", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 26, Color("ff0055"))
		draw_string(font, Vector2(0, 280), "PRESS TO RESPAWN ON WAVE 10 PHASE 2", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color("cbd5e0"))
		_draw_bouncy_button(start_btn_rect, btn_scales["start"], Color("ff0055"), Color("ff77aa"), "RESPAWN WAVE 10", 26)
	else:
		draw_string_outline(font, Vector2(0, 245), "You reached Wave %d" % current_wave, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, 5, Color.BLACK)
		draw_string(font, Vector2(0, 245), "You reached Wave %d" % current_wave, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, Color("ffe762"))
		draw_string(font, Vector2(0, 280), "PRESS TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color("cbd5e0"))
		_draw_bouncy_button(start_btn_rect, btn_scales["start"], Color("ff5e7e"), Color("ff9e2c"), "BOUNCE BACK", 28)

	_draw_bouncy_button(credits_btn_rect, btn_scales["credits"], Color("3b5dc9"), Color("41f3ff"), "MAIN MENU", 28)

# --- VICTORY OVERLAY (CONQUERED ALL 10 WAVES) ---
func _draw_victory_overlay() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.04, 0.06, 0.12, 0.85))
	var font := ThemeDB.fallback_font

	var v_box := Rect2(VIEW_W * 0.5 - 440, 120, 880, 420)
	_draw_rounded_box(Rect2(v_box.position + Vector2(0, 10), v_box.size), 22.0, Color(0, 0, 0, 0.6), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(v_box, 22.0, Color("101626"), Color("ffd700"), 4.0)

	draw_string_outline(font, Vector2(v_box.position.x, v_box.position.y + 70), "VICTORY ACHIEVED!", HORIZONTAL_ALIGNMENT_CENTER, v_box.size.x, 48, 8, Color.BLACK)
	draw_string(font, Vector2(v_box.position.x, v_box.position.y + 70), "VICTORY ACHIEVED!", HORIZONTAL_ALIGNMENT_CENTER, v_box.size.x, 48, Color("ffe550"))

	draw_string_outline(font, Vector2(v_box.position.x, v_box.position.y + 130), "YOU HAVE CONQUERED ALL 10 WAVES!", HORIZONTAL_ALIGNMENT_CENTER, v_box.size.x, 24, 5, Color.BLACK)
	draw_string(font, Vector2(v_box.position.x, v_box.position.y + 130), "YOU HAVE CONQUERED ALL 10 WAVES!", HORIZONTAL_ALIGNMENT_CENTER, v_box.size.x, 24, Color.WHITE)

	draw_string(font, Vector2(v_box.position.x, v_box.position.y + 180), "The Void Hypercube and the Golden Sovereign have fallen.", HORIZONTAL_ALIGNMENT_CENTER, v_box.size.x, 16, Color("cbd5e1"))
	draw_string(font, Vector2(v_box.position.x, v_box.position.y + 215), "You are the undisputed Grand Master of Bounce Back!", HORIZONTAL_ALIGNMENT_CENTER, v_box.size.x, 16, Color("41f3ff"))

	_draw_bouncy_button(victory_restart_rect, btn_scales["vic_restart"], Color("38b764"), Color("ffe550"), "PLAY AGAIN", 24)
	_draw_bouncy_button(victory_menu_rect, btn_scales["vic_menu"], Color("3b6cd9"), Color("41f3ff"), "MAIN MENU", 24)

func _draw_bouncy_button(rect: Rect2, scale_val: float, fill_col: Color, border_col: Color, label: String, font_size: int) -> void:
	var center := rect.get_center()
	var scaled_size := rect.size * scale_val
	var s_rect := Rect2(center - scaled_size * 0.5, scaled_size)

	_draw_rounded_box(Rect2(s_rect.position + Vector2(0, 7), s_rect.size), 20.0, Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(s_rect, 20.0, fill_col, border_col, 4.0)
	var gloss := Rect2(s_rect.position.x + 12, s_rect.position.y + 6, s_rect.size.x - 24, s_rect.size.y * 0.32)
	_draw_rounded_box(gloss, 10.0, Color(1, 1, 1, 0.22), Color.TRANSPARENT, 0.0)

	var font := ThemeDB.fallback_font
	var text_y: float = center.y + font_size * 0.36
	draw_string_outline(font, Vector2(s_rect.position.x, text_y), label, HORIZONTAL_ALIGNMENT_CENTER, s_rect.size.x, font_size, 5, Color("141018"))
	draw_string(font, Vector2(s_rect.position.x, text_y), label, HORIZONTAL_ALIGNMENT_CENTER, s_rect.size.x, font_size, Color.WHITE)

func _draw_credits_modal() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0, 0, 0, 0.65))
	_draw_rounded_box(credits_box_rect, 24.0, Color("1a2238"), Color("41f3ff"), 4.5)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(credits_box_rect.position.x, credits_box_rect.position.y + 68), "CREATORS", HORIZONTAL_ALIGNMENT_CENTER, credits_box_rect.size.x, 34, 5, Color.BLACK)
	draw_string(font, Vector2(credits_box_rect.position.x, credits_box_rect.position.y + 68), "CREATORS", HORIZONTAL_ALIGNMENT_CENTER, credits_box_rect.size.x, 34, Color("ffe762"))

	var creators := [
		"- Mounib Reda",
		"- Chingiz Shikhgayibov",
		"- Nurazkhan Nygmet"
	]
	for i in range(creators.size()):
		var cy: float = credits_box_rect.position.y + 150.0 + i * 62.0
		draw_string_outline(font, Vector2(credits_box_rect.position.x, cy), creators[i], HORIZONTAL_ALIGNMENT_CENTER, credits_box_rect.size.x, 28, 4, Color.BLACK)
		draw_string(font, Vector2(credits_box_rect.position.x, cy), creators[i], HORIZONTAL_ALIGNMENT_CENTER, credits_box_rect.size.x, 28, Color("73eff7"))

	var r: float = CLOSE_BTN_RADIUS * btn_scales["close"]
	draw_circle(close_credits_center + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.45))
	draw_circle(close_credits_center, r, Color("ff2a4b"))
	draw_arc(close_credits_center, r, 0.0, TAU, 28, Color.WHITE, 2.5)
	var x_off: float = r * 0.42
	draw_line(close_credits_center + Vector2(-x_off, -x_off), close_credits_center + Vector2(x_off, x_off), Color.WHITE, 3.0)
	draw_line(close_credits_center + Vector2(x_off, -x_off), close_credits_center + Vector2(-x_off, x_off), Color.WHITE, 3.0)

func _draw_wave_transition_overlay() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0, 0, 0, clampf(transition_alpha, 0.0, 1.0)))
	if transition_alpha > 0.35:
		var text_a: float = clampf((transition_alpha - 0.35) / 0.65, 0.0, 1.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, VIEW_H * 0.5 + 14), transition_text, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 54, Color(1, 1, 1, text_a))

func _draw_rounded_box(rect: Rect2, radius: float, fill_col: Color, border_col: Color, border_width: float) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r)
	]
	var angles := [PI, 1.5 * PI, 0.0, 0.5 * PI]
	for c_idx in range(4):
		var center: Vector2 = corners[c_idx]
		var start_a: float = angles[c_idx]
		for step in range(9):
			var a: float = start_a + (float(step) / 8.0) * (PI * 0.5)
			pts.append(center + Vector2(cos(a), sin(a)) * r)
	if fill_col.a > 0.0:
		draw_colored_polygon(pts, fill_col)
	if border_width > 0.0 and border_col.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, border_col, border_width)

# ==============================================================================
# F1 DEVELOPER CONSOLE RENDERING
# ==============================================================================
func _draw_console() -> void:
	var font := ThemeDB.fallback_font
	var box_w := 780.0
	var box_h := 105.0
	var box_x := (VIEW_W - box_w) * 0.5
	var box_y := 16.0
	var box_rect := Rect2(box_x, box_y, box_w, box_h)

	# Semi-transparent backdrop to obscure game behind console
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.02, 0.04, 0.08, 0.55))

	# Drop shadow and background panel
	_draw_rounded_box(Rect2(box_rect.position + Vector2(0, 6), box_rect.size), 14.0, Color(0, 0, 0, 0.55), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(box_rect, 14.0, Color("0b1320", 0.96), Color("41f3ff"), 2.5)

	# Top Title bar
	draw_string(font, Vector2(box_x + 18, box_y + 22), "> DEV CONSOLE  [F1 or ESC to close]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("41f3ff"))

	# Input Field box
	var inp_box := Rect2(box_x + 16, box_y + 32, box_w - 32, 38)
	_draw_rounded_box(inp_box, 8.0, Color("070c14"), Color("24364f"), 1.2)

	# Text prefix + user input + blinking cursor
	var prefix := "WARP TO WAVE > "
	draw_string(font, Vector2(inp_box.position.x + 12, inp_box.position.y + 25), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ffe762"))

	var pref_size: Vector2 = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	var text_x: float = inp_box.position.x + 12 + pref_size.x
	draw_string(font, Vector2(text_x, inp_box.position.y + 25), console_input, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Blinking cursor
	var cur_w: Vector2 = font.get_string_size(console_input, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if int(Time.get_ticks_msec() * 0.003) % 2 == 0:
		draw_line(Vector2(text_x + cur_w.x + 2, inp_box.position.y + 10), Vector2(text_x + cur_w.x + 2, inp_box.position.y + 28), Color("41f3ff"), 2.0)

	# Bottom Help / Status text
	var is_err: bool = console_msg.begins_with("Invalid")
	var msg_col: Color = Color("ff5e7e") if is_err else (Color("ffe762") if console_msg.begins_with("WARP") else Color("94a3b8"))
	draw_string(font, Vector2(box_x + 18, box_y + 92), console_msg, HORIZONTAL_ALIGNMENT_LEFT, box_w - 36, 12, msg_col)

