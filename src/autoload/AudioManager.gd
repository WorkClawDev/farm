extends Node

## AudioManager - 音频管理器
## 负责背景音乐、音效的播放和管理

signal music_changed(track_name: String)
signal sfx_played(sfx_name: String)

# 音频播放器
@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var ambient_player: AudioStreamPlayer = AudioStreamPlayer.new()

# 音量设置
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.5

# 当前播放的曲目
var current_music: String = ""
var current_location: String = "farm"  # farm, village, forest
var _music_tween: Tween = null

const BGM_SCHEDULE := {
	"farm_morning":   "res://assets/audio/bgm/farm/farm_morning.ogg",
	"farm_day":       "res://assets/audio/bgm/farm/farm_day.ogg",
	"farm_evening":   "res://assets/audio/bgm/farm/farm_evening.ogg",
	"farm_night":     "res://assets/audio/bgm/farm/farm_night.ogg",
	"village_day":    "res://assets/audio/bgm/village/village_day.ogg",
	"village_night":  "res://assets/audio/bgm/village/village_night.ogg",
	"forest_day":     "res://assets/audio/bgm/forest/forest_day.ogg",
	"forest_night":   "res://assets/audio/bgm/forest/forest_night.ogg",
	# Beach / mine / house reuse outdoor tracks (no dedicated stems yet) — BUG-52.
	"beach_morning":  "res://assets/audio/bgm/farm/farm_morning.ogg",
	"beach_day":      "res://assets/audio/bgm/farm/farm_day.ogg",
	"beach_evening":  "res://assets/audio/bgm/farm/farm_evening.ogg",
	"beach_night":    "res://assets/audio/bgm/farm/farm_night.ogg",
	"mine_day":       "res://assets/audio/bgm/forest/forest_day.ogg",
	"mine_night":     "res://assets/audio/bgm/forest/forest_night.ogg",
	"house_day":      "res://assets/audio/bgm/farm/farm_day.ogg",
	"house_night":    "res://assets/audio/bgm/farm/farm_night.ogg",
	"festival_main":  "res://assets/audio/bgm/festival/festival_main.ogg",
	"festival_harvest":"res://assets/audio/bgm/festival/festival_harvest.ogg",
}
var current_ambient: String = ""

func _ready() -> void:
	print("[AudioManager] Initialized")
	_setup_players()
	# Drive BGM from in-game clock, not the host OS clock (BUG-52).
	call_deferred("_connect_time_manager")

## Quitting while a track plays left its Ogg playback referenced in the audio
## server ("2 resources still in use at exit"). The server drops a stopped
## playback on its next mix, so stop early (quit_game waits a few frames).
func release_streams() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	for player in [music_player, ambient_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		release_streams()

func _exit_tree() -> void:
	release_streams()

func _setup_players() -> void:
	# 设置音乐播放器
	music_player.bus = "Music"
	music_player.name = "MusicPlayer"
	add_child(music_player)
	
	# 设置环境音播放器
	ambient_player.bus = "Ambient"
	ambient_player.name = "AmbientPlayer"
	add_child(ambient_player)
	
	# 创建音频总线
	_setup_audio_buses()

func _setup_audio_buses() -> void:
	# 确保音频总线存在
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
	
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "SFX")
	
	if AudioServer.get_bus_index("Ambient") == -1:
		AudioServer.add_bus(3)
		AudioServer.set_bus_name(3, "Ambient")
	
	_update_volumes()

func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if current_music == track_name:
		return
	
	var path: String = "res://assets/audio/bgm/" + track_name + ".ogg"
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		music_player.stream = stream
		music_player.play()
		current_music = track_name
		music_changed.emit(track_name)
		print("[AudioManager] Playing music: ", track_name)
	else:
		push_warning("[AudioManager] Music track not found: " + path)

func update_location_bgm(location: String) -> void:
	"""切换场景时更新 BGM."""
	current_location = location
	if DisplayServer.get_name() == "headless":
		return
	_update_time_bgm()


func _connect_time_manager() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm and not tm.time_changed.is_connected(_on_game_time_changed):
		tm.time_changed.connect(_on_game_time_changed)


func _on_game_time_changed(_new_time: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_update_time_bgm()


func _game_hour() -> int:
	var tm := get_node_or_null("/root/TimeManager")
	if tm:
		return int(fposmod(float(tm.current_time), 24.0))
	return 12


func _update_time_bgm() -> void:
	"""Update BGM from in-game TimeManager hour (BUG-52)."""
	var hour: int = _game_hour()
	var track_key: String

	if hour >= 6 and hour < 9:
		track_key = current_location + "_morning"
	elif hour >= 9 and hour < 17:
		track_key = current_location + "_day"
	elif hour >= 17 and hour < 20:
		track_key = current_location + "_evening"
	else:
		track_key = current_location + "_night"

	var path: String = BGM_SCHEDULE.get(track_key, "")
	if path == "":
		# Period missing for this map: fall back to day, then farm_day.
		if BGM_SCHEDULE.has(current_location + "_day"):
			track_key = current_location + "_day"
			path = BGM_SCHEDULE[track_key]
		else:
			track_key = "farm_day"
			path = BGM_SCHEDULE.get("farm_day", "")
	if path != "" and ResourceLoader.exists(path):
		_crossfade_to(path, track_key)
	elif path == "":
		print("[AudioManager] No BGM for time slot: ", track_key)



func _crossfade_to(path: String, track_name: String) -> void:
	"""淡入淡出切换曲目."""
	if music_player.playing and current_music == track_name:
		return
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("[AudioManager] Could not load: " + path)
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	var target_volume := linear_to_db(music_volume)
	if not music_player.playing:
		_start_music_stream(stream, track_name, target_volume)
		return
	_music_tween = create_tween()
	_music_tween.tween_property(music_player, "volume_db", -80.0, 0.35)
	_music_tween.tween_callback(_start_music_stream.bind(stream, track_name, target_volume))


func _start_music_stream(stream: AudioStream, track_name: String, target_volume: float) -> void:
	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = target_volume
	music_player.play()
	current_music = track_name
	music_changed.emit(track_name)
	print("[AudioManager] Crossfade to: ", track_name)


func stop_music(fade_duration: float = 1.0) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	music_player.stop()
	music_player.stream = null
	current_music = ""
	print("[AudioManager] Music stopped")

func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	var path: String = "res://assets/audio/sfx/" + sfx_name + ".wav"
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = volume_db
		player.bus = "SFX"
		player.name = "SFX_" + sfx_name
		add_child(player)
		player.play()
		
		# 播放完成后自动删除
		player.finished.connect(func(): player.queue_free())
		
		sfx_played.emit(sfx_name)
	else:
		push_warning("[AudioManager] SFX not found: " + path)

func play_ambient(ambient_name: String) -> void:
	if current_ambient == ambient_name:
		return
	
	var path: String = "res://assets/audio/ambient/" + ambient_name + ".ogg"
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		ambient_player.stream = stream
		ambient_player.play()
		current_ambient = ambient_name
		print("[AudioManager] Playing ambient: ", ambient_name)
	else:
		push_warning("[AudioManager] Ambient track not found: " + path)

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func set_ambient_volume(volume: float) -> void:
	ambient_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()

func _update_volumes() -> void:
	var music_bus: int = AudioServer.get_bus_index("Music")
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	var ambient_bus: int = AudioServer.get_bus_index("Ambient")
	
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume * master_volume))
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume * master_volume))
	if ambient_bus != -1:
		AudioServer.set_bus_volume_db(ambient_bus, linear_to_db(ambient_volume * master_volume))

func mute_all() -> void:
	AudioServer.set_bus_mute(0, true)

func unmute_all() -> void:
	AudioServer.set_bus_mute(0, false)
