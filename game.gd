extends Node2D

# ==============================================================================
# BOUNCE BACK - Complete Godot 4 Game Script
# Creators: Mounib Reda, Chingiz Shikhgayibov, Nurazkhan Nygmet
# ==============================================================================

enum State { MENU, TRANSITION, PLAYING, GAME_OVER }
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
const PARRY_RADIUS := 70.0      # Deflection reach around player center

# --- Character Abilities State ---
# Bandit: Dash to dodge (Shift), covers big distance, hitbox negation, 5s cooldown, wind & woosh
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
var characters_open: bool = false
var online_lobby_open: bool = false
var viewing_character: Character = Character.BANDIT
var boss_warning_timer: float = 0.0

var start_btn_rect := Rect2(470, 280, 340, 56)
var online_btn_rect := Rect2(470, 350, 340, 56)
var characters_btn_rect := Rect2(470, 420, 340, 56)
var credits_btn_rect := Rect2(470, 490, 340, 56)

var retry_btn_rect := Rect2(470, 335, 340, 62)
var game_over_menu_btn_rect := Rect2(470, 415, 340, 62)

var credits_box_rect := Rect2(350, 180, 580, 370)
var close_credits_center := Vector2(895, 215)
const CLOSE_BTN_RADIUS := 20.0

var char_box_rect := Rect2(60, 35, 1160, 650)
var close_char_center := Vector2(1185, 62)
var char_tab_rects: Array[Rect2] = [
	Rect2(80, 86, 360, 48),
	Rect2(460, 86, 360, 48),
	Rect2(840, 86, 360, 48)
]
var char_activate_btn_rect := Rect2(556, 566, 628, 54)

# --- Online Lobby & WebRTC Networking ---
var online_box_rect := Rect2(160, 55, 960, 610)
var close_online_center := Vector2(1095, 85)
var host_card_rect := Rect2(190, 115, 435, 455)
var join_card_rect := Rect2(655, 115, 435, 455)
var host_create_btn_rect := Rect2(225, 345, 365, 52)
var host_start_btn_rect := Rect2(225, 415, 365, 56)
var join_enter_btn_rect := Rect2(690, 385, 365, 54)
var server_url_bar_rect := Rect2(190, 580, 900, 42)

var signaling_server_url: String = "wss://assumed-residents-oxford-gotta.trycloudflare.com"
var editing_server_url: bool = false
var ws_client: WebSocketPeer = null
var rtc_conn: WebRTCPeerConnection = null
var rtc_data_channel: WebRTCDataChannel = null

var is_multiplayer: bool = false
var is_host: bool = false
var my_room_code: String = ""
var join_code_input: String = ""
var online_status: String = "DISCONNECTED"
var peer_is_ready: bool = false
var net_sync_timer: float = 0.0
var host_world_sync_timer: float = 0.0
var revive_timer: float = 0.0
var p2_reviving_progress: float = 0.0

# Remote Teammate Player State
var player2 := {
	"active": false,
	"pos": Vector2(740.0, 630.0),
	"target_pos": Vector2(740.0, 630.0),
	"vel": Vector2.ZERO,
	"facing": -1,
	"walk_anim": 0.0,
	"character": Character.SCIENTIST,
	"hearts": 5,
	"max_hearts": 5,
	"is_down": false,
	"parry_active_timer": 0.0,
	"parry_flash": 0.0,
	"invuln_timer": 0.0
}

var btn_scales := {
	"start": 1.0,
	"online": 1.0,
	"characters": 1.0,
	"credits": 1.0,
	"close": 1.0,
	"char_close": 1.0,
	"online_close": 1.0,
	"host_create": 1.0,
	"host_start": 1.0,
	"join_btn": 1.0,
	"edit_server": 1.0,
	"tab_0": 1.0,
	"tab_1": 1.0,
	"tab_2": 1.0,
	"char_activate": 1.0
}
var btn_vel := {
	"start": 0.0,
	"online": 0.0,
	"characters": 0.0,
	"credits": 0.0,
	"close": 0.0,
	"char_close": 0.0,
	"online_close": 0.0,
	"host_create": 0.0,
	"host_start": 0.0,
	"join_btn": 0.0,
	"edit_server": 0.0,
	"tab_0": 0.0,
	"tab_1": 0.0,
	"tab_2": 0.0,
	"char_activate": 0.0
}
var btn_hovered := {
	"start": false,
	"online": false,
	"characters": false,
	"credits": false,
	"close": false,
	"char_close": false,
	"online_close": false,
	"host_create": false,
	"host_start": false,
	"join_btn": false,
	"edit_server": false,
	"tab_0": false,
	"tab_1": false,
	"tab_2": false,
	"char_activate": false
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

# Nerdy minor-key arpeggio frequencies (C minor / Phrygian tension loop)
const ARP_NOTES := [
	261.63, 311.13, 392.00, 523.25, 392.00, 311.13, 466.16, 392.00,
	277.18, 349.23, 415.30, 554.37, 415.30, 349.23, 523.25, 415.30
]
const BASS_NOTES := [130.81, 130.81, 155.56, 130.81, 138.59, 138.59, 123.47, 146.83]

func _ready() -> void:
	randomize()
	if FileAccess.file_exists("user://server_url.txt"):
		var saved_url := FileAccess.get_file_as_string("user://server_url.txt").strip_edges()
		if saved_url != "" and not saved_url.contains("niro.hackclub.app"):
			signaling_server_url = saved_url
		else:
			_save_server_url(signaling_server_url)
	else:
		_save_server_url(signaling_server_url)
	_generate_scenery()
	_setup_audio()

func _save_server_url(url: String) -> void:
	var f := FileAccess.open("user://server_url.txt", FileAccess.WRITE)
	if f:
		f.store_string(url)
		f.close()

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

	# Dynamic Grief / Underworld Elements:
	# 1. Rising Embers & Heat Shimmers
	grief_embers.clear()
	for i in range(48):
		grief_embers.append({
			"pos": Vector2(randf_range(0, VIEW_W), randf_range(50, VIEW_H)),
			"vel": Vector2(randf_range(-25, 25), randf_range(-65, -130)),
			"size": randf_range(2.0, 5.0),
			"alpha": randf_range(0.3, 0.85),
			"hue": randf_range(0.0, 1.0)
		})

	# 2. Vertical pulsating Geometry Dash Grief laser columns
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

	# 3. Hanging chains with obsidian crystals
	grief_chains.clear()
	var chain_xs := [90.0, 270.0, 440.0, 640.0, 840.0, 1030.0, 1210.0]
	for cx in chain_xs:
		grief_chains.append({
			"x": cx,
			"len": randf_range(60.0, 140.0),
			"sway_phase": randf_range(0.0, TAU),
			"crystal_size": randf_range(12.0, 22.0)
		})

	# 4. Demon eyes blinking in the background mountains
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
	# Wave type 2: Filtered air/wind woosh for Bandit's dash
	_play_sfx(600.0, 180.0, 0.22, 2)

func _play_freeze_sfx() -> void:
	# Wave type 3: Temporal sub-bass and crystalline chime for Scientist
	_play_sfx(160.0, 60.0, 0.38, 3)
	_play_sfx(1200.0, 400.0, 0.28, 3)

func _play_heal_sfx() -> void:
	# Wave type 3: Pure gentle health restorative chime for Nurse
	_play_sfx(440.0, 880.0, 0.32, 3)

func _fill_audio_buffers() -> void:
	var mix_rate := 22050.0
	if music_playback:
		var frames := music_playback.get_frames_available()
		var step_dur := 0.115 if state != State.PLAYING else maxf(0.065, 0.115 - current_wave * 0.005)
		# On Wave 5 (Boss Wave), music steps up for tryhard adrenaline
		if current_wave == 5 and state == State.PLAYING:
			step_dur = 0.072

		for i in range(frames):
			arp_time += 1.0 / mix_rate
			if arp_time >= step_dur:
				arp_time -= step_dur
				arp_step = (arp_step + 1) % ARP_NOTES.size()
				# Grief background beat pulse sync
				if arp_step % 2 == 0:
					grief_pulse_flash = 0.14

			var freq: float = ARP_NOTES[arp_step]
			var bass_freq: float = BASS_NOTES[(arp_step / 2) % BASS_NOTES.size()]
			# Boss wave pitches down slightly for menacing sub-heavy terror
			if current_wave == 5 and state == State.PLAYING:
				freq *= 0.75
				bass_freq *= 0.75

			var env: float = maxf(0.0, 1.0 - (arp_time / step_dur) * 0.75)

			music_phase = fmod(music_phase + freq / mix_rate, 1.0)
			bass_phase = fmod(bass_phase + bass_freq / mix_rate, 1.0)

			# Pulse wave + triangle bass
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
				elif s["type"] == 1: # Noise + tone (Hit / Explosion)
					sample += ((randf() * 2.0 - 1.0) * 0.5 + sin(s["phase"] * TAU) * 0.5) * 0.38 * env
				elif s["type"] == 2: # Wind / Woosh (Bandit Dash)
					var noise := (randf() * 2.0 - 1.0) * 0.44 * sin(prog * PI)
					sample += noise
				elif s["type"] == 3: # Harmonic Sine Chime (Scientist Time / Nurse Heal)
					sample += sin(s["phase"] * TAU) * 0.36 * env
			sample = clampf(sample, -0.95, 0.95)
			sfx_playback.push_frame(Vector2(sample, sample))

# ==============================================================================
# WEBRTC & WEBSOCKET NETWORKING ENGINE
# ==============================================================================
func _clean_url(raw: String) -> String:
	var u := raw.strip_edges()
	while u.ends_with("/"):
		u = u.substr(0, u.length() - 1)
	if u.begins_with("https://"):
		u = "wss://" + u.substr(8)
	elif u.begins_with("http://"):
		u = "ws://" + u.substr(7)
	elif not u.begins_with("ws://") and not u.begins_with("wss://"):
		u = "wss://" + u
	return u

func _connect_to_signaling() -> void:
	if ws_client != null:
		ws_client.close()
	ws_client = WebSocketPeer.new()
	signaling_server_url = _clean_url(signaling_server_url)
	_save_server_url(signaling_server_url)
	var err := ws_client.connect_to_url(signaling_server_url)
	if err != OK:
		online_status = "FAILED TO CONNECT (ERROR %d)" % err
	else:
		online_status = "CONNECTING TO SIGNALING SERVER..."

func _create_online_room() -> void:
	if ws_client == null or ws_client.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_connect_to_signaling()
	online_status = "CREATING ROOM..."
	_send_signaling_packet({"type": "create"})

func _join_online_room() -> void:
	if join_code_input.length() != 4:
		return
	if ws_client == null or ws_client.get_ready_state() != WebSocketPeer.STATE_OPEN:
		_connect_to_signaling()
	online_status = "JOINING ROOM %s..." % join_code_input
	_send_signaling_packet({"type": "join", "code": join_code_input})

func _send_signaling_packet(packet: Dictionary) -> void:
	if ws_client != null and ws_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_client.send_text(JSON.stringify(packet))

func _send_game_message(data: Dictionary) -> void:
	# 1. High speed WebRTC P2P direct data channel
	if rtc_data_channel != null and rtc_data_channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		rtc_data_channel.put_packet(JSON.stringify(data).to_utf8_buffer())
	# 2. Reliable WebSocket relay fallback on Hack Club Nest Linux server
	elif ws_client != null and ws_client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws_client.send_text(JSON.stringify({"type": "msg", "data": data}))

func _init_webrtc() -> void:
	rtc_conn = WebRTCPeerConnection.new()
	rtc_conn.initialize({
		"iceServers": [{ "urls": ["stun:stun.l.google.com:19302"] }]
	})
	rtc_conn.session_description_created.connect(_on_session_description_created)
	rtc_conn.ice_candidate_created.connect(_on_ice_candidate_created)
	rtc_data_channel = rtc_conn.create_data_channel("bounce_back", {"negotiated": true, "id": 1})

func _on_session_description_created(type: String, sdp: String) -> void:
	if rtc_conn != null:
		rtc_conn.set_local_description(type, sdp)
	_send_signaling_packet({
		"type": "signal",
		"data": {
			"type": type,
			"sdp": sdp
		}
	})

func _on_ice_candidate_created(media: String, index: int, name: String) -> void:
	_send_signaling_packet({
		"type": "signal",
		"data": {
			"type": "ice",
			"media": media,
			"index": index,
			"name": name
		}
	})

func _handle_signal_packet(sig: Dictionary) -> void:
	if rtc_conn == null:
		return
	var s_type: String = sig.get("type", "")
	if s_type == "offer":
		rtc_conn.set_remote_description(s_type, sig.get("sdp", ""))
		rtc_conn.create_answer()
	elif s_type == "answer":
		rtc_conn.set_remote_description(s_type, sig.get("sdp", ""))
	elif s_type == "ice":
		rtc_conn.add_ice_candidate(sig.get("media", ""), sig.get("index", 0), sig.get("name", ""))

func _host_start_coop_game() -> void:
	if not peer_is_ready:
		return
	is_multiplayer = true
	is_host = true
	player2["active"] = true
	online_lobby_open = false
	_send_game_message({
		"action": "start_game",
		"wave": 1,
		"host_char": selected_character
	})
	_begin_game_from_wave_1()

func _update_networking(delta: float) -> void:
	# 1. Poll WebRTC Connection & Data Channel
	if rtc_conn != null:
		rtc_conn.poll()
	if rtc_data_channel != null:
		rtc_data_channel.poll()
		while rtc_data_channel.get_available_packet_count() > 0:
			var pkt := rtc_data_channel.get_packet()
			var msg_str := pkt.get_string_from_utf8()
			var json := JSON.new()
			if json.parse(msg_str) == OK and json.data is Dictionary:
				_handle_game_message(json.data)

	# 2. Poll WebSocket Signaling & Relay
	if ws_client != null:
		ws_client.poll()
		var ws_state := ws_client.get_ready_state()
		if ws_state == WebSocketPeer.STATE_OPEN:
			if online_status == "CONNECTING TO SIGNALING SERVER...":
				online_status = "CONNECTED TO SIGNALING SERVER"
			while ws_client.get_available_packet_count() > 0:
				var pkt := ws_client.get_packet()
				var msg_str := pkt.get_string_from_utf8()
				var json := JSON.new()
				if json.parse(msg_str) == OK and json.data is Dictionary:
					var d: Dictionary = json.data
					var msg_type: String = d.get("type", "")
					match msg_type:
						"created":
							my_room_code = d.get("code", "")
							is_host = true
							online_status = "ROOM %s READY! WAITING FOR FRIEND" % my_room_code
							_play_sfx(540.0, 880.0, 0.15, 0)
							_init_webrtc()
						"joined":
							my_room_code = d.get("code", "")
							is_host = false
							peer_is_ready = true
							online_status = "CONNECTED TO ROOM %s! READY!" % my_room_code
							_play_sfx(540.0, 880.0, 0.15, 0)
							_init_webrtc()
							_send_game_message({"action": "peer_greeting", "char": selected_character})
						"peer_joined":
							peer_is_ready = true
							online_status = "FRIEND CONNECTED! READY TO START!"
							_play_sfx(660.0, 990.0, 0.2, 0)
							if is_host:
								_init_webrtc()
								rtc_conn.create_offer()
						"peer_left":
							peer_is_ready = false
							player2["active"] = false
							online_status = "FRIEND DISCONNECTED"
							_play_sfx(330.0, 220.0, 0.2, 0)
							if state == State.PLAYING:
								_add_floating_text("CO-OP PARTNER LEFT!", Vector2(VIEW_W * 0.5, 200), Color("ff3b5b"))
						"signal":
							_handle_signal_packet(d.get("data", {}))
						"msg":
							_handle_game_message(d.get("data", {}))
						"error":
							online_status = "ERROR: " + d.get("message", "Unknown error")
							_play_sfx(220.0, 160.0, 0.2, 0)
		elif ws_state == WebSocketPeer.STATE_CLOSED:
			if online_lobby_open and online_status != "DISCONNECTED":
				online_status = "DISCONNECTED FROM SERVER"

	# 3. Synchronize Player Movement & Actions during Gameplay
	if is_multiplayer and state == State.PLAYING:
		net_sync_timer -= delta
		if net_sync_timer <= 0.0:
			net_sync_timer = 0.05 # 20 FPS sync rate
			_send_game_message({
				"action": "player_sync",
				"pos_x": player["pos"].x,
				"pos_y": player["pos"].y,
				"vel_x": player["vel"].x,
				"vel_y": player["vel"].y,
				"facing": player["facing"],
				"walk_anim": player["walk_anim"],
				"hearts": player["hearts"],
				"is_down": player.get("is_down", false),
				"parry": player["parry_active_timer"] > 0.0,
				"char": selected_character
			})

		# Host World Sync (Mobs, Lasers & Wave authority)
		if is_host:
			host_world_sync_timer -= delta
			if host_world_sync_timer <= 0.0:
				host_world_sync_timer = 0.08 # 12.5 FPS world authority sync
				var mobs_data: Array = []
				for m in mobs:
					mobs_data.append({
						"pos_x": m["pos"].x,
						"pos_y": m["pos"].y,
						"type": m["type"],
						"hp": m.get("hp", 1),
						"max_hp": m.get("max_hp", 20 if m.get("is_boss", false) else 1),
						"is_boss": m.get("is_boss", false),
						"flash": m.get("hit_flash", 0.0) > 0.0,
						"glow": m.get("charge_glow", 0.0),
						"anim": m.get("anim", 0.0)
					})
				var lasers_data: Array = []
				for l in lasers:
					lasers_data.append({
						"pos_x": l["pos"].x,
						"pos_y": l["pos"].y,
						"vel_x": l["vel"].x,
						"vel_y": l["vel"].y,
						"bounced": l["bounced"]
					})
				_send_game_message({
					"action": "host_world_sync",
					"wave": current_wave,
					"mobs": mobs_data,
					"lasers": lasers_data,
					"mobs_left": mobs.size() + mobs_to_spawn,
					"boss_warning": boss_warning_timer
				})

func _handle_game_message(data: Dictionary) -> void:
	var act: String = data.get("action", "")
	match act:
		"peer_greeting":
			peer_is_ready = true
			player2["active"] = true
			player2["character"] = data.get("char", Character.SCIENTIST)
		"start_game":
			is_multiplayer = true
			is_host = false
			player2["active"] = true
			player2["character"] = data.get("host_char", Character.BANDIT)
			online_lobby_open = false
			_begin_game_from_wave_1()
		"player_sync":
			player2["active"] = true
			player2["target_pos"] = Vector2(data.get("pos_x", player2["pos"].x), data.get("pos_y", player2["pos"].y))
			player2["vel"] = Vector2(data.get("vel_x", 0.0), data.get("vel_y", 0.0))
			player2["facing"] = int(data.get("facing", 1))
			player2["walk_anim"] = float(data.get("walk_anim", 0.0))
			player2["hearts"] = int(data.get("hearts", 5))
			player2["is_down"] = bool(data.get("is_down", false))
			player2["character"] = int(data.get("char", player2["character"]))
			if bool(data.get("parry", false)):
				player2["parry_flash"] = 0.18
		"player_parry":
			player2["parry_flash"] = 0.18
			_play_sfx(520.0, 960.0, 0.08, 0)
		"client_deflect":
			if is_host:
				var c_pos := Vector2(data.get("pos_x", 0.0), data.get("pos_y", 0.0))
				for l in lasers:
					if not l["bounced"] and l["pos"].distance_to(c_pos) <= PARRY_RADIUS + 30.0:
						l["bounced"] = true
						var target_mob = _get_nearest_mob(l["pos"])
						l["homing_target"] = target_mob
						l["speed"] = maxf(l["vel"].length() * 1.55, 780.0)
						var aim_dir: Vector2 = (target_mob["pos"] - l["pos"]).normalized() if target_mob != null else -l["vel"].normalized()
						l["vel"] = aim_dir * l["speed"]
						l["color"] = Color("38ffff")
						screen_shake = 7.0
						_play_sfx(680.0, 1480.0, 0.16, 0)
						_spawn_burst(l["pos"], Color("73eff7"), 18, 260.0)
						_add_floating_text("TEAMMATE PARRY!", c_pos + Vector2(0, -34), Color("73eff7"))
						break
		"host_world_sync":
			if not is_host:
				current_wave = data.get("wave", current_wave)
				boss_warning_timer = data.get("boss_warning", boss_warning_timer)
				var m_list: Array = data.get("mobs", [])
				mobs.clear()
				for m_item in m_list:
					var is_boss: bool = m_item.get("is_boss", false)
					var m_dict := {
						"pos": Vector2(m_item.get("pos_x", 0.0), m_item.get("pos_y", 0.0)),
						"type": int(m_item.get("type", 0)),
						"hp": int(m_item.get("hp", 1)),
						"max_hp": int(m_item.get("max_hp", 20 if is_boss else 1)),
						"is_boss": is_boss,
						"radius": 52.0 if is_boss else 20.0,
						"charge_glow": float(m_item.get("glow", 0.0)),
						"hit_flash": 0.15 if m_item.get("flash", false) else 0.0,
						"anim": float(m_item.get("anim", 0.0)),
						"name": "THE APEX ANOMALY" if is_boss else ""
					}
					mobs.append(m_dict)
				var mobs_left_val: int = data.get("mobs_left", mobs.size())
				mobs_to_spawn = max(0, mobs_left_val - mobs.size())

				var l_list: Array = data.get("lasers", [])
				lasers.clear()
				for l_item in l_list:
					lasers.append({
						"pos": Vector2(l_item.get("pos_x", 0.0), l_item.get("pos_y", 0.0)),
						"vel": Vector2(l_item.get("vel_x", 0.0), l_item.get("vel_y", 0.0)),
						"speed": 600.0,
						"bounced": l_item.get("bounced", false),
						"owner": null,
						"homing_target": null,
						"color": Color("38ffff") if l_item.get("bounced", false) else Color("ff3b5b"),
						"trail": []
					})
		"player2_hit":
			if not is_host:
				_damage_player()
		"player_down":
			player2["is_down"] = true
			player2["hearts"] = 0
			_add_floating_text("FRIEND DOWNED! REVIVE THEM!", player2["pos"] - Vector2(0, 48), Color("ff3b5b"))
			if player.get("is_down", false):
				state = State.GAME_OVER
				_play_sfx(140.0, 50.0, 0.55, 1)
		"revived":
			var p_id: int = data.get("player_id", 1)
			if (p_id == 1 and not is_host) or (p_id == 2 and is_host):
				player["is_down"] = false
				player["hearts"] = 2
				_play_heal_sfx()
				_spawn_burst(player["pos"], Color("55ff99"), 24, 200.0)
				_add_floating_text("REVIVED BY FRIEND!", player["pos"] - Vector2(0, 48), Color("55ff99"))
			else:
				player2["is_down"] = false
				player2["hearts"] = 2
				_play_heal_sfx()
				_spawn_burst(player2["pos"], Color("55ff99"), 24, 200.0)
				_add_floating_text("TEAMMATE REVIVED!", player2["pos"] - Vector2(0, 48), Color("55ff99"))
		"game_over":
			state = State.GAME_OVER
			_play_sfx(140.0, 50.0, 0.55, 1)
		"restart_game":
			_begin_game_from_wave_1()
		"client_request_restart":
			if is_host and state == State.GAME_OVER:
				_send_game_message({"action": "restart_game"})
				_begin_game_from_wave_1()

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
			elif characters_open:
				if mpos.distance_to(close_char_center) <= CLOSE_BTN_RADIUS + 6.0:
					characters_open = false
					_play_sfx(520.0, 260.0, 0.1, 0)
				else:
					for idx in range(3):
						if char_tab_rects[idx].has_point(mpos):
							viewing_character = idx as Character
							btn_vel["tab_%d" % idx] = 5.0
							_play_sfx(540.0, 780.0, 0.12, 0)
							break
					if char_activate_btn_rect.has_point(mpos):
						selected_character = viewing_character
						btn_vel["char_activate"] = 6.0
						_play_sfx(540.0, 960.0, 0.18, 0)
						_spawn_burst(char_activate_btn_rect.get_center(), Color("41f3ff"), 24, 200.0)
			elif online_lobby_open:
				if mpos.distance_to(close_online_center) <= CLOSE_BTN_RADIUS + 6.0:
					online_lobby_open = false
					editing_server_url = false
					_play_sfx(520.0, 260.0, 0.1, 0)
				elif host_create_btn_rect.has_point(mpos):
					_play_sfx(540.0, 880.0, 0.15, 0)
					_create_online_room()
				elif host_start_btn_rect.has_point(mpos) and peer_is_ready:
					_play_sfx(440.0, 880.0, 0.18, 0)
					_host_start_coop_game()
				elif join_enter_btn_rect.has_point(mpos) and join_code_input.length() == 4:
					_play_sfx(540.0, 880.0, 0.15, 0)
					_join_online_room()
				elif server_url_bar_rect.has_point(mpos):
					editing_server_url = not editing_server_url
					_play_sfx(600.0, 720.0, 0.08, 0)
			else:
				if start_btn_rect.has_point(mpos):
					is_multiplayer = false
					player2["active"] = false
					_play_sfx(440.0, 880.0, 0.18, 0)
					_begin_game_from_wave_1()
				elif online_btn_rect.has_point(mpos):
					online_lobby_open = true
					btn_vel["online"] = 6.5
					_play_sfx(440.0, 880.0, 0.14, 0)
					_connect_to_signaling()
				elif characters_btn_rect.has_point(mpos):
					characters_open = true
					viewing_character = selected_character
					btn_vel["characters"] = 6.5
					_play_sfx(440.0, 720.0, 0.14, 0)
				elif credits_btn_rect.has_point(mpos):
					credits_open = true
					btn_vel["credits"] = 6.5
					_play_sfx(380.0, 620.0, 0.14, 0)
		elif state == State.GAME_OVER:
			if retry_btn_rect.has_point(mpos):
				_play_sfx(440.0, 880.0, 0.18, 0)
				if is_multiplayer and is_host:
					_send_game_message({"action": "restart_game"})
					_begin_game_from_wave_1()
				elif is_multiplayer and not is_host:
					_send_game_message({"action": "client_request_restart"})
					_add_floating_text("WAITING FOR HOST TO RESTART...", Vector2(VIEW_W * 0.5, 300), Color("ffe762"))
				else:
					_begin_game_from_wave_1()
			elif game_over_menu_btn_rect.has_point(mpos):
				state = State.MENU
				credits_open = false
				characters_open = false
				online_lobby_open = false
				is_multiplayer = false
				player2["active"] = false
				_play_sfx(520.0, 320.0, 0.14, 0)

	if event is InputEventKey and event.pressed and not event.echo:
		if state == State.MENU and online_lobby_open:
			if editing_server_url:
				if (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_V:
					var clip := DisplayServer.clipboard_get().strip_edges()
					if clip.length() > 0:
						signaling_server_url = _clean_url(clip)
						_play_sfx(540.0, 720.0, 0.08, 0)
				elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
					editing_server_url = false
					signaling_server_url = _clean_url(signaling_server_url)
					_connect_to_signaling()
				elif event.keycode == KEY_ESCAPE:
					editing_server_url = false
				elif event.keycode == KEY_BACKSPACE:
					if signaling_server_url.length() > 0:
						signaling_server_url = signaling_server_url.substr(0, signaling_server_url.length() - 1)
				elif event.unicode > 31 and event.unicode < 127:
					signaling_server_url += char(event.unicode)
			else:
				if event.keycode >= KEY_A and event.keycode <= KEY_Z:
					var char_str := OS.get_keycode_string(event.keycode).to_upper()
					if join_code_input.length() < 4:
						join_code_input += char_str
						_play_sfx(620.0, 780.0, 0.05, 0)
				elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
					var char_str := OS.get_keycode_string(event.keycode)
					if join_code_input.length() < 4:
						join_code_input += char_str
						_play_sfx(620.0, 780.0, 0.05, 0)
				elif event.keycode == KEY_BACKSPACE:
					if join_code_input.length() > 0:
						join_code_input = join_code_input.substr(0, join_code_input.length() - 1)
						_play_sfx(440.0, 320.0, 0.05, 0)
				elif event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
					if join_code_input.length() == 4:
						_join_online_room()
				elif event.keycode == KEY_ESCAPE:
					online_lobby_open = false
					_play_sfx(520.0, 260.0, 0.1, 0)
		elif state == State.MENU and characters_open:
			if event.keycode in [KEY_LEFT, KEY_A]:
				viewing_character = (int(viewing_character) + 2) % 3 as Character
				_play_sfx(540.0, 780.0, 0.1, 0)
			elif event.keycode in [KEY_RIGHT, KEY_D]:
				viewing_character = (int(viewing_character) + 1) % 3 as Character
				_play_sfx(540.0, 780.0, 0.1, 0)
			elif event.keycode in [KEY_ENTER, KEY_SPACE]:
				selected_character = viewing_character
				btn_vel["char_activate"] = 6.0
				_play_sfx(540.0, 960.0, 0.18, 0)
				_spawn_burst(char_activate_btn_rect.get_center(), Color("41f3ff"), 24, 200.0)
			elif event.keycode == KEY_ESCAPE:
				characters_open = false
				_play_sfx(520.0, 260.0, 0.1, 0)
		elif state == State.PLAYING:
			if not player.get("is_down", false):
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
				# Dash in facing direction or moving direction
				var h_dir := 0.0
				if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
					h_dir -= 1.0
				if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
					h_dir += 1.0
				bandit_dash_dir = h_dir if h_dir != 0.0 else float(player["facing"])
				player["facing"] = int(sign(bandit_dash_dir)) if bandit_dash_dir != 0.0 else player["facing"]
				# Hitbox negation during dash!
				player["invuln_timer"] = maxf(player["invuln_timer"], BANDIT_DASH_DUR + 0.08)
				_play_woosh_sfx()
				screen_shake = 4.0
				_add_floating_text("SHADOW DASH!", player["pos"] - Vector2(0, 48), Color("38ffff"))
				# Spawn initial wind gust
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
			# Nurse is passive, but notify user if pressed
			_add_floating_text("PASSIVE REGEN ACTIVE!", player["pos"] - Vector2(0, 48), Color("64ff88"))

func _begin_game_from_wave_1() -> void:
	current_wave = 1
	player["hearts"] = player["max_hearts"]
	player["pos"] = Vector2(VIEW_W * 0.4 if is_multiplayer else VIEW_W * 0.5, GROUND_Y)
	player["vel"] = Vector2.ZERO
	player["parry_active_timer"] = 0.0
	player["parry_cooldown_timer"] = 0.0
	player["invuln_timer"] = 0.0
	player["is_down"] = false
	if is_multiplayer:
		player2["pos"] = Vector2(VIEW_W * 0.6, GROUND_Y)
		player2["vel"] = Vector2.ZERO
		player2["hearts"] = player2["max_hearts"]
		player2["is_down"] = false
		player2["parry_flash"] = 0.0
	bandit_dash_cooldown = 0.0
	bandit_dashing = false
	scientist_freeze_cooldown = 0.0
	time_freeze_timer = 0.0
	nurse_regen_timer = NURSE_REGEN_INTERVAL
	revive_timer = 0.0
	p2_reviving_progress = 0.0
	dash_ghosts.clear()
	wind_particles.clear()
	mobs.clear()
	lasers.clear()
	particles.clear()
	floating_texts.clear()
	_start_wave_transition(1, 0.0)

func _start_wave_transition(wave_num: int, initial_pause: float) -> void:
	state = State.TRANSITION
	# Wave text requirement: exactly "wave n" with no dots!
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

	# WAVE 5: EXTREME BOSS FIGHT (ONE BIG MOB, 20 LASER HITS)
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
			"dodge_chance": 0.25,
			"dodge_strength": 340.0,
			"dodge_cooldown": 0.0,
			"charge_glow": 0.0,
			"attack_pattern": 0,
			"enraged": false,
			"burst_count": 0,
			"laser_speed": 660.0
		}
		mobs.append(boss)
		screen_shake = 24.0
		boss_warning_timer = 3.8
		_play_sfx(140.0, 60.0, 0.85, 1)
		_add_floating_text("EXTREME BOSS INCOMING!", Vector2(VIEW_W * 0.5, 120.0), Color("ff2a4b"))
	else:
		mobs_to_spawn = 3 + wave_num * 2
		spawn_timer = 0.45

# ==============================================================================
# MAIN LOOP (60 FPS Fluid Physics & Updates)
# ==============================================================================
func _physics_process(delta: float) -> void:
	_fill_audio_buffers()
	_update_dynamic_scenery(delta)
	_update_menu_buttons(delta)
	_update_networking(delta)
	screen_shake = maxf(0.0, screen_shake - delta * 28.0)
	grief_pulse_flash = maxf(0.0, grief_pulse_flash - delta * 1.8)

	if boss_warning_timer > 0.0:
		boss_warning_timer = maxf(0.0, boss_warning_timer - delta)
		if fmod(boss_warning_timer, 0.65) < delta and boss_warning_timer > 0.4:
			_play_sfx(440.0, 180.0, 0.22, 1)
			screen_shake = maxf(screen_shake, 12.0)
			_spawn_burst(Vector2(randf_range(200.0, VIEW_W - 200.0), 38.0), Color("ff2a4b"), 8, 200.0)
			_spawn_burst(Vector2(randf_range(200.0, VIEW_W - 200.0), VIEW_H - 38.0), Color("ff2a4b"), 8, 200.0)

	match state:
		State.MENU:
			pass
		State.TRANSITION:
			_update_transition(delta)
		State.PLAYING:
			_update_playing_state(delta)
		State.GAME_OVER:
			_update_particles_and_text(delta)

	queue_redraw()

func _update_playing_state(delta: float) -> void:
	# Ability cooldowns countdown
	bandit_dash_cooldown = maxf(0.0, bandit_dash_cooldown - delta)
	scientist_freeze_cooldown = maxf(0.0, scientist_freeze_cooldown - delta)

	# Scientist Time Freeze logic: freezes both enemies and lasers for 1 second!
	if time_freeze_timer > 0.0:
		time_freeze_timer = maxf(0.0, time_freeze_timer - delta)
		# Only update player, wind particles, and texts; freeze mobs and lasers in mid-air
		_update_player(delta)
		_update_particles_and_text(delta)
		return

	# Regular unfreezed updates
	_update_player(delta)
	if is_multiplayer and player2["active"]:
		player2["pos"] = player2["pos"].lerp(player2.get("target_pos", player2["pos"]), minf(1.0, 18.0 * delta))
	if not is_multiplayer or is_host:
		_update_wave_spawner(delta)
		_update_mobs(delta)
	else:
		# Client-side smooth mob visuals & wing animations
		for m in mobs:
			m["anim"] = m.get("anim", 0.0) + delta * 3.0
			if m.get("hit_flash", 0.0) > 0.0:
				m["hit_flash"] = maxf(0.0, m["hit_flash"] - delta)
	_update_lasers(delta)
	_update_particles_and_text(delta)

func _update_dynamic_scenery(delta: float) -> void:
	# Clouds drift
	for c in clouds:
		c["pos"].x += c["speed"] * delta
		if c["pos"].x > VIEW_W + 140.0:
			c["pos"].x = -140.0

	# Fireflies
	for f in fireflies:
		f["phase"] += delta * 2.5
		f["pos"].x += cos(f["phase"]) * f["speed"] * delta
		f["pos"].y += sin(f["phase"] * 1.3) * (f["speed"] * 0.6) * delta

	# Grief Embers (Rise upward with turbulence like hot ash in Grief map)
	for em in grief_embers:
		em["pos"] += em["vel"] * delta
		em["pos"].x += sin(em["pos"].y * 0.02) * 18.0 * delta
		if em["pos"].y < -20.0 or em["pos"].x < -20.0 or em["pos"].x > VIEW_W + 20.0:
			em["pos"].y = GROUND_Y + randf_range(0.0, 40.0)
			em["pos"].x = randf_range(0.0, VIEW_W)
			em["vel"] = Vector2(randf_range(-25, 25), randf_range(-65, -130))

	# Grief vertical laser columns pulse
	for col in grief_laser_columns:
		col["phase"] += col["speed"] * delta

	# Grief mountain demon eyes blink
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
	var in_menu_or_over := (state in [State.MENU, State.GAME_OVER])
	var modals_closed := not credits_open and not characters_open and not online_lobby_open

	var hover_start := in_menu_or_over and modals_closed and (start_btn_rect.has_point(mpos) if state == State.MENU else retry_btn_rect.has_point(mpos))
	var hover_online := (state == State.MENU) and modals_closed and online_btn_rect.has_point(mpos)
	var hover_chars := (state == State.MENU) and modals_closed and characters_btn_rect.has_point(mpos)
	var hover_credits := in_menu_or_over and modals_closed and (credits_btn_rect.has_point(mpos) if state == State.MENU else game_over_menu_btn_rect.has_point(mpos))
	var hover_close := (state == State.MENU) and credits_open and (mpos.distance_to(close_credits_center) <= CLOSE_BTN_RADIUS + 4.0)
	var hover_char_close := (state == State.MENU) and characters_open and (mpos.distance_to(close_char_center) <= CLOSE_BTN_RADIUS + 4.0)
	var hover_online_close := (state == State.MENU) and online_lobby_open and (mpos.distance_to(close_online_center) <= CLOSE_BTN_RADIUS + 4.0)

	_apply_spring_button("start", hover_start, delta)
	_apply_spring_button("online", hover_online, delta)
	_apply_spring_button("characters", hover_chars, delta)
	_apply_spring_button("credits", hover_credits, delta)
	_apply_spring_button("close", hover_close, delta)
	_apply_spring_button("char_close", hover_char_close, delta)
	_apply_spring_button("online_close", hover_online_close, delta)

	# Online lobby buttons
	if state == State.MENU and online_lobby_open:
		var hover_create := host_create_btn_rect.has_point(mpos)
		var hover_host_start := host_start_btn_rect.has_point(mpos) and peer_is_ready
		var hover_join := join_enter_btn_rect.has_point(mpos) and join_code_input.length() == 4
		var hover_server := server_url_bar_rect.has_point(mpos)
		_apply_spring_button("host_create", hover_create, delta)
		_apply_spring_button("host_start", hover_host_start, delta)
		_apply_spring_button("join_btn", hover_join, delta)
		_apply_spring_button("edit_server", hover_server, delta)

	# Character selection tabs and activate button spring animations
	if state == State.MENU and characters_open:
		for idx in range(3):
			var hover_tab: bool = char_tab_rects[idx].has_point(mpos)
			_apply_spring_button("tab_%d" % idx, hover_tab, delta)
		var hover_act: bool = char_activate_btn_rect.has_point(mpos)
		_apply_spring_button("char_activate", hover_act, delta)

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
	if is_multiplayer:
		_send_game_message({"action": "player_parry"})
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
				# AIMBOT REQUIREMENT: Lock onto the mob that threw the laser!
				var target_mob = l["owner"]
				if target_mob == null or not mobs.has(target_mob):
					target_mob = _get_nearest_mob(l["pos"])
				l["homing_target"] = target_mob
				l["speed"] = maxf(l["vel"].length() * 1.55, 780.0)

				var aim_dir: Vector2 = -l["vel"].normalized()
				if target_mob != null:
					aim_dir = (target_mob["pos"] - l["pos"]).normalized()
				l["vel"] = aim_dir * l["speed"]
				l["color"] = Color("38ffff")

				# Reset parry cooldown on perfect parry for fluid chains!
				player["parry_cooldown_timer"] = 0.05
				screen_shake = 7.0
				_play_sfx(680.0, 1480.0, 0.16, 0)
				_spawn_burst(l["pos"], Color("73eff7"), 18, 260.0)
				_add_floating_text("PERFECT PARRY!", p_center + Vector2(0, -34), Color("73eff7"))
				if is_multiplayer and not is_host:
					_send_game_message({"action": "client_deflect", "pos_x": p_center.x, "pos_y": p_center.y})

func _update_player(delta: float) -> void:
	player["parry_active_timer"] = maxf(0.0, player["parry_active_timer"] - delta)
	player["parry_cooldown_timer"] = maxf(0.0, player["parry_cooldown_timer"] - delta)
	player["invuln_timer"] = maxf(0.0, player["invuln_timer"] - delta)
	player["parry_flash"] = maxf(0.0, player["parry_flash"] - delta)
	player["parry_fail_flash"] = maxf(0.0, player["parry_fail_flash"] - delta)

	# Nurse Passive Ability: Regenerates 1 heart every 8 seconds automatically
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

	# Bandit Dash execution
	if bandit_dashing:
		bandit_dash_timer -= delta
		player["vel"].y = 0.0
		player["pos"].x += bandit_dash_dir * BANDIT_DASH_SPEED * delta
		player["invuln_timer"] = maxf(player["invuln_timer"], 0.1) # Hitbox negation while dashing!

		# Spawn wind trails and ghost afterimages
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
		if not player.get("is_down", false):
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				dir -= 1.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				dir += 1.0
		else:
			# Downed crawl
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				dir -= 0.35
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				dir += 0.35

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

		# One-way platform collisions
		if player["vel"].y >= 0.0:
			for plat in platforms:
				var within_x: bool = (player["pos"].x + player["w"] * 0.45 >= plat.position.x) and (player["pos"].x - player["w"] * 0.45 <= plat.position.x + plat.size.x)
				if within_x and prev_y <= plat.position.y + 4.0 and player["pos"].y >= plat.position.y:
					player["pos"].y = plat.position.y
					player["vel"].y = 0.0
					player["on_ground"] = true
					break

		# Ground collision
		if player["pos"].y >= GROUND_Y:
			player["pos"].y = GROUND_Y
			player["vel"].y = 0.0
			player["on_ground"] = true

	player["pos"].x = clampf(player["pos"].x, 28.0, VIEW_W - 28.0)

	# Co-op Revive Mechanic
	if is_multiplayer:
		# If local player is downed:
		if player.get("is_down", false) and player2["active"] and not player2.get("is_down", false):
			if player["pos"].distance_to(player2["pos"]) <= 75.0:
				revive_timer += delta
				if revive_timer >= 2.0:
					player["is_down"] = false
					player["hearts"] = 2
					revive_timer = 0.0
					_send_game_message({"action": "revived", "player_id": 1 if is_host else 2})
					_play_heal_sfx()
					_spawn_burst(player["pos"], Color("55ff99"), 24, 200.0)
					_add_floating_text("REVIVED BY TEAMMATE!", player["pos"] - Vector2(0, 48), Color("55ff99"))
			else:
				revive_timer = maxf(0.0, revive_timer - delta * 0.5)

		# If teammate is downed and local player is standing close:
		if not player.get("is_down", false) and player2["active"] and player2.get("is_down", false):
			if player["pos"].distance_to(player2["pos"]) <= 75.0:
				p2_reviving_progress += delta
				if p2_reviving_progress >= 2.0:
					player2["is_down"] = false
					player2["hearts"] = 2
					p2_reviving_progress = 0.0
					_send_game_message({"action": "revived", "player_id": 2 if is_host else 1})
					_play_heal_sfx()
					_spawn_burst(player2["pos"], Color("55ff99"), 24, 200.0)
					_add_floating_text("YOU REVIVED TEAMMATE!", player2["pos"] - Vector2(0, 48), Color("55ff99"))
			else:
				p2_reviving_progress = maxf(0.0, p2_reviving_progress - delta * 0.8)

	# Update dash ghosts
	for i in range(dash_ghosts.size() - 1, -1, -1):
		dash_ghosts[i]["alpha"] -= delta * 3.5
		if dash_ghosts[i]["alpha"] <= 0.0:
			dash_ghosts.remove_at(i)

	# Check active parry frames against incoming lasers
	if player["parry_active_timer"] > 0.0:
		_check_parry_deflection()

# ==============================================================================
# FLYING MOBS, SMART DODGING AI & WAVE 5 EXTREME BOSS
# ==============================================================================
func _update_wave_spawner(delta: float) -> void:
	if mobs_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_mob()
			mobs_to_spawn -= 1
			spawn_timer = maxf(0.32, 1.15 - current_wave * 0.07)
	elif mobs.is_empty() and state == State.PLAYING:
		# Wave Cleared!
		current_wave += 1
		_play_sfx(392.0, 784.0, 0.35, 0)
		_add_floating_text("WAVE CLEARED!", player["pos"] - Vector2(0, 60), Color("ffe762"))
		_start_wave_transition(current_wave, 0.95)

func _spawn_mob() -> void:
	var max_archetype: int = mini(3, (current_wave - 1) / 1)
	var mob_type: int = randi_range(0, max_archetype)

	var spawn_x: float = randf_range(80.0, VIEW_W - 80.0)
	var spawn_y: float = -40.0
	if randf() < 0.4:
		spawn_x = -40.0 if randf() < 0.5 else VIEW_W + 40.0
		spawn_y = randf_range(70.0, 260.0)

	var base_fire_cd: float = maxf(0.85, 2.55 - current_wave * 0.14)
	var laser_spd: float = minf(760.0, 350.0 + current_wave * 26.0)
	var dodge_chance: float = clampf((current_wave - 1) * 0.16, 0.0, 0.82)
	var dodge_strength: float = 210.0 + current_wave * 28.0

	mobs.append({
		"is_boss": false,
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

		if m.get("is_boss", false):
			_update_boss_ai(m, p_center, delta)
			continue

		# Regular mob AI
		if m["retarget_timer"] <= 0.0 or m["pos"].distance_to(m["target_pos"]) < 36.0:
			m["target_pos"] = Vector2(randf_range(100.0, VIEW_W - 100.0), randf_range(65.0, 310.0))
			m["retarget_timer"] = randf_range(1.4, 2.8)

		var desired_vel: Vector2 = (m["target_pos"] - m["pos"]).normalized() * (115.0 + current_wave * 8.0)
		desired_vel.y += sin(m["anim"]) * 35.0

		# Smart dodging for regular mobs
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
								m["dodge_cooldown"] = maxf(0.48, 1.15 - current_wave * 0.06)
								_spawn_burst(m["pos"], Color("ffee83"), 6, 95.0)
								_add_floating_text("DODGE!", m["pos"] + Vector2(0, -26), Color("ffee83"))
							else:
								m["dodge_cooldown"] = 0.35
							break

		m["vel"] = m["vel"].lerp(desired_vel, 4.5 * delta)
		m["pos"] += m["vel"] * delta
		m["pos"].x = clampf(m["pos"].x, 55.0, VIEW_W - 55.0)
		m["pos"].y = clampf(m["pos"].y, 50.0, 360.0)

		# Shooting
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
			_play_sfx(780.0, 310.0, 0.11, 0)

# ==============================================================================
# WAVE 5 EXTREME BOSS AI & MECHANICS
# ==============================================================================
func _update_boss_ai(boss: Dictionary, p_center: Vector2, delta: float) -> void:
	boss["hit_flash"] = maxf(0.0, boss["hit_flash"] - delta)
	boss["enraged"] = (boss["hp"] <= 10)

	var move_spd: float = 240.0 if not boss["enraged"] else 340.0
	if boss["hp"] <= 5:
		move_spd = 400.0 # Berserk speed

	if boss["retarget_timer"] <= 0.0 or boss["pos"].distance_to(boss["target_pos"]) < 45.0:
		# Dynamic boss swooping coordinates
		var min_y: float = 80.0
		var max_y: float = 290.0 if not boss["enraged"] else 380.0
		boss["target_pos"] = Vector2(randf_range(160.0, VIEW_W - 160.0), randf_range(min_y, max_y))
		boss["retarget_timer"] = randf_range(1.0, 2.2) if not boss["enraged"] else randf_range(0.6, 1.4)

	var desired_vel: Vector2 = (boss["target_pos"] - boss["pos"]).normalized() * move_spd
	desired_vel.y += sin(boss["anim"] * 1.5) * 45.0
	boss["vel"] = boss["vel"].lerp(desired_vel, 6.0 * delta)
	boss["pos"] += boss["vel"] * delta
	boss["pos"].x = clampf(boss["pos"].x, 80.0, VIEW_W - 80.0)
	boss["pos"].y = clampf(boss["pos"].y, 65.0, 420.0)

	# Boss laser firing patterns
	boss["shoot_timer"] -= delta
	var charge_window: float = 0.35 if not boss["enraged"] else 0.24
	boss["charge_glow"] = clampf(1.0 - (boss["shoot_timer"] / charge_window), 0.0, 1.0) if boss["shoot_timer"] < charge_window else 0.0

	if boss["shoot_timer"] <= 0.0:
		var cd: float = 0.75 if not boss["enraged"] else 0.48
		if boss["hp"] <= 5:
			cd = 0.38
		boss["shoot_timer"] = cd
		boss["attack_pattern"] = (boss["attack_pattern"] + 1) % 3

		var base_aim: Vector2 = (p_center - boss["pos"]).normalized()
		var spd: float = boss["laser_speed"] if not boss["enraged"] else (boss["laser_speed"] + 60.0)

		if boss["attack_pattern"] == 0:
			# Twin heavy aimed lasers
			var perp := Vector2(-base_aim.y, base_aim.x) * 22.0
			_spawn_boss_laser(boss, boss["pos"] + perp, base_aim, spd, Color("ff2a55"))
			_spawn_boss_laser(boss, boss["pos"] - perp, base_aim, spd, Color("ff2a55"))
			_play_sfx(620.0, 240.0, 0.16, 0)
		elif boss["attack_pattern"] == 1:
			# Triple spread barrage
			for ang in [-0.26, 0.0, 0.26]:
				var dir := base_aim.rotated(ang)
				_spawn_boss_laser(boss, boss["pos"], dir, spd * 0.95, Color("ff7e2a"))
			_play_sfx(720.0, 260.0, 0.18, 0)
		else:
			# Quad / Rapid crossfire when enraged
			if boss["enraged"]:
				for ang in [-0.38, -0.12, 0.12, 0.38]:
					var dir := base_aim.rotated(ang)
					_spawn_boss_laser(boss, boss["pos"], dir, spd * 1.08, Color("ff22ff"))
				screen_shake = 5.0
			else:
				_spawn_boss_laser(boss, boss["pos"], base_aim, spd * 1.15, Color("ff2a55"))
			_play_sfx(880.0, 210.0, 0.15, 0)

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
	screen_shake = 13.0
	_play_sfx(220.0, 60.0, 0.32, 1)
	_spawn_burst(boss["pos"], Color("ff2a55"), 28, 280.0)
	_spawn_burst(boss["pos"], Color("41f3ff"), 18, 220.0)
	_add_floating_text("BOSS HIT! [%d/20]" % boss["hp"], boss["pos"] + Vector2(0, -60), Color("ff5555"))

	if laser_idx >= 0 and laser_idx < lasers.size():
		lasers.remove_at(laser_idx)

	if boss["hp"] <= 0:
		# Boss Annihilated!
		screen_shake = 26.0
		_play_sfx(140.0, 40.0, 0.85, 1)
		_spawn_burst(boss["pos"], Color("ffe762"), 70, 360.0)
		_spawn_burst(boss["pos"], Color("ff2a4b"), 60, 320.0)
		_spawn_burst(boss["pos"], Color("41f3ff"), 60, 320.0)
		_add_floating_text("EXTREME BOSS DEFEATED!", Vector2(VIEW_W * 0.5, 200), Color("ffe762"))
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
# LASERS & AIMBOT TRACKING COLLISIONS
# ==============================================================================
func _update_lasers(delta: float) -> void:
	var p_center: Vector2 = player["pos"] - Vector2(0, player["h"] * 0.5)

	for i in range(lasers.size() - 1, -1, -1):
		var l = lasers[i]
		l["trail"].append(l["pos"])
		if l["trail"].size() > 8:
			l["trail"].pop_front()

		# AIMBOT HOMING LOGIC: If laser was parried, it aggressively curves directly to its target!
		if l["bounced"] and l["homing_target"] != null and mobs.has(l["homing_target"]):
			var target_mob = l["homing_target"]
			var to_target: Vector2 = target_mob["pos"] - l["pos"]
			if to_target.length_squared() > 16.0:
				var desired_dir: Vector2 = to_target.normalized()
				var cur_speed: float = l["speed"]
				var cur_dir: Vector2 = l["vel"].normalized()
				# High-authority aimbot steering
				var new_dir: Vector2 = cur_dir.lerp(desired_dir, 16.0 * delta).normalized()
				l["vel"] = new_dir * cur_speed

		l["pos"] += l["vel"] * delta

		# Remove offscreen
		if l["pos"].x < -90.0 or l["pos"].x > VIEW_W + 90.0 or l["pos"].y < -90.0 or l["pos"].y > VIEW_H + 90.0:
			lasers.remove_at(i)
			continue

		if not l["bounced"]:
			# Deflection window check
			if player["parry_active_timer"] > 0.0 and l["pos"].distance_to(p_center) <= PARRY_RADIUS:
				_check_parry_deflection()
				continue

			# Hitbox collision with player body
			var p_rect: Rect2 = Rect2(player["pos"].x - player["w"] * 0.45, player["pos"].y - player["h"], player["w"] * 0.9, player["h"])
			if p_rect.grow(3.0).has_point(l["pos"]):
				if bandit_dashing or player["invuln_timer"] > 0.0 or player.get("is_down", false):
					_spawn_burst(l["pos"], Color("38ffff"), 4, 80.0)
					continue
				lasers.remove_at(i)
				_damage_player()
				continue

			# Hitbox collision with player 2 in multiplayer (computed by host)
			if is_multiplayer and is_host and player2["active"] and not player2.get("is_down", false):
				var p2_rect: Rect2 = Rect2(player2["pos"].x - player["w"] * 0.45, player2["pos"].y - player["h"], player["w"] * 0.9, player["h"])
				if p2_rect.grow(3.0).has_point(l["pos"]):
					lasers.remove_at(i)
					_send_game_message({"action": "player2_hit"})
					continue

			# Laser hits ground
			if l["pos"].y >= GROUND_Y:
				_spawn_burst(l["pos"], l["color"], 7, 90.0)
				lasers.remove_at(i)
				continue
		else:
			# Bounced / Aimbot laser: check collision against living mobs
			var hit_any := false
			for j in range(mobs.size() - 1, -1, -1):
				var m = mobs[j]
				if l["pos"].distance_to(m["pos"]) <= m["radius"] + 12.0:
					hit_any = true
					if m.get("is_boss", false):
						_damage_boss(m, i)
					else:
						_spawn_burst(m["pos"], Color("ff5555"), 24, 240.0)
						_spawn_burst(m["pos"], Color("73eff7"), 14, 180.0)
						_add_floating_text("ELIMINATED!", m["pos"], Color("ffdd55"))
						_play_sfx(240.0, 75.0, 0.22, 1)
						screen_shake = 8.5
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
	screen_shake = 11.0
	_play_sfx(180.0, 65.0, 0.26, 1)
	_spawn_burst(player["pos"] - Vector2(0, 18), Color("ff2a4b"), 22, 220.0)
	_add_floating_text("-1 HEART!", player["pos"] - Vector2(0, 46), Color("ff4b6b"))

	if player["hearts"] <= 0:
		if is_multiplayer:
			player["is_down"] = true
			player["hearts"] = 0
			_add_floating_text("DOWNED! NEED REVIVE!", player["pos"] - Vector2(0, 46), Color("ff2a4b"))
			_send_game_message({"action": "player_down", "player_id": 1 if is_host else 2})
			if player2.get("is_down", false):
				state = State.GAME_OVER
				_play_sfx(140.0, 50.0, 0.55, 1)
				_send_game_message({"action": "game_over"})
		else:
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
# CUSTOM RENDERING (Terraria + Grief Tryhard Map, Characters, Mobs, UI)
# ==============================================================================
func _draw() -> void:
	var shake_offset := Vector2.ZERO
	if screen_shake > 0.0:
		shake_offset = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake))

	draw_set_transform(shake_offset, 0.0, Vector2.ONE)

	_draw_dynamic_grief_background()
	_draw_platforms_and_ground()

	if state in [State.PLAYING, State.TRANSITION, State.GAME_OVER]:
		_draw_dash_ghosts()
		_draw_player()
		if is_multiplayer and player2["active"]:
			_draw_remote_player()
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

	if boss_warning_timer > 0.0:
		_draw_boss_warning(boss_warning_timer)

# --- Dynamic Background: Geometry Dash Grief Map Atmosphere + Terraria Underworld ---
func _draw_dynamic_grief_background() -> void:
	# Sky gradient: Dark obsidian abyss with rhythmic crimson beat pulse
	var pulse_r: float = grief_pulse_flash * 0.45
	var sky_top := Color(0.04 + pulse_r, 0.02, 0.06)
	var sky_mid := Color(0.12 + pulse_r * 1.2, 0.03, 0.07)
	var sky_bot := Color(0.20 + pulse_r * 1.5, 0.05, 0.10)

	# Wave 5: Sky intensifies into deep apocalyptic blood-red
	if current_wave == 5 and state == State.PLAYING:
		sky_top = Color(0.14 + pulse_r, 0.01, 0.03)
		sky_mid = Color(0.26 + pulse_r * 1.5, 0.03, 0.06)
		sky_bot = Color(0.40 + pulse_r * 2.0, 0.06, 0.10)

	draw_rect(Rect2(0, 0, VIEW_W, 240), sky_top)
	draw_rect(Rect2(0, 240, VIEW_W, 200), sky_mid)
	draw_rect(Rect2(0, 440, VIEW_W, VIEW_H - 440), sky_bot)

	# Geometry Dash Grief Vertical Laser Beams / Light Pillars in the background
	for col in grief_laser_columns:
		var col_x: float = col["x"]
		var w: float = col["width"] * (1.0 + 0.3 * sin(col["phase"]))
		var a: float = col["intensity"] + grief_pulse_flash * 0.35
		var beam_col := Color(1.0, 0.15, 0.25, clampf(a, 0.05, 0.65))
		draw_rect(Rect2(col_x - w * 0.5, 0, w, GROUND_Y), beam_col)
		# Intense inner white-hot core
		draw_rect(Rect2(col_x - w * 0.15, 0, w * 0.3, GROUND_Y), Color(1.0, 0.9, 0.95, clampf(a * 1.4, 0.08, 0.85)))

	# Jagged volcanic obsidian peaks
	var m1 := PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(0, 390), Vector2(180, 260), Vector2(390, 410),
		Vector2(620, 230), Vector2(880, 400), Vector2(1090, 275), Vector2(VIEW_W, 370), Vector2(VIEW_W, GROUND_Y)
	])
	draw_colored_polygon(m1, Color("140912"))

	# Rolling underworld brimstone hills with glowing magma veins
	var m2 := PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(0, 470), Vector2(240, 420), Vector2(510, 485),
		Vector2(790, 415), Vector2(1040, 470), Vector2(VIEW_W, 435), Vector2(VIEW_W, GROUND_Y)
	])
	draw_colored_polygon(m2, Color("200d18"))

	# Mountain magma fissures
	for i in range(5):
		var fx: float = 160.0 + i * 220.0
		var fy: float = 380.0 + sin(i) * 60.0
		draw_line(Vector2(fx, fy), Vector2(fx + 24, fy + 38), Color("ff3b3b", 0.6), 2.5)
		draw_line(Vector2(fx + 24, fy + 38), Vector2(fx + 46, fy + 72), Color("ff7e2a", 0.5), 2.0)

	# Hanging Grief Abyssal Chains & Spikes from ceiling
	for ch in grief_chains:
		var cx: float = ch["x"]
		var l: float = ch["len"]
		# Chain links
		for k in range(0, int(l), 10):
			draw_rect(Rect2(cx - 3, k, 6, 8), Color("2e1c25"))
			draw_rect(Rect2(cx - 1.5, k + 2, 3, 4), Color("4d313e"))
		# Sharp obsidian crystal spike at bottom of chain
		var cs: float = ch["crystal_size"]
		var tip := Vector2(cx, l + cs * 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - cs * 0.6, l),
			Vector2(cx + cs * 0.6, l),
			tip
		]), Color("180a14"))
		# Crystal neon core line
		draw_line(Vector2(cx, l + 2), tip - Vector2(0, 3), Color("ff2a4b", 0.75), 2.0)

	# Demon Eyes blinking in the dark abyss backdrop
	for eye in grief_eyes:
		if eye["open_amount"] > 0.05:
			var ep: Vector2 = eye["pos"]
			var oa: float = eye["open_amount"]
			draw_line(ep - Vector2(12, 0), ep + Vector2(12, 0), Color("4a0e1c", oa), 3.0)
			draw_circle(ep, 6.0 * oa, Color("ff2a4b", oa))
			draw_circle(ep, 2.5 * oa, Color("ffffff", oa))

	# Terraria-style giant twisted trees with crimson weeping leaves
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
		draw_circle(Vector2(tx - cr * 0.45, top_y + 12), cr * 0.62, leaf_dark)
		draw_circle(Vector2(tx + cr * 0.45, top_y + 12), cr * 0.62, leaf_dark)
		draw_circle(Vector2(tx, top_y - cr * 0.25), cr * 0.78, leaf_mid)
		draw_circle(Vector2(tx - cr * 0.22, top_y - cr * 0.38), cr * 0.48, leaf_bright)

	# Grief Floating Embers & Fire Sparks rising continuously
	for em in grief_embers:
		var ep: Vector2 = em["pos"]
		var col: Color = Color("ff3b3b") if em["hue"] < 0.65 else Color("ff9e2c")
		col.a = em["alpha"]
		draw_rect(Rect2(ep.x, ep.y, em["size"], em["size"]), col)

	# Fireflies
	for f in fireflies:
		var alpha: float = 0.35 + 0.45 * sin(f["phase"])
		draw_rect(Rect2(f["pos"].x, f["pos"].y, 4, 4), Color(1.0, 0.45, 0.65, alpha))

func _draw_platforms_and_ground() -> void:
	# One-way Wooden/Obsidian Platforms with Grief Neon Top Trim
	for plat in platforms:
		draw_rect(Rect2(plat.position.x + 6, plat.position.y + 6, plat.size.x - 12, plat.size.y), Color(0, 0, 0, 0.55))
		draw_rect(plat, Color("2d1a24"))
		# Grief Neon Runic Trim on top of platforms
		draw_rect(Rect2(plat.position.x, plat.position.y, plat.size.x, 4), Color("ff2a55"))
		draw_rect(Rect2(plat.position.x, plat.position.y + 4, plat.size.x, 3), Color("7a162b"))

		var num_joints := int(plat.size.x / 36.0)
		for k in range(1, num_joints):
			var jx: float = plat.position.x + k * 36.0
			draw_line(Vector2(jx, plat.position.y + 5), Vector2(jx, plat.position.y + plat.size.y), Color("1a0e15"), 2.0)
		draw_rect(plat, Color("140910"), false, 2.0)

	# Terraria Hellstone & Obsidian Dirt Floor
	draw_rect(Rect2(0, GROUND_Y, VIEW_W, VIEW_H - GROUND_Y), Color("2b161f"))
	for gx in range(0, int(VIEW_W), 32):
		for gy in range(int(GROUND_Y) + 16, int(VIEW_H), 28):
			draw_rect(Rect2(gx + 4, gy + 4, 24, 20), Color("200f16"))
			if (gx + gy) % 64 == 0:
				draw_rect(Rect2(gx + 10, gy + 8, 8, 8), Color("ff3b3b", 0.75)) # Embedded hellstone ember

	# Top ground neon brimstone rim
	draw_rect(Rect2(0, GROUND_Y, VIEW_W, 10), Color("ff2a4b"))
	draw_rect(Rect2(0, GROUND_Y + 10, VIEW_W, 5), Color("7a162b"))
	for g in grass_tufts:
		draw_line(Vector2(g["x"], GROUND_Y), Vector2(g["x"] + g["lean"], GROUND_Y - g["h"]), Color("ff5e7e"), 2.5)

# --- Player Drawing for Each Selected Character (Bandit, Scientist, Nurse) ---
func _draw_dash_ghosts() -> void:
	for g in dash_ghosts:
		var gp: Vector2 = g["pos"]
		var ga: float = g["alpha"]
		draw_rect(Rect2(gp.x - 7, gp.y - 36, 14, 34), Color(0.22, 0.95, 1.0, ga * 0.5))

func _draw_player() -> void:
	var p: Vector2 = player["pos"]
	var facing: int = player["facing"]
	var flash: bool = (player["invuln_timer"] > 0.0 and int(player["invuln_timer"] * 22.0) % 2 == 0)

	# Wind particles trailing behind Bandit
	for wp in wind_particles:
		var wa: float = wp["life"] / wp["max_life"]
		draw_rect(Rect2(wp["pos"].x, wp["pos"].y, wp["size"], wp["size"] * 0.6), Color(0.85, 0.98, 1.0, wa * 0.75))

	# Parry shield aura
	var p_center: Vector2 = p - Vector2(0, player["h"] * 0.5)
	if player["parry_active_timer"] > 0.0 or player["parry_flash"] > 0.0:
		var a: float = clampf(player["parry_flash"] * 5.0, 0.15, 0.9)
		draw_arc(p_center, PARRY_RADIUS * 0.75, 0.0, TAU, 36, Color(0.25, 0.95, 1.0, a), 4.0)
		draw_circle(p_center, PARRY_RADIUS * 0.65, Color(0.25, 0.95, 1.0, a * 0.25))
	elif player["parry_fail_flash"] > 0.0:
		draw_arc(p_center, 26.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.3, 0.8), 2.5)

	# Scientist Time Freeze Screen Warp Aura
	if time_freeze_timer > 0.0:
		draw_circle(p_center, 90.0 * (1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.1), Color(0.25, 0.85, 1.0, 0.14))
		draw_arc(p_center, 78.0, 0.0, TAU, 32, Color(0.4, 0.95, 1.0, 0.6), 2.5)

	if is_multiplayer and player.get("is_down", false):
		var font := ThemeDB.fallback_font
		draw_circle(p - Vector2(0, 10), 22.0, Color(0.12, 0.02, 0.05, 0.6))
		draw_arc(p - Vector2(0, 10), 32.0, 0.0, TAU, 28, Color("ff2a55", 0.8), 2.5)
		if revive_timer > 0.0:
			var ratio: float = clampf(revive_timer / 2.0, 0.0, 1.0)
			draw_arc(p - Vector2(0, 10), 38.0, -PI * 0.5, -PI * 0.5 + ratio * TAU, 36, Color("55ff99"), 4.0)
			draw_string(font, p + Vector2(-60, -56), "REVIVING... %.0f%%" % (ratio * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color("55ff99"))
		else:
			draw_string_outline(font, p + Vector2(-75, -50), "⚠ DOWNED! CALL TEAMMATE", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, 2, Color.BLACK)
			draw_string(font, p + Vector2(-75, -50), "⚠ DOWNED! CALL TEAMMATE", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, Color("ff3b5b"))

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

	if is_multiplayer and not player.get("is_down", false):
		var font := ThemeDB.fallback_font
		var p1_name: String = "P1 (YOU)"
		var tag_rect := Rect2(p.x - 36, p.y - 58, 72, 18)
		_draw_rounded_box(tag_rect, 5.0, Color("101626", 0.85), Color("41f3ff"), 1.0)
		draw_string(font, Vector2(tag_rect.position.x, tag_rect.position.y + 13), p1_name, HORIZONTAL_ALIGNMENT_CENTER, 72, 10, Color("41f3ff"))

func _draw_remote_player() -> void:
	var p2: Vector2 = player2["pos"]
	var facing: int = player2["facing"]
	var font := ThemeDB.fallback_font

	if player2["parry_flash"] > 0.0:
		var p2_center := p2 - Vector2(0, 18.0)
		draw_arc(p2_center, PARRY_RADIUS * 0.75, 0.0, TAU, 36, Color("73eff7", 0.7), 3.5)
		draw_circle(p2_center, PARRY_RADIUS * 0.55, Color("73eff7", 0.2))

	if player2.get("is_down", false):
		draw_circle(p2 - Vector2(0, 10), 22.0, Color(0.12, 0.02, 0.05, 0.6))
		draw_arc(p2 - Vector2(0, 10), 32.0, 0.0, TAU, 28, Color("ff2a55", 0.8), 2.5)

		if p2_reviving_progress > 0.0:
			var ratio: float = clampf(p2_reviving_progress / 2.0, 0.0, 1.0)
			draw_arc(p2 - Vector2(0, 10), 38.0, -PI * 0.5, -PI * 0.5 + ratio * TAU, 36, Color("55ff99"), 4.0)
			draw_string(font, p2 + Vector2(-60, -56), "REVIVING... %.0f%%" % (ratio * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color("55ff99"))
		else:
			draw_string_outline(font, p2 + Vector2(-75, -50), "⚠ DOWNED! STAND NEAR", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, 2, Color.BLACK)
			draw_string(font, p2 + Vector2(-75, -50), "⚠ DOWNED! STAND NEAR", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, Color("ff3b5b"))

		draw_set_transform(p2, 0.45 * facing, Vector2.ONE)
		_draw_bandit_sprite(Vector2.ZERO, facing, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	var leg_swing: float = sin(player2["walk_anim"]) * 5.0
	match int(player2["character"]):
		Character.BANDIT:
			_draw_bandit_sprite(p2, facing, leg_swing)
		Character.SCIENTIST:
			_draw_scientist_sprite(p2, facing, leg_swing)
		Character.NURSE:
			_draw_nurse_sprite(p2, facing, leg_swing)

	var p2_name: String = "P2 • " + _get_character_name(player2["character"])
	var tag_w: float = 88.0
	var tag_rect := Rect2(p2.x - tag_w * 0.5, p2.y - 58, tag_w, 18)
	_draw_rounded_box(tag_rect, 5.0, Color("101626", 0.85), Color("ffe762"), 1.0)
	draw_string(font, Vector2(tag_rect.position.x, tag_rect.position.y + 13), p2_name, HORIZONTAL_ALIGNMENT_CENTER, tag_w, 10, Color("ffe762"))

func _draw_bandit_sprite(p: Vector2, facing: int, leg_swing: float) -> void:
	# Bandit (Outlaw Rogue: Dark Cowl, Outlaw Brim, Crimson Mask, Leather Bandolier & Loot Purse)
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("1a1a24"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("12121c"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("2c2c3e"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("2c2c3e"))

	# Dark Tunic & Fluttering Stealth Cloak
	draw_rect(Rect2(p.x - 9, p.y - 26, 18, 15), Color("232332"))
	# Leather bandolier diagonal sash across chest with ammo studs
	draw_line(Vector2(p.x - 8, p.y - 25), Vector2(p.x + 8, p.y - 15), Color("5c3822"), 2.2)
	draw_circle(Vector2(p.x - 2, p.y - 20), 1.4, Color("e2b544"))
	draw_circle(Vector2(p.x + 3, p.y - 17), 1.4, Color("e2b544"))

	# Outlaw Belt, Gold Buckle & Leather Loot Coin Purse
	draw_rect(Rect2(p.x - 9, p.y - 15, 18, 3), Color("4a2d1e"))
	draw_rect(Rect2(p.x - 2, p.y - 15, 4, 3), Color("c8a855"))
	# Loot coin pouch at hip
	draw_rect(Rect2(p.x - (8 if facing > 0 else -4), p.y - 14, 4, 5), Color("7b4f2c"))
	draw_circle(Vector2(p.x - (6 if facing > 0 else -6), p.y - 12), 1.0, Color("ffe762"))

	# Cloak tail
	draw_rect(Rect2(p.x - (11 if facing > 0 else -7), p.y - 24, 4, 16), Color("161622"))

	# Head & Crimson Bandit Face Mask
	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	draw_rect(Rect2(p.x - 7, p.y - 32, 14, 7), Color("b1203d"))
	var eye_x: float = p.x + (3.0 if facing > 0 else -5.0)
	draw_rect(Rect2(eye_x, p.y - 35, 3.0, 2.5), Color("ffffff"))

	# Dark Outlaw Cowl & Slouch Hat Brim
	draw_rect(Rect2(p.x - 8, p.y - 41, 16, 6), Color("1a1a26"))
	draw_rect(Rect2(p.x - (9 if facing > 0 else 5), p.y - 38, 5, 8), Color("1a1a26"))
	draw_rect(Rect2(p.x - 10, p.y - 39, 20, 2), Color("12121c"))

	# Arm & Sleek Curved Parry Blade with Guard
	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("232332"))
	var blade_col: Color = Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("5b6270")
	draw_rect(Rect2(p.x + facing * 11.0 - 2.0, p.y - 28, 4, 16), blade_col)
	draw_rect(Rect2(p.x + facing * 11.0 - 4.0, p.y - 20, 8, 3), Color("c8a855"))

func _draw_scientist_sprite(p: Vector2, facing: int, leg_swing: float) -> void:
	# Scientist (Chrono Physicist: White Lab Coat, Goggles, Quantum Vials & Emitter Gauntlet)
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("28323e"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("1c242e"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("11161d"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("11161d"))

	# White Lab Coat & Blue Shirt
	draw_rect(Rect2(p.x - 9, p.y - 26, 18, 16), Color("e4e8ec"))
	draw_rect(Rect2(p.x - 2, p.y - 26, 4, 16), Color("4171a6"))
	# Front lab coat pocket with red & blue pens
	draw_rect(Rect2(p.x + (2 if facing > 0 else -6), p.y - 24, 4, 5), Color("cbd5e0"))
	draw_rect(Rect2(p.x + (3 if facing > 0 else -5), p.y - 26, 1, 3), Color("e63946"))
	draw_rect(Rect2(p.x + (4 if facing > 0 else -4), p.y - 26, 1, 3), Color("2b6cb0"))

	# Belt with glowing cyan & green quantum test tubes
	draw_rect(Rect2(p.x - 9, p.y - 14, 18, 3), Color("2d3748"))
	draw_rect(Rect2(p.x - 7, p.y - 13, 3, 5), Color("38ffff"))
	draw_rect(Rect2(p.x + 4, p.y - 13, 3, 5), Color("48bb78"))

	# Head & Glowing Chrono Goggles
	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	draw_rect(Rect2(p.x - 8, p.y - 34, 16, 4), Color("1a202c"))
	var goggle_x: float = p.x + (2.0 if facing > 0 else -6.0)
	draw_rect(Rect2(goggle_x, p.y - 35, 5.0, 5.0), Color("38ffff"))
	draw_rect(Rect2(goggle_x + 1, p.y - 34, 2.0, 2.0), Color("ffffff"))

	# Wild Mad Scientist Hair
	draw_rect(Rect2(p.x - 8, p.y - 42, 16, 6), Color("a0aec0"))
	draw_rect(Rect2(p.x - 9, p.y - 40, 4, 6), Color("a0aec0"))
	draw_rect(Rect2(p.x + 5, p.y - 40, 4, 6), Color("a0aec0"))

	# Arm & Chrono Emitter Gauntlet
	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("e4e8ec"))
	var emitter_col: Color = Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("5b6270")
	draw_circle(Vector2(p.x + facing * 10.0, p.y - 19), 6.5, emitter_col)
	draw_circle(Vector2(p.x + facing * 10.0, p.y - 19), 3.0, Color.WHITE)

func _draw_nurse_sprite(p: Vector2, facing: int, leg_swing: float) -> void:
	# Nurse (Combat Medic: Nurse Cap, Red Cross Apron, Stethoscope & Medkit)
	draw_rect(Rect2(p.x - 7 + leg_swing * 0.5, p.y - 12, 6, 12), Color("d8e2dc"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 12, 6, 12), Color("c2cec7"))
	draw_rect(Rect2(p.x - 8 + leg_swing * 0.5, p.y - 4, 7, 4), Color("ffffff"))
	draw_rect(Rect2(p.x + 1 - leg_swing * 0.5, p.y - 4, 7, 4), Color("ffffff"))

	# Nurse Dress & Red Cross Apron
	draw_rect(Rect2(p.x - 8, p.y - 26, 16, 15), Color("ffffff"))
	draw_rect(Rect2(p.x - 8, p.y - 15, 16, 3), Color("ff4d6d"))
	draw_rect(Rect2(p.x - 1.5, p.y - 23, 3, 7), Color("e63946"))
	draw_rect(Rect2(p.x - 3.5, p.y - 21, 7, 3), Color("e63946"))

	# Medical Stethoscope around neck
	draw_arc(Vector2(p.x, p.y - 26), 4.5, 0.0, PI, 12, Color("4a5568"), 1.8)
	draw_circle(Vector2(p.x + (1 if facing > 0 else -1), p.y - 21), 1.5, Color("cbd5e0"))

	# First-aid medkit bag at hip
	draw_rect(Rect2(p.x - (9 if facing > 0 else -5), p.y - 16, 5, 6), Color("ffffff"))
	draw_line(Vector2(p.x - (7 if facing > 0 else -7), p.y - 15), Vector2(p.x - (7 if facing > 0 else -7), p.y - 11), Color("e63946"), 1.2)
	draw_line(Vector2(p.x - (9 if facing > 0 else -5), p.y - 13), Vector2(p.x - (5 if facing > 0 else -9), p.y - 13), Color("e63946"), 1.2)

	# Head & Face
	draw_rect(Rect2(p.x - 7, p.y - 37, 14, 12), Color("f4b896"))
	var eye_x: float = p.x + (3.0 if facing > 0 else -5.0)
	draw_rect(Rect2(eye_x, p.y - 33, 2.5, 3.5), Color("1a1c2c"))

	# Brown hair & Classic Nurse Cap with Red Cross
	draw_rect(Rect2(p.x - 8, p.y - 40, 16, 5), Color("7a432e"))
	draw_rect(Rect2(p.x - 6, p.y - 44, 12, 5), Color("ffffff"))
	draw_rect(Rect2(p.x - 1, p.y - 43, 2, 4), Color("e63946"))
	draw_rect(Rect2(p.x - 2, p.y - 42, 4, 2), Color("e63946"))

	# Arm & Medical Deflector
	var arm_x: float = p.x + (5.0 if facing > 0 else -11.0)
	draw_rect(Rect2(arm_x, p.y - 23, 6, 9), Color("ffffff"))
	var defl_col: Color = Color("41f3ff") if player["parry_cooldown_timer"] <= 0.0 else Color("5b6270")
	draw_rect(Rect2(p.x + facing * 10.0 - 2.0, p.y - 26, 4, 14), defl_col)

# --- Mobs & Boss Drawing ---
func _draw_mobs() -> void:
	for m in mobs:
		var pos: Vector2 = m["pos"]

		if m.get("is_boss", false):
			_draw_extreme_boss(m)
			continue

		var t: int = m["type"]
		var flap: float = sin(m["anim"] * 2.2) * 8.0

		if m["charge_glow"] > 0.0:
			draw_circle(pos, 26.0 + m["charge_glow"] * 8.0, Color(1.0, 0.25, 0.35, m["charge_glow"] * 0.35))

		if t == 0:
			# Type 0: Demon Eye
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
			# Type 1: Corrupt Hornet
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
			# Type 2: Pixie Wisp
			draw_circle(pos + Vector2(-16, flap * 0.7), 10.0, Color(0.95, 0.65, 1.0, 0.45))
			draw_circle(pos + Vector2(16, flap * 0.7), 10.0, Color(0.95, 0.65, 1.0, 0.45))
			draw_circle(pos, 18.0, Color(1.0, 0.45, 0.88, 0.38))
			draw_circle(pos, 12.0, Color("ff9be8"))
			draw_circle(pos, 6.5, Color("ffffff"))
		else:
			# Type 3: Hellwing Imp
			draw_colored_polygon(PackedVector2Array([
				pos, pos + Vector2(-28, -14 + flap), pos + Vector2(-20, 10 + flap * 0.4)
			]), Color("591f36"))
			draw_colored_polygon(PackedVector2Array([
				pos, pos + Vector2(28, -14 + flap), pos + Vector2(20, 10 + flap * 0.4)
			]), Color("591f36"))
			draw_circle(pos, 15.0, Color("381426"))
			draw_circle(pos + Vector2(-5, -2), 3.5, Color("ff9e2c"))
			draw_circle(pos + Vector2(5, -2), 3.5, Color("ff9e2c"))

func _draw_extreme_boss(boss: Dictionary) -> void:
	var pos: Vector2 = boss["pos"]
	var r: float = boss["radius"]
	var p_dir: Vector2 = (player["pos"] - pos).normalized()
	var flash: bool = (boss["hit_flash"] > 0.0)

	# Terraria / Grief Boss Outer Demonic Thrusters & Veins
	for k in range(5):
		var ang: float = PI + (k - 2) * 0.38 + sin(boss["anim"] * 2.0 + k) * 0.15
		var t_dir := Vector2(cos(ang), sin(ang))
		var t_start := pos + t_dir * (r * 0.85)
		var t_end := t_start + t_dir * (r * 0.75)
		draw_line(t_start, t_end, Color("8b1429"), 6.0)
		draw_line(t_start + t_dir * 4.0, t_end, Color("ff2a4b"), 3.0)

	# Charging telegraph ring
	if boss["charge_glow"] > 0.0:
		draw_circle(pos, r + 18.0 * boss["charge_glow"], Color(1.0, 0.1, 0.2, boss["charge_glow"] * 0.45))

	# Orbiting cyber-hazard shields / laser nodes
	for k in range(4):
		var orb_ang: float = boss["anim"] * 1.8 + k * (TAU / 4.0)
		var orb_pos := pos + Vector2(cos(orb_ang), sin(orb_ang)) * (r + 18.0)
		draw_circle(orb_pos, 7.5, Color("ff2a55"))
		draw_circle(orb_pos, 4.0, Color.WHITE)
		draw_line(pos, orb_pos, Color("ff2a55", 0.45), 2.0)

	# Main Boss Eyeball Body
	var body_col := Color.WHITE if flash else Color("801124")
	draw_circle(pos, r, body_col)
	draw_circle(pos, r * 0.88, Color("f4f4f8") if not flash else Color("ffd5dd"))

	# Blood vessels in iris
	for i in range(8):
		var v_ang: float = i * (TAU / 8.0) + boss["anim"] * 0.2
		var v_vec := Vector2(cos(v_ang), sin(v_ang))
		draw_line(pos + v_vec * (r * 0.4), pos + v_vec * (r * 0.82), Color("b1203d", 0.65), 2.0)

	# Crimson Iris staring down the player
	var iris_pos := pos + p_dir * (r * 0.28)
	draw_circle(iris_pos, r * 0.48, Color("b81432"))
	draw_circle(iris_pos, r * 0.38, Color("ff2a55") if not boss["enraged"] else Color("ff7e2a"))

	# Core Demonic Pupil
	draw_circle(iris_pos + p_dir * (r * 0.06), r * 0.22, Color("140910"))
	draw_circle(iris_pos + p_dir * (r * 0.06), r * 0.10, Color.WHITE)

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
		draw_string_outline(font, ft["pos"] - Vector2(100, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, 16, 4, Color(0, 0, 0, c.a))
		draw_string(font, ft["pos"] - Vector2(100, 0), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, 16, c)

# ==============================================================================
# HUD (Hearts, Wave, Ability Indicators & Boss Health Bar)
# ==============================================================================
func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	if not is_multiplayer:
		# Terraria-style Hearts top-left
		for i in range(player["max_hearts"]):
			var hx: float = 38.0 + i * 38.0
			var hy: float = 36.0
			var filled: bool = (i < player["hearts"])
			_draw_heart_icon(Vector2(hx, hy), 14.0, filled)
	else:
		# Dual Co-Op HUD
		# P1 Hearts & Label
		var p1_label: String = "P1 (YOU) • " + _get_character_name(selected_character)
		if player.get("is_down", false):
			p1_label += " [⚠ DOWNED!]"
		draw_string_outline(font, Vector2(28, 26), p1_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color.BLACK)
		draw_string(font, Vector2(28, 26), p1_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("41f3ff") if not player.get("is_down", false) else Color("ff3b5b"))
		for i in range(player["max_hearts"]):
			var hx: float = 38.0 + i * 28.0
			var hy: float = 48.0
			var filled: bool = (i < player["hearts"])
			_draw_heart_icon(Vector2(hx, hy), 11.0, filled)

		# P2 Hearts & Label (Top Right)
		var p2_label: String = "P2 (FRIEND) • " + _get_character_name(player2["character"])
		if player2.get("is_down", false):
			p2_label += " [⚠ DOWNED!]"
		draw_string_outline(font, Vector2(VIEW_W - 240, 26), p2_label, HORIZONTAL_ALIGNMENT_RIGHT, 210, 14, 3, Color.BLACK)
		draw_string(font, Vector2(VIEW_W - 240, 26), p2_label, HORIZONTAL_ALIGNMENT_RIGHT, 210, 14, Color("ffe762") if not player2.get("is_down", false) else Color("ff3b5b"))
		for i in range(player2["max_hearts"]):
			var hx: float = (VIEW_W - 170.0) + i * 28.0
			var hy: float = 48.0
			var filled: bool = (i < player2["hearts"])
			_draw_heart_icon(Vector2(hx, hy), 11.0, filled)

	var hud_y: float = 76.0 if not is_multiplayer else 86.0
	draw_string_outline(font, Vector2(28, hud_y), "WAVE %d   |   MOBS LEFT: %d" % [current_wave, mobs.size() + mobs_to_spawn], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color.BLACK)
	draw_string(font, Vector2(28, hud_y), "WAVE %d   |   MOBS LEFT: %d" % [current_wave, mobs.size() + mobs_to_spawn], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe762"))

	var parry_status: String = "PARRY [F]: READY" if player["parry_cooldown_timer"] <= 0.0 else "PARRY [F]: RECHARGING"
	var parry_col: Color = Color("73eff7") if player["parry_cooldown_timer"] <= 0.0 else Color("ff6b6b")

	# Character Ability HUD prompt
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

	draw_string_outline(font, Vector2(28, hud_y + 26.0), parry_status + "   |   " + ability_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
	draw_string(font, Vector2(28, hud_y + 26.0), parry_status + "   |   " + ability_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ability_col)

	# WAVE 5: EXTREME BOSS HEALTH BAR
	if current_wave == 5:
		for m in mobs:
			if m.get("is_boss", false):
				_draw_boss_health_bar(m)
				break

func _get_character_name(c: int) -> String:
	match c:
		Character.BANDIT: return "BANDIT"
		Character.SCIENTIST: return "SCIENTIST"
		Character.NURSE: return "NURSE"
	return "FIGHTER"

func _draw_boss_health_bar(boss: Dictionary) -> void:
	var bar_w := 540.0
	var bar_h := 22.0
	var bar_x: float = VIEW_W * 0.5 - bar_w * 0.5
	var bar_y := 28.0

	# Plate container
	_draw_rounded_box(Rect2(bar_x - 14, bar_y - 10, bar_w + 28, bar_h + 38), 12.0, Color("140912", 0.92), Color("ff2a4b"), 3.0)

	var font := ThemeDB.fallback_font
	var boss_title: String = "EXTREME BOSS: %s" % boss["name"]
	draw_string_outline(font, Vector2(bar_x, bar_y + 8), boss_title, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16, 4, Color.BLACK)
	draw_string(font, Vector2(bar_x, bar_y + 8), boss_title, HORIZONTAL_ALIGNMENT_CENTER, bar_w, 16, Color("ffe762"))

	# Progress bar track
	draw_rect(Rect2(bar_x, bar_y + 16, bar_w, bar_h), Color("240d16"))
	var fill_ratio: float = clampf(float(boss["hp"]) / float(boss["max_hp"]), 0.0, 1.0)
	var fill_w: float = bar_w * fill_ratio
	var bar_col: Color = Color("ff2a4b") if boss["hp"] > 6 else Color("ff7e2a")
	if boss["hit_flash"] > 0.0:
		bar_col = Color.WHITE
	draw_rect(Rect2(bar_x, bar_y + 16, fill_w, bar_h), bar_col)
	draw_rect(Rect2(bar_x, bar_y + 16, bar_w, bar_h), Color("ff2a4b"), false, 2.0)

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
# ROBOT FONT RENDERER ("Bounce Back" Big in Middle Top)
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

	var pad := 24.0
	var plate := Rect2(start_x - pad, start_y - pad, total_w + pad * 2.0, 5.0 * pixel_size + pad * 2.0)
	_draw_rounded_box(plate, 18.0, Color(0.08, 0.11, 0.19, 0.88), Color("41f3ff"), 4.0)

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
					draw_rect(Rect2(px + 4, py + 5, pixel_size - 1, pixel_size - 1), Color("0b0e17"))
					var seg_col := Color("41f3ff") if r < 2 else Color("ff2a55")
					draw_rect(Rect2(px, py, pixel_size - 1.5, pixel_size - 1.5), seg_col)
					draw_rect(Rect2(px + 2, py + 2, pixel_size * 0.4, pixel_size * 0.4), Color(1, 1, 1, 0.65))

# ==============================================================================
# MENU, BUTTONS, CHARACTER SELECTION MODAL & CREDITS
# ==============================================================================
func _draw_main_menu() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.05, 0.07, 0.13, 0.52))

	var bob: float = sin(Time.get_ticks_msec() * 0.003) * 6.0
	_draw_robot_title("BOUNCE BACK", Vector2(VIEW_W * 0.5, 135.0 + bob), 12.0)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, 245), "PERFECT PARRY [F] | SHIFT FOR CHARACTER ABILITIES", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 19, 4, Color.BLACK)
	draw_string(font, Vector2(0, 245), "PERFECT PARRY [F] | SHIFT FOR CHARACTER ABILITIES", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 19, Color("ffe762"))

	# 4 Menu Buttons (SOLO MISSION, ONLINE CO-OP, CHARACTERS, CREDITS)
	_draw_bouncy_button(start_btn_rect, btn_scales["start"], Color("ff5e7e"), Color("ff9e2c"), "SOLO MISSION", 28)
	_draw_bouncy_button(online_btn_rect, btn_scales["online"], Color("1b499c"), Color("41f3ff"), "ONLINE CO-OP", 28)
	_draw_bouncy_button(characters_btn_rect, btn_scales["characters"], Color("3b6cd9"), Color("41f3ff"), "CHARACTERS", 26)
	_draw_bouncy_button(credits_btn_rect, btn_scales["credits"], Color("38b764"), Color("41f3ff"), "CREDITS", 26)

	if online_lobby_open:
		_draw_online_lobby_modal()
	elif characters_open:
		_draw_characters_modal()
	elif credits_open:
		_draw_credits_modal()

func _draw_characters_modal() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.04, 0.06, 0.12, 0.85))
	# Main modal container with drop shadow
	_draw_rounded_box(Rect2(char_box_rect.position + Vector2(0, 10), char_box_rect.size), 22.0, Color(0, 0, 0, 0.6), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(char_box_rect, 22.0, Color("101626"), Color("41f3ff"), 3.5)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(char_box_rect.position.x, char_box_rect.position.y + 34), "CHARACTER ARCHIVES & ABILITIES", HORIZONTAL_ALIGNMENT_CENTER, char_box_rect.size.x, 26, 5, Color.BLACK)
	draw_string(font, Vector2(char_box_rect.position.x, char_box_rect.position.y + 34), "CHARACTER ARCHIVES & ABILITIES", HORIZONTAL_ALIGNMENT_CENTER, char_box_rect.size.x, 26, Color("ffe762"))

	draw_string_outline(font, Vector2(char_box_rect.position.x, char_box_rect.position.y + 54), "SELECT ANY FIGHTER TO OPEN THEIR AUTHENTIC SKIN & COMBAT BLUEPRINT", HORIZONTAL_ALIGNMENT_CENTER, char_box_rect.size.x, 12, 3, Color.BLACK)
	draw_string(font, Vector2(char_box_rect.position.x, char_box_rect.position.y + 54), "SELECT ANY FIGHTER TO OPEN THEIR AUTHENTIC SKIN & COMBAT BLUEPRINT", HORIZONTAL_ALIGNMENT_CENTER, char_box_rect.size.x, 12, Color("41f3ff"))

	# Close button ('X' at top right)
	var r: float = CLOSE_BTN_RADIUS * btn_scales["char_close"]
	draw_circle(close_char_center + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.45))
	draw_circle(close_char_center, r, Color("ff2a4b"))
	draw_arc(close_char_center, r, 0.0, TAU, 28, Color.WHITE, 2.5)
	var x_off: float = r * 0.42
	draw_line(close_char_center + Vector2(-x_off, -x_off), close_char_center + Vector2(x_off, x_off), Color.WHITE, 3.0)
	draw_line(close_char_center + Vector2(x_off, -x_off), close_char_center + Vector2(-x_off, x_off), Color.WHITE, 3.0)

	var char_data := [
		{
			"name": "BANDIT",
			"sub": "THE PHANTOM OUTLAW",
			"role": "AGILITY & BURST",
			"icon": "🗡 BANDIT",
			"skin_name": "OUTLAW SHADOW ROBES",
			"skin_features": [
				"Outlaw Cowl & Slouch Brim",
				"Crimson Bandit Face Mask",
				"Leather Bandolier & Ammo",
				"Parry Blade & Loot Purse"
			],
			"lore": "The Bandit wears a classic outlaw cowl, crimson face mask, diagonal leather ammo sash, and a coin purse at his hip. His skin matches the ruthless badlands outlaw archetype.",
			"ability_name": "SHADOW DASH",
			"keybind": "[SHIFT] KEYBIND",
			"cd": "5.0s COOLDOWN",
			"mechanics": "Dashes a massive distance across the arena in a flash. Grants complete invulnerability (hitbox negation) while dashing, leaving wind trails and a roaring sound effect.",
			"tactics": "Use Shadow Dash to instantly slip through dense bullet walls, evade boss attacks, or reposition behind enemies right before they fire.",
			"ratings": {"mobility": 0.95, "defense": 0.45, "control": 0.35},
			"theme_col": Color("ff9e2c"),
			"border_col": Color("ff5e7e")
		},
		{
			"name": "SCIENTIST",
			"sub": "THE CHRONO PHYSICIST",
			"role": "CONTROL & TIMING",
			"icon": "⚡ SCIENTIST",
			"skin_name": "CHRONOMANCER LAB COAT",
			"skin_features": [
				"White Lab Coat & Pen Pocket",
				"Bifocal Chrono Goggles",
				"Quantum Vials on Utility Belt",
				"Chrono Emitter Gauntlet"
			],
			"lore": "The Scientist sports a white laboratory coat with pens in his breast pocket, wild gray hair, glowing teal goggles, and belt-strapped chemical vials containing temporal catalysts.",
			"ability_name": "TEMPORAL FREEZE",
			"keybind": "[SHIFT] KEYBIND",
			"cd": "10.0s COOLDOWN",
			"mechanics": "Stops reality itself for 1.0 full second! Freezes both flying mobs and incoming lasers in mid-air with an ethereal chronofield while letting you move freely.",
			"tactics": "Freeze the battlefield when caught in unavoidable crossfires. Walk right up to frozen lasers and ready your parry keybind the millisecond time resumes.",
			"ratings": {"mobility": 0.60, "defense": 0.65, "control": 0.95},
			"theme_col": Color("38ffff"),
			"border_col": Color("3b6cd9")
		},
		{
			"name": "NURSE",
			"sub": "THE COMBAT MEDIC",
			"role": "SUSTAIN & SURVIVAL",
			"icon": "✚ NURSE",
			"skin_name": "FIRST RESPONDER UNIFORM",
			"skin_features": [
				"Nurse Cap with Red Cross",
				"Medical Neck Stethoscope",
				"Red Cross Apron Dress",
				"First-Aid Medkit Bag"
			],
			"lore": "The Nurse wears a crisp white nurse cap emblazoned with a red cross, medical stethoscope, protective scrub apron, and a first-aid medkit bag carrying restorative elixirs.",
			"ability_name": "VITAL REGENERATION",
			"keybind": "[PASSIVE] AUTOMATIC",
			"cd": "HEALS EVERY 8.0s",
			"mechanics": "Passively restores 1 Heart every 8 seconds automatically without pressing any key. Keeps you resilient throughout extended battles and bullet hell swarms.",
			"tactics": "The best choice for outlasting the Wave 5 Boss. Even if you take hits, focus on safe distance parrying while your passive constantly replenishes your health.",
			"ratings": {"mobility": 0.55, "defense": 0.95, "control": 0.45},
			"theme_col": Color("55ff99"),
			"border_col": Color("ff5e7e")
		}
	]

	# 1. Top 3 Character Selector Tabs (Click to open each character!)
	for idx in range(3):
		var cd = char_data[idx]
		var is_viewing: bool = (int(viewing_character) == idx)
		var is_active: bool = (int(selected_character) == idx)
		var t_rect: Rect2 = char_tab_rects[idx]
		var t_scale: float = btn_scales["tab_%d" % idx]
		var s_rect := Rect2(t_rect.get_center() - t_rect.size * t_scale * 0.5, t_rect.size * t_scale)
		var is_hovered: bool = btn_hovered["tab_%d" % idx]

		_draw_rounded_box(Rect2(s_rect.position + Vector2(0, 4), s_rect.size), 12.0, Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0.0)
		var tab_fill := Color(cd["theme_col"].r * 0.3, cd["theme_col"].g * 0.3, cd["theme_col"].b * 0.3, 0.9) if is_viewing else (Color("1a2436") if is_hovered else Color("131a29"))
		var tab_brd: Color = cd["theme_col"] if is_viewing else (Color("41f3ff") if is_hovered else Color("2c3b52"))
		var tab_brd_w: float = 2.5 if is_viewing else (1.8 if is_hovered else 1.2)
		_draw_rounded_box(s_rect, 12.0, tab_fill, tab_brd, tab_brd_w)

		# Tab Icon & Title
		draw_string_outline(font, Vector2(s_rect.position.x + 16, s_rect.position.y + 24), cd["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color.BLACK)
		draw_string(font, Vector2(s_rect.position.x + 16, s_rect.position.y + 24), cd["icon"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, cd["theme_col"] if is_viewing else Color.WHITE)

		draw_string(font, Vector2(s_rect.position.x + 16, s_rect.position.y + 40), cd["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("94a3b8"))

		# Status badges on the right side of tab
		if is_active:
			var act_badge := Rect2(s_rect.end.x - 90, s_rect.position.y + 12, 78, 22)
			_draw_rounded_box(act_badge, 6.0, Color("ffe762", 0.25), Color("ffe762"), 1.2)
			draw_string(font, Vector2(act_badge.position.x, act_badge.position.y + 16), "★ ACTIVE", HORIZONTAL_ALIGNMENT_CENTER, act_badge.size.x, 10, Color("ffe762"))
		elif is_viewing:
			var view_badge := Rect2(s_rect.end.x - 90, s_rect.position.y + 12, 78, 22)
			_draw_rounded_box(view_badge, 6.0, Color("41f3ff", 0.2), Color("41f3ff"), 1.0)
			draw_string(font, Vector2(view_badge.position.x, view_badge.position.y + 16), "OPENED", HORIZONTAL_ALIGNMENT_CENTER, view_badge.size.x, 10, Color("41f3ff"))

	# Currently Opened Character
	var cur_idx := int(viewing_character)
	var d = char_data[cur_idx]
	var is_active_fighter: bool = (selected_character == viewing_character)

	# 2. LEFT PANEL: Skin Showcase Stage
	var left_rect := Rect2(80, 144, 440, 520)
	_draw_rounded_box(Rect2(left_rect.position + Vector2(0, 8), left_rect.size), 18.0, Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(left_rect, 18.0, Color("0e1524", 0.95), d["theme_col"], 2.2)

	# Stage Header Banner
	var s_hdr := Rect2(left_rect.position.x + 14, left_rect.position.y + 12, left_rect.size.x - 28, 26)
	_draw_rounded_box(s_hdr, 8.0, Color("141d2e"), d["theme_col"], 1.2)
	draw_string(font, Vector2(s_hdr.position.x, s_hdr.position.y + 18), "AUTHENTIC FIGHTER SKIN: " + d["skin_name"], HORIZONTAL_ALIGNMENT_CENTER, s_hdr.size.x, 11, d["theme_col"])

	# Character Name & Subtitle
	draw_string_outline(font, Vector2(left_rect.position.x, left_rect.position.y + 64), d["name"], HORIZONTAL_ALIGNMENT_CENTER, left_rect.size.x, 26, 4, Color.BLACK)
	draw_string(font, Vector2(left_rect.position.x, left_rect.position.y + 64), d["name"], HORIZONTAL_ALIGNMENT_CENTER, left_rect.size.x, 26, d["theme_col"])

	draw_string(font, Vector2(left_rect.position.x, left_rect.position.y + 82), d["sub"], HORIZONTAL_ALIGNMENT_CENTER, left_rect.size.x, 11, Color("94a3b8"))

	# Pedestal Stage
	var ped_center := Vector2(left_rect.get_center().x, left_rect.position.y + 225.0)
	var time_sec: float = Time.get_ticks_msec() * 0.001
	var bob: float = sin(time_sec * 3.2) * 3.5

	# Pedestal Base Rings
	draw_circle(ped_center + Vector2(0, 18), 58.0, Color(0, 0, 0, 0.4))
	draw_circle(ped_center + Vector2(0, 14), 52.0, Color(d["theme_col"].r, d["theme_col"].g, d["theme_col"].b, 0.22))
	draw_arc(ped_center + Vector2(0, 14), 52.0, 0.0, TAU, 36, d["theme_col"], 2.5)

	# Holographic Pulse Wave
	var pulse: float = fmod(time_sec * 18.0, 16.0)
	draw_arc(ped_center + Vector2(0, 14), 52.0 + pulse, 0.0, TAU, 36, Color(d["theme_col"].r, d["theme_col"].g, d["theme_col"].b, maxf(0.0, 0.5 - pulse / 16.0)), 1.5)

	# Character Ambient Particles
	match cur_idx:
		0:
			for i in range(4):
				var ang: float = time_sec * 2.0 + i * (TAU / 4.0)
				var e_pos := ped_center + Vector2(cos(ang) * 44.0, sin(ang) * 16.0 - 25.0)
				draw_circle(e_pos, 2.0, Color("ff9e2c", 0.75))
		1:
			for i in range(4):
				var ang: float = -time_sec * 2.5 + i * (TAU / 4.0)
				var e_pos := ped_center + Vector2(cos(ang) * 46.0, sin(ang) * 16.0 - 25.0)
				draw_circle(e_pos, 2.2, Color("38ffff", 0.85))
		2:
			for i in range(3):
				var hp_y: float = fmod(time_sec * 24.0 + i * 20.0, 50.0)
				var hp_x: float = sin(time_sec * 2.0 + i) * 36.0
				var h_pos := ped_center + Vector2(hp_x, -10.0 - hp_y)
				draw_string(font, h_pos, "✚", HORIZONTAL_ALIGNMENT_CENTER, 14, 12, Color("55ff99", 0.75))

	# 2.8x Scaled Animated Character Sprite
	var sprite_pos := ped_center + Vector2(0, 6 + bob)
	draw_set_transform(sprite_pos, 0.0, Vector2(2.8, 2.8))
	match cur_idx:
		0:
			_draw_bandit_sprite(Vector2.ZERO, 1, 0.0)
		1:
			_draw_scientist_sprite(Vector2.ZERO, 1, 0.0)
		2:
			_draw_nurse_sprite(Vector2.ZERO, 1, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Skin Matches Name Breakdown (4 Pills)
	draw_string_outline(font, Vector2(left_rect.position.x + 16, left_rect.position.y + 295), "AUTHENTIC SKIN PIECES (MATCHES NAME):", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 2, Color.BLACK)
	draw_string(font, Vector2(left_rect.position.x + 16, left_rect.position.y + 295), "AUTHENTIC SKIN PIECES (MATCHES NAME):", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe762"))

	var pill_w: float = 196.0
	var pill_h: float = 24.0
	for i in range(4):
		var col_idx := i % 2
		var row_idx := i / 2
		var px := left_rect.position.x + 16.0 + col_idx * (pill_w + 16.0)
		var py := left_rect.position.y + 308.0 + row_idx * (pill_h + 8.0)
		var p_rect := Rect2(px, py, pill_w, pill_h)
		_draw_rounded_box(p_rect, 6.0, Color("141c2c"), Color("2d3f5a"), 1.0)
		draw_string(font, Vector2(px + 8, py + 16), "⬡ " + d["skin_features"][i], HORIZONTAL_ALIGNMENT_LEFT, pill_w - 12, 10, Color("e2e8f0"))

	# Backstory / Lore
	var lore_box := Rect2(left_rect.position.x + 14, left_rect.position.y + 378, left_rect.size.x - 28, 128)
	_draw_rounded_box(lore_box, 10.0, Color("0b101c", 0.9), Color("1e2a3c"), 1.0)
	draw_string(font, Vector2(lore_box.position.x + 10, lore_box.position.y + 18), "LORE & ARCHETYPE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, d["theme_col"])
	_draw_wrapped_text(font, d["lore"], lore_box.position + Vector2(10, 36), lore_box.size.x - 20, 11, Color("cbd5e1"))

	# 3. RIGHT PANEL: Cool Ability Blueprint & Tactics
	var right_rect := Rect2(540, 144, 660, 520)
	_draw_rounded_box(Rect2(right_rect.position + Vector2(0, 8), right_rect.size), 18.0, Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(right_rect, 18.0, Color("0b121e", 0.95), Color("283854"), 2.0)

	# Ability Header Card
	var ab_hdr := Rect2(right_rect.position.x + 16, right_rect.position.y + 14, right_rect.size.x - 32, 78)
	_draw_rounded_box(ab_hdr, 12.0, Color("121a2b"), d["theme_col"], 1.5)

	# Ability Name
	draw_string_outline(font, Vector2(ab_hdr.position.x + 16, ab_hdr.position.y + 36), d["ability_name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 4, Color.BLACK)
	draw_string(font, Vector2(ab_hdr.position.x + 16, ab_hdr.position.y + 36), d["ability_name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffe762"))

	draw_string(font, Vector2(ab_hdr.position.x + 16, ab_hdr.position.y + 58), "PRIMARY SPECIAL ABILITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, d["theme_col"])

	# Keybind pill
	var kb_pill := Rect2(ab_hdr.end.x - 260, ab_hdr.position.y + 26, 115, 26)
	_draw_rounded_box(kb_pill, 6.0, Color(d["theme_col"].r, d["theme_col"].g, d["theme_col"].b, 0.25), d["theme_col"], 1.2)
	draw_string(font, Vector2(kb_pill.position.x, kb_pill.position.y + 18), d["keybind"], HORIZONTAL_ALIGNMENT_CENTER, kb_pill.size.x, 10, Color.WHITE)

	# Cooldown pill
	var cd_pill := Rect2(ab_hdr.end.x - 135, ab_hdr.position.y + 26, 120, 26)
	_draw_rounded_box(cd_pill, 6.0, Color("ff9e2c", 0.2), Color("ff9e2c"), 1.2)
	draw_string(font, Vector2(cd_pill.position.x, cd_pill.position.y + 18), d["cd"], HORIZONTAL_ALIGNMENT_CENTER, cd_pill.size.x, 10, Color("ffbd59"))

	# Ability Mechanics Box
	var mech_box := Rect2(right_rect.position.x + 16, right_rect.position.y + 102, right_rect.size.x - 32, 108)
	_draw_rounded_box(mech_box, 10.0, Color("101626"), Color("24334a"), 1.0)
	draw_string(font, Vector2(mech_box.position.x + 12, mech_box.position.y + 20), "⚡ ABILITY MECHANICS & EXECUTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("41f3ff"))
	_draw_wrapped_text(font, d["mechanics"], mech_box.position + Vector2(12, 40), mech_box.size.x - 24, 12, Color("e2e8f0"))

	# Pro Tactics Box
	var tact_box := Rect2(right_rect.position.x + 16, right_rect.position.y + 220, right_rect.size.x - 32, 98)
	_draw_rounded_box(tact_box, 10.0, Color("101626"), Color("24334a"), 1.0)
	draw_string(font, Vector2(tact_box.position.x + 12, tact_box.position.y + 20), "⚔ PRO COMBAT STRATEGY & SYNERGIES", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe762"))
	_draw_wrapped_text(font, d["tactics"], tact_box.position + Vector2(12, 40), tact_box.size.x - 24, 11, Color("cbd5e1"))

	# Fighter Attribute Meters
	var attr_box := Rect2(right_rect.position.x + 16, right_rect.position.y + 328, right_rect.size.x - 32, 82)
	_draw_rounded_box(attr_box, 10.0, Color("101626"), Color("24334a"), 1.0)
	draw_string(font, Vector2(attr_box.position.x + 12, attr_box.position.y + 18), "📊 FIGHTER COMBAT METERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("94a3b8"))

	var ratings = d["ratings"]
	var bar_labels := ["MOBILITY", "DEFENSE", "CONTROL"]
	var bar_keys := ["mobility", "defense", "control"]
	for i in range(3):
		var by: float = attr_box.position.y + 38.0 + i * 15.0
		draw_string(font, Vector2(attr_box.position.x + 12, by + 8), bar_labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("718096"))
		var m_rect := Rect2(attr_box.position.x + 95, by, 500, 8)
		draw_rect(m_rect, Color("1a2436"))
		var fill_w: float = 500.0 * ratings[bar_keys[i]]
		draw_rect(Rect2(m_rect.position.x, m_rect.position.y, fill_w, 8), d["theme_col"])

	# Bottom Action Button
	var act_btn_rect := char_activate_btn_rect
	var act_scale: float = btn_scales["char_activate"]
	var s_act := Rect2(act_btn_rect.get_center() - act_btn_rect.size * act_scale * 0.5, act_btn_rect.size * act_scale)
	var is_act_hovered: bool = btn_hovered["char_activate"]

	_draw_rounded_box(Rect2(s_act.position + Vector2(0, 4), s_act.size), 14.0, Color(0, 0, 0, 0.4), Color.TRANSPARENT, 0.0)
	if is_active_fighter:
		_draw_rounded_box(s_act, 14.0, Color(0.12, 0.42, 0.22, 0.95), Color("ffe762"), 2.5)
		draw_string_outline(font, Vector2(s_act.position.x, s_act.position.y + 33), "★ CURRENT ACTIVE FIGHTER (EQUIPPED)", HORIZONTAL_ALIGNMENT_CENTER, s_act.size.x, 16, 4, Color.BLACK)
		draw_string(font, Vector2(s_act.position.x, s_act.position.y + 33), "★ CURRENT ACTIVE FIGHTER (EQUIPPED)", HORIZONTAL_ALIGNMENT_CENTER, s_act.size.x, 16, Color.WHITE)
	else:
		var btn_fill := Color("24334d") if is_act_hovered else Color("182338")
		var btn_brd: Color = Color("6bfaff") if is_act_hovered else Color("41f3ff")
		_draw_rounded_box(s_act, 14.0, btn_fill, btn_brd, 2.0)
		var label_str: String = "CHOOSE & EQUIP " + d["name"]
		draw_string_outline(font, Vector2(s_act.position.x, s_act.position.y + 33), label_str, HORIZONTAL_ALIGNMENT_CENTER, s_act.size.x, 16, 4, Color.BLACK)
		draw_string(font, Vector2(s_act.position.x, s_act.position.y + 33), label_str, HORIZONTAL_ALIGNMENT_CENTER, s_act.size.x, 16, Color("41f3ff"))

func _draw_wrapped_text(font: Font, text: String, start_pos: Vector2, max_w: float, font_size: int, col: Color) -> void:
	var words := text.split(" ")
	var cur_line := ""
	var line_y: float = start_pos.y
	var line_spacing: float = font_size + 4.0

	for w in words:
		var test_line: String = cur_line + (" " if cur_line != "" else "") + w
		var sz: Vector2 = font.get_string_size(test_line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if sz.x > max_w and cur_line != "":
			draw_string(font, Vector2(start_pos.x, line_y), cur_line, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, col)
			cur_line = w
			line_y += line_spacing
		else:
			cur_line = test_line
	if cur_line != "":
		draw_string(font, Vector2(start_pos.x, line_y), cur_line, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, col)

func _draw_boss_warning(timer: float) -> void:
	var font := ThemeDB.fallback_font
	var pulse: float = sin((3.8 - timer) * 11.0) * 0.5 + 0.5
	var alpha: float = clampf(timer / 0.5, 0.0, 1.0)

	# 1. Pulsing Red Screen Flash Vignette
	var red_tint := Color(0.85, 0.04, 0.12, (0.16 + pulse * 0.18) * alpha)
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), red_tint)

	# 2. Top & Bottom Hazard Warning Stripes
	var bar_h: float = 38.0
	var top_bar := Rect2(0, 0, VIEW_W, bar_h)
	var bot_bar := Rect2(0, VIEW_H - bar_h, VIEW_W, bar_h)
	draw_rect(top_bar, Color(0.12, 0.01, 0.03, 0.92 * alpha))
	draw_rect(bot_bar, Color(0.12, 0.01, 0.03, 0.92 * alpha))
	draw_line(Vector2(0, bar_h), Vector2(VIEW_W, bar_h), Color(1.0, 0.15, 0.25, alpha), 2.5)
	draw_line(Vector2(0, VIEW_H - bar_h), Vector2(VIEW_W, VIEW_H - bar_h), Color(1.0, 0.15, 0.25, alpha), 2.5)

	# Moving warning text ticker
	var ticker_text := "⚠ WARNING // DANGER // EXTREME APEX BOSS DETECTED // ⚠ WARNING // DANGER // EXTREME APEX BOSS DETECTED // ⚠ WARNING //"
	var ticker_x: float = fmod(-Time.get_ticks_msec() * 0.12, 400.0)
	draw_string(font, Vector2(ticker_x, 24), ticker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.2, 0.3, alpha))
	draw_string(font, Vector2(ticker_x, VIEW_H - 14), ticker_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.2, 0.3, alpha))

	# 3. Main Center Warning Badge
	var banner_w: float = 880.0
	var banner_h: float = 126.0
	var banner_rect := Rect2((VIEW_W - banner_w) * 0.5, 175.0, banner_w, banner_h)

	_draw_rounded_box(Rect2(banner_rect.position + Vector2(0, 8), banner_rect.size), 18.0, Color(0, 0, 0, 0.6 * alpha), Color.TRANSPARENT, 0.0)
	var box_fill := Color(0.16, 0.02, 0.05, 0.94 * alpha)
	var box_brd := Color(1.0, 0.15 + pulse * 0.4, 0.25, alpha)
	_draw_rounded_box(banner_rect, 18.0, box_fill, box_brd, 3.5)

	# Flashing Siren Headlines
	var title_col := Color("ff3b5b") if pulse > 0.35 else Color("ffffff")
	draw_string_outline(font, Vector2(banner_rect.position.x, banner_rect.position.y + 50), "⚠ WARNING: BOSS APPROACHING ⚠", HORIZONTAL_ALIGNMENT_CENTER, banner_w, 36, 6, Color.BLACK)
	draw_string(font, Vector2(banner_rect.position.x, banner_rect.position.y + 50), "⚠ WARNING: BOSS APPROACHING ⚠", HORIZONTAL_ALIGNMENT_CENTER, banner_w, 36, Color(title_col.r, title_col.g, title_col.b, alpha))

	var sub_text := "THE APEX ANOMALY • 20 LASER DEFLECTIONS REQUIRED"
	draw_string_outline(font, Vector2(banner_rect.position.x, banner_rect.position.y + 88), sub_text, HORIZONTAL_ALIGNMENT_CENTER, banner_w, 18, 4, Color.BLACK)
	draw_string(font, Vector2(banner_rect.position.x, banner_rect.position.y + 88), sub_text, HORIZONTAL_ALIGNMENT_CENTER, banner_w, 18, Color(1.0, 0.88, 0.35, alpha))

func _draw_game_over_overlay() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.06, 0.02, 0.05, 0.74))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(0, 180), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 64, 8, Color.BLACK)
	draw_string(font, Vector2(0, 180), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 64, Color("ff3b5b"))

	draw_string_outline(font, Vector2(0, 245), "You reached Wave %d" % current_wave, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, 5, Color.BLACK)
	draw_string(font, Vector2(0, 245), "You reached Wave %d" % current_wave, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 28, Color("ffe762"))

	draw_string(font, Vector2(0, 280), "PRESS TO RESTART", HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 14, Color("cbd5e0"))

	_draw_bouncy_button(retry_btn_rect, btn_scales["start"], Color("ff5e7e"), Color("ff9e2c"), "BOUNCE BACK", 28)
	_draw_bouncy_button(game_over_menu_btn_rect, btn_scales["credits"], Color("3b5dc9"), Color("41f3ff"), "MAIN MENU", 28)

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

func _draw_online_lobby_modal() -> void:
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), Color(0.04, 0.06, 0.12, 0.88))
	_draw_rounded_box(Rect2(online_box_rect.position + Vector2(0, 10), online_box_rect.size), 22.0, Color(0, 0, 0, 0.6), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(online_box_rect, 22.0, Color("101626"), Color("41f3ff"), 3.5)

	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(online_box_rect.position.x, online_box_rect.position.y + 34), "ONLINE CO-OP MULTIPLAYER", HORIZONTAL_ALIGNMENT_CENTER, online_box_rect.size.x, 26, 5, Color.BLACK)
	draw_string(font, Vector2(online_box_rect.position.x, online_box_rect.position.y + 34), "ONLINE CO-OP MULTIPLAYER", HORIZONTAL_ALIGNMENT_CENTER, online_box_rect.size.x, 26, Color("ffe762"))

	draw_string_outline(font, Vector2(online_box_rect.position.x, online_box_rect.position.y + 54), "PLAY TOGETHER ON ITCH.IO • 4-LETTER ROOM CODES • WEBRTC P2P", HORIZONTAL_ALIGNMENT_CENTER, online_box_rect.size.x, 12, 3, Color.BLACK)
	draw_string(font, Vector2(online_box_rect.position.x, online_box_rect.position.y + 54), "PLAY TOGETHER ON ITCH.IO • 4-LETTER ROOM CODES • WEBRTC P2P", HORIZONTAL_ALIGNMENT_CENTER, online_box_rect.size.x, 12, Color("41f3ff"))

	# Close button ('X' at top right)
	var r: float = CLOSE_BTN_RADIUS * btn_scales["online_close"]
	draw_circle(close_online_center + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.45))
	draw_circle(close_online_center, r, Color("ff2a4b"))
	draw_arc(close_online_center, r, 0.0, TAU, 28, Color.WHITE, 2.5)
	var x_off: float = r * 0.42
	draw_line(close_online_center + Vector2(-x_off, -x_off), close_online_center + Vector2(x_off, x_off), Color.WHITE, 3.0)
	draw_line(close_online_center + Vector2(x_off, -x_off), close_online_center + Vector2(-x_off, x_off), Color.WHITE, 3.0)

	# --- 1. LEFT CARD: HOST ROOM ---
	_draw_rounded_box(Rect2(host_card_rect.position + Vector2(0, 6), host_card_rect.size), 16.0, Color(0, 0, 0, 0.4), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(host_card_rect, 16.0, Color("141c2c"), Color("41f3ff") if is_host else Color("2a3c57"), 2.0)

	draw_string_outline(font, Vector2(host_card_rect.position.x, host_card_rect.position.y + 36), "⚔ HOST A CO-OP ROOM", HORIZONTAL_ALIGNMENT_CENTER, host_card_rect.size.x, 20, 4, Color.BLACK)
	draw_string(font, Vector2(host_card_rect.position.x, host_card_rect.position.y + 36), "⚔ HOST A CO-OP ROOM", HORIZONTAL_ALIGNMENT_CENTER, host_card_rect.size.x, 20, Color("41f3ff"))

	draw_string(font, Vector2(host_card_rect.position.x, host_card_rect.position.y + 58), "Create a room and share the 4-letter code", HORIZONTAL_ALIGNMENT_CENTER, host_card_rect.size.x, 11, Color("94a3b8"))

	# Big Room Code Display Box
	var code_display_rect := Rect2(host_card_rect.position.x + 36, host_card_rect.position.y + 85, host_card_rect.size.x - 72, 86)
	_draw_rounded_box(code_display_rect, 12.0, Color("0b101c"), Color("ffe762") if my_room_code != "" and is_host else Color("223147"), 2.0)
	if my_room_code != "" and is_host:
		var letters := ""
		for idx in range(my_room_code.length()):
			letters += my_room_code[idx] + "   "
		draw_string_outline(font, Vector2(code_display_rect.position.x, code_display_rect.position.y + 52), letters.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, code_display_rect.size.x, 36, 5, Color.BLACK)
		draw_string(font, Vector2(code_display_rect.position.x, code_display_rect.position.y + 52), letters.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, code_display_rect.size.x, 36, Color("ffe762"))
		draw_string(font, Vector2(code_display_rect.position.x, code_display_rect.position.y + 74), "SHARE THIS 4-LETTER CODE", HORIZONTAL_ALIGNMENT_CENTER, code_display_rect.size.x, 10, Color("55ff99"))
	else:
		draw_string(font, Vector2(code_display_rect.position.x, code_display_rect.position.y + 48), "NO ROOM CREATED YET", HORIZONTAL_ALIGNMENT_CENTER, code_display_rect.size.x, 14, Color("64748b"))
		draw_string(font, Vector2(code_display_rect.position.x, code_display_rect.position.y + 68), "Click 'Create Room' below", HORIZONTAL_ALIGNMENT_CENTER, code_display_rect.size.x, 10, Color("475569"))

	# Host Status Pill
	var host_pill_rect := Rect2(host_card_rect.position.x + 36, host_card_rect.position.y + 190, host_card_rect.size.x - 72, 38)
	var peer_col: Color = Color("55ff99") if peer_is_ready else (Color("ffe762") if my_room_code != "" and is_host else Color("64748b"))
	var peer_text: String = "● FRIEND CONNECTED! READY!" if peer_is_ready else ("● WAITING FOR FRIEND TO JOIN..." if my_room_code != "" and is_host else "● READY TO CREATE")
	_draw_rounded_box(host_pill_rect, 8.0, Color("0f172a"), peer_col, 1.2)
	draw_string(font, Vector2(host_pill_rect.position.x, host_pill_rect.position.y + 24), peer_text, HORIZONTAL_ALIGNMENT_CENTER, host_pill_rect.size.x, 12, peer_col)

	# [CREATE ROOM] Button
	_draw_bouncy_button(host_create_btn_rect, btn_scales["host_create"], Color("2563eb"), Color("60a5fa"), "CREATE ROOM", 18)

	# [START CO-OP GAME] Button
	var start_fill: Color = Color("059669") if peer_is_ready else Color("1e293b")
	var start_brd: Color = Color("34d399") if peer_is_ready else Color("475569")
	var start_label: String = "START CO-OP MISSION" if peer_is_ready else "WAITING FOR FRIEND..."
	_draw_bouncy_button(host_start_btn_rect, btn_scales["host_start"], start_fill, start_brd, start_label, 18)

	# --- 2. RIGHT CARD: JOIN ROOM ---
	_draw_rounded_box(Rect2(join_card_rect.position + Vector2(0, 6), join_card_rect.size), 16.0, Color(0, 0, 0, 0.4), Color.TRANSPARENT, 0.0)
	_draw_rounded_box(join_card_rect, 16.0, Color("141c2c"), Color("ffe762") if not is_host and my_room_code != "" else Color("2a3c57"), 2.0)

	draw_string_outline(font, Vector2(join_card_rect.position.x, join_card_rect.position.y + 36), "🔗 JOIN FRIEND'S ROOM", HORIZONTAL_ALIGNMENT_CENTER, join_card_rect.size.x, 20, 4, Color.BLACK)
	draw_string(font, Vector2(join_card_rect.position.x, join_card_rect.position.y + 36), "🔗 JOIN FRIEND'S ROOM", HORIZONTAL_ALIGNMENT_CENTER, join_card_rect.size.x, 20, Color("ffe762"))

	draw_string(font, Vector2(join_card_rect.position.x, join_card_rect.position.y + 58), "Type your friend's 4-letter room code", HORIZONTAL_ALIGNMENT_CENTER, join_card_rect.size.x, 11, Color("94a3b8"))

	# 4 Big Letter Input Slots
	var slot_w: float = 64.0
	var slot_h: float = 78.0
	var slot_gap: float = 16.0
	var total_slot_w: float = 4.0 * slot_w + 3.0 * slot_gap
	var slot_start_x: float = join_card_rect.get_center().x - total_slot_w * 0.5
	var slot_y: float = join_card_rect.position.y + 90.0

	for i in range(4):
		var sx: float = slot_start_x + i * (slot_w + slot_gap)
		var s_box := Rect2(sx, slot_y, slot_w, slot_h)
		var has_char: bool = (join_code_input.length() > i)
		var is_cur: bool = (join_code_input.length() == i)
		var box_brd: Color = Color("41f3ff") if is_cur else (Color("ffe762") if has_char else Color("334155"))
		_draw_rounded_box(s_box, 10.0, Color("0b101c"), box_brd, 2.0 if (has_char or is_cur) else 1.2)

		if has_char:
			var ch: String = join_code_input.substr(i, 1)
			draw_string_outline(font, Vector2(sx, slot_y + 52), ch, HORIZONTAL_ALIGNMENT_CENTER, slot_w, 36, 4, Color.BLACK)
			draw_string(font, Vector2(sx, slot_y + 52), ch, HORIZONTAL_ALIGNMENT_CENTER, slot_w, 36, Color("ffe762"))
		elif is_cur:
			var blink: float = sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
			if blink > 0.35:
				draw_rect(Rect2(sx + slot_w * 0.25, slot_y + slot_h - 14, slot_w * 0.5, 4), Color("41f3ff"))

	draw_string(font, Vector2(join_card_rect.position.x, slot_y + slot_h + 20), "CLICK ANYWHERE & TYPE LETTERS (A-Z) ON KEYBOARD", HORIZONTAL_ALIGNMENT_CENTER, join_card_rect.size.x, 10, Color("94a3b8"))

	# Join Status Pill
	var join_pill_rect := Rect2(join_card_rect.position.x + 36, join_card_rect.position.y + 225, join_card_rect.size.x - 72, 38)
	var j_col: Color = Color("55ff99") if not is_host and my_room_code != "" else Color("64748b")
	var j_text: String = "● CONNECTED TO HOST! READY!" if not is_host and my_room_code != "" else "● ENTER 4 LETTERS & CLICK JOIN"
	_draw_rounded_box(join_pill_rect, 8.0, Color("0f172a"), j_col, 1.2)
	draw_string(font, Vector2(join_pill_rect.position.x, join_pill_rect.position.y + 24), j_text, HORIZONTAL_ALIGNMENT_CENTER, join_pill_rect.size.x, 12, j_col)

	# [JOIN ROOM] Button
	var can_join: bool = (join_code_input.length() == 4)
	var join_fill: Color = Color("7c3aed") if can_join else Color("1e293b")
	var join_brd: Color = Color("a78bfa") if can_join else Color("475569")
	_draw_bouncy_button(join_enter_btn_rect, btn_scales["join_btn"], join_fill, join_brd, "JOIN ROOM", 18)

	# --- 3. BOTTOM BAR: SERVER CONFIGURATION & STATUS ---
	_draw_rounded_box(server_url_bar_rect, 10.0, Color("0b101c"), Color("38ffff") if editing_server_url else Color("1e293b"), 1.8)
	var dot_col: Color = Color("55ff99") if (ws_client != null and ws_client.get_ready_state() == WebSocketPeer.STATE_OPEN) else Color("ef4444")
	draw_circle(Vector2(server_url_bar_rect.position.x + 18, server_url_bar_rect.get_center().y), 5.0, dot_col)

	var svr_text: String = "SERVER: " + signaling_server_url + (" [EDITING... PASTE: CTRL+V | ENTER]" if editing_server_url else " (CLICK TO EDIT)")
	draw_string(font, Vector2(server_url_bar_rect.position.x + 34, server_url_bar_rect.get_center().y + 5), svr_text, HORIZONTAL_ALIGNMENT_LEFT, 540, 11, Color("e2e8f0"))

	draw_string(font, Vector2(server_url_bar_rect.end.x - 340, server_url_bar_rect.get_center().y + 5), "STATUS: " + online_status, HORIZONTAL_ALIGNMENT_RIGHT, 320, 11, dot_col)

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

# --- Wave Transition Overlay ("wave n" with no dots) ---
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
