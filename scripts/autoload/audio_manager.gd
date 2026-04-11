extends Node

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

var _sfx_library: Dictionary = {}
var _music_library: Dictionary = {}

var _gs: Node

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_sfx_player = AudioStreamPlayer.new()
	add_child(_music_player)
	add_child(_sfx_player)
	_gs = get_node("/root/GameState")
	_gs.time_direction_changed.connect(_on_time_direction_changed)
	_gs.level_completed.connect(_on_level_completed)

func register_sfx(sfx_name: String, stream: AudioStream) -> void:
	_sfx_library[sfx_name] = stream

func register_music(track_name: String, stream: AudioStream) -> void:
	_music_library[track_name] = stream

func play_sfx(sfx_name: String) -> void:
	if sfx_name in _sfx_library:
		_sfx_player.stream = _sfx_library[sfx_name]
		_sfx_player.play()

func play_music(track_name: String) -> void:
	if track_name in _music_library:
		_music_player.stream = _music_library[track_name]
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func _on_time_direction_changed(direction: int) -> void:
	if direction == get_node("/root/GameState").TIME_REWIND:
		play_sfx("rewind")
	else:
		play_sfx("forward")

func _on_level_completed() -> void:
	play_sfx("win")
	stop_music()
