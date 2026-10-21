extends SceneTree
## 임시 효과음을 wav 파일로 뽑아 귀로 확인하는 개발 도구.
##   godot --headless --path . -s tools/dump_sfx.gd -- 출력폴더

const Synth := preload("res://scripts/sfx_synth.gd")


func _init() -> void:
	var dir := "res://shots/sfx"
	if not OS.get_cmdline_user_args().is_empty():
		dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dir)
	# 하나씩 + 전부 이어 붙인 미리듣기(_all.wav, 소리 사이 0.4초 쉼)
	var all := PackedByteArray()
	var gap := PackedByteArray()
	gap.resize(int(Synth.RATE * 0.4) * 2)
	for name: String in Synth.PRESETS:
		var s := Synth.make(name)
		s.save_to_wav("%s/%s.wav" % [dir, name])
		all.append_array(s.data)
		all.append_array(gap)
	var joined := Synth.make("click")
	joined.data = all
	joined.save_to_wav("%s/_all.wav" % dir)
	print("saved %d sounds to %s" % [Synth.PRESETS.size(), dir])
	quit()
