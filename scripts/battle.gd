extends Node3D
## 3인칭 2.5D 전투 화면. 3D 보드 위에 도트 스프라이트를 빌보드로 세운다.
## 연출은 rules 가 돌려준 이벤트만 읽는다 — 1인칭 카메라를 더해도 규칙 코드는 건드리지 않게 하려는 것.
## 전투원은 여럿일 수 있다(0번 = 나, 1번부터 적). 배열은 모두 전투원 번호로 맞춘다.

const Rules := preload("res://scripts/game_rules.gd")
const Cards := preload("res://scripts/cards.gd")
const AI := preload("res://scripts/ai.gd")
const CharArt := preload("res://scripts/char_art.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const BossPlan := preload("res://scripts/boss_plan.gd")
const Themes := preload("res://scripts/themes.gd")
const PropArt := preload("res://scripts/prop_art.gd")
const PixelArt := preload("res://scripts/pixel_art.gd")
const SlashShader := preload("res://shaders/slash_ring.gdshader")
const Minimap := preload("res://scripts/minimap.gd")
const RangeIcon := preload("res://scripts/range_icon.gd")

const TILE := 2.0
const SPRITE_PX := 0.09  # 발사체 도트 크기
# 캐릭터는 그림 해상도와 상관없이 월드에서 이 높이로 맞춘다 — 임시 도트와 직접 그린 그림을 바꿔 끼워도 판이 달라지지 않게
const CHAR_HEIGHT := 2.16
const SPRITE_Y := CHAR_HEIGHT / 2.0  # 스프라이트는 중심 기준이라 절반만큼 올려야 발이 타일에 닿는다
const MOVE_TIME := 0.3
# 연출 전체 속도 배율(클수록 느림). 시간 값을 하나하나 고치지 않고 여기 한 곳에서 조절하려고 둔다
const ANIM_SLOW := 1.3
const TP_FOV := 40.0
const CAM_X := 0.0  # 3인칭 카메라 가로 위치(보드 중심 = 0)
const FP_FOV := 70.0
# 상대와의 거리(칸, 대각선도 1칸) → 1인칭에서 엿볼 수 있는 상대 카드 수.
# 가까울수록 자세가 잘 읽힌다는 설정 — 접근해야 하는 검사와 거리를 벌리려는 궁수 사이에 긴장을 만든다
const PEEK_BY_DIST := {1: 2, 2: 1}
# 전투원별 범위·이름표 색 — 같은 단계에 여럿이 공격하면 누구 범위인지 구분돼야 한다
const FIGHTER_COLOR := [Color(0.95, 0.35, 0.25), Color(0.3, 0.55, 0.95), Color(0.7, 0.45, 0.95), Color(0.3, 0.8, 0.7)]
const PREVIEW_COLOR := Color(0.95, 0.85, 0.3)
const CARD_ACCENT := {
	"move": Color(0.45, 0.8, 0.45),
	"guard": Color(0.5, 0.7, 0.95),
	"rest": Color(0.5, 0.7, 0.95),
	"heal": Color(0.45, 0.85, 0.55),
	"attack": Color(0.95, 0.4, 0.35),
}
# 1인칭 회전베기 때 카메라를 한 바퀴 돌릴지. 짧지만 어지러우면 false 로 — 무기 휩쓸기와 칼바람 고리만 남는다
const FP_SPIN_CAMERA := true
const SPIN_TIME := 0.45
const ORDER_MARK := ["①", "②", "③"]
const MOVE_W := 92  # 손패 이동 버튼 폭
const UTIL_W := 128  # 손패 방어·기 모으기·회복 버튼 폭
const ATTACK_SFX := {"lunge": "slash", "thrust": "thrust", "spin": "spin", "jump": "jump",
	"arrow": "arrow", "volley": "volley", "wave": "wave"}
const REST_TIME := 0.8  # 기 모으기 연출 길이
const DEATH_HOLD := 0.9  # 쓰러진 모습을 보여주는 시간. 바로 사라지면 무엇이 쓰러졌는지 놓친다
const DEATH_FADE := 0.7

var rules
var theme: Dictionary  # 장 테마(themes.gd). 전투 장면을 다시 열기 전까지 바뀌지 않는다
# 배경 그림(art/bg/<테마>.png). 있으면 3인칭은 화면 전체에 그림을 깔고(격자는 반투명), 1인칭은 같은 그림을 둘러싼 하늘로.
# 화면 고정 그림을 1인칭에도 쓰면 고개를 돌려도 배경이 따라 움직이지 않아 어색해서 시점마다 다르게 쓴다
var backdrop: Texture2D
var world_env: WorldEnvironment
var env_tp: Environment
var env_fp: Environment
var backdrop_layer: CanvasLayer
var scenery_root: Node3D  # 코드로 만든 땅·바다·소품(배경 그림이 있으면 3인칭에선 숨긴다)
var _backdrop_fp := -1  # 마지막으로 맞춘 시점(-1 = 아직)
var rng := RandomNumberGenerator.new()
var turn := 0
var busy := false
var selected: Array[String] = []

var tile_mats := {}  # Vector2i -> StandardMaterial3D
var cam: Camera3D
var tp_xform: Transform3D  # 3인칭 카메라 자리
var cam_smooth: Transform3D  # 흔들림을 빼고 부드럽게 따라가는 카메라 상태
var shake_off := Vector3.ZERO
var fov_kick := 0.0  # 1인칭 기술 반동으로 잠깐 좁아지는 시야
var fp_spin := 0.0  # 1인칭 회전베기 중 카메라가 더 돌아간 각도(라디안)
# 1인칭에서 내가 공격하는 동안엔 적이 아니라 몸 정면(실제 공격 방향)을 본다.
# 적을 본 채로 찌르면 빗나가는 공격도 맞는 것처럼 보여서 착각을 부른다
var fp_face_lock := false
var first_person := false
var overview := false  # Space 를 누르는 동안 1인칭에서 잠깐 3인칭으로
var minimap_always := false  # M: 3인칭에서도 미니맵 표시
var preview_tiles: Array[Vector2i] = []  # 마우스를 올린 카드의 범위(미니맵도 같이 그린다)
var attack_marks := {}  # 지금 공격 중인 칸 → 공격자 색. 1인칭에선 보드가 잘 안 보여 미니맵에도 칠한다
var fp_target := 1  # 1인칭 카메라가 바라보는 적
var enemy_plans := {}  # 적 번호 → 이번 턴 카드. 엿보기를 하려면 내가 고르기 전에 정해져 있어야 한다
var boss_states := {}  # 적 번호 → 패턴 보스의 진행(페이즈·턴)
var facing_tex: ImageTexture
var wave_tex: ImageTexture
var debug_ai: Array = []  # 개발용: 스크린샷에서 특정 연출을 보려고 첫 번째 적의 카드를 고정

# 전투원별(번호 = rules.fighters 번호)
var sprites: Array[AnimatedSprite3D] = []
var card_tags: Array[Label3D] = []
var facing_marks: Array[Sprite3D] = []  # 발밑의 바라보는 방향 화살표 — 누가 등을 보이는지 한눈에
var motion: Array[Tween] = []  # 위치 트윈. 돌진하는 도중에 맞으면 이전 트윈을 끊어야 두 트윈이 위치를 다투지 않는다
var step_pos: Array[Vector3] = []  # 이번 단계에서 각자 서 있어야 할 자리
var step_facing: Array[int] = []
var sprite_half: Array[float] = []  # 화면 키의 절반. 보스처럼 큰 캐릭터도 발이 타일에 닿게
var gone: Array[bool] = []  # 쓰러져 사라진 전투원
var name_labels: Array[Label] = []
var hp_bars: Array[ProgressBar] = []
var mp_bars: Array[ProgressBar] = []
var offscreen_marks: Array[Label] = []  # 1인칭에서 화면 밖에 있는 적 방향 표시

var ui_root: Control
var player_box: VBoxContainer
var enemy_box: VBoxContainer
var log_panel: PanelContainer
var hand_box: HBoxContainer
var slot_label: Label
var go_button: Button
var log_label: RichTextLabel
var result_panel: PanelContainer
var result_label: Label
var result_buttons: HBoxContainer
var card_buttons := {}  # card id -> Button
var move_grid: GridContainer  # 손패의 이동 버튼 묶음(1인칭에선 몸 기준 순서로 다시 늘어놓는다)
var compact_cards := false  # 손패가 많아 카드 폭을 줄였으면 카드 글씨도 짧게
var view_button: Button
var peek_label: Label
var warn_label: Label
var step_label: Label  # 실행 중 "2단계 · 상대 먼저" — 지금 몇 번째 카드끼리 겨루는지
var hurt_flash: ColorRect
var compass_label: Label
var fp_act_label: Label
var viewmodel: TextureRect  # 1인칭에서 화면 오른쪽 아래에 보이는 내 무기
var minimap: Control
var vm_offset := Vector2.ZERO  # 무기 휘두르기 트윈은 이 값을 움직인다(위치는 매 프레임 흔들림과 합쳐 다시 계산되므로)


func _ready() -> void:
	rng.randomize()
	var theme_id: String = Game.battle_config().theme
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--theme="):
			theme_id = a.substr(8)  # 개발용: 아직 스테이지가 없는 테마(해안가 등) 배경 확인
	theme = Themes.get_theme(theme_id)
	backdrop = CharArt.background(theme_id)
	# 배경음악: 보스 스테이지면 보스곡, 아니면 장 테마 곡(audio/bgm/forest.ogg 등). 파일이 없으면 무음
	Sound.play_bgm("boss" if Game.current_stage().get("boss", false) else theme_id)
	_build_world()
	_build_scenery()
	_build_ui()
	_new_game()
	_handle_debug_args()


# ---------------------------------------------------------------- 월드

func _world(t: Vector2i) -> Vector3:
	return Vector3((t.x - (Rules.COLS - 1) / 2.0) * TILE, 0, (t.y - (Rules.ROWS - 1) / 2.0) * TILE)


func _tile_color(t: Vector2i) -> Color:
	var c: Color = theme.tile_a if (t.x + t.y) % 2 == 0 else theme.tile_b
	if backdrop:
		c.a = 0.45  # 배경 그림 위에 격자만 살짝 — 그림이 비쳐 보이게
	return c


func _color(i: int) -> Color:
	return FIGHTER_COLOR[mini(i, FIGHTER_COLOR.size() - 1)]


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	# 3인칭에선 거의 땅만 보이고, 하늘은 1인칭에서 지평선 위로 보인다
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme.sky_top
	sky_mat.sky_horizon_color = theme.sky_horizon
	sky_mat.ground_horizon_color = theme.sky_horizon.lerp(theme.ground, 0.5)
	sky_mat.ground_bottom_color = theme.ground
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = theme.ambient
	e.ambient_light_energy = theme.ambient_energy
	if theme.has("fog"):
		e.fog_enabled = true
		e.fog_light_color = theme.sky_horizon
		e.fog_density = theme.fog
	env.environment = e
	add_child(env)
	world_env = env
	if backdrop:
		env_fp = e
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = backdrop
		var psky := Sky.new()
		psky.sky_material = pano
		env_fp.sky = psky
		env_tp = e.duplicate()
		env_tp.background_mode = Environment.BG_CANVAS
		env_tp.background_canvas_max_layer = -1  # 레이어 -1 이하의 2D(배경 그림)를 3D 뒤에 그린다
		backdrop_layer = CanvasLayer.new()
		backdrop_layer.layer = -10
		var bg := TextureRect.new()
		bg.texture = backdrop
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop_layer.add_child(bg)
		add_child(backdrop_layer)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = theme.sun
	sun.light_energy = theme.sun_energy
	sun.shadow_enabled = true
	add_child(sun)

	# 이누야샤 플래시 게임처럼 보드를 앞쪽 위에서 비스듬히 내려다보는 3인칭 카메라.
	# 시선을 보드 중심보다 앞(z+)에 두는 건 하단 카드 UI 에 보드가 가리지 않게 위로 올리려는 것.
	# 전투 기록 패널은 기본으로 숨겨서(L) 보드를 화면 가운데에 둔다.
	cam = Camera3D.new()
	cam.fov = TP_FOV
	add_child(cam)
	cam.position = Vector3(CAM_X, 9.5, 10.5)
	cam.look_at(Vector3(CAM_X, 0, 1.0))
	cam.current = true
	tp_xform = cam.global_transform
	cam_smooth = tp_xform
	wave_tex = _make_wave_texture()
	facing_tex = _make_facing_texture()

	for r in Rules.ROWS:
		for c in Rules.COLS:
			var t := Vector2i(c, r)
			var box := BoxMesh.new()
			box.size = Vector3(TILE * 0.92, 0.25, TILE * 0.92)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = _tile_color(t)
			if backdrop:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var m := MeshInstance3D.new()
			m.mesh = box
			m.material_override = mat
			m.position = _world(t) + Vector3(0, -0.125, 0)
			add_child(m)
			tile_mats[t] = mat


## 전투원 수만큼 스프라이트(그림자·이름표 포함)를 맞춘다. 스테이지마다 적 수가 달라서 전투 시작 때 만든다.
func _ensure_fighter_nodes(n: int) -> void:
	while sprites.size() < n:
		var i := sprites.size()
		var s := AnimatedSprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.speed_scale = 1.0 / ANIM_SLOW
		s.animation_finished.connect(_on_anim_finished.bind(i))
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
		s.add_child(shadow)

		var tag := Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font_size = 44
		tag.outline_size = 10
		_fit_label(tag)
		tag.hide()
		s.add_child(tag)
		card_tags.append(tag)

		var fm := Sprite3D.new()
		fm.texture = facing_tex
		fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		fm.pixel_size = 0.045
		fm.rotation_degrees = Vector3(-90, 0, 0)  # 바닥에 눕힌다
		fm.shaded = false
		fm.modulate = Color(_color(i).r, _color(i).g, _color(i).b, 0.85)
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(fm)
		facing_marks.append(fm)

		var mark := Label.new()
		mark.add_theme_font_size_override("font_size", 20)
		mark.add_theme_color_override("font_color", _color(i).lightened(0.3))
		mark.add_theme_constant_override("outline_size", 8)
		mark.add_theme_color_override("font_outline_color", Color.BLACK)
		mark.hide()
		ui_root.add_child(mark)
		offscreen_marks.append(mark)

		motion.append(null)
		step_pos.append(Vector3.ZERO)
		step_facing.append(1)
		sprite_half.append(SPRITE_Y)
		gone.append(false)
	for i in sprites.size():
		sprites[i].visible = i < n and not (i == 0 and first_person)


## 테마 배경: 넓은 땅, (해안이면) 바다, 보드 둘레의 소품.
## 소품 배치는 테마 이름으로 시드를 고정해, 같은 장에선 늘 같은 풍경이 나오게 한다(다시 하기마다 숲이 바뀌면 어색).
func _build_scenery() -> void:
	scenery_root = Node3D.new()
	add_child(scenery_root)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	ground.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = theme.ground
	ground.material_override = gmat
	ground.position = Vector3(0, -0.26, 0)
	scenery_root.add_child(ground)

	if theme.has("water"):
		var sea := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = Vector2(120, 60)
		sea.mesh = sp
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = theme.water
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wmat.metallic_specular = 0.9
		wmat.roughness = 0.15
		sea.material_override = wmat
		sea.position = Vector3(0, -0.22, -37)  # 보드 뒤편(z < -7)이 바다
		scenery_root.add_child(sea)

	var prng := RandomNumberGenerator.new()
	prng.seed = hash(theme.get("sky_top"))
	var tint: Color = theme.get("prop_tint", Color.WHITE)
	for kind: String in theme.props:
		var count: int = theme.props[kind][0]
		var height: float = theme.props[kind][1]
		for k in count:
			var pos := _prop_spot(prng, theme.has("water"), height > 2.0)
			var tex := PropArt.make(kind, k)
			var p := Sprite3D.new()
			p.texture = tex
			p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			p.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			p.shaded = false
			p.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			p.modulate = tint
			var h := height * prng.randf_range(0.8, 1.2)
			p.pixel_size = h / tex.get_height()
			p.flip_h = prng.randf() < 0.5
			p.position = pos + Vector3(0, h / 2.0 - 0.25, 0)
			scenery_root.add_child(p)


## 보드와 그 앞쪽(카메라 쪽)은 비워 둔다 — 소품이 칸이나 캐릭터를 가리면 안 된다.
## 키 큰 소품(나무·종유석·야자수)은 카메라에 가까우면 화면을 덮으니 보드 뒤편이나 멀리 옆으로만 둔다.
func _prop_spot(prng: RandomNumberGenerator, has_sea: bool, tall: bool) -> Vector3:
	for _try in 60:
		var p := Vector3(prng.randf_range(-16, 18), 0, prng.randf_range(-14, 2))
		if absf(p.x) < 5.5 and p.z > -4.5:
			continue
		if tall and p.z > -3.5 and absf(p.x - CAM_X) < 11.0:
			continue
		if has_sea and p.z < -7.5:
			continue
		return p
	return Vector3(-12, 0, -6)


## 바라보는 방향 화살표(오른쪽 = 앞). 바닥에 눕혀 발 앞에 둔다.
func _make_facing_texture() -> ImageTexture:
	var img := Image.create(14, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	PixelArt._poly(img, [Vector2(1, 3.5), Vector2(7, 3.5), Vector2(7, 0.5), Vector2(13.5, 5.5),
		Vector2(7, 10.5), Vector2(7, 7.5), Vector2(1, 7.5)], Color.WHITE)
	PixelArt._outline(img, Color(0, 0, 0, 0.6))
	return ImageTexture.create_from_image(img)


func _update_mark(i: int) -> void:
	var fm := facing_marks[i]
	fm.flip_h = step_facing[i] < 0
	fm.position = Vector3(step_facing[i] * 0.8, -sprite_half[i] + 0.05, 0.25)
	fm.visible = not gone[i]


## 초음파: 오른쪽으로 퍼지는 호 두 겹.
func _make_wave_texture() -> ImageTexture:
	var img := Image.create(7, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for k in 2:
		for y in 11:
			var x := 1 + k * 3 + int(round(2.0 - absf(y - 5) * 0.45))
			img.set_pixel(clampi(x, 0, 6), y, Color(0.85, 0.7, 1.0, 1.0 - k * 0.35))
	return ImageTexture.create_from_image(img)


## 1인칭 무기(뷰모델). 화면 오른쪽 아래에서 위로 들고 있는 칼 / 세워 든 활.
func _make_viewmodel(char_id: String) -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin := Color(0.98, 0.84, 0.7)
	if char_id == "archer":
		var wood := Color(0.5, 0.3, 0.12)
		var pts: Array[Vector2] = []
		for k in 9:
			var t := lerpf(-PI / 2, PI / 2, k / 8.0)
			pts.append(Vector2(24 - cos(t) * 8.0, 26 + sin(t) * 20.0))
		for k in 8:
			PixelArt._limb(img, pts[k], pts[k + 1], 3.0, wood)
		PixelArt._limb(img, pts[0], pts[8], 1.0, Color(0.92, 0.92, 0.86))
		PixelArt._limb(img, Vector2(24, 26), Vector2(4, 22), 1.5, Color(0.6, 0.4, 0.18))
		PixelArt._disc(img, Vector2(4, 22), 1.5, Color(0.75, 0.78, 0.82))
		PixelArt._limb(img, Vector2(40, 47), Vector2(18, 28), 6.0, Color(0.16, 0.5, 0.42))
		PixelArt._disc(img, Vector2(17, 27), 3.5, skin)
	else:
		PixelArt._limb(img, Vector2(30, 30), Vector2(6, 4), 3.0, Color(0.88, 0.9, 0.96))
		PixelArt._limb(img, Vector2(31, 31), Vector2(9, 5), 1.0, Color(1, 1, 1))
		PixelArt._limb(img, Vector2(27, 33), Vector2(35, 25), 2.5, Color(0.85, 0.7, 0.2))
		PixelArt._limb(img, Vector2(31, 29), Vector2(40, 38), 4.0, Color(0.25, 0.15, 0.1))
		PixelArt._limb(img, Vector2(47, 47), Vector2(36, 35), 7.0, Color(0.82, 0.18, 0.2))
		PixelArt._disc(img, Vector2(36, 34), 4.0, skin)
	PixelArt._outline(img)
	return ImageTexture.create_from_image(img)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	var root := ui_root

	# 1인칭 무기는 하단 카드 패널보다 먼저 넣어 아래쪽이 패널에 가리게 한다(손이 화면 아래에서 올라온 느낌)
	viewmodel = TextureRect.new()
	viewmodel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewmodel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewmodel.size = Vector2(270, 270)
	viewmodel.pivot_offset = Vector2(205, 215)
	viewmodel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewmodel.hide()
	root.add_child(viewmodel)

	# 1인칭에서 내가 맞으면 내 스프라이트 대신 화면 전체를 붉게 번쩍인다
	hurt_flash = ColorRect.new()
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_flash)

	peek_label = _overlay_label(root, 92, Color(1, 0.9, 0.5))
	# 보스 대기술 예고. 패턴을 읽고 피하는 게 보스전의 핵심이라 로그만이 아니라 화면에 크게 띄운다
	warn_label = _overlay_label(root, 128, Color(1, 0.45, 0.35))
	# 위쪽 가운데(양쪽 HP 칸 사이)는 비어 있고 판·캐릭터를 가리지 않는다
	step_label = _overlay_label(root, 22, Color(1, 1, 1))
	step_label.add_theme_font_size_override("font_size", 26)
	# 1인칭에선 카메라가 적을 보느라 몸 방향과 어긋날 수 있어서, 카드의 "앞"이 어느 쪽인지 따로 알려준다
	compass_label = _overlay_label(root, 0, Color(0.9, 0.95, 1.0))
	compass_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	compass_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	compass_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	compass_label.offset_top = -200
	compass_label.offset_bottom = -170
	fp_act_label = _overlay_label(root, 300, Color(1, 1, 1))
	minimap = Minimap.new()
	minimap.battle = self
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.position = Vector2(24, 96)
	minimap.hide()
	root.add_child(minimap)
	fp_act_label.add_theme_font_size_override("font_size", 30)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	root.add_child(top)
	player_box = VBoxContainer.new()
	player_box.custom_minimum_size.x = 340
	top.add_child(player_box)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	enemy_box = VBoxContainer.new()
	enemy_box.custom_minimum_size.x = 340
	enemy_box.add_theme_constant_override("separation", 6)
	top.add_child(enemy_box)

	log_panel = PanelContainer.new()
	log_panel.anchor_left = 1
	log_panel.anchor_right = 1
	log_panel.anchor_bottom = 1
	log_panel.offset_left = -280
	log_panel.offset_right = -16
	log_panel.offset_top = 100
	log_panel.offset_bottom = -170
	# 중요한 정보(보스 예고·피해·처치)는 화면에 크게 뜨니 기록은 필요할 때만(L) 본다
	log_panel.hide()
	root.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_label.add_theme_font_size_override("bold_font_size", 14)
	log_panel.add_child(log_label)

	# 전투 기록을 숨겨 둬서 조작 안내가 안 보이니, 카드 패널 바로 위에 한 줄로 늘 띄운다
	var keys := Label.new()
	keys.text = "V 1인칭   Tab 볼 적   Space 잠깐 3인칭   M 미니맵   L 전투 기록"
	keys.add_theme_font_size_override("font_size", 13)
	keys.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	keys.add_theme_constant_override("outline_size", 5)
	keys.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	keys.anchor_top = 1
	keys.anchor_bottom = 1
	keys.offset_left = 16
	keys.offset_top = -184
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(keys)

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
	view_button = Button.new()
	view_button.text = "1인칭 보기 (V)"
	view_button.focus_mode = Control.FOCUS_NONE
	view_button.pressed.connect(_toggle_view)
	row.add_child(view_button)
	_style_button(view_button, Color(0.6, 0.85, 0.95))
	go_button = Button.new()
	go_button.text = "    실행    "
	go_button.pressed.connect(_on_go)
	go_button.focus_mode = Control.FOCUS_NONE
	row.add_child(go_button)
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
	result_buttons = HBoxContainer.new()
	result_buttons.add_theme_constant_override("separation", 10)
	rv.add_child(result_buttons)


func _overlay_label(parent: Control, top: int, color: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = top
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.hide()
	parent.add_child(l)
	return l


## 이름 + HP·MP 막대 한 묶음. 적은 오른쪽 정렬로 여러 줄 쌓인다.
func _stat_block(parent: VBoxContainer, right: bool, compact: bool) -> void:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 17 if compact else 20)
	# 해안가처럼 밝은 배경에서도 읽히게 외곽선
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	if right:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)
	name_labels.append(l)
	hp_bars.append(_bar(parent, Rules.MAX_HP, Color(0.85, 0.25, 0.25), 12 if compact else 18))
	mp_bars.append(_bar(parent, Rules.MAX_MP, Color(0.3, 0.6, 0.95), 6 if compact else 10))


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


func _build_stat_ui() -> void:
	for box: VBoxContainer in [player_box, enemy_box]:
		for c in box.get_children():
			c.queue_free()
	name_labels.clear()
	hp_bars.clear()
	mp_bars.clear()
	var n: int = rules.fighters.size()
	_stat_block(player_box, false, false)
	for i in range(1, n):
		_stat_block(enemy_box, true, n > 2)
	for i in n:
		hp_bars[i].max_value = rules.fighters[i].max_hp
	# 적이 여럿이면 오른쪽 위 상태 칸이 길어지니 전투 기록 패널을 그만큼 내린다
	log_panel.offset_top = 100 + (n - 2) * 50


func _build_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	card_buttons.clear()
	# 손패를 종류별 세 묶음으로 나눈다: 이동(4×2 작은 버튼) | 방어·기 모으기·회복(2열 작은 버튼) | 공격(큰 카드 + 범위 그림).
	# 한 줄로 늘어놓던 때는 보상으로 카드가 늘수록 폭이 줄어 글씨가 잘리고 무엇이 공격인지 한눈에 안 들어왔다.
	# 실제로 고민하는 건 공격 카드뿐이라, 나머지는 작게 접고 공격 카드에 폭을 몰아준다.
	var moves := _hand_group(4)
	move_grid = moves
	hand_box.add_child(VSeparator.new())
	var utils := _hand_group(2)
	var attacks := 0
	for id: String in rules.hand(0):
		attacks += 1 if Cards.get_card(id).type == "attack" else 0
	# 화면 1280 에서 여백·이동 묶음(4×92)·보조 묶음(2×128)·구분선 몫을 빼고 공격 카드끼리 나눈다
	var room := 1280 - 40 - (MOVE_W * 4 + 12) - (UTIL_W * 2 + 4) - 40 - 8 * attacks
	var big_w := clampi(room / maxi(attacks, 1), 84, 130)
	compact_cards = big_w < 118
	if attacks > 0:
		hand_box.add_child(VSeparator.new())
	for id: String in rules.hand(0):
		var card: Dictionary = Cards.get_card(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		_style_button(b, CARD_ACCENT[card.type])
		b.pressed.connect(_on_card_pressed.bind(id))
		b.mouse_entered.connect(_preview.bind(id))
		b.mouse_exited.connect(_end_preview)
		match card.type:
			"move":
				b.custom_minimum_size = Vector2(MOVE_W, 35)
				b.add_theme_font_size_override("font_size", 14)
				moves.add_child(b)
			"attack":
				b.custom_minimum_size = Vector2(big_w, 74)
				b.clip_text = compact_cards  # 폭을 줄였을 때만 — 보통 폭에선 자르면 "MP 15" 의 숫자가 잘렸다
				b.add_theme_font_size_override("font_size", 14 if not compact_cards else 12)
				b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
				hand_box.add_child(b)
			_:
				b.custom_minimum_size = Vector2(UTIL_W, 35)
				b.add_theme_font_size_override("font_size", 13)
				utils.add_child(b)
		card_buttons[id] = b


func _hand_group(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	hand_box.add_child(g)
	return g


## 카드 종류별 테두리 색. 기본 테마 버튼은 어두운 배경에서 글자만 떠 보여서 카드처럼 보이지 않는다.
func _style_button(b: Button, accent: Color) -> void:
	UiStyle.style_button(b, accent)


func _card_text(card: Dictionary, facing := 1) -> String:
	match card.type:
		# 이동·보조 카드는 작은 한 줄 버튼이라 숫자만 붙인다
		"move":
			if first_person:
				var body := _body_move_name(card, facing)
				# "▲ 앞 2칸 ·MP5" 는 버튼 폭을 넘어 비용을 숫자만
				return body if card.cost == 0 else "%s ·%d" % [body, card.cost]
			return card.name if card.cost == 0 else "%s ·MP%d" % [card.name, card.cost]
		"guard":
			return "%s -%d%s" % [card.name, card.get("block", Rules.GUARD_BLOCK), " ·MP%d" % card.cost if card.cost > 0 else ""]
		"rest":
			return "기 모으기 +%d" % Rules.REST_MP
		"heal":
			return "%s +%d ·MP%d" % [card.name, card.heal, card.cost]
	if compact_cards:
		return "%s\n%d ·MP%d" % [card.name, card.dmg, card.cost]
	return "%s\n피해 %d · MP %d" % [card.name, card.dmg, card.cost]


# ---------------------------------------------------------------- 진행

## 싱글이면 현재 스테이지 몬스터들과 이어진 HP 로, 아니면(대전·F6 직접 실행) 기본 대전으로 시작.
func _new_game() -> void:
	var cfg: Dictionary = Game.battle_config()
	rules = Rules.new(cfg.player, cfg.enemies)
	# 싱글은 늘 플레이어가 먼저 행동하고, 대전은 단계마다 먼저 움직이는 쪽을 번갈아 공평하게
	rules.alternate = Game.mode == "versus"
	rules.fighters[0].extra.assign(cfg.extra_cards)  # 이번 던전에서 보상으로 얻은 카드
	rules.fighters[0].max_hp += cfg.max_hp_bonus
	rules.fighters[0].hp = cfg.player_hp if cfg.player_hp >= 0 else rules.fighters[0].max_hp
	for k in cfg.enemies.size():
		if cfg.enemy_hp[k] > 0:
			rules.fighters[k + 1].max_hp = cfg.enemy_hp[k]
			rules.fighters[k + 1].hp = cfg.enemy_hp[k]
	var n: int = rules.fighters.size()
	turn = 0
	busy = false
	selected.clear()
	_ensure_fighter_nodes(n)
	for i in n:
		var f = rules.fighters[i]
		var frames := CharArt.build_frames(f.char_id)
		var s := sprites[i]
		s.sprite_frames = frames
		# 도트는 각지게, 큰 그림(캡처·일러스트 풍)은 부드럽게 + 밉맵(작게 그려질 때 지글거림 방지)
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if CharArt.is_smooth(frames) \
			else BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var height: float = CHAR_HEIGHT * Cards.CHARACTERS[f.char_id].get("scale", 1.0)
		sprite_half[i] = height / 2.0
		s.pixel_size = height / frames.get_frame_texture("idle", 0).get_height()
		s.get_child(0).position.y = -sprite_half[i] + 0.02  # 발밑 그림자
		s.get_child(0).show()
		card_tags[i].position.y = sprite_half[i] + 0.45
		s.play("idle")
		s.position = _stand(f.pos, i)
		s.flip_h = f.facing < 0
		s.modulate = Color.WHITE
		step_facing[i] = f.facing
		step_pos[i] = s.position
		gone[i] = false
		_update_mark(i)
	_build_stat_ui()
	_build_hand()
	_clear_tiles()
	log_label.clear()
	var st: Dictionary = Game.current_stage()
	if not st.is_empty():
		var waves: int = st.waves.size()
		var wave_txt := " (%d/%d)" % [Game.wave + 1, waves] if waves > 1 else ""
		var names := PackedStringArray()
		for i in range(1, n):
			names.append(_who(i))
		_log("[b]%s · %s[/b]%s%s — %s 등장!\n" % [Game.stage_code(Game.chapter, Game.stage), st.name, wave_txt,
			" (보스)" if st.get("boss", false) else "", ", ".join(names)])
	_log("카드 3장을 순서대로 고르고 [b]실행[/b]을 누르세요.\n카드에 마우스를 올리면 범위가 노랗게 보입니다.")
	_log("이동 카드는 화면 기준(←→↑↓)이고 다른 캐릭터에 막히지 않습니다(같은 칸 가능). 공격은 바라보는 방향(발밑 화살표)으로 나갑니다. 이동하면 착지하자마자, 이동하지 않았으면 턴이 끝날 때 가장 가까운 적을 향해 돌아섭니다. 같은 칸의 적은 어떤 공격에도 맞습니다. MP 는 턴마다 %d 회복합니다." % Rules.MP_REGEN)
	if rules.alternate:
		_log("같은 단계의 카드는 한 명씩 차례로 나갑니다. 단계마다 먼저 움직이는 쪽이 번갈아 바뀌니 카드 칸의 [b][선][/b]·[b][후][/b]를 보고 고르세요. 방어는 순서와 상관없이 그 단계 내내 걸립니다.")
	else:
		_log("같은 단계의 카드는 [b]내가 먼저[/b], 그다음 적이 차례로 나갑니다. 방어는 순서와 상관없이 그 단계 내내 걸립니다.")
	_log("[b]V[/b]: 1인칭(적이 여럿이면 [b]Tab[/b]으로 볼 적 전환). 바라보는 적이 2칸 이내면 카드를 엿볼 수 있습니다.")
	_log("1인칭에선 왼쪽 위 [b]미니맵[/b]에 고른 카드의 예상 경로가 나옵니다. [b]Space[/b]를 누르는 동안 3인칭, [b]M[/b]은 미니맵 켜기·끄기, [b]L[/b]은 이 기록 창.")
	result_panel.hide()
	_show_current_stats()
	boss_states.clear()
	for i in range(1, n):
		if BossPlan.has_pattern(rules.fighters[i].char_id):
			boss_states[i] = BossPlan.new_state()
	fp_target = _nearest_enemy()
	_plan_enemies()
	_refresh_hand()


func _who(i: int) -> String:
	if i == 0:
		return "나"
	var name: String = Cards.CHARACTERS[rules.fighters[i].char_id].name
	# 같은 몬스터가 둘 이상이면 A·B 로 구분
	var same := 0
	var order := 0
	for j in range(1, rules.fighters.size()):
		if rules.fighters[j].char_id == rules.fighters[i].char_id:
			same += 1
			if j <= i:
				order = same
	return name + (" " + "ABC"[order - 1] if same > 1 else "")


func _show_current_stats() -> void:
	var hp := []
	var mp := []
	for f in rules.fighters:
		hp.append(f.hp)
		mp.append(f.mp)
	_show_stats(hp, mp)


func _show_stats(hp: Array, mp: Array) -> void:
	for i in hp.size():
		var label := "나 · %s" % Cards.CHARACTERS[rules.fighters[i].char_id].name if i == 0 else _who(i)
		if Game.mode != "single" and i > 0:
			label = "AI · " + label
		name_labels[i].text = "%s    HP %d   MP %d" % [label, hp[i], mp[i]]
		hp_bars[i].value = hp[i]
		mp_bars[i].value = mp[i]
		name_labels[i].modulate = Color(1, 1, 1, 0.45) if hp[i] <= 0 else Color.WHITE


func _refresh_hand() -> void:
	var mp: int = rules.fighters[0].mp
	var used: int = rules.cost_of(selected)
	var names := PackedStringArray()
	for k in Rules.CARDS_PER_TURN:
		names.append("%d)%s %s" % [k + 1, _initiative_mark(k), _card_name(selected[k], k) if k < selected.size() else "—"])
	slot_label.text = "   ".join(names) + "        MP 사용 %d / %d" % [used, mp]
	if selected.is_empty() and not busy:
		slot_label.text += "    (고른 카드를 다시 누르면 해제)"
	var full := selected.size() >= Rules.CARDS_PER_TURN
	for id: String in card_buttons:
		var b: Button = card_buttons[id]
		var cost: int = Cards.get_card(id).cost
		var order := selected.find(id)
		# 고른 카드는 다시 눌러 해제할 수 있어야 하니 비활성으로 두지 않는다
		var locked: bool = busy or rules.winner != -1
		# 앞서 고른 카드를 쓴 뒤의 자리에서 보드 밖이라 못 가는 이동 카드는 고를 수 없다
		var dead: bool = order == -1 and Cards.get_card(id).type == "move" and rules.first_dead_move(0, selected + [id]) != -1
		b.disabled = locked or (order == -1 and (full or used + cost > mp or dead))
		b.tooltip_text = "보드 밖이라 갈 수 없음" if dead else ""
		# 방향이 들어간 표기(1인칭 이동 이름, 범위 그림)는 그 카드를 쓸 때의 예상 방향으로 —
		# 고른 카드는 그 순번, 아직 안 고른 카드는 다음 순번. 앞서 고른 이동으로 적을 지나치면 바로 바뀐다(보드 미리보기와 같은 계산)
		var slot := order if order != -1 else selected.size()
		var facing: int = _planned_fighter(slot).facing
		b.text = ("%s " % ORDER_MARK[order] if order != -1 else "") + _card_text(Cards.get_card(id), facing)
		if Cards.get_card(id).type == "attack":
			# 1인칭은 앞이 위로 가게 작게 돌려 그린다(세로로 길어져 카드 높이에 맞춰 칸을 줄임)
			b.icon = RangeIcon.make(Cards.get_card(id), 6 if first_person else 8, facing, first_person)
		b.modulate = Color(1.0, 0.85, 0.35) if order != -1 else Color.WHITE
	_arrange_moves()
	go_button.disabled = busy or not full


## 1인칭에선 이동 버튼을 몸 기준 왼쪽·앞·뒤·오른쪽 순으로(3인칭의 ← ↑ ↓ → 자리와 같은 배치), 2칸 이동은 아랫줄에.
## 3인칭은 손패 순서(← ↑ ↓ →) 그대로라 다시 늘어놓을 필요가 없지만, 1인칭에서 돌아올 때 되돌려야 해서 함께 처리한다.
func _arrange_moves() -> void:
	var facing: int = _planned_fighter(selected.size()).facing
	var ids: Array = []
	for id: String in card_buttons:
		if Cards.get_card(id).type == "move":
			ids.append(id)
	var key := func(id: String) -> int:
		var d: Vector2i = Cards.get_card(id).dir
		var row := 0 if maxi(absi(d.x), absi(d.y)) == 1 else 4
		if not first_person:
			return row + ["l", "u", "d", "r"].find("l" if d.x < 0 else ("r" if d.x > 0 else ("u" if d.y < 0 else "d")))
		return row + ["◀", "▲", "▼", "▶"].find(_body_arrow(d, facing))
	ids.sort_custom(func(a: String, b: String) -> bool: return key.call(a) < key.call(b))
	for k in ids.size():
		move_grid.move_child(card_buttons[ids[k]], k)


## 보드 방향 d 가 facing 을 향한 몸 기준으로 앞(▲)·뒤(▼)·왼쪽(◀)·오른쪽(▶) 중 어디인지.
## 오른쪽을 보면 보드 위쪽이 몸의 왼쪽, 왼쪽을 보면 몸의 오른쪽이다(1인칭 카메라에서 보이는 그대로).
static func _body_arrow(d: Vector2i, facing: int) -> String:
	if d.x != 0:
		return "▲" if signi(d.x) == facing else "▼"
	return "◀" if signi(d.y) == -facing else "▶"


## 슬롯 표시용 카드 이름. 1인칭 이동 카드는 그 순번에서의 몸 기준으로 부른다.
func _card_name(id: String, slot: int) -> String:
	var card: Dictionary = Cards.get_card(id)
	if first_person and card.type == "move":
		return _body_move_name(card, _planned_fighter(slot).facing)
	return card.name


## 1인칭 이동 카드 이름: "▲ 앞", "◀ 왼쪽 2칸". 3인칭의 화면 기준(→ 오른쪽)은 1인칭에선 지금 화면의 어느 쪽인지 따로 따져야 해서
## 몸 기준으로 바꿔 부른다. 카드(규칙)는 그대로이고 이름만 바뀐다.
func _body_move_name(card: Dictionary, facing: int) -> String:
	var arrow := _body_arrow(card.dir, facing)
	var word: String = {"▲": "앞", "▼": "뒤", "◀": "왼쪽", "▶": "오른쪽"}[arrow]
	return "%s %s" % [arrow, word] if card.cost == 0 else "%s %s 2칸" % [arrow, word]


## 대전에서 k 번째 단계에 내가 먼저면 "선", 나중이면 "후". 싱글은 늘 내가 먼저라 표시하지 않는다.
func _initiative_mark(k: int) -> String:
	if not rules.alternate:
		return ""
	return "[선]" if rules.step_order(k)[0] == 0 else "[후]"


func _show_step_banner(ev: Dictionary) -> void:
	var first: int = ev.order[0]
	step_label.text = "%d단계 · %s 먼저" % [ev.step + 1, "나" if first == 0 else _who(first)]
	step_label.show()


## 카드를 누르면 다음 순번으로 들어가고, 이미 고른 카드를 다시 누르면 빠진다(뒤 순번은 앞으로 당겨진다).
func _on_card_pressed(id: String) -> void:
	if busy:
		return
	if selected.has(id):
		selected.erase(id)
		# 앞 카드를 빼서 뒤 이동 카드가 보드 밖으로 나가게 되면 그 카드도 뺀다(고를 수 없는 조합이 남지 않게)
		var dead: int = rules.first_dead_move(0, selected)
		while dead != -1:
			selected.remove_at(dead)
			dead = rules.first_dead_move(0, selected)
		Sound.play("deselect")
		_refresh_hand()
		return
	if selected.size() >= Rules.CARDS_PER_TURN:
		return
	if rules.cost_of(selected + [id]) > rules.fighters[0].mp or rules.first_dead_move(0, selected + [id]) != -1:
		return
	selected.append(id)
	Sound.play("select")
	_refresh_hand()


func _on_go() -> void:
	if busy or not rules.is_valid_selection(0, selected):
		return
	busy = true
	Sound.play("go")
	turn += 1
	var plans := [selected.duplicate()]
	for i in range(1, rules.fighters.size()):
		plans.append(enemy_plans.get(i, []))
	selected.clear()
	_clear_tiles()
	_refresh_hand()
	_update_peek()
	warn_label.hide()
	_log("\n[b]— %d턴 —[/b]" % turn)
	var events: Array = rules.resolve_turn(plans)
	for ev: Dictionary in events:
		_show_step_banner(ev)
		for act: Dictionary in ev.actions:
			await _play_step(act)
	step_label.hide()
	# 턴이 끝나면 규칙대로 모두 가장 가까운 적을 향해 돌아선다 — 다음 턴 미리보기는 이 방향 기준
	for i in rules.fighters.size():
		step_facing[i] = rules.fighters[i].facing
		sprites[i].flip_h = step_facing[i] < 0
		_update_mark(i)
		if not gone[i]:
			sprites[i].modulate = Color.WHITE
			sprites[i].play("idle")
	busy = false
	if rules.winner != -1:
		_show_result()
	else:
		_log("[color=#8fb8ff]턴 종료 — MP +%d[/color]" % Rules.MP_REGEN)
		_show_current_stats()
		_plan_enemies()
	_refresh_hand()


## AI 는 내가 고르기 전에 카드를 정한다(내 선택을 보고 고르는 게 아니므로 공정성은 그대로).
## 패턴 보스는 boss_plan 을 따르고, 예고가 있으면 화면에 띄운다.
func _plan_enemies() -> void:
	warn_label.hide()
	enemy_plans.clear()
	for i in range(1, rules.fighters.size()):
		if not rules.fighters[i].alive():
			continue
		if i == 1 and not debug_ai.is_empty() and rules.is_valid_selection(i, debug_ai):
			enemy_plans[i] = debug_ai
		elif boss_states.has(i):
			var plan := BossPlan.plan(rules, i, rng, boss_states[i])
			enemy_plans[i] = plan.cards
			if plan.phase_msg != "":
				_log("[color=#ff7a5c][b]%s[/b][/color]" % plan.phase_msg)
			if plan.warn != "":
				_log("[color=#ff7a5c]⚠ %s[/color]" % plan.warn)
				warn_label.text = "⚠ " + plan.warn
				warn_label.show()
				Sound.play("warn")
		else:
			enemy_plans[i] = AI.choose(rules, i, rng)
	_update_peek()


func _show_result() -> void:
	Sound.play("victory" if rules.winner == 0 else "defeat")
	match rules.winner:
		0:
			result_label.text = "승리!"
		1:
			result_label.text = "패배..."
		_:
			result_label.text = "무승부"
	for c in result_buttons.get_children():
		c.queue_free()
	if Game.mode == "single":
		if rules.winner == 0 and Game.has_next_wave():
			var waves: int = Game.current_stage().waves.size()
			_result_button("다음 전투 (%d/%d)" % [Game.wave + 2, waves], Color(0.95, 0.8, 0.3), func() -> void:
				Game.on_single_won(rules.fighters[0].hp)
				Game.goto_battle())
		elif rules.winner == 0 and Game.is_final_stage():
			_result_button("던전 클리어!", Color(0.95, 0.8, 0.3), func() -> void:
				Game.on_single_won(rules.fighters[0].hp)
				Game.goto_map())
		elif rules.winner == 0:
			# 스테이지 보상: 셋 중 하나를 골라야 다음으로 넘어간다
			result_label.text = "승리!  보상을 하나 고르세요"
			for opt: Dictionary in Game.reward_options(rng):
				var rb := _result_button("%s\n%s" % [opt.name, opt.desc], Color(0.55, 0.85, 0.6) if opt.kind == "card" else Color(0.95, 0.8, 0.3),
					func() -> void:
						Game.on_single_won(rules.fighters[0].hp)
						Game.take_reward(opt)
						Game.goto_map(), Vector2(210, 64))
				# 새 기술은 범위를 그림으로 미리 보여준다 — 고른 뒤에야 "앞 3칸 한 칸만"인 걸 알게 되면 보상 선택이 운이 된다
				if opt.kind == "card" and Cards.get_card(opt.id).type == "attack":
					rb.icon = RangeIcon.make(Cards.get_card(opt.id), 12)
					rb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
					rb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
					rb.custom_minimum_size.y = 108
		else:
			# 무승부도 패배로 친다 — 보스와 맞교환으로 끝났는데 다음으로 넘어가면 허무하다
			_result_button("처음부터 다시", Color(0.95, 0.8, 0.3), func() -> void:
				Game.start_single()
				Game.goto_map())
	else:
		_result_button("다시 하기", Color(0.95, 0.8, 0.3), _new_game)
	_result_button("타이틀로", Color(0.6, 0.6, 0.65), Game.goto_title)
	result_panel.show()


func _result_button(text: String, accent: Color, action: Callable, size := Vector2(150, 40)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	_style_button(b, accent)
	b.pressed.connect(Sound.play.bind("click"))
	b.pressed.connect(action)
	result_buttons.add_child(b)
	return b


# ---------------------------------------------------------------- 시점·엿보기

## _unhandled_input 이 아니라 _input 에서 받는다 — Tab 은 GUI 가 "다음 버튼으로 포커스 이동"으로 먼저 써버려서
## _unhandled_input 까지 오지 않는다(버튼 하이라이트만 옮겨 다니던 증상).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and not event.echo):
		return
	if event.keycode == KEY_SPACE:
		_set_overview(event.pressed and first_person)
		get_viewport().set_input_as_handled()
		return
	if not event.pressed:
		return
	if event.keycode == KEY_M:
		minimap_always = not minimap_always
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_L:
		log_panel.visible = not log_panel.visible
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_V:
		_toggle_view()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_TAB:
		_cycle_target()
		get_viewport().set_input_as_handled()


func _toggle_view() -> void:
	first_person = not first_person
	# 1인칭에선 내 몸이 카메라를 가리므로 숨긴다(이름표·그림자도 자식이라 함께 숨겨진다)
	sprites[0].visible = not first_person and not gone[0]
	view_button.text = "3인칭 보기 (V)" if first_person else "1인칭 보기 (V)"
	for tag in card_tags:
		_fit_label(tag)
	viewmodel.texture = _make_viewmodel(rules.fighters[0].char_id)
	viewmodel.visible = first_person
	compass_label.visible = first_person
	# 이동 카드 이름·배치와 범위 그림이 시점에 따라 달라진다(1인칭은 몸 기준)
	_refresh_hand()
	if not first_person:
		for m in offscreen_marks:
			m.hide()
	_update_peek()


## Space 를 누르는 동안만 3인칭으로 판 전체를 본다. 떼면 1인칭으로 돌아온다.
func _set_overview(on: bool) -> void:
	overview = on
	sprites[0].visible = (not first_person or overview) and not gone[0]
	viewmodel.visible = first_person and not overview


func _nearest_enemy() -> int:
	var best := -1
	var best_d := 99
	var me = rules.fighters[0]
	for j in rules.foes_of(0):
		var f = rules.fighters[j]
		var d: int = absi(f.pos.x - me.pos.x) + absi(f.pos.y - me.pos.y)
		if d < best_d:
			best_d = d
			best = j
	return best


## 바라볼 적 전환(Tab). 살아 있는 적만 돌아가며.
func _cycle_target() -> void:
	var foes: Array[int] = rules.foes_of(0)
	if foes.is_empty():
		return
	var k := foes.find(fp_target)
	fp_target = foes[(k + 1) % foes.size()]
	_update_peek()


## 1인칭에선 상대가 코앞이라 월드 크기 글자가 화면을 덮는다 → 거리와 무관한 화면 고정 크기로 바꾼다.
func _fit_label(l: Label3D) -> void:
	l.fixed_size = first_person
	l.pixel_size = 0.0011 if first_person else 0.01


## 카메라는 매 프레임 목표 시점으로 부드럽게 따라간다. 전환 트윈을 따로 두지 않아도
## 1인칭에서 캐릭터가 점프·돌진할 때 눈높이가 자연스럽게 따라붙고, 바라보는 적이 바뀌면 고개가 돌아간다.
func _process(delta: float) -> void:
	var fp := first_person and not overview
	var target := _fp_xform() if fp else tp_xform
	var k := 1.0 - exp(-delta * 8.0)
	# 회전베기 중엔 보간 없이 바로 따른다 — 보간하면 180도를 넘는 순간 반대쪽(짧은 쪽)으로 되감긴다
	cam_smooth = target if fp_spin != 0.0 else cam_smooth.interpolate_with(target, k)
	cam.global_transform = Transform3D(cam_smooth.basis, cam_smooth.origin + shake_off)
	cam.fov = lerpf(cam.fov, FP_FOV if fp else TP_FOV, k) + fov_kick
	_apply_backdrop(fp)
	if fp:
		_update_fp_hud()
	# Space 로 잠깐 3인칭을 보는 동안엔 1인칭 전용 표시(나침반·화면 밖 표시)를 숨긴다
	compass_label.visible = fp
	if not fp:
		for m in offscreen_marks:
			m.hide()
	minimap.visible = first_person or minimap_always
	if minimap.visible:
		minimap.queue_redraw()


## 배경 그림이 있을 때 시점에 맞춰 바꾼다: 3인칭 = 화면 전체 그림(땅·소품 숨김), 1인칭 = 파노라마 하늘 + 땅·소품.
func _apply_backdrop(fp: bool) -> void:
	if backdrop == null or _backdrop_fp == int(fp):
		return
	_backdrop_fp = int(fp)
	world_env.environment = env_fp if fp else env_tp
	backdrop_layer.visible = not fp
	scenery_root.visible = fp


## 눈은 내 위치, 시선은 바라보는 적. 적이 옆이나 뒤에 있어도 화면에서 놓치지 않게 고개를 돌린다.
func _fp_xform() -> Transform3D:
	var f := step_facing[0]
	var eye := sprites[0].position + Vector3(-f * 0.2, 0.75, 0)
	var look := eye + Vector3(f * 4.0, -1.3, 0)
	if not fp_face_lock and fp_target > 0 and fp_target < sprites.size() and not gone[fp_target]:
		var tp := sprites[fp_target].position + Vector3(0, -0.5, 0)
		var flat := Vector2(tp.x - eye.x, tp.z - eye.z)
		if flat.length() > 0.6:
			look = tp
	var xf := Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
	if fp_spin != 0.0:
		xf.basis = Basis(Vector3.UP, fp_spin) * xf.basis
	return xf


## 1인칭 HUD: 몸 방향 나침반, 화면 밖 적 표시, 무기 흔들림.
func _update_fp_hud() -> void:
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	var flat_fwd := Vector3(fwd.x, 0, fwd.z).normalized()
	var flat_right := Vector3(right.x, 0, right.z).normalized()
	var hint := "   [Tab] 볼 적 바꾸기" if rules.foes_of(0).size() > 1 else ""
	# 1인칭의 이동 카드는 몸 기준(앞·뒤·왼·오)이라, 카메라가 적을 보느라 고개를 돌렸을 때 몸 앞이 어느 쪽인지만 알려준다
	compass_label.text = "카드의 앞(공격 방향) %s%s" % [
		_screen_arrow(Vector3(step_facing[0], 0, 0), flat_fwd, flat_right), hint]

	var view := get_viewport().get_visible_rect().size
	var area := ui_root.size
	var margin := Vector2(70, 110)
	for i in range(1, sprites.size()):
		var m := offscreen_marks[i]
		if i >= rules.fighters.size() or gone[i]:
			m.hide()
			continue
		var p := sprites[i].global_position
		var behind := cam.is_position_behind(p)
		var sp := cam.unproject_position(p) / view * area
		var inside := not behind and sp.x > margin.x and sp.x < area.x - margin.x and sp.y > margin.y and sp.y < area.y - 200
		if inside:
			m.hide()
			continue
		var center := area / 2.0
		var dir := sp - center
		if behind:
			dir = -dir
		if dir.length() < 1.0:
			dir = Vector2(0, 1)
		# 화면 가장자리로 밀어내되, 아래쪽은 카드 패널 위에서 멈춘다
		var lim := Vector2(center.x - margin.x, (center.y - margin.y) if dir.y < 0 else (area.y - 250 - center.y))
		var t := minf(absf(lim.x / dir.x) if dir.x != 0 else 1e9, absf(lim.y / dir.y) if dir.y != 0 else 1e9)
		var pos := center + dir * t
		var arr := ("▶" if dir.x > 0 else "◀") if absf(dir.x) > absf(dir.y) else ("▼" if dir.y > 0 else "▲")
		m.text = "◀ %s" % _who(i) if arr == "◀" else ("%s ▶" % _who(i) if arr == "▶" else "%s %s" % [arr, _who(i)])
		m.position = pos - m.size / 2.0
		m.show()

	# 무기는 전투 기록 패널 왼쪽 아래에 두고, 숨 쉬듯 살짝 흔든다
	var t_now := Time.get_ticks_msec() / 1000.0
	viewmodel.position = Vector2(area.x - 270 - 290, area.y - 300) + vm_offset + Vector2(0, sin(t_now * 2.2) * 4.0)


## 월드 방향 v 가 지금 카메라 기준으로 앞(▲)·뒤(▼)·오른쪽(▶)·왼쪽(◀) 중 어디인지.
func _screen_arrow(v: Vector3, fwd: Vector3, right: Vector3) -> String:
	var f := v.dot(fwd)
	if f > 0.7:
		return "▲"
	if f < -0.7:
		return "▼"
	return "▶" if v.dot(right) > 0 else "◀"


## 엿보기는 지금 바라보는 적에게만. 가까울수록 많이 보인다.
func _peek_count() -> int:
	if not first_person or busy or rules.winner != -1 or not enemy_plans.has(fp_target):
		return 0
	var me = rules.fighters[0]
	var foe = rules.fighters[fp_target]
	var dist := maxi(absi(foe.pos.x - me.pos.x), absi(foe.pos.y - me.pos.y))
	return PEEK_BY_DIST.get(dist, 0)


func _update_peek() -> void:
	if busy or not first_person or not enemy_plans.has(fp_target):
		peek_label.hide()
		return
	var n := _peek_count()
	if n == 0:
		peek_label.text = "간파 불가 — %s 이(가) 멀다 (2칸 이내로 다가가면 보임)" % _who(fp_target)
	else:
		var parts := PackedStringArray()
		var plan: Array = enemy_plans[fp_target]
		for k in Rules.CARDS_PER_TURN:
			parts.append("%d) %s" % [k + 1, Cards.get_card(plan[k]).name if k < n else "?"])
		# 상대 머리 위에는 띄우지 않는다 — 1인칭에선 상대가 코앞이라 머리 위 글자가 화면 밖으로 잘린다
		peek_label.text = "간파(%s): %s" % [_who(fp_target), "   ".join(parts)]
	peek_label.show()


## 1인칭에서 내가 기술을 쓸 때: 무기 휘두르기·베기 궤적·시야 반동. 3인칭에선 내 스프라이트 연출로 충분하다.
func _fp_attack_fx(card: Dictionary) -> void:
	fp_act_label.text = card.name
	fp_act_label.show()
	_tween().tween_callback(fp_act_label.hide).set_delay(0.7)
	var anim: String = card.get("anim", "lunge")
	var kick := -3.0 if anim in ["arrow", "volley", "wave"] else -7.0
	fov_kick = kick
	_tween().tween_property(self, "fov_kick", 0.0, 0.35)
	var vm := _tween()
	match anim:
		"arrow", "wave":
			# 시위를 당기며 살짝 끌려왔다가, 놓는 순간 앞으로 튕긴다
			vm.tween_property(self, "vm_offset", Vector2(45, 30), 0.08)
			vm.tween_property(self, "vm_offset", Vector2(-30, -18), 0.05)
			vm.tween_property(self, "vm_offset", Vector2.ZERO, 0.2)
		"volley":
			# 하늘로 쏘아 올리니 활을 위로 치켜든다
			vm.tween_property(viewmodel, "rotation_degrees", -28.0, 0.1)
			vm.parallel().tween_property(self, "vm_offset", Vector2(-50, -110), 0.1)
			vm.tween_property(viewmodel, "rotation_degrees", 0.0, 0.3)
			vm.parallel().tween_property(self, "vm_offset", Vector2.ZERO, 0.3)
		"spin":
			# 무기가 화면 오른쪽에서 왼쪽 끝까지 가로로 쓸고, 카메라가 한 바퀴 돈다
			vm.tween_property(viewmodel, "rotation_degrees", -80.0, 0.06)
			vm.tween_property(self, "vm_offset", Vector2(-760, -40), SPIN_TIME * 0.6)
			vm.tween_property(viewmodel, "rotation_degrees", 0.0, 0.15)
			vm.parallel().tween_property(self, "vm_offset", Vector2.ZERO, 0.2)
			if FP_SPIN_CAMERA:
				var cs := _tween()
				cs.tween_property(self, "fp_spin", TAU, SPIN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				cs.tween_callback(func() -> void: fp_spin = 0.0)
		"thrust":
			vm.tween_property(self, "vm_offset", Vector2(-140, -90), 0.08)
			vm.parallel().tween_property(viewmodel, "scale", Vector2(1.2, 1.2), 0.08)
			vm.tween_property(self, "vm_offset", Vector2.ZERO, 0.2)
			vm.parallel().tween_property(viewmodel, "scale", Vector2.ONE, 0.2)
			_slash_fx(false, true)
		_:
			vm.tween_property(viewmodel, "rotation_degrees", -65.0, 0.08)
			vm.parallel().tween_property(self, "vm_offset", Vector2(-160, 20), 0.08)
			vm.tween_property(viewmodel, "rotation_degrees", 0.0, 0.22)
			vm.parallel().tween_property(self, "vm_offset", Vector2.ZERO, 0.22)
			_slash_fx(false)


## 화면을 가르는 흰 궤적. stab 이면 가운데로 찌르는 직선.
func _slash_fx(full: bool, stab := false) -> void:
	var line := Line2D.new()
	line.width = 24.0
	line.default_color = Color(1, 0.97, 0.85, 0.95)
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var c := ui_root.size / 2.0 + Vector2(-120, -40)
	if stab:
		line.add_point(c + Vector2(240, 160))
		line.add_point(c)
	else:
		var span := TAU if full else PI * 0.6
		var start := -PI * 0.15 if not full else 0.0
		for k in 18:
			var a := start + span * k / 17.0
			line.add_point(c + Vector2(cos(a) * 300.0, sin(a) * 160.0 - 40.0))
	ui_root.add_child(line)
	var tw := _tween()
	tw.tween_interval(0.12)
	tw.tween_property(line, "modulate:a", 0.0, 0.35)
	tw.tween_callback(line.queue_free)


# ---------------------------------------------------------------- 연출

## 한 칸에 여럿이 서면 포개져 안 보이므로 칸 안에서 앞뒤로 살짝 비켜 세운다(규칙상으론 같은 칸).
func _overlap_offset(i: int, ev: Dictionary) -> Vector3:
	var same: Array[int] = []
	for j in ev.pos.size():
		if ev.pos[j] == ev.pos[i] and (j == i or ev.hp[j] > 0):
			same.append(j)
	if same.size() <= 1:
		return Vector3.ZERO
	var k := float(same.find(i)) - (same.size() - 1) / 2.0
	return Vector3(k * 0.2, 0, k * 0.55)


## 캐릭터 i 가 칸 t 에 서 있을 때의 스프라이트 중심. i 를 빼면 보통 키 기준(발사체 높이 등).
func _stand(t: Vector2i, i := -1) -> Vector3:
	return _world(t) + Vector3(0, sprite_half[i] if i >= 0 else SPRITE_Y, 0)


## 행동 하나(규칙의 actions 한 칸)를 연출한다. 보통 한 명의 카드만 들어 있고, 단계 첫머리의 방어는 여럿이 함께 들어 있다.
func _play_step(ev: Dictionary) -> void:
	var n: int = rules.fighters.size()
	var cards := []
	for i in n:
		cards.append(Cards.get_card(ev.cards[i]) if ev.cards[i] != "" else {})
		var off := _overlap_offset(i, ev)
		step_pos[i] = _stand(ev.pos[i], i) + off
		step_facing[i] = ev.facing[i]
		# 같은 칸이면 뒤쪽 캐릭터의 카드 이름표를 올려 두 이름표가 포개지지 않게
		card_tags[i].position.y = sprite_half[i] + 0.45 + (0.55 if off.z < 0.0 else 0.0)

	# 누가 비우는 칸으로 들어가는 이동은 비우는 쪽을 먼저 보여줘야 몸이 겹쳐 지나가지 않는다
	var order := range(n)
	for _pass in n:
		for a in n:
			for b in n:
				var ia: int = order.find(a)
				var ib: int = order.find(b)
				if a != b and ia < ib and step_pos[a].is_equal_approx(sprites[b].position):
					order.remove_at(ib)
					order.insert(ia, b)
	for i: int in order:
		if gone[i]:
			continue
		var moved := not sprites[i].position.is_equal_approx(step_pos[i])
		if moved or cards[i].get("type", "") == "move":
			_show_tag(i, cards[i])
			# 2칸 이동은 더 높이 뛰어 "넘어간다"는 게 보이게
			var dist := sprites[i].position.distance_to(step_pos[i]) / TILE
			# 보던 방향의 반대로 가면 뒷걸음질(걷기 동작을 거꾸로)
			var old_f := -1 if sprites[i].flip_h else 1
			if moved:
				var backward := (step_pos[i].x - sprites[i].position.x) * old_f < -0.01
				_hop(i, step_pos[i], 0.35 + 0.35 * dist, backward)
			elif not ev.fizzled[i]:
				# 벽이나 다른 전투원에 막혀 제자리 — 이유 없이 안 움직인 것처럼 보이지 않게 "막힘"과 부딪히는 동작
				card_tags[i].text = cards[i].name + " (막힘)"
				var d: Vector2i = cards[i].dir
				_bump(i, Vector3(signi(d.x), 0, signi(d.y)))  # 이동은 화면 기준이라 바라보는 방향과 무관
			await _wait(MOVE_TIME + 0.15)
			# 규칙상 이동한 쪽은 착지하자마자 가장 가까운 적을 향해 돈다
			sprites[i].flip_h = step_facing[i] < 0
			_update_mark(i)
	for i in n:
		sprites[i].flip_h = step_facing[i] < 0
		_update_mark(i)

	for i in n:
		var type: String = cards[i].get("type", "")
		if type == "guard" or type == "rest" or type == "heal":
			_show_tag(i, cards[i])
			if ev.fizzled[i]:
				card_tags[i].text = cards[i].name + " (MP 부족)"
				await _wait(0.4)
				continue
			Sound.play_at(type, step_pos[i], -2.0)  # "guard" / "rest" / "heal"
			if type == "guard":
				sprites[i].modulate = Color(0.6, 0.8, 1.0)
				sprites[i].play("guard")
				await _wait(0.4)
			elif type == "heal":
				_rest_fx(i, Color(0.45, 1.0, 0.55), Color(0.1, 0.7, 0.25), "+%d HP" % ev.healed[i])
				await _wait(REST_TIME)
			else:
				_rest_fx(i)
				await _wait(REST_TIME)

	for i in n:
		if cards[i].get("type", "") == "attack":
			_show_tag(i, cards[i])
			await _play_attack(i, cards[i], ev)

	_show_stats(ev.hp, ev.mp)
	_log(_step_text(ev))
	for j: int in ev.died:
		_play_death(j)
	await _wait(0.35 + (DEATH_HOLD if not ev.died.is_empty() else 0.0))
	for i in n:
		card_tags[i].hide()
		if ev.hp[i] <= 0:
			continue  # 쓰러진 쪽은 페이드아웃 중이라 건드리지 않는다
		# 방어는 단계 내내 걸리니, 그 단계의 다른 행동을 보여주는 동안에도 방어 자세를 유지한다
		sprites[i].modulate = Color(0.6, 0.8, 1.0) if ev.guarding[i] else Color.WHITE
		_tween().tween_property(sprites[i], "scale", Vector3.ONE, 0.1)
		sprites[i].play("guard" if ev.guarding[i] else "idle")
		# 연출이 겹쳐 조금 어긋났더라도 다음 단계는 정확한 칸에서 시작
		if motion[i] and motion[i].is_valid():
			motion[i].kill()
		sprites[i].position = step_pos[i]


## 쓰러짐: 쓰러지는 동작 → 잠시 그대로 → 서서히 사라짐.
func _play_death(i: int) -> void:
	gone[i] = true
	card_tags[i].hide()
	facing_marks[i].hide()
	if motion[i] and motion[i].is_valid():
		motion[i].kill()
	var s := sprites[i]
	s.position = step_pos[i]
	s.modulate = Color.WHITE
	s.play("die")
	Sound.play_at("death", step_pos[i])
	_log("[color=#c8c8c8]%s[/color]" % ("쓰러졌다…" if i == 0 else "%s 처치!" % _who(i)))
	var tw := _tween()
	tw.tween_interval(DEATH_HOLD)
	tw.tween_callback(s.get_child(0).hide)
	tw.tween_property(s, "modulate:a", 0.0, DEATH_FADE)
	tw.tween_callback(func() -> void: s.visible = false)
	if i == fp_target:
		fp_target = _nearest_enemy()


## 범위 표시 → 공격 동작 → 동작이 닿는 시점(impact)에 맞은 쪽 반응.
func _play_attack(i: int, card: Dictionary, ev: Dictionary) -> void:
	if ev.fizzled[i]:
		card_tags[i].text = card.name + " (MP 부족)"
		await _wait(0.4)
		return
	for h: Dictionary in ev.hits:
		if h.from != i:
			continue
		for t: Vector2i in h.tiles:
			tile_mats[t].albedo_color = _color(i)
			attack_marks[t] = _color(i)
		var fp_me := i == 0 and first_person
		if fp_me:
			# 먼저 몸 정면으로 고개를 돌려 범위 칸을 보여준 뒤 공격 — 카메라 보간(약 0.3초)이 끝날 시간을 준다
			fp_face_lock = true
			await _wait(0.35)
		await _wait(0.2)
		sprites[i].play("attack")
		if fp_me:
			_fp_attack_fx(card)
		await _wait(_attack_anim(i, card, h))
		var landed := false
		for tg: Dictionary in h.targets:
			_on_hit(tg.to, i, tg.dmg)
			landed = landed or tg.dmg > 0
		if landed and card.get("anim", "") == "spin":
			_hitstop(0.07)
		await _wait(0.5)
		_clear_tiles()
		fp_face_lock = false


func _show_tag(i: int, card: Dictionary) -> void:
	if card.is_empty():
		return
	card_tags[i].text = card.name
	card_tags[i].modulate = _color(i).lightened(0.45)
	card_tags[i].show()


## 연출용 트윈/대기. ANIM_SLOW 를 한 곳에서 적용하려고 연출 코드는 create_tween/create_timer 대신 이것만 쓴다.
func _tween() -> Tween:
	return create_tween().set_speed_scale(1.0 / ANIM_SLOW)


func _wait(sec: float) -> Signal:
	return get_tree().create_timer(sec * ANIM_SLOW).timeout


## 같은 스프라이트의 위치 트윈은 항상 하나만 돌게 한다.
func _motion(i: int) -> Tween:
	if motion[i] and motion[i].is_valid():
		motion[i].kill()
	motion[i] = _tween()
	return motion[i]


## 포물선 이동. 수평과 수직을 따로 트윈하면 같은 position 을 두 트윈이 다투게 돼서 한 함수로 계산한다.
func _hop(i: int, to: Vector3, height: float, backward := false) -> void:
	var s := sprites[i]
	var from := s.position
	if backward:
		s.play_backwards("walk")
	else:
		s.play("walk")
	if height > 0.75:
		Sound.play_at("dash", from)  # 2칸 이동은 바람 가르는 소리로 시작
	var tw := _motion(i)
	tw.tween_method(func(t: float) -> void:
		s.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * height, 0), 0.0, 1.0, MOVE_TIME)
	tw.tween_callback(s.play.bind("idle"))
	tw.tween_callback(Sound.play_at.bind("move", to, -4.0))


## 가려던 쪽으로 살짝 나갔다가 튕겨 돌아온다(이동이 막혔을 때).
func _bump(i: int, dir: Vector3) -> void:
	var s := sprites[i]
	var base := step_pos[i]
	var tw := _motion(i)
	tw.tween_property(s, "position", base + dir * 0.35, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position", base, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play_at("block", base, -8.0)


## 공격·피격처럼 한 번만 재생하는 동작이 끝나면 대기로 돌아간다(쓰러짐은 마지막 프레임에 멈춘다).
func _on_anim_finished(i: int) -> void:
	if sprites[i].animation in ["attack", "hit"]:
		sprites[i].play("idle")


## 공격 연출을 시작하고, 공격이 닿기까지 걸리는 시간을 돌려준다(이 시간 뒤에 피격 반응).
func _attack_anim(i: int, card: Dictionary, h: Dictionary) -> float:
	var anim: String = card.get("anim", "lunge")
	Sound.play_at(ATTACK_SFX.get(anim, "slash"), step_pos[i])
	match anim:
		"thrust":
			return _lunge(i, 0.7)
		"spin":
			return _spin(i)
		"jump":
			return _jump_slam(i)
		"arrow":
			return _shoot_arrow(i, h)
		"wave":
			return _shoot(i, h, wave_tex)
		"volley":
			return _volley(i, h)
	return _lunge(i, 0.35)


func _lunge(i: int, dist: float) -> float:
	var base := step_pos[i]
	var tw := _motion(i)
	tw.tween_property(sprites[i], "position", base + Vector3(step_facing[i] * TILE * dist, 0, 0), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprites[i], "position", base, 0.2)
	return 0.12


## 높이 뛰어올랐다가 내리찍는다. 내려앉는 순간이 impact 라 그때 화면을 크게 흔든다.
func _jump_slam(i: int) -> float:
	var s := sprites[i]
	var base := step_pos[i]
	var tw := _motion(i)
	tw.tween_property(s, "position", base + Vector3(0, 2.6, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(s, "position", base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_shake.bind(0.4))
	tw.tween_callback(Sound.play_at.bind("slam", base))
	return 0.54


## 회전베기: 살짝 뛰어오르며 한 번 돌아서고(앞→뒤→앞), 몸 주위로 칼바람 고리가 퍼진다.
## 좌우 반전만 빠르게 반복하던 이전 연출은 깜빡임처럼 보여서, 도는 건 고리로 보여준다.
func _spin(i: int) -> float:
	var s := sprites[i]
	var flip := _tween()
	flip.tween_interval(SPIN_TIME * 0.25)
	flip.tween_callback(func() -> void: s.flip_h = not s.flip_h)
	flip.tween_interval(SPIN_TIME * 0.5)
	flip.tween_callback(func() -> void: s.flip_h = not s.flip_h)
	var base := step_pos[i]
	var hop := _motion(i)
	hop.tween_property(s, "position", base + Vector3(0, 0.35, 0), SPIN_TIME * 0.5).set_ease(Tween.EASE_OUT)
	hop.tween_property(s, "position", base, SPIN_TIME * 0.5).set_ease(Tween.EASE_IN)
	_spin_vfx(base + Vector3(0, -sprite_half[i], 0), step_facing[i], _color(i).lightened(0.15))
	return SPIN_TIME * 0.6


## 회전베기 이펙트 네 겹: 칼날 궤적(바깥) + 잔상 궤적(안쪽, 살짝 늦게) + 바닥 충격파 + 불꽃 파편.
## 궤적은 셰이더(slash_ring)로 그린 띠가 실제로 몸 둘레를 한 바퀴 돈다. 1인칭에선 내 둘레를 감싸며 지나간다.
func _spin_vfx(feet: Vector3, facing: int, tint: Color) -> void:
	var start_rot := 0.0 if facing > 0 else PI  # 궤적이 몸 정면에서 출발
	for layer: Array in [[0.95, 0.55, 0.92, 4.2, 1.0, 0.0], [0.75, 0.38, 0.58, 3.0, 0.65, 0.05]]:
		var trail := _ring_plane(feet + Vector3(0, layer[0], 0))
		var m: ShaderMaterial = trail.material_override
		m.set_shader_parameter("r_in", layer[1])
		m.set_shader_parameter("r_out", layer[2])
		m.set_shader_parameter("tail", layer[3])
		m.set_shader_parameter("fade", layer[4])
		m.set_shader_parameter("edge", tint)
		m.set_shader_parameter("head", -1.0)  # 시작 전엔 아무것도 안 보이게
		trail.rotation = Vector3(0.12, start_rot, 0.0)  # 살짝 기울여 평평한 원판처럼 보이지 않게
		var fade0: float = layer[4]
		var tw := _tween()
		tw.tween_interval(layer[5])
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("head", v), 0.0, TAU + 0.8, SPIN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("fade", v), fade0, 0.0, 0.22)
		tw.tween_callback(trail.queue_free)

	var wave := _ring_plane(feet + Vector3(0, 0.04, 0))
	var wm: ShaderMaterial = wave.material_override
	wm.set_shader_parameter("full", true)
	wm.set_shader_parameter("edge", tint.lightened(0.3))
	var wt := _tween()
	wt.tween_method(func(v: float) -> void:
		wm.set_shader_parameter("r_in", lerpf(0.05, 0.86, v))
		wm.set_shader_parameter("r_out", lerpf(0.15, 0.96, v))
		wm.set_shader_parameter("fade", 0.9 * (1.0 - v)), 0.0, 1.0, SPIN_TIME * 1.2).set_ease(Tween.EASE_OUT)
	wt.tween_callback(wave.queue_free)

	var sparks := _particles(48, 0.5, Color(1, 0.95, 0.8), tint)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_axis = Vector3.UP
	sparks.emission_ring_radius = 2.1
	sparks.emission_ring_inner_radius = 1.5
	sparks.emission_ring_height = 0.2
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.radial_accel_min = 6.0
	sparks.radial_accel_max = 12.0
	sparks.position = feet + Vector3(0, 0.9, 0)
	sparks.emitting = true


## 수평으로 눕힌 사각형에 칼날 궤적 셰이더를 입힌 판. 반폭 2.6 이면 주변 8칸(±2)을 덮는다.
func _ring_plane(pos: Vector3) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.2, 5.2)
	var mat := ShaderMaterial.new()
	mat.shader = SlashShader
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi


## 기 모으기: 발밑에서 파란 기운이 몸을 감싸며 소용돌이쳐 올라가고, 푸른 고리 두 개가 발에서 머리로 솟는다.
## 몸도 잠깐 푸르게 빛나고 "+MP" 가 뜬다.
## 기본은 파란 기(기 모으기). 치유는 같은 연출을 초록으로 쓴다.
func _rest_fx(i: int, tint := Color(0.45, 0.75, 1.0), deep := Color(0.1, 0.3, 1.0), text := "") -> void:
	var feet := step_pos[i] + Vector3(0, -sprite_half[i], 0)
	var height := sprite_half[i] * 2.0

	# 1) 몸을 감싸며 올라가는 기 입자: 발밑 고리에서 뿜어, 접선 가속으로 돌고 안쪽으로 살짝 모이며 위로
	var p := _particles(90, 0.9, Color(tint.r, tint.g, tint.b, 1.0), deep)
	p.one_shot = true
	p.explosiveness = 0.0  # 한 번에 터지지 않고 기간 내내 뿜는다
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.75
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, 0.6, 0)
	p.tangential_accel_min = 4.0
	p.tangential_accel_max = 6.0
	p.radial_accel_min = -1.6
	p.radial_accel_max = -0.8
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.8
	p.position = feet + Vector3(0, 0.05, 0)
	p.emitting = true

	# 몸을 감싸는 푸른 빛기둥: 아래가 진하고 위로 갈수록 사라지는 원통. 입자만으론 "감싸는" 느낌이 약했다
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	var mid := tint.lerp(deep, 0.5)
	g.set_color(0, Color(mid.r, mid.g, mid.b, 0.0))  # 위(UV 0)
	g.set_color(1, Color(mid.r, mid.g, mid.b, 0.75))  # 아래
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura_mat.albedo_texture = tex
	aura_mat.albedo_color = Color(1, 1, 1, 0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.75
	cyl.height = height * 1.1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var aura := MeshInstance3D.new()
	aura.mesh = cyl
	aura.material_override = aura_mat
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.position = feet + Vector3(0, height * 0.55, 0)
	add_child(aura)
	var at := _tween()
	at.tween_property(aura_mat, "albedo_color:a", 1.0, 0.2)
	at.parallel().tween_property(aura, "rotation:y", TAU, REST_TIME)
	at.tween_property(aura_mat, "albedo_color:a", 0.0, 0.35).set_delay(REST_TIME - 0.55)
	at.tween_callback(aura.queue_free)

	# 2) 발에서 머리로 솟는 푸른 고리 두 개(시간차)
	for k in 2:
		var ring := _ring_plane(feet + Vector3(0, 0.1, 0))
		ring.scale = Vector3(0.32, 1, 0.32)
		var m: ShaderMaterial = ring.material_override
		m.set_shader_parameter("full", true)
		m.set_shader_parameter("r_in", 0.7)
		m.set_shader_parameter("r_out", 0.92)
		m.set_shader_parameter("edge", deep.lightened(0.2))
		m.set_shader_parameter("core", tint.lightened(0.5))
		m.set_shader_parameter("fade", 0.0)
		var tw := _tween()
		tw.tween_interval(k * 0.22)
		tw.tween_method(func(v: float) -> void:
			ring.position.y = feet.y + 0.1 + v * height
			ring.scale = Vector3(0.32 - v * 0.12, 1, 0.32 - v * 0.12)
			m.set_shader_parameter("fade", sin(v * PI) * 0.95), 0.0, 1.0, 0.55).set_ease(Tween.EASE_OUT)
		tw.tween_callback(ring.queue_free)

	# 3) 몸이 푸르게 빛났다 돌아오고, +MP 표시
	var s := sprites[i]
	var glow := _tween()
	glow.tween_property(s, "modulate", tint.lightened(0.3), 0.2)
	glow.tween_property(s, "modulate", Color.WHITE, 0.45)
	var l := Label3D.new()
	l.text = text if text != "" else "+%d MP" % Rules.REST_MP
	l.font_size = 52
	l.outline_size = 10
	l.modulate = tint
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	_fit_label(l)
	add_child(l)
	l.position = s.position + Vector3(0.7, -0.3, 0.3)  # 머리 위 카드 이름표와 겹치지 않게 몸통 높이에서 시작
	var lt := _tween().set_parallel(true)
	lt.tween_property(l, "position:y", l.position.y + 1.0, 0.8)
	lt.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.4)
	lt.chain().tween_callback(l.queue_free)


## 한 번 터지고 사라지는 빛 입자. 색은 from → to 로 바래며 투명해진다.
func _particles(amount: int, life: float, from: Color, to: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.speed_scale = 1.0 / ANIM_SLOW
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, Color(to.r, to.g, to.b, 0.0))
	p.color_ramp = g
	add_child(p)
	get_tree().create_timer(life * ANIM_SLOW + 0.5).timeout.connect(p.queue_free)
	return p


## 맞은 자리에서 튀는 불꽃. 큰 피해는 더 크게.
func _hit_sparks(pos: Vector3, big: bool) -> void:
	var p := _particles(26 if big else 14, 0.35, Color(1, 1, 0.85), Color(1, 0.45, 0.15))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0 if big else 4.0
	p.gravity = Vector3(0, -9, 0)
	p.position = pos
	p.emitting = true


## 아주 짧게 시간을 거의 멈춘다(타격감). 실제 시간으로 기다려야 하므로 타이머는 time_scale 을 무시한다.
func _hitstop(sec: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = 1.0


func _make_projectile(tex: Texture2D, flip: bool) -> Sprite3D:
	var a := Sprite3D.new()
	a.texture = tex
	a.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	a.pixel_size = SPRITE_PX
	a.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	a.shaded = false
	a.flip_h = flip
	add_child(a)
	return a


## 입체 화살(촉이 -Z). 빌보드 그림은 1인칭에서 옆모습 그대로 날아가 어색해서, 어느 방향에서 봐도 맞게 보이도록
## 화살대·촉·깃을 메시로 만든다. look_at 으로 날아가는 쪽을 향하게 한다.
func _make_arrow() -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.022
	cyl.height = 0.85
	cyl.radial_segments = 6
	cyl.rings = 1
	shaft.mesh = cyl
	shaft.rotation_degrees.x = 90
	shaft.material_override = _flat_mat(Color(0.62, 0.42, 0.2))
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.065
	cone.height = 0.18
	cone.radial_segments = 6
	cone.rings = 1
	head.mesh = cone
	head.rotation_degrees.x = -90  # 원뿔 꼭지(+Y)를 -Z(앞)로
	head.position = Vector3(0, 0, -0.5)
	head.material_override = _flat_mat(Color(0.82, 0.85, 0.9))
	root.add_child(head)
	for size: Vector3 in [Vector3(0.15, 0.006, 0.18), Vector3(0.006, 0.15, 0.18)]:
		var fl := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		fl.mesh = box
		fl.position = Vector3(0, 0, 0.36)
		fl.material_override = _flat_mat(Color(0.96, 0.96, 0.96))
		root.add_child(fl)
	add_child(root)
	return root


## 도트 그림과 어울리게 빛을 받지 않는 단색 재질.
func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## 화살 꼬리의 빛 띠: 화살 축을 따라 뒤로 길게 뻗으며 흐려지는 십자 모양 판 두 장.
## 입자로 뿌리면 1인칭에서 카메라 코앞에 생긴 입자가 커다란 사각형으로 보여서, 화살에 붙은 띠로 만든다
## (정면·뒤에선 거의 안 보이고 옆에서 보면 궤적이 된다).
func _trail(arrow: Node3D) -> Node3D:
	var root := Node3D.new()
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.5, 0.0))  # 꼬리 끝
	g.set_color(1, Color(1, 0.95, 0.75, 0.75))  # 화살 쪽
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	for roll in [0.0, 90.0]:
		var wrap := Node3D.new()
		wrap.rotation_degrees.z = roll
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.07, 1.1)
		quad.mesh = qm
		quad.material_override = mat
		quad.rotation_degrees.x = 90  # 판의 세로(+Y)를 화살 뒤쪽(+Z)으로 눕힌다
		quad.position = Vector3(0, 0, 0.95)
		wrap.add_child(quad)
		root.add_child(wrap)
	arrow.add_child(root)
	return root


## 화살. 맞으면 처음 맞은 적에서 사라지고, 빗나가면 범위 끝 바닥에 비스듬히 꽂혔다가 사라진다.
## 1인칭에서 내가 쏘면 눈 바로 아래에서 출발해, 내 손을 떠나 멀어지는 뒷모습이 보인다.
func _shoot_arrow(i: int, h: Dictionary) -> float:
	var f := step_facing[i]
	var start := step_pos[i] + Vector3(f * 0.5, 0.15, 0)
	if i == 0 and first_person:
		start = sprites[0].position + Vector3(f * 0.35, 0.5, 0.15)
	var stuck: bool = not h.hit
	var end: Vector3
	if h.hit:
		end = step_pos[h.targets[0].to] + Vector3(-f * 0.3, 0.1, 0)
	elif not h.tiles.is_empty():
		end = _world(h.tiles[-1]) + Vector3(f * 0.5, 0.08, 0)
	else:
		end = Vector3(start.x + f * TILE, 0.08, start.z)
	var a := _make_arrow()
	a.position = start
	a.look_at(end, Vector3.UP)
	var trail := _trail(a)
	var t := 0.12 + start.distance_to(end) / TILE * 0.07
	var tw := _tween()
	tw.tween_property(a, "position", end, t)
	tw.tween_callback(trail.hide)
	if stuck:
		tw.tween_callback(_dust.bind(end))
		tw.tween_callback(Sound.play_at.bind("arrow_hit", end, -4.0))
		tw.tween_interval(1.0)
		tw.tween_property(a, "scale", Vector3.ZERO, 0.25)
	tw.tween_callback(a.queue_free)
	_recoil(i)
	return t


## 발사체(화살·초음파). 맞으면 처음 맞은 적 앞에서, 빗나가면 사거리 끝 칸까지 날아간다.
func _shoot(i: int, h: Dictionary, tex: Texture2D) -> float:
	var f := step_facing[i]
	var start := step_pos[i] + Vector3(f * 0.6, 0.1, 0)
	var end := start + Vector3(f * TILE, 0, 0)
	if h.hit:
		end = step_pos[h.targets[0].to] + Vector3(-f * 0.4, 0.1, 0)
	elif not h.tiles.is_empty():
		end = _stand(h.tiles[-1]) + Vector3(0, 0.1, 0)
	var a := _make_projectile(tex, f < 0)
	a.position = start
	var t := 0.1 + absf(end.x - start.x) / TILE * 0.08
	var tw := _tween()
	tw.tween_property(a, "position", end, t)
	tw.tween_callback(a.queue_free)
	_recoil(i)
	return t


## 화살비: 하늘로 세 발 쏘아 올린 뒤, 범위 칸마다 경고 고리가 깔리고 화살이 비스듬히 떨어져 꽂힌다.
func _volley(i: int, h: Dictionary) -> float:
	var f := step_facing[i]
	var bow := step_pos[i] + Vector3(f * 0.4, 0.35, 0)
	const LAUNCH := 0.25
	const FALL := 0.22
	for k in 3:
		var up := _make_arrow()
		up.position = bow
		var sky := bow + Vector3(f * (1.0 + k * 0.4), 6.5, (k - 1) * 0.5)
		up.look_at(sky, Vector3.BACK)
		var ut := _tween()
		ut.tween_property(up, "position", sky, LAUNCH).set_ease(Tween.EASE_IN)
		ut.tween_callback(up.queue_free)

	var n: int = h.tiles.size()
	for k in n:
		var ground := _world(h.tiles[k])
		var warn := _ring_plane(ground + Vector3(0, 0.03, 0))
		warn.scale = Vector3(0.36, 1, 0.36)
		var wm: ShaderMaterial = warn.material_override
		wm.set_shader_parameter("full", true)
		wm.set_shader_parameter("r_in", 0.62)
		wm.set_shader_parameter("r_out", 0.9)
		wm.set_shader_parameter("edge", Color(1, 0.25, 0.2))
		wm.set_shader_parameter("core", Color(1, 0.6, 0.5))
		wm.set_shader_parameter("fade", 0.0)
		var wt := _tween()
		wt.tween_method(func(v: float) -> void: wm.set_shader_parameter("fade", v), 0.0, 0.9, LAUNCH * 0.6)
		wt.tween_interval(LAUNCH * 0.4 + FALL + k * 0.06)
		wt.tween_method(func(v: float) -> void: wm.set_shader_parameter("fade", v), 0.9, 0.0, 0.25)
		wt.tween_callback(warn.queue_free)
		for m in 3:
			var land := ground + Vector3(rng.randf_range(-0.55, 0.55), 0.05, rng.randf_range(-0.55, 0.55))
			var from := land + Vector3(-f * 1.4, 5.5, 0)
			var a := _make_arrow()
			a.position = from
			a.look_at(land, Vector3.BACK)
			a.visible = false
			var tw := _tween()
			tw.tween_interval(LAUNCH + k * 0.06 + m * 0.04)
			tw.tween_callback(a.show)
			tw.tween_property(a, "position", land, FALL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(_dust.bind(land))
			tw.tween_callback(Sound.play_at.bind("arrow_hit", land, -10.0, 0.15))
			tw.tween_interval(0.8)
			tw.tween_property(a, "scale", Vector3.ZERO, 0.2)
			tw.tween_callback(a.queue_free)
	_recoil(i)
	return LAUNCH + FALL + maxi(n - 1, 0) * 0.06 + 0.08


## 화살이 꽂힌 자리에서 이는 흙먼지.
func _dust(pos: Vector3) -> void:
	var p := _particles(8, 0.4, Color(0.9, 0.85, 0.7, 0.9), Color(0.6, 0.55, 0.45))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -3, 0)
	p.position = pos
	p.emitting = true


## 활을 쏠 때 살짝 뒤로 밀리는 반동.
func _recoil(i: int) -> void:
	var tw := _motion(i)
	tw.tween_property(sprites[i], "position", step_pos[i] + Vector3(-step_facing[i] * 0.2, 0, 0), 0.06)
	tw.tween_property(sprites[i], "position", step_pos[i], 0.15)


## 피해 숫자 + 공격자 반대쪽으로 밀림 + 화면 흔들림(피해가 클수록 세게).
func _on_hit(target: int, attacker: int, dmg: int) -> void:
	Sound.play_at("block" if dmg <= 0 else "hit", step_pos[target])
	if first_person and target == 0:
		hurt_flash.color.a = 0.28 + minf(0.15, dmg * 0.004)
		_tween().tween_property(hurt_flash, "color:a", 0.0, 0.45)
	else:
		_damage_popup(target, dmg)
	if dmg <= 0:
		return
	_hit_sparks(step_pos[target], dmg >= 30)
	sprites[target].play("hit")
	var away := step_pos[target] - step_pos[attacker]
	away.y = 0
	if away.length() < 0.01:
		away = Vector3(-step_facing[target], 0, 0)
	away = away.normalized() * 0.35
	var tw := _motion(target)
	tw.tween_property(sprites[target], "position", step_pos[target] + away, 0.08)
	tw.tween_property(sprites[target], "position", step_pos[target], 0.2)
	_shake(0.1 + dmg * 0.005)


func _shake(strength: float) -> void:
	var tw := _tween()
	for k in 5:
		var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * strength
		tw.tween_property(self, "shake_off", off, 0.03)
	tw.tween_property(self, "shake_off", Vector3.ZERO, 0.05)


func _damage_popup(target: int, dmg: int) -> void:
	var l := Label3D.new()
	l.text = "-%d" % dmg if dmg > 0 else "막음"
	l.font_size = 64
	l.outline_size = 12
	l.modulate = Color(1, 0.35, 0.3)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	_fit_label(l)
	add_child(l)
	l.position = sprites[target].position + Vector3(0.7, 0.1, 0.3)
	var tw := _tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

	# 방어로 다 막았으면 빨갛게 깜빡이지 않는다 — 맞은 것처럼 보이면 방어가 실패한 줄 안다
	if dmg > 0:
		var s := sprites[target]
		s.modulate = Color(1, 0.35, 0.35)
		_tween().tween_property(s, "modulate", Color.WHITE, 0.4)


## 카드에 마우스를 올리면 범위/도착 칸을 보여준다. 기준은 지금 자리가 아니라 "앞서 고른 카드를 다 쓴 뒤의 자리"
## — ①→2칸 을 고르고 ②베기 를 보면, 이동한 자리에서의 베기 범위가 보여야 계획을 세울 수 있다.
## (이미 고른 카드에 올리면 그 카드 직전 자리 기준)
func _preview(id: String) -> void:
	if busy:
		return
	_clear_tiles()
	var order := selected.find(id)
	var f = _planned_fighter(order if order != -1 else selected.size())
	var card: Dictionary = Cards.get_card(id)
	preview_tiles.clear()
	if card.type == "attack":
		preview_tiles.assign(rules.attack_tiles(f, card))
	elif card.type == "move":
		var t: Vector2i = Rules.move_target(f, card.dir)
		if t != f.pos:
			preview_tiles = [t]
	for t: Vector2i in preview_tiles:
		tile_mats[t].albedo_color = PREVIEW_COLOR


func _end_preview() -> void:
	preview_tiles.clear()
	_clear_tiles()


## 고른 카드 앞에서부터 count 장을 썼을 때의 내 상태(위치·방향). 다른 전투원은 제자리라고 가정한다
## — 상대 카드는 모르니 계획용 근사. 이동 후엔 규칙대로 가장 가까운 적을 향해 돈다.
func _planned_fighter(count: int):
	var me = rules.fighters[0].copy()
	for k in mini(count, selected.size()):
		var card: Dictionary = Cards.get_card(selected[k])
		if card.type != "move":
			continue
		me.pos = Rules.move_target(me, card.dir)  # 다른 전투원에 막히지 않는다(같은 칸 허용)
		me.facing = rules.nearest_facing(0, me)
	return me


## 미니맵용 예상 경로: 고른 카드마다 그 뒤의 자리·방향, 공격 카드면 그 자리에서의 범위.
func planned_path() -> Array:
	var out := []
	if busy:
		return out
	for k in selected.size():
		var card: Dictionary = Cards.get_card(selected[k])
		var me = _planned_fighter(k + 1)
		var step := {"order": k, "pos": me.pos}
		if card.type == "attack":
			step.tiles = rules.attack_tiles(_planned_fighter(k), card)
		out.append(step)
	return out


## 스프라이트가 지금 서 있는(또는 지나가는) 칸. 연출 중에도 미니맵이 실제 움직임을 따라가게.
func sprite_tile(i: int) -> Vector2i:
	var p := sprites[i].position
	return Vector2i(clampi(roundi(p.x / TILE + (Rules.COLS - 1) / 2.0), 0, Rules.COLS - 1),
		clampi(roundi(p.z / TILE + (Rules.ROWS - 1) / 2.0), 0, Rules.ROWS - 1))


func _clear_tiles() -> void:
	attack_marks.clear()
	for t: Vector2i in tile_mats:
		tile_mats[t].albedo_color = _tile_color(t)


func _step_text(ev: Dictionary) -> String:
	var parts := PackedStringArray()
	for i in rules.fighters.size():
		if ev.cards[i] == "":
			continue
		var s := "%s: %s" % [_who(i), Cards.get_card(ev.cards[i]).name]
		if ev.fizzled[i]:
			s += " (MP 부족)"
		for h: Dictionary in ev.hits:
			if h.from != i:
				continue
			if not h.hit:
				s += " → 빗나감"
			for tg: Dictionary in h.targets:
				var who := _who(tg.to)
				if tg.dmg == 0:
					s += " → %s 막힘" % who
				else:
					s += " → %s %d" % [who, tg.dmg]
		parts.append(s)
	return "  /  ".join(parts)


func _log(text: String) -> void:
	log_label.append_text(text + "\n")


# ---------------------------------------------------------------- 개발용

## `godot --path . -- --shot=경로.png [--auto]`
## 화면을 PNG 로 저장하고 종료한다. --auto 면 한 턴을 자동 진행해 연출 도중(_mid0, _mid1…)과 끝난 뒤를 저장한다.
## --cards=내 카드3장, --ai=첫 적 카드3장 (쉼표 구분), --mid=캡처 시각(초, 쉼표 구분)으로 보고 싶은 연출을 고정할 수 있다.
## --fp 는 1인칭으로 시작, --pos=x,y,facing 를 전투원 순서대로 이어 붙여 시작 배치,
## --hp=HP 를 전투원 순서대로(쉼표) 시작 HP, --theme=coast 는 배경 지정, --keys=Tab,V 는 키 입력 흉내.
func _handle_debug_args() -> void:
	var shot := ""
	var auto := false
	var reward_shot := false  # --reward: 이긴 것으로 치고 결과(보상 선택) 화면을 찍는다
	var hand: Array = rules.hand(0)
	var mine: Array = ["right", hand[Cards.COMMON.size()], "guard"]  # 오른쪽 + 첫 공격 + 방어 (캐릭터와 무관하게 유효)
	var mids: Array[float] = [0.75]
	var n: int = rules.fighters.size()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a == "--auto":
			auto = true
		elif a == "--fp":
			_toggle_view()
		elif a.begins_with("--pos="):
			# 특정 배치가 필요한 연출을 바로 보려고
			var v := a.substr(6).split(",")
			for i in mini(n, v.size() / 3):
				rules.fighters[i].pos = Vector2i(int(v[i * 3]), int(v[i * 3 + 1]))
				rules.fighters[i].facing = int(v[i * 3 + 2])
				step_facing[i] = rules.fighters[i].facing
				sprites[i].position = _stand(rules.fighters[i].pos, i)
				sprites[i].flip_h = step_facing[i] < 0
				_update_mark(i)
			fp_target = _nearest_enemy()
			_plan_enemies()
		elif a.begins_with("--hp="):
			# 보스 분노 페이즈처럼 HP 조건이 있는 장면을 바로 보려고
			var v := a.substr(5).split(",")
			for i in mini(n, v.size()):
				rules.fighters[i].hp = int(v[i])
			_show_current_stats()
			_plan_enemies()
		elif a.begins_with("--cards="):
			mine = Array(a.substr(8).split(","))
		elif a.begins_with("--ai="):
			debug_ai = Array(a.substr(5).split(","))
			_plan_enemies()
		elif a == "--reward":
			reward_shot = true
		elif a.begins_with("--mid="):
			mids.clear()
			for m in a.substr(6).split(","):
				mids.append(float(m))
	if shot == "":
		return
	await get_tree().create_timer(0.5).timeout
	for id: String in mine:
		_on_card_pressed(id)
	# 키 입력을 실제 입력 경로로 흘려 보낸다(버튼 포커스가 키를 가로채지 않는지까지 확인하려고)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--keys="):
			for key in a.substr(7).split(","):
				var ev := InputEventKey.new()
				ev.keycode = OS.find_keycode_from_string(key)
				ev.pressed = true
				Input.parse_input_event(ev)
				await get_tree().create_timer(0.6).timeout
	if auto:
		_on_go()
		var elapsed := 0.0
		for k in mids.size():
			await get_tree().create_timer(mids[k] - elapsed).timeout
			elapsed = mids[k]
			get_viewport().get_texture().get_image().save_png(shot.get_basename() + "_mid%d.png" % k)
		while busy:
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
	if reward_shot:
		rules.winner = 0
		_show_result()
		await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()
