extends RefCounted
## 도트 그림 두 장(옆모습·정면)으로 복셀(작은 정육면체) 입체 모델을 만든다.
## 빌보드(카메라를 향해 도는 판)는 시점을 조금만 옮겨도 그림이 그대로라 "판에 그린 그림"으로 보였다.
## 줄(높이)마다 옆모습의 폭과 정면의 폭을 두 반지름으로 하는 타원 단면을 쌓아 둥근 몸을 만든다.
## (두 실루엣을 그냥 겹쳐 깎으면 단면이 네모라 베개처럼 각진 덩어리가 됐다.)
## 슬라임처럼 대칭인 단순한 몸에 잘 맞는다. 팔다리가 많은 사람형은 두 장으로는 모양이 안 나온다.
##
## 좌표: 몸은 +X 를 본다. 옆모습 그림의 가로 = X(오른쪽이 앞), 세로 = Y. 정면 그림의 가로 = Z(앞에서 볼 때 오른쪽이 -Z).
## 한 칸 크기는 스프라이트의 pixel_size 와 같고, 그림 가운데가 원점 — 빌보드 스프라이트와 같은 자리·크기로 겹친다.

const ALPHA_MIN := 0.5


## frames(옆모습)·front(정면) SpriteFrames 의 모든 동작·프레임을 메시로. 반환: {동작: [ArrayMesh, ...]}
## 프레임 수는 옆모습 기준이고 정면은 같은 순번(없으면 마지막)을 쓴다.
static func build(frames: SpriteFrames, front: SpriteFrames, px: float) -> Dictionary:
	var out := {}
	for anim: String in frames.get_animation_names():
		var meshes: Array[ArrayMesh] = []
		var nf := front.get_frame_count(anim) if front.has_animation(anim) else 0
		for k in frames.get_frame_count(anim):
			var side := frames.get_frame_texture(anim, k).get_image()
			var face := side
			if nf > 0:
				face = front.get_frame_texture(anim, mini(k, nf - 1)).get_image()
			meshes.append(_mesh(side, face, px))
		out[anim] = meshes
	return out


static func _mesh(side: Image, face: Image, px: float) -> ArrayMesh:
	var w := side.get_width()
	var h := side.get_height()
	var d := face.get_width()
	# 줄마다 옆모습(X)·정면(Z)의 불투명 구간 → 타원 단면의 중심과 반지름
	var filled := {}
	var rows := {}  # y → [cx, rx, cz, rz]
	for y in h:
		var sx := _span(side, y)
		var fz := _span(face, y)
		if sx.x < 0 or fz.x < 0:
			continue
		var cx := (sx.x + sx.y + 1) / 2.0
		var rx := (sx.y - sx.x + 1) / 2.0
		var cz := (fz.x + fz.y + 1) / 2.0
		var rz := (fz.y - fz.x + 1) / 2.0
		rows[y] = [cx, rx, cz, rz]
		for x in range(sx.x, sx.y + 1):
			for z in range(fz.x, fz.y + 1):
				var u := (x + 0.5 - cx) / rx
				var t := (z + 0.5 - cz) / rz
				if u * u + t * t <= 1.0:
					filled[Vector3i(x, y, z)] = true
	# 눈(정면 그림 안쪽의 어두운 점·흰 반짝임)은 앞면에 한 칸 도드라지게 붙인다 — 면 색으로만 칠하면
	# 계단진 앞면에 조각조각 찍혀 눈으로 안 읽혔다
	var paint := {}  # 칸 → 강제 색
	for y: int in rows:
		for z in d:
			var c := face.get_pixel(z, y)
			if c.a < ALPHA_MIN or _is_edge(face, z, y):
				continue
			if not _is_feature(c):
				continue
			for x in range(w - 1, -1, -1):
				if filled.has(Vector3i(x, y, z)):
					var bump := Vector3i(x + 1, y, z)
					filled[bump] = true
					paint[bump] = c
					break
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin := Vector3(w / 2.0, h / 2.0, d / 2.0)
	for v: Vector3i in filled:
		for n: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if filled.has(v + n):
				continue
			# 몸의 앞쪽(+X 쪽 부채꼴)에 있는 면은 정면 그림(눈이 여기에만), 나머지는 옆모습 그림에서 눈 같은
			# 어두운 점을 지운 색 — 옆모습의 눈까지 옆면에 찍으면 비스듬히 볼 때 눈이 두 쌍 보였다
			if paint.has(v):
				_quad(st, v, n, paint[v], origin, px)
				continue
			var r: Array = rows[v.y]
			var u := (v.x + 0.5 - float(r[0])) / float(r[1])
			var t := (v.z + 0.5 - float(r[2])) / float(r[3])
			var col: Color
			if u > 0.35 and u > absf(t) * 0.9:
				col = _inner_color(face, v.z, v.y)
			else:
				col = _body_color(side, v.x, v.y)
			if n.y == 1:
				col = col.lightened(0.08)
			elif n.y == -1:
				col = col.darkened(0.3)
			_quad(st, v, n, col, origin, px)
	return st.commit()


## 테두리(투명과 맞닿은 칸)는 그림의 외곽선이라 검다. 입체에선 실루엣이 저절로 생기니, 테두리 칸의 색은
## 안쪽 이웃 칸 색으로 바꾼다 — 안 그러면 몸 윗면이 통째로 검게 칠해졌다. 눈처럼 안쪽의 어두운 칸은 그대로.
static func _inner_color(img: Image, x: int, y: int) -> Color:
	if not _is_edge(img, x, y):
		return img.get_pixel(x, y)
	var c := Vector2(img.get_used_rect().get_center())
	var step := (c - Vector2(x, y)).normalized()
	for k in range(1, 4):
		var p := Vector2i(Vector2(x, y) + step * k)
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() \
				and img.get_pixel(p.x, p.y).a >= ALPHA_MIN and not _is_edge(img, p.x, p.y):
			return img.get_pixel(p.x, p.y)
	return img.get_pixel(x, y)


## 옆모습 색에서 눈(몸 안쪽의 어두운 점)을 지운다: 어두우면 위아래로 가까운 몸 색을 쓴다.
static func _body_color(img: Image, x: int, y: int) -> Color:
	var c := _inner_color(img, x, y)
	if not _is_feature(c):
		return c
	for k in range(1, 5):
		for dy: int in [k, -k]:
			if y + dy >= 0 and y + dy < img.get_height() and img.get_pixel(x, y + dy).a >= ALPHA_MIN:
				var cc := _inner_color(img, x, y + dy)
				if not _is_feature(cc):
					return cc
	return c


## 눈동자(아주 어두움)나 눈의 흰 반짝임(아주 밝고 색이 거의 없음) — 몸 색이 아닌 얼굴 점.
static func _is_feature(c: Color) -> bool:
	return c.get_luminance() < 0.2 or (c.get_luminance() > 0.9 and c.s < 0.1)


## y 줄에서 불투명 칸의 처음·끝 x (없으면 (-1, -1)).
static func _span(img: Image, y: int) -> Vector2i:
	var lo := -1
	var hi := -1
	for x in img.get_width():
		if img.get_pixel(x, y).a >= ALPHA_MIN:
			if lo < 0:
				lo = x
			hi = x
	return Vector2i(lo, hi)


static func _is_edge(img: Image, x: int, y: int) -> bool:
	for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p := Vector2i(x, y) + n
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height() or img.get_pixel(p.x, p.y).a < ALPHA_MIN:
			return true
	return false


## 칸 v 의 n 쪽 면 하나(삼각형 두 개). 그림의 y 는 아래로 커지니 3D 에선 뒤집는다.
static func _quad(st: SurfaceTool, v: Vector3i, n: Vector3i, col: Color, origin: Vector3, px: float) -> void:
	var c := (Vector3(v.x + 0.5, v.y + 0.5, v.z + 0.5) - origin)
	c = Vector3(c.x, -c.y, -c.z)  # 그림 y 아래 → 3D 위, 정면 그림 가로 → -Z
	var nn := Vector3(n.x, -n.y, -n.z)
	# 면의 두 축
	var a := Vector3(nn.y, nn.z, nn.x) if absf(nn.x) < 0.5 else Vector3(0, 1, 0)
	var b := nn.cross(a)
	var center := (c + nn * 0.5) * px
	a *= 0.5 * px
	b *= 0.5 * px
	var p := [center - a - b, center + a - b, center + a + b, center - a + b]
	# 앞면이 바깥(nn)을 보도록 감는 순서를 맞춘다(Godot 은 시계 방향이 앞면)
	var order: Array = [0, 2, 1, 0, 3, 2] if a.cross(b).dot(nn) > 0.0 else [0, 1, 2, 0, 2, 3]
	for i: int in order:
		st.set_color(col)
		st.set_normal(nn)  # 면 방향을 직접 — 빛을 받는 면마다 밝기가 달라야 입체로 읽힌다
		st.add_vertex(p[i])
