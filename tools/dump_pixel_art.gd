extends SceneTree
## 임시 도트 전 프레임을 한 장으로 확대 저장해 눈으로 확인하는 개발 도구.
##   godot --headless --path . -s tools/dump_pixel_art.gd -- 출력.png

const PixelArt := preload("res://scripts/pixel_art.gd")
const SCALE := 4


func _init() -> void:
	var out := "res://shots/pixel_art.png"
	if not OS.get_cmdline_user_args().is_empty():
		out = OS.get_cmdline_user_args()[0]
	var rows := []
	for char_id in ["sword", "archer", "slime", "mushroom", "king_slime", "bat", "skeleton"]:
		var anims: Dictionary = PixelArt.build(char_id)
		var row: Array[Image] = []
		for anim: String in anims:
			for t: Texture2D in anims[anim]:
				row.append(t.get_image())
		rows.append(row)
	var cols := 0
	for row: Array in rows:
		cols = maxi(cols, row.size())
	var sheet := Image.create(cols * PixelArt.W, rows.size() * PixelArt.H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.35, 0.4, 0.35))
	for r in rows.size():
		for c in rows[r].size():
			var img: Image = rows[r][c]
			sheet.blend_rect(img, Rect2i(0, 0, PixelArt.W, PixelArt.H), Vector2i(c * PixelArt.W, r * PixelArt.H))
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out)
	print("saved ", out)
	quit()
