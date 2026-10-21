extends Node
## 효과음·배경음악. 오토로드 "Sound".
## audio/sfx/<이름>.wav|ogg 가 있으면 그 파일을, 없으면 sfx_synth 의 임시 8비트 소리를 쓴다.
## 배경음악도 audio/bgm/<이름>.ogg|wav 가 있으면 그 파일을, 없으면 bgm_synth 의 임시 칩튠 곡을(있는 곡만) 튼다.
## 규칙은 audio/README.md 참고.

const Synth := preload("res://scripts/sfx_synth.gd")
const BgmSynth := preload("res://scripts/bgm_synth.gd")
const SFX_DIR := "res://audio/sfx"
const BGM_DIR := "res://audio/bgm"
const POOL := 12  # 동시에 겹쳐 날 수 있는 효과음 수(화살비처럼 한꺼번에 여러 개)
const BGM_FADE := 0.8

var _cache := {}  # 이름 → AudioStream (없으면 null 도 기억해 매번 디스크를 뒤지지 않게)
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bgm: AudioStreamPlayer
var _bgm_name := ""
var _bgm_cache := {}  # 합성한 곡은 한 번만 만든다


func _ready() -> void:
	# 음악과 효과음 볼륨을 따로 조절할 수 있게 버스를 나눈다(나중에 설정 화면에서 쓰려고)
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# 화살비처럼 여러 소리가 한꺼번에 겹치면 합이 최대치를 넘어 찢어진다 → 효과음 버스와 마스터에 리미터
	for bus in ["SFX", "Master"]:
		var idx := AudioServer.get_bus_index(bus)
		if AudioServer.get_bus_effect_count(idx) == 0:
			var lim := AudioEffectHardLimiter.new()
			lim.ceiling_db = -1.0
			AudioServer.add_bus_effect(idx, lim)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -3.0)
	for k in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Music"
	add_child(_bgm)


## 위치 없는 효과음(UI 등). 같은 소리가 반복돼도 덜 거슬리게 음높이를 조금씩 흔든다.
func play(name: String, volume_db := 0.0, jitter := 0.05) -> void:
	var s := _sfx(name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.play()


## 3D 위치에서 나는 효과음. 1인칭에서 뒤쪽 적의 공격이 뒤에서 들리게 하려고.
## 3인칭 카메라는 보드에서 멀어서 거리 감쇠는 약하게 둔다(소리가 작아지지 않게).
func play_at(name: String, pos: Vector3, volume_db := 0.0, jitter := 0.05) -> void:
	var s := _sfx(name)
	var scene := get_tree().current_scene
	if s == null or not (scene is Node3D):
		play(name, volume_db, jitter)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = "SFX"
	p.unit_size = 14.0
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-jitter, jitter)
	p.position = pos
	scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## 배경음악 전환. 같은 곡이면 이어서 틀고, 파일이 없으면 지금 곡을 페이드아웃만 한다.
func play_bgm(name: String) -> void:
	if name == _bgm_name:
		return
	_bgm_name = name
	var s := _load(BGM_DIR, name)
	if s == null and BgmSynth.has(name):
		if not _bgm_cache.has(name):
			_bgm_cache[name] = BgmSynth.make(name)
		s = _bgm_cache[name]
	var tw := create_tween()
	if _bgm.playing:
		tw.tween_property(_bgm, "volume_db", -40.0, BGM_FADE * 0.5)
	tw.tween_callback(func() -> void:
		_bgm.stop()
		if s == null:
			return
		if s is AudioStreamOggVorbis or s is AudioStreamMP3:
			s.loop = true
		elif s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.data.size() / (2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if s.stereo else 1)
		_bgm.stream = s
		_bgm.volume_db = -40.0
		_bgm.play())
	tw.tween_property(_bgm, "volume_db", -6.0, BGM_FADE)


func _sfx(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s := _load(SFX_DIR, name)
	if s == null and Synth.has(name):
		s = Synth.make(name)
	_cache[name] = s
	return s


## 에디터가 임포트한 파일이면 리소스로, 방금 넣어 아직 임포트 전이면 파일에서 바로 읽는다
## (그림과 같은 이유 — 에디터를 열지 않고 게임만 실행해도 새 소리가 들리게).
func _load(dir: String, name: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s/%s.%s" % [dir, name, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			match ext:
				"ogg":
					return AudioStreamOggVorbis.load_from_file(abs_path)
				"wav":
					return AudioStreamWAV.load_from_file(abs_path)
				"mp3":
					var mp3 := AudioStreamMP3.new()
					mp3.data = FileAccess.get_file_as_bytes(abs_path)
					return mp3
	return null
