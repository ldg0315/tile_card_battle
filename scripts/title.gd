extends Control
## 타이틀: 모드 선택. 개발 중엔 실행 인자로 건너뛸 수 있다(Game.handle_skip_args).

const UiStyle := preload("res://scripts/ui_style.gd")
const CharArt := preload("res://scripts/char_art.gd")


func _ready() -> void:
	if Game.handle_skip_args():
		return
	Game.mode = ""
	Sound.play_bgm("title")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiStyle.background(self)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)

	row.add_child(UiStyle.portrait(CharArt.build_frames("sword"), 4.0))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	row.add_child(box)
	box.add_child(UiStyle.label("타일 카드 배틀", 56, Color(1, 0.88, 0.5)))
	box.add_child(UiStyle.label("카드 3장으로 읽고, 피하고, 뒤를 잡아라", 18, Color(0.75, 0.78, 0.85)))
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	box.add_child(gap)
	_menu_button(box, "싱글 플레이", Color(0.95, 0.8, 0.3), _on_single)
	_menu_button(box, "AI 대전", Color(0.95, 0.4, 0.35), _on_versus)
	var online := _menu_button(box, "온라인 대전 (준비 중)", Color(0.5, 0.7, 0.95), func() -> void: pass)
	online.disabled = true
	_menu_button(box, "종료", Color(0.6, 0.6, 0.65), get_tree().quit)

	var archer := UiStyle.portrait(CharArt.build_frames("archer"), 4.0)
	archer.flip_h = true
	row.add_child(archer)


func _menu_button(parent: Control, text: String, accent: Color, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(b, accent)
	b.pressed.connect(Sound.play.bind("click"))
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _on_single() -> void:
	Game.mode = "single"
	Game.goto_select()


func _on_versus() -> void:
	Game.start_versus()
	Game.goto_select()
