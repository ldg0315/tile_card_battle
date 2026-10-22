extends RefCounted
## 공격 카드의 범위를 작은 격자 그림으로. 손패·보상 카드 버튼의 아이콘으로 쓴다.
## 이름과 숫자만으로는 "찌르기 = 앞 2칸"을 외워야 해서, 고르기 전에 모양으로 읽히게 한다.
## 범위는 상대좌표라(cards.gd) 기본은 오른쪽을 본 그림이고, facing = -1 이면 좌우를 뒤집는다.
## 손패에선 그 카드를 쓸 때의 예상 방향을 넘겨, 왼쪽을 볼 때 머릿속으로 뒤집지 않아도 되게 한다.
## body = true(1인칭)면 "앞"이 위로 가게 돌린다 — 1인칭 화면에선 앞이 화면 위쪽이라 그쪽으로 읽힌다.
##
## 격자는 카드마다 크기를 바꾸지 않고 X_MIN..X_MAX × -1..1 로 고정한다.
## 카드마다 맞춰 자르면 "앞 1칸"과 "앞 3칸"이 같은 크기로 보여 사거리 차이가 안 읽혔다.

const X_MIN := -1
const X_MAX := 3
const Y_MIN := -1
const Y_MAX := 1
const SELF_COLOR := Color(1, 1, 1, 0.9)
const HIT_COLOR := Color(0.95, 0.4, 0.3)
const EMPTY_COLOR := Color(1, 1, 1, 0.12)


## cell = 한 칸의 픽셀 수(테두리 1px 포함). 공격 카드가 아니면 null.
static func make(card: Dictionary, cell: int, facing := 1, body := false) -> ImageTexture:
	if card.get("type", "") != "attack":
		return null
	var cols := X_MAX - X_MIN + 1
	var rows := Y_MAX - Y_MIN + 1
	var img := Image.create(cols * cell + 1, rows * cell + 1, false, Image.FORMAT_RGBA8)
	var hits := {}
	for off: Vector2i in card.range:
		hits[off] = true
	for y in range(Y_MIN, Y_MAX + 1):
		for x in range(X_MIN, X_MAX + 1):
			var c := EMPTY_COLOR
			if hits.has(Vector2i(x, y)):
				c = HIT_COLOR
			elif x == 0 and y == 0:
				c = SELF_COLOR
			img.fill_rect(Rect2i((x - X_MIN) * cell + 1, (y - Y_MIN) * cell + 1, cell - 1, cell - 1), c)
	# 내 칸에 앞쪽 표시(작은 삼각형 대신 오른쪽 한 줄을 어둡게) — 어느 쪽이 "앞"인지
	var sx := (0 - X_MIN) * cell + 1
	var sy := (0 - Y_MIN) * cell + 1
	img.fill_rect(Rect2i(sx + cell - 1 - maxi(1, cell / 4), sy + cell / 4, maxi(1, cell / 4), cell - 1 - cell / 2), Color(0.2, 0.2, 0.25))
	if facing < 0:
		img.flip_x()
	if body:
		# 행 차이(y)는 방향과 무관한 보드 기준이라, 오른쪽을 볼 땐 보드 위쪽이 몸의 왼쪽, 왼쪽을 볼 땐 몸의 오른쪽이 된다.
		# 뒤집은 그림을 앞이 위로 오게 돌리면 이 관계가 그대로 맞는다
		img.rotate_90(COUNTERCLOCKWISE if facing > 0 else CLOCKWISE)
	return ImageTexture.create_from_image(img)
