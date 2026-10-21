extends SceneTree
## 임시 배경음악을 wav 로 뽑아 귀로 확인하는 개발 도구.
##   godot --headless --path . -s tools/dump_bgm.gd -- 출력폴더

const Bgm := preload("res://scripts/bgm_synth.gd")


func _init() -> void:
	var dir := "res://shots/bgm"
	if not OS.get_cmdline_user_args().is_empty():
		dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in Bgm.SONGS:
		var t0 := Time.get_ticks_msec()
		Bgm.make(name).save_to_wav("%s/%s.wav" % [dir, name])
		print("%s: %d ms" % [name, Time.get_ticks_msec() - t0])
	quit()
