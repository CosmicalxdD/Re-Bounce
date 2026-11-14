extends Node2D

# ==============================================================================
# BOUNCE BACK - Complete Godot 4 Game Script
# Creators: Mounib Reda, Chingiz Shikhgayibov, Nurazkhan Nygmet
# ==============================================================================

enum State { MENU, TRANSITION, PLAYING, GAME_OVER }
var state: State = State.MENU

const VIEW_W := 1280.0
const VIEW_H := 720.0
const GROUND_Y := 630.0

# --- Wave & Transition State ---
var current_wave: int = 1
var transition_alpha: float = 0.0
var transition_phase: int = 0 # 0: delay before fade, 1: fade to black, 2: hold "wave X..", 3: fade in
var transition_timer: float = 0.0
var transition_text: String = "wave 1.."
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
	"parry_active_timer": 0.0,   # Tight parry window (~0.13s)
	"parry_cooldown_timer": 0.0, # Penalty if pressed too early (~0.42s)
	"invuln_timer": 0.0,
	"parry_flash": 0.0,
	"parry_fail_flash": 0.0
}

const GRAVITY := 1350.0
const MOVE_SPEED := 330.0
const JUMP_FORCE := -610.0
const PARRY_WINDOW := 0.135     # Tight, rewarding perfect-parry tolerance!
const PARRY_COOLDOWN := 0.44    # Pressing F too early locks you out so the laser hits you
const PARRY_RADIUS := 68.0      # Deflection reach around player center

# --- Map Platforms (One-way jump-through from underneath, leave only via sides like Brawlhalla) ---
var platforms: Array[Rect2] = [
	Rect2(170, 495, 250, 18),
	Rect2(860, 495, 250, 18),
	Rect2(470, 385, 340, 18),
	Rect2(210, 270, 210, 18),
	Rect2(860, 270, 210, 18)
]

var trees: Array = []
var clouds: Array = []
var grass_tufts: Array = []
var fireflies: Array = []

# --- Entities ---
var mobs: Array = []
var lasers: Array = []
var particles: Array = []
var floating_texts: Array = []
var screen_shake: float = 0.0

var mobs_to_spawn: int = 0
var spawn_timer: float = 0.0

# --- Menu & UI ---
var credits_open: bool = false
var start_btn_rect := Rect2(490, 330, 300, 74)
var credits_btn_rect := Rect2(490, 435, 300, 74)
var credits_box_rect := Rect2(350, 180, 580, 370)
var close_credits_center := Vector2(895, 215)
const CLOSE_BTN_RADIUS := 20.0

var btn_scales := {"start": 1.0, "credits": 1.0, "close": 1.0}
var btn_vel := {"start": 0.0, "credits": 0.0, "close": 0.0}
var btn_hovered := {"start": false, "credits": false, "close": false}

# --- Procedural Audio (Chill, Nerdy, Stressing & Repetitive Synth + SFX) ---
var music_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var sfx_player: AudioStreamPlayer
var sfx_playback: AudioStreamGeneratorPlayback
var music_phase: float = 0.0
var bass_phase: float = 0.0
var arp_time: float = 0.0
var arp_step: int = 0
var sfx_queue: Array = []

# Nerdy minor-key arpeggio frequencies (C minor / Phrygian tension loop)
const ARP_NOTES := [
	261.63, 311.13, 392.00, 523.25, 392.00, 311.13, 466.16, 392.00,
	277.18, 349.23, 415.30, 554.37, 415.30, 349.23, 523.25, 415.30
]
const BASS_NOTES := [130.81, 130.81, 155.56, 130.81, 138.59, 138.59, 123.47, 146.83]

func _ready() -> void:
	randomize()
	_generate_forest_scenery()
	_setup_audio()

func _generate_forest_scenery() -> void:
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
	for i in range(28):
		fireflies.append({
			"pos": Vector2(randf_range(40, VIEW_W - 40), randf_range(120, GROUND_Y - 20)),
			"phase": randf_range(0, TAU),
			"speed": randf_range(18.0, 40.0)
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

func _fill_audio_buffers() -> void:
	var mix_rate := 22050.0
	if music_playback:
		var frames := music_playback.get_frames_available()
		# Speed up the nerdy arpeggio slightly on higher waves for extra tension
		var step_dur := 0.115 if state != State.PLAYING else maxf(0.075, 0.115 - current_wave * 0.003)
		for i in range(frames):
			arp_time += 1.0 / mix_rate
			if arp_time >= step_dur:
				arp_time -= step_dur
				arp_step = (arp_step + 1) % ARP_NOTES.size()
			var freq: float = ARP_NOTES[arp_step]
			var bass_freq: float = BASS_NOTES[(arp_step / 2) % BASS_NOTES.size()]
			var env: float = maxf(0.0, 1.0 - (arp_time / step_dur) * 0.75)

			music_phase = fmod(music_phase + freq / mix_rate, 1.0)
			bass_phase = fmod(bass_phase + bass_freq / mix_rate, 1.0)

			# Pulse wave + triangle bass for retro nerdy chiptune vibe
			var lead: float = (1.0 if music_phase < 0.25 else -1.0) * 0.16 * env
			var bass: float = (absf(bass_phase * 4.0 - 2.0) - 1.0) * 0.18
			var tick: float = (randf() * 2.0 - 1.0) * 0.04 if (arp_step % 2 == 0 and arp_time < 0.012) else 0.0
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
				elif s["type"] == 1: # Noise + tone (Hit / Explosion)
					sample += ((randf() * 2.0 - 1.0) * 0.5 + sin(s["phase"] * TAU) * 0.5) * 0.38 * env
			sample = clampf(sample, -0.95, 0.95)
			sfx_playback.push_frame(Vector2(sample, sample))

# ==============================================================================
# INPUT & MENU LOGIC
# ==============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mpos: Vector2 = get_global_mouse_position()
		if state == State.MENU:
			if credits_open:
				if mpos.distance_to(close_credits_center) <= CLOSE_BTN_RADIUS + 6.0:
					credits_open = false
					_play_sfx(520.0, 260.0, 0.1, 0)
			else:
				if start_btn_rect.has_point(mpos):
					_play_sfx(440.0, 880.0, 0.18, 0)
					_begin_game_from_wave_1()
				elif credits_btn_rect.has_point(mpos):
					credits_open = true
					btn_vel["credits"] = 6.5
					_play_sfx(380.0, 620.0, 0.14, 0)
		elif state == State.GAME_OVER:
			if start_btn_rect.has_point(mpos):
				_play_sfx(440.0, 880.0, 0.18, 0)
				_begin_game_from_wave_1()
			elif credits_btn_rect.has_point(mpos):
				state = State.MENU
				credits_open = false
				_play_sfx(520.0, 320.0, 0.14, 0)

	if event is InputEventKey and event.pressed and not event.echo:
		if state == State.PLAYING:
			if event.keycode == KEY_F:
				_attempt_parry()
			elif event.keycode in [KEY_SPACE, KEY_W, KEY_UP]:
				_attempt_jump()

func _begin_game_from_wave_1() -> void:
	current_wave = 1
	player["hearts"] = player["max_hearts"]
	player["pos"] = Vector2(VIEW_W * 0.5, GROUND_Y)
	player["vel"] = Vector2.ZERO
	player["parry_active_timer"] = 0.0
	player["parry_cooldown_timer"] = 0.0
	player["invuln_timer"] = 0.0
	mobs.clear()
	lasers.clear()
	particles.clear()
	floating_texts.clear()
	_start_wave_transition(1, 0.0)

func _start_wave_transition(wave_num: int, initial_pause: float) -> void:
	state = State.TRANSITION
	transition_text = "wave %d.." % wave_num
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
	mobs_to_spawn = 3 + wave_num * 2
	spawn_timer = 0.45

# ==============================================================================
# MAIN LOOP (60 FPS Fluid Physics & Updates)
# ==============================================================================
func _physics_process(delta: float) -> void:
	_fill_audio_buffers()
	_update_scenery(delta)
	_update_menu_buttons(delta)
	screen_shake = maxf(0.0, screen_shake - delta * 28.0)

	match state:
		State.MENU:
			pass
		State.TRANSITION:
			_update_transition(delta)
		State.PLAYING:
			_update_player(delta)
			_update_wave_spawner(delta)
			_update_mobs(delta)
			_update_lasers(delta)
			_update_particles_and_text(delta)
		State.GAME_OVER:
			_update_particles_and_text(delta)

	queue_redraw()

func _update_scenery(delta: float) -> void:
	for c in clouds:
		c["pos"].x += c["speed"] * delta
		if c["pos"].x > VIEW_W + 140.0:
			c["pos"].x = -140.0
	for f in fireflies:
		f["phase"] += delta * 2.5
		f["pos"].x += cos(f["phase"]) * f["speed"] * delta
		f["pos"].y += sin(f["phase"] * 1.3) * (f["speed"] * 0.6) * delta

func _update_menu_buttons(delta: float) -> void:
	var mpos: Vector2 = get_global_mouse_position()
	var hover_start := (state in [State.MENU, State.GAME_OVER]) and (not credits_open) and start_btn_rect.has_point(mpos)
	var hover_credits := (state in [State.MENU, State.GAME_OVER]) and (not credits_open) and credits_btn_rect.has_point(mpos)
	var hover_close := (state == State.MENU) and credits_open and (mpos.distance_to(close_credits_center) <= CLOSE_BTN_RADIUS + 4.0)

	_apply_spring_button("start", hover_start, delta)
	_apply_spring_button("credits", hover_credits, delta)
	_apply_spring_button("close", hover_close, delta)

func _apply_spring_button(key: String, is_hovered: bool, delta: float) -> void:
	if is_hovered and not btn_hovered[key]:
		btn_vel[key] = 4.2 # Bouncy pop impulse on cursor hover
		_play_sfx(660.0, 780.0, 0.05, 0)
	btn_hovered[key] = is_hovered
	var target: float = 1.10 if is_hovered else 1.0
	var force: float = (target - btn_scales[key]) * 180.0
	btn_vel[key] = (btn_vel[key] + force * delta) * exp(-9.5 * delta)
	btn_scales[key] += btn_vel[key] * delta

func _update_transition(delta: float) -> void:
	_update_particles_and_text(delta)
	if transition_phase == 0:
		# Short pause after eliminating the wave's last mob, player can still move
		_update_player(delta)
		transition_timer -= delta
		if transition_timer <= 0.0:
			transition_phase = 1
	elif transition_phase == 1:
		transition_alpha += delta * 1.45
		if transition_alpha >= 1.0:
			transition_alpha = 1.0
			transition_phase = 2
			transition_timer = 1.25
			_setup_wave_entities(current_wave)
	elif transition_phase == 2:
		transition_timer -= delta
		if transition_timer <= 0.0:
			transition_phase = 3
	elif transition_phase == 3:
		transition_alpha -= delta * 1.65
		if transition_alpha <= 0.0:
			transition_alpha = 0.0
			state = State.PLAYING

# ==============================================================================
# PLAYER MOVEMENT, ONE-WAY PLATFORMS & PERFECT PARRY ('F')
# ==============================================================================
func _attempt_jump() -> void:
	if player["on_ground"]:
		player["vel"].y = JUMP_FORCE
		player["on_ground"] = false
		_play_sfx(260.0, 520.0, 0.11, 0)
		_spawn_burst(player["pos"], Color("a7f070"), 7, 110.0)

func _attempt_parry() -> void:
	# If on cooldown from spamming/early press, ignore
	if player["parry_cooldown_timer"] > 0.0:
		player["parry_fail_flash"] = 0.18
		_play_sfx(150.0, 110.0, 0.08, 0)
		return

	player["parry_active_timer"] = PARRY_WINDOW
	player["parry_cooldown_timer"] = PARRY_COOLDOWN
	player["parry_flash"] = 0.18
	_play_sfx(520.0, 960.0, 0.08, 0)

	# Immediately check if any incoming laser is inside the tight deflection zone
	_check_parry_deflection()

func _check_parry_deflection() -> void:
	if player["parry_active_timer"] <= 0.0:
		return
	var p_center: Vector2 = player["pos"] - Vector2(0, player["h"] * 0.5)
	var deflected_any := false

	for l in lasers:
		if not l["bounced"]:
			var dist: float = l["pos"].distance_to(p_center)
			# Laser must be very close and about to strike the player
			if dist <= PARRY_RADIUS:
				l["bounced"] = true
				deflected_any = true
				# Bounce laser directly back toward the mob that fired it (or nearest living mob)
				var target_mob = l["owner"]
				if target_mob == null or not mobs.has(target_mob):
					target_mob = _get_nearest_mob(l["pos"])
				var aim_dir: Vector2 = -l["vel"].normalized()
				if target_mob != null:
					# Lead the shot slightly toward the mob's current position
					aim_dir = (target_mob["pos"] - l["pos"]).normalized()
				l["vel"] = aim_dir * (l["vel"].length() * 1.48)
				l["color"] = Color("41f3ff")
				# Reset parry cooldown on a successful perfect parry so you can chain parries!
				player["parry_cooldown_timer"] = 0.06
				screen_shake = 6.5
				_play_sfx(680.0, 1480.0, 0.16, 0)
				_spawn_burst(l["pos"], Color("73eff7"), 18, 260.0)
				_add_floating_text("PERFECT PARRY!", p_center + Vector2(0, -34), Color("73eff7"))

func _update_player(delta: float) -> void:
	player["parry_active_timer"] = maxf(0.0, player["parry_active_timer"] - delta)
	player["parry_cooldown_timer"] = maxf(0.0, player["parry_cooldown_timer"] - delta)
	player["invuln_timer"] = maxf(0.0, player["invuln_timer"] - delta)
	player["parry_flash"] = maxf(0.0, player["parry_flash"] - delta)
	player["parry_fail_flash"] = maxf(0.0, player["parry_fail_flash"] - delta)

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
	player["pos"].x = clampf(player["pos"].x, 28.0, VIEW_W - 28.0)

	player["on_ground"] = false

	# One-way floor collisions: jump up through from underneath, walk off the sides to go down!
	if player["vel"].y >= 0.0:
		for plat in platforms:
			var within_x: bool = (player["pos"].x + player["w"] * 0.45 >= plat.position.x) and (player["pos"].x - player["w"] * 0.45 <= plat.position.x + plat.size.x)
			if within_x and prev_y <= plat.position.y + 4.0 and player["pos"].y >= plat.position.y:
				player["pos"].y = plat.position.y
				player["vel"].y = 0.0
				player["on_ground"] = true
				break

	# Main forest ground collision
	if player["pos"].y >= GROUND_Y:
		player["pos"].y = GROUND_Y
		player["vel"].y = 0.0
		player["on_ground"] = true

	# Check active parry frames against incoming lasers
	if player["parry_active_timer"] > 0.0:
		_check_parry_deflection()

# ==============================================================================
# FLYING MOBS, SMART DODGING AI & WAVES
# ==============================================================================
func _update_wave_spawner(delta: float) -> void:
	if mobs_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_mob()
			mobs_to_spawn -= 1
			spawn_timer = maxf(0.32, 1.15 - current_wave * 0.07)
	elif mobs.is_empty() and state == State.PLAYING:
		# Wave Cleared! Short pause, then fade to black & show next wave
		current_wave += 1
		_play_sfx(392.0, 784.0, 0.35, 0)
		_add_floating_text("WAVE CLEARED!", player["pos"] - Vector2(0, 60), Color("ffe762"))
		_start_wave_transition(current_wave, 0.95)

func _spawn_mob() -> void:
	# 4 Diverse Terraria-Inspired Flying Mob Archetypes:
	# 0: Demon Eye (Crimson iris, trailing veins, agile)
	# 1: Corrupt Eater / Hornet (Toxic green wings, segmented mandibles)
	# 2: Pixie Wisp (Radiant cyan/gold fae core, fast flutter)
	# 3: Crimson Bat / Wyvern Imp (Purple winged demon, rapid fire)
	var max_archetype: int = mini(3, (current_wave - 1) / 1)
	var mob_type: int = randi_range(0, max_archetype)

	var spawn_x: float = randf_range(80.0, VIEW_W - 80.0)
	var spawn_y: float = -40.0
	if randf() < 0.4:
		spawn_x = -40.0 if randf() < 0.5 else VIEW_W + 40.0
		spawn_y = randf_range(70.0, 260.0)

	var base_fire_cd: float = maxf(0.85, 2.55 - current_wave * 0.14)
	var laser_spd: float = minf(760.0, 350.0 + current_wave * 26.0)

	# Smartness scales with wave: mobs dodge bounced lasers faster and more reliably!
	var dodge_chance: float = clampf((current_wave - 1) * 0.16, 0.0, 0.82)
	var dodge_strength: float = 210.0 + current_wave * 28.0

	mobs.append({
		"type": mob_type,
		"pos": Vector2(spawn_x, spawn_y),
		"vel": Vector2.ZERO,
		"target_pos": Vector2(randf_range(120.0, VIEW_W - 120.0), randf_range(75.0, 290.0)),
		"retarget_timer": randf_range(1.2, 2.6),
		"shoot_timer": randf_range(0.9, base_fire_cd),
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
		m["dodge_cooldown"] = maxf(0.0, m["dodge_cooldown"] - delta)
		m["retarget_timer"] -= delta

		if m["retarget_timer"] <= 0.0 or m["pos"].distance_to(m["target_pos"]) < 36.0:
			m["target_pos"] = Vector2(randf_range(100.0, VIEW_W - 100.0), randf_range(65.0, 310.0))
			m["retarget_timer"] = randf_range(1.4, 2.8)

		var desired_vel: Vector2 = (m["target_pos"] - m["pos"]).normalized() * (115.0 + current_wave * 8.0)
		desired_vel.y += sin(m["anim"]) * 35.0

		# Smart AI Evasion: Detect bounced lasers heading toward this mob and juke perpendicular!
		if current_wave >= 2 and m["dodge_cooldown"] <= 0.0:
			for l in lasers:
				if l["bounced"]:
					var to_mob: Vector2 = m["pos"] - l["pos"]
					var dist: float = to_mob.length()
					if dist < 240.0 and dist > 10.0:
						var l_dir: Vector2 = l["vel"].normalized()
						var alignment: float = l_dir.dot(to_mob.normalized())
						# If the bounced laser is heading straight at this mob
						if alignment > 0.84:
							if randf() < m["dodge_chance"]:
								var perp := Vector2(-l_dir.y, l_dir.x)
								if perp.dot(m["pos"] - Vector2(VIEW_W * 0.5, 180.0)) > 0.0:
									perp = -perp
								m["vel"] = perp * m["dodge_strength"]
								m["dodge_cooldown"] = maxf(0.48, 1.15 - current_wave * 0.06)
								_spawn_burst(m["pos"], Color("ffee83"), 6, 95.0)
								_add_floating_text("DODGE!", m["pos"] + Vector2(0, -26), Color("ffee83"))
							else:
								# Failed roll to dodge this particular laser briefly
								m["dodge_cooldown"] = 0.35
							break

		m["vel"] = m["vel"].lerp(desired_vel, 4.5 * delta)
		m["pos"] += m["vel"] * delta
		m["pos"].x = clampf(m["pos"].x, 55.0, VIEW_W - 55.0)
		m["pos"].y = clampf(m["pos"].y, 50.0, 360.0)

		# Laser charging & firing
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
				"bounced": false,
				"owner": m,
				"color": col,
				"trail": []
			})
			_play_sfx(780.0, 310.0, 0.11, 0)

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
# LASERS & COLLISIONS
# ==============================================================================
func _update_lasers(delta: float) -> void:
	var p_center: Vector2 = player["pos"] - Vector2(0, player["h"] * 0.5)

	for i in range(lasers.size() - 1, -1, -1):
		var l = lasers[i]
		l["trail"].append(l["pos"])
		if l["trail"].size() > 7:
			l["trail"].pop_front()

		l["pos"] += l["vel"] * delta

		# Remove offscreen lasers
		if l["pos"].x < -80.0 or l["pos"].x > VIEW_W + 80.0 or l["pos"].y < -80.0 or l["pos"].y > VIEW_H + 80.0:
			lasers.remove_at(i)
			continue

		if not l["bounced"]:
			# If player is currently inside their active parry frames, deflect it!
			if player["parry_active_timer"] > 0.0 and l["pos"].distance_to(p_center) <= PARRY_RADIUS:
				_check_parry_deflection()
				continue

			# Check if laser hits the player body
			var p_rect := Rect2(player["pos"].x - player["w"] * 0.45, player["pos"].y - player["h"], player["w"] * 0.9, player["h"])
			if p_rect.grow(3.0).has_point(l["pos"]):
				lasers.remove_at(i)
				_damage_player()
				continue

			# Laser hits ground
			if l["pos"].y >= GROUND_Y:
				_spawn_burst(l["pos"], l["color"], 7, 90.0)
				lasers.remove_at(i)
				continue
		else:
			# Bounced laser: check collision with any flying mob
			var hit_mob := false
			for j in range(mobs.size() - 1, -1, -1):
				var m = mobs[j]
				if l["pos"].distance_to(m["pos"]) <= m["radius"] + 10.0:
					_spawn_burst(m["pos"], Color("ff5555"), 24, 240.0)
					_spawn_burst(m["pos"], Color("73eff7"), 14, 180.0)
					_add_floating_text("ELIMINATED!", m["pos"], Color("ffdd55"))
					_play_sfx(240.0, 75.0, 0.22, 1)
					screen_shake = 8.5
					mobs.remove_at(j)
					lasers.remove_at(i)
					hit_mob = true
					break
			if hit_mob:
				continue

func _damage_player() -> void:
	if player["invuln_timer"] > 0.0:
		return
	player["hearts"] -= 1
	player["invuln_timer"] = 0.65
	screen_shake = 11.0
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

	for i in range(floating_texts.size() - 1, -1, -1):
		var ft = floating_texts[i]
		ft["life"] -= delta
		ft["pos"].y -= 38.0 * delta
		if ft["life"] <= 0.0:
			floating_texts.remove_at(i)

# ==============================================================================
# CUSTOM RENDERING (Terraria Forest, Character, Mobs, Robot Font, UI)
# ==============================================================================
func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake))

	draw_set_transform(shake_offset, 0.0, Vector2.ONE)

	_draw_terraria_forest_background()
	_draw_platforms_and_ground()

	if state in [State.PLAYING, State.TRANSITION, State.GAME_OVER]:
		_draw_player()
		_draw_mobs()
		_draw_lasers()
		_draw_particles_and_texts()
		_draw_hud()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if state == State.MENU:
		_draw_main_menu()
	elif state == State.GAME_OVER:
		_draw_game_over_overlay()

	if state == State.TRANSITION or transition_alpha > 0.001:
		_draw_wave_transition_overlay()

func _draw_terraria_forest_background() -> void:
	# Sky gradient bands (Terraria twilight/day-forest mood)
	draw_rect(Rect2(0, 0, VIEW_W, 240), Color("16203a"))
	draw_rect(Rect2(0, 240, VIEW_W, 200), Color("1f3156"))
	draw_rect(Rect2(0, 440, VIEW_W, VIEW_H - 440), Color("294268"))

	# Distant pixelated mountains
	var m1 := PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(0, 390), Vector2(180, 260), Vector2(390, 410),
		Vector2(620, 230), Vector2(880, 400), Vector2(1090, 275), Vector2(VIEW_W, 370), Vector2(VIEW_W, GROUND_Y)
	])
	draw_colored_polygon(m1, Color("182844"))

	# Rolling forest hills
	var m2 := PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(0, 470), Vector2(240, 420), Vector2(510, 485),
		Vector2(790, 415), Vector2(1040, 470), Vector2(VIEW_W, 435), Vector2(VIEW_W, GROUND_Y)
	])
	draw_colored_polygon(m2, Color("1d3a45"))

	# Clouds
	for c in clouds:
		var cp: Vector2 = c["pos"]
		var sc: float = c["scale"]
		draw_rect(Rect2(cp.x - 42 * sc, cp.y, 84 * sc, 18 * sc), Color(0.85, 0.92, 1.0, 0.22))
		draw_rect(Rect2(cp.x - 26 * sc, cp.y - 12 * sc, 52 * sc, 14 * sc), Color(0.90, 0.95, 1.0, 0.26))

	# Terraria-style background giant forest trees
	for t in trees:
		var tx: float = t["x"]
		var th: float = t["h"]
		var tw: float = t["w"]
		var cr: float = t["canopy"]
		# Trunk & roots
		draw_rect(Rect2(tx - tw * 0.5, GROUND_Y - th, tw, th), Color("4b3124"))
		draw_rect(Rect2(tx - tw * 0.3, GROUND_Y - th, tw * 0.35, th), Color("5e3e2e"))
		draw_rect(Rect2(tx - tw * 0.8, GROUND_Y - 14, tw * 1.6, 14), Color("4b3124"))
		# Layered pixelated canopy puffs
		var top_y: float = GROUND_Y - th
		var leaf_dark := Color(0.12, 0.36 + t["tint"], 0.23)
		var leaf_mid := Color(0.18, 0.48 + t["tint"], 0.29)
		var leaf_bright := Color(0.27, 0.62 + t["tint"], 0.34)
		draw_circle(Vector2(tx - cr * 0.45, top_y + 12), cr * 0.62, leaf_dark)
		draw_circle(Vector2(tx + cr * 0.45, top_y + 12), cr * 0.62, leaf_dark)
		draw_circle(Vector2(tx, top_y - cr * 0.25), cr * 0.78, leaf_mid)
		draw_circle(Vector2(tx - cr * 0.22, top_y - cr * 0.38), cr * 0.48, leaf_bright)

	# Ambient glowing forest fireflies
	for f in fireflies:
		var alpha: float = 0.35 + 0.45 * sin(f["phase"])
		draw_rect(Rect2(f["pos"].x, f["pos"].y, 4, 4), Color(0.75, 1.0, 0.45, alpha))

func _draw_platforms_and_ground() -> void:
	# One-way Wooden & Mossy Forest Platforms
	for plat in platforms:
		# Support beam shadow
		draw_rect(Rect2(plat.position.x + 6, plat.position.y + 6, plat.size.x - 12, plat.size.y), Color(0, 0, 0, 0.35))
		# Wood plank body
		draw_rect(plat, Color("5c3c28"))
		# Top grassy/mossy trim (signals jump-through floor)
		draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 5), Color("38b764"))
		draw_rect(Rect2(plat.position.x, plat.position.y + 5, plat.size.x, 3), Color("257179"))
		# Plank vertical joints
		var num_joints := int(plat.size.x / 36.0)
		for k in range(1, num_joints):
			var jx: float = plat.position.x + k * 36.0
			draw_line(Vector2(jx, plat.position.y + 5), Vector2(jx, plat.position.y + plat.size.y), Color("3b2416"), 2.0)
		draw_rect(plat, Color("2a1a10"), false, 2.0)

	# Terraria-style tiled dirt & lush grass floor
	draw_rect(Rect2(0, GROUND_Y, VIEW_W, VIEW_H - GROUND_Y), Color("4f3324"))
	# Dirt blocks texture
	for gx in range(0, int(VIEW_W), 32):
		for gy in range(int(GROUND_Y) + 16, int(VIEW_H), 28):
			draw_rect(Rect2(gx + 4, gy + 4, 24, 20), Color("42291c"))
			if (gx + gy) % 64 == 0:
				draw_rect(Rect2(gx + 10, gy + 8, 8, 8), Color("5e4b42")) # Embedded stone pebble

	# Top grass layer
	draw_rect(Rect2(0, GROUND_Y, VIEW_W, 12), Color("38b764"))
	draw_rect(Rect2(0, GROUND_Y + 12, VIEW_W, 5), Color("257179"))
	for g in grass_tufts:
		draw_line(Vector2(g["x"], GROUND_Y), Vector2(g["x"] + g["lean"], GROUND_Y - g["h"]), Color("59c135"), 2.5)

func _draw_player() -> void:
	var p: Vector2 = player["pos"]
	var facing: int = player["facing"]
	var flash: bool = (player["invuln_timer"] > 0.0 and int(player["invuln_timer"] * 20.0) % 2 == 0)

	# Parry shield aura
	var p_center := p - Vector2(0, player["h"] * 0.5)
	if player["parry_active_timer"] > 0.0 or player["parry_flash"] > 0.0:
		var a: float = clampf(player["parry_flash"] * 5.0, 0.15, 0.85)
		draw_arc(p_center, PARRY_RADIUS * 0.72, 0.0, TAU, 36, Color(0.25, 0.95, 1.0, a), 3.5)
		draw_circle(p_center, PARRY_RADIUS * 0.65, Color(0.25, 0.95, 1.0, a * 0.22))
	elif player["parry_fail_flash"] > 0.0:
		draw_arc(p_center, 26.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.3, 0.75), 2.5)

	if flash:
		return

	var leg_swing: float = sin(player["walk_anim"]) * 5.0 if player["on_ground"] else 4.0

	# Boots & Trousers (Terraria Guide / Hero look)
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("2b4c7e"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("1e3559"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("3d251e"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("3d251e"))

	# Tunic & Belt
	draw_rect(Rect2(p.x - 8, p.y - 25, 16, 14), Color("4b8b5b"))
	draw_rect(Rect2(p.x - 8, p.y - 15, 16, 3), Color("3d251e"))
	draw_rect(Rect2(p.x - 2, p.y - 15, 4, 3), Color("ffd84d")) # Belt buckle

	# Head & Face
	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	# Eye
	var eye_x: float = p.x + (3.0 if facing > 0 else -5.0)
	draw_rect(Rect2(eye_x, p.y - 33, 2.5, 3.5), Color("1a1c2c"))

	# Iconic Terraria Spiky Brown Hair
	draw_rect(Rect2(p.x - 8, p.y - 40, 16, 5), Color("6e3b26"))
	draw_rect(Rect2(p.x - (8 if facing > 0 else 4), p.y - 37, 5, 7), Color("6e3b26"))
	draw_rect(Rect2(p.x - 6, p.y - 42, 12, 3), Color("854930"))

	# Arm & Energy Parry Buckler/Blade
	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("4b8b5b"))
	var shield_col := Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("6b7280")
	draw_rect(Rect2(p.x + facing * 10.0 - 2.0, p.y - 26, 4, 13), shield_col)

func _draw_mobs() -> void:
	for m in mobs:
		var pos: Vector2 = m["pos"]
		var t: int = m["type"]
		var flap: float = sin(m["anim"] * 2.2) * 8.0

		# Charging laser telegraph glow
		if m["charge_glow"] > 0.0:
			draw_circle(pos, 26.0 + m["charge_glow"] * 8.0, Color(1.0, 0.25, 0.35, m["charge_glow"] * 0.35))

		if t == 0:
			# Type 0: Terraria Demon Eye (Floating eyeball with crimson trailing tendrils)
			var p_dir: Vector2 = (player["pos"] - pos).normalized()
			for k in range(3):
				var tail_start := pos - p_dir * 14.0 + Vector2(0, (k - 1) * 6.0)
				var tail_end := tail_start - p_dir * 16.0 + Vector2(sin(m["anim"] + k) * 5.0, cos(m["anim"] + k) * 5.0)
				draw_line(tail_start, tail_end, Color("b1203d"), 3.0)
			draw_circle(pos, 18.0, Color("b1203d"))
			draw_circle(pos, 15.5, Color("f4f4f8"))
			draw_circle(pos + p_dir * 5.0, 7.5, Color("d92648"))
			draw_circle(pos + p_dir * 6.5, 3.5, Color("141018"))
		elif t == 1:
			# Type 1: Corrupt Eater / Jungle Hornet (Green chitin, buzzing wings & mandibles)
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
			# Type 2: Hallowed Pixie Wisp (Glowing fae wings + radiant core)
			draw_circle(pos + Vector2(-16, flap * 0.7), 10.0, Color(0.95, 0.65, 1.0, 0.45))
			draw_circle(pos + Vector2(16, flap * 0.7), 10.0, Color(0.95, 0.65, 1.0, 0.45))
			draw_circle(pos, 18.0, Color(1.0, 0.45, 0.88, 0.38))
			draw_circle(pos, 12.0, Color("ff9be8"))
			draw_circle(pos, 6.5, Color("ffffff"))
		else:
			# Type 3: Hellwing Imp / Bat (Leathery crimson wings, horned silhouette, blazing eyes)
			draw_colored_polygon(PackedVector2Array([
				pos, pos + Vector2(-28, -14 + flap), pos + Vector2(-20, 10 + flap * 0.4)
			]), Color("591f36"))
			draw_colored_polygon(PackedVector2Array([
				pos, pos + Vector2(28, -14 + flap), pos + Vector2(20, 10 + flap * 0.4)
			]), Color("591f36"))
			draw_circle(pos, 15.0, Color("381426"))
			draw_circle(pos + Vector2(-5, -2), 3.5, Color("ff9e2c"))
			draw_circle(pos + Vector2(5, -2), 3.5, Color("ff9e2c"))

func _draw_lasers() -> void:
	for l in lasers:
		var pos: Vector2 = l["pos"]
		var dir: Vector2 = l["vel"].normalized()
		var col: Color = l["color"]

		# Glowing tail
		for k in range(l["trail"].size()):
			var tp: Vector2 = l["trail"][k]
			var ratio: float = float(k + 1) / float(l["trail"].size() + 1)
			draw_circle(tp, 4.5 * ratio, Color(col.r, col.g, col.b, 0.45 * ratio))

		# Outer laser beam & white-hot core
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
		draw_string_outline(font, ft["pos"] - Vector2(55, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 110, 16, 4, Color(0, 0, 0, c.a))
		draw_string(font, ft["pos"] - Vector2(55, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 110, 16, c)

# ==============================================================================
# HUD (5 Hearts, Wave Counter, Controls & Parry Ready Indicator)
# ==============================================================================
func _draw_hud() -> void:
	# 5 Classic Terraria-style Hearts top-left
	for i in range(player["max_hearts"]):
		var hx: float = 38.0 + i * 38.0
		var hy: float = 36.0
		var filled: bool = (i < player["hearts"])
		_draw_heart_icon(Vector2(hx, hy), 14.0, filled)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(28, 76), "WAVE %d   |   MOBS LEFT: %d" % [current_wave, mobs.size() + mobs_to_spawn], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color.BLACK)
	draw_string(font, Vector2(28, 76), "WAVE %d   |   MOBS LEFT: %d" % [current_wave, mobs.size() + mobs_to_spawn], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe762"))

	var parry_status := "PARRY [F]: READY" if player["parry_cooldown_timer"] <= 0.0 else "PARRY [F]: RECHARGING"
	var parry_col := Color("73eff7") if player["parry_cooldown_timer"] <= 0.0 else Color("ff6b6b")
	draw_string_outline(font, Vector2(28, 102), parry_status + "   |   [A/D] Move   [W/Space] Jump Up Floors", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	draw_string(font, Vector2(28, 102), parry_status + "   |   [A/D] Move   [W/Space] Jump Up Floors", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, parry_col)

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
# ROBOT FONT RENDERER ("Bounce Back" Big in Middle Top in a Robot Police/Typeface)
# ==============================================================================
const ROBOT_GLYPHS := {
	"B": ["11110", "10001", "11110", "10001", "11110"],
	"O": ["01110", "10001", "10001", "10001", "01110"],
	"U": ["10001", "10001", "10001", "10001", "01110"],
	"N": ["10001", "11001", "10101", "10011", "10001"],
	"C": ["01111", "10000", "10000", "10000", "01111"],
	"E": ["11111", "10000", "11110", "10000", "11111"],
	"A": ["01110", "10001", "11111", "10001", "10001"],
	"K": ["10001", "10010", "11100", "10010", "10001"],
	" ": ["00000", "00000", "00000", "00000", "00000"]
}

func _draw_robot_title(text: String, center_pos: Vector2, pixel_size: float) -> void:
	var upper := text.to_upper()
	var char_w: float = 5.0 * pixel_size
	var spacing: float = 1.6 * pixel_size
	var total_w: float = upper.length() * char_w + (upper.length() - 1) * spacing
	var start_x: float = center_pos.x - total_w * 0.5
	var start_y: float = center_pos.y - (5.0 * pixel_size) * 0.5

	# Robot visor frame behind title
	var pad := 24.0
	var plate := Rect2(start_x - pad, start_y - pad, total_w + pad * 2.0, 5.0 * pixel_size + pad * 2.0)
	_draw_rounded_box(plate, 18.0, Color(0.08, 0.11, 0.19, 0.88), Color("41f3ff"), 4.0)

	# Robot antenna bolts on top of title frame
	draw_circle(Vector2(plate.position.x + 18, plate.position.y + 18), 5.0, Color("ff4b6b"))
	draw_circle(Vector2(plate.end.x - 18, plate.position.y + 18), 5.0, Color("41f3ff"))

	for idx in range(upper.length()):
		var ch := upper.substr(idx, 1)
		var grid: Array = ROBOT_GLYPHS.get(ch, ROBOT_GLYPHS[" "])
		var cx: float = start_x + idx * (char_w + spacing)
		for r in range(5):
			var row_str: String = grid[r]
			for c in range(5):
				if row_str.substr(c, 1) == "1":
					var px := cx + c * pixel_size
					var py := start_y + r * pixel_size
					# Drop shadow
					draw_rect(Rect2(px + 4, py + 5, pixel_size - 1, pixel_size - 1), Color("0b0e17"))
					# Metallic neon robot segment
					var seg_col := Color("41f3ff") if r < 2 else Color("38b764")
					draw_rect(Rect2(px, py, pixel_size - 1.5, pixel_size - 1.5), seg_col)
					draw_rect(Rect2(px + 2, py + 2, pixel_size * 0.4, pixel_size * 0.4), Color(1, 1, 1, 0.65))

# ==============================================================================
# MENU, BOUNCY ROUNDED BUTTONS, CREDITS MODAL & WAVE TRANSITION
# ==============================================================================
func _draw_main_menu() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.05, 0.07, 0.13, 0.52))

	var bob: float = sin(Time.get_ticks_msec() * 0.003) * 6.0
	_draw_robot_title("BOUNCE BACK", Vector2(VIEW_W * 0.5, 145.0 + bob), 12.5)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, 258), "PRESS [F] RIGHT BEFORE IMPACT TO PARRY LASERS BACK AT MOBS!", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 19, 4, Color.BLACK)
	draw_string(font, Vector2(0, 258), "PRESS [F] RIGHT BEFORE IMPACT TO PARRY LASERS BACK AT MOBS!", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 19, Color("ffe762"))

	# Bouncy Catchy Rounded Buttons
	_draw_bouncy_button(start_btn_rect, btn_scales["start"], Color("ff5e7e"), Color("ff9e2c"), "START", 32)
	_draw_bouncy_button(credits_btn_rect, btn_scales["credits"], Color("38b764"), Color("41f3ff"), "CREDITS", 30)

	if credits_open:
		_draw_credits_modal()

func _draw_game_over_overlay() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.06, 0.02, 0.05, 0.74))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, 180), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 64, 8, Color.BLACK)
	draw_string(font, Vector2(0, 180), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 64, Color("ff3b5b"))

	draw_string_outline(font, Vector2(0, 245), "You reached Wave %d" % current_wave, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, 5, Color.BLACK)
	draw_string(font, Vector2(0, 245), "You reached Wave %d" % current_wave, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, Color("ffe762"))

	_draw_bouncy_button(start_btn_rect, btn_scales["start"], Color("ff5e7e"), Color("ff9e2c"), "RETRY WAVE 1", 28)
	_draw_bouncy_button(credits_btn_rect, btn_scales["credits"], Color("3b5dc9"), Color("41f3ff"), "MAIN MENU", 28)

func _draw_bouncy_button(rect: Rect2, scale_val: float, fill_col: Color, border_col: Color, label: String, font_size: int) -> void:
	var center := rect.get_center()
	var scaled_size := rect.size * scale_val
	var s_rect := Rect2(center - scaled_size * 0.5, scaled_size)

	# Shadow
	_draw_rounded_box(Rect2(s_rect.position + Vector2(0, 7), s_rect.size), 20.0, Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0.0)
	# Main button body
	_draw_rounded_box(s_rect, 20.0, fill_col, border_col, 4.0)
	# Top glossy highlight
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

	# Little Red Circle at the top-right of the square to close it and return to main menu
	var r: float = CLOSE_BTN_RADIUS * btn_scales["close"]
	draw_circle(close_credits_center + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.45))
	draw_circle(close_credits_center, r, Color("ff2a4b"))
	draw_arc(close_credits_center, r, 0.0, TAU, 28, Color.WHITE, 2.5)
	# Crisp 'X' inside the red circle
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
