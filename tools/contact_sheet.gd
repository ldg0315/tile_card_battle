extends SceneTree
## 스크린샷 여러 장을 한 장의 격자로 모은다(연출 프레임을 나란히 비교하려고).
##   godot --headless --path . -s tools/contact_sheet.gd -- 출력.png 열수 입력1.png 입력2.png …

const TILE_W := 640


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		print("사용법: -- 출력.png 열수 입력1.png …")
		quit(1)
		return
	var out: String = args[0]
	var cols := int(args[1])
	var imgs: Array[Image] = []
	for path in args.slice(2):
		var img := Image.load_from_file(path)
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)  # 스크린샷은 RGB8 이라 그대로면 blit_rect 가 조용히 실패한다
		img.resize(TILE_W, int(img.get_height() * float(TILE_W) / img.get_width()), Image.INTERPOLATE_BILINEAR)
		imgs.append(img)
	var tile_h := imgs[0].get_height()
	var rows := ceili(imgs.size() / float(cols))
	var sheet := Image.create(cols * TILE_W, rows * tile_h, false, Image.FORMAT_RGBA8)
	for k in imgs.size():
		sheet.blit_rect(imgs[k], Rect2i(Vector2i.ZERO, imgs[k].get_size()), Vector2i(k % cols * TILE_W, k / cols * tile_h))
	sheet.save_png(out)
	print("saved ", out)
	quit()
