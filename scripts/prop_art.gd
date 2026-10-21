extends RefCounted
## 배경 소품 임시 도트(나무·덤불·종유석·야자수…). 캐릭터 도트와 같은 그리기 도구(pixel_art.gd)를 쓴다.
## 진짜 그림으로 바꾸려면 make() 가 텍스처를 돌려주는 자리만 load("res://art/props/…png") 로 바꾸면 된다.

const PixelArt := preload("res://scripts/pixel_art.gd")


static func make(kind: String, variant: int) -> ImageTexture:
	var img: Image
	match kind:
		"tree":
			img = _tree(variant)
		"bush":
			img = _bush(variant)
		"flower":
			img = _flower(variant)
		"stalagmite":
			img = _stalagmite(variant)
		"crystal":
			img = _crystal(variant)
		"rock":
			img = _rock(variant)
		"palm":
			img = _palm(variant)
		"shell":
			img = _shell(variant)
		_:
			img = _rock(variant)
	PixelArt._outline(img)
	return ImageTexture.create_from_image(img)


static func _blank(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## 둥근 잎 덩어리 세 겹. variant 로 잎 색을 조금씩 바꿔 숲이 단조롭지 않게.
static func _tree(v: int) -> Image:
	var img := _blank(34, 50)
	var leaf: Color = [Color(0.22, 0.5, 0.25), Color(0.28, 0.56, 0.22), Color(0.18, 0.44, 0.3)][v % 3]
	var leaf_d := leaf.darkened(0.35)
	var leaf_l := leaf.lightened(0.25)
	PixelArt._limb(img, Vector2(17, 49), Vector2(17, 28), 5.0, Color(0.42, 0.27, 0.15))
	PixelArt._limb(img, Vector2(15, 49), Vector2(15, 30), 1.5, Color(0.3, 0.19, 0.1))
	for blob: Array in [[Vector2(17, 28), 11.0], [Vector2(17, 18), 9.5], [Vector2(17, 9), 7.0]]:
		var c: Vector2 = blob[0]
		var r: float = blob[1]
		PixelArt._disc(img, c + Vector2(0, 1.5), r, leaf_d)
		PixelArt._disc(img, c, r - 1.0, leaf)
		PixelArt._disc(img, c + Vector2(-r * 0.35, -r * 0.35), r * 0.35, leaf_l)
	return img


static func _bush(v: int) -> Image:
	var img := _blank(26, 14)
	var leaf: Color = [Color(0.25, 0.52, 0.24), Color(0.2, 0.46, 0.28)][v % 2]
	for c: Vector2 in [Vector2(7, 9), Vector2(13, 7), Vector2(19, 9)]:
		PixelArt._disc(img, c + Vector2(0, 1), 6.0, leaf.darkened(0.3))
		PixelArt._disc(img, c, 5.0, leaf)
	if v % 2 == 0:
		PixelArt._disc(img, Vector2(10, 6), 1.2, Color(0.9, 0.25, 0.3))  # 산딸기
		PixelArt._disc(img, Vector2(17, 8), 1.2, Color(0.9, 0.25, 0.3))
	return img


static func _flower(v: int) -> Image:
	var img := _blank(9, 10)
	var petal: Color = [Color(0.98, 0.9, 0.3), Color(0.95, 0.5, 0.65), Color(0.95, 0.95, 0.95)][v % 3]
	PixelArt._limb(img, Vector2(4.5, 9.5), Vector2(4.5, 4), 1.0, Color(0.25, 0.55, 0.25))
	for off: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		PixelArt._disc(img, Vector2(4.5, 3.5) + off, 1.2, petal)
	PixelArt._px(img, 4, 3, Color(0.85, 0.55, 0.1))
	return img


static func _stalagmite(v: int) -> Image:
	var img := _blank(20, 40)
	var rock := Color(0.42, 0.38, 0.5) if v % 2 == 0 else Color(0.36, 0.34, 0.42)
	PixelArt._poly(img, [Vector2(2, 39), Vector2(18, 39), Vector2(11, 2 + v % 3 * 4)], rock)
	PixelArt._poly(img, [Vector2(2, 39), Vector2(8, 39), Vector2(11, 2 + v % 3 * 4)], rock.darkened(0.3))
	return img


static func _crystal(v: int) -> Image:
	var img := _blank(16, 22)
	var glow: Color = [Color(0.45, 0.9, 1.0), Color(0.75, 0.55, 1.0)][v % 2]
	PixelArt._poly(img, [Vector2(4, 21), Vector2(2, 9), Vector2(6, 1), Vector2(9, 9), Vector2(8, 21)], glow)
	PixelArt._poly(img, [Vector2(8, 21), Vector2(10, 11), Vector2(13, 6), Vector2(14, 14), Vector2(12, 21)], glow.darkened(0.25))
	PixelArt._limb(img, Vector2(5, 4), Vector2(4, 14), 1.0, Color(1, 1, 1, 0.9))
	return img


static func _rock(v: int) -> Image:
	var img := _blank(22, 14)
	var col: Color = [Color(0.5, 0.5, 0.52), Color(0.45, 0.42, 0.4), Color(0.55, 0.52, 0.48)][v % 3]
	PixelArt._disc(img, Vector2(11, 10), 8.0, col.darkened(0.3))
	PixelArt._disc(img, Vector2(10, 9), 7.0, col)
	PixelArt._disc(img, Vector2(7, 6), 2.0, col.lightened(0.2))
	return img


static func _palm(v: int) -> Image:
	var img := _blank(40, 54)
	var lean := 4.0 if v % 2 == 0 else -4.0
	var top := Vector2(20 + lean, 12)
	PixelArt._limb(img, Vector2(20, 53), Vector2(20 + lean * 0.5, 30), 4.0, Color(0.6, 0.45, 0.28))
	PixelArt._limb(img, Vector2(20 + lean * 0.5, 30), top, 3.5, Color(0.6, 0.45, 0.28))
	for k in 5:
		PixelArt._limb(img, Vector2(20, 53 - k * 8), Vector2(23, 53 - k * 8), 1.0, Color(0.45, 0.32, 0.2))
	var leaf := Color(0.25, 0.62, 0.3)
	for ang: float in [-160.0, -120.0, -60.0, -20.0, 200.0]:
		var d := Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang)) * 0.6 + 0.35)
		PixelArt._limb(img, top, top + d * 16.0, 3.0, leaf)
		PixelArt._limb(img, top + d * 8.0, top + d * 16.0 + Vector2(0, 2), 2.0, leaf.darkened(0.2))
	PixelArt._disc(img, top + Vector2(0, 2), 2.0, Color(0.45, 0.3, 0.15))  # 코코넛
	return img


static func _shell(v: int) -> Image:
	var img := _blank(9, 7)
	var col: Color = [Color(0.98, 0.8, 0.75), Color(0.95, 0.92, 0.85)][v % 2]
	PixelArt._disc(img, Vector2(4.5, 4.5), 3.5, col)
	for x in [2, 4, 6]:
		PixelArt._limb(img, Vector2(4.5, 6.5), Vector2(x, 2), 0.8, col.darkened(0.25))
	return img
