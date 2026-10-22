extends RefCounted
## 임시 도트 생성기. 진짜 그림(art/<캐릭터>/<동작>_<프레임수>.png)이 없는 동작에만 쓰인다.
## 관절 각도로 포즈를 정하는 작은 리그로 그리고 외곽선은 자동으로 두른다 —
## 프레임마다 픽셀을 손으로 찍지 않고도 여러 동작을 같은 비율로 뽑으려는 것.
## 각도는 0 = 아래, 90 = 앞(오른쪽), 180 = 위. 캐릭터는 오른쪽을 본다(왼쪽은 화면에서 flip).

const W := 56  # 칼·활이 앞으로 뻗어도 잘리지 않게 몸보다 넓게. 몸은 가로 중앙이라 flip 해도 제자리
const H := 48
const OX := W / 2 - 16  # 아래 좌표는 몸 중심 x=16 기준으로 적고 여기서 가운데로 민다
const GROUND := 46
const ARM := 10.0
const OUTLINE := Color(0.07, 0.05, 0.09)
const SKIN := Color(0.98, 0.84, 0.7)
const SKIN_D := Color(0.85, 0.63, 0.5)
const EYE := Color(0.1, 0.08, 0.12)
const WHITE := Color(0.95, 0.95, 0.92)

# 사람형 리그를 같이 쓰는 캐릭터의 색. 해골 무사는 검사 리그에 색만 바꾼 것
const SAMURAI := {
	"top": Color(0.82, 0.18, 0.2), "top_d": Color(0.55, 0.1, 0.14),
	"pants": Color(0.27, 0.29, 0.42), "pants_d": Color(0.17, 0.18, 0.28),
	"hair": Color(0.13, 0.1, 0.15), "skin": SKIN, "skin_d": SKIN_D, "eye": EYE,
	"collar": WHITE, "blade": Color(0.88, 0.9, 0.96), "topknot": true,
}
const SKELETON := {
	"top": Color(0.36, 0.3, 0.48), "top_d": Color(0.22, 0.18, 0.3),
	"pants": Color(0.16, 0.15, 0.2), "pants_d": Color(0.09, 0.08, 0.12),
	"hair": Color(0.88, 0.86, 0.78), "skin": Color(0.88, 0.86, 0.78), "skin_d": Color(0.66, 0.64, 0.56),
	"eye": Color(0.95, 0.25, 0.15), "collar": Color(0.85, 0.68, 0.2), "blade": Color(0.6, 0.95, 0.75),
	"topknot": false,
}

const BASE_POSE := {
	"bob": 0.0, "lean": 0.0, "fa": 20.0, "ba": -15.0, "fl": 8.0, "bl": -8.0,
	"wpn": 150.0, "eyes": "open", "draw": 0.0,
}


static func build(char_id: String) -> Dictionary:
	var poses: Dictionary
	match char_id:
		"sword", "skeleton":
			poses = _sword_poses()
		"slime", "king_slime", "mushroom":
			poses = _slime_poses()
		"bat":
			poses = _bat_poses()
		_:
			poses = _archer_poses()
	var out := {}
	for anim: String in poses:
		var texs: Array[Texture2D] = []
		for over: Dictionary in poses[anim]:
			var pose := BASE_POSE.duplicate()
			pose.merge(over, true)
			var img := render(char_id, pose)
			if pose.get("lie", false):
				img = _lying(img)
			texs.append(ImageTexture.create_from_image(img))
		out[anim] = texs
	return out


## 쓰러진 자세: 선 자세를 뒤로(반시계) 눕혀 바닥에 붙인다. 사람형 리그는 회전 관절이 없어서 그림째 돌린다.
static func _lying(src: Image) -> Image:
	var r := src.duplicate() as Image
	r.rotate_90(COUNTERCLOCKWISE)
	var used := r.get_used_rect()
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(r, used, Vector2i((W - used.size.x) / 2, GROUND + 1 - used.size.y))
	return out


static func _sword_poses() -> Dictionary:
	return {
		"idle": [{}, {"bob": 1.0}],
		"walk": [{"fl": 30.0, "bl": -25.0}, {"fl": 5.0, "bl": -5.0, "bob": 1.0},
			{"fl": -25.0, "bl": 30.0}, {"fl": 5.0, "bl": -5.0, "bob": 1.0}],
		# 베기: 머리 위에서 앞 아래로 대각선으로 내려친다
		"attack": [{"fa": 170.0, "wpn": 215.0, "lean": -1.0}, {"fa": 100.0, "wpn": 95.0, "lean": 2.0},
			{"fa": 65.0, "wpn": 60.0, "lean": 2.0}, {"fa": 35.0, "wpn": 120.0}],
		# 찌르기: 칼을 수평으로 겨눈 채 허리 뒤로 당겼다가, 다리를 크게 벌리며 팔을 일직선으로 뻗는다
		"attack_thrust": [{"fa": -20.0, "wpn": 90.0, "lean": -1.5, "fl": 15.0, "bl": -15.0},
			{"fa": -20.0, "wpn": 90.0, "lean": -1.5, "fl": 15.0, "bl": -15.0},
			{"fa": 90.0, "wpn": 90.0, "lean": 3.0, "fl": 40.0, "bl": -35.0},
			{"fa": 90.0, "wpn": 90.0, "lean": 3.0, "fl": 40.0, "bl": -35.0}, {"fa": 60.0, "wpn": 110.0, "lean": 1.0}],
		# 십자베기: 위에서 아래로 곧게 내려친 뒤(세로), 그대로 앞으로 가로베기
		"attack_cross": [{"fa": 175.0, "wpn": 180.0, "lean": -1.0, "bob": -1.0}, {"fa": 120.0, "wpn": 160.0},
			{"fa": 60.0, "wpn": 20.0, "lean": 2.0, "bob": 1.0}, {"fa": 90.0, "wpn": 90.0, "lean": 2.0},
			{"fa": 95.0, "wpn": 95.0, "lean": 2.0}, {"fa": 40.0, "wpn": 120.0}],
		# 발도술: 칼을 허리에 찬 채 낮게 웅크려 모았다가 한순간에 뽑아 올려 벤다. 웅크림을 여러 프레임 두어 "모으는" 시간을 만든다
		"attack_iai": [{"bob": 3.0, "lean": 1.5, "fa": -35.0, "wpn": 300.0, "fl": 30.0, "bl": -30.0, "eyes": "shut"},
			{"bob": 3.0, "lean": 1.5, "fa": -35.0, "wpn": 300.0, "fl": 30.0, "bl": -30.0, "eyes": "shut"},
			{"bob": 3.0, "lean": 1.5, "fa": -35.0, "wpn": 300.0, "fl": 30.0, "bl": -30.0, "eyes": "shut"},
			{"bob": 3.0, "lean": 1.5, "fa": -35.0, "wpn": 300.0, "fl": 30.0, "bl": -30.0},
			{"bob": 2.0, "lean": 3.0, "fa": 120.0, "wpn": 100.0, "fl": 45.0, "bl": -40.0},
			{"bob": 2.0, "lean": 3.0, "fa": 120.0, "wpn": 100.0, "fl": 45.0, "bl": -40.0},
			{"bob": 2.0, "lean": 2.0, "fa": 150.0, "wpn": 165.0, "fl": 40.0, "bl": -35.0},
			{"bob": 2.0, "lean": 2.0, "fa": 150.0, "wpn": 165.0, "fl": 40.0, "bl": -35.0},
			{"bob": 1.0, "fa": -30.0, "wpn": 300.0}],
		"hit": [{"lean": -2.0, "fa": -10.0, "ba": -40.0, "wpn": 200.0, "eyes": "shut"},
			{"lean": -1.0, "wpn": 170.0, "eyes": "shut"}],
		"guard": [{"bob": 3.0, "fa": 100.0, "ba": 70.0, "wpn": 178.0}],
		"die": [{"bob": 6.0, "lean": -3.0, "fa": -20.0, "ba": -30.0, "wpn": 200.0, "eyes": "shut"},
			{"lie": true, "fa": 60.0, "ba": -40.0, "wpn": 100.0, "eyes": "shut"}],
	}


static func _archer_poses() -> Dictionary:
	return {
		"idle": [{"fa": 30.0}, {"fa": 30.0, "bob": 1.0}],
		"walk": [{"fa": 30.0, "fl": 30.0, "bl": -25.0}, {"fa": 30.0, "fl": 5.0, "bl": -5.0, "bob": 1.0},
			{"fa": 30.0, "fl": -25.0, "bl": 30.0}, {"fa": 30.0, "fl": 5.0, "bl": -5.0, "bob": 1.0}],
		"attack": [{"fa": 90.0, "ba": 95.0, "draw": 0.4}, {"fa": 90.0, "ba": 85.0, "draw": 1.0, "lean": -1.0},
			{"fa": 90.0, "ba": -35.0, "lean": 1.0}, {"fa": 60.0, "ba": -10.0}],
		"hit": [{"lean": -2.0, "fa": -15.0, "ba": -40.0, "eyes": "shut"},
			{"lean": -1.0, "fa": 10.0, "eyes": "shut"}],
		"guard": [{"bob": 3.0, "fa": 100.0, "ba": 60.0}],
		"die": [{"bob": 6.0, "lean": -3.0, "fa": -10.0, "ba": -30.0, "eyes": "shut"},
			{"lie": true, "eyes": "shut"}],
	}


## 슬라임: sq = 눌림(+면 납작), fx = 앞으로 늘어남, lift = 뛰어오름, hard = 방어로 굳음.
static func _slime_poses() -> Dictionary:
	return {
		"idle": [{}, {"sq": 0.12}],
		"walk": [{"sq": 0.2}, {"sq": -0.15, "lift": 4.0}, {"sq": -0.1, "lift": 6.0}, {"sq": 0.15}],
		"attack": [{"sq": 0.25}, {"fx": 6.0, "sq": -0.1}, {"fx": 3.0}, {"sq": 0.05}],
		"hit": [{"sq": 0.35, "eyes": "shut"}, {"sq": 0.15, "eyes": "shut"}],
		"guard": [{"sq": 0.4, "hard": true}],
		"die": [{"sq": 0.5, "eyes": "shut"}, {"sq": 0.8, "eyes": "shut"}],
	}


## 박쥐: wing = 날개 각도(+면 위로), 공중에 떠 있다.
static func _bat_poses() -> Dictionary:
	return {
		"idle": [{"wing": 40.0}, {"wing": -30.0, "bob": 1.0}],
		"walk": [{"wing": 50.0}, {"wing": -40.0}, {"wing": 50.0}, {"wing": -40.0}],
		"attack": [{"wing": 60.0, "fx": -2.0}, {"wing": -50.0, "fx": 6.0}, {"wing": 10.0, "fx": 3.0}, {"wing": 30.0}],
		"hit": [{"wing": -60.0, "bob": 2.0, "eyes": "shut"}, {"wing": 0.0, "eyes": "shut"}],
		"guard": [{"wing": -80.0, "bob": 3.0}],
		"die": [{"wing": -70.0, "bob": 8.0, "eyes": "shut"}, {"wing": -85.0, "bob": 17.0, "eyes": "shut"}],
	}


static func render(char_id: String, p: Dictionary) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bob: float = p.bob
	var lean: float = p.lean
	var j := {}
	j.hip = Vector2(OX + 15, 30 + bob)
	j.neck = Vector2(OX + 15 + lean, 19 + bob)
	j.head = Vector2(OX + 16 + lean * 1.3, 12 + bob)
	j.sh_f = Vector2(OX + 18 + lean, 21 + bob)
	j.sh_b = Vector2(OX + 12 + lean, 21 + bob)
	j.hip_f = j.hip + Vector2(1.5, 0)
	j.hip_b = j.hip + Vector2(-1.5, 0)
	j.foot_f = _foot(j.hip_f, p.fl)
	j.foot_b = _foot(j.hip_b, p.bl)
	j.hand_f = j.sh_f + _dir(p.fa) * ARM
	# 시위를 당길수록 뒷손이 가슴 쪽으로 온다
	j.hand_b = j.sh_b + _dir(p.ba) * ARM * (1.0 - 0.6 * float(p.draw))
	match char_id:
		"sword":
			_draw_samurai(img, p, j, SAMURAI)
		"skeleton":
			_draw_samurai(img, p, j, SKELETON)
		"slime":
			_draw_slime(img, p, false)
		"king_slime":
			_draw_slime(img, p, true)
		"mushroom":
			_draw_mushroom(img, p)
		"bat":
			_draw_bat(img, p)
		_:
			_draw_archer(img, p, j)
	_outline(img)
	return img


static func _dir(deg: float) -> Vector2:
	return Vector2(sin(deg_to_rad(deg)), cos(deg_to_rad(deg)))


## 다리 각도와 상관없이 발끝이 땅(GROUND)에 닿도록 길이를 맞춘다 — 웅크리거나 걸을 때 공중에 뜨지 않게.
static func _foot(hip: Vector2, deg: float) -> Vector2:
	var c := maxf(cos(deg_to_rad(deg)), 0.5)
	return hip + _dir(deg) * ((GROUND - hip.y) / c)


# ---------------------------------------------------------------- 캐릭터

## 검사: 상투 튼 사무라이, 붉은 상의, 넓은 하카마, 긴 칼. 색(pal)만 바꿔 해골 무사로도 쓴다.
static func _draw_samurai(img: Image, p: Dictionary, j: Dictionary, pal: Dictionary) -> void:
	var red: Color = pal.top
	var red_d: Color = pal.top_d
	var pants: Color = pal.pants
	var pants_d: Color = pal.pants_d
	var hair: Color = pal.hair
	var skin: Color = pal.skin
	var sandal := Color(0.35, 0.22, 0.12)
	var n: Vector2 = j.neck
	var h: Vector2 = j.hip

	# 뒤쪽 팔다리를 어둡게 칠해 앞뒤 깊이를 만든다
	_limb(img, j.sh_b, j.hand_b, 4.0, red_d)
	_disc(img, j.hand_b, 1.6, pal.skin_d)
	_limb(img, j.hip_b, j.foot_b, 6.0, pants_d)
	_limb(img, j.foot_b, j.foot_b + Vector2(3, 0), 2.0, sandal)
	_limb(img, j.hip_f, j.foot_f, 6.0, pants)
	_limb(img, j.foot_f, j.foot_f + Vector2(3, 0), 2.0, sandal)

	_poly(img, [n + Vector2(-5, 0), n + Vector2(5, 0), h + Vector2(5, 1), h + Vector2(-6, 1)], red)
	_poly(img, [n + Vector2(-5, 0), n + Vector2(-2, 0), h + Vector2(-3, 1), h + Vector2(-6, 1)], red_d)
	var v := n.lerp(h, 0.55) + Vector2(2, 0)
	_limb(img, n + Vector2(0.5, 0), v, 1.2, pal.collar)
	_limb(img, n + Vector2(3.5, 0), v, 1.2, pal.collar)
	_limb(img, h + Vector2(-6, -1), h + Vector2(5, -1), 2.2, Color(0.15, 0.15, 0.25))

	_head(img, j.head, hair, p.eyes, skin, pal.skin_d, pal.eye)
	if pal.topknot:
		_disc(img, j.head + Vector2(-5, -5), 2.2, hair)

	var hf: Vector2 = j.hand_f
	var bd := _dir(p.wpn)
	_limb(img, hf - bd * 4.0, hf, 2.2, Color(0.25, 0.15, 0.1))
	_limb(img, hf, hf + bd * 15.0, 1.6, pal.blade)
	_disc(img, hf + bd * 0.8, 1.3, Color(0.85, 0.7, 0.2))
	_limb(img, j.sh_f, hf, 4.0, red)
	_disc(img, hf, 1.7, skin)


## 궁수: 초록 두건과 망토, 가죽 튜닉, 장화, 등에 화살통.
static func _draw_archer(img: Image, p: Dictionary, j: Dictionary) -> void:
	var cloak := Color(0.16, 0.5, 0.42)
	var cloak_d := Color(0.09, 0.32, 0.28)
	var leather := Color(0.58, 0.38, 0.2)
	var leather_d := Color(0.4, 0.25, 0.13)
	var pants := Color(0.32, 0.24, 0.18)
	var boots := Color(0.18, 0.12, 0.1)
	var n: Vector2 = j.neck
	var h: Vector2 = j.hip
	var c: Vector2 = j.head

	_poly(img, [n + Vector2(-4, -1), n + Vector2(0, -1), h + Vector2(-3, 9), h + Vector2(-9, 8)], cloak_d)
	_limb(img, n + Vector2(-5, -3), n + Vector2(-2, 9), 3.0, leather_d)
	for k in 3:
		_px(img, int(n.x) - 6 + k, int(n.y) - 5, WHITE)

	_limb(img, j.sh_b, j.hand_b, 3.0, cloak_d)
	_disc(img, j.hand_b, 1.4, SKIN_D)
	for leg in [[j.hip_b, j.foot_b, pants.darkened(0.3)], [j.hip_f, j.foot_f, pants]]:
		var a: Vector2 = leg[0]
		var b: Vector2 = leg[1]
		_limb(img, a, b, 3.5, leg[2])
		_limb(img, a.lerp(b, 0.6), b, 3.8, boots)
		_limb(img, b, b + Vector2(2.5, 0), 2.0, boots)

	_poly(img, [n + Vector2(-4, 0), n + Vector2(4, 0), h + Vector2(4, 2), h + Vector2(-4, 2)], leather)
	_poly(img, [n + Vector2(-4, 0), n + Vector2(-2, 0), h + Vector2(-2, 2), h + Vector2(-4, 2)], leather_d)
	_limb(img, h + Vector2(-4, -1), h + Vector2(4, -1), 1.6, Color(0.25, 0.16, 0.1))

	_disc(img, c + Vector2(-1, -0.5), 7.0, cloak)
	_disc(img, c + Vector2(-6, -4), 1.6, cloak)
	_disc(img, c + Vector2(1.5, 1.0), 4.6, SKIN)
	_limb(img, c + Vector2(-0.5, -2.5), c + Vector2(4.5, -2.5), 1.4, Color(0.75, 0.45, 0.2))
	_eyes(img, c + Vector2(0.5, 0.5), p.eyes)
	_px(img, int(c.x) + 5, int(c.y) + 4, SKIN_D)

	_bow(img, p, j)
	_limb(img, j.sh_f, j.hand_f, 3.0, cloak)
	_disc(img, j.hand_f, 1.5, SKIN)


## 활은 앞손을 중심으로 팔 방향으로 볼록한 호. 당기는 중이면 시위가 뒷손까지 오고 화살이 걸린다.
static func _bow(img: Image, p: Dictionary, j: Dictionary) -> void:
	var hand: Vector2 = j.hand_f
	var dir: Vector2 = (j.hand_f - j.sh_f).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var pts: Array[Vector2] = []
	for k in 9:
		var t := lerpf(-PI / 2, PI / 2, k / 8.0)
		pts.append(hand + perp * sin(t) * 9.0 + dir * cos(t) * 3.0)
	for k in 8:
		_limb(img, pts[k], pts[k + 1], 1.6, Color(0.5, 0.3, 0.12))
	var drawing := float(p.draw) > 0.0
	var nock: Vector2 = j.hand_b if drawing else hand
	_limb(img, pts[0], nock, 1.0, WHITE)
	_limb(img, pts[8], nock, 1.0, WHITE)
	if float(p.draw) > 0.5:
		_limb(img, nock, nock + dir * 14.0, 1.0, Color(0.6, 0.4, 0.18))
		_disc(img, nock + dir * 14.0, 1.0, Color(0.75, 0.78, 0.82))


## 얼굴은 앞(오른쪽), 정수리·뒤통수는 머리카락. 3/4 측면이라 눈 두 개가 앞쪽에 몰린다.
static func _head(img: Image, c: Vector2, hair: Color, eyes: String,
		skin := SKIN, skin_d := SKIN_D, eye := EYE) -> void:
	_disc(img, c, 6.0, skin)
	for y in range(int(c.y) - 7, int(c.y) + 8):
		for x in range(int(c.x) - 7, int(c.x) + 8):
			var d := Vector2(x + 0.5, y + 0.5) - c
			if d.length() <= 6.0 and (d.y < -2.0 or d.x < -1.5 + d.y * 0.3):
				_px(img, x, y, hair)
	for dx: int in [1, 3, 5]:
		_px(img, int(c.x) + dx, int(c.y) - 2, hair)
	_eyes(img, c, eyes, eye)
	_px(img, int(c.x) + 5, int(c.y) + 3, skin_d)


static func _eyes(img: Image, c: Vector2, state: String, eye := EYE) -> void:
	var ey := int(c.y)
	for ex: int in [int(c.x) + 1, int(c.x) + 4]:
		if state == "shut":
			_px(img, ex, ey + 1, eye)
			_px(img, ex + 1, ey + 1, eye)
		else:
			_px(img, ex, ey, eye)
			_px(img, ex, ey + 1, eye)
			_px(img, ex + 1, ey + 1, eye)
			_px(img, ex + 1, ey, Color.WHITE)


## 킹슬라임은 같은 몸에 파란색 + 왕관. 화면 크기는 cards.gd 의 scale 로 키운다.
static func _draw_slime(img: Image, p: Dictionary, king: bool) -> void:
	var sq: float = p.get("sq", 0.0)
	var green := Color(0.3, 0.55, 0.95) if king else Color(0.35, 0.8, 0.35)
	var green_d := Color(0.18, 0.33, 0.7) if king else Color(0.2, 0.55, 0.25)
	if p.get("hard", false):
		green = green.darkened(0.3)
		green_d = green_d.darkened(0.3)
	var rx := 11.0 * (1.0 + sq)
	var ry := 9.0 * (1.0 - sq)
	var c := Vector2(W / 2.0 + float(p.get("fx", 0.0)), GROUND - ry - float(p.get("lift", 0.0)))
	for y in range(floori(c.y - ry), ceili(c.y + ry) + 1):
		for x in range(floori(c.x - rx), ceili(c.x + rx) + 1):
			var d := Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / ry)
			if d.length_squared() <= 1.0 and y <= GROUND:
				_px(img, x, y, green_d if d.y > 0.4 else green)
	_disc(img, c + Vector2(-rx * 0.45, -ry * 0.45), 1.6, Color(0.85, 0.92, 1.0) if king else Color(0.8, 1.0, 0.75))
	_eyes(img, c + Vector2(rx * 0.15, -ry * 0.25), p.eyes)
	if king:
		var top := c.y - ry
		var gold := Color(0.98, 0.8, 0.2)
		_poly(img, [Vector2(c.x - 6, top + 1), Vector2(c.x - 6, top - 4), Vector2(c.x - 3, top - 1.5),
			Vector2(c.x, top - 5), Vector2(c.x + 3, top - 1.5), Vector2(c.x + 6, top - 4), Vector2(c.x + 6, top + 1)], gold)
		_px(img, int(c.x), int(top - 2), Color(0.9, 0.2, 0.25))


## 독버섯: 붉은 갓에 흰 점, 베이지 기둥에 얼굴. 슬라임과 같은 포즈 값(sq·fx·lift)을 쓴다.
static func _draw_mushroom(img: Image, p: Dictionary) -> void:
	var sq: float = p.get("sq", 0.0)
	var lift: float = p.get("lift", 0.0)
	var fx: float = p.get("fx", 0.0)
	var cap := Color(0.85, 0.2, 0.22)
	var cap_d := Color(0.58, 0.12, 0.16)
	var stem := Color(0.95, 0.88, 0.72)
	var stem_d := Color(0.78, 0.68, 0.52)
	if p.get("hard", false):
		cap = cap.darkened(0.3)
		cap_d = cap_d.darkened(0.3)
	var foot := GROUND - lift
	var sh := 12.0 * (1.0 - sq)  # 기둥 높이
	var cx := W / 2.0 + fx * 0.5
	_limb(img, Vector2(cx - 3, foot - 1), Vector2(cx - 5, foot), 2.0, stem_d)
	_limb(img, Vector2(cx + 3, foot - 1), Vector2(cx + 5, foot), 2.0, stem_d)
	_poly(img, [Vector2(cx - 5, foot - 1), Vector2(cx + 5, foot - 1), Vector2(cx + 4, foot - sh), Vector2(cx - 4, foot - sh)], stem)
	_poly(img, [Vector2(cx - 5, foot - 1), Vector2(cx - 2, foot - 1), Vector2(cx - 2, foot - sh), Vector2(cx - 4, foot - sh)], stem_d)
	_eyes(img, Vector2(cx - 0.5, foot - sh * 0.62), p.eyes)
	# 갓: 반타원. 공격(fx)할 땐 앞으로 기울어 들이받는 느낌
	var crx := 13.0 * (1.0 + sq * 0.6)
	var cry := 9.0 * (1.0 - sq * 0.5)
	var cc := Vector2(cx + fx, foot - sh + 1)
	for y in range(floori(cc.y - cry), ceili(cc.y) + 1):
		for x in range(floori(cc.x - crx), ceili(cc.x + crx) + 1):
			var d := Vector2((x + 0.5 - cc.x) / crx, (y + 0.5 - cc.y) / cry)
			if d.length_squared() <= 1.0:
				_px(img, x, y, cap_d if d.y > -0.25 else cap)
	for off: Vector2 in [Vector2(-6, -4), Vector2(1, -6.5), Vector2(6, -3), Vector2(-1, -2)]:
		_disc(img, cc + off, 1.3, WHITE)


static func _draw_bat(img: Image, p: Dictionary) -> void:
	var body := Color(0.4, 0.31, 0.48)
	var body_d := Color(0.26, 0.19, 0.32)
	var c := Vector2(W / 2.0 + float(p.get("fx", 0.0)), 24.0 + float(p.bob))
	var lift := sin(deg_to_rad(float(p.get("wing", 0.0))))
	# 뒤 날개를 먼저, 어둡게
	for side: int in [-1, 1]:
		var root := c + Vector2(side * 3, -1)
		var tip := root + Vector2(side * 14, -lift * 10.0)
		var col := body_d if side < 0 else Color(0.33, 0.24, 0.4)
		_poly(img, [root, tip, root + Vector2(side * 10, 6 - lift * 3.0), root + Vector2(side * 4, 5)], col)
	_disc(img, c, 5.5, body)
	_disc(img, c + Vector2(0, 2.5), 3.5, body_d)
	_poly(img, [c + Vector2(-4, -3), c + Vector2(-3, -9), c + Vector2(-1, -4)], body)
	_poly(img, [c + Vector2(1, -4), c + Vector2(3, -9), c + Vector2(4, -3)], body)
	_eyes(img, c + Vector2(-1.5, -2), p.eyes, Color(0.95, 0.85, 0.2))
	_px(img, int(c.x) + 2, int(c.y) + 3, WHITE)
	_px(img, int(c.x) + 4, int(c.y) + 3, WHITE)


# ---------------------------------------------------------------- 그리기 도구

## 그리기 도구는 캐릭터 프레임(W×H)과 배경 소품(prop_art.gd, 크기 제각각)이 같이 쓴다 → 크기는 이미지에서 읽는다.
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				_px(img, x, y, col)


## 두께 있는 선분. 픽셀 중심에서 선분까지 거리로 칠해 각도가 바뀌어도 두께가 고르다.
static func _limb(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var r := w / 2.0
	for y in range(floori(minf(a.y, b.y) - r), ceili(maxf(a.y, b.y) + r) + 1):
		for x in range(floori(minf(a.x, b.x) - r), ceili(maxf(a.x, b.x) + r) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) <= r:
				_px(img, x, y, col)


static func _poly(img: Image, pts: Array, col: Color) -> void:
	var poly := PackedVector2Array(pts)
	var lo := poly[0]
	var hi := poly[0]
	for v in poly:
		lo = lo.min(v)
		hi = hi.max(v)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				_px(img, x, y, col)


## 투명 픽셀 중 상하좌우에 칠해진 픽셀이 있으면 외곽선. 애니 풍 도트의 진한 테두리.
static func _outline(img: Image, col := OUTLINE) -> void:
	var src := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in dirs:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h and src.get_pixelv(q).a > 0.0:
					img.set_pixel(x, y, col)
					break
