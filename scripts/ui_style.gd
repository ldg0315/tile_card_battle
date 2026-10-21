extends RefCounted
## 화면들이 같이 쓰는 UI 모양. 기본 테마 버튼은 어두운 배경에서 글자만 떠 보여서 직접 칠한다.

const BG := Color(0.09, 0.1, 0.16)


static func style_button(b: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.17, 0.22) if state != "hover" else Color(0.24, 0.25, 0.32)
		if state == "disabled":
			sb.bg_color = Color(0.11, 0.11, 0.14)
		sb.border_color = accent if state != "disabled" else accent.darkened(0.6)
		sb.set_border_width_all(2)
		sb.border_width_top = 5
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))


static func panel(accent: Color, fill := Color(0.13, 0.14, 0.19)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	return sb


static func background(parent: Control, color := BG) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)


static func label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## 캐릭터 대기 첫 프레임 그림. 도트는 각지게, 큰 그림은 부드럽게 확대한다(char_art 의 "smooth").
## scale 은 "48px 높이 도트 기준" 배율이라, 그림 해상도가 달라도 화면에 같은 크기로 나온다.
const PORTRAIT_BASE_H := 48.0


static func portrait(frames: SpriteFrames, scale: float) -> TextureRect:
	var tex := frames.get_frame_texture("idle", 0)
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if frames.get_meta("smooth", false) \
		else CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var k := scale * PORTRAIT_BASE_H / tex.get_height()
	r.custom_minimum_size = Vector2(tex.get_width(), tex.get_height()) * k
	return r
