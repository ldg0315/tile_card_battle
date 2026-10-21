extends Control
## 미니맵: 보드를 위에서 내려다본 작은 지도. 1인칭에선 타일이 잘 안 보여 위치·방향·다음 이동을 읽기 어려워서,
## 판 전체와 "고른 카드대로 움직이면 어디로 가는지"를 한눈에 보여준다.
## 그릴 값은 battle.gd 에서 읽는다 — 위치는 스프라이트 기준이라 연출 중에도 실제 움직임을 따라간다.

const Rules := preload("res://scripts/game_rules.gd")
const MARKS := ["①", "②", "③"]
const CELL := 34.0
const PAD := 8.0
const TITLE_H := 20.0

var battle  # battle.gd (값을 읽기만 한다)


func board_size() -> Vector2:
	return Vector2(Rules.COLS * CELL + PAD * 2, Rules.ROWS * CELL + PAD * 2 + TITLE_H)


func _cell_rect(t: Vector2i) -> Rect2:
	return Rect2(PAD + t.x * CELL + 1, TITLE_H + PAD + t.y * CELL + 1, CELL - 2, CELL - 2)


func _center(t: Vector2i) -> Vector2:
	return _cell_rect(t).get_center()


func _draw() -> void:
	if battle == null or battle.rules == null:
		return
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, board_size()), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(Vector2.ZERO, board_size()), Color(1, 1, 1, 0.25), false, 1.0)
	draw_string(font, Vector2(PAD, 15), "미니맵  [M] 켜기·끄기  [Space] 3인칭", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
	for r in Rules.ROWS:
		for c in Rules.COLS:
			var t := Vector2i(c, r)
			draw_rect(_cell_rect(t), battle._tile_color(t).darkened(0.15))

	# 마우스를 올린 카드의 범위/도착 칸
	for t: Vector2i in battle.preview_tiles:
		draw_rect(_cell_rect(t), Color(1, 0.85, 0.3, 0.6))

	# 고른 카드대로의 예상 경로: 이동은 선과 순번, 공격은 그 자리에서의 범위
	var plan: Array = battle.planned_path()
	var prev: Vector2i = battle.rules.fighters[0].pos
	for step: Dictionary in plan:
		for t: Vector2i in step.get("tiles", []):
			draw_rect(_cell_rect(t), Color(0.95, 0.35, 0.25, 0.35))
		if step.pos != prev:
			draw_line(_center(prev), _center(step.pos), Color(1, 0.9, 0.4, 0.9), 3.0)
		var mark: String = MARKS[step.order]
		var at := _center(step.pos) + Vector2(4 + step.order * 7, -6)
		draw_string(font, at, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.4))
		prev = step.pos

	# 전투원: 색 원 + 바라보는 쪽 삼각형. 1인칭에서 보고 있는 적은 노란 테두리
	for i in battle.rules.fighters.size():
		if battle.gone[i]:
			continue
		var t: Vector2i = battle.sprite_tile(i)
		var c := _center(t)
		var col: Color = battle._color(i)
		draw_circle(c, 9.0, col)
		var f: float = battle.step_facing[i]
		draw_colored_polygon(PackedVector2Array([c + Vector2(f * 15, 0), c + Vector2(f * 8, -5), c + Vector2(f * 8, 5)]), col.lightened(0.3))
		if i == 0:
			draw_string(font, c + Vector2(-6, 4), "나", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		if battle.first_person and i == battle.fp_target:
			draw_arc(c, 12.5, 0, TAU, 24, Color(1, 0.9, 0.3), 2.0)
