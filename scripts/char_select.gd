extends Control
## 캐릭터 선택. 싱글이면 던전 맵으로, AI 대전이면 고르지 않은 캐릭터와 바로 전투.

const UiStyle := preload("res://scripts/ui_style.gd")
const CharArt := preload("res://scripts/char_art.gd")
const Cards := preload("res://scripts/cards.gd")

const ACCENT := {"sword": Color(0.95, 0.4, 0.35), "archer": Color(0.35, 0.8, 0.6)}
const BLURB := {
	"sword": "가까이 붙어 베는 근접형. 한 방이 크고 회전베기로 주변을 한꺼번에 벤다.",
	"archer": "거리를 벌려 쏘는 원거리형. 3칸 화살로 다가오기 전에 깎는다.",
}


func _ready() -> void:
	if Game.mode == "":
		Game.mode = "single"  # F6 으로 바로 열었을 때
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sound.play_bgm("title")
	UiStyle.background(self)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)  # 기술 체험 버튼까지 한 화면(720)에 들어가게
	add_child(box)
	box.add_child(UiStyle.label("캐릭터 선택", 40, Color(1, 0.88, 0.5)))
	box.add_child(UiStyle.label("싱글 플레이 — 던전으로" if Game.mode == "single" else "AI 대전 — 고르지 않은 캐릭터가 상대", 17, Color(0.7, 0.73, 0.8)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)
	for id: String in Game.PLAYABLE:
		row.add_child(_char_card(id))

	var back := Button.new()
	back.text = "뒤로"
	back.custom_minimum_size = Vector2(160, 40)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(back, Color(0.6, 0.6, 0.65))
	back.pressed.connect(Sound.play.bind("click"))
	back.pressed.connect(Game.goto_title)
	box.add_child(back)


func _char_card(id: String) -> Control:
	var ch: Dictionary = Cards.CHARACTERS[id]
	var accent: Color = ACCENT.get(id, Color.GRAY)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(accent))
	card.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UiStyle.label(ch.name, 28, accent))
	v.add_child(UiStyle.portrait(CharArt.build_frames(id), 3.4))
	v.add_child(UiStyle.label("HP %d" % Game.max_hp(id), 17))
	var blurb := UiStyle.label(BLURB.get(id, ""), 15, Color(0.75, 0.78, 0.85))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size.x = 300
	v.add_child(blurb)
	for atk: Dictionary in ch.attacks.values():
		v.add_child(UiStyle.label("%s  피해 %d · MP %d" % [atk.name, atk.dmg, atk.cost], 15, Color(0.9, 0.9, 0.92)))
	var pick := Button.new()
	pick.text = "%s 선택" % ch.name
	pick.custom_minimum_size = Vector2(0, 44)
	pick.add_theme_font_size_override("font_size", 20)
	UiStyle.style_button(pick, accent)
	pick.pressed.connect(Sound.play.bind("click"))
	pick.pressed.connect(Game.choose_character.bind(id))
	v.add_child(pick)
	# 모든 기술(보상 기술 포함)을 1·3인칭으로 한 번씩 써 보는 연습장 — 고르기 전에 손맛을 보고, 개발할 땐 새 기술 확인용
	var practice := Button.new()
	practice.text = "기술 체험"
	practice.custom_minimum_size = Vector2(0, 34)
	practice.add_theme_font_size_override("font_size", 16)
	UiStyle.style_button(practice, Color(0.6, 0.75, 0.95))
	practice.pressed.connect(Sound.play.bind("click"))
	practice.pressed.connect(Game.start_practice.bind(id))
	v.add_child(practice)
	return card
