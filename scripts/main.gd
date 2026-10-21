extends Node3D
## 3인칭 2.5D 전투 화면. 3D 보드 위에 도트 스프라이트를 빌보드로 세운다.
## 연출은 rules 가 돌려준 이벤트만 읽는다 — 나중에 1인칭 카메라를 추가해도 규칙 코드는 건드리지 않게 하려는 것.

const Rules := preload("res://scripts/game_rules.gd")
const Cards := preload("res://scripts/cards.gd")
const AI := preload("res://scripts/ai.gd")

const TILE := 2.0
const SPRITE_PX := 0.09
const SPRITE_Y := 24 * SPRITE_PX / 2.0  # 스프라이트는 중심 기준이라 절반만큼 올려야 발이 타일에 닿는다
const MOVE_TIME := 0.3
const PLAYER_CHAR := "sword"
const ENEMY_CHAR := "archer"
const TILE_A := Color(0.36, 0.42, 0.33)
const TILE_B := Color(0.30, 0.36, 0.28)
# 공격자별 범위 색 — 같은 단계에 둘 다 공격하면 어느 쪽 범위인지 구분돼야 한다
const HIT_COLOR := [Color(0.95, 0.35, 0.25), Color(0.3, 0.55, 0.95)]
const PREVIEW_COLOR := Color(0.95, 0.85, 0.3)
const CARD_ACCENT := {
	"move": Color(0.45, 0.8, 0.45),
	"guard": Color(0.5, 0.7, 0.95),
	"rest": Color(0.5, 0.7, 0.95),
	"attack": Color(0.95, 0.4, 0.35),
}

var rules
var rng := RandomNumberGenerator.new()
var turn := 0
var busy := false
var selected: Array[String] = []

var tile_mats := {}  # Vector2i -> StandardMaterial3D
var sprites: Array[Sprite3D] = []
var card_tags: Array[Label3D] = []

var name_labels: Array[Label] = []
var hp_bars: Array[ProgressBar] = []
var mp_bars: Array[ProgressBar] = []
var hand_box: HBoxContainer
var slot_label: Label
var go_button: Button
var clear_button: Button
var log_label: RichTextLabel
var result_panel: PanelContainer
var result_label: Label
var card_buttons := {}  # card id -> Button


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_ui()
	_new_game()
	_handle_debug_args()


# ---------------------------------------------------------------- 월드

func _world(t: Vector2i) -> Vector3:
	return Vector3((t.x - (Rules.COLS - 1) / 2.0) * TILE, 0, (t.y - (Rules.ROWS - 1) / 2.0) * TILE)


func _tile_color(t: Vector2i) -> Color:
	return TILE_A if (t.x + t.y) % 2 == 0 else TILE_B


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.1, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# 이누야샤 플래시 게임처럼 보드를 앞쪽 위에서 비스듬히 내려다보는 3인칭 카메라.
	# 시선을 보드 중심보다 앞(z+)에 두는 건 하단 카드 UI 에 보드가 가리지 않게 위로 올리려는 것,
	# 오른쪽(x+)으로 비키는 건 오른쪽 전투 기록 패널에 보드 끝 열이 가리지 않게 하려는 것.
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = Vector3(1.6, 9.5, 10.5)
	cam.look_at(Vector3(1.6, 0, 1.0))
	cam.current = true

	for r in Rules.ROWS:
		for c in Rules.COLS:
			var t := Vector2i(c, r)
			var box := BoxMesh.new()
			box.size = Vector3(TILE * 0.92, 0.25, TILE * 0.92)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _tile_color(t)
			var m := MeshInstance3D.new()
			m.mesh = box
			m.material_override = mat
			m.position = _world(t) + Vector3(0, -0.125, 0)
			add_child(m)
			tile_mats[t] = mat

	for i in 2:
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.pixel_size = SPRITE_PX
		s.shaded = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		sprites.append(s)

		# 빌보드 스프라이트는 그림자가 어색해서 발밑에 납작한 원판으로 가짜 그림자를 둔다
		var disc := CylinderMesh.new()
		disc.top_radius = 0.55
		disc.bottom_radius = 0.55
		disc.height = 0.02
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.albedo_color = Color(0, 0, 0, 0.35)
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var shadow := MeshInstance3D.new()
		shadow.mesh = disc
		shadow.material_override = shadow_mat
		shadow.position = Vector3(0, -SPRITE_Y + 0.02, 0)
		s.add_child(shadow)

		var tag := Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font_size = 44
		tag.outline_size = 10
		tag.pixel_size = 0.01
		tag.position = Vector3(0, SPRITE_Y + 0.45, 0)
		tag.hide()
		s.add_child(tag)
		card_tags.append(tag)


## 임시 도트(16x24). 진짜 도트를 그리면 이 함수 대신 load("res://art/xxx.png") 로 바꾸면 된다.
func _make_sprite_texture(char_id: String) -> ImageTexture:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body: Color = Cards.CHARACTERS[char_id].body
	var dark := body.darkened(0.45)
	var skin := Color(0.98, 0.82, 0.66)
	var hair := Color(0.15, 0.1, 0.08)
	_rect(img, 5, 1, 6, 2, hair)
	_rect(img, 5, 3, 6, 5, skin)
	img.set_pixel(8, 5, Color.BLACK)
	img.set_pixel(10, 5, Color.BLACK)
	_rect(img, 4, 8, 8, 8, body)
	_rect(img, 4, 14, 8, 1, dark)
	_rect(img, 3, 9, 1, 5, skin)
	_rect(img, 12, 9, 1, 5, skin)
	_rect(img, 5, 16, 2, 7, dark)
	_rect(img, 9, 16, 2, 7, dark)
	_rect(img, 4, 23, 3, 1, Color.BLACK)
	_rect(img, 9, 23, 3, 1, Color.BLACK)
	if char_id == "sword":
		_rect(img, 13, 2, 1, 10, Color(0.85, 0.85, 0.92))
		_rect(img, 12, 12, 3, 1, Color(0.6, 0.45, 0.2))
	else:
		_rect(img, 14, 5, 1, 12, Color(0.55, 0.35, 0.15))
		img.set_pixel(13, 4, Color(0.55, 0.35, 0.15))
		img.set_pixel(13, 17, Color(0.55, 0.35, 0.15))
	return ImageTexture.create_from_image(img)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	root.add_child(top)
	for i in 2:
		if i == 1:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(gap)
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 340
		top.add_child(box)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		if i == 1:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(l)
		name_labels.append(l)
		hp_bars.append(_bar(box, Rules.MAX_HP, Color(0.85, 0.25, 0.25), 18))
		mp_bars.append(_bar(box, Rules.MAX_MP, Color(0.3, 0.6, 0.95), 10))

	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 1
	log_panel.anchor_right = 1
	log_panel.anchor_bottom = 1
	log_panel.offset_left = -280
	log_panel.offset_right = -16
	log_panel.offset_top = 100
	log_panel.offset_bottom = -170
	root.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_label.add_theme_font_size_override("bold_font_size", 14)
	log_panel.add_child(log_label)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -160
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	bottom.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	slot_label = Label.new()
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_label.add_theme_font_size_override("font_size", 18)
	row.add_child(slot_label)
	clear_button = Button.new()
	clear_button.text = "선택 취소"
	clear_button.pressed.connect(_on_clear)
	row.add_child(clear_button)
	go_button = Button.new()
	go_button.text = "    실행    "
	go_button.pressed.connect(_on_go)
	row.add_child(go_button)
	_style_button(clear_button, Color(0.6, 0.6, 0.65))
	_style_button(go_button, Color(0.95, 0.8, 0.3))
	go_button.custom_minimum_size = Vector2(120, 34)
	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hand_box)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(result_panel)
	var rv := VBoxContainer.new()
	result_panel.add_child(rv)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 40)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(320, 0)
	rv.add_child(result_label)
	var again := Button.new()
	again.text = "다시 하기"
	again.pressed.connect(_new_game)
	rv.add_child(again)


func _bar(parent: Control, max_value: int, color: Color, height: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	return b


func _build_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	card_buttons.clear()
	for id: String in rules.hand(0):
		var b := Button.new()
		b.text = _card_text(Cards.get_card(id))
		b.custom_minimum_size = Vector2(118, 74)
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, CARD_ACCENT[Cards.get_card(id).type])
		b.pressed.connect(_on_card_pressed.bind(id))
		b.mouse_entered.connect(_preview.bind(id))
		b.mouse_exited.connect(_clear_tiles)
		hand_box.add_child(b)
		card_buttons[id] = b


## 카드 종류별 테두리 색. 기본 테마 버튼은 어두운 배경에서 글자만 떠 보여서 카드처럼 보이지 않는다.
func _style_button(b: Button, accent: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.17, 0.22) if state != "hover" else Color(0.24, 0.25, 0.32)
		if state == "disabled":
			sb.bg_color = Color(0.11, 0.11, 0.14)
		sb.border_color = accent if state != "disabled" else accent.darkened(0.6)
		sb.set_border_width_all(2)
		sb.border_width_top = 5
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))


func _card_text(card: Dictionary) -> String:
	if card.type == "move":
		return "%s\n이동" % card.name
	if card.type == "guard":
		return "방어\n받는 피해 -%d" % Rules.GUARD_BLOCK
	if card.type == "rest":
		return "기 모으기\nMP +%d" % Rules.REST_MP
	return "%s\n피해 %d · MP %d" % [card.name, card.dmg, card.cost]


# ---------------------------------------------------------------- 진행

func _new_game() -> void:
	rules = Rules.new(PLAYER_CHAR, ENEMY_CHAR)
	turn = 0
	busy = false
	selected.clear()
	for i in 2:
		var f = rules.fighters[i]
		sprites[i].texture = _make_sprite_texture(f.char_id)
		sprites[i].position = _world(f.pos) + Vector3(0, SPRITE_Y, 0)
		sprites[i].flip_h = f.facing < 0
		sprites[i].modulate = Color.WHITE
	_build_hand()
	_clear_tiles()
	log_label.clear()
	_log("카드 3장을 순서대로 고르고 [b]실행[/b]을 누르세요.\n카드에 마우스를 올리면 범위가 노랗게 보입니다.")
	result_panel.hide()
	_show_stats([rules.fighters[0].hp, rules.fighters[1].hp], [rules.fighters[0].mp, rules.fighters[1].mp])
	_refresh_hand()


func _show_stats(hp: Array, mp: Array) -> void:
	for i in 2:
		var who := "나" if i == 0 else "AI"
		name_labels[i].text = "%s · %s    HP %d   MP %d" % [who, Cards.CHARACTERS[rules.fighters[i].char_id].name, hp[i], mp[i]]
		hp_bars[i].value = hp[i]
		mp_bars[i].value = mp[i]


func _refresh_hand() -> void:
	var mp: int = rules.fighters[0].mp
	var used: int = rules.cost_of(selected)
	var names := PackedStringArray()
	for k in Rules.CARDS_PER_TURN:
		names.append("%d) %s" % [k + 1, Cards.get_card(selected[k]).name if k < selected.size() else "—"])
	slot_label.text = "   ".join(names) + "        MP 사용 %d / %d" % [used, mp]
	var full := selected.size() >= Rules.CARDS_PER_TURN
	for id: String in card_buttons:
		var b: Button = card_buttons[id]
		var cost: int = Cards.get_card(id).cost
		var order := selected.find(id)
		b.disabled = busy or rules.winner != -1 or full or order != -1 or used + cost > mp
		b.text = ("[%d] " % (order + 1) if order != -1 else "") + _card_text(Cards.get_card(id))
		b.modulate = Color(1.0, 0.85, 0.35) if order != -1 else Color.WHITE
	go_button.disabled = busy or not full
	clear_button.disabled = busy or selected.is_empty()


func _on_card_pressed(id: String) -> void:
	if busy or selected.size() >= Rules.CARDS_PER_TURN or selected.has(id):
		return
	if rules.cost_of(selected + [id]) > rules.fighters[0].mp:
		return
	selected.append(id)
	_refresh_hand()


func _on_clear() -> void:
	if busy:
		return
	selected.clear()
	_refresh_hand()


func _on_go() -> void:
	if busy or not rules.is_valid_selection(0, selected):
		return
	busy = true
	turn += 1
	var mine: Array = selected.duplicate()
	var theirs: Array = AI.choose(rules, 1, rng)
	selected.clear()
	_clear_tiles()
	_refresh_hand()
	_log("\n[b]— %d턴 —[/b]" % turn)
	var events: Array = rules.resolve_turn(mine, theirs)
	for ev: Dictionary in events:
		await _play_step(ev)
	busy = false
	_refresh_hand()
	if rules.winner != -1:
		_show_result()


func _show_result() -> void:
	match rules.winner:
		0:
			result_label.text = "승리!"
		1:
			result_label.text = "패배..."
		_:
			result_label.text = "무승부"
	result_panel.show()


# ---------------------------------------------------------------- 연출

func _play_step(ev: Dictionary) -> void:
	for i in 2:
		card_tags[i].text = Cards.get_card(ev.cards[i]).name
		card_tags[i].modulate = HIT_COLOR[i].lightened(0.45)
		card_tags[i].show()

	var tw := create_tween().set_parallel(true)
	for i in 2:
		tw.tween_property(sprites[i], "position", _world(ev.pos[i]) + Vector3(0, SPRITE_Y, 0), MOVE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	for i in 2:
		sprites[i].flip_h = ev.facing[i] < 0
		if ev.guarding[i]:
			sprites[i].modulate = Color(0.6, 0.8, 1.0)

	if not ev.hits.is_empty():
		for h: Dictionary in ev.hits:
			for t: Vector2i in h.tiles:
				tile_mats[t].albedo_color = HIT_COLOR[h.from]
		await get_tree().create_timer(0.25).timeout
		for h: Dictionary in ev.hits:
			if h.hit:
				_damage_popup(1 - h.from, h.dmg)
		await get_tree().create_timer(0.45).timeout
		_clear_tiles()

	_show_stats(ev.hp, ev.mp)
	_log(_step_text(ev))
	await get_tree().create_timer(0.3).timeout
	for i in 2:
		card_tags[i].hide()
		sprites[i].modulate = Color.WHITE


func _damage_popup(target: int, dmg: int) -> void:
	var l := Label3D.new()
	l.text = "-%d" % dmg if dmg > 0 else "막음"
	l.font_size = 64
	l.outline_size = 12
	l.modulate = Color(1, 0.35, 0.3)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	add_child(l)
	l.position = sprites[target].position + Vector3(0.7, 0.1, 0.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

	var s := sprites[target]
	s.modulate = Color(1, 0.35, 0.35)
	create_tween().tween_property(s, "modulate", Color.WHITE, 0.4)


func _preview(id: String) -> void:
	if busy:
		return
	_clear_tiles()
	var f = rules.fighters[0]
	var card: Dictionary = Cards.get_card(id)
	var tiles: Array = []
	if card.type == "attack":
		tiles = rules.attack_tiles(f, card)
	elif card.type == "move":
		var d: Vector2i = card.dir
		var t := Vector2i(f.pos.x + d.x * f.facing, f.pos.y + d.y)
		if Rules.in_board(t):
			tiles = [t]
	for t: Vector2i in tiles:
		tile_mats[t].albedo_color = PREVIEW_COLOR


func _clear_tiles() -> void:
	for t: Vector2i in tile_mats:
		tile_mats[t].albedo_color = _tile_color(t)


func _step_text(ev: Dictionary) -> String:
	var parts := PackedStringArray()
	for i in 2:
		var who := "나" if i == 0 else "AI"
		var s := "%s: %s" % [who, Cards.get_card(ev.cards[i]).name]
		if ev.fizzled[i]:
			s += " (MP 부족)"
		for h: Dictionary in ev.hits:
			if h.from == i:
				s += (" → 명중 %d" % h.dmg) if h.hit else " → 빗나감"
		parts.append(s)
	return "  /  ".join(parts)


func _log(text: String) -> void:
	log_label.append_text(text + "\n")


# ---------------------------------------------------------------- 개발용

## `godot --path . -- --shot=경로.png [--auto]`
## 화면을 PNG 로 저장하고 종료한다. --auto 면 한 턴을 자동 진행해 공격 연출 도중(_mid)과 끝난 뒤를 각각 저장한다.
func _handle_debug_args() -> void:
	var shot := ""
	var auto := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a == "--auto":
			auto = true
	if shot == "":
		return
	await get_tree().create_timer(0.5).timeout
	for id: String in ["fwd", "sword_slash", "guard"]:
		_on_card_pressed(id)
	if auto:
		_on_go()
		await get_tree().create_timer(0.75).timeout
		get_viewport().get_texture().get_image().save_png(shot.get_basename() + "_mid.png")
		while busy:
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()
