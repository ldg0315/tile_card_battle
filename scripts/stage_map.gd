extends Control
## 싱글 플레이 던전 진행 화면. 현재 장(chapter)의 스테이지를 일직선으로 보여준다(갈림길·카드 보상은 다음 단계).

const UiStyle := preload("res://scripts/ui_style.gd")
const CharArt := preload("res://scripts/char_art.gd")
const Cards := preload("res://scripts/cards.gd")
const Themes := preload("res://scripts/themes.gd")

const GOLD := Color(0.95, 0.8, 0.3)
const DONE := Color(0.45, 0.8, 0.45)
const LOCKED := Color(0.35, 0.36, 0.42)


func _ready() -> void:
	# 에디터에서 이 장면을 F6 으로 바로 열었을 때도 동작하게
	if Game.mode != "single":
		Game.start_single()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.background(self, Themes.get_theme(Game.current_chapter().theme).ui_bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	var ch: Dictionary = Game.current_chapter()
	var title := "던전 클리어!" if Game.is_cleared() else "%d장 · %s" % [Game.chapter + 1, ch.name]
	box.add_child(UiStyle.label(title, 44, GOLD))
	var me := Game.player_char
	var hp: int = Game.player_hp if Game.player_hp >= 0 else Game.max_hp(me)
	var who := HBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(UiStyle.portrait(CharArt.build_frames(me), 1.5))
	who.add_child(UiStyle.label("%s  HP %d / %d" % [Cards.CHARACTERS[me].name, hp, Game.max_hp(me)], 20))
	box.add_child(who)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var stages: Array = ch.stages
	for k in stages.size():
		if k > 0:
			row.add_child(UiStyle.label("→", 36, DONE if _cleared(k) else LOCKED))
		row.add_child(_stage_card(k))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)
	if Game.is_cleared():
		_button(actions, "처음부터 다시", GOLD, func() -> void:
			Game.start_single()
			Game.goto_map())
	else:
		_button(actions, "%s 도전" % Game.stage_code(Game.chapter, Game.stage), GOLD, Game.goto_battle)
	_button(actions, "캐릭터 변경", Color(0.5, 0.7, 0.95), Game.goto_select)
	_button(actions, "타이틀로", Color(0.6, 0.6, 0.65), Game.goto_title)
	box.add_child(UiStyle.label("스테이지를 넘어갈 때 HP %d 회복" % Game.HEAL_BETWEEN, 15, Color(0.6, 0.63, 0.7)))


## 클리어한 장을 다시 보여줄 때(던전 클리어 화면)는 전부 클리어로 친다.
func _cleared(k: int) -> bool:
	return Game.is_cleared() or k < Game.stage


func _stage_card(k: int) -> Control:
	var st: Dictionary = Game.current_chapter().stages[k]
	var enemies: Array = Game.stage_enemies(st)
	var cleared := _cleared(k)
	var current := not Game.is_cleared() and k == Game.stage
	var locked := not cleared and not current
	var accent := DONE if cleared else (GOLD if current else LOCKED)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(accent))
	card.custom_minimum_size = Vector2(220, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var code := Game.stage_code(mini(Game.chapter, Game.CHAPTERS.size() - 1), k)
	v.add_child(UiStyle.label(("보스 · " if st.get("boss", false) else "") + code, 16, accent))
	v.add_child(UiStyle.label(st.name, 20))
	# 여럿이 나오면 나란히, 그림은 그만큼 작게
	var pics := HBoxContainer.new()
	pics.alignment = BoxContainer.ALIGNMENT_CENTER
	var names := PackedStringArray()
	for e: Dictionary in enemies:
		var pic := UiStyle.portrait(CharArt.build_frames(e.id), 2.6 / enemies.size() + 0.4)
		if locked:
			pic.modulate = Color(0, 0, 0, 0.8)  # 아직 못 간 곳은 실루엣만
		pics.add_child(pic)
		names.append("%s HP %d" % [Cards.CHARACTERS[e.id].name, Game.enemy_hp(e)])
	v.add_child(pics)
	var who := "???" if locked else (" + " if st.waves.size() == 1 else " → ").join(names)
	v.add_child(UiStyle.label(who, 15, Color(0.8, 0.82, 0.88)))
	v.add_child(UiStyle.label("클리어" if cleared else ("도전" if current else "잠김"), 16, accent))
	return card


func _button(parent: Control, text: String, accent: Color, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 46)
	b.add_theme_font_size_override("font_size", 20)
	UiStyle.style_button(b, accent)
	b.pressed.connect(action)
	parent.add_child(b)
